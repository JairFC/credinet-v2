-- Actualizar vista v_associate_all_payments para incluir pagos de convenios
-- Fecha: 2026-01-08

DROP VIEW IF EXISTS v_associate_all_payments;

CREATE VIEW v_associate_all_payments AS
-- Pagos a saldo actual (statements)
SELECT 
    asp.id,
    'SALDO_ACTUAL' AS payment_type,
    ap.id AS associate_profile_id,
    CONCAT(u.first_name, ' ', u.last_name) AS associate_name,
    asp.payment_amount,
    asp.payment_date,
    pm.name AS payment_method,
    asp.payment_reference,
    aps.cut_period_id,
    cp.period_start_date AS period_start,
    cp.period_end_date AS period_end,
    asp.notes,
    asp.created_at
FROM associate_statement_payments asp
JOIN associate_payment_statements aps ON aps.id = asp.statement_id
JOIN users u ON u.id = aps.user_id
JOIN associate_profiles ap ON ap.user_id = u.id
JOIN payment_methods pm ON pm.id = asp.payment_method_id
LEFT JOIN cut_periods cp ON cp.id = aps.cut_period_id

UNION ALL

-- Pagos a deuda acumulada directa
SELECT 
    adp.id,
    'DEUDA_ACUMULADA' AS payment_type,
    adp.associate_profile_id,
    CONCAT(u.first_name, ' ', u.last_name) AS associate_name,
    adp.payment_amount,
    adp.payment_date,
    pm.name AS payment_method,
    adp.payment_reference,
    NULL::integer AS cut_period_id,
    NULL::date AS period_start,
    NULL::date AS period_end,
    adp.notes,
    adp.created_at
FROM associate_debt_payments adp
JOIN associate_profiles ap ON ap.id = adp.associate_profile_id
JOIN users u ON u.id = ap.user_id
JOIN payment_methods pm ON pm.id = adp.payment_method_id

UNION ALL

-- Pagos de convenios (PAID)
SELECT 
    ap_conv.id,
    'PAGO_CONVENIO' AS payment_type,
    agr.associate_profile_id,
    CONCAT(u.first_name, ' ', u.last_name) AS associate_name,
    ap_conv.payment_amount,
    ap_conv.payment_date,
    COALESCE(pm.name, 'N/A')::VARCHAR(50) AS payment_method,
    ap_conv.payment_reference,
    NULL::integer AS cut_period_id,
    NULL::date AS period_start,
    NULL::date AS period_end,
    CONCAT('Pago #', ap_conv.payment_number, ' - ', agr.agreement_number) AS notes,
    ap_conv.created_at
FROM agreement_payments ap_conv
JOIN agreements agr ON agr.id = ap_conv.agreement_id
JOIN associate_profiles aprof ON aprof.id = agr.associate_profile_id
JOIN users u ON u.id = aprof.user_id
LEFT JOIN payment_methods pm ON pm.id = ap_conv.payment_method_id
WHERE ap_conv.status = 'PAID'

ORDER BY payment_date DESC, created_at DESC;

-- Comentarios
COMMENT ON VIEW v_associate_all_payments IS 
'Vista unificada de todos los tipos de pagos de asociados: statements, deuda acumulada y convenios';
