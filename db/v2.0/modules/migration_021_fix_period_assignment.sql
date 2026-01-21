-- =============================================================================
-- MIGRACIÓN 021: Corrección de asignación de periodos en pagos
-- =============================================================================
-- Fecha: 2025-11-26
-- Autor: Sistema Credinet v2.0
--
-- PROBLEMA IDENTIFICADO:
-- Los pagos se estaban asignando al periodo que CONTIENE la fecha de vencimiento,
-- pero la lógica de negocio requiere que salgan en el statement ANTERIOR.
--
-- LÓGICA CORRECTA:
-- - Pagos día 15 → Deben salir en el corte del día 8 (7-8 días ANTES del vencimiento)
-- - Pagos último día → Deben salir en el corte del día 23 (7-8 días ANTES del vencimiento)
--
-- RAZÓN:
-- El statement se genera al día siguiente del cierre del periodo, dándole tiempo
-- al asociado para cobrar al cliente ANTES de la fecha de vencimiento oficial.
-- =============================================================================

-- =============================================================================
-- FUNCIÓN AUXILIAR: get_cut_period_for_payment
-- =============================================================================
-- Asigna el periodo de corte correcto para una fecha de pago dada.

CREATE OR REPLACE FUNCTION get_cut_period_for_payment(p_payment_date DATE)
RETURNS INTEGER
LANGUAGE plpgsql
IMMUTABLE
STRICT
AS $$
DECLARE
    v_period_id INTEGER;
    v_day INTEGER;
    v_month INTEGER;
    v_year INTEGER;
BEGIN
    v_day := EXTRACT(DAY FROM p_payment_date)::INTEGER;
    v_month := EXTRACT(MONTH FROM p_payment_date)::INTEGER;
    v_year := EXTRACT(YEAR FROM p_payment_date)::INTEGER;
    
    -- Determinar si es día 15 o último día del mes
    IF v_day = 15 THEN
        -- Pago día 15 → Buscar periodo que cierra día 7-8 (aproximado) ANTES del día 15
        SELECT id INTO v_period_id
        FROM cut_periods
        WHERE EXTRACT(DAY FROM period_end_date) BETWEEN 6 AND 8  -- Cierra ~día 7
          AND period_end_date < p_payment_date  -- Cierra ANTES del vencimiento
          AND EXTRACT(MONTH FROM period_end_date) = v_month  -- Mismo mes
          AND EXTRACT(YEAR FROM period_end_date) = v_year
        ORDER BY period_end_date DESC
        LIMIT 1;
        
        -- Si no encontró en el mismo mes, buscar a fin del mes anterior
        IF v_period_id IS NULL THEN
            SELECT id INTO v_period_id
            FROM cut_periods
            WHERE EXTRACT(DAY FROM period_end_date) BETWEEN 6 AND 8
              AND period_end_date < p_payment_date
              AND (
                  (EXTRACT(MONTH FROM period_end_date) = v_month - 1 AND EXTRACT(YEAR FROM period_end_date) = v_year) OR
                  (v_month = 1 AND EXTRACT(MONTH FROM period_end_date) = 12 AND EXTRACT(YEAR FROM period_end_date) = v_year - 1)
              )
            ORDER BY period_end_date DESC
            LIMIT 1;
        END IF;
        
    ELSE
        -- Pago último día → Buscar periodo que cierra día 22-23 ANTES del último día
        SELECT id INTO v_period_id
        FROM cut_periods
        WHERE EXTRACT(DAY FROM period_end_date) BETWEEN 21 AND 23  -- Cierra ~día 22
          AND period_end_date < p_payment_date  -- Cierra ANTES del vencimiento
          AND EXTRACT(MONTH FROM period_end_date) = v_month  -- Mismo mes
          AND EXTRACT(YEAR FROM period_end_date) = v_year
        ORDER BY period_end_date DESC
        LIMIT 1;
    END IF;
    
    -- Si aún no encontró, usar lógica de fallback (contención)
    IF v_period_id IS NULL THEN
        RAISE WARNING 'No se encontró periodo con cierre antes de %. Usando fallback.', p_payment_date;
        SELECT id INTO v_period_id
        FROM cut_periods
        WHERE period_start_date <= p_payment_date
          AND period_end_date >= p_payment_date
        ORDER BY period_start_date DESC
        LIMIT 1;
    END IF;
    
    RETURN v_period_id;
END;
$$;

COMMENT ON FUNCTION get_cut_period_for_payment(DATE) IS 
'Asigna el periodo de corte correcto para una fecha de pago. 
Día 15 → periodo con cierre ~día 8 anterior (statement se genera día 8).
Último día → periodo con cierre ~día 23 anterior (statement se genera día 23).';

-- =============================================================================
-- ACTUALIZAR generate_payment_schedule con nueva lógica
-- =============================================================================

CREATE OR REPLACE FUNCTION generate_payment_schedule()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $function$
DECLARE
    v_approval_date DATE;
    v_first_payment_date DATE;
    v_approved_status_id INTEGER;
    v_pending_status_id INTEGER;
    v_amortization_row RECORD;
    v_period_id INTEGER;
    v_total_inserted INTEGER := 0;
    v_sum_expected DECIMAL(12,2) := 0;
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
    v_legacy_data RECORD;
    v_period_counter INTEGER;
    v_current_payment_date DATE;
    v_is_day_15 BOOLEAN;
BEGIN
    SELECT id INTO v_approved_status_id FROM loan_statuses WHERE name = 'APPROVED';
    SELECT id INTO v_pending_status_id FROM payment_statuses WHERE name = 'PENDING';
    
    IF NEW.status_id = v_approved_status_id 
       AND (OLD.status_id IS NULL OR OLD.status_id != v_approved_status_id) 
    THEN
        v_start_time := CLOCK_TIMESTAMP();
        v_approval_date := NEW.approved_at::DATE;
        v_first_payment_date := calculate_first_payment_date(v_approval_date);
        
        -- ===================================================================
        -- CASO ESPECIAL: LEGACY - Usar tabla estática
        -- ===================================================================
        IF NEW.profile_code = 'legacy' THEN
            RAISE NOTICE '🔵 LEGACY: Usando legacy_payment_table para préstamo % ($%, 12Q)', 
                NEW.id, NEW.amount;
            
            SELECT 
                biweekly_payment,
                associate_biweekly_payment,
                total_payment,
                total_commission
            INTO v_legacy_data
            FROM legacy_payment_table
            WHERE amount = NEW.amount AND term_biweeks = 12
            LIMIT 1;
            
            IF v_legacy_data IS NULL THEN
                RAISE EXCEPTION 'No se encontró configuración legacy para monto $% con 12 quincenas', NEW.amount;
            END IF;
            
            v_current_payment_date := v_first_payment_date;
            v_is_day_15 := (EXTRACT(DAY FROM v_current_payment_date) = 15);
            
            FOR v_period_counter IN 1..12 LOOP
                -- ✅ NUEVA LÓGICA: Asignar periodo con cierre ANTES del vencimiento
                v_period_id := get_cut_period_for_payment(v_current_payment_date);
                
                INSERT INTO payments (
                    loan_id, payment_number, expected_amount, amount_paid,
                    interest_amount, principal_amount, 
                    commission_amount, associate_payment,
                    balance_remaining, payment_date, payment_due_date, 
                    is_late, status_id, cut_period_id, created_at, updated_at
                ) VALUES (
                    NEW.id,
                    v_period_counter,
                    v_legacy_data.biweekly_payment,
                    0.00,
                    NULL,
                    NULL,
                    v_legacy_data.biweekly_payment - v_legacy_data.associate_biweekly_payment,
                    v_legacy_data.associate_biweekly_payment,
                    NULL,
                    v_current_payment_date,
                    v_current_payment_date,
                    false,
                    v_pending_status_id,
                    v_period_id,
                    CURRENT_TIMESTAMP,
                    CURRENT_TIMESTAMP
                );
                
                v_total_inserted := v_total_inserted + 1;
                v_sum_expected := v_sum_expected + v_legacy_data.biweekly_payment;
                
                -- Calcular siguiente fecha (alternancia 15 ↔ último día)
                IF v_is_day_15 THEN
                    v_current_payment_date := (DATE_TRUNC('month', v_current_payment_date) + INTERVAL '1 month' - INTERVAL '1 day')::DATE;
                    v_is_day_15 := false;
                ELSE
                    v_current_payment_date := (DATE_TRUNC('month', v_current_payment_date) + INTERVAL '1 month' + INTERVAL '14 days')::DATE;
                    v_is_day_15 := true;
                END IF;
            END LOOP;
            
            RAISE NOTICE '✅ LEGACY: % pagos insertados. Total: $%', v_total_inserted, v_sum_expected;
            
        -- ===================================================================
        -- CASO NORMAL: Standard/Custom - Calcular con fórmula
        -- ===================================================================
        ELSE
            FOR v_amortization_row IN
                SELECT * FROM generate_amortization_schedule(
                    NEW.amount, NEW.biweekly_payment, NEW.term_biweeks, 
                    COALESCE(NEW.commission_rate, 0), v_first_payment_date)
            LOOP
                -- ✅ NUEVA LÓGICA: Asignar periodo con cierre ANTES del vencimiento
                v_period_id := get_cut_period_for_payment(v_amortization_row.fecha_pago);
                
                INSERT INTO payments (
                    loan_id, payment_number, expected_amount, amount_paid,
                    interest_amount, principal_amount, commission_amount, associate_payment,
                    balance_remaining, payment_date, payment_due_date, is_late,
                    status_id, cut_period_id, created_at, updated_at
                ) VALUES (
                    NEW.id, v_amortization_row.periodo, v_amortization_row.pago_cliente, 0.00,
                    v_amortization_row.interes_cliente, v_amortization_row.capital_cliente,
                    v_amortization_row.comision_socio, v_amortization_row.pago_socio,
                    v_amortization_row.saldo_pendiente, v_amortization_row.fecha_pago,
                    v_amortization_row.fecha_pago, false, v_pending_status_id, v_period_id,
                    CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
                );
                
                v_total_inserted := v_total_inserted + 1;
                v_sum_expected := v_sum_expected + v_amortization_row.pago_cliente;
            END LOOP;
        END IF;
        
        v_end_time := CLOCK_TIMESTAMP();
        RAISE NOTICE '✅ Schedule completado: % pagos, Total: $%, Tiempo: %ms',
            v_total_inserted, v_sum_expected,
            EXTRACT(MILLISECONDS FROM (v_end_time - v_start_time));
    END IF;
    
    RETURN NEW;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'ERROR al generar payment schedule para préstamo %: % (SQLState: %)',
            NEW.id, SQLERRM, SQLSTATE;
        RETURN NULL;
END;
$function$;

COMMENT ON FUNCTION generate_payment_schedule() IS 
'⭐ CRÍTICA: Trigger que genera automáticamente el cronograma completo de pagos quincenales cuando un préstamo es aprobado. 
✅ VERSIÓN MIGRACIÓN 021 (2025-11-26): Corregida asignación de periodos - los pagos salen en el statement del corte ANTERIOR al vencimiento.';

-- =============================================================================
-- FIN MIGRACIÓN 021
-- =============================================================================
