-- =============================================================================
-- Migration 023: Corregir asignación de periodos en simulate_loan()
-- =============================================================================
-- Fecha: 2024-11-26
-- Descripción:
--   La función simulate_loan() usaba lógica de CONTENCIÓN (WHERE payment_date 
--   BETWEEN period_start AND period_end) que asignaba pagos al periodo que
--   CONTIENE la fecha de pago.
--
--   PROBLEMA:
--   - Pago 15/dic caía en periodo Dec08-2025 to Dec22-2025 → asignaba Dec22-2025 ❌
--   - Pero DEBE asignarse al periodo que CIERRA ANTES del 15/dic → Dec07-2025 ✅
--
--   SOLUCIÓN:
--   - Usar get_cut_period_for_payment() igual que el trigger real
--   - Garantiza que simulación y préstamo aprobado muestren mismos periodos
--
-- Validación:
--   SELECT payment_number, payment_date, cut_period_code 
--   FROM simulate_loan(5000, 12, 'standard')
--   WHERE payment_number <= 2;
--   
--   Debe mostrar:
--   - Payment 1 (15/dic) → Dec07-YYYY (no Dec22-YYYY)
--   - Payment 2 (31/dic) → Dec22-YYYY ✅
-- =============================================================================

CREATE OR REPLACE FUNCTION simulate_loan(
    p_amount NUMERIC,
    p_term_biweeks INTEGER,
    p_profile_code VARCHAR,
    p_approval_date DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE(
    payment_number INTEGER,
    payment_date DATE,
    cut_period_code VARCHAR(20),
    client_payment NUMERIC(10,2),
    associate_payment NUMERIC(10,2),
    commission_amount NUMERIC(10,2),
    remaining_balance NUMERIC(12,2)
)
LANGUAGE plpgsql
STABLE
AS $function$
DECLARE
    v_calc RECORD;
    v_current_date DATE;
    v_balance DECIMAL(12,2);
    v_cut_code VARCHAR(20);
    v_period_capital DECIMAL(12,2);
    v_period_id INTEGER;
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
        -- ✅ CORRECCIÓN: Usar la misma función que el trigger real
        -- Esto garantiza que la simulación muestre los mismos periodos
        -- que el préstamo aprobado (no más discrepancias)
        v_period_id := get_cut_period_for_payment(v_current_date);
        
        -- Obtener el cut_code del periodo asignado
        IF v_period_id IS NOT NULL THEN
            SELECT cut_code INTO v_cut_code
            FROM cut_periods
            WHERE id = v_period_id;
        ELSE
            -- Fallback: Si no encuentra período (simulación muy futura)
            v_cut_code := EXTRACT(YEAR FROM v_current_date)::TEXT || '-Q' ||
                LPAD(CEIL(EXTRACT(DOY FROM v_current_date) / 15)::TEXT, 2, '0');
        END IF;
        
        -- Calcular saldo restante
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
        
        -- Calcular siguiente fecha (alternancia 15 ↔ último día)
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
    
    RETURN;
END;
$function$;

COMMENT ON FUNCTION simulate_loan(NUMERIC, INTEGER, VARCHAR, DATE) IS 
'✅ ACTUALIZADO (2024-11-26): Simula tabla de amortización usando get_cut_period_for_payment() para asignación correcta de periodos.
Garantiza que la simulación (antes de aprobar) muestre los mismos periodos que el préstamo aprobado (después de aprobar).
Pagos día 15 → periodos que cierran ~día 07. Pagos último día → periodos que cierran ~día 22.';

-- =============================================================================
-- Validación final
-- =============================================================================
DO $$
DECLARE
    v_result RECORD;
BEGIN
    -- Verificar que pago del 15 va a periodo Dec07 (no Dec22)
    SELECT * INTO v_result
    FROM simulate_loan(5000, 12, 'standard', CURRENT_DATE)
    WHERE payment_number = 1;
    
    IF v_result.cut_period_code NOT LIKE '%07-%' THEN
        RAISE WARNING 'POSIBLE ERROR: Pago del día 15 asignado a periodo %, esperado periodo que cierra día 07', 
            v_result.cut_period_code;
    ELSE
        RAISE NOTICE '✅ Validación OK: Pago día 15 correctamente asignado a periodo %', 
            v_result.cut_period_code;
    END IF;
END $$;
