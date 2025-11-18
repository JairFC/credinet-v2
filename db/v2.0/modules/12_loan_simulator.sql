-- =============================================================================
-- SIMULADOR DE PRÉSTAMOS - Tabla de Amortización Completa
-- =============================================================================

-- =============================================================================
-- FUNCIÓN: simulate_loan_complete - Simulador con Resumen + Amortización
-- =============================================================================
CREATE OR REPLACE FUNCTION simulate_loan_complete(
    p_amount DECIMAL(12,2),
    p_term_biweeks INTEGER,
    p_profile_code VARCHAR(50),
    p_approval_date DATE DEFAULT CURRENT_DATE
) RETURNS TABLE (
    -- SECCIÓN: Resumen del Préstamo
    section_type VARCHAR(20),
    label VARCHAR(100),
    value_text VARCHAR(100),
    value_numeric DECIMAL(12,2),
    
    -- SECCIÓN: Tabla de Amortización
    payment_num INTEGER,
    payment_date DATE,
    cut_code VARCHAR(20),
    client_pay DECIMAL(10,2),
    associate_pay DECIMAL(10,2),
    commission DECIMAL(10,2),
    balance DECIMAL(12,2)
) AS $$
DECLARE
    v_calc RECORD;
    v_profile RECORD;
BEGIN
    -- Obtener información del perfil y cálculos
    SELECT 
        rp.name as profile_name,
        c.*
    INTO v_calc
    FROM calculate_loan_payment(p_amount, p_term_biweeks, p_profile_code) c
    JOIN rate_profiles rp ON rp.code = p_profile_code;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Perfil % no encontrado o deshabilitado', p_profile_code;
    END IF;
    
    -- =========================================================================
    -- SECCIÓN 1: RESUMEN DEL PRÉSTAMO
    -- =========================================================================
    RETURN QUERY SELECT
        'RESUMEN'::VARCHAR(20),
        'Perfil'::VARCHAR(100),
        v_calc.profile_name::VARCHAR(100),
        NULL::DECIMAL(12,2),
        NULL::INTEGER, NULL::DATE, NULL::VARCHAR(20),
        NULL::DECIMAL(10,2), NULL::DECIMAL(10,2), NULL::DECIMAL(10,2), NULL::DECIMAL(12,2);
    
    RETURN QUERY SELECT
        'RESUMEN'::VARCHAR(20), 'Monto Solicitado'::VARCHAR(100),
        ('$' || p_amount::TEXT)::VARCHAR(100), p_amount,
        NULL::INTEGER, NULL::DATE, NULL::VARCHAR(20),
        NULL::DECIMAL(10,2), NULL::DECIMAL(10,2), NULL::DECIMAL(10,2), NULL::DECIMAL(12,2);
    
    RETURN QUERY SELECT
        'RESUMEN'::VARCHAR(20), 'Plazo'::VARCHAR(100),
        (p_term_biweeks || ' quincenas')::VARCHAR(100), p_term_biweeks::DECIMAL(12,2),
        NULL::INTEGER, NULL::DATE, NULL::VARCHAR(20),
        NULL::DECIMAL(10,2), NULL::DECIMAL(10,2), NULL::DECIMAL(10,2), NULL::DECIMAL(12,2);
    
    RETURN QUERY SELECT
        'RESUMEN'::VARCHAR(20), 'Tasa de Interés'::VARCHAR(100),
        (v_calc.interest_rate_percent || '%')::VARCHAR(100), v_calc.interest_rate_percent,
        NULL::INTEGER, NULL::DATE, NULL::VARCHAR(20),
        NULL::DECIMAL(10,2), NULL::DECIMAL(10,2), NULL::DECIMAL(10,2), NULL::DECIMAL(12,2);
    
    RETURN QUERY SELECT
        'RESUMEN'::VARCHAR(20), 'Tasa de Comisión'::VARCHAR(100),
        (v_calc.commission_rate_percent || '%')::VARCHAR(100), v_calc.commission_rate_percent,
        NULL::INTEGER, NULL::DATE, NULL::VARCHAR(20),
        NULL::DECIMAL(10,2), NULL::DECIMAL(10,2), NULL::DECIMAL(10,2), NULL::DECIMAL(12,2);
    
    RETURN QUERY SELECT
        'RESUMEN'::VARCHAR(20), 'Fecha de Aprobación'::VARCHAR(100),
        TO_CHAR(p_approval_date, 'DD/MM/YYYY')::VARCHAR(100), NULL::DECIMAL(12,2),
        NULL::INTEGER, NULL::DATE, NULL::VARCHAR(20),
        NULL::DECIMAL(10,2), NULL::DECIMAL(10,2), NULL::DECIMAL(10,2), NULL::DECIMAL(12,2);
    
    -- Totales
    RETURN QUERY SELECT
        'TOTALES'::VARCHAR(20), 'Pago Quincenal Cliente'::VARCHAR(100),
        ('$' || v_calc.biweekly_payment::TEXT)::VARCHAR(100), v_calc.biweekly_payment,
        NULL::INTEGER, NULL::DATE, NULL::VARCHAR(20),
        NULL::DECIMAL(10,2), NULL::DECIMAL(10,2), NULL::DECIMAL(10,2), NULL::DECIMAL(12,2);
    
    RETURN QUERY SELECT
        'TOTALES'::VARCHAR(20), 'Total a Pagar (Cliente)'::VARCHAR(100),
        ('$' || v_calc.total_payment::TEXT)::VARCHAR(100), v_calc.total_payment,
        NULL::INTEGER, NULL::DATE, NULL::VARCHAR(20),
        NULL::DECIMAL(10,2), NULL::DECIMAL(10,2), NULL::DECIMAL(10,2), NULL::DECIMAL(12,2);
    
    RETURN QUERY SELECT
        'TOTALES'::VARCHAR(20), 'Pago Quincenal Asociado'::VARCHAR(100),
        ('$' || v_calc.associate_payment::TEXT)::VARCHAR(100), v_calc.associate_payment,
        NULL::INTEGER, NULL::DATE, NULL::VARCHAR(20),
        NULL::DECIMAL(10,2), NULL::DECIMAL(10,2), NULL::DECIMAL(10,2), NULL::DECIMAL(12,2);
    
    RETURN QUERY SELECT
        'TOTALES'::VARCHAR(20), 'Total Asociado → CrediCuenta'::VARCHAR(100),
        ('$' || v_calc.associate_total::TEXT)::VARCHAR(100), v_calc.associate_total,
        NULL::INTEGER, NULL::DATE, NULL::VARCHAR(20),
        NULL::DECIMAL(10,2), NULL::DECIMAL(10,2), NULL::DECIMAL(10,2), NULL::DECIMAL(12,2);
    
    RETURN QUERY SELECT
        'TOTALES'::VARCHAR(20), 'Comisión por Pago'::VARCHAR(100),
        ('$' || v_calc.commission_per_payment::TEXT)::VARCHAR(100), v_calc.commission_per_payment,
        NULL::INTEGER, NULL::DATE, NULL::VARCHAR(20),
        NULL::DECIMAL(10,2), NULL::DECIMAL(10,2), NULL::DECIMAL(10,2), NULL::DECIMAL(12,2);
    
    RETURN QUERY SELECT
        'TOTALES'::VARCHAR(20), 'Comisión Total Asociado'::VARCHAR(100),
        ('$' || v_calc.total_commission::TEXT)::VARCHAR(100), v_calc.total_commission,
        NULL::INTEGER, NULL::DATE, NULL::VARCHAR(20),
        NULL::DECIMAL(10,2), NULL::DECIMAL(10,2), NULL::DECIMAL(10,2), NULL::DECIMAL(12,2);
    
    -- =========================================================================
    -- SECCIÓN 2: TABLA DE AMORTIZACIÓN
    -- =========================================================================
    RETURN QUERY 
    SELECT 
        'AMORTIZACIÓN'::VARCHAR(20),
        NULL::VARCHAR(100),
        NULL::VARCHAR(100),
        NULL::DECIMAL(12,2),
        s.payment_number,
        s.payment_date,
        s.cut_period_code,
        s.client_payment,
        s.associate_payment,
        s.commission_amount,
        s.remaining_balance
    FROM simulate_loan(p_amount, p_term_biweeks, p_profile_code, p_approval_date) s;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION simulate_loan_complete IS 
'Simulador completo de préstamos con RESUMEN + TABLA DE AMORTIZACIÓN.
Incluye: perfil, tasas, totales, fechas de pago, períodos de corte.
Uso: SELECT * FROM simulate_loan_complete(10000, 12, ''standard'', ''2025-11-15'');';
