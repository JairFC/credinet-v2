-- =============================================================================
-- CORRECCIÓN: LIBERACIÓN DE CRÉDITO EN PAGOS DE ASOCIADO
-- =============================================================================
-- Descripción:
--   Corrige la lógica de liberación de crédito para que SOLO se libere cuando
--   el asociado PAGA a CrediCuenta, no cuando el cliente paga al asociado.
--
-- Problema identificado:
--   1. El trigger en payments.amount_paid libera crédito prematuramente
--      (cuando cliente paga a asociado, no cuando asociado paga a CrediCuenta)
--   2. Los abonos a statements NO liberan credit_used (inconsistente con debt)
--
-- Solución:
--   1. ELIMINAR: trigger_update_associate_credit_on_payment (tabla payments)
--   2. MODIFICAR: update_statement_on_payment() para liberar credit_used
--   3. MANTENER: apply_debt_payment_v2() funciona correctamente
--
-- Autor: GitHub Copilot + Análisis del usuario
-- Fecha: 2026-01-07
-- Versión: 2.0.5
-- Referencias:
--   - docs/LOGICA_LIBERACION_CREDITO_EJEMPLOS.md
--   - ANALISIS_EXHAUSTIVO_SISTEMA_PAGOS.md
-- =============================================================================

-- =============================================================================
-- PASO 1: CREAR FUNCIÓN PARA ROLLBACK (por si se necesita)
-- =============================================================================

CREATE OR REPLACE FUNCTION rollback_credit_liberation_v2()
RETURNS TEXT
LANGUAGE plpgsql
AS $$
BEGIN
    -- Recrear el trigger que eliminamos (por si se necesita rollback)
    CREATE TRIGGER trigger_update_associate_credit_on_payment
        AFTER UPDATE OF amount_paid ON payments
        FOR EACH ROW
        EXECUTE FUNCTION trigger_update_associate_credit_on_payment();
    
    RETURN 'Trigger restaurado. NOTA: Este trigger libera crédito prematuramente.';
END;
$$;

COMMENT ON FUNCTION rollback_credit_liberation_v2() IS
'⚠️ ROLLBACK: Restaura el trigger en payments (NO recomendado). Solo usar si se detectan problemas graves.';

-- =============================================================================
-- PASO 2: ELIMINAR TRIGGER Y FUNCIÓN DE payments.amount_paid
-- =============================================================================

-- Eliminar el trigger
DROP TRIGGER IF EXISTS trigger_update_associate_credit_on_payment ON payments;

-- NOTA: NO eliminamos la función porque puede ser referenciada en otros lugares
-- La dejamos disponible pero sin trigger activo
COMMENT ON FUNCTION trigger_update_associate_credit_on_payment() IS
'⚠️ DEPRECATED: Esta función liberaba crédito cuando cliente pagaba a asociado (INCORRECTO).
Trigger eliminado en v2.0.5. Crédito ahora se libera SOLO cuando asociado paga a CrediCuenta.';

-- =============================================================================
-- PASO 3: ACTUALIZAR update_statement_on_payment() PARA LIBERAR CRÉDITO
-- =============================================================================

CREATE OR REPLACE FUNCTION update_statement_on_payment()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_total_paid DECIMAL(12,2);
    v_total_owed DECIMAL(12,2);
    v_remaining DECIMAL(12,2);
    v_new_status_id INTEGER;
    v_associate_profile_id INTEGER;
BEGIN
    -- Calcular total pagado (suma de todos los abonos)
    SELECT COALESCE(SUM(payment_amount), 0)
    INTO v_total_paid
    FROM associate_statement_payments
    WHERE statement_id = NEW.statement_id;

    -- Obtener total adeudado a CrediCuenta (nuevo campo con nombre correcto)
    SELECT
        aps.total_to_credicuenta + aps.late_fee_amount,
        ap.id
    INTO v_total_owed, v_associate_profile_id
    FROM associate_payment_statements aps
    JOIN associate_profiles ap ON aps.user_id = ap.user_id
    WHERE aps.id = NEW.statement_id;

    IF v_total_owed IS NULL THEN
        RAISE EXCEPTION 'Statement % no encontrado', NEW.statement_id;
    END IF;

    v_remaining := v_total_owed - v_total_paid;

    -- Determinar nuevo estado
    IF v_remaining <= 0 THEN
        SELECT id INTO v_new_status_id FROM statement_statuses WHERE name = 'PAID';
    ELSIF v_total_paid > 0 THEN
        SELECT id INTO v_new_status_id FROM statement_statuses WHERE name = 'PARTIAL_PAID';
    END IF;

    -- Actualizar statement
    UPDATE associate_payment_statements
    SET paid_amount = v_total_paid,
        paid_date = CASE WHEN v_remaining <= 0 THEN CURRENT_DATE ELSE paid_date END,
        status_id = COALESCE(v_new_status_id, status_id),
        updated_at = CURRENT_TIMESTAMP
    WHERE id = NEW.statement_id;

    -- ✅ CORRECCIÓN CRÍTICA: Liberar crédito Y reducir deuda
    -- El asociado está pagando a CrediCuenta, se debe liberar credit_used
    UPDATE associate_profiles
    SET 
        debt_balance = GREATEST(debt_balance - NEW.payment_amount, 0),
        credit_used = GREATEST(credit_used - NEW.payment_amount, 0),
        credit_last_updated = CURRENT_TIMESTAMP
    WHERE id = v_associate_profile_id;

    RAISE NOTICE '💰 Statement #% | Pagado: $% | Debe: $% | Restante: $% | Crédito liberado: $%',
        NEW.statement_id, v_total_paid, v_total_owed, v_remaining, NEW.payment_amount;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION update_statement_on_payment() IS
'⭐ v2.0.5: Actualiza statement cuando asociado hace abono. LIBERA credit_used porque es pago a CrediCuenta.
Trigger en: associate_statement_payments (INSERT)
Actualiza: debt_balance, credit_used, credit_available (computed)';

-- =============================================================================
-- PASO 4: VALIDAR QUE apply_debt_payment_v2() NO NECESITA CAMBIOS
-- =============================================================================

-- Esta función YA libera correctamente credit_used al aplicar pagos a deuda
-- No requiere modificaciones

COMMENT ON FUNCTION apply_debt_payment_v2() IS
'✅ v2.0.4: Aplica abono del asociado a deuda acumulada usando FIFO. 
LIBERA credit_used correctamente. No requiere cambios en v2.0.5.';

-- =============================================================================
-- PASO 5: CREAR FUNCIÓN DE VALIDACIÓN
-- =============================================================================

CREATE OR REPLACE FUNCTION validate_credit_liberation_logic()
RETURNS TABLE(
    check_name TEXT,
    status TEXT,
    details TEXT
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Check 1: Verificar que el trigger en payments NO existe
    RETURN QUERY
    SELECT 
        'Trigger en payments'::TEXT,
        CASE 
            WHEN COUNT(*) = 0 THEN '✅ CORRECTO'
            ELSE '❌ ERROR'
        END::TEXT,
        CASE 
            WHEN COUNT(*) = 0 THEN 'Trigger eliminado correctamente'
            ELSE 'Trigger aún existe - debe eliminarse'
        END::TEXT
    FROM information_schema.triggers
    WHERE trigger_name = 'trigger_update_associate_credit_on_payment'
        AND event_object_table = 'payments';

    -- Check 2: Verificar que update_statement_on_payment actualiza credit_used
    RETURN QUERY
    SELECT 
        'update_statement_on_payment'::TEXT,
        CASE 
            WHEN pg_get_functiondef('update_statement_on_payment'::regproc) LIKE '%credit_used%' 
            THEN '✅ CORRECTO'
            ELSE '❌ ERROR'
        END::TEXT,
        CASE 
            WHEN pg_get_functiondef('update_statement_on_payment'::regproc) LIKE '%credit_used%'
            THEN 'Función actualiza credit_used correctamente'
            ELSE 'Función NO actualiza credit_used'
        END::TEXT;

    -- Check 3: Verificar que apply_debt_payment_v2 sigue actualizando credit_used
    RETURN QUERY
    SELECT 
        'apply_debt_payment_v2'::TEXT,
        CASE 
            WHEN pg_get_functiondef('apply_debt_payment_v2'::regproc) LIKE '%credit_used%' 
            THEN '✅ CORRECTO'
            ELSE '❌ ERROR'
        END::TEXT,
        CASE 
            WHEN pg_get_functiondef('apply_debt_payment_v2'::regproc) LIKE '%credit_used%'
            THEN 'Función actualiza credit_used correctamente'
            ELSE 'Función NO actualiza credit_used'
        END::TEXT;

    -- Check 4: Verificar trigger en associate_statement_payments
    RETURN QUERY
    SELECT 
        'Trigger en statement_payments'::TEXT,
        CASE 
            WHEN COUNT(*) > 0 THEN '✅ CORRECTO'
            ELSE '❌ ERROR'
        END::TEXT,
        CASE 
            WHEN COUNT(*) > 0 THEN 'Trigger existe y está activo'
            ELSE 'Trigger NO existe'
        END::TEXT
    FROM information_schema.triggers
    WHERE trigger_name = 'trigger_update_statement_on_payment'
        AND event_object_table = 'associate_statement_payments';

END;
$$;

COMMENT ON FUNCTION validate_credit_liberation_logic() IS
'⭐ v2.0.5: Valida que la lógica de liberación de crédito esté correctamente implementada.';

-- =============================================================================
-- PASO 6: EJECUTAR VALIDACIÓN
-- =============================================================================

SELECT * FROM validate_credit_liberation_logic();

-- =============================================================================
-- PASO 7: REGISTRO EN AUDIT LOG
-- =============================================================================

-- Crear entrada de auditoría si la tabla existe
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'migration_log') THEN
        INSERT INTO migration_log (migration_name, description, status)
        VALUES (
            'CORRECCION_LIBERACION_CREDITO_V2',
            'Corrige liberación de crédito: elimina trigger en payments, actualiza update_statement_on_payment',
            'SUCCESS'
        );
    END IF;
END $$;

-- =============================================================================
-- RESUMEN DE CAMBIOS
-- =============================================================================

/*
✅ ANTES (v2.0.4):
   - Cliente paga a asociado → Libera credit_used ❌ (incorrecto)
   - Asociado paga a statement → NO libera credit_used ❌ (inconsistente)
   - Asociado paga a deuda → Libera credit_used ✅ (correcto)

✅ AHORA (v2.0.5):
   - Cliente paga a asociado → NO libera credit_used ✅ (correcto)
   - Asociado paga a statement → Libera credit_used ✅ (correcto)
   - Asociado paga a deuda → Libera credit_used ✅ (correcto)

🎯 LÓGICA CORRECTA:
   Crédito se libera SOLO cuando asociado paga a CrediCuenta
   (vía statement o vía deuda)

📊 IMPACTO:
   - credit_available ahora refleja correctamente el crédito disponible
   - Consistencia entre abonos a statement y abonos a deuda
   - No hay liberación prematura de crédito

🔄 ROLLBACK:
   Si se necesita rollback: SELECT rollback_credit_liberation_v2();
   (NO recomendado - restaura comportamiento incorrecto)
*/
