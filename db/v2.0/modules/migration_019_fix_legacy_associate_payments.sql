-- =============================================================================
-- MIGRATION 019: Corregir pagos de asociado en legacy_payment_table
-- =============================================================================
-- Basado en análisis del PDF "TABLA PRESTAMOS CREDICUENTA - CALCULO VALES.pdf"
-- 
-- PROBLEMA IDENTIFICADO:
-- - La columna associate_biweekly_payment tiene valores inconsistentes
-- - El porcentaje de comisión varía entre 11.57% y 14.08%
-- - Los primeros valores parecen correctos, pero los demás necesitan revisión
--
-- SOLUCIÓN:
-- - Actualizar associate_biweekly_payment basándose en una tasa de comisión
--   consistente del 12.09% (tasa promedio del sistema)
-- =============================================================================

-- PASO 1: Crear tabla de respaldo
CREATE TABLE IF NOT EXISTS legacy_payment_table_backup_2025_11_18 AS
SELECT * FROM legacy_payment_table;

-- PASO 2: Análisis de datos actuales
SELECT 
    amount,
    biweekly_payment,
    associate_biweekly_payment as current_associate_payment,
    commission_per_payment as current_commission,
    ROUND((commission_per_payment::numeric / biweekly_payment::numeric * 100), 2) as current_commission_percent,
    
    -- Calcular nuevo pago de asociado con 12.09% de comisión
    ROUND(biweekly_payment * (1 - 0.1209), 2) as suggested_associate_payment,
    ROUND(biweekly_payment * 0.1209, 2) as suggested_commission,
    
    -- Diferencia
    ROUND(biweekly_payment * (1 - 0.1209), 2) - associate_biweekly_payment as difference
FROM legacy_payment_table
ORDER BY amount;

-- PASO 3: Mostrar resumen de inconsistencias
SELECT 
    COUNT(*) as total_records,
    COUNT(*) FILTER (WHERE ROUND((commission_per_payment::numeric / biweekly_payment::numeric * 100), 2) BETWEEN 12.00 AND 12.20) as consistent_records,
    COUNT(*) FILTER (WHERE ROUND((commission_per_payment::numeric / biweekly_payment::numeric * 100), 2) < 12.00 OR ROUND((commission_per_payment::numeric / biweekly_payment::numeric * 100), 2) > 12.20) as inconsistent_records,
    ROUND(AVG(commission_per_payment::numeric / biweekly_payment::numeric * 100), 2) as avg_commission_percent,
    ROUND(MIN(commission_per_payment::numeric / biweekly_payment::numeric * 100), 2) as min_commission_percent,
    ROUND(MAX(commission_per_payment::numeric / biweekly_payment::numeric * 100), 2) as max_commission_percent
FROM legacy_payment_table;

-- NOTA: NO ejecutar el UPDATE automáticamente
-- Primero revisar el análisis y confirmar con el equipo

/*
-- PASO 4: UPDATE (DESCOMENTAR SOLO DESPUÉS DE REVISAR)
-- Actualizar pagos de asociado basándose en comisión del 12.09%

UPDATE legacy_payment_table
SET associate_biweekly_payment = ROUND(biweekly_payment * (1 - 0.1209), 2)
WHERE id > 0;  -- Cambiar esta condición según necesidad

-- Verificar resultados después del UPDATE
SELECT 
    amount,
    biweekly_payment,
    associate_biweekly_payment,
    commission_per_payment,
    ROUND((commission_per_payment::numeric / biweekly_payment::numeric * 100), 2) as commission_percent
FROM legacy_payment_table
ORDER BY amount;
*/

-- =============================================================================
-- VALORES ESPERADOS SEGÚN PDF (COMPLETAR CON DATOS REALES DEL PDF)
-- =============================================================================
/*
Los valores correctos según el PDF serían:

Amount    | Pago Quincenal | Pago Asociado | Comisión
----------|----------------|---------------|----------
3,000     | 392.00         | ???           | ???
4,000     | 510.00         | ???           | ???
...

PENDIENTE: Obtener valores reales del PDF para comparar y validar
*/
