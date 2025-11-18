-- =============================================================================
-- HOTFIX: Corregir fórmula de credit_available en associate_profiles
-- =============================================================================
-- Fecha: 2025-11-13
-- Problema: El campo calculado credit_available NO incluye debt_balance
-- Fórmula actual: credit_limit - credit_used
-- Fórmula correcta: credit_limit - credit_used - debt_balance
--
-- Impacto: CRÍTICO - Afecta validaciones de crédito disponible
-- Solución: Recrear columna calculada con fórmula correcta
-- =============================================================================

BEGIN;

-- Eliminar columna calculada existente (incorrecta)
ALTER TABLE associate_profiles 
DROP COLUMN IF EXISTS credit_available;

-- Crear nueva columna calculada con fórmula correcta
ALTER TABLE associate_profiles 
ADD COLUMN credit_available DECIMAL(12, 2) 
GENERATED ALWAYS AS (
    GREATEST(credit_limit - credit_used - debt_balance, 0)
) STORED;

-- Comentario explicativo
COMMENT ON COLUMN associate_profiles.credit_available IS 
'⚠️ v2.0.5 HOTFIX: Crédito operativo disponible REAL (columna calculada). 
Fórmula: credit_limit - credit_used - debt_balance (con mínimo 0).
IMPORTANTE: Esta es la fórmula CORRECTA que incluye debt_balance.
NO confundir con la función check_associate_credit_available() que hace lo mismo.';

-- Verificar que la fórmula sea consistente
DO $$
DECLARE
    v_profile RECORD;
    v_calculated DECIMAL(12,2);
    v_stored DECIMAL(12,2);
BEGIN
    RAISE NOTICE '🔍 Verificando consistencia de credit_available...';
    
    FOR v_profile IN 
        SELECT id, credit_limit, credit_used, debt_balance, credit_available
        FROM associate_profiles
    LOOP
        -- Calcular manualmente
        v_calculated := GREATEST(
            v_profile.credit_limit - v_profile.credit_used - v_profile.debt_balance, 
            0
        );
        v_stored := v_profile.credit_available;
        
        -- Comparar
        IF v_calculated != v_stored THEN
            RAISE EXCEPTION 'INCONSISTENCIA en associate_profile %: calculado=% vs stored=%',
                v_profile.id, v_calculated, v_stored;
        END IF;
    END LOOP;
    
    RAISE NOTICE '✅ Verificación exitosa: Todos los credit_available son consistentes';
END $$;

COMMIT;

-- =============================================================================
-- VALIDACIÓN POST-HOTFIX
-- =============================================================================

-- Verificar que la columna existe con la fórmula correcta
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default,
    generation_expression
FROM information_schema.columns
WHERE table_name = 'associate_profiles'
  AND column_name = 'credit_available';

-- Ejemplo de valores actuales
SELECT 
    id,
    credit_limit,
    credit_used,
    debt_balance,
    credit_available,
    credit_available AS "Fórmula Correcta: limit - used - debt"
FROM associate_profiles
ORDER BY id
LIMIT 5;

-- =============================================================================
-- FIN HOTFIX
-- =============================================================================
