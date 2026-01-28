-- CrediNet Maintenance: Sync Associate Profile Balances
-- ========================================================
-- 
-- Este script sincroniza los saldos de los asociados con los datos reales.
-- Es una operación de SOLO LECTURA primero (SELECT), luego UPDATE.
--
-- USO:
--   1. Primero ejecutar solo el SELECT para ver qué se va a cambiar
--   2. Luego ejecutar el UPDATE (comentado al final)
--

-- ============ PASO 1: DIAGNÓSTICO ============

-- 1.1 Perfiles con pending_payments_total desincronizado
SELECT 
    'pending_payments_total mismatch' as issue,
    ap.id as profile_id, 
    CONCAT(u.first_name, ' ', u.last_name) as associate_name,
    ap.pending_payments_total as recorded,
    COALESCE(SUM(p.expected_amount), 0) as actual,
    ap.pending_payments_total - COALESCE(SUM(p.expected_amount), 0) as diff
FROM associate_profiles ap
JOIN users u ON u.id = ap.user_id
LEFT JOIN loans l ON l.associate_user_id = ap.user_id
LEFT JOIN payments p ON p.loan_id = l.id AND p.status_id = 1  -- PENDING
GROUP BY ap.id, u.first_name, u.last_name, ap.pending_payments_total
HAVING ABS(ap.pending_payments_total - COALESCE(SUM(p.expected_amount), 0)) > 0.01
ORDER BY ap.id;


-- 1.2 Perfiles con consolidated_debt desincronizado de convenios activos
SELECT 
    'consolidated_debt mismatch' as issue,
    ap.id as profile_id,
    CONCAT(u.first_name, ' ', u.last_name) as associate_name,
    ap.consolidated_debt as recorded,
    COALESCE(SUM(a.total_debt_amount), 0) as actual,
    ap.consolidated_debt - COALESCE(SUM(a.total_debt_amount), 0) as diff
FROM associate_profiles ap
JOIN users u ON u.id = ap.user_id
LEFT JOIN agreements a ON a.associate_profile_id = ap.id AND a.status = 'ACTIVE'
GROUP BY ap.id, u.first_name, u.last_name, ap.consolidated_debt
HAVING ABS(ap.consolidated_debt - COALESCE(SUM(a.total_debt_amount), 0)) > 0.01
ORDER BY ap.id;


-- ============ PASO 2: CORRECCIÓN (Descomentarlas para ejecutar) ============

/*
-- 2.1 Corregir pending_payments_total
UPDATE associate_profiles ap
SET 
    pending_payments_total = (
        SELECT COALESCE(SUM(p.expected_amount), 0) 
        FROM payments p 
        JOIN loans l ON l.id = p.loan_id
        WHERE l.associate_user_id = ap.user_id
          AND p.status_id = 1  -- PENDING
    ),
    updated_at = CURRENT_TIMESTAMP
WHERE ABS(
    ap.pending_payments_total - (
        SELECT COALESCE(SUM(p.expected_amount), 0) 
        FROM payments p 
        JOIN loans l ON l.id = p.loan_id
        WHERE l.associate_user_id = ap.user_id
          AND p.status_id = 1
    )
) > 0.01;


-- 2.2 Corregir consolidated_debt
UPDATE associate_profiles ap
SET 
    consolidated_debt = (
        SELECT COALESCE(SUM(a.total_debt_amount), 0) 
        FROM agreements a 
        WHERE a.associate_profile_id = ap.id 
          AND a.status = 'ACTIVE'
    ),
    updated_at = CURRENT_TIMESTAMP
WHERE ABS(
    ap.consolidated_debt - (
        SELECT COALESCE(SUM(a.total_debt_amount), 0) 
        FROM agreements a 
        WHERE a.associate_profile_id = ap.id 
          AND a.status = 'ACTIVE'
    )
) > 0.01;


-- 2.3 Verificar después de corrección
SELECT 
    ap.id,
    CONCAT(u.first_name, ' ', u.last_name) as associate_name,
    ap.pending_payments_total,
    ap.consolidated_debt,
    ap.available_credit,
    ap.credit_limit
FROM associate_profiles ap
JOIN users u ON u.id = ap.user_id
WHERE ap.active = true
ORDER BY ap.id;
*/
