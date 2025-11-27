-- =============================================================================
-- MIGRACIÓN 019: Renombrar códigos de períodos a formato más intuitivo
-- =============================================================================
-- Formato anterior: 2025-Q22 (no es claro qué mes es)
-- Formato nuevo: Nov01-2025, Nov02-2025 (mucho más legible)
-- 
-- Lógica:
-- - Período 01 del mes: Día 8-22 → Ene01, Feb01, Mar01, etc.
-- - Período 02 del mes: Día 23-7 siguiente → Ene02, Feb02, Mar02, etc.
--   (El período 02 usa el mes donde INICIA, no donde termina)
-- =============================================================================

DO $$
DECLARE
    v_record RECORD;
    v_new_code VARCHAR(20);
    v_month_abbr VARCHAR(3);
    v_period_num VARCHAR(2);
    v_start_day INTEGER;
    v_start_month INTEGER;
    v_start_year INTEGER;
    v_count INTEGER := 0;
BEGIN
    RAISE NOTICE '=== INICIANDO RENOMBRADO DE CÓDIGOS DE PERÍODOS ===';
    
    FOR v_record IN 
        SELECT id, cut_code, period_start_date, period_end_date 
        FROM cut_periods 
        ORDER BY period_start_date
    LOOP
        -- Extraer día, mes y año del inicio del período
        v_start_day := EXTRACT(DAY FROM v_record.period_start_date)::INTEGER;
        v_start_month := EXTRACT(MONTH FROM v_record.period_start_date)::INTEGER;
        v_start_year := EXTRACT(YEAR FROM v_record.period_start_date)::INTEGER;
        
        -- Determinar abreviatura del mes en español
        v_month_abbr := CASE v_start_month
            WHEN 1 THEN 'Ene'
            WHEN 2 THEN 'Feb'
            WHEN 3 THEN 'Mar'
            WHEN 4 THEN 'Abr'
            WHEN 5 THEN 'May'
            WHEN 6 THEN 'Jun'
            WHEN 7 THEN 'Jul'
            WHEN 8 THEN 'Ago'
            WHEN 9 THEN 'Sep'
            WHEN 10 THEN 'Oct'
            WHEN 11 THEN 'Nov'
            WHEN 12 THEN 'Dic'
        END;
        
        -- Determinar número del período (01 o 02)
        -- Si inicia día 8 → es período 01
        -- Si inicia día 23 → es período 02
        IF v_start_day = 8 THEN
            v_period_num := '01';
        ELSIF v_start_day = 23 THEN
            v_period_num := '02';
        ELSE
            -- Caso excepcional (no debería ocurrir)
            RAISE WARNING 'Período ID % tiene fecha de inicio inusual: día %', v_record.id, v_start_day;
            v_period_num := '??';
        END IF;
        
        -- Construir nuevo código: MesNN-YYYY (ej: Ene01-2025)
        v_new_code := v_month_abbr || v_period_num || '-' || v_start_year::TEXT;
        
        -- Actualizar el código
        UPDATE cut_periods 
        SET cut_code = v_new_code 
        WHERE id = v_record.id;
        
        v_count := v_count + 1;
        
        RAISE NOTICE '✅ ID %: % → % (% a %)', 
            v_record.id,
            v_record.cut_code, 
            v_new_code,
            TO_CHAR(v_record.period_start_date, 'DD-Mon'),
            TO_CHAR(v_record.period_end_date, 'DD-Mon');
    END LOOP;
    
    RAISE NOTICE '=== COMPLETADO: % períodos renombrados ===', v_count;
    
    -- Mostrar algunos ejemplos del nuevo formato
    RAISE NOTICE '';
    RAISE NOTICE '=== EJEMPLOS DE NUEVOS CÓDIGOS ===';
    
    FOR v_record IN 
        SELECT cut_code, period_start_date, period_end_date 
        FROM cut_periods 
        WHERE period_start_date >= '2025-11-01' 
          AND period_start_date < '2026-02-01'
        ORDER BY period_start_date
    LOOP
        RAISE NOTICE '📅 %: % a %', 
            v_record.cut_code,
            TO_CHAR(v_record.period_start_date, 'DD-Mon-YYYY'),
            TO_CHAR(v_record.period_end_date, 'DD-Mon-YYYY');
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
-- CREAR VISTA PARA FACILITAR CONSULTAS
-- =============================================================================

CREATE OR REPLACE VIEW v_cut_periods_readable AS
SELECT 
    id,
    cut_code,
    period_start_date,
    period_end_date,
    period_end_date - period_start_date + 1 as days_in_period,
    TO_CHAR(period_start_date, 'DD-Mon-YYYY') as start_formatted,
    TO_CHAR(period_end_date, 'DD-Mon-YYYY') as end_formatted,
    CASE 
        WHEN EXTRACT(DAY FROM period_start_date) = 8 THEN 'Primera Quincena'
        WHEN EXTRACT(DAY FROM period_start_date) = 23 THEN 'Segunda Quincena'
        ELSE 'Irregular'
    END as period_type,
    status_id,
    total_payments_expected,
    total_payments_received,
    total_commission
FROM cut_periods;

COMMENT ON VIEW v_cut_periods_readable IS 
'Vista con códigos de períodos en formato legible (Ene01-2025) y fechas formateadas para español';

-- Probar la vista
SELECT * FROM v_cut_periods_readable 
WHERE period_start_date >= '2025-11-01' 
  AND period_start_date < '2026-01-01'
ORDER BY period_start_date;

RAISE NOTICE '';
RAISE NOTICE '✅ Migración completada exitosamente';
RAISE NOTICE '📊 Usa la vista v_cut_periods_readable para consultas legibles';
