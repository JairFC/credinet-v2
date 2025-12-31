-- =============================================================================
-- Migration 024: Cambiar nomenclatura de periodos a días de IMPRESIÓN
-- =============================================================================
-- Fecha: 2024-11-26
-- Descripción:
--   PROBLEMA ACTUAL:
--   - Nomenclatura "Dec07-2025" representa el día que CIERRA (7)
--   - Pero operativamente, lo relevante es el día que se IMPRIME (8)
--   - Usuarios confunden "07" pensando que es día de impresión
--
--   SOLUCIÓN:
--   - Cambiar nomenclatura para reflejar día de IMPRESIÓN (operativamente relevante)
--   - "Dec07-2025" → "Dec08-2025" (se imprime día 8, aunque cierra día 7)
--   - "Dec22-2025" → "Dec23-2025" (se imprime día 23, aunque cierra día 22)
--
--   JUSTIFICACIÓN:
--   - Mayor claridad operativa para usuarios
--   - Alineado con días reales de generación de statements (8 y 23)
--   - Reduce confusión en frontend y reportes
--   - Nomenclatura representa acción operativa, no detalle técnico
--
-- Impacto:
--   - ✅ Cambio cosmético, NO afecta lógica de asignación
--   - ✅ Función get_cut_period_for_payment() sigue funcionando igual
--   - ✅ Triggers y simulaciones no requieren cambios
--   - ⚠️ Requiere actualizar documentación con nueva nomenclatura
--   - ⚠️ Frontend debe refrescar datos (no hardcodear nombres)
--
-- Validación:
--   SELECT cut_code, period_end_date, period_end_date + 1 as dia_impresion
--   FROM cut_periods
--   WHERE cut_code LIKE '%08-%' OR cut_code LIKE '%23-%'
--   LIMIT 10;
-- =============================================================================

BEGIN;

-- =============================================================================
-- PASO 1: Mostrar estado ANTES del cambio
-- =============================================================================
DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'ESTADO ANTES DEL CAMBIO:';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Ejemplo periodos actuales:';
    RAISE NOTICE '  - Dec07-2025 (cierra día 7, imprime día 8)';
    RAISE NOTICE '  - Dec22-2025 (cierra día 22, imprime día 23)';
    RAISE NOTICE '';
END $$;

-- =============================================================================
-- PASO 2: Cambiar periodos que cierran día 7 → Nueva nomenclatura con día 8
-- =============================================================================
UPDATE cut_periods
SET cut_code = 
    CASE 
        WHEN cut_code LIKE '%07-%' THEN 
            REPLACE(cut_code, '07-', '08-')
        ELSE cut_code
    END
WHERE EXTRACT(DAY FROM period_end_date) = 7;

-- =============================================================================
-- PASO 3: Cambiar periodos que cierran día 22 → Nueva nomenclatura con día 23
-- =============================================================================
UPDATE cut_periods
SET cut_code = 
    CASE 
        WHEN cut_code LIKE '%22-%' THEN 
            REPLACE(cut_code, '22-', '23-')
        ELSE cut_code
    END
WHERE EXTRACT(DAY FROM period_end_date) = 22;

-- =============================================================================
-- PASO 4: Validar cambios aplicados
-- =============================================================================
DO $$
DECLARE
    v_count_08 INTEGER;
    v_count_23 INTEGER;
    v_count_07 INTEGER;
    v_count_22 INTEGER;
BEGIN
    -- Contar periodos con nueva nomenclatura
    SELECT COUNT(*) INTO v_count_08
    FROM cut_periods
    WHERE cut_code LIKE '%08-%';
    
    SELECT COUNT(*) INTO v_count_23
    FROM cut_periods
    WHERE cut_code LIKE '%23-%';
    
    -- Verificar que no queden periodos con nomenclatura antigua
    SELECT COUNT(*) INTO v_count_07
    FROM cut_periods
    WHERE cut_code LIKE '%07-%';
    
    SELECT COUNT(*) INTO v_count_22
    FROM cut_periods
    WHERE cut_code LIKE '%22-%';
    
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'VALIDACIÓN DE CAMBIOS:';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Periodos con nomenclatura nueva:';
    RAISE NOTICE '  - %%08-YYYY: % periodos', v_count_08;
    RAISE NOTICE '  - %%23-YYYY: % periodos', v_count_23;
    RAISE NOTICE '';
    RAISE NOTICE 'Periodos con nomenclatura antigua (debe ser 0):';
    RAISE NOTICE '  - %%07-YYYY: % periodos', v_count_07;
    RAISE NOTICE '  - %%22-YYYY: % periodos', v_count_22;
    RAISE NOTICE '';
    
    IF v_count_07 > 0 OR v_count_22 > 0 THEN
        RAISE EXCEPTION 'ERROR: Aún existen periodos con nomenclatura antigua';
    END IF;
    
    IF v_count_08 = 0 OR v_count_23 = 0 THEN
        RAISE WARNING 'ADVERTENCIA: No se encontraron periodos con la nueva nomenclatura';
    END IF;
    
    RAISE NOTICE '✅ Validación exitosa: Todos los periodos actualizados correctamente';
END $$;

-- =============================================================================
-- PASO 5: Mostrar ejemplos de periodos actualizados
-- =============================================================================
DO $$
DECLARE
    v_example RECORD;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'EJEMPLOS DE PERIODOS ACTUALIZADOS:';
    RAISE NOTICE '========================================';
    
    FOR v_example IN 
        SELECT 
            cut_code,
            TO_CHAR(period_start_date, 'DD/Mon/YY') as inicia,
            TO_CHAR(period_end_date, 'DD/Mon/YY') as cierra,
            TO_CHAR(period_end_date + 1, 'DD/Mon/YY') as imprime
        FROM cut_periods
        WHERE (cut_code LIKE '%08-%' OR cut_code LIKE '%23-%')
          AND EXTRACT(YEAR FROM period_start_date) = 2025
        ORDER BY period_start_date
        LIMIT 6
    LOOP
        RAISE NOTICE 'Periodo: % | Cierra: % | Imprime: %', 
            v_example.cut_code, v_example.cierra, v_example.imprime;
    END LOOP;
    
    RAISE NOTICE '';
END $$;

-- =============================================================================
-- PASO 6: Actualizar comentario en tabla cut_periods
-- =============================================================================
COMMENT ON TABLE cut_periods IS 
'✅ ACTUALIZADO (2024-11-26): Tabla de periodos de corte con nomenclatura basada en días de IMPRESIÓN.
Formato: MonDD-YYYY donde DD es el día de IMPRESIÓN de statements (8 o 23).
Ejemplo: Dec08-2025 = Periodo que se imprime el 8 de diciembre (cierra el 7).
Los períodos se imprimen:
- Día 8: Imprime pagos que vencen el día 15
- Día 23: Imprime pagos que vencen el último día del mes';

COMMIT;

-- =============================================================================
-- VALIDACIÓN FINAL (ejecutar manualmente después del commit)
-- =============================================================================
-- SELECT 
--     cut_code,
--     period_start_date,
--     period_end_date,
--     EXTRACT(DAY FROM period_end_date) as dia_cierre,
--     period_end_date + 1 as dia_impresion,
--     CASE 
--         WHEN cut_code LIKE '%08-%' THEN '✅ Nomenclatura correcta (imprime día 8)'
--         WHEN cut_code LIKE '%23-%' THEN '✅ Nomenclatura correcta (imprime día 23)'
--         ELSE '❌ Nomenclatura incorrecta'
--     END as validacion
-- FROM cut_periods
-- WHERE EXTRACT(YEAR FROM period_start_date) = 2025
-- ORDER BY period_start_date;
