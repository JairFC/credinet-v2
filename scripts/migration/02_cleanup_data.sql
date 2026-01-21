-- =============================================================================
-- CrediNet v2.0 - Script de Limpieza para Producción
-- =============================================================================
-- PROPÓSITO: Eliminar SOLO datos de prueba, conservar catálogos y estructura
-- 
-- EJECUTAR EN ORDEN:
-- 1. Primero levantar PostgreSQL con init.sql (esquema + catálogos)
-- 2. NO ejecutar este script si init.sql ya viene limpio
--
-- Este script es para LIMPIAR una BD existente, no para una nueva instalación
-- =============================================================================

BEGIN;

-- =============================================================================
-- VERIFICACIÓN PRE-LIMPIEZA
-- =============================================================================
DO $$
DECLARE
    v_loans INTEGER;
    v_payments INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_loans FROM loans;
    SELECT COUNT(*) INTO v_payments FROM payments;
    
    RAISE NOTICE '=== PRE-LIMPIEZA ===';
    RAISE NOTICE 'Préstamos a eliminar: %', v_loans;
    RAISE NOTICE 'Pagos a eliminar: %', v_payments;
END $$;

-- =============================================================================
-- PASO 1: ELIMINAR DATOS TRANSACCIONALES (orden por dependencias FK)
-- =============================================================================

-- 1.1 Eliminar historial de pagos
TRUNCATE TABLE payment_status_history CASCADE;
RAISE NOTICE 'Eliminado: payment_status_history';

-- 1.2 Eliminar pagos de statements
TRUNCATE TABLE associate_statement_payments CASCADE;
RAISE NOTICE 'Eliminado: associate_statement_payments';

-- 1.3 Eliminar statements
TRUNCATE TABLE associate_payment_statements CASCADE;
RAISE NOTICE 'Eliminado: associate_payment_statements';

-- 1.4 Eliminar pagos de convenios
TRUNCATE TABLE agreement_payments CASCADE;
RAISE NOTICE 'Eliminado: agreement_payments';

-- 1.5 Eliminar items de convenios
TRUNCATE TABLE agreement_items CASCADE;
RAISE NOTICE 'Eliminado: agreement_items';

-- 1.6 Eliminar convenios
TRUNCATE TABLE agreements CASCADE;
RAISE NOTICE 'Eliminado: agreements';

-- 1.7 Eliminar pagos de deuda
TRUNCATE TABLE associate_debt_payments CASCADE;
RAISE NOTICE 'Eliminado: associate_debt_payments';

-- 1.8 Eliminar breakdown de deuda
TRUNCATE TABLE associate_debt_breakdown CASCADE;
RAISE NOTICE 'Eliminado: associate_debt_breakdown';

-- 1.9 Eliminar balances acumulados
TRUNCATE TABLE associate_accumulated_balances CASCADE;
RAISE NOTICE 'Eliminado: associate_accumulated_balances';

-- 1.10 Eliminar reportes de morosos
TRUNCATE TABLE defaulted_client_reports CASCADE;
RAISE NOTICE 'Eliminado: defaulted_client_reports';

-- 1.11 Eliminar pagos
TRUNCATE TABLE payments CASCADE;
RAISE NOTICE 'Eliminado: payments';

-- 1.12 Eliminar préstamos
TRUNCATE TABLE loans CASCADE;
RAISE NOTICE 'Eliminado: loans';

-- 1.13 Eliminar contratos
TRUNCATE TABLE contracts CASCADE;
RAISE NOTICE 'Eliminado: contracts';

-- 1.14 Eliminar documentos de cliente
TRUNCATE TABLE client_documents CASCADE;
RAISE NOTICE 'Eliminado: client_documents';

-- 1.15 Eliminar beneficiarios
TRUNCATE TABLE beneficiaries CASCADE;
RAISE NOTICE 'Eliminado: beneficiaries';

-- 1.16 Eliminar avales
TRUNCATE TABLE guarantors CASCADE;
RAISE NOTICE 'Eliminado: guarantors';

-- 1.17 Eliminar direcciones
TRUNCATE TABLE addresses CASCADE;
RAISE NOTICE 'Eliminado: addresses';

-- =============================================================================
-- PASO 2: ELIMINAR USUARIOS DE PRUEBA (conservar admin)
-- =============================================================================

-- 2.1 Eliminar historial de niveles de asociado
TRUNCATE TABLE associate_level_history CASCADE;
RAISE NOTICE 'Eliminado: associate_level_history';

-- 2.2 Eliminar perfiles de asociado
DELETE FROM associate_profiles WHERE id > 0;
RAISE NOTICE 'Eliminado: associate_profiles (todos)';

-- 2.3 Eliminar roles de usuario (excepto admins)
DELETE FROM user_roles WHERE user_id > 2;
RAISE NOTICE 'Eliminado: user_roles (excepto id 1,2)';

-- 2.4 Eliminar usuarios (excepto admins)
DELETE FROM users WHERE id > 2;
RAISE NOTICE 'Eliminado: users (excepto id 1,2)';

-- =============================================================================
-- PASO 3: RESETEAR SECUENCIAS
-- =============================================================================

-- Resetear secuencias para nuevos registros
SELECT setval('loans_id_seq', 1, false);
SELECT setval('payments_id_seq', 1, false);
SELECT setval('agreements_id_seq', 1, false);
SELECT setval('associate_payment_statements_id_seq', 1, false);
SELECT setval('users_id_seq', 3, false);  -- Siguiente después de admin
SELECT setval('associate_profiles_id_seq', 1, false);

RAISE NOTICE 'Secuencias reseteadas';

-- =============================================================================
-- PASO 4: LIMPIAR LOGS DE AUDITORÍA (opcional)
-- =============================================================================

-- Descomenta si quieres limpiar también los logs
-- TRUNCATE TABLE audit_log CASCADE;
-- TRUNCATE TABLE audit_session_log CASCADE;
-- RAISE NOTICE 'Logs de auditoría eliminados';

-- =============================================================================
-- VERIFICACIÓN POST-LIMPIEZA
-- =============================================================================
DO $$
DECLARE
    v_users INTEGER;
    v_roles INTEGER;
    v_periods INTEGER;
    v_rate_profiles INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_users FROM users;
    SELECT COUNT(*) INTO v_roles FROM roles;
    SELECT COUNT(*) INTO v_periods FROM cut_periods;
    SELECT COUNT(*) INTO v_rate_profiles FROM rate_profiles;
    
    RAISE NOTICE '=== POST-LIMPIEZA ===';
    RAISE NOTICE 'Usuarios conservados: % (deben ser 2: jair, admin)', v_users;
    RAISE NOTICE 'Roles: % (deben ser 5)', v_roles;
    RAISE NOTICE 'Períodos de corte: % (deben ser 288)', v_periods;
    RAISE NOTICE 'Perfiles de tasa: % (deben ser 5)', v_rate_profiles;
END $$;

COMMIT;

-- =============================================================================
-- MENSAJE FINAL
-- =============================================================================
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '╔════════════════════════════════════════════════════════════════════╗';
    RAISE NOTICE '║     ✓ LIMPIEZA COMPLETADA - BASE DE DATOS LISTA PARA PRODUCCIÓN    ║';
    RAISE NOTICE '╚════════════════════════════════════════════════════════════════════╝';
    RAISE NOTICE '';
    RAISE NOTICE 'PRÓXIMOS PASOS:';
    RAISE NOTICE '1. Verificar usuarios admin (SELECT * FROM users;)';
    RAISE NOTICE '2. Crear primer asociado desde la UI';
    RAISE NOTICE '3. Probar flujo completo de préstamo';
END $$;
