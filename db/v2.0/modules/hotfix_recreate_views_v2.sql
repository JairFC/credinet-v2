-- =============================================================================
-- HOTFIX: Recrear Vistas Dependientes de credit_available
-- =============================================================================
-- Fecha: 2025-11-13
-- Autor: Sistema
-- Propósito: Recrear las vistas eliminadas en hotfix_credit_available_v2.sql
--           con correcciones de nombres de columnas.
--
-- Vistas a recrear:
--   1. v_associate_credit_summary
--   2. v_associate_debt_summary
-- =============================================================================

BEGIN;

-- =============================================================================
-- VISTA 1: v_associate_credit_summary (de 08_views.sql)
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
-- VISTA 2: v_associate_debt_summary (de migration_016)
-- =============================================================================
CREATE OR REPLACE VIEW v_associate_debt_summary AS
SELECT 
    ap.id AS associate_profile_id,
    CONCAT(u.first_name, ' ', u.last_name) AS associate_name,
    ap.debt_balance AS current_debt_balance,
    
    -- Contadores
    COUNT(DISTINCT adb.id) FILTER (WHERE adb.is_liquidated = false) AS pending_debt_items,
    COUNT(DISTINCT adb.id) FILTER (WHERE adb.is_liquidated = true) AS liquidated_debt_items,
    
    -- Montos desglosados
    COALESCE(SUM(adb.amount) FILTER (WHERE adb.is_liquidated = false), 0) AS total_pending_debt,
    COALESCE(SUM(adp.payment_amount), 0) AS total_paid_to_debt,
    
    -- Fechas
    MIN(adb.created_at) FILTER (WHERE adb.is_liquidated = false) AS oldest_debt_date,
    MAX(adp.payment_date) AS last_payment_date,
    
    -- Estadísticas
    COUNT(DISTINCT adp.id) AS total_debt_payments_count,
    ap.credit_available,
    ap.credit_limit
    
FROM associate_profiles ap
JOIN users u ON u.id = ap.user_id
LEFT JOIN associate_debt_breakdown adb ON adb.associate_profile_id = ap.id
LEFT JOIN associate_debt_payments adp ON adp.associate_profile_id = ap.id

GROUP BY 
    ap.id,
    u.first_name,
    u.last_name,
    ap.debt_balance,
    ap.credit_available,
    ap.credit_limit;

COMMENT ON VIEW v_associate_debt_summary IS 
'⭐ v2.0.4: Vista de resumen de deuda por asociado. Muestra deuda actual, items pendientes/liquidados, total pagado, y fechas clave.';

COMMIT;

-- =============================================================================
-- VERIFICACIÓN (ejecutar después del COMMIT)
-- =============================================================================

SELECT 'Vistas recreadas exitosamente' AS status;

-- Verificar vistas
SELECT 
    table_name,
    view_definition IS NOT NULL AS exists
FROM information_schema.views
WHERE table_name IN ('v_associate_credit_summary', 'v_associate_debt_summary')
ORDER BY table_name;
