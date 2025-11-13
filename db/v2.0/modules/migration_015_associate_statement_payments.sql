-- =============================================================================
-- MIGRACIÓN 015: ASSOCIATE_STATEMENT_PAYMENTS - Tracking de Abonos Parciales
-- =============================================================================
-- Descripción:
--   Crea la tabla associate_statement_payments para registrar abonos parciales
--   del asociado a los estados de cuenta (saldo actual).
--
-- Propósito:
--   Implementar el tracking completo de abonos al "SALDO ACTUAL" del período.
--   Esta tabla es CRÍTICA para la lógica de cierre y cálculo de mora.
--
-- Dependencias:
--   - associate_payment_statements (debe existir)
--   - payment_methods (debe existir)
--   - users (debe existir)
--
-- Autor: GitHub Copilot (Piloto Principal)
-- Fecha: 2025-11-11
-- Versión: 2.0.4
-- =============================================================================

-- =============================================================================
-- PASO 1: CREAR TABLA associate_statement_payments
-- =============================================================================

CREATE TABLE IF NOT EXISTS associate_statement_payments (
    id SERIAL PRIMARY KEY,
    statement_id INTEGER NOT NULL REFERENCES associate_payment_statements(id) ON DELETE CASCADE,
    payment_amount DECIMAL(12, 2) NOT NULL,
    payment_date DATE NOT NULL,
    payment_method_id INTEGER NOT NULL REFERENCES payment_methods(id),
    payment_reference VARCHAR(100),
    registered_by INTEGER NOT NULL REFERENCES users(id),
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Validaciones
    CONSTRAINT check_statement_payments_amount_positive CHECK (payment_amount > 0),
    CONSTRAINT check_statement_payments_date_logical CHECK (payment_date <= CURRENT_DATE)
);

COMMENT ON TABLE associate_statement_payments IS '⭐ NUEVO v2.0.4: Registro detallado de abonos parciales del asociado para liquidar estados de cuenta (SALDO ACTUAL). Permite múltiples pagos por statement con tracking completo.';
COMMENT ON COLUMN associate_statement_payments.statement_id IS 'Referencia al estado de cuenta que se está liquidando (associate_payment_statements).';
COMMENT ON COLUMN associate_statement_payments.payment_amount IS 'Monto del abono (puede ser parcial). Múltiples abonos se suman para liquidar el statement.';
COMMENT ON COLUMN associate_statement_payments.payment_reference IS 'Referencia bancaria (ej: SPEI-123456) o número de recibo para transferencias/depósitos.';
COMMENT ON COLUMN associate_statement_payments.registered_by IS 'Usuario que registró el abono (normalmente admin o auxiliar administrativo).';
COMMENT ON COLUMN associate_statement_payments.notes IS 'Notas adicionales sobre el abono (ej: "Abono parcial, liquidación completa pendiente").';

-- =============================================================================
-- PASO 2: CREAR ÍNDICES
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_statement_payments_statement_id ON associate_statement_payments(statement_id);
CREATE INDEX IF NOT EXISTS idx_statement_payments_payment_date ON associate_statement_payments(payment_date);
CREATE INDEX IF NOT EXISTS idx_statement_payments_registered_by ON associate_statement_payments(registered_by);
CREATE INDEX IF NOT EXISTS idx_statement_payments_method ON associate_statement_payments(payment_method_id);

-- Índice compuesto para consultas de resumen por statement
CREATE INDEX IF NOT EXISTS idx_statement_payments_statement_amount ON associate_statement_payments(statement_id, payment_amount);

-- =============================================================================
-- PASO 3: CREAR FUNCIÓN PARA ACTUALIZAR STATEMENT AL REGISTRAR ABONO
-- =============================================================================

CREATE OR REPLACE FUNCTION update_statement_on_payment()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_total_paid DECIMAL(12,2);
    v_total_amount_collected DECIMAL(12,2);
    v_total_commission_owed DECIMAL(12,2);
    v_associate_payment_total DECIMAL(12,2);
    v_excess_amount DECIMAL(12,2);
BEGIN
    -- Calcular total de abonos realizados al statement
    SELECT COALESCE(SUM(payment_amount), 0)
    INTO v_total_paid
    FROM associate_statement_payments
    WHERE statement_id = NEW.statement_id;
    
    -- Obtener totales del statement
    SELECT total_amount_collected, total_commission_owed
    INTO v_total_amount_collected, v_total_commission_owed
    FROM associate_payment_statements
    WHERE id = NEW.statement_id;
    
    -- Calcular lo que el asociado debe pagar (collected - commission)
    v_associate_payment_total := v_total_amount_collected - v_total_commission_owed;
    
    -- Actualizar paid_amount en el statement
    UPDATE associate_payment_statements
    SET 
        paid_amount = v_total_paid,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = NEW.statement_id;
    
    -- Si el pago cubre el total adeudado
    IF v_total_paid >= v_associate_payment_total THEN
        -- Marcar statement como PAID
        UPDATE associate_payment_statements
        SET 
            status_id = (SELECT id FROM statement_statuses WHERE name = 'PAID'),
            paid_date = NEW.payment_date,
            updated_at = CURRENT_TIMESTAMP
        WHERE id = NEW.statement_id;
        
        -- Calcular excedente
        v_excess_amount := v_total_paid - v_associate_payment_total;
        
        -- Si hay excedente, aplicar a deuda acumulada (FIFO)
        IF v_excess_amount > 0 THEN
            -- Aplicar FIFO en associate_debt_breakdown
            PERFORM apply_excess_to_debt_fifo(
                p_associate_profile_id := (
                    SELECT ap.id 
                    FROM associate_payment_statements aps
                    JOIN users u ON u.id = aps.user_id
                    JOIN associate_profiles ap ON ap.user_id = u.id
                    WHERE aps.id = NEW.statement_id
                ),
                p_excess_amount := v_excess_amount,
                p_payment_reference := NEW.payment_reference
            );
        END IF;
    ELSIF v_total_paid > 0 THEN
        -- Pago parcial
        UPDATE associate_payment_statements
        SET 
            status_id = (SELECT id FROM statement_statuses WHERE name = 'PARTIAL_PAID'),
            updated_at = CURRENT_TIMESTAMP
        WHERE id = NEW.statement_id;
    END IF;
    
    RAISE NOTICE 'Statement % actualizado: paid_amount = %, total_required = %', 
                 NEW.statement_id, v_total_paid, v_associate_payment_total;
    
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION update_statement_on_payment() IS '⭐ v2.0.4: Trigger que actualiza automáticamente el estado de cuenta cuando se registra un abono. Suma todos los abonos, calcula saldo restante, actualiza estado (PARTIAL_PAID o PAID), y LIBERA CRÉDITO automáticamente aplicando excedente a deuda (FIFO).';

-- =============================================================================
-- PASO 4: CREAR TRIGGER
-- =============================================================================

CREATE TRIGGER trigger_update_statement_on_payment
AFTER INSERT ON associate_statement_payments
FOR EACH ROW
EXECUTE FUNCTION update_statement_on_payment();

COMMENT ON TRIGGER trigger_update_statement_on_payment ON associate_statement_payments IS
'Actualiza el estado de cuenta automáticamente cuando se registra un abono, aplicando excedentes a deuda acumulada vía FIFO.';

-- =============================================================================
-- PASO 5: CREAR FUNCIÓN HELPER PARA FIFO (si no existe)
-- =============================================================================

CREATE OR REPLACE FUNCTION apply_excess_to_debt_fifo(
    p_associate_profile_id INTEGER,
    p_excess_amount DECIMAL(12,2),
    p_payment_reference VARCHAR(100)
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_remaining_amount DECIMAL(12,2);
    v_debt_record RECORD;
BEGIN
    v_remaining_amount := p_excess_amount;
    
    -- Aplicar FIFO: liquidar deudas más antiguas primero
    FOR v_debt_record IN (
        SELECT id, amount
        FROM associate_debt_breakdown
        WHERE associate_profile_id = p_associate_profile_id
          AND is_liquidated = false
        ORDER BY created_at ASC, id ASC  -- ⭐ FIFO
    )
    LOOP
        EXIT WHEN v_remaining_amount <= 0;
        
        IF v_remaining_amount >= v_debt_record.amount THEN
            -- Liquidar completamente este item
            UPDATE associate_debt_breakdown
            SET 
                is_liquidated = true,
                liquidated_at = CURRENT_TIMESTAMP,
                liquidation_reference = p_payment_reference,
                updated_at = CURRENT_TIMESTAMP
            WHERE id = v_debt_record.id;
            
            v_remaining_amount := v_remaining_amount - v_debt_record.amount;
            
            RAISE NOTICE 'Deuda % liquidada completamente (monto: %)', 
                         v_debt_record.id, v_debt_record.amount;
        ELSE
            -- Liquidar parcialmente (reducir monto del item)
            UPDATE associate_debt_breakdown
            SET 
                amount = amount - v_remaining_amount,
                updated_at = CURRENT_TIMESTAMP
            WHERE id = v_debt_record.id;
            
            RAISE NOTICE 'Deuda % liquidada parcialmente (abono: %, restante: %)', 
                         v_debt_record.id, v_remaining_amount, v_debt_record.amount - v_remaining_amount;
            
            v_remaining_amount := 0;
        END IF;
    END LOOP;
    
    -- Actualizar debt_balance del asociado
    UPDATE associate_profiles
    SET 
        debt_balance = (
            SELECT COALESCE(SUM(amount), 0)
            FROM associate_debt_breakdown
            WHERE associate_profile_id = p_associate_profile_id
              AND is_liquidated = false
        ),
        updated_at = CURRENT_TIMESTAMP
    WHERE id = p_associate_profile_id;
    
    RAISE NOTICE 'Excedente aplicado: % (sobrante: %)', p_excess_amount - v_remaining_amount, v_remaining_amount;
END;
$$;

COMMENT ON FUNCTION apply_excess_to_debt_fifo(INTEGER, DECIMAL, VARCHAR) IS '⭐ v2.0.4: Aplica excedente de pago a deuda acumulada usando estrategia FIFO (más antiguos primero). Actualiza debt_balance automáticamente.';

-- =============================================================================
-- PASO 6: CREAR TRIGGER PARA updated_at
-- =============================================================================

CREATE TRIGGER update_associate_statement_payments_updated_at
BEFORE UPDATE ON associate_statement_payments
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- PASO 7: VALIDACIONES POST-MIGRACIÓN
-- =============================================================================

-- Verificar que la tabla existe
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_name = 'associate_statement_payments'
    ) THEN
        RAISE EXCEPTION 'MIGRACIÓN FALLIDA: Tabla associate_statement_payments no fue creada';
    END IF;
    
    RAISE NOTICE '✅ Migración 015 completada exitosamente';
    RAISE NOTICE '   - Tabla: associate_statement_payments';
    RAISE NOTICE '   - Índices: 5 índices creados';
    RAISE NOTICE '   - Funciones: 2 funciones creadas';
    RAISE NOTICE '   - Triggers: 2 triggers creados';
END $$;

-- =============================================================================
-- FIN DE LA MIGRACIÓN 015
-- =============================================================================
