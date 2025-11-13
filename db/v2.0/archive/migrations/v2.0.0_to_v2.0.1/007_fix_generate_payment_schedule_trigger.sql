-- ============================================================================
-- MIGRACIÓN 007: Reescribir Trigger generate_payment_schedule()
-- ============================================================================
-- Propósito: Corregir el trigger para que:
--            1. Use valores pre-calculados de loans (biweekly_payment)
--            2. Llame a generate_amortization_schedule() para desglose
--            3. Inserte payments con TODOS los campos completos
--            4. Valide consistencia matemática (SUM = total_payment)
--
-- Fecha: 2025-11-05
-- Versión: 2.0
-- Estado: ✅ LISTA PARA APLICAR
--
-- CRÍTICO: Este trigger es el corazón del sistema de pagos.
--          Genera el cronograma completo cuando un préstamo es aprobado.
-- ============================================================================

BEGIN;

-- ============================================================================
-- PASO 1: Eliminar trigger antiguo
-- ============================================================================

DROP TRIGGER IF EXISTS trigger_generate_payment_schedule ON loans;

-- ============================================================================
-- PASO 2: Crear función mejorada generate_payment_schedule()
-- ============================================================================

CREATE OR REPLACE FUNCTION generate_payment_schedule()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $function$
DECLARE
    v_approval_date DATE;
    v_first_payment_date DATE;
    v_approved_status_id INTEGER;
    v_pending_status_id INTEGER;
    v_amortization_row RECORD;
    v_period_id INTEGER;
    v_total_inserted INTEGER := 0;
    v_sum_expected DECIMAL(12,2) := 0;
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
BEGIN
    -- ==========================================================================
    -- VALIDACIÓN INICIAL: Verificar que este evento es una aprobación
    -- ==========================================================================
    
    -- Obtener IDs de estados
    SELECT id INTO v_approved_status_id 
    FROM loan_statuses 
    WHERE name = 'APPROVED';
    
    SELECT id INTO v_pending_status_id 
    FROM payment_statuses 
    WHERE name = 'PENDING';
    
    IF v_approved_status_id IS NULL THEN
        RAISE EXCEPTION 'CRITICAL: loan_statuses.APPROVED no encontrado';
    END IF;
    
    IF v_pending_status_id IS NULL THEN
        RAISE EXCEPTION 'CRITICAL: payment_statuses.PENDING no encontrado';
    END IF;
    
    -- Solo ejecutar si el préstamo acaba de ser aprobado
    IF NEW.status_id = v_approved_status_id 
       AND (OLD.status_id IS NULL OR OLD.status_id != v_approved_status_id) 
    THEN
        v_start_time := CLOCK_TIMESTAMP();
        
        -- ======================================================================
        -- VALIDACIONES DE NEGOCIO
        -- ======================================================================
        
        -- Validar: approved_at debe existir
        IF NEW.approved_at IS NULL THEN
            RAISE EXCEPTION 'CRITICAL: Préstamo % marcado como APPROVED pero approved_at es NULL', 
                NEW.id;
        END IF;
        
        -- Validar: term_biweeks válido
        IF NEW.term_biweeks IS NULL OR NEW.term_biweeks <= 0 THEN
            RAISE EXCEPTION 'CRITICAL: Préstamo % tiene term_biweeks inválido: %', 
                NEW.id, NEW.term_biweeks;
        END IF;
        
        -- ✅ CRÍTICO: Validar que los campos calculados existen
        IF NEW.biweekly_payment IS NULL THEN
            RAISE EXCEPTION 'CRITICAL: Préstamo % no tiene biweekly_payment calculado. El préstamo debe ser creado con profile_code o tener valores calculados manualmente.',
                NEW.id;
        END IF;
        
        IF NEW.total_payment IS NULL THEN
            RAISE EXCEPTION 'CRITICAL: Préstamo % no tiene total_payment calculado.',
                NEW.id;
        END IF;
        
        IF NEW.commission_per_payment IS NULL THEN
            RAISE WARNING 'Préstamo % no tiene commission_per_payment. Se usará 0 por defecto.',
                NEW.id;
        END IF;
        
        -- ======================================================================
        -- CALCULAR PRIMERA FECHA DE PAGO USANDO EL ORÁCULO
        -- ======================================================================
        
        v_approval_date := NEW.approved_at::DATE;
        
        RAISE NOTICE '🎯 Generando schedule para préstamo %:', NEW.id;
        RAISE NOTICE '   - Capital: $%', NEW.amount;
        RAISE NOTICE '   - Plazo: % quincenas', NEW.term_biweeks;
        RAISE NOTICE '   - Pago quincenal: $%', NEW.biweekly_payment;
        RAISE NOTICE '   - Total a pagar: $%', NEW.total_payment;
        RAISE NOTICE '   - Aprobado: %', v_approval_date;
        
        -- ✅ Usar el oráculo del doble calendario
        v_first_payment_date := calculate_first_payment_date(v_approval_date);
        
        RAISE NOTICE '📅 Primera fecha de pago: % (aprobado el %)', 
            v_first_payment_date, v_approval_date;
        
        -- ======================================================================
        -- GENERAR CRONOGRAMA COMPLETO CON DESGLOSE
        -- ======================================================================
        
        -- ✅ Llamar a generate_amortization_schedule() para obtener desglose completo
        FOR v_amortization_row IN
            SELECT 
                periodo,              -- Número de pago (1, 2, 3, ...)
                fecha_pago,           -- Fecha de vencimiento (15 o último día)
                pago_cliente,         -- Monto esperado (capital + interés)
                interes_cliente,      -- Interés del periodo
                capital_cliente,      -- Abono a capital del periodo
                saldo_pendiente,      -- Saldo restante después del pago
                comision_socio,       -- Comisión del asociado
                pago_socio            -- Pago neto al asociado
            FROM generate_amortization_schedule(
                NEW.amount,                           -- Capital del préstamo
                NEW.biweekly_payment,                 -- ✅ Pago quincenal calculado
                NEW.term_biweeks,                     -- Plazo en quincenas
                COALESCE(NEW.commission_per_payment, 0),  -- Comisión por pago
                v_first_payment_date                  -- ✅ Primera fecha del oráculo
            )
        LOOP
            -- ==================================================================
            -- BUSCAR PERIODO ADMINISTRATIVO (cut_period)
            -- ==================================================================
            
            -- Buscar el periodo administrativo que contiene esta fecha de vencimiento
            SELECT id INTO v_period_id
            FROM cut_periods
            WHERE period_start_date <= v_amortization_row.fecha_pago
              AND period_end_date >= v_amortization_row.fecha_pago
            ORDER BY period_start_date DESC
            LIMIT 1;
            
            IF v_period_id IS NULL THEN
                RAISE WARNING 'No se encontró cut_period para fecha %. Insertando pago con period_id = NULL. Verifique que cut_periods estén creados para todo el año.',
                    v_amortization_row.fecha_pago;
            END IF;
            
            -- ==================================================================
            -- INSERTAR PAGO CON TODOS LOS CAMPOS
            -- ==================================================================
            
            INSERT INTO payments (
                loan_id,
                payment_number,
                expected_amount,
                amount_paid,
                interest_amount,
                principal_amount,
                commission_amount,
                associate_payment,
                balance_remaining,
                payment_date,
                payment_due_date,
                is_late,
                status_id,
                cut_period_id,
                created_at,
                updated_at
            ) VALUES (
                NEW.id,                                    -- FK al préstamo
                v_amortization_row.periodo,                -- Número secuencial (1, 2, 3, ...)
                v_amortization_row.pago_cliente,           -- ✅ Monto esperado (con interés)
                0.00,                                      -- Aún no ha pagado nada
                v_amortization_row.interes_cliente,        -- ✅ Interés del periodo
                v_amortization_row.capital_cliente,        -- ✅ Abono a capital
                v_amortization_row.comision_socio,         -- ✅ Comisión del asociado
                v_amortization_row.pago_socio,             -- ✅ Pago neto al asociado
                v_amortization_row.saldo_pendiente,        -- ✅ Saldo restante
                v_amortization_row.fecha_pago,             -- payment_date inicial = due_date
                v_amortization_row.fecha_pago,             -- ✅ Fecha de vencimiento
                false,                                     -- No está atrasado (aún)
                v_pending_status_id,                       -- Estado: PENDING
                v_period_id,                               -- ✅ FK al periodo administrativo
                CURRENT_TIMESTAMP,                         -- created_at
                CURRENT_TIMESTAMP                          -- updated_at
            );
            
            v_total_inserted := v_total_inserted + 1;
            v_sum_expected := v_sum_expected + v_amortization_row.pago_cliente;
            
            -- Log de progreso cada 5 pagos
            IF v_amortization_row.periodo % 5 = 0 THEN
                RAISE DEBUG 'Progreso: % de % pagos insertados', 
                    v_amortization_row.periodo, NEW.term_biweeks;
            END IF;
        END LOOP;
        
        -- ======================================================================
        -- VALIDACIONES DE CONSISTENCIA FINAL
        -- ======================================================================
        
        v_end_time := CLOCK_TIMESTAMP();
        
        -- Validar: Se insertaron todos los pagos esperados
        IF v_total_inserted != NEW.term_biweeks THEN
            RAISE EXCEPTION 'INCONSISTENCIA: Se insertaron % pagos pero se esperaban %. Préstamo %. Revisar generate_amortization_schedule().',
                v_total_inserted, NEW.term_biweeks, NEW.id;
        END IF;
        
        -- ✅ VALIDAR: SUM(expected_amount) debe ser igual a loans.total_payment
        -- Tolerancia de $1.00 para errores de redondeo
        IF ABS(v_sum_expected - NEW.total_payment) > 1.00 THEN
            RAISE EXCEPTION 'INCONSISTENCIA MATEMÁTICA: SUM(expected_amount) = $% pero loans.total_payment = $%. Diferencia: $%. Préstamo %. Esto indica un error en los cálculos de generate_amortization_schedule().',
                v_sum_expected, NEW.total_payment, 
                (v_sum_expected - NEW.total_payment), NEW.id;
        END IF;
        
        -- ======================================================================
        -- LOG DE ÉXITO
        -- ======================================================================
        
        RAISE NOTICE '✅ Schedule generado exitosamente:';
        RAISE NOTICE '   - Pagos insertados: %', v_total_inserted;
        RAISE NOTICE '   - Total esperado: $%', v_sum_expected;
        RAISE NOTICE '   - Total préstamo: $%', NEW.total_payment;
        RAISE NOTICE '   - Diferencia: $%', (v_sum_expected - NEW.total_payment);
        RAISE NOTICE '   - Tiempo: % ms', 
            EXTRACT(MILLISECONDS FROM (v_end_time - v_start_time));
        
    END IF;
    
    RETURN NEW;
    
EXCEPTION
    WHEN OTHERS THEN
        -- Log detallado del error
        RAISE EXCEPTION 'ERROR CRÍTICO al generar payment schedule para préstamo %: % (%). SQLState: %, Context: %',
            NEW.id, SQLERRM, SQLSTATE, SQLSTATE, 
            coalesce(PG_EXCEPTION_CONTEXT, 'No context');
        RETURN NULL;
END;
$function$;

COMMENT ON FUNCTION generate_payment_schedule() IS
'Trigger que genera el cronograma de pagos cuando un préstamo es aprobado.
✅ VERSIÓN 2.0 - CORREGIDA
- Usa loans.biweekly_payment (pre-calculado)
- Llama a generate_amortization_schedule() para desglose completo
- Inserta payments con TODOS los campos (payment_number, expected_amount, etc.)
- Valida consistencia matemática: SUM(expected_amount) = loans.total_payment
- Mapea correctamente payment_due_date a cut_period_id
- Implementa el sistema de doble calendario (15/último día vs 8-22/23-7)';

-- ============================================================================
-- PASO 3: Crear trigger
-- ============================================================================

CREATE TRIGGER trigger_generate_payment_schedule
    AFTER UPDATE OF status_id ON loans
    FOR EACH ROW
    EXECUTE FUNCTION generate_payment_schedule();

COMMENT ON TRIGGER trigger_generate_payment_schedule ON loans IS
'Trigger que genera automáticamente el cronograma de pagos cuando un préstamo es aprobado.
Se ejecuta AFTER UPDATE OF status_id para detectar cambios a APPROVED.';

-- ============================================================================
-- PASO 4: Verificación
-- ============================================================================

DO $$
DECLARE
    v_trigger_exists BOOLEAN;
    v_function_exists BOOLEAN;
BEGIN
    -- Verificar que el trigger existe
    SELECT EXISTS (
        SELECT 1 
        FROM pg_trigger 
        WHERE tgname = 'trigger_generate_payment_schedule'
    ) INTO v_trigger_exists;
    
    IF NOT v_trigger_exists THEN
        RAISE EXCEPTION 'FALLO: Trigger trigger_generate_payment_schedule no fue creado';
    END IF;
    
    -- Verificar que la función existe
    SELECT EXISTS (
        SELECT 1 
        FROM pg_proc 
        WHERE proname = 'generate_payment_schedule'
    ) INTO v_function_exists;
    
    IF NOT v_function_exists THEN
        RAISE EXCEPTION 'FALLO: Función generate_payment_schedule() no existe';
    END IF;
    
    RAISE NOTICE '✅ Migración completada exitosamente:';
    RAISE NOTICE '   - Función generate_payment_schedule() actualizada';
    RAISE NOTICE '   - Trigger trigger_generate_payment_schedule recreado';
    RAISE NOTICE '   - Sistema listo para generar cronogramas completos';
    RAISE NOTICE '';
    RAISE NOTICE '⚠️  IMPORTANTE:';
    RAISE NOTICE '   Los préstamos EXISTENTES que ya tienen payments generados NO se actualizarán automáticamente.';
    RAISE NOTICE '   Si necesitas regenerarlos, usa el script de migración de datos (migration 008).';
END;
$$;

COMMIT;

-- ============================================================================
-- ROLLBACK (por si necesitas revertir la migración)
-- ============================================================================
-- COMENTADO - Descomenta solo si necesitas hacer rollback

/*
BEGIN;

-- Restaurar trigger y función antigua
-- NOTA: Necesitarías tener un backup de la versión anterior

-- Eliminar trigger nuevo
DROP TRIGGER IF EXISTS trigger_generate_payment_schedule ON loans;

-- Restaurar función anterior (ejemplo simplificado)
-- Aquí irías el código de la función ANTERIOR

-- Recrear trigger con función anterior
CREATE TRIGGER trigger_generate_payment_schedule
    AFTER UPDATE OF status_id ON loans
    FOR EACH ROW
    EXECUTE FUNCTION generate_payment_schedule();

COMMIT;
*/

-- ============================================================================
-- FIN DE MIGRACIÓN 007
-- ============================================================================
