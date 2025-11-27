-- ============================================================================
-- MIGRACIÓN 005: Agregar Campos Calculados a Tabla loans
-- ============================================================================
-- Propósito: Guardar los valores calculados por calculate_loan_payment()
--            para mantener histórico exacto de lo acordado con el cliente
--
-- Fecha: 2025-11-05
-- Versión: 2.0
-- Estado: ✅ LISTA PARA APLICAR
-- ============================================================================

BEGIN;

-- ============================================================================
-- PASO 1: Agregar columnas para valores calculados
-- ============================================================================

-- Pago quincenal que debe realizar el cliente (incluye capital + interés)
ALTER TABLE loans ADD COLUMN IF NOT EXISTS biweekly_payment DECIMAL(12,2);
COMMENT ON COLUMN loans.biweekly_payment IS 
'Pago quincenal calculado que debe realizar el cliente (capital + interés). Calculado por calculate_loan_payment().';

-- Monto total que pagará el cliente al final del préstamo
ALTER TABLE loans ADD COLUMN IF NOT EXISTS total_payment DECIMAL(12,2);
COMMENT ON COLUMN loans.total_payment IS 
'Monto total que pagará el cliente (biweekly_payment * term_biweeks). Incluye capital + interés total.';

-- Interés total que pagará el cliente durante todo el préstamo
ALTER TABLE loans ADD COLUMN IF NOT EXISTS total_interest DECIMAL(12,2);
COMMENT ON COLUMN loans.total_interest IS 
'Interés total que pagará el cliente durante todo el préstamo (total_payment - amount).';

-- Comisión total acumulada de todos los pagos
ALTER TABLE loans ADD COLUMN IF NOT EXISTS total_commission DECIMAL(12,2);
COMMENT ON COLUMN loans.total_commission IS 
'Comisión total acumulada que se descontará en todos los pagos (commission_per_payment * term_biweeks).';

-- Comisión que se descuenta en cada pago quincenal
ALTER TABLE loans ADD COLUMN IF NOT EXISTS commission_per_payment DECIMAL(10,2);
COMMENT ON COLUMN loans.commission_per_payment IS 
'Comisión que se descuenta del asociado en cada pago quincenal. Calculado por calculate_loan_payment().';

-- Pago neto que recibirá el asociado en cada periodo
ALTER TABLE loans ADD COLUMN IF NOT EXISTS associate_payment DECIMAL(10,2);
COMMENT ON COLUMN loans.associate_payment IS 
'Pago neto que recibirá el asociado en cada periodo (biweekly_payment - commission_per_payment).';

-- ============================================================================
-- PASO 2: Crear índices para mejorar consultas
-- ============================================================================

-- Índice para búsquedas por rango de pago quincenal
CREATE INDEX IF NOT EXISTS idx_loans_biweekly_payment 
ON loans(biweekly_payment) 
WHERE biweekly_payment IS NOT NULL;

-- Índice para búsquedas por monto total
CREATE INDEX IF NOT EXISTS idx_loans_total_payment 
ON loans(total_payment) 
WHERE total_payment IS NOT NULL;

-- Índice compuesto para reportes de préstamos con profile_code
CREATE INDEX IF NOT EXISTS idx_loans_profile_code_biweekly 
ON loans(profile_code, biweekly_payment) 
WHERE profile_code IS NOT NULL AND biweekly_payment IS NOT NULL;

-- ============================================================================
-- PASO 3: Agregar constraints de validación
-- ============================================================================

-- El pago quincenal debe ser positivo
ALTER TABLE loans ADD CONSTRAINT chk_loans_biweekly_payment_positive 
CHECK (biweekly_payment IS NULL OR biweekly_payment > 0);

-- El pago total debe ser mayor o igual al capital
ALTER TABLE loans ADD CONSTRAINT chk_loans_total_payment_gte_amount 
CHECK (total_payment IS NULL OR total_payment >= amount);

-- El interés total no puede ser negativo
ALTER TABLE loans ADD CONSTRAINT chk_loans_total_interest_non_negative 
CHECK (total_interest IS NULL OR total_interest >= 0);

-- La comisión por pago no puede ser negativa
ALTER TABLE loans ADD CONSTRAINT chk_loans_commission_per_payment_non_negative 
CHECK (commission_per_payment IS NULL OR commission_per_payment >= 0);

-- El pago al asociado debe ser menor o igual al pago del cliente
ALTER TABLE loans ADD CONSTRAINT chk_loans_associate_payment_lte_biweekly 
CHECK (associate_payment IS NULL OR biweekly_payment IS NULL OR associate_payment <= biweekly_payment);

-- ============================================================================
-- PASO 4: Validación de consistencia matemática
-- ============================================================================

-- total_payment = biweekly_payment * term_biweeks (con tolerancia de 1 peso)
ALTER TABLE loans ADD CONSTRAINT chk_loans_total_payment_consistent
CHECK (
    total_payment IS NULL 
    OR biweekly_payment IS NULL 
    OR term_biweeks IS NULL
    OR ABS(total_payment - (biweekly_payment * term_biweeks)) < 1.00
);

-- total_interest = total_payment - amount (con tolerancia de 1 peso)
ALTER TABLE loans ADD CONSTRAINT chk_loans_total_interest_consistent
CHECK (
    total_interest IS NULL
    OR total_payment IS NULL
    OR amount IS NULL
    OR ABS(total_interest - (total_payment - amount)) < 1.00
);

-- associate_payment = biweekly_payment - commission_per_payment (con tolerancia de 0.10 centavos)
ALTER TABLE loans ADD CONSTRAINT chk_loans_associate_payment_consistent
CHECK (
    associate_payment IS NULL
    OR biweekly_payment IS NULL
    OR commission_per_payment IS NULL
    OR ABS(associate_payment - (biweekly_payment - commission_per_payment)) < 0.10
);

-- ============================================================================
-- PASO 5: Crear función helper para validar campos calculados
-- ============================================================================

CREATE OR REPLACE FUNCTION validate_loan_calculated_fields(
    p_loan_id INTEGER
) RETURNS TABLE (
    campo TEXT,
    valor_actual DECIMAL,
    valor_esperado DECIMAL,
    diferencia DECIMAL,
    es_valido BOOLEAN
) 
LANGUAGE plpgsql
AS $$
DECLARE
    v_loan RECORD;
BEGIN
    -- Obtener datos del préstamo
    SELECT 
        amount, term_biweeks, biweekly_payment, total_payment,
        total_interest, commission_per_payment, associate_payment
    INTO v_loan
    FROM loans
    WHERE id = p_loan_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Préstamo % no encontrado', p_loan_id;
    END IF;
    
    -- Validar total_payment = biweekly_payment * term_biweeks
    IF v_loan.total_payment IS NOT NULL AND v_loan.biweekly_payment IS NOT NULL THEN
        RETURN QUERY SELECT 
            'total_payment'::TEXT,
            v_loan.total_payment,
            v_loan.biweekly_payment * v_loan.term_biweeks,
            v_loan.total_payment - (v_loan.biweekly_payment * v_loan.term_biweeks),
            ABS(v_loan.total_payment - (v_loan.biweekly_payment * v_loan.term_biweeks)) < 1.00;
    END IF;
    
    -- Validar total_interest = total_payment - amount
    IF v_loan.total_interest IS NOT NULL AND v_loan.total_payment IS NOT NULL THEN
        RETURN QUERY SELECT 
            'total_interest'::TEXT,
            v_loan.total_interest,
            v_loan.total_payment - v_loan.amount,
            v_loan.total_interest - (v_loan.total_payment - v_loan.amount),
            ABS(v_loan.total_interest - (v_loan.total_payment - v_loan.amount)) < 1.00;
    END IF;
    
    -- Validar associate_payment = biweekly_payment - commission_per_payment
    IF v_loan.associate_payment IS NOT NULL AND v_loan.biweekly_payment IS NOT NULL THEN
        RETURN QUERY SELECT 
            'associate_payment'::TEXT,
            v_loan.associate_payment,
            v_loan.biweekly_payment - COALESCE(v_loan.commission_per_payment, 0),
            v_loan.associate_payment - (v_loan.biweekly_payment - COALESCE(v_loan.commission_per_payment, 0)),
            ABS(v_loan.associate_payment - (v_loan.biweekly_payment - COALESCE(v_loan.commission_per_payment, 0))) < 0.10;
    END IF;
END;
$$;

COMMENT ON FUNCTION validate_loan_calculated_fields(INTEGER) IS 
'Valida que los campos calculados del préstamo sean matemáticamente consistentes. Retorna una tabla con las validaciones.';

-- ============================================================================
-- PASO 6: Migración de datos existentes (si aplica)
-- ============================================================================

-- Para préstamos existentes con profile_code, recalcular valores
-- SOLO si no tienen estos campos calculados

DO $$
DECLARE
    v_loan RECORD;
    v_calc RECORD;
    v_updated_count INTEGER := 0;
BEGIN
    RAISE NOTICE 'Iniciando migración de datos existentes...';
    
    FOR v_loan IN 
        SELECT id, amount, term_biweeks, profile_code
        FROM loans
        WHERE profile_code IS NOT NULL 
          AND biweekly_payment IS NULL
          AND status_id IN (SELECT id FROM loan_statuses WHERE name IN ('PENDING', 'APPROVED', 'ACTIVE'))
    LOOP
        BEGIN
            -- Calcular valores con la función
            SELECT * INTO v_calc
            FROM calculate_loan_payment(
                v_loan.amount,
                v_loan.term_biweeks,
                v_loan.profile_code
            );
            
            -- Actualizar préstamo
            UPDATE loans SET
                biweekly_payment = v_calc.biweekly_payment,
                total_payment = v_calc.total_payment,
                total_interest = v_calc.total_interest,
                total_commission = v_calc.total_commission,
                commission_per_payment = v_calc.commission_per_payment,
                associate_payment = v_calc.associate_payment,
                updated_at = CURRENT_TIMESTAMP
            WHERE id = v_loan.id;
            
            v_updated_count := v_updated_count + 1;
            
            RAISE NOTICE 'Préstamo % actualizado: biweekly_payment=$%, total_payment=$%',
                v_loan.id, v_calc.biweekly_payment, v_calc.total_payment;
                
        EXCEPTION
            WHEN OTHERS THEN
                RAISE WARNING 'Error al recalcular préstamo %: % (%)', 
                    v_loan.id, SQLERRM, SQLSTATE;
        END;
    END LOOP;
    
    RAISE NOTICE 'Migración completada: % préstamos actualizados', v_updated_count;
END;
$$;

-- ============================================================================
-- PASO 7: Crear vista de resumen de préstamos con campos calculados
-- ============================================================================

CREATE OR REPLACE VIEW v_loans_summary AS
SELECT 
    l.id,
    l.user_id,
    u.username,
    l.amount as capital,
    l.term_biweeks as plazo_quincenas,
    l.profile_code,
    rp.name as profile_name,
    l.biweekly_payment as pago_quincenal,
    l.total_payment as pago_total,
    l.total_interest as interes_total,
    l.commission_per_payment as comision_por_pago,
    l.associate_payment as pago_al_asociado,
    l.total_commission as comision_total,
    ls.name as estado,
    l.created_at as fecha_creacion,
    l.approved_at as fecha_aprobacion,
    -- Cálculos derivados
    CASE 
        WHEN l.amount > 0 THEN ROUND((l.total_interest / l.amount) * 100, 2)
        ELSE NULL
    END as tasa_interes_efectiva_pct,
    CASE
        WHEN l.biweekly_payment > 0 THEN ROUND((l.commission_per_payment / l.biweekly_payment) * 100, 2)
        ELSE NULL
    END as comision_pct
FROM loans l
LEFT JOIN users u ON l.user_id = u.id
LEFT JOIN rate_profiles rp ON l.profile_code = rp.code
LEFT JOIN loan_statuses ls ON l.status_id = ls.id
WHERE l.biweekly_payment IS NOT NULL;

COMMENT ON VIEW v_loans_summary IS 
'Vista de resumen de préstamos con campos calculados y métricas derivadas.';

-- ============================================================================
-- PASO 8: Verificación final
-- ============================================================================

DO $$
DECLARE
    v_column_count INTEGER;
    v_index_count INTEGER;
    v_constraint_count INTEGER;
BEGIN
    -- Verificar que se agregaron todas las columnas
    SELECT COUNT(*) INTO v_column_count
    FROM information_schema.columns
    WHERE table_name = 'loans'
      AND column_name IN (
          'biweekly_payment', 'total_payment', 'total_interest',
          'total_commission', 'commission_per_payment', 'associate_payment'
      );
    
    IF v_column_count != 6 THEN
        RAISE EXCEPTION 'FALLO: Solo se agregaron % de 6 columnas esperadas', v_column_count;
    END IF;
    
    -- Verificar índices
    SELECT COUNT(*) INTO v_index_count
    FROM pg_indexes
    WHERE tablename = 'loans'
      AND indexname IN (
          'idx_loans_biweekly_payment',
          'idx_loans_total_payment',
          'idx_loans_profile_code_biweekly'
      );
    
    IF v_index_count != 3 THEN
        RAISE WARNING 'Advertencia: Solo se crearon % de 3 índices esperados', v_index_count;
    END IF;
    
    -- Verificar constraints
    SELECT COUNT(*) INTO v_constraint_count
    FROM information_schema.table_constraints
    WHERE table_name = 'loans'
      AND constraint_type = 'CHECK'
      AND constraint_name LIKE 'chk_loans_%calculated%'
         OR constraint_name LIKE 'chk_loans_%payment%'
         OR constraint_name LIKE 'chk_loans_%commission%'
         OR constraint_name LIKE 'chk_loans_%interest%'
         OR constraint_name LIKE 'chk_loans_%associate%';
    
    RAISE NOTICE '✅ Migración completada exitosamente:';
    RAISE NOTICE '   - Columnas agregadas: %', v_column_count;
    RAISE NOTICE '   - Índices creados: %', v_index_count;
    RAISE NOTICE '   - Constraints aplicados: %', v_constraint_count;
    RAISE NOTICE '   - Función helper: validate_loan_calculated_fields()';
    RAISE NOTICE '   - Vista creada: v_loans_summary';
END;
$$;

COMMIT;

-- ============================================================================
-- ROLLBACK (por si necesitas revertir la migración)
-- ============================================================================
-- COMENTADO - Descomenta solo si necesitas hacer rollback

/*
BEGIN;

-- Eliminar vista
DROP VIEW IF EXISTS v_loans_summary;

-- Eliminar función
DROP FUNCTION IF EXISTS validate_loan_calculated_fields(INTEGER);

-- Eliminar constraints
ALTER TABLE loans DROP CONSTRAINT IF EXISTS chk_loans_biweekly_payment_positive;
ALTER TABLE loans DROP CONSTRAINT IF EXISTS chk_loans_total_payment_gte_amount;
ALTER TABLE loans DROP CONSTRAINT IF EXISTS chk_loans_total_interest_non_negative;
ALTER TABLE loans DROP CONSTRAINT IF EXISTS chk_loans_commission_per_payment_non_negative;
ALTER TABLE loans DROP CONSTRAINT IF EXISTS chk_loans_associate_payment_lte_biweekly;
ALTER TABLE loans DROP CONSTRAINT IF EXISTS chk_loans_total_payment_consistent;
ALTER TABLE loans DROP CONSTRAINT IF EXISTS chk_loans_total_interest_consistent;
ALTER TABLE loans DROP CONSTRAINT IF EXISTS chk_loans_associate_payment_consistent;

-- Eliminar índices
DROP INDEX IF EXISTS idx_loans_biweekly_payment;
DROP INDEX IF EXISTS idx_loans_total_payment;
DROP INDEX IF EXISTS idx_loans_profile_code_biweekly;

-- Eliminar columnas
ALTER TABLE loans DROP COLUMN IF EXISTS biweekly_payment;
ALTER TABLE loans DROP COLUMN IF EXISTS total_payment;
ALTER TABLE loans DROP COLUMN IF EXISTS total_interest;
ALTER TABLE loans DROP COLUMN IF EXISTS total_commission;
ALTER TABLE loans DROP COLUMN IF EXISTS commission_per_payment;
ALTER TABLE loans DROP COLUMN IF EXISTS associate_payment;

COMMIT;
*/

-- ============================================================================
-- FIN DE MIGRACIÓN 005
-- ============================================================================
