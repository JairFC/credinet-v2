-- =============================================================================
-- SCRIPT DE VALIDACIÓN Y CORRECCIÓN DE CREDIT_USED v2.0.3
-- =============================================================================
-- Fecha: 2026-01-07
-- Propósito: Validar y corregir desincronización en credit_used de asociados
-- Ejecutar DESPUÉS de aplicar correcciones de triggers
-- =============================================================================

-- =============================================================================
-- PASO 1: ANÁLISIS DE DESINCRONIZACIÓN ACTUAL
-- =============================================================================

DO $$
DECLARE
    v_total_associates INTEGER;
    v_synced_associates INTEGER;
    v_desynced_associates INTEGER;
    v_total_discrepancy DECIMAL(12,2);
BEGIN
    RAISE NOTICE '🔍 ANÁLISIS DE SINCRONIZACIÓN - CREDIT_USED';
    RAISE NOTICE '================================================';
    
    -- Contar asociados
    SELECT COUNT(*) INTO v_total_associates
    FROM associate_profiles;
    
    -- Contar asociados sincronizados (discrepancia < $1.00)
    SELECT COUNT(*) INTO v_synced_associates
    FROM associate_profiles ap
    WHERE ABS(
        ap.credit_used - (
            SELECT COALESCE(SUM(l.amount), 0)
            FROM loans l
            WHERE l.associate_user_id = ap.user_id
              AND l.status_id IN (2, 3)  -- APPROVED, ACTIVE
        )
    ) < 1.00;
    
    -- Asociados desincronizados
    v_desynced_associates := v_total_associates - v_synced_associates;
    
    -- Total de discrepancia
    SELECT COALESCE(SUM(
        ABS(
            ap.credit_used - (
                SELECT COALESCE(SUM(l.amount), 0)
                FROM loans l
                WHERE l.associate_user_id = ap.user_id
                  AND l.status_id IN (2, 3)
            )
        )
    ), 0) INTO v_total_discrepancy
    FROM associate_profiles ap
    WHERE ABS(
        ap.credit_used - (
            SELECT COALESCE(SUM(l.amount), 0)
            FROM loans l
            WHERE l.associate_user_id = ap.user_id
              AND l.status_id IN (2, 3)
        )
    ) >= 1.00;
    
    RAISE NOTICE '';
    RAISE NOTICE 'Total asociados: %', v_total_associates;
    RAISE NOTICE 'Sincronizados: % (%.2f%%)', 
        v_synced_associates, 
        (v_synced_associates::DECIMAL / NULLIF(v_total_associates, 0) * 100);
    RAISE NOTICE 'Desincronizados: % (%.2f%%)', 
        v_desynced_associates,
        (v_desynced_associates::DECIMAL / NULLIF(v_total_associates, 0) * 100);
    RAISE NOTICE 'Discrepancia total: $%', v_total_discrepancy;
    RAISE NOTICE '';
END;
$$;

-- =============================================================================
-- PASO 2: DETALLE DE ASOCIADOS DESINCRONIZADOS
-- =============================================================================

RAISE NOTICE '📊 DETALLE DE DESINCRONIZACIÓN POR ASOCIADO';
RAISE NOTICE '================================================';

SELECT 
    ap.id AS profile_id,
    ap.user_id,
    u.first_name || ' ' || u.last_name AS associate_name,
    ap.credit_limit,
    ap.credit_used AS current_credit_used,
    (
        SELECT COALESCE(SUM(l.amount), 0)
        FROM loans l
        WHERE l.associate_user_id = ap.user_id
          AND l.status_id IN (2, 3)  -- APPROVED, ACTIVE
    ) AS expected_credit_used,
    (
        ap.credit_used - (
            SELECT COALESCE(SUM(l.amount), 0)
            FROM loans l
            WHERE l.associate_user_id = ap.user_id
              AND l.status_id IN (2, 3)
        )
    ) AS discrepancy,
    (
        SELECT COUNT(*)
        FROM loans l
        WHERE l.associate_user_id = ap.user_id
          AND l.status_id IN (2, 3)
    ) AS active_loans,
    ap.debt_balance,
    ap.credit_last_updated
FROM associate_profiles ap
JOIN users u ON ap.user_id = u.id
WHERE ABS(
    ap.credit_used - (
        SELECT COALESCE(SUM(l.amount), 0)
        FROM loans l
        WHERE l.associate_user_id = ap.user_id
          AND l.status_id IN (2, 3)
    )
) >= 1.00
ORDER BY ABS(
    ap.credit_used - (
        SELECT COALESCE(SUM(l.amount), 0)
        FROM loans l
        WHERE l.associate_user_id = ap.user_id
          AND l.status_id IN (2, 3)
    )
) DESC;

-- =============================================================================
-- PASO 3: BACKUP DE DATOS ANTES DE CORRECCIÓN
-- =============================================================================

-- Crear tabla temporal con valores actuales
DROP TABLE IF EXISTS credit_used_backup_20260107;

CREATE TEMP TABLE credit_used_backup_20260107 AS
SELECT 
    ap.id,
    ap.user_id,
    ap.credit_used AS old_credit_used,
    ap.credit_limit,
    ap.debt_balance,
    ap.credit_last_updated AS old_credit_last_updated,
    (
        SELECT COALESCE(SUM(l.amount), 0)
        FROM loans l
        WHERE l.associate_user_id = ap.user_id
          AND l.status_id IN (2, 3)
    ) AS calculated_credit_used,
    CURRENT_TIMESTAMP AS backup_date
FROM associate_profiles ap;

RAISE NOTICE '✅ Backup creado en credit_used_backup_20260107';

-- =============================================================================
-- PASO 4: CORRECCIÓN AUTOMÁTICA (COMENTADO - DESCOMENTAR PARA EJECUTAR)
-- =============================================================================

-- ⚠️ ADVERTENCIA: Esta operación modifica datos en producción
-- Descomentar SOLO después de revisar el análisis anterior

/*
DO $$
DECLARE
    v_affected_rows INTEGER;
BEGIN
    RAISE NOTICE '🔧 INICIANDO CORRECCIÓN DE CREDIT_USED';
    RAISE NOTICE '================================================';
    
    -- Actualizar credit_used para asociados desincronizados
    WITH corrections AS (
        UPDATE associate_profiles ap
        SET credit_used = (
            SELECT COALESCE(SUM(l.amount), 0)
            FROM loans l
            WHERE l.associate_user_id = ap.user_id
              AND l.status_id IN (2, 3)  -- APPROVED, ACTIVE
        ),
        credit_last_updated = CURRENT_TIMESTAMP
        WHERE ABS(
            ap.credit_used - (
                SELECT COALESCE(SUM(l.amount), 0)
                FROM loans l
                WHERE l.associate_user_id = ap.user_id
                  AND l.status_id IN (2, 3)
            )
        ) >= 1.00
        RETURNING ap.id
    )
    SELECT COUNT(*) INTO v_affected_rows FROM corrections;
    
    RAISE NOTICE '✅ Corrección completada';
    RAISE NOTICE 'Asociados actualizados: %', v_affected_rows;
    RAISE NOTICE '';
    RAISE NOTICE 'Backup disponible en: credit_used_backup_20260107';
    RAISE NOTICE 'Para revertir, contactar al equipo técnico';
END;
$$;
*/

-- =============================================================================
-- PASO 5: VALIDACIÓN POST-CORRECCIÓN (Ejecutar después del PASO 4)
-- =============================================================================

/*
DO $$
DECLARE
    v_remaining_desynced INTEGER;
BEGIN
    RAISE NOTICE '✅ VALIDACIÓN POST-CORRECCIÓN';
    RAISE NOTICE '================================================';
    
    SELECT COUNT(*) INTO v_remaining_desynced
    FROM associate_profiles ap
    WHERE ABS(
        ap.credit_used - (
            SELECT COALESCE(SUM(l.amount), 0)
            FROM loans l
            WHERE l.associate_user_id = ap.user_id
              AND l.status_id IN (2, 3)
        )
    ) >= 1.00;
    
    IF v_remaining_desynced = 0 THEN
        RAISE NOTICE '✅ ÉXITO: Todos los asociados están sincronizados';
    ELSE
        RAISE WARNING '⚠️ Aún hay % asociados desincronizados', v_remaining_desynced;
        RAISE WARNING 'Revisar manualmente';
    END IF;
END;
$$;
*/

-- =============================================================================
-- PASO 6: COMPARACIÓN ANTES/DESPUÉS (Ejecutar después del PASO 4)
-- =============================================================================

/*
SELECT 
    b.user_id,
    b.old_credit_used,
    b.calculated_credit_used AS new_credit_used,
    (b.calculated_credit_used - b.old_credit_used) AS correction_amount,
    b.credit_limit,
    b.debt_balance,
    (b.credit_limit - b.calculated_credit_used - b.debt_balance) AS credit_available_after
FROM credit_used_backup_20260107 b
WHERE ABS(b.calculated_credit_used - b.old_credit_used) >= 1.00
ORDER BY ABS(b.calculated_credit_used - b.old_credit_used) DESC;
*/

-- =============================================================================
-- FUNCIONES DE MONITOREO CONTINUO
-- =============================================================================

-- Función para validar sincronización de un asociado
CREATE OR REPLACE FUNCTION validate_associate_credit_sync(p_associate_user_id INTEGER)
RETURNS TABLE (
    user_id INTEGER,
    current_credit_used DECIMAL(12,2),
    expected_credit_used DECIMAL(12,2),
    discrepancy DECIMAL(12,2),
    is_synced BOOLEAN,
    active_loans_count INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ap.user_id,
        ap.credit_used,
        (
            SELECT COALESCE(SUM(l.amount), 0)
            FROM loans l
            WHERE l.associate_user_id = ap.user_id
              AND l.status_id IN (2, 3)
        ),
        (
            ap.credit_used - (
                SELECT COALESCE(SUM(l.amount), 0)
                FROM loans l
                WHERE l.associate_user_id = ap.user_id
                  AND l.status_id IN (2, 3)
            )
        ),
        ABS(
            ap.credit_used - (
                SELECT COALESCE(SUM(l.amount), 0)
                FROM loans l
                WHERE l.associate_user_id = ap.user_id
                  AND l.status_id IN (2, 3)
            )
        ) < 1.00,
        (
            SELECT COUNT(*)::INTEGER
            FROM loans l
            WHERE l.associate_user_id = ap.user_id
              AND l.status_id IN (2, 3)
        )
    FROM associate_profiles ap
    WHERE ap.user_id = p_associate_user_id;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION validate_associate_credit_sync(INTEGER) IS
'Valida la sincronización del credit_used de un asociado específico. Retorna current vs expected y estado de sincronización.';

-- Función para monitoreo global
CREATE OR REPLACE FUNCTION get_credit_sync_summary()
RETURNS TABLE (
    total_associates INTEGER,
    synced_count INTEGER,
    desynced_count INTEGER,
    synced_percentage DECIMAL(5,2),
    total_discrepancy DECIMAL(12,2),
    max_discrepancy DECIMAL(12,2),
    last_check TIMESTAMP
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*)::INTEGER,
        COUNT(*) FILTER (WHERE ABS(
            ap.credit_used - (
                SELECT COALESCE(SUM(l.amount), 0)
                FROM loans l
                WHERE l.associate_user_id = ap.user_id
                  AND l.status_id IN (2, 3)
            )
        ) < 1.00)::INTEGER,
        COUNT(*) FILTER (WHERE ABS(
            ap.credit_used - (
                SELECT COALESCE(SUM(l.amount), 0)
                FROM loans l
                WHERE l.associate_user_id = ap.user_id
                  AND l.status_id IN (2, 3)
            )
        ) >= 1.00)::INTEGER,
        (COUNT(*) FILTER (WHERE ABS(
            ap.credit_used - (
                SELECT COALESCE(SUM(l.amount), 0)
                FROM loans l
                WHERE l.associate_user_id = ap.user_id
                  AND l.status_id IN (2, 3)
            )
        ) < 1.00)::DECIMAL / NULLIF(COUNT(*), 0) * 100),
        COALESCE(SUM(ABS(
            ap.credit_used - (
                SELECT COALESCE(SUM(l.amount), 0)
                FROM loans l
                WHERE l.associate_user_id = ap.user_id
                  AND l.status_id IN (2, 3)
            )
        )) FILTER (WHERE ABS(
            ap.credit_used - (
                SELECT COALESCE(SUM(l.amount), 0)
                FROM loans l
                WHERE l.associate_user_id = ap.user_id
                  AND l.status_id IN (2, 3)
            )
        ) >= 1.00), 0),
        COALESCE(MAX(ABS(
            ap.credit_used - (
                SELECT COALESCE(SUM(l.amount), 0)
                FROM loans l
                WHERE l.associate_user_id = ap.user_id
                  AND l.status_id IN (2, 3)
            )
        )), 0),
        CURRENT_TIMESTAMP
    FROM associate_profiles ap;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION get_credit_sync_summary() IS
'Retorna un resumen del estado de sincronización de credit_used de todos los asociados. Útil para monitoreo diario.';

-- =============================================================================
-- EJEMPLO DE USO
-- =============================================================================

-- Validar un asociado específico:
-- SELECT * FROM validate_associate_credit_sync(10);

-- Ver resumen global:
-- SELECT * FROM get_credit_sync_summary();

-- =============================================================================
-- FIN DEL SCRIPT
-- =============================================================================
