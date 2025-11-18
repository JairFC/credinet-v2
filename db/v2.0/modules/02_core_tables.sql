-- =============================================================================
-- CREDINET DB v2.0 - MÓDULO 02: TABLAS CORE
-- =============================================================================
-- Descripción:
--   Tablas principales del sistema (usuarios, préstamos, pagos, contratos, períodos).
--   Estas tablas son el corazón del negocio.
--
-- Tablas incluidas:
--   - users (con CURP, validaciones)
--   - user_roles (N:M con roles)
--   - addresses (direcciones de usuarios)
--   - beneficiaries (beneficiarios de clientes)
--   - guarantors (avales de clientes)
--   - loans (préstamos con lógica quincenal)
--   - contracts (contratos 1:1 con loans)
--   - payments (cronograma de pagos generado automáticamente)
--   - cut_periods (períodos de corte quincenales)
--
-- Versión: 2.0.0
-- Fecha: 2025-10-30
-- =============================================================================

-- =============================================================================
-- 1. USERS - Usuarios del Sistema
-- =============================================================================
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(150) UNIQUE NOT NULL,
    phone_number VARCHAR(20) UNIQUE NOT NULL,
    birth_date DATE,
    curp VARCHAR(18) UNIQUE,
    profile_picture_url VARCHAR(500),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    -- Validaciones
    CONSTRAINT check_users_curp_length CHECK (curp IS NULL OR LENGTH(curp) = 18),
    CONSTRAINT check_users_phone_format CHECK (phone_number ~ '^[0-9]{10}$')
);

COMMENT ON TABLE users IS 'Usuarios del sistema (clientes, asociados, administradores).';
COMMENT ON COLUMN users.curp IS 'Clave Única de Registro de Población (CURP) de México. Formato: 18 caracteres alfanuméricos.';
COMMENT ON COLUMN users.password_hash IS 'Hash bcrypt de la contraseña del usuario. NUNCA almacenar contraseñas en texto plano.';

-- Índices
CREATE INDEX IF NOT EXISTS idx_users_username_lower ON users(LOWER(username));
CREATE INDEX IF NOT EXISTS idx_users_email_lower ON users(LOWER(email));

-- =============================================================================
-- 2. USER_ROLES - Relación N:M entre Users y Roles
-- =============================================================================
CREATE TABLE IF NOT EXISTS user_roles (
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role_id INTEGER NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, role_id)
);

COMMENT ON TABLE user_roles IS 'Relación N:M entre usuarios y roles. Un usuario puede tener múltiples roles.';

-- =============================================================================
-- 3. ADDRESSES - Direcciones de Usuarios
-- =============================================================================
CREATE TABLE IF NOT EXISTS addresses (
    id SERIAL PRIMARY KEY,
    user_id INTEGER UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    street VARCHAR(200) NOT NULL,
    external_number VARCHAR(10) NOT NULL,
    internal_number VARCHAR(10),
    colony VARCHAR(100) NOT NULL,
    municipality VARCHAR(100) NOT NULL,
    state VARCHAR(100) NOT NULL,
    zip_code VARCHAR(10) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE addresses IS 'Direcciones físicas de usuarios (relación 1:1 con users).';

-- =============================================================================
-- 4. BENEFICIARIES - Beneficiarios de Clientes
-- =============================================================================
CREATE TABLE IF NOT EXISTS beneficiaries (
    id SERIAL PRIMARY KEY,
    user_id INTEGER UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    full_name VARCHAR(200) NOT NULL,
    relationship VARCHAR(50) NOT NULL,
    phone_number VARCHAR(20) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE beneficiaries IS 'Beneficiarios designados por clientes (relación 1:1 con users).';

-- =============================================================================
-- 5. GUARANTORS - Avales de Clientes
-- =============================================================================
CREATE TABLE IF NOT EXISTS guarantors (
    id SERIAL PRIMARY KEY,
    user_id INTEGER UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    full_name VARCHAR(200) NOT NULL,
    first_name VARCHAR(100),
    paternal_last_name VARCHAR(100),
    maternal_last_name VARCHAR(100),
    relationship VARCHAR(50) NOT NULL,
    phone_number VARCHAR(20) NOT NULL,
    curp VARCHAR(18) UNIQUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    -- Validaciones
    CONSTRAINT check_guarantors_curp_length CHECK (curp IS NULL OR LENGTH(curp) = 18),
    CONSTRAINT check_guarantors_phone_format CHECK (phone_number ~ '^[0-9]{10}$')
);

COMMENT ON TABLE guarantors IS 'Avales o garantes de clientes (relación 1:1 con users).';

-- =============================================================================
-- 6. LOANS - Préstamos (Tabla Central)
-- =============================================================================
CREATE TABLE IF NOT EXISTS loans (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE, -- Cliente
    associate_user_id INTEGER REFERENCES users(id), -- Asociado (si aplica)
    amount DECIMAL(12, 2) NOT NULL,
    interest_rate DECIMAL(5, 2) NOT NULL,
    commission_rate DECIMAL(5, 2) NOT NULL DEFAULT 0.0,
    term_biweeks INTEGER NOT NULL, -- Plazo en quincenas
    profile_code VARCHAR(50), -- FK a rate_profiles (opcional, se agregará constraint después)
    status_id INTEGER NOT NULL REFERENCES loan_statuses(id),
    contract_id INTEGER, -- FK a contracts (se agregará después)
    
    -- ⭐ CAMPOS CALCULADOS (Sprint 6 - Migración 005) - Valores de calculate_loan_payment()
    biweekly_payment DECIMAL(10,2), -- Pago quincenal calculado (con interés incluido)
    total_payment DECIMAL(12,2), -- Pago total del préstamo (biweekly_payment * term_biweeks)
    total_interest DECIMAL(12,2), -- Interés total a pagar
    total_commission DECIMAL(12,2), -- Comisión total del asociado
    commission_per_payment DECIMAL(10,2), -- Comisión por pago quincenal
    associate_payment DECIMAL(10,2), -- Pago neto del cliente (biweekly_payment - commission_per_payment)
    
    -- Campos críticos de aprobación
    approved_at TIMESTAMP WITH TIME ZONE,
    approved_by INTEGER REFERENCES users(id),
    rejected_at TIMESTAMP WITH TIME ZONE,
    rejected_by INTEGER REFERENCES users(id), 
    rejection_reason TEXT,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    -- Validaciones
    CONSTRAINT check_loans_amount_positive CHECK (amount > 0),
    CONSTRAINT check_loans_interest_rate_valid CHECK (interest_rate >= 0 AND interest_rate <= 100),
    CONSTRAINT check_loans_commission_rate_valid CHECK (commission_rate >= 0 AND commission_rate <= 100),
    CONSTRAINT check_loans_term_biweeks_valid CHECK (term_biweeks IN (3, 6, 9, 12, 15, 18, 21, 24, 30, 36)),
    CONSTRAINT check_loans_approved_after_created CHECK (approved_at IS NULL OR approved_at >= created_at),
    CONSTRAINT check_loans_rejected_after_created CHECK (rejected_at IS NULL OR rejected_at >= created_at),
    -- ⭐ Validaciones campos calculados (Sprint 6 - Migración 005)
    CONSTRAINT check_biweekly_payment_positive CHECK (biweekly_payment IS NULL OR biweekly_payment > 0),
    CONSTRAINT check_total_payment_positive CHECK (total_payment IS NULL OR total_payment > 0),
    CONSTRAINT check_total_interest_non_negative CHECK (total_interest IS NULL OR total_interest >= 0),
    CONSTRAINT check_total_commission_non_negative CHECK (total_commission IS NULL OR total_commission >= 0),
    CONSTRAINT check_commission_per_payment_non_negative CHECK (commission_per_payment IS NULL OR commission_per_payment >= 0),
    CONSTRAINT check_associate_payment_non_negative CHECK (associate_payment IS NULL OR associate_payment >= 0)
);

COMMENT ON TABLE loans IS 'Tabla central del sistema. Registra todos los préstamos solicitados, aprobados, rechazados o completados.';
COMMENT ON COLUMN loans.term_biweeks IS '⭐ V2.0: Plazo del préstamo en quincenas. Valores permitidos: 3, 6, 9, 12, 15, 18, 21, 24, 30 o 36 quincenas. Validado por check_loans_term_biweeks_valid.';
COMMENT ON COLUMN loans.commission_rate IS 'Tasa de comisión del asociado en porcentaje. Ejemplo: 2.5 = 2.5%. Rango válido: 0-100.';
COMMENT ON COLUMN loans.biweekly_payment IS '⭐ Sprint 6: Pago quincenal calculado con interés incluido (desde calculate_loan_payment). NULL si usa tasas manuales.';
COMMENT ON COLUMN loans.total_payment IS '⭐ Sprint 6: Monto total a pagar incluyendo capital e interés (biweekly_payment * term_biweeks).';
COMMENT ON COLUMN loans.total_interest IS '⭐ Sprint 6: Interés total a pagar (total_payment - amount).';
COMMENT ON COLUMN loans.total_commission IS '⭐ Sprint 6: Comisión total del asociado durante todo el préstamo.';
COMMENT ON COLUMN loans.commission_per_payment IS '⭐ Sprint 6: Comisión del asociado por cada pago quincenal.';
COMMENT ON COLUMN loans.associate_payment IS '⭐ Sprint 6: Pago neto del cliente al asociado (biweekly_payment - commission_per_payment).';

-- Índices para loans
CREATE INDEX IF NOT EXISTS idx_loans_user_id ON loans(user_id);
CREATE INDEX IF NOT EXISTS idx_loans_associate_user_id ON loans(associate_user_id);
CREATE INDEX IF NOT EXISTS idx_loans_status_id ON loans(status_id);
CREATE INDEX IF NOT EXISTS idx_loans_approved_at ON loans(approved_at) WHERE approved_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_loans_status_id_approved_at ON loans(status_id, approved_at);
-- ⭐ Sprint 6: Índices para campos calculados
CREATE INDEX IF NOT EXISTS idx_loans_profile_code ON loans(profile_code) WHERE profile_code IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_loans_biweekly_payment ON loans(biweekly_payment) WHERE biweekly_payment IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_loans_total_payment ON loans(total_payment) WHERE total_payment IS NOT NULL;

-- =============================================================================
-- 7. CONTRACTS - Contratos (Relación 1:1 con Loans)
-- =============================================================================
CREATE TABLE IF NOT EXISTS contracts (
    id SERIAL PRIMARY KEY,
    loan_id INTEGER NOT NULL REFERENCES loans(id) ON DELETE CASCADE,
    file_path VARCHAR(500),
    start_date DATE NOT NULL,
    sign_date DATE,
    document_number VARCHAR(50) UNIQUE NOT NULL,
    status_id INTEGER NOT NULL REFERENCES contract_statuses(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    -- Validaciones
    CONSTRAINT check_contracts_sign_after_start CHECK (sign_date IS NULL OR sign_date >= start_date)
);

COMMENT ON TABLE contracts IS 'Contratos generados automáticamente cuando un préstamo es aprobado. Relación 1:1 con loans.';
COMMENT ON COLUMN contracts.document_number IS 'Número único del contrato (formato: CONT-YYYY-NNN). Usado para referencia legal y archivos.';

-- Índices para contracts
CREATE INDEX IF NOT EXISTS idx_contracts_document_number ON contracts(document_number);
CREATE INDEX IF NOT EXISTS idx_contracts_loan_id ON contracts(loan_id);

-- Agregar FK de loans.contract_id → contracts.id
ALTER TABLE loans ADD CONSTRAINT fk_loans_contract_id FOREIGN KEY (contract_id) REFERENCES contracts(id);

-- =============================================================================
-- 8. CUT_PERIODS - Períodos de Corte Quincenales
-- =============================================================================
CREATE TABLE IF NOT EXISTS cut_periods (
    id SERIAL PRIMARY KEY,
    cut_number INTEGER NOT NULL,
    period_start_date DATE NOT NULL,
    period_end_date DATE NOT NULL,
    status_id INTEGER NOT NULL REFERENCES cut_period_statuses(id),
    total_payments_expected DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    total_payments_received DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    total_commission DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    created_by INTEGER NOT NULL REFERENCES users(id),
    closed_by INTEGER REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    -- Validaciones
    CONSTRAINT check_cut_periods_dates_logical CHECK (period_end_date > period_start_date),
    CONSTRAINT check_cut_periods_totals_non_negative CHECK (
        total_payments_expected >= 0 AND
        total_payments_received >= 0 AND
        total_commission >= 0
    )
);

COMMENT ON TABLE cut_periods IS 'Períodos administrativos quincenales del sistema (8-22 y 23-7 de cada mes). Usados para cortes de caja y liquidaciones.';
COMMENT ON COLUMN cut_periods.cut_number IS 'Número secuencial del período de corte. Se reinicia cada año (1-24 por año).';

-- Índices para cut_periods
CREATE INDEX IF NOT EXISTS idx_cut_periods_status_id ON cut_periods(status_id);
CREATE INDEX IF NOT EXISTS idx_cut_periods_dates ON cut_periods(period_start_date, period_end_date);
CREATE INDEX IF NOT EXISTS idx_cut_periods_active ON cut_periods(status_id) WHERE status_id IN (1, 2); -- Parcial: solo PRELIMINARY y ACTIVE

-- =============================================================================
-- 9. PAYMENTS - Cronograma de Pagos (Generado Automáticamente)
-- =============================================================================
CREATE TABLE IF NOT EXISTS payments (
    id SERIAL PRIMARY KEY,
    loan_id INTEGER NOT NULL REFERENCES loans(id) ON DELETE CASCADE,
    amount_paid DECIMAL(12, 2) NOT NULL,
    
    -- ⭐ CAMPOS DE DESGLOSE FINANCIERO (Sprint 6 - Migración 006)
    payment_number INTEGER, -- Número de pago en el cronograma (1, 2, 3, ..., term_biweeks)
    expected_amount DECIMAL(12,2), -- Monto esperado del pago (biweekly_payment del préstamo)
    interest_amount DECIMAL(10,2), -- Porción de interés en este pago
    principal_amount DECIMAL(10,2), -- Porción de capital en este pago
    commission_amount DECIMAL(10,2), -- Comisión del asociado en este pago
    associate_payment DECIMAL(10,2), -- Pago neto del cliente (expected_amount - commission_amount)
    balance_remaining DECIMAL(12,2), -- Saldo pendiente después de este pago
    
    payment_date DATE NOT NULL,
    payment_due_date DATE NOT NULL, -- Fecha esperada (día 15 o último día)
    is_late BOOLEAN NOT NULL DEFAULT false,
    status_id INTEGER REFERENCES payment_statuses(id), -- ⭐ NUEVO v2.0
    cut_period_id INTEGER REFERENCES cut_periods(id),
    -- ⭐ NUEVO v2.0: Tracking de marcado manual
    marked_by INTEGER REFERENCES users(id),
    marked_at TIMESTAMP WITH TIME ZONE,
    marking_notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    -- Validaciones
    CONSTRAINT check_payments_amount_paid_non_negative CHECK (amount_paid >= 0),
    CONSTRAINT check_payments_dates_logical CHECK (payment_date <= payment_due_date),
    -- ⭐ Validaciones campos de desglose (Sprint 6 - Migración 006)
    CONSTRAINT check_payment_number_positive CHECK (payment_number IS NULL OR payment_number > 0),
    CONSTRAINT check_expected_amount_positive CHECK (expected_amount IS NULL OR expected_amount > 0),
    CONSTRAINT check_interest_amount_non_negative CHECK (interest_amount IS NULL OR interest_amount >= 0),
    CONSTRAINT check_principal_amount_non_negative CHECK (principal_amount IS NULL OR principal_amount >= 0),
    CONSTRAINT check_commission_amount_non_negative CHECK (commission_amount IS NULL OR commission_amount >= 0),
    CONSTRAINT check_associate_payment_non_negative CHECK (associate_payment IS NULL OR associate_payment >= 0),
    CONSTRAINT check_balance_remaining_non_negative CHECK (balance_remaining IS NULL OR balance_remaining >= 0),
    -- ⭐ Unicidad: No puede haber 2 pagos con el mismo número para el mismo préstamo
    CONSTRAINT payments_unique_loan_payment_number UNIQUE (loan_id, payment_number)
);

COMMENT ON TABLE payments IS 'Schedule de pagos generado automáticamente cuando un préstamo es aprobado. Un registro por cada quincena del plazo.';
COMMENT ON COLUMN payments.payment_due_date IS 'Fecha de vencimiento del pago según reglas de negocio: día 15 o último día del mes. Generado por calculate_first_payment_date().';
COMMENT ON COLUMN payments.is_late IS 'Indica si el pago está atrasado (TRUE si payment_due_date < CURRENT_DATE y no está pagado).';
COMMENT ON COLUMN payments.marked_by IS '⭐ v2.0: Usuario que marcó manualmente el estado del pago (admin puede remarcar).';
COMMENT ON COLUMN payments.payment_number IS '⭐ Sprint 6: Número secuencial del pago (1, 2, 3, ...). Permite ordenar el cronograma de amortización.';
COMMENT ON COLUMN payments.expected_amount IS '⭐ Sprint 6: Monto esperado del pago quincenal (loans.biweekly_payment). Usado para validación de consistencia.';
COMMENT ON COLUMN payments.interest_amount IS '⭐ Sprint 6: Porción de interés en este pago específico (varía por amortización).';
COMMENT ON COLUMN payments.principal_amount IS '⭐ Sprint 6: Porción de capital/principal amortizado en este pago.';
COMMENT ON COLUMN payments.commission_amount IS '⭐ Sprint 6: Comisión del asociado en este pago (normalmente fija = loans.commission_per_payment).';
COMMENT ON COLUMN payments.associate_payment IS '⭐ Sprint 6: Pago neto del cliente al asociado (expected_amount - commission_amount).';
COMMENT ON COLUMN payments.balance_remaining IS '⭐ Sprint 6: Saldo de capital pendiente después de aplicar este pago. Debe llegar a 0 en el último pago.';

-- Índices para payments
CREATE INDEX IF NOT EXISTS idx_payments_loan_id ON payments(loan_id);
CREATE INDEX IF NOT EXISTS idx_payments_payment_due_date ON payments(payment_due_date);
CREATE INDEX IF NOT EXISTS idx_payments_is_late ON payments(is_late);
CREATE INDEX IF NOT EXISTS idx_payments_cut_period_id ON payments(cut_period_id);
CREATE INDEX IF NOT EXISTS idx_payments_status_id ON payments(status_id); -- ⭐ NUEVO v2.0
CREATE INDEX IF NOT EXISTS idx_payments_late_loan ON payments(loan_id, is_late, payment_due_date); -- Compuesto para consultas de mora
-- ⭐ Sprint 6: Índices para campos de desglose
CREATE INDEX IF NOT EXISTS idx_payments_loan_payment_number ON payments(loan_id, payment_number) WHERE payment_number IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_payments_balance_remaining ON payments(balance_remaining) WHERE balance_remaining IS NOT NULL;

-- =============================================================================
-- 10. CLIENT_DOCUMENTS - Documentos de Clientes
-- =============================================================================
CREATE TABLE IF NOT EXISTS client_documents (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    document_type_id INTEGER NOT NULL REFERENCES document_types(id),
    file_name VARCHAR(255) NOT NULL,
    original_file_name VARCHAR(255),
    file_path VARCHAR(500) NOT NULL,
    file_size BIGINT,
    mime_type VARCHAR(100),
    status_id INTEGER NOT NULL REFERENCES document_statuses(id),
    upload_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    reviewed_by INTEGER REFERENCES users(id),
    reviewed_at TIMESTAMP WITH TIME ZONE,
    comments TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE client_documents IS 'Documentos cargados por clientes (INE, comprobante de domicilio, etc.).';

-- Índices
CREATE INDEX IF NOT EXISTS idx_client_documents_user_id ON client_documents(user_id);
CREATE INDEX IF NOT EXISTS idx_client_documents_status_id ON client_documents(status_id);

-- =============================================================================
-- 11. SYSTEM_CONFIGURATIONS - Configuraciones del Sistema
-- =============================================================================
CREATE TABLE IF NOT EXISTS system_configurations (
    id SERIAL PRIMARY KEY,
    config_key VARCHAR(100) UNIQUE NOT NULL,
    config_value TEXT NOT NULL,
    description TEXT,
    config_type_id INTEGER NOT NULL REFERENCES config_types(id),
    updated_by INTEGER NOT NULL REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE system_configurations IS 'Configuraciones globales del sistema (tasas, montos, flags de funcionalidad).';

-- =============================================================================
-- FIN MÓDULO 02
-- =============================================================================
