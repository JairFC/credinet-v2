-- =============================================================================
-- SCRIPT: Limpieza de Datos de Prueba de Préstamos
-- =============================================================================
-- Descripción:
--   Elimina todos los préstamos y datos relacionados (pagos, contratos, etc.)
--   Mantiene intactos: usuarios, asociados, clientes, catálogos
--
-- ADVERTENCIA: Esta operación es IRREVERSIBLE
-- Solo ejecutar en ambientes de desarrollo/prueba
-- =============================================================================

BEGIN;

-- Mostrar estadísticas ANTES de eliminar
SELECT 
    'ANTES DE LIMPIAR' as momento,
    (SELECT COUNT(*) FROM loans) as total_loans,
    (SELECT COUNT(*) FROM payments) as total_payments,
    (SELECT COUNT(*) FROM contracts) as total_contracts,
    (SELECT COUNT(*) FROM agreement_items) as total_agreement_items,
    (SELECT COUNT(*) FROM associate_debt_breakdown) as total_debt_breakdown,
    (SELECT COUNT(*) FROM defaulted_client_reports) as total_defaulted_reports,
    (SELECT COUNT(*) FROM loan_renewals) as total_renewals;

-- =============================================================================
-- PASO 1: Eliminar datos dependientes de préstamos
-- Orden: de más dependiente a menos dependiente
-- =============================================================================

-- 1.1 Eliminar renovaciones de préstamos (NO ACTION - requiere eliminación manual)
DELETE FROM loan_renewals WHERE original_loan_id IN (SELECT id FROM loans);
DELETE FROM loan_renewals WHERE renewed_loan_id IN (SELECT id FROM loans);

-- 1.2 Eliminar reportes de morosidad (NO ACTION - requiere eliminación manual)
DELETE FROM defaulted_client_reports WHERE loan_id IN (SELECT id FROM loans);

-- 1.3 Eliminar desglose de deuda de asociados (NO ACTION - requiere eliminación manual)
DELETE FROM associate_debt_breakdown WHERE loan_id IN (SELECT id FROM loans);

-- 1.4 Eliminar items de acuerdo (NO ACTION - requiere eliminación manual)
DELETE FROM agreement_items WHERE loan_id IN (SELECT id FROM loans);

-- 1.5 Contratos se eliminarán automáticamente por CASCADE
-- 1.6 Pagos se eliminarán automáticamente por CASCADE

-- =============================================================================
-- PASO 2: Eliminar préstamos (esto eliminará cascadas: payments, contracts)
-- =============================================================================

DELETE FROM loans;

-- =============================================================================
-- PASO 3: Resetear secuencias (IDs empezarán desde 1)
-- =============================================================================

ALTER SEQUENCE loans_id_seq RESTART WITH 1;
ALTER SEQUENCE payments_id_seq RESTART WITH 1;
ALTER SEQUENCE contracts_id_seq RESTART WITH 1;
-- Agregar otras secuencias si existen
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_class WHERE relname = 'agreement_items_id_seq') THEN
        ALTER SEQUENCE agreement_items_id_seq RESTART WITH 1;
    END IF;
    IF EXISTS (SELECT 1 FROM pg_class WHERE relname = 'associate_debt_breakdown_id_seq') THEN
        ALTER SEQUENCE associate_debt_breakdown_id_seq RESTART WITH 1;
    END IF;
    IF EXISTS (SELECT 1 FROM pg_class WHERE relname = 'defaulted_client_reports_id_seq') THEN
        ALTER SEQUENCE defaulted_client_reports_id_seq RESTART WITH 1;
    END IF;
    IF EXISTS (SELECT 1 FROM pg_class WHERE relname = 'loan_renewals_id_seq') THEN
        ALTER SEQUENCE loan_renewals_id_seq RESTART WITH 1;
    END IF;
END$$;

-- =============================================================================
-- PASO 4: Limpiar datos de deuda de asociados
-- =============================================================================

-- Resetear crédito usado de asociados (credit_available es columna generada, se actualiza automáticamente)
UPDATE associate_profiles SET 
    credit_used = 0
WHERE id > 0;

-- =============================================================================
-- PASO 5: Verificación final
-- =============================================================================

SELECT 
    'DESPUÉS DE LIMPIAR' as momento,
    (SELECT COUNT(*) FROM loans) as total_loans,
    (SELECT COUNT(*) FROM payments) as total_payments,
    (SELECT COUNT(*) FROM contracts) as total_contracts,
    (SELECT COUNT(*) FROM agreement_items) as total_agreement_items,
    (SELECT COUNT(*) FROM associate_debt_breakdown) as total_debt_breakdown,
    (SELECT COUNT(*) FROM defaulted_client_reports) as total_defaulted_reports,
    (SELECT COUNT(*) FROM loan_renewals) as total_renewals,
    (SELECT SUM(credit_used)::NUMERIC(15,2) FROM associate_profiles) as total_credito_usado,
    (SELECT SUM(credit_available)::NUMERIC(15,2) FROM associate_profiles) as total_credito_disponible;

COMMIT;

-- =============================================================================
-- RESUMEN DE RELACIONES:
-- =============================================================================
-- Tablas con CASCADE (se eliminan automáticamente):
--   • payments → loans (ON DELETE CASCADE)
--   • contracts → loans (ON DELETE CASCADE)
--
-- Tablas con NO ACTION (requieren eliminación manual ANTES de loans):
--   • agreement_items → loans
--   • associate_debt_breakdown → loans
--   • defaulted_client_reports → loans
--   • loan_renewals → loans (original_loan_id y renewed_loan_id)
--
-- Intactos después de limpieza:
--   • users (clientes, asociados, administradores)
--   • user_roles
--   • associate_profiles (crédito resetado a disponible)
--   • loan_statuses (catálogo)
--   • payment_statuses (catálogo)
--   • rate_profiles (perfiles de tasas)
--   • biweekly_periods (períodos de corte)
-- =============================================================================

-- Para ejecutar este script:
-- docker exec -i credinet-postgres psql -U credinet_user -d credinet_db < /home/credicuenta/proyectos/credinet-v2/scripts/database/cleanup_test_loans.sql
