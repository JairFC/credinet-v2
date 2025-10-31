-- =============================================================================
-- CREDINET DB v2.0 - MÓDULO 03: TABLAS DE LÓGICA DE NEGOCIO
-- =============================================================================
-- Descripción:
--   Tablas para lógica de negocio específica: asociados, convenios, renovaciones.
--   Incluye las extensiones de la migración 07 (sistema de crédito del asociado).
--
-- Tablas incluidas:
--   - associate_profiles (con credit tracking v2.0)
--   - associate_payment_statements (con late_fee v2.0)
--   - associate_accumulated_balances
--   - associate_level_history
--   - agreements (convenios de pago)
--   - agreement_items (ítems de convenio)
--   - agreement_payments (pagos de convenio)
--   - loan_renewals (registro de renovaciones)
--
-- Versión: 2.0.0
-- Fecha: 2025-10-30
-- =============================================================================

-- =============================================================================
-- 1. ASSOCIATE_PROFILES - Perfiles de Asociados ⭐ CON CRÉDITO v2.0
-- =============================================================================
CREATE TABLE IF NOT EXISTS associate_profiles (
    id SERIAL PRIMARY KEY,
    user_id INTEGER UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    level_id INTEGER NOT NULL REFERENCES associate_levels(id),
    contact_person VARCHAR(150),
    contact_email VARCHAR(150) UNIQUE,
    default_commission_rate DECIMAL(5, 2) NOT NULL DEFAULT 5.0,
    active BOOLEAN NOT NULL DEFAULT true,
    consecutive_full_credit_periods INTEGER NOT NULL DEFAULT 0,
    consecutive_on_time_payments INTEGER NOT NULL DEFAULT 0,
    clients_in_agreement INTEGER NOT NULL DEFAULT 0,
    last_level_evaluation_date TIMESTAMP WITH TIME ZONE,
    
    -- ⭐ NUEVO v2.0 - MIGRACIÓN 07: Sistema de Crédito del Asociado
    credit_used DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    credit_limit DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    credit_available DECIMAL(12, 2) GENERATED ALWAYS AS (credit_limit - credit_used) STORED,
    credit_last_updated TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- ⭐ NUEVO v2.0 - MIGRACIÓN 09: Deuda del Asociado
    debt_balance DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Validaciones
    CONSTRAINT check_associate_profiles_commission_rate_valid CHECK (default_commission_rate >= 0 AND default_commission_rate <= 100),
    CONSTRAINT check_associate_profiles_counters_non_negative CHECK (
        consecutive_full_credit_periods >= 0 AND
        consecutive_on_time_payments >= 0 AND
        clients_in_agreement >= 0
    ),
    CONSTRAINT check_associate_profiles_credit_non_negative CHECK (
        credit_used >= 0 AND
        credit_limit >= 0
    ),
    CONSTRAINT check_associate_profiles_debt_non_negative CHECK (debt_balance >= 0)
);

COMMENT ON TABLE associate_profiles IS 'Información extendida de usuarios que son asociados (gestores de cartera de préstamos). Incluye sistema de crédito v2.0.';
COMMENT ON COLUMN associate_profiles.consecutive_full_credit_periods IS 'Contador de períodos consecutivos con 100% de cobro. Usado para evaluaciones de nivel.';
COMMENT ON COLUMN associate_profiles.credit_used IS '⭐ v2.0: Crédito actualmente utilizado por el asociado (préstamos absorbidos no liquidados).';
COMMENT ON COLUMN associate_profiles.credit_limit IS '⭐ v2.0: Límite máximo de crédito disponible para el asociado según su nivel.';
COMMENT ON COLUMN associate_profiles.credit_available IS '⭐ v2.0: Crédito disponible restante (columna calculada: credit_limit - credit_used).';
COMMENT ON COLUMN associate_profiles.debt_balance IS '⭐ v2.0: Deuda total del asociado (pagos no reportados + clientes morosos + mora).';

-- Índices
CREATE INDEX IF NOT EXISTS idx_associate_profiles_user_id ON associate_profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_associate_profiles_level_id ON associate_profiles(level_id);
CREATE INDEX IF NOT EXISTS idx_associate_profiles_active ON associate_profiles(active);
CREATE INDEX IF NOT EXISTS idx_associate_profiles_credit_used ON associate_profiles(credit_used); -- v2.0

-- =============================================================================
-- 2. ASSOCIATE_PAYMENT_STATEMENTS - Estados de Cuenta ⭐ CON MORA v2.0
-- =============================================================================
CREATE TABLE IF NOT EXISTS associate_payment_statements (
    id SERIAL PRIMARY KEY,
    cut_period_id INTEGER NOT NULL REFERENCES cut_periods(id),
    user_id INTEGER NOT NULL REFERENCES users(id),
    statement_number VARCHAR(50) NOT NULL,
    total_payments_count INTEGER NOT NULL DEFAULT 0,
    total_amount_collected DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    total_commission_owed DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    commission_rate_applied DECIMAL(5, 2) NOT NULL,
    status_id INTEGER NOT NULL REFERENCES statement_statuses(id),
    generated_date DATE NOT NULL,
    sent_date DATE,
    due_date DATE NOT NULL,
    paid_date DATE,
    paid_amount DECIMAL(12, 2),
    payment_method_id INTEGER REFERENCES payment_methods(id),
    payment_reference VARCHAR(100),
    
    -- ⭐ NUEVO v2.0 - MIGRACIÓN 10: Sistema de Mora del 30%
    late_fee_amount DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    late_fee_applied BOOLEAN NOT NULL DEFAULT false,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Validaciones
    CONSTRAINT check_statements_totals_non_negative CHECK (
        total_payments_count >= 0 AND
        total_amount_collected >= 0 AND
        total_commission_owed >= 0 AND
        late_fee_amount >= 0
    )
);

COMMENT ON TABLE associate_payment_statements IS 'Estados de cuenta generados para asociados por cada período de corte. Incluye sistema de mora v2.0.';
COMMENT ON COLUMN associate_payment_statements.late_fee_amount IS '⭐ v2.0: Mora del 30% aplicada sobre comisión si NO reportó ningún pago (total_payments_count = 0).';
COMMENT ON COLUMN associate_payment_statements.late_fee_applied IS '⭐ v2.0: Flag que indica si ya se aplicó la mora del 30%.';

-- =============================================================================
-- 3. ASSOCIATE_ACCUMULATED_BALANCES - Balances Acumulados
-- =============================================================================
CREATE TABLE IF NOT EXISTS associate_accumulated_balances (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id),
    cut_period_id INTEGER NOT NULL REFERENCES cut_periods(id),
    accumulated_debt DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    debt_details JSONB, -- Desglose de la deuda en formato JSON
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (user_id, cut_period_id)
);

COMMENT ON TABLE associate_accumulated_balances IS 'Balances de deuda acumulados por asociado en cada período de corte.';
COMMENT ON COLUMN associate_accumulated_balances.debt_details IS 'Desglose JSON de la deuda (unreported_payments, defaulted_clients, late_fees, etc.).';

-- =============================================================================
-- 4. ASSOCIATE_LEVEL_HISTORY - Historial de Cambios de Nivel
-- =============================================================================
CREATE TABLE IF NOT EXISTS associate_level_history (
    id SERIAL PRIMARY KEY,
    associate_profile_id INTEGER NOT NULL REFERENCES associate_profiles(id) ON DELETE CASCADE,
    old_level_id INTEGER NOT NULL REFERENCES associate_levels(id),
    new_level_id INTEGER NOT NULL REFERENCES associate_levels(id),
    reason TEXT,
    change_type_id INTEGER NOT NULL REFERENCES level_change_types(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE associate_level_history IS 'Historial de cambios de nivel de asociados (promociones, descensos, manuales).';

-- =============================================================================
-- 5. AGREEMENTS - Convenios de Pago (v2.0)
-- =============================================================================
CREATE TABLE IF NOT EXISTS agreements (
    id SERIAL PRIMARY KEY,
    associate_profile_id INTEGER NOT NULL REFERENCES associate_profiles(id) ON DELETE CASCADE,
    agreement_number VARCHAR(50) UNIQUE NOT NULL,
    agreement_date DATE NOT NULL,
    total_debt_amount DECIMAL(12, 2) NOT NULL,
    payment_plan_months INTEGER NOT NULL,
    monthly_payment_amount DECIMAL(12, 2) NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'ACTIVE', -- ACTIVE, COMPLETED, DEFAULTED
    start_date DATE NOT NULL,
    end_date DATE,
    created_by INTEGER NOT NULL REFERENCES users(id),
    approved_by INTEGER REFERENCES users(id),
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Validaciones
    CONSTRAINT check_agreements_amounts_positive CHECK (
        total_debt_amount > 0 AND
        monthly_payment_amount > 0
    ),
    CONSTRAINT check_agreements_months_positive CHECK (payment_plan_months > 0),
    CONSTRAINT check_agreements_status_valid CHECK (status IN ('ACTIVE', 'COMPLETED', 'DEFAULTED', 'CANCELLED'))
);

COMMENT ON TABLE agreements IS 'Convenios de pago entre asociado y Credinet para liquidar deudas acumuladas. El asociado absorbe la deuda del cliente.';
COMMENT ON COLUMN agreements.agreement_number IS 'Número único del convenio (formato: AGR-YYYY-NNN).';

-- Índices
CREATE INDEX IF NOT EXISTS idx_agreements_associate_profile_id ON agreements(associate_profile_id);
CREATE INDEX IF NOT EXISTS idx_agreements_status ON agreements(status);

-- =============================================================================
-- 6. AGREEMENT_ITEMS - Ítems de Convenio (Desglose)
-- =============================================================================
CREATE TABLE IF NOT EXISTS agreement_items (
    id SERIAL PRIMARY KEY,
    agreement_id INTEGER NOT NULL REFERENCES agreements(id) ON DELETE CASCADE,
    loan_id INTEGER NOT NULL REFERENCES loans(id), -- Préstamo relacionado
    client_user_id INTEGER NOT NULL REFERENCES users(id), -- Cliente moroso
    debt_amount DECIMAL(12, 2) NOT NULL,
    debt_type VARCHAR(50) NOT NULL, -- UNREPORTED_PAYMENT, DEFAULTED_CLIENT, LATE_FEE
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Validaciones
    CONSTRAINT check_agreement_items_debt_positive CHECK (debt_amount > 0),
    CONSTRAINT check_agreement_items_type_valid CHECK (debt_type IN ('UNREPORTED_PAYMENT', 'DEFAULTED_CLIENT', 'LATE_FEE', 'OTHER'))
);

COMMENT ON TABLE agreement_items IS 'Ítems individuales que componen un convenio de pago (desglose por préstamo/cliente).';
COMMENT ON COLUMN agreement_items.debt_type IS 'Tipo de deuda: UNREPORTED_PAYMENT (pago no reportado), DEFAULTED_CLIENT (cliente moroso), LATE_FEE (mora 30%), OTHER.';

-- Índices
CREATE INDEX IF NOT EXISTS idx_agreement_items_agreement_id ON agreement_items(agreement_id);
CREATE INDEX IF NOT EXISTS idx_agreement_items_loan_id ON agreement_items(loan_id);

-- =============================================================================
-- 7. AGREEMENT_PAYMENTS - Pagos de Convenio
-- =============================================================================
CREATE TABLE IF NOT EXISTS agreement_payments (
    id SERIAL PRIMARY KEY,
    agreement_id INTEGER NOT NULL REFERENCES agreements(id) ON DELETE CASCADE,
    payment_number INTEGER NOT NULL,
    payment_amount DECIMAL(12, 2) NOT NULL,
    payment_due_date DATE NOT NULL,
    payment_date DATE,
    payment_method_id INTEGER REFERENCES payment_methods(id),
    payment_reference VARCHAR(100),
    status VARCHAR(50) NOT NULL DEFAULT 'PENDING', -- PENDING, PAID, OVERDUE
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Validaciones
    CONSTRAINT check_agreement_payments_amount_positive CHECK (payment_amount > 0),
    CONSTRAINT check_agreement_payments_status_valid CHECK (status IN ('PENDING', 'PAID', 'OVERDUE', 'CANCELLED'))
);

COMMENT ON TABLE agreement_payments IS 'Cronograma de pagos mensuales del convenio (1 registro por cada mes del plan de pagos).';

-- Índices
CREATE INDEX IF NOT EXISTS idx_agreement_payments_agreement_id ON agreement_payments(agreement_id);
CREATE INDEX IF NOT EXISTS idx_agreement_payments_status ON agreement_payments(status);

-- =============================================================================
-- 8. LOAN_RENEWALS - Registro de Renovaciones de Préstamos
-- =============================================================================
CREATE TABLE IF NOT EXISTS loan_renewals (
    id SERIAL PRIMARY KEY,
    original_loan_id INTEGER NOT NULL REFERENCES loans(id),
    renewed_loan_id INTEGER NOT NULL REFERENCES loans(id),
    renewal_date DATE NOT NULL,
    pending_balance DECIMAL(12, 2) NOT NULL,
    new_amount DECIMAL(12, 2) NOT NULL,
    reason TEXT,
    created_by INTEGER NOT NULL REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Validaciones
    CONSTRAINT check_loan_renewals_amounts_positive CHECK (
        pending_balance >= 0 AND
        new_amount > 0
    )
);

COMMENT ON TABLE loan_renewals IS 'Registro de renovaciones de préstamos (préstamo original → préstamo renovado).';
COMMENT ON COLUMN loan_renewals.pending_balance IS 'Saldo pendiente del préstamo original al momento de la renovación.';
COMMENT ON COLUMN loan_renewals.new_amount IS 'Monto del nuevo préstamo (puede incluir o no el saldo pendiente).';

-- Índices
CREATE INDEX IF NOT EXISTS idx_loan_renewals_original_loan_id ON loan_renewals(original_loan_id);
CREATE INDEX IF NOT EXISTS idx_loan_renewals_renewed_loan_id ON loan_renewals(renewed_loan_id);

-- =============================================================================
-- FIN MÓDULO 03
-- =============================================================================
