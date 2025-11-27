-- =============================================================================
-- MIGRACIÓN 018: Corrección de simulate_loan para usar períodos reales
-- =============================================================================
-- Problema: simulate_loan genera códigos de corte ficticios (CORTE_23_11)
-- Solución: Consultar cut_periods y asignar el período real donde cae el pago
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
    v_period_capital DECIMAL(12,2);
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
    
    -- Calcular abono a capital por periodo (interés distribuido uniformemente)
    v_period_capital := p_amount / p_term_biweeks;
    
    -- Generar tabla de amortización
    FOR i IN 1..p_term_biweeks LOOP
        -- ⭐ CORRECCIÓN CRÍTICA: Buscar período de corte REAL donde cae el pago
        -- Un pago pertenece al período donde payment_date está entre start y end
        SELECT cp.cut_code INTO v_cut_code
        FROM cut_periods cp
        WHERE v_current_date >= cp.period_start_date 
          AND v_current_date <= cp.period_end_date
        LIMIT 1;
        
        -- Si no encuentra período (ej: simulación muy futura), usar código genérico
        IF v_cut_code IS NULL THEN
            -- Formato: YYYY-QXX (año-número quincenal)
            v_cut_code := EXTRACT(YEAR FROM v_current_date)::TEXT || '-Q' || 
                LPAD(CEIL(EXTRACT(DOY FROM v_current_date) / 15)::TEXT, 2, '0');
        END IF;
        
        -- Calcular saldo restante (disminuye por el abono a capital)
        v_balance := v_balance - v_period_capital;
        IF v_balance < 0.01 THEN
            v_balance := 0;
        END IF;
        
        -- Retornar fila de la tabla de amortización
        RETURN QUERY SELECT
            i::INTEGER,
            v_current_date::DATE,
            v_cut_code::VARCHAR(20),
            v_calc.biweekly_payment::DECIMAL(10,2),
            v_calc.associate_payment::DECIMAL(10,2),
            v_calc.commission_per_payment::DECIMAL(10,2),
            v_balance::DECIMAL(12,2);
        
        -- ⭐ LÓGICA DEL CALENDARIO: Alternar entre día 15 y último día del mes
        IF EXTRACT(DAY FROM v_current_date) = 15 THEN
            -- Si estamos en día 15, siguiente pago es el último día del mes ACTUAL
            v_current_date := (DATE_TRUNC('month', v_current_date) + INTERVAL '1 month' - INTERVAL '1 day')::DATE;
        ELSE
            -- Si estamos en último día, siguiente pago es el 15 del mes SIGUIENTE
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
'✅ CORREGIDO: Genera tabla de amortización con períodos de corte REALES.
Calcula fechas de pago alternando entre día 15 y último del mes.
Asigna cada pago al cut_period donde payment_date cae entre period_start_date y period_end_date.
Uso: SELECT * FROM simulate_loan(10000, 12, ''standard'', ''2025-11-14'');';

-- =============================================================================
-- VERIFICACIÓN DE LA CORRECCIÓN
-- =============================================================================

-- Test 1: Verificar que use períodos reales
DO $$
DECLARE
    v_result RECORD;
    v_expected_codes TEXT[] := ARRAY['2025-Q22', '2025-Q23', '2025-Q24'];
    v_actual_code TEXT;
    v_test_passed BOOLEAN := TRUE;
BEGIN
    RAISE NOTICE '=== TEST: simulate_loan con períodos reales ===';
    
    -- Obtener primeros 3 pagos
    FOR v_result IN 
        SELECT payment_number, payment_date, cut_period_code 
        FROM simulate_loan(30000, 12, 'legacy', '2025-11-14'::DATE)
        LIMIT 3
    LOOP
        RAISE NOTICE 'Pago %: Fecha %, Período %', 
            v_result.payment_number, 
            v_result.payment_date, 
            v_result.cut_period_code;
        
        -- Verificar que el código existe en cut_periods
        SELECT cut_code INTO v_actual_code
        FROM cut_periods
        WHERE cut_code = v_result.cut_period_code;
        
        IF v_actual_code IS NULL THEN
            RAISE WARNING '⚠️ Código de período % NO existe en cut_periods', v_result.cut_period_code;
            v_test_passed := FALSE;
        END IF;
    END LOOP;
    
    IF v_test_passed THEN
        RAISE NOTICE '✅ Test PASADO: Todos los períodos existen en la BD';
    ELSE
        RAISE WARNING '❌ Test FALLIDO: Algunos períodos no existen';
    END IF;
END $$;
