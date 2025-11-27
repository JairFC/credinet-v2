-- ============================================================================
-- MIGRACIÓN 006: Agregar Campos de Desglose a Tabla payments
-- ============================================================================
-- Propósito: Guardar el desglose financiero completo de cada pago
--            (interés, capital, comisión, saldo) generado por
--            generate_amortization_schedule()
--
-- Fecha: 2025-11-05
-- Versión: 2.0
-- Estado: ✅ LISTA PARA APLICAR
-- ============================================================================

BEGIN;

-- ============================================================================
-- PASO 1: Agregar columnas para desglose de pagos
-- ============================================================================

-- Número secuencial del pago (1, 2, 3, ..., 12)
ALTER TABLE payments ADD COLUMN IF NOT EXISTS payment_number INTEGER;
COMMENT ON COLUMN payments.payment_number IS 
'Número secuencial del pago dentro del préstamo (1, 2, 3, ..., term_biweeks). Facilita ordenamiento y referencias.';

-- Monto esperado que debe pagar el cliente (capital + interés)
ALTER TABLE payments ADD COLUMN IF NOT EXISTS expected_amount DECIMAL(12,2);
COMMENT ON COLUMN payments.expected_amount IS 
'Monto esperado que debe pagar el cliente en este periodo (incluye capital + interés). Valor de referencia para validar pagos.';

-- Interés correspondiente a este periodo
ALTER TABLE payments ADD COLUMN IF NOT EXISTS interest_amount DECIMAL(10,2);
COMMENT ON COLUMN payments.interest_amount IS 
'Monto de interés correspondiente a este periodo. Parte del expected_amount que representa el costo del préstamo.';

-- Abono a capital de este periodo
ALTER TABLE payments ADD COLUMN IF NOT EXISTS principal_amount DECIMAL(10,2);
COMMENT ON COLUMN payments.principal_amount IS 
'Monto de capital (abono al principal) correspondiente a este periodo. Reduce el saldo pendiente del préstamo.';

-- Comisión que se descuenta al asociado en este pago
ALTER TABLE payments ADD COLUMN IF NOT EXISTS commission_amount DECIMAL(10,2);
COMMENT ON COLUMN payments.commission_amount IS 
'Monto de comisión que se descuenta al asociado en este pago. Se calcula sobre el expected_amount.';

-- Pago neto que recibe el asociado (después de comisión)
ALTER TABLE payments ADD COLUMN IF NOT EXISTS associate_payment DECIMAL(10,2);
COMMENT ON COLUMN payments.associate_payment IS 
'Monto neto que recibe el asociado en este periodo (expected_amount - commission_amount).';

-- Saldo pendiente después de aplicar este pago
ALTER TABLE payments ADD COLUMN IF NOT EXISTS balance_remaining DECIMAL(12,2);
COMMENT ON COLUMN payments.balance_remaining IS 
'Saldo pendiente del préstamo después de aplicar el abono a capital de este pago. El último pago debe dejar balance=0.';

-- ============================================================================
-- PASO 2: Crear índices para mejorar consultas
-- ============================================================================

-- Índice único compuesto: Un préstamo no puede tener 2 pagos con el mismo número
CREATE UNIQUE INDEX IF NOT EXISTS idx_payments_loan_number_unique 
ON payments(loan_id, payment_number) 
WHERE payment_number IS NOT NULL;

-- Índice para ordenar pagos por número
CREATE INDEX IF NOT EXISTS idx_payments_payment_number 
ON payments(payment_number) 
WHERE payment_number IS NOT NULL;

-- Índice para búsquedas por monto esperado
CREATE INDEX IF NOT EXISTS idx_payments_expected_amount 
ON payments(expected_amount) 
WHERE expected_amount IS NOT NULL;

-- Índice para búsquedas por saldo pendiente
CREATE INDEX IF NOT EXISTS idx_payments_balance_remaining 
ON payments(balance_remaining) 
WHERE balance_remaining IS NOT NULL;

-- Índice compuesto para análisis de morosidad
CREATE INDEX IF NOT EXISTS idx_payments_due_date_status_expected 
ON payments(payment_due_date, status_id, expected_amount) 
WHERE expected_amount IS NOT NULL;

-- ============================================================================
-- PASO 3: Agregar constraints de validación
-- ============================================================================

-- El número de pago debe ser positivo
ALTER TABLE payments ADD CONSTRAINT chk_payments_payment_number_positive 
CHECK (payment_number IS NULL OR payment_number > 0);

-- El monto esperado debe ser positivo
ALTER TABLE payments ADD CONSTRAINT chk_payments_expected_amount_positive 
CHECK (expected_amount IS NULL OR expected_amount > 0);

-- El interés no puede ser negativo
ALTER TABLE payments ADD CONSTRAINT chk_payments_interest_non_negative 
CHECK (interest_amount IS NULL OR interest_amount >= 0);

-- El capital no puede ser negativo
ALTER TABLE payments ADD CONSTRAINT chk_payments_principal_non_negative 
CHECK (principal_amount IS NULL OR principal_amount >= 0);

-- La comisión no puede ser negativa
ALTER TABLE payments ADD CONSTRAINT chk_payments_commission_non_negative 
CHECK (commission_amount IS NULL OR commission_amount >= 0);

-- El pago al asociado no puede ser negativo
ALTER TABLE payments ADD CONSTRAINT chk_payments_associate_payment_non_negative 
CHECK (associate_payment IS NULL OR associate_payment >= 0);

-- El saldo pendiente no puede ser negativo
ALTER TABLE payments ADD CONSTRAINT chk_payments_balance_non_negative 
CHECK (balance_remaining IS NULL OR balance_remaining >= 0);

-- ============================================================================
-- PASO 4: Validación de consistencia matemática
-- ============================================================================

-- expected_amount = interest_amount + principal_amount (con tolerancia de 0.10 centavos)
ALTER TABLE payments ADD CONSTRAINT chk_payments_expected_equals_interest_plus_principal
CHECK (
    expected_amount IS NULL 
    OR interest_amount IS NULL 
    OR principal_amount IS NULL
    OR ABS(expected_amount - (interest_amount + principal_amount)) < 0.10
);

-- associate_payment = expected_amount - commission_amount (con tolerancia de 0.10 centavos)
ALTER TABLE payments ADD CONSTRAINT chk_payments_associate_equals_expected_minus_commission
CHECK (
    associate_payment IS NULL
    OR expected_amount IS NULL
    OR commission_amount IS NULL
    OR ABS(associate_payment - (expected_amount - commission_amount)) < 0.10
);

-- El pago al asociado no puede ser mayor que el monto esperado
ALTER TABLE payments ADD CONSTRAINT chk_payments_associate_lte_expected
CHECK (
    associate_payment IS NULL
    OR expected_amount IS NULL
    OR associate_payment <= expected_amount
);

-- Si amount_paid > 0, no puede ser mayor que expected_amount
ALTER TABLE payments ADD CONSTRAINT chk_payments_paid_lte_expected
CHECK (
    expected_amount IS NULL
    OR amount_paid <= expected_amount + 100.00  -- Tolerancia para sobrepagos
);

-- ============================================================================
-- PASO 5: Crear función para validar consistencia de pagos
-- ============================================================================

CREATE OR REPLACE FUNCTION validate_payment_breakdown(
    p_payment_id INTEGER
) RETURNS TABLE (
    validacion TEXT,
    valor_actual DECIMAL,
    valor_esperado DECIMAL,
    diferencia DECIMAL,
    es_valido BOOLEAN
) 
LANGUAGE plpgsql
AS $$
DECLARE
    v_payment RECORD;
BEGIN
    -- Obtener datos del pago
    SELECT 
        payment_number, expected_amount, interest_amount, principal_amount,
        commission_amount, associate_payment, amount_paid, balance_remaining
    INTO v_payment
    FROM payments
    WHERE id = p_payment_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Pago % no encontrado', p_payment_id;
    END IF;
    
    -- Validar expected_amount = interest_amount + principal_amount
    IF v_payment.expected_amount IS NOT NULL AND v_payment.interest_amount IS NOT NULL AND v_payment.principal_amount IS NOT NULL THEN
        RETURN QUERY SELECT 
            'expected = interest + principal'::TEXT,
            v_payment.expected_amount,
            v_payment.interest_amount + v_payment.principal_amount,
            v_payment.expected_amount - (v_payment.interest_amount + v_payment.principal_amount),
            ABS(v_payment.expected_amount - (v_payment.interest_amount + v_payment.principal_amount)) < 0.10;
    END IF;
    
    -- Validar associate_payment = expected_amount - commission_amount
    IF v_payment.associate_payment IS NOT NULL AND v_payment.expected_amount IS NOT NULL AND v_payment.commission_amount IS NOT NULL THEN
        RETURN QUERY SELECT 
            'associate = expected - commission'::TEXT,
            v_payment.associate_payment,
            v_payment.expected_amount - v_payment.commission_amount,
            v_payment.associate_payment - (v_payment.expected_amount - v_payment.commission_amount),
            ABS(v_payment.associate_payment - (v_payment.expected_amount - v_payment.commission_amount)) < 0.10;
    END IF;
    
    -- Validar amount_paid <= expected_amount (permitir sobrepago de hasta 100)
    IF v_payment.amount_paid IS NOT NULL AND v_payment.expected_amount IS NOT NULL THEN
        RETURN QUERY SELECT 
            'paid <= expected'::TEXT,
            v_payment.amount_paid,
            v_payment.expected_amount,
            v_payment.amount_paid - v_payment.expected_amount,
            v_payment.amount_paid <= v_payment.expected_amount + 100.00;
    END IF;
END;
$$;

COMMENT ON FUNCTION validate_payment_breakdown(INTEGER) IS 
'Valida que el desglose matemático del pago sea consistente. Retorna una tabla con las validaciones.';

-- ============================================================================
-- PASO 6: Crear función para validar cronograma completo de un préstamo
-- ============================================================================

CREATE OR REPLACE FUNCTION validate_loan_payment_schedule(
    p_loan_id INTEGER
) RETURNS TABLE (
    validacion TEXT,
    valor DECIMAL,
    esperado DECIMAL,
    diferencia DECIMAL,
    es_valido BOOLEAN,
    detalle TEXT
) 
LANGUAGE plpgsql
AS $$
DECLARE
    v_loan RECORD;
    v_payment_count INTEGER;
    v_sum_expected DECIMAL;
    v_sum_interest DECIMAL;
    v_sum_principal DECIMAL;
    v_sum_commission DECIMAL;
    v_last_balance DECIMAL;
    v_numbers_ok BOOLEAN;
BEGIN
    -- Obtener datos del préstamo
    SELECT 
        id, amount, term_biweeks, total_payment, total_interest,
        total_commission, biweekly_payment
    INTO v_loan
    FROM loans
    WHERE id = p_loan_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Préstamo % no encontrado', p_loan_id;
    END IF;
    
    -- Contar pagos generados
    SELECT COUNT(*) INTO v_payment_count
    FROM payments
    WHERE loan_id = p_loan_id;
    
    -- Validar: Cantidad de pagos = term_biweeks
    RETURN QUERY SELECT 
        'Cantidad de pagos'::TEXT,
        v_payment_count::DECIMAL,
        v_loan.term_biweeks::DECIMAL,
        (v_payment_count - v_loan.term_biweeks)::DECIMAL,
        v_payment_count = v_loan.term_biweeks,
        format('Se esperaban %s pagos, se encontraron %s', v_loan.term_biweeks, v_payment_count);
    
    -- Validar: payment_number son secuenciales (1, 2, 3, ..., N)
    SELECT COUNT(*) = v_payment_count INTO v_numbers_ok
    FROM (
        SELECT payment_number
        FROM payments
        WHERE loan_id = p_loan_id
        ORDER BY payment_number
    ) t
    WHERE payment_number BETWEEN 1 AND v_payment_count;
    
    RETURN QUERY SELECT 
        'Números secuenciales'::TEXT,
        CASE WHEN v_numbers_ok THEN 1::DECIMAL ELSE 0::DECIMAL END,
        1::DECIMAL,
        CASE WHEN v_numbers_ok THEN 0::DECIMAL ELSE 1::DECIMAL END,
        v_numbers_ok,
        CASE WHEN v_numbers_ok 
            THEN 'Los números de pago son secuenciales (1..N)'
            ELSE 'Los números de pago NO son secuenciales'
        END;
    
    -- Calcular sumas
    SELECT 
        COALESCE(SUM(expected_amount), 0),
        COALESCE(SUM(interest_amount), 0),
        COALESCE(SUM(principal_amount), 0),
        COALESCE(SUM(commission_amount), 0)
    INTO v_sum_expected, v_sum_interest, v_sum_principal, v_sum_commission
    FROM payments
    WHERE loan_id = p_loan_id;
    
    -- Validar: SUM(expected_amount) = loans.total_payment
    IF v_loan.total_payment IS NOT NULL THEN
        RETURN QUERY SELECT 
            'SUM(expected) = total_payment'::TEXT,
            v_sum_expected,
            v_loan.total_payment,
            v_sum_expected - v_loan.total_payment,
            ABS(v_sum_expected - v_loan.total_payment) < 1.00,
            format('Suma de pagos esperados: $%s, Total préstamo: $%s', v_sum_expected, v_loan.total_payment);
    END IF;
    
    -- Validar: SUM(interest_amount) = loans.total_interest
    IF v_loan.total_interest IS NOT NULL THEN
        RETURN QUERY SELECT 
            'SUM(interest) = total_interest'::TEXT,
            v_sum_interest,
            v_loan.total_interest,
            v_sum_interest - v_loan.total_interest,
            ABS(v_sum_interest - v_loan.total_interest) < 1.00,
            format('Suma de intereses: $%s, Total interés préstamo: $%s', v_sum_interest, v_loan.total_interest);
    END IF;
    
    -- Validar: SUM(principal_amount) = loans.amount
    RETURN QUERY SELECT 
        'SUM(principal) = amount'::TEXT,
        v_sum_principal,
        v_loan.amount,
        v_sum_principal - v_loan.amount,
        ABS(v_sum_principal - v_loan.amount) < 1.00,
        format('Suma de abonos a capital: $%s, Capital préstamo: $%s', v_sum_principal, v_loan.amount);
    
    -- Validar: SUM(commission_amount) = loans.total_commission
    IF v_loan.total_commission IS NOT NULL THEN
        RETURN QUERY SELECT 
            'SUM(commission) = total_commission'::TEXT,
            v_sum_commission,
            v_loan.total_commission,
            v_sum_commission - v_loan.total_commission,
            ABS(v_sum_commission - v_loan.total_commission) < 1.00,
            format('Suma de comisiones: $%s, Total comisión préstamo: $%s', v_sum_commission, v_loan.total_commission);
    END IF;
    
    -- Validar: Último pago tiene balance_remaining = 0
    SELECT balance_remaining INTO v_last_balance
    FROM payments
    WHERE loan_id = p_loan_id
    ORDER BY payment_number DESC
    LIMIT 1;
    
    IF v_last_balance IS NOT NULL THEN
        RETURN QUERY SELECT 
            'Último pago balance = 0'::TEXT,
            v_last_balance,
            0::DECIMAL,
            v_last_balance,
            ABS(v_last_balance) < 0.10,
            format('El saldo después del último pago es: $%s (debe ser $0.00)', v_last_balance);
    END IF;
END;
$$;

COMMENT ON FUNCTION validate_loan_payment_schedule(INTEGER) IS 
'Valida el cronograma completo de pagos de un préstamo. Verifica cantidades, sumas, secuencias y consistencia.';

-- ============================================================================
-- PASO 7: Crear vista de resumen de pagos
-- ============================================================================

CREATE OR REPLACE VIEW v_payments_summary AS
SELECT 
    p.id,
    p.loan_id,
    l.user_id,
    u.username,
    p.payment_number,
    p.payment_due_date as fecha_vencimiento,
    p.expected_amount as monto_esperado,
    p.amount_paid as monto_pagado,
    p.interest_amount as interes,
    p.principal_amount as capital,
    p.commission_amount as comision,
    p.associate_payment as pago_asociado,
    p.balance_remaining as saldo_pendiente,
    ps.name as estado_pago,
    cp.period_start_date as periodo_inicio,
    cp.period_end_date as periodo_fin,
    p.is_late as esta_atrasado,
    -- Cálculos derivados
    CASE 
        WHEN p.expected_amount > 0 THEN ROUND((p.amount_paid / p.expected_amount) * 100, 2)
        ELSE 0
    END as porcentaje_pagado,
    CASE
        WHEN p.amount_paid >= p.expected_amount THEN 'PAGADO COMPLETO'
        WHEN p.amount_paid > 0 THEN 'PAGO PARCIAL'
        ELSE 'SIN PAGAR'
    END as estado_pago_detalle,
    p.expected_amount - p.amount_paid as saldo_pago
FROM payments p
INNER JOIN loans l ON p.loan_id = l.id
LEFT JOIN users u ON l.user_id = u.id
LEFT JOIN payment_statuses ps ON p.status_id = ps.id
LEFT JOIN cut_periods cp ON p.cut_period_id = cp.id
WHERE p.expected_amount IS NOT NULL
ORDER BY l.id, p.payment_number;

COMMENT ON VIEW v_payments_summary IS 
'Vista de resumen de pagos con desglose completo y métricas derivadas.';

-- ============================================================================
-- PASO 8: Migración de datos existentes (si aplica)
-- ============================================================================

-- NOTA: Los payments existentes fueron creados con el trigger antiguo
-- que NO insertaba estos campos. Por ahora los dejamos NULL.
-- Cuando se regeneren con el nuevo trigger, tendrán todos los campos.

DO $$
DECLARE
    v_payments_count INTEGER;
    v_payments_with_expected INTEGER;
BEGIN
    -- Contar pagos existentes
    SELECT COUNT(*) INTO v_payments_count FROM payments;
    
    -- Contar pagos que ya tienen expected_amount
    SELECT COUNT(*) INTO v_payments_with_expected 
    FROM payments 
    WHERE expected_amount IS NOT NULL;
    
    RAISE NOTICE 'Pagos existentes: %', v_payments_count;
    RAISE NOTICE 'Pagos con expected_amount: %', v_payments_with_expected;
    RAISE NOTICE 'Pagos que necesitan regeneración: %', (v_payments_count - v_payments_with_expected);
    
    IF v_payments_count > 0 AND v_payments_with_expected = 0 THEN
        RAISE WARNING 'IMPORTANTE: Hay % pagos sin expected_amount. Necesitarán ser regenerados después de actualizar el trigger.', v_payments_count;
    END IF;
END;
$$;

-- ============================================================================
-- PASO 9: Verificación final
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
    WHERE table_name = 'payments'
      AND column_name IN (
          'payment_number', 'expected_amount', 'interest_amount',
          'principal_amount', 'commission_amount', 'associate_payment',
          'balance_remaining'
      );
    
    IF v_column_count != 7 THEN
        RAISE EXCEPTION 'FALLO: Solo se agregaron % de 7 columnas esperadas', v_column_count;
    END IF;
    
    -- Verificar índices
    SELECT COUNT(*) INTO v_index_count
    FROM pg_indexes
    WHERE tablename = 'payments'
      AND indexname IN (
          'idx_payments_loan_number_unique',
          'idx_payments_payment_number',
          'idx_payments_expected_amount',
          'idx_payments_balance_remaining',
          'idx_payments_due_date_status_expected'
      );
    
    IF v_index_count != 5 THEN
        RAISE WARNING 'Advertencia: Solo se crearon % de 5 índices esperados', v_index_count;
    END IF;
    
    -- Verificar constraints
    SELECT COUNT(*) INTO v_constraint_count
    FROM information_schema.table_constraints
    WHERE table_name = 'payments'
      AND constraint_type = 'CHECK'
      AND (
          constraint_name LIKE 'chk_payments_%positive%'
          OR constraint_name LIKE 'chk_payments_%negative%'
          OR constraint_name LIKE 'chk_payments_%equals%'
          OR constraint_name LIKE 'chk_payments_%lte%'
      );
    
    RAISE NOTICE '✅ Migración completada exitosamente:';
    RAISE NOTICE '   - Columnas agregadas: %', v_column_count;
    RAISE NOTICE '   - Índices creados: %', v_index_count;
    RAISE NOTICE '   - Constraints aplicados: %', v_constraint_count;
    RAISE NOTICE '   - Funciones creadas: validate_payment_breakdown(), validate_loan_payment_schedule()';
    RAISE NOTICE '   - Vista creada: v_payments_summary';
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
DROP VIEW IF EXISTS v_payments_summary;

-- Eliminar funciones
DROP FUNCTION IF EXISTS validate_payment_breakdown(INTEGER);
DROP FUNCTION IF EXISTS validate_loan_payment_schedule(INTEGER);

-- Eliminar constraints
ALTER TABLE payments DROP CONSTRAINT IF EXISTS chk_payments_payment_number_positive;
ALTER TABLE payments DROP CONSTRAINT IF EXISTS chk_payments_expected_amount_positive;
ALTER TABLE payments DROP CONSTRAINT IF EXISTS chk_payments_interest_non_negative;
ALTER TABLE payments DROP CONSTRAINT IF EXISTS chk_payments_principal_non_negative;
ALTER TABLE payments DROP CONSTRAINT IF EXISTS chk_payments_commission_non_negative;
ALTER TABLE payments DROP CONSTRAINT IF EXISTS chk_payments_associate_payment_non_negative;
ALTER TABLE payments DROP CONSTRAINT IF EXISTS chk_payments_balance_non_negative;
ALTER TABLE payments DROP CONSTRAINT IF EXISTS chk_payments_expected_equals_interest_plus_principal;
ALTER TABLE payments DROP CONSTRAINT IF EXISTS chk_payments_associate_equals_expected_minus_commission;
ALTER TABLE payments DROP CONSTRAINT IF EXISTS chk_payments_associate_lte_expected;
ALTER TABLE payments DROP CONSTRAINT IF EXISTS chk_payments_paid_lte_expected;

-- Eliminar índices
DROP INDEX IF EXISTS idx_payments_loan_number_unique;
DROP INDEX IF EXISTS idx_payments_payment_number;
DROP INDEX IF EXISTS idx_payments_expected_amount;
DROP INDEX IF EXISTS idx_payments_balance_remaining;
DROP INDEX IF EXISTS idx_payments_due_date_status_expected;

-- Eliminar columnas
ALTER TABLE payments DROP COLUMN IF EXISTS payment_number;
ALTER TABLE payments DROP COLUMN IF EXISTS expected_amount;
ALTER TABLE payments DROP COLUMN IF EXISTS interest_amount;
ALTER TABLE payments DROP COLUMN IF EXISTS principal_amount;
ALTER TABLE payments DROP COLUMN IF EXISTS commission_amount;
ALTER TABLE payments DROP COLUMN IF EXISTS associate_payment;
ALTER TABLE payments DROP COLUMN IF EXISTS balance_remaining;

COMMIT;
*/

-- ============================================================================
-- FIN DE MIGRACIÓN 006
-- ============================================================================
