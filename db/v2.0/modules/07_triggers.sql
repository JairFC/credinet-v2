-- =============================================================================
-- CREDINET DB v2.0 - MÓDULO 07: TRIGGERS
-- =============================================================================
-- Descripción:
--   Todos los triggers del sistema organizados por categoría.
--   Incluye triggers de migraciones 07 y 12.
--
-- Categorías:
--   1. Triggers de updated_at (automáticos) - 20 triggers
--   2. Trigger de aprobación de préstamos
--   3. Trigger de generación de schedule ⭐ CRÍTICO
--   4. Trigger de historial de pagos ⭐ MIGRACIÓN 12
--   5. Triggers de crédito del asociado ⭐ MIGRACIÓN 07 (4 triggers)
--   6. Triggers de auditoría general (5 triggers)
--   7. Trigger de actualización de statements ⭐ NUEVO v2.0.1
--
-- Total: 33 triggers
-- Versión: 2.0.1
-- Fecha: 2025-10-31
-- =============================================================================

-- =============================================================================
-- CATEGORÍA 1: TRIGGERS DE UPDATED_AT (15 triggers)
-- =============================================================================

CREATE TRIGGER update_loan_statuses_updated_at 
    BEFORE UPDATE ON loan_statuses 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_contract_statuses_updated_at 
    BEFORE UPDATE ON contract_statuses 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_cut_period_statuses_updated_at 
    BEFORE UPDATE ON cut_period_statuses 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_payment_methods_updated_at 
    BEFORE UPDATE ON payment_methods 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_document_statuses_updated_at 
    BEFORE UPDATE ON document_statuses 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_statement_statuses_updated_at 
    BEFORE UPDATE ON statement_statuses 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_config_types_updated_at 
    BEFORE UPDATE ON config_types 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_level_change_types_updated_at 
    BEFORE UPDATE ON level_change_types 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_users_updated_at 
    BEFORE UPDATE ON users 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_associate_profiles_updated_at 
    BEFORE UPDATE ON associate_profiles 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_addresses_updated_at 
    BEFORE UPDATE ON addresses 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_beneficiaries_updated_at 
    BEFORE UPDATE ON beneficiaries 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_guarantors_updated_at 
    BEFORE UPDATE ON guarantors 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_loans_updated_at 
    BEFORE UPDATE ON loans 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_contracts_updated_at 
    BEFORE UPDATE ON contracts 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_payments_updated_at 
    BEFORE UPDATE ON payments 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_cut_periods_updated_at 
    BEFORE UPDATE ON cut_periods 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_associate_payment_statements_updated_at 
    BEFORE UPDATE ON associate_payment_statements 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_client_documents_updated_at 
    BEFORE UPDATE ON client_documents 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_system_configurations_updated_at 
    BEFORE UPDATE ON system_configurations 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TRIGGER update_loans_updated_at ON loans IS 
'Actualiza automáticamente el campo updated_at cuando se modifica un registro de loans.';

-- =============================================================================
-- CATEGORÍA 2: TRIGGER DE APROBACIÓN DE PRÉSTAMOS
-- =============================================================================

CREATE TRIGGER handle_loan_approval_trigger 
    BEFORE UPDATE ON loans 
    FOR EACH ROW 
    EXECUTE FUNCTION handle_loan_approval_status();

COMMENT ON TRIGGER handle_loan_approval_trigger ON loans IS 
'Setea automáticamente approved_at o rejected_at cuando el estado del préstamo cambia a APPROVED o REJECTED.';

-- =============================================================================
-- CATEGORÍA 3: TRIGGER DE GENERACIÓN DE SCHEDULE ⭐ CRÍTICO
-- =============================================================================

-- Eliminar trigger anterior si existe (idempotencia)
DROP TRIGGER IF EXISTS generate_payment_schedule_trigger ON loans;
DROP TRIGGER IF EXISTS trigger_generate_payment_schedule ON loans;

CREATE TRIGGER trigger_generate_payment_schedule
    AFTER UPDATE OF status_id ON loans
    FOR EACH ROW
    EXECUTE FUNCTION generate_payment_schedule();

COMMENT ON TRIGGER trigger_generate_payment_schedule ON loans IS
'⭐ CRÍTICO: Ejecuta la generación automática del payment schedule cuando el estado del préstamo cambia a APPROVED. Inserta N registros en payments donde N = term_biweeks.';

-- =============================================================================
-- CATEGORÍA 4: TRIGGER DE HISTORIAL DE PAGOS ⭐ MIGRACIÓN 12
-- =============================================================================

DROP TRIGGER IF EXISTS trigger_log_payment_status_change ON payments;

CREATE TRIGGER trigger_log_payment_status_change
    AFTER UPDATE OF status_id ON payments
    FOR EACH ROW
    EXECUTE FUNCTION log_payment_status_change();

COMMENT ON TRIGGER trigger_log_payment_status_change ON payments IS
'⭐ MIGRACIÓN 12: Registra automáticamente todos los cambios de estado de pagos en payment_status_history para auditoría completa y compliance.';

-- =============================================================================
-- CATEGORÍA 5: TRIGGERS DE CRÉDITO DEL ASOCIADO ⭐ MIGRACIÓN 07
-- =============================================================================

-- Trigger 1: Actualizar crédito al aprobar préstamo
CREATE OR REPLACE FUNCTION trigger_update_associate_credit_on_loan_approval()
RETURNS TRIGGER AS $$
DECLARE
    v_associate_profile_id INTEGER;
    v_approved_status_id INTEGER;
BEGIN
    SELECT id INTO v_approved_status_id FROM loan_statuses WHERE name = 'APPROVED';
    
    IF NEW.status_id = v_approved_status_id AND (OLD.status_id IS NULL OR OLD.status_id != v_approved_status_id) THEN
        IF NEW.associate_user_id IS NOT NULL THEN
            SELECT id INTO v_associate_profile_id
            FROM associate_profiles
            WHERE user_id = NEW.associate_user_id;
            
            IF v_associate_profile_id IS NOT NULL THEN
                UPDATE associate_profiles
                SET credit_used = credit_used + NEW.amount,
                    credit_last_updated = CURRENT_TIMESTAMP
                WHERE id = v_associate_profile_id;
                
                RAISE NOTICE 'Crédito del asociado % actualizado: +%', v_associate_profile_id, NEW.amount;
            END IF;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_associate_credit_on_loan_approval
    AFTER UPDATE OF status_id ON loans
    FOR EACH ROW
    EXECUTE FUNCTION trigger_update_associate_credit_on_loan_approval();

COMMENT ON TRIGGER trigger_update_associate_credit_on_loan_approval ON loans IS
'⭐ MIGRACIÓN 07: Incrementa credit_used del asociado cuando se aprueba un préstamo.';

-- Trigger 2: Actualizar crédito al registrar pago
CREATE OR REPLACE FUNCTION trigger_update_associate_credit_on_payment()
RETURNS TRIGGER AS $$
DECLARE
    v_associate_user_id INTEGER;
    v_associate_profile_id INTEGER;
    v_amount_diff DECIMAL(12,2);
    v_capital_paid DECIMAL(12,2);
    v_expected_amount DECIMAL(12,2);
    v_loan_amount DECIMAL(12,2);
    v_loan_term INTEGER;
BEGIN
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
                
                -- ✅ CRÍTICO: Calcular proporción de CAPITAL en el pago
                -- credit_used debe reflejar solo el capital prestado, no intereses/comisiones
                SELECT l.amount, l.term_biweeks INTO v_loan_amount, v_loan_term
                FROM loans l
                WHERE l.id = NEW.loan_id;
                
                -- Obtener expected_amount del pago actual
                v_expected_amount := NEW.expected_amount;
                
                -- Si el pago está completo (amount_paid >= expected_amount)
                IF NEW.amount_paid >= v_expected_amount THEN
                    -- Calcular capital de este pago: loan_amount / term_biweeks
                    v_capital_paid := v_loan_amount / v_loan_term;
                ELSE
                    -- Pago parcial: calcular proporción de capital
                    -- capital_paid = (loan_amount / term) * (amount_paid / expected_amount)
                    v_capital_paid := (v_loan_amount / v_loan_term) * (v_amount_diff / v_expected_amount);
                END IF;
                
                -- Liberar SOLO el capital, no intereses ni comisión
                UPDATE associate_profiles
                SET credit_used = GREATEST(credit_used - v_capital_paid, 0),
                    credit_last_updated = CURRENT_TIMESTAMP
                WHERE id = v_associate_profile_id;
                
                RAISE NOTICE 'Crédito del asociado % actualizado: pago total $%, capital liberado $%', 
                    v_associate_profile_id, v_amount_diff, v_capital_paid;
            END IF;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_associate_credit_on_payment
    AFTER UPDATE OF amount_paid ON payments
    FOR EACH ROW
    EXECUTE FUNCTION trigger_update_associate_credit_on_payment();

COMMENT ON TRIGGER trigger_update_associate_credit_on_payment ON payments IS
'⭐ MIGRACIÓN 07: Decrementa credit_used del asociado cuando se registra un pago.';

-- Trigger 3: Actualizar crédito al liquidar deuda
CREATE OR REPLACE FUNCTION trigger_update_associate_credit_on_debt_payment()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.is_liquidated = true AND OLD.is_liquidated = false THEN
        UPDATE associate_profiles
        SET debt_balance = GREATEST(debt_balance - NEW.amount, 0),
            credit_last_updated = CURRENT_TIMESTAMP
        WHERE id = NEW.associate_profile_id;
        
        RAISE NOTICE 'Deuda del asociado % liquidada: -%', NEW.associate_profile_id, NEW.amount;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_associate_credit_on_debt_payment
    AFTER UPDATE OF is_liquidated ON associate_debt_breakdown
    FOR EACH ROW
    EXECUTE FUNCTION trigger_update_associate_credit_on_debt_payment();

COMMENT ON TRIGGER trigger_update_associate_credit_on_debt_payment ON associate_debt_breakdown IS
'⭐ MIGRACIÓN 07: Decrementa debt_balance del asociado cuando liquida una deuda.';

-- Trigger 4: Actualizar crédito al cambiar de nivel
CREATE OR REPLACE FUNCTION trigger_update_associate_credit_on_level_change()
RETURNS TRIGGER AS $$
DECLARE
    v_new_credit_limit DECIMAL(12,2);
BEGIN
    IF NEW.level_id != OLD.level_id THEN
        SELECT credit_limit INTO v_new_credit_limit
        FROM associate_levels
        WHERE id = NEW.level_id;
        
        UPDATE associate_profiles
        SET credit_limit = v_new_credit_limit,
            credit_last_updated = CURRENT_TIMESTAMP
        WHERE id = NEW.id;
        
        RAISE NOTICE 'Límite de crédito del asociado % actualizado a %', NEW.id, v_new_credit_limit;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_associate_credit_on_level_change
    AFTER UPDATE OF level_id ON associate_profiles
    FOR EACH ROW
    EXECUTE FUNCTION trigger_update_associate_credit_on_level_change();

COMMENT ON TRIGGER trigger_update_associate_credit_on_level_change ON associate_profiles IS
'⭐ MIGRACIÓN 07: Actualiza credit_limit del asociado cuando cambia de nivel (promoción/descenso).';

-- =============================================================================
-- CATEGORÍA 6: TRIGGERS DE AUDITORÍA GENERAL (v1.0)
-- =============================================================================

-- Función genérica de auditoría
CREATE OR REPLACE FUNCTION audit_trigger_function()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'DELETE') THEN
        INSERT INTO audit_log (table_name, record_id, operation, old_data)
        VALUES (TG_TABLE_NAME, OLD.id, 'DELETE', row_to_json(OLD)::jsonb);
        RETURN OLD;
    ELSIF (TG_OP = 'UPDATE') THEN
        INSERT INTO audit_log (table_name, record_id, operation, old_data, new_data)
        VALUES (TG_TABLE_NAME, NEW.id, 'UPDATE', row_to_json(OLD)::jsonb, row_to_json(NEW)::jsonb);
        RETURN NEW;
    ELSIF (TG_OP = 'INSERT') THEN
        INSERT INTO audit_log (table_name, record_id, operation, new_data)
        VALUES (TG_TABLE_NAME, NEW.id, 'INSERT', row_to_json(NEW)::jsonb);
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION audit_trigger_function() IS 
'Función genérica de auditoría que registra INSERT, UPDATE y DELETE en audit_log con snapshots JSON completos.';

-- Aplicar triggers de auditoría a tablas críticas
CREATE TRIGGER audit_loans_trigger
    AFTER INSERT OR UPDATE OR DELETE ON loans
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();

CREATE TRIGGER audit_payments_trigger
    AFTER INSERT OR UPDATE OR DELETE ON payments
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();

CREATE TRIGGER audit_contracts_trigger
    AFTER INSERT OR UPDATE OR DELETE ON contracts
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();

CREATE TRIGGER audit_users_trigger
    AFTER INSERT OR UPDATE OR DELETE ON users
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();

CREATE TRIGGER audit_cut_periods_trigger
    AFTER INSERT OR UPDATE OR DELETE ON cut_periods
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();

COMMENT ON TRIGGER audit_loans_trigger ON loans IS
'Registra todos los cambios en la tabla loans en audit_log para trazabilidad completa.';

COMMENT ON TRIGGER audit_payments_trigger ON payments IS
'Registra todos los cambios en la tabla payments en audit_log para trazabilidad completa.';

-- =============================================================================
-- CATEGORÍA 7: TRIGGER DE ABONOS DE ASOCIADO ⭐ NUEVO v2.0
-- =============================================================================

CREATE TRIGGER trigger_update_statement_on_payment
    AFTER INSERT ON associate_statement_payments
    FOR EACH ROW
    EXECUTE FUNCTION update_statement_on_payment();

COMMENT ON TRIGGER trigger_update_statement_on_payment ON associate_statement_payments IS
'⭐ NUEVO v2.0: Actualiza automáticamente el estado de cuenta (associate_payment_statements) cuando se registra un abono. Suma todos los abonos y actualiza estado a PARTIAL_PAID o PAID según corresponda.';

-- =============================================================================
-- FIN MÓDULO 07
-- =============================================================================
