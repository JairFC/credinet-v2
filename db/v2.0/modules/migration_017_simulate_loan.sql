-- =============================================================================
-- MIGRACIÓN 017: Función simulate_loan para simulador de préstamos
-- =============================================================================

CREATE OR REPLACE FUNCTION simulate_loan(
    p_amount DECIMAL(12,2),
    p_term_biweeks INTEGER,
    p_profile_code VARCHAR(50),
    p_approval_date DATE DEFAULT CURRENT_DATE
) RETURNS TABLE (
    payment_number INTEGER,
    payment_date DATE,
    cut_period_code VARCHAR(20),
    client_payment DECIMAL(10,2),
    associate_payment DECIMAL(10,2),
    commission_amount DECIMAL(10,2),
    remaining_balance DECIMAL(12,2)
) AS $$
DECLARE
    v_calc RECORD;
    v_current_date DATE;
    v_balance DECIMAL(12,2);
    v_cut_code VARCHAR(20);
    i INTEGER;
BEGIN
    -- Obtener cálculos del perfil
    SELECT * INTO v_calc
    FROM calculate_loan_payment(p_amount, p_term_biweeks, p_profile_code);
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Perfil % no encontrado o deshabilitado', p_profile_code;
    END IF;
    
    -- Calcular primera fecha de pago usando el oráculo
    v_current_date := calculate_first_payment_date(p_approval_date);
    v_balance := p_amount;
    
    -- Generar tabla de amortización
    FOR i IN 1..p_term_biweeks LOOP
        -- Determinar código de corte según regla del calendario
        IF EXTRACT(DAY FROM v_current_date) <= 8 THEN
            v_cut_code := 'CORTE_8_' || EXTRACT(MONTH FROM v_current_date)::TEXT;
        ELSE
            v_cut_code := 'CORTE_23_' || EXTRACT(MONTH FROM v_current_date)::TEXT;
        END IF;
        
        -- Calcular saldo restante (se va reduciendo el capital)
        v_balance := p_amount - (v_calc.biweekly_payment - (p_amount * v_calc.interest_rate_percent / 100)) * i;
        IF v_balance < 0 THEN
            v_balance := 0;
        END IF;
        
        RETURN QUERY SELECT
            i,
            v_current_date,
            v_cut_code,
            v_calc.biweekly_payment,
            v_calc.associate_payment,
            v_calc.commission_per_payment,
            v_balance;
        
        -- Calcular siguiente fecha: alternar entre día 15 y último día del mes
        IF EXTRACT(DAY FROM v_current_date) = 15 THEN
            -- Si estamos en día 15, siguiente pago es el último día del mes
            v_current_date := (DATE_TRUNC('month', v_current_date) + INTERVAL '1 month' - INTERVAL '1 day')::DATE;
        ELSE
            -- Si estamos en último día, siguiente pago es el 15 del siguiente mes
            v_current_date := MAKE_DATE(
                EXTRACT(YEAR FROM v_current_date + INTERVAL '1 month')::INTEGER,
                EXTRACT(MONTH FROM v_current_date + INTERVAL '1 month')::INTEGER,
                15
            );
        END IF;
    END LOOP;
    
    RETURN;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION simulate_loan IS 
'Genera tabla de amortización completa para simulación de préstamos.
Calcula fechas de pago cada 15 días, asigna períodos de corte, y muestra desglose por pago.
Uso: SELECT * FROM simulate_loan(10000, 12, ''standard'', ''2025-01-15'');';
