-- =============================================================================
-- MIGRACIÓN 020: Corregir pagos de asociado según PDF oficial
-- =============================================================================
-- Fecha: 2025-11-18
-- Fuente de verdad: TABLA PRESTAMOS CREDICUENTA - CALCULO VALES.pdf
-- 
-- PROBLEMA IDENTIFICADO:
-- ----------------------
-- ✅ Los pagos de CLIENTE (biweekly_payment) están correctos
-- ❌ Los pagos de ASOCIADO (associate_biweekly_payment) tienen errores en 23 de 28 montos
-- ➕ El monto $7,500 existe en DB pero NO en el PDF oficial
--
-- RESUMEN DE ERRORES:
-- -------------------
-- ✅ Correctos: 5 montos ($3k, $4k, $5k, $6k, $7k)
-- ❌ Incorrectos: 23 montos (desde $8k hasta $30k)
-- ➕ Extra: 1 monto ($7,500 no aparece en PDF)
--
-- IMPACTO:
-- --------
-- - Afecta cálculos de comisión para préstamos legacy
-- - Afecta tabla de referencia rate_profile_reference_table
-- - NO afecta préstamos ya creados (usan valores almacenados)
-- =============================================================================

-- 1. Crear respaldo antes de modificar
-- =============================================================================
DROP TABLE IF EXISTS legacy_payment_table_backup_before_pdf_fix;
CREATE TABLE legacy_payment_table_backup_before_pdf_fix AS
SELECT * FROM legacy_payment_table;

-- 2. Verificar datos actuales con errores
-- =============================================================================
SELECT 
    amount,
    biweekly_payment as pago_cliente,
    associate_biweekly_payment as pago_asociado_actual,
    commission_per_payment as comision_actual
FROM legacy_payment_table
WHERE amount >= 8000
ORDER BY amount;

-- 3. Actualizar pagos de asociado según PDF
-- =============================================================================
-- Los valores del PDF son la fuente de verdad oficial
-- Formato: (monto, pago_asociado_correcto, comision_correcta)

-- NOTA: commission_per_payment es GENERATED COLUMN (se calcula automáticamente)
-- Solo actualizamos associate_biweekly_payment y el resto se recalcula solo

UPDATE legacy_payment_table SET associate_biweekly_payment = 878.00 WHERE amount = 8000;
UPDATE legacy_payment_table SET associate_biweekly_payment = 987.00 WHERE amount = 9000;
UPDATE legacy_payment_table SET associate_biweekly_payment = 1095.00 WHERE amount = 10000;
UPDATE legacy_payment_table SET associate_biweekly_payment = 1215.00 WHERE amount = 11000;
UPDATE legacy_payment_table SET associate_biweekly_payment = 1324.00 WHERE amount = 12000;
UPDATE legacy_payment_table SET associate_biweekly_payment = 1432.00 WHERE amount = 13000;
UPDATE legacy_payment_table SET associate_biweekly_payment = 1541.00 WHERE amount = 14000;
UPDATE legacy_payment_table SET associate_biweekly_payment = 1648.00 WHERE amount = 15000;
UPDATE legacy_payment_table SET associate_biweekly_payment = 1756.00 WHERE amount = 16000;
UPDATE legacy_payment_table SET associate_biweekly_payment = 1865.00 WHERE amount = 17000;
UPDATE legacy_payment_table SET associate_biweekly_payment = 1974.00 WHERE amount = 18000;
UPDATE legacy_payment_table SET associate_biweekly_payment = 2082.00 WHERE amount = 19000;
UPDATE legacy_payment_table SET associate_biweekly_payment = 2190.00 WHERE amount = 20000;
UPDATE legacy_payment_table SET associate_biweekly_payment = 2310.00 WHERE amount = 21000;
UPDATE legacy_payment_table SET associate_biweekly_payment = 2419.00 WHERE amount = 22000;
UPDATE legacy_payment_table SET associate_biweekly_payment = 2527.00 WHERE amount = 23000;
UPDATE legacy_payment_table SET associate_biweekly_payment = 2636.00 WHERE amount = 24000;
UPDATE legacy_payment_table SET associate_biweekly_payment = 2743.00 WHERE amount = 25000;
UPDATE legacy_payment_table SET associate_biweekly_payment = 2851.00 WHERE amount = 26000;
UPDATE legacy_payment_table SET associate_biweekly_payment = 2960.00 WHERE amount = 27000;
UPDATE legacy_payment_table SET associate_biweekly_payment = 3069.00 WHERE amount = 28000;
UPDATE legacy_payment_table SET associate_biweekly_payment = 3177.00 WHERE amount = 29000;
UPDATE legacy_payment_table SET associate_biweekly_payment = 3285.00 WHERE amount = 30000;

-- 4. Verificar correcciones
-- =============================================================================
SELECT 
    amount,
    biweekly_payment as pago_cliente,
    associate_biweekly_payment as pago_asociado_corregido,
    commission_per_payment as comision_corregida,
    associate_total_payment as total_asociado,
    ROUND((commission_per_payment / biweekly_payment * 100)::NUMERIC, 2) as porcentaje_comision
FROM legacy_payment_table
ORDER BY amount;

-- 5. Actualizar tabla de referencia
-- =============================================================================
-- Regenerar los datos de la tabla de referencia con los valores corregidos
DELETE FROM rate_profile_reference_table WHERE profile_code = 'legacy';

INSERT INTO rate_profile_reference_table (
    profile_code,
    amount,
    term_biweeks,
    biweekly_payment,
    total_payment,
    commission_per_payment,
    total_commission,
    associate_payment,
    associate_total,
    interest_rate_percent,
    commission_rate_percent
)
SELECT 
    'legacy' as profile_code,
    amount,
    term_biweeks,
    biweekly_payment,
    total_payment,
    commission_per_payment,
    commission_per_payment * term_biweeks as total_commission,
    associate_biweekly_payment as associate_payment,
    associate_total_payment as associate_total,
    biweekly_rate_percent as interest_rate_percent,
    ROUND(((commission_per_payment / NULLIF(biweekly_payment, 0)) * 100)::NUMERIC, 3) as commission_rate_percent
FROM legacy_payment_table
ORDER BY amount;

-- 6. Verificación final
-- =============================================================================
COMMENT ON TABLE legacy_payment_table_backup_before_pdf_fix IS 
'Respaldo de legacy_payment_table antes de corregir valores según PDF oficial. 
Creado: 2025-11-18. 
Razón: 23 de 28 montos tenían pagos de asociado incorrectos.';

-- 7. Eliminar monto $7,500 (NO aparece en PDF oficial)
-- =============================================================================
-- El monto $7,500 existe en la base de datos pero NO aparece en el PDF oficial.
-- Decisión: ELIMINARLO porque no es parte de la tabla oficial.

-- Primero eliminar de la tabla de referencia
DELETE FROM rate_profile_reference_table 
WHERE profile_code = 'legacy' AND amount = 7500;

-- Luego eliminar de la tabla legacy
DELETE FROM legacy_payment_table WHERE amount = 7500;

-- 8. Resumen de cambios
-- =============================================================================
SELECT 
    '✅ MIGRACIÓN 020 COMPLETADA' as status,
    COUNT(*) as total_registros,
    SUM(CASE WHEN amount BETWEEN 8000 AND 30000 THEN 1 ELSE 0 END) as registros_corregidos,
    SUM(CASE WHEN amount < 8000 THEN 1 ELSE 0 END) as registros_sin_cambios
FROM legacy_payment_table;

-- Verificar que $7,500 fue eliminado
SELECT 
    CASE 
        WHEN COUNT(*) = 0 THEN '✅ Monto $7,500 eliminado correctamente'
        ELSE '❌ ERROR: Monto $7,500 aún existe'
    END as verificacion_7500
FROM legacy_payment_table WHERE amount = 7500;

-- =============================================================================
-- RESUMEN FINAL
-- =============================================================================
-- ✅ 23 montos corregidos (de $8,000 a $30,000)
-- ✅ 5 montos sin cambios (de $3,000 a $7,000) - ya estaban correctos
-- ✅ 1 monto eliminado ($7,500) - no aparece en PDF oficial
-- ✅ Total final: 28 registros (todos según PDF oficial)
-- =============================================================================
