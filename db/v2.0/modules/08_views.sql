-- =============================================================================
-- CREDINET DB v2.0 - MÓDULO 08: VISTAS
-- =============================================================================
-- Descripción:
--   Vistas especializadas para consultas comunes del sistema.
--   Todas las vistas provienen de las migraciones 07-12.
--
-- Vistas incluidas:
--   - v_associate_credit_summary ⭐ MIGRACIÓN 07
--   - v_period_closure_summary ⭐ MIGRACIÓN 08
--   - v_associate_debt_detailed ⭐ MIGRACIÓN 09
--   - v_associate_late_fees ⭐ MIGRACIÓN 10
--   - v_payments_by_status_detailed ⭐ MIGRACIÓN 11
--   - v_payments_absorbed_by_associate ⭐ MIGRACIÓN 11
--   - v_payment_changes_summary ⭐ MIGRACIÓN 12
--   - v_recent_payment_changes ⭐ MIGRACIÓN 12
--   - v_payments_multiple_changes ⭐ MIGRACIÓN 12
--
-- Total: 9 vistas
-- Versión: 2.0.0
-- Fecha: 2025-10-30
-- =============================================================================

-- =============================================================================
-- VISTA 1: v_associate_credit_summary ⭐ MIGRACIÓN 07
-- =============================================================================
CREATE OR REPLACE VIEW v_associate_credit_summary AS
SELECT 
    ap.id AS associate_profile_id,
    u.id AS user_id,
    CONCAT(u.first_name, ' ', u.last_name) AS associate_name,
    u.email,
    al.name AS associate_level,
    ap.credit_limit,
    ap.credit_used,
    ap.debt_balance,
    ap.credit_available,
    ap.credit_last_updated,
    CASE 
        WHEN ap.credit_available <= 0 THEN 'SIN_CREDITO'
        WHEN ap.credit_available < (ap.credit_limit * 0.25) THEN 'CRITICO'
        WHEN ap.credit_available < (ap.credit_limit * 0.50) THEN 'MEDIO'
        ELSE 'ALTO'
    END AS credit_status,
    ROUND((ap.credit_used::DECIMAL / NULLIF(ap.credit_limit, 0)) * 100, 2) AS credit_usage_percentage,
    ap.active AS is_active
FROM associate_profiles ap
JOIN users u ON ap.user_id = u.id
JOIN associate_levels al ON ap.level_id = al.id
ORDER BY ap.credit_available DESC;

COMMENT ON VIEW v_associate_credit_summary IS 
'⭐ MIGRACIÓN 07: Resumen ejecutivo del crédito disponible de cada asociado con análisis de utilización y estado.';

-- =============================================================================
-- VISTA 2: v_period_closure_summary ⭐ MIGRACIÓN 08
-- =============================================================================
CREATE OR REPLACE VIEW v_period_closure_summary AS
SELECT 
    cp.id AS cut_period_id,
    cp.cut_number,
    cp.period_start_date,
    cp.period_end_date,
    cps.name AS period_status,
    COUNT(p.id) AS total_payments,
    COUNT(CASE WHEN ps.name = 'PAID' THEN 1 END) AS payments_paid,
    COUNT(CASE WHEN ps.name = 'PAID_NOT_REPORTED' THEN 1 END) AS payments_not_reported,
    COUNT(CASE WHEN ps.name = 'PAID_BY_ASSOCIATE' THEN 1 END) AS payments_by_associate,
    COUNT(CASE WHEN ps.name IN ('PENDING', 'DUE_TODAY', 'OVERDUE') THEN 1 END) AS payments_pending,
    COALESCE(SUM(CASE WHEN ps.name = 'PAID' THEN p.amount_paid ELSE 0 END), 0) AS total_collected,
    cp.total_payments_expected,
    cp.total_commission,
    CONCAT(u.first_name, ' ', u.last_name) AS closed_by_name,
    cp.updated_at AS last_updated
FROM cut_periods cp
JOIN cut_period_statuses cps ON cp.status_id = cps.id
LEFT JOIN payments p ON cp.id = p.cut_period_id
LEFT JOIN payment_statuses ps ON p.status_id = ps.id
LEFT JOIN users u ON cp.closed_by = u.id
GROUP BY 
    cp.id, cp.cut_number, cp.period_start_date, cp.period_end_date,
    cps.name, cp.total_payments_expected, cp.total_commission,
    u.first_name, u.last_name, cp.updated_at
ORDER BY cp.period_start_date DESC;

COMMENT ON VIEW v_period_closure_summary IS 
'⭐ MIGRACIÓN 08: Resumen de cierre de cada período de corte con estadísticas de pagos por estado (PAID, PAID_NOT_REPORTED, PAID_BY_ASSOCIATE).';

-- =============================================================================
-- VISTA 3: v_associate_debt_detailed ⭐ MIGRACIÓN 09
-- =============================================================================
CREATE OR REPLACE VIEW v_associate_debt_detailed AS
SELECT 
    adb.id AS debt_id,
    ap.id AS associate_profile_id,
    CONCAT(u.first_name, ' ', u.last_name) AS associate_name,
    adb.debt_type,
    adb.amount AS debt_amount,
    adb.is_liquidated,
    adb.liquidated_at,
    cp.cut_number,
    cp.period_start_date,
    cp.period_end_date,
    l.id AS loan_id,
    CONCAT(uc.first_name, ' ', uc.last_name) AS client_name,
    adb.description,
    adb.created_at AS debt_registered_at,
    CASE adb.debt_type
        WHEN 'UNREPORTED_PAYMENT' THEN 'Pago no reportado al cierre'
        WHEN 'DEFAULTED_CLIENT' THEN 'Cliente moroso aprobado'
        WHEN 'LATE_FEE' THEN 'Mora del 30% aplicada'
        WHEN 'OTHER' THEN 'Otro tipo de deuda'
    END AS debt_type_description
FROM associate_debt_breakdown adb
JOIN associate_profiles ap ON adb.associate_profile_id = ap.id
JOIN users u ON ap.user_id = u.id
JOIN cut_periods cp ON adb.cut_period_id = cp.id
LEFT JOIN loans l ON adb.loan_id = l.id
LEFT JOIN users uc ON adb.client_user_id = uc.id
ORDER BY adb.created_at DESC, adb.is_liquidated ASC;

COMMENT ON VIEW v_associate_debt_detailed IS 
'⭐ MIGRACIÓN 09: Desglose detallado de todas las deudas de asociados por tipo, origen y estado de liquidación.';

-- =============================================================================
-- VISTA 4: v_associate_late_fees ⭐ MIGRACIÓN 10
-- =============================================================================
CREATE OR REPLACE VIEW v_associate_late_fees AS
SELECT 
    aps.id AS statement_id,
    aps.statement_number,
    CONCAT(u.first_name, ' ', u.last_name) AS associate_name,
    cp.cut_number,
    cp.period_start_date,
    cp.period_end_date,
    aps.total_payments_count,
    aps.total_amount_collected,
    aps.total_commission_owed,
    aps.late_fee_amount,
    aps.late_fee_applied,
    ss.name AS statement_status,
    CASE 
        WHEN aps.late_fee_applied THEN 'MORA APLICADA'
        WHEN aps.total_payments_count = 0 AND aps.total_commission_owed > 0 THEN 'SUJETO A MORA'
        ELSE 'SIN MORA'
    END AS late_fee_status,
    ROUND((aps.late_fee_amount / NULLIF(aps.total_commission_owed, 0)) * 100, 2) AS late_fee_percentage,
    aps.generated_date,
    aps.due_date,
    aps.paid_date
FROM associate_payment_statements aps
JOIN users u ON aps.user_id = u.id
JOIN cut_periods cp ON aps.cut_period_id = cp.id
JOIN statement_statuses ss ON aps.status_id = ss.id
WHERE aps.late_fee_amount > 0 OR (aps.total_payments_count = 0 AND aps.total_commission_owed > 0)
ORDER BY aps.generated_date DESC, aps.late_fee_amount DESC;

COMMENT ON VIEW v_associate_late_fees IS 
'⭐ MIGRACIÓN 10: Vista especializada de moras del 30% aplicadas o potenciales (cuando payments_count = 0).';

-- =============================================================================
-- VISTA 5: v_payments_by_status_detailed ⭐ MIGRACIÓN 11
-- =============================================================================
CREATE OR REPLACE VIEW v_payments_by_status_detailed AS
SELECT 
    p.id AS payment_id,
    p.loan_id,
    CONCAT(u.first_name, ' ', u.last_name) AS client_name,
    l.amount AS loan_amount,
    p.amount_paid,
    p.payment_date,
    p.payment_due_date,
    p.is_late,
    ps.name AS payment_status,
    ps.is_real_payment,
    CASE 
        WHEN ps.is_real_payment THEN 'REAL 💵'
        ELSE 'FICTICIO ⚠️'
    END AS payment_type,
    CONCAT(um.first_name, ' ', um.last_name) AS marked_by_name,
    p.marked_at,
    p.marking_notes,
    cp.cut_number,
    cp.period_start_date,
    cp.period_end_date,
    CONCAT(ua.first_name, ' ', ua.last_name) AS associate_name,
    p.created_at,
    p.updated_at
FROM payments p
JOIN loans l ON p.loan_id = l.id
JOIN users u ON l.user_id = u.id
JOIN payment_statuses ps ON p.status_id = ps.id
LEFT JOIN users um ON p.marked_by = um.id
LEFT JOIN cut_periods cp ON p.cut_period_id = cp.id
LEFT JOIN users ua ON l.associate_user_id = ua.id
ORDER BY p.payment_due_date DESC, p.id DESC;

COMMENT ON VIEW v_payments_by_status_detailed IS 
'⭐ MIGRACIÓN 11: Vista detallada de todos los pagos con su estado, tipo (real/ficticio) y tracking de marcado manual.';

-- =============================================================================
-- VISTA 6: v_payments_absorbed_by_associate ⭐ MIGRACIÓN 11
-- =============================================================================
CREATE OR REPLACE VIEW v_payments_absorbed_by_associate AS
SELECT 
    CONCAT(ua.first_name, ' ', ua.last_name) AS associate_name,
    ap.id AS associate_profile_id,
    COUNT(p.id) AS total_payments_absorbed,
    SUM(p.amount_paid) AS total_amount_absorbed,
    ps.name AS payment_status,
    cp.cut_number,
    cp.period_start_date,
    cp.period_end_date,
    STRING_AGG(DISTINCT CONCAT(uc.first_name, ' ', uc.last_name), ', ') AS affected_clients
FROM payments p
JOIN payment_statuses ps ON p.status_id = ps.id
JOIN loans l ON p.loan_id = l.id
JOIN users uc ON l.user_id = uc.id
JOIN users ua ON l.associate_user_id = ua.id
JOIN associate_profiles ap ON ua.id = ap.user_id
LEFT JOIN cut_periods cp ON p.cut_period_id = cp.id
WHERE ps.is_real_payment = FALSE
  AND ps.name IN ('PAID_BY_ASSOCIATE', 'PAID_NOT_REPORTED')
GROUP BY 
    ua.first_name, ua.last_name, ap.id, ps.name,
    cp.cut_number, cp.period_start_date, cp.period_end_date
ORDER BY SUM(p.amount_paid) DESC;

COMMENT ON VIEW v_payments_absorbed_by_associate IS 
'⭐ MIGRACIÓN 11: Resumen de pagos absorbidos por cada asociado (PAID_BY_ASSOCIATE, PAID_NOT_REPORTED) con totales y clientes afectados.';

-- =============================================================================
-- VISTA 7: v_payment_changes_summary ⭐ MIGRACIÓN 12
-- =============================================================================
CREATE OR REPLACE VIEW v_payment_changes_summary AS
SELECT 
    DATE(psh.changed_at) AS change_date,
    psh.change_type,
    COUNT(*) AS total_changes,
    COUNT(DISTINCT psh.payment_id) AS unique_payments,
    COUNT(DISTINCT psh.changed_by) AS unique_users,
    STRING_AGG(DISTINCT ps_new.name, ', ') AS status_changes_to,
    MIN(psh.changed_at) AS first_change,
    MAX(psh.changed_at) AS last_change
FROM payment_status_history psh
JOIN payment_statuses ps_new ON psh.new_status_id = ps_new.id
GROUP BY DATE(psh.changed_at), psh.change_type
ORDER BY change_date DESC, total_changes DESC;

COMMENT ON VIEW v_payment_changes_summary IS 
'⭐ MIGRACIÓN 12: Resumen estadístico diario de cambios de estado de pagos agrupados por tipo (AUTOMATIC, MANUAL_ADMIN, etc.).';

-- =============================================================================
-- VISTA 8: v_recent_payment_changes ⭐ MIGRACIÓN 12
-- =============================================================================
CREATE OR REPLACE VIEW v_recent_payment_changes AS
SELECT 
    psh.id AS change_id,
    psh.payment_id,
    p.loan_id,
    CONCAT(u.first_name, ' ', u.last_name) AS client_name,
    ps_old.name AS old_status,
    ps_new.name AS new_status,
    psh.change_type,
    CONCAT(uc.first_name, ' ', uc.last_name) AS changed_by_name,
    psh.change_reason,
    psh.changed_at,
    EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - psh.changed_at)) / 3600 AS hours_ago
FROM payment_status_history psh
JOIN payments p ON psh.payment_id = p.id
JOIN loans l ON p.loan_id = l.id
JOIN users u ON l.user_id = u.id
LEFT JOIN payment_statuses ps_old ON psh.old_status_id = ps_old.id
JOIN payment_statuses ps_new ON psh.new_status_id = ps_new.id
LEFT JOIN users uc ON psh.changed_by = uc.id
WHERE psh.changed_at >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
ORDER BY psh.changed_at DESC;

COMMENT ON VIEW v_recent_payment_changes IS 
'⭐ MIGRACIÓN 12: Cambios de estado de pagos en las últimas 24 horas (útil para monitoreo en tiempo real y detección temprana de anomalías).';

-- =============================================================================
-- VISTA 9: v_payments_multiple_changes ⭐ MIGRACIÓN 12
-- =============================================================================
CREATE OR REPLACE VIEW v_payments_multiple_changes AS
SELECT 
    p.id AS payment_id,
    p.loan_id,
    CONCAT(u.first_name, ' ', u.last_name) AS client_name,
    COUNT(psh.id) AS total_changes,
    STRING_AGG(
        CONCAT(ps.name, ' (', TO_CHAR(psh.changed_at, 'YYYY-MM-DD HH24:MI'), ')'),
        ' → '
        ORDER BY psh.changed_at
    ) AS status_timeline,
    MIN(psh.changed_at) AS first_change,
    MAX(psh.changed_at) AS last_change,
    EXTRACT(EPOCH FROM (MAX(psh.changed_at) - MIN(psh.changed_at))) / 3600 AS hours_between_first_last,
    COUNT(CASE WHEN psh.change_type = 'MANUAL_ADMIN' THEN 1 END) AS manual_changes_count,
    CASE 
        WHEN COUNT(psh.id) >= 5 THEN 'CRÍTICO'
        WHEN COUNT(psh.id) >= 3 THEN 'ALERTA'
        ELSE 'NORMAL'
    END AS review_priority
FROM payments p
JOIN payment_status_history psh ON p.id = psh.payment_id
JOIN payment_statuses ps ON psh.new_status_id = ps.id
JOIN loans l ON p.loan_id = l.id
JOIN users u ON l.user_id = u.id
GROUP BY p.id, p.loan_id, u.first_name, u.last_name
HAVING COUNT(psh.id) >= 3
ORDER BY COUNT(psh.id) DESC, MAX(psh.changed_at) DESC;

COMMENT ON VIEW v_payments_multiple_changes IS 
'⭐ MIGRACIÓN 12: Pagos con 3 o más cambios de estado (posibles errores, fraude o correcciones múltiples). Prioridad CRÍTICA para revisión forense.';

-- =============================================================================
-- FIN MÓDULO 08
-- =============================================================================
