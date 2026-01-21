-- =============================================================================
-- MIGRACIÓN 022: Corregir nomenclatura de cut_code
-- =============================================================================
-- Fecha: 2025-11-26
-- Autor: Sistema Credinet v2.0
--
-- PROBLEMA:
-- Los nombres actuales usan el día de INICIO del siguiente periodo:
--   - "Dec08-2025" inicia 23-nov, cierra 07-dic (el 08 es del siguiente)
--   - "Dec23-2025" inicia 08-dic, cierra 22-dic (el 23 es del siguiente)
--
-- SOLUCIÓN:
-- Usar el día de CIERRE del periodo actual (cuando se genera el statement):
--   - "Dec07-2025" para el periodo que cierra 07-dic
--   - "Dec22-2025" para el periodo que cierra 22-dic
--
-- RAZÓN:
-- El statement se genera el día SIGUIENTE al cierre, por lo que tiene más
-- sentido nombrar el periodo por su día de cierre que por el inicio del siguiente.
-- =============================================================================

DO $$
DECLARE
    v_record RECORD;
    v_new_code VARCHAR(20);
    v_month_abbr VARCHAR(3);
    v_close_day INTEGER;
    v_close_month INTEGER;
    v_close_year INTEGER;
    v_count INTEGER := 0;
BEGIN
    RAISE NOTICE '=== RENOMBRANDO CUT_CODES A NOMENCLATURA DE DÍA DE CIERRE ===';
    
    FOR v_record IN 
        SELECT id, cut_code, period_start_date, period_end_date 
        FROM cut_periods 
        ORDER BY period_start_date
    LOOP
        -- Extraer día, mes y año del CIERRE del período
        v_close_day := EXTRACT(DAY FROM v_record.period_end_date)::INTEGER;
        v_close_month := EXTRACT(MONTH FROM v_record.period_end_date)::INTEGER;
        v_close_year := EXTRACT(YEAR FROM v_record.period_end_date)::INTEGER;
        
        -- Determinar abreviatura del mes en inglés (3 letras, capitalizado)
        v_month_abbr := CASE v_close_month
            WHEN 1 THEN 'Jan'
            WHEN 2 THEN 'Feb'
            WHEN 3 THEN 'Mar'
            WHEN 4 THEN 'Apr'
            WHEN 5 THEN 'May'
            WHEN 6 THEN 'Jun'
            WHEN 7 THEN 'Jul'
            WHEN 8 THEN 'Aug'
            WHEN 9 THEN 'Sep'
            WHEN 10 THEN 'Oct'
            WHEN 11 THEN 'Nov'
            WHEN 12 THEN 'Dec'
        END;
        
        -- Construir nuevo código: MesDíaCierre-YYYY
        -- Ejemplos: Dec07-2025, Dec22-2025, Jan07-2026, Jan22-2026
        v_new_code := v_month_abbr || LPAD(v_close_day::TEXT, 2, '0') || '-' || v_close_year::TEXT;
        
        -- Actualizar el código
        UPDATE cut_periods 
        SET cut_code = v_new_code 
        WHERE id = v_record.id;
        
        v_count := v_count + 1;
        
        RAISE NOTICE '✅ ID %: % → % (Inicia: %, Cierra: %)', 
            v_record.id,
            v_record.cut_code, 
            v_new_code,
            TO_CHAR(v_record.period_start_date, 'DD-Mon-YYYY'),
            TO_CHAR(v_record.period_end_date, 'DD-Mon-YYYY');
    END LOOP;
    
    RAISE NOTICE '=== COMPLETADO: % períodos renombrados ===', v_count;
    
    -- Mostrar ejemplos del nuevo formato
    RAISE NOTICE '';
    RAISE NOTICE '=== EJEMPLOS DE NUEVOS CÓDIGOS (NOMENCLATURA DE CIERRE) ===';
    
    FOR v_record IN 
        SELECT cut_code, period_start_date, period_end_date 
        FROM cut_periods 
        WHERE period_start_date >= '2025-11-01' 
          AND period_start_date < '2026-02-01'
        ORDER BY period_start_date
    LOOP
        RAISE NOTICE '📅 %: Inicia %, Cierra % → Statement genera el %', 
            v_record.cut_code,
            TO_CHAR(v_record.period_start_date, 'DD-Mon-YYYY'),
            TO_CHAR(v_record.period_end_date, 'DD-Mon-YYYY'),
            TO_CHAR(v_record.period_end_date + 1, 'DD-Mon-YYYY');
    END LOOP;
END $$;

-- =============================================================================
-- VERIFICACIÓN: Validar que no haya duplicados
-- =============================================================================

DO $$
DECLARE
    v_duplicates INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_duplicates
    FROM (
        SELECT cut_code, COUNT(*) as cnt
        FROM cut_periods
        GROUP BY cut_code
        HAVING COUNT(*) > 1
    ) dups;
    
    IF v_duplicates > 0 THEN
        RAISE EXCEPTION '❌ ERROR: Se encontraron % códigos duplicados', v_duplicates;
    ELSE
        RAISE NOTICE '✅ VALIDACIÓN PASADA: No hay códigos duplicados';
    END IF;
END $$;

-- =============================================================================
-- VERIFICAR COHERENCIA: Los nombres deben reflejar el día de cierre
-- =============================================================================

DO $$
DECLARE
    v_incoherencias INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_incoherencias
    FROM cut_periods
    WHERE SUBSTRING(cut_code FROM 4 FOR 2)::INTEGER != EXTRACT(DAY FROM period_end_date)::INTEGER;
    
    IF v_incoherencias > 0 THEN
        RAISE EXCEPTION '❌ ERROR: Se encontraron % periodos con nomenclatura incoherente', v_incoherencias;
    ELSE
        RAISE NOTICE '✅ COHERENCIA VALIDADA: Todos los cut_codes reflejan el día de cierre';
    END IF;
END $$;

-- =============================================================================
-- MOSTRAR TABLA COMPARATIVA ANTES/DESPUÉS
-- =============================================================================

SELECT 
    '=== TABLA COMPARATIVA: NUEVA NOMENCLATURA ===' AS info;

SELECT 
    CASE 
        WHEN EXTRACT(DAY FROM period_end_date) IN (7, 8) THEN 'Cierre día 7-8'
        WHEN EXTRACT(DAY FROM period_end_date) IN (22, 23) THEN 'Cierre día 22-23'
    END AS tipo_cierre,
    cut_code AS nombre_periodo,
    TO_CHAR(period_start_date, 'DD-Mon-YYYY') AS inicia,
    TO_CHAR(period_end_date, 'DD-Mon-YYYY') AS cierra,
    TO_CHAR(period_end_date + 1, 'DD-Mon-YYYY') AS statement_se_genera,
    'Pagos que vencen ' || 
    CASE 
        WHEN EXTRACT(DAY FROM period_end_date) IN (7, 8) THEN 'día 15'
        WHEN EXTRACT(DAY FROM period_end_date) IN (22, 23) THEN 'último día'
    END AS contiene_pagos
FROM cut_periods
WHERE period_start_date >= '2025-12-01' AND period_start_date < '2026-03-01'
ORDER BY period_start_date;

-- =============================================================================
-- FIN MIGRACIÓN 022
-- =============================================================================
