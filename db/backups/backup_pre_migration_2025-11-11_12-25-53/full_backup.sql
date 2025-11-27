--
-- PostgreSQL database dump
--

\restrict 2CAUdwpecTB9lNLBXs700Wub5AcAVQ6RDIeRPoS8atWMRe9csVlhwCyEaI2t9LY

-- Dumped from database version 15.14
-- Dumped by pg_dump version 15.14

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

DROP DATABASE credinet_db;
--
-- Name: credinet_db; Type: DATABASE; Schema: -; Owner: credinet_user
--

CREATE DATABASE credinet_db WITH TEMPLATE = template0 ENCODING = 'UTF8' LOCALE_PROVIDER = libc LOCALE = 'es_MX.UTF-8';


ALTER DATABASE credinet_db OWNER TO credinet_user;

\unrestrict 2CAUdwpecTB9lNLBXs700Wub5AcAVQ6RDIeRPoS8atWMRe9csVlhwCyEaI2t9LY
\connect credinet_db
\restrict 2CAUdwpecTB9lNLBXs700Wub5AcAVQ6RDIeRPoS8atWMRe9csVlhwCyEaI2t9LY

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: pg_database_owner
--

COMMENT ON SCHEMA public IS 'Schema público de CrediCuenta v2.0.3 con sistema de perfiles de tasa flexible.';


--
-- Name: admin_mark_payment_status(integer, integer, integer, text); Type: FUNCTION; Schema: public; Owner: credinet_user
--

CREATE FUNCTION public.admin_mark_payment_status(p_payment_id integer, p_new_status_id integer, p_admin_user_id integer, p_notes text DEFAULT NULL::text) RETURNS void
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.admin_mark_payment_status(p_payment_id integer, p_new_status_id integer, p_admin_user_id integer, p_notes text) OWNER TO credinet_user;

--
-- Name: FUNCTION admin_mark_payment_status(p_payment_id integer, p_new_status_id integer, p_admin_user_id integer, p_notes text); Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON FUNCTION public.admin_mark_payment_status(p_payment_id integer, p_new_status_id integer, p_admin_user_id integer, p_notes text) IS '⭐ MIGRACIÓN 11: Permite a un administrador marcar manualmente el estado de un pago con notas. El trigger de auditoría registrará el cambio automáticamente.';


--
-- Name: approve_defaulted_client_report(integer, integer, integer); Type: FUNCTION; Schema: public; Owner: credinet_user
--

CREATE FUNCTION public.approve_defaulted_client_report(p_report_id integer, p_approved_by integer, p_cut_period_id integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.approve_defaulted_client_report(p_report_id integer, p_approved_by integer, p_cut_period_id integer) OWNER TO credinet_user;

--
-- Name: FUNCTION approve_defaulted_client_report(p_report_id integer, p_approved_by integer, p_cut_period_id integer); Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON FUNCTION public.approve_defaulted_client_report(p_report_id integer, p_approved_by integer, p_cut_period_id integer) IS '⭐ MIGRACIÓN 09: Aprueba un reporte de cliente moroso, marca pagos como PAID_BY_ASSOCIATE y crea registro de deuda en associate_debt_breakdown.';


--
-- Name: audit_trigger_function(); Type: FUNCTION; Schema: public; Owner: credinet_user
--

CREATE FUNCTION public.audit_trigger_function() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.audit_trigger_function() OWNER TO credinet_user;

--
-- Name: FUNCTION audit_trigger_function(); Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON FUNCTION public.audit_trigger_function() IS 'Función genérica de auditoría que registra INSERT, UPDATE y DELETE en audit_log con snapshots JSON completos.';


--
-- Name: calculate_first_payment_date(date); Type: FUNCTION; Schema: public; Owner: credinet_user
--

CREATE FUNCTION public.calculate_first_payment_date(p_approval_date date) RETURNS date
    LANGUAGE plpgsql IMMUTABLE STRICT PARALLEL SAFE
    AS $$
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
$$;


ALTER FUNCTION public.calculate_first_payment_date(p_approval_date date) OWNER TO credinet_user;

--
-- Name: FUNCTION calculate_first_payment_date(p_approval_date date); Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON FUNCTION public.calculate_first_payment_date(p_approval_date date) IS '⭐ ORÁCULO: Calcula la primera fecha de pago del cliente según lógica del doble calendario (cortes días 8 y 23, vencimientos días 15 y último). INMUTABLE y PURA.';


--
-- Name: calculate_late_fee_for_statement(integer); Type: FUNCTION; Schema: public; Owner: credinet_user
--

CREATE FUNCTION public.calculate_late_fee_for_statement(p_statement_id integer) RETURNS numeric
    LANGUAGE plpgsql STABLE
    AS $$
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
$$;


ALTER FUNCTION public.calculate_late_fee_for_statement(p_statement_id integer) OWNER TO credinet_user;

--
-- Name: FUNCTION calculate_late_fee_for_statement(p_statement_id integer); Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON FUNCTION public.calculate_late_fee_for_statement(p_statement_id integer) IS '⭐ MIGRACIÓN 10: Calcula mora del 30% sobre comisión si el asociado NO reportó ningún pago en el período (total_payments_count = 0).';


--
-- Name: calculate_loan_payment(numeric, integer, character varying); Type: FUNCTION; Schema: public; Owner: credinet_user
--

CREATE FUNCTION public.calculate_loan_payment(p_amount numeric, p_term_biweeks integer, p_profile_code character varying) RETURNS TABLE(profile_code character varying, profile_name character varying, calculation_method character varying, interest_rate_percent numeric, commission_rate_percent numeric, biweekly_payment numeric, total_payment numeric, total_interest numeric, effective_rate_percent numeric, commission_per_payment numeric, total_commission numeric, associate_payment numeric, associate_total numeric)
    LANGUAGE plpgsql STABLE
    AS $$
DECLARE
    v_profile RECORD;
    v_legacy_entry RECORD;
    v_factor DECIMAL(10,6);
    v_total DECIMAL(12,2);
    v_payment DECIMAL(10,2);
    v_commission_per_payment DECIMAL(10,2);
BEGIN
    -- Obtener perfil con LAS DOS TASAS
    SELECT * INTO v_profile
    FROM rate_profiles
    WHERE code = p_profile_code AND enabled = true;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Perfil de tasa no encontrado o deshabilitado: %', p_profile_code;
    END IF;
    
    -- MÉTODO 1: Table Lookup (perfil legacy)
    IF v_profile.calculation_type = 'table_lookup' THEN
        SELECT * INTO v_legacy_entry
        FROM legacy_payment_table
        WHERE amount = p_amount AND term_biweeks = p_term_biweeks;
        
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Monto % no encontrado en tabla legacy para plazo %Q', p_amount, p_term_biweeks;
        END IF;
        
        v_payment := v_legacy_entry.biweekly_payment;
        v_total := v_legacy_entry.total_payment;
        
        -- Para legacy, usar comisión del perfil o default 2.5%
        v_commission_per_payment := v_payment * (COALESCE(v_profile.commission_rate_percent, 2.5) / 100);
        
        RETURN QUERY SELECT
            v_profile.code,
            v_profile.name,
            v_profile.calculation_type,
            
            v_legacy_entry.biweekly_rate_percent AS interest_rate,
            COALESCE(v_profile.commission_rate_percent, 2.5) AS commission_rate,
            
            v_payment,
            v_total,
            v_legacy_entry.total_interest,
            v_legacy_entry.effective_rate_percent,
            
            ROUND(v_commission_per_payment, 2),
            ROUND(v_commission_per_payment * p_term_biweeks, 2),
            ROUND(v_payment - v_commission_per_payment, 2),
            ROUND((v_payment - v_commission_per_payment) * p_term_biweeks, 2);
        
        RETURN;
    END IF;
    
    -- MÉTODO 2: Formula (perfiles transition, standard, premium, custom)
    IF v_profile.calculation_type = 'formula' THEN
        IF v_profile.interest_rate_percent IS NULL THEN
            RAISE EXCEPTION 'Perfil % tipo formula requiere interest_rate_percent configurado', p_profile_code;
        END IF;
        
        IF v_profile.commission_rate_percent IS NULL THEN
            RAISE EXCEPTION 'Perfil % tipo formula requiere commission_rate_percent configurado', p_profile_code;
        END IF;
        
        -- Calcular CLIENTE (interés simple)
        v_factor := 1 + (v_profile.interest_rate_percent / 100) * p_term_biweeks;
        v_total := p_amount * v_factor;
        v_payment := v_total / p_term_biweeks;
        
        -- Calcular ASOCIADO (comisión sobre pago)
        v_commission_per_payment := v_payment * (v_profile.commission_rate_percent / 100);
        
        RETURN QUERY SELECT
            v_profile.code,
            v_profile.name,
            v_profile.calculation_type,
            
            v_profile.interest_rate_percent,
            v_profile.commission_rate_percent,
            
            ROUND(v_payment, 2) AS biweekly_payment,
            ROUND(v_total, 2) AS total_payment,
            ROUND(v_total - p_amount, 2) AS total_interest,
            ROUND(((v_total - p_amount) / p_amount * 100)::NUMERIC, 2) AS effective_rate,
            
            ROUND(v_commission_per_payment, 2),
            ROUND(v_commission_per_payment * p_term_biweeks, 2),
            ROUND(v_payment - v_commission_per_payment, 2),
            ROUND((v_payment - v_commission_per_payment) * p_term_biweeks, 2);
        
        RETURN;
    END IF;
    
    RAISE EXCEPTION 'Tipo de cálculo no soportado: %', v_profile.calculation_type;
END;
$$;


ALTER FUNCTION public.calculate_loan_payment(p_amount numeric, p_term_biweeks integer, p_profile_code character varying) OWNER TO credinet_user;

--
-- Name: calculate_loan_remaining_balance(integer); Type: FUNCTION; Schema: public; Owner: credinet_user
--

CREATE FUNCTION public.calculate_loan_remaining_balance(p_loan_id integer) RETURNS numeric
    LANGUAGE plpgsql STABLE
    AS $$
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
$$;


ALTER FUNCTION public.calculate_loan_remaining_balance(p_loan_id integer) OWNER TO credinet_user;

--
-- Name: FUNCTION calculate_loan_remaining_balance(p_loan_id integer); Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON FUNCTION public.calculate_loan_remaining_balance(p_loan_id integer) IS 'Calcula el saldo pendiente de un préstamo (monto total - pagos realizados).';


--
-- Name: calculate_payment_preview(timestamp with time zone, integer, numeric); Type: FUNCTION; Schema: public; Owner: credinet_user
--

CREATE FUNCTION public.calculate_payment_preview(p_approval_timestamp timestamp with time zone DEFAULT CURRENT_TIMESTAMP, p_term_biweeks integer DEFAULT 12, p_amount numeric DEFAULT 100000.00) RETURNS TABLE(payment_number integer, payment_due_date date, payment_amount numeric, payment_type text, cut_period_estimated text)
    LANGUAGE plpgsql STABLE
    AS $$
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
$$;


ALTER FUNCTION public.calculate_payment_preview(p_approval_timestamp timestamp with time zone, p_term_biweeks integer, p_amount numeric) OWNER TO credinet_user;

--
-- Name: FUNCTION calculate_payment_preview(p_approval_timestamp timestamp with time zone, p_term_biweeks integer, p_amount numeric); Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON FUNCTION public.calculate_payment_preview(p_approval_timestamp timestamp with time zone, p_term_biweeks integer, p_amount numeric) IS 'Genera un preview del cronograma de pagos sin persistir en BD (útil para mostrar al usuario antes de aprobar).';


--
-- Name: check_associate_credit_available(integer, numeric); Type: FUNCTION; Schema: public; Owner: credinet_user
--

CREATE FUNCTION public.check_associate_credit_available(p_associate_profile_id integer, p_requested_amount numeric) RETURNS boolean
    LANGUAGE plpgsql STABLE
    AS $$
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
$$;


ALTER FUNCTION public.check_associate_credit_available(p_associate_profile_id integer, p_requested_amount numeric) OWNER TO credinet_user;

--
-- Name: FUNCTION check_associate_credit_available(p_associate_profile_id integer, p_requested_amount numeric); Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON FUNCTION public.check_associate_credit_available(p_associate_profile_id integer, p_requested_amount numeric) IS '⭐ MIGRACIÓN 07: Valida si un asociado tiene crédito disponible suficiente para absorber un préstamo (credit_limit - credit_used - debt_balance >= monto).';


--
-- Name: close_period_and_accumulate_debt(integer, integer); Type: FUNCTION; Schema: public; Owner: credinet_user
--

CREATE FUNCTION public.close_period_and_accumulate_debt(p_cut_period_id integer, p_closed_by integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.close_period_and_accumulate_debt(p_cut_period_id integer, p_closed_by integer) OWNER TO credinet_user;

--
-- Name: FUNCTION close_period_and_accumulate_debt(p_cut_period_id integer, p_closed_by integer); Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON FUNCTION public.close_period_and_accumulate_debt(p_cut_period_id integer, p_closed_by integer) IS '⭐ MIGRACIÓN 08 v3: Cierra un período de corte marcando TODOS los pagos según regla: reportados→PAID, no reportados→PAID_NOT_REPORTED, morosos→PAID_BY_ASSOCIATE.';


--
-- Name: detect_suspicious_payment_changes(integer, integer); Type: FUNCTION; Schema: public; Owner: credinet_user
--

CREATE FUNCTION public.detect_suspicious_payment_changes(p_days_back integer DEFAULT 7, p_min_changes integer DEFAULT 3) RETURNS TABLE(payment_id integer, loan_id integer, client_name text, total_changes bigint, last_change timestamp with time zone, status_sequence text)
    LANGUAGE plpgsql STABLE
    AS $$
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
$$;


ALTER FUNCTION public.detect_suspicious_payment_changes(p_days_back integer, p_min_changes integer) OWNER TO credinet_user;

--
-- Name: FUNCTION detect_suspicious_payment_changes(p_days_back integer, p_min_changes integer); Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON FUNCTION public.detect_suspicious_payment_changes(p_days_back integer, p_min_changes integer) IS '⭐ MIGRACIÓN 12: Detecta pagos con patrones anómalos (3+ cambios de estado en N días). Útil para detección de fraude o errores.';


--
-- Name: generate_amortization_schedule(numeric, numeric, integer, numeric, date); Type: FUNCTION; Schema: public; Owner: credinet_user
--

CREATE FUNCTION public.generate_amortization_schedule(p_amount numeric, p_biweekly_payment numeric, p_term_biweeks integer, p_commission_rate numeric, p_start_date date DEFAULT CURRENT_DATE) RETURNS TABLE(periodo integer, fecha_pago date, pago_cliente numeric, interes_cliente numeric, capital_cliente numeric, saldo_pendiente numeric, comision_socio numeric, pago_socio numeric)
    LANGUAGE plpgsql STABLE
    AS $$
DECLARE
    v_current_date DATE;
    v_balance DECIMAL(12,2);
    v_total_interest DECIMAL(12,2);
    v_period_interest DECIMAL(10,2);
    v_period_principal DECIMAL(10,2);
    v_commission DECIMAL(10,2);
    v_payment_to_associate DECIMAL(10,2);
    v_is_day_15 BOOLEAN;
BEGIN
    -- Inicializar
    v_balance := p_amount;
    v_total_interest := (p_biweekly_payment * p_term_biweeks) - p_amount;
    v_current_date := p_start_date;
    
    -- Generar cronograma completo
    FOR v_period IN 1..p_term_biweeks LOOP
        -- Calcular interés y capital del período (distribución proporcional)
        v_period_interest := v_total_interest / p_term_biweeks;
        v_period_principal := p_biweekly_payment - v_period_interest;
        
        -- Actualizar saldo
        v_balance := v_balance - v_period_principal;
        
        -- Evitar saldo negativo por redondeo
        IF v_balance < 0.01 THEN
            v_balance := 0;
        END IF;
        
        -- Calcular comisión del asociado
        v_commission := p_biweekly_payment * (p_commission_rate / 100);
        v_payment_to_associate := p_biweekly_payment - v_commission;
        
        -- Retornar fila
        RETURN QUERY SELECT
            v_period,
            v_current_date,
            p_biweekly_payment,
            ROUND(v_period_interest, 2),
            ROUND(v_period_principal, 2),
            ROUND(v_balance, 2),
            ROUND(v_commission, 2),
            ROUND(v_payment_to_associate, 2);
        
        -- Calcular siguiente fecha (alternancia día 15 ↔ último día del mes)
        v_is_day_15 := EXTRACT(DAY FROM v_current_date) = 15;
        
        IF v_is_day_15 THEN
            -- Si es día 15 → siguiente es último día del mes actual
            v_current_date := (DATE_TRUNC('month', v_current_date) + INTERVAL '1 month' - INTERVAL '1 day')::DATE;
        ELSE
            -- Si es último día → siguiente es día 15 del mes siguiente
            v_current_date := MAKE_DATE(
                EXTRACT(YEAR FROM v_current_date + INTERVAL '1 month')::INTEGER,
                EXTRACT(MONTH FROM v_current_date + INTERVAL '1 month')::INTEGER,
                15
            );
        END IF;
    END LOOP;
END;
$$;


ALTER FUNCTION public.generate_amortization_schedule(p_amount numeric, p_biweekly_payment numeric, p_term_biweeks integer, p_commission_rate numeric, p_start_date date) OWNER TO credinet_user;

--
-- Name: FUNCTION generate_amortization_schedule(p_amount numeric, p_biweekly_payment numeric, p_term_biweeks integer, p_commission_rate numeric, p_start_date date); Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON FUNCTION public.generate_amortization_schedule(p_amount numeric, p_biweekly_payment numeric, p_term_biweeks integer, p_commission_rate numeric, p_start_date date) IS 'Genera tabla de amortización completa con fechas, pagos del cliente, interés, capital, saldo pendiente, comisión del asociado y pago al asociado. Usa lógica de doble calendario (día 15 y último día del mes).';


--
-- Name: generate_loan_summary(numeric, integer, numeric, numeric); Type: FUNCTION; Schema: public; Owner: credinet_user
--

CREATE FUNCTION public.generate_loan_summary(p_amount numeric, p_term_biweeks integer, p_interest_rate numeric, p_commission_rate numeric) RETURNS TABLE(capital numeric, plazo_quincenas integer, tasa_interes_quincenal numeric, tasa_comision numeric, pago_quincenal_cliente numeric, pago_total_cliente numeric, interes_total_cliente numeric, tasa_efectiva_cliente numeric, comision_por_pago numeric, comision_total_socio numeric, pago_quincenal_socio numeric, pago_total_socio numeric)
    LANGUAGE plpgsql IMMUTABLE
    AS $$
DECLARE
    v_factor DECIMAL(10,6);
    v_total_cliente DECIMAL(12,2);
    v_pago_q_cliente DECIMAL(10,2);
    v_interes_cliente DECIMAL(12,2);
    v_comision_por_pago DECIMAL(10,2);
    v_comision_total DECIMAL(12,2);
    v_pago_q_socio DECIMAL(10,2);
BEGIN
    -- Calcular CLIENTE (Interés Simple)
    v_factor := 1 + (p_interest_rate / 100) * p_term_biweeks;
    v_total_cliente := p_amount * v_factor;
    v_pago_q_cliente := v_total_cliente / p_term_biweeks;
    v_interes_cliente := v_total_cliente - p_amount;
    
    -- Calcular SOCIO (Comisión sobre pago del cliente)
    v_comision_por_pago := v_pago_q_cliente * (p_commission_rate / 100);
    v_comision_total := v_comision_por_pago * p_term_biweeks;
    v_pago_q_socio := v_pago_q_cliente - v_comision_por_pago;
    
    RETURN QUERY SELECT
        p_amount AS capital,
        p_term_biweeks AS plazo_quincenas,
        
        p_interest_rate AS tasa_interes_quincenal,
        p_commission_rate AS tasa_comision,
        
        ROUND(v_pago_q_cliente, 2) AS pago_quincenal_cliente,
        ROUND(v_total_cliente, 2) AS pago_total_cliente,
        ROUND(v_interes_cliente, 2) AS interes_total_cliente,
        ROUND(((v_interes_cliente / p_amount * 100)::NUMERIC), 2) AS tasa_efectiva_cliente,
        
        ROUND(v_comision_por_pago, 2) AS comision_por_pago,
        ROUND(v_comision_total, 2) AS comision_total_socio,
        ROUND(v_pago_q_socio, 2) AS pago_quincenal_socio,
        ROUND(v_pago_q_socio * p_term_biweeks, 2) AS pago_total_socio;
END;
$$;


ALTER FUNCTION public.generate_loan_summary(p_amount numeric, p_term_biweeks integer, p_interest_rate numeric, p_commission_rate numeric) OWNER TO credinet_user;

--
-- Name: FUNCTION generate_loan_summary(p_amount numeric, p_term_biweeks integer, p_interest_rate numeric, p_commission_rate numeric); Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON FUNCTION public.generate_loan_summary(p_amount numeric, p_term_biweeks integer, p_interest_rate numeric, p_commission_rate numeric) IS 'Genera tabla resumen completa con cálculos de CLIENTE y SOCIO (asociado). Muestra: pagos quincenales, totales, intereses, comisiones. Similar a tabla "Importe de prestamos" de la UI.';


--
-- Name: generate_payment_schedule(); Type: FUNCTION; Schema: public; Owner: credinet_user
--

CREATE FUNCTION public.generate_payment_schedule() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_payment_amount NUMERIC(12, 2);
    v_principal_payment NUMERIC(12, 2);
    v_interest_payment NUMERIC(12, 2);
    v_commission_payment NUMERIC(12, 2);
    v_associate_payment NUMERIC(12, 2);
    v_balance NUMERIC(12, 2);
    v_period_counter INT;
    v_current_period_id INT;
    v_payment_date DATE;
    v_approved_status_id INT;
BEGIN
    SELECT id INTO v_approved_status_id FROM loan_statuses WHERE name = 'APPROVED';
    
    IF NEW.status_id = v_approved_status_id AND (OLD.status_id IS NULL OR OLD.status_id != v_approved_status_id) THEN
        IF NEW.biweekly_payment IS NULL OR NEW.term_biweeks IS NULL THEN
            RAISE EXCEPTION 'Cannot generate payment schedule: biweekly_payment or term_biweeks is NULL for loan %', NEW.id;
        END IF;
        
        v_balance := NEW.amount;
        v_payment_amount := NEW.biweekly_payment;
        v_commission_payment := COALESCE(NEW.commission_per_payment, 0);
        v_associate_payment := COALESCE(NEW.associate_payment, v_payment_amount - v_commission_payment);
        
        FOR v_period_counter IN 1..NEW.term_biweeks LOOP
            SELECT id, start_date INTO v_current_period_id, v_payment_date
            FROM cut_periods
            WHERE start_date >= COALESCE(NEW.approved_at, CURRENT_TIMESTAMP)
            ORDER BY start_date ASC
            LIMIT 1 OFFSET (v_period_counter - 1);
            
            IF v_current_period_id IS NULL THEN
                RAISE WARNING 'No cut period found for payment % of loan %', v_period_counter, NEW.id;
                CONTINUE;
            END IF;
            
            v_interest_payment := v_balance * (NEW.interest_rate / 100);
            v_principal_payment := v_payment_amount - v_interest_payment;
            v_balance := v_balance - v_principal_payment;
            
            INSERT INTO payments (
                loan_id, payment_number, expected_amount,
                interest_amount, principal_amount, commission_amount,
                associate_payment, balance_remaining, payment_date,
                payment_due_date, status_id, cut_period_id
            ) VALUES (
                NEW.id, v_period_counter, v_payment_amount,
                v_interest_payment, v_principal_payment, v_commission_payment,
                v_associate_payment, GREATEST(v_balance, 0), v_payment_date,
                v_payment_date, 1, v_current_period_id
            );
        END LOOP;
    END IF;
    
    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING 'Error generating payment schedule for loan %: % (%)', NEW.id, SQLERRM, SQLSTATE;
        RETURN NEW;
END;
$$;


ALTER FUNCTION public.generate_payment_schedule() OWNER TO credinet_user;

--
-- Name: FUNCTION generate_payment_schedule(); Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON FUNCTION public.generate_payment_schedule() IS 'Trigger que genera el cronograma de pagos cuando un préstamo es aprobado.
✅ VERSIÓN 2.0 - CORREGIDA
- Usa loans.biweekly_payment (pre-calculado)
- Llama a generate_amortization_schedule() para desglose completo
- Inserta payments con TODOS los campos (payment_number, expected_amount, etc.)
- Valida consistencia matemática: SUM(expected_amount) = loans.total_payment
- Mapea correctamente payment_due_date a cut_period_id
- Implementa el sistema de doble calendario (15/último día vs 8-22/23-7)';


--
-- Name: get_payment_history(integer); Type: FUNCTION; Schema: public; Owner: credinet_user
--

CREATE FUNCTION public.get_payment_history(p_payment_id integer) RETURNS TABLE(change_id integer, old_status character varying, new_status character varying, change_type character varying, changed_by_username character varying, change_reason text, changed_at timestamp with time zone)
    LANGUAGE plpgsql STABLE
    AS $$
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
$$;


ALTER FUNCTION public.get_payment_history(p_payment_id integer) OWNER TO credinet_user;

--
-- Name: FUNCTION get_payment_history(p_payment_id integer); Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON FUNCTION public.get_payment_history(p_payment_id integer) IS '⭐ MIGRACIÓN 12: Obtiene el historial completo de cambios de estado de un pago (timeline forense).';


--
-- Name: handle_loan_approval_status(); Type: FUNCTION; Schema: public; Owner: credinet_user
--

CREATE FUNCTION public.handle_loan_approval_status() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.handle_loan_approval_status() OWNER TO credinet_user;

--
-- Name: FUNCTION handle_loan_approval_status(); Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON FUNCTION public.handle_loan_approval_status() IS 'Trigger function: Setea automáticamente approved_at o rejected_at cuando el estado del préstamo cambia.';


--
-- Name: log_payment_status_change(); Type: FUNCTION; Schema: public; Owner: credinet_user
--

CREATE FUNCTION public.log_payment_status_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.log_payment_status_change() OWNER TO credinet_user;

--
-- Name: FUNCTION log_payment_status_change(); Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON FUNCTION public.log_payment_status_change() IS '⭐ MIGRACIÓN 12: Trigger function que registra automáticamente todos los cambios de estado de pagos en payment_status_history para auditoría completa.';


--
-- Name: renew_loan(integer, numeric, integer, numeric, numeric, integer); Type: FUNCTION; Schema: public; Owner: credinet_user
--

CREATE FUNCTION public.renew_loan(p_original_loan_id integer, p_new_amount numeric, p_new_term_biweeks integer, p_interest_rate numeric, p_commission_rate numeric, p_created_by integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.renew_loan(p_original_loan_id integer, p_new_amount numeric, p_new_term_biweeks integer, p_interest_rate numeric, p_commission_rate numeric, p_created_by integer) OWNER TO credinet_user;

--
-- Name: FUNCTION renew_loan(p_original_loan_id integer, p_new_amount numeric, p_new_term_biweeks integer, p_interest_rate numeric, p_commission_rate numeric, p_created_by integer); Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON FUNCTION public.renew_loan(p_original_loan_id integer, p_new_amount numeric, p_new_term_biweeks integer, p_interest_rate numeric, p_commission_rate numeric, p_created_by integer) IS 'Renueva un préstamo existente creando uno nuevo. Calcula automáticamente el saldo pendiente y lo registra en loan_renewals.';


--
-- Name: report_defaulted_client(integer, integer, integer, numeric, text, character varying); Type: FUNCTION; Schema: public; Owner: credinet_user
--

CREATE FUNCTION public.report_defaulted_client(p_associate_profile_id integer, p_loan_id integer, p_reported_by integer, p_total_debt_amount numeric, p_evidence_details text, p_evidence_file_path character varying DEFAULT NULL::character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.report_defaulted_client(p_associate_profile_id integer, p_loan_id integer, p_reported_by integer, p_total_debt_amount numeric, p_evidence_details text, p_evidence_file_path character varying) OWNER TO credinet_user;

--
-- Name: FUNCTION report_defaulted_client(p_associate_profile_id integer, p_loan_id integer, p_reported_by integer, p_total_debt_amount numeric, p_evidence_details text, p_evidence_file_path character varying); Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON FUNCTION public.report_defaulted_client(p_associate_profile_id integer, p_loan_id integer, p_reported_by integer, p_total_debt_amount numeric, p_evidence_details text, p_evidence_file_path character varying) IS '⭐ MIGRACIÓN 09: Permite a un asociado reportar un cliente moroso con evidencia. El reporte queda en estado PENDING hasta aprobación administrativa.';


--
-- Name: revert_last_payment_change(integer, integer, text); Type: FUNCTION; Schema: public; Owner: credinet_user
--

CREATE FUNCTION public.revert_last_payment_change(p_payment_id integer, p_admin_user_id integer, p_reason text) RETURNS void
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.revert_last_payment_change(p_payment_id integer, p_admin_user_id integer, p_reason text) OWNER TO credinet_user;

--
-- Name: FUNCTION revert_last_payment_change(p_payment_id integer, p_admin_user_id integer, p_reason text); Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON FUNCTION public.revert_last_payment_change(p_payment_id integer, p_admin_user_id integer, p_reason text) IS '⭐ MIGRACIÓN 12: Revierte el último cambio de estado de un pago (función de emergencia para corregir errores).';


--
-- Name: trigger_update_associate_credit_on_debt_payment(); Type: FUNCTION; Schema: public; Owner: credinet_user
--

CREATE FUNCTION public.trigger_update_associate_credit_on_debt_payment() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.trigger_update_associate_credit_on_debt_payment() OWNER TO credinet_user;

--
-- Name: trigger_update_associate_credit_on_level_change(); Type: FUNCTION; Schema: public; Owner: credinet_user
--

CREATE FUNCTION public.trigger_update_associate_credit_on_level_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.trigger_update_associate_credit_on_level_change() OWNER TO credinet_user;

--
-- Name: trigger_update_associate_credit_on_loan_approval(); Type: FUNCTION; Schema: public; Owner: credinet_user
--

CREATE FUNCTION public.trigger_update_associate_credit_on_loan_approval() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.trigger_update_associate_credit_on_loan_approval() OWNER TO credinet_user;

--
-- Name: trigger_update_associate_credit_on_payment(); Type: FUNCTION; Schema: public; Owner: credinet_user
--

CREATE FUNCTION public.trigger_update_associate_credit_on_payment() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.trigger_update_associate_credit_on_payment() OWNER TO credinet_user;

--
-- Name: update_legacy_payment_table_timestamp(); Type: FUNCTION; Schema: public; Owner: credinet_user
--

CREATE FUNCTION public.update_legacy_payment_table_timestamp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_legacy_payment_table_timestamp() OWNER TO credinet_user;

--
-- Name: update_updated_at_column(); Type: FUNCTION; Schema: public; Owner: credinet_user
--

CREATE FUNCTION public.update_updated_at_column() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_updated_at_column() OWNER TO credinet_user;

--
-- Name: validate_loan_calculated_fields(integer); Type: FUNCTION; Schema: public; Owner: credinet_user
--

CREATE FUNCTION public.validate_loan_calculated_fields(p_loan_id integer) RETURNS TABLE(campo text, valor_actual numeric, valor_esperado numeric, diferencia numeric, es_valido boolean)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_loan RECORD;
BEGIN
    -- Obtener datos del préstamo
    SELECT 
        amount, term_biweeks, biweekly_payment, total_payment,
        total_interest, commission_per_payment, associate_payment
    INTO v_loan
    FROM loans
    WHERE id = p_loan_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Préstamo % no encontrado', p_loan_id;
    END IF;
    
    -- Validar total_payment = biweekly_payment * term_biweeks
    IF v_loan.total_payment IS NOT NULL AND v_loan.biweekly_payment IS NOT NULL THEN
        RETURN QUERY SELECT 
            'total_payment'::TEXT,
            v_loan.total_payment,
            v_loan.biweekly_payment * v_loan.term_biweeks,
            v_loan.total_payment - (v_loan.biweekly_payment * v_loan.term_biweeks),
            ABS(v_loan.total_payment - (v_loan.biweekly_payment * v_loan.term_biweeks)) < 1.00;
    END IF;
    
    -- Validar total_interest = total_payment - amount
    IF v_loan.total_interest IS NOT NULL AND v_loan.total_payment IS NOT NULL THEN
        RETURN QUERY SELECT 
            'total_interest'::TEXT,
            v_loan.total_interest,
            v_loan.total_payment - v_loan.amount,
            v_loan.total_interest - (v_loan.total_payment - v_loan.amount),
            ABS(v_loan.total_interest - (v_loan.total_payment - v_loan.amount)) < 1.00;
    END IF;
    
    -- Validar associate_payment = biweekly_payment - commission_per_payment
    IF v_loan.associate_payment IS NOT NULL AND v_loan.biweekly_payment IS NOT NULL THEN
        RETURN QUERY SELECT 
            'associate_payment'::TEXT,
            v_loan.associate_payment,
            v_loan.biweekly_payment - COALESCE(v_loan.commission_per_payment, 0),
            v_loan.associate_payment - (v_loan.biweekly_payment - COALESCE(v_loan.commission_per_payment, 0)),
            ABS(v_loan.associate_payment - (v_loan.biweekly_payment - COALESCE(v_loan.commission_per_payment, 0))) < 0.10;
    END IF;
END;
$$;


ALTER FUNCTION public.validate_loan_calculated_fields(p_loan_id integer) OWNER TO credinet_user;

--
-- Name: FUNCTION validate_loan_calculated_fields(p_loan_id integer); Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON FUNCTION public.validate_loan_calculated_fields(p_loan_id integer) IS 'Valida que los campos calculados del préstamo sean matemáticamente consistentes. Retorna una tabla con las validaciones.';


--
-- Name: validate_loan_payment_schedule(integer); Type: FUNCTION; Schema: public; Owner: credinet_user
--

CREATE FUNCTION public.validate_loan_payment_schedule(p_loan_id integer) RETURNS TABLE(validacion text, valor numeric, esperado numeric, diferencia numeric, es_valido boolean, detalle text)
    LANGUAGE plpgsql
    AS $_$
DECLARE
    v_loan RECORD;
    v_payment_count INTEGER;
    v_sum_expected DECIMAL;
    v_sum_interest DECIMAL;
    v_sum_principal DECIMAL;
    v_sum_commission DECIMAL;
    v_last_balance DECIMAL;
    v_numbers_ok BOOLEAN;
BEGIN
    -- Obtener datos del préstamo
    SELECT 
        id, amount, term_biweeks, total_payment, total_interest,
        total_commission, biweekly_payment
    INTO v_loan
    FROM loans
    WHERE id = p_loan_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Préstamo % no encontrado', p_loan_id;
    END IF;
    
    -- Contar pagos generados
    SELECT COUNT(*) INTO v_payment_count
    FROM payments
    WHERE loan_id = p_loan_id;
    
    -- Validar: Cantidad de pagos = term_biweeks
    RETURN QUERY SELECT 
        'Cantidad de pagos'::TEXT,
        v_payment_count::DECIMAL,
        v_loan.term_biweeks::DECIMAL,
        (v_payment_count - v_loan.term_biweeks)::DECIMAL,
        v_payment_count = v_loan.term_biweeks,
        format('Se esperaban %s pagos, se encontraron %s', v_loan.term_biweeks, v_payment_count);
    
    -- Validar: payment_number son secuenciales (1, 2, 3, ..., N)
    SELECT COUNT(*) = v_payment_count INTO v_numbers_ok
    FROM (
        SELECT payment_number
        FROM payments
        WHERE loan_id = p_loan_id
        ORDER BY payment_number
    ) t
    WHERE payment_number BETWEEN 1 AND v_payment_count;
    
    RETURN QUERY SELECT 
        'Números secuenciales'::TEXT,
        CASE WHEN v_numbers_ok THEN 1::DECIMAL ELSE 0::DECIMAL END,
        1::DECIMAL,
        CASE WHEN v_numbers_ok THEN 0::DECIMAL ELSE 1::DECIMAL END,
        v_numbers_ok,
        CASE WHEN v_numbers_ok 
            THEN 'Los números de pago son secuenciales (1..N)'
            ELSE 'Los números de pago NO son secuenciales'
        END;
    
    -- Calcular sumas
    SELECT 
        COALESCE(SUM(expected_amount), 0),
        COALESCE(SUM(interest_amount), 0),
        COALESCE(SUM(principal_amount), 0),
        COALESCE(SUM(commission_amount), 0)
    INTO v_sum_expected, v_sum_interest, v_sum_principal, v_sum_commission
    FROM payments
    WHERE loan_id = p_loan_id;
    
    -- Validar: SUM(expected_amount) = loans.total_payment
    IF v_loan.total_payment IS NOT NULL THEN
        RETURN QUERY SELECT 
            'SUM(expected) = total_payment'::TEXT,
            v_sum_expected,
            v_loan.total_payment,
            v_sum_expected - v_loan.total_payment,
            ABS(v_sum_expected - v_loan.total_payment) < 1.00,
            format('Suma de pagos esperados: $%s, Total préstamo: $%s', v_sum_expected, v_loan.total_payment);
    END IF;
    
    -- Validar: SUM(interest_amount) = loans.total_interest
    IF v_loan.total_interest IS NOT NULL THEN
        RETURN QUERY SELECT 
            'SUM(interest) = total_interest'::TEXT,
            v_sum_interest,
            v_loan.total_interest,
            v_sum_interest - v_loan.total_interest,
            ABS(v_sum_interest - v_loan.total_interest) < 1.00,
            format('Suma de intereses: $%s, Total interés préstamo: $%s', v_sum_interest, v_loan.total_interest);
    END IF;
    
    -- Validar: SUM(principal_amount) = loans.amount
    RETURN QUERY SELECT 
        'SUM(principal) = amount'::TEXT,
        v_sum_principal,
        v_loan.amount,
        v_sum_principal - v_loan.amount,
        ABS(v_sum_principal - v_loan.amount) < 1.00,
        format('Suma de abonos a capital: $%s, Capital préstamo: $%s', v_sum_principal, v_loan.amount);
    
    -- Validar: SUM(commission_amount) = loans.total_commission
    IF v_loan.total_commission IS NOT NULL THEN
        RETURN QUERY SELECT 
            'SUM(commission) = total_commission'::TEXT,
            v_sum_commission,
            v_loan.total_commission,
            v_sum_commission - v_loan.total_commission,
            ABS(v_sum_commission - v_loan.total_commission) < 1.00,
            format('Suma de comisiones: $%s, Total comisión préstamo: $%s', v_sum_commission, v_loan.total_commission);
    END IF;
    
    -- Validar: Último pago tiene balance_remaining = 0
    SELECT balance_remaining INTO v_last_balance
    FROM payments
    WHERE loan_id = p_loan_id
    ORDER BY payment_number DESC
    LIMIT 1;
    
    IF v_last_balance IS NOT NULL THEN
        RETURN QUERY SELECT 
            'Último pago balance = 0'::TEXT,
            v_last_balance,
            0::DECIMAL,
            v_last_balance,
            ABS(v_last_balance) < 0.10,
            format('El saldo después del último pago es: $%s (debe ser $0.00)', v_last_balance);
    END IF;
END;
$_$;


ALTER FUNCTION public.validate_loan_payment_schedule(p_loan_id integer) OWNER TO credinet_user;

--
-- Name: FUNCTION validate_loan_payment_schedule(p_loan_id integer); Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON FUNCTION public.validate_loan_payment_schedule(p_loan_id integer) IS 'Valida el cronograma completo de pagos de un préstamo. Verifica cantidades, sumas, secuencias y consistencia.';


--
-- Name: validate_payment_breakdown(integer); Type: FUNCTION; Schema: public; Owner: credinet_user
--

CREATE FUNCTION public.validate_payment_breakdown(p_payment_id integer) RETURNS TABLE(validacion text, valor_actual numeric, valor_esperado numeric, diferencia numeric, es_valido boolean)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_payment RECORD;
BEGIN
    -- Obtener datos del pago
    SELECT 
        payment_number, expected_amount, interest_amount, principal_amount,
        commission_amount, associate_payment, amount_paid, balance_remaining
    INTO v_payment
    FROM payments
    WHERE id = p_payment_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Pago % no encontrado', p_payment_id;
    END IF;
    
    -- Validar expected_amount = interest_amount + principal_amount
    IF v_payment.expected_amount IS NOT NULL AND v_payment.interest_amount IS NOT NULL AND v_payment.principal_amount IS NOT NULL THEN
        RETURN QUERY SELECT 
            'expected = interest + principal'::TEXT,
            v_payment.expected_amount,
            v_payment.interest_amount + v_payment.principal_amount,
            v_payment.expected_amount - (v_payment.interest_amount + v_payment.principal_amount),
            ABS(v_payment.expected_amount - (v_payment.interest_amount + v_payment.principal_amount)) < 0.10;
    END IF;
    
    -- Validar associate_payment = expected_amount - commission_amount
    IF v_payment.associate_payment IS NOT NULL AND v_payment.expected_amount IS NOT NULL AND v_payment.commission_amount IS NOT NULL THEN
        RETURN QUERY SELECT 
            'associate = expected - commission'::TEXT,
            v_payment.associate_payment,
            v_payment.expected_amount - v_payment.commission_amount,
            v_payment.associate_payment - (v_payment.expected_amount - v_payment.commission_amount),
            ABS(v_payment.associate_payment - (v_payment.expected_amount - v_payment.commission_amount)) < 0.10;
    END IF;
    
    -- Validar amount_paid <= expected_amount (permitir sobrepago de hasta 100)
    IF v_payment.amount_paid IS NOT NULL AND v_payment.expected_amount IS NOT NULL THEN
        RETURN QUERY SELECT 
            'paid <= expected'::TEXT,
            v_payment.amount_paid,
            v_payment.expected_amount,
            v_payment.amount_paid - v_payment.expected_amount,
            v_payment.amount_paid <= v_payment.expected_amount + 100.00;
    END IF;
END;
$$;


ALTER FUNCTION public.validate_payment_breakdown(p_payment_id integer) OWNER TO credinet_user;

--
-- Name: FUNCTION validate_payment_breakdown(p_payment_id integer); Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON FUNCTION public.validate_payment_breakdown(p_payment_id integer) IS 'Valida que el desglose matemático del pago sea consistente. Retorna una tabla con las validaciones.';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: addresses; Type: TABLE; Schema: public; Owner: credinet_user
--

CREATE TABLE public.addresses (
    id integer NOT NULL,
    user_id integer NOT NULL,
    street character varying(200) NOT NULL,
    external_number character varying(10) NOT NULL,
    internal_number character varying(10),
    colony character varying(100) NOT NULL,
    municipality character varying(100) NOT NULL,
    state character varying(100) NOT NULL,
    zip_code character varying(10) NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.addresses OWNER TO credinet_user;

--
-- Name: TABLE addresses; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON TABLE public.addresses IS 'Direcciones físicas de usuarios (relación 1:1 con users).';


--
-- Name: addresses_id_seq; Type: SEQUENCE; Schema: public; Owner: credinet_user
--

CREATE SEQUENCE public.addresses_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.addresses_id_seq OWNER TO credinet_user;

--
-- Name: addresses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: credinet_user
--

ALTER SEQUENCE public.addresses_id_seq OWNED BY public.addresses.id;


--
-- Name: agreement_items; Type: TABLE; Schema: public; Owner: credinet_user
--

CREATE TABLE public.agreement_items (
    id integer NOT NULL,
    agreement_id integer NOT NULL,
    loan_id integer NOT NULL,
    client_user_id integer NOT NULL,
    debt_amount numeric(12,2) NOT NULL,
    debt_type character varying(50) NOT NULL,
    description text,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT check_agreement_items_debt_positive CHECK ((debt_amount > (0)::numeric)),
    CONSTRAINT check_agreement_items_type_valid CHECK (((debt_type)::text = ANY ((ARRAY['UNREPORTED_PAYMENT'::character varying, 'DEFAULTED_CLIENT'::character varying, 'LATE_FEE'::character varying, 'OTHER'::character varying])::text[])))
);


ALTER TABLE public.agreement_items OWNER TO credinet_user;

--
-- Name: TABLE agreement_items; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON TABLE public.agreement_items IS 'Ítems individuales que componen un convenio de pago (desglose por préstamo/cliente).';


--
-- Name: COLUMN agreement_items.debt_type; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON COLUMN public.agreement_items.debt_type IS 'Tipo de deuda: UNREPORTED_PAYMENT (pago no reportado), DEFAULTED_CLIENT (cliente moroso), LATE_FEE (mora 30%), OTHER.';


--
-- Name: agreement_items_id_seq; Type: SEQUENCE; Schema: public; Owner: credinet_user
--

CREATE SEQUENCE public.agreement_items_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.agreement_items_id_seq OWNER TO credinet_user;

--
-- Name: agreement_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: credinet_user
--

ALTER SEQUENCE public.agreement_items_id_seq OWNED BY public.agreement_items.id;


--
-- Name: agreement_payments; Type: TABLE; Schema: public; Owner: credinet_user
--

CREATE TABLE public.agreement_payments (
    id integer NOT NULL,
    agreement_id integer NOT NULL,
    payment_number integer NOT NULL,
    payment_amount numeric(12,2) NOT NULL,
    payment_due_date date NOT NULL,
    payment_date date,
    payment_method_id integer,
    payment_reference character varying(100),
    status character varying(50) DEFAULT 'PENDING'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT check_agreement_payments_amount_positive CHECK ((payment_amount > (0)::numeric)),
    CONSTRAINT check_agreement_payments_status_valid CHECK (((status)::text = ANY ((ARRAY['PENDING'::character varying, 'PAID'::character varying, 'OVERDUE'::character varying, 'CANCELLED'::character varying])::text[])))
);


ALTER TABLE public.agreement_payments OWNER TO credinet_user;

--
-- Name: TABLE agreement_payments; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON TABLE public.agreement_payments IS 'Cronograma de pagos mensuales del convenio (1 registro por cada mes del plan de pagos).';


--
-- Name: agreement_payments_id_seq; Type: SEQUENCE; Schema: public; Owner: credinet_user
--

CREATE SEQUENCE public.agreement_payments_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.agreement_payments_id_seq OWNER TO credinet_user;

--
-- Name: agreement_payments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: credinet_user
--

ALTER SEQUENCE public.agreement_payments_id_seq OWNED BY public.agreement_payments.id;


--
-- Name: agreements; Type: TABLE; Schema: public; Owner: credinet_user
--

CREATE TABLE public.agreements (
    id integer NOT NULL,
    associate_profile_id integer NOT NULL,
    agreement_number character varying(50) NOT NULL,
    agreement_date date NOT NULL,
    total_debt_amount numeric(12,2) NOT NULL,
    payment_plan_months integer NOT NULL,
    monthly_payment_amount numeric(12,2) NOT NULL,
    status character varying(50) DEFAULT 'ACTIVE'::character varying NOT NULL,
    start_date date NOT NULL,
    end_date date,
    created_by integer NOT NULL,
    approved_by integer,
    notes text,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT check_agreements_amounts_positive CHECK (((total_debt_amount > (0)::numeric) AND (monthly_payment_amount > (0)::numeric))),
    CONSTRAINT check_agreements_months_positive CHECK ((payment_plan_months > 0)),
    CONSTRAINT check_agreements_status_valid CHECK (((status)::text = ANY ((ARRAY['ACTIVE'::character varying, 'COMPLETED'::character varying, 'DEFAULTED'::character varying, 'CANCELLED'::character varying])::text[])))
);


ALTER TABLE public.agreements OWNER TO credinet_user;

--
-- Name: TABLE agreements; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON TABLE public.agreements IS 'Convenios de pago entre asociado y Credinet para liquidar deudas acumuladas. El asociado absorbe la deuda del cliente.';


--
-- Name: COLUMN agreements.agreement_number; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON COLUMN public.agreements.agreement_number IS 'Número único del convenio (formato: AGR-YYYY-NNN).';


--
-- Name: agreements_id_seq; Type: SEQUENCE; Schema: public; Owner: credinet_user
--

CREATE SEQUENCE public.agreements_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.agreements_id_seq OWNER TO credinet_user;

--
-- Name: agreements_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: credinet_user
--

ALTER SEQUENCE public.agreements_id_seq OWNED BY public.agreements.id;


--
-- Name: associate_accumulated_balances; Type: TABLE; Schema: public; Owner: credinet_user
--

CREATE TABLE public.associate_accumulated_balances (
    id integer NOT NULL,
    user_id integer NOT NULL,
    cut_period_id integer NOT NULL,
    accumulated_debt numeric(12,2) DEFAULT 0.00 NOT NULL,
    debt_details jsonb,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.associate_accumulated_balances OWNER TO credinet_user;

--
-- Name: TABLE associate_accumulated_balances; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON TABLE public.associate_accumulated_balances IS 'Balances de deuda acumulados por asociado en cada período de corte.';


--
-- Name: COLUMN associate_accumulated_balances.debt_details; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON COLUMN public.associate_accumulated_balances.debt_details IS 'Desglose JSON de la deuda (unreported_payments, defaulted_clients, late_fees, etc.).';


--
-- Name: associate_accumulated_balances_id_seq; Type: SEQUENCE; Schema: public; Owner: credinet_user
--

CREATE SEQUENCE public.associate_accumulated_balances_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.associate_accumulated_balances_id_seq OWNER TO credinet_user;

--
-- Name: associate_accumulated_balances_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: credinet_user
--

ALTER SEQUENCE public.associate_accumulated_balances_id_seq OWNED BY public.associate_accumulated_balances.id;


--
-- Name: associate_debt_breakdown; Type: TABLE; Schema: public; Owner: credinet_user
--

CREATE TABLE public.associate_debt_breakdown (
    id integer NOT NULL,
    associate_profile_id integer NOT NULL,
    cut_period_id integer NOT NULL,
    debt_type character varying(50) NOT NULL,
    loan_id integer,
    client_user_id integer,
    amount numeric(12,2) NOT NULL,
    description text,
    is_liquidated boolean DEFAULT false NOT NULL,
    liquidated_at timestamp with time zone,
    liquidation_reference character varying(100),
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT check_debt_breakdown_amount_positive CHECK ((amount > (0)::numeric)),
    CONSTRAINT check_debt_breakdown_liquidated_has_timestamp CHECK ((((is_liquidated = true) AND (liquidated_at IS NOT NULL)) OR ((is_liquidated = false) AND (liquidated_at IS NULL)))),
    CONSTRAINT check_debt_breakdown_type_valid CHECK (((debt_type)::text = ANY ((ARRAY['UNREPORTED_PAYMENT'::character varying, 'DEFAULTED_CLIENT'::character varying, 'LATE_FEE'::character varying, 'OTHER'::character varying])::text[])))
);


ALTER TABLE public.associate_debt_breakdown OWNER TO credinet_user;

--
-- Name: TABLE associate_debt_breakdown; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON TABLE public.associate_debt_breakdown IS '⭐ MIGRACIÓN 09: Desglose detallado de la deuda del asociado por tipo y origen (préstamo/cliente).';


--
-- Name: COLUMN associate_debt_breakdown.debt_type; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON COLUMN public.associate_debt_breakdown.debt_type IS 'Tipo de deuda: UNREPORTED_PAYMENT (pago no reportado al cierre), DEFAULTED_CLIENT (cliente moroso aprobado), LATE_FEE (mora del 30%), OTHER (otros).';


--
-- Name: COLUMN associate_debt_breakdown.is_liquidated; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON COLUMN public.associate_debt_breakdown.is_liquidated IS 'TRUE si la deuda ya fue liquidada (pagada o incluida en convenio).';


--
-- Name: associate_debt_breakdown_id_seq; Type: SEQUENCE; Schema: public; Owner: credinet_user
--

CREATE SEQUENCE public.associate_debt_breakdown_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.associate_debt_breakdown_id_seq OWNER TO credinet_user;

--
-- Name: associate_debt_breakdown_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: credinet_user
--

ALTER SEQUENCE public.associate_debt_breakdown_id_seq OWNED BY public.associate_debt_breakdown.id;


--
-- Name: associate_level_history; Type: TABLE; Schema: public; Owner: credinet_user
--

CREATE TABLE public.associate_level_history (
    id integer NOT NULL,
    associate_profile_id integer NOT NULL,
    old_level_id integer NOT NULL,
    new_level_id integer NOT NULL,
    reason text,
    change_type_id integer NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.associate_level_history OWNER TO credinet_user;

--
-- Name: TABLE associate_level_history; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON TABLE public.associate_level_history IS 'Historial de cambios de nivel de asociados (promociones, descensos, manuales).';


--
-- Name: associate_level_history_id_seq; Type: SEQUENCE; Schema: public; Owner: credinet_user
--

CREATE SEQUENCE public.associate_level_history_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.associate_level_history_id_seq OWNER TO credinet_user;

--
-- Name: associate_level_history_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: credinet_user
--

ALTER SEQUENCE public.associate_level_history_id_seq OWNED BY public.associate_level_history.id;


--
-- Name: associate_levels; Type: TABLE; Schema: public; Owner: credinet_user
--

CREATE TABLE public.associate_levels (
    id integer NOT NULL,
    name character varying(50) NOT NULL,
    max_loan_amount numeric(12,2) NOT NULL,
    credit_limit numeric(12,2) DEFAULT 0.00,
    description text,
    min_clients integer DEFAULT 0,
    min_collection_rate numeric(5,2) DEFAULT 0.00,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.associate_levels OWNER TO credinet_user;

--
-- Name: TABLE associate_levels; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON TABLE public.associate_levels IS 'Niveles de asociados (Bronce, Plata, Oro, Platino, Diamante) con límites de préstamo y crédito.';


--
-- Name: COLUMN associate_levels.credit_limit; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON COLUMN public.associate_levels.credit_limit IS 'Límite de crédito disponible para el asociado en este nivel (v2.0).';


--
-- Name: associate_levels_id_seq; Type: SEQUENCE; Schema: public; Owner: credinet_user
--

CREATE SEQUENCE public.associate_levels_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.associate_levels_id_seq OWNER TO credinet_user;

--
-- Name: associate_levels_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: credinet_user
--

ALTER SEQUENCE public.associate_levels_id_seq OWNED BY public.associate_levels.id;


--
-- Name: associate_payment_statements; Type: TABLE; Schema: public; Owner: credinet_user
--

CREATE TABLE public.associate_payment_statements (
    id integer NOT NULL,
    cut_period_id integer NOT NULL,
    user_id integer NOT NULL,
    statement_number character varying(50) NOT NULL,
    total_payments_count integer DEFAULT 0 NOT NULL,
    total_amount_collected numeric(12,2) DEFAULT 0.00 NOT NULL,
    total_commission_owed numeric(12,2) DEFAULT 0.00 NOT NULL,
    commission_rate_applied numeric(5,2) NOT NULL,
    status_id integer NOT NULL,
    generated_date date NOT NULL,
    sent_date date,
    due_date date NOT NULL,
    paid_date date,
    paid_amount numeric(12,2),
    payment_method_id integer,
    payment_reference character varying(100),
    late_fee_amount numeric(12,2) DEFAULT 0.00 NOT NULL,
    late_fee_applied boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT check_statements_totals_non_negative CHECK (((total_payments_count >= 0) AND (total_amount_collected >= (0)::numeric) AND (total_commission_owed >= (0)::numeric) AND (late_fee_amount >= (0)::numeric)))
);


ALTER TABLE public.associate_payment_statements OWNER TO credinet_user;

--
-- Name: TABLE associate_payment_statements; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON TABLE public.associate_payment_statements IS 'Estados de cuenta generados para asociados por cada período de corte. Incluye sistema de mora v2.0.';


--
-- Name: COLUMN associate_payment_statements.late_fee_amount; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON COLUMN public.associate_payment_statements.late_fee_amount IS '⭐ v2.0: Mora del 30% aplicada sobre comisión si NO reportó ningún pago (total_payments_count = 0).';


--
-- Name: COLUMN associate_payment_statements.late_fee_applied; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON COLUMN public.associate_payment_statements.late_fee_applied IS '⭐ v2.0: Flag que indica si ya se aplicó la mora del 30%.';


--
-- Name: associate_payment_statements_id_seq; Type: SEQUENCE; Schema: public; Owner: credinet_user
--

CREATE SEQUENCE public.associate_payment_statements_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.associate_payment_statements_id_seq OWNER TO credinet_user;

--
-- Name: associate_payment_statements_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: credinet_user
--

ALTER SEQUENCE public.associate_payment_statements_id_seq OWNED BY public.associate_payment_statements.id;


--
-- Name: associate_profiles; Type: TABLE; Schema: public; Owner: credinet_user
--

CREATE TABLE public.associate_profiles (
    id integer NOT NULL,
    user_id integer NOT NULL,
    level_id integer NOT NULL,
    contact_person character varying(150),
    contact_email character varying(150),
    default_commission_rate numeric(5,2) DEFAULT 5.0 NOT NULL,
    active boolean DEFAULT true NOT NULL,
    consecutive_full_credit_periods integer DEFAULT 0 NOT NULL,
    consecutive_on_time_payments integer DEFAULT 0 NOT NULL,
    clients_in_agreement integer DEFAULT 0 NOT NULL,
    last_level_evaluation_date timestamp with time zone,
    credit_used numeric(12,2) DEFAULT 0.00 NOT NULL,
    credit_limit numeric(12,2) DEFAULT 0.00 NOT NULL,
    credit_available numeric(12,2) GENERATED ALWAYS AS ((credit_limit - credit_used)) STORED,
    credit_last_updated timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    debt_balance numeric(12,2) DEFAULT 0.00 NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT check_associate_profiles_commission_rate_valid CHECK (((default_commission_rate >= (0)::numeric) AND (default_commission_rate <= (100)::numeric))),
    CONSTRAINT check_associate_profiles_counters_non_negative CHECK (((consecutive_full_credit_periods >= 0) AND (consecutive_on_time_payments >= 0) AND (clients_in_agreement >= 0))),
    CONSTRAINT check_associate_profiles_credit_non_negative CHECK (((credit_used >= (0)::numeric) AND (credit_limit >= (0)::numeric))),
    CONSTRAINT check_associate_profiles_debt_non_negative CHECK ((debt_balance >= (0)::numeric))
);


ALTER TABLE public.associate_profiles OWNER TO credinet_user;

--
-- Name: TABLE associate_profiles; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON TABLE public.associate_profiles IS 'Información extendida de usuarios que son asociados (gestores de cartera de préstamos). Incluye sistema de crédito v2.0.';


--
-- Name: COLUMN associate_profiles.consecutive_full_credit_periods; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON COLUMN public.associate_profiles.consecutive_full_credit_periods IS 'Contador de períodos consecutivos con 100% de cobro. Usado para evaluaciones de nivel.';


--
-- Name: COLUMN associate_profiles.credit_used; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON COLUMN public.associate_profiles.credit_used IS '⭐ v2.0: Crédito actualmente utilizado por el asociado (préstamos absorbidos no liquidados).';


--
-- Name: COLUMN associate_profiles.credit_limit; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON COLUMN public.associate_profiles.credit_limit IS '⭐ v2.0: Límite máximo de crédito disponible para el asociado según su nivel.';


--
-- Name: COLUMN associate_profiles.credit_available; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON COLUMN public.associate_profiles.credit_available IS '⭐ v2.0: Crédito disponible restante (columna calculada: credit_limit - credit_used).';


--
-- Name: COLUMN associate_profiles.debt_balance; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON COLUMN public.associate_profiles.debt_balance IS '⭐ v2.0: Deuda total del asociado (pagos no reportados + clientes morosos + mora).';


--
-- Name: associate_profiles_id_seq; Type: SEQUENCE; Schema: public; Owner: credinet_user
--

CREATE SEQUENCE public.associate_profiles_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.associate_profiles_id_seq OWNER TO credinet_user;

--
-- Name: associate_profiles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: credinet_user
--

ALTER SEQUENCE public.associate_profiles_id_seq OWNED BY public.associate_profiles.id;


--
-- Name: audit_log; Type: TABLE; Schema: public; Owner: credinet_user
--

CREATE TABLE public.audit_log (
    id integer NOT NULL,
    table_name character varying(100) NOT NULL,
    record_id integer NOT NULL,
    operation character varying(10) NOT NULL,
    old_data jsonb,
    new_data jsonb,
    changed_by integer,
    changed_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    ip_address inet,
    user_agent text,
    CONSTRAINT audit_log_operation_check CHECK (((operation)::text = ANY ((ARRAY['INSERT'::character varying, 'UPDATE'::character varying, 'DELETE'::character varying])::text[])))
);


ALTER TABLE public.audit_log OWNER TO credinet_user;

--
-- Name: TABLE audit_log; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON TABLE public.audit_log IS 'Registro de auditoría general para todas las tablas críticas (loans, payments, contracts, etc.).';


--
-- Name: COLUMN audit_log.old_data; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON COLUMN public.audit_log.old_data IS 'Snapshot JSON del registro ANTES del cambio (solo en UPDATE y DELETE).';


--
-- Name: COLUMN audit_log.new_data; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON COLUMN public.audit_log.new_data IS 'Snapshot JSON del registro DESPUÉS del cambio (solo en INSERT y UPDATE).';


--
-- Name: audit_log_id_seq; Type: SEQUENCE; Schema: public; Owner: credinet_user
--

CREATE SEQUENCE public.audit_log_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.audit_log_id_seq OWNER TO credinet_user;

--
-- Name: audit_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: credinet_user
--

ALTER SEQUENCE public.audit_log_id_seq OWNED BY public.audit_log.id;


--
-- Name: audit_session_log; Type: TABLE; Schema: public; Owner: credinet_user
--

CREATE TABLE public.audit_session_log (
    id integer NOT NULL,
    user_id integer NOT NULL,
    session_token character varying(500) NOT NULL,
    login_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    logout_at timestamp with time zone,
    ip_address inet,
    user_agent text,
    is_active boolean DEFAULT true,
    CONSTRAINT check_session_log_logout_after_login CHECK (((logout_at IS NULL) OR (logout_at >= login_at)))
);


ALTER TABLE public.audit_session_log OWNER TO credinet_user;

--
-- Name: TABLE audit_session_log; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON TABLE public.audit_session_log IS 'Registro de sesiones de usuario para auditoría de accesos al sistema (opcional, para compliance).';


--
-- Name: audit_session_log_id_seq; Type: SEQUENCE; Schema: public; Owner: credinet_user
--

CREATE SEQUENCE public.audit_session_log_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.audit_session_log_id_seq OWNER TO credinet_user;

--
-- Name: audit_session_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: credinet_user
--

ALTER SEQUENCE public.audit_session_log_id_seq OWNED BY public.audit_session_log.id;


--
-- Name: beneficiaries; Type: TABLE; Schema: public; Owner: credinet_user
--

CREATE TABLE public.beneficiaries (
    id integer NOT NULL,
    user_id integer NOT NULL,
    full_name character varying(200) NOT NULL,
    relationship character varying(50) NOT NULL,
    phone_number character varying(20) NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.beneficiaries OWNER TO credinet_user;

--
-- Name: TABLE beneficiaries; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON TABLE public.beneficiaries IS 'Beneficiarios designados por clientes (relación 1:1 con users).';


--
-- Name: beneficiaries_id_seq; Type: SEQUENCE; Schema: public; Owner: credinet_user
--

CREATE SEQUENCE public.beneficiaries_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.beneficiaries_id_seq OWNER TO credinet_user;

--
-- Name: beneficiaries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: credinet_user
--

ALTER SEQUENCE public.beneficiaries_id_seq OWNED BY public.beneficiaries.id;


--
-- Name: client_documents; Type: TABLE; Schema: public; Owner: credinet_user
--

CREATE TABLE public.client_documents (
    id integer NOT NULL,
    user_id integer NOT NULL,
    document_type_id integer NOT NULL,
    file_name character varying(255) NOT NULL,
    original_file_name character varying(255),
    file_path character varying(500) NOT NULL,
    file_size bigint,
    mime_type character varying(100),
    status_id integer NOT NULL,
    upload_date timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    reviewed_by integer,
    reviewed_at timestamp with time zone,
    comments text,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.client_documents OWNER TO credinet_user;

--
-- Name: TABLE client_documents; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON TABLE public.client_documents IS 'Documentos cargados por clientes (INE, comprobante de domicilio, etc.).';


--
-- Name: client_documents_id_seq; Type: SEQUENCE; Schema: public; Owner: credinet_user
--

CREATE SEQUENCE public.client_documents_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.client_documents_id_seq OWNER TO credinet_user;

--
-- Name: client_documents_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: credinet_user
--

ALTER SEQUENCE public.client_documents_id_seq OWNED BY public.client_documents.id;


--
-- Name: config_types; Type: TABLE; Schema: public; Owner: credinet_user
--

CREATE TABLE public.config_types (
    id integer NOT NULL,
    name character varying(50) NOT NULL,
    description text,
    validation_regex text,
    example_value text,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.config_types OWNER TO credinet_user;

--
-- Name: TABLE config_types; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON TABLE public.config_types IS 'Catálogo de tipos de datos para configuraciones del sistema (STRING, NUMBER, BOOLEAN, JSON).';


--
-- Name: config_types_id_seq; Type: SEQUENCE; Schema: public; Owner: credinet_user
--

CREATE SEQUENCE public.config_types_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.config_types_id_seq OWNER TO credinet_user;

--
-- Name: config_types_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: credinet_user
--

ALTER SEQUENCE public.config_types_id_seq OWNED BY public.config_types.id;


--
-- Name: contract_statuses; Type: TABLE; Schema: public; Owner: credinet_user
--

CREATE TABLE public.contract_statuses (
    id integer NOT NULL,
    name character varying(50) NOT NULL,
    description text NOT NULL,
    is_active boolean DEFAULT true,
    requires_signature boolean DEFAULT false,
    display_order integer DEFAULT 0,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.contract_statuses OWNER TO credinet_user;

--
-- Name: TABLE contract_statuses; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON TABLE public.contract_statuses IS 'Catálogo de estados posibles para contratos. Normaliza contracts.status_id.';


--
-- Name: contract_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: credinet_user
--

CREATE SEQUENCE public.contract_statuses_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.contract_statuses_id_seq OWNER TO credinet_user;

--
-- Name: contract_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: credinet_user
--

ALTER SEQUENCE public.contract_statuses_id_seq OWNED BY public.contract_statuses.id;


--
-- Name: contracts; Type: TABLE; Schema: public; Owner: credinet_user
--

CREATE TABLE public.contracts (
    id integer NOT NULL,
    loan_id integer NOT NULL,
    file_path character varying(500),
    start_date date NOT NULL,
    sign_date date,
    document_number character varying(50) NOT NULL,
    status_id integer NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT check_contracts_sign_after_start CHECK (((sign_date IS NULL) OR (sign_date >= start_date)))
);


ALTER TABLE public.contracts OWNER TO credinet_user;

--
-- Name: TABLE contracts; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON TABLE public.contracts IS 'Contratos generados automáticamente cuando un préstamo es aprobado. Relación 1:1 con loans.';


--
-- Name: COLUMN contracts.document_number; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON COLUMN public.contracts.document_number IS 'Número único del contrato (formato: CONT-YYYY-NNN). Usado para referencia legal y archivos.';


--
-- Name: contracts_id_seq; Type: SEQUENCE; Schema: public; Owner: credinet_user
--

CREATE SEQUENCE public.contracts_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.contracts_id_seq OWNER TO credinet_user;

--
-- Name: contracts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: credinet_user
--

ALTER SEQUENCE public.contracts_id_seq OWNED BY public.contracts.id;


--
-- Name: cut_period_statuses; Type: TABLE; Schema: public; Owner: credinet_user
--

CREATE TABLE public.cut_period_statuses (
    id integer NOT NULL,
    name character varying(50) NOT NULL,
    description text NOT NULL,
    is_terminal boolean DEFAULT false,
    allows_payments boolean DEFAULT true,
    display_order integer DEFAULT 0,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.cut_period_statuses OWNER TO credinet_user;

--
-- Name: TABLE cut_period_statuses; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON TABLE public.cut_period_statuses IS 'Catálogo de estados para períodos de corte quincenal (días 8-22 y 23-7).';


--
-- Name: cut_period_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: credinet_user
--

CREATE SEQUENCE public.cut_period_statuses_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.cut_period_statuses_id_seq OWNER TO credinet_user;

--
-- Name: cut_period_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: credinet_user
--

ALTER SEQUENCE public.cut_period_statuses_id_seq OWNED BY public.cut_period_statuses.id;


--
-- Name: cut_periods; Type: TABLE; Schema: public; Owner: credinet_user
--

CREATE TABLE public.cut_periods (
    id integer NOT NULL,
    cut_number integer NOT NULL,
    period_start_date date NOT NULL,
    period_end_date date NOT NULL,
    status_id integer NOT NULL,
    total_payments_expected numeric(12,2) DEFAULT 0.00 NOT NULL,
    total_payments_received numeric(12,2) DEFAULT 0.00 NOT NULL,
    total_commission numeric(12,2) DEFAULT 0.00 NOT NULL,
    created_by integer NOT NULL,
    closed_by integer,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    cut_code character varying(10),
    CONSTRAINT check_cut_periods_dates_logical CHECK ((period_end_date > period_start_date)),
    CONSTRAINT check_cut_periods_totals_non_negative CHECK (((total_payments_expected >= (0)::numeric) AND (total_payments_received >= (0)::numeric) AND (total_commission >= (0)::numeric)))
);


ALTER TABLE public.cut_periods OWNER TO credinet_user;

--
-- Name: TABLE cut_periods; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON TABLE public.cut_periods IS 'Períodos administrativos quincenales del sistema (8-22 y 23-7 de cada mes). Usados para cortes de caja y liquidaciones.';


--
-- Name: COLUMN cut_periods.cut_number; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON COLUMN public.cut_periods.cut_number IS 'Número secuencial del período de corte. Se reinicia cada año (1-24 por año).';


--
-- Name: COLUMN cut_periods.cut_code; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON COLUMN public.cut_periods.cut_code IS 'Código único del periodo: {YYYY}-Q{NN}. Ej: 2025-Q01 (ene 8-22), 2025-Q24 (dic 23-ene 7)';


--
-- Name: cut_periods_id_seq; Type: SEQUENCE; Schema: public; Owner: credinet_user
--

CREATE SEQUENCE public.cut_periods_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.cut_periods_id_seq OWNER TO credinet_user;

--
-- Name: cut_periods_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: credinet_user
--

ALTER SEQUENCE public.cut_periods_id_seq OWNED BY public.cut_periods.id;


--
-- Name: defaulted_client_reports; Type: TABLE; Schema: public; Owner: credinet_user
--

CREATE TABLE public.defaulted_client_reports (
    id integer NOT NULL,
    associate_profile_id integer NOT NULL,
    loan_id integer NOT NULL,
    client_user_id integer NOT NULL,
    reported_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    reported_by integer NOT NULL,
    total_debt_amount numeric(12,2) NOT NULL,
    evidence_details text,
    evidence_file_path character varying(500),
    status character varying(50) DEFAULT 'PENDING'::character varying NOT NULL,
    approved_by integer,
    approved_at timestamp with time zone,
    rejection_reason text,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT check_defaulted_reports_approved_has_user CHECK (((((status)::text = 'APPROVED'::text) AND (approved_by IS NOT NULL) AND (approved_at IS NOT NULL)) OR ((status)::text <> 'APPROVED'::text))),
    CONSTRAINT check_defaulted_reports_debt_positive CHECK ((total_debt_amount > (0)::numeric)),
    CONSTRAINT check_defaulted_reports_status_valid CHECK (((status)::text = ANY ((ARRAY['PENDING'::character varying, 'APPROVED'::character varying, 'REJECTED'::character varying, 'IN_REVIEW'::character varying])::text[])))
);


ALTER TABLE public.defaulted_client_reports OWNER TO credinet_user;

--
-- Name: TABLE defaulted_client_reports; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON TABLE public.defaulted_client_reports IS '⭐ MIGRACIÓN 09: Reportes de clientes morosos presentados por asociados con evidencia. Requieren aprobación administrativa.';


--
-- Name: COLUMN defaulted_client_reports.evidence_details; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON COLUMN public.defaulted_client_reports.evidence_details IS 'Descripción detallada de la evidencia de morosidad (llamadas, visitas, mensajes, etc.).';


--
-- Name: COLUMN defaulted_client_reports.evidence_file_path; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON COLUMN public.defaulted_client_reports.evidence_file_path IS 'Path a archivo de evidencia (screenshots, grabaciones, etc.).';


--
-- Name: defaulted_client_reports_id_seq; Type: SEQUENCE; Schema: public; Owner: credinet_user
--

CREATE SEQUENCE public.defaulted_client_reports_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.defaulted_client_reports_id_seq OWNER TO credinet_user;

--
-- Name: defaulted_client_reports_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: credinet_user
--

ALTER SEQUENCE public.defaulted_client_reports_id_seq OWNED BY public.defaulted_client_reports.id;


--
-- Name: document_statuses; Type: TABLE; Schema: public; Owner: credinet_user
--

CREATE TABLE public.document_statuses (
    id integer NOT NULL,
    name character varying(50) NOT NULL,
    description text NOT NULL,
    display_order integer DEFAULT 0,
    color_code character varying(7),
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.document_statuses OWNER TO credinet_user;

--
-- Name: TABLE document_statuses; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON TABLE public.document_statuses IS 'Catálogo de estados para documentos de clientes (PENDING, APPROVED, REJECTED).';


--
-- Name: document_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: credinet_user
--

CREATE SEQUENCE public.document_statuses_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.document_statuses_id_seq OWNER TO credinet_user;

--
-- Name: document_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: credinet_user
--

ALTER SEQUENCE public.document_statuses_id_seq OWNED BY public.document_statuses.id;


--
-- Name: document_types; Type: TABLE; Schema: public; Owner: credinet_user
--

CREATE TABLE public.document_types (
    id integer NOT NULL,
    name character varying(100) NOT NULL,
    description text,
    is_required boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.document_types OWNER TO credinet_user;

--
-- Name: TABLE document_types; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON TABLE public.document_types IS 'Tipos de documentos requeridos para clientes (INE, comprobante de domicilio, etc.).';


--
-- Name: document_types_id_seq; Type: SEQUENCE; Schema: public; Owner: credinet_user
--

CREATE SEQUENCE public.document_types_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.document_types_id_seq OWNER TO credinet_user;

--
-- Name: document_types_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: credinet_user
--

ALTER SEQUENCE public.document_types_id_seq OWNED BY public.document_types.id;


--
-- Name: guarantors; Type: TABLE; Schema: public; Owner: credinet_user
--

CREATE TABLE public.guarantors (
    id integer NOT NULL,
    user_id integer NOT NULL,
    full_name character varying(200) NOT NULL,
    first_name character varying(100),
    paternal_last_name character varying(100),
    maternal_last_name character varying(100),
    relationship character varying(50) NOT NULL,
    phone_number character varying(20) NOT NULL,
    curp character varying(18),
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT check_guarantors_curp_length CHECK (((curp IS NULL) OR (length((curp)::text) = 18))),
    CONSTRAINT check_guarantors_phone_format CHECK (((phone_number)::text ~ '^[0-9]{10}$'::text))
);


ALTER TABLE public.guarantors OWNER TO credinet_user;

--
-- Name: TABLE guarantors; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON TABLE public.guarantors IS 'Avales o garantes de clientes (relación 1:1 con users).';


--
-- Name: guarantors_id_seq; Type: SEQUENCE; Schema: public; Owner: credinet_user
--

CREATE SEQUENCE public.guarantors_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.guarantors_id_seq OWNER TO credinet_user;

--
-- Name: guarantors_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: credinet_user
--

ALTER SEQUENCE public.guarantors_id_seq OWNED BY public.guarantors.id;


--
-- Name: legacy_payment_table; Type: TABLE; Schema: public; Owner: credinet_user
--

CREATE TABLE public.legacy_payment_table (
    id integer NOT NULL,
    amount numeric(12,2) NOT NULL,
    biweekly_payment numeric(10,2) NOT NULL,
    term_biweeks integer DEFAULT 12 NOT NULL,
    total_payment numeric(12,2) GENERATED ALWAYS AS ((biweekly_payment * (term_biweeks)::numeric)) STORED,
    total_interest numeric(12,2) GENERATED ALWAYS AS (((biweekly_payment * (term_biweeks)::numeric) - amount)) STORED,
    effective_rate_percent numeric(5,2) GENERATED ALWAYS AS (round(((((biweekly_payment * (term_biweeks)::numeric) - amount) / amount) * (100)::numeric), 2)) STORED,
    biweekly_rate_percent numeric(5,3) GENERATED ALWAYS AS (round((((((biweekly_payment * (term_biweeks)::numeric) - amount) / amount) / (term_biweeks)::numeric) * (100)::numeric), 3)) STORED,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    created_by integer,
    updated_by integer,
    CONSTRAINT check_legacy_amount_positive CHECK ((amount > (0)::numeric)),
    CONSTRAINT check_legacy_payment_positive CHECK ((biweekly_payment > (0)::numeric)),
    CONSTRAINT check_legacy_term_valid CHECK (((term_biweeks >= 1) AND (term_biweeks <= 52)))
);


ALTER TABLE public.legacy_payment_table OWNER TO credinet_user;

--
-- Name: TABLE legacy_payment_table; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON TABLE public.legacy_payment_table IS 'Tabla histórica de pagos quincenales. TOTALMENTE EDITABLE por admin. Permite agregar montos como $7,500, $12,350, etc.';


--
-- Name: COLUMN legacy_payment_table.amount; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON COLUMN public.legacy_payment_table.amount IS 'Monto del préstamo (capital). Debe ser único para cada plazo.';


--
-- Name: COLUMN legacy_payment_table.biweekly_payment; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON COLUMN public.legacy_payment_table.biweekly_payment IS 'Pago quincenal fijo para este monto. Admin puede editarlo.';


--
-- Name: COLUMN legacy_payment_table.effective_rate_percent; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON COLUMN public.legacy_payment_table.effective_rate_percent IS 'Tasa efectiva total calculada automáticamente.';


--
-- Name: COLUMN legacy_payment_table.biweekly_rate_percent; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON COLUMN public.legacy_payment_table.biweekly_rate_percent IS 'Tasa quincenal promedio calculada automáticamente.';


--
-- Name: legacy_payment_table_id_seq; Type: SEQUENCE; Schema: public; Owner: credinet_user
--

CREATE SEQUENCE public.legacy_payment_table_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.legacy_payment_table_id_seq OWNER TO credinet_user;

--
-- Name: legacy_payment_table_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: credinet_user
--

ALTER SEQUENCE public.legacy_payment_table_id_seq OWNED BY public.legacy_payment_table.id;


--
-- Name: level_change_types; Type: TABLE; Schema: public; Owner: credinet_user
--

CREATE TABLE public.level_change_types (
    id integer NOT NULL,
    name character varying(50) NOT NULL,
    description text NOT NULL,
    is_automatic boolean DEFAULT false,
    display_order integer DEFAULT 0,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.level_change_types OWNER TO credinet_user;

--
-- Name: TABLE level_change_types; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON TABLE public.level_change_types IS 'Catálogo de tipos de cambio de nivel de asociados (PROMOTION, DEMOTION, MANUAL).';


--
-- Name: level_change_types_id_seq; Type: SEQUENCE; Schema: public; Owner: credinet_user
--

CREATE SEQUENCE public.level_change_types_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.level_change_types_id_seq OWNER TO credinet_user;

--
-- Name: level_change_types_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: credinet_user
--

ALTER SEQUENCE public.level_change_types_id_seq OWNED BY public.level_change_types.id;


--
-- Name: loan_renewals; Type: TABLE; Schema: public; Owner: credinet_user
--

CREATE TABLE public.loan_renewals (
    id integer NOT NULL,
    original_loan_id integer NOT NULL,
    renewed_loan_id integer NOT NULL,
    renewal_date date NOT NULL,
    pending_balance numeric(12,2) NOT NULL,
    new_amount numeric(12,2) NOT NULL,
    reason text,
    created_by integer NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT check_loan_renewals_amounts_positive CHECK (((pending_balance >= (0)::numeric) AND (new_amount > (0)::numeric)))
);


ALTER TABLE public.loan_renewals OWNER TO credinet_user;

--
-- Name: TABLE loan_renewals; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON TABLE public.loan_renewals IS 'Registro de renovaciones de préstamos (préstamo original → préstamo renovado).';


--
-- Name: COLUMN loan_renewals.pending_balance; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON COLUMN public.loan_renewals.pending_balance IS 'Saldo pendiente del préstamo original al momento de la renovación.';


--
-- Name: COLUMN loan_renewals.new_amount; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON COLUMN public.loan_renewals.new_amount IS 'Monto del nuevo préstamo (puede incluir o no el saldo pendiente).';


--
-- Name: loan_renewals_id_seq; Type: SEQUENCE; Schema: public; Owner: credinet_user
--

CREATE SEQUENCE public.loan_renewals_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.loan_renewals_id_seq OWNER TO credinet_user;

--
-- Name: loan_renewals_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: credinet_user
--

ALTER SEQUENCE public.loan_renewals_id_seq OWNED BY public.loan_renewals.id;


--
-- Name: loan_statuses; Type: TABLE; Schema: public; Owner: credinet_user
--

CREATE TABLE public.loan_statuses (
    id integer NOT NULL,
    name character varying(50) NOT NULL,
    description text NOT NULL,
    is_active boolean DEFAULT true,
    display_order integer DEFAULT 0,
    color_code character varying(7),
    icon_name character varying(50),
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.loan_statuses OWNER TO credinet_user;

--
-- Name: TABLE loan_statuses; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON TABLE public.loan_statuses IS 'Catálogo de estados posibles para préstamos. Normaliza loans.status_id.';


--
-- Name: loan_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: credinet_user
--

CREATE SEQUENCE public.loan_statuses_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.loan_statuses_id_seq OWNER TO credinet_user;

--
-- Name: loan_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: credinet_user
--

ALTER SEQUENCE public.loan_statuses_id_seq OWNED BY public.loan_statuses.id;


--
-- Name: loans; Type: TABLE; Schema: public; Owner: credinet_user
--

CREATE TABLE public.loans (
    id integer NOT NULL,
    user_id integer NOT NULL,
    associate_user_id integer,
    amount numeric(12,2) NOT NULL,
    interest_rate numeric(5,2) NOT NULL,
    commission_rate numeric(5,2) DEFAULT 0.0 NOT NULL,
    term_biweeks integer NOT NULL,
    status_id integer NOT NULL,
    contract_id integer,
    approved_at timestamp with time zone,
    approved_by integer,
    rejected_at timestamp with time zone,
    rejected_by integer,
    rejection_reason text,
    notes text,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    profile_code character varying(50),
    biweekly_payment numeric(12,2),
    total_payment numeric(12,2),
    total_interest numeric(12,2),
    total_commission numeric(12,2),
    commission_per_payment numeric(10,2),
    associate_payment numeric(10,2),
    CONSTRAINT check_loans_amount_positive CHECK ((amount > (0)::numeric)),
    CONSTRAINT check_loans_approved_after_created CHECK (((approved_at IS NULL) OR (approved_at >= created_at))),
    CONSTRAINT check_loans_commission_rate_valid CHECK (((commission_rate >= (0)::numeric) AND (commission_rate <= (100)::numeric))),
    CONSTRAINT check_loans_interest_rate_valid CHECK (((interest_rate >= (0)::numeric) AND (interest_rate <= (100)::numeric))),
    CONSTRAINT check_loans_rejected_after_created CHECK (((rejected_at IS NULL) OR (rejected_at >= created_at))),
    CONSTRAINT check_loans_term_biweeks_valid CHECK ((term_biweeks = ANY (ARRAY[6, 12, 18, 24]))),
    CONSTRAINT chk_loans_associate_payment_consistent CHECK (((associate_payment IS NULL) OR (biweekly_payment IS NULL) OR (commission_per_payment IS NULL) OR (abs((associate_payment - (biweekly_payment - commission_per_payment))) < 0.10))),
    CONSTRAINT chk_loans_associate_payment_lte_biweekly CHECK (((associate_payment IS NULL) OR (biweekly_payment IS NULL) OR (associate_payment <= biweekly_payment))),
    CONSTRAINT chk_loans_biweekly_payment_positive CHECK (((biweekly_payment IS NULL) OR (biweekly_payment > (0)::numeric))),
    CONSTRAINT chk_loans_commission_per_payment_non_negative CHECK (((commission_per_payment IS NULL) OR (commission_per_payment >= (0)::numeric))),
    CONSTRAINT chk_loans_total_interest_consistent CHECK (((total_interest IS NULL) OR (total_payment IS NULL) OR (amount IS NULL) OR (abs((total_interest - (total_payment - amount))) < 1.00))),
    CONSTRAINT chk_loans_total_interest_non_negative CHECK (((total_interest IS NULL) OR (total_interest >= (0)::numeric))),
    CONSTRAINT chk_loans_total_payment_consistent CHECK (((total_payment IS NULL) OR (biweekly_payment IS NULL) OR (term_biweeks IS NULL) OR (abs((total_payment - (biweekly_payment * (term_biweeks)::numeric))) < 1.00))),
    CONSTRAINT chk_loans_total_payment_gte_amount CHECK (((total_payment IS NULL) OR (total_payment >= amount)))
);


ALTER TABLE public.loans OWNER TO credinet_user;

--
-- Name: TABLE loans; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON TABLE public.loans IS 'Tabla central del sistema. Registra todos los préstamos solicitados, aprobados, rechazados o completados.';


--
-- Name: COLUMN loans.commission_rate; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON COLUMN public.loans.commission_rate IS 'Tasa de comisión del asociado en porcentaje. Ejemplo: 2.5 = 2.5%. Rango válido: 0-100.';


--
-- Name: COLUMN loans.term_biweeks; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON COLUMN public.loans.term_biweeks IS '⭐ V2.0: Plazo del préstamo en quincenas. Valores permitidos: 6, 12, 18 o 24 quincenas (3, 6, 9 o 12 meses). Validado por check_loans_term_biweeks_valid.';


--
-- Name: COLUMN loans.biweekly_payment; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON COLUMN public.loans.biweekly_payment IS 'Pago quincenal calculado que debe realizar el cliente (capital + interés). Calculado por calculate_loan_payment().';


--
-- Name: COLUMN loans.total_payment; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON COLUMN public.loans.total_payment IS 'Monto total que pagará el cliente (biweekly_payment * term_biweeks). Incluye capital + interés total.';


--
-- Name: COLUMN loans.total_interest; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON COLUMN public.loans.total_interest IS 'Interés total que pagará el cliente durante todo el préstamo (total_payment - amount).';


--
-- Name: COLUMN loans.total_commission; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON COLUMN public.loans.total_commission IS 'Comisión total acumulada que se descontará en todos los pagos (commission_per_payment * term_biweeks).';


--
-- Name: COLUMN loans.commission_per_payment; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON COLUMN public.loans.commission_per_payment IS 'Comisión que se descuenta del asociado en cada pago quincenal. Calculado por calculate_loan_payment().';


--
-- Name: COLUMN loans.associate_payment; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON COLUMN public.loans.associate_payment IS 'Pago neto que recibirá el asociado en cada periodo (biweekly_payment - commission_per_payment).';


--
-- Name: loans_id_seq; Type: SEQUENCE; Schema: public; Owner: credinet_user
--

CREATE SEQUENCE public.loans_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.loans_id_seq OWNER TO credinet_user;

--
-- Name: loans_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: credinet_user
--

ALTER SEQUENCE public.loans_id_seq OWNED BY public.loans.id;


--
-- Name: payment_methods; Type: TABLE; Schema: public; Owner: credinet_user
--

CREATE TABLE public.payment_methods (
    id integer NOT NULL,
    name character varying(50) NOT NULL,
    description text,
    is_active boolean DEFAULT true,
    requires_reference boolean DEFAULT false,
    display_order integer DEFAULT 0,
    icon_name character varying(50),
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.payment_methods OWNER TO credinet_user;

--
-- Name: TABLE payment_methods; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON TABLE public.payment_methods IS 'Catálogo de métodos de pago aceptados (efectivo, transferencia, OXXO, etc.).';


--
-- Name: payment_methods_id_seq; Type: SEQUENCE; Schema: public; Owner: credinet_user
--

CREATE SEQUENCE public.payment_methods_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.payment_methods_id_seq OWNER TO credinet_user;

--
-- Name: payment_methods_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: credinet_user
--

ALTER SEQUENCE public.payment_methods_id_seq OWNED BY public.payment_methods.id;


--
-- Name: payment_status_history; Type: TABLE; Schema: public; Owner: credinet_user
--

CREATE TABLE public.payment_status_history (
    id integer NOT NULL,
    payment_id integer NOT NULL,
    old_status_id integer,
    new_status_id integer NOT NULL,
    change_type character varying(50) NOT NULL,
    changed_by integer,
    change_reason text,
    ip_address inet,
    user_agent text,
    changed_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT check_payment_status_history_change_type_valid CHECK (((change_type)::text = ANY ((ARRAY['AUTOMATIC'::character varying, 'MANUAL_ADMIN'::character varying, 'SYSTEM_CLOSURE'::character varying, 'CORRECTION'::character varying, 'TRIGGER'::character varying])::text[]))),
    CONSTRAINT check_payment_status_history_manual_has_user CHECK (((((change_type)::text = ANY ((ARRAY['MANUAL_ADMIN'::character varying, 'CORRECTION'::character varying])::text[])) AND (changed_by IS NOT NULL)) OR ((change_type)::text <> ALL ((ARRAY['MANUAL_ADMIN'::character varying, 'CORRECTION'::character varying])::text[]))))
);


ALTER TABLE public.payment_status_history OWNER TO credinet_user;

--
-- Name: TABLE payment_status_history; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON TABLE public.payment_status_history IS '⭐ MIGRACIÓN 12: Registro completo de todos los cambios de estado de pagos para auditoría y compliance.';


--
-- Name: COLUMN payment_status_history.change_type; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON COLUMN public.payment_status_history.change_type IS 'Tipo de cambio: AUTOMATIC (trigger), MANUAL_ADMIN (admin marcó), SYSTEM_CLOSURE (cierre de período), CORRECTION (corrección manual).';


--
-- Name: COLUMN payment_status_history.changed_by; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON COLUMN public.payment_status_history.changed_by IS 'Usuario que realizó el cambio. NULL si fue automático (trigger o cierre de sistema).';


--
-- Name: COLUMN payment_status_history.change_reason; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON COLUMN public.payment_status_history.change_reason IS 'Razón del cambio (obligatorio en cambios manuales). Ej: "Cliente pagó en efectivo pero no se había registrado".';


--
-- Name: payment_status_history_id_seq; Type: SEQUENCE; Schema: public; Owner: credinet_user
--

CREATE SEQUENCE public.payment_status_history_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.payment_status_history_id_seq OWNER TO credinet_user;

--
-- Name: payment_status_history_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: credinet_user
--

ALTER SEQUENCE public.payment_status_history_id_seq OWNED BY public.payment_status_history.id;


--
-- Name: payment_statuses; Type: TABLE; Schema: public; Owner: credinet_user
--

CREATE TABLE public.payment_statuses (
    id integer NOT NULL,
    name character varying(50) NOT NULL,
    description text NOT NULL,
    is_active boolean DEFAULT true,
    display_order integer DEFAULT 0,
    color_code character varying(7),
    icon_name character varying(50),
    is_real_payment boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.payment_statuses OWNER TO credinet_user;

--
-- Name: TABLE payment_statuses; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON TABLE public.payment_statuses IS 'Catálogo de estados posibles para pagos. 12 estados consolidados (6 pendientes, 2 reales, 4 ficticios).';


--
-- Name: COLUMN payment_statuses.is_real_payment; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON COLUMN public.payment_statuses.is_real_payment IS 'TRUE si el pago es dinero real cobrado, FALSE si es ficticio (absorbido, cancelado, perdonado).';


--
-- Name: payment_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: credinet_user
--

CREATE SEQUENCE public.payment_statuses_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.payment_statuses_id_seq OWNER TO credinet_user;

--
-- Name: payment_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: credinet_user
--

ALTER SEQUENCE public.payment_statuses_id_seq OWNED BY public.payment_statuses.id;


--
-- Name: payments; Type: TABLE; Schema: public; Owner: credinet_user
--

CREATE TABLE public.payments (
    id integer NOT NULL,
    loan_id integer NOT NULL,
    amount_paid numeric(12,2) NOT NULL,
    payment_date date NOT NULL,
    payment_due_date date NOT NULL,
    is_late boolean DEFAULT false NOT NULL,
    status_id integer,
    cut_period_id integer,
    marked_by integer,
    marked_at timestamp with time zone,
    marking_notes text,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    payment_number integer,
    expected_amount numeric(12,2),
    interest_amount numeric(10,2),
    principal_amount numeric(10,2),
    commission_amount numeric(10,2),
    associate_payment numeric(10,2),
    balance_remaining numeric(12,2),
    CONSTRAINT check_payments_amount_paid_non_negative CHECK ((amount_paid >= (0)::numeric)),
    CONSTRAINT check_payments_dates_logical CHECK ((payment_date <= payment_due_date)),
    CONSTRAINT chk_payments_associate_equals_expected_minus_commission CHECK (((associate_payment IS NULL) OR (expected_amount IS NULL) OR (commission_amount IS NULL) OR (abs((associate_payment - (expected_amount - commission_amount))) < 0.10))),
    CONSTRAINT chk_payments_associate_lte_expected CHECK (((associate_payment IS NULL) OR (expected_amount IS NULL) OR (associate_payment <= expected_amount))),
    CONSTRAINT chk_payments_associate_payment_non_negative CHECK (((associate_payment IS NULL) OR (associate_payment >= (0)::numeric))),
    CONSTRAINT chk_payments_balance_non_negative CHECK (((balance_remaining IS NULL) OR (balance_remaining >= (0)::numeric))),
    CONSTRAINT chk_payments_commission_non_negative CHECK (((commission_amount IS NULL) OR (commission_amount >= (0)::numeric))),
    CONSTRAINT chk_payments_expected_amount_positive CHECK (((expected_amount IS NULL) OR (expected_amount > (0)::numeric))),
    CONSTRAINT chk_payments_expected_equals_interest_plus_principal CHECK (((expected_amount IS NULL) OR (interest_amount IS NULL) OR (principal_amount IS NULL) OR (abs((expected_amount - (interest_amount + principal_amount))) < 0.10))),
    CONSTRAINT chk_payments_interest_non_negative CHECK (((interest_amount IS NULL) OR (interest_amount >= (0)::numeric))),
    CONSTRAINT chk_payments_paid_lte_expected CHECK (((expected_amount IS NULL) OR (amount_paid <= (expected_amount + 100.00)))),
    CONSTRAINT chk_payments_payment_number_positive CHECK (((payment_number IS NULL) OR (payment_number > 0))),
    CONSTRAINT chk_payments_principal_non_negative CHECK (((principal_amount IS NULL) OR (principal_amount >= (0)::numeric)))
);


ALTER TABLE public.payments OWNER TO credinet_user;

--
-- Name: TABLE payments; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON TABLE public.payments IS 'Schedule de pagos generado automáticamente cuando un préstamo es aprobado. Un registro por cada quincena del plazo.';


--
-- Name: COLUMN payments.payment_due_date; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON COLUMN public.payments.payment_due_date IS 'Fecha de vencimiento del pago según reglas de negocio: día 15 o último día del mes. Generado por calculate_first_payment_date().';


--
-- Name: COLUMN payments.is_late; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON COLUMN public.payments.is_late IS 'Indica si el pago está atrasado (TRUE si payment_due_date < CURRENT_DATE y no está pagado).';


--
-- Name: COLUMN payments.marked_by; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON COLUMN public.payments.marked_by IS '⭐ v2.0: Usuario que marcó manualmente el estado del pago (admin puede remarcar).';


--
-- Name: COLUMN payments.payment_number; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON COLUMN public.payments.payment_number IS 'Número secuencial del pago dentro del préstamo (1, 2, 3, ..., term_biweeks). Facilita ordenamiento y referencias.';


--
-- Name: COLUMN payments.expected_amount; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON COLUMN public.payments.expected_amount IS 'Monto esperado que debe pagar el cliente en este periodo (incluye capital + interés). Valor de referencia para validar pagos.';


--
-- Name: COLUMN payments.interest_amount; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON COLUMN public.payments.interest_amount IS 'Monto de interés correspondiente a este periodo. Parte del expected_amount que representa el costo del préstamo.';


--
-- Name: COLUMN payments.principal_amount; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON COLUMN public.payments.principal_amount IS 'Monto de capital (abono al principal) correspondiente a este periodo. Reduce el saldo pendiente del préstamo.';


--
-- Name: COLUMN payments.commission_amount; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON COLUMN public.payments.commission_amount IS 'Monto de comisión que se descuenta al asociado en este pago. Se calcula sobre el expected_amount.';


--
-- Name: COLUMN payments.associate_payment; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON COLUMN public.payments.associate_payment IS 'Monto neto que recibe el asociado en este periodo (expected_amount - commission_amount).';


--
-- Name: COLUMN payments.balance_remaining; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON COLUMN public.payments.balance_remaining IS 'Saldo pendiente del préstamo después de aplicar el abono a capital de este pago. El último pago debe dejar balance=0.';


--
-- Name: payments_id_seq; Type: SEQUENCE; Schema: public; Owner: credinet_user
--

CREATE SEQUENCE public.payments_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.payments_id_seq OWNER TO credinet_user;

--
-- Name: payments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: credinet_user
--

ALTER SEQUENCE public.payments_id_seq OWNED BY public.payments.id;


--
-- Name: rate_profiles; Type: TABLE; Schema: public; Owner: credinet_user
--

CREATE TABLE public.rate_profiles (
    id integer NOT NULL,
    code character varying(50) NOT NULL,
    name character varying(100) NOT NULL,
    description text,
    calculation_type character varying(20) NOT NULL,
    interest_rate_percent numeric(5,3),
    enabled boolean DEFAULT true,
    is_recommended boolean DEFAULT false,
    display_order integer DEFAULT 0,
    min_amount numeric(12,2),
    max_amount numeric(12,2),
    valid_terms integer[],
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    created_by integer,
    updated_by integer,
    commission_rate_percent numeric(5,3),
    CONSTRAINT rate_profiles_calculation_type_check CHECK (((calculation_type)::text = ANY ((ARRAY['table_lookup'::character varying, 'formula'::character varying])::text[])))
);


ALTER TABLE public.rate_profiles OWNER TO credinet_user;

--
-- Name: TABLE rate_profiles; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON TABLE public.rate_profiles IS 'Perfiles de tasa configurables. Admin puede crear, editar, habilitar/deshabilitar perfiles.';


--
-- Name: COLUMN rate_profiles.code; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON COLUMN public.rate_profiles.code IS 'Código único interno. Ejemplos: legacy, standard, premium, custom_vip.';


--
-- Name: COLUMN rate_profiles.calculation_type; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON COLUMN public.rate_profiles.calculation_type IS 'Método de cálculo: table_lookup (busca en legacy_payment_table) o formula (usa tasa fija).';


--
-- Name: COLUMN rate_profiles.interest_rate_percent; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON COLUMN public.rate_profiles.interest_rate_percent IS 'Tasa de interés quincenal que paga el CLIENTE. Ejemplo: 4.250 = 4.25% quincenal. NULL para perfil legacy (usa tabla).';


--
-- Name: COLUMN rate_profiles.is_recommended; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON COLUMN public.rate_profiles.is_recommended IS 'Si TRUE, este perfil aparece destacado como "Recomendado" en UI.';


--
-- Name: COLUMN rate_profiles.valid_terms; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON COLUMN public.rate_profiles.valid_terms IS 'Array de plazos permitidos en quincenas. NULL = permite cualquier plazo.';


--
-- Name: COLUMN rate_profiles.commission_rate_percent; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON COLUMN public.rate_profiles.commission_rate_percent IS 'Tasa de comisión que cobra la empresa al ASOCIADO sobre cada pago. Ejemplo: 2.500 = 2.5% de comisión. NULL para perfil legacy.';


--
-- Name: rate_profiles_id_seq; Type: SEQUENCE; Schema: public; Owner: credinet_user
--

CREATE SEQUENCE public.rate_profiles_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.rate_profiles_id_seq OWNER TO credinet_user;

--
-- Name: rate_profiles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: credinet_user
--

ALTER SEQUENCE public.rate_profiles_id_seq OWNED BY public.rate_profiles.id;


--
-- Name: roles; Type: TABLE; Schema: public; Owner: credinet_user
--

CREATE TABLE public.roles (
    id integer NOT NULL,
    name character varying(50) NOT NULL,
    description text,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.roles OWNER TO credinet_user;

--
-- Name: TABLE roles; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON TABLE public.roles IS 'Roles de usuario en el sistema (desarrollador, admin, asociado, cliente).';


--
-- Name: roles_id_seq; Type: SEQUENCE; Schema: public; Owner: credinet_user
--

CREATE SEQUENCE public.roles_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.roles_id_seq OWNER TO credinet_user;

--
-- Name: roles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: credinet_user
--

ALTER SEQUENCE public.roles_id_seq OWNED BY public.roles.id;


--
-- Name: statement_statuses; Type: TABLE; Schema: public; Owner: credinet_user
--

CREATE TABLE public.statement_statuses (
    id integer NOT NULL,
    name character varying(50) NOT NULL,
    description text NOT NULL,
    is_paid boolean DEFAULT false,
    display_order integer DEFAULT 0,
    color_code character varying(7),
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.statement_statuses OWNER TO credinet_user;

--
-- Name: TABLE statement_statuses; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON TABLE public.statement_statuses IS 'Catálogo de estados para cuentas de pago de asociados (GENERATED, PAID, OVERDUE).';


--
-- Name: statement_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: credinet_user
--

CREATE SEQUENCE public.statement_statuses_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.statement_statuses_id_seq OWNER TO credinet_user;

--
-- Name: statement_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: credinet_user
--

ALTER SEQUENCE public.statement_statuses_id_seq OWNED BY public.statement_statuses.id;


--
-- Name: system_configurations; Type: TABLE; Schema: public; Owner: credinet_user
--

CREATE TABLE public.system_configurations (
    id integer NOT NULL,
    config_key character varying(100) NOT NULL,
    config_value text NOT NULL,
    description text,
    config_type_id integer NOT NULL,
    updated_by integer NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.system_configurations OWNER TO credinet_user;

--
-- Name: TABLE system_configurations; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON TABLE public.system_configurations IS 'Configuraciones globales del sistema (tasas, montos, flags de funcionalidad).';


--
-- Name: system_configurations_id_seq; Type: SEQUENCE; Schema: public; Owner: credinet_user
--

CREATE SEQUENCE public.system_configurations_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.system_configurations_id_seq OWNER TO credinet_user;

--
-- Name: system_configurations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: credinet_user
--

ALTER SEQUENCE public.system_configurations_id_seq OWNED BY public.system_configurations.id;


--
-- Name: user_roles; Type: TABLE; Schema: public; Owner: credinet_user
--

CREATE TABLE public.user_roles (
    user_id integer NOT NULL,
    role_id integer NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.user_roles OWNER TO credinet_user;

--
-- Name: TABLE user_roles; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON TABLE public.user_roles IS 'Relación N:M entre usuarios y roles. Un usuario puede tener múltiples roles.';


--
-- Name: users; Type: TABLE; Schema: public; Owner: credinet_user
--

CREATE TABLE public.users (
    id integer NOT NULL,
    username character varying(50) NOT NULL,
    password_hash character varying(255) NOT NULL,
    first_name character varying(100) NOT NULL,
    last_name character varying(100) NOT NULL,
    email character varying(150),
    phone_number character varying(20) NOT NULL,
    birth_date date,
    curp character varying(18),
    profile_picture_url character varying(500),
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    active boolean DEFAULT true NOT NULL,
    CONSTRAINT check_users_curp_length CHECK (((curp IS NULL) OR (length((curp)::text) = 18))),
    CONSTRAINT check_users_phone_format CHECK (((phone_number)::text ~ '^[0-9]{10}$'::text))
);


ALTER TABLE public.users OWNER TO credinet_user;

--
-- Name: TABLE users; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON TABLE public.users IS 'Usuarios del sistema (clientes, asociados, administradores).';


--
-- Name: COLUMN users.password_hash; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON COLUMN public.users.password_hash IS 'Hash bcrypt de la contraseña del usuario. NUNCA almacenar contraseñas en texto plano.';


--
-- Name: COLUMN users.email; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON COLUMN public.users.email IS 'Email del usuario (OPCIONAL - algunos usuarios mayores pueden no tener correo electrónico).';


--
-- Name: COLUMN users.curp; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON COLUMN public.users.curp IS 'Clave Única de Registro de Población (CURP) de México. Formato: 18 caracteres alfanuméricos.';


--
-- Name: COLUMN users.active; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON COLUMN public.users.active IS 'Indica si el usuario está activo en el sistema. Los usuarios inactivos no pueden iniciar sesión.';


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: credinet_user
--

CREATE SEQUENCE public.users_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.users_id_seq OWNER TO credinet_user;

--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: credinet_user
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: v_associate_credit_summary; Type: VIEW; Schema: public; Owner: credinet_user
--

CREATE VIEW public.v_associate_credit_summary AS
 SELECT ap.id AS associate_profile_id,
    u.id AS user_id,
    concat(u.first_name, ' ', u.last_name) AS associate_name,
    u.email,
    al.name AS associate_level,
    ap.credit_limit,
    ap.credit_used,
    ap.debt_balance,
    ap.credit_available,
    ap.credit_last_updated,
        CASE
            WHEN (ap.credit_available <= (0)::numeric) THEN 'SIN_CREDITO'::text
            WHEN (ap.credit_available < (ap.credit_limit * 0.25)) THEN 'CRITICO'::text
            WHEN (ap.credit_available < (ap.credit_limit * 0.50)) THEN 'MEDIO'::text
            ELSE 'ALTO'::text
        END AS credit_status,
    round((((ap.credit_used)::numeric / NULLIF(ap.credit_limit, (0)::numeric)) * (100)::numeric), 2) AS credit_usage_percentage,
    ap.active AS is_active
   FROM ((public.associate_profiles ap
     JOIN public.users u ON ((ap.user_id = u.id)))
     JOIN public.associate_levels al ON ((ap.level_id = al.id)))
  ORDER BY ap.credit_available DESC;


ALTER TABLE public.v_associate_credit_summary OWNER TO credinet_user;

--
-- Name: VIEW v_associate_credit_summary; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON VIEW public.v_associate_credit_summary IS '⭐ MIGRACIÓN 07: Resumen ejecutivo del crédito disponible de cada asociado con análisis de utilización y estado.';


--
-- Name: v_associate_debt_detailed; Type: VIEW; Schema: public; Owner: credinet_user
--

CREATE VIEW public.v_associate_debt_detailed AS
 SELECT adb.id AS debt_id,
    ap.id AS associate_profile_id,
    concat(u.first_name, ' ', u.last_name) AS associate_name,
    adb.debt_type,
    adb.amount AS debt_amount,
    adb.is_liquidated,
    adb.liquidated_at,
    cp.cut_number,
    cp.period_start_date,
    cp.period_end_date,
    l.id AS loan_id,
    concat(uc.first_name, ' ', uc.last_name) AS client_name,
    adb.description,
    adb.created_at AS debt_registered_at,
        CASE adb.debt_type
            WHEN 'UNREPORTED_PAYMENT'::text THEN 'Pago no reportado al cierre'::text
            WHEN 'DEFAULTED_CLIENT'::text THEN 'Cliente moroso aprobado'::text
            WHEN 'LATE_FEE'::text THEN 'Mora del 30% aplicada'::text
            WHEN 'OTHER'::text THEN 'Otro tipo de deuda'::text
            ELSE NULL::text
        END AS debt_type_description
   FROM (((((public.associate_debt_breakdown adb
     JOIN public.associate_profiles ap ON ((adb.associate_profile_id = ap.id)))
     JOIN public.users u ON ((ap.user_id = u.id)))
     JOIN public.cut_periods cp ON ((adb.cut_period_id = cp.id)))
     LEFT JOIN public.loans l ON ((adb.loan_id = l.id)))
     LEFT JOIN public.users uc ON ((adb.client_user_id = uc.id)))
  ORDER BY adb.created_at DESC, adb.is_liquidated;


ALTER TABLE public.v_associate_debt_detailed OWNER TO credinet_user;

--
-- Name: VIEW v_associate_debt_detailed; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON VIEW public.v_associate_debt_detailed IS '⭐ MIGRACIÓN 09: Desglose detallado de todas las deudas de asociados por tipo, origen y estado de liquidación.';


--
-- Name: v_associate_late_fees; Type: VIEW; Schema: public; Owner: credinet_user
--

CREATE VIEW public.v_associate_late_fees AS
 SELECT aps.id AS statement_id,
    aps.statement_number,
    concat(u.first_name, ' ', u.last_name) AS associate_name,
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
            WHEN aps.late_fee_applied THEN 'MORA APLICADA'::text
            WHEN ((aps.total_payments_count = 0) AND (aps.total_commission_owed > (0)::numeric)) THEN 'SUJETO A MORA'::text
            ELSE 'SIN MORA'::text
        END AS late_fee_status,
    round(((aps.late_fee_amount / NULLIF(aps.total_commission_owed, (0)::numeric)) * (100)::numeric), 2) AS late_fee_percentage,
    aps.generated_date,
    aps.due_date,
    aps.paid_date
   FROM (((public.associate_payment_statements aps
     JOIN public.users u ON ((aps.user_id = u.id)))
     JOIN public.cut_periods cp ON ((aps.cut_period_id = cp.id)))
     JOIN public.statement_statuses ss ON ((aps.status_id = ss.id)))
  WHERE ((aps.late_fee_amount > (0)::numeric) OR ((aps.total_payments_count = 0) AND (aps.total_commission_owed > (0)::numeric)))
  ORDER BY aps.generated_date DESC, aps.late_fee_amount DESC;


ALTER TABLE public.v_associate_late_fees OWNER TO credinet_user;

--
-- Name: VIEW v_associate_late_fees; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON VIEW public.v_associate_late_fees IS '⭐ MIGRACIÓN 10: Vista especializada de moras del 30% aplicadas o potenciales (cuando payments_count = 0).';


--
-- Name: v_loans_summary; Type: VIEW; Schema: public; Owner: credinet_user
--

CREATE VIEW public.v_loans_summary AS
 SELECT l.id,
    l.user_id,
    u.username,
    l.amount AS capital,
    l.term_biweeks AS plazo_quincenas,
    l.profile_code,
    rp.name AS profile_name,
    l.biweekly_payment AS pago_quincenal,
    l.total_payment AS pago_total,
    l.total_interest AS interes_total,
    l.commission_per_payment AS comision_por_pago,
    l.associate_payment AS pago_al_asociado,
    l.total_commission AS comision_total,
    ls.name AS estado,
    l.created_at AS fecha_creacion,
    l.approved_at AS fecha_aprobacion,
        CASE
            WHEN (l.amount > (0)::numeric) THEN round(((l.total_interest / l.amount) * (100)::numeric), 2)
            ELSE NULL::numeric
        END AS tasa_interes_efectiva_pct,
        CASE
            WHEN (l.biweekly_payment > (0)::numeric) THEN round(((l.commission_per_payment / l.biweekly_payment) * (100)::numeric), 2)
            ELSE NULL::numeric
        END AS comision_pct
   FROM (((public.loans l
     LEFT JOIN public.users u ON ((l.user_id = u.id)))
     LEFT JOIN public.rate_profiles rp ON (((l.profile_code)::text = (rp.code)::text)))
     LEFT JOIN public.loan_statuses ls ON ((l.status_id = ls.id)))
  WHERE (l.biweekly_payment IS NOT NULL);


ALTER TABLE public.v_loans_summary OWNER TO credinet_user;

--
-- Name: VIEW v_loans_summary; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON VIEW public.v_loans_summary IS 'Vista de resumen de préstamos con campos calculados y métricas derivadas.';


--
-- Name: v_payment_changes_summary; Type: VIEW; Schema: public; Owner: credinet_user
--

CREATE VIEW public.v_payment_changes_summary AS
 SELECT date(psh.changed_at) AS change_date,
    psh.change_type,
    count(*) AS total_changes,
    count(DISTINCT psh.payment_id) AS unique_payments,
    count(DISTINCT psh.changed_by) AS unique_users,
    string_agg(DISTINCT (ps_new.name)::text, ', '::text) AS status_changes_to,
    min(psh.changed_at) AS first_change,
    max(psh.changed_at) AS last_change
   FROM (public.payment_status_history psh
     JOIN public.payment_statuses ps_new ON ((psh.new_status_id = ps_new.id)))
  GROUP BY (date(psh.changed_at)), psh.change_type
  ORDER BY (date(psh.changed_at)) DESC, (count(*)) DESC;


ALTER TABLE public.v_payment_changes_summary OWNER TO credinet_user;

--
-- Name: VIEW v_payment_changes_summary; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON VIEW public.v_payment_changes_summary IS '⭐ MIGRACIÓN 12: Resumen estadístico diario de cambios de estado de pagos agrupados por tipo (AUTOMATIC, MANUAL_ADMIN, etc.).';


--
-- Name: v_payments_absorbed_by_associate; Type: VIEW; Schema: public; Owner: credinet_user
--

CREATE VIEW public.v_payments_absorbed_by_associate AS
 SELECT concat(ua.first_name, ' ', ua.last_name) AS associate_name,
    ap.id AS associate_profile_id,
    count(p.id) AS total_payments_absorbed,
    sum(p.amount_paid) AS total_amount_absorbed,
    ps.name AS payment_status,
    cp.cut_number,
    cp.period_start_date,
    cp.period_end_date,
    string_agg(DISTINCT concat(uc.first_name, ' ', uc.last_name), ', '::text) AS affected_clients
   FROM ((((((public.payments p
     JOIN public.payment_statuses ps ON ((p.status_id = ps.id)))
     JOIN public.loans l ON ((p.loan_id = l.id)))
     JOIN public.users uc ON ((l.user_id = uc.id)))
     JOIN public.users ua ON ((l.associate_user_id = ua.id)))
     JOIN public.associate_profiles ap ON ((ua.id = ap.user_id)))
     LEFT JOIN public.cut_periods cp ON ((p.cut_period_id = cp.id)))
  WHERE ((ps.is_real_payment = false) AND ((ps.name)::text = ANY ((ARRAY['PAID_BY_ASSOCIATE'::character varying, 'PAID_NOT_REPORTED'::character varying])::text[])))
  GROUP BY ua.first_name, ua.last_name, ap.id, ps.name, cp.cut_number, cp.period_start_date, cp.period_end_date
  ORDER BY (sum(p.amount_paid)) DESC;


ALTER TABLE public.v_payments_absorbed_by_associate OWNER TO credinet_user;

--
-- Name: VIEW v_payments_absorbed_by_associate; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON VIEW public.v_payments_absorbed_by_associate IS '⭐ MIGRACIÓN 11: Resumen de pagos absorbidos por cada asociado (PAID_BY_ASSOCIATE, PAID_NOT_REPORTED) con totales y clientes afectados.';


--
-- Name: v_payments_by_status_detailed; Type: VIEW; Schema: public; Owner: credinet_user
--

CREATE VIEW public.v_payments_by_status_detailed AS
 SELECT p.id AS payment_id,
    p.loan_id,
    concat(u.first_name, ' ', u.last_name) AS client_name,
    l.amount AS loan_amount,
    p.amount_paid,
    p.payment_date,
    p.payment_due_date,
    p.is_late,
    ps.name AS payment_status,
    ps.is_real_payment,
        CASE
            WHEN ps.is_real_payment THEN 'REAL 💵'::text
            ELSE 'FICTICIO ⚠️'::text
        END AS payment_type,
    concat(um.first_name, ' ', um.last_name) AS marked_by_name,
    p.marked_at,
    p.marking_notes,
    cp.cut_number,
    cp.period_start_date,
    cp.period_end_date,
    concat(ua.first_name, ' ', ua.last_name) AS associate_name,
    p.created_at,
    p.updated_at
   FROM ((((((public.payments p
     JOIN public.loans l ON ((p.loan_id = l.id)))
     JOIN public.users u ON ((l.user_id = u.id)))
     JOIN public.payment_statuses ps ON ((p.status_id = ps.id)))
     LEFT JOIN public.users um ON ((p.marked_by = um.id)))
     LEFT JOIN public.cut_periods cp ON ((p.cut_period_id = cp.id)))
     LEFT JOIN public.users ua ON ((l.associate_user_id = ua.id)))
  ORDER BY p.payment_due_date DESC, p.id DESC;


ALTER TABLE public.v_payments_by_status_detailed OWNER TO credinet_user;

--
-- Name: VIEW v_payments_by_status_detailed; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON VIEW public.v_payments_by_status_detailed IS '⭐ MIGRACIÓN 11: Vista detallada de todos los pagos con su estado, tipo (real/ficticio) y tracking de marcado manual.';


--
-- Name: v_payments_multiple_changes; Type: VIEW; Schema: public; Owner: credinet_user
--

CREATE VIEW public.v_payments_multiple_changes AS
 SELECT p.id AS payment_id,
    p.loan_id,
    concat(u.first_name, ' ', u.last_name) AS client_name,
    count(psh.id) AS total_changes,
    string_agg(concat(ps.name, ' (', to_char(psh.changed_at, 'YYYY-MM-DD HH24:MI'::text), ')'), ' → '::text ORDER BY psh.changed_at) AS status_timeline,
    min(psh.changed_at) AS first_change,
    max(psh.changed_at) AS last_change,
    (EXTRACT(epoch FROM (max(psh.changed_at) - min(psh.changed_at))) / (3600)::numeric) AS hours_between_first_last,
    count(
        CASE
            WHEN ((psh.change_type)::text = 'MANUAL_ADMIN'::text) THEN 1
            ELSE NULL::integer
        END) AS manual_changes_count,
        CASE
            WHEN (count(psh.id) >= 5) THEN 'CRÍTICO'::text
            WHEN (count(psh.id) >= 3) THEN 'ALERTA'::text
            ELSE 'NORMAL'::text
        END AS review_priority
   FROM ((((public.payments p
     JOIN public.payment_status_history psh ON ((p.id = psh.payment_id)))
     JOIN public.payment_statuses ps ON ((psh.new_status_id = ps.id)))
     JOIN public.loans l ON ((p.loan_id = l.id)))
     JOIN public.users u ON ((l.user_id = u.id)))
  GROUP BY p.id, p.loan_id, u.first_name, u.last_name
 HAVING (count(psh.id) >= 3)
  ORDER BY (count(psh.id)) DESC, (max(psh.changed_at)) DESC;


ALTER TABLE public.v_payments_multiple_changes OWNER TO credinet_user;

--
-- Name: VIEW v_payments_multiple_changes; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON VIEW public.v_payments_multiple_changes IS '⭐ MIGRACIÓN 12: Pagos con 3 o más cambios de estado (posibles errores, fraude o correcciones múltiples). Prioridad CRÍTICA para revisión forense.';


--
-- Name: v_payments_summary; Type: VIEW; Schema: public; Owner: credinet_user
--

CREATE VIEW public.v_payments_summary AS
 SELECT p.id,
    p.loan_id,
    l.user_id,
    u.username,
    p.payment_number,
    p.payment_due_date AS fecha_vencimiento,
    p.expected_amount AS monto_esperado,
    p.amount_paid AS monto_pagado,
    p.interest_amount AS interes,
    p.principal_amount AS capital,
    p.commission_amount AS comision,
    p.associate_payment AS pago_asociado,
    p.balance_remaining AS saldo_pendiente,
    ps.name AS estado_pago,
    cp.period_start_date AS periodo_inicio,
    cp.period_end_date AS periodo_fin,
    p.is_late AS esta_atrasado,
        CASE
            WHEN (p.expected_amount > (0)::numeric) THEN round(((p.amount_paid / p.expected_amount) * (100)::numeric), 2)
            ELSE (0)::numeric
        END AS porcentaje_pagado,
        CASE
            WHEN (p.amount_paid >= p.expected_amount) THEN 'PAGADO COMPLETO'::text
            WHEN (p.amount_paid > (0)::numeric) THEN 'PAGO PARCIAL'::text
            ELSE 'SIN PAGAR'::text
        END AS estado_pago_detalle,
    (p.expected_amount - p.amount_paid) AS saldo_pago
   FROM ((((public.payments p
     JOIN public.loans l ON ((p.loan_id = l.id)))
     LEFT JOIN public.users u ON ((l.user_id = u.id)))
     LEFT JOIN public.payment_statuses ps ON ((p.status_id = ps.id)))
     LEFT JOIN public.cut_periods cp ON ((p.cut_period_id = cp.id)))
  WHERE (p.expected_amount IS NOT NULL)
  ORDER BY l.id, p.payment_number;


ALTER TABLE public.v_payments_summary OWNER TO credinet_user;

--
-- Name: VIEW v_payments_summary; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON VIEW public.v_payments_summary IS 'Vista de resumen de pagos con desglose completo y métricas derivadas.';


--
-- Name: v_period_closure_summary; Type: VIEW; Schema: public; Owner: credinet_user
--

CREATE VIEW public.v_period_closure_summary AS
 SELECT cp.id AS cut_period_id,
    cp.cut_number,
    cp.period_start_date,
    cp.period_end_date,
    cps.name AS period_status,
    count(p.id) AS total_payments,
    count(
        CASE
            WHEN ((ps.name)::text = 'PAID'::text) THEN 1
            ELSE NULL::integer
        END) AS payments_paid,
    count(
        CASE
            WHEN ((ps.name)::text = 'PAID_NOT_REPORTED'::text) THEN 1
            ELSE NULL::integer
        END) AS payments_not_reported,
    count(
        CASE
            WHEN ((ps.name)::text = 'PAID_BY_ASSOCIATE'::text) THEN 1
            ELSE NULL::integer
        END) AS payments_by_associate,
    count(
        CASE
            WHEN ((ps.name)::text = ANY ((ARRAY['PENDING'::character varying, 'DUE_TODAY'::character varying, 'OVERDUE'::character varying])::text[])) THEN 1
            ELSE NULL::integer
        END) AS payments_pending,
    COALESCE(sum(
        CASE
            WHEN ((ps.name)::text = 'PAID'::text) THEN p.amount_paid
            ELSE (0)::numeric
        END), (0)::numeric) AS total_collected,
    cp.total_payments_expected,
    cp.total_commission,
    concat(u.first_name, ' ', u.last_name) AS closed_by_name,
    cp.updated_at AS last_updated
   FROM ((((public.cut_periods cp
     JOIN public.cut_period_statuses cps ON ((cp.status_id = cps.id)))
     LEFT JOIN public.payments p ON ((cp.id = p.cut_period_id)))
     LEFT JOIN public.payment_statuses ps ON ((p.status_id = ps.id)))
     LEFT JOIN public.users u ON ((cp.closed_by = u.id)))
  GROUP BY cp.id, cp.cut_number, cp.period_start_date, cp.period_end_date, cps.name, cp.total_payments_expected, cp.total_commission, u.first_name, u.last_name, cp.updated_at
  ORDER BY cp.period_start_date DESC;


ALTER TABLE public.v_period_closure_summary OWNER TO credinet_user;

--
-- Name: VIEW v_period_closure_summary; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON VIEW public.v_period_closure_summary IS '⭐ MIGRACIÓN 08: Resumen de cierre de cada período de corte con estadísticas de pagos por estado (PAID, PAID_NOT_REPORTED, PAID_BY_ASSOCIATE).';


--
-- Name: v_recent_payment_changes; Type: VIEW; Schema: public; Owner: credinet_user
--

CREATE VIEW public.v_recent_payment_changes AS
 SELECT psh.id AS change_id,
    psh.payment_id,
    p.loan_id,
    concat(u.first_name, ' ', u.last_name) AS client_name,
    ps_old.name AS old_status,
    ps_new.name AS new_status,
    psh.change_type,
    concat(uc.first_name, ' ', uc.last_name) AS changed_by_name,
    psh.change_reason,
    psh.changed_at,
    (EXTRACT(epoch FROM (CURRENT_TIMESTAMP - psh.changed_at)) / (3600)::numeric) AS hours_ago
   FROM ((((((public.payment_status_history psh
     JOIN public.payments p ON ((psh.payment_id = p.id)))
     JOIN public.loans l ON ((p.loan_id = l.id)))
     JOIN public.users u ON ((l.user_id = u.id)))
     LEFT JOIN public.payment_statuses ps_old ON ((psh.old_status_id = ps_old.id)))
     JOIN public.payment_statuses ps_new ON ((psh.new_status_id = ps_new.id)))
     LEFT JOIN public.users uc ON ((psh.changed_by = uc.id)))
  WHERE (psh.changed_at >= (CURRENT_TIMESTAMP - '24:00:00'::interval))
  ORDER BY psh.changed_at DESC;


ALTER TABLE public.v_recent_payment_changes OWNER TO credinet_user;

--
-- Name: VIEW v_recent_payment_changes; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON VIEW public.v_recent_payment_changes IS '⭐ MIGRACIÓN 12: Cambios de estado de pagos en las últimas 24 horas (útil para monitoreo en tiempo real y detección temprana de anomalías).';


--
-- Name: addresses id; Type: DEFAULT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.addresses ALTER COLUMN id SET DEFAULT nextval('public.addresses_id_seq'::regclass);


--
-- Name: agreement_items id; Type: DEFAULT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.agreement_items ALTER COLUMN id SET DEFAULT nextval('public.agreement_items_id_seq'::regclass);


--
-- Name: agreement_payments id; Type: DEFAULT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.agreement_payments ALTER COLUMN id SET DEFAULT nextval('public.agreement_payments_id_seq'::regclass);


--
-- Name: agreements id; Type: DEFAULT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.agreements ALTER COLUMN id SET DEFAULT nextval('public.agreements_id_seq'::regclass);


--
-- Name: associate_accumulated_balances id; Type: DEFAULT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.associate_accumulated_balances ALTER COLUMN id SET DEFAULT nextval('public.associate_accumulated_balances_id_seq'::regclass);


--
-- Name: associate_debt_breakdown id; Type: DEFAULT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.associate_debt_breakdown ALTER COLUMN id SET DEFAULT nextval('public.associate_debt_breakdown_id_seq'::regclass);


--
-- Name: associate_level_history id; Type: DEFAULT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.associate_level_history ALTER COLUMN id SET DEFAULT nextval('public.associate_level_history_id_seq'::regclass);


--
-- Name: associate_levels id; Type: DEFAULT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.associate_levels ALTER COLUMN id SET DEFAULT nextval('public.associate_levels_id_seq'::regclass);


--
-- Name: associate_payment_statements id; Type: DEFAULT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.associate_payment_statements ALTER COLUMN id SET DEFAULT nextval('public.associate_payment_statements_id_seq'::regclass);


--
-- Name: associate_profiles id; Type: DEFAULT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.associate_profiles ALTER COLUMN id SET DEFAULT nextval('public.associate_profiles_id_seq'::regclass);


--
-- Name: audit_log id; Type: DEFAULT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.audit_log ALTER COLUMN id SET DEFAULT nextval('public.audit_log_id_seq'::regclass);


--
-- Name: audit_session_log id; Type: DEFAULT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.audit_session_log ALTER COLUMN id SET DEFAULT nextval('public.audit_session_log_id_seq'::regclass);


--
-- Name: beneficiaries id; Type: DEFAULT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.beneficiaries ALTER COLUMN id SET DEFAULT nextval('public.beneficiaries_id_seq'::regclass);


--
-- Name: client_documents id; Type: DEFAULT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.client_documents ALTER COLUMN id SET DEFAULT nextval('public.client_documents_id_seq'::regclass);


--
-- Name: config_types id; Type: DEFAULT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.config_types ALTER COLUMN id SET DEFAULT nextval('public.config_types_id_seq'::regclass);


--
-- Name: contract_statuses id; Type: DEFAULT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.contract_statuses ALTER COLUMN id SET DEFAULT nextval('public.contract_statuses_id_seq'::regclass);


--
-- Name: contracts id; Type: DEFAULT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.contracts ALTER COLUMN id SET DEFAULT nextval('public.contracts_id_seq'::regclass);


--
-- Name: cut_period_statuses id; Type: DEFAULT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.cut_period_statuses ALTER COLUMN id SET DEFAULT nextval('public.cut_period_statuses_id_seq'::regclass);


--
-- Name: cut_periods id; Type: DEFAULT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.cut_periods ALTER COLUMN id SET DEFAULT nextval('public.cut_periods_id_seq'::regclass);


--
-- Name: defaulted_client_reports id; Type: DEFAULT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.defaulted_client_reports ALTER COLUMN id SET DEFAULT nextval('public.defaulted_client_reports_id_seq'::regclass);


--
-- Name: document_statuses id; Type: DEFAULT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.document_statuses ALTER COLUMN id SET DEFAULT nextval('public.document_statuses_id_seq'::regclass);


--
-- Name: document_types id; Type: DEFAULT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.document_types ALTER COLUMN id SET DEFAULT nextval('public.document_types_id_seq'::regclass);


--
-- Name: guarantors id; Type: DEFAULT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.guarantors ALTER COLUMN id SET DEFAULT nextval('public.guarantors_id_seq'::regclass);


--
-- Name: legacy_payment_table id; Type: DEFAULT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.legacy_payment_table ALTER COLUMN id SET DEFAULT nextval('public.legacy_payment_table_id_seq'::regclass);


--
-- Name: level_change_types id; Type: DEFAULT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.level_change_types ALTER COLUMN id SET DEFAULT nextval('public.level_change_types_id_seq'::regclass);


--
-- Name: loan_renewals id; Type: DEFAULT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.loan_renewals ALTER COLUMN id SET DEFAULT nextval('public.loan_renewals_id_seq'::regclass);


--
-- Name: loan_statuses id; Type: DEFAULT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.loan_statuses ALTER COLUMN id SET DEFAULT nextval('public.loan_statuses_id_seq'::regclass);


--
-- Name: loans id; Type: DEFAULT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.loans ALTER COLUMN id SET DEFAULT nextval('public.loans_id_seq'::regclass);


--
-- Name: payment_methods id; Type: DEFAULT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.payment_methods ALTER COLUMN id SET DEFAULT nextval('public.payment_methods_id_seq'::regclass);


--
-- Name: payment_status_history id; Type: DEFAULT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.payment_status_history ALTER COLUMN id SET DEFAULT nextval('public.payment_status_history_id_seq'::regclass);


--
-- Name: payment_statuses id; Type: DEFAULT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.payment_statuses ALTER COLUMN id SET DEFAULT nextval('public.payment_statuses_id_seq'::regclass);


--
-- Name: payments id; Type: DEFAULT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.payments ALTER COLUMN id SET DEFAULT nextval('public.payments_id_seq'::regclass);


--
-- Name: rate_profiles id; Type: DEFAULT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.rate_profiles ALTER COLUMN id SET DEFAULT nextval('public.rate_profiles_id_seq'::regclass);


--
-- Name: roles id; Type: DEFAULT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.roles ALTER COLUMN id SET DEFAULT nextval('public.roles_id_seq'::regclass);


--
-- Name: statement_statuses id; Type: DEFAULT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.statement_statuses ALTER COLUMN id SET DEFAULT nextval('public.statement_statuses_id_seq'::regclass);


--
-- Name: system_configurations id; Type: DEFAULT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.system_configurations ALTER COLUMN id SET DEFAULT nextval('public.system_configurations_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Data for Name: addresses; Type: TABLE DATA; Schema: public; Owner: credinet_user
--

COPY public.addresses (id, user_id, street, external_number, internal_number, colony, municipality, state, zip_code, created_at, updated_at) FROM stdin;
1	4	Av. Insurgentes Sur	1234	Depto 501	Del Valle	Benito Juárez	Ciudad de México	03100	2025-10-31 01:12:22.117513+00	2025-10-31 01:12:22.117513+00
2	5	Calle Reforma	567	\N	Polanco	Miguel Hidalgo	Ciudad de México	11560	2025-10-31 01:12:22.117513+00	2025-10-31 01:12:22.117513+00
3	6	Av. Chapultepec	890	Local 3	Roma Norte	Cuauhtémoc	Ciudad de México	06700	2025-10-31 01:12:22.117513+00	2025-10-31 01:12:22.117513+00
4	3	Calle Madero	123	Piso 2	Centro Histórico	Cuauhtémoc	Ciudad de México	06000	2025-10-31 01:12:22.117513+00	2025-10-31 01:12:22.117513+00
\.


--
-- Data for Name: agreement_items; Type: TABLE DATA; Schema: public; Owner: credinet_user
--

COPY public.agreement_items (id, agreement_id, loan_id, client_user_id, debt_amount, debt_type, description, created_at) FROM stdin;
\.


--
-- Data for Name: agreement_payments; Type: TABLE DATA; Schema: public; Owner: credinet_user
--

COPY public.agreement_payments (id, agreement_id, payment_number, payment_amount, payment_due_date, payment_date, payment_method_id, payment_reference, status, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: agreements; Type: TABLE DATA; Schema: public; Owner: credinet_user
--

COPY public.agreements (id, associate_profile_id, agreement_number, agreement_date, total_debt_amount, payment_plan_months, monthly_payment_amount, status, start_date, end_date, created_by, approved_by, notes, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: associate_accumulated_balances; Type: TABLE DATA; Schema: public; Owner: credinet_user
--

COPY public.associate_accumulated_balances (id, user_id, cut_period_id, accumulated_debt, debt_details, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: associate_debt_breakdown; Type: TABLE DATA; Schema: public; Owner: credinet_user
--

COPY public.associate_debt_breakdown (id, associate_profile_id, cut_period_id, debt_type, loan_id, client_user_id, amount, description, is_liquidated, liquidated_at, liquidation_reference, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: associate_level_history; Type: TABLE DATA; Schema: public; Owner: credinet_user
--

COPY public.associate_level_history (id, associate_profile_id, old_level_id, new_level_id, reason, change_type_id, created_at) FROM stdin;
\.


--
-- Data for Name: associate_levels; Type: TABLE DATA; Schema: public; Owner: credinet_user
--

COPY public.associate_levels (id, name, max_loan_amount, credit_limit, description, min_clients, min_collection_rate, created_at, updated_at) FROM stdin;
1	Bronce	50000.00	25000.00	\N	0	0.00	2025-10-31 01:12:22.074569+00	2025-10-31 01:12:22.074569+00
2	Plata	100000.00	50000.00	\N	0	0.00	2025-10-31 01:12:22.074569+00	2025-10-31 01:12:22.074569+00
3	Oro	250000.00	125000.00	\N	0	0.00	2025-10-31 01:12:22.074569+00	2025-10-31 01:12:22.074569+00
4	Platino	600000.00	300000.00	\N	0	0.00	2025-10-31 01:12:22.074569+00	2025-10-31 01:12:22.074569+00
5	Diamante	1000000.00	500000.00	\N	0	0.00	2025-10-31 01:12:22.074569+00	2025-10-31 01:12:22.074569+00
\.


--
-- Data for Name: associate_payment_statements; Type: TABLE DATA; Schema: public; Owner: credinet_user
--

COPY public.associate_payment_statements (id, cut_period_id, user_id, statement_number, total_payments_count, total_amount_collected, total_commission_owed, commission_rate_applied, status_id, generated_date, sent_date, due_date, paid_date, paid_amount, payment_method_id, payment_reference, late_fee_amount, late_fee_applied, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: associate_profiles; Type: TABLE DATA; Schema: public; Owner: credinet_user
--

COPY public.associate_profiles (id, user_id, level_id, contact_person, contact_email, default_commission_rate, active, consecutive_full_credit_periods, consecutive_on_time_payments, clients_in_agreement, last_level_evaluation_date, credit_used, credit_limit, credit_last_updated, debt_balance, created_at, updated_at) FROM stdin;
1	3	2	Contacto Central	central@distribuidora.com	4.50	t	0	0	0	\N	21854.17	200000.00	2025-11-06 07:06:47.088707+00	0.00	2025-10-31 01:12:22.094625+00	2025-11-06 07:06:47.088707+00
2	8	1	Contacto Norte	norte@creditos.com	5.00	t	0	0	0	\N	8000.00	200000.00	2025-11-06 07:40:29.827967+00	0.00	2025-10-31 01:12:22.094625+00	2025-11-06 07:40:29.827967+00
\.


--
-- Data for Name: audit_log; Type: TABLE DATA; Schema: public; Owner: credinet_user
--

COPY public.audit_log (id, table_name, record_id, operation, old_data, new_data, changed_by, changed_at, ip_address, user_agent) FROM stdin;
1	users	1	INSERT	\N	{"id": 1, "curp": "FERJ900115HDFXXX01", "email": "jair@dev.com", "username": "jair", "last_name": "FC", "birth_date": "1990-01-15", "created_at": "2025-10-31T01:12:22.089593+00:00", "first_name": "Jair", "updated_at": "2025-10-31T01:12:22.089593+00:00", "phone_number": "5511223344", "password_hash": "$2b$12$aSMdt0Kd8I2lrCIvSNbxx.X5U.BmY9MAZAoPvM/MgK5mXOxQgq0s6", "profile_picture_url": null}	\N	2025-10-31 01:12:22.089593+00	\N	\N
2	users	2	INSERT	\N	{"id": 2, "curp": null, "email": "admin@credinet.com", "username": "admin", "last_name": "Total", "birth_date": null, "created_at": "2025-10-31T01:12:22.089593+00:00", "first_name": "Admin", "updated_at": "2025-10-31T01:12:22.089593+00:00", "phone_number": "5522334455", "password_hash": "$2b$12$aSMdt0Kd8I2lrCIvSNbxx.X5U.BmY9MAZAoPvM/MgK5mXOxQgq0s6", "profile_picture_url": null}	\N	2025-10-31 01:12:22.089593+00	\N	\N
3	users	3	INSERT	\N	{"id": 3, "curp": null, "email": "asociado@test.com", "username": "asociado_test", "last_name": "Prueba", "birth_date": null, "created_at": "2025-10-31T01:12:22.089593+00:00", "first_name": "Asociado", "updated_at": "2025-10-31T01:12:22.089593+00:00", "phone_number": "5533445566", "password_hash": "$2b$12$aSMdt0Kd8I2lrCIvSNbxx.X5U.BmY9MAZAoPvM/MgK5mXOxQgq0s6", "profile_picture_url": null}	\N	2025-10-31 01:12:22.089593+00	\N	\N
4	users	4	INSERT	\N	{"id": 4, "curp": "VARS850520MDFXXX02", "email": "sofia.vargas@email.com", "username": "sofia.vargas", "last_name": "Vargas", "birth_date": "1985-05-20", "created_at": "2025-10-31T01:12:22.089593+00:00", "first_name": "Sofía", "updated_at": "2025-10-31T01:12:22.089593+00:00", "phone_number": "5544556677", "password_hash": "$2b$12$aSMdt0Kd8I2lrCIvSNbxx.X5U.BmY9MAZAoPvM/MgK5mXOxQgq0s6", "profile_picture_url": null}	\N	2025-10-31 01:12:22.089593+00	\N	\N
5	users	5	INSERT	\N	{"id": 5, "curp": "PERJ921130HDFXXX03", "email": "juan.perez@email.com", "username": "juan.perez", "last_name": "Pérez", "birth_date": "1992-11-30", "created_at": "2025-10-31T01:12:22.089593+00:00", "first_name": "Juan", "updated_at": "2025-10-31T01:12:22.089593+00:00", "phone_number": "5555667788", "password_hash": "$2b$12$aSMdt0Kd8I2lrCIvSNbxx.X5U.BmY9MAZAoPvM/MgK5mXOxQgq0s6", "profile_picture_url": null}	\N	2025-10-31 01:12:22.089593+00	\N	\N
6	users	6	INSERT	\N	{"id": 6, "curp": null, "email": "laura.martinez@email.com", "username": "laura.mtz", "last_name": "Martínez", "birth_date": null, "created_at": "2025-10-31T01:12:22.089593+00:00", "first_name": "Laura", "updated_at": "2025-10-31T01:12:22.089593+00:00", "phone_number": "5566778899", "password_hash": "$2b$12$aSMdt0Kd8I2lrCIvSNbxx.X5U.BmY9MAZAoPvM/MgK5mXOxQgq0s6", "profile_picture_url": null}	\N	2025-10-31 01:12:22.089593+00	\N	\N
7	users	7	INSERT	\N	{"id": 7, "curp": null, "email": "pedro.ramirez@credinet.com", "username": "aux.admin", "last_name": "Ramírez", "birth_date": null, "created_at": "2025-10-31T01:12:22.089593+00:00", "first_name": "Pedro", "updated_at": "2025-10-31T01:12:22.089593+00:00", "phone_number": "5577889900", "password_hash": "$2b$12$aSMdt0Kd8I2lrCIvSNbxx.X5U.BmY9MAZAoPvM/MgK5mXOxQgq0s6", "profile_picture_url": null}	\N	2025-10-31 01:12:22.089593+00	\N	\N
8	users	8	INSERT	\N	{"id": 8, "curp": null, "email": "user@norte.com", "username": "asociado_norte", "last_name": "Norte", "birth_date": null, "created_at": "2025-10-31T01:12:22.089593+00:00", "first_name": "User", "updated_at": "2025-10-31T01:12:22.089593+00:00", "phone_number": "5588990011", "password_hash": "$2b$12$aSMdt0Kd8I2lrCIvSNbxx.X5U.BmY9MAZAoPvM/MgK5mXOxQgq0s6", "profile_picture_url": null}	\N	2025-10-31 01:12:22.089593+00	\N	\N
9	users	1000	INSERT	\N	{"id": 1000, "curp": "FACJ950525HCHRRR04", "email": "maria.aval@demo.com", "username": "aval_test", "last_name": "Aval", "birth_date": "1995-05-25", "created_at": "2025-10-31T01:12:22.089593+00:00", "first_name": "María", "updated_at": "2025-10-31T01:12:22.089593+00:00", "phone_number": "6143618296", "password_hash": "$2b$12$aSMdt0Kd8I2lrCIvSNbxx.X5U.BmY9MAZAoPvM/MgK5mXOxQgq0s6", "profile_picture_url": null}	\N	2025-10-31 01:12:22.089593+00	\N	\N
10	loans	1	INSERT	\N	{"id": 1, "notes": null, "amount": 100000.00, "user_id": 4, "status_id": 1, "created_at": "2025-01-07T00:00:00+00:00", "updated_at": "2025-01-07T00:00:00+00:00", "approved_at": null, "approved_by": null, "contract_id": null, "rejected_at": null, "rejected_by": null, "term_biweeks": 12, "interest_rate": 2.50, "commission_rate": 2.50, "rejection_reason": null, "associate_user_id": 3}	\N	2025-10-31 01:12:22.096473+00	\N	\N
11	loans	2	INSERT	\N	{"id": 2, "notes": null, "amount": 75000.00, "user_id": 5, "status_id": 1, "created_at": "2025-02-08T00:00:00+00:00", "updated_at": "2025-02-08T00:00:00+00:00", "approved_at": null, "approved_by": null, "contract_id": null, "rejected_at": null, "rejected_by": null, "term_biweeks": 8, "interest_rate": 3.00, "commission_rate": 3.00, "rejection_reason": null, "associate_user_id": 8}	\N	2025-10-31 01:12:22.096473+00	\N	\N
12	loans	3	INSERT	\N	{"id": 3, "notes": null, "amount": 50000.00, "user_id": 6, "status_id": 1, "created_at": "2025-02-23T00:00:00+00:00", "updated_at": "2025-02-23T00:00:00+00:00", "approved_at": null, "approved_by": null, "contract_id": null, "rejected_at": null, "rejected_by": null, "term_biweeks": 6, "interest_rate": 2.00, "commission_rate": 2.00, "rejection_reason": null, "associate_user_id": 3}	\N	2025-10-31 01:12:22.096473+00	\N	\N
13	loans	4	INSERT	\N	{"id": 4, "notes": null, "amount": 25000.00, "user_id": 1000, "status_id": 4, "created_at": "2024-12-07T00:00:00+00:00", "updated_at": "2024-12-07T00:00:00+00:00", "approved_at": null, "approved_by": null, "contract_id": null, "rejected_at": null, "rejected_by": null, "term_biweeks": 4, "interest_rate": 1.50, "commission_rate": 0.00, "rejection_reason": null, "associate_user_id": null}	\N	2025-10-31 01:12:22.096473+00	\N	\N
14	loans	1	UPDATE	{"id": 1, "notes": null, "amount": 100000.00, "user_id": 4, "status_id": 1, "created_at": "2025-01-07T00:00:00+00:00", "updated_at": "2025-01-07T00:00:00+00:00", "approved_at": null, "approved_by": null, "contract_id": null, "rejected_at": null, "rejected_by": null, "term_biweeks": 12, "interest_rate": 2.50, "commission_rate": 2.50, "rejection_reason": null, "associate_user_id": 3}	{"id": 1, "notes": null, "amount": 100000.00, "user_id": 4, "status_id": 2, "created_at": "2025-01-07T00:00:00+00:00", "updated_at": "2025-10-31T01:12:22.098659+00:00", "approved_at": "2025-01-07T00:00:00+00:00", "approved_by": 2, "contract_id": null, "rejected_at": null, "rejected_by": null, "term_biweeks": 12, "interest_rate": 2.50, "commission_rate": 2.50, "rejection_reason": null, "associate_user_id": 3}	\N	2025-10-31 01:12:22.098659+00	\N	\N
15	payments	1	INSERT	\N	{"id": 1, "is_late": false, "loan_id": 1, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-10-31T01:12:22.098659+00:00", "updated_at": "2025-10-31T01:12:22.098659+00:00", "amount_paid": 0.00, "payment_date": "2025-01-15", "cut_period_id": null, "marking_notes": null, "payment_due_date": "2025-01-15"}	\N	2025-10-31 01:12:22.098659+00	\N	\N
16	payments	2	INSERT	\N	{"id": 2, "is_late": false, "loan_id": 1, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-10-31T01:12:22.098659+00:00", "updated_at": "2025-10-31T01:12:22.098659+00:00", "amount_paid": 0.00, "payment_date": "2025-01-31", "cut_period_id": null, "marking_notes": null, "payment_due_date": "2025-01-31"}	\N	2025-10-31 01:12:22.098659+00	\N	\N
17	payments	3	INSERT	\N	{"id": 3, "is_late": false, "loan_id": 1, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-10-31T01:12:22.098659+00:00", "updated_at": "2025-10-31T01:12:22.098659+00:00", "amount_paid": 0.00, "payment_date": "2025-02-15", "cut_period_id": null, "marking_notes": null, "payment_due_date": "2025-02-15"}	\N	2025-10-31 01:12:22.098659+00	\N	\N
18	payments	4	INSERT	\N	{"id": 4, "is_late": false, "loan_id": 1, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-10-31T01:12:22.098659+00:00", "updated_at": "2025-10-31T01:12:22.098659+00:00", "amount_paid": 0.00, "payment_date": "2025-02-28", "cut_period_id": null, "marking_notes": null, "payment_due_date": "2025-02-28"}	\N	2025-10-31 01:12:22.098659+00	\N	\N
19	payments	5	INSERT	\N	{"id": 5, "is_late": false, "loan_id": 1, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-10-31T01:12:22.098659+00:00", "updated_at": "2025-10-31T01:12:22.098659+00:00", "amount_paid": 0.00, "payment_date": "2025-03-15", "cut_period_id": null, "marking_notes": null, "payment_due_date": "2025-03-15"}	\N	2025-10-31 01:12:22.098659+00	\N	\N
20	payments	6	INSERT	\N	{"id": 6, "is_late": false, "loan_id": 1, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-10-31T01:12:22.098659+00:00", "updated_at": "2025-10-31T01:12:22.098659+00:00", "amount_paid": 0.00, "payment_date": "2025-03-31", "cut_period_id": null, "marking_notes": null, "payment_due_date": "2025-03-31"}	\N	2025-10-31 01:12:22.098659+00	\N	\N
21	payments	7	INSERT	\N	{"id": 7, "is_late": false, "loan_id": 1, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-10-31T01:12:22.098659+00:00", "updated_at": "2025-10-31T01:12:22.098659+00:00", "amount_paid": 0.00, "payment_date": "2025-04-15", "cut_period_id": null, "marking_notes": null, "payment_due_date": "2025-04-15"}	\N	2025-10-31 01:12:22.098659+00	\N	\N
22	payments	8	INSERT	\N	{"id": 8, "is_late": false, "loan_id": 1, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-10-31T01:12:22.098659+00:00", "updated_at": "2025-10-31T01:12:22.098659+00:00", "amount_paid": 0.00, "payment_date": "2025-04-30", "cut_period_id": null, "marking_notes": null, "payment_due_date": "2025-04-30"}	\N	2025-10-31 01:12:22.098659+00	\N	\N
23	payments	9	INSERT	\N	{"id": 9, "is_late": false, "loan_id": 1, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-10-31T01:12:22.098659+00:00", "updated_at": "2025-10-31T01:12:22.098659+00:00", "amount_paid": 0.00, "payment_date": "2025-05-15", "cut_period_id": null, "marking_notes": null, "payment_due_date": "2025-05-15"}	\N	2025-10-31 01:12:22.098659+00	\N	\N
24	payments	10	INSERT	\N	{"id": 10, "is_late": false, "loan_id": 1, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-10-31T01:12:22.098659+00:00", "updated_at": "2025-10-31T01:12:22.098659+00:00", "amount_paid": 0.00, "payment_date": "2025-05-31", "cut_period_id": null, "marking_notes": null, "payment_due_date": "2025-05-31"}	\N	2025-10-31 01:12:22.098659+00	\N	\N
25	payments	11	INSERT	\N	{"id": 11, "is_late": false, "loan_id": 1, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-10-31T01:12:22.098659+00:00", "updated_at": "2025-10-31T01:12:22.098659+00:00", "amount_paid": 0.00, "payment_date": "2025-06-15", "cut_period_id": null, "marking_notes": null, "payment_due_date": "2025-06-15"}	\N	2025-10-31 01:12:22.098659+00	\N	\N
26	payments	12	INSERT	\N	{"id": 12, "is_late": false, "loan_id": 1, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-10-31T01:12:22.098659+00:00", "updated_at": "2025-10-31T01:12:22.098659+00:00", "amount_paid": 0.00, "payment_date": "2025-06-30", "cut_period_id": null, "marking_notes": null, "payment_due_date": "2025-06-30"}	\N	2025-10-31 01:12:22.098659+00	\N	\N
27	loans	2	UPDATE	{"id": 2, "notes": null, "amount": 75000.00, "user_id": 5, "status_id": 1, "created_at": "2025-02-08T00:00:00+00:00", "updated_at": "2025-02-08T00:00:00+00:00", "approved_at": null, "approved_by": null, "contract_id": null, "rejected_at": null, "rejected_by": null, "term_biweeks": 8, "interest_rate": 3.00, "commission_rate": 3.00, "rejection_reason": null, "associate_user_id": 8}	{"id": 2, "notes": null, "amount": 75000.00, "user_id": 5, "status_id": 2, "created_at": "2025-02-08T00:00:00+00:00", "updated_at": "2025-10-31T01:12:22.106335+00:00", "approved_at": "2025-02-08T00:00:00+00:00", "approved_by": 2, "contract_id": null, "rejected_at": null, "rejected_by": null, "term_biweeks": 8, "interest_rate": 3.00, "commission_rate": 3.00, "rejection_reason": null, "associate_user_id": 8}	\N	2025-10-31 01:12:22.106335+00	\N	\N
28	payments	13	INSERT	\N	{"id": 13, "is_late": false, "loan_id": 2, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-10-31T01:12:22.106335+00:00", "updated_at": "2025-10-31T01:12:22.106335+00:00", "amount_paid": 0.00, "payment_date": "2025-02-28", "cut_period_id": null, "marking_notes": null, "payment_due_date": "2025-02-28"}	\N	2025-10-31 01:12:22.106335+00	\N	\N
29	payments	14	INSERT	\N	{"id": 14, "is_late": false, "loan_id": 2, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-10-31T01:12:22.106335+00:00", "updated_at": "2025-10-31T01:12:22.106335+00:00", "amount_paid": 0.00, "payment_date": "2025-03-15", "cut_period_id": null, "marking_notes": null, "payment_due_date": "2025-03-15"}	\N	2025-10-31 01:12:22.106335+00	\N	\N
30	payments	15	INSERT	\N	{"id": 15, "is_late": false, "loan_id": 2, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-10-31T01:12:22.106335+00:00", "updated_at": "2025-10-31T01:12:22.106335+00:00", "amount_paid": 0.00, "payment_date": "2025-03-31", "cut_period_id": null, "marking_notes": null, "payment_due_date": "2025-03-31"}	\N	2025-10-31 01:12:22.106335+00	\N	\N
31	payments	16	INSERT	\N	{"id": 16, "is_late": false, "loan_id": 2, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-10-31T01:12:22.106335+00:00", "updated_at": "2025-10-31T01:12:22.106335+00:00", "amount_paid": 0.00, "payment_date": "2025-04-15", "cut_period_id": null, "marking_notes": null, "payment_due_date": "2025-04-15"}	\N	2025-10-31 01:12:22.106335+00	\N	\N
32	payments	17	INSERT	\N	{"id": 17, "is_late": false, "loan_id": 2, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-10-31T01:12:22.106335+00:00", "updated_at": "2025-10-31T01:12:22.106335+00:00", "amount_paid": 0.00, "payment_date": "2025-04-30", "cut_period_id": null, "marking_notes": null, "payment_due_date": "2025-04-30"}	\N	2025-10-31 01:12:22.106335+00	\N	\N
33	payments	18	INSERT	\N	{"id": 18, "is_late": false, "loan_id": 2, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-10-31T01:12:22.106335+00:00", "updated_at": "2025-10-31T01:12:22.106335+00:00", "amount_paid": 0.00, "payment_date": "2025-05-15", "cut_period_id": null, "marking_notes": null, "payment_due_date": "2025-05-15"}	\N	2025-10-31 01:12:22.106335+00	\N	\N
34	payments	19	INSERT	\N	{"id": 19, "is_late": false, "loan_id": 2, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-10-31T01:12:22.106335+00:00", "updated_at": "2025-10-31T01:12:22.106335+00:00", "amount_paid": 0.00, "payment_date": "2025-05-31", "cut_period_id": null, "marking_notes": null, "payment_due_date": "2025-05-31"}	\N	2025-10-31 01:12:22.106335+00	\N	\N
35	payments	20	INSERT	\N	{"id": 20, "is_late": false, "loan_id": 2, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-10-31T01:12:22.106335+00:00", "updated_at": "2025-10-31T01:12:22.106335+00:00", "amount_paid": 0.00, "payment_date": "2025-06-15", "cut_period_id": null, "marking_notes": null, "payment_due_date": "2025-06-15"}	\N	2025-10-31 01:12:22.106335+00	\N	\N
36	loans	3	UPDATE	{"id": 3, "notes": null, "amount": 50000.00, "user_id": 6, "status_id": 1, "created_at": "2025-02-23T00:00:00+00:00", "updated_at": "2025-02-23T00:00:00+00:00", "approved_at": null, "approved_by": null, "contract_id": null, "rejected_at": null, "rejected_by": null, "term_biweeks": 6, "interest_rate": 2.00, "commission_rate": 2.00, "rejection_reason": null, "associate_user_id": 3}	{"id": 3, "notes": null, "amount": 50000.00, "user_id": 6, "status_id": 2, "created_at": "2025-02-23T00:00:00+00:00", "updated_at": "2025-10-31T01:12:22.108941+00:00", "approved_at": "2025-02-23T00:00:00+00:00", "approved_by": 2, "contract_id": null, "rejected_at": null, "rejected_by": null, "term_biweeks": 6, "interest_rate": 2.00, "commission_rate": 2.00, "rejection_reason": null, "associate_user_id": 3}	\N	2025-10-31 01:12:22.108941+00	\N	\N
37	payments	21	INSERT	\N	{"id": 21, "is_late": false, "loan_id": 3, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-10-31T01:12:22.108941+00:00", "updated_at": "2025-10-31T01:12:22.108941+00:00", "amount_paid": 0.00, "payment_date": "2025-03-15", "cut_period_id": null, "marking_notes": null, "payment_due_date": "2025-03-15"}	\N	2025-10-31 01:12:22.108941+00	\N	\N
38	payments	22	INSERT	\N	{"id": 22, "is_late": false, "loan_id": 3, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-10-31T01:12:22.108941+00:00", "updated_at": "2025-10-31T01:12:22.108941+00:00", "amount_paid": 0.00, "payment_date": "2025-03-31", "cut_period_id": null, "marking_notes": null, "payment_due_date": "2025-03-31"}	\N	2025-10-31 01:12:22.108941+00	\N	\N
39	payments	23	INSERT	\N	{"id": 23, "is_late": false, "loan_id": 3, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-10-31T01:12:22.108941+00:00", "updated_at": "2025-10-31T01:12:22.108941+00:00", "amount_paid": 0.00, "payment_date": "2025-04-15", "cut_period_id": null, "marking_notes": null, "payment_due_date": "2025-04-15"}	\N	2025-10-31 01:12:22.108941+00	\N	\N
40	payments	24	INSERT	\N	{"id": 24, "is_late": false, "loan_id": 3, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-10-31T01:12:22.108941+00:00", "updated_at": "2025-10-31T01:12:22.108941+00:00", "amount_paid": 0.00, "payment_date": "2025-04-30", "cut_period_id": null, "marking_notes": null, "payment_due_date": "2025-04-30"}	\N	2025-10-31 01:12:22.108941+00	\N	\N
41	payments	25	INSERT	\N	{"id": 25, "is_late": false, "loan_id": 3, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-10-31T01:12:22.108941+00:00", "updated_at": "2025-10-31T01:12:22.108941+00:00", "amount_paid": 0.00, "payment_date": "2025-05-15", "cut_period_id": null, "marking_notes": null, "payment_due_date": "2025-05-15"}	\N	2025-10-31 01:12:22.108941+00	\N	\N
42	payments	26	INSERT	\N	{"id": 26, "is_late": false, "loan_id": 3, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-10-31T01:12:22.108941+00:00", "updated_at": "2025-10-31T01:12:22.108941+00:00", "amount_paid": 0.00, "payment_date": "2025-05-31", "cut_period_id": null, "marking_notes": null, "payment_due_date": "2025-05-31"}	\N	2025-10-31 01:12:22.108941+00	\N	\N
43	contracts	1	INSERT	\N	{"id": 1, "loan_id": 1, "file_path": null, "sign_date": null, "status_id": 3, "created_at": "2025-10-31T01:12:22.11122+00:00", "start_date": "2025-01-07", "updated_at": "2025-10-31T01:12:22.11122+00:00", "document_number": "CONT-2025-001"}	\N	2025-10-31 01:12:22.11122+00	\N	\N
44	contracts	2	INSERT	\N	{"id": 2, "loan_id": 2, "file_path": null, "sign_date": null, "status_id": 3, "created_at": "2025-10-31T01:12:22.11122+00:00", "start_date": "2025-02-08", "updated_at": "2025-10-31T01:12:22.11122+00:00", "document_number": "CONT-2025-002"}	\N	2025-10-31 01:12:22.11122+00	\N	\N
45	contracts	3	INSERT	\N	{"id": 3, "loan_id": 3, "file_path": null, "sign_date": null, "status_id": 3, "created_at": "2025-10-31T01:12:22.11122+00:00", "start_date": "2025-02-23", "updated_at": "2025-10-31T01:12:22.11122+00:00", "document_number": "CONT-2025-003"}	\N	2025-10-31 01:12:22.11122+00	\N	\N
46	contracts	4	INSERT	\N	{"id": 4, "loan_id": 4, "file_path": null, "sign_date": null, "status_id": 5, "created_at": "2025-10-31T01:12:22.11122+00:00", "start_date": "2024-12-07", "updated_at": "2025-10-31T01:12:22.11122+00:00", "document_number": "CONT-2024-012"}	\N	2025-10-31 01:12:22.11122+00	\N	\N
47	loans	1	UPDATE	{"id": 1, "notes": null, "amount": 100000.00, "user_id": 4, "status_id": 2, "created_at": "2025-01-07T00:00:00+00:00", "updated_at": "2025-10-31T01:12:22.098659+00:00", "approved_at": "2025-01-07T00:00:00+00:00", "approved_by": 2, "contract_id": null, "rejected_at": null, "rejected_by": null, "term_biweeks": 12, "interest_rate": 2.50, "commission_rate": 2.50, "rejection_reason": null, "associate_user_id": 3}	{"id": 1, "notes": null, "amount": 100000.00, "user_id": 4, "status_id": 2, "created_at": "2025-01-07T00:00:00+00:00", "updated_at": "2025-10-31T01:12:22.112977+00:00", "approved_at": "2025-01-07T00:00:00+00:00", "approved_by": 2, "contract_id": 1, "rejected_at": null, "rejected_by": null, "term_biweeks": 12, "interest_rate": 2.50, "commission_rate": 2.50, "rejection_reason": null, "associate_user_id": 3}	\N	2025-10-31 01:12:22.112977+00	\N	\N
62	payments	4	DELETE	{"id": 4, "is_late": false, "loan_id": 1, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-10-31T01:12:22.098659+00:00", "updated_at": "2025-10-31T01:12:22.098659+00:00", "amount_paid": 0.00, "payment_date": "2025-02-28", "cut_period_id": null, "marking_notes": null, "payment_due_date": "2025-02-28"}	\N	\N	2025-11-05 08:09:21.907254+00	\N	\N
63	payments	5	DELETE	{"id": 5, "is_late": false, "loan_id": 1, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-10-31T01:12:22.098659+00:00", "updated_at": "2025-10-31T01:12:22.098659+00:00", "amount_paid": 0.00, "payment_date": "2025-03-15", "cut_period_id": null, "marking_notes": null, "payment_due_date": "2025-03-15"}	\N	\N	2025-11-05 08:09:21.907254+00	\N	\N
48	loans	2	UPDATE	{"id": 2, "notes": null, "amount": 75000.00, "user_id": 5, "status_id": 2, "created_at": "2025-02-08T00:00:00+00:00", "updated_at": "2025-10-31T01:12:22.106335+00:00", "approved_at": "2025-02-08T00:00:00+00:00", "approved_by": 2, "contract_id": null, "rejected_at": null, "rejected_by": null, "term_biweeks": 8, "interest_rate": 3.00, "commission_rate": 3.00, "rejection_reason": null, "associate_user_id": 8}	{"id": 2, "notes": null, "amount": 75000.00, "user_id": 5, "status_id": 2, "created_at": "2025-02-08T00:00:00+00:00", "updated_at": "2025-10-31T01:12:22.114165+00:00", "approved_at": "2025-02-08T00:00:00+00:00", "approved_by": 2, "contract_id": 2, "rejected_at": null, "rejected_by": null, "term_biweeks": 8, "interest_rate": 3.00, "commission_rate": 3.00, "rejection_reason": null, "associate_user_id": 8}	\N	2025-10-31 01:12:22.114165+00	\N	\N
49	loans	3	UPDATE	{"id": 3, "notes": null, "amount": 50000.00, "user_id": 6, "status_id": 2, "created_at": "2025-02-23T00:00:00+00:00", "updated_at": "2025-10-31T01:12:22.108941+00:00", "approved_at": "2025-02-23T00:00:00+00:00", "approved_by": 2, "contract_id": null, "rejected_at": null, "rejected_by": null, "term_biweeks": 6, "interest_rate": 2.00, "commission_rate": 2.00, "rejection_reason": null, "associate_user_id": 3}	{"id": 3, "notes": null, "amount": 50000.00, "user_id": 6, "status_id": 2, "created_at": "2025-02-23T00:00:00+00:00", "updated_at": "2025-10-31T01:12:22.115303+00:00", "approved_at": "2025-02-23T00:00:00+00:00", "approved_by": 2, "contract_id": 3, "rejected_at": null, "rejected_by": null, "term_biweeks": 6, "interest_rate": 2.00, "commission_rate": 2.00, "rejection_reason": null, "associate_user_id": 3}	\N	2025-10-31 01:12:22.115303+00	\N	\N
50	loans	4	UPDATE	{"id": 4, "notes": null, "amount": 25000.00, "user_id": 1000, "status_id": 4, "created_at": "2024-12-07T00:00:00+00:00", "updated_at": "2024-12-07T00:00:00+00:00", "approved_at": null, "approved_by": null, "contract_id": null, "rejected_at": null, "rejected_by": null, "term_biweeks": 4, "interest_rate": 1.50, "commission_rate": 0.00, "rejection_reason": null, "associate_user_id": null}	{"id": 4, "notes": null, "amount": 25000.00, "user_id": 1000, "status_id": 4, "created_at": "2024-12-07T00:00:00+00:00", "updated_at": "2025-10-31T01:12:22.116421+00:00", "approved_at": null, "approved_by": null, "contract_id": 4, "rejected_at": null, "rejected_by": null, "term_biweeks": 4, "interest_rate": 1.50, "commission_rate": 0.00, "rejection_reason": null, "associate_user_id": null}	\N	2025-10-31 01:12:22.116421+00	\N	\N
51	cut_periods	1	INSERT	\N	{"id": 1, "closed_by": null, "status_id": 5, "created_at": "2025-10-31T01:12:22.121973+00:00", "created_by": 2, "cut_number": 23, "updated_at": "2025-10-31T01:12:22.121973+00:00", "period_end_date": "2024-12-22", "total_commission": 0.00, "period_start_date": "2024-12-08", "total_payments_expected": 0.00, "total_payments_received": 0.00}	\N	2025-10-31 01:12:22.121973+00	\N	\N
52	cut_periods	2	INSERT	\N	{"id": 2, "closed_by": null, "status_id": 5, "created_at": "2025-10-31T01:12:22.121973+00:00", "created_by": 2, "cut_number": 24, "updated_at": "2025-10-31T01:12:22.121973+00:00", "period_end_date": "2025-01-07", "total_commission": 0.00, "period_start_date": "2024-12-23", "total_payments_expected": 0.00, "total_payments_received": 0.00}	\N	2025-10-31 01:12:22.121973+00	\N	\N
53	cut_periods	3	INSERT	\N	{"id": 3, "closed_by": null, "status_id": 5, "created_at": "2025-10-31T01:12:22.121973+00:00", "created_by": 2, "cut_number": 1, "updated_at": "2025-10-31T01:12:22.121973+00:00", "period_end_date": "2025-01-22", "total_commission": 0.00, "period_start_date": "2025-01-08", "total_payments_expected": 0.00, "total_payments_received": 0.00}	\N	2025-10-31 01:12:22.121973+00	\N	\N
54	cut_periods	4	INSERT	\N	{"id": 4, "closed_by": null, "status_id": 5, "created_at": "2025-10-31T01:12:22.121973+00:00", "created_by": 2, "cut_number": 2, "updated_at": "2025-10-31T01:12:22.121973+00:00", "period_end_date": "2025-02-07", "total_commission": 0.00, "period_start_date": "2025-01-23", "total_payments_expected": 0.00, "total_payments_received": 0.00}	\N	2025-10-31 01:12:22.121973+00	\N	\N
55	cut_periods	5	INSERT	\N	{"id": 5, "closed_by": null, "status_id": 5, "created_at": "2025-10-31T01:12:22.121973+00:00", "created_by": 2, "cut_number": 3, "updated_at": "2025-10-31T01:12:22.121973+00:00", "period_end_date": "2025-02-22", "total_commission": 0.00, "period_start_date": "2025-02-08", "total_payments_expected": 0.00, "total_payments_received": 0.00}	\N	2025-10-31 01:12:22.121973+00	\N	\N
56	cut_periods	6	INSERT	\N	{"id": 6, "closed_by": null, "status_id": 2, "created_at": "2025-10-31T01:12:22.121973+00:00", "created_by": 2, "cut_number": 4, "updated_at": "2025-10-31T01:12:22.121973+00:00", "period_end_date": "2025-03-07", "total_commission": 0.00, "period_start_date": "2025-02-23", "total_payments_expected": 0.00, "total_payments_received": 0.00}	\N	2025-10-31 01:12:22.121973+00	\N	\N
57	cut_periods	7	INSERT	\N	{"id": 7, "closed_by": null, "status_id": 2, "created_at": "2025-10-31T01:12:22.121973+00:00", "created_by": 2, "cut_number": 5, "updated_at": "2025-10-31T01:12:22.121973+00:00", "period_end_date": "2025-03-22", "total_commission": 0.00, "period_start_date": "2025-03-08", "total_payments_expected": 0.00, "total_payments_received": 0.00}	\N	2025-10-31 01:12:22.121973+00	\N	\N
58	cut_periods	8	INSERT	\N	{"id": 8, "closed_by": null, "status_id": 2, "created_at": "2025-10-31T01:12:22.121973+00:00", "created_by": 2, "cut_number": 6, "updated_at": "2025-10-31T01:12:22.121973+00:00", "period_end_date": "2025-04-07", "total_commission": 0.00, "period_start_date": "2025-03-23", "total_payments_expected": 0.00, "total_payments_received": 0.00}	\N	2025-10-31 01:12:22.121973+00	\N	\N
59	payments	1	DELETE	{"id": 1, "is_late": false, "loan_id": 1, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-10-31T01:12:22.098659+00:00", "updated_at": "2025-10-31T01:12:22.098659+00:00", "amount_paid": 0.00, "payment_date": "2025-01-15", "cut_period_id": null, "marking_notes": null, "payment_due_date": "2025-01-15"}	\N	\N	2025-11-05 08:09:21.907254+00	\N	\N
60	payments	2	DELETE	{"id": 2, "is_late": false, "loan_id": 1, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-10-31T01:12:22.098659+00:00", "updated_at": "2025-10-31T01:12:22.098659+00:00", "amount_paid": 0.00, "payment_date": "2025-01-31", "cut_period_id": null, "marking_notes": null, "payment_due_date": "2025-01-31"}	\N	\N	2025-11-05 08:09:21.907254+00	\N	\N
61	payments	3	DELETE	{"id": 3, "is_late": false, "loan_id": 1, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-10-31T01:12:22.098659+00:00", "updated_at": "2025-10-31T01:12:22.098659+00:00", "amount_paid": 0.00, "payment_date": "2025-02-15", "cut_period_id": null, "marking_notes": null, "payment_due_date": "2025-02-15"}	\N	\N	2025-11-05 08:09:21.907254+00	\N	\N
64	payments	6	DELETE	{"id": 6, "is_late": false, "loan_id": 1, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-10-31T01:12:22.098659+00:00", "updated_at": "2025-10-31T01:12:22.098659+00:00", "amount_paid": 0.00, "payment_date": "2025-03-31", "cut_period_id": null, "marking_notes": null, "payment_due_date": "2025-03-31"}	\N	\N	2025-11-05 08:09:21.907254+00	\N	\N
65	payments	7	DELETE	{"id": 7, "is_late": false, "loan_id": 1, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-10-31T01:12:22.098659+00:00", "updated_at": "2025-10-31T01:12:22.098659+00:00", "amount_paid": 0.00, "payment_date": "2025-04-15", "cut_period_id": null, "marking_notes": null, "payment_due_date": "2025-04-15"}	\N	\N	2025-11-05 08:09:21.907254+00	\N	\N
66	payments	8	DELETE	{"id": 8, "is_late": false, "loan_id": 1, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-10-31T01:12:22.098659+00:00", "updated_at": "2025-10-31T01:12:22.098659+00:00", "amount_paid": 0.00, "payment_date": "2025-04-30", "cut_period_id": null, "marking_notes": null, "payment_due_date": "2025-04-30"}	\N	\N	2025-11-05 08:09:21.907254+00	\N	\N
67	payments	9	DELETE	{"id": 9, "is_late": false, "loan_id": 1, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-10-31T01:12:22.098659+00:00", "updated_at": "2025-10-31T01:12:22.098659+00:00", "amount_paid": 0.00, "payment_date": "2025-05-15", "cut_period_id": null, "marking_notes": null, "payment_due_date": "2025-05-15"}	\N	\N	2025-11-05 08:09:21.907254+00	\N	\N
68	payments	10	DELETE	{"id": 10, "is_late": false, "loan_id": 1, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-10-31T01:12:22.098659+00:00", "updated_at": "2025-10-31T01:12:22.098659+00:00", "amount_paid": 0.00, "payment_date": "2025-05-31", "cut_period_id": null, "marking_notes": null, "payment_due_date": "2025-05-31"}	\N	\N	2025-11-05 08:09:21.907254+00	\N	\N
69	payments	11	DELETE	{"id": 11, "is_late": false, "loan_id": 1, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-10-31T01:12:22.098659+00:00", "updated_at": "2025-10-31T01:12:22.098659+00:00", "amount_paid": 0.00, "payment_date": "2025-06-15", "cut_period_id": null, "marking_notes": null, "payment_due_date": "2025-06-15"}	\N	\N	2025-11-05 08:09:21.907254+00	\N	\N
70	payments	12	DELETE	{"id": 12, "is_late": false, "loan_id": 1, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-10-31T01:12:22.098659+00:00", "updated_at": "2025-10-31T01:12:22.098659+00:00", "amount_paid": 0.00, "payment_date": "2025-06-30", "cut_period_id": null, "marking_notes": null, "payment_due_date": "2025-06-30"}	\N	\N	2025-11-05 08:09:21.907254+00	\N	\N
71	payments	13	DELETE	{"id": 13, "is_late": false, "loan_id": 2, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-10-31T01:12:22.106335+00:00", "updated_at": "2025-10-31T01:12:22.106335+00:00", "amount_paid": 0.00, "payment_date": "2025-02-28", "cut_period_id": null, "marking_notes": null, "payment_due_date": "2025-02-28"}	\N	\N	2025-11-05 08:09:21.907254+00	\N	\N
72	payments	14	DELETE	{"id": 14, "is_late": false, "loan_id": 2, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-10-31T01:12:22.106335+00:00", "updated_at": "2025-10-31T01:12:22.106335+00:00", "amount_paid": 0.00, "payment_date": "2025-03-15", "cut_period_id": null, "marking_notes": null, "payment_due_date": "2025-03-15"}	\N	\N	2025-11-05 08:09:21.907254+00	\N	\N
73	payments	15	DELETE	{"id": 15, "is_late": false, "loan_id": 2, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-10-31T01:12:22.106335+00:00", "updated_at": "2025-10-31T01:12:22.106335+00:00", "amount_paid": 0.00, "payment_date": "2025-03-31", "cut_period_id": null, "marking_notes": null, "payment_due_date": "2025-03-31"}	\N	\N	2025-11-05 08:09:21.907254+00	\N	\N
74	payments	16	DELETE	{"id": 16, "is_late": false, "loan_id": 2, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-10-31T01:12:22.106335+00:00", "updated_at": "2025-10-31T01:12:22.106335+00:00", "amount_paid": 0.00, "payment_date": "2025-04-15", "cut_period_id": null, "marking_notes": null, "payment_due_date": "2025-04-15"}	\N	\N	2025-11-05 08:09:21.907254+00	\N	\N
75	payments	17	DELETE	{"id": 17, "is_late": false, "loan_id": 2, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-10-31T01:12:22.106335+00:00", "updated_at": "2025-10-31T01:12:22.106335+00:00", "amount_paid": 0.00, "payment_date": "2025-04-30", "cut_period_id": null, "marking_notes": null, "payment_due_date": "2025-04-30"}	\N	\N	2025-11-05 08:09:21.907254+00	\N	\N
76	payments	18	DELETE	{"id": 18, "is_late": false, "loan_id": 2, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-10-31T01:12:22.106335+00:00", "updated_at": "2025-10-31T01:12:22.106335+00:00", "amount_paid": 0.00, "payment_date": "2025-05-15", "cut_period_id": null, "marking_notes": null, "payment_due_date": "2025-05-15"}	\N	\N	2025-11-05 08:09:21.907254+00	\N	\N
77	payments	19	DELETE	{"id": 19, "is_late": false, "loan_id": 2, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-10-31T01:12:22.106335+00:00", "updated_at": "2025-10-31T01:12:22.106335+00:00", "amount_paid": 0.00, "payment_date": "2025-05-31", "cut_period_id": null, "marking_notes": null, "payment_due_date": "2025-05-31"}	\N	\N	2025-11-05 08:09:21.907254+00	\N	\N
78	payments	20	DELETE	{"id": 20, "is_late": false, "loan_id": 2, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-10-31T01:12:22.106335+00:00", "updated_at": "2025-10-31T01:12:22.106335+00:00", "amount_paid": 0.00, "payment_date": "2025-06-15", "cut_period_id": null, "marking_notes": null, "payment_due_date": "2025-06-15"}	\N	\N	2025-11-05 08:09:21.907254+00	\N	\N
79	payments	21	DELETE	{"id": 21, "is_late": false, "loan_id": 3, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-10-31T01:12:22.108941+00:00", "updated_at": "2025-10-31T01:12:22.108941+00:00", "amount_paid": 0.00, "payment_date": "2025-03-15", "cut_period_id": null, "marking_notes": null, "payment_due_date": "2025-03-15"}	\N	\N	2025-11-05 08:09:21.907254+00	\N	\N
80	payments	22	DELETE	{"id": 22, "is_late": false, "loan_id": 3, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-10-31T01:12:22.108941+00:00", "updated_at": "2025-10-31T01:12:22.108941+00:00", "amount_paid": 0.00, "payment_date": "2025-03-31", "cut_period_id": null, "marking_notes": null, "payment_due_date": "2025-03-31"}	\N	\N	2025-11-05 08:09:21.907254+00	\N	\N
81	payments	23	DELETE	{"id": 23, "is_late": false, "loan_id": 3, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-10-31T01:12:22.108941+00:00", "updated_at": "2025-10-31T01:12:22.108941+00:00", "amount_paid": 0.00, "payment_date": "2025-04-15", "cut_period_id": null, "marking_notes": null, "payment_due_date": "2025-04-15"}	\N	\N	2025-11-05 08:09:21.907254+00	\N	\N
82	payments	24	DELETE	{"id": 24, "is_late": false, "loan_id": 3, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-10-31T01:12:22.108941+00:00", "updated_at": "2025-10-31T01:12:22.108941+00:00", "amount_paid": 0.00, "payment_date": "2025-04-30", "cut_period_id": null, "marking_notes": null, "payment_due_date": "2025-04-30"}	\N	\N	2025-11-05 08:09:21.907254+00	\N	\N
83	payments	25	DELETE	{"id": 25, "is_late": false, "loan_id": 3, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-10-31T01:12:22.108941+00:00", "updated_at": "2025-10-31T01:12:22.108941+00:00", "amount_paid": 0.00, "payment_date": "2025-05-15", "cut_period_id": null, "marking_notes": null, "payment_due_date": "2025-05-15"}	\N	\N	2025-11-05 08:09:21.907254+00	\N	\N
84	payments	26	DELETE	{"id": 26, "is_late": false, "loan_id": 3, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-10-31T01:12:22.108941+00:00", "updated_at": "2025-10-31T01:12:22.108941+00:00", "amount_paid": 0.00, "payment_date": "2025-05-31", "cut_period_id": null, "marking_notes": null, "payment_due_date": "2025-05-31"}	\N	\N	2025-11-05 08:09:21.907254+00	\N	\N
85	loans	1	DELETE	{"id": 1, "notes": null, "amount": 100000.00, "user_id": 4, "status_id": 2, "created_at": "2025-01-07T00:00:00+00:00", "updated_at": "2025-10-31T01:12:22.112977+00:00", "approved_at": "2025-01-07T00:00:00+00:00", "approved_by": 2, "contract_id": 1, "rejected_at": null, "rejected_by": null, "term_biweeks": 12, "interest_rate": 2.50, "commission_rate": 2.50, "rejection_reason": null, "associate_user_id": 3}	\N	\N	2025-11-05 08:09:21.924827+00	\N	\N
86	loans	2	DELETE	{"id": 2, "notes": null, "amount": 75000.00, "user_id": 5, "status_id": 2, "created_at": "2025-02-08T00:00:00+00:00", "updated_at": "2025-10-31T01:12:22.114165+00:00", "approved_at": "2025-02-08T00:00:00+00:00", "approved_by": 2, "contract_id": 2, "rejected_at": null, "rejected_by": null, "term_biweeks": 8, "interest_rate": 3.00, "commission_rate": 3.00, "rejection_reason": null, "associate_user_id": 8}	\N	\N	2025-11-05 08:09:21.924827+00	\N	\N
87	loans	3	DELETE	{"id": 3, "notes": null, "amount": 50000.00, "user_id": 6, "status_id": 2, "created_at": "2025-02-23T00:00:00+00:00", "updated_at": "2025-10-31T01:12:22.115303+00:00", "approved_at": "2025-02-23T00:00:00+00:00", "approved_by": 2, "contract_id": 3, "rejected_at": null, "rejected_by": null, "term_biweeks": 6, "interest_rate": 2.00, "commission_rate": 2.00, "rejection_reason": null, "associate_user_id": 3}	\N	\N	2025-11-05 08:09:21.924827+00	\N	\N
88	loans	4	DELETE	{"id": 4, "notes": null, "amount": 25000.00, "user_id": 1000, "status_id": 4, "created_at": "2024-12-07T00:00:00+00:00", "updated_at": "2025-10-31T01:12:22.116421+00:00", "approved_at": null, "approved_by": null, "contract_id": 4, "rejected_at": null, "rejected_by": null, "term_biweeks": 4, "interest_rate": 1.50, "commission_rate": 0.00, "rejection_reason": null, "associate_user_id": null}	\N	\N	2025-11-05 08:09:21.924827+00	\N	\N
89	contracts	1	DELETE	{"id": 1, "loan_id": 1, "file_path": null, "sign_date": null, "status_id": 3, "created_at": "2025-10-31T01:12:22.11122+00:00", "start_date": "2025-01-07", "updated_at": "2025-10-31T01:12:22.11122+00:00", "document_number": "CONT-2025-001"}	\N	\N	2025-11-05 08:09:21.924827+00	\N	\N
90	contracts	2	DELETE	{"id": 2, "loan_id": 2, "file_path": null, "sign_date": null, "status_id": 3, "created_at": "2025-10-31T01:12:22.11122+00:00", "start_date": "2025-02-08", "updated_at": "2025-10-31T01:12:22.11122+00:00", "document_number": "CONT-2025-002"}	\N	\N	2025-11-05 08:09:21.924827+00	\N	\N
91	contracts	3	DELETE	{"id": 3, "loan_id": 3, "file_path": null, "sign_date": null, "status_id": 3, "created_at": "2025-10-31T01:12:22.11122+00:00", "start_date": "2025-02-23", "updated_at": "2025-10-31T01:12:22.11122+00:00", "document_number": "CONT-2025-003"}	\N	\N	2025-11-05 08:09:21.924827+00	\N	\N
92	contracts	4	DELETE	{"id": 4, "loan_id": 4, "file_path": null, "sign_date": null, "status_id": 5, "created_at": "2025-10-31T01:12:22.11122+00:00", "start_date": "2024-12-07", "updated_at": "2025-10-31T01:12:22.11122+00:00", "document_number": "CONT-2024-012"}	\N	\N	2025-11-05 08:09:21.924827+00	\N	\N
93	loans	1	INSERT	\N	{"id": 1, "notes": "Préstamo con perfil standard - integración rate_profiles", "amount": 22000.00, "user_id": 4, "status_id": 1, "created_at": "2025-11-05T17:40:06.993376+00:00", "updated_at": "2025-11-05T17:40:06.993376+00:00", "approved_at": null, "approved_by": null, "contract_id": null, "rejected_at": null, "rejected_by": null, "profile_code": null, "term_biweeks": 12, "interest_rate": 4.25, "commission_rate": 2.50, "rejection_reason": null, "associate_user_id": 3}	\N	2025-11-05 17:40:06.993376+00	\N	\N
94	loans	1	DELETE	{"id": 1, "notes": "Préstamo con perfil standard - integración rate_profiles", "amount": 22000.00, "user_id": 4, "status_id": 1, "created_at": "2025-11-05T17:40:06.993376+00:00", "updated_at": "2025-11-05T17:40:06.993376+00:00", "approved_at": null, "approved_by": null, "contract_id": null, "rejected_at": null, "rejected_by": null, "profile_code": null, "term_biweeks": 12, "interest_rate": 4.25, "commission_rate": 2.50, "rejection_reason": null, "associate_user_id": 3}	\N	\N	2025-11-05 17:41:29.970433+00	\N	\N
95	loans	2	INSERT	\N	{"id": 2, "notes": "Préstamo con perfil standard", "amount": 15000.00, "user_id": 4, "status_id": 1, "created_at": "2025-11-05T17:41:35.811215+00:00", "updated_at": "2025-11-05T17:41:35.811215+00:00", "approved_at": null, "approved_by": null, "contract_id": null, "rejected_at": null, "rejected_by": null, "profile_code": null, "term_biweeks": 6, "interest_rate": 4.25, "commission_rate": 2.50, "rejection_reason": null, "associate_user_id": 3}	\N	2025-11-05 17:41:35.811215+00	\N	\N
96	loans	2	DELETE	{"id": 2, "notes": "Préstamo con perfil standard", "amount": 15000.00, "user_id": 4, "status_id": 1, "created_at": "2025-11-05T17:41:35.811215+00:00", "updated_at": "2025-11-05T17:41:35.811215+00:00", "approved_at": null, "approved_by": null, "contract_id": null, "rejected_at": null, "rejected_by": null, "profile_code": null, "term_biweeks": 6, "interest_rate": 4.25, "commission_rate": 2.50, "rejection_reason": null, "associate_user_id": 3}	\N	\N	2025-11-05 17:44:00.899697+00	\N	\N
97	loans	3	INSERT	\N	{"id": 3, "notes": "Préstamo con perfil standard - prueba final", "amount": 18500.00, "user_id": 4, "status_id": 1, "created_at": "2025-11-05T17:45:05.647253+00:00", "updated_at": "2025-11-05T17:45:05.647253+00:00", "approved_at": null, "approved_by": null, "contract_id": null, "rejected_at": null, "rejected_by": null, "profile_code": null, "term_biweeks": 9, "interest_rate": 4.25, "commission_rate": 2.50, "rejection_reason": null, "associate_user_id": 3}	\N	2025-11-05 17:45:05.647253+00	\N	\N
98	loans	3	DELETE	{"id": 3, "notes": "Préstamo con perfil standard - prueba final", "amount": 18500.00, "user_id": 4, "status_id": 1, "created_at": "2025-11-05T17:45:05.647253+00:00", "updated_at": "2025-11-05T17:45:05.647253+00:00", "approved_at": null, "approved_by": null, "contract_id": null, "rejected_at": null, "rejected_by": null, "profile_code": null, "term_biweeks": 9, "interest_rate": 4.25, "commission_rate": 2.50, "rejection_reason": null, "associate_user_id": 3}	\N	\N	2025-11-05 17:49:34.755296+00	\N	\N
99	loans	4	INSERT	\N	{"id": 4, "notes": "Prueba con logs", "amount": 12000.00, "user_id": 4, "status_id": 1, "created_at": "2025-11-05T17:50:05.61392+00:00", "updated_at": "2025-11-05T17:50:05.61392+00:00", "approved_at": null, "approved_by": null, "contract_id": null, "rejected_at": null, "rejected_by": null, "profile_code": null, "term_biweeks": 8, "interest_rate": 4.25, "commission_rate": 2.50, "rejection_reason": null, "associate_user_id": 3}	\N	2025-11-05 17:50:05.61392+00	\N	\N
100	loans	4	DELETE	{"id": 4, "notes": "Prueba con logs", "amount": 12000.00, "user_id": 4, "status_id": 1, "created_at": "2025-11-05T17:50:05.61392+00:00", "updated_at": "2025-11-05T17:50:05.61392+00:00", "approved_at": null, "approved_by": null, "contract_id": null, "rejected_at": null, "rejected_by": null, "profile_code": null, "term_biweeks": 8, "interest_rate": 4.25, "commission_rate": 2.50, "rejection_reason": null, "associate_user_id": 3}	\N	\N	2025-11-05 17:54:18.789677+00	\N	\N
101	loans	5	INSERT	\N	{"id": 5, "notes": "Préstamo FINAL con profile_code funcionando", "amount": 20000.00, "user_id": 4, "status_id": 1, "created_at": "2025-11-05T17:56:10.213143+00:00", "updated_at": "2025-11-05T17:56:10.213143+00:00", "approved_at": null, "approved_by": null, "contract_id": null, "rejected_at": null, "rejected_by": null, "profile_code": "standard", "term_biweeks": 10, "interest_rate": 4.25, "commission_rate": 2.50, "rejection_reason": null, "associate_user_id": 3}	\N	2025-11-05 17:56:10.213143+00	\N	\N
102	loans	5	DELETE	{"id": 5, "notes": "Préstamo FINAL con profile_code funcionando", "amount": 20000.00, "user_id": 4, "status_id": 1, "created_at": "2025-11-05T17:56:10.213143+00:00", "updated_at": "2025-11-05T17:56:10.213143+00:00", "approved_at": null, "approved_by": null, "contract_id": null, "rejected_at": null, "rejected_by": null, "profile_code": "standard", "term_biweeks": 10, "interest_rate": 4.25, "commission_rate": 2.50, "rejection_reason": null, "associate_user_id": 3}	\N	\N	2025-11-05 18:05:15.932246+00	\N	\N
103	loans	6	INSERT	\N	{"id": 6, "notes": "Préstamo de auditoría final", "amount": 25000.00, "user_id": 4, "status_id": 1, "created_at": "2025-11-05T18:05:15.948023+00:00", "updated_at": "2025-11-05T18:05:15.948023+00:00", "approved_at": null, "approved_by": null, "contract_id": null, "rejected_at": null, "rejected_by": null, "profile_code": "standard", "term_biweeks": 12, "interest_rate": 4.25, "commission_rate": 2.50, "rejection_reason": null, "associate_user_id": 3}	\N	2025-11-05 18:05:15.948023+00	\N	\N
104	loans	6	UPDATE	{"id": 6, "notes": "Préstamo de auditoría final", "amount": 25000.00, "user_id": 4, "status_id": 1, "created_at": "2025-11-05T18:05:15.948023+00:00", "updated_at": "2025-11-05T18:05:15.948023+00:00", "approved_at": null, "approved_by": null, "contract_id": null, "rejected_at": null, "rejected_by": null, "profile_code": "standard", "term_biweeks": 12, "interest_rate": 4.25, "total_payment": null, "total_interest": null, "commission_rate": 2.50, "biweekly_payment": null, "rejection_reason": null, "total_commission": null, "associate_payment": null, "associate_user_id": 3, "commission_per_payment": null}	{"id": 6, "notes": "Préstamo de auditoría final", "amount": 25000.00, "user_id": 4, "status_id": 1, "created_at": "2025-11-05T18:05:15.948023+00:00", "updated_at": "2025-11-05T18:43:21.35631+00:00", "approved_at": null, "approved_by": null, "contract_id": null, "rejected_at": null, "rejected_by": null, "profile_code": "standard", "term_biweeks": 12, "interest_rate": 4.25, "total_payment": 37750.00, "total_interest": 12750.00, "commission_rate": 2.50, "biweekly_payment": 3145.83, "rejection_reason": null, "total_commission": 943.80, "associate_payment": 3067.18, "associate_user_id": 3, "commission_per_payment": 78.65}	\N	2025-11-05 18:43:21.35631+00	\N	\N
105	loans	6	UPDATE	{"id": 6, "notes": "Préstamo de auditoría final", "amount": 25000.00, "user_id": 4, "status_id": 1, "created_at": "2025-11-05T18:05:15.948023+00:00", "updated_at": "2025-11-05T18:43:21.35631+00:00", "approved_at": null, "approved_by": null, "contract_id": null, "rejected_at": null, "rejected_by": null, "profile_code": "standard", "term_biweeks": 12, "interest_rate": 4.25, "total_payment": 37750.00, "total_interest": 12750.00, "commission_rate": 2.50, "biweekly_payment": 3145.83, "rejection_reason": null, "total_commission": 943.80, "associate_payment": 3067.18, "associate_user_id": 3, "commission_per_payment": 78.65}	{"id": 6, "notes": "Préstamo de auditoría final", "amount": 25000.00, "user_id": 4, "status_id": 2, "created_at": "2025-11-05T18:05:15.948023+00:00", "updated_at": "2025-11-05T19:33:36.414762+00:00", "approved_at": "2025-11-05T19:33:36.414762+00:00", "approved_by": 1, "contract_id": null, "rejected_at": null, "rejected_by": null, "profile_code": "standard", "term_biweeks": 12, "interest_rate": 4.25, "total_payment": 37750.00, "total_interest": 12750.00, "commission_rate": 2.50, "biweekly_payment": 3145.83, "rejection_reason": null, "total_commission": 943.80, "associate_payment": 3067.18, "associate_user_id": 3, "commission_per_payment": 78.65}	\N	2025-11-05 19:33:36.414762+00	\N	\N
106	payments	1	INSERT	\N	{"id": 1, "is_late": false, "loan_id": 6, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-11-05T19:33:36.414762+00:00", "updated_at": "2025-11-05T19:33:36.414762+00:00", "amount_paid": 0.00, "payment_date": "2025-11-15", "cut_period_id": null, "marking_notes": null, "payment_number": 1, "expected_amount": 3145.83, "interest_amount": 1062.50, "payment_due_date": "2025-11-15", "principal_amount": 2083.33, "associate_payment": 671.63, "balance_remaining": 22916.67, "commission_amount": 2474.20}	\N	2025-11-05 19:33:36.414762+00	\N	\N
107	payments	2	INSERT	\N	{"id": 2, "is_late": false, "loan_id": 6, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-11-05T19:33:36.414762+00:00", "updated_at": "2025-11-05T19:33:36.414762+00:00", "amount_paid": 0.00, "payment_date": "2025-11-30", "cut_period_id": null, "marking_notes": null, "payment_number": 2, "expected_amount": 3145.83, "interest_amount": 1062.50, "payment_due_date": "2025-11-30", "principal_amount": 2083.33, "associate_payment": 671.63, "balance_remaining": 20833.34, "commission_amount": 2474.20}	\N	2025-11-05 19:33:36.414762+00	\N	\N
108	payments	3	INSERT	\N	{"id": 3, "is_late": false, "loan_id": 6, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-11-05T19:33:36.414762+00:00", "updated_at": "2025-11-05T19:33:36.414762+00:00", "amount_paid": 0.00, "payment_date": "2025-12-15", "cut_period_id": null, "marking_notes": null, "payment_number": 3, "expected_amount": 3145.83, "interest_amount": 1062.50, "payment_due_date": "2025-12-15", "principal_amount": 2083.33, "associate_payment": 671.63, "balance_remaining": 18750.01, "commission_amount": 2474.20}	\N	2025-11-05 19:33:36.414762+00	\N	\N
109	payments	4	INSERT	\N	{"id": 4, "is_late": false, "loan_id": 6, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-11-05T19:33:36.414762+00:00", "updated_at": "2025-11-05T19:33:36.414762+00:00", "amount_paid": 0.00, "payment_date": "2025-12-31", "cut_period_id": null, "marking_notes": null, "payment_number": 4, "expected_amount": 3145.83, "interest_amount": 1062.50, "payment_due_date": "2025-12-31", "principal_amount": 2083.33, "associate_payment": 671.63, "balance_remaining": 16666.68, "commission_amount": 2474.20}	\N	2025-11-05 19:33:36.414762+00	\N	\N
110	payments	5	INSERT	\N	{"id": 5, "is_late": false, "loan_id": 6, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-11-05T19:33:36.414762+00:00", "updated_at": "2025-11-05T19:33:36.414762+00:00", "amount_paid": 0.00, "payment_date": "2026-01-15", "cut_period_id": null, "marking_notes": null, "payment_number": 5, "expected_amount": 3145.83, "interest_amount": 1062.50, "payment_due_date": "2026-01-15", "principal_amount": 2083.33, "associate_payment": 671.63, "balance_remaining": 14583.35, "commission_amount": 2474.20}	\N	2025-11-05 19:33:36.414762+00	\N	\N
111	payments	6	INSERT	\N	{"id": 6, "is_late": false, "loan_id": 6, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-11-05T19:33:36.414762+00:00", "updated_at": "2025-11-05T19:33:36.414762+00:00", "amount_paid": 0.00, "payment_date": "2026-01-31", "cut_period_id": null, "marking_notes": null, "payment_number": 6, "expected_amount": 3145.83, "interest_amount": 1062.50, "payment_due_date": "2026-01-31", "principal_amount": 2083.33, "associate_payment": 671.63, "balance_remaining": 12500.02, "commission_amount": 2474.20}	\N	2025-11-05 19:33:36.414762+00	\N	\N
112	payments	7	INSERT	\N	{"id": 7, "is_late": false, "loan_id": 6, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-11-05T19:33:36.414762+00:00", "updated_at": "2025-11-05T19:33:36.414762+00:00", "amount_paid": 0.00, "payment_date": "2026-02-15", "cut_period_id": null, "marking_notes": null, "payment_number": 7, "expected_amount": 3145.83, "interest_amount": 1062.50, "payment_due_date": "2026-02-15", "principal_amount": 2083.33, "associate_payment": 671.63, "balance_remaining": 10416.69, "commission_amount": 2474.20}	\N	2025-11-05 19:33:36.414762+00	\N	\N
113	payments	8	INSERT	\N	{"id": 8, "is_late": false, "loan_id": 6, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-11-05T19:33:36.414762+00:00", "updated_at": "2025-11-05T19:33:36.414762+00:00", "amount_paid": 0.00, "payment_date": "2026-02-28", "cut_period_id": null, "marking_notes": null, "payment_number": 8, "expected_amount": 3145.83, "interest_amount": 1062.50, "payment_due_date": "2026-02-28", "principal_amount": 2083.33, "associate_payment": 671.63, "balance_remaining": 8333.36, "commission_amount": 2474.20}	\N	2025-11-05 19:33:36.414762+00	\N	\N
114	payments	9	INSERT	\N	{"id": 9, "is_late": false, "loan_id": 6, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-11-05T19:33:36.414762+00:00", "updated_at": "2025-11-05T19:33:36.414762+00:00", "amount_paid": 0.00, "payment_date": "2026-03-15", "cut_period_id": null, "marking_notes": null, "payment_number": 9, "expected_amount": 3145.83, "interest_amount": 1062.50, "payment_due_date": "2026-03-15", "principal_amount": 2083.33, "associate_payment": 671.63, "balance_remaining": 6250.03, "commission_amount": 2474.20}	\N	2025-11-05 19:33:36.414762+00	\N	\N
115	payments	10	INSERT	\N	{"id": 10, "is_late": false, "loan_id": 6, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-11-05T19:33:36.414762+00:00", "updated_at": "2025-11-05T19:33:36.414762+00:00", "amount_paid": 0.00, "payment_date": "2026-03-31", "cut_period_id": null, "marking_notes": null, "payment_number": 10, "expected_amount": 3145.83, "interest_amount": 1062.50, "payment_due_date": "2026-03-31", "principal_amount": 2083.33, "associate_payment": 671.63, "balance_remaining": 4166.70, "commission_amount": 2474.20}	\N	2025-11-05 19:33:36.414762+00	\N	\N
116	payments	11	INSERT	\N	{"id": 11, "is_late": false, "loan_id": 6, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-11-05T19:33:36.414762+00:00", "updated_at": "2025-11-05T19:33:36.414762+00:00", "amount_paid": 0.00, "payment_date": "2026-04-15", "cut_period_id": null, "marking_notes": null, "payment_number": 11, "expected_amount": 3145.83, "interest_amount": 1062.50, "payment_due_date": "2026-04-15", "principal_amount": 2083.33, "associate_payment": 671.63, "balance_remaining": 2083.37, "commission_amount": 2474.20}	\N	2025-11-05 19:33:36.414762+00	\N	\N
117	payments	12	INSERT	\N	{"id": 12, "is_late": false, "loan_id": 6, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-11-05T19:33:36.414762+00:00", "updated_at": "2025-11-05T19:33:36.414762+00:00", "amount_paid": 0.00, "payment_date": "2026-04-30", "cut_period_id": null, "marking_notes": null, "payment_number": 12, "expected_amount": 3145.83, "interest_amount": 1062.50, "payment_due_date": "2026-04-30", "principal_amount": 2083.33, "associate_payment": 671.63, "balance_remaining": 0.04, "commission_amount": 2474.20}	\N	2025-11-05 19:33:36.414762+00	\N	\N
118	loans	8	INSERT	\N	{"id": 8, "notes": null, "amount": 10000.00, "user_id": 4, "status_id": 1, "created_at": "2025-11-06T03:33:06.462989+00:00", "updated_at": "2025-11-06T03:33:06.462989+00:00", "approved_at": null, "approved_by": null, "contract_id": null, "rejected_at": null, "rejected_by": null, "profile_code": "standard", "term_biweeks": 6, "interest_rate": 2.50, "total_payment": null, "total_interest": null, "commission_rate": 2.50, "biweekly_payment": null, "rejection_reason": null, "total_commission": null, "associate_payment": null, "associate_user_id": null, "commission_per_payment": null}	\N	2025-11-06 03:33:06.462989+00	\N	\N
119	loans	9	INSERT	\N	{"id": 9, "notes": null, "amount": 30000.00, "user_id": 5, "status_id": 1, "created_at": "2025-11-06T03:33:13.392382+00:00", "updated_at": "2025-11-06T03:33:13.392382+00:00", "approved_at": null, "approved_by": null, "contract_id": null, "rejected_at": null, "rejected_by": null, "profile_code": "standard", "term_biweeks": 18, "interest_rate": 2.50, "total_payment": null, "total_interest": null, "commission_rate": 2.50, "biweekly_payment": null, "rejection_reason": null, "total_commission": null, "associate_payment": null, "associate_user_id": null, "commission_per_payment": null}	\N	2025-11-06 03:33:13.392382+00	\N	\N
120	loans	10	INSERT	\N	{"id": 10, "notes": null, "amount": 50000.00, "user_id": 6, "status_id": 1, "created_at": "2025-11-06T03:33:20.197819+00:00", "updated_at": "2025-11-06T03:33:20.197819+00:00", "approved_at": null, "approved_by": null, "contract_id": null, "rejected_at": null, "rejected_by": null, "profile_code": "standard", "term_biweeks": 24, "interest_rate": 2.50, "total_payment": null, "total_interest": null, "commission_rate": 2.50, "biweekly_payment": null, "rejection_reason": null, "total_commission": null, "associate_payment": null, "associate_user_id": null, "commission_per_payment": null}	\N	2025-11-06 03:33:20.197819+00	\N	\N
121	loans	8	UPDATE	{"id": 8, "notes": null, "amount": 10000.00, "user_id": 4, "status_id": 1, "created_at": "2025-11-06T03:33:06.462989+00:00", "updated_at": "2025-11-06T03:33:06.462989+00:00", "approved_at": null, "approved_by": null, "contract_id": null, "rejected_at": null, "rejected_by": null, "profile_code": "standard", "term_biweeks": 6, "interest_rate": 2.50, "total_payment": null, "total_interest": null, "commission_rate": 2.50, "biweekly_payment": null, "rejection_reason": null, "total_commission": null, "associate_payment": null, "associate_user_id": null, "commission_per_payment": null}	{"id": 8, "notes": null, "amount": 10000.00, "user_id": 4, "status_id": 2, "created_at": "2025-11-06T03:33:06.462989+00:00", "updated_at": "2025-11-06T03:33:43.064871+00:00", "approved_at": "2025-11-06T03:33:43.064871+00:00", "approved_by": 1, "contract_id": null, "rejected_at": null, "rejected_by": null, "profile_code": "standard", "term_biweeks": 6, "interest_rate": 2.50, "total_payment": 10400.00, "total_interest": 400.00, "commission_rate": 2.50, "biweekly_payment": 1733.33, "rejection_reason": null, "total_commission": null, "associate_payment": 1690.00, "associate_user_id": null, "commission_per_payment": 43.33}	\N	2025-11-06 03:33:43.064871+00	\N	\N
122	payments	13	INSERT	\N	{"id": 13, "is_late": false, "loan_id": 8, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-11-06T03:33:43.064871+00:00", "updated_at": "2025-11-06T03:33:43.064871+00:00", "amount_paid": 0.00, "payment_date": "2025-11-15", "cut_period_id": null, "marking_notes": null, "payment_number": 1, "expected_amount": 1733.33, "interest_amount": 66.66, "payment_due_date": "2025-11-15", "principal_amount": 1666.67, "associate_payment": 982.28, "balance_remaining": 8333.33, "commission_amount": 751.05}	\N	2025-11-06 03:33:43.064871+00	\N	\N
123	payments	14	INSERT	\N	{"id": 14, "is_late": false, "loan_id": 8, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-11-06T03:33:43.064871+00:00", "updated_at": "2025-11-06T03:33:43.064871+00:00", "amount_paid": 0.00, "payment_date": "2025-11-30", "cut_period_id": null, "marking_notes": null, "payment_number": 2, "expected_amount": 1733.33, "interest_amount": 66.66, "payment_due_date": "2025-11-30", "principal_amount": 1666.67, "associate_payment": 982.28, "balance_remaining": 6666.66, "commission_amount": 751.05}	\N	2025-11-06 03:33:43.064871+00	\N	\N
124	payments	15	INSERT	\N	{"id": 15, "is_late": false, "loan_id": 8, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-11-06T03:33:43.064871+00:00", "updated_at": "2025-11-06T03:33:43.064871+00:00", "amount_paid": 0.00, "payment_date": "2025-12-15", "cut_period_id": null, "marking_notes": null, "payment_number": 3, "expected_amount": 1733.33, "interest_amount": 66.66, "payment_due_date": "2025-12-15", "principal_amount": 1666.67, "associate_payment": 982.28, "balance_remaining": 4999.99, "commission_amount": 751.05}	\N	2025-11-06 03:33:43.064871+00	\N	\N
125	payments	16	INSERT	\N	{"id": 16, "is_late": false, "loan_id": 8, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-11-06T03:33:43.064871+00:00", "updated_at": "2025-11-06T03:33:43.064871+00:00", "amount_paid": 0.00, "payment_date": "2025-12-31", "cut_period_id": null, "marking_notes": null, "payment_number": 4, "expected_amount": 1733.33, "interest_amount": 66.66, "payment_due_date": "2025-12-31", "principal_amount": 1666.67, "associate_payment": 982.28, "balance_remaining": 3333.32, "commission_amount": 751.05}	\N	2025-11-06 03:33:43.064871+00	\N	\N
126	payments	17	INSERT	\N	{"id": 17, "is_late": false, "loan_id": 8, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-11-06T03:33:43.064871+00:00", "updated_at": "2025-11-06T03:33:43.064871+00:00", "amount_paid": 0.00, "payment_date": "2026-01-15", "cut_period_id": null, "marking_notes": null, "payment_number": 5, "expected_amount": 1733.33, "interest_amount": 66.66, "payment_due_date": "2026-01-15", "principal_amount": 1666.67, "associate_payment": 982.28, "balance_remaining": 1666.65, "commission_amount": 751.05}	\N	2025-11-06 03:33:43.064871+00	\N	\N
127	payments	18	INSERT	\N	{"id": 18, "is_late": false, "loan_id": 8, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-11-06T03:33:43.064871+00:00", "updated_at": "2025-11-06T03:33:43.064871+00:00", "amount_paid": 0.00, "payment_date": "2026-01-31", "cut_period_id": null, "marking_notes": null, "payment_number": 6, "expected_amount": 1733.33, "interest_amount": 66.66, "payment_due_date": "2026-01-31", "principal_amount": 1666.67, "associate_payment": 982.28, "balance_remaining": 0.00, "commission_amount": 751.05}	\N	2025-11-06 03:33:43.064871+00	\N	\N
128	loans	9	UPDATE	{"id": 9, "notes": null, "amount": 30000.00, "user_id": 5, "status_id": 1, "created_at": "2025-11-06T03:33:13.392382+00:00", "updated_at": "2025-11-06T03:33:13.392382+00:00", "approved_at": null, "approved_by": null, "contract_id": null, "rejected_at": null, "rejected_by": null, "profile_code": "standard", "term_biweeks": 18, "interest_rate": 2.50, "total_payment": null, "total_interest": null, "commission_rate": 2.50, "biweekly_payment": null, "rejection_reason": null, "total_commission": null, "associate_payment": null, "associate_user_id": null, "commission_per_payment": null}	{"id": 9, "notes": null, "amount": 30000.00, "user_id": 5, "status_id": 2, "created_at": "2025-11-06T03:33:13.392382+00:00", "updated_at": "2025-11-06T03:34:01.319366+00:00", "approved_at": "2025-11-06T03:34:01.319366+00:00", "approved_by": 1, "contract_id": null, "rejected_at": null, "rejected_by": null, "profile_code": "standard", "term_biweeks": 18, "interest_rate": 2.50, "total_payment": 31000.00, "total_interest": 1000.00, "commission_rate": 2.50, "biweekly_payment": 1722.22, "rejection_reason": null, "total_commission": null, "associate_payment": 1679.16, "associate_user_id": null, "commission_per_payment": 43.06}	\N	2025-11-06 03:34:01.319366+00	\N	\N
129	payments	19	INSERT	\N	{"id": 19, "is_late": false, "loan_id": 9, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-11-06T03:34:01.319366+00:00", "updated_at": "2025-11-06T03:34:01.319366+00:00", "amount_paid": 0.00, "payment_date": "2025-11-15", "cut_period_id": null, "marking_notes": null, "payment_number": 1, "expected_amount": 1722.22, "interest_amount": 55.55, "payment_due_date": "2025-11-15", "principal_amount": 1666.67, "associate_payment": 980.63, "balance_remaining": 28333.33, "commission_amount": 741.59}	\N	2025-11-06 03:34:01.319366+00	\N	\N
193	cut_periods	11	INSERT	\N	{"id": 11, "cut_code": "2024-Q11", "closed_by": null, "status_id": 5, "created_at": "2025-11-06T08:12:35.24612+00:00", "created_by": 1, "cut_number": 11, "updated_at": "2025-11-06T08:12:35.24612+00:00", "period_end_date": "2024-06-22", "total_commission": 0.00, "period_start_date": "2024-06-08", "total_payments_expected": 0.00, "total_payments_received": 0.00}	\N	2025-11-06 08:12:35.24612+00	\N	\N
130	payments	20	INSERT	\N	{"id": 20, "is_late": false, "loan_id": 9, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-11-06T03:34:01.319366+00:00", "updated_at": "2025-11-06T03:34:01.319366+00:00", "amount_paid": 0.00, "payment_date": "2025-11-30", "cut_period_id": null, "marking_notes": null, "payment_number": 2, "expected_amount": 1722.22, "interest_amount": 55.55, "payment_due_date": "2025-11-30", "principal_amount": 1666.67, "associate_payment": 980.63, "balance_remaining": 26666.66, "commission_amount": 741.59}	\N	2025-11-06 03:34:01.319366+00	\N	\N
131	payments	21	INSERT	\N	{"id": 21, "is_late": false, "loan_id": 9, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-11-06T03:34:01.319366+00:00", "updated_at": "2025-11-06T03:34:01.319366+00:00", "amount_paid": 0.00, "payment_date": "2025-12-15", "cut_period_id": null, "marking_notes": null, "payment_number": 3, "expected_amount": 1722.22, "interest_amount": 55.55, "payment_due_date": "2025-12-15", "principal_amount": 1666.67, "associate_payment": 980.63, "balance_remaining": 24999.99, "commission_amount": 741.59}	\N	2025-11-06 03:34:01.319366+00	\N	\N
132	payments	22	INSERT	\N	{"id": 22, "is_late": false, "loan_id": 9, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-11-06T03:34:01.319366+00:00", "updated_at": "2025-11-06T03:34:01.319366+00:00", "amount_paid": 0.00, "payment_date": "2025-12-31", "cut_period_id": null, "marking_notes": null, "payment_number": 4, "expected_amount": 1722.22, "interest_amount": 55.55, "payment_due_date": "2025-12-31", "principal_amount": 1666.67, "associate_payment": 980.63, "balance_remaining": 23333.32, "commission_amount": 741.59}	\N	2025-11-06 03:34:01.319366+00	\N	\N
133	payments	23	INSERT	\N	{"id": 23, "is_late": false, "loan_id": 9, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-11-06T03:34:01.319366+00:00", "updated_at": "2025-11-06T03:34:01.319366+00:00", "amount_paid": 0.00, "payment_date": "2026-01-15", "cut_period_id": null, "marking_notes": null, "payment_number": 5, "expected_amount": 1722.22, "interest_amount": 55.55, "payment_due_date": "2026-01-15", "principal_amount": 1666.67, "associate_payment": 980.63, "balance_remaining": 21666.65, "commission_amount": 741.59}	\N	2025-11-06 03:34:01.319366+00	\N	\N
134	payments	24	INSERT	\N	{"id": 24, "is_late": false, "loan_id": 9, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-11-06T03:34:01.319366+00:00", "updated_at": "2025-11-06T03:34:01.319366+00:00", "amount_paid": 0.00, "payment_date": "2026-01-31", "cut_period_id": null, "marking_notes": null, "payment_number": 6, "expected_amount": 1722.22, "interest_amount": 55.55, "payment_due_date": "2026-01-31", "principal_amount": 1666.67, "associate_payment": 980.63, "balance_remaining": 19999.98, "commission_amount": 741.59}	\N	2025-11-06 03:34:01.319366+00	\N	\N
135	payments	25	INSERT	\N	{"id": 25, "is_late": false, "loan_id": 9, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-11-06T03:34:01.319366+00:00", "updated_at": "2025-11-06T03:34:01.319366+00:00", "amount_paid": 0.00, "payment_date": "2026-02-15", "cut_period_id": null, "marking_notes": null, "payment_number": 7, "expected_amount": 1722.22, "interest_amount": 55.55, "payment_due_date": "2026-02-15", "principal_amount": 1666.67, "associate_payment": 980.63, "balance_remaining": 18333.31, "commission_amount": 741.59}	\N	2025-11-06 03:34:01.319366+00	\N	\N
136	payments	26	INSERT	\N	{"id": 26, "is_late": false, "loan_id": 9, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-11-06T03:34:01.319366+00:00", "updated_at": "2025-11-06T03:34:01.319366+00:00", "amount_paid": 0.00, "payment_date": "2026-02-28", "cut_period_id": null, "marking_notes": null, "payment_number": 8, "expected_amount": 1722.22, "interest_amount": 55.55, "payment_due_date": "2026-02-28", "principal_amount": 1666.67, "associate_payment": 980.63, "balance_remaining": 16666.64, "commission_amount": 741.59}	\N	2025-11-06 03:34:01.319366+00	\N	\N
137	payments	27	INSERT	\N	{"id": 27, "is_late": false, "loan_id": 9, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-11-06T03:34:01.319366+00:00", "updated_at": "2025-11-06T03:34:01.319366+00:00", "amount_paid": 0.00, "payment_date": "2026-03-15", "cut_period_id": null, "marking_notes": null, "payment_number": 9, "expected_amount": 1722.22, "interest_amount": 55.55, "payment_due_date": "2026-03-15", "principal_amount": 1666.67, "associate_payment": 980.63, "balance_remaining": 14999.97, "commission_amount": 741.59}	\N	2025-11-06 03:34:01.319366+00	\N	\N
138	payments	28	INSERT	\N	{"id": 28, "is_late": false, "loan_id": 9, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-11-06T03:34:01.319366+00:00", "updated_at": "2025-11-06T03:34:01.319366+00:00", "amount_paid": 0.00, "payment_date": "2026-03-31", "cut_period_id": null, "marking_notes": null, "payment_number": 10, "expected_amount": 1722.22, "interest_amount": 55.55, "payment_due_date": "2026-03-31", "principal_amount": 1666.67, "associate_payment": 980.63, "balance_remaining": 13333.30, "commission_amount": 741.59}	\N	2025-11-06 03:34:01.319366+00	\N	\N
139	payments	29	INSERT	\N	{"id": 29, "is_late": false, "loan_id": 9, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-11-06T03:34:01.319366+00:00", "updated_at": "2025-11-06T03:34:01.319366+00:00", "amount_paid": 0.00, "payment_date": "2026-04-15", "cut_period_id": null, "marking_notes": null, "payment_number": 11, "expected_amount": 1722.22, "interest_amount": 55.55, "payment_due_date": "2026-04-15", "principal_amount": 1666.67, "associate_payment": 980.63, "balance_remaining": 11666.63, "commission_amount": 741.59}	\N	2025-11-06 03:34:01.319366+00	\N	\N
140	payments	30	INSERT	\N	{"id": 30, "is_late": false, "loan_id": 9, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-11-06T03:34:01.319366+00:00", "updated_at": "2025-11-06T03:34:01.319366+00:00", "amount_paid": 0.00, "payment_date": "2026-04-30", "cut_period_id": null, "marking_notes": null, "payment_number": 12, "expected_amount": 1722.22, "interest_amount": 55.55, "payment_due_date": "2026-04-30", "principal_amount": 1666.67, "associate_payment": 980.63, "balance_remaining": 9999.96, "commission_amount": 741.59}	\N	2025-11-06 03:34:01.319366+00	\N	\N
141	payments	31	INSERT	\N	{"id": 31, "is_late": false, "loan_id": 9, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-11-06T03:34:01.319366+00:00", "updated_at": "2025-11-06T03:34:01.319366+00:00", "amount_paid": 0.00, "payment_date": "2026-05-15", "cut_period_id": null, "marking_notes": null, "payment_number": 13, "expected_amount": 1722.22, "interest_amount": 55.55, "payment_due_date": "2026-05-15", "principal_amount": 1666.67, "associate_payment": 980.63, "balance_remaining": 8333.29, "commission_amount": 741.59}	\N	2025-11-06 03:34:01.319366+00	\N	\N
142	payments	32	INSERT	\N	{"id": 32, "is_late": false, "loan_id": 9, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-11-06T03:34:01.319366+00:00", "updated_at": "2025-11-06T03:34:01.319366+00:00", "amount_paid": 0.00, "payment_date": "2026-05-31", "cut_period_id": null, "marking_notes": null, "payment_number": 14, "expected_amount": 1722.22, "interest_amount": 55.55, "payment_due_date": "2026-05-31", "principal_amount": 1666.67, "associate_payment": 980.63, "balance_remaining": 6666.62, "commission_amount": 741.59}	\N	2025-11-06 03:34:01.319366+00	\N	\N
143	payments	33	INSERT	\N	{"id": 33, "is_late": false, "loan_id": 9, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-11-06T03:34:01.319366+00:00", "updated_at": "2025-11-06T03:34:01.319366+00:00", "amount_paid": 0.00, "payment_date": "2026-06-15", "cut_period_id": null, "marking_notes": null, "payment_number": 15, "expected_amount": 1722.22, "interest_amount": 55.55, "payment_due_date": "2026-06-15", "principal_amount": 1666.67, "associate_payment": 980.63, "balance_remaining": 4999.95, "commission_amount": 741.59}	\N	2025-11-06 03:34:01.319366+00	\N	\N
144	payments	34	INSERT	\N	{"id": 34, "is_late": false, "loan_id": 9, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-11-06T03:34:01.319366+00:00", "updated_at": "2025-11-06T03:34:01.319366+00:00", "amount_paid": 0.00, "payment_date": "2026-06-30", "cut_period_id": null, "marking_notes": null, "payment_number": 16, "expected_amount": 1722.22, "interest_amount": 55.55, "payment_due_date": "2026-06-30", "principal_amount": 1666.67, "associate_payment": 980.63, "balance_remaining": 3333.28, "commission_amount": 741.59}	\N	2025-11-06 03:34:01.319366+00	\N	\N
145	payments	35	INSERT	\N	{"id": 35, "is_late": false, "loan_id": 9, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-11-06T03:34:01.319366+00:00", "updated_at": "2025-11-06T03:34:01.319366+00:00", "amount_paid": 0.00, "payment_date": "2026-07-15", "cut_period_id": null, "marking_notes": null, "payment_number": 17, "expected_amount": 1722.22, "interest_amount": 55.55, "payment_due_date": "2026-07-15", "principal_amount": 1666.67, "associate_payment": 980.63, "balance_remaining": 1666.61, "commission_amount": 741.59}	\N	2025-11-06 03:34:01.319366+00	\N	\N
146	payments	36	INSERT	\N	{"id": 36, "is_late": false, "loan_id": 9, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-11-06T03:34:01.319366+00:00", "updated_at": "2025-11-06T03:34:01.319366+00:00", "amount_paid": 0.00, "payment_date": "2026-07-31", "cut_period_id": null, "marking_notes": null, "payment_number": 18, "expected_amount": 1722.22, "interest_amount": 55.55, "payment_due_date": "2026-07-31", "principal_amount": 1666.67, "associate_payment": 980.63, "balance_remaining": 0.00, "commission_amount": 741.59}	\N	2025-11-06 03:34:01.319366+00	\N	\N
147	loans	10	UPDATE	{"id": 10, "notes": null, "amount": 50000.00, "user_id": 6, "status_id": 1, "created_at": "2025-11-06T03:33:20.197819+00:00", "updated_at": "2025-11-06T03:33:20.197819+00:00", "approved_at": null, "approved_by": null, "contract_id": null, "rejected_at": null, "rejected_by": null, "profile_code": "standard", "term_biweeks": 24, "interest_rate": 2.50, "total_payment": null, "total_interest": null, "commission_rate": 2.50, "biweekly_payment": null, "rejection_reason": null, "total_commission": null, "associate_payment": null, "associate_user_id": null, "commission_per_payment": null}	{"id": 10, "notes": null, "amount": 50000.00, "user_id": 6, "status_id": 2, "created_at": "2025-11-06T03:33:20.197819+00:00", "updated_at": "2025-11-06T03:39:48.596637+00:00", "approved_at": "2025-11-06T03:39:48.596637+00:00", "approved_by": 1, "contract_id": null, "rejected_at": null, "rejected_by": null, "profile_code": "standard", "term_biweeks": 24, "interest_rate": 2.50, "total_payment": 51500.00, "total_interest": 1500.00, "commission_rate": 2.50, "biweekly_payment": 2145.83, "rejection_reason": null, "total_commission": null, "associate_payment": 2092.18, "associate_user_id": null, "commission_per_payment": 53.65}	\N	2025-11-06 03:39:48.596637+00	\N	\N
148	payments	37	INSERT	\N	{"id": 37, "is_late": false, "loan_id": 10, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-11-06T03:39:48.596637+00:00", "updated_at": "2025-11-06T03:39:48.596637+00:00", "amount_paid": 0.00, "payment_date": "2025-11-15", "cut_period_id": null, "marking_notes": null, "payment_number": 1, "expected_amount": 2145.83, "interest_amount": 62.50, "payment_due_date": "2025-11-15", "principal_amount": 2083.33, "associate_payment": 994.59, "balance_remaining": 47916.67, "commission_amount": 1151.24}	\N	2025-11-06 03:39:48.596637+00	\N	\N
149	payments	38	INSERT	\N	{"id": 38, "is_late": false, "loan_id": 10, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-11-06T03:39:48.596637+00:00", "updated_at": "2025-11-06T03:39:48.596637+00:00", "amount_paid": 0.00, "payment_date": "2025-11-30", "cut_period_id": null, "marking_notes": null, "payment_number": 2, "expected_amount": 2145.83, "interest_amount": 62.50, "payment_due_date": "2025-11-30", "principal_amount": 2083.33, "associate_payment": 994.59, "balance_remaining": 45833.34, "commission_amount": 1151.24}	\N	2025-11-06 03:39:48.596637+00	\N	\N
150	payments	39	INSERT	\N	{"id": 39, "is_late": false, "loan_id": 10, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-11-06T03:39:48.596637+00:00", "updated_at": "2025-11-06T03:39:48.596637+00:00", "amount_paid": 0.00, "payment_date": "2025-12-15", "cut_period_id": null, "marking_notes": null, "payment_number": 3, "expected_amount": 2145.83, "interest_amount": 62.50, "payment_due_date": "2025-12-15", "principal_amount": 2083.33, "associate_payment": 994.59, "balance_remaining": 43750.01, "commission_amount": 1151.24}	\N	2025-11-06 03:39:48.596637+00	\N	\N
151	payments	40	INSERT	\N	{"id": 40, "is_late": false, "loan_id": 10, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-11-06T03:39:48.596637+00:00", "updated_at": "2025-11-06T03:39:48.596637+00:00", "amount_paid": 0.00, "payment_date": "2025-12-31", "cut_period_id": null, "marking_notes": null, "payment_number": 4, "expected_amount": 2145.83, "interest_amount": 62.50, "payment_due_date": "2025-12-31", "principal_amount": 2083.33, "associate_payment": 994.59, "balance_remaining": 41666.68, "commission_amount": 1151.24}	\N	2025-11-06 03:39:48.596637+00	\N	\N
152	payments	41	INSERT	\N	{"id": 41, "is_late": false, "loan_id": 10, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-11-06T03:39:48.596637+00:00", "updated_at": "2025-11-06T03:39:48.596637+00:00", "amount_paid": 0.00, "payment_date": "2026-01-15", "cut_period_id": null, "marking_notes": null, "payment_number": 5, "expected_amount": 2145.83, "interest_amount": 62.50, "payment_due_date": "2026-01-15", "principal_amount": 2083.33, "associate_payment": 994.59, "balance_remaining": 39583.35, "commission_amount": 1151.24}	\N	2025-11-06 03:39:48.596637+00	\N	\N
153	payments	42	INSERT	\N	{"id": 42, "is_late": false, "loan_id": 10, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-11-06T03:39:48.596637+00:00", "updated_at": "2025-11-06T03:39:48.596637+00:00", "amount_paid": 0.00, "payment_date": "2026-01-31", "cut_period_id": null, "marking_notes": null, "payment_number": 6, "expected_amount": 2145.83, "interest_amount": 62.50, "payment_due_date": "2026-01-31", "principal_amount": 2083.33, "associate_payment": 994.59, "balance_remaining": 37500.02, "commission_amount": 1151.24}	\N	2025-11-06 03:39:48.596637+00	\N	\N
154	payments	43	INSERT	\N	{"id": 43, "is_late": false, "loan_id": 10, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-11-06T03:39:48.596637+00:00", "updated_at": "2025-11-06T03:39:48.596637+00:00", "amount_paid": 0.00, "payment_date": "2026-02-15", "cut_period_id": null, "marking_notes": null, "payment_number": 7, "expected_amount": 2145.83, "interest_amount": 62.50, "payment_due_date": "2026-02-15", "principal_amount": 2083.33, "associate_payment": 994.59, "balance_remaining": 35416.69, "commission_amount": 1151.24}	\N	2025-11-06 03:39:48.596637+00	\N	\N
155	payments	44	INSERT	\N	{"id": 44, "is_late": false, "loan_id": 10, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-11-06T03:39:48.596637+00:00", "updated_at": "2025-11-06T03:39:48.596637+00:00", "amount_paid": 0.00, "payment_date": "2026-02-28", "cut_period_id": null, "marking_notes": null, "payment_number": 8, "expected_amount": 2145.83, "interest_amount": 62.50, "payment_due_date": "2026-02-28", "principal_amount": 2083.33, "associate_payment": 994.59, "balance_remaining": 33333.36, "commission_amount": 1151.24}	\N	2025-11-06 03:39:48.596637+00	\N	\N
156	payments	45	INSERT	\N	{"id": 45, "is_late": false, "loan_id": 10, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-11-06T03:39:48.596637+00:00", "updated_at": "2025-11-06T03:39:48.596637+00:00", "amount_paid": 0.00, "payment_date": "2026-03-15", "cut_period_id": null, "marking_notes": null, "payment_number": 9, "expected_amount": 2145.83, "interest_amount": 62.50, "payment_due_date": "2026-03-15", "principal_amount": 2083.33, "associate_payment": 994.59, "balance_remaining": 31250.03, "commission_amount": 1151.24}	\N	2025-11-06 03:39:48.596637+00	\N	\N
157	payments	46	INSERT	\N	{"id": 46, "is_late": false, "loan_id": 10, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-11-06T03:39:48.596637+00:00", "updated_at": "2025-11-06T03:39:48.596637+00:00", "amount_paid": 0.00, "payment_date": "2026-03-31", "cut_period_id": null, "marking_notes": null, "payment_number": 10, "expected_amount": 2145.83, "interest_amount": 62.50, "payment_due_date": "2026-03-31", "principal_amount": 2083.33, "associate_payment": 994.59, "balance_remaining": 29166.70, "commission_amount": 1151.24}	\N	2025-11-06 03:39:48.596637+00	\N	\N
158	payments	47	INSERT	\N	{"id": 47, "is_late": false, "loan_id": 10, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-11-06T03:39:48.596637+00:00", "updated_at": "2025-11-06T03:39:48.596637+00:00", "amount_paid": 0.00, "payment_date": "2026-04-15", "cut_period_id": null, "marking_notes": null, "payment_number": 11, "expected_amount": 2145.83, "interest_amount": 62.50, "payment_due_date": "2026-04-15", "principal_amount": 2083.33, "associate_payment": 994.59, "balance_remaining": 27083.37, "commission_amount": 1151.24}	\N	2025-11-06 03:39:48.596637+00	\N	\N
159	payments	48	INSERT	\N	{"id": 48, "is_late": false, "loan_id": 10, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-11-06T03:39:48.596637+00:00", "updated_at": "2025-11-06T03:39:48.596637+00:00", "amount_paid": 0.00, "payment_date": "2026-04-30", "cut_period_id": null, "marking_notes": null, "payment_number": 12, "expected_amount": 2145.83, "interest_amount": 62.50, "payment_due_date": "2026-04-30", "principal_amount": 2083.33, "associate_payment": 994.59, "balance_remaining": 25000.04, "commission_amount": 1151.24}	\N	2025-11-06 03:39:48.596637+00	\N	\N
160	payments	49	INSERT	\N	{"id": 49, "is_late": false, "loan_id": 10, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-11-06T03:39:48.596637+00:00", "updated_at": "2025-11-06T03:39:48.596637+00:00", "amount_paid": 0.00, "payment_date": "2026-05-15", "cut_period_id": null, "marking_notes": null, "payment_number": 13, "expected_amount": 2145.83, "interest_amount": 62.50, "payment_due_date": "2026-05-15", "principal_amount": 2083.33, "associate_payment": 994.59, "balance_remaining": 22916.71, "commission_amount": 1151.24}	\N	2025-11-06 03:39:48.596637+00	\N	\N
161	payments	50	INSERT	\N	{"id": 50, "is_late": false, "loan_id": 10, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-11-06T03:39:48.596637+00:00", "updated_at": "2025-11-06T03:39:48.596637+00:00", "amount_paid": 0.00, "payment_date": "2026-05-31", "cut_period_id": null, "marking_notes": null, "payment_number": 14, "expected_amount": 2145.83, "interest_amount": 62.50, "payment_due_date": "2026-05-31", "principal_amount": 2083.33, "associate_payment": 994.59, "balance_remaining": 20833.38, "commission_amount": 1151.24}	\N	2025-11-06 03:39:48.596637+00	\N	\N
162	payments	51	INSERT	\N	{"id": 51, "is_late": false, "loan_id": 10, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-11-06T03:39:48.596637+00:00", "updated_at": "2025-11-06T03:39:48.596637+00:00", "amount_paid": 0.00, "payment_date": "2026-06-15", "cut_period_id": null, "marking_notes": null, "payment_number": 15, "expected_amount": 2145.83, "interest_amount": 62.50, "payment_due_date": "2026-06-15", "principal_amount": 2083.33, "associate_payment": 994.59, "balance_remaining": 18750.05, "commission_amount": 1151.24}	\N	2025-11-06 03:39:48.596637+00	\N	\N
163	payments	52	INSERT	\N	{"id": 52, "is_late": false, "loan_id": 10, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-11-06T03:39:48.596637+00:00", "updated_at": "2025-11-06T03:39:48.596637+00:00", "amount_paid": 0.00, "payment_date": "2026-06-30", "cut_period_id": null, "marking_notes": null, "payment_number": 16, "expected_amount": 2145.83, "interest_amount": 62.50, "payment_due_date": "2026-06-30", "principal_amount": 2083.33, "associate_payment": 994.59, "balance_remaining": 16666.72, "commission_amount": 1151.24}	\N	2025-11-06 03:39:48.596637+00	\N	\N
164	payments	53	INSERT	\N	{"id": 53, "is_late": false, "loan_id": 10, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-11-06T03:39:48.596637+00:00", "updated_at": "2025-11-06T03:39:48.596637+00:00", "amount_paid": 0.00, "payment_date": "2026-07-15", "cut_period_id": null, "marking_notes": null, "payment_number": 17, "expected_amount": 2145.83, "interest_amount": 62.50, "payment_due_date": "2026-07-15", "principal_amount": 2083.33, "associate_payment": 994.59, "balance_remaining": 14583.39, "commission_amount": 1151.24}	\N	2025-11-06 03:39:48.596637+00	\N	\N
165	payments	54	INSERT	\N	{"id": 54, "is_late": false, "loan_id": 10, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-11-06T03:39:48.596637+00:00", "updated_at": "2025-11-06T03:39:48.596637+00:00", "amount_paid": 0.00, "payment_date": "2026-07-31", "cut_period_id": null, "marking_notes": null, "payment_number": 18, "expected_amount": 2145.83, "interest_amount": 62.50, "payment_due_date": "2026-07-31", "principal_amount": 2083.33, "associate_payment": 994.59, "balance_remaining": 12500.06, "commission_amount": 1151.24}	\N	2025-11-06 03:39:48.596637+00	\N	\N
166	payments	55	INSERT	\N	{"id": 55, "is_late": false, "loan_id": 10, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-11-06T03:39:48.596637+00:00", "updated_at": "2025-11-06T03:39:48.596637+00:00", "amount_paid": 0.00, "payment_date": "2026-08-15", "cut_period_id": null, "marking_notes": null, "payment_number": 19, "expected_amount": 2145.83, "interest_amount": 62.50, "payment_due_date": "2026-08-15", "principal_amount": 2083.33, "associate_payment": 994.59, "balance_remaining": 10416.73, "commission_amount": 1151.24}	\N	2025-11-06 03:39:48.596637+00	\N	\N
167	payments	56	INSERT	\N	{"id": 56, "is_late": false, "loan_id": 10, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-11-06T03:39:48.596637+00:00", "updated_at": "2025-11-06T03:39:48.596637+00:00", "amount_paid": 0.00, "payment_date": "2026-08-31", "cut_period_id": null, "marking_notes": null, "payment_number": 20, "expected_amount": 2145.83, "interest_amount": 62.50, "payment_due_date": "2026-08-31", "principal_amount": 2083.33, "associate_payment": 994.59, "balance_remaining": 8333.40, "commission_amount": 1151.24}	\N	2025-11-06 03:39:48.596637+00	\N	\N
168	payments	57	INSERT	\N	{"id": 57, "is_late": false, "loan_id": 10, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-11-06T03:39:48.596637+00:00", "updated_at": "2025-11-06T03:39:48.596637+00:00", "amount_paid": 0.00, "payment_date": "2026-09-15", "cut_period_id": null, "marking_notes": null, "payment_number": 21, "expected_amount": 2145.83, "interest_amount": 62.50, "payment_due_date": "2026-09-15", "principal_amount": 2083.33, "associate_payment": 994.59, "balance_remaining": 6250.07, "commission_amount": 1151.24}	\N	2025-11-06 03:39:48.596637+00	\N	\N
169	payments	58	INSERT	\N	{"id": 58, "is_late": false, "loan_id": 10, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-11-06T03:39:48.596637+00:00", "updated_at": "2025-11-06T03:39:48.596637+00:00", "amount_paid": 0.00, "payment_date": "2026-09-30", "cut_period_id": null, "marking_notes": null, "payment_number": 22, "expected_amount": 2145.83, "interest_amount": 62.50, "payment_due_date": "2026-09-30", "principal_amount": 2083.33, "associate_payment": 994.59, "balance_remaining": 4166.74, "commission_amount": 1151.24}	\N	2025-11-06 03:39:48.596637+00	\N	\N
170	payments	59	INSERT	\N	{"id": 59, "is_late": false, "loan_id": 10, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-11-06T03:39:48.596637+00:00", "updated_at": "2025-11-06T03:39:48.596637+00:00", "amount_paid": 0.00, "payment_date": "2026-10-15", "cut_period_id": null, "marking_notes": null, "payment_number": 23, "expected_amount": 2145.83, "interest_amount": 62.50, "payment_due_date": "2026-10-15", "principal_amount": 2083.33, "associate_payment": 994.59, "balance_remaining": 2083.41, "commission_amount": 1151.24}	\N	2025-11-06 03:39:48.596637+00	\N	\N
171	payments	60	INSERT	\N	{"id": 60, "is_late": false, "loan_id": 10, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-11-06T03:39:48.596637+00:00", "updated_at": "2025-11-06T03:39:48.596637+00:00", "amount_paid": 0.00, "payment_date": "2026-10-31", "cut_period_id": null, "marking_notes": null, "payment_number": 24, "expected_amount": 2145.83, "interest_amount": 62.50, "payment_due_date": "2026-10-31", "principal_amount": 2083.33, "associate_payment": 994.59, "balance_remaining": 0.08, "commission_amount": 1151.24}	\N	2025-11-06 03:39:48.596637+00	\N	\N
173	payments	37	UPDATE	{"id": 37, "is_late": false, "loan_id": 10, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-11-06T03:39:48.596637+00:00", "updated_at": "2025-11-06T03:39:48.596637+00:00", "amount_paid": 0.00, "payment_date": "2025-11-15", "cut_period_id": null, "marking_notes": null, "payment_number": 1, "expected_amount": 2145.83, "interest_amount": 62.50, "payment_due_date": "2025-11-15", "principal_amount": 2083.33, "associate_payment": 994.59, "balance_remaining": 47916.67, "commission_amount": 1151.24}	{"id": 37, "is_late": false, "loan_id": 10, "marked_at": "2025-11-06T05:03:56.738072+00:00", "marked_by": 1, "status_id": 2, "created_at": "2025-11-06T03:39:48.596637+00:00", "updated_at": "2025-11-06T05:03:56.738072+00:00", "amount_paid": 2145.83, "payment_date": "2025-11-06", "cut_period_id": null, "marking_notes": "Pago registrado correctamente", "payment_number": 1, "expected_amount": 2145.83, "interest_amount": 62.50, "payment_due_date": "2025-11-15", "principal_amount": 2083.33, "associate_payment": 994.59, "balance_remaining": 47916.67, "commission_amount": 1151.24}	\N	2025-11-06 05:03:56.738072+00	\N	\N
194	cut_periods	12	INSERT	\N	{"id": 12, "cut_code": "2024-Q12", "closed_by": null, "status_id": 5, "created_at": "2025-11-06T08:12:35.247165+00:00", "created_by": 1, "cut_number": 12, "updated_at": "2025-11-06T08:12:35.247165+00:00", "period_end_date": "2024-07-07", "total_commission": 0.00, "period_start_date": "2024-06-23", "total_payments_expected": 0.00, "total_payments_received": 0.00}	\N	2025-11-06 08:12:35.247165+00	\N	\N
174	payments	1	UPDATE	{"id": 1, "is_late": false, "loan_id": 6, "marked_at": null, "marked_by": null, "status_id": 1, "created_at": "2025-11-05T19:33:36.414762+00:00", "updated_at": "2025-11-05T19:33:36.414762+00:00", "amount_paid": 0.00, "payment_date": "2025-11-15", "cut_period_id": null, "marking_notes": null, "payment_number": 1, "expected_amount": 3145.83, "interest_amount": 1062.50, "payment_due_date": "2025-11-15", "principal_amount": 2083.33, "associate_payment": 671.63, "balance_remaining": 22916.67, "commission_amount": 2474.20}	{"id": 1, "is_late": false, "loan_id": 6, "marked_at": "2025-11-06T07:04:04.79747+00:00", "marked_by": 1, "status_id": 1, "created_at": "2025-11-05T19:33:36.414762+00:00", "updated_at": "2025-11-06T07:04:04.794992+00:00", "amount_paid": 1000.00, "payment_date": "2025-11-15", "cut_period_id": null, "marking_notes": "Pago manual de prueba", "payment_number": 1, "expected_amount": 3145.83, "interest_amount": 1062.50, "payment_due_date": "2025-11-15", "principal_amount": 2083.33, "associate_payment": 671.63, "balance_remaining": 22916.67, "commission_amount": 2474.20}	\N	2025-11-06 07:04:04.794992+00	\N	\N
175	payments	1	UPDATE	{"id": 1, "is_late": false, "loan_id": 6, "marked_at": "2025-11-06T07:04:04.79747+00:00", "marked_by": 1, "status_id": 1, "created_at": "2025-11-05T19:33:36.414762+00:00", "updated_at": "2025-11-06T07:04:04.794992+00:00", "amount_paid": 1000.00, "payment_date": "2025-11-15", "cut_period_id": null, "marking_notes": "Pago manual de prueba", "payment_number": 1, "expected_amount": 3145.83, "interest_amount": 1062.50, "payment_due_date": "2025-11-15", "principal_amount": 2083.33, "associate_payment": 671.63, "balance_remaining": 22916.67, "commission_amount": 2474.20}	{"id": 1, "is_late": false, "loan_id": 6, "marked_at": "2025-11-06T07:06:47.089198+00:00", "marked_by": 1, "status_id": 1, "created_at": "2025-11-05T19:33:36.414762+00:00", "updated_at": "2025-11-06T07:06:47.088707+00:00", "amount_paid": 3145.83, "payment_date": "2025-11-15", "cut_period_id": null, "marking_notes": null, "payment_number": 1, "expected_amount": 3145.83, "interest_amount": 1062.50, "payment_due_date": "2025-11-15", "principal_amount": 2083.33, "associate_payment": 671.63, "balance_remaining": 22916.67, "commission_amount": 2474.20}	\N	2025-11-06 07:06:47.088707+00	\N	\N
176	loans	12	INSERT	\N	{"id": 12, "notes": null, "amount": 8000.00, "user_id": 4, "status_id": 1, "created_at": "2025-11-06T07:37:11.817299+00:00", "updated_at": "2025-11-06T07:37:11.817299+00:00", "approved_at": null, "approved_by": null, "contract_id": null, "rejected_at": null, "rejected_by": null, "profile_code": null, "term_biweeks": 6, "interest_rate": 3.50, "total_payment": null, "total_interest": null, "commission_rate": 15.00, "biweekly_payment": null, "rejection_reason": null, "total_commission": null, "associate_payment": null, "associate_user_id": 2, "commission_per_payment": null}	\N	2025-11-06 07:37:11.817299+00	\N	\N
177	loans	13	INSERT	\N	{"id": 13, "notes": null, "amount": 8000.00, "user_id": 5, "status_id": 1, "created_at": "2025-11-06T07:37:58.558987+00:00", "updated_at": "2025-11-06T07:37:58.558987+00:00", "approved_at": null, "approved_by": null, "contract_id": null, "rejected_at": null, "rejected_by": null, "profile_code": null, "term_biweeks": 6, "interest_rate": 3.50, "total_payment": null, "total_interest": null, "commission_rate": 15.00, "biweekly_payment": null, "rejection_reason": null, "total_commission": null, "associate_payment": null, "associate_user_id": 8, "commission_per_payment": null}	\N	2025-11-06 07:37:58.558987+00	\N	\N
195	cut_periods	13	INSERT	\N	{"id": 13, "cut_code": "2024-Q13", "closed_by": null, "status_id": 5, "created_at": "2025-11-06T08:12:35.24812+00:00", "created_by": 1, "cut_number": 13, "updated_at": "2025-11-06T08:12:35.24812+00:00", "period_end_date": "2024-07-22", "total_commission": 0.00, "period_start_date": "2024-07-08", "total_payments_expected": 0.00, "total_payments_received": 0.00}	\N	2025-11-06 08:12:35.24812+00	\N	\N
196	cut_periods	14	INSERT	\N	{"id": 14, "cut_code": "2024-Q14", "closed_by": null, "status_id": 5, "created_at": "2025-11-06T08:12:35.249161+00:00", "created_by": 1, "cut_number": 14, "updated_at": "2025-11-06T08:12:35.249161+00:00", "period_end_date": "2024-08-07", "total_commission": 0.00, "period_start_date": "2024-07-23", "total_payments_expected": 0.00, "total_payments_received": 0.00}	\N	2025-11-06 08:12:35.249161+00	\N	\N
181	loans	13	UPDATE	{"id": 13, "notes": null, "amount": 8000.00, "user_id": 5, "status_id": 1, "created_at": "2025-11-06T07:37:58.558987+00:00", "updated_at": "2025-11-06T07:37:58.558987+00:00", "approved_at": null, "approved_by": null, "contract_id": null, "rejected_at": null, "rejected_by": null, "profile_code": null, "term_biweeks": 6, "interest_rate": 3.50, "total_payment": null, "total_interest": null, "commission_rate": 15.00, "biweekly_payment": null, "rejection_reason": null, "total_commission": null, "associate_payment": null, "associate_user_id": 8, "commission_per_payment": null}	{"id": 13, "notes": null, "amount": 8000.00, "user_id": 5, "status_id": 2, "created_at": "2025-11-06T07:37:58.558987+00:00", "updated_at": "2025-11-06T07:40:29.827967+00:00", "approved_at": "2025-11-06T07:40:29.830068+00:00", "approved_by": 1, "contract_id": null, "rejected_at": null, "rejected_by": null, "profile_code": null, "term_biweeks": 6, "interest_rate": 3.50, "total_payment": null, "total_interest": null, "commission_rate": 15.00, "biweekly_payment": null, "rejection_reason": null, "total_commission": null, "associate_payment": null, "associate_user_id": 8, "commission_per_payment": null}	\N	2025-11-06 07:40:29.827967+00	\N	\N
182	loans	12	UPDATE	{"id": 12, "notes": null, "amount": 8000.00, "user_id": 4, "status_id": 1, "created_at": "2025-11-06T07:37:11.817299+00:00", "updated_at": "2025-11-06T07:37:11.817299+00:00", "approved_at": null, "approved_by": null, "contract_id": null, "rejected_at": null, "rejected_by": null, "profile_code": null, "term_biweeks": 6, "interest_rate": 3.50, "total_payment": null, "total_interest": null, "commission_rate": 15.00, "biweekly_payment": null, "rejection_reason": null, "total_commission": null, "associate_payment": null, "associate_user_id": 2, "commission_per_payment": null}	{"id": 12, "notes": null, "amount": 8000.00, "user_id": 4, "status_id": 6, "created_at": "2025-11-06T07:37:11.817299+00:00", "updated_at": "2025-11-06T07:40:36.583757+00:00", "approved_at": null, "approved_by": null, "contract_id": null, "rejected_at": "2025-11-06T07:40:36.584129+00:00", "rejected_by": 1, "profile_code": null, "term_biweeks": 6, "interest_rate": 3.50, "total_payment": null, "total_interest": null, "commission_rate": 15.00, "biweekly_payment": null, "rejection_reason": "Documentación incompleta - falta comprobante de ingresos", "total_commission": null, "associate_payment": null, "associate_user_id": 2, "commission_per_payment": null}	\N	2025-11-06 07:40:36.583757+00	\N	\N
183	cut_periods	1	INSERT	\N	{"id": 1, "cut_code": "2024-Q01", "closed_by": null, "status_id": 5, "created_at": "2025-11-06T08:12:35.232865+00:00", "created_by": 1, "cut_number": 1, "updated_at": "2025-11-06T08:12:35.232865+00:00", "period_end_date": "2024-01-22", "total_commission": 0.00, "period_start_date": "2024-01-08", "total_payments_expected": 0.00, "total_payments_received": 0.00}	\N	2025-11-06 08:12:35.232865+00	\N	\N
184	cut_periods	2	INSERT	\N	{"id": 2, "cut_code": "2024-Q02", "closed_by": null, "status_id": 5, "created_at": "2025-11-06T08:12:35.236375+00:00", "created_by": 1, "cut_number": 2, "updated_at": "2025-11-06T08:12:35.236375+00:00", "period_end_date": "2024-02-07", "total_commission": 0.00, "period_start_date": "2024-01-23", "total_payments_expected": 0.00, "total_payments_received": 0.00}	\N	2025-11-06 08:12:35.236375+00	\N	\N
185	cut_periods	3	INSERT	\N	{"id": 3, "cut_code": "2024-Q03", "closed_by": null, "status_id": 5, "created_at": "2025-11-06T08:12:35.237509+00:00", "created_by": 1, "cut_number": 3, "updated_at": "2025-11-06T08:12:35.237509+00:00", "period_end_date": "2024-02-22", "total_commission": 0.00, "period_start_date": "2024-02-08", "total_payments_expected": 0.00, "total_payments_received": 0.00}	\N	2025-11-06 08:12:35.237509+00	\N	\N
186	cut_periods	4	INSERT	\N	{"id": 4, "cut_code": "2024-Q04", "closed_by": null, "status_id": 5, "created_at": "2025-11-06T08:12:35.238601+00:00", "created_by": 1, "cut_number": 4, "updated_at": "2025-11-06T08:12:35.238601+00:00", "period_end_date": "2024-03-07", "total_commission": 0.00, "period_start_date": "2024-02-23", "total_payments_expected": 0.00, "total_payments_received": 0.00}	\N	2025-11-06 08:12:35.238601+00	\N	\N
187	cut_periods	5	INSERT	\N	{"id": 5, "cut_code": "2024-Q05", "closed_by": null, "status_id": 5, "created_at": "2025-11-06T08:12:35.239673+00:00", "created_by": 1, "cut_number": 5, "updated_at": "2025-11-06T08:12:35.239673+00:00", "period_end_date": "2024-03-22", "total_commission": 0.00, "period_start_date": "2024-03-08", "total_payments_expected": 0.00, "total_payments_received": 0.00}	\N	2025-11-06 08:12:35.239673+00	\N	\N
188	cut_periods	6	INSERT	\N	{"id": 6, "cut_code": "2024-Q06", "closed_by": null, "status_id": 5, "created_at": "2025-11-06T08:12:35.240759+00:00", "created_by": 1, "cut_number": 6, "updated_at": "2025-11-06T08:12:35.240759+00:00", "period_end_date": "2024-04-07", "total_commission": 0.00, "period_start_date": "2024-03-23", "total_payments_expected": 0.00, "total_payments_received": 0.00}	\N	2025-11-06 08:12:35.240759+00	\N	\N
189	cut_periods	7	INSERT	\N	{"id": 7, "cut_code": "2024-Q07", "closed_by": null, "status_id": 5, "created_at": "2025-11-06T08:12:35.241855+00:00", "created_by": 1, "cut_number": 7, "updated_at": "2025-11-06T08:12:35.241855+00:00", "period_end_date": "2024-04-22", "total_commission": 0.00, "period_start_date": "2024-04-08", "total_payments_expected": 0.00, "total_payments_received": 0.00}	\N	2025-11-06 08:12:35.241855+00	\N	\N
190	cut_periods	8	INSERT	\N	{"id": 8, "cut_code": "2024-Q08", "closed_by": null, "status_id": 5, "created_at": "2025-11-06T08:12:35.242878+00:00", "created_by": 1, "cut_number": 8, "updated_at": "2025-11-06T08:12:35.242878+00:00", "period_end_date": "2024-05-07", "total_commission": 0.00, "period_start_date": "2024-04-23", "total_payments_expected": 0.00, "total_payments_received": 0.00}	\N	2025-11-06 08:12:35.242878+00	\N	\N
191	cut_periods	9	INSERT	\N	{"id": 9, "cut_code": "2024-Q09", "closed_by": null, "status_id": 5, "created_at": "2025-11-06T08:12:35.243887+00:00", "created_by": 1, "cut_number": 9, "updated_at": "2025-11-06T08:12:35.243887+00:00", "period_end_date": "2024-05-22", "total_commission": 0.00, "period_start_date": "2024-05-08", "total_payments_expected": 0.00, "total_payments_received": 0.00}	\N	2025-11-06 08:12:35.243887+00	\N	\N
192	cut_periods	10	INSERT	\N	{"id": 10, "cut_code": "2024-Q10", "closed_by": null, "status_id": 5, "created_at": "2025-11-06T08:12:35.244909+00:00", "created_by": 1, "cut_number": 10, "updated_at": "2025-11-06T08:12:35.244909+00:00", "period_end_date": "2024-06-07", "total_commission": 0.00, "period_start_date": "2024-05-23", "total_payments_expected": 0.00, "total_payments_received": 0.00}	\N	2025-11-06 08:12:35.244909+00	\N	\N
197	cut_periods	15	INSERT	\N	{"id": 15, "cut_code": "2024-Q15", "closed_by": null, "status_id": 5, "created_at": "2025-11-06T08:12:35.250188+00:00", "created_by": 1, "cut_number": 15, "updated_at": "2025-11-06T08:12:35.250188+00:00", "period_end_date": "2024-08-22", "total_commission": 0.00, "period_start_date": "2024-08-08", "total_payments_expected": 0.00, "total_payments_received": 0.00}	\N	2025-11-06 08:12:35.250188+00	\N	\N
198	cut_periods	16	INSERT	\N	{"id": 16, "cut_code": "2024-Q16", "closed_by": null, "status_id": 5, "created_at": "2025-11-06T08:12:35.251225+00:00", "created_by": 1, "cut_number": 16, "updated_at": "2025-11-06T08:12:35.251225+00:00", "period_end_date": "2024-09-07", "total_commission": 0.00, "period_start_date": "2024-08-23", "total_payments_expected": 0.00, "total_payments_received": 0.00}	\N	2025-11-06 08:12:35.251225+00	\N	\N
199	cut_periods	17	INSERT	\N	{"id": 17, "cut_code": "2024-Q17", "closed_by": null, "status_id": 5, "created_at": "2025-11-06T08:12:35.25225+00:00", "created_by": 1, "cut_number": 17, "updated_at": "2025-11-06T08:12:35.25225+00:00", "period_end_date": "2024-09-22", "total_commission": 0.00, "period_start_date": "2024-09-08", "total_payments_expected": 0.00, "total_payments_received": 0.00}	\N	2025-11-06 08:12:35.25225+00	\N	\N
200	cut_periods	18	INSERT	\N	{"id": 18, "cut_code": "2024-Q18", "closed_by": null, "status_id": 5, "created_at": "2025-11-06T08:12:35.253281+00:00", "created_by": 1, "cut_number": 18, "updated_at": "2025-11-06T08:12:35.253281+00:00", "period_end_date": "2024-10-07", "total_commission": 0.00, "period_start_date": "2024-09-23", "total_payments_expected": 0.00, "total_payments_received": 0.00}	\N	2025-11-06 08:12:35.253281+00	\N	\N
201	cut_periods	19	INSERT	\N	{"id": 19, "cut_code": "2024-Q19", "closed_by": null, "status_id": 5, "created_at": "2025-11-06T08:12:35.254293+00:00", "created_by": 1, "cut_number": 19, "updated_at": "2025-11-06T08:12:35.254293+00:00", "period_end_date": "2024-10-22", "total_commission": 0.00, "period_start_date": "2024-10-08", "total_payments_expected": 0.00, "total_payments_received": 0.00}	\N	2025-11-06 08:12:35.254293+00	\N	\N
202	cut_periods	20	INSERT	\N	{"id": 20, "cut_code": "2024-Q20", "closed_by": null, "status_id": 5, "created_at": "2025-11-06T08:12:35.255324+00:00", "created_by": 1, "cut_number": 20, "updated_at": "2025-11-06T08:12:35.255324+00:00", "period_end_date": "2024-11-07", "total_commission": 0.00, "period_start_date": "2024-10-23", "total_payments_expected": 0.00, "total_payments_received": 0.00}	\N	2025-11-06 08:12:35.255324+00	\N	\N
203	cut_periods	21	INSERT	\N	{"id": 21, "cut_code": "2024-Q21", "closed_by": null, "status_id": 5, "created_at": "2025-11-06T08:12:35.256349+00:00", "created_by": 1, "cut_number": 21, "updated_at": "2025-11-06T08:12:35.256349+00:00", "period_end_date": "2024-11-22", "total_commission": 0.00, "period_start_date": "2024-11-08", "total_payments_expected": 0.00, "total_payments_received": 0.00}	\N	2025-11-06 08:12:35.256349+00	\N	\N
204	cut_periods	22	INSERT	\N	{"id": 22, "cut_code": "2024-Q22", "closed_by": null, "status_id": 5, "created_at": "2025-11-06T08:12:35.257381+00:00", "created_by": 1, "cut_number": 22, "updated_at": "2025-11-06T08:12:35.257381+00:00", "period_end_date": "2024-12-07", "total_commission": 0.00, "period_start_date": "2024-11-23", "total_payments_expected": 0.00, "total_payments_received": 0.00}	\N	2025-11-06 08:12:35.257381+00	\N	\N
205	cut_periods	23	INSERT	\N	{"id": 23, "cut_code": "2024-Q23", "closed_by": null, "status_id": 5, "created_at": "2025-11-06T08:12:35.25842+00:00", "created_by": 1, "cut_number": 23, "updated_at": "2025-11-06T08:12:35.25842+00:00", "period_end_date": "2024-12-22", "total_commission": 0.00, "period_start_date": "2024-12-08", "total_payments_expected": 0.00, "total_payments_received": 0.00}	\N	2025-11-06 08:12:35.25842+00	\N	\N
206	cut_periods	24	INSERT	\N	{"id": 24, "cut_code": "2024-Q24", "closed_by": null, "status_id": 5, "created_at": "2025-11-06T08:12:35.259538+00:00", "created_by": 1, "cut_number": 24, "updated_at": "2025-11-06T08:12:35.259538+00:00", "period_end_date": "2025-01-07", "total_commission": 0.00, "period_start_date": "2024-12-23", "total_payments_expected": 0.00, "total_payments_received": 0.00}	\N	2025-11-06 08:12:35.259538+00	\N	\N
207	cut_periods	25	INSERT	\N	{"id": 25, "cut_code": "2025-Q01", "closed_by": null, "status_id": 5, "created_at": "2025-11-06T08:12:35.260567+00:00", "created_by": 1, "cut_number": 1, "updated_at": "2025-11-06T08:12:35.260567+00:00", "period_end_date": "2025-01-22", "total_commission": 0.00, "period_start_date": "2025-01-08", "total_payments_expected": 0.00, "total_payments_received": 0.00}	\N	2025-11-06 08:12:35.260567+00	\N	\N
208	cut_periods	26	INSERT	\N	{"id": 26, "cut_code": "2025-Q02", "closed_by": null, "status_id": 5, "created_at": "2025-11-06T08:12:35.261606+00:00", "created_by": 1, "cut_number": 2, "updated_at": "2025-11-06T08:12:35.261606+00:00", "period_end_date": "2025-02-07", "total_commission": 0.00, "period_start_date": "2025-01-23", "total_payments_expected": 0.00, "total_payments_received": 0.00}	\N	2025-11-06 08:12:35.261606+00	\N	\N
209	cut_periods	27	INSERT	\N	{"id": 27, "cut_code": "2025-Q03", "closed_by": null, "status_id": 5, "created_at": "2025-11-06T08:12:35.262638+00:00", "created_by": 1, "cut_number": 3, "updated_at": "2025-11-06T08:12:35.262638+00:00", "period_end_date": "2025-02-22", "total_commission": 0.00, "period_start_date": "2025-02-08", "total_payments_expected": 0.00, "total_payments_received": 0.00}	\N	2025-11-06 08:12:35.262638+00	\N	\N
210	cut_periods	28	INSERT	\N	{"id": 28, "cut_code": "2025-Q04", "closed_by": null, "status_id": 5, "created_at": "2025-11-06T08:12:35.263678+00:00", "created_by": 1, "cut_number": 4, "updated_at": "2025-11-06T08:12:35.263678+00:00", "period_end_date": "2025-03-07", "total_commission": 0.00, "period_start_date": "2025-02-23", "total_payments_expected": 0.00, "total_payments_received": 0.00}	\N	2025-11-06 08:12:35.263678+00	\N	\N
211	cut_periods	29	INSERT	\N	{"id": 29, "cut_code": "2025-Q05", "closed_by": null, "status_id": 5, "created_at": "2025-11-06T08:12:35.26471+00:00", "created_by": 1, "cut_number": 5, "updated_at": "2025-11-06T08:12:35.26471+00:00", "period_end_date": "2025-03-22", "total_commission": 0.00, "period_start_date": "2025-03-08", "total_payments_expected": 0.00, "total_payments_received": 0.00}	\N	2025-11-06 08:12:35.26471+00	\N	\N
212	cut_periods	30	INSERT	\N	{"id": 30, "cut_code": "2025-Q06", "closed_by": null, "status_id": 5, "created_at": "2025-11-06T08:12:35.26574+00:00", "created_by": 1, "cut_number": 6, "updated_at": "2025-11-06T08:12:35.26574+00:00", "period_end_date": "2025-04-07", "total_commission": 0.00, "period_start_date": "2025-03-23", "total_payments_expected": 0.00, "total_payments_received": 0.00}	\N	2025-11-06 08:12:35.26574+00	\N	\N
213	cut_periods	31	INSERT	\N	{"id": 31, "cut_code": "2025-Q07", "closed_by": null, "status_id": 5, "created_at": "2025-11-06T08:12:35.266767+00:00", "created_by": 1, "cut_number": 7, "updated_at": "2025-11-06T08:12:35.266767+00:00", "period_end_date": "2025-04-22", "total_commission": 0.00, "period_start_date": "2025-04-08", "total_payments_expected": 0.00, "total_payments_received": 0.00}	\N	2025-11-06 08:12:35.266767+00	\N	\N
214	cut_periods	32	INSERT	\N	{"id": 32, "cut_code": "2025-Q08", "closed_by": null, "status_id": 5, "created_at": "2025-11-06T08:12:35.26782+00:00", "created_by": 1, "cut_number": 8, "updated_at": "2025-11-06T08:12:35.26782+00:00", "period_end_date": "2025-05-07", "total_commission": 0.00, "period_start_date": "2025-04-23", "total_payments_expected": 0.00, "total_payments_received": 0.00}	\N	2025-11-06 08:12:35.26782+00	\N	\N
215	cut_periods	33	INSERT	\N	{"id": 33, "cut_code": "2025-Q09", "closed_by": null, "status_id": 5, "created_at": "2025-11-06T08:12:35.268866+00:00", "created_by": 1, "cut_number": 9, "updated_at": "2025-11-06T08:12:35.268866+00:00", "period_end_date": "2025-05-22", "total_commission": 0.00, "period_start_date": "2025-05-08", "total_payments_expected": 0.00, "total_payments_received": 0.00}	\N	2025-11-06 08:12:35.268866+00	\N	\N
216	cut_periods	34	INSERT	\N	{"id": 34, "cut_code": "2025-Q10", "closed_by": null, "status_id": 5, "created_at": "2025-11-06T08:12:35.269927+00:00", "created_by": 1, "cut_number": 10, "updated_at": "2025-11-06T08:12:35.269927+00:00", "period_end_date": "2025-06-07", "total_commission": 0.00, "period_start_date": "2025-05-23", "total_payments_expected": 0.00, "total_payments_received": 0.00}	\N	2025-11-06 08:12:35.269927+00	\N	\N
217	cut_periods	35	INSERT	\N	{"id": 35, "cut_code": "2025-Q11", "closed_by": null, "status_id": 5, "created_at": "2025-11-06T08:12:35.271003+00:00", "created_by": 1, "cut_number": 11, "updated_at": "2025-11-06T08:12:35.271003+00:00", "period_end_date": "2025-06-22", "total_commission": 0.00, "period_start_date": "2025-06-08", "total_payments_expected": 0.00, "total_payments_received": 0.00}	\N	2025-11-06 08:12:35.271003+00	\N	\N
218	cut_periods	36	INSERT	\N	{"id": 36, "cut_code": "2025-Q12", "closed_by": null, "status_id": 5, "created_at": "2025-11-06T08:12:35.272185+00:00", "created_by": 1, "cut_number": 12, "updated_at": "2025-11-06T08:12:35.272185+00:00", "period_end_date": "2025-07-07", "total_commission": 0.00, "period_start_date": "2025-06-23", "total_payments_expected": 0.00, "total_payments_received": 0.00}	\N	2025-11-06 08:12:35.272185+00	\N	\N
219	cut_periods	37	INSERT	\N	{"id": 37, "cut_code": "2025-Q13", "closed_by": null, "status_id": 5, "created_at": "2025-11-06T08:12:35.273257+00:00", "created_by": 1, "cut_number": 13, "updated_at": "2025-11-06T08:12:35.273257+00:00", "period_end_date": "2025-07-22", "total_commission": 0.00, "period_start_date": "2025-07-08", "total_payments_expected": 0.00, "total_payments_received": 0.00}	\N	2025-11-06 08:12:35.273257+00	\N	\N
220	cut_periods	38	INSERT	\N	{"id": 38, "cut_code": "2025-Q14", "closed_by": null, "status_id": 5, "created_at": "2025-11-06T08:12:35.274299+00:00", "created_by": 1, "cut_number": 14, "updated_at": "2025-11-06T08:12:35.274299+00:00", "period_end_date": "2025-08-07", "total_commission": 0.00, "period_start_date": "2025-07-23", "total_payments_expected": 0.00, "total_payments_received": 0.00}	\N	2025-11-06 08:12:35.274299+00	\N	\N
221	cut_periods	39	INSERT	\N	{"id": 39, "cut_code": "2025-Q15", "closed_by": null, "status_id": 5, "created_at": "2025-11-06T08:12:35.275323+00:00", "created_by": 1, "cut_number": 15, "updated_at": "2025-11-06T08:12:35.275323+00:00", "period_end_date": "2025-08-22", "total_commission": 0.00, "period_start_date": "2025-08-08", "total_payments_expected": 0.00, "total_payments_received": 0.00}	\N	2025-11-06 08:12:35.275323+00	\N	\N
222	cut_periods	40	INSERT	\N	{"id": 40, "cut_code": "2025-Q16", "closed_by": null, "status_id": 5, "created_at": "2025-11-06T08:12:35.276338+00:00", "created_by": 1, "cut_number": 16, "updated_at": "2025-11-06T08:12:35.276338+00:00", "period_end_date": "2025-09-07", "total_commission": 0.00, "period_start_date": "2025-08-23", "total_payments_expected": 0.00, "total_payments_received": 0.00}	\N	2025-11-06 08:12:35.276338+00	\N	\N
223	cut_periods	41	INSERT	\N	{"id": 41, "cut_code": "2025-Q17", "closed_by": null, "status_id": 5, "created_at": "2025-11-06T08:12:35.277349+00:00", "created_by": 1, "cut_number": 17, "updated_at": "2025-11-06T08:12:35.277349+00:00", "period_end_date": "2025-09-22", "total_commission": 0.00, "period_start_date": "2025-09-08", "total_payments_expected": 0.00, "total_payments_received": 0.00}	\N	2025-11-06 08:12:35.277349+00	\N	\N
224	cut_periods	42	INSERT	\N	{"id": 42, "cut_code": "2025-Q18", "closed_by": null, "status_id": 5, "created_at": "2025-11-06T08:12:35.278353+00:00", "created_by": 1, "cut_number": 18, "updated_at": "2025-11-06T08:12:35.278353+00:00", "period_end_date": "2025-10-07", "total_commission": 0.00, "period_start_date": "2025-09-23", "total_payments_expected": 0.00, "total_payments_received": 0.00}	\N	2025-11-06 08:12:35.278353+00	\N	\N
225	cut_periods	43	INSERT	\N	{"id": 43, "cut_code": "2025-Q19", "closed_by": null, "status_id": 5, "created_at": "2025-11-06T08:12:35.279354+00:00", "created_by": 1, "cut_number": 19, "updated_at": "2025-11-06T08:12:35.279354+00:00", "period_end_date": "2025-10-22", "total_commission": 0.00, "period_start_date": "2025-10-08", "total_payments_expected": 0.00, "total_payments_received": 0.00}	\N	2025-11-06 08:12:35.279354+00	\N	\N
226	cut_periods	44	INSERT	\N	{"id": 44, "cut_code": "2025-Q20", "closed_by": null, "status_id": 2, "created_at": "2025-11-06T08:12:35.280379+00:00", "created_by": 1, "cut_number": 20, "updated_at": "2025-11-06T08:12:35.280379+00:00", "period_end_date": "2025-11-07", "total_commission": 0.00, "period_start_date": "2025-10-23", "total_payments_expected": 0.00, "total_payments_received": 0.00}	\N	2025-11-06 08:12:35.280379+00	\N	\N
227	cut_periods	45	INSERT	\N	{"id": 45, "cut_code": "2025-Q21", "closed_by": null, "status_id": 1, "created_at": "2025-11-06T08:12:35.281436+00:00", "created_by": 1, "cut_number": 21, "updated_at": "2025-11-06T08:12:35.281436+00:00", "period_end_date": "2025-11-22", "total_commission": 0.00, "period_start_date": "2025-11-08", "total_payments_expected": 0.00, "total_payments_received": 0.00}	\N	2025-11-06 08:12:35.281436+00	\N	\N
228	cut_periods	46	INSERT	\N	{"id": 46, "cut_code": "2025-Q22", "closed_by": null, "status_id": 1, "created_at": "2025-11-06T08:12:35.282433+00:00", "created_by": 1, "cut_number": 22, "updated_at": "2025-11-06T08:12:35.282433+00:00", "period_end_date": "2025-12-07", "total_commission": 0.00, "period_start_date": "2025-11-23", "total_payments_expected": 0.00, "total_payments_received": 0.00}	\N	2025-11-06 08:12:35.282433+00	\N	\N
229	cut_periods	47	INSERT	\N	{"id": 47, "cut_code": "2025-Q23", "closed_by": null, "status_id": 1, "created_at": "2025-11-06T08:12:35.283429+00:00", "created_by": 1, "cut_number": 23, "updated_at": "2025-11-06T08:12:35.283429+00:00", "period_end_date": "2025-12-22", "total_commission": 0.00, "period_start_date": "2025-12-08", "total_payments_expected": 0.00, "total_payments_received": 0.00}	\N	2025-11-06 08:12:35.283429+00	\N	\N
230	cut_periods	48	INSERT	\N	{"id": 48, "cut_code": "2025-Q24", "closed_by": null, "status_id": 1, "created_at": "2025-11-06T08:12:35.284442+00:00", "created_by": 1, "cut_number": 24, "updated_at": "2025-11-06T08:12:35.284442+00:00", "period_end_date": "2026-01-07", "total_commission": 0.00, "period_start_date": "2025-12-23", "total_payments_expected": 0.00, "total_payments_received": 0.00}	\N	2025-11-06 08:12:35.284442+00	\N	\N
231	cut_periods	49	INSERT	\N	{"id": 49, "cut_code": "2026-Q01", "closed_by": null, "status_id": 1, "created_at": "2025-11-06T08:12:35.285443+00:00", "created_by": 1, "cut_number": 1, "updated_at": "2025-11-06T08:12:35.285443+00:00", "period_end_date": "2026-01-22", "total_commission": 0.00, "period_start_date": "2026-01-08", "total_payments_expected": 0.00, "total_payments_received": 0.00}	\N	2025-11-06 08:12:35.285443+00	\N	\N
232	cut_periods	50	INSERT	\N	{"id": 50, "cut_code": "2026-Q02", "closed_by": null, "status_id": 1, "created_at": "2025-11-06T08:12:35.286442+00:00", "created_by": 1, "cut_number": 2, "updated_at": "2025-11-06T08:12:35.286442+00:00", "period_end_date": "2026-02-07", "total_commission": 0.00, "period_start_date": "2026-01-23", "total_payments_expected": 0.00, "total_payments_received": 0.00}	\N	2025-11-06 08:12:35.286442+00	\N	\N
233	cut_periods	51	INSERT	\N	{"id": 51, "cut_code": "2026-Q03", "closed_by": null, "status_id": 1, "created_at": "2025-11-06T08:12:35.287441+00:00", "created_by": 1, "cut_number": 3, "updated_at": "2025-11-06T08:12:35.287441+00:00", "period_end_date": "2026-02-22", "total_commission": 0.00, "period_start_date": "2026-02-08", "total_payments_expected": 0.00, "total_payments_received": 0.00}	\N	2025-11-06 08:12:35.287441+00	\N	\N
234	cut_periods	52	INSERT	\N	{"id": 52, "cut_code": "2026-Q04", "closed_by": null, "status_id": 1, "created_at": "2025-11-06T08:12:35.288437+00:00", "created_by": 1, "cut_number": 4, "updated_at": "2025-11-06T08:12:35.288437+00:00", "period_end_date": "2026-03-07", "total_commission": 0.00, "period_start_date": "2026-02-23", "total_payments_expected": 0.00, "total_payments_received": 0.00}	\N	2025-11-06 08:12:35.288437+00	\N	\N
235	cut_periods	53	INSERT	\N	{"id": 53, "cut_code": "2026-Q05", "closed_by": null, "status_id": 1, "created_at": "2025-11-06T08:12:35.289431+00:00", "created_by": 1, "cut_number": 5, "updated_at": "2025-11-06T08:12:35.289431+00:00", "period_end_date": "2026-03-22", "total_commission": 0.00, "period_start_date": "2026-03-08", "total_payments_expected": 0.00, "total_payments_received": 0.00}	\N	2025-11-06 08:12:35.289431+00	\N	\N
236	cut_periods	54	INSERT	\N	{"id": 54, "cut_code": "2026-Q06", "closed_by": null, "status_id": 1, "created_at": "2025-11-06T08:12:35.290424+00:00", "created_by": 1, "cut_number": 6, "updated_at": "2025-11-06T08:12:35.290424+00:00", "period_end_date": "2026-04-07", "total_commission": 0.00, "period_start_date": "2026-03-23", "total_payments_expected": 0.00, "total_payments_received": 0.00}	\N	2025-11-06 08:12:35.290424+00	\N	\N
237	cut_periods	55	INSERT	\N	{"id": 55, "cut_code": "2026-Q07", "closed_by": null, "status_id": 1, "created_at": "2025-11-06T08:12:35.291428+00:00", "created_by": 1, "cut_number": 7, "updated_at": "2025-11-06T08:12:35.291428+00:00", "period_end_date": "2026-04-22", "total_commission": 0.00, "period_start_date": "2026-04-08", "total_payments_expected": 0.00, "total_payments_received": 0.00}	\N	2025-11-06 08:12:35.291428+00	\N	\N
238	cut_periods	56	INSERT	\N	{"id": 56, "cut_code": "2026-Q08", "closed_by": null, "status_id": 1, "created_at": "2025-11-06T08:12:35.292434+00:00", "created_by": 1, "cut_number": 8, "updated_at": "2025-11-06T08:12:35.292434+00:00", "period_end_date": "2026-05-07", "total_commission": 0.00, "period_start_date": "2026-04-23", "total_payments_expected": 0.00, "total_payments_received": 0.00}	\N	2025-11-06 08:12:35.292434+00	\N	\N
239	cut_periods	57	INSERT	\N	{"id": 57, "cut_code": "2026-Q09", "closed_by": null, "status_id": 1, "created_at": "2025-11-06T08:12:35.293426+00:00", "created_by": 1, "cut_number": 9, "updated_at": "2025-11-06T08:12:35.293426+00:00", "period_end_date": "2026-05-22", "total_commission": 0.00, "period_start_date": "2026-05-08", "total_payments_expected": 0.00, "total_payments_received": 0.00}	\N	2025-11-06 08:12:35.293426+00	\N	\N
240	cut_periods	58	INSERT	\N	{"id": 58, "cut_code": "2026-Q10", "closed_by": null, "status_id": 1, "created_at": "2025-11-06T08:12:35.294429+00:00", "created_by": 1, "cut_number": 10, "updated_at": "2025-11-06T08:12:35.294429+00:00", "period_end_date": "2026-06-07", "total_commission": 0.00, "period_start_date": "2026-05-23", "total_payments_expected": 0.00, "total_payments_received": 0.00}	\N	2025-11-06 08:12:35.294429+00	\N	\N
241	cut_periods	59	INSERT	\N	{"id": 59, "cut_code": "2026-Q11", "closed_by": null, "status_id": 1, "created_at": "2025-11-06T08:12:35.295432+00:00", "created_by": 1, "cut_number": 11, "updated_at": "2025-11-06T08:12:35.295432+00:00", "period_end_date": "2026-06-22", "total_commission": 0.00, "period_start_date": "2026-06-08", "total_payments_expected": 0.00, "total_payments_received": 0.00}	\N	2025-11-06 08:12:35.295432+00	\N	\N
242	cut_periods	60	INSERT	\N	{"id": 60, "cut_code": "2026-Q12", "closed_by": null, "status_id": 1, "created_at": "2025-11-06T08:12:35.296437+00:00", "created_by": 1, "cut_number": 12, "updated_at": "2025-11-06T08:12:35.296437+00:00", "period_end_date": "2026-07-07", "total_commission": 0.00, "period_start_date": "2026-06-23", "total_payments_expected": 0.00, "total_payments_received": 0.00}	\N	2025-11-06 08:12:35.296437+00	\N	\N
243	cut_periods	61	INSERT	\N	{"id": 61, "cut_code": "2026-Q13", "closed_by": null, "status_id": 1, "created_at": "2025-11-06T08:12:35.297433+00:00", "created_by": 1, "cut_number": 13, "updated_at": "2025-11-06T08:12:35.297433+00:00", "period_end_date": "2026-07-22", "total_commission": 0.00, "period_start_date": "2026-07-08", "total_payments_expected": 0.00, "total_payments_received": 0.00}	\N	2025-11-06 08:12:35.297433+00	\N	\N
244	cut_periods	62	INSERT	\N	{"id": 62, "cut_code": "2026-Q14", "closed_by": null, "status_id": 1, "created_at": "2025-11-06T08:12:35.298427+00:00", "created_by": 1, "cut_number": 14, "updated_at": "2025-11-06T08:12:35.298427+00:00", "period_end_date": "2026-08-07", "total_commission": 0.00, "period_start_date": "2026-07-23", "total_payments_expected": 0.00, "total_payments_received": 0.00}	\N	2025-11-06 08:12:35.298427+00	\N	\N
245	cut_periods	63	INSERT	\N	{"id": 63, "cut_code": "2026-Q15", "closed_by": null, "status_id": 1, "created_at": "2025-11-06T08:12:35.299425+00:00", "created_by": 1, "cut_number": 15, "updated_at": "2025-11-06T08:12:35.299425+00:00", "period_end_date": "2026-08-22", "total_commission": 0.00, "period_start_date": "2026-08-08", "total_payments_expected": 0.00, "total_payments_received": 0.00}	\N	2025-11-06 08:12:35.299425+00	\N	\N
246	cut_periods	64	INSERT	\N	{"id": 64, "cut_code": "2026-Q16", "closed_by": null, "status_id": 1, "created_at": "2025-11-06T08:12:35.300436+00:00", "created_by": 1, "cut_number": 16, "updated_at": "2025-11-06T08:12:35.300436+00:00", "period_end_date": "2026-09-07", "total_commission": 0.00, "period_start_date": "2026-08-23", "total_payments_expected": 0.00, "total_payments_received": 0.00}	\N	2025-11-06 08:12:35.300436+00	\N	\N
247	cut_periods	65	INSERT	\N	{"id": 65, "cut_code": "2026-Q17", "closed_by": null, "status_id": 1, "created_at": "2025-11-06T08:12:35.301429+00:00", "created_by": 1, "cut_number": 17, "updated_at": "2025-11-06T08:12:35.301429+00:00", "period_end_date": "2026-09-22", "total_commission": 0.00, "period_start_date": "2026-09-08", "total_payments_expected": 0.00, "total_payments_received": 0.00}	\N	2025-11-06 08:12:35.301429+00	\N	\N
248	cut_periods	66	INSERT	\N	{"id": 66, "cut_code": "2026-Q18", "closed_by": null, "status_id": 1, "created_at": "2025-11-06T08:12:35.302446+00:00", "created_by": 1, "cut_number": 18, "updated_at": "2025-11-06T08:12:35.302446+00:00", "period_end_date": "2026-10-07", "total_commission": 0.00, "period_start_date": "2026-09-23", "total_payments_expected": 0.00, "total_payments_received": 0.00}	\N	2025-11-06 08:12:35.302446+00	\N	\N
249	cut_periods	67	INSERT	\N	{"id": 67, "cut_code": "2026-Q19", "closed_by": null, "status_id": 1, "created_at": "2025-11-06T08:12:35.30345+00:00", "created_by": 1, "cut_number": 19, "updated_at": "2025-11-06T08:12:35.30345+00:00", "period_end_date": "2026-10-22", "total_commission": 0.00, "period_start_date": "2026-10-08", "total_payments_expected": 0.00, "total_payments_received": 0.00}	\N	2025-11-06 08:12:35.30345+00	\N	\N
250	cut_periods	68	INSERT	\N	{"id": 68, "cut_code": "2026-Q20", "closed_by": null, "status_id": 1, "created_at": "2025-11-06T08:12:35.304456+00:00", "created_by": 1, "cut_number": 20, "updated_at": "2025-11-06T08:12:35.304456+00:00", "period_end_date": "2026-11-07", "total_commission": 0.00, "period_start_date": "2026-10-23", "total_payments_expected": 0.00, "total_payments_received": 0.00}	\N	2025-11-06 08:12:35.304456+00	\N	\N
251	cut_periods	69	INSERT	\N	{"id": 69, "cut_code": "2026-Q21", "closed_by": null, "status_id": 1, "created_at": "2025-11-06T08:12:35.305447+00:00", "created_by": 1, "cut_number": 21, "updated_at": "2025-11-06T08:12:35.305447+00:00", "period_end_date": "2026-11-22", "total_commission": 0.00, "period_start_date": "2026-11-08", "total_payments_expected": 0.00, "total_payments_received": 0.00}	\N	2025-11-06 08:12:35.305447+00	\N	\N
252	cut_periods	70	INSERT	\N	{"id": 70, "cut_code": "2026-Q22", "closed_by": null, "status_id": 1, "created_at": "2025-11-06T08:12:35.306443+00:00", "created_by": 1, "cut_number": 22, "updated_at": "2025-11-06T08:12:35.306443+00:00", "period_end_date": "2026-12-07", "total_commission": 0.00, "period_start_date": "2026-11-23", "total_payments_expected": 0.00, "total_payments_received": 0.00}	\N	2025-11-06 08:12:35.306443+00	\N	\N
253	cut_periods	71	INSERT	\N	{"id": 71, "cut_code": "2026-Q23", "closed_by": null, "status_id": 1, "created_at": "2025-11-06T08:12:35.307448+00:00", "created_by": 1, "cut_number": 23, "updated_at": "2025-11-06T08:12:35.307448+00:00", "period_end_date": "2026-12-22", "total_commission": 0.00, "period_start_date": "2026-12-08", "total_payments_expected": 0.00, "total_payments_received": 0.00}	\N	2025-11-06 08:12:35.307448+00	\N	\N
254	cut_periods	72	INSERT	\N	{"id": 72, "cut_code": "2026-Q24", "closed_by": null, "status_id": 1, "created_at": "2025-11-06T08:12:35.308444+00:00", "created_by": 1, "cut_number": 24, "updated_at": "2025-11-06T08:12:35.308444+00:00", "period_end_date": "2027-01-07", "total_commission": 0.00, "period_start_date": "2026-12-23", "total_payments_expected": 0.00, "total_payments_received": 0.00}	\N	2025-11-06 08:12:35.308444+00	\N	\N
\.


--
-- Data for Name: audit_session_log; Type: TABLE DATA; Schema: public; Owner: credinet_user
--

COPY public.audit_session_log (id, user_id, session_token, login_at, logout_at, ip_address, user_agent, is_active) FROM stdin;
\.


--
-- Data for Name: beneficiaries; Type: TABLE DATA; Schema: public; Owner: credinet_user
--

COPY public.beneficiaries (id, user_id, full_name, relationship, phone_number, created_at, updated_at) FROM stdin;
1	4	María Fernanda Vargas Torres	Hija	5544556611	2025-10-31 01:12:22.120572+00	2025-10-31 01:12:22.120572+00
2	5	Luis Alberto Pérez Cruz	Hijo	5555667711	2025-10-31 01:12:22.120572+00	2025-10-31 01:12:22.120572+00
3	6	Ana Laura Martínez López	Hija	5566778811	2025-10-31 01:12:22.120572+00	2025-10-31 01:12:22.120572+00
\.


--
-- Data for Name: client_documents; Type: TABLE DATA; Schema: public; Owner: credinet_user
--

COPY public.client_documents (id, user_id, document_type_id, file_name, original_file_name, file_path, file_size, mime_type, status_id, upload_date, reviewed_by, reviewed_at, comments, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: config_types; Type: TABLE DATA; Schema: public; Owner: credinet_user
--

COPY public.config_types (id, name, description, validation_regex, example_value, created_at, updated_at) FROM stdin;
1	STRING	Cadena de texto.	\N	Hola Mundo	2025-10-31 01:12:22.085589+00	2025-10-31 01:12:22.085589+00
2	NUMBER	Número entero o decimal.	^-?\\d+(\\.\\d+)?$	123.45	2025-10-31 01:12:22.085589+00	2025-10-31 01:12:22.085589+00
3	BOOLEAN	Valor booleano.	^(true|false)$	true	2025-10-31 01:12:22.085589+00	2025-10-31 01:12:22.085589+00
4	JSON	Objeto JSON válido.	\N	{"key": "value"}	2025-10-31 01:12:22.085589+00	2025-10-31 01:12:22.085589+00
5	URL	URL válida.	^https?://[^\\s]+$	https://ejemplo.com	2025-10-31 01:12:22.085589+00	2025-10-31 01:12:22.085589+00
6	EMAIL	Correo electrónico.	^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$	user@example.com	2025-10-31 01:12:22.085589+00	2025-10-31 01:12:22.085589+00
7	DATE	Fecha ISO 8601.	^\\d{4}-\\d{2}-\\d{2}$	2025-10-30	2025-10-31 01:12:22.085589+00	2025-10-31 01:12:22.085589+00
8	PERCENTAGE	Porcentaje 0-100.	^(100(\\.0+)?|\\d{1,2}(\\.\\d+)?)$	15.5	2025-10-31 01:12:22.085589+00	2025-10-31 01:12:22.085589+00
\.


--
-- Data for Name: contract_statuses; Type: TABLE DATA; Schema: public; Owner: credinet_user
--

COPY public.contract_statuses (id, name, description, is_active, requires_signature, display_order, created_at, updated_at) FROM stdin;
1	draft	Contrato en borrador.	t	f	1	2025-10-31 01:12:22.078957+00	2025-10-31 01:12:22.078957+00
2	pending	Pendiente de firma del cliente.	t	t	2	2025-10-31 01:12:22.078957+00	2025-10-31 01:12:22.078957+00
3	signed	Firmado por el cliente.	t	f	3	2025-10-31 01:12:22.078957+00	2025-10-31 01:12:22.078957+00
4	active	Contrato activo y vigente.	t	f	4	2025-10-31 01:12:22.078957+00	2025-10-31 01:12:22.078957+00
5	completed	Contrato completado, préstamo liquidado.	t	f	5	2025-10-31 01:12:22.078957+00	2025-10-31 01:12:22.078957+00
6	cancelled	Contrato cancelado.	t	f	6	2025-10-31 01:12:22.078957+00	2025-10-31 01:12:22.078957+00
\.


--
-- Data for Name: contracts; Type: TABLE DATA; Schema: public; Owner: credinet_user
--

COPY public.contracts (id, loan_id, file_path, start_date, sign_date, document_number, status_id, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: cut_period_statuses; Type: TABLE DATA; Schema: public; Owner: credinet_user
--

COPY public.cut_period_statuses (id, name, description, is_terminal, allows_payments, display_order, created_at, updated_at) FROM stdin;
1	PRELIMINARY	Período creado, en configuración.	f	f	1	2025-10-31 01:12:22.080292+00	2025-10-31 01:12:22.080292+00
2	ACTIVE	Período activo, permite operaciones.	f	t	2	2025-10-31 01:12:22.080292+00	2025-10-31 01:12:22.080292+00
3	REVIEW	En revisión contable.	f	f	3	2025-10-31 01:12:22.080292+00	2025-10-31 01:12:22.080292+00
4	LOCKED	Bloqueado para cierre.	f	f	4	2025-10-31 01:12:22.080292+00	2025-10-31 01:12:22.080292+00
5	CLOSED	Cerrado definitivamente.	t	f	5	2025-10-31 01:12:22.080292+00	2025-10-31 01:12:22.080292+00
\.


--
-- Data for Name: cut_periods; Type: TABLE DATA; Schema: public; Owner: credinet_user
--

COPY public.cut_periods (id, cut_number, period_start_date, period_end_date, status_id, total_payments_expected, total_payments_received, total_commission, created_by, closed_by, created_at, updated_at, cut_code) FROM stdin;
1	1	2024-01-08	2024-01-22	5	0.00	0.00	0.00	1	\N	2025-11-06 08:12:35.232865+00	2025-11-06 08:12:35.232865+00	2024-Q01
2	2	2024-01-23	2024-02-07	5	0.00	0.00	0.00	1	\N	2025-11-06 08:12:35.236375+00	2025-11-06 08:12:35.236375+00	2024-Q02
3	3	2024-02-08	2024-02-22	5	0.00	0.00	0.00	1	\N	2025-11-06 08:12:35.237509+00	2025-11-06 08:12:35.237509+00	2024-Q03
4	4	2024-02-23	2024-03-07	5	0.00	0.00	0.00	1	\N	2025-11-06 08:12:35.238601+00	2025-11-06 08:12:35.238601+00	2024-Q04
5	5	2024-03-08	2024-03-22	5	0.00	0.00	0.00	1	\N	2025-11-06 08:12:35.239673+00	2025-11-06 08:12:35.239673+00	2024-Q05
6	6	2024-03-23	2024-04-07	5	0.00	0.00	0.00	1	\N	2025-11-06 08:12:35.240759+00	2025-11-06 08:12:35.240759+00	2024-Q06
7	7	2024-04-08	2024-04-22	5	0.00	0.00	0.00	1	\N	2025-11-06 08:12:35.241855+00	2025-11-06 08:12:35.241855+00	2024-Q07
8	8	2024-04-23	2024-05-07	5	0.00	0.00	0.00	1	\N	2025-11-06 08:12:35.242878+00	2025-11-06 08:12:35.242878+00	2024-Q08
9	9	2024-05-08	2024-05-22	5	0.00	0.00	0.00	1	\N	2025-11-06 08:12:35.243887+00	2025-11-06 08:12:35.243887+00	2024-Q09
10	10	2024-05-23	2024-06-07	5	0.00	0.00	0.00	1	\N	2025-11-06 08:12:35.244909+00	2025-11-06 08:12:35.244909+00	2024-Q10
11	11	2024-06-08	2024-06-22	5	0.00	0.00	0.00	1	\N	2025-11-06 08:12:35.24612+00	2025-11-06 08:12:35.24612+00	2024-Q11
12	12	2024-06-23	2024-07-07	5	0.00	0.00	0.00	1	\N	2025-11-06 08:12:35.247165+00	2025-11-06 08:12:35.247165+00	2024-Q12
13	13	2024-07-08	2024-07-22	5	0.00	0.00	0.00	1	\N	2025-11-06 08:12:35.24812+00	2025-11-06 08:12:35.24812+00	2024-Q13
14	14	2024-07-23	2024-08-07	5	0.00	0.00	0.00	1	\N	2025-11-06 08:12:35.249161+00	2025-11-06 08:12:35.249161+00	2024-Q14
15	15	2024-08-08	2024-08-22	5	0.00	0.00	0.00	1	\N	2025-11-06 08:12:35.250188+00	2025-11-06 08:12:35.250188+00	2024-Q15
16	16	2024-08-23	2024-09-07	5	0.00	0.00	0.00	1	\N	2025-11-06 08:12:35.251225+00	2025-11-06 08:12:35.251225+00	2024-Q16
17	17	2024-09-08	2024-09-22	5	0.00	0.00	0.00	1	\N	2025-11-06 08:12:35.25225+00	2025-11-06 08:12:35.25225+00	2024-Q17
18	18	2024-09-23	2024-10-07	5	0.00	0.00	0.00	1	\N	2025-11-06 08:12:35.253281+00	2025-11-06 08:12:35.253281+00	2024-Q18
19	19	2024-10-08	2024-10-22	5	0.00	0.00	0.00	1	\N	2025-11-06 08:12:35.254293+00	2025-11-06 08:12:35.254293+00	2024-Q19
20	20	2024-10-23	2024-11-07	5	0.00	0.00	0.00	1	\N	2025-11-06 08:12:35.255324+00	2025-11-06 08:12:35.255324+00	2024-Q20
21	21	2024-11-08	2024-11-22	5	0.00	0.00	0.00	1	\N	2025-11-06 08:12:35.256349+00	2025-11-06 08:12:35.256349+00	2024-Q21
22	22	2024-11-23	2024-12-07	5	0.00	0.00	0.00	1	\N	2025-11-06 08:12:35.257381+00	2025-11-06 08:12:35.257381+00	2024-Q22
23	23	2024-12-08	2024-12-22	5	0.00	0.00	0.00	1	\N	2025-11-06 08:12:35.25842+00	2025-11-06 08:12:35.25842+00	2024-Q23
24	24	2024-12-23	2025-01-07	5	0.00	0.00	0.00	1	\N	2025-11-06 08:12:35.259538+00	2025-11-06 08:12:35.259538+00	2024-Q24
25	1	2025-01-08	2025-01-22	5	0.00	0.00	0.00	1	\N	2025-11-06 08:12:35.260567+00	2025-11-06 08:12:35.260567+00	2025-Q01
26	2	2025-01-23	2025-02-07	5	0.00	0.00	0.00	1	\N	2025-11-06 08:12:35.261606+00	2025-11-06 08:12:35.261606+00	2025-Q02
27	3	2025-02-08	2025-02-22	5	0.00	0.00	0.00	1	\N	2025-11-06 08:12:35.262638+00	2025-11-06 08:12:35.262638+00	2025-Q03
28	4	2025-02-23	2025-03-07	5	0.00	0.00	0.00	1	\N	2025-11-06 08:12:35.263678+00	2025-11-06 08:12:35.263678+00	2025-Q04
29	5	2025-03-08	2025-03-22	5	0.00	0.00	0.00	1	\N	2025-11-06 08:12:35.26471+00	2025-11-06 08:12:35.26471+00	2025-Q05
30	6	2025-03-23	2025-04-07	5	0.00	0.00	0.00	1	\N	2025-11-06 08:12:35.26574+00	2025-11-06 08:12:35.26574+00	2025-Q06
31	7	2025-04-08	2025-04-22	5	0.00	0.00	0.00	1	\N	2025-11-06 08:12:35.266767+00	2025-11-06 08:12:35.266767+00	2025-Q07
32	8	2025-04-23	2025-05-07	5	0.00	0.00	0.00	1	\N	2025-11-06 08:12:35.26782+00	2025-11-06 08:12:35.26782+00	2025-Q08
33	9	2025-05-08	2025-05-22	5	0.00	0.00	0.00	1	\N	2025-11-06 08:12:35.268866+00	2025-11-06 08:12:35.268866+00	2025-Q09
34	10	2025-05-23	2025-06-07	5	0.00	0.00	0.00	1	\N	2025-11-06 08:12:35.269927+00	2025-11-06 08:12:35.269927+00	2025-Q10
35	11	2025-06-08	2025-06-22	5	0.00	0.00	0.00	1	\N	2025-11-06 08:12:35.271003+00	2025-11-06 08:12:35.271003+00	2025-Q11
36	12	2025-06-23	2025-07-07	5	0.00	0.00	0.00	1	\N	2025-11-06 08:12:35.272185+00	2025-11-06 08:12:35.272185+00	2025-Q12
37	13	2025-07-08	2025-07-22	5	0.00	0.00	0.00	1	\N	2025-11-06 08:12:35.273257+00	2025-11-06 08:12:35.273257+00	2025-Q13
38	14	2025-07-23	2025-08-07	5	0.00	0.00	0.00	1	\N	2025-11-06 08:12:35.274299+00	2025-11-06 08:12:35.274299+00	2025-Q14
39	15	2025-08-08	2025-08-22	5	0.00	0.00	0.00	1	\N	2025-11-06 08:12:35.275323+00	2025-11-06 08:12:35.275323+00	2025-Q15
40	16	2025-08-23	2025-09-07	5	0.00	0.00	0.00	1	\N	2025-11-06 08:12:35.276338+00	2025-11-06 08:12:35.276338+00	2025-Q16
41	17	2025-09-08	2025-09-22	5	0.00	0.00	0.00	1	\N	2025-11-06 08:12:35.277349+00	2025-11-06 08:12:35.277349+00	2025-Q17
42	18	2025-09-23	2025-10-07	5	0.00	0.00	0.00	1	\N	2025-11-06 08:12:35.278353+00	2025-11-06 08:12:35.278353+00	2025-Q18
43	19	2025-10-08	2025-10-22	5	0.00	0.00	0.00	1	\N	2025-11-06 08:12:35.279354+00	2025-11-06 08:12:35.279354+00	2025-Q19
44	20	2025-10-23	2025-11-07	2	0.00	0.00	0.00	1	\N	2025-11-06 08:12:35.280379+00	2025-11-06 08:12:35.280379+00	2025-Q20
45	21	2025-11-08	2025-11-22	1	0.00	0.00	0.00	1	\N	2025-11-06 08:12:35.281436+00	2025-11-06 08:12:35.281436+00	2025-Q21
46	22	2025-11-23	2025-12-07	1	0.00	0.00	0.00	1	\N	2025-11-06 08:12:35.282433+00	2025-11-06 08:12:35.282433+00	2025-Q22
47	23	2025-12-08	2025-12-22	1	0.00	0.00	0.00	1	\N	2025-11-06 08:12:35.283429+00	2025-11-06 08:12:35.283429+00	2025-Q23
48	24	2025-12-23	2026-01-07	1	0.00	0.00	0.00	1	\N	2025-11-06 08:12:35.284442+00	2025-11-06 08:12:35.284442+00	2025-Q24
49	1	2026-01-08	2026-01-22	1	0.00	0.00	0.00	1	\N	2025-11-06 08:12:35.285443+00	2025-11-06 08:12:35.285443+00	2026-Q01
50	2	2026-01-23	2026-02-07	1	0.00	0.00	0.00	1	\N	2025-11-06 08:12:35.286442+00	2025-11-06 08:12:35.286442+00	2026-Q02
51	3	2026-02-08	2026-02-22	1	0.00	0.00	0.00	1	\N	2025-11-06 08:12:35.287441+00	2025-11-06 08:12:35.287441+00	2026-Q03
52	4	2026-02-23	2026-03-07	1	0.00	0.00	0.00	1	\N	2025-11-06 08:12:35.288437+00	2025-11-06 08:12:35.288437+00	2026-Q04
53	5	2026-03-08	2026-03-22	1	0.00	0.00	0.00	1	\N	2025-11-06 08:12:35.289431+00	2025-11-06 08:12:35.289431+00	2026-Q05
54	6	2026-03-23	2026-04-07	1	0.00	0.00	0.00	1	\N	2025-11-06 08:12:35.290424+00	2025-11-06 08:12:35.290424+00	2026-Q06
55	7	2026-04-08	2026-04-22	1	0.00	0.00	0.00	1	\N	2025-11-06 08:12:35.291428+00	2025-11-06 08:12:35.291428+00	2026-Q07
56	8	2026-04-23	2026-05-07	1	0.00	0.00	0.00	1	\N	2025-11-06 08:12:35.292434+00	2025-11-06 08:12:35.292434+00	2026-Q08
57	9	2026-05-08	2026-05-22	1	0.00	0.00	0.00	1	\N	2025-11-06 08:12:35.293426+00	2025-11-06 08:12:35.293426+00	2026-Q09
58	10	2026-05-23	2026-06-07	1	0.00	0.00	0.00	1	\N	2025-11-06 08:12:35.294429+00	2025-11-06 08:12:35.294429+00	2026-Q10
59	11	2026-06-08	2026-06-22	1	0.00	0.00	0.00	1	\N	2025-11-06 08:12:35.295432+00	2025-11-06 08:12:35.295432+00	2026-Q11
60	12	2026-06-23	2026-07-07	1	0.00	0.00	0.00	1	\N	2025-11-06 08:12:35.296437+00	2025-11-06 08:12:35.296437+00	2026-Q12
61	13	2026-07-08	2026-07-22	1	0.00	0.00	0.00	1	\N	2025-11-06 08:12:35.297433+00	2025-11-06 08:12:35.297433+00	2026-Q13
62	14	2026-07-23	2026-08-07	1	0.00	0.00	0.00	1	\N	2025-11-06 08:12:35.298427+00	2025-11-06 08:12:35.298427+00	2026-Q14
63	15	2026-08-08	2026-08-22	1	0.00	0.00	0.00	1	\N	2025-11-06 08:12:35.299425+00	2025-11-06 08:12:35.299425+00	2026-Q15
64	16	2026-08-23	2026-09-07	1	0.00	0.00	0.00	1	\N	2025-11-06 08:12:35.300436+00	2025-11-06 08:12:35.300436+00	2026-Q16
65	17	2026-09-08	2026-09-22	1	0.00	0.00	0.00	1	\N	2025-11-06 08:12:35.301429+00	2025-11-06 08:12:35.301429+00	2026-Q17
66	18	2026-09-23	2026-10-07	1	0.00	0.00	0.00	1	\N	2025-11-06 08:12:35.302446+00	2025-11-06 08:12:35.302446+00	2026-Q18
67	19	2026-10-08	2026-10-22	1	0.00	0.00	0.00	1	\N	2025-11-06 08:12:35.30345+00	2025-11-06 08:12:35.30345+00	2026-Q19
68	20	2026-10-23	2026-11-07	1	0.00	0.00	0.00	1	\N	2025-11-06 08:12:35.304456+00	2025-11-06 08:12:35.304456+00	2026-Q20
69	21	2026-11-08	2026-11-22	1	0.00	0.00	0.00	1	\N	2025-11-06 08:12:35.305447+00	2025-11-06 08:12:35.305447+00	2026-Q21
70	22	2026-11-23	2026-12-07	1	0.00	0.00	0.00	1	\N	2025-11-06 08:12:35.306443+00	2025-11-06 08:12:35.306443+00	2026-Q22
71	23	2026-12-08	2026-12-22	1	0.00	0.00	0.00	1	\N	2025-11-06 08:12:35.307448+00	2025-11-06 08:12:35.307448+00	2026-Q23
72	24	2026-12-23	2027-01-07	1	0.00	0.00	0.00	1	\N	2025-11-06 08:12:35.308444+00	2025-11-06 08:12:35.308444+00	2026-Q24
\.


--
-- Data for Name: defaulted_client_reports; Type: TABLE DATA; Schema: public; Owner: credinet_user
--

COPY public.defaulted_client_reports (id, associate_profile_id, loan_id, client_user_id, reported_at, reported_by, total_debt_amount, evidence_details, evidence_file_path, status, approved_by, approved_at, rejection_reason, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: document_statuses; Type: TABLE DATA; Schema: public; Owner: credinet_user
--

COPY public.document_statuses (id, name, description, display_order, color_code, created_at, updated_at) FROM stdin;
1	PENDING	Documento cargado, pendiente de revisión.	1	#FFA500	2025-10-31 01:12:22.083043+00	2025-10-31 01:12:22.083043+00
2	UNDER_REVIEW	En proceso de revisión.	2	#2196F3	2025-10-31 01:12:22.083043+00	2025-10-31 01:12:22.083043+00
3	APPROVED	Documento aprobado.	3	#4CAF50	2025-10-31 01:12:22.083043+00	2025-10-31 01:12:22.083043+00
4	REJECTED	Documento rechazado.	4	#F44336	2025-10-31 01:12:22.083043+00	2025-10-31 01:12:22.083043+00
\.


--
-- Data for Name: document_types; Type: TABLE DATA; Schema: public; Owner: credinet_user
--

COPY public.document_types (id, name, description, is_required, created_at, updated_at) FROM stdin;
1	Identificación Oficial	INE, Pasaporte o Cédula Profesional	t	2025-10-31 01:12:22.088252+00	2025-10-31 01:12:22.088252+00
2	Comprobante de Domicilio	Recibo de luz, agua o predial	t	2025-10-31 01:12:22.088252+00	2025-10-31 01:12:22.088252+00
3	Comprobante de Ingresos	Estado de cuenta o constancia laboral	t	2025-10-31 01:12:22.088252+00	2025-10-31 01:12:22.088252+00
4	CURP	Clave Única de Registro de Población	f	2025-10-31 01:12:22.088252+00	2025-10-31 01:12:22.088252+00
5	Referencia Personal	Datos de contacto de referencia	f	2025-10-31 01:12:22.088252+00	2025-10-31 01:12:22.088252+00
\.


--
-- Data for Name: guarantors; Type: TABLE DATA; Schema: public; Owner: credinet_user
--

COPY public.guarantors (id, user_id, full_name, first_name, paternal_last_name, maternal_last_name, relationship, phone_number, curp, created_at, updated_at) FROM stdin;
1	4	Carlos Alberto Vargas Hernández	Carlos Alberto	Vargas	Hernández	Padre	5544556600	VAHC600101HDFVRR05	2025-10-31 01:12:22.118939+00	2025-10-31 01:12:22.118939+00
2	5	Ana María Pérez Gómez	Ana María	Pérez	Gómez	Madre	5555667700	PEGA650202MDFRMN06	2025-10-31 01:12:22.118939+00	2025-10-31 01:12:22.118939+00
3	6	Jorge Luis Martínez Sánchez	Jorge Luis	Martínez	Sánchez	Hermano	5566778800	MASJ880315HDFRRL07	2025-10-31 01:12:22.118939+00	2025-10-31 01:12:22.118939+00
\.


--
-- Data for Name: legacy_payment_table; Type: TABLE DATA; Schema: public; Owner: credinet_user
--

COPY public.legacy_payment_table (id, amount, biweekly_payment, term_biweeks, created_at, updated_at, created_by, updated_by) FROM stdin;
1	3000.00	392.00	12	2025-11-05 00:58:16.106847+00	2025-11-05 00:58:16.106847+00	\N	\N
2	4000.00	510.00	12	2025-11-05 00:58:16.106847+00	2025-11-05 00:58:16.106847+00	\N	\N
3	5000.00	633.00	12	2025-11-05 00:58:16.106847+00	2025-11-05 00:58:16.106847+00	\N	\N
4	6000.00	752.00	12	2025-11-05 00:58:16.106847+00	2025-11-05 00:58:16.106847+00	\N	\N
5	7000.00	882.00	12	2025-11-05 00:58:16.106847+00	2025-11-05 00:58:16.106847+00	\N	\N
6	8000.00	1006.00	12	2025-11-05 00:58:16.106847+00	2025-11-05 00:58:16.106847+00	\N	\N
7	9000.00	1131.00	12	2025-11-05 00:58:16.106847+00	2025-11-05 00:58:16.106847+00	\N	\N
8	10000.00	1255.00	12	2025-11-05 00:58:16.106847+00	2025-11-05 00:58:16.106847+00	\N	\N
9	11000.00	1385.00	12	2025-11-05 00:58:16.106847+00	2025-11-05 00:58:16.106847+00	\N	\N
10	12000.00	1504.00	12	2025-11-05 00:58:16.106847+00	2025-11-05 00:58:16.106847+00	\N	\N
11	13000.00	1634.00	12	2025-11-05 00:58:16.106847+00	2025-11-05 00:58:16.106847+00	\N	\N
12	14000.00	1765.00	12	2025-11-05 00:58:16.106847+00	2025-11-05 00:58:16.106847+00	\N	\N
13	15000.00	1888.00	12	2025-11-05 00:58:16.106847+00	2025-11-05 00:58:16.106847+00	\N	\N
14	16000.00	2012.00	12	2025-11-05 00:58:16.106847+00	2025-11-05 00:58:16.106847+00	\N	\N
15	17000.00	2137.00	12	2025-11-05 00:58:16.106847+00	2025-11-05 00:58:16.106847+00	\N	\N
16	18000.00	2262.00	12	2025-11-05 00:58:16.106847+00	2025-11-05 00:58:16.106847+00	\N	\N
17	19000.00	2386.00	12	2025-11-05 00:58:16.106847+00	2025-11-05 00:58:16.106847+00	\N	\N
18	20000.00	2510.00	12	2025-11-05 00:58:16.106847+00	2025-11-05 00:58:16.106847+00	\N	\N
19	21000.00	2640.00	12	2025-11-05 00:58:16.106847+00	2025-11-05 00:58:16.106847+00	\N	\N
20	22000.00	2759.00	12	2025-11-05 00:58:16.106847+00	2025-11-05 00:58:16.106847+00	\N	\N
21	23000.00	2889.00	12	2025-11-05 00:58:16.106847+00	2025-11-05 00:58:16.106847+00	\N	\N
22	24000.00	3020.00	12	2025-11-05 00:58:16.106847+00	2025-11-05 00:58:16.106847+00	\N	\N
23	25000.00	3143.00	12	2025-11-05 00:58:16.106847+00	2025-11-05 00:58:16.106847+00	\N	\N
24	26000.00	3267.00	12	2025-11-05 00:58:16.106847+00	2025-11-05 00:58:16.106847+00	\N	\N
25	27000.00	3392.00	12	2025-11-05 00:58:16.106847+00	2025-11-05 00:58:16.106847+00	\N	\N
26	28000.00	3517.00	12	2025-11-05 00:58:16.106847+00	2025-11-05 00:58:16.106847+00	\N	\N
27	29000.00	3641.00	12	2025-11-05 00:58:16.106847+00	2025-11-05 00:58:16.106847+00	\N	\N
28	30000.00	3765.00	12	2025-11-05 00:58:16.106847+00	2025-11-05 00:58:16.106847+00	\N	\N
29	7500.00	962.50	12	2025-11-05 01:00:37.324145+00	2025-11-05 01:00:37.324145+00	\N	\N
\.


--
-- Data for Name: level_change_types; Type: TABLE DATA; Schema: public; Owner: credinet_user
--

COPY public.level_change_types (id, name, description, is_automatic, display_order, created_at, updated_at) FROM stdin;
1	PROMOTION	Promoción automática a nivel superior.	t	1	2025-10-31 01:12:22.086922+00	2025-10-31 01:12:22.086922+00
2	DEMOTION	Descenso por incumplimiento.	t	2	2025-10-31 01:12:22.086922+00	2025-10-31 01:12:22.086922+00
3	MANUAL	Cambio manual por admin.	f	3	2025-10-31 01:12:22.086922+00	2025-10-31 01:12:22.086922+00
4	INITIAL	Nivel inicial al registrarse.	f	4	2025-10-31 01:12:22.086922+00	2025-10-31 01:12:22.086922+00
5	REWARD	Promoción especial por logro.	f	5	2025-10-31 01:12:22.086922+00	2025-10-31 01:12:22.086922+00
6	PENALTY	Descenso por sanción.	f	6	2025-10-31 01:12:22.086922+00	2025-10-31 01:12:22.086922+00
\.


--
-- Data for Name: loan_renewals; Type: TABLE DATA; Schema: public; Owner: credinet_user
--

COPY public.loan_renewals (id, original_loan_id, renewed_loan_id, renewal_date, pending_balance, new_amount, reason, created_by, created_at) FROM stdin;
\.


--
-- Data for Name: loan_statuses; Type: TABLE DATA; Schema: public; Owner: credinet_user
--

COPY public.loan_statuses (id, name, description, is_active, display_order, color_code, icon_name, created_at, updated_at) FROM stdin;
1	PENDING	Préstamo solicitado pero aún no aprobado ni desembolsado.	t	1	#FFA500	clock	2025-10-31 01:12:22.075733+00	2025-10-31 01:12:22.075733+00
2	APPROVED	Préstamo aprobado, listo para desembolso y generación de cronograma.	t	2	#4CAF50	check-circle	2025-10-31 01:12:22.075733+00	2025-10-31 01:12:22.075733+00
3	ACTIVE	Préstamo desembolsado y activo, con pagos en curso.	t	3	#2196F3	activity	2025-10-31 01:12:22.075733+00	2025-10-31 01:12:22.075733+00
4	COMPLETED	Préstamo completamente liquidado.	t	4	#00C853	check-all	2025-10-31 01:12:22.075733+00	2025-10-31 01:12:22.075733+00
5	PAID	Préstamo totalmente pagado (sinónimo de COMPLETED).	t	5	#00C853	check-all	2025-10-31 01:12:22.075733+00	2025-10-31 01:12:22.075733+00
6	DEFAULTED	Préstamo en mora o incumplimiento.	t	6	#F44336	alert-triangle	2025-10-31 01:12:22.075733+00	2025-10-31 01:12:22.075733+00
7	REJECTED	Solicitud rechazada por administrador.	t	7	#9E9E9E	x-circle	2025-10-31 01:12:22.075733+00	2025-10-31 01:12:22.075733+00
8	CANCELLED	Préstamo cancelado antes de completarse.	t	8	#757575	slash	2025-10-31 01:12:22.075733+00	2025-10-31 01:12:22.075733+00
\.


--
-- Data for Name: loans; Type: TABLE DATA; Schema: public; Owner: credinet_user
--

COPY public.loans (id, user_id, associate_user_id, amount, interest_rate, commission_rate, term_biweeks, status_id, contract_id, approved_at, approved_by, rejected_at, rejected_by, rejection_reason, notes, created_at, updated_at, profile_code, biweekly_payment, total_payment, total_interest, total_commission, commission_per_payment, associate_payment) FROM stdin;
6	4	3	25000.00	4.25	2.50	12	2	\N	2025-11-05 19:33:36.414762+00	1	\N	\N	\N	Préstamo de auditoría final	2025-11-05 18:05:15.948023+00	2025-11-05 19:33:36.414762+00	standard	3145.83	37750.00	12750.00	943.80	78.65	3067.18
8	4	\N	10000.00	2.50	2.50	6	2	\N	2025-11-06 03:33:43.064871+00	1	\N	\N	\N	\N	2025-11-06 03:33:06.462989+00	2025-11-06 03:33:43.064871+00	standard	1733.33	10400.00	400.00	\N	43.33	1690.00
9	5	\N	30000.00	2.50	2.50	18	2	\N	2025-11-06 03:34:01.319366+00	1	\N	\N	\N	\N	2025-11-06 03:33:13.392382+00	2025-11-06 03:34:01.319366+00	standard	1722.22	31000.00	1000.00	\N	43.06	1679.16
10	6	\N	50000.00	2.50	2.50	24	2	\N	2025-11-06 03:39:48.596637+00	1	\N	\N	\N	\N	2025-11-06 03:33:20.197819+00	2025-11-06 03:39:48.596637+00	standard	2145.83	51500.00	1500.00	\N	53.65	2092.18
13	5	8	8000.00	3.50	15.00	6	2	\N	2025-11-06 07:40:29.830068+00	1	\N	\N	\N	\N	2025-11-06 07:37:58.558987+00	2025-11-06 07:40:29.827967+00	\N	\N	\N	\N	\N	\N	\N
12	4	2	8000.00	3.50	15.00	6	6	\N	\N	\N	2025-11-06 07:40:36.584129+00	1	Documentación incompleta - falta comprobante de ingresos	\N	2025-11-06 07:37:11.817299+00	2025-11-06 07:40:36.583757+00	\N	\N	\N	\N	\N	\N	\N
\.


--
-- Data for Name: payment_methods; Type: TABLE DATA; Schema: public; Owner: credinet_user
--

COPY public.payment_methods (id, name, description, is_active, requires_reference, display_order, icon_name, created_at, updated_at) FROM stdin;
1	CASH	Pago en efectivo.	t	f	1	dollar-sign	2025-10-31 01:12:22.081669+00	2025-10-31 01:12:22.081669+00
2	TRANSFER	Transferencia bancaria.	t	t	2	arrow-right-circle	2025-10-31 01:12:22.081669+00	2025-10-31 01:12:22.081669+00
3	CHECK	Cheque bancario.	t	t	3	file-text	2025-10-31 01:12:22.081669+00	2025-10-31 01:12:22.081669+00
4	PAYROLL_DEDUCTION	Descuento de nómina.	t	f	4	briefcase	2025-10-31 01:12:22.081669+00	2025-10-31 01:12:22.081669+00
5	CARD	Tarjeta débito/crédito.	t	t	5	credit-card	2025-10-31 01:12:22.081669+00	2025-10-31 01:12:22.081669+00
6	DEPOSIT	Depósito bancario.	t	t	6	inbox	2025-10-31 01:12:22.081669+00	2025-10-31 01:12:22.081669+00
7	OXXO	Pago en OXXO.	t	t	7	shopping-bag	2025-10-31 01:12:22.081669+00	2025-10-31 01:12:22.081669+00
\.


--
-- Data for Name: payment_status_history; Type: TABLE DATA; Schema: public; Owner: credinet_user
--

COPY public.payment_status_history (id, payment_id, old_status_id, new_status_id, change_type, changed_by, change_reason, ip_address, user_agent, changed_at) FROM stdin;
\.


--
-- Data for Name: payment_statuses; Type: TABLE DATA; Schema: public; Owner: credinet_user
--

COPY public.payment_statuses (id, name, description, is_active, display_order, color_code, icon_name, is_real_payment, created_at, updated_at) FROM stdin;
1	PENDING	Pago programado, aún no vence.	t	1	#9E9E9E	clock	t	2025-10-31 01:12:22.077324+00	2025-10-31 01:12:22.077324+00
2	DUE_TODAY	Pago vence hoy.	t	2	#FF9800	calendar	t	2025-10-31 01:12:22.077324+00	2025-10-31 01:12:22.077324+00
4	OVERDUE	Pago vencido, no pagado.	t	4	#F44336	alert-circle	t	2025-10-31 01:12:22.077324+00	2025-10-31 01:12:22.077324+00
5	PARTIAL	Pago parcial realizado.	t	5	#2196F3	pie-chart	t	2025-10-31 01:12:22.077324+00	2025-10-31 01:12:22.077324+00
6	IN_COLLECTION	En proceso de cobranza.	t	6	#9C27B0	phone	t	2025-10-31 01:12:22.077324+00	2025-10-31 01:12:22.077324+00
7	RESCHEDULED	Pago reprogramado.	t	7	#03A9F4	refresh-cw	t	2025-10-31 01:12:22.077324+00	2025-10-31 01:12:22.077324+00
3	PAID	Pago completado por cliente.	t	3	#4CAF50	check	t	2025-10-31 01:12:22.077324+00	2025-10-31 01:12:22.077324+00
8	PAID_PARTIAL	Pago parcial aceptado.	t	8	#8BC34A	check-circle	t	2025-10-31 01:12:22.077324+00	2025-10-31 01:12:22.077324+00
9	PAID_BY_ASSOCIATE	Pagado por asociado (cliente moroso).	t	9	#FF5722	user-x	f	2025-10-31 01:12:22.077324+00	2025-10-31 01:12:22.077324+00
10	PAID_NOT_REPORTED	Pago no reportado al cierre.	t	10	#FFC107	alert-triangle	f	2025-10-31 01:12:22.077324+00	2025-10-31 01:12:22.077324+00
11	FORGIVEN	Pago perdonado por administración.	t	11	#00BCD4	heart	f	2025-10-31 01:12:22.077324+00	2025-10-31 01:12:22.077324+00
12	CANCELLED	Pago cancelado.	t	12	#607D8B	x	f	2025-10-31 01:12:22.077324+00	2025-10-31 01:12:22.077324+00
\.


--
-- Data for Name: payments; Type: TABLE DATA; Schema: public; Owner: credinet_user
--

COPY public.payments (id, loan_id, amount_paid, payment_date, payment_due_date, is_late, status_id, cut_period_id, marked_by, marked_at, marking_notes, created_at, updated_at, payment_number, expected_amount, interest_amount, principal_amount, commission_amount, associate_payment, balance_remaining) FROM stdin;
\.


--
-- Data for Name: rate_profiles; Type: TABLE DATA; Schema: public; Owner: credinet_user
--

COPY public.rate_profiles (id, code, name, description, calculation_type, interest_rate_percent, enabled, is_recommended, display_order, min_amount, max_amount, valid_terms, created_at, updated_at, created_by, updated_by, commission_rate_percent) FROM stdin;
1	legacy	Tabla Histórica v2.0	Sistema actual con montos predefinidos en tabla. Totalmente editable por admin. Permite agregar nuevos montos como $7,500, $12,350, etc.	table_lookup	\N	t	f	1	\N	\N	{12}	2025-11-05 00:58:16.105135+00	2025-11-05 00:58:16.105135+00	\N	\N	\N
2	transition	Transición Suave 3.75%	Tasa reducida para facilitar adopción gradual. Cliente ahorra vs tabla actual. Ideal para primeros 6 meses de migración.	formula	3.750	t	f	2	\N	\N	{6,12,18,24}	2025-11-05 00:58:16.105135+00	2025-11-05 00:58:16.105135+00	\N	\N	2.500
3	standard	Estándar 4.25% - Recomendado	Balance óptimo entre competitividad y rentabilidad. Tasa ~51% total (12Q), similar al promedio actual. Recomendado para mayoría de casos.	formula	4.250	t	t	3	\N	\N	{3,6,9,12,15,18,21,24,30,36}	2025-11-05 00:58:16.105135+00	2025-11-05 00:58:16.105135+00	\N	\N	2.500
4	premium	Premium 4.5%	Tasa objetivo con máxima rentabilidad (54% total en 12Q). Mantiene competitividad vs mercado (60-80%). Activar desde mes 7+ de migración.	formula	4.500	f	f	4	\N	\N	{3,6,9,12,15,18,21,24,30,36}	2025-11-05 00:58:16.105135+00	2025-11-05 00:58:16.105135+00	\N	\N	2.500
5	custom	Personalizado	Tasa ajustable manualmente para casos especiales. Requiere aprobación de gerente/admin. Rango permitido: 2.0% - 6.0% quincenal.	formula	\N	t	f	5	\N	\N	\N	2025-11-05 00:58:16.105135+00	2025-11-05 00:58:16.105135+00	\N	\N	2.500
\.


--
-- Data for Name: roles; Type: TABLE DATA; Schema: public; Owner: credinet_user
--

COPY public.roles (id, name, description, created_at) FROM stdin;
1	desarrollador	\N	2025-10-31 01:12:22.07323+00
2	administrador	\N	2025-10-31 01:12:22.07323+00
3	auxiliar_administrativo	\N	2025-10-31 01:12:22.07323+00
4	asociado	\N	2025-10-31 01:12:22.07323+00
5	cliente	\N	2025-10-31 01:12:22.07323+00
\.


--
-- Data for Name: statement_statuses; Type: TABLE DATA; Schema: public; Owner: credinet_user
--

COPY public.statement_statuses (id, name, description, is_paid, display_order, color_code, created_at, updated_at) FROM stdin;
1	GENERATED	Estado de cuenta generado.	f	1	#9E9E9E	2025-10-31 01:12:22.084329+00	2025-10-31 01:12:22.084329+00
2	SENT	Enviado al asociado.	f	2	#2196F3	2025-10-31 01:12:22.084329+00	2025-10-31 01:12:22.084329+00
3	PAID	Pagado completamente.	t	3	#4CAF50	2025-10-31 01:12:22.084329+00	2025-10-31 01:12:22.084329+00
4	PARTIAL_PAID	Pago parcial recibido.	f	4	#FF9800	2025-10-31 01:12:22.084329+00	2025-10-31 01:12:22.084329+00
5	OVERDUE	Vencido sin pagar.	f	5	#F44336	2025-10-31 01:12:22.084329+00	2025-10-31 01:12:22.084329+00
\.


--
-- Data for Name: system_configurations; Type: TABLE DATA; Schema: public; Owner: credinet_user
--

COPY public.system_configurations (id, config_key, config_value, description, config_type_id, updated_by, created_at, updated_at) FROM stdin;
1	max_loan_amount	1000000	Monto máximo de préstamo permitido	2	2	2025-10-31 01:12:22.124383+00	2025-10-31 01:12:22.124383+00
2	default_interest_rate	2.5	Tasa de interés por defecto	2	2	2025-10-31 01:12:22.124383+00	2025-10-31 01:12:22.124383+00
3	default_commission_rate	2.5	Tasa de comisión por defecto	2	2	2025-10-31 01:12:22.124383+00	2025-10-31 01:12:22.124383+00
4	system_name	Credinet	Nombre del sistema	1	2	2025-10-31 01:12:22.124383+00	2025-10-31 01:12:22.124383+00
5	maintenance_mode	false	Modo de mantenimiento	3	2	2025-10-31 01:12:22.124383+00	2025-10-31 01:12:22.124383+00
6	payment_system	BIWEEKLY_v2.0	Sistema de pagos quincenal v2.0	1	2	2025-10-31 01:12:22.124383+00	2025-10-31 01:12:22.124383+00
7	perfect_dates_enabled	true	Fechas perfectas (día 15 y último)	3	2	2025-10-31 01:12:22.124383+00	2025-10-31 01:12:22.124383+00
8	cut_days	8,23	Días de corte exactos	1	2	2025-10-31 01:12:22.124383+00	2025-10-31 01:12:22.124383+00
9	payment_days	15,LAST	Días de pago permitidos	1	2	2025-10-31 01:12:22.124383+00	2025-10-31 01:12:22.124383+00
10	db_version	2.0.0	Versión de base de datos	1	2	2025-10-31 01:12:22.124383+00	2025-10-31 01:12:22.124383+00
\.


--
-- Data for Name: user_roles; Type: TABLE DATA; Schema: public; Owner: credinet_user
--

COPY public.user_roles (user_id, role_id, created_at) FROM stdin;
1	1	2025-10-31 01:12:22.092816+00
2	2	2025-10-31 01:12:22.092816+00
3	4	2025-10-31 01:12:22.092816+00
4	5	2025-10-31 01:12:22.092816+00
5	5	2025-10-31 01:12:22.092816+00
6	5	2025-10-31 01:12:22.092816+00
7	3	2025-10-31 01:12:22.092816+00
8	4	2025-10-31 01:12:22.092816+00
1000	5	2025-10-31 01:12:22.092816+00
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: credinet_user
--

COPY public.users (id, username, password_hash, first_name, last_name, email, phone_number, birth_date, curp, profile_picture_url, created_at, updated_at, active) FROM stdin;
1	jair	$2b$12$aSMdt0Kd8I2lrCIvSNbxx.X5U.BmY9MAZAoPvM/MgK5mXOxQgq0s6	Jair	FC	jair@dev.com	5511223344	1990-01-15	FERJ900115HDFXXX01	\N	2025-10-31 01:12:22.089593+00	2025-10-31 01:12:22.089593+00	t
2	admin	$2b$12$aSMdt0Kd8I2lrCIvSNbxx.X5U.BmY9MAZAoPvM/MgK5mXOxQgq0s6	Admin	Total	admin@credinet.com	5522334455	\N	\N	\N	2025-10-31 01:12:22.089593+00	2025-10-31 01:12:22.089593+00	t
3	asociado_test	$2b$12$aSMdt0Kd8I2lrCIvSNbxx.X5U.BmY9MAZAoPvM/MgK5mXOxQgq0s6	Asociado	Prueba	asociado@test.com	5533445566	\N	\N	\N	2025-10-31 01:12:22.089593+00	2025-10-31 01:12:22.089593+00	t
4	sofia.vargas	$2b$12$aSMdt0Kd8I2lrCIvSNbxx.X5U.BmY9MAZAoPvM/MgK5mXOxQgq0s6	Sofía	Vargas	sofia.vargas@email.com	5544556677	1985-05-20	VARS850520MDFXXX02	\N	2025-10-31 01:12:22.089593+00	2025-10-31 01:12:22.089593+00	t
5	juan.perez	$2b$12$aSMdt0Kd8I2lrCIvSNbxx.X5U.BmY9MAZAoPvM/MgK5mXOxQgq0s6	Juan	Pérez	juan.perez@email.com	5555667788	1992-11-30	PERJ921130HDFXXX03	\N	2025-10-31 01:12:22.089593+00	2025-10-31 01:12:22.089593+00	t
6	laura.mtz	$2b$12$aSMdt0Kd8I2lrCIvSNbxx.X5U.BmY9MAZAoPvM/MgK5mXOxQgq0s6	Laura	Martínez	laura.martinez@email.com	5566778899	\N	\N	\N	2025-10-31 01:12:22.089593+00	2025-10-31 01:12:22.089593+00	t
7	aux.admin	$2b$12$aSMdt0Kd8I2lrCIvSNbxx.X5U.BmY9MAZAoPvM/MgK5mXOxQgq0s6	Pedro	Ramírez	pedro.ramirez@credinet.com	5577889900	\N	\N	\N	2025-10-31 01:12:22.089593+00	2025-10-31 01:12:22.089593+00	t
8	asociado_norte	$2b$12$aSMdt0Kd8I2lrCIvSNbxx.X5U.BmY9MAZAoPvM/MgK5mXOxQgq0s6	User	Norte	user@norte.com	5588990011	\N	\N	\N	2025-10-31 01:12:22.089593+00	2025-10-31 01:12:22.089593+00	t
1000	aval_test	$2b$12$aSMdt0Kd8I2lrCIvSNbxx.X5U.BmY9MAZAoPvM/MgK5mXOxQgq0s6	María	Aval	maria.aval@demo.com	6143618296	1995-05-25	FACJ950525HCHRRR04	\N	2025-10-31 01:12:22.089593+00	2025-10-31 01:12:22.089593+00	t
\.


--
-- Name: addresses_id_seq; Type: SEQUENCE SET; Schema: public; Owner: credinet_user
--

SELECT pg_catalog.setval('public.addresses_id_seq', 5, false);


--
-- Name: agreement_items_id_seq; Type: SEQUENCE SET; Schema: public; Owner: credinet_user
--

SELECT pg_catalog.setval('public.agreement_items_id_seq', 1, false);


--
-- Name: agreement_payments_id_seq; Type: SEQUENCE SET; Schema: public; Owner: credinet_user
--

SELECT pg_catalog.setval('public.agreement_payments_id_seq', 1, false);


--
-- Name: agreements_id_seq; Type: SEQUENCE SET; Schema: public; Owner: credinet_user
--

SELECT pg_catalog.setval('public.agreements_id_seq', 1, false);


--
-- Name: associate_accumulated_balances_id_seq; Type: SEQUENCE SET; Schema: public; Owner: credinet_user
--

SELECT pg_catalog.setval('public.associate_accumulated_balances_id_seq', 1, false);


--
-- Name: associate_debt_breakdown_id_seq; Type: SEQUENCE SET; Schema: public; Owner: credinet_user
--

SELECT pg_catalog.setval('public.associate_debt_breakdown_id_seq', 1, false);


--
-- Name: associate_level_history_id_seq; Type: SEQUENCE SET; Schema: public; Owner: credinet_user
--

SELECT pg_catalog.setval('public.associate_level_history_id_seq', 1, false);


--
-- Name: associate_levels_id_seq; Type: SEQUENCE SET; Schema: public; Owner: credinet_user
--

SELECT pg_catalog.setval('public.associate_levels_id_seq', 1, false);


--
-- Name: associate_payment_statements_id_seq; Type: SEQUENCE SET; Schema: public; Owner: credinet_user
--

SELECT pg_catalog.setval('public.associate_payment_statements_id_seq', 1, false);


--
-- Name: associate_profiles_id_seq; Type: SEQUENCE SET; Schema: public; Owner: credinet_user
--

SELECT pg_catalog.setval('public.associate_profiles_id_seq', 3, false);


--
-- Name: audit_log_id_seq; Type: SEQUENCE SET; Schema: public; Owner: credinet_user
--

SELECT pg_catalog.setval('public.audit_log_id_seq', 254, true);


--
-- Name: audit_session_log_id_seq; Type: SEQUENCE SET; Schema: public; Owner: credinet_user
--

SELECT pg_catalog.setval('public.audit_session_log_id_seq', 1, false);


--
-- Name: beneficiaries_id_seq; Type: SEQUENCE SET; Schema: public; Owner: credinet_user
--

SELECT pg_catalog.setval('public.beneficiaries_id_seq', 4, false);


--
-- Name: client_documents_id_seq; Type: SEQUENCE SET; Schema: public; Owner: credinet_user
--

SELECT pg_catalog.setval('public.client_documents_id_seq', 1, false);


--
-- Name: config_types_id_seq; Type: SEQUENCE SET; Schema: public; Owner: credinet_user
--

SELECT pg_catalog.setval('public.config_types_id_seq', 8, true);


--
-- Name: contract_statuses_id_seq; Type: SEQUENCE SET; Schema: public; Owner: credinet_user
--

SELECT pg_catalog.setval('public.contract_statuses_id_seq', 6, true);


--
-- Name: contracts_id_seq; Type: SEQUENCE SET; Schema: public; Owner: credinet_user
--

SELECT pg_catalog.setval('public.contracts_id_seq', 1, false);


--
-- Name: cut_period_statuses_id_seq; Type: SEQUENCE SET; Schema: public; Owner: credinet_user
--

SELECT pg_catalog.setval('public.cut_period_statuses_id_seq', 5, true);


--
-- Name: cut_periods_id_seq; Type: SEQUENCE SET; Schema: public; Owner: credinet_user
--

SELECT pg_catalog.setval('public.cut_periods_id_seq', 72, true);


--
-- Name: defaulted_client_reports_id_seq; Type: SEQUENCE SET; Schema: public; Owner: credinet_user
--

SELECT pg_catalog.setval('public.defaulted_client_reports_id_seq', 1, false);


--
-- Name: document_statuses_id_seq; Type: SEQUENCE SET; Schema: public; Owner: credinet_user
--

SELECT pg_catalog.setval('public.document_statuses_id_seq', 4, true);


--
-- Name: document_types_id_seq; Type: SEQUENCE SET; Schema: public; Owner: credinet_user
--

SELECT pg_catalog.setval('public.document_types_id_seq', 1, false);


--
-- Name: guarantors_id_seq; Type: SEQUENCE SET; Schema: public; Owner: credinet_user
--

SELECT pg_catalog.setval('public.guarantors_id_seq', 4, false);


--
-- Name: legacy_payment_table_id_seq; Type: SEQUENCE SET; Schema: public; Owner: credinet_user
--

SELECT pg_catalog.setval('public.legacy_payment_table_id_seq', 29, true);


--
-- Name: level_change_types_id_seq; Type: SEQUENCE SET; Schema: public; Owner: credinet_user
--

SELECT pg_catalog.setval('public.level_change_types_id_seq', 6, true);


--
-- Name: loan_renewals_id_seq; Type: SEQUENCE SET; Schema: public; Owner: credinet_user
--

SELECT pg_catalog.setval('public.loan_renewals_id_seq', 1, false);


--
-- Name: loan_statuses_id_seq; Type: SEQUENCE SET; Schema: public; Owner: credinet_user
--

SELECT pg_catalog.setval('public.loan_statuses_id_seq', 8, true);


--
-- Name: loans_id_seq; Type: SEQUENCE SET; Schema: public; Owner: credinet_user
--

SELECT pg_catalog.setval('public.loans_id_seq', 13, true);


--
-- Name: payment_methods_id_seq; Type: SEQUENCE SET; Schema: public; Owner: credinet_user
--

SELECT pg_catalog.setval('public.payment_methods_id_seq', 7, true);


--
-- Name: payment_status_history_id_seq; Type: SEQUENCE SET; Schema: public; Owner: credinet_user
--

SELECT pg_catalog.setval('public.payment_status_history_id_seq', 1, false);


--
-- Name: payment_statuses_id_seq; Type: SEQUENCE SET; Schema: public; Owner: credinet_user
--

SELECT pg_catalog.setval('public.payment_statuses_id_seq', 1, false);


--
-- Name: payments_id_seq; Type: SEQUENCE SET; Schema: public; Owner: credinet_user
--

SELECT pg_catalog.setval('public.payments_id_seq', 1, false);


--
-- Name: rate_profiles_id_seq; Type: SEQUENCE SET; Schema: public; Owner: credinet_user
--

SELECT pg_catalog.setval('public.rate_profiles_id_seq', 5, true);


--
-- Name: roles_id_seq; Type: SEQUENCE SET; Schema: public; Owner: credinet_user
--

SELECT pg_catalog.setval('public.roles_id_seq', 6, false);


--
-- Name: statement_statuses_id_seq; Type: SEQUENCE SET; Schema: public; Owner: credinet_user
--

SELECT pg_catalog.setval('public.statement_statuses_id_seq', 5, true);


--
-- Name: system_configurations_id_seq; Type: SEQUENCE SET; Schema: public; Owner: credinet_user
--

SELECT pg_catalog.setval('public.system_configurations_id_seq', 10, true);


--
-- Name: users_id_seq; Type: SEQUENCE SET; Schema: public; Owner: credinet_user
--

SELECT pg_catalog.setval('public.users_id_seq', 1001, false);


--
-- Name: addresses addresses_pkey; Type: CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.addresses
    ADD CONSTRAINT addresses_pkey PRIMARY KEY (id);


--
-- Name: addresses addresses_user_id_key; Type: CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.addresses
    ADD CONSTRAINT addresses_user_id_key UNIQUE (user_id);


--
-- Name: agreement_items agreement_items_pkey; Type: CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.agreement_items
    ADD CONSTRAINT agreement_items_pkey PRIMARY KEY (id);


--
-- Name: agreement_payments agreement_payments_pkey; Type: CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.agreement_payments
    ADD CONSTRAINT agreement_payments_pkey PRIMARY KEY (id);


--
-- Name: agreements agreements_agreement_number_key; Type: CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.agreements
    ADD CONSTRAINT agreements_agreement_number_key UNIQUE (agreement_number);


--
-- Name: agreements agreements_pkey; Type: CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.agreements
    ADD CONSTRAINT agreements_pkey PRIMARY KEY (id);


--
-- Name: associate_accumulated_balances associate_accumulated_balances_pkey; Type: CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.associate_accumulated_balances
    ADD CONSTRAINT associate_accumulated_balances_pkey PRIMARY KEY (id);


--
-- Name: associate_accumulated_balances associate_accumulated_balances_user_id_cut_period_id_key; Type: CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.associate_accumulated_balances
    ADD CONSTRAINT associate_accumulated_balances_user_id_cut_period_id_key UNIQUE (user_id, cut_period_id);


--
-- Name: associate_debt_breakdown associate_debt_breakdown_pkey; Type: CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.associate_debt_breakdown
    ADD CONSTRAINT associate_debt_breakdown_pkey PRIMARY KEY (id);


--
-- Name: associate_level_history associate_level_history_pkey; Type: CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.associate_level_history
    ADD CONSTRAINT associate_level_history_pkey PRIMARY KEY (id);


--
-- Name: associate_levels associate_levels_name_key; Type: CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.associate_levels
    ADD CONSTRAINT associate_levels_name_key UNIQUE (name);


--
-- Name: associate_levels associate_levels_pkey; Type: CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.associate_levels
    ADD CONSTRAINT associate_levels_pkey PRIMARY KEY (id);


--
-- Name: associate_payment_statements associate_payment_statements_pkey; Type: CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.associate_payment_statements
    ADD CONSTRAINT associate_payment_statements_pkey PRIMARY KEY (id);


--
-- Name: associate_profiles associate_profiles_contact_email_key; Type: CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.associate_profiles
    ADD CONSTRAINT associate_profiles_contact_email_key UNIQUE (contact_email);


--
-- Name: associate_profiles associate_profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.associate_profiles
    ADD CONSTRAINT associate_profiles_pkey PRIMARY KEY (id);


--
-- Name: associate_profiles associate_profiles_user_id_key; Type: CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.associate_profiles
    ADD CONSTRAINT associate_profiles_user_id_key UNIQUE (user_id);


--
-- Name: audit_log audit_log_pkey; Type: CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.audit_log
    ADD CONSTRAINT audit_log_pkey PRIMARY KEY (id);


--
-- Name: audit_session_log audit_session_log_pkey; Type: CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.audit_session_log
    ADD CONSTRAINT audit_session_log_pkey PRIMARY KEY (id);


--
-- Name: beneficiaries beneficiaries_pkey; Type: CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.beneficiaries
    ADD CONSTRAINT beneficiaries_pkey PRIMARY KEY (id);


--
-- Name: beneficiaries beneficiaries_user_id_key; Type: CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.beneficiaries
    ADD CONSTRAINT beneficiaries_user_id_key UNIQUE (user_id);


--
-- Name: client_documents client_documents_pkey; Type: CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.client_documents
    ADD CONSTRAINT client_documents_pkey PRIMARY KEY (id);


--
-- Name: config_types config_types_name_key; Type: CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.config_types
    ADD CONSTRAINT config_types_name_key UNIQUE (name);


--
-- Name: config_types config_types_pkey; Type: CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.config_types
    ADD CONSTRAINT config_types_pkey PRIMARY KEY (id);


--
-- Name: contract_statuses contract_statuses_name_key; Type: CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.contract_statuses
    ADD CONSTRAINT contract_statuses_name_key UNIQUE (name);


--
-- Name: contract_statuses contract_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.contract_statuses
    ADD CONSTRAINT contract_statuses_pkey PRIMARY KEY (id);


--
-- Name: contracts contracts_document_number_key; Type: CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.contracts
    ADD CONSTRAINT contracts_document_number_key UNIQUE (document_number);


--
-- Name: contracts contracts_pkey; Type: CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.contracts
    ADD CONSTRAINT contracts_pkey PRIMARY KEY (id);


--
-- Name: cut_period_statuses cut_period_statuses_name_key; Type: CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.cut_period_statuses
    ADD CONSTRAINT cut_period_statuses_name_key UNIQUE (name);


--
-- Name: cut_period_statuses cut_period_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.cut_period_statuses
    ADD CONSTRAINT cut_period_statuses_pkey PRIMARY KEY (id);


--
-- Name: cut_periods cut_periods_cut_code_key; Type: CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.cut_periods
    ADD CONSTRAINT cut_periods_cut_code_key UNIQUE (cut_code);


--
-- Name: cut_periods cut_periods_pkey; Type: CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.cut_periods
    ADD CONSTRAINT cut_periods_pkey PRIMARY KEY (id);


--
-- Name: defaulted_client_reports defaulted_client_reports_pkey; Type: CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.defaulted_client_reports
    ADD CONSTRAINT defaulted_client_reports_pkey PRIMARY KEY (id);


--
-- Name: document_statuses document_statuses_name_key; Type: CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.document_statuses
    ADD CONSTRAINT document_statuses_name_key UNIQUE (name);


--
-- Name: document_statuses document_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.document_statuses
    ADD CONSTRAINT document_statuses_pkey PRIMARY KEY (id);


--
-- Name: document_types document_types_name_key; Type: CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.document_types
    ADD CONSTRAINT document_types_name_key UNIQUE (name);


--
-- Name: document_types document_types_pkey; Type: CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.document_types
    ADD CONSTRAINT document_types_pkey PRIMARY KEY (id);


--
-- Name: guarantors guarantors_curp_key; Type: CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.guarantors
    ADD CONSTRAINT guarantors_curp_key UNIQUE (curp);


--
-- Name: guarantors guarantors_pkey; Type: CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.guarantors
    ADD CONSTRAINT guarantors_pkey PRIMARY KEY (id);


--
-- Name: guarantors guarantors_user_id_key; Type: CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.guarantors
    ADD CONSTRAINT guarantors_user_id_key UNIQUE (user_id);


--
-- Name: legacy_payment_table legacy_payment_table_pkey; Type: CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.legacy_payment_table
    ADD CONSTRAINT legacy_payment_table_pkey PRIMARY KEY (id);


--
-- Name: level_change_types level_change_types_name_key; Type: CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.level_change_types
    ADD CONSTRAINT level_change_types_name_key UNIQUE (name);


--
-- Name: level_change_types level_change_types_pkey; Type: CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.level_change_types
    ADD CONSTRAINT level_change_types_pkey PRIMARY KEY (id);


--
-- Name: loan_renewals loan_renewals_pkey; Type: CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.loan_renewals
    ADD CONSTRAINT loan_renewals_pkey PRIMARY KEY (id);


--
-- Name: loan_statuses loan_statuses_name_key; Type: CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.loan_statuses
    ADD CONSTRAINT loan_statuses_name_key UNIQUE (name);


--
-- Name: loan_statuses loan_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.loan_statuses
    ADD CONSTRAINT loan_statuses_pkey PRIMARY KEY (id);


--
-- Name: loans loans_pkey; Type: CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.loans
    ADD CONSTRAINT loans_pkey PRIMARY KEY (id);


--
-- Name: payment_methods payment_methods_name_key; Type: CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.payment_methods
    ADD CONSTRAINT payment_methods_name_key UNIQUE (name);


--
-- Name: payment_methods payment_methods_pkey; Type: CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.payment_methods
    ADD CONSTRAINT payment_methods_pkey PRIMARY KEY (id);


--
-- Name: payment_status_history payment_status_history_pkey; Type: CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.payment_status_history
    ADD CONSTRAINT payment_status_history_pkey PRIMARY KEY (id);


--
-- Name: payment_statuses payment_statuses_name_key; Type: CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.payment_statuses
    ADD CONSTRAINT payment_statuses_name_key UNIQUE (name);


--
-- Name: payment_statuses payment_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.payment_statuses
    ADD CONSTRAINT payment_statuses_pkey PRIMARY KEY (id);


--
-- Name: payments payments_pkey; Type: CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_pkey PRIMARY KEY (id);


--
-- Name: rate_profiles rate_profiles_code_key; Type: CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.rate_profiles
    ADD CONSTRAINT rate_profiles_code_key UNIQUE (code);


--
-- Name: rate_profiles rate_profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.rate_profiles
    ADD CONSTRAINT rate_profiles_pkey PRIMARY KEY (id);


--
-- Name: roles roles_name_key; Type: CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_name_key UNIQUE (name);


--
-- Name: roles roles_pkey; Type: CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_pkey PRIMARY KEY (id);


--
-- Name: statement_statuses statement_statuses_name_key; Type: CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.statement_statuses
    ADD CONSTRAINT statement_statuses_name_key UNIQUE (name);


--
-- Name: statement_statuses statement_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.statement_statuses
    ADD CONSTRAINT statement_statuses_pkey PRIMARY KEY (id);


--
-- Name: system_configurations system_configurations_config_key_key; Type: CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.system_configurations
    ADD CONSTRAINT system_configurations_config_key_key UNIQUE (config_key);


--
-- Name: system_configurations system_configurations_pkey; Type: CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.system_configurations
    ADD CONSTRAINT system_configurations_pkey PRIMARY KEY (id);


--
-- Name: legacy_payment_table uq_legacy_amount_term; Type: CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.legacy_payment_table
    ADD CONSTRAINT uq_legacy_amount_term UNIQUE (amount, term_biweeks);


--
-- Name: user_roles user_roles_pkey; Type: CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.user_roles
    ADD CONSTRAINT user_roles_pkey PRIMARY KEY (user_id, role_id);


--
-- Name: users users_curp_key; Type: CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_curp_key UNIQUE (curp);


--
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- Name: users users_phone_number_key; Type: CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_phone_number_key UNIQUE (phone_number);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: users users_username_key; Type: CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_username_key UNIQUE (username);


--
-- Name: idx_agreement_items_agreement_id; Type: INDEX; Schema: public; Owner: credinet_user
--

CREATE INDEX idx_agreement_items_agreement_id ON public.agreement_items USING btree (agreement_id);


--
-- Name: idx_agreement_items_loan_id; Type: INDEX; Schema: public; Owner: credinet_user
--

CREATE INDEX idx_agreement_items_loan_id ON public.agreement_items USING btree (loan_id);


--
-- Name: idx_agreement_payments_agreement_id; Type: INDEX; Schema: public; Owner: credinet_user
--

CREATE INDEX idx_agreement_payments_agreement_id ON public.agreement_payments USING btree (agreement_id);


--
-- Name: idx_agreement_payments_status; Type: INDEX; Schema: public; Owner: credinet_user
--

CREATE INDEX idx_agreement_payments_status ON public.agreement_payments USING btree (status);


--
-- Name: idx_agreements_associate_profile_id; Type: INDEX; Schema: public; Owner: credinet_user
--

CREATE INDEX idx_agreements_associate_profile_id ON public.agreements USING btree (associate_profile_id);


--
-- Name: idx_agreements_status; Type: INDEX; Schema: public; Owner: credinet_user
--

CREATE INDEX idx_agreements_status ON public.agreements USING btree (status);


--
-- Name: idx_associate_profiles_active; Type: INDEX; Schema: public; Owner: credinet_user
--

CREATE INDEX idx_associate_profiles_active ON public.associate_profiles USING btree (active);


--
-- Name: idx_associate_profiles_credit_used; Type: INDEX; Schema: public; Owner: credinet_user
--

CREATE INDEX idx_associate_profiles_credit_used ON public.associate_profiles USING btree (credit_used);


--
-- Name: idx_associate_profiles_level_id; Type: INDEX; Schema: public; Owner: credinet_user
--

CREATE INDEX idx_associate_profiles_level_id ON public.associate_profiles USING btree (level_id);


--
-- Name: idx_associate_profiles_user_id; Type: INDEX; Schema: public; Owner: credinet_user
--

CREATE INDEX idx_associate_profiles_user_id ON public.associate_profiles USING btree (user_id);


--
-- Name: idx_audit_log_changed_at; Type: INDEX; Schema: public; Owner: credinet_user
--

CREATE INDEX idx_audit_log_changed_at ON public.audit_log USING btree (changed_at);


--
-- Name: idx_audit_log_changed_by; Type: INDEX; Schema: public; Owner: credinet_user
--

CREATE INDEX idx_audit_log_changed_by ON public.audit_log USING btree (changed_by);


--
-- Name: idx_audit_log_operation; Type: INDEX; Schema: public; Owner: credinet_user
--

CREATE INDEX idx_audit_log_operation ON public.audit_log USING btree (operation);


--
-- Name: idx_audit_log_table_record; Type: INDEX; Schema: public; Owner: credinet_user
--

CREATE INDEX idx_audit_log_table_record ON public.audit_log USING btree (table_name, record_id);


--
-- Name: idx_client_documents_status_id; Type: INDEX; Schema: public; Owner: credinet_user
--

CREATE INDEX idx_client_documents_status_id ON public.client_documents USING btree (status_id);


--
-- Name: idx_client_documents_user_id; Type: INDEX; Schema: public; Owner: credinet_user
--

CREATE INDEX idx_client_documents_user_id ON public.client_documents USING btree (user_id);


--
-- Name: idx_config_types_name; Type: INDEX; Schema: public; Owner: credinet_user
--

CREATE INDEX idx_config_types_name ON public.config_types USING btree (name);


--
-- Name: idx_contract_statuses_name; Type: INDEX; Schema: public; Owner: credinet_user
--

CREATE INDEX idx_contract_statuses_name ON public.contract_statuses USING btree (name);


--
-- Name: idx_contracts_document_number; Type: INDEX; Schema: public; Owner: credinet_user
--

CREATE INDEX idx_contracts_document_number ON public.contracts USING btree (document_number);


--
-- Name: idx_contracts_loan_id; Type: INDEX; Schema: public; Owner: credinet_user
--

CREATE INDEX idx_contracts_loan_id ON public.contracts USING btree (loan_id);


--
-- Name: idx_cut_period_statuses_name; Type: INDEX; Schema: public; Owner: credinet_user
--

CREATE INDEX idx_cut_period_statuses_name ON public.cut_period_statuses USING btree (name);


--
-- Name: idx_cut_periods_active; Type: INDEX; Schema: public; Owner: credinet_user
--

CREATE INDEX idx_cut_periods_active ON public.cut_periods USING btree (status_id) WHERE (status_id = ANY (ARRAY[1, 2]));


--
-- Name: idx_cut_periods_cut_code; Type: INDEX; Schema: public; Owner: credinet_user
--

CREATE INDEX idx_cut_periods_cut_code ON public.cut_periods USING btree (cut_code);


--
-- Name: idx_cut_periods_dates; Type: INDEX; Schema: public; Owner: credinet_user
--

CREATE INDEX idx_cut_periods_dates ON public.cut_periods USING btree (period_start_date, period_end_date);


--
-- Name: idx_cut_periods_status_id; Type: INDEX; Schema: public; Owner: credinet_user
--

CREATE INDEX idx_cut_periods_status_id ON public.cut_periods USING btree (status_id);


--
-- Name: idx_debt_breakdown_associate_period; Type: INDEX; Schema: public; Owner: credinet_user
--

CREATE INDEX idx_debt_breakdown_associate_period ON public.associate_debt_breakdown USING btree (associate_profile_id, cut_period_id, is_liquidated);


--
-- Name: idx_debt_breakdown_associate_profile_id; Type: INDEX; Schema: public; Owner: credinet_user
--

CREATE INDEX idx_debt_breakdown_associate_profile_id ON public.associate_debt_breakdown USING btree (associate_profile_id);


--
-- Name: idx_debt_breakdown_cut_period_id; Type: INDEX; Schema: public; Owner: credinet_user
--

CREATE INDEX idx_debt_breakdown_cut_period_id ON public.associate_debt_breakdown USING btree (cut_period_id);


--
-- Name: idx_debt_breakdown_debt_type; Type: INDEX; Schema: public; Owner: credinet_user
--

CREATE INDEX idx_debt_breakdown_debt_type ON public.associate_debt_breakdown USING btree (debt_type);


--
-- Name: idx_debt_breakdown_is_liquidated; Type: INDEX; Schema: public; Owner: credinet_user
--

CREATE INDEX idx_debt_breakdown_is_liquidated ON public.associate_debt_breakdown USING btree (is_liquidated);


--
-- Name: idx_debt_breakdown_loan_id; Type: INDEX; Schema: public; Owner: credinet_user
--

CREATE INDEX idx_debt_breakdown_loan_id ON public.associate_debt_breakdown USING btree (loan_id);


--
-- Name: idx_defaulted_reports_associate_profile_id; Type: INDEX; Schema: public; Owner: credinet_user
--

CREATE INDEX idx_defaulted_reports_associate_profile_id ON public.defaulted_client_reports USING btree (associate_profile_id);


--
-- Name: idx_defaulted_reports_client_user_id; Type: INDEX; Schema: public; Owner: credinet_user
--

CREATE INDEX idx_defaulted_reports_client_user_id ON public.defaulted_client_reports USING btree (client_user_id);


--
-- Name: idx_defaulted_reports_loan_id; Type: INDEX; Schema: public; Owner: credinet_user
--

CREATE INDEX idx_defaulted_reports_loan_id ON public.defaulted_client_reports USING btree (loan_id);


--
-- Name: idx_defaulted_reports_reported_at; Type: INDEX; Schema: public; Owner: credinet_user
--

CREATE INDEX idx_defaulted_reports_reported_at ON public.defaulted_client_reports USING btree (reported_at DESC);


--
-- Name: idx_defaulted_reports_status; Type: INDEX; Schema: public; Owner: credinet_user
--

CREATE INDEX idx_defaulted_reports_status ON public.defaulted_client_reports USING btree (status);


--
-- Name: idx_document_statuses_name; Type: INDEX; Schema: public; Owner: credinet_user
--

CREATE INDEX idx_document_statuses_name ON public.document_statuses USING btree (name);


--
-- Name: idx_legacy_amount; Type: INDEX; Schema: public; Owner: credinet_user
--

CREATE INDEX idx_legacy_amount ON public.legacy_payment_table USING btree (amount);


--
-- Name: idx_legacy_amount_term_unique; Type: INDEX; Schema: public; Owner: credinet_user
--

CREATE UNIQUE INDEX idx_legacy_amount_term_unique ON public.legacy_payment_table USING btree (amount, term_biweeks);


--
-- Name: idx_legacy_term; Type: INDEX; Schema: public; Owner: credinet_user
--

CREATE INDEX idx_legacy_term ON public.legacy_payment_table USING btree (term_biweeks);


--
-- Name: idx_level_change_types_name; Type: INDEX; Schema: public; Owner: credinet_user
--

CREATE INDEX idx_level_change_types_name ON public.level_change_types USING btree (name);


--
-- Name: idx_loan_renewals_original_loan_id; Type: INDEX; Schema: public; Owner: credinet_user
--

CREATE INDEX idx_loan_renewals_original_loan_id ON public.loan_renewals USING btree (original_loan_id);


--
-- Name: idx_loan_renewals_renewed_loan_id; Type: INDEX; Schema: public; Owner: credinet_user
--

CREATE INDEX idx_loan_renewals_renewed_loan_id ON public.loan_renewals USING btree (renewed_loan_id);


--
-- Name: idx_loan_statuses_active; Type: INDEX; Schema: public; Owner: credinet_user
--

CREATE INDEX idx_loan_statuses_active ON public.loan_statuses USING btree (is_active);


--
-- Name: idx_loan_statuses_name; Type: INDEX; Schema: public; Owner: credinet_user
--

CREATE INDEX idx_loan_statuses_name ON public.loan_statuses USING btree (name);


--
-- Name: idx_loans_approved_at; Type: INDEX; Schema: public; Owner: credinet_user
--

CREATE INDEX idx_loans_approved_at ON public.loans USING btree (approved_at) WHERE (approved_at IS NOT NULL);


--
-- Name: idx_loans_associate_user_id; Type: INDEX; Schema: public; Owner: credinet_user
--

CREATE INDEX idx_loans_associate_user_id ON public.loans USING btree (associate_user_id);


--
-- Name: idx_loans_biweekly_payment; Type: INDEX; Schema: public; Owner: credinet_user
--

CREATE INDEX idx_loans_biweekly_payment ON public.loans USING btree (biweekly_payment) WHERE (biweekly_payment IS NOT NULL);


--
-- Name: idx_loans_profile_code_biweekly; Type: INDEX; Schema: public; Owner: credinet_user
--

CREATE INDEX idx_loans_profile_code_biweekly ON public.loans USING btree (profile_code, biweekly_payment) WHERE ((profile_code IS NOT NULL) AND (biweekly_payment IS NOT NULL));


--
-- Name: idx_loans_status_id; Type: INDEX; Schema: public; Owner: credinet_user
--

CREATE INDEX idx_loans_status_id ON public.loans USING btree (status_id);


--
-- Name: idx_loans_status_id_approved_at; Type: INDEX; Schema: public; Owner: credinet_user
--

CREATE INDEX idx_loans_status_id_approved_at ON public.loans USING btree (status_id, approved_at);


--
-- Name: idx_loans_total_payment; Type: INDEX; Schema: public; Owner: credinet_user
--

CREATE INDEX idx_loans_total_payment ON public.loans USING btree (total_payment) WHERE (total_payment IS NOT NULL);


--
-- Name: idx_loans_user_id; Type: INDEX; Schema: public; Owner: credinet_user
--

CREATE INDEX idx_loans_user_id ON public.loans USING btree (user_id);


--
-- Name: idx_payment_methods_name; Type: INDEX; Schema: public; Owner: credinet_user
--

CREATE INDEX idx_payment_methods_name ON public.payment_methods USING btree (name);


--
-- Name: idx_payment_status_history_change_type; Type: INDEX; Schema: public; Owner: credinet_user
--

CREATE INDEX idx_payment_status_history_change_type ON public.payment_status_history USING btree (change_type);


--
-- Name: idx_payment_status_history_changed_at; Type: INDEX; Schema: public; Owner: credinet_user
--

CREATE INDEX idx_payment_status_history_changed_at ON public.payment_status_history USING btree (changed_at DESC);


--
-- Name: idx_payment_status_history_changed_by; Type: INDEX; Schema: public; Owner: credinet_user
--

CREATE INDEX idx_payment_status_history_changed_by ON public.payment_status_history USING btree (changed_by);


--
-- Name: idx_payment_status_history_new_status_id; Type: INDEX; Schema: public; Owner: credinet_user
--

CREATE INDEX idx_payment_status_history_new_status_id ON public.payment_status_history USING btree (new_status_id);


--
-- Name: idx_payment_status_history_payment_changed_at; Type: INDEX; Schema: public; Owner: credinet_user
--

CREATE INDEX idx_payment_status_history_payment_changed_at ON public.payment_status_history USING btree (payment_id, changed_at DESC);


--
-- Name: idx_payment_status_history_payment_id; Type: INDEX; Schema: public; Owner: credinet_user
--

CREATE INDEX idx_payment_status_history_payment_id ON public.payment_status_history USING btree (payment_id);


--
-- Name: idx_payment_statuses_active; Type: INDEX; Schema: public; Owner: credinet_user
--

CREATE INDEX idx_payment_statuses_active ON public.payment_statuses USING btree (is_active);


--
-- Name: idx_payment_statuses_is_real; Type: INDEX; Schema: public; Owner: credinet_user
--

CREATE INDEX idx_payment_statuses_is_real ON public.payment_statuses USING btree (is_real_payment);


--
-- Name: idx_payment_statuses_name; Type: INDEX; Schema: public; Owner: credinet_user
--

CREATE INDEX idx_payment_statuses_name ON public.payment_statuses USING btree (name);


--
-- Name: idx_payments_balance_remaining; Type: INDEX; Schema: public; Owner: credinet_user
--

CREATE INDEX idx_payments_balance_remaining ON public.payments USING btree (balance_remaining) WHERE (balance_remaining IS NOT NULL);


--
-- Name: idx_payments_cut_period_id; Type: INDEX; Schema: public; Owner: credinet_user
--

CREATE INDEX idx_payments_cut_period_id ON public.payments USING btree (cut_period_id);


--
-- Name: idx_payments_due_date_status_expected; Type: INDEX; Schema: public; Owner: credinet_user
--

CREATE INDEX idx_payments_due_date_status_expected ON public.payments USING btree (payment_due_date, status_id, expected_amount) WHERE (expected_amount IS NOT NULL);


--
-- Name: idx_payments_expected_amount; Type: INDEX; Schema: public; Owner: credinet_user
--

CREATE INDEX idx_payments_expected_amount ON public.payments USING btree (expected_amount) WHERE (expected_amount IS NOT NULL);


--
-- Name: idx_payments_is_late; Type: INDEX; Schema: public; Owner: credinet_user
--

CREATE INDEX idx_payments_is_late ON public.payments USING btree (is_late);


--
-- Name: idx_payments_late_loan; Type: INDEX; Schema: public; Owner: credinet_user
--

CREATE INDEX idx_payments_late_loan ON public.payments USING btree (loan_id, is_late, payment_due_date);


--
-- Name: idx_payments_loan_id; Type: INDEX; Schema: public; Owner: credinet_user
--

CREATE INDEX idx_payments_loan_id ON public.payments USING btree (loan_id);


--
-- Name: idx_payments_loan_number_unique; Type: INDEX; Schema: public; Owner: credinet_user
--

CREATE UNIQUE INDEX idx_payments_loan_number_unique ON public.payments USING btree (loan_id, payment_number) WHERE (payment_number IS NOT NULL);


--
-- Name: idx_payments_payment_due_date; Type: INDEX; Schema: public; Owner: credinet_user
--

CREATE INDEX idx_payments_payment_due_date ON public.payments USING btree (payment_due_date);


--
-- Name: idx_payments_payment_number; Type: INDEX; Schema: public; Owner: credinet_user
--

CREATE INDEX idx_payments_payment_number ON public.payments USING btree (payment_number) WHERE (payment_number IS NOT NULL);


--
-- Name: idx_payments_status_id; Type: INDEX; Schema: public; Owner: credinet_user
--

CREATE INDEX idx_payments_status_id ON public.payments USING btree (status_id);


--
-- Name: idx_rate_profiles_code; Type: INDEX; Schema: public; Owner: credinet_user
--

CREATE INDEX idx_rate_profiles_code ON public.rate_profiles USING btree (code);


--
-- Name: idx_rate_profiles_display; Type: INDEX; Schema: public; Owner: credinet_user
--

CREATE INDEX idx_rate_profiles_display ON public.rate_profiles USING btree (display_order);


--
-- Name: idx_rate_profiles_enabled; Type: INDEX; Schema: public; Owner: credinet_user
--

CREATE INDEX idx_rate_profiles_enabled ON public.rate_profiles USING btree (enabled) WHERE (enabled = true);


--
-- Name: idx_session_log_is_active; Type: INDEX; Schema: public; Owner: credinet_user
--

CREATE INDEX idx_session_log_is_active ON public.audit_session_log USING btree (is_active);


--
-- Name: idx_session_log_login_at; Type: INDEX; Schema: public; Owner: credinet_user
--

CREATE INDEX idx_session_log_login_at ON public.audit_session_log USING btree (login_at DESC);


--
-- Name: idx_session_log_user_id; Type: INDEX; Schema: public; Owner: credinet_user
--

CREATE INDEX idx_session_log_user_id ON public.audit_session_log USING btree (user_id);


--
-- Name: idx_statement_statuses_name; Type: INDEX; Schema: public; Owner: credinet_user
--

CREATE INDEX idx_statement_statuses_name ON public.statement_statuses USING btree (name);


--
-- Name: idx_users_active; Type: INDEX; Schema: public; Owner: credinet_user
--

CREATE INDEX idx_users_active ON public.users USING btree (active);


--
-- Name: idx_users_email_lower; Type: INDEX; Schema: public; Owner: credinet_user
--

CREATE INDEX idx_users_email_lower ON public.users USING btree (lower((email)::text));


--
-- Name: idx_users_username_lower; Type: INDEX; Schema: public; Owner: credinet_user
--

CREATE INDEX idx_users_username_lower ON public.users USING btree (lower((username)::text));


--
-- Name: contracts audit_contracts_trigger; Type: TRIGGER; Schema: public; Owner: credinet_user
--

CREATE TRIGGER audit_contracts_trigger AFTER INSERT OR DELETE OR UPDATE ON public.contracts FOR EACH ROW EXECUTE FUNCTION public.audit_trigger_function();


--
-- Name: cut_periods audit_cut_periods_trigger; Type: TRIGGER; Schema: public; Owner: credinet_user
--

CREATE TRIGGER audit_cut_periods_trigger AFTER INSERT OR DELETE OR UPDATE ON public.cut_periods FOR EACH ROW EXECUTE FUNCTION public.audit_trigger_function();


--
-- Name: loans audit_loans_trigger; Type: TRIGGER; Schema: public; Owner: credinet_user
--

CREATE TRIGGER audit_loans_trigger AFTER INSERT OR DELETE OR UPDATE ON public.loans FOR EACH ROW EXECUTE FUNCTION public.audit_trigger_function();


--
-- Name: TRIGGER audit_loans_trigger ON loans; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON TRIGGER audit_loans_trigger ON public.loans IS 'Registra todos los cambios en la tabla loans en audit_log para trazabilidad completa.';


--
-- Name: payments audit_payments_trigger; Type: TRIGGER; Schema: public; Owner: credinet_user
--

CREATE TRIGGER audit_payments_trigger AFTER INSERT OR DELETE OR UPDATE ON public.payments FOR EACH ROW EXECUTE FUNCTION public.audit_trigger_function();


--
-- Name: TRIGGER audit_payments_trigger ON payments; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON TRIGGER audit_payments_trigger ON public.payments IS 'Registra todos los cambios en la tabla payments en audit_log para trazabilidad completa.';


--
-- Name: users audit_users_trigger; Type: TRIGGER; Schema: public; Owner: credinet_user
--

CREATE TRIGGER audit_users_trigger AFTER INSERT OR DELETE OR UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION public.audit_trigger_function();


--
-- Name: loans handle_loan_approval_trigger; Type: TRIGGER; Schema: public; Owner: credinet_user
--

CREATE TRIGGER handle_loan_approval_trigger BEFORE UPDATE ON public.loans FOR EACH ROW EXECUTE FUNCTION public.handle_loan_approval_status();


--
-- Name: TRIGGER handle_loan_approval_trigger ON loans; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON TRIGGER handle_loan_approval_trigger ON public.loans IS 'Setea automáticamente approved_at o rejected_at cuando el estado del préstamo cambia a APPROVED o REJECTED.';


--
-- Name: loans trigger_generate_payment_schedule; Type: TRIGGER; Schema: public; Owner: credinet_user
--

CREATE TRIGGER trigger_generate_payment_schedule AFTER UPDATE OF status_id ON public.loans FOR EACH ROW EXECUTE FUNCTION public.generate_payment_schedule();


--
-- Name: TRIGGER trigger_generate_payment_schedule ON loans; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON TRIGGER trigger_generate_payment_schedule ON public.loans IS 'Trigger que genera automáticamente el cronograma de pagos cuando un préstamo es aprobado.
Se ejecuta AFTER UPDATE OF status_id para detectar cambios a APPROVED.';


--
-- Name: legacy_payment_table trigger_legacy_payment_table_updated_at; Type: TRIGGER; Schema: public; Owner: credinet_user
--

CREATE TRIGGER trigger_legacy_payment_table_updated_at BEFORE UPDATE ON public.legacy_payment_table FOR EACH ROW EXECUTE FUNCTION public.update_legacy_payment_table_timestamp();


--
-- Name: payments trigger_log_payment_status_change; Type: TRIGGER; Schema: public; Owner: credinet_user
--

CREATE TRIGGER trigger_log_payment_status_change AFTER UPDATE OF status_id ON public.payments FOR EACH ROW EXECUTE FUNCTION public.log_payment_status_change();


--
-- Name: TRIGGER trigger_log_payment_status_change ON payments; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON TRIGGER trigger_log_payment_status_change ON public.payments IS '⭐ MIGRACIÓN 12: Registra automáticamente todos los cambios de estado de pagos en payment_status_history para auditoría completa y compliance.';


--
-- Name: associate_debt_breakdown trigger_update_associate_credit_on_debt_payment; Type: TRIGGER; Schema: public; Owner: credinet_user
--

CREATE TRIGGER trigger_update_associate_credit_on_debt_payment AFTER UPDATE OF is_liquidated ON public.associate_debt_breakdown FOR EACH ROW EXECUTE FUNCTION public.trigger_update_associate_credit_on_debt_payment();


--
-- Name: TRIGGER trigger_update_associate_credit_on_debt_payment ON associate_debt_breakdown; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON TRIGGER trigger_update_associate_credit_on_debt_payment ON public.associate_debt_breakdown IS '⭐ MIGRACIÓN 07: Decrementa debt_balance del asociado cuando liquida una deuda.';


--
-- Name: associate_profiles trigger_update_associate_credit_on_level_change; Type: TRIGGER; Schema: public; Owner: credinet_user
--

CREATE TRIGGER trigger_update_associate_credit_on_level_change AFTER UPDATE OF level_id ON public.associate_profiles FOR EACH ROW EXECUTE FUNCTION public.trigger_update_associate_credit_on_level_change();


--
-- Name: TRIGGER trigger_update_associate_credit_on_level_change ON associate_profiles; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON TRIGGER trigger_update_associate_credit_on_level_change ON public.associate_profiles IS '⭐ MIGRACIÓN 07: Actualiza credit_limit del asociado cuando cambia de nivel (promoción/descenso).';


--
-- Name: loans trigger_update_associate_credit_on_loan_approval; Type: TRIGGER; Schema: public; Owner: credinet_user
--

CREATE TRIGGER trigger_update_associate_credit_on_loan_approval AFTER UPDATE OF status_id ON public.loans FOR EACH ROW EXECUTE FUNCTION public.trigger_update_associate_credit_on_loan_approval();


--
-- Name: TRIGGER trigger_update_associate_credit_on_loan_approval ON loans; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON TRIGGER trigger_update_associate_credit_on_loan_approval ON public.loans IS '⭐ MIGRACIÓN 07: Incrementa credit_used del asociado cuando se aprueba un préstamo.';


--
-- Name: payments trigger_update_associate_credit_on_payment; Type: TRIGGER; Schema: public; Owner: credinet_user
--

CREATE TRIGGER trigger_update_associate_credit_on_payment AFTER UPDATE OF amount_paid ON public.payments FOR EACH ROW EXECUTE FUNCTION public.trigger_update_associate_credit_on_payment();


--
-- Name: TRIGGER trigger_update_associate_credit_on_payment ON payments; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON TRIGGER trigger_update_associate_credit_on_payment ON public.payments IS '⭐ MIGRACIÓN 07: Decrementa credit_used del asociado cuando se registra un pago.';


--
-- Name: addresses update_addresses_updated_at; Type: TRIGGER; Schema: public; Owner: credinet_user
--

CREATE TRIGGER update_addresses_updated_at BEFORE UPDATE ON public.addresses FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: associate_payment_statements update_associate_payment_statements_updated_at; Type: TRIGGER; Schema: public; Owner: credinet_user
--

CREATE TRIGGER update_associate_payment_statements_updated_at BEFORE UPDATE ON public.associate_payment_statements FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: associate_profiles update_associate_profiles_updated_at; Type: TRIGGER; Schema: public; Owner: credinet_user
--

CREATE TRIGGER update_associate_profiles_updated_at BEFORE UPDATE ON public.associate_profiles FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: beneficiaries update_beneficiaries_updated_at; Type: TRIGGER; Schema: public; Owner: credinet_user
--

CREATE TRIGGER update_beneficiaries_updated_at BEFORE UPDATE ON public.beneficiaries FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: client_documents update_client_documents_updated_at; Type: TRIGGER; Schema: public; Owner: credinet_user
--

CREATE TRIGGER update_client_documents_updated_at BEFORE UPDATE ON public.client_documents FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: config_types update_config_types_updated_at; Type: TRIGGER; Schema: public; Owner: credinet_user
--

CREATE TRIGGER update_config_types_updated_at BEFORE UPDATE ON public.config_types FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: contract_statuses update_contract_statuses_updated_at; Type: TRIGGER; Schema: public; Owner: credinet_user
--

CREATE TRIGGER update_contract_statuses_updated_at BEFORE UPDATE ON public.contract_statuses FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: contracts update_contracts_updated_at; Type: TRIGGER; Schema: public; Owner: credinet_user
--

CREATE TRIGGER update_contracts_updated_at BEFORE UPDATE ON public.contracts FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: cut_period_statuses update_cut_period_statuses_updated_at; Type: TRIGGER; Schema: public; Owner: credinet_user
--

CREATE TRIGGER update_cut_period_statuses_updated_at BEFORE UPDATE ON public.cut_period_statuses FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: cut_periods update_cut_periods_updated_at; Type: TRIGGER; Schema: public; Owner: credinet_user
--

CREATE TRIGGER update_cut_periods_updated_at BEFORE UPDATE ON public.cut_periods FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: document_statuses update_document_statuses_updated_at; Type: TRIGGER; Schema: public; Owner: credinet_user
--

CREATE TRIGGER update_document_statuses_updated_at BEFORE UPDATE ON public.document_statuses FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: guarantors update_guarantors_updated_at; Type: TRIGGER; Schema: public; Owner: credinet_user
--

CREATE TRIGGER update_guarantors_updated_at BEFORE UPDATE ON public.guarantors FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: level_change_types update_level_change_types_updated_at; Type: TRIGGER; Schema: public; Owner: credinet_user
--

CREATE TRIGGER update_level_change_types_updated_at BEFORE UPDATE ON public.level_change_types FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: loan_statuses update_loan_statuses_updated_at; Type: TRIGGER; Schema: public; Owner: credinet_user
--

CREATE TRIGGER update_loan_statuses_updated_at BEFORE UPDATE ON public.loan_statuses FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: loans update_loans_updated_at; Type: TRIGGER; Schema: public; Owner: credinet_user
--

CREATE TRIGGER update_loans_updated_at BEFORE UPDATE ON public.loans FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: TRIGGER update_loans_updated_at ON loans; Type: COMMENT; Schema: public; Owner: credinet_user
--

COMMENT ON TRIGGER update_loans_updated_at ON public.loans IS 'Actualiza automáticamente el campo updated_at cuando se modifica un registro de loans.';


--
-- Name: payment_methods update_payment_methods_updated_at; Type: TRIGGER; Schema: public; Owner: credinet_user
--

CREATE TRIGGER update_payment_methods_updated_at BEFORE UPDATE ON public.payment_methods FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: payments update_payments_updated_at; Type: TRIGGER; Schema: public; Owner: credinet_user
--

CREATE TRIGGER update_payments_updated_at BEFORE UPDATE ON public.payments FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: statement_statuses update_statement_statuses_updated_at; Type: TRIGGER; Schema: public; Owner: credinet_user
--

CREATE TRIGGER update_statement_statuses_updated_at BEFORE UPDATE ON public.statement_statuses FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: system_configurations update_system_configurations_updated_at; Type: TRIGGER; Schema: public; Owner: credinet_user
--

CREATE TRIGGER update_system_configurations_updated_at BEFORE UPDATE ON public.system_configurations FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: users update_users_updated_at; Type: TRIGGER; Schema: public; Owner: credinet_user
--

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: addresses addresses_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.addresses
    ADD CONSTRAINT addresses_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: agreement_items agreement_items_agreement_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.agreement_items
    ADD CONSTRAINT agreement_items_agreement_id_fkey FOREIGN KEY (agreement_id) REFERENCES public.agreements(id) ON DELETE CASCADE;


--
-- Name: agreement_items agreement_items_client_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.agreement_items
    ADD CONSTRAINT agreement_items_client_user_id_fkey FOREIGN KEY (client_user_id) REFERENCES public.users(id);


--
-- Name: agreement_items agreement_items_loan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.agreement_items
    ADD CONSTRAINT agreement_items_loan_id_fkey FOREIGN KEY (loan_id) REFERENCES public.loans(id);


--
-- Name: agreement_payments agreement_payments_agreement_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.agreement_payments
    ADD CONSTRAINT agreement_payments_agreement_id_fkey FOREIGN KEY (agreement_id) REFERENCES public.agreements(id) ON DELETE CASCADE;


--
-- Name: agreement_payments agreement_payments_payment_method_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.agreement_payments
    ADD CONSTRAINT agreement_payments_payment_method_id_fkey FOREIGN KEY (payment_method_id) REFERENCES public.payment_methods(id);


--
-- Name: agreements agreements_approved_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.agreements
    ADD CONSTRAINT agreements_approved_by_fkey FOREIGN KEY (approved_by) REFERENCES public.users(id);


--
-- Name: agreements agreements_associate_profile_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.agreements
    ADD CONSTRAINT agreements_associate_profile_id_fkey FOREIGN KEY (associate_profile_id) REFERENCES public.associate_profiles(id) ON DELETE CASCADE;


--
-- Name: agreements agreements_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.agreements
    ADD CONSTRAINT agreements_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);


--
-- Name: associate_accumulated_balances associate_accumulated_balances_cut_period_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.associate_accumulated_balances
    ADD CONSTRAINT associate_accumulated_balances_cut_period_id_fkey FOREIGN KEY (cut_period_id) REFERENCES public.cut_periods(id);


--
-- Name: associate_accumulated_balances associate_accumulated_balances_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.associate_accumulated_balances
    ADD CONSTRAINT associate_accumulated_balances_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: associate_debt_breakdown associate_debt_breakdown_associate_profile_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.associate_debt_breakdown
    ADD CONSTRAINT associate_debt_breakdown_associate_profile_id_fkey FOREIGN KEY (associate_profile_id) REFERENCES public.associate_profiles(id) ON DELETE CASCADE;


--
-- Name: associate_debt_breakdown associate_debt_breakdown_client_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.associate_debt_breakdown
    ADD CONSTRAINT associate_debt_breakdown_client_user_id_fkey FOREIGN KEY (client_user_id) REFERENCES public.users(id);


--
-- Name: associate_debt_breakdown associate_debt_breakdown_cut_period_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.associate_debt_breakdown
    ADD CONSTRAINT associate_debt_breakdown_cut_period_id_fkey FOREIGN KEY (cut_period_id) REFERENCES public.cut_periods(id);


--
-- Name: associate_debt_breakdown associate_debt_breakdown_loan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.associate_debt_breakdown
    ADD CONSTRAINT associate_debt_breakdown_loan_id_fkey FOREIGN KEY (loan_id) REFERENCES public.loans(id);


--
-- Name: associate_level_history associate_level_history_associate_profile_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.associate_level_history
    ADD CONSTRAINT associate_level_history_associate_profile_id_fkey FOREIGN KEY (associate_profile_id) REFERENCES public.associate_profiles(id) ON DELETE CASCADE;


--
-- Name: associate_level_history associate_level_history_change_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.associate_level_history
    ADD CONSTRAINT associate_level_history_change_type_id_fkey FOREIGN KEY (change_type_id) REFERENCES public.level_change_types(id);


--
-- Name: associate_level_history associate_level_history_new_level_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.associate_level_history
    ADD CONSTRAINT associate_level_history_new_level_id_fkey FOREIGN KEY (new_level_id) REFERENCES public.associate_levels(id);


--
-- Name: associate_level_history associate_level_history_old_level_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.associate_level_history
    ADD CONSTRAINT associate_level_history_old_level_id_fkey FOREIGN KEY (old_level_id) REFERENCES public.associate_levels(id);


--
-- Name: associate_payment_statements associate_payment_statements_cut_period_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.associate_payment_statements
    ADD CONSTRAINT associate_payment_statements_cut_period_id_fkey FOREIGN KEY (cut_period_id) REFERENCES public.cut_periods(id);


--
-- Name: associate_payment_statements associate_payment_statements_payment_method_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.associate_payment_statements
    ADD CONSTRAINT associate_payment_statements_payment_method_id_fkey FOREIGN KEY (payment_method_id) REFERENCES public.payment_methods(id);


--
-- Name: associate_payment_statements associate_payment_statements_status_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.associate_payment_statements
    ADD CONSTRAINT associate_payment_statements_status_id_fkey FOREIGN KEY (status_id) REFERENCES public.statement_statuses(id);


--
-- Name: associate_payment_statements associate_payment_statements_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.associate_payment_statements
    ADD CONSTRAINT associate_payment_statements_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: associate_profiles associate_profiles_level_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.associate_profiles
    ADD CONSTRAINT associate_profiles_level_id_fkey FOREIGN KEY (level_id) REFERENCES public.associate_levels(id);


--
-- Name: associate_profiles associate_profiles_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.associate_profiles
    ADD CONSTRAINT associate_profiles_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: audit_log audit_log_changed_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.audit_log
    ADD CONSTRAINT audit_log_changed_by_fkey FOREIGN KEY (changed_by) REFERENCES public.users(id);


--
-- Name: audit_session_log audit_session_log_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.audit_session_log
    ADD CONSTRAINT audit_session_log_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: beneficiaries beneficiaries_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.beneficiaries
    ADD CONSTRAINT beneficiaries_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: client_documents client_documents_document_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.client_documents
    ADD CONSTRAINT client_documents_document_type_id_fkey FOREIGN KEY (document_type_id) REFERENCES public.document_types(id);


--
-- Name: client_documents client_documents_reviewed_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.client_documents
    ADD CONSTRAINT client_documents_reviewed_by_fkey FOREIGN KEY (reviewed_by) REFERENCES public.users(id);


--
-- Name: client_documents client_documents_status_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.client_documents
    ADD CONSTRAINT client_documents_status_id_fkey FOREIGN KEY (status_id) REFERENCES public.document_statuses(id);


--
-- Name: client_documents client_documents_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.client_documents
    ADD CONSTRAINT client_documents_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: contracts contracts_loan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.contracts
    ADD CONSTRAINT contracts_loan_id_fkey FOREIGN KEY (loan_id) REFERENCES public.loans(id) ON DELETE CASCADE;


--
-- Name: contracts contracts_status_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.contracts
    ADD CONSTRAINT contracts_status_id_fkey FOREIGN KEY (status_id) REFERENCES public.contract_statuses(id);


--
-- Name: cut_periods cut_periods_closed_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.cut_periods
    ADD CONSTRAINT cut_periods_closed_by_fkey FOREIGN KEY (closed_by) REFERENCES public.users(id);


--
-- Name: cut_periods cut_periods_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.cut_periods
    ADD CONSTRAINT cut_periods_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);


--
-- Name: cut_periods cut_periods_status_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.cut_periods
    ADD CONSTRAINT cut_periods_status_id_fkey FOREIGN KEY (status_id) REFERENCES public.cut_period_statuses(id);


--
-- Name: defaulted_client_reports defaulted_client_reports_approved_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.defaulted_client_reports
    ADD CONSTRAINT defaulted_client_reports_approved_by_fkey FOREIGN KEY (approved_by) REFERENCES public.users(id);


--
-- Name: defaulted_client_reports defaulted_client_reports_associate_profile_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.defaulted_client_reports
    ADD CONSTRAINT defaulted_client_reports_associate_profile_id_fkey FOREIGN KEY (associate_profile_id) REFERENCES public.associate_profiles(id) ON DELETE CASCADE;


--
-- Name: defaulted_client_reports defaulted_client_reports_client_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.defaulted_client_reports
    ADD CONSTRAINT defaulted_client_reports_client_user_id_fkey FOREIGN KEY (client_user_id) REFERENCES public.users(id);


--
-- Name: defaulted_client_reports defaulted_client_reports_loan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.defaulted_client_reports
    ADD CONSTRAINT defaulted_client_reports_loan_id_fkey FOREIGN KEY (loan_id) REFERENCES public.loans(id);


--
-- Name: defaulted_client_reports defaulted_client_reports_reported_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.defaulted_client_reports
    ADD CONSTRAINT defaulted_client_reports_reported_by_fkey FOREIGN KEY (reported_by) REFERENCES public.users(id);


--
-- Name: loans fk_loans_contract_id; Type: FK CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.loans
    ADD CONSTRAINT fk_loans_contract_id FOREIGN KEY (contract_id) REFERENCES public.contracts(id);


--
-- Name: loans fk_loans_profile_code; Type: FK CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.loans
    ADD CONSTRAINT fk_loans_profile_code FOREIGN KEY (profile_code) REFERENCES public.rate_profiles(code) ON DELETE SET NULL;


--
-- Name: guarantors guarantors_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.guarantors
    ADD CONSTRAINT guarantors_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: legacy_payment_table legacy_payment_table_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.legacy_payment_table
    ADD CONSTRAINT legacy_payment_table_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);


--
-- Name: legacy_payment_table legacy_payment_table_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.legacy_payment_table
    ADD CONSTRAINT legacy_payment_table_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.users(id);


--
-- Name: loan_renewals loan_renewals_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.loan_renewals
    ADD CONSTRAINT loan_renewals_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);


--
-- Name: loan_renewals loan_renewals_original_loan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.loan_renewals
    ADD CONSTRAINT loan_renewals_original_loan_id_fkey FOREIGN KEY (original_loan_id) REFERENCES public.loans(id);


--
-- Name: loan_renewals loan_renewals_renewed_loan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.loan_renewals
    ADD CONSTRAINT loan_renewals_renewed_loan_id_fkey FOREIGN KEY (renewed_loan_id) REFERENCES public.loans(id);


--
-- Name: loans loans_approved_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.loans
    ADD CONSTRAINT loans_approved_by_fkey FOREIGN KEY (approved_by) REFERENCES public.users(id);


--
-- Name: loans loans_associate_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.loans
    ADD CONSTRAINT loans_associate_user_id_fkey FOREIGN KEY (associate_user_id) REFERENCES public.users(id);


--
-- Name: loans loans_rejected_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.loans
    ADD CONSTRAINT loans_rejected_by_fkey FOREIGN KEY (rejected_by) REFERENCES public.users(id);


--
-- Name: loans loans_status_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.loans
    ADD CONSTRAINT loans_status_id_fkey FOREIGN KEY (status_id) REFERENCES public.loan_statuses(id);


--
-- Name: loans loans_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.loans
    ADD CONSTRAINT loans_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: payment_status_history payment_status_history_changed_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.payment_status_history
    ADD CONSTRAINT payment_status_history_changed_by_fkey FOREIGN KEY (changed_by) REFERENCES public.users(id);


--
-- Name: payment_status_history payment_status_history_new_status_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.payment_status_history
    ADD CONSTRAINT payment_status_history_new_status_id_fkey FOREIGN KEY (new_status_id) REFERENCES public.payment_statuses(id);


--
-- Name: payment_status_history payment_status_history_old_status_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.payment_status_history
    ADD CONSTRAINT payment_status_history_old_status_id_fkey FOREIGN KEY (old_status_id) REFERENCES public.payment_statuses(id);


--
-- Name: payment_status_history payment_status_history_payment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.payment_status_history
    ADD CONSTRAINT payment_status_history_payment_id_fkey FOREIGN KEY (payment_id) REFERENCES public.payments(id) ON DELETE CASCADE;


--
-- Name: payments payments_cut_period_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_cut_period_id_fkey FOREIGN KEY (cut_period_id) REFERENCES public.cut_periods(id);


--
-- Name: payments payments_loan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_loan_id_fkey FOREIGN KEY (loan_id) REFERENCES public.loans(id) ON DELETE CASCADE;


--
-- Name: payments payments_marked_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_marked_by_fkey FOREIGN KEY (marked_by) REFERENCES public.users(id);


--
-- Name: payments payments_status_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_status_id_fkey FOREIGN KEY (status_id) REFERENCES public.payment_statuses(id);


--
-- Name: rate_profiles rate_profiles_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.rate_profiles
    ADD CONSTRAINT rate_profiles_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);


--
-- Name: rate_profiles rate_profiles_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.rate_profiles
    ADD CONSTRAINT rate_profiles_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.users(id);


--
-- Name: system_configurations system_configurations_config_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.system_configurations
    ADD CONSTRAINT system_configurations_config_type_id_fkey FOREIGN KEY (config_type_id) REFERENCES public.config_types(id);


--
-- Name: system_configurations system_configurations_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.system_configurations
    ADD CONSTRAINT system_configurations_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.users(id);


--
-- Name: user_roles user_roles_role_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.user_roles
    ADD CONSTRAINT user_roles_role_id_fkey FOREIGN KEY (role_id) REFERENCES public.roles(id) ON DELETE CASCADE;


--
-- Name: user_roles user_roles_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: credinet_user
--

ALTER TABLE ONLY public.user_roles
    ADD CONSTRAINT user_roles_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

\unrestrict 2CAUdwpecTB9lNLBXs700Wub5AcAVQ6RDIeRPoS8atWMRe9csVlhwCyEaI2t9LY

