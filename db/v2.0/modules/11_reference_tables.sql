-- =============================================================================
-- MÓDULO 11: TABLAS DE REFERENCIA PARA ADMINISTRADORES
-- =============================================================================
-- Propósito: Proporcionar tablas precalculadas de consulta rápida para que
--            los administradores puedan ver pagos del cliente, asociado y
--            comisiones para diferentes montos y plazos.
-- =============================================================================

-- =============================================================================
-- TABLA: rate_profile_reference_table
-- =============================================================================
DROP TABLE IF EXISTS rate_profile_reference_table CASCADE;

CREATE TABLE rate_profile_reference_table (
    id SERIAL PRIMARY KEY,
    profile_code VARCHAR(50) NOT NULL,
    amount DECIMAL(12,2) NOT NULL,
    term_biweeks INTEGER NOT NULL,
    
    -- Pagos y totales del CLIENTE
    biweekly_payment DECIMAL(10,2) NOT NULL COMMENT 'Pago quincenal del cliente',
    total_payment DECIMAL(12,2) NOT NULL COMMENT 'Total a pagar por el cliente',
    
    -- Comisiones
    commission_per_payment DECIMAL(10,2) NOT NULL COMMENT 'Comisión por pago quincenal',
    total_commission DECIMAL(12,2) NOT NULL COMMENT 'Comisión total del asociado',
    
    -- Pagos y totales del ASOCIADO (hacia CrediCuenta)
    associate_payment DECIMAL(10,2) NOT NULL COMMENT 'Pago quincenal del asociado hacia CrediCuenta',
    associate_total DECIMAL(12,2) NOT NULL COMMENT 'Total que paga el asociado a CrediCuenta',
    
    -- Tasas
    interest_rate_percent DECIMAL(5,3) COMMENT 'Tasa de interés aplicada',
    commission_rate_percent DECIMAL(5,3) COMMENT 'Porcentaje de comisión',
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT uq_profile_amount_term UNIQUE (profile_code, amount, term_biweeks),
    CONSTRAINT fk_profile_code FOREIGN KEY (profile_code) REFERENCES rate_profiles(code)
);

COMMENT ON TABLE rate_profile_reference_table IS 
'⭐ Tabla de referencia rápida con valores precalculados para consulta de administradores. 
Muestra: Pago cliente, Pago asociado, Comisiones para diferentes montos y plazos.
Actualizar cuando cambien las tasas de los perfiles.';

CREATE INDEX idx_ref_profile_code ON rate_profile_reference_table(profile_code);
CREATE INDEX idx_ref_amount ON rate_profile_reference_table(amount);
CREATE INDEX idx_ref_term ON rate_profile_reference_table(term_biweeks);

-- =============================================================================
-- VISTA: Tabla de Referencia a 12 Quincenas
-- =============================================================================
CREATE OR REPLACE VIEW v_rate_reference_12q AS
SELECT 
    rp.name as "Perfil",
    r.amount as "Importe",
    r.biweekly_payment as "Pago Cliente (Quinc)",
    r.total_payment as "Total Cliente",
    r.commission_per_payment as "Comisión (Quinc)",
    r.total_commission as "Comisión Total",
    r.associate_payment as "Pago Asociado (Quinc)",
    r.associate_total as "Total Asociado",
    r.interest_rate_percent as "Tasa Interés %",
    r.commission_rate_percent as "Tasa Comisión %"
FROM rate_profile_reference_table r
JOIN rate_profiles rp ON rp.code = r.profile_code
WHERE r.term_biweeks = 12
ORDER BY rp.name, r.amount;

COMMENT ON VIEW v_rate_reference_12q IS 
'Vista de referencia rápida a 12 quincenas. Útil para comparar con tabla legacy.';

-- =============================================================================
-- VISTA: Tabla de Referencia Completa (Todos los Plazos)
-- =============================================================================
CREATE OR REPLACE VIEW v_rate_reference_complete AS
SELECT 
    rp.name as "Perfil",
    r.amount as "Importe",
    r.term_biweeks as "Plazo (Quinc)",
    r.biweekly_payment as "Pago Cliente",
    r.associate_payment as "Pago Asociado",
    r.commission_per_payment as "Comisión",
    r.total_payment as "Total Cliente",
    r.associate_total as "Total Asociado",
    r.total_commission as "Comisión Total"
FROM rate_profile_reference_table r
JOIN rate_profiles rp ON rp.code = r.profile_code
ORDER BY rp.name, r.term_biweeks, r.amount;

COMMENT ON VIEW v_rate_reference_complete IS 
'Vista completa de referencia con todos los perfiles, montos y plazos.';

-- =============================================================================
-- FUNCIÓN: Regenerar Tabla de Referencia
-- =============================================================================
CREATE OR REPLACE FUNCTION regenerate_reference_table()
RETURNS TEXT AS $$
DECLARE
    v_count INTEGER := 0;
BEGIN
    -- Limpiar tabla existente
    DELETE FROM rate_profile_reference_table;
    
    -- TRANSITION (6, 12, 18, 24 quincenas)
    INSERT INTO rate_profile_reference_table 
        (profile_code, amount, term_biweeks, biweekly_payment, total_payment, 
         commission_per_payment, total_commission, associate_payment, associate_total,
         interest_rate_percent, commission_rate_percent)
    SELECT 
        c.profile_code, m.amount, t.term,
        c.biweekly_payment, c.total_payment,
        c.commission_per_payment, c.total_commission,
        c.associate_payment, c.associate_total,
        c.interest_rate_percent, c.commission_rate_percent
    FROM 
        (SELECT unnest(ARRAY[3000, 4000, 5000, 6000, 7000, 8000, 9000, 10000, 
                              12000, 15000, 18000, 20000, 25000, 30000]::DECIMAL[]) as amount) m,
        (SELECT unnest(ARRAY[6, 12, 18, 24]) as term) t
    CROSS JOIN LATERAL calculate_loan_payment(m.amount, t.term, 'transition') c;
    
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RAISE NOTICE 'TRANSITION: % registros', v_count;
    
    -- STANDARD (3, 6, 9, 12, 15, 18, 21, 24, 30, 36 quincenas)
    INSERT INTO rate_profile_reference_table 
        (profile_code, amount, term_biweeks, biweekly_payment, total_payment, 
         commission_per_payment, total_commission, associate_payment, associate_total,
         interest_rate_percent, commission_rate_percent)
    SELECT 
        c.profile_code, m.amount, t.term,
        c.biweekly_payment, c.total_payment,
        c.commission_per_payment, c.total_commission,
        c.associate_payment, c.associate_total,
        c.interest_rate_percent, c.commission_rate_percent
    FROM 
        (SELECT unnest(ARRAY[3000, 4000, 5000, 6000, 7000, 8000, 9000, 10000, 
                              12000, 15000, 18000, 20000, 25000, 30000]::DECIMAL[]) as amount) m,
        (SELECT unnest(ARRAY[3, 6, 9, 12, 15, 18, 21, 24, 30, 36]) as term) t
    CROSS JOIN LATERAL calculate_loan_payment(m.amount, t.term, 'standard') c;
    
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RAISE NOTICE 'STANDARD: % registros', v_count;
    
    -- PREMIUM (3, 6, 9, 12, 15, 18, 21, 24, 30, 36 quincenas)
    INSERT INTO rate_profile_reference_table 
        (profile_code, amount, term_biweeks, biweekly_payment, total_payment, 
         commission_per_payment, total_commission, associate_payment, associate_total,
         interest_rate_percent, commission_rate_percent)
    SELECT 
        c.profile_code, m.amount, t.term,
        c.biweekly_payment, c.total_payment,
        c.commission_per_payment, c.total_commission,
        c.associate_payment, c.associate_total,
        c.interest_rate_percent, c.commission_rate_percent
    FROM 
        (SELECT unnest(ARRAY[3000, 4000, 5000, 6000, 7000, 8000, 9000, 10000, 
                              12000, 15000, 18000, 20000, 25000, 30000]::DECIMAL[]) as amount) m,
        (SELECT unnest(ARRAY[3, 6, 9, 12, 15, 18, 21, 24, 30, 36]) as term) t
    CROSS JOIN LATERAL calculate_loan_payment(m.amount, t.term, 'premium') c;
    
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RAISE NOTICE 'PREMIUM: % registros', v_count;
    
    SELECT COUNT(*)::TEXT || ' registros totales generados' INTO v_count FROM rate_profile_reference_table;
    
    RETURN v_count;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION regenerate_reference_table() IS 
'Regenera la tabla de referencia con valores actualizados. 
Ejecutar cuando se modifiquen las tasas de los perfiles.';

-- =============================================================================
-- POBLAR TABLA INICIAL
-- =============================================================================
SELECT regenerate_reference_table();
