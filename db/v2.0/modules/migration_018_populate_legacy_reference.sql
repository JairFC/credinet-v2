-- =============================================================================
-- MIGRACIÓN 018: Poblar tabla de referencia con datos legacy
-- =============================================================================
-- Inserta los 29 registros de la tabla legacy_payment_table en la tabla
-- rate_profile_reference_table para que aparezcan en el simulador

INSERT INTO rate_profile_reference_table (
    profile_code,
    amount,
    term_biweeks,
    biweekly_payment,
    total_payment,
    commission_per_payment,
    total_commission,
    associate_payment,
    associate_total,
    interest_rate_percent,
    commission_rate_percent
)
SELECT 
    'legacy' as profile_code,
    amount,
    term_biweeks,
    biweekly_payment,
    total_payment,
    commission_per_payment,
    commission_per_payment * term_biweeks as total_commission,
    associate_biweekly_payment as associate_payment,
    associate_total_payment as associate_total,
    biweekly_rate_percent as interest_rate_percent,
    ROUND(((commission_per_payment / NULLIF(biweekly_payment, 0)) * 100)::NUMERIC, 3) as commission_rate_percent
FROM legacy_payment_table
ON CONFLICT (profile_code, amount, term_biweeks) DO UPDATE SET
    biweekly_payment = EXCLUDED.biweekly_payment,
    total_payment = EXCLUDED.total_payment,
    commission_per_payment = EXCLUDED.commission_per_payment,
    total_commission = EXCLUDED.total_commission,
    associate_payment = EXCLUDED.associate_payment,
    associate_total = EXCLUDED.associate_total,
    interest_rate_percent = EXCLUDED.interest_rate_percent,
    commission_rate_percent = EXCLUDED.commission_rate_percent;

COMMENT ON TABLE rate_profile_reference_table IS 
'Tabla de referencia precalculada con valores para todos los perfiles (legacy, transition, standard, premium).
Incluye los 29 registros históricos del perfil legacy para consulta rápida en el simulador.';
