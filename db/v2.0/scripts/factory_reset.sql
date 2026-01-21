-- =============================================================================
-- SCRIPT: factory_reset.sql
-- Propósito: Limpieza de datos de prueba manteniendo catálogos esenciales
-- Fecha: 2026-01-19
-- Versión: 1.0
-- =============================================================================
-- 
-- USO:
--   docker exec -it credinet-postgres psql -U credinet_user -d credinet_db -f /path/to/factory_reset.sql
--
-- ¿QUÉ HACE?
--   1. ELIMINA todos los datos transaccionales (préstamos, pagos, etc.)
--   2. PRESERVA los catálogos (roles, niveles, estados, legacy_payment_table, etc.)
--   3. PRESERVA usuarios del sistema (admin, dev, jair)
--   4. REINICIA las secuencias para empezar desde 1
--
-- ¿CUÁNDO USARLO?
--   - Antes de ir a producción
--   - Para limpiar datos de prueba en cualquier momento
--   - Se puede ejecutar múltiples veces sin problema
--
-- NOTA: Este script es DESTRUCTIVO para datos transaccionales.
--       Asegúrate de tener un backup antes de ejecutar.
-- =============================================================================

BEGIN;

-- Mensaje de inicio
DO $$ BEGIN RAISE NOTICE '=== INICIANDO FACTORY RESET ==='; END $$;

-- =============================================================================
-- FASE 1: Deshabilitar triggers temporalmente
-- =============================================================================
DO $$ BEGIN RAISE NOTICE 'Fase 1: Deshabilitando triggers...'; END $$;

SET session_replication_role = replica;

-- =============================================================================
-- FASE 2: Eliminar datos transaccionales (en orden de dependencias FK)
-- =============================================================================
DO $$ BEGIN RAISE NOTICE 'Fase 2: Eliminando datos transaccionales...'; END $$;

-- Pagos y relacionados
TRUNCATE TABLE payment_status_history CASCADE;
TRUNCATE TABLE associate_statement_payments CASCADE;
TRUNCATE TABLE associate_debt_payments CASCADE;
TRUNCATE TABLE payments CASCADE;

-- Statements y acumulados
TRUNCATE TABLE associate_payment_statements CASCADE;
TRUNCATE TABLE associate_accumulated_balances CASCADE;
TRUNCATE TABLE associate_debt_breakdown CASCADE;

-- Préstamos
TRUNCATE TABLE loan_renewals CASCADE;
TRUNCATE TABLE contracts CASCADE;
TRUNCATE TABLE defaulted_client_reports CASCADE;
TRUNCATE TABLE loans CASCADE;

-- Convenios
TRUNCATE TABLE agreement_payments CASCADE;
TRUNCATE TABLE agreement_items CASCADE;
TRUNCATE TABLE agreements CASCADE;

-- Historial de niveles (transaccional, no catálogo)
TRUNCATE TABLE associate_level_history CASCADE;

-- Documentos de clientes (transaccional)
TRUNCATE TABLE client_documents CASCADE;

-- Auditoría (logs, se pueden borrar)
TRUNCATE TABLE audit_log CASCADE;
TRUNCATE TABLE audit_session_log CASCADE;

-- Backups temporales si existen
DROP TABLE IF EXISTS backup_associate_profiles_20260108 CASCADE;
DROP TABLE IF EXISTS backup_associate_profiles_pre_refactor_20260108 CASCADE;

DO $$ BEGIN RAISE NOTICE 'Datos transaccionales eliminados.'; END $$;

-- =============================================================================
-- FASE 3: Limpiar datos de usuarios NO ESENCIALES
-- =============================================================================
DO $$ BEGIN RAISE NOTICE 'Fase 3: Limpiando usuarios no esenciales...'; END $$;

-- Primero eliminamos los perfiles asociados de usuarios que no son del sistema
-- Guardamos los IDs de usuarios del sistema (admin, dev, jair)
DELETE FROM associate_profiles 
WHERE user_id NOT IN (
    SELECT id FROM users 
    WHERE username IN ('admin', 'dev', 'jair')
);

-- Eliminar beneficiarios de usuarios no esenciales
DELETE FROM beneficiaries 
WHERE user_id NOT IN (
    SELECT id FROM users 
    WHERE username IN ('admin', 'dev', 'jair')
);

-- Eliminar garantías de usuarios no esenciales
DELETE FROM guarantors 
WHERE user_id NOT IN (
    SELECT id FROM users 
    WHERE username IN ('admin', 'dev', 'jair')
);

-- Eliminar direcciones de usuarios no esenciales
DELETE FROM addresses 
WHERE user_id NOT IN (
    SELECT id FROM users 
    WHERE username IN ('admin', 'dev', 'jair')
);

-- Eliminar roles de usuarios no esenciales
DELETE FROM user_roles 
WHERE user_id NOT IN (
    SELECT id FROM users 
    WHERE username IN ('admin', 'dev', 'jair')
);

-- Finalmente eliminar usuarios no esenciales
DELETE FROM users 
WHERE username NOT IN ('admin', 'dev', 'jair');

DO $$ BEGIN RAISE NOTICE 'Usuarios no esenciales eliminados.'; END $$;

-- =============================================================================
-- FASE 4: Reiniciar secuencias
-- =============================================================================
DO $$ BEGIN RAISE NOTICE 'Fase 4: Reiniciando secuencias...'; END $$;

-- Reiniciar secuencias de tablas transaccionales
SELECT setval('loans_id_seq', 1, false);
SELECT setval('payments_id_seq', 1, false);
SELECT setval('contracts_id_seq', 1, false);
SELECT setval('loan_renewals_id_seq', 1, false);
SELECT setval('agreements_id_seq', 1, false);
SELECT setval('agreement_items_id_seq', 1, false);
SELECT setval('agreement_payments_id_seq', 1, false);
SELECT setval('associate_payment_statements_id_seq', 1, false);
SELECT setval('associate_statement_payments_id_seq', 1, false);
SELECT setval('associate_accumulated_balances_id_seq', 1, false);
SELECT setval('associate_debt_breakdown_id_seq', 1, false);
SELECT setval('associate_debt_payments_id_seq', 1, false);
SELECT setval('associate_level_history_id_seq', 1, false);
SELECT setval('payment_status_history_id_seq', 1, false);
SELECT setval('defaulted_client_reports_id_seq', 1, false);
SELECT setval('client_documents_id_seq', 1, false);
SELECT setval('audit_log_id_seq', 1, false);
SELECT setval('audit_session_log_id_seq', 1, false);

-- Mantener secuencias de usuarios según los existentes
SELECT setval('users_id_seq', COALESCE((SELECT MAX(id) FROM users), 1), true);
SELECT setval('associate_profiles_id_seq', COALESCE((SELECT MAX(id) FROM associate_profiles), 1), true);
SELECT setval('addresses_id_seq', COALESCE((SELECT MAX(id) FROM addresses), 1), true);
SELECT setval('beneficiaries_id_seq', COALESCE((SELECT MAX(id) FROM beneficiaries), 1), true);
SELECT setval('guarantors_id_seq', COALESCE((SELECT MAX(id) FROM guarantors), 1), true);

DO $$ BEGIN RAISE NOTICE 'Secuencias reiniciadas.'; END $$;

-- =============================================================================
-- FASE 5: Rehabilitar triggers
-- =============================================================================
DO $$ BEGIN RAISE NOTICE 'Fase 5: Rehabilitando triggers...'; END $$;

SET session_replication_role = DEFAULT;

-- =============================================================================
-- FASE 6: Verificación final
-- =============================================================================
DO $$ BEGIN RAISE NOTICE 'Fase 6: Verificando estado final...'; END $$;

-- Mostrar resumen
DO $$
DECLARE
    v_users INT;
    v_loans INT;
    v_payments INT;
    v_roles INT;
    v_levels INT;
    v_legacy INT;
    v_periods INT;
BEGIN
    SELECT COUNT(*) INTO v_users FROM users;
    SELECT COUNT(*) INTO v_loans FROM loans;
    SELECT COUNT(*) INTO v_payments FROM payments;
    SELECT COUNT(*) INTO v_roles FROM roles;
    SELECT COUNT(*) INTO v_levels FROM associate_levels;
    SELECT COUNT(*) INTO v_legacy FROM legacy_payment_table;
    SELECT COUNT(*) INTO v_periods FROM cut_periods;
    
    RAISE NOTICE '';
    RAISE NOTICE '=== RESUMEN POST-LIMPIEZA ===';
    RAISE NOTICE 'Usuarios del sistema: %', v_users;
    RAISE NOTICE 'Préstamos: % (debería ser 0)', v_loans;
    RAISE NOTICE 'Pagos: % (debería ser 0)', v_payments;
    RAISE NOTICE '';
    RAISE NOTICE '=== CATÁLOGOS PRESERVADOS ===';
    RAISE NOTICE 'Roles: %', v_roles;
    RAISE NOTICE 'Niveles de asociado: %', v_levels;
    RAISE NOTICE 'Tabla legacy_payment: %', v_legacy;
    RAISE NOTICE 'Períodos de corte: %', v_periods;
    RAISE NOTICE '';
    RAISE NOTICE '=== FACTORY RESET COMPLETADO ===';
END $$;

COMMIT;

-- Listado de usuarios que quedaron
SELECT id, username, first_name, last_name, email, active 
FROM users 
ORDER BY id;
