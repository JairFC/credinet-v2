-- =============================================================================
-- HOTFIX: Corregir fórmula de credit_available en associate_profiles
-- =============================================================================
-- Fecha: 2025-11-13
-- Versión: v2 (con CASCADE para vistas dependientes)
-- =============================================================================

BEGIN;

-- Paso 1: Eliminar vistas dependientes temporalmente
DROP VIEW IF EXISTS v_associate_credit_summary CASCADE;
DROP VIEW IF EXISTS v_associate_debt_summary CASCADE;

-- Paso 2: Eliminar columna calculada existente (incorrecta)
ALTER TABLE associate_profiles 
DROP COLUMN IF EXISTS credit_available CASCADE;

-- Paso 3: Crear nueva columna calculada con fórmula correcta
ALTER TABLE associate_profiles 
ADD COLUMN credit_available DECIMAL(12, 2) 
GENERATED ALWAYS AS (
    GREATEST(credit_limit - credit_used - debt_balance, 0)
) STORED;

-- Comentario explicativo
COMMENT ON COLUMN associate_profiles.credit_available IS 
'✅ v2.0.5 HOTFIX: Crédito operativo disponible REAL (columna calculada). 
Fórmula CORRECTA: credit_limit - credit_used - debt_balance (con mínimo 0).
IMPORTANTE: Ahora incluye debt_balance. Consistente con check_associate_credit_available().';

-- Paso 4: Recrear vistas (si existen en 08_views.sql)
-- Verificamos primero si las vistas están definidas
DO $$
BEGIN
    RAISE NOTICE '✅ Columna credit_available corregida';
    RAISE NOTICE '⚠️  ACCIÓN REQUERIDA: Recrear vistas v_associate_credit_summary y v_associate_debt_summary';
    RAISE NOTICE '   Ejecutar: psql -U credinet_user -d credinet_db -f db/v2.0/modules/08_views.sql';
END $$;

COMMIT;

-- Verificación
SELECT 
    id,
    credit_limit,
    credit_used,
    debt_balance,
    credit_available,
    (credit_limit - credit_used - debt_balance) AS "Verificación Manual"
FROM associate_profiles
ORDER BY id
LIMIT 5;
