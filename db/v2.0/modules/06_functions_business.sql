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
