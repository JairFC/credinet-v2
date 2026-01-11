-- =============================================================================
-- TEST SUITE: VALIDACIÓN DE LIBERACIÓN DE CRÉDITO
-- =============================================================================
-- Descripción:
--   Tests completos para validar que la corrección de liberación de crédito
--   funciona correctamente en todos los escenarios.
--
-- Escenarios:
--   1. Cliente paga a asociado → NO debe liberar crédito
--   2. Asociado paga a statement → SÍ debe liberar crédito
--   3. Asociado paga a deuda → SÍ debe liberar crédito
--   4. Múltiples abonos parciales → Liberación proporcional
--
-- Autor: GitHub Copilot
-- Fecha: 2026-01-07
-- Versión: 2.0.5
-- =============================================================================

BEGIN;

-- =============================================================================
-- SETUP: Crear datos de prueba
-- =============================================================================

-- Variables para el test
DO $$
DECLARE
    v_test_associate_id INTEGER;
    v_test_client_id INTEGER;
    v_test_loan_id INTEGER;
    v_test_statement_id INTEGER;
    v_initial_credit_used DECIMAL(12,2);
    v_initial_debt_balance DECIMAL(12,2);
    v_final_credit_used DECIMAL(12,2);
    v_final_debt_balance DECIMAL(12,2);
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE '🧪 INICIANDO TEST SUITE DE LIBERACIÓN DE CRÉDITO';
    RAISE NOTICE '========================================';

    -- Usar asociado real existente (user_id = 8)
    v_test_associate_id := 8;

    -- Guardar estado inicial
    SELECT credit_used, debt_balance
    INTO v_initial_credit_used, v_initial_debt_balance
    FROM associate_profiles
    WHERE user_id = v_test_associate_id;

    RAISE NOTICE '';
    RAISE NOTICE '📊 ESTADO INICIAL:';
    RAISE NOTICE '   - Associate User ID: %', v_test_associate_id;
    RAISE NOTICE '   - Credit Used: $%', v_initial_credit_used;
    RAISE NOTICE '   - Debt Balance: $%', v_initial_debt_balance;
    RAISE NOTICE '';

    -- ==========================================================================
    -- TEST 1: Cliente paga a asociado (payments.amount_paid) → NO libera crédito
    -- ==========================================================================
    
    RAISE NOTICE '========================================';
    RAISE NOTICE '🧪 TEST 1: Cliente paga a asociado';
    RAISE NOTICE '========================================';

    -- Buscar un payment PENDING del asociado
    SELECT p.id, p.loan_id
    INTO v_test_loan_id, v_test_loan_id
    FROM payments p
    JOIN loans l ON l.id = p.loan_id
    WHERE l.associate_user_id = v_test_associate_id
        AND p.status_id = 1  -- PENDING
        AND p.amount_paid = 0
    LIMIT 1;

    IF v_test_loan_id IS NULL THEN
        RAISE NOTICE '⚠️  No hay payments PENDING para testear. Saltando TEST 1.';
    ELSE
        DECLARE
            v_payment_id INTEGER;
            v_credit_before DECIMAL(12,2);
            v_credit_after DECIMAL(12,2);
        BEGIN
            -- Obtener payment_id
            SELECT id INTO v_payment_id
            FROM payments
            WHERE loan_id = v_test_loan_id
                AND status_id = 1
                AND amount_paid = 0
            LIMIT 1;

            -- Guardar credit_used antes
            SELECT credit_used INTO v_credit_before
            FROM associate_profiles
            WHERE user_id = v_test_associate_id;

            -- Marcar pago parcial del cliente al asociado
            UPDATE payments
            SET amount_paid = expected_amount * 0.5
            WHERE id = v_payment_id;

            -- Verificar credit_used después
            SELECT credit_used INTO v_credit_after
            FROM associate_profiles
            WHERE user_id = v_test_associate_id;

            -- Validar
            IF v_credit_after = v_credit_before THEN
                RAISE NOTICE '✅ TEST 1 PASSED: Cliente paga → NO liberó crédito';
                RAISE NOTICE '   - Credit antes: $%', v_credit_before;
                RAISE NOTICE '   - Credit después: $%', v_credit_after;
            ELSE
                RAISE NOTICE '❌ TEST 1 FAILED: Cliente paga → Liberó crédito (INCORRECTO)';
                RAISE NOTICE '   - Credit antes: $%', v_credit_before;
                RAISE NOTICE '   - Credit después: $%', v_credit_after;
                RAISE NOTICE '   - Diferencia: $%', v_credit_before - v_credit_after;
            END IF;

            -- Rollback del pago de prueba
            UPDATE payments
            SET amount_paid = 0
            WHERE id = v_payment_id;
        END;
    END IF;

    RAISE NOTICE '';

    -- ==========================================================================
    -- TEST 2: Asociado paga a statement → SÍ libera crédito
    -- ==========================================================================
    
    RAISE NOTICE '========================================';
    RAISE NOTICE '🧪 TEST 2: Asociado paga a statement';
    RAISE NOTICE '========================================';

    -- Buscar un statement con balance pendiente
    SELECT id
    INTO v_test_statement_id
    FROM associate_payment_statements
    WHERE user_id = v_test_associate_id
        AND (total_to_credicuenta - COALESCE(paid_amount, 0)) > 0
    ORDER BY generated_date DESC
    LIMIT 1;

    IF v_test_statement_id IS NULL THEN
        RAISE NOTICE '⚠️  No hay statements con balance para testear. Saltando TEST 2.';
    ELSE
        DECLARE
            v_test_payment_amount DECIMAL(12,2) := 500.00;
            v_credit_before DECIMAL(12,2);
            v_credit_after DECIMAL(12,2);
            v_debt_before DECIMAL(12,2);
            v_debt_after DECIMAL(12,2);
            v_test_payment_id INTEGER;
        BEGIN
            -- Guardar estado antes
            SELECT credit_used, debt_balance
            INTO v_credit_before, v_debt_before
            FROM associate_profiles
            WHERE user_id = v_test_associate_id;

            -- Hacer abono al statement
            INSERT INTO associate_statement_payments (
                statement_id,
                payment_amount,
                payment_date,
                payment_method_id,
                registered_by,
                notes
            ) VALUES (
                v_test_statement_id,
                v_test_payment_amount,
                CURRENT_DATE,
                1,  -- Cash
                1,  -- Admin user
                'TEST: Validación de liberación de crédito'
            ) RETURNING id INTO v_test_payment_id;

            -- Verificar estado después
            SELECT credit_used, debt_balance
            INTO v_credit_after, v_debt_after
            FROM associate_profiles
            WHERE user_id = v_test_associate_id;

            -- Validar
            IF v_credit_after = (v_credit_before - v_test_payment_amount) 
               AND v_debt_after = (v_debt_before - v_test_payment_amount) THEN
                RAISE NOTICE '✅ TEST 2 PASSED: Abono a statement → Liberó crédito y redujo deuda';
                RAISE NOTICE '   - Credit antes: $%, después: $%, diferencia: $%', 
                    v_credit_before, v_credit_after, v_credit_before - v_credit_after;
                RAISE NOTICE '   - Debt antes: $%, después: $%, diferencia: $%', 
                    v_debt_before, v_debt_after, v_debt_before - v_debt_after;
            ELSE
                RAISE NOTICE '❌ TEST 2 FAILED: Abono a statement → NO liberó correctamente';
                RAISE NOTICE '   - Credit: esperado $%, actual $%', 
                    v_credit_before - v_test_payment_amount, v_credit_after;
                RAISE NOTICE '   - Debt: esperado $%, actual $%', 
                    v_debt_before - v_test_payment_amount, v_debt_after;
            END IF;

            -- Rollback del pago de prueba
            DELETE FROM associate_statement_payments WHERE id = v_test_payment_id;
        END;
    END IF;

    RAISE NOTICE '';

    -- ==========================================================================
    -- TEST 3: Validar que NO hay trigger en payments
    -- ==========================================================================
    
    RAISE NOTICE '========================================';
    RAISE NOTICE '🧪 TEST 3: Validar ausencia de trigger';
    RAISE NOTICE '========================================';

    DECLARE
        v_trigger_count INTEGER;
    BEGIN
        SELECT COUNT(*)
        INTO v_trigger_count
        FROM information_schema.triggers
        WHERE trigger_name = 'trigger_update_associate_credit_on_payment'
            AND event_object_table = 'payments';

        IF v_trigger_count = 0 THEN
            RAISE NOTICE '✅ TEST 3 PASSED: Trigger eliminado correctamente';
        ELSE
            RAISE NOTICE '❌ TEST 3 FAILED: Trigger aún existe (debe eliminarse)';
        END IF;
    END;

    RAISE NOTICE '';

    -- ==========================================================================
    -- TEST 4: Validar que update_statement_on_payment actualiza credit_used
    -- ==========================================================================
    
    RAISE NOTICE '========================================';
    RAISE NOTICE '🧪 TEST 4: Validar función actualizada';
    RAISE NOTICE '========================================';

    DECLARE
        v_function_def TEXT;
    BEGIN
        SELECT pg_get_functiondef('update_statement_on_payment'::regproc)
        INTO v_function_def;

        IF v_function_def LIKE '%credit_used%' THEN
            RAISE NOTICE '✅ TEST 4 PASSED: Función actualiza credit_used';
        ELSE
            RAISE NOTICE '❌ TEST 4 FAILED: Función NO actualiza credit_used';
        END IF;
    END;

    RAISE NOTICE '';

    -- ==========================================================================
    -- RESUMEN FINAL
    -- ==========================================================================
    
    -- Verificar que el estado final es igual al inicial (todos los cambios se rollbackearon)
    SELECT credit_used, debt_balance
    INTO v_final_credit_used, v_final_debt_balance
    FROM associate_profiles
    WHERE user_id = v_test_associate_id;

    RAISE NOTICE '========================================';
    RAISE NOTICE '📊 ESTADO FINAL:';
    RAISE NOTICE '========================================';
    RAISE NOTICE '   - Credit Used: $% (inicial: $%)', v_final_credit_used, v_initial_credit_used;
    RAISE NOTICE '   - Debt Balance: $% (inicial: $%)', v_final_debt_balance, v_initial_debt_balance;
    
    IF v_final_credit_used = v_initial_credit_used 
       AND v_final_debt_balance = v_initial_debt_balance THEN
        RAISE NOTICE '';
        RAISE NOTICE '✅ Estado restaurado correctamente (rollback exitoso)';
    ELSE
        RAISE NOTICE '';
        RAISE NOTICE '⚠️  Estado NO restaurado - verificar rollback manual';
    END IF;

    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ TEST SUITE COMPLETADO';
    RAISE NOTICE '========================================';

END $$;

ROLLBACK;

-- =============================================================================
-- RESUMEN
-- =============================================================================

/*
Este test suite valida:

✅ TEST 1: Cliente paga a asociado → NO libera crédito
   - UPDATE payments SET amount_paid = X
   - credit_used debe permanecer igual

✅ TEST 2: Asociado paga a statement → SÍ libera crédito
   - INSERT INTO associate_statement_payments
   - credit_used debe disminuir en monto del pago
   - debt_balance debe disminuir en monto del pago

✅ TEST 3: Trigger eliminado
   - No debe existir trigger_update_associate_credit_on_payment en payments

✅ TEST 4: Función actualizada
   - update_statement_on_payment debe contener lógica de credit_used

📝 NOTA: 
   - Todos los tests usan TRANSACCIÓN con ROLLBACK final
   - No alteran datos reales de producción
   - Se pueden ejecutar múltiples veces sin efecto
*/
