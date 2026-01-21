-- =============================================================================
-- Migration 026: Calcular balance_remaining en préstamos LEGACY
-- =============================================================================
-- Fecha: 2024-11-26
-- Descripción:
--   PROBLEMA:
--   - Préstamos legacy insertan NULL en balance_remaining, principal_amount, interest_amount
--   - Frontend muestra $0.00 en tabla de amortización
--
--   SOLUCIÓN:
--   - Calcular balance decreciente basado en pagos a capital
--   - Calcular principal e interés desde expected_amount y commission
--   - Actualizar trigger para futuros préstamos legacy
--   - Recalcular préstamos legacy existentes
--
-- Impacto:
--   - ✅ Corrige visualización de saldo en frontend
--   - ✅ Permite tracking correcto de deuda pendiente
--   - ✅ Alinea legacy con standard/custom
-- =============================================================================

BEGIN;

-- =============================================================================
-- PASO 1: Actualizar trigger para FUTUROS préstamos legacy
-- =============================================================================

CREATE OR REPLACE FUNCTION generate_payment_schedule()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_period_id INTEGER;
    v_pending_status_id INTEGER;
    v_first_payment_date DATE;
    v_approval_date DATE;
    v_current_payment_date DATE;
    v_is_day_15 BOOLEAN;
    v_period_counter INTEGER;
    v_total_inserted INTEGER := 0;
    v_sum_expected DECIMAL(12,2) := 0;
    
    -- Variables para LEGACY
    v_legacy_data RECORD;
    v_current_balance DECIMAL(12,2);
    v_payment_to_principal DECIMAL(12,2);
    v_payment_interest DECIMAL(12,2);
    
    -- Variables para STANDARD/CUSTOM
    v_amortization_row RECORD;
BEGIN
    IF TG_OP != 'UPDATE' OR OLD.status_id = NEW.status_id THEN
        RETURN NEW;
    END IF;
    
    IF NEW.status_id != (SELECT id FROM loan_statuses WHERE name = 'APPROVED' LIMIT 1) THEN
        RETURN NEW;
    END IF;
    
    SELECT id INTO v_pending_status_id 
    FROM payment_statuses 
    WHERE name = 'PENDING' 
    LIMIT 1;
    
    IF v_pending_status_id IS NULL THEN
        RAISE EXCEPTION 'Estado de pago PENDING no encontrado';
    END IF;
    
    v_approval_date := NEW.approved_at::DATE;
    v_first_payment_date := calculate_first_payment_date(v_approval_date);
    
    -- =========================================================================
    -- CASO ESPECIAL: LEGACY - Usar tabla estática CON BALANCE CALCULADO
    -- =========================================================================
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
        
        -- ✅ INICIALIZAR BALANCE
        v_current_balance := NEW.amount;
        v_payment_to_principal := NEW.amount / 12.0;  -- Capital distribuido uniformemente
        
        -- ✅ CALCULAR INTERÉS para cumplir constraint
        -- Constraint: expected_amount = interest + principal (±0.10)
        -- Entonces: interest = expected_amount - principal
        v_payment_interest := v_legacy_data.biweekly_payment - v_payment_to_principal;
        
        v_current_payment_date := v_first_payment_date;
        v_is_day_15 := (EXTRACT(DAY FROM v_current_payment_date) = 15);
        
        FOR v_period_counter IN 1..12 LOOP
            v_period_id := get_cut_period_for_payment(v_current_payment_date);
            
            -- ✅ CALCULAR BALANCE RESTANTE
            v_current_balance := v_current_balance - v_payment_to_principal;
            IF v_current_balance < 0.01 THEN
                v_current_balance := 0;
            END IF;
            
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
                v_payment_interest,  -- ✅ CALCULADO
                v_payment_to_principal,  -- ✅ CALCULADO
                v_legacy_data.biweekly_payment - v_legacy_data.associate_biweekly_payment,
                v_legacy_data.associate_biweekly_payment,
                v_current_balance,  -- ✅ CALCULADO
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
        
    -- =========================================================================
    -- CASO NORMAL: Standard/Custom - Calcular con fórmula (sin cambios)
    -- =========================================================================
    ELSE
        FOR v_amortization_row IN
            SELECT * FROM generate_amortization_schedule(
                NEW.amount, NEW.biweekly_payment, NEW.term_biweeks, 
                COALESCE(NEW.commission_rate, 0), v_first_payment_date)
        LOOP
            v_period_id := get_cut_period_for_payment(v_amortization_row.fecha_pago);
            
            INSERT INTO payments (
                loan_id, payment_number, expected_amount, amount_paid,
                interest_amount, principal_amount, commission_amount, associate_payment,
                balance_remaining, payment_date, payment_due_date, is_late,
                status_id, cut_period_id, created_at, updated_at
            ) VALUES (
                NEW.id, v_amortization_row.periodo, v_amortization_row.pago_cliente, 0.00,
                v_amortization_row.interes_cliente, v_amortization_row.capital_cliente,
                v_amortization_row.comision, v_amortization_row.pago_asociado,
                v_amortization_row.saldo_restante, v_amortization_row.fecha_pago,
                v_amortization_row.fecha_pago, false, v_pending_status_id, v_period_id,
                CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
            );
            
            v_total_inserted := v_total_inserted + 1;
            v_sum_expected := v_sum_expected + v_amortization_row.pago_cliente;
        END LOOP;
        
        RAISE NOTICE '✅ STANDARD/CUSTOM: % pagos insertados. Total: $%', v_total_inserted, v_sum_expected;
    END IF;
    
    IF v_total_inserted = 0 THEN
        RAISE WARNING 'No se insertaron pagos para préstamo %', NEW.id;
    END IF;
    
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION generate_payment_schedule() IS 
'✅ ACTUALIZADO (2024-11-26): Genera schedule de pagos al aprobar préstamo.
LEGACY: Calcula balance_remaining, principal_amount e interest_amount correctamente.
STANDARD/CUSTOM: Sin cambios, usa generate_amortization_schedule().';

-- =============================================================================
-- PASO 2: Recalcular pagos de préstamos LEGACY existentes
-- =============================================================================

DO $$
DECLARE
    v_loan RECORD;
    v_legacy_data RECORD;
    v_payment RECORD;
    v_current_balance DECIMAL(12,2);
    v_payment_to_principal DECIMAL(12,2);
    v_payment_interest DECIMAL(12,2);
    v_updated_count INTEGER := 0;
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'RECALCULANDO PAGOS LEGACY EXISTENTES';
    RAISE NOTICE '========================================';
    
    -- Iterar sobre préstamos legacy aprobados
    FOR v_loan IN 
        SELECT id, amount 
        FROM loans 
        WHERE profile_code = 'legacy' 
          AND status_id = (SELECT id FROM loan_statuses WHERE name = 'APPROVED')
        ORDER BY id
    LOOP
        -- Obtener datos de la tabla legacy
        SELECT 
            biweekly_payment,
            associate_biweekly_payment
        INTO v_legacy_data
        FROM legacy_payment_table
        WHERE amount = v_loan.amount AND term_biweeks = 12
        LIMIT 1;
        
        IF v_legacy_data IS NULL THEN
            RAISE WARNING 'No se encontró configuración legacy para préstamo % ($%)', v_loan.id, v_loan.amount;
            CONTINUE;
        END IF;
        
        -- Inicializar balance
        v_current_balance := v_loan.amount;
        v_payment_to_principal := v_loan.amount / 12.0;
        
        -- Calcular interés para cumplir constraint
        -- Constraint: expected_amount = interest + principal
        -- Entonces: interest = expected_amount - principal
        v_payment_interest := v_legacy_data.biweekly_payment - v_payment_to_principal;
        
        -- Actualizar cada pago del préstamo
        FOR v_payment IN 
            SELECT id, payment_number 
            FROM payments 
            WHERE loan_id = v_loan.id 
            ORDER BY payment_number
        LOOP
            -- Calcular balance restante
            v_current_balance := v_current_balance - v_payment_to_principal;
            IF v_current_balance < 0.01 THEN
                v_current_balance := 0;
            END IF;
            
            -- Actualizar pago
            UPDATE payments
            SET 
                interest_amount = v_payment_interest,
                principal_amount = v_payment_to_principal,
                balance_remaining = v_current_balance,
                updated_at = CURRENT_TIMESTAMP
            WHERE id = v_payment.id;
            
            v_updated_count := v_updated_count + 1;
        END LOOP;
        
        RAISE NOTICE '✅ Préstamo % ($%): 12 pagos actualizados', v_loan.id, v_loan.amount;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'TOTAL PAGOS ACTUALIZADOS: %', v_updated_count;
    RAISE NOTICE '========================================';
END $$;

COMMIT;

-- =============================================================================
-- VALIDACIÓN FINAL
-- =============================================================================
-- SELECT 
--     l.id as loan_id,
--     l.amount,
--     p.payment_number,
--     p.expected_amount,
--     p.principal_amount,
--     p.interest_amount,
--     p.commission_amount,
--     p.balance_remaining
-- FROM loans l
-- JOIN payments p ON p.loan_id = l.id
-- WHERE l.profile_code = 'legacy'
--   AND l.id = (SELECT MAX(id) FROM loans WHERE profile_code = 'legacy')
-- ORDER BY p.payment_number;
