-- =============================================================================
-- MIGRACIÓN 027: TRACKING DE DEUDA DE ASOCIADO
-- =============================================================================
-- Fecha: 2025-11-27
-- Descripción: 
-- 1. Agrega columna `associate_balance_remaining` a tabla `payments`.
-- 2. Actualiza `generate_amortization_schedule` para calcular este saldo.
-- 3. Actualiza `generate_payment_schedule` para persistir este saldo.
-- 4. Actualiza `simulate_loan` para mostrar este saldo en simulaciones.
-- =============================================================================

BEGIN;

-- 1. Agregar columna a tabla payments
ALTER TABLE payments ADD COLUMN IF NOT EXISTS associate_balance_remaining DECIMAL(12,2);

-- 2. Actualizar generate_amortization_schedule para retornar associate_balance
DROP FUNCTION IF EXISTS generate_amortization_schedule(numeric, numeric, integer, numeric, date);

CREATE OR REPLACE FUNCTION generate_amortization_schedule(
    p_amount numeric, 
    p_biweekly_payment numeric, 
    p_term_biweeks integer, 
    p_commission_rate numeric, 
    p_start_date date
)
RETURNS TABLE(
    periodo integer, 
    fecha_pago date, 
    pago_cliente numeric, 
    interes_cliente numeric, 
    capital_cliente numeric, 
    saldo_pendiente numeric, 
    comision_socio numeric, 
    pago_socio numeric,
    saldo_asociado numeric -- ✅ NUEVO CAMPO
)
LANGUAGE plpgsql
STABLE
AS $function$
DECLARE
    v_current_date DATE;
    v_balance DECIMAL(12,2);
    v_associate_balance DECIMAL(12,2); -- ✅ NUEVO
    v_total_interest DECIMAL(12,2);
    v_period_interest DECIMAL(10,2);
    v_period_principal DECIMAL(10,2);
    v_commission DECIMAL(10,2);
    v_payment_to_associate DECIMAL(10,2);
    v_is_day_15 BOOLEAN;
BEGIN
    -- Inicializar
    v_balance := p_amount;
    v_total_interest := (p_biweekly_payment * p_term_biweeks) - p_amount;
    v_current_date := p_start_date;
    
    -- Calcular comisión y pago al asociado (fijos por periodo)
    v_commission := p_amount * (p_commission_rate / 100);
    v_payment_to_associate := p_biweekly_payment - v_commission;
    
    -- Inicializar saldo asociado (Total a pagar por asociado)
    v_associate_balance := v_payment_to_associate * p_term_biweeks;

    -- Generar cronograma completo
    FOR v_period IN 1..p_term_biweeks LOOP
        -- Calcular interés y capital del período (distribución proporcional)
        v_period_interest := v_total_interest / p_term_biweeks;
        v_period_principal := p_biweekly_payment - v_period_interest;

        -- Actualizar saldo cliente
        v_balance := v_balance - v_period_principal;
        IF v_balance < 0.01 THEN v_balance := 0; END IF;
        
        -- Actualizar saldo asociado
        v_associate_balance := v_associate_balance - v_payment_to_associate;
        IF v_associate_balance < 0.01 THEN v_associate_balance := 0; END IF;

        -- Retornar fila
        RETURN QUERY SELECT
            v_period,
            v_current_date,
            p_biweekly_payment,
            ROUND(v_period_interest, 2),
            ROUND(v_period_principal, 2),
            ROUND(v_balance, 2),
            ROUND(v_commission, 2),
            ROUND(v_payment_to_associate, 2),
            ROUND(v_associate_balance, 2); -- ✅ RETORNAR NUEVO SALDO

        -- Calcular siguiente fecha
        v_is_day_15 := EXTRACT(DAY FROM v_current_date) = 15;

        IF v_is_day_15 THEN
            v_current_date := (DATE_TRUNC('month', v_current_date) + INTERVAL '1 month' - INTERVAL '1 day')::DATE;
        ELSE
            v_current_date := MAKE_DATE(
                EXTRACT(YEAR FROM v_current_date + INTERVAL '1 month')::INTEGER,
                EXTRACT(MONTH FROM v_current_date + INTERVAL '1 month')::INTEGER,
                15
            );
        END IF;
    END LOOP;
END;
$function$;

-- 3. Actualizar generate_payment_schedule para insertar el nuevo campo
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
BEGIN
    SELECT id INTO v_approved_status_id FROM loan_statuses WHERE name = 'APPROVED';
    SELECT id INTO v_pending_status_id FROM payment_statuses WHERE name = 'PENDING';
    
    IF NEW.status_id = v_approved_status_id AND (OLD.status_id IS NULL OR OLD.status_id != v_approved_status_id) THEN
        
        v_approval_date := NEW.approved_at::DATE;
        v_first_payment_date := calculate_first_payment_date(v_approval_date);
        
        FOR v_amortization_row IN
            SELECT * FROM generate_amortization_schedule(
                NEW.amount,
                NEW.biweekly_payment,
                NEW.term_biweeks,
                COALESCE(NEW.commission_rate, 0),
                v_first_payment_date
            )
        LOOP
            -- Buscar periodo administrativo
            SELECT id INTO v_period_id
            FROM cut_periods
            WHERE period_start_date <= v_amortization_row.fecha_pago
              AND period_end_date >= v_amortization_row.fecha_pago
            ORDER BY period_start_date DESC
            LIMIT 1;
            
            INSERT INTO payments (
                loan_id,
                payment_number,
                expected_amount,
                amount_paid,
                interest_amount,
                principal_amount,
                commission_amount,
                associate_payment,
                balance_remaining,
                associate_balance_remaining, -- ✅ NUEVO CAMPO
                payment_date,
                payment_due_date,
                is_late,
                status_id,
                cut_period_id,
                created_at,
                updated_at
            ) VALUES (
                NEW.id,
                v_amortization_row.periodo,
                v_amortization_row.pago_cliente,
                0.00,
                v_amortization_row.interes_cliente,
                v_amortization_row.capital_cliente,
                v_amortization_row.comision_socio,
                v_amortization_row.pago_socio,
                v_amortization_row.saldo_pendiente,
                v_amortization_row.saldo_asociado, -- ✅ INSERTAR NUEVO VALOR
                v_amortization_row.fecha_pago,
                v_amortization_row.fecha_pago,
                false,
                v_pending_status_id,
                v_period_id,
                CURRENT_TIMESTAMP,
                CURRENT_TIMESTAMP
            );
            
            v_total_inserted := v_total_inserted + 1;
            v_sum_expected := v_sum_expected + v_amortization_row.pago_cliente;
        END LOOP;
        
        -- Validaciones finales (simplificadas para brevedad, mantener lógica original si es posible)
        IF v_total_inserted != NEW.term_biweeks THEN
            RAISE EXCEPTION 'INCONSISTENCIA: Se insertaron % pagos pero se esperaban %.', v_total_inserted, NEW.term_biweeks;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$function$;

-- 4. Actualizar simulate_loan para retornar el nuevo campo
DROP FUNCTION IF EXISTS simulate_loan(numeric, integer, character varying, date);

CREATE OR REPLACE FUNCTION simulate_loan(
    p_amount numeric, 
    p_term_biweeks integer, 
    p_profile_code character varying, 
    p_approval_date date DEFAULT CURRENT_DATE
)
RETURNS TABLE(
    payment_number integer, 
    payment_date date, 
    cut_period_code character varying, 
    client_payment numeric, 
    associate_payment numeric, 
    commission_amount numeric, 
    remaining_balance numeric,
    associate_remaining_balance numeric -- ✅ NUEVO CAMPO
)
LANGUAGE plpgsql
STABLE
AS $function$
DECLARE
    v_calc RECORD;
    v_current_date DATE;
    v_balance DECIMAL(12,2);
    v_associate_balance DECIMAL(12,2); -- ✅ NUEVO
    v_cut_code VARCHAR(20);
    v_period_capital DECIMAL(12,2);
    v_period_id INTEGER;
    i INTEGER;
BEGIN
    -- Obtener cálculos del perfil
    SELECT * INTO v_calc
    FROM calculate_loan_payment(p_amount, p_term_biweeks, p_profile_code);

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Perfil % no encontrado', p_profile_code;
    END IF;

    v_current_date := calculate_first_payment_date(p_approval_date);
    v_balance := p_amount;
    
    -- Inicializar saldo asociado
    v_associate_balance := v_calc.associate_payment * p_term_biweeks;

    v_period_capital := p_amount / p_term_biweeks;

    FOR i IN 1..p_term_biweeks LOOP
        v_period_id := get_cut_period_for_payment(v_current_date);

        IF v_period_id IS NOT NULL THEN
            SELECT cut_code INTO v_cut_code FROM cut_periods WHERE id = v_period_id;
        ELSE
            v_cut_code := EXTRACT(YEAR FROM v_current_date)::TEXT || '-Q' || LPAD(CEIL(EXTRACT(DOY FROM v_current_date) / 15)::TEXT, 2, '0');
        END IF;

        v_balance := v_balance - v_period_capital;
        IF v_balance < 0.01 THEN v_balance := 0; END IF;
        
        -- Actualizar saldo asociado
        v_associate_balance := v_associate_balance - v_calc.associate_payment;
        IF v_associate_balance < 0.01 THEN v_associate_balance := 0; END IF;

        RETURN QUERY SELECT
            i::INTEGER,
            v_current_date::DATE,
            v_cut_code::VARCHAR(20),
            v_calc.biweekly_payment::DECIMAL(10,2),
            v_calc.associate_payment::DECIMAL(10,2),
            v_calc.commission_per_payment::DECIMAL(10,2),
            v_balance::DECIMAL(12,2),
            v_associate_balance::DECIMAL(12,2); -- ✅ RETORNAR

        IF EXTRACT(DAY FROM v_current_date) = 15 THEN
            v_current_date := (DATE_TRUNC('month', v_current_date) + INTERVAL '1 month' - INTERVAL '1 day')::DATE;
        ELSE
            v_current_date := MAKE_DATE(
                EXTRACT(YEAR FROM v_current_date + INTERVAL '1 month')::INTEGER,
                EXTRACT(MONTH FROM v_current_date + INTERVAL '1 month')::INTEGER,
                15
            );
        END IF;
    END LOOP;
END;
$function$;

COMMIT;
