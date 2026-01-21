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
    v_remaining DECIMAL(12,2);
    v_pending_status_id INTEGER;
BEGIN
    -- Obtener ID del estado PENDING
    SELECT id INTO v_pending_status_id FROM payment_statuses WHERE name = 'PENDING';
    
    -- ✅ CORREGIDO: Sumar expected_amount de los pagos PENDIENTES
    -- Esto da el saldo real que debe liquidar el cliente (capital + interés + comisión completos)
    SELECT COALESCE(SUM(expected_amount), 0) INTO v_remaining
    FROM payments
    WHERE loan_id = p_loan_id
      AND status_id = v_pending_status_id;  -- Solo pagos PENDIENTES
    
    -- Validar que el préstamo exista
    IF NOT EXISTS (SELECT 1 FROM loans WHERE id = p_loan_id) THEN
        RAISE EXCEPTION 'Préstamo con ID % no encontrado', p_loan_id;
    END IF;
    
    -- No permitir saldo negativo
    IF v_remaining < 0 THEN
        v_remaining := 0;
    END IF;
    
    RETURN v_remaining;
END;
$$ LANGUAGE plpgsql
STABLE;

COMMENT ON FUNCTION calculate_loan_remaining_balance(INTEGER) IS 
'✅ v2.0.3: Calcula el saldo pendiente REAL de un préstamo sumando expected_amount de los pagos PENDIENTES. Incluye capital + interés + comisión completos de cada pago no realizado. NO usa amount - amount_paid que es incorrecto.';

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
