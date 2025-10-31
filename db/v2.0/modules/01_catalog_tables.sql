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
