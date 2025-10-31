-- Function para actualizar timestamps automáticamente
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';
-- =============================================================================
-- CREDINET DB v2.0 - ARCHIVO MONOLÍTICO
-- =============================================================================
-- Descripción:
--   Base de datos completa consolidada en un solo archivo.
--   Generado automáticamente desde arquitectura modular.
--
-- Generación: $(date '+%Y-%m-%d %H:%M:%S')
-- Versión: 2.0.0
-- Módulos incluidos: 9 (01_catalog → 09_seeds)
-- Migraciones integradas: 6 (07-12)
--
-- ADVERTENCIA:
--   Este archivo es GENERADO AUTOMÁTICAMENTE.
--   NO editar directamente - modificar módulos en /modules/ y regenerar.
-- =============================================================================

-- =============================================================================
-- CREDINET DB v2.0 - MÓDULO 01: TABLAS DE CATÁLOGO
-- =============================================================================
-- Descripción:
--   Tablas de referencia normalizadas para reemplazar "magic strings".
--   Catálogos para estados, tipos y configuraciones del sistema.
--
-- Tablas incluidas:
--   - roles (5 registros)
--   - loan_statuses (10 registros)
--   - payment_statuses (12 registros) ⭐ ACTUALIZADO con v2.0
--   - contract_statuses (6 registros)
--   - cut_period_statuses (5 registros)
--   - payment_methods (7 registros)
--   - document_statuses (4 registros)
--   - statement_statuses (5 registros)
--   - config_types (8 registros)
--   - level_change_types (6 registros)
--   - associate_levels (5 niveles)
--   - document_types (5 tipos)
--
-- Filosofía: "Zero Magic Strings"
-- Versión: 2.0.0
-- Fecha: 2025-10-30
-- =============================================================================

-- =============================================================================
-- 1. ROLES DEL SISTEMA
-- =============================================================================
CREATE TABLE IF NOT EXISTS roles (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) UNIQUE NOT NULL,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE roles IS 'Roles de usuario en el sistema (desarrollador, admin, asociado, cliente).';

-- =============================================================================
-- 2. LOAN_STATUSES - Estados de Préstamos
-- =============================================================================
CREATE TABLE IF NOT EXISTS loan_statuses (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    display_order INTEGER DEFAULT 0,
    color_code VARCHAR(7),
    icon_name VARCHAR(50),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE loan_statuses IS 'Catálogo de estados posibles para préstamos. Normaliza loans.status_id.';

CREATE INDEX IF NOT EXISTS idx_loan_statuses_name ON loan_statuses(name);
CREATE INDEX IF NOT EXISTS idx_loan_statuses_active ON loan_statuses(is_active);

-- =============================================================================
-- 3. PAYMENT_STATUSES - Estados de Pagos (12 ESTADOS v2.0) ⭐
-- =============================================================================
CREATE TABLE IF NOT EXISTS payment_statuses (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    display_order INTEGER DEFAULT 0,
    color_code VARCHAR(7),
    icon_name VARCHAR(50),
    is_real_payment BOOLEAN DEFAULT TRUE, -- ⭐ NUEVO v2.0: Distingue pagos reales vs ficticios
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE payment_statuses IS 'Catálogo de estados posibles para pagos. 12 estados consolidados (6 pendientes, 2 reales, 4 ficticios).';
COMMENT ON COLUMN payment_statuses.is_real_payment IS 'TRUE si el pago es dinero real cobrado, FALSE si es ficticio (absorbido, cancelado, perdonado).';

CREATE INDEX IF NOT EXISTS idx_payment_statuses_name ON payment_statuses(name);
CREATE INDEX IF NOT EXISTS idx_payment_statuses_active ON payment_statuses(is_active);
CREATE INDEX IF NOT EXISTS idx_payment_statuses_is_real ON payment_statuses(is_real_payment);

-- =============================================================================
-- 4. CONTRACT_STATUSES - Estados de Contratos
-- =============================================================================
CREATE TABLE IF NOT EXISTS contract_statuses (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    requires_signature BOOLEAN DEFAULT FALSE,
    display_order INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE contract_statuses IS 'Catálogo de estados posibles para contratos. Normaliza contracts.status_id.';

CREATE INDEX IF NOT EXISTS idx_contract_statuses_name ON contract_statuses(name);

-- =============================================================================
-- 5. CUT_PERIOD_STATUSES - Estados de Períodos de Corte
-- =============================================================================
CREATE TABLE IF NOT EXISTS cut_period_statuses (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT NOT NULL,
    is_terminal BOOLEAN DEFAULT FALSE,
    allows_payments BOOLEAN DEFAULT TRUE,
    display_order INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE cut_period_statuses IS 'Catálogo de estados para períodos de corte quincenal (días 8-22 y 23-7).';

CREATE INDEX IF NOT EXISTS idx_cut_period_statuses_name ON cut_period_statuses(name);

-- =============================================================================
-- 6. PAYMENT_METHODS - Métodos de Pago
-- =============================================================================
CREATE TABLE IF NOT EXISTS payment_methods (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    requires_reference BOOLEAN DEFAULT FALSE,
    display_order INTEGER DEFAULT 0,
    icon_name VARCHAR(50),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE payment_methods IS 'Catálogo de métodos de pago aceptados (efectivo, transferencia, OXXO, etc.).';

CREATE INDEX IF NOT EXISTS idx_payment_methods_name ON payment_methods(name);

-- =============================================================================
-- 7. DOCUMENT_STATUSES - Estados de Documentos
-- =============================================================================
CREATE TABLE IF NOT EXISTS document_statuses (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT NOT NULL,
    display_order INTEGER DEFAULT 0,
    color_code VARCHAR(7),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE document_statuses IS 'Catálogo de estados para documentos de clientes (PENDING, APPROVED, REJECTED).';

CREATE INDEX IF NOT EXISTS idx_document_statuses_name ON document_statuses(name);

-- =============================================================================
-- 8. STATEMENT_STATUSES - Estados de Cuenta de Asociados
-- =============================================================================
CREATE TABLE IF NOT EXISTS statement_statuses (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT NOT NULL,
    is_paid BOOLEAN DEFAULT FALSE,
    display_order INTEGER DEFAULT 0,
    color_code VARCHAR(7),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE statement_statuses IS 'Catálogo de estados para cuentas de pago de asociados (GENERATED, PAID, OVERDUE).';

CREATE INDEX IF NOT EXISTS idx_statement_statuses_name ON statement_statuses(name);

-- =============================================================================
-- 9. CONFIG_TYPES - Tipos de Configuración
-- =============================================================================
CREATE TABLE IF NOT EXISTS config_types (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT,
    validation_regex TEXT,
    example_value TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE config_types IS 'Catálogo de tipos de datos para configuraciones del sistema (STRING, NUMBER, BOOLEAN, JSON).';

CREATE INDEX IF NOT EXISTS idx_config_types_name ON config_types(name);

-- =============================================================================
-- 10. LEVEL_CHANGE_TYPES - Tipos de Cambio de Nivel
-- =============================================================================
CREATE TABLE IF NOT EXISTS level_change_types (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT NOT NULL,
    is_automatic BOOLEAN DEFAULT FALSE,
    display_order INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE level_change_types IS 'Catálogo de tipos de cambio de nivel de asociados (PROMOTION, DEMOTION, MANUAL).';

CREATE INDEX IF NOT EXISTS idx_level_change_types_name ON level_change_types(name);

-- =============================================================================
-- 11. ASSOCIATE_LEVELS - Niveles de Asociados
-- =============================================================================
CREATE TABLE IF NOT EXISTS associate_levels (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) UNIQUE NOT NULL,
    max_loan_amount DECIMAL(12, 2) NOT NULL,
    credit_limit DECIMAL(12, 2) DEFAULT 0.00, -- ⭐ NUEVO v2.0: Límite de crédito por nivel
    description TEXT,
    min_clients INTEGER DEFAULT 0,
    min_collection_rate DECIMAL(5, 2) DEFAULT 0.00,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE associate_levels IS 'Niveles de asociados (Bronce, Plata, Oro, Platino, Diamante) con límites de préstamo y crédito.';
COMMENT ON COLUMN associate_levels.credit_limit IS 'Límite de crédito disponible para el asociado en este nivel (v2.0).';

-- =============================================================================
-- 12. DOCUMENT_TYPES - Tipos de Documentos
-- =============================================================================
CREATE TABLE IF NOT EXISTS document_types (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) UNIQUE NOT NULL,
    description TEXT,
    is_required BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE document_types IS 'Tipos de documentos requeridos para clientes (INE, comprobante de domicilio, etc.).';

-- =============================================================================
-- FIN MÓDULO 01
-- =============================================================================
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
    email VARCHAR(150) UNIQUE, -- NULL permitido: usuarios mayores pueden no tener email
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
COMMENT ON COLUMN users.email IS 'Email del usuario (OPCIONAL - algunos usuarios mayores pueden no tener correo electrónico).';
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
    status_id INTEGER NOT NULL REFERENCES loan_statuses(id),
    contract_id INTEGER, -- FK a contracts (se agregará después)
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
    CONSTRAINT check_loans_term_biweeks_valid CHECK (term_biweeks BETWEEN 1 AND 52),
    CONSTRAINT check_loans_approved_after_created CHECK (approved_at IS NULL OR approved_at >= created_at),
    CONSTRAINT check_loans_rejected_after_created CHECK (rejected_at IS NULL OR rejected_at >= created_at)
);

COMMENT ON TABLE loans IS 'Tabla central del sistema. Registra todos los préstamos solicitados, aprobados, rechazados o completados.';
COMMENT ON COLUMN loans.term_biweeks IS 'Plazo del préstamo en quincenas (1 quincena = 15 días). Ejemplo: 12 quincenas = 6 meses.';
COMMENT ON COLUMN loans.commission_rate IS 'Tasa de comisión del asociado en porcentaje. Ejemplo: 2.5 = 2.5%. Rango válido: 0-100.';

-- Índices para loans
CREATE INDEX IF NOT EXISTS idx_loans_user_id ON loans(user_id);
CREATE INDEX IF NOT EXISTS idx_loans_associate_user_id ON loans(associate_user_id);
CREATE INDEX IF NOT EXISTS idx_loans_status_id ON loans(status_id);
CREATE INDEX IF NOT EXISTS idx_loans_approved_at ON loans(approved_at) WHERE approved_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_loans_status_id_approved_at ON loans(status_id, approved_at);

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
    CONSTRAINT check_payments_dates_logical CHECK (payment_date <= payment_due_date)
);

COMMENT ON TABLE payments IS 'Schedule de pagos generado automáticamente cuando un préstamo es aprobado. Un registro por cada quincena del plazo.';
COMMENT ON COLUMN payments.payment_due_date IS 'Fecha de vencimiento del pago según reglas de negocio: día 15 o último día del mes. Generado por calculate_first_payment_date().';
COMMENT ON COLUMN payments.is_late IS 'Indica si el pago está atrasado (TRUE si payment_due_date < CURRENT_DATE y no está pagado).';
COMMENT ON COLUMN payments.marked_by IS '⭐ v2.0: Usuario que marcó manualmente el estado del pago (admin puede remarcar).';

-- Índices para payments
CREATE INDEX IF NOT EXISTS idx_payments_loan_id ON payments(loan_id);
CREATE INDEX IF NOT EXISTS idx_payments_payment_due_date ON payments(payment_due_date);
CREATE INDEX IF NOT EXISTS idx_payments_is_late ON payments(is_late);
CREATE INDEX IF NOT EXISTS idx_payments_cut_period_id ON payments(cut_period_id);
CREATE INDEX IF NOT EXISTS idx_payments_status_id ON payments(status_id); -- ⭐ NUEVO v2.0
CREATE INDEX IF NOT EXISTS idx_payments_late_loan ON payments(loan_id, is_late, payment_due_date); -- Compuesto para consultas de mora

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
-- =============================================================================
-- CREDINET DB v2.0 - MÓDULO 04: TABLAS DE AUDITORÍA Y TRACKING
-- =============================================================================
-- Descripción:
--   Tablas para auditoría completa del sistema y tracking especializado.
--   Incluye:
--   - Migración 12: payment_status_history (historial completo de cambios)
--   - Migración 09: defaulted_client_reports, associate_debt_breakdown
--   - Sistema de auditoría general (audit_log)
--
-- Tablas incluidas:
--   - audit_log (auditoría general para todas las tablas)
--   - payment_status_history ⭐ MIGRACIÓN 12 (tracking de pagos)
--   - defaulted_client_reports ⭐ MIGRACIÓN 09 (reportes de morosidad)
--   - associate_debt_breakdown ⭐ MIGRACIÓN 09 (desglose de deuda)
--
-- Versión: 2.0.0
-- Fecha: 2025-10-30
-- =============================================================================

-- =============================================================================
-- 1. AUDIT_LOG - Sistema de Auditoría General
-- =============================================================================
CREATE TABLE IF NOT EXISTS audit_log (
    id SERIAL PRIMARY KEY,
    table_name VARCHAR(100) NOT NULL,
    record_id INTEGER NOT NULL,
    operation VARCHAR(10) NOT NULL CHECK (operation IN ('INSERT', 'UPDATE', 'DELETE')),
    old_data JSONB,
    new_data JSONB,
    changed_by INTEGER REFERENCES users(id),
    changed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    ip_address INET,
    user_agent TEXT
);

COMMENT ON TABLE audit_log IS 'Registro de auditoría general para todas las tablas críticas (loans, payments, contracts, etc.).';
COMMENT ON COLUMN audit_log.old_data IS 'Snapshot JSON del registro ANTES del cambio (solo en UPDATE y DELETE).';
COMMENT ON COLUMN audit_log.new_data IS 'Snapshot JSON del registro DESPUÉS del cambio (solo en INSERT y UPDATE).';

-- Índices para consultas rápidas
CREATE INDEX IF NOT EXISTS idx_audit_log_table_record ON audit_log(table_name, record_id);
CREATE INDEX IF NOT EXISTS idx_audit_log_changed_by ON audit_log(changed_by);
CREATE INDEX IF NOT EXISTS idx_audit_log_changed_at ON audit_log(changed_at);
CREATE INDEX IF NOT EXISTS idx_audit_log_operation ON audit_log(operation);

-- =============================================================================
-- 2. PAYMENT_STATUS_HISTORY ⭐ MIGRACIÓN 12 - Historial de Cambios de Estado de Pagos
-- =============================================================================
CREATE TABLE IF NOT EXISTS payment_status_history (
    id SERIAL PRIMARY KEY,
    payment_id INTEGER NOT NULL REFERENCES payments(id) ON DELETE CASCADE,
    old_status_id INTEGER REFERENCES payment_statuses(id),
    new_status_id INTEGER NOT NULL REFERENCES payment_statuses(id),
    change_type VARCHAR(50) NOT NULL, -- AUTOMATIC, MANUAL_ADMIN, SYSTEM_CLOSURE, CORRECTION
    changed_by INTEGER REFERENCES users(id), -- Usuario que realizó el cambio (NULL si automático)
    change_reason TEXT, -- Razón del cambio (obligatorio en manuales)
    ip_address INET,
    user_agent TEXT,
    changed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Validaciones
    CONSTRAINT check_payment_status_history_change_type_valid CHECK (
        change_type IN ('AUTOMATIC', 'MANUAL_ADMIN', 'SYSTEM_CLOSURE', 'CORRECTION', 'TRIGGER')
    ),
    CONSTRAINT check_payment_status_history_manual_has_user CHECK (
        (change_type IN ('MANUAL_ADMIN', 'CORRECTION') AND changed_by IS NOT NULL) OR
        (change_type NOT IN ('MANUAL_ADMIN', 'CORRECTION'))
    )
);

COMMENT ON TABLE payment_status_history IS '⭐ MIGRACIÓN 12: Registro completo de todos los cambios de estado de pagos para auditoría y compliance.';
COMMENT ON COLUMN payment_status_history.change_type IS 'Tipo de cambio: AUTOMATIC (trigger), MANUAL_ADMIN (admin marcó), SYSTEM_CLOSURE (cierre de período), CORRECTION (corrección manual).';
COMMENT ON COLUMN payment_status_history.changed_by IS 'Usuario que realizó el cambio. NULL si fue automático (trigger o cierre de sistema).';
COMMENT ON COLUMN payment_status_history.change_reason IS 'Razón del cambio (obligatorio en cambios manuales). Ej: "Cliente pagó en efectivo pero no se había registrado".';

-- Índices especializados
CREATE INDEX IF NOT EXISTS idx_payment_status_history_payment_id ON payment_status_history(payment_id);
CREATE INDEX IF NOT EXISTS idx_payment_status_history_changed_at ON payment_status_history(changed_at DESC);
CREATE INDEX IF NOT EXISTS idx_payment_status_history_changed_by ON payment_status_history(changed_by);
CREATE INDEX IF NOT EXISTS idx_payment_status_history_change_type ON payment_status_history(change_type);
CREATE INDEX IF NOT EXISTS idx_payment_status_history_new_status_id ON payment_status_history(new_status_id);

-- Índice compuesto para análisis forense (pagos con múltiples cambios)
CREATE INDEX IF NOT EXISTS idx_payment_status_history_payment_changed_at ON payment_status_history(payment_id, changed_at DESC);

-- =============================================================================
-- 3. DEFAULTED_CLIENT_REPORTS ⭐ MIGRACIÓN 09 - Reportes de Clientes Morosos
-- =============================================================================
CREATE TABLE IF NOT EXISTS defaulted_client_reports (
    id SERIAL PRIMARY KEY,
    associate_profile_id INTEGER NOT NULL REFERENCES associate_profiles(id) ON DELETE CASCADE,
    loan_id INTEGER NOT NULL REFERENCES loans(id),
    client_user_id INTEGER NOT NULL REFERENCES users(id),
    reported_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    reported_by INTEGER NOT NULL REFERENCES users(id), -- Asociado que reporta
    total_debt_amount DECIMAL(12, 2) NOT NULL,
    evidence_details TEXT, -- Descripción de la evidencia
    evidence_file_path VARCHAR(500), -- Path al archivo de evidencia
    status VARCHAR(50) NOT NULL DEFAULT 'PENDING', -- PENDING, APPROVED, REJECTED
    approved_by INTEGER REFERENCES users(id),
    approved_at TIMESTAMP WITH TIME ZONE,
    rejection_reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Validaciones
    CONSTRAINT check_defaulted_reports_debt_positive CHECK (total_debt_amount > 0),
    CONSTRAINT check_defaulted_reports_status_valid CHECK (
        status IN ('PENDING', 'APPROVED', 'REJECTED', 'IN_REVIEW')
    ),
    CONSTRAINT check_defaulted_reports_approved_has_user CHECK (
        (status = 'APPROVED' AND approved_by IS NOT NULL AND approved_at IS NOT NULL) OR
        (status != 'APPROVED')
    )
);

COMMENT ON TABLE defaulted_client_reports IS '⭐ MIGRACIÓN 09: Reportes de clientes morosos presentados por asociados con evidencia. Requieren aprobación administrativa.';
COMMENT ON COLUMN defaulted_client_reports.evidence_details IS 'Descripción detallada de la evidencia de morosidad (llamadas, visitas, mensajes, etc.).';
COMMENT ON COLUMN defaulted_client_reports.evidence_file_path IS 'Path a archivo de evidencia (screenshots, grabaciones, etc.).';

-- Índices
CREATE INDEX IF NOT EXISTS idx_defaulted_reports_associate_profile_id ON defaulted_client_reports(associate_profile_id);
CREATE INDEX IF NOT EXISTS idx_defaulted_reports_loan_id ON defaulted_client_reports(loan_id);
CREATE INDEX IF NOT EXISTS idx_defaulted_reports_client_user_id ON defaulted_client_reports(client_user_id);
CREATE INDEX IF NOT EXISTS idx_defaulted_reports_status ON defaulted_client_reports(status);
CREATE INDEX IF NOT EXISTS idx_defaulted_reports_reported_at ON defaulted_client_reports(reported_at DESC);

-- =============================================================================
-- 4. ASSOCIATE_DEBT_BREAKDOWN ⭐ MIGRACIÓN 09 - Desglose Detallado de Deuda
-- =============================================================================
CREATE TABLE IF NOT EXISTS associate_debt_breakdown (
    id SERIAL PRIMARY KEY,
    associate_profile_id INTEGER NOT NULL REFERENCES associate_profiles(id) ON DELETE CASCADE,
    cut_period_id INTEGER NOT NULL REFERENCES cut_periods(id),
    debt_type VARCHAR(50) NOT NULL, -- UNREPORTED_PAYMENT, DEFAULTED_CLIENT, LATE_FEE, OTHER
    loan_id INTEGER REFERENCES loans(id),
    client_user_id INTEGER REFERENCES users(id),
    amount DECIMAL(12, 2) NOT NULL,
    description TEXT,
    is_liquidated BOOLEAN NOT NULL DEFAULT false,
    liquidated_at TIMESTAMP WITH TIME ZONE,
    liquidation_reference VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Validaciones
    CONSTRAINT check_debt_breakdown_amount_positive CHECK (amount > 0),
    CONSTRAINT check_debt_breakdown_type_valid CHECK (
        debt_type IN ('UNREPORTED_PAYMENT', 'DEFAULTED_CLIENT', 'LATE_FEE', 'OTHER')
    ),
    CONSTRAINT check_debt_breakdown_liquidated_has_timestamp CHECK (
        (is_liquidated = true AND liquidated_at IS NOT NULL) OR
        (is_liquidated = false AND liquidated_at IS NULL)
    )
);

COMMENT ON TABLE associate_debt_breakdown IS '⭐ MIGRACIÓN 09: Desglose detallado de la deuda del asociado por tipo y origen (préstamo/cliente).';
COMMENT ON COLUMN associate_debt_breakdown.debt_type IS 'Tipo de deuda: UNREPORTED_PAYMENT (pago no reportado al cierre), DEFAULTED_CLIENT (cliente moroso aprobado), LATE_FEE (mora del 30%), OTHER (otros).';
COMMENT ON COLUMN associate_debt_breakdown.is_liquidated IS 'TRUE si la deuda ya fue liquidada (pagada o incluida en convenio).';

-- Índices
CREATE INDEX IF NOT EXISTS idx_debt_breakdown_associate_profile_id ON associate_debt_breakdown(associate_profile_id);
CREATE INDEX IF NOT EXISTS idx_debt_breakdown_cut_period_id ON associate_debt_breakdown(cut_period_id);
CREATE INDEX IF NOT EXISTS idx_debt_breakdown_debt_type ON associate_debt_breakdown(debt_type);
CREATE INDEX IF NOT EXISTS idx_debt_breakdown_loan_id ON associate_debt_breakdown(loan_id);
CREATE INDEX IF NOT EXISTS idx_debt_breakdown_is_liquidated ON associate_debt_breakdown(is_liquidated);

-- Índice compuesto para análisis de deuda por asociado y período
CREATE INDEX IF NOT EXISTS idx_debt_breakdown_associate_period ON associate_debt_breakdown(associate_profile_id, cut_period_id, is_liquidated);

-- =============================================================================
-- 5. AUDIT_SESSION_LOG - Registro de Sesiones (Opcional, para compliance avanzado)
-- =============================================================================
CREATE TABLE IF NOT EXISTS audit_session_log (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    session_token VARCHAR(500) NOT NULL,
    login_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    logout_at TIMESTAMP WITH TIME ZONE,
    ip_address INET,
    user_agent TEXT,
    is_active BOOLEAN DEFAULT true,
    
    -- Validaciones
    CONSTRAINT check_session_log_logout_after_login CHECK (
        logout_at IS NULL OR logout_at >= login_at
    )
);

COMMENT ON TABLE audit_session_log IS 'Registro de sesiones de usuario para auditoría de accesos al sistema (opcional, para compliance).';

-- Índices
CREATE INDEX IF NOT EXISTS idx_session_log_user_id ON audit_session_log(user_id);
CREATE INDEX IF NOT EXISTS idx_session_log_login_at ON audit_session_log(login_at DESC);
CREATE INDEX IF NOT EXISTS idx_session_log_is_active ON audit_session_log(is_active);

-- =============================================================================
-- FIN MÓDULO 04
-- =============================================================================
-- =============================================================================
-- CREDINET DB v2.0 - MÓDULO 05: FUNCIONES BASE (NIVEL 1)
-- =============================================================================
-- Descripción:
--   Funciones base sin dependencias complejas. Nivel 1 en jerarquía.
--   Incluye funciones críticas del sistema y de migraciones 07, 10, 11, 12.
--
-- Funciones incluidas:
--   - calculate_first_payment_date() ⭐ ORÁCULO (doble calendario)
--   - calculate_loan_remaining_balance()
--   - handle_loan_approval_status()
--   - check_associate_credit_available() ⭐ MIGRACIÓN 07
--   - calculate_late_fee_for_statement() ⭐ MIGRACIÓN 10
--   - admin_mark_payment_status() ⭐ MIGRACIÓN 11
--   - log_payment_status_change() ⭐ MIGRACIÓN 12 (trigger function)
--   - get_payment_history() ⭐ MIGRACIÓN 12
--   - detect_suspicious_payment_changes() ⭐ MIGRACIÓN 12
--   - revert_last_payment_change() ⭐ MIGRACIÓN 12
--   - calculate_payment_preview() (preview sin persistir)
--
-- Versión: 2.0.0
-- Fecha: 2025-10-30
-- =============================================================================

-- =============================================================================
-- FUNCIÓN 1: calculate_first_payment_date ⭐ ORÁCULO DEL DOBLE CALENDARIO
-- =============================================================================
CREATE OR REPLACE FUNCTION calculate_first_payment_date(
    p_approval_date DATE
)
RETURNS DATE AS $$
DECLARE
    v_approval_day INTEGER;
    v_approval_year INTEGER;
    v_approval_month INTEGER;
    v_first_payment_date DATE;
    v_next_month_date DATE;
    v_last_day_current_month DATE;
BEGIN
    -- Extraer componentes de la fecha
    v_approval_day := EXTRACT(DAY FROM p_approval_date)::INTEGER;
    v_approval_year := EXTRACT(YEAR FROM p_approval_date)::INTEGER;
    v_approval_month := EXTRACT(MONTH FROM p_approval_date)::INTEGER;
    
    -- Pre-calcular fechas comunes
    v_next_month_date := p_approval_date + INTERVAL '1 month';
    v_last_day_current_month := (DATE_TRUNC('month', p_approval_date) + INTERVAL '1 month' - INTERVAL '1 day')::DATE;
    
    -- Aplicar lógica del doble calendario
    v_first_payment_date := CASE
        -- CASO 1: Aprobación días 1-7 → Primer pago día 15 del mes ACTUAL
        WHEN v_approval_day >= 1 AND v_approval_day < 8 THEN
            MAKE_DATE(v_approval_year, v_approval_month, 15)
        
        -- CASO 2: Aprobación días 8-22 → Primer pago ÚLTIMO día del mes ACTUAL
        WHEN v_approval_day >= 8 AND v_approval_day < 23 THEN
            v_last_day_current_month
        
        -- CASO 3: Aprobación día 23+ → Primer pago día 15 del mes SIGUIENTE
        WHEN v_approval_day >= 23 THEN
            MAKE_DATE(
                EXTRACT(YEAR FROM v_next_month_date)::INTEGER,
                EXTRACT(MONTH FROM v_next_month_date)::INTEGER,
                15
            )
        
        ELSE NULL
    END;
    
    -- Validaciones
    IF p_approval_date IS NULL THEN
        RAISE EXCEPTION 'La fecha de aprobación no puede ser NULL';
    END IF;
    
    IF v_approval_day < 1 OR v_approval_day > 31 THEN
        RAISE EXCEPTION 'Día de aprobación inválido: %. Debe estar entre 1 y 31.', v_approval_day;
    END IF;
    
    IF v_first_payment_date < p_approval_date THEN
        RAISE WARNING 'ALERTA: La fecha de primer pago (%) es anterior a la fecha de aprobación (%).',
            v_first_payment_date, p_approval_date;
    END IF;
    
    RETURN v_first_payment_date;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Error al calcular primera fecha de pago para %: % (%)',
            p_approval_date, SQLERRM, SQLSTATE;
END;
$$ LANGUAGE plpgsql
IMMUTABLE
STRICT
PARALLEL SAFE;

COMMENT ON FUNCTION calculate_first_payment_date(DATE) IS 
'⭐ ORÁCULO: Calcula la primera fecha de pago del cliente según lógica del doble calendario (cortes días 8 y 23, vencimientos días 15 y último). INMUTABLE y PURA.';

-- =============================================================================
-- FUNCIÓN 2: calculate_loan_remaining_balance
-- =============================================================================
CREATE OR REPLACE FUNCTION calculate_loan_remaining_balance(
    p_loan_id INTEGER
)
RETURNS DECIMAL(12,2) AS $$
DECLARE
    v_total_amount DECIMAL(12,2);
    v_total_paid DECIMAL(12,2);
    v_remaining DECIMAL(12,2);
BEGIN
    -- Obtener monto total del préstamo
    SELECT amount INTO v_total_amount
    FROM loans
    WHERE id = p_loan_id;
    
    IF v_total_amount IS NULL THEN
        RAISE EXCEPTION 'Préstamo con ID % no encontrado', p_loan_id;
    END IF;
    
    -- Calcular total pagado
    SELECT COALESCE(SUM(amount_paid), 0) INTO v_total_paid
    FROM payments
    WHERE loan_id = p_loan_id;
    
    v_remaining := v_total_amount - v_total_paid;
    
    -- No permitir saldo negativo
    IF v_remaining < 0 THEN
        v_remaining := 0;
    END IF;
    
    RETURN v_remaining;
END;
$$ LANGUAGE plpgsql
STABLE;

COMMENT ON FUNCTION calculate_loan_remaining_balance(INTEGER) IS 
'Calcula el saldo pendiente de un préstamo (monto total - pagos realizados).';

-- =============================================================================
-- FUNCIÓN 3: handle_loan_approval_status
-- =============================================================================
CREATE OR REPLACE FUNCTION handle_loan_approval_status()
RETURNS TRIGGER AS $$
DECLARE
    v_approved_status_id INTEGER;
    v_rejected_status_id INTEGER;
BEGIN
    -- Obtener IDs de estados APPROVED y REJECTED
    SELECT id INTO v_approved_status_id FROM loan_statuses WHERE name = 'APPROVED';
    SELECT id INTO v_rejected_status_id FROM loan_statuses WHERE name = 'REJECTED';
    
    -- Si cambió a APPROVED, setear timestamp
    IF NEW.status_id = v_approved_status_id AND (OLD.status_id IS NULL OR OLD.status_id != v_approved_status_id) AND NEW.approved_at IS NULL THEN
        NEW.approved_at = CURRENT_TIMESTAMP;
    END IF;
    
    -- Si cambió a REJECTED, setear timestamp  
    IF NEW.status_id = v_rejected_status_id AND (OLD.status_id IS NULL OR OLD.status_id != v_rejected_status_id) AND NEW.rejected_at IS NULL THEN
        NEW.rejected_at = CURRENT_TIMESTAMP;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION handle_loan_approval_status() IS 
'Trigger function: Setea automáticamente approved_at o rejected_at cuando el estado del préstamo cambia.';

-- =============================================================================
-- FUNCIÓN 4: check_associate_credit_available ⭐ MIGRACIÓN 07
-- =============================================================================
CREATE OR REPLACE FUNCTION check_associate_credit_available(
    p_associate_profile_id INTEGER,
    p_requested_amount DECIMAL(12,2)
)
RETURNS BOOLEAN AS $$
DECLARE
    v_credit_available DECIMAL(12,2);
    v_credit_limit DECIMAL(12,2);
    v_credit_used DECIMAL(12,2);
    v_debt_balance DECIMAL(12,2);
BEGIN
    -- Obtener datos del asociado
    SELECT credit_limit, credit_used, debt_balance
    INTO v_credit_limit, v_credit_used, v_debt_balance
    FROM associate_profiles
    WHERE id = p_associate_profile_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Perfil de asociado % no encontrado', p_associate_profile_id;
    END IF;
    
    -- Calcular crédito disponible
    v_credit_available := v_credit_limit - v_credit_used - v_debt_balance;
    
    -- Validar si hay crédito suficiente
    IF v_credit_available >= p_requested_amount THEN
        RETURN TRUE;
    ELSE
        RAISE NOTICE 'Crédito insuficiente. Disponible: %, Solicitado: %', v_credit_available, p_requested_amount;
        RETURN FALSE;
    END IF;
END;
$$ LANGUAGE plpgsql
STABLE;

COMMENT ON FUNCTION check_associate_credit_available(INTEGER, DECIMAL) IS 
'⭐ MIGRACIÓN 07: Valida si un asociado tiene crédito disponible suficiente para absorber un préstamo (credit_limit - credit_used - debt_balance >= monto).';

-- =============================================================================
-- FUNCIÓN 5: calculate_late_fee_for_statement ⭐ MIGRACIÓN 10
-- =============================================================================
CREATE OR REPLACE FUNCTION calculate_late_fee_for_statement(
    p_statement_id INTEGER
)
RETURNS DECIMAL(12,2) AS $$
DECLARE
    v_total_payments_count INTEGER;
    v_total_commission_owed DECIMAL(12,2);
    v_late_fee DECIMAL(12,2);
BEGIN
    -- Obtener datos del statement
    SELECT total_payments_count, total_commission_owed
    INTO v_total_payments_count, v_total_commission_owed
    FROM associate_payment_statements
    WHERE id = p_statement_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Statement % no encontrado', p_statement_id;
    END IF;
    
    -- Aplicar regla: Si NO reportó ningún pago, mora del 30% sobre comisión
    IF v_total_payments_count = 0 AND v_total_commission_owed > 0 THEN
        v_late_fee := v_total_commission_owed * 0.30;
        RAISE NOTICE 'Mora del 30%% aplicada: % (comisión: %)', v_late_fee, v_total_commission_owed;
    ELSE
        v_late_fee := 0.00;
    END IF;
    
    RETURN ROUND(v_late_fee, 2);
END;
$$ LANGUAGE plpgsql
STABLE;

COMMENT ON FUNCTION calculate_late_fee_for_statement(INTEGER) IS 
'⭐ MIGRACIÓN 10: Calcula mora del 30% sobre comisión si el asociado NO reportó ningún pago en el período (total_payments_count = 0).';

-- =============================================================================
-- FUNCIÓN 6: admin_mark_payment_status ⭐ MIGRACIÓN 11
-- =============================================================================
CREATE OR REPLACE FUNCTION admin_mark_payment_status(
    p_payment_id INTEGER,
    p_new_status_id INTEGER,
    p_admin_user_id INTEGER,
    p_notes TEXT DEFAULT NULL
)
RETURNS VOID AS $$
DECLARE
    v_old_status_id INTEGER;
BEGIN
    -- Obtener estado actual
    SELECT status_id INTO v_old_status_id
    FROM payments
    WHERE id = p_payment_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Pago % no encontrado', p_payment_id;
    END IF;
    
    -- Actualizar estado del pago
    UPDATE payments
    SET 
        status_id = p_new_status_id,
        marked_by = p_admin_user_id,
        marked_at = CURRENT_TIMESTAMP,
        marking_notes = p_notes,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = p_payment_id;
    
    RAISE NOTICE 'Pago % marcado como estado % por usuario %', p_payment_id, p_new_status_id, p_admin_user_id;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION admin_mark_payment_status(INTEGER, INTEGER, INTEGER, TEXT) IS 
'⭐ MIGRACIÓN 11: Permite a un administrador marcar manualmente el estado de un pago con notas. El trigger de auditoría registrará el cambio automáticamente.';

-- =============================================================================
-- FUNCIÓN 7: log_payment_status_change ⭐ MIGRACIÓN 12 (TRIGGER FUNCTION)
-- =============================================================================
CREATE OR REPLACE FUNCTION log_payment_status_change()
RETURNS TRIGGER AS $$
DECLARE
    v_change_type VARCHAR(50);
    v_changed_by INTEGER;
BEGIN
    -- Solo registrar si el status_id cambió
    IF OLD.status_id IS DISTINCT FROM NEW.status_id THEN
        
        -- Determinar tipo de cambio
        IF NEW.marked_by IS NOT NULL THEN
            v_change_type := 'MANUAL_ADMIN';
            v_changed_by := NEW.marked_by;
        ELSE
            v_change_type := 'AUTOMATIC';
            v_changed_by := NULL;
        END IF;
        
        -- Insertar en historial
        INSERT INTO payment_status_history (
            payment_id,
            old_status_id,
            new_status_id,
            change_type,
            changed_by,
            change_reason,
            changed_at
        ) VALUES (
            NEW.id,
            OLD.status_id,
            NEW.status_id,
            v_change_type,
            v_changed_by,
            NEW.marking_notes,
            CURRENT_TIMESTAMP
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION log_payment_status_change() IS 
'⭐ MIGRACIÓN 12: Trigger function que registra automáticamente todos los cambios de estado de pagos en payment_status_history para auditoría completa.';

-- =============================================================================
-- FUNCIÓN 8: get_payment_history ⭐ MIGRACIÓN 12
-- =============================================================================
CREATE OR REPLACE FUNCTION get_payment_history(
    p_payment_id INTEGER
)
RETURNS TABLE(
    change_id INTEGER,
    old_status VARCHAR(50),
    new_status VARCHAR(50),
    change_type VARCHAR(50),
    changed_by_username VARCHAR(50),
    change_reason TEXT,
    changed_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        psh.id,
        ps_old.name,
        ps_new.name,
        psh.change_type,
        u.username,
        psh.change_reason,
        psh.changed_at
    FROM payment_status_history psh
    LEFT JOIN payment_statuses ps_old ON psh.old_status_id = ps_old.id
    JOIN payment_statuses ps_new ON psh.new_status_id = ps_new.id
    LEFT JOIN users u ON psh.changed_by = u.id
    WHERE psh.payment_id = p_payment_id
    ORDER BY psh.changed_at DESC;
END;
$$ LANGUAGE plpgsql
STABLE;

COMMENT ON FUNCTION get_payment_history(INTEGER) IS 
'⭐ MIGRACIÓN 12: Obtiene el historial completo de cambios de estado de un pago (timeline forense).';

-- =============================================================================
-- FUNCIÓN 9: detect_suspicious_payment_changes ⭐ MIGRACIÓN 12
-- =============================================================================
CREATE OR REPLACE FUNCTION detect_suspicious_payment_changes(
    p_days_back INTEGER DEFAULT 7,
    p_min_changes INTEGER DEFAULT 3
)
RETURNS TABLE(
    payment_id INTEGER,
    loan_id INTEGER,
    client_name TEXT,
    total_changes BIGINT,
    last_change TIMESTAMP WITH TIME ZONE,
    status_sequence TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.id,
        p.loan_id,
        CONCAT(u.first_name, ' ', u.last_name),
        COUNT(psh.id),
        MAX(psh.changed_at),
        STRING_AGG(ps.name, ' → ' ORDER BY psh.changed_at)
    FROM payments p
    JOIN payment_status_history psh ON p.id = psh.payment_id
    JOIN payment_statuses ps ON psh.new_status_id = ps.id
    JOIN loans l ON p.loan_id = l.id
    JOIN users u ON l.user_id = u.id
    WHERE psh.changed_at >= CURRENT_TIMESTAMP - (p_days_back || ' days')::INTERVAL
    GROUP BY p.id, p.loan_id, u.first_name, u.last_name
    HAVING COUNT(psh.id) >= p_min_changes
    ORDER BY COUNT(psh.id) DESC, MAX(psh.changed_at) DESC;
END;
$$ LANGUAGE plpgsql
STABLE;

COMMENT ON FUNCTION detect_suspicious_payment_changes(INTEGER, INTEGER) IS 
'⭐ MIGRACIÓN 12: Detecta pagos con patrones anómalos (3+ cambios de estado en N días). Útil para detección de fraude o errores.';

-- =============================================================================
-- FUNCIÓN 10: revert_last_payment_change ⭐ MIGRACIÓN 12
-- =============================================================================
CREATE OR REPLACE FUNCTION revert_last_payment_change(
    p_payment_id INTEGER,
    p_admin_user_id INTEGER,
    p_reason TEXT
)
RETURNS VOID AS $$
DECLARE
    v_last_old_status_id INTEGER;
    v_current_status_id INTEGER;
BEGIN
    -- Obtener estado actual
    SELECT status_id INTO v_current_status_id
    FROM payments
    WHERE id = p_payment_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Pago % no encontrado', p_payment_id;
    END IF;
    
    -- Obtener el estado anterior (último cambio)
    SELECT old_status_id INTO v_last_old_status_id
    FROM payment_status_history
    WHERE payment_id = p_payment_id
    ORDER BY changed_at DESC
    LIMIT 1;
    
    IF v_last_old_status_id IS NULL THEN
        RAISE EXCEPTION 'No hay historial previo para revertir el pago %', p_payment_id;
    END IF;
    
    -- Revertir al estado anterior
    UPDATE payments
    SET 
        status_id = v_last_old_status_id,
        marked_by = p_admin_user_id,
        marked_at = CURRENT_TIMESTAMP,
        marking_notes = 'REVERSIÓN: ' || p_reason,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = p_payment_id;
    
    RAISE NOTICE 'Pago % revertido de estado % a estado % por usuario %', 
        p_payment_id, v_current_status_id, v_last_old_status_id, p_admin_user_id;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION revert_last_payment_change(INTEGER, INTEGER, TEXT) IS 
'⭐ MIGRACIÓN 12: Revierte el último cambio de estado de un pago (función de emergencia para corregir errores).';

-- =============================================================================
-- FUNCIÓN 11: calculate_payment_preview (Preview sin persistir)
-- =============================================================================
CREATE OR REPLACE FUNCTION calculate_payment_preview(
    p_approval_timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    p_term_biweeks INTEGER DEFAULT 12,
    p_amount DECIMAL(12,2) DEFAULT 100000.00
)
RETURNS TABLE(
    payment_number INTEGER,
    payment_due_date DATE,
    payment_amount DECIMAL(12,2),
    payment_type TEXT,
    cut_period_estimated TEXT
) AS $$
DECLARE
    v_approval_date DATE;
    v_approval_day INTEGER;
    v_current_payment_date DATE;
    v_payment_amount DECIMAL(12,2);
    i INTEGER;
BEGIN
    v_approval_date := p_approval_timestamp::DATE;
    v_approval_day := EXTRACT(DAY FROM v_approval_date);
    v_payment_amount := ROUND(p_amount / p_term_biweeks, 2);
    
    -- Calcular primera fecha usando el oráculo
    v_current_payment_date := calculate_first_payment_date(v_approval_date);
    
    -- Generar preview de todos los pagos
    FOR i IN 1..p_term_biweeks LOOP
        RETURN QUERY SELECT 
            i,
            v_current_payment_date,
            v_payment_amount,
            CASE 
                WHEN EXTRACT(DAY FROM v_current_payment_date) = 15 THEN 'DÍA_15'
                ELSE 'ÚLTIMO_DÍA'
            END::TEXT,
            CASE 
                WHEN EXTRACT(DAY FROM v_current_payment_date) <= 8 THEN 'CORTE_8_' || EXTRACT(MONTH FROM v_current_payment_date)::TEXT
                ELSE 'CORTE_23_' || EXTRACT(MONTH FROM v_current_payment_date)::TEXT
            END::TEXT;
        
        -- Alternar fechas: día 15 ↔ último día del mes
        IF EXTRACT(DAY FROM v_current_payment_date) = 15 THEN
            v_current_payment_date := (DATE_TRUNC('month', v_current_payment_date) + INTERVAL '1 month' - INTERVAL '1 day')::DATE;
        ELSE
            v_current_payment_date := MAKE_DATE(
                EXTRACT(YEAR FROM v_current_payment_date + INTERVAL '1 month')::INTEGER,
                EXTRACT(MONTH FROM v_current_payment_date + INTERVAL '1 month')::INTEGER,
                15
            );
        END IF;
    END LOOP;
    
    RETURN;
END;
$$ LANGUAGE plpgsql
STABLE;

COMMENT ON FUNCTION calculate_payment_preview(TIMESTAMP WITH TIME ZONE, INTEGER, DECIMAL) IS 
'Genera un preview del cronograma de pagos sin persistir en BD (útil para mostrar al usuario antes de aprobar).';

-- =============================================================================
-- FIN MÓDULO 05
-- =============================================================================
-- =============================================================================
-- CREDINET DB v2.0 - MÓDULO 06: FUNCIONES DE NEGOCIO (NIVEL 2-3)
-- =============================================================================
-- Descripción:
--   Funciones de lógica de negocio con dependencias complejas.
--   Incluye funciones críticas de migraciones 08 y 09.
--
-- Funciones incluidas:
--   - generate_payment_schedule() ⭐ CRÍTICA (genera cronograma al aprobar)
--   - close_period_and_accumulate_debt() ⭐ MIGRACIÓN 08 v3 (cierre de período)
--   - report_defaulted_client() ⭐ MIGRACIÓN 09 (reportar moroso)
--   - approve_defaulted_client_report() ⭐ MIGRACIÓN 09 (aprobar reporte)
--   - renew_loan() (renovación de préstamos)
--
-- Versión: 2.0.0
-- Fecha: 2025-10-30
-- =============================================================================

-- =============================================================================
-- FUNCIÓN 1: generate_payment_schedule ⭐ TRIGGER CRÍTICO
-- =============================================================================
CREATE OR REPLACE FUNCTION generate_payment_schedule()
RETURNS TRIGGER AS $$
DECLARE
    v_approval_date DATE;
    v_first_payment_date DATE;
    v_current_payment_date DATE;
    v_payment_amount DECIMAL(12,2);
    v_payment_count INTEGER;
    v_period_id INTEGER;
    v_total_inserted INTEGER := 0;
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
    v_approved_status_id INTEGER;
    v_pending_status_id INTEGER;
BEGIN
    -- Obtener IDs de estados
    SELECT id INTO v_approved_status_id FROM loan_statuses WHERE name = 'APPROVED';
    SELECT id INTO v_pending_status_id FROM payment_statuses WHERE name = 'PENDING';
    
    -- Solo ejecutar si el préstamo acaba de ser aprobado
    IF NEW.status_id = v_approved_status_id AND (OLD.status_id IS NULL OR OLD.status_id != v_approved_status_id) THEN
        
        v_start_time := CLOCK_TIMESTAMP();
        
        -- Validaciones
        IF NEW.approved_at IS NULL THEN
            RAISE EXCEPTION 'CRITICAL: Préstamo % marcado como APPROVED pero approved_at es NULL', NEW.id;
        END IF;
        
        IF NEW.term_biweeks IS NULL OR NEW.term_biweeks <= 0 THEN
            RAISE EXCEPTION 'CRITICAL: Préstamo % tiene term_biweeks inválido: %', NEW.id, NEW.term_biweeks;
        END IF;
        
        v_approval_date := NEW.approved_at::DATE;
        v_payment_amount := ROUND(NEW.amount / NEW.term_biweeks, 2);
        
        RAISE NOTICE '🎯 Generando schedule para préstamo %: Monto=%, Plazo=% quincenas, Aprobado=%',
            NEW.id, NEW.amount, NEW.term_biweeks, v_approval_date;
        
        -- Calcular primera fecha usando el oráculo
        v_first_payment_date := calculate_first_payment_date(v_approval_date);
        
        RAISE NOTICE '📅 Primera fecha de pago: % (aprobado el %)', 
            v_first_payment_date, v_approval_date;
        
        v_current_payment_date := v_first_payment_date;
        
        -- Generar cronograma completo
        FOR v_payment_count IN 1..NEW.term_biweeks LOOP
            
            -- Buscar el período de corte apropiado
            SELECT id INTO v_period_id 
            FROM cut_periods 
            WHERE period_start_date <= v_current_payment_date 
              AND period_end_date >= v_current_payment_date 
            ORDER BY period_start_date DESC
            LIMIT 1;
            
            IF v_period_id IS NULL THEN
                RAISE WARNING 'No se encontró cut_period para fecha %. Insertando con period_id = NULL', 
                    v_current_payment_date;
            END IF;
            
            -- Insertar pago
            INSERT INTO payments (
                loan_id, 
                amount_paid,
                payment_date,
                payment_due_date,
                is_late,
                status_id,
                cut_period_id,
                created_at,
                updated_at
            ) VALUES (
                NEW.id,
                0.00,
                v_current_payment_date,
                v_current_payment_date,
                false,
                v_pending_status_id, -- Estado inicial: PENDING
                v_period_id,
                CURRENT_TIMESTAMP,
                CURRENT_TIMESTAMP
            );
            
            v_total_inserted := v_total_inserted + 1;
            
            -- Calcular siguiente fecha (alternancia día 15 ↔ último día)
            IF EXTRACT(DAY FROM v_current_payment_date) = 15 THEN
                v_current_payment_date := (
                    DATE_TRUNC('month', v_current_payment_date) + INTERVAL '1 month' - INTERVAL '1 day'
                )::DATE;
            ELSE
                v_current_payment_date := MAKE_DATE(
                    EXTRACT(YEAR FROM v_current_payment_date + INTERVAL '1 month')::INTEGER,
                    EXTRACT(MONTH FROM v_current_payment_date + INTERVAL '1 month')::INTEGER,
                    15
                );
            END IF;
            
            IF v_payment_count % 5 = 0 THEN
                RAISE DEBUG 'Progreso: % de % pagos insertados', v_payment_count, NEW.term_biweeks;
            END IF;
            
        END LOOP;
        
        v_end_time := CLOCK_TIMESTAMP();
        
        IF v_total_inserted != NEW.term_biweeks THEN
            RAISE WARNING 'INCONSISTENCIA: Se insertaron % pagos pero se esperaban %. Préstamo %',
                v_total_inserted, NEW.term_biweeks, NEW.id;
        ELSE
            RAISE NOTICE '✅ Schedule generado: % pagos en % ms',
                v_total_inserted, 
                EXTRACT(MILLISECONDS FROM (v_end_time - v_start_time));
        END IF;
        
    END IF;
    
    RETURN NEW;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'ERROR al generar payment schedule para préstamo %: % (%)', 
            NEW.id, SQLERRM, SQLSTATE;
        RETURN NULL;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION generate_payment_schedule() IS 
'⭐ CRÍTICA: Trigger que genera automáticamente el cronograma completo de pagos quincenales cuando un préstamo es aprobado.';

-- =============================================================================
-- FUNCIÓN 2: close_period_and_accumulate_debt ⭐ MIGRACIÓN 08 v3
-- =============================================================================
CREATE OR REPLACE FUNCTION close_period_and_accumulate_debt(
    p_cut_period_id INTEGER,
    p_closed_by INTEGER
)
RETURNS VOID AS $$
DECLARE
    v_period_start DATE;
    v_period_end DATE;
    v_paid_status_id INTEGER;
    v_paid_not_reported_id INTEGER;
    v_paid_by_associate_id INTEGER;
    v_total_payments_marked INTEGER := 0;
    v_unreported_count INTEGER := 0;
    v_morosos_count INTEGER := 0;
BEGIN
    -- Obtener fechas del período
    SELECT period_start_date, period_end_date
    INTO v_period_start, v_period_end
    FROM cut_periods
    WHERE id = p_cut_period_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Período de corte % no encontrado', p_cut_period_id;
    END IF;
    
    -- Obtener IDs de estados
    SELECT id INTO v_paid_status_id FROM payment_statuses WHERE name = 'PAID';
    SELECT id INTO v_paid_not_reported_id FROM payment_statuses WHERE name = 'PAID_NOT_REPORTED';
    SELECT id INTO v_paid_by_associate_id FROM payment_statuses WHERE name = 'PAID_BY_ASSOCIATE';
    
    RAISE NOTICE '🔒 Cerrando período %: % a %', p_cut_period_id, v_period_start, v_period_end;
    
    -- PASO 1: Marcar pagos reportados como PAID
    WITH updated AS (
        UPDATE payments
        SET status_id = v_paid_status_id,
            updated_at = CURRENT_TIMESTAMP
        WHERE cut_period_id = p_cut_period_id
          AND status_id NOT IN (v_paid_status_id, v_paid_not_reported_id, v_paid_by_associate_id)
          AND amount_paid > 0
        RETURNING id
    )
    SELECT COUNT(*) INTO v_total_payments_marked FROM updated;
    
    RAISE NOTICE '✅ Pagos reportados marcados como PAID: %', v_total_payments_marked;
    
    -- PASO 2: Marcar pagos NO reportados como PAID_NOT_REPORTED
    WITH updated AS (
        UPDATE payments
        SET status_id = v_paid_not_reported_id,
            updated_at = CURRENT_TIMESTAMP
        WHERE cut_period_id = p_cut_period_id
          AND status_id NOT IN (v_paid_status_id, v_paid_not_reported_id, v_paid_by_associate_id)
          AND (amount_paid = 0 OR amount_paid IS NULL)
        RETURNING id
    )
    SELECT COUNT(*) INTO v_unreported_count FROM updated;
    
    RAISE NOTICE '⚠️  Pagos NO reportados marcados como PAID_NOT_REPORTED: %', v_unreported_count;
    
    -- PASO 3: Marcar clientes morosos como PAID_BY_ASSOCIATE
    -- (Esta lógica se implementará cuando se aprueben reportes de morosidad)
    
    -- PASO 4: Actualizar estado del período
    UPDATE cut_periods
    SET status_id = (SELECT id FROM cut_period_statuses WHERE name = 'CLOSED'),
        closed_by = p_closed_by,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = p_cut_period_id;
    
    -- PASO 5: Acumular deuda en associate_debt_breakdown
    -- Por cada pago PAID_NOT_REPORTED, crear registro de deuda
    INSERT INTO associate_debt_breakdown (
        associate_profile_id,
        cut_period_id,
        debt_type,
        loan_id,
        client_user_id,
        amount,
        description,
        is_liquidated
    )
    SELECT 
        ap.id,
        p.cut_period_id,
        'UNREPORTED_PAYMENT',
        l.id,
        l.user_id,
        p.amount_paid,
        'Pago no reportado al cierre del período',
        false
    FROM payments p
    JOIN loans l ON p.loan_id = l.id
    JOIN associate_profiles ap ON l.associate_user_id = ap.user_id
    WHERE p.cut_period_id = p_cut_period_id
      AND p.status_id = v_paid_not_reported_id;
    
    -- PASO 6: Actualizar debt_balance en associate_profiles
    UPDATE associate_profiles ap
    SET debt_balance = (
        SELECT COALESCE(SUM(amount), 0)
        FROM associate_debt_breakdown adb
        WHERE adb.associate_profile_id = ap.id
          AND adb.is_liquidated = false
    );
    
    RAISE NOTICE '✅ Período % cerrado exitosamente', p_cut_period_id;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION close_period_and_accumulate_debt(INTEGER, INTEGER) IS 
'⭐ MIGRACIÓN 08 v3: Cierra un período de corte marcando TODOS los pagos según regla: reportados→PAID, no reportados→PAID_NOT_REPORTED, morosos→PAID_BY_ASSOCIATE.';

-- =============================================================================
-- FUNCIÓN 3: report_defaulted_client ⭐ MIGRACIÓN 09
-- =============================================================================
CREATE OR REPLACE FUNCTION report_defaulted_client(
    p_associate_profile_id INTEGER,
    p_loan_id INTEGER,
    p_reported_by INTEGER,
    p_total_debt_amount DECIMAL(12,2),
    p_evidence_details TEXT,
    p_evidence_file_path VARCHAR(500) DEFAULT NULL
)
RETURNS INTEGER AS $$
DECLARE
    v_client_user_id INTEGER;
    v_report_id INTEGER;
BEGIN
    -- Obtener ID del cliente desde el préstamo
    SELECT user_id INTO v_client_user_id
    FROM loans
    WHERE id = p_loan_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Préstamo % no encontrado', p_loan_id;
    END IF;
    
    -- Insertar reporte de morosidad
    INSERT INTO defaulted_client_reports (
        associate_profile_id,
        loan_id,
        client_user_id,
        reported_by,
        total_debt_amount,
        evidence_details,
        evidence_file_path,
        status
    ) VALUES (
        p_associate_profile_id,
        p_loan_id,
        v_client_user_id,
        p_reported_by,
        p_total_debt_amount,
        p_evidence_details,
        p_evidence_file_path,
        'PENDING'
    ) RETURNING id INTO v_report_id;
    
    RAISE NOTICE '📋 Reporte de morosidad creado: ID %, Cliente %, Deuda: %', 
        v_report_id, v_client_user_id, p_total_debt_amount;
    
    RETURN v_report_id;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION report_defaulted_client(INTEGER, INTEGER, INTEGER, DECIMAL, TEXT, VARCHAR) IS 
'⭐ MIGRACIÓN 09: Permite a un asociado reportar un cliente moroso con evidencia. El reporte queda en estado PENDING hasta aprobación administrativa.';

-- =============================================================================
-- FUNCIÓN 4: approve_defaulted_client_report ⭐ MIGRACIÓN 09
-- =============================================================================
CREATE OR REPLACE FUNCTION approve_defaulted_client_report(
    p_report_id INTEGER,
    p_approved_by INTEGER,
    p_cut_period_id INTEGER
)
RETURNS VOID AS $$
DECLARE
    v_associate_profile_id INTEGER;
    v_loan_id INTEGER;
    v_client_user_id INTEGER;
    v_total_debt_amount DECIMAL(12,2);
    v_paid_by_associate_id INTEGER;
BEGIN
    -- Obtener datos del reporte
    SELECT 
        associate_profile_id,
        loan_id,
        client_user_id,
        total_debt_amount
    INTO 
        v_associate_profile_id,
        v_loan_id,
        v_client_user_id,
        v_total_debt_amount
    FROM defaulted_client_reports
    WHERE id = p_report_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Reporte % no encontrado', p_report_id;
    END IF;
    
    -- Obtener ID del estado PAID_BY_ASSOCIATE
    SELECT id INTO v_paid_by_associate_id FROM payment_statuses WHERE name = 'PAID_BY_ASSOCIATE';
    
    -- Actualizar reporte como aprobado
    UPDATE defaulted_client_reports
    SET status = 'APPROVED',
        approved_by = p_approved_by,
        approved_at = CURRENT_TIMESTAMP
    WHERE id = p_report_id;
    
    -- Marcar pagos del préstamo como PAID_BY_ASSOCIATE
    UPDATE payments
    SET status_id = v_paid_by_associate_id,
        updated_at = CURRENT_TIMESTAMP
    WHERE loan_id = v_loan_id
      AND status_id NOT IN (
          SELECT id FROM payment_statuses WHERE name IN ('PAID', 'PAID_BY_ASSOCIATE')
      );
    
    -- Crear registro de deuda en associate_debt_breakdown
    INSERT INTO associate_debt_breakdown (
        associate_profile_id,
        cut_period_id,
        debt_type,
        loan_id,
        client_user_id,
        amount,
        description,
        is_liquidated
    ) VALUES (
        v_associate_profile_id,
        p_cut_period_id,
        'DEFAULTED_CLIENT',
        v_loan_id,
        v_client_user_id,
        v_total_debt_amount,
        'Cliente moroso aprobado - Reporte #' || p_report_id,
        false
    );
    
    -- Actualizar debt_balance del asociado
    UPDATE associate_profiles
    SET debt_balance = debt_balance + v_total_debt_amount
    WHERE id = v_associate_profile_id;
    
    RAISE NOTICE '✅ Reporte % aprobado. Deuda de % agregada a asociado %', 
        p_report_id, v_total_debt_amount, v_associate_profile_id;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION approve_defaulted_client_report(INTEGER, INTEGER, INTEGER) IS 
'⭐ MIGRACIÓN 09: Aprueba un reporte de cliente moroso, marca pagos como PAID_BY_ASSOCIATE y crea registro de deuda en associate_debt_breakdown.';

-- =============================================================================
-- FUNCIÓN 5: renew_loan (Renovación de Préstamos)
-- =============================================================================
CREATE OR REPLACE FUNCTION renew_loan(
    p_original_loan_id INTEGER,
    p_new_amount DECIMAL(12,2),
    p_new_term_biweeks INTEGER,
    p_interest_rate DECIMAL(5,2),
    p_commission_rate DECIMAL(5,2),
    p_created_by INTEGER
)
RETURNS INTEGER AS $$
DECLARE
    v_client_user_id INTEGER;
    v_associate_user_id INTEGER;
    v_pending_balance DECIMAL(12,2);
    v_new_loan_id INTEGER;
    v_pending_status_id INTEGER;
BEGIN
    -- Obtener datos del préstamo original
    SELECT 
        user_id,
        associate_user_id
    INTO 
        v_client_user_id,
        v_associate_user_id
    FROM loans
    WHERE id = p_original_loan_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Préstamo original % no encontrado', p_original_loan_id;
    END IF;
    
    -- Calcular saldo pendiente
    v_pending_balance := calculate_loan_remaining_balance(p_original_loan_id);
    
    -- Obtener ID del estado PENDING
    SELECT id INTO v_pending_status_id FROM loan_statuses WHERE name = 'PENDING';
    
    -- Crear nuevo préstamo
    INSERT INTO loans (
        user_id,
        associate_user_id,
        amount,
        interest_rate,
        commission_rate,
        term_biweeks,
        status_id,
        notes,
        created_at
    ) VALUES (
        v_client_user_id,
        v_associate_user_id,
        p_new_amount,
        p_interest_rate,
        p_commission_rate,
        p_new_term_biweeks,
        v_pending_status_id,
        'Renovación de préstamo #' || p_original_loan_id || '. Saldo pendiente: ' || v_pending_balance,
        CURRENT_TIMESTAMP
    ) RETURNING id INTO v_new_loan_id;
    
    -- Registrar la renovación
    INSERT INTO loan_renewals (
        original_loan_id,
        renewed_loan_id,
        renewal_date,
        pending_balance,
        new_amount,
        reason,
        created_by
    ) VALUES (
        p_original_loan_id,
        v_new_loan_id,
        CURRENT_DATE,
        v_pending_balance,
        p_new_amount,
        'Renovación estándar',
        p_created_by
    );
    
    RAISE NOTICE '✅ Préstamo % renovado como préstamo %. Saldo pendiente: %, Nuevo monto: %',
        p_original_loan_id, v_new_loan_id, v_pending_balance, p_new_amount;
    
    RETURN v_new_loan_id;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION renew_loan(INTEGER, DECIMAL, INTEGER, DECIMAL, DECIMAL, INTEGER) IS 
'Renueva un préstamo existente creando uno nuevo. Calcula automáticamente el saldo pendiente y lo registra en loan_renewals.';

-- =============================================================================
-- FIN MÓDULO 06
-- =============================================================================
-- =============================================================================
-- CREDINET DB v2.0 - MÓDULO 07: TRIGGERS
-- =============================================================================
-- Descripción:
--   Todos los triggers del sistema organizados por categoría.
--   Incluye triggers de migraciones 07 y 12.
--
-- Categorías:
--   1. Triggers de updated_at (automáticos)
--   2. Trigger de aprobación de préstamos
--   3. Trigger de generación de schedule ⭐ CRÍTICO
--   4. Trigger de historial de pagos ⭐ MIGRACIÓN 12
--   5. Triggers de crédito del asociado ⭐ MIGRACIÓN 07
--   6. Triggers de auditoría general
--
-- Total: 28 triggers
-- Versión: 2.0.0
-- Fecha: 2025-10-30
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
                
                UPDATE associate_profiles
                SET credit_used = GREATEST(credit_used - v_amount_diff, 0),
                    credit_last_updated = CURRENT_TIMESTAMP
                WHERE id = v_associate_profile_id;
                
                RAISE NOTICE 'Crédito del asociado % actualizado por pago: -%', v_associate_profile_id, v_amount_diff;
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
-- FIN MÓDULO 07
-- =============================================================================
-- =============================================================================
-- CREDINET DB v2.0 - MÓDULO 08: VISTAS
-- =============================================================================
-- Descripción:
--   Vistas especializadas para consultas comunes del sistema.
--   Todas las vistas provienen de las migraciones 07-12.
--
-- Vistas incluidas:
--   - v_associate_credit_summary ⭐ MIGRACIÓN 07
--   - v_period_closure_summary ⭐ MIGRACIÓN 08
--   - v_associate_debt_detailed ⭐ MIGRACIÓN 09
--   - v_associate_late_fees ⭐ MIGRACIÓN 10
--   - v_payments_by_status_detailed ⭐ MIGRACIÓN 11
--   - v_payments_absorbed_by_associate ⭐ MIGRACIÓN 11
--   - v_payment_changes_summary ⭐ MIGRACIÓN 12
--   - v_recent_payment_changes ⭐ MIGRACIÓN 12
--   - v_payments_multiple_changes ⭐ MIGRACIÓN 12
--
-- Total: 9 vistas
-- Versión: 2.0.0
-- Fecha: 2025-10-30
-- =============================================================================

-- =============================================================================
-- VISTA 1: v_associate_credit_summary ⭐ MIGRACIÓN 07
-- =============================================================================
CREATE OR REPLACE VIEW v_associate_credit_summary AS
SELECT 
    ap.id AS associate_profile_id,
    u.id AS user_id,
    CONCAT(u.first_name, ' ', u.last_name) AS associate_name,
    u.email,
    al.name AS associate_level,
    ap.credit_limit,
    ap.credit_used,
    ap.debt_balance,
    ap.credit_available,
    ap.credit_last_updated,
    CASE 
        WHEN ap.credit_available <= 0 THEN 'SIN_CREDITO'
        WHEN ap.credit_available < (ap.credit_limit * 0.25) THEN 'CRITICO'
        WHEN ap.credit_available < (ap.credit_limit * 0.50) THEN 'MEDIO'
        ELSE 'ALTO'
    END AS credit_status,
    ROUND((ap.credit_used::DECIMAL / NULLIF(ap.credit_limit, 0)) * 100, 2) AS credit_usage_percentage,
    ap.active AS is_active
FROM associate_profiles ap
JOIN users u ON ap.user_id = u.id
JOIN associate_levels al ON ap.level_id = al.id
ORDER BY ap.credit_available DESC;

COMMENT ON VIEW v_associate_credit_summary IS 
'⭐ MIGRACIÓN 07: Resumen ejecutivo del crédito disponible de cada asociado con análisis de utilización y estado.';

-- =============================================================================
-- VISTA 2: v_period_closure_summary ⭐ MIGRACIÓN 08
-- =============================================================================
CREATE OR REPLACE VIEW v_period_closure_summary AS
SELECT 
    cp.id AS cut_period_id,
    cp.cut_number,
    cp.period_start_date,
    cp.period_end_date,
    cps.name AS period_status,
    COUNT(p.id) AS total_payments,
    COUNT(CASE WHEN ps.name = 'PAID' THEN 1 END) AS payments_paid,
    COUNT(CASE WHEN ps.name = 'PAID_NOT_REPORTED' THEN 1 END) AS payments_not_reported,
    COUNT(CASE WHEN ps.name = 'PAID_BY_ASSOCIATE' THEN 1 END) AS payments_by_associate,
    COUNT(CASE WHEN ps.name IN ('PENDING', 'DUE_TODAY', 'OVERDUE') THEN 1 END) AS payments_pending,
    COALESCE(SUM(CASE WHEN ps.name = 'PAID' THEN p.amount_paid ELSE 0 END), 0) AS total_collected,
    cp.total_payments_expected,
    cp.total_commission,
    CONCAT(u.first_name, ' ', u.last_name) AS closed_by_name,
    cp.updated_at AS last_updated
FROM cut_periods cp
JOIN cut_period_statuses cps ON cp.status_id = cps.id
LEFT JOIN payments p ON cp.id = p.cut_period_id
LEFT JOIN payment_statuses ps ON p.status_id = ps.id
LEFT JOIN users u ON cp.closed_by = u.id
GROUP BY 
    cp.id, cp.cut_number, cp.period_start_date, cp.period_end_date,
    cps.name, cp.total_payments_expected, cp.total_commission,
    u.first_name, u.last_name, cp.updated_at
ORDER BY cp.period_start_date DESC;

COMMENT ON VIEW v_period_closure_summary IS 
'⭐ MIGRACIÓN 08: Resumen de cierre de cada período de corte con estadísticas de pagos por estado (PAID, PAID_NOT_REPORTED, PAID_BY_ASSOCIATE).';

-- =============================================================================
-- VISTA 3: v_associate_debt_detailed ⭐ MIGRACIÓN 09
-- =============================================================================
CREATE OR REPLACE VIEW v_associate_debt_detailed AS
SELECT 
    adb.id AS debt_id,
    ap.id AS associate_profile_id,
    CONCAT(u.first_name, ' ', u.last_name) AS associate_name,
    adb.debt_type,
    adb.amount AS debt_amount,
    adb.is_liquidated,
    adb.liquidated_at,
    cp.cut_number,
    cp.period_start_date,
    cp.period_end_date,
    l.id AS loan_id,
    CONCAT(uc.first_name, ' ', uc.last_name) AS client_name,
    adb.description,
    adb.created_at AS debt_registered_at,
    CASE adb.debt_type
        WHEN 'UNREPORTED_PAYMENT' THEN 'Pago no reportado al cierre'
        WHEN 'DEFAULTED_CLIENT' THEN 'Cliente moroso aprobado'
        WHEN 'LATE_FEE' THEN 'Mora del 30% aplicada'
        WHEN 'OTHER' THEN 'Otro tipo de deuda'
    END AS debt_type_description
FROM associate_debt_breakdown adb
JOIN associate_profiles ap ON adb.associate_profile_id = ap.id
JOIN users u ON ap.user_id = u.id
JOIN cut_periods cp ON adb.cut_period_id = cp.id
LEFT JOIN loans l ON adb.loan_id = l.id
LEFT JOIN users uc ON adb.client_user_id = uc.id
ORDER BY adb.created_at DESC, adb.is_liquidated ASC;

COMMENT ON VIEW v_associate_debt_detailed IS 
'⭐ MIGRACIÓN 09: Desglose detallado de todas las deudas de asociados por tipo, origen y estado de liquidación.';

-- =============================================================================
-- VISTA 4: v_associate_late_fees ⭐ MIGRACIÓN 10
-- =============================================================================
CREATE OR REPLACE VIEW v_associate_late_fees AS
SELECT 
    aps.id AS statement_id,
    aps.statement_number,
    CONCAT(u.first_name, ' ', u.last_name) AS associate_name,
    cp.cut_number,
    cp.period_start_date,
    cp.period_end_date,
    aps.total_payments_count,
    aps.total_amount_collected,
    aps.total_commission_owed,
    aps.late_fee_amount,
    aps.late_fee_applied,
    ss.name AS statement_status,
    CASE 
        WHEN aps.late_fee_applied THEN 'MORA APLICADA'
        WHEN aps.total_payments_count = 0 AND aps.total_commission_owed > 0 THEN 'SUJETO A MORA'
        ELSE 'SIN MORA'
    END AS late_fee_status,
    ROUND((aps.late_fee_amount / NULLIF(aps.total_commission_owed, 0)) * 100, 2) AS late_fee_percentage,
    aps.generated_date,
    aps.due_date,
    aps.paid_date
FROM associate_payment_statements aps
JOIN users u ON aps.user_id = u.id
JOIN cut_periods cp ON aps.cut_period_id = cp.id
JOIN statement_statuses ss ON aps.status_id = ss.id
WHERE aps.late_fee_amount > 0 OR (aps.total_payments_count = 0 AND aps.total_commission_owed > 0)
ORDER BY aps.generated_date DESC, aps.late_fee_amount DESC;

COMMENT ON VIEW v_associate_late_fees IS 
'⭐ MIGRACIÓN 10: Vista especializada de moras del 30% aplicadas o potenciales (cuando payments_count = 0).';

-- =============================================================================
-- VISTA 5: v_payments_by_status_detailed ⭐ MIGRACIÓN 11
-- =============================================================================
CREATE OR REPLACE VIEW v_payments_by_status_detailed AS
SELECT 
    p.id AS payment_id,
    p.loan_id,
    CONCAT(u.first_name, ' ', u.last_name) AS client_name,
    l.amount AS loan_amount,
    p.amount_paid,
    p.payment_date,
    p.payment_due_date,
    p.is_late,
    ps.name AS payment_status,
    ps.is_real_payment,
    CASE 
        WHEN ps.is_real_payment THEN 'REAL 💵'
        ELSE 'FICTICIO ⚠️'
    END AS payment_type,
    CONCAT(um.first_name, ' ', um.last_name) AS marked_by_name,
    p.marked_at,
    p.marking_notes,
    cp.cut_number,
    cp.period_start_date,
    cp.period_end_date,
    CONCAT(ua.first_name, ' ', ua.last_name) AS associate_name,
    p.created_at,
    p.updated_at
FROM payments p
JOIN loans l ON p.loan_id = l.id
JOIN users u ON l.user_id = u.id
JOIN payment_statuses ps ON p.status_id = ps.id
LEFT JOIN users um ON p.marked_by = um.id
LEFT JOIN cut_periods cp ON p.cut_period_id = cp.id
LEFT JOIN users ua ON l.associate_user_id = ua.id
ORDER BY p.payment_due_date DESC, p.id DESC;

COMMENT ON VIEW v_payments_by_status_detailed IS 
'⭐ MIGRACIÓN 11: Vista detallada de todos los pagos con su estado, tipo (real/ficticio) y tracking de marcado manual.';

-- =============================================================================
-- VISTA 6: v_payments_absorbed_by_associate ⭐ MIGRACIÓN 11
-- =============================================================================
CREATE OR REPLACE VIEW v_payments_absorbed_by_associate AS
SELECT 
    CONCAT(ua.first_name, ' ', ua.last_name) AS associate_name,
    ap.id AS associate_profile_id,
    COUNT(p.id) AS total_payments_absorbed,
    SUM(p.amount_paid) AS total_amount_absorbed,
    ps.name AS payment_status,
    cp.cut_number,
    cp.period_start_date,
    cp.period_end_date,
    STRING_AGG(DISTINCT CONCAT(uc.first_name, ' ', uc.last_name), ', ') AS affected_clients
FROM payments p
JOIN payment_statuses ps ON p.status_id = ps.id
JOIN loans l ON p.loan_id = l.id
JOIN users uc ON l.user_id = uc.id
JOIN users ua ON l.associate_user_id = ua.id
JOIN associate_profiles ap ON ua.id = ap.user_id
LEFT JOIN cut_periods cp ON p.cut_period_id = cp.id
WHERE ps.is_real_payment = FALSE
  AND ps.name IN ('PAID_BY_ASSOCIATE', 'PAID_NOT_REPORTED')
GROUP BY 
    ua.first_name, ua.last_name, ap.id, ps.name,
    cp.cut_number, cp.period_start_date, cp.period_end_date
ORDER BY SUM(p.amount_paid) DESC;

COMMENT ON VIEW v_payments_absorbed_by_associate IS 
'⭐ MIGRACIÓN 11: Resumen de pagos absorbidos por cada asociado (PAID_BY_ASSOCIATE, PAID_NOT_REPORTED) con totales y clientes afectados.';

-- =============================================================================
-- VISTA 7: v_payment_changes_summary ⭐ MIGRACIÓN 12
-- =============================================================================
CREATE OR REPLACE VIEW v_payment_changes_summary AS
SELECT 
    DATE(psh.changed_at) AS change_date,
    psh.change_type,
    COUNT(*) AS total_changes,
    COUNT(DISTINCT psh.payment_id) AS unique_payments,
    COUNT(DISTINCT psh.changed_by) AS unique_users,
    STRING_AGG(DISTINCT ps_new.name, ', ') AS status_changes_to,
    MIN(psh.changed_at) AS first_change,
    MAX(psh.changed_at) AS last_change
FROM payment_status_history psh
JOIN payment_statuses ps_new ON psh.new_status_id = ps_new.id
GROUP BY DATE(psh.changed_at), psh.change_type
ORDER BY change_date DESC, total_changes DESC;

COMMENT ON VIEW v_payment_changes_summary IS 
'⭐ MIGRACIÓN 12: Resumen estadístico diario de cambios de estado de pagos agrupados por tipo (AUTOMATIC, MANUAL_ADMIN, etc.).';

-- =============================================================================
-- VISTA 8: v_recent_payment_changes ⭐ MIGRACIÓN 12
-- =============================================================================
CREATE OR REPLACE VIEW v_recent_payment_changes AS
SELECT 
    psh.id AS change_id,
    psh.payment_id,
    p.loan_id,
    CONCAT(u.first_name, ' ', u.last_name) AS client_name,
    ps_old.name AS old_status,
    ps_new.name AS new_status,
    psh.change_type,
    CONCAT(uc.first_name, ' ', uc.last_name) AS changed_by_name,
    psh.change_reason,
    psh.changed_at,
    EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - psh.changed_at)) / 3600 AS hours_ago
FROM payment_status_history psh
JOIN payments p ON psh.payment_id = p.id
JOIN loans l ON p.loan_id = l.id
JOIN users u ON l.user_id = u.id
LEFT JOIN payment_statuses ps_old ON psh.old_status_id = ps_old.id
JOIN payment_statuses ps_new ON psh.new_status_id = ps_new.id
LEFT JOIN users uc ON psh.changed_by = uc.id
WHERE psh.changed_at >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
ORDER BY psh.changed_at DESC;

COMMENT ON VIEW v_recent_payment_changes IS 
'⭐ MIGRACIÓN 12: Cambios de estado de pagos en las últimas 24 horas (útil para monitoreo en tiempo real y detección temprana de anomalías).';

-- =============================================================================
-- VISTA 9: v_payments_multiple_changes ⭐ MIGRACIÓN 12
-- =============================================================================
CREATE OR REPLACE VIEW v_payments_multiple_changes AS
SELECT 
    p.id AS payment_id,
    p.loan_id,
    CONCAT(u.first_name, ' ', u.last_name) AS client_name,
    COUNT(psh.id) AS total_changes,
    STRING_AGG(
        CONCAT(ps.name, ' (', TO_CHAR(psh.changed_at, 'YYYY-MM-DD HH24:MI'), ')'),
        ' → '
        ORDER BY psh.changed_at
    ) AS status_timeline,
    MIN(psh.changed_at) AS first_change,
    MAX(psh.changed_at) AS last_change,
    EXTRACT(EPOCH FROM (MAX(psh.changed_at) - MIN(psh.changed_at))) / 3600 AS hours_between_first_last,
    COUNT(CASE WHEN psh.change_type = 'MANUAL_ADMIN' THEN 1 END) AS manual_changes_count,
    CASE 
        WHEN COUNT(psh.id) >= 5 THEN 'CRÍTICO'
        WHEN COUNT(psh.id) >= 3 THEN 'ALERTA'
        ELSE 'NORMAL'
    END AS review_priority
FROM payments p
JOIN payment_status_history psh ON p.id = psh.payment_id
JOIN payment_statuses ps ON psh.new_status_id = ps.id
JOIN loans l ON p.loan_id = l.id
JOIN users u ON l.user_id = u.id
GROUP BY p.id, p.loan_id, u.first_name, u.last_name
HAVING COUNT(psh.id) >= 3
ORDER BY COUNT(psh.id) DESC, MAX(psh.changed_at) DESC;

COMMENT ON VIEW v_payments_multiple_changes IS 
'⭐ MIGRACIÓN 12: Pagos con 3 o más cambios de estado (posibles errores, fraude o correcciones múltiples). Prioridad CRÍTICA para revisión forense.';

-- =============================================================================
-- FIN MÓDULO 08
-- =============================================================================
-- =============================================================================
-- CREDINET DB v2.0 - MÓDULO 09: SEEDS (DATOS INICIALES)
-- =============================================================================
-- Descripción:
--   Datos iniciales del sistema para arranque completo.
--   Incluye catálogos, usuarios de prueba, préstamos de ejemplo.
--
-- Contenido:
--   - Catálogos (12 tablas): roles, statuses, levels, types
--   - Usuarios de prueba (8 usuarios + 1 aval)
--   - Préstamos de ejemplo (4 préstamos con casos reales)
--   - Períodos de corte (8 períodos: 2024-2025)
--   - Configuraciones del sistema
--
-- Versión: 2.0.0
-- Fecha: 2025-10-30
-- =============================================================================

-- =============================================================================
-- CATÁLOGO 1: ROLES (5 registros)
-- =============================================================================
INSERT INTO roles (id, name) VALUES
(1, 'desarrollador'),
(2, 'administrador'),
(3, 'auxiliar_administrativo'),
(4, 'asociado'),
(5, 'cliente')
ON CONFLICT (id) DO NOTHING;

-- =============================================================================
-- CATÁLOGO 2: ASSOCIATE_LEVELS (5 niveles)
-- =============================================================================
INSERT INTO associate_levels (id, name, max_loan_amount, credit_limit) VALUES
(1, 'Bronce', 50000.00, 25000.00),
(2, 'Plata', 100000.00, 50000.00),
(3, 'Oro', 250000.00, 125000.00),
(4, 'Platino', 600000.00, 300000.00),
(5, 'Diamante', 1000000.00, 500000.00)
ON CONFLICT (id) DO NOTHING;

-- =============================================================================
-- CATÁLOGO 3: LOAN_STATUSES (8 estados)
-- =============================================================================
INSERT INTO loan_statuses (name, description, is_active, display_order, color_code, icon_name) VALUES
    ('PENDING', 'Préstamo solicitado pero aún no aprobado ni desembolsado.', TRUE, 1, '#FFA500', 'clock'),
    ('APPROVED', 'Préstamo aprobado, listo para desembolso y generación de cronograma.', TRUE, 2, '#4CAF50', 'check-circle'),
    ('ACTIVE', 'Préstamo desembolsado y activo, con pagos en curso.', TRUE, 3, '#2196F3', 'activity'),
    ('COMPLETED', 'Préstamo completamente liquidado.', TRUE, 4, '#00C853', 'check-all'),
    ('PAID', 'Préstamo totalmente pagado (sinónimo de COMPLETED).', TRUE, 5, '#00C853', 'check-all'),
    ('DEFAULTED', 'Préstamo en mora o incumplimiento.', TRUE, 6, '#F44336', 'alert-triangle'),
    ('REJECTED', 'Solicitud rechazada por administrador.', TRUE, 7, '#9E9E9E', 'x-circle'),
    ('CANCELLED', 'Préstamo cancelado antes de completarse.', TRUE, 8, '#757575', 'slash')
ON CONFLICT (name) DO NOTHING;

-- =============================================================================
-- CATÁLOGO 4: PAYMENT_STATUSES (12 estados ⭐ v2.0)
-- =============================================================================
INSERT INTO payment_statuses (id, name, description, is_real_payment, display_order, color_code, icon_name) VALUES
    -- Estados pendientes (6)
    (1, 'PENDING', 'Pago programado, aún no vence.', TRUE, 1, '#9E9E9E', 'clock'),
    (2, 'DUE_TODAY', 'Pago vence hoy.', TRUE, 2, '#FF9800', 'calendar'),
    (4, 'OVERDUE', 'Pago vencido, no pagado.', TRUE, 4, '#F44336', 'alert-circle'),
    (5, 'PARTIAL', 'Pago parcial realizado.', TRUE, 5, '#2196F3', 'pie-chart'),
    (6, 'IN_COLLECTION', 'En proceso de cobranza.', TRUE, 6, '#9C27B0', 'phone'),
    (7, 'RESCHEDULED', 'Pago reprogramado.', TRUE, 7, '#03A9F4', 'refresh-cw'),
    
    -- Estados pagados reales (2) 💵
    (3, 'PAID', 'Pago completado por cliente.', TRUE, 3, '#4CAF50', 'check'),
    (8, 'PAID_PARTIAL', 'Pago parcial aceptado.', TRUE, 8, '#8BC34A', 'check-circle'),
    
    -- Estados ficticios (4) ⚠️
    (9, 'PAID_BY_ASSOCIATE', 'Pagado por asociado (cliente moroso).', FALSE, 9, '#FF5722', 'user-x'),
    (10, 'PAID_NOT_REPORTED', 'Pago no reportado al cierre.', FALSE, 10, '#FFC107', 'alert-triangle'),
    (11, 'FORGIVEN', 'Pago perdonado por administración.', FALSE, 11, '#00BCD4', 'heart'),
    (12, 'CANCELLED', 'Pago cancelado.', FALSE, 12, '#607D8B', 'x')
ON CONFLICT (id) DO NOTHING;

-- =============================================================================
-- CATÁLOGO 5: CONTRACT_STATUSES (6 estados)
-- =============================================================================
INSERT INTO contract_statuses (name, description, is_active, requires_signature, display_order) VALUES
    ('draft', 'Contrato en borrador.', TRUE, FALSE, 1),
    ('pending', 'Pendiente de firma del cliente.', TRUE, TRUE, 2),
    ('signed', 'Firmado por el cliente.', TRUE, FALSE, 3),
    ('active', 'Contrato activo y vigente.', TRUE, FALSE, 4),
    ('completed', 'Contrato completado, préstamo liquidado.', TRUE, FALSE, 5),
    ('cancelled', 'Contrato cancelado.', TRUE, FALSE, 6)
ON CONFLICT (name) DO NOTHING;

-- =============================================================================
-- CATÁLOGO 6: CUT_PERIOD_STATUSES (5 estados)
-- =============================================================================
INSERT INTO cut_period_statuses (name, description, is_terminal, allows_payments, display_order) VALUES
    ('PRELIMINARY', 'Período creado, en configuración.', FALSE, FALSE, 1),
    ('ACTIVE', 'Período activo, permite operaciones.', FALSE, TRUE, 2),
    ('REVIEW', 'En revisión contable.', FALSE, FALSE, 3),
    ('LOCKED', 'Bloqueado para cierre.', FALSE, FALSE, 4),
    ('CLOSED', 'Cerrado definitivamente.', TRUE, FALSE, 5)
ON CONFLICT (name) DO NOTHING;

-- =============================================================================
-- CATÁLOGO 7: PAYMENT_METHODS (7 métodos)
-- =============================================================================
INSERT INTO payment_methods (name, description, is_active, requires_reference, display_order, icon_name) VALUES
    ('CASH', 'Pago en efectivo.', TRUE, FALSE, 1, 'dollar-sign'),
    ('TRANSFER', 'Transferencia bancaria.', TRUE, TRUE, 2, 'arrow-right-circle'),
    ('CHECK', 'Cheque bancario.', TRUE, TRUE, 3, 'file-text'),
    ('PAYROLL_DEDUCTION', 'Descuento de nómina.', TRUE, FALSE, 4, 'briefcase'),
    ('CARD', 'Tarjeta débito/crédito.', TRUE, TRUE, 5, 'credit-card'),
    ('DEPOSIT', 'Depósito bancario.', TRUE, TRUE, 6, 'inbox'),
    ('OXXO', 'Pago en OXXO.', TRUE, TRUE, 7, 'shopping-bag')
ON CONFLICT (name) DO NOTHING;

-- =============================================================================
-- CATÁLOGO 8: DOCUMENT_STATUSES (4 estados)
-- =============================================================================
INSERT INTO document_statuses (name, description, display_order, color_code) VALUES
    ('PENDING', 'Documento cargado, pendiente de revisión.', 1, '#FFA500'),
    ('UNDER_REVIEW', 'En proceso de revisión.', 2, '#2196F3'),
    ('APPROVED', 'Documento aprobado.', 3, '#4CAF50'),
    ('REJECTED', 'Documento rechazado.', 4, '#F44336')
ON CONFLICT (name) DO NOTHING;

-- =============================================================================
-- CATÁLOGO 9: STATEMENT_STATUSES (5 estados)
-- =============================================================================
INSERT INTO statement_statuses (name, description, is_paid, display_order, color_code) VALUES
    ('GENERATED', 'Estado de cuenta generado.', FALSE, 1, '#9E9E9E'),
    ('SENT', 'Enviado al asociado.', FALSE, 2, '#2196F3'),
    ('PAID', 'Pagado completamente.', TRUE, 3, '#4CAF50'),
    ('PARTIAL_PAID', 'Pago parcial recibido.', FALSE, 4, '#FF9800'),
    ('OVERDUE', 'Vencido sin pagar.', FALSE, 5, '#F44336')
ON CONFLICT (name) DO NOTHING;

-- =============================================================================
-- CATÁLOGO 10: CONFIG_TYPES (8 tipos)
-- =============================================================================
INSERT INTO config_types (name, description, validation_regex, example_value) VALUES
    ('STRING', 'Cadena de texto.', NULL, 'Hola Mundo'),
    ('NUMBER', 'Número entero o decimal.', '^-?\d+(\.\d+)?$', '123.45'),
    ('BOOLEAN', 'Valor booleano.', '^(true|false)$', 'true'),
    ('JSON', 'Objeto JSON válido.', NULL, '{"key": "value"}'),
    ('URL', 'URL válida.', '^https?://[^\s]+$', 'https://ejemplo.com'),
    ('EMAIL', 'Correo electrónico.', '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$', 'user@example.com'),
    ('DATE', 'Fecha ISO 8601.', '^\d{4}-\d{2}-\d{2}$', '2025-10-30'),
    ('PERCENTAGE', 'Porcentaje 0-100.', '^(100(\.0+)?|\d{1,2}(\.\d+)?)$', '15.5')
ON CONFLICT (name) DO NOTHING;

-- =============================================================================
-- CATÁLOGO 11: LEVEL_CHANGE_TYPES (6 tipos)
-- =============================================================================
INSERT INTO level_change_types (name, description, is_automatic, display_order) VALUES
    ('PROMOTION', 'Promoción automática a nivel superior.', TRUE, 1),
    ('DEMOTION', 'Descenso por incumplimiento.', TRUE, 2),
    ('MANUAL', 'Cambio manual por admin.', FALSE, 3),
    ('INITIAL', 'Nivel inicial al registrarse.', FALSE, 4),
    ('REWARD', 'Promoción especial por logro.', FALSE, 5),
    ('PENALTY', 'Descenso por sanción.', FALSE, 6)
ON CONFLICT (name) DO NOTHING;

-- =============================================================================
-- CATÁLOGO 12: DOCUMENT_TYPES (5 tipos)
-- =============================================================================
INSERT INTO document_types (id, name, description, is_required) VALUES
(1, 'Identificación Oficial', 'INE, Pasaporte o Cédula Profesional', true),
(2, 'Comprobante de Domicilio', 'Recibo de luz, agua o predial', true),
(3, 'Comprobante de Ingresos', 'Estado de cuenta o constancia laboral', true),
(4, 'CURP', 'Clave Única de Registro de Población', false),
(5, 'Referencia Personal', 'Datos de contacto de referencia', false)
ON CONFLICT (id) DO NOTHING;

-- =============================================================================
-- USUARIOS DE PRUEBA (9 usuarios)
-- Contraseña para todos: Sparrow20
-- Hash bcrypt: $2b$12$aSMdt0Kd8I2lrCIvSNbxx.X5U.BmY9MAZAoPvM/MgK5mXOxQgq0s6
-- =============================================================================
INSERT INTO users (id, username, password_hash, first_name, last_name, email, phone_number, birth_date, curp) VALUES
(1, 'jair', '$2b$12$aSMdt0Kd8I2lrCIvSNbxx.X5U.BmY9MAZAoPvM/MgK5mXOxQgq0s6', 'Jair', 'FC', 'jair@dev.com', '5511223344', '1990-01-15', 'FERJ900115HDFXXX01'),
(2, 'admin', '$2b$12$aSMdt0Kd8I2lrCIvSNbxx.X5U.BmY9MAZAoPvM/MgK5mXOxQgq0s6', 'Admin', 'Total', 'admin@credinet.com', '5522334455', NULL, NULL),
(3, 'asociado_test', '$2b$12$aSMdt0Kd8I2lrCIvSNbxx.X5U.BmY9MAZAoPvM/MgK5mXOxQgq0s6', 'Asociado', 'Prueba', 'asociado@test.com', '5533445566', NULL, NULL),
(4, 'sofia.vargas', '$2b$12$aSMdt0Kd8I2lrCIvSNbxx.X5U.BmY9MAZAoPvM/MgK5mXOxQgq0s6', 'Sofía', 'Vargas', 'sofia.vargas@email.com', '5544556677', '1985-05-20', 'VARS850520MDFXXX02'),
(5, 'juan.perez', '$2b$12$aSMdt0Kd8I2lrCIvSNbxx.X5U.BmY9MAZAoPvM/MgK5mXOxQgq0s6', 'Juan', 'Pérez', 'juan.perez@email.com', '5555667788', '1992-11-30', 'PERJ921130HDFXXX03'),
(6, 'laura.mtz', '$2b$12$aSMdt0Kd8I2lrCIvSNbxx.X5U.BmY9MAZAoPvM/MgK5mXOxQgq0s6', 'Laura', 'Martínez', 'laura.martinez@email.com', '5566778899', NULL, NULL),
(7, 'aux.admin', '$2b$12$aSMdt0Kd8I2lrCIvSNbxx.X5U.BmY9MAZAoPvM/MgK5mXOxQgq0s6', 'Pedro', 'Ramírez', 'pedro.ramirez@credinet.com', '5577889900', NULL, NULL),
(8, 'asociado_norte', '$2b$12$aSMdt0Kd8I2lrCIvSNbxx.X5U.BmY9MAZAoPvM/MgK5mXOxQgq0s6', 'User', 'Norte', 'user@norte.com', '5588990011', NULL, NULL),
(1000, 'aval_test', '$2b$12$aSMdt0Kd8I2lrCIvSNbxx.X5U.BmY9MAZAoPvM/MgK5mXOxQgq0s6', 'María', 'Aval', 'maria.aval@demo.com', '6143618296', '1995-05-25', 'FACJ950525HCHRRR04')
ON CONFLICT (id) DO NOTHING;

-- Asignar roles
INSERT INTO user_roles (user_id, role_id) VALUES
(1, 1), -- jair: desarrollador
(2, 2), -- admin: administrador  
(3, 4), -- asociado_test: asociado
(4, 5), -- sofia.vargas: cliente
(5, 5), -- juan.perez: cliente
(6, 5), -- laura.mtz: cliente
(7, 3), -- aux.admin: auxiliar_administrativo
(8, 4), -- asociado_norte: asociado
(1000, 5) -- aval_test: cliente
ON CONFLICT DO NOTHING;

-- Perfiles de asociados
INSERT INTO associate_profiles (user_id, level_id, contact_person, contact_email, default_commission_rate, credit_limit) VALUES
(3, 2, 'Contacto Central', 'central@distribuidora.com', 4.5, 50000.00),
(8, 1, 'Contacto Norte', 'norte@creditos.com', 5.0, 25000.00)
ON CONFLICT (user_id) DO NOTHING;

-- =============================================================================
-- PRÉSTAMOS DE EJEMPLO (4 préstamos críticos)
-- =============================================================================
INSERT INTO loans (id, user_id, associate_user_id, amount, interest_rate, commission_rate, term_biweeks, status_id, created_at, updated_at) VALUES
-- Préstamo 1: Aprobado 7 enero → Primer pago 15 enero
(1, 4, 3, 100000.00, 2.5, 2.5, 12, 1, '2025-01-07 00:00:00+00', '2025-01-07 00:00:00+00'),
-- Préstamo 2: Aprobado 8 febrero → Primer pago último día febrero
(2, 5, 8, 75000.00, 3.0, 3.0, 8, 1, '2025-02-08 00:00:00+00', '2025-02-08 00:00:00+00'),
-- Préstamo 3: Aprobado 23 febrero → Primer pago 15 marzo
(3, 6, 3, 50000.00, 2.0, 2.0, 6, 1, '2025-02-23 00:00:00+00', '2025-02-23 00:00:00+00'),
-- Préstamo 4: Completado (ejemplo histórico)
(4, 1000, NULL, 25000.00, 1.5, 0.0, 4, 4, '2024-12-07 00:00:00+00', '2024-12-07 00:00:00+00')
ON CONFLICT (id) DO NOTHING;

-- Aprobar préstamos (esto dispara generate_payment_schedule)
UPDATE loans SET status_id = 2, approved_at = '2025-01-07 00:00:00+00', approved_by = 2 WHERE id = 1;
UPDATE loans SET status_id = 2, approved_at = '2025-02-08 00:00:00+00', approved_by = 2 WHERE id = 2;
UPDATE loans SET status_id = 2, approved_at = '2025-02-23 00:00:00+00', approved_by = 2 WHERE id = 3;

-- Contratos
INSERT INTO contracts (id, loan_id, start_date, document_number, status_id) VALUES
(1, 1, '2025-01-07', 'CONT-2025-001', 3),
(2, 2, '2025-02-08', 'CONT-2025-002', 3),
(3, 3, '2025-02-23', 'CONT-2025-003', 3),
(4, 4, '2024-12-07', 'CONT-2024-012', 5)
ON CONFLICT (id) DO NOTHING;

-- Actualizar contract_id en loans
UPDATE loans SET contract_id = 1 WHERE id = 1;
UPDATE loans SET contract_id = 2 WHERE id = 2;
UPDATE loans SET contract_id = 3 WHERE id = 3;
UPDATE loans SET contract_id = 4 WHERE id = 4;

-- =============================================================================
-- DATOS RELACIONADOS (Addresses, Guarantors, Beneficiaries)
-- =============================================================================
INSERT INTO addresses (user_id, street, external_number, internal_number, colony, municipality, state, zip_code) VALUES
(4, 'Av. Insurgentes Sur', '1234', 'Depto 501', 'Del Valle', 'Benito Juárez', 'Ciudad de México', '03100'),
(5, 'Calle Reforma', '567', NULL, 'Polanco', 'Miguel Hidalgo', 'Ciudad de México', '11560'),
(6, 'Av. Chapultepec', '890', 'Local 3', 'Roma Norte', 'Cuauhtémoc', 'Ciudad de México', '06700'),
(3, 'Calle Madero', '123', 'Piso 2', 'Centro Histórico', 'Cuauhtémoc', 'Ciudad de México', '06000')
ON CONFLICT (user_id) DO NOTHING;

INSERT INTO guarantors (user_id, full_name, first_name, paternal_last_name, maternal_last_name, relationship, phone_number, curp) VALUES
(4, 'Carlos Alberto Vargas Hernández', 'Carlos Alberto', 'Vargas', 'Hernández', 'Padre', '5544556600', 'VAHC600101HDFVRR05'),
(5, 'Ana María Pérez Gómez', 'Ana María', 'Pérez', 'Gómez', 'Madre', '5555667700', 'PEGA650202MDFRMN06'),
(6, 'Jorge Luis Martínez Sánchez', 'Jorge Luis', 'Martínez', 'Sánchez', 'Hermano', '5566778800', 'MASJ880315HDFRRL07')
ON CONFLICT (user_id) DO NOTHING;

INSERT INTO beneficiaries (user_id, full_name, relationship, phone_number) VALUES
(4, 'María Fernanda Vargas Torres', 'Hija', '5544556611'),
(5, 'Luis Alberto Pérez Cruz', 'Hijo', '5555667711'),
(6, 'Ana Laura Martínez López', 'Hija', '5566778811')
ON CONFLICT (user_id) DO NOTHING;

-- =============================================================================
-- PERÍODOS DE CORTE (8 períodos: 2024-2025)
-- =============================================================================
INSERT INTO cut_periods (id, cut_number, period_start_date, period_end_date, status_id, created_by) VALUES
-- 2024
(1, 23, '2024-12-08', '2024-12-22', 5, 2),
(2, 24, '2024-12-23', '2025-01-07', 5, 2),
-- 2025 
(3, 1, '2025-01-08', '2025-01-22', 5, 2),
(4, 2, '2025-01-23', '2025-02-07', 5, 2),
(5, 3, '2025-02-08', '2025-02-22', 5, 2),
(6, 4, '2025-02-23', '2025-03-07', 2, 2),
(7, 5, '2025-03-08', '2025-03-22', 2, 2),
(8, 6, '2025-03-23', '2025-04-07', 2, 2)
ON CONFLICT (id) DO NOTHING;

-- =============================================================================
-- CONFIGURACIONES DEL SISTEMA
-- =============================================================================
INSERT INTO system_configurations (config_key, config_value, description, config_type_id, updated_by) VALUES
('max_loan_amount', '1000000', 'Monto máximo de préstamo permitido', 2, 2),
('default_interest_rate', '2.5', 'Tasa de interés por defecto', 2, 2),
('default_commission_rate', '2.5', 'Tasa de comisión por defecto', 2, 2),
('system_name', 'Credinet', 'Nombre del sistema', 1, 2),
('maintenance_mode', 'false', 'Modo de mantenimiento', 3, 2),
('payment_system', 'BIWEEKLY_v2.0', 'Sistema de pagos quincenal v2.0', 1, 2),
('perfect_dates_enabled', 'true', 'Fechas perfectas (día 15 y último)', 3, 2),
('cut_days', '8,23', 'Días de corte exactos', 1, 2),
('payment_days', '15,LAST', 'Días de pago permitidos', 1, 2),
('db_version', '2.0.0', 'Versión de base de datos', 1, 2)
ON CONFLICT (config_key) DO NOTHING;

-- =============================================================================
-- AJUSTAR SECUENCIAS (Optimización FIX-008)
-- =============================================================================
SELECT setval('users_id_seq', COALESCE((SELECT MAX(id) FROM users), 0) + 1, false);
SELECT setval('roles_id_seq', COALESCE((SELECT MAX(id) FROM roles), 0) + 1, false);
SELECT setval('loans_id_seq', COALESCE((SELECT MAX(id) FROM loans), 0) + 1, false);
SELECT setval('contracts_id_seq', COALESCE((SELECT MAX(id) FROM contracts), 0) + 1, false);
SELECT setval('payments_id_seq', COALESCE((SELECT MAX(id) FROM payments), 0) + 1, false);
SELECT setval('cut_periods_id_seq', COALESCE((SELECT MAX(id) FROM cut_periods), 0) + 1, false);
SELECT setval('associate_profiles_id_seq', COALESCE((SELECT MAX(id) FROM associate_profiles), 0) + 1, false);
SELECT setval('client_documents_id_seq', COALESCE((SELECT MAX(id) FROM client_documents), 0) + 1, false);
SELECT setval('addresses_id_seq', COALESCE((SELECT MAX(id) FROM addresses), 0) + 1, false);
SELECT setval('guarantors_id_seq', COALESCE((SELECT MAX(id) FROM guarantors), 0) + 1, false);
SELECT setval('beneficiaries_id_seq', COALESCE((SELECT MAX(id) FROM beneficiaries), 0) + 1, false);

-- =============================================================================
-- FIN MÓDULO 09
-- =============================================================================
