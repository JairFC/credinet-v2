-- =============================================================================
-- Migration 025: Agregar estados DRAFT y FINALIZED para sistema de doble corte
-- =============================================================================
-- Fecha: 2024-11-26
-- Descripción:
--   SISTEMA DE DOBLE CORTE:
--   1. CORTE AUTOMÁTICO (00:00 días 8 y 23) → Estado DRAFT (editable)
--   2. CORTE MANUAL (horario laboral) → Estado FINALIZED (bloqueado)
--
--   FLUJO:
--   - 00:00: Sistema genera statements automáticamente en DRAFT
--   - Horario laboral: Admin revisa y ajusta statements (permitido en DRAFT)
--   - Admin ejecuta "Finalizar Corte" manualmente
--   - Statements pasan a FINALIZED (ya no editables)
--   - Asociados reciben notificaciones
--
--   NUEVOS ESTADOS:
--   - DRAFT: Vista preliminar después de corte automático (editable)
--   - FINALIZED: Versión definitiva después de corte manual (bloqueada)
--
-- Dependencias:
--   - Migration 024 (nomenclatura Dec08, Dec23)
--   - Tabla statement_statuses existente
--
-- Validación:
--   SELECT * FROM statement_statuses ORDER BY display_order;
-- =============================================================================

BEGIN;

-- =============================================================================
-- PASO 1: Insertar nuevos estados
-- =============================================================================

INSERT INTO statement_statuses (id, name, description, is_paid, display_order, color_code, created_at, updated_at)
VALUES 
    (
        6,
        'DRAFT',
        'Corte automático 00:00 - Vista preliminar editable. Admin puede ajustar antes de finalizar.',
        false,
        0,  -- Primer estado (antes de GENERATED)
        '#FFC107',  -- Amarillo (warning)
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP
    ),
    (
        7,
        'FINALIZED',
        'Corte manual - Versión definitiva bloqueada. No se permiten más cambios.',
        false,
        1,  -- Segundo estado (antes de SENT)
        '#2196F3',  -- Azul (info)
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP
    )
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    display_order = EXCLUDED.display_order,
    color_code = EXCLUDED.color_code,
    updated_at = CURRENT_TIMESTAMP;

-- =============================================================================
-- PASO 2: Reordenar display_order de estados existentes
-- =============================================================================

-- Ajustar orden de estados existentes para hacer espacio a DRAFT y FINALIZED
UPDATE statement_statuses SET display_order = 2 WHERE id = 1;  -- GENERATED
UPDATE statement_statuses SET display_order = 3 WHERE id = 2;  -- SENT
UPDATE statement_statuses SET display_order = 4 WHERE id = 3;  -- PAID
UPDATE statement_statuses SET display_order = 5 WHERE id = 4;  -- PARTIAL_PAID
UPDATE statement_statuses SET display_order = 6 WHERE id = 5;  -- OVERDUE

-- =============================================================================
-- PASO 3: Validar estados insertados
-- =============================================================================

DO $$
DECLARE
    v_draft_exists BOOLEAN;
    v_finalized_exists BOOLEAN;
    v_total_count INTEGER;
BEGIN
    -- Verificar existencia de nuevos estados
    SELECT EXISTS(SELECT 1 FROM statement_statuses WHERE id = 6 AND name = 'DRAFT')
    INTO v_draft_exists;
    
    SELECT EXISTS(SELECT 1 FROM statement_statuses WHERE id = 7 AND name = 'FINALIZED')
    INTO v_finalized_exists;
    
    SELECT COUNT(*) INTO v_total_count FROM statement_statuses;
    
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'VALIDACIÓN DE NUEVOS ESTADOS:';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Estado DRAFT (ID 6):      %', CASE WHEN v_draft_exists THEN '✅ Creado' ELSE '❌ Error' END;
    RAISE NOTICE 'Estado FINALIZED (ID 7):  %', CASE WHEN v_finalized_exists THEN '✅ Creado' ELSE '❌ Error' END;
    RAISE NOTICE 'Total de estados:         %', v_total_count;
    RAISE NOTICE '';
    
    IF NOT v_draft_exists OR NOT v_finalized_exists THEN
        RAISE EXCEPTION 'ERROR: No se pudieron crear los nuevos estados';
    END IF;
    
    IF v_total_count < 7 THEN
        RAISE WARNING 'ADVERTENCIA: Se esperaban al menos 7 estados, se encontraron %', v_total_count;
    END IF;
END $$;

-- =============================================================================
-- PASO 4: Mostrar tabla de estados actualizada
-- =============================================================================

DO $$
DECLARE
    v_estado RECORD;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'ESTADOS DE STATEMENTS (ORDENADOS):';
    RAISE NOTICE '========================================';
    
    FOR v_estado IN 
        SELECT 
            id,
            name,
            description,
            display_order,
            color_code,
            CASE 
                WHEN name IN ('DRAFT', 'FINALIZED') THEN '🆕 NUEVO'
                ELSE ''
            END as badge
        FROM statement_statuses
        ORDER BY display_order
    LOOP
        RAISE NOTICE '% | % - % | Orden: % | Color: %',
            v_estado.badge,
            v_estado.id,
            v_estado.name,
            v_estado.display_order,
            v_estado.color_code;
    END LOOP;
    
    RAISE NOTICE '';
END $$;

-- =============================================================================
-- PASO 5: Crear función de corte automático (ejecuta a las 00:00)
-- =============================================================================

CREATE OR REPLACE FUNCTION auto_generate_statements_at_midnight()
RETURNS TABLE(
    period_code VARCHAR(20),
    statements_generated INTEGER,
    total_amount NUMERIC(12,2)
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_current_day INTEGER;
    v_is_cut_day BOOLEAN;
    v_period_id INTEGER;
    v_period_code VARCHAR(20);
    v_count INTEGER;
    v_total NUMERIC(12,2);
BEGIN
    v_current_day := EXTRACT(DAY FROM CURRENT_DATE);
    
    -- Verificar si es día de corte (8 o 23)
    v_is_cut_day := v_current_day IN (8, 23);
    
    IF NOT v_is_cut_day THEN
        RAISE NOTICE 'Hoy no es día de corte (día %, esperado 8 o 23)', v_current_day;
        RETURN;
    END IF;
    
    -- Obtener periodo correspondiente a hoy (día de impresión)
    SELECT id, cut_code INTO v_period_id, v_period_code
    FROM cut_periods
    WHERE period_end_date + 1 = CURRENT_DATE;
    
    IF v_period_id IS NULL THEN
        RAISE EXCEPTION 'No se encontró periodo para hoy: %', CURRENT_DATE;
    END IF;
    
    RAISE NOTICE '🔄 Iniciando corte automático para periodo: %', v_period_code;
    
    -- Generar statements automáticos con estado DRAFT (ID 6)
    INSERT INTO associate_payment_statements (
        cut_period_id,
        user_id,
        statement_number,
        total_payments_count,
        total_amount_collected,
        total_commission_owed,
        commission_rate_applied,
        status_id,
        generated_date,
        due_date
    )
    SELECT 
        v_period_id,
        l.associate_user_id,
        CONCAT(v_period_code, '-A', l.associate_user_id) as statement_number,
        COUNT(p.id) as total_payments,
        SUM(p.expected_amount) as total_amount,
        SUM(p.commission_amount) as total_commission,
        l.commission_rate,
        6,  -- DRAFT
        CURRENT_DATE,
        CURRENT_DATE + INTERVAL '7 days'
    FROM payments p
    JOIN loans l ON p.loan_id = l.id
    WHERE p.cut_period_id = v_period_id
      AND p.status_id = 1  -- PENDING
      AND l.associate_user_id IS NOT NULL
    GROUP BY v_period_id, l.associate_user_id, v_period_code, l.commission_rate
    ON CONFLICT DO NOTHING;
    
    GET DIAGNOSTICS v_count = ROW_COUNT;
    
    -- Calcular total generado
    SELECT COALESCE(SUM(total_amount_collected), 0) INTO v_total
    FROM associate_payment_statements
    WHERE cut_period_id = v_period_id AND status_id = 6;
    
    RAISE NOTICE '✅ Corte automático completado: % statements en DRAFT, Total: $%',
        v_count, v_total;
    
    -- Retornar resumen
    RETURN QUERY SELECT v_period_code, v_count, v_total;
END;
$$;

COMMENT ON FUNCTION auto_generate_statements_at_midnight() IS
'✅ CORTE AUTOMÁTICO (00:00 hrs - Días 8 y 23)
Genera statements automáticamente en estado DRAFT (editable).
Admin puede revisar y ajustar antes de ejecutar corte manual.
Ejecutar con cron: 0 0 * * * SELECT auto_generate_statements_at_midnight()';

-- =============================================================================
-- PASO 6: Crear función de corte manual (ejecuta en horario laboral)
-- =============================================================================

CREATE OR REPLACE FUNCTION finalize_statements_manual(
    p_cut_period_id INTEGER
)
RETURNS TABLE(
    finalized_count INTEGER,
    total_finalized NUMERIC(12,2),
    period_code VARCHAR(20)
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_draft_count INTEGER;
    v_updated_count INTEGER;
    v_total NUMERIC(12,2);
    v_period_code VARCHAR(20);
BEGIN
    -- Obtener información del periodo
    SELECT cut_code INTO v_period_code
    FROM cut_periods
    WHERE id = p_cut_period_id;
    
    IF v_period_code IS NULL THEN
        RAISE EXCEPTION 'Periodo con ID % no encontrado', p_cut_period_id;
    END IF;
    
    -- Verificar que existan statements en DRAFT
    SELECT COUNT(*) INTO v_draft_count
    FROM associate_payment_statements
    WHERE cut_period_id = p_cut_period_id
      AND status_id = 6;  -- DRAFT
    
    IF v_draft_count = 0 THEN
        RAISE EXCEPTION 'No hay statements en DRAFT para finalizar en periodo %', v_period_code;
    END IF;
    
    RAISE NOTICE '🔒 Finalizando % statements en periodo %', v_draft_count, v_period_code;
    
    -- Cambiar estado de DRAFT (6) → FINALIZED (7)
    UPDATE associate_payment_statements
    SET 
        status_id = 7,  -- FINALIZED
        updated_at = CURRENT_TIMESTAMP
    WHERE cut_period_id = p_cut_period_id
      AND status_id = 6;
    
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    
    -- Calcular total finalizado
    SELECT COALESCE(SUM(total_amount_collected), 0) INTO v_total
    FROM associate_payment_statements
    WHERE cut_period_id = p_cut_period_id AND status_id = 7;
    
    RAISE NOTICE '✅ Corte manual completado: % statements FINALIZADOS (bloqueados), Total: $%',
        v_updated_count, v_total;
    
    RAISE NOTICE '📧 TODO: Enviar notificaciones a asociados';
    
    -- Retornar resumen
    RETURN QUERY SELECT v_updated_count, v_total, v_period_code;
END;
$$;

COMMENT ON FUNCTION finalize_statements_manual(INTEGER) IS
'✅ CORTE MANUAL (Horario Laboral - Admin ejecuta)
Cambia statements de DRAFT → FINALIZED (bloqueados).
Después de esto, NO se permiten modificaciones.
Admin debe ejecutar manualmente después de revisar statements en DRAFT.';

-- =============================================================================
-- PASO 7: Crear restricción CHECK para validar transiciones de estado
-- =============================================================================

-- Nota: Esta restricción se validará en backend, no en base de datos
-- para permitir mayor flexibilidad y mejores mensajes de error

COMMENT ON TABLE associate_payment_statements IS
'✅ ACTUALIZADO (2024-11-26): Tabla de statements con sistema de doble corte.
Estados principales:
- DRAFT (6): Generado automáticamente a las 00:00, editable
- FINALIZED (7): Finalizado manualmente por admin, bloqueado
- SENT (2): Enviado a asociados después de finalizar
- PAID (3): Pagado completamente
Transiciones permitidas: DRAFT → FINALIZED → SENT → PAID/PARTIAL_PAID → OVERDUE';

-- =============================================================================
-- PASO 8: Validación final
-- =============================================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ MIGRATION 025 COMPLETADA';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Estados agregados:       DRAFT (6), FINALIZED (7)';
    RAISE NOTICE 'Funciones creadas:       auto_generate_statements_at_midnight()';
    RAISE NOTICE '                         finalize_statements_manual(period_id)';
    RAISE NOTICE 'Próximo paso:            Configurar cron job para corte automático';
    RAISE NOTICE '';
    RAISE NOTICE 'TESTING:';
    RAISE NOTICE '  -- Ver estados actuales:';
    RAISE NOTICE '  SELECT * FROM statement_statuses ORDER BY display_order;';
    RAISE NOTICE '';
    RAISE NOTICE '  -- Simular corte automático (si hoy es día 8 o 23):';
    RAISE NOTICE '  SELECT * FROM auto_generate_statements_at_midnight();';
    RAISE NOTICE '';
    RAISE NOTICE '  -- Finalizar statements de un periodo:';
    RAISE NOTICE '  SELECT * FROM finalize_statements_manual(46);  -- ID del periodo';
    RAISE NOTICE '';
END $$;

COMMIT;
