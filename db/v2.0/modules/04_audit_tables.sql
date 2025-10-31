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
