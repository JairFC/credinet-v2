-- =============================================================================
-- CORRECCIONES CRÍTICAS - LÓGICA DE CRÉDITO BASADA EN associate_payment
-- =============================================================================
-- Fecha: 2026-01-07
-- Issue: El crédito debe rastrear lo que el asociado PAGA a CrediCuenta,
--        no solo el capital prestado.
--
-- Fórmula correcta:
--   credit_used = SUM(associate_payment) de todos los pagos pendientes
--   associate_payment = expected_amount - commission_amount
--
-- Ejemplo:
--   Préstamo $22,000 → Cliente paga $36,025 total
--   → Comisión total $5,280 → Asociado paga $30,745 a CrediCuenta
--   → credit_used debe ser $30,745, NO $22,000
-- =============================================================================

-- =============================================================================
-- CORRECCIÓN 1: Trigger al APROBAR préstamo
-- =============================================================================
-- Cambio: Sumar associate_payment total en lugar de solo loan.amount
-- =============================================================================

CREATE OR REPLACE FUNCTION trigger_update_associate_credit_on_loan_approval()
RETURNS TRIGGER AS $$
DECLARE
    v_associate_profile_id INTEGER;
    v_approved_status_id INTEGER;
    v_total_associate_payment DECIMAL(12,2);
BEGIN
    SELECT id INTO v_approved_status_id FROM loan_statuses WHERE name = 'APPROVED';
    
    -- Solo ejecutar cuando el préstamo pasa a APPROVED
    IF NEW.status_id = v_approved_status_id 
       AND (OLD.status_id IS NULL OR OLD.status_id != v_approved_status_id) 
    THEN
        IF NEW.associate_user_id IS NOT NULL THEN
            SELECT id INTO v_associate_profile_id
            FROM associate_profiles
            WHERE user_id = NEW.associate_user_id;
            
            IF v_associate_profile_id IS NOT NULL THEN
                -- ✅ CORRECCIÓN CRÍTICA:
                -- Calcular el TOTAL que el asociado pagará a CrediCuenta
                -- Esto es la suma de associate_payment de todos los pagos del préstamo
                -- associate_payment = expected_amount - commission_amount
                -- = (capital + interés) que el asociado debe entregar a CrediCuenta
                
                SELECT COALESCE(SUM(associate_payment), 0)
                INTO v_total_associate_payment
                FROM payments
                WHERE loan_id = NEW.id;
                
                -- Si no hay pagos generados aún (no debería pasar), usar el monto del préstamo
                IF v_total_associate_payment = 0 THEN
                    RAISE WARNING 'Préstamo % aprobado pero sin cronograma. Usando amount como fallback.', 
                        NEW.id;
                    v_total_associate_payment := NEW.amount;
                END IF;
                
                -- Incrementar credit_used por lo que el asociado PAGARÁ a CrediCuenta
                UPDATE associate_profiles
                SET credit_used = credit_used + v_total_associate_payment,
                    credit_last_updated = CURRENT_TIMESTAMP
                WHERE id = v_associate_profile_id;
                
                RAISE NOTICE 'Crédito del asociado % actualizado: +$% (total a pagar a CrediCuenta)', 
                    v_associate_profile_id, v_total_associate_payment;
            END IF;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION trigger_update_associate_credit_on_loan_approval() IS
'⭐ CORRECCIÓN 2026-01-07: Incrementa credit_used por el TOTAL que el asociado pagará a CrediCuenta (suma de associate_payment), no solo el capital. Ejemplo: préstamo $10k → asociado paga $12k a CrediCuenta → credit_used += $12k.';

-- =============================================================================
-- CORRECCIÓN 2: Trigger al PAGAR
-- =============================================================================
-- Cambio: Liberar associate_payment en lugar de solo capital
-- =============================================================================

CREATE OR REPLACE FUNCTION trigger_update_associate_credit_on_payment()
RETURNS TRIGGER AS $$
DECLARE
    v_associate_user_id INTEGER;
    v_associate_profile_id INTEGER;
    v_amount_diff DECIMAL(12,2);
    v_payment_liberation DECIMAL(12,2);
    v_expected_amount DECIMAL(12,2);
    v_associate_payment DECIMAL(12,2);
BEGIN
    -- Solo ejecutar si amount_paid cambió
    IF NEW.amount_paid != OLD.amount_paid THEN
        SELECT associate_user_id INTO v_associate_user_id
        FROM loans
        WHERE id = NEW.loan_id;
        
        IF v_associate_user_id IS NOT NULL THEN
            SELECT id INTO v_associate_profile_id
            FROM associate_profiles
            WHERE user_id = v_associate_user_id;
            
            IF v_associate_profile_id IS NOT NULL THEN
                v_amount_diff := NEW.amount_paid - OLD.amount_paid;
                v_expected_amount := NEW.expected_amount;
                v_associate_payment := NEW.associate_payment;
                
                -- ✅ CORRECCIÓN CRÍTICA:
                -- Liberar lo que el asociado debe PAGAR a CrediCuenta (associate_payment)
                -- NO solo el capital
                
                -- Si el pago está completo (amount_paid >= expected_amount)
                IF NEW.amount_paid >= v_expected_amount THEN
                    -- Liberar el monto completo de associate_payment
                    v_payment_liberation := v_associate_payment;
                ELSE
                    -- Pago parcial: liberar proporción de associate_payment
                    -- payment_liberation = associate_payment * (amount_paid / expected_amount)
                    v_payment_liberation := v_associate_payment * (v_amount_diff / v_expected_amount);
                END IF;
                
                -- Liberar lo que el asociado pagará a CrediCuenta
                UPDATE associate_profiles
                SET credit_used = GREATEST(credit_used - v_payment_liberation, 0),
                    credit_last_updated = CURRENT_TIMESTAMP
                WHERE id = v_associate_profile_id;
                
                RAISE NOTICE 'Crédito del asociado % actualizado: pago $%, liberado $% (associate_payment)', 
                    v_associate_profile_id, v_amount_diff, v_payment_liberation;
            END IF;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION trigger_update_associate_credit_on_payment() IS
'⭐ CORRECCIÓN 2026-01-07: Decrementa credit_used por el monto que el asociado debe PAGAR a CrediCuenta (associate_payment = expected_amount - commission), no solo capital. Ejemplo: cliente paga $1,250 → comisión $250 → asociado paga $1,000 → se libera $1,000 de crédito.';

-- =============================================================================
-- CORRECCIÓN 3: Función de cálculo de saldo
-- =============================================================================
-- Cambio: Sumar associate_payment en lugar de expected_amount
-- =============================================================================

CREATE OR REPLACE FUNCTION calculate_loan_remaining_balance(p_loan_id INTEGER)
RETURNS DECIMAL(12,2)
LANGUAGE plpgsql
AS $$
DECLARE
    v_pending_status_id INTEGER;
    v_remaining_balance DECIMAL(12,2);
BEGIN
    -- Obtener ID del estado PENDING
    SELECT id INTO v_pending_status_id 
    FROM payment_statuses 
    WHERE name = 'PENDING';
    
    IF v_pending_status_id IS NULL THEN
        RAISE EXCEPTION 'CRITICAL: payment_statuses.PENDING no encontrado';
    END IF;
    
    -- ✅ CORRECCIÓN CRÍTICA:
    -- Sumar associate_payment (lo que debe pagar a CrediCuenta)
    -- NO expected_amount (lo que el cliente paga al asociado)
    --
    -- Lógica:
    -- - expected_amount = capital + interés (lo que cliente paga)
    -- - commission_amount = ganancia del asociado
    -- - associate_payment = expected_amount - commission_amount
    --                     = lo que el asociado debe entregar a CrediCuenta
    --
    -- El saldo pendiente del préstamo es lo que el asociado aún debe
    -- entregar a CrediCuenta, NO lo que el cliente debe al asociado.
    
    SELECT COALESCE(SUM(associate_payment), 0)
    INTO v_remaining_balance
    FROM payments
    WHERE loan_id = p_loan_id 
    AND status_id = v_pending_status_id;
    
    RETURN v_remaining_balance;
END;
$$;

COMMENT ON FUNCTION calculate_loan_remaining_balance(INTEGER) IS
'⭐ CORRECCIÓN 2026-01-07: Calcula el saldo pendiente del préstamo sumando associate_payment de pagos PENDING. Esto representa lo que el asociado aún debe pagar a CrediCuenta, no lo que el cliente debe al asociado. Ejemplo: si quedan 3 pagos de $1,000 cada uno (associate_payment), el saldo es $3,000.';

-- =============================================================================
-- VALIDACIÓN DE CORRECCIONES
-- =============================================================================

-- Query de validación: Ver un préstamo completo
-- SELECT 
--     l.id as loan_id,
--     l.amount as capital,
--     l.total_payment,
--     l.term_biweeks,
--     l.biweekly_payment,
--     l.commission_per_payment,
--     -- Totales calculados
--     (SELECT SUM(expected_amount) FROM payments WHERE loan_id = l.id) as total_cliente_paga,
--     (SELECT SUM(commission_amount) FROM payments WHERE loan_id = l.id) as total_comision,
--     (SELECT SUM(associate_payment) FROM payments WHERE loan_id = l.id) as total_asociado_paga,
--     -- Asociado
--     ap.credit_limit,
--     ap.credit_used,
--     ap.credit_available
-- FROM loans l
-- JOIN associate_profiles ap ON ap.user_id = l.associate_user_id
-- WHERE l.id = 95;

-- Query de validación: Ver un pago individual
-- SELECT 
--     id,
--     loan_id,
--     payment_number,
--     expected_amount,      -- Cliente paga al asociado
--     commission_amount,    -- Asociado se queda
--     associate_payment,    -- Asociado paga a CrediCuenta
--     principal_amount,     -- Porción de capital
--     interest_amount       -- Porción de interés
-- FROM payments 
-- WHERE loan_id = 95 
-- ORDER BY payment_number 
-- LIMIT 3;

-- =============================================================================
-- FIN DE CORRECCIONES
-- =============================================================================
