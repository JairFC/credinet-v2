--
-- PostgreSQL database dump
--

\restrict 5MXCZGcbiGv8fFN1bGMrTpUjmMnkzcHWHylfFuQIWWI0POuTo6uciP8cgOf6UtI

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

--
-- Name: admin_mark_payment_status(integer, integer, integer, text); Type: FUNCTION; Schema: public; Owner: -
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


--
-- Name: apply_debt_payment_v2(integer, numeric, integer, character varying, integer, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.apply_debt_payment_v2(p_associate_profile_id integer, p_payment_amount numeric, p_payment_method_id integer, p_payment_reference character varying, p_registered_by integer, p_notes text DEFAULT NULL::text) RETURNS TABLE(payment_id integer, amount_applied numeric, remaining_debt numeric, applied_items jsonb, credit_released numeric)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_user_id INTEGER;
    v_remaining_amount DECIMAL(12,2);
    v_debt_record RECORD;
    v_applied_items JSONB := '[]'::jsonb;
    v_item JSONB;
    v_amount_to_apply DECIMAL(12,2);
    v_total_applied DECIMAL(12,2) := 0;
    v_payment_id INTEGER;
    v_credit_before DECIMAL(12,2);
    v_credit_after DECIMAL(12,2);
BEGIN
    -- Validaciones iniciales
    IF p_payment_amount <= 0 THEN
        RAISE EXCEPTION 'El monto del abono debe ser mayor a 0';
    END IF;
    
    -- Obtener user_id y crédito actual
    SELECT ap.user_id, ap.credit_available
    INTO v_user_id, v_credit_before
    FROM associate_profiles ap WHERE ap.id = p_associate_profile_id;
    
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Perfil de asociado % no encontrado', p_associate_profile_id;
    END IF;
    
    v_remaining_amount := p_payment_amount;
    
    -- ⭐ APLICAR FIFO: liquidar deudas más antiguas primero desde accumulated_balances
    FOR v_debt_record IN (
        SELECT 
            aab.id,
            aab.accumulated_debt,
            aab.cut_period_id,
            aab.created_at,
            cp.cut_code
        FROM associate_accumulated_balances aab
        JOIN cut_periods cp ON cp.id = aab.cut_period_id
        WHERE aab.user_id = v_user_id
          AND aab.accumulated_debt > 0
        ORDER BY aab.created_at ASC, aab.id ASC  -- ⭐ FIFO por fecha
    )
    LOOP
        EXIT WHEN v_remaining_amount <= 0;
        
        IF v_remaining_amount >= v_debt_record.accumulated_debt THEN
            -- Liquidar completamente este item
            v_amount_to_apply := v_debt_record.accumulated_debt;
            
            UPDATE associate_accumulated_balances
            SET 
                accumulated_debt = 0,
                updated_at = CURRENT_TIMESTAMP
            WHERE id = v_debt_record.id;
            
            v_remaining_amount := v_remaining_amount - v_amount_to_apply;
            
            v_item := jsonb_build_object(
                'accumulated_balance_id', v_debt_record.id,
                'cut_period_id', v_debt_record.cut_period_id,
                'period_code', v_debt_record.cut_code,
                'original_debt', v_debt_record.accumulated_debt,
                'amount_applied', v_amount_to_apply,
                'remaining_debt', 0,
                'fully_liquidated', true
            );
        ELSE
            -- Liquidar parcialmente
            v_amount_to_apply := v_remaining_amount;
            
            UPDATE associate_accumulated_balances
            SET 
                accumulated_debt = accumulated_debt - v_remaining_amount,
                updated_at = CURRENT_TIMESTAMP
            WHERE id = v_debt_record.id;
            
            v_item := jsonb_build_object(
                'accumulated_balance_id', v_debt_record.id,
                'cut_period_id', v_debt_record.cut_period_id,
                'period_code', v_debt_record.cut_code,
                'original_debt', v_debt_record.accumulated_debt,
                'amount_applied', v_amount_to_apply,
                'remaining_debt', v_debt_record.accumulated_debt - v_remaining_amount,
                'fully_liquidated', false
            );
            
            v_remaining_amount := 0;
        END IF;
        
        v_applied_items := v_applied_items || v_item;
        v_total_applied := v_total_applied + v_amount_to_apply;
    END LOOP;
    
    -- Si no se aplicó nada (no había deuda), advertir
    IF v_total_applied = 0 THEN
        RAISE EXCEPTION 'No se encontró deuda pendiente para aplicar el abono';
    END IF;
    
    -- Insertar registro de pago
    INSERT INTO associate_debt_payments (
        associate_profile_id,
        payment_amount,
        payment_date,
        payment_method_id,
        payment_reference,
        registered_by,
        applied_breakdown_items,
        notes
    ) VALUES (
        p_associate_profile_id,
        v_total_applied,  -- Solo el monto realmente aplicado
        CURRENT_DATE,
        p_payment_method_id,
        p_payment_reference,
        p_registered_by,
        v_applied_items,
        CASE 
            WHEN v_remaining_amount > 0 THEN 
                COALESCE(p_notes, '') || ' [Sobrante no aplicado: ' || v_remaining_amount || ']'
            ELSE p_notes
        END
    )
    RETURNING id INTO v_payment_id;
    
    -- Sincronizar debt_balance en associate_profiles
    PERFORM sync_associate_debt_balance(p_associate_profile_id);
    
    -- Recalcular crédito disponible (liberar el monto pagado)
    UPDATE associate_profiles
    SET 
        credit_available = credit_available + v_total_applied,
        credit_used = credit_used - v_total_applied,
        credit_last_updated = CURRENT_TIMESTAMP,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = p_associate_profile_id
    RETURNING credit_available INTO v_credit_after;
    
    -- Retornar resultado
    RETURN QUERY SELECT 
        v_payment_id,
        v_total_applied,
        (SELECT COALESCE(SUM(accumulated_debt), 0) FROM associate_accumulated_balances WHERE user_id = v_user_id),
        v_applied_items,
        v_credit_after - v_credit_before;
END;
$$;


--
-- Name: apply_excess_to_debt_fifo(integer, numeric, character varying); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.apply_excess_to_debt_fifo(p_associate_profile_id integer, p_excess_amount numeric, p_payment_reference character varying) RETURNS void
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


--
-- Name: approve_defaulted_client_report(integer, integer, integer); Type: FUNCTION; Schema: public; Owner: -
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


--
-- Name: audit_trigger_function(); Type: FUNCTION; Schema: public; Owner: -
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


--
-- Name: auto_generate_statements_at_midnight(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.auto_generate_statements_at_midnight() RETURNS TABLE(period_code character varying, statements_generated integer, total_amount numeric)
    LANGUAGE plpgsql
    AS $_$
DECLARE
    v_current_day INTEGER;
    v_is_cut_day BOOLEAN;
    v_period_id INTEGER;
    v_period_code VARCHAR(20);
    v_count INTEGER;
    v_total NUMERIC(12,2);
BEGIN
    v_current_day := EXTRACT(DAY FROM CURRENT_DATE);
    
    -- Verificar si es día de corte (8 o 23)
    v_is_cut_day := v_current_day IN (8, 23);
    
    IF NOT v_is_cut_day THEN
        RAISE NOTICE 'Hoy no es día de corte (día %, esperado 8 o 23)', v_current_day;
        RETURN;
    END IF;
    
    -- Obtener periodo correspondiente a hoy (día de impresión)
    SELECT id, cut_code INTO v_period_id, v_period_code
    FROM cut_periods
    WHERE period_end_date + 1 = CURRENT_DATE;
    
    IF v_period_id IS NULL THEN
        RAISE EXCEPTION 'No se encontró periodo para hoy: %', CURRENT_DATE;
    END IF;
    
    RAISE NOTICE '🔄 Iniciando corte automático para periodo: %', v_period_code;
    
    -- Generar statements automáticos con estado DRAFT (ID 6)
    INSERT INTO associate_payment_statements (
        cut_period_id,
        user_id,
        statement_number,
        total_payments_count,
        total_amount_collected,
        total_commission_owed,
        commission_rate_applied,
        status_id,
        generated_date,
        due_date
    )
    SELECT 
        v_period_id,
        l.associate_user_id,
        CONCAT(v_period_code, '-A', l.associate_user_id) as statement_number,
        COUNT(p.id) as total_payments,
        SUM(p.expected_amount) as total_amount,
        SUM(p.commission_amount) as total_commission,
        l.commission_rate,
        6,  -- DRAFT
        CURRENT_DATE,
        CURRENT_DATE + INTERVAL '7 days'
    FROM payments p
    JOIN loans l ON p.loan_id = l.id
    WHERE p.cut_period_id = v_period_id
      AND p.status_id = 1  -- PENDING
      AND l.associate_user_id IS NOT NULL
    GROUP BY v_period_id, l.associate_user_id, v_period_code, l.commission_rate
    ON CONFLICT DO NOTHING;
    
    GET DIAGNOSTICS v_count = ROW_COUNT;
    
    -- Calcular total generado
    SELECT COALESCE(SUM(total_amount_collected), 0) INTO v_total
    FROM associate_payment_statements
    WHERE cut_period_id = v_period_id AND status_id = 6;
    
    RAISE NOTICE '✅ Corte automático completado: % statements en DRAFT, Total: $%',
        v_count, v_total;
    
    -- Retornar resumen
    RETURN QUERY SELECT v_period_code, v_count, v_total;
END;
$_$;


--
-- Name: calculate_first_payment_date(date); Type: FUNCTION; Schema: public; Owner: -
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


--
-- Name: calculate_late_fee_for_statement(integer); Type: FUNCTION; Schema: public; Owner: -
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


--
-- Name: calculate_loan_payment(numeric, integer, character varying); Type: FUNCTION; Schema: public; Owner: -
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
    -- Obtener perfil
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
        v_commission_per_payment := COALESCE(v_legacy_entry.commission_per_payment, 0);
        
        RETURN QUERY SELECT
            v_profile.code,
            v_profile.name,
            v_profile.calculation_type,
            v_legacy_entry.biweekly_rate_percent AS interest_rate,
            ROUND(((COALESCE(v_legacy_entry.commission_per_payment, 0) / NULLIF(v_payment, 0)) * 100)::NUMERIC, 3) AS commission_rate,
            v_payment,
            v_total,
            v_legacy_entry.total_interest,
            v_legacy_entry.effective_rate_percent,
            ROUND(v_commission_per_payment, 2),
            ROUND(COALESCE(v_legacy_entry.total_commission, 0), 2),
            ROUND(COALESCE(v_legacy_entry.associate_biweekly_payment, 0), 2),
            ROUND(COALESCE(v_legacy_entry.associate_total_payment, 0), 2);
        
        RETURN;
    END IF;
    
    -- MÉTODO 2: Formula (perfiles standard, custom)
    IF v_profile.calculation_type = 'formula' THEN
        IF v_profile.interest_rate_percent IS NULL THEN
            RAISE EXCEPTION 'Perfil % tipo formula requiere interest_rate_percent configurado', p_profile_code;
        END IF;
        
        IF v_profile.commission_rate_percent IS NULL THEN
            RAISE EXCEPTION 'Perfil % tipo formula requiere commission_rate_percent configurado', p_profile_code;
        END IF;
        
        -- Calcular pago del CLIENTE (interés simple)
        v_factor := 1 + (v_profile.interest_rate_percent / 100) * p_term_biweeks;
        v_total := p_amount * v_factor;
        v_payment := v_total / p_term_biweeks;
        
        -- ⭐ CAMBIO CRÍTICO: Comisión sobre el MONTO, no sobre el pago
        v_commission_per_payment := p_amount * (v_profile.commission_rate_percent / 100);
        
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


--
-- Name: calculate_loan_payment_custom(numeric, integer, numeric, numeric); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.calculate_loan_payment_custom(p_amount numeric, p_term_biweeks integer, p_interest_rate numeric, p_commission_rate numeric) RETURNS TABLE(profile_code character varying, profile_name character varying, calculation_method character varying, interest_rate_percent numeric, commission_rate_percent numeric, biweekly_payment numeric, total_payment numeric, total_interest numeric, effective_rate_percent numeric, commission_per_payment numeric, total_commission numeric, associate_payment numeric, associate_total numeric)
    LANGUAGE plpgsql IMMUTABLE
    AS $$
DECLARE
    v_factor DECIMAL(10,6);
    v_total DECIMAL(12,2);
    v_payment DECIMAL(10,2);
    v_commission_per_payment DECIMAL(10,2);
BEGIN
    -- Calcular pago del CLIENTE (interés simple)
    v_factor := 1 + (p_interest_rate / 100) * p_term_biweeks;
    v_total := p_amount * v_factor;
    v_payment := v_total / p_term_biweeks;
    
    -- ⭐ CAMBIO CRÍTICO: Comisión sobre el MONTO, no sobre el pago
    v_commission_per_payment := p_amount * (p_commission_rate / 100);
    
    RETURN QUERY SELECT
        'custom'::VARCHAR(50),
        'Personalizado'::VARCHAR(100),
        'formula'::VARCHAR(20),
        p_interest_rate,
        p_commission_rate,
        ROUND(v_payment, 2) AS biweekly_payment,
        ROUND(v_total, 2) AS total_payment,
        ROUND(v_total - p_amount, 2) AS total_interest,
        ROUND(((v_total - p_amount) / p_amount * 100)::NUMERIC, 2) AS effective_rate,
        ROUND(v_commission_per_payment, 2),
        ROUND(v_commission_per_payment * p_term_biweeks, 2),
        ROUND(v_payment - v_commission_per_payment, 2),
        ROUND((v_payment - v_commission_per_payment) * p_term_biweeks, 2);
END;
$$;


--
-- Name: calculate_loan_remaining_balance(integer); Type: FUNCTION; Schema: public; Owner: -
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


--
-- Name: calculate_payment_preview(timestamp with time zone, integer, numeric); Type: FUNCTION; Schema: public; Owner: -
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


--
-- Name: check_associate_credit_available(integer, numeric); Type: FUNCTION; Schema: public; Owner: -
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


--
-- Name: close_period_and_accumulate_debt(integer, integer); Type: FUNCTION; Schema: public; Owner: -
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


--
-- Name: detect_suspicious_payment_changes(integer, integer); Type: FUNCTION; Schema: public; Owner: -
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


--
-- Name: finalize_statements_manual(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.finalize_statements_manual(p_cut_period_id integer) RETURNS TABLE(finalized_count integer, total_finalized numeric, period_code character varying)
    LANGUAGE plpgsql
    AS $_$
DECLARE
    v_draft_count INTEGER;
    v_updated_count INTEGER;
    v_total NUMERIC(12,2);
    v_period_code VARCHAR(20);
BEGIN
    -- Obtener información del periodo
    SELECT cut_code INTO v_period_code
    FROM cut_periods
    WHERE id = p_cut_period_id;
    
    IF v_period_code IS NULL THEN
        RAISE EXCEPTION 'Periodo con ID % no encontrado', p_cut_period_id;
    END IF;
    
    -- Verificar que existan statements en DRAFT
    SELECT COUNT(*) INTO v_draft_count
    FROM associate_payment_statements
    WHERE cut_period_id = p_cut_period_id
      AND status_id = 6;  -- DRAFT
    
    IF v_draft_count = 0 THEN
        RAISE EXCEPTION 'No hay statements en DRAFT para finalizar en periodo %', v_period_code;
    END IF;
    
    RAISE NOTICE '🔒 Finalizando % statements en periodo %', v_draft_count, v_period_code;
    
    -- Cambiar estado de DRAFT (6) → FINALIZED (7)
    UPDATE associate_payment_statements
    SET 
        status_id = 7,  -- FINALIZED
        updated_at = CURRENT_TIMESTAMP
    WHERE cut_period_id = p_cut_period_id
      AND status_id = 6;
    
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    
    -- Calcular total finalizado
    SELECT COALESCE(SUM(total_amount_collected), 0) INTO v_total
    FROM associate_payment_statements
    WHERE cut_period_id = p_cut_period_id AND status_id = 7;
    
    RAISE NOTICE '✅ Corte manual completado: % statements FINALIZADOS (bloqueados), Total: $%',
        v_updated_count, v_total;
    
    RAISE NOTICE '📧 TODO: Enviar notificaciones a asociados';
    
    -- Retornar resumen
    RETURN QUERY SELECT v_updated_count, v_total, v_period_code;
END;
$_$;


--
-- Name: generate_amortization_schedule(numeric, numeric, integer, numeric, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_amortization_schedule(p_amount numeric, p_biweekly_payment numeric, p_term_biweeks integer, p_commission_rate numeric, p_start_date date) RETURNS TABLE(periodo integer, fecha_pago date, pago_cliente numeric, interes_cliente numeric, capital_cliente numeric, saldo_pendiente numeric, comision_socio numeric, pago_socio numeric, saldo_asociado numeric)
    LANGUAGE plpgsql STABLE
    AS $$
DECLARE
    v_current_date DATE;
    v_balance DECIMAL(12,2);
    v_associate_balance DECIMAL(12,2); -- ✅ NUEVO
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
    
    -- Calcular comisión y pago al asociado (fijos por periodo)
    v_commission := p_amount * (p_commission_rate / 100);
    v_payment_to_associate := p_biweekly_payment - v_commission;
    
    -- Inicializar saldo asociado (Total a pagar por asociado)
    v_associate_balance := v_payment_to_associate * p_term_biweeks;

    -- Generar cronograma completo
    FOR v_period IN 1..p_term_biweeks LOOP
        -- Calcular interés y capital del período (distribución proporcional)
        v_period_interest := v_total_interest / p_term_biweeks;
        v_period_principal := p_biweekly_payment - v_period_interest;

        -- Actualizar saldo cliente
        v_balance := v_balance - v_period_principal;
        IF v_balance < 0.01 THEN v_balance := 0; END IF;
        
        -- Actualizar saldo asociado
        v_associate_balance := v_associate_balance - v_payment_to_associate;
        IF v_associate_balance < 0.01 THEN v_associate_balance := 0; END IF;

        -- Retornar fila
        RETURN QUERY SELECT
            v_period,
            v_current_date,
            p_biweekly_payment,
            ROUND(v_period_interest, 2),
            ROUND(v_period_principal, 2),
            ROUND(v_balance, 2),
            ROUND(v_commission, 2),
            ROUND(v_payment_to_associate, 2),
            ROUND(v_associate_balance, 2); -- ✅ RETORNAR NUEVO SALDO

        -- Calcular siguiente fecha
        v_is_day_15 := EXTRACT(DAY FROM v_current_date) = 15;

        IF v_is_day_15 THEN
            v_current_date := (DATE_TRUNC('month', v_current_date) + INTERVAL '1 month' - INTERVAL '1 day')::DATE;
        ELSE
            v_current_date := MAKE_DATE(
                EXTRACT(YEAR FROM v_current_date + INTERVAL '1 month')::INTEGER,
                EXTRACT(MONTH FROM v_current_date + INTERVAL '1 month')::INTEGER,
                15
            );
        END IF;
    END LOOP;
END;
$$;


--
-- Name: generate_loan_summary(numeric, integer, numeric, numeric); Type: FUNCTION; Schema: public; Owner: -
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


--
-- Name: generate_payment_schedule(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_payment_schedule() RETURNS trigger
    LANGUAGE plpgsql
    AS $_$
DECLARE
    v_approval_date DATE;
    v_first_payment_date DATE;
    v_approved_status_id INTEGER;
    v_pending_status_id INTEGER;
    v_amortization_row RECORD;
    v_period_id INTEGER;
    v_total_inserted INTEGER := 0;
    v_sum_expected DECIMAL(12,2) := 0;
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
    v_total_associate_payment DECIMAL(12,2);
    v_cumulative_associate_paid DECIMAL(12,2) := 0;
    v_commission_rate_for_function DECIMAL(10,4);
    v_payment_day INTEGER;
    v_target_cut_day INTEGER;
    v_month_name VARCHAR(3);
    v_year_str VARCHAR(4);
    v_target_cut_code VARCHAR(20);
BEGIN
    -- Get status IDs
    SELECT id INTO v_approved_status_id FROM loan_statuses WHERE name = 'APPROVED';
    SELECT id INTO v_pending_status_id FROM payment_statuses WHERE name = 'PENDING';

    IF v_approved_status_id IS NULL THEN
        RAISE EXCEPTION 'CRITICAL: loan_statuses.APPROVED not found';
    END IF;

    IF v_pending_status_id IS NULL THEN
        RAISE EXCEPTION 'CRITICAL: payment_statuses.PENDING not found';
    END IF;

    -- Only execute if loan just got approved
    IF NEW.status_id = v_approved_status_id
       AND (OLD.status_id IS NULL OR OLD.status_id != v_approved_status_id)
    THEN
        v_start_time := CLOCK_TIMESTAMP();

        -- Validations
        IF NEW.approved_at IS NULL THEN
            RAISE EXCEPTION 'CRITICAL: Loan % marked as APPROVED but approved_at is NULL', NEW.id;
        END IF;

        IF NEW.term_biweeks IS NULL OR NEW.term_biweeks <= 0 THEN
            RAISE EXCEPTION 'CRITICAL: Loan % has invalid term_biweeks: %', NEW.id, NEW.term_biweeks;
        END IF;

        IF NEW.biweekly_payment IS NULL THEN
            RAISE EXCEPTION 'CRITICAL: Loan % does not have biweekly_payment calculated', NEW.id;
        END IF;

        v_approval_date := NEW.approved_at::DATE;
        v_first_payment_date := calculate_first_payment_date(v_approval_date);

        -- FIX: Calculate correct commission rate for the function
        IF COALESCE(NEW.commission_per_payment, 0) > 0 AND NEW.amount > 0 THEN
            v_commission_rate_for_function := (NEW.commission_per_payment / NEW.amount) * 100;
        ELSE
            v_commission_rate_for_function := 0;
        END IF;

        RAISE NOTICE 'Generating schedule for loan %: Amount=$%, Term=%, Biweekly=$%, CommPerPmt=$%, Profile=%',
            NEW.id, NEW.amount, NEW.term_biweeks, NEW.biweekly_payment,
            COALESCE(NEW.commission_per_payment, 0), COALESCE(NEW.profile_code, 'N/A');

        -- Calculate total associate payment for this loan
        SELECT SUM(pago_socio) INTO v_total_associate_payment
        FROM generate_amortization_schedule(
            NEW.amount,
            NEW.biweekly_payment,
            NEW.term_biweeks,
            v_commission_rate_for_function,
            v_first_payment_date
        );

        -- Generate complete schedule with breakdown
        FOR v_amortization_row IN
            SELECT
                periodo,
                fecha_pago,
                pago_cliente,
                interes_cliente,
                capital_cliente,
                saldo_pendiente,
                comision_socio,
                pago_socio
            FROM generate_amortization_schedule(
                NEW.amount,
                NEW.biweekly_payment,
                NEW.term_biweeks,
                v_commission_rate_for_function,
                v_first_payment_date
            )
        LOOP
            -- NUEVA LÓGICA: Asignar período basado en día de vencimiento
            v_payment_day := EXTRACT(DAY FROM v_amortization_row.fecha_pago);
            
            IF v_payment_day = 15 THEN
                v_target_cut_day := 8;
            ELSE
                v_target_cut_day := 23;
            END IF;
            
            -- Construir el cut_code esperado: MonDD-YYYY
            v_month_name := TO_CHAR(v_amortization_row.fecha_pago, 'Mon');
            v_year_str := TO_CHAR(v_amortization_row.fecha_pago, 'YYYY');
            v_target_cut_code := v_month_name || LPAD(v_target_cut_day::text, 2, '0') || '-' || v_year_str;
            
            -- Buscar el período de corte por cut_code
            SELECT id INTO v_period_id
            FROM cut_periods
            WHERE cut_code = v_target_cut_code
            LIMIT 1;

            IF v_period_id IS NULL THEN
                RAISE WARNING 'No cut_period found with code %. Inserting with period_id = NULL',
                    v_target_cut_code;
            ELSE
                RAISE NOTICE 'Payment due % -> assigned to period % (%)',
                    v_amortization_row.fecha_pago, v_target_cut_code, v_period_id;
            END IF;

            -- Calculate cumulative associate paid
            v_cumulative_associate_paid := v_cumulative_associate_paid + v_amortization_row.pago_socio;

            -- Insert payment
            INSERT INTO payments (
                loan_id, payment_number, expected_amount, amount_paid,
                interest_amount, principal_amount, commission_amount, associate_payment,
                balance_remaining, associate_balance_remaining,
                payment_date, payment_due_date, is_late, status_id, cut_period_id,
                created_at, updated_at
            ) VALUES (
                NEW.id, v_amortization_row.periodo, v_amortization_row.pago_cliente, 0.00,
                v_amortization_row.interes_cliente, v_amortization_row.capital_cliente,
                v_amortization_row.comision_socio, v_amortization_row.pago_socio,
                v_amortization_row.saldo_pendiente, v_total_associate_payment - v_cumulative_associate_paid,
                v_amortization_row.fecha_pago, v_amortization_row.fecha_pago, false,
                v_pending_status_id, v_period_id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
            );

            v_total_inserted := v_total_inserted + 1;
            v_sum_expected := v_sum_expected + v_amortization_row.pago_cliente;
        END LOOP;

        v_end_time := CLOCK_TIMESTAMP();

        IF v_total_inserted != NEW.term_biweeks THEN
            RAISE EXCEPTION 'INCONSISTENCY: Inserted % payments but expected %',
                v_total_inserted, NEW.term_biweeks;
        END IF;

        RAISE NOTICE 'Schedule generated: % payments, Total expected: $%, Time: % ms',
            v_total_inserted, v_sum_expected,
            EXTRACT(MILLISECONDS FROM (v_end_time - v_start_time));

    END IF;

    RETURN NEW;

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'CRITICAL ERROR generating payment schedule for loan %: % (%). SQLState: %',
            NEW.id, SQLERRM, SQLSTATE, SQLSTATE;
        RETURN NULL;
END;
$_$;


--
-- Name: get_cut_period_for_payment(date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_cut_period_for_payment(p_payment_date date) RETURNS integer
    LANGUAGE plpgsql IMMUTABLE STRICT
    AS $$
DECLARE
    v_period_id INTEGER;
    v_day INTEGER;
    v_month INTEGER;
    v_year INTEGER;
BEGIN
    v_day := EXTRACT(DAY FROM p_payment_date)::INTEGER;
    v_month := EXTRACT(MONTH FROM p_payment_date)::INTEGER;
    v_year := EXTRACT(YEAR FROM p_payment_date)::INTEGER;
    
    -- Determinar si es día 15 o último día del mes
    IF v_day = 15 THEN
        -- Pago día 15 → Buscar periodo que cierra día 7-8 (aproximado) ANTES del día 15
        SELECT id INTO v_period_id
        FROM cut_periods
        WHERE EXTRACT(DAY FROM period_end_date) BETWEEN 6 AND 8  -- Cierra ~día 7
          AND period_end_date < p_payment_date  -- Cierra ANTES del vencimiento
          AND EXTRACT(MONTH FROM period_end_date) = v_month  -- Mismo mes
          AND EXTRACT(YEAR FROM period_end_date) = v_year
        ORDER BY period_end_date DESC
        LIMIT 1;
        
        -- Si no encontró en el mismo mes, buscar a fin del mes anterior
        IF v_period_id IS NULL THEN
            SELECT id INTO v_period_id
            FROM cut_periods
            WHERE EXTRACT(DAY FROM period_end_date) BETWEEN 6 AND 8
              AND period_end_date < p_payment_date
              AND (
                  (EXTRACT(MONTH FROM period_end_date) = v_month - 1 AND EXTRACT(YEAR FROM period_end_date) = v_year) OR
                  (v_month = 1 AND EXTRACT(MONTH FROM period_end_date) = 12 AND EXTRACT(YEAR FROM period_end_date) = v_year - 1)
              )
            ORDER BY period_end_date DESC
            LIMIT 1;
        END IF;
        
    ELSE
        -- Pago último día → Buscar periodo que cierra día 22-23 ANTES del último día
        SELECT id INTO v_period_id
        FROM cut_periods
        WHERE EXTRACT(DAY FROM period_end_date) BETWEEN 21 AND 23  -- Cierra ~día 22
          AND period_end_date < p_payment_date  -- Cierra ANTES del vencimiento
          AND EXTRACT(MONTH FROM period_end_date) = v_month  -- Mismo mes
          AND EXTRACT(YEAR FROM period_end_date) = v_year
        ORDER BY period_end_date DESC
        LIMIT 1;
    END IF;
    
    -- Si aún no encontró, usar lógica de fallback (contención)
    IF v_period_id IS NULL THEN
        RAISE WARNING 'No se encontró periodo con cierre antes de %. Usando fallback.', p_payment_date;
        SELECT id INTO v_period_id
        FROM cut_periods
        WHERE period_start_date <= p_payment_date
          AND period_end_date >= p_payment_date
        ORDER BY period_start_date DESC
        LIMIT 1;
    END IF;
    
    RETURN v_period_id;
END;
$$;


--
-- Name: get_debt_payment_detail(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_debt_payment_detail(p_debt_payment_id integer) RETURNS TABLE(breakdown_id integer, cut_period_id integer, period_description character varying, original_amount numeric, amount_applied numeric, liquidated boolean, remaining_amount numeric)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        (item->>'breakdown_id')::INTEGER AS breakdown_id,
        (item->>'cut_period_id')::INTEGER AS cut_period_id,
        COALESCE(
            cp.description,
            'Período ' || TO_CHAR(cp.start_date, 'DD/MM/YYYY') || ' - ' || TO_CHAR(cp.end_date, 'DD/MM/YYYY')
        ) AS period_description,
        (item->>'original_amount')::DECIMAL(12,2) AS original_amount,
        (item->>'amount_applied')::DECIMAL(12,2) AS amount_applied,
        (item->>'liquidated')::BOOLEAN AS liquidated,
        COALESCE((item->>'remaining_amount')::DECIMAL(12,2), 0) AS remaining_amount
    FROM associate_debt_payments adp
    CROSS JOIN jsonb_array_elements(adp.applied_breakdown_items) AS item
    LEFT JOIN cut_periods cp ON cp.id = (item->>'cut_period_id')::INTEGER
    WHERE adp.id = p_debt_payment_id;
END;
$$;


--
-- Name: get_payment_history(integer); Type: FUNCTION; Schema: public; Owner: -
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


--
-- Name: handle_loan_approval_status(); Type: FUNCTION; Schema: public; Owner: -
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


--
-- Name: log_payment_status_change(); Type: FUNCTION; Schema: public; Owner: -
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


--
-- Name: renew_loan(integer, numeric, integer, numeric, numeric, integer); Type: FUNCTION; Schema: public; Owner: -
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


--
-- Name: report_defaulted_client(integer, integer, integer, numeric, text, character varying); Type: FUNCTION; Schema: public; Owner: -
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


--
-- Name: revert_last_payment_change(integer, integer, text); Type: FUNCTION; Schema: public; Owner: -
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


--
-- Name: simulate_loan(numeric, integer, character varying, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.simulate_loan(p_amount numeric, p_term_biweeks integer, p_profile_code character varying, p_approval_date date DEFAULT CURRENT_DATE) RETURNS TABLE(payment_number integer, payment_date date, cut_period_code character varying, client_payment numeric, associate_payment numeric, commission_amount numeric, remaining_balance numeric, associate_remaining_balance numeric)
    LANGUAGE plpgsql STABLE
    AS $$
DECLARE
    v_calc RECORD;
    v_current_date DATE;
    v_balance DECIMAL(12,2);
    v_associate_balance DECIMAL(12,2); -- ✅ NUEVO
    v_cut_code VARCHAR(20);
    v_period_capital DECIMAL(12,2);
    v_period_id INTEGER;
    i INTEGER;
BEGIN
    -- Obtener cálculos del perfil
    SELECT * INTO v_calc
    FROM calculate_loan_payment(p_amount, p_term_biweeks, p_profile_code);

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Perfil % no encontrado', p_profile_code;
    END IF;

    v_current_date := calculate_first_payment_date(p_approval_date);
    v_balance := p_amount;
    
    -- Inicializar saldo asociado
    v_associate_balance := v_calc.associate_payment * p_term_biweeks;

    v_period_capital := p_amount / p_term_biweeks;

    FOR i IN 1..p_term_biweeks LOOP
        v_period_id := get_cut_period_for_payment(v_current_date);

        IF v_period_id IS NOT NULL THEN
            SELECT cut_code INTO v_cut_code FROM cut_periods WHERE id = v_period_id;
        ELSE
            v_cut_code := EXTRACT(YEAR FROM v_current_date)::TEXT || '-Q' || LPAD(CEIL(EXTRACT(DOY FROM v_current_date) / 15)::TEXT, 2, '0');
        END IF;

        v_balance := v_balance - v_period_capital;
        IF v_balance < 0.01 THEN v_balance := 0; END IF;
        
        -- Actualizar saldo asociado
        v_associate_balance := v_associate_balance - v_calc.associate_payment;
        IF v_associate_balance < 0.01 THEN v_associate_balance := 0; END IF;

        RETURN QUERY SELECT
            i::INTEGER,
            v_current_date::DATE,
            v_cut_code::VARCHAR(20),
            v_calc.biweekly_payment::DECIMAL(10,2),
            v_calc.associate_payment::DECIMAL(10,2),
            v_calc.commission_per_payment::DECIMAL(10,2),
            v_balance::DECIMAL(12,2),
            v_associate_balance::DECIMAL(12,2); -- ✅ RETORNAR

        IF EXTRACT(DAY FROM v_current_date) = 15 THEN
            v_current_date := (DATE_TRUNC('month', v_current_date) + INTERVAL '1 month' - INTERVAL '1 day')::DATE;
        ELSE
            v_current_date := MAKE_DATE(
                EXTRACT(YEAR FROM v_current_date + INTERVAL '1 month')::INTEGER,
                EXTRACT(MONTH FROM v_current_date + INTERVAL '1 month')::INTEGER,
                15
            );
        END IF;
    END LOOP;
END;
$$;


--
-- Name: simulate_loan_complete(numeric, integer, character varying, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.simulate_loan_complete(p_amount numeric, p_term_biweeks integer, p_profile_code character varying, p_approval_date date DEFAULT CURRENT_DATE) RETURNS TABLE(section_type character varying, label character varying, value_text character varying, value_numeric numeric, payment_num integer, payment_date date, cut_code character varying, client_pay numeric, associate_pay numeric, commission numeric, balance numeric)
    LANGUAGE plpgsql STABLE
    AS $_$
DECLARE
    v_calc RECORD;
    v_profile RECORD;
BEGIN
    -- Obtener información del perfil y cálculos
    SELECT 
        rp.name as profile_name,
        c.*
    INTO v_calc
    FROM calculate_loan_payment(p_amount, p_term_biweeks, p_profile_code) c
    JOIN rate_profiles rp ON rp.code = p_profile_code;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Perfil % no encontrado o deshabilitado', p_profile_code;
    END IF;
    
    -- =========================================================================
    -- SECCIÓN 1: RESUMEN DEL PRÉSTAMO
    -- =========================================================================
    RETURN QUERY SELECT
        'RESUMEN'::VARCHAR(20),
        'Perfil'::VARCHAR(100),
        v_calc.profile_name::VARCHAR(100),
        NULL::DECIMAL(12,2),
        NULL::INTEGER, NULL::DATE, NULL::VARCHAR(20),
        NULL::DECIMAL(10,2), NULL::DECIMAL(10,2), NULL::DECIMAL(10,2), NULL::DECIMAL(12,2);
    
    RETURN QUERY SELECT
        'RESUMEN'::VARCHAR(20), 'Monto Solicitado'::VARCHAR(100),
        ('$' || p_amount::TEXT)::VARCHAR(100), p_amount,
        NULL::INTEGER, NULL::DATE, NULL::VARCHAR(20),
        NULL::DECIMAL(10,2), NULL::DECIMAL(10,2), NULL::DECIMAL(10,2), NULL::DECIMAL(12,2);
    
    RETURN QUERY SELECT
        'RESUMEN'::VARCHAR(20), 'Plazo'::VARCHAR(100),
        (p_term_biweeks || ' quincenas')::VARCHAR(100), p_term_biweeks::DECIMAL(12,2),
        NULL::INTEGER, NULL::DATE, NULL::VARCHAR(20),
        NULL::DECIMAL(10,2), NULL::DECIMAL(10,2), NULL::DECIMAL(10,2), NULL::DECIMAL(12,2);
    
    RETURN QUERY SELECT
        'RESUMEN'::VARCHAR(20), 'Tasa de Interés'::VARCHAR(100),
        (v_calc.interest_rate_percent || '%')::VARCHAR(100), v_calc.interest_rate_percent,
        NULL::INTEGER, NULL::DATE, NULL::VARCHAR(20),
        NULL::DECIMAL(10,2), NULL::DECIMAL(10,2), NULL::DECIMAL(10,2), NULL::DECIMAL(12,2);
    
    RETURN QUERY SELECT
        'RESUMEN'::VARCHAR(20), 'Tasa de Comisión'::VARCHAR(100),
        (v_calc.commission_rate_percent || '%')::VARCHAR(100), v_calc.commission_rate_percent,
        NULL::INTEGER, NULL::DATE, NULL::VARCHAR(20),
        NULL::DECIMAL(10,2), NULL::DECIMAL(10,2), NULL::DECIMAL(10,2), NULL::DECIMAL(12,2);
    
    RETURN QUERY SELECT
        'RESUMEN'::VARCHAR(20), 'Fecha de Aprobación'::VARCHAR(100),
        TO_CHAR(p_approval_date, 'DD/MM/YYYY')::VARCHAR(100), NULL::DECIMAL(12,2),
        NULL::INTEGER, NULL::DATE, NULL::VARCHAR(20),
        NULL::DECIMAL(10,2), NULL::DECIMAL(10,2), NULL::DECIMAL(10,2), NULL::DECIMAL(12,2);
    
    -- Totales
    RETURN QUERY SELECT
        'TOTALES'::VARCHAR(20), 'Pago Quincenal Cliente'::VARCHAR(100),
        ('$' || v_calc.biweekly_payment::TEXT)::VARCHAR(100), v_calc.biweekly_payment,
        NULL::INTEGER, NULL::DATE, NULL::VARCHAR(20),
        NULL::DECIMAL(10,2), NULL::DECIMAL(10,2), NULL::DECIMAL(10,2), NULL::DECIMAL(12,2);
    
    RETURN QUERY SELECT
        'TOTALES'::VARCHAR(20), 'Total a Pagar (Cliente)'::VARCHAR(100),
        ('$' || v_calc.total_payment::TEXT)::VARCHAR(100), v_calc.total_payment,
        NULL::INTEGER, NULL::DATE, NULL::VARCHAR(20),
        NULL::DECIMAL(10,2), NULL::DECIMAL(10,2), NULL::DECIMAL(10,2), NULL::DECIMAL(12,2);
    
    RETURN QUERY SELECT
        'TOTALES'::VARCHAR(20), 'Pago Quincenal Asociado'::VARCHAR(100),
        ('$' || v_calc.associate_payment::TEXT)::VARCHAR(100), v_calc.associate_payment,
        NULL::INTEGER, NULL::DATE, NULL::VARCHAR(20),
        NULL::DECIMAL(10,2), NULL::DECIMAL(10,2), NULL::DECIMAL(10,2), NULL::DECIMAL(12,2);
    
    RETURN QUERY SELECT
        'TOTALES'::VARCHAR(20), 'Total Asociado → CrediCuenta'::VARCHAR(100),
        ('$' || v_calc.associate_total::TEXT)::VARCHAR(100), v_calc.associate_total,
        NULL::INTEGER, NULL::DATE, NULL::VARCHAR(20),
        NULL::DECIMAL(10,2), NULL::DECIMAL(10,2), NULL::DECIMAL(10,2), NULL::DECIMAL(12,2);
    
    RETURN QUERY SELECT
        'TOTALES'::VARCHAR(20), 'Comisión por Pago'::VARCHAR(100),
        ('$' || v_calc.commission_per_payment::TEXT)::VARCHAR(100), v_calc.commission_per_payment,
        NULL::INTEGER, NULL::DATE, NULL::VARCHAR(20),
        NULL::DECIMAL(10,2), NULL::DECIMAL(10,2), NULL::DECIMAL(10,2), NULL::DECIMAL(12,2);
    
    RETURN QUERY SELECT
        'TOTALES'::VARCHAR(20), 'Comisión Total Asociado'::VARCHAR(100),
        ('$' || v_calc.total_commission::TEXT)::VARCHAR(100), v_calc.total_commission,
        NULL::INTEGER, NULL::DATE, NULL::VARCHAR(20),
        NULL::DECIMAL(10,2), NULL::DECIMAL(10,2), NULL::DECIMAL(10,2), NULL::DECIMAL(12,2);
    
    -- =========================================================================
    -- SECCIÓN 2: TABLA DE AMORTIZACIÓN
    -- =========================================================================
    RETURN QUERY 
    SELECT 
        'AMORTIZACIÓN'::VARCHAR(20),
        NULL::VARCHAR(100),
        NULL::VARCHAR(100),
        NULL::DECIMAL(12,2),
        s.payment_number,
        s.payment_date,
        s.cut_period_code,
        s.client_payment,
        s.associate_payment,
        s.commission_amount,
        s.remaining_balance
    FROM simulate_loan(p_amount, p_term_biweeks, p_profile_code, p_approval_date) s;
END;
$_$;


--
-- Name: simulate_loan_custom(numeric, integer, numeric, numeric, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.simulate_loan_custom(p_amount numeric, p_term_biweeks integer, p_interest_rate numeric, p_commission_rate numeric, p_approval_date date DEFAULT CURRENT_DATE) RETURNS TABLE(payment_number integer, payment_date date, cut_period_code character varying, client_payment numeric, associate_payment numeric, commission_amount numeric, remaining_balance numeric)
    LANGUAGE plpgsql STABLE
    AS $$
DECLARE
    v_calc RECORD;
    v_current_date DATE;
    v_balance DECIMAL(12,2);
    v_cut_code VARCHAR(20);
    v_period_capital DECIMAL(12,2);
    i INTEGER;
BEGIN
    -- Obtener cálculos con tasas custom
    SELECT * INTO v_calc
    FROM calculate_loan_payment_custom(p_amount, p_term_biweeks, p_interest_rate, p_commission_rate);
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Error al calcular préstamo custom';
    END IF;
    
    -- Calcular primera fecha de pago usando el oráculo
    v_current_date := calculate_first_payment_date(p_approval_date);
    v_balance := p_amount;
    
    -- Calcular abono a capital por periodo (interés distribuido uniformemente)
    v_period_capital := p_amount / p_term_biweeks;
    
    -- Generar tabla de amortización
    FOR i IN 1..p_term_biweeks LOOP
        -- ⭐ CORRECCIÓN CRÍTICA: Buscar período de corte REAL donde cae el pago
        -- Un pago pertenece al período donde payment_date está entre start y end
        SELECT cp.cut_code INTO v_cut_code
        FROM cut_periods cp
        WHERE v_current_date >= cp.period_start_date 
          AND v_current_date <= cp.period_end_date
        LIMIT 1;
        
        -- Si no encuentra período (ej: simulación muy futura), usar código genérico
        IF v_cut_code IS NULL THEN
            -- Formato: YYYY-QXX (año-número quincenal)
            v_cut_code := EXTRACT(YEAR FROM v_current_date)::TEXT || '-Q' || 
                LPAD(CEIL(EXTRACT(DOY FROM v_current_date) / 15)::TEXT, 2, '0');
        END IF;
        
        -- Calcular saldo restante (disminuye por el abono a capital)
        v_balance := v_balance - v_period_capital;
        IF v_balance < 0.01 THEN
            v_balance := 0;
        END IF;
        
        RETURN QUERY SELECT
            i,
            v_current_date,
            v_cut_code,
            v_calc.biweekly_payment,
            v_calc.associate_payment,
            v_calc.commission_per_payment,
            v_balance;
        
        -- ⭐ LÓGICA DEL CALENDARIO: Alternar entre día 15 y último día del mes
        IF EXTRACT(DAY FROM v_current_date) = 15 THEN
            -- Si estamos en día 15, siguiente pago es el último día del mes ACTUAL
            v_current_date := (DATE_TRUNC('month', v_current_date) + INTERVAL '1 month' - INTERVAL '1 day')::DATE;
        ELSE
            -- Si estamos en último día, siguiente pago es el 15 del mes SIGUIENTE
            v_current_date := MAKE_DATE(
                EXTRACT(YEAR FROM v_current_date + INTERVAL '1 month')::INTEGER,
                EXTRACT(MONTH FROM v_current_date + INTERVAL '1 month')::INTEGER,
                15
            );
        END IF;
    END LOOP;
    
    RETURN;
END;
$$;


--
-- Name: sync_associate_debt_balance(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sync_associate_debt_balance(p_associate_profile_id integer) RETURNS numeric
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_user_id INTEGER;
    v_total_debt DECIMAL(12,2);
BEGIN
    -- Obtener user_id del perfil
    SELECT user_id INTO v_user_id
    FROM associate_profiles WHERE id = p_associate_profile_id;
    
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Associate profile % not found', p_associate_profile_id;
    END IF;
    
    -- Calcular deuda total desde accumulated_balances
    SELECT COALESCE(SUM(accumulated_debt), 0)
    INTO v_total_debt
    FROM associate_accumulated_balances
    WHERE user_id = v_user_id;
    
    -- Actualizar debt_balance en associate_profiles
    UPDATE associate_profiles
    SET 
        debt_balance = v_total_debt,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = p_associate_profile_id;
    
    RETURN v_total_debt;
END;
$$;


--
-- Name: trigger_update_associate_credit_on_level_change(); Type: FUNCTION; Schema: public; Owner: -
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


--
-- Name: trigger_update_associate_credit_on_loan_approval(); Type: FUNCTION; Schema: public; Owner: -
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


--
-- Name: trigger_update_associate_credit_on_payment(); Type: FUNCTION; Schema: public; Owner: -
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


--
-- Name: update_legacy_payment_table_timestamp(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_legacy_payment_table_timestamp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;


--
-- Name: update_statement_on_payment(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_statement_on_payment() RETURNS trigger
    LANGUAGE plpgsql
    AS $_$
DECLARE
    v_total_paid DECIMAL(12,2);
    v_total_owed DECIMAL(12,2);
    v_remaining DECIMAL(12,2);
    v_new_status_id INTEGER;
    v_associate_profile_id INTEGER;
BEGIN
    -- Calcular total pagado (suma de todos los abonos)
    SELECT COALESCE(SUM(payment_amount), 0)
    INTO v_total_paid
    FROM associate_statement_payments
    WHERE statement_id = NEW.statement_id;

    -- Obtener total adeudado a CrediCuenta (nuevo campo con nombre correcto)
    SELECT
        aps.total_to_credicuenta + aps.late_fee_amount,
        ap.id
    INTO v_total_owed, v_associate_profile_id
    FROM associate_payment_statements aps
    JOIN associate_profiles ap ON aps.user_id = ap.user_id
    WHERE aps.id = NEW.statement_id;

    IF v_total_owed IS NULL THEN
        RAISE EXCEPTION 'Statement % no encontrado', NEW.statement_id;
    END IF;

    v_remaining := v_total_owed - v_total_paid;

    -- Determinar nuevo estado
    IF v_remaining <= 0 THEN
        SELECT id INTO v_new_status_id FROM statement_statuses WHERE name = 'PAID';
    ELSIF v_total_paid > 0 THEN
        SELECT id INTO v_new_status_id FROM statement_statuses WHERE name = 'PARTIAL_PAID';
    END IF;

    -- Actualizar statement
    UPDATE associate_payment_statements
    SET paid_amount = v_total_paid,
        paid_date = CASE WHEN v_remaining <= 0 THEN CURRENT_DATE ELSE paid_date END,
        status_id = COALESCE(v_new_status_id, status_id),
        updated_at = CURRENT_TIMESTAMP
    WHERE id = NEW.statement_id;

    -- Liberar crédito del asociado
    UPDATE associate_profiles
    SET debt_balance = GREATEST(debt_balance - NEW.payment_amount, 0),
        credit_last_updated = CURRENT_TIMESTAMP
    WHERE id = v_associate_profile_id;

    RAISE NOTICE '💰 Statement #% | Pagado: $% | Debe: $% | Restante: $%',
        NEW.statement_id, v_total_paid, v_total_owed, v_remaining;

    RETURN NEW;
END;
$_$;


--
-- Name: update_updated_at_column(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_updated_at_column() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;


--
-- Name: validate_loan_calculated_fields(integer); Type: FUNCTION; Schema: public; Owner: -
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


--
-- Name: validate_loan_payment_schedule(integer); Type: FUNCTION; Schema: public; Owner: -
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


--
-- Name: validate_payment_breakdown(integer); Type: FUNCTION; Schema: public; Owner: -
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


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: addresses; Type: TABLE; Schema: public; Owner: -
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


--
-- Name: addresses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.addresses_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: addresses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.addresses_id_seq OWNED BY public.addresses.id;


--
-- Name: agreement_items; Type: TABLE; Schema: public; Owner: -
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


--
-- Name: agreement_items_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.agreement_items_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: agreement_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.agreement_items_id_seq OWNED BY public.agreement_items.id;


--
-- Name: agreement_payments; Type: TABLE; Schema: public; Owner: -
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


--
-- Name: agreement_payments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.agreement_payments_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: agreement_payments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.agreement_payments_id_seq OWNED BY public.agreement_payments.id;


--
-- Name: agreements; Type: TABLE; Schema: public; Owner: -
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


--
-- Name: agreements_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.agreements_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: agreements_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.agreements_id_seq OWNED BY public.agreements.id;


--
-- Name: associate_accumulated_balances; Type: TABLE; Schema: public; Owner: -
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


--
-- Name: associate_accumulated_balances_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.associate_accumulated_balances_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: associate_accumulated_balances_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.associate_accumulated_balances_id_seq OWNED BY public.associate_accumulated_balances.id;


--
-- Name: associate_debt_payments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.associate_debt_payments (
    id integer NOT NULL,
    associate_profile_id integer NOT NULL,
    payment_amount numeric(12,2) NOT NULL,
    payment_date date NOT NULL,
    payment_method_id integer NOT NULL,
    payment_reference character varying(100),
    registered_by integer NOT NULL,
    applied_breakdown_items jsonb DEFAULT '[]'::jsonb NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT check_debt_payments_amount_positive CHECK ((payment_amount > (0)::numeric)),
    CONSTRAINT check_debt_payments_date_logical CHECK ((payment_date <= CURRENT_DATE))
);


--
-- Name: associate_debt_payments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.associate_debt_payments_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: associate_debt_payments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.associate_debt_payments_id_seq OWNED BY public.associate_debt_payments.id;


--
-- Name: associate_level_history; Type: TABLE; Schema: public; Owner: -
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


--
-- Name: associate_level_history_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.associate_level_history_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: associate_level_history_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.associate_level_history_id_seq OWNED BY public.associate_level_history.id;


--
-- Name: associate_levels; Type: TABLE; Schema: public; Owner: -
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


--
-- Name: associate_levels_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.associate_levels_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: associate_levels_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.associate_levels_id_seq OWNED BY public.associate_levels.id;


--
-- Name: associate_payment_statements; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.associate_payment_statements (
    id integer NOT NULL,
    cut_period_id integer NOT NULL,
    user_id integer NOT NULL,
    statement_number character varying(50) NOT NULL,
    total_payments_count integer DEFAULT 0 NOT NULL,
    total_amount_collected numeric(12,2) DEFAULT 0.00 NOT NULL,
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
    total_to_credicuenta numeric(12,2),
    commission_earned numeric(12,2)
);


--
-- Name: associate_payment_statements_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.associate_payment_statements_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: associate_payment_statements_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.associate_payment_statements_id_seq OWNED BY public.associate_payment_statements.id;


--
-- Name: associate_profiles; Type: TABLE; Schema: public; Owner: -
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
    credit_last_updated timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    debt_balance numeric(12,2) DEFAULT 0.00 NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    credit_available numeric(12,2) GENERATED ALWAYS AS (GREATEST(((credit_limit - credit_used) - debt_balance), (0)::numeric)) STORED,
    CONSTRAINT check_associate_profiles_commission_rate_valid CHECK (((default_commission_rate >= (0)::numeric) AND (default_commission_rate <= (100)::numeric))),
    CONSTRAINT check_associate_profiles_counters_non_negative CHECK (((consecutive_full_credit_periods >= 0) AND (consecutive_on_time_payments >= 0) AND (clients_in_agreement >= 0))),
    CONSTRAINT check_associate_profiles_credit_non_negative CHECK (((credit_used >= (0)::numeric) AND (credit_limit >= (0)::numeric))),
    CONSTRAINT check_associate_profiles_debt_non_negative CHECK ((debt_balance >= (0)::numeric))
);


--
-- Name: associate_profiles_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.associate_profiles_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: associate_profiles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.associate_profiles_id_seq OWNED BY public.associate_profiles.id;


--
-- Name: associate_statement_payments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.associate_statement_payments (
    id integer NOT NULL,
    statement_id integer NOT NULL,
    payment_amount numeric(12,2) NOT NULL,
    payment_date date NOT NULL,
    payment_method_id integer NOT NULL,
    payment_reference character varying(100),
    registered_by integer NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT check_statement_payments_amount_positive CHECK ((payment_amount > (0)::numeric)),
    CONSTRAINT check_statement_payments_date_logical CHECK ((payment_date <= CURRENT_DATE))
);


--
-- Name: associate_statement_payments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.associate_statement_payments_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: associate_statement_payments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.associate_statement_payments_id_seq OWNED BY public.associate_statement_payments.id;


--
-- Name: audit_log; Type: TABLE; Schema: public; Owner: -
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


--
-- Name: audit_log_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.audit_log_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: audit_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.audit_log_id_seq OWNED BY public.audit_log.id;


--
-- Name: audit_session_log; Type: TABLE; Schema: public; Owner: -
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


--
-- Name: audit_session_log_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.audit_session_log_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: audit_session_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.audit_session_log_id_seq OWNED BY public.audit_session_log.id;


--
-- Name: beneficiaries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.beneficiaries (
    id integer NOT NULL,
    user_id integer NOT NULL,
    full_name character varying(200) NOT NULL,
    relationship character varying(50) NOT NULL,
    phone_number character varying(20) NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    relationship_id integer
);


--
-- Name: beneficiaries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.beneficiaries_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: beneficiaries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.beneficiaries_id_seq OWNED BY public.beneficiaries.id;


--
-- Name: client_documents; Type: TABLE; Schema: public; Owner: -
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


--
-- Name: client_documents_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.client_documents_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: client_documents_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.client_documents_id_seq OWNED BY public.client_documents.id;


--
-- Name: config_types; Type: TABLE; Schema: public; Owner: -
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


--
-- Name: config_types_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.config_types_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: config_types_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.config_types_id_seq OWNED BY public.config_types.id;


--
-- Name: contract_statuses; Type: TABLE; Schema: public; Owner: -
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


--
-- Name: contract_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.contract_statuses_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: contract_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.contract_statuses_id_seq OWNED BY public.contract_statuses.id;


--
-- Name: contracts; Type: TABLE; Schema: public; Owner: -
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


--
-- Name: contracts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.contracts_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: contracts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.contracts_id_seq OWNED BY public.contracts.id;


--
-- Name: cut_period_statuses; Type: TABLE; Schema: public; Owner: -
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


--
-- Name: cut_period_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.cut_period_statuses_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: cut_period_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.cut_period_statuses_id_seq OWNED BY public.cut_period_statuses.id;


--
-- Name: cut_periods; Type: TABLE; Schema: public; Owner: -
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


--
-- Name: cut_periods_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.cut_periods_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: cut_periods_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.cut_periods_id_seq OWNED BY public.cut_periods.id;


--
-- Name: defaulted_client_reports; Type: TABLE; Schema: public; Owner: -
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


--
-- Name: defaulted_client_reports_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.defaulted_client_reports_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: defaulted_client_reports_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.defaulted_client_reports_id_seq OWNED BY public.defaulted_client_reports.id;


--
-- Name: document_statuses; Type: TABLE; Schema: public; Owner: -
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


--
-- Name: document_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.document_statuses_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: document_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.document_statuses_id_seq OWNED BY public.document_statuses.id;


--
-- Name: document_types; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.document_types (
    id integer NOT NULL,
    name character varying(100) NOT NULL,
    description text,
    is_required boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: document_types_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.document_types_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: document_types_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.document_types_id_seq OWNED BY public.document_types.id;


--
-- Name: guarantors; Type: TABLE; Schema: public; Owner: -
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
    relationship_id integer,
    CONSTRAINT check_guarantors_curp_length CHECK (((curp IS NULL) OR (length((curp)::text) = 18))),
    CONSTRAINT check_guarantors_phone_format CHECK (((phone_number)::text ~ '^[0-9]{10}$'::text))
);


--
-- Name: guarantors_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.guarantors_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: guarantors_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.guarantors_id_seq OWNED BY public.guarantors.id;


--
-- Name: legacy_payment_table; Type: TABLE; Schema: public; Owner: -
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
    associate_biweekly_payment numeric(10,2),
    commission_per_payment numeric(10,2) GENERATED ALWAYS AS ((biweekly_payment - COALESCE(associate_biweekly_payment, (0)::numeric))) STORED,
    associate_total_payment numeric(12,2) GENERATED ALWAYS AS ((COALESCE(associate_biweekly_payment, (0)::numeric) * (term_biweeks)::numeric)) STORED,
    total_commission numeric(12,2) GENERATED ALWAYS AS (((biweekly_payment - COALESCE(associate_biweekly_payment, (0)::numeric)) * (term_biweeks)::numeric)) STORED,
    CONSTRAINT check_legacy_amount_positive CHECK ((amount > (0)::numeric)),
    CONSTRAINT check_legacy_payment_positive CHECK ((biweekly_payment > (0)::numeric)),
    CONSTRAINT check_legacy_term_valid CHECK (((term_biweeks >= 1) AND (term_biweeks <= 52)))
);


--
-- Name: legacy_payment_table_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.legacy_payment_table_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: legacy_payment_table_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.legacy_payment_table_id_seq OWNED BY public.legacy_payment_table.id;


--
-- Name: level_change_types; Type: TABLE; Schema: public; Owner: -
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


--
-- Name: level_change_types_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.level_change_types_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: level_change_types_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.level_change_types_id_seq OWNED BY public.level_change_types.id;


--
-- Name: loan_renewals; Type: TABLE; Schema: public; Owner: -
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


--
-- Name: loan_renewals_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.loan_renewals_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: loan_renewals_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.loan_renewals_id_seq OWNED BY public.loan_renewals.id;


--
-- Name: loan_statuses; Type: TABLE; Schema: public; Owner: -
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


--
-- Name: loan_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.loan_statuses_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: loan_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.loan_statuses_id_seq OWNED BY public.loan_statuses.id;


--
-- Name: loans; Type: TABLE; Schema: public; Owner: -
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
    CONSTRAINT check_loans_term_biweeks_valid CHECK ((term_biweeks = ANY (ARRAY[3, 6, 9, 12, 15, 18, 21, 24, 30, 36]))),
    CONSTRAINT chk_loans_associate_payment_consistent CHECK (((associate_payment IS NULL) OR (biweekly_payment IS NULL) OR (commission_per_payment IS NULL) OR (abs((associate_payment - (biweekly_payment - commission_per_payment))) < 0.10))),
    CONSTRAINT chk_loans_associate_payment_lte_biweekly CHECK (((associate_payment IS NULL) OR (biweekly_payment IS NULL) OR (associate_payment <= biweekly_payment))),
    CONSTRAINT chk_loans_biweekly_payment_positive CHECK (((biweekly_payment IS NULL) OR (biweekly_payment > (0)::numeric))),
    CONSTRAINT chk_loans_commission_per_payment_non_negative CHECK (((commission_per_payment IS NULL) OR (commission_per_payment >= (0)::numeric))),
    CONSTRAINT chk_loans_total_interest_consistent CHECK (((total_interest IS NULL) OR (total_payment IS NULL) OR (amount IS NULL) OR (abs((total_interest - (total_payment - amount))) < 1.00))),
    CONSTRAINT chk_loans_total_interest_non_negative CHECK (((total_interest IS NULL) OR (total_interest >= (0)::numeric))),
    CONSTRAINT chk_loans_total_payment_consistent CHECK (((total_payment IS NULL) OR (biweekly_payment IS NULL) OR (term_biweeks IS NULL) OR (abs((total_payment - (biweekly_payment * (term_biweeks)::numeric))) < 1.00))),
    CONSTRAINT chk_loans_total_payment_gte_amount CHECK (((total_payment IS NULL) OR (total_payment >= amount)))
);


--
-- Name: loans_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.loans_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: loans_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.loans_id_seq OWNED BY public.loans.id;


--
-- Name: payment_methods; Type: TABLE; Schema: public; Owner: -
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


--
-- Name: payment_methods_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.payment_methods_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: payment_methods_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.payment_methods_id_seq OWNED BY public.payment_methods.id;


--
-- Name: payment_status_history; Type: TABLE; Schema: public; Owner: -
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


--
-- Name: payment_status_history_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.payment_status_history_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: payment_status_history_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.payment_status_history_id_seq OWNED BY public.payment_status_history.id;


--
-- Name: payment_statuses; Type: TABLE; Schema: public; Owner: -
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


--
-- Name: payment_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.payment_statuses_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: payment_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.payment_statuses_id_seq OWNED BY public.payment_statuses.id;


--
-- Name: payments; Type: TABLE; Schema: public; Owner: -
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
    associate_balance_remaining numeric(12,2),
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


--
-- Name: payments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.payments_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: payments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.payments_id_seq OWNED BY public.payments.id;


--
-- Name: rate_profile_reference_table; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.rate_profile_reference_table (
    id integer NOT NULL,
    profile_code character varying(50) NOT NULL,
    amount numeric(12,2) NOT NULL,
    term_biweeks integer NOT NULL,
    biweekly_payment numeric(10,2) NOT NULL,
    total_payment numeric(12,2) NOT NULL,
    commission_per_payment numeric(10,2) NOT NULL,
    total_commission numeric(12,2) NOT NULL,
    associate_payment numeric(10,2) NOT NULL,
    associate_total numeric(12,2) NOT NULL,
    interest_rate_percent numeric(5,3),
    commission_rate_percent numeric(5,3),
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: rate_profile_reference_table_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.rate_profile_reference_table_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: rate_profile_reference_table_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.rate_profile_reference_table_id_seq OWNED BY public.rate_profile_reference_table.id;


--
-- Name: rate_profiles; Type: TABLE; Schema: public; Owner: -
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


--
-- Name: rate_profiles_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.rate_profiles_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: rate_profiles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.rate_profiles_id_seq OWNED BY public.rate_profiles.id;


--
-- Name: relationships; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.relationships (
    id integer NOT NULL,
    name character varying(50) NOT NULL,
    description text,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: relationships_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.relationships_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: relationships_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.relationships_id_seq OWNED BY public.relationships.id;


--
-- Name: roles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.roles (
    id integer NOT NULL,
    name character varying(50) NOT NULL,
    description text,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: roles_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.roles_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: roles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.roles_id_seq OWNED BY public.roles.id;


--
-- Name: statement_statuses; Type: TABLE; Schema: public; Owner: -
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


--
-- Name: statement_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.statement_statuses_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: statement_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.statement_statuses_id_seq OWNED BY public.statement_statuses.id;


--
-- Name: system_configurations; Type: TABLE; Schema: public; Owner: -
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


--
-- Name: system_configurations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.system_configurations_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: system_configurations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.system_configurations_id_seq OWNED BY public.system_configurations.id;


--
-- Name: user_roles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_roles (
    user_id integer NOT NULL,
    role_id integer NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
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


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: v_associate_all_payments; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_associate_all_payments AS
 SELECT asp.id,
    'SALDO_ACTUAL'::text AS payment_type,
    ap.id AS associate_profile_id,
    concat(u.first_name, ' ', u.last_name) AS associate_name,
    asp.payment_amount,
    asp.payment_date,
    pm.name AS payment_method,
    asp.payment_reference,
    aps.cut_period_id,
    cp.period_start_date AS period_start,
    cp.period_end_date AS period_end,
    asp.notes,
    asp.created_at
   FROM (((((public.associate_statement_payments asp
     JOIN public.associate_payment_statements aps ON ((aps.id = asp.statement_id)))
     JOIN public.users u ON ((u.id = aps.user_id)))
     JOIN public.associate_profiles ap ON ((ap.user_id = u.id)))
     JOIN public.payment_methods pm ON ((pm.id = asp.payment_method_id)))
     LEFT JOIN public.cut_periods cp ON ((cp.id = aps.cut_period_id)))
UNION ALL
 SELECT adp.id,
    'DEUDA_ACUMULADA'::text AS payment_type,
    adp.associate_profile_id,
    concat(u.first_name, ' ', u.last_name) AS associate_name,
    adp.payment_amount,
    adp.payment_date,
    pm.name AS payment_method,
    adp.payment_reference,
    NULL::integer AS cut_period_id,
    NULL::date AS period_start,
    NULL::date AS period_end,
    adp.notes,
    adp.created_at
   FROM (((public.associate_debt_payments adp
     JOIN public.associate_profiles ap ON ((ap.id = adp.associate_profile_id)))
     JOIN public.users u ON ((u.id = ap.user_id)))
     JOIN public.payment_methods pm ON ((pm.id = adp.payment_method_id)))
  ORDER BY 6 DESC, 13 DESC;


--
-- Name: v_associate_credit_complete; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_associate_credit_complete AS
 SELECT ap.id AS associate_profile_id,
    u.id AS user_id,
    concat(u.first_name, ' ', u.last_name) AS associate_name,
    u.email,
    u.phone_number,
    al.name AS level,
    ap.credit_limit,
    ap.credit_used,
    ap.credit_available,
    ap.debt_balance,
    (ap.credit_available - ap.debt_balance) AS real_available_credit,
    round((((ap.credit_used)::numeric / NULLIF(ap.credit_limit, (0)::numeric)) * (100)::numeric), 2) AS usage_percentage,
    round((((ap.debt_balance)::numeric / NULLIF(ap.credit_limit, (0)::numeric)) * (100)::numeric), 2) AS debt_percentage,
    round((((ap.credit_available - ap.debt_balance) / NULLIF(ap.credit_limit, (0)::numeric)) * (100)::numeric), 2) AS real_available_percentage,
        CASE
            WHEN ((ap.credit_available - ap.debt_balance) <= (0)::numeric) THEN 'SIN_CREDITO'::text
            WHEN ((ap.credit_available - ap.debt_balance) < (ap.credit_limit * 0.25)) THEN 'CRITICO'::text
            WHEN ((ap.credit_available - ap.debt_balance) < (ap.credit_limit * 0.50)) THEN 'MEDIO'::text
            ELSE 'ALTO'::text
        END AS credit_health_status,
        CASE
            WHEN (ap.debt_balance = (0)::numeric) THEN 'SIN_DEUDA'::text
            WHEN (ap.debt_balance < (ap.credit_limit * 0.10)) THEN 'DEUDA_BAJA'::text
            WHEN (ap.debt_balance < (ap.credit_limit * 0.25)) THEN 'DEUDA_MEDIA'::text
            ELSE 'DEUDA_ALTA'::text
        END AS debt_status,
    ap.consecutive_full_credit_periods,
    ap.consecutive_on_time_payments,
    ap.clients_in_agreement,
    ap.active,
    ap.credit_last_updated,
    ap.last_level_evaluation_date
   FROM ((public.associate_profiles ap
     JOIN public.users u ON ((ap.user_id = u.id)))
     JOIN public.associate_levels al ON ((ap.level_id = al.id)))
  ORDER BY (ap.credit_available - ap.debt_balance) DESC;


--
-- Name: v_associate_credit_summary; Type: VIEW; Schema: public; Owner: -
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


--
-- Name: v_associate_late_fees; Type: VIEW; Schema: public; Owner: -
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
    aps.total_to_credicuenta,
    aps.commission_earned,
    aps.late_fee_amount,
    aps.late_fee_applied,
    ss.name AS statement_status,
        CASE
            WHEN aps.late_fee_applied THEN 'MORA APLICADA'::text
            WHEN ((aps.total_payments_count = 0) AND (aps.total_to_credicuenta > (0)::numeric)) THEN 'SUJETO A MORA'::text
            ELSE 'SIN MORA'::text
        END AS late_fee_status,
    round(((aps.late_fee_amount / NULLIF(aps.total_to_credicuenta, (0)::numeric)) * (100)::numeric), 2) AS late_fee_percentage,
    aps.generated_date,
    aps.due_date,
    aps.paid_date
   FROM (((public.associate_payment_statements aps
     JOIN public.users u ON ((aps.user_id = u.id)))
     JOIN public.cut_periods cp ON ((aps.cut_period_id = cp.id)))
     JOIN public.statement_statuses ss ON ((aps.status_id = ss.id)))
  WHERE ((aps.late_fee_amount > (0)::numeric) OR ((aps.total_payments_count = 0) AND (aps.total_to_credicuenta > (0)::numeric)))
  ORDER BY aps.generated_date DESC, aps.late_fee_amount DESC;


--
-- Name: v_associate_real_debt_summary; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_associate_real_debt_summary AS
 SELECT ap.id AS associate_profile_id,
    ap.user_id,
    concat(u.first_name, ' ', u.last_name) AS associate_name,
    COALESCE(debt_agg.total_accumulated_debt, (0)::numeric) AS total_debt,
    COALESCE(debt_agg.periods_with_debt, (0)::bigint) AS periods_with_debt,
    debt_agg.oldest_debt_date,
    debt_agg.newest_debt_date,
    ap.debt_balance AS profile_debt_balance,
    ap.credit_limit,
    ap.credit_available,
    ap.credit_used,
    COALESCE(payments_agg.total_paid_to_debt, (0)::numeric) AS total_paid_to_debt,
    COALESCE(payments_agg.total_payments_count, (0)::bigint) AS total_payments_count,
    payments_agg.last_payment_date
   FROM (((public.associate_profiles ap
     JOIN public.users u ON ((u.id = ap.user_id)))
     LEFT JOIN ( SELECT associate_accumulated_balances.user_id,
            sum(associate_accumulated_balances.accumulated_debt) AS total_accumulated_debt,
            count(*) AS periods_with_debt,
            min(associate_accumulated_balances.created_at) AS oldest_debt_date,
            max(associate_accumulated_balances.created_at) AS newest_debt_date
           FROM public.associate_accumulated_balances
          WHERE (associate_accumulated_balances.accumulated_debt > (0)::numeric)
          GROUP BY associate_accumulated_balances.user_id) debt_agg ON ((debt_agg.user_id = ap.user_id)))
     LEFT JOIN ( SELECT associate_debt_payments.associate_profile_id,
            sum(associate_debt_payments.payment_amount) AS total_paid_to_debt,
            count(*) AS total_payments_count,
            max(associate_debt_payments.payment_date) AS last_payment_date
           FROM public.associate_debt_payments
          GROUP BY associate_debt_payments.associate_profile_id) payments_agg ON ((payments_agg.associate_profile_id = ap.id)));


--
-- Name: v_cut_periods_readable; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_cut_periods_readable AS
 SELECT cut_periods.id,
    cut_periods.cut_code,
    cut_periods.period_start_date,
    cut_periods.period_end_date,
    ((cut_periods.period_end_date - cut_periods.period_start_date) + 1) AS days_in_period,
    to_char((cut_periods.period_start_date)::timestamp with time zone, 'DD-Mon-YYYY'::text) AS start_formatted,
    to_char((cut_periods.period_end_date)::timestamp with time zone, 'DD-Mon-YYYY'::text) AS end_formatted,
        CASE
            WHEN (EXTRACT(day FROM cut_periods.period_start_date) = (8)::numeric) THEN 'Primera Quincena'::text
            WHEN (EXTRACT(day FROM cut_periods.period_start_date) = (23)::numeric) THEN 'Segunda Quincena'::text
            ELSE 'Irregular'::text
        END AS period_type,
    cut_periods.status_id,
    cut_periods.total_payments_expected,
    cut_periods.total_payments_received,
    cut_periods.total_commission
   FROM public.cut_periods;


--
-- Name: v_loans_summary; Type: VIEW; Schema: public; Owner: -
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


--
-- Name: v_payment_changes_summary; Type: VIEW; Schema: public; Owner: -
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


--
-- Name: v_payments_absorbed_by_associate; Type: VIEW; Schema: public; Owner: -
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


--
-- Name: v_payments_by_status_detailed; Type: VIEW; Schema: public; Owner: -
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


--
-- Name: v_payments_multiple_changes; Type: VIEW; Schema: public; Owner: -
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


--
-- Name: v_payments_summary; Type: VIEW; Schema: public; Owner: -
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


--
-- Name: v_period_closure_summary; Type: VIEW; Schema: public; Owner: -
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


--
-- Name: v_rate_reference_12q; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_rate_reference_12q AS
 SELECT rate_profile_reference_table.profile_code AS "Perfil",
    rate_profile_reference_table.amount AS "Importe",
    rate_profile_reference_table.biweekly_payment AS "Pago Cliente",
    rate_profile_reference_table.total_payment AS "Total Cliente",
    rate_profile_reference_table.commission_per_payment AS "Comisión",
    rate_profile_reference_table.total_commission AS "Comisión Total",
    rate_profile_reference_table.associate_payment AS "Pago Asociado",
    rate_profile_reference_table.associate_total AS "Total Asociado"
   FROM public.rate_profile_reference_table
  WHERE (rate_profile_reference_table.term_biweeks = 12)
  ORDER BY rate_profile_reference_table.profile_code, rate_profile_reference_table.amount;


--
-- Name: v_recent_payment_changes; Type: VIEW; Schema: public; Owner: -
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


--
-- Name: v_statement_payment_history; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_statement_payment_history AS
 SELECT asp.id AS payment_id,
    asp.statement_id,
    aps.statement_number,
    concat(u_assoc.first_name, ' ', u_assoc.last_name) AS associate_name,
    cp.cut_number,
    cp.period_start_date,
    cp.period_end_date,
    asp.payment_amount,
    asp.payment_date,
    pm.name AS payment_method,
    asp.payment_reference,
    asp.notes,
    aps.total_to_credicuenta,
    aps.commission_earned,
    aps.late_fee_amount,
    (aps.total_to_credicuenta + aps.late_fee_amount) AS total_owed,
    aps.paid_amount AS total_paid_to_date,
    ((aps.total_to_credicuenta + aps.late_fee_amount) - aps.paid_amount) AS remaining_balance,
    ss.name AS statement_status,
    concat(u_reg.first_name, ' ', u_reg.last_name) AS registered_by_name,
    asp.created_at AS payment_registered_at
   FROM ((((((public.associate_statement_payments asp
     JOIN public.associate_payment_statements aps ON ((asp.statement_id = aps.id)))
     JOIN public.users u_assoc ON ((aps.user_id = u_assoc.id)))
     JOIN public.cut_periods cp ON ((aps.cut_period_id = cp.id)))
     JOIN public.payment_methods pm ON ((asp.payment_method_id = pm.id)))
     JOIN public.statement_statuses ss ON ((aps.status_id = ss.id)))
     JOIN public.users u_reg ON ((asp.registered_by = u_reg.id)))
  ORDER BY asp.payment_date DESC, asp.id DESC;


--
-- Name: addresses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.addresses ALTER COLUMN id SET DEFAULT nextval('public.addresses_id_seq'::regclass);


--
-- Name: agreement_items id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agreement_items ALTER COLUMN id SET DEFAULT nextval('public.agreement_items_id_seq'::regclass);


--
-- Name: agreement_payments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agreement_payments ALTER COLUMN id SET DEFAULT nextval('public.agreement_payments_id_seq'::regclass);


--
-- Name: agreements id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agreements ALTER COLUMN id SET DEFAULT nextval('public.agreements_id_seq'::regclass);


--
-- Name: associate_accumulated_balances id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.associate_accumulated_balances ALTER COLUMN id SET DEFAULT nextval('public.associate_accumulated_balances_id_seq'::regclass);


--
-- Name: associate_debt_payments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.associate_debt_payments ALTER COLUMN id SET DEFAULT nextval('public.associate_debt_payments_id_seq'::regclass);


--
-- Name: associate_level_history id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.associate_level_history ALTER COLUMN id SET DEFAULT nextval('public.associate_level_history_id_seq'::regclass);


--
-- Name: associate_levels id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.associate_levels ALTER COLUMN id SET DEFAULT nextval('public.associate_levels_id_seq'::regclass);


--
-- Name: associate_payment_statements id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.associate_payment_statements ALTER COLUMN id SET DEFAULT nextval('public.associate_payment_statements_id_seq'::regclass);


--
-- Name: associate_profiles id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.associate_profiles ALTER COLUMN id SET DEFAULT nextval('public.associate_profiles_id_seq'::regclass);


--
-- Name: associate_statement_payments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.associate_statement_payments ALTER COLUMN id SET DEFAULT nextval('public.associate_statement_payments_id_seq'::regclass);


--
-- Name: audit_log id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_log ALTER COLUMN id SET DEFAULT nextval('public.audit_log_id_seq'::regclass);


--
-- Name: audit_session_log id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_session_log ALTER COLUMN id SET DEFAULT nextval('public.audit_session_log_id_seq'::regclass);


--
-- Name: beneficiaries id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.beneficiaries ALTER COLUMN id SET DEFAULT nextval('public.beneficiaries_id_seq'::regclass);


--
-- Name: client_documents id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_documents ALTER COLUMN id SET DEFAULT nextval('public.client_documents_id_seq'::regclass);


--
-- Name: config_types id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.config_types ALTER COLUMN id SET DEFAULT nextval('public.config_types_id_seq'::regclass);


--
-- Name: contract_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contract_statuses ALTER COLUMN id SET DEFAULT nextval('public.contract_statuses_id_seq'::regclass);


--
-- Name: contracts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contracts ALTER COLUMN id SET DEFAULT nextval('public.contracts_id_seq'::regclass);


--
-- Name: cut_period_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cut_period_statuses ALTER COLUMN id SET DEFAULT nextval('public.cut_period_statuses_id_seq'::regclass);


--
-- Name: cut_periods id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cut_periods ALTER COLUMN id SET DEFAULT nextval('public.cut_periods_id_seq'::regclass);


--
-- Name: defaulted_client_reports id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.defaulted_client_reports ALTER COLUMN id SET DEFAULT nextval('public.defaulted_client_reports_id_seq'::regclass);


--
-- Name: document_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_statuses ALTER COLUMN id SET DEFAULT nextval('public.document_statuses_id_seq'::regclass);


--
-- Name: document_types id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_types ALTER COLUMN id SET DEFAULT nextval('public.document_types_id_seq'::regclass);


--
-- Name: guarantors id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guarantors ALTER COLUMN id SET DEFAULT nextval('public.guarantors_id_seq'::regclass);


--
-- Name: legacy_payment_table id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legacy_payment_table ALTER COLUMN id SET DEFAULT nextval('public.legacy_payment_table_id_seq'::regclass);


--
-- Name: level_change_types id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.level_change_types ALTER COLUMN id SET DEFAULT nextval('public.level_change_types_id_seq'::regclass);


--
-- Name: loan_renewals id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.loan_renewals ALTER COLUMN id SET DEFAULT nextval('public.loan_renewals_id_seq'::regclass);


--
-- Name: loan_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.loan_statuses ALTER COLUMN id SET DEFAULT nextval('public.loan_statuses_id_seq'::regclass);


--
-- Name: loans id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.loans ALTER COLUMN id SET DEFAULT nextval('public.loans_id_seq'::regclass);


--
-- Name: payment_methods id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_methods ALTER COLUMN id SET DEFAULT nextval('public.payment_methods_id_seq'::regclass);


--
-- Name: payment_status_history id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_status_history ALTER COLUMN id SET DEFAULT nextval('public.payment_status_history_id_seq'::regclass);


--
-- Name: payment_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_statuses ALTER COLUMN id SET DEFAULT nextval('public.payment_statuses_id_seq'::regclass);


--
-- Name: payments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments ALTER COLUMN id SET DEFAULT nextval('public.payments_id_seq'::regclass);


--
-- Name: rate_profile_reference_table id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rate_profile_reference_table ALTER COLUMN id SET DEFAULT nextval('public.rate_profile_reference_table_id_seq'::regclass);


--
-- Name: rate_profiles id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rate_profiles ALTER COLUMN id SET DEFAULT nextval('public.rate_profiles_id_seq'::regclass);


--
-- Name: relationships id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.relationships ALTER COLUMN id SET DEFAULT nextval('public.relationships_id_seq'::regclass);


--
-- Name: roles id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles ALTER COLUMN id SET DEFAULT nextval('public.roles_id_seq'::regclass);


--
-- Name: statement_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.statement_statuses ALTER COLUMN id SET DEFAULT nextval('public.statement_statuses_id_seq'::regclass);


--
-- Name: system_configurations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.system_configurations ALTER COLUMN id SET DEFAULT nextval('public.system_configurations_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: addresses addresses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.addresses
    ADD CONSTRAINT addresses_pkey PRIMARY KEY (id);


--
-- Name: addresses addresses_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.addresses
    ADD CONSTRAINT addresses_user_id_key UNIQUE (user_id);


--
-- Name: agreement_items agreement_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agreement_items
    ADD CONSTRAINT agreement_items_pkey PRIMARY KEY (id);


--
-- Name: agreement_payments agreement_payments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agreement_payments
    ADD CONSTRAINT agreement_payments_pkey PRIMARY KEY (id);


--
-- Name: agreements agreements_agreement_number_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agreements
    ADD CONSTRAINT agreements_agreement_number_key UNIQUE (agreement_number);


--
-- Name: agreements agreements_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agreements
    ADD CONSTRAINT agreements_pkey PRIMARY KEY (id);


--
-- Name: associate_accumulated_balances associate_accumulated_balances_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.associate_accumulated_balances
    ADD CONSTRAINT associate_accumulated_balances_pkey PRIMARY KEY (id);


--
-- Name: associate_accumulated_balances associate_accumulated_balances_user_id_cut_period_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.associate_accumulated_balances
    ADD CONSTRAINT associate_accumulated_balances_user_id_cut_period_id_key UNIQUE (user_id, cut_period_id);


--
-- Name: associate_debt_payments associate_debt_payments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.associate_debt_payments
    ADD CONSTRAINT associate_debt_payments_pkey PRIMARY KEY (id);


--
-- Name: associate_level_history associate_level_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.associate_level_history
    ADD CONSTRAINT associate_level_history_pkey PRIMARY KEY (id);


--
-- Name: associate_levels associate_levels_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.associate_levels
    ADD CONSTRAINT associate_levels_name_key UNIQUE (name);


--
-- Name: associate_levels associate_levels_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.associate_levels
    ADD CONSTRAINT associate_levels_pkey PRIMARY KEY (id);


--
-- Name: associate_payment_statements associate_payment_statements_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.associate_payment_statements
    ADD CONSTRAINT associate_payment_statements_pkey PRIMARY KEY (id);


--
-- Name: associate_profiles associate_profiles_contact_email_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.associate_profiles
    ADD CONSTRAINT associate_profiles_contact_email_key UNIQUE (contact_email);


--
-- Name: associate_profiles associate_profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.associate_profiles
    ADD CONSTRAINT associate_profiles_pkey PRIMARY KEY (id);


--
-- Name: associate_profiles associate_profiles_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.associate_profiles
    ADD CONSTRAINT associate_profiles_user_id_key UNIQUE (user_id);


--
-- Name: associate_statement_payments associate_statement_payments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.associate_statement_payments
    ADD CONSTRAINT associate_statement_payments_pkey PRIMARY KEY (id);


--
-- Name: audit_log audit_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_log
    ADD CONSTRAINT audit_log_pkey PRIMARY KEY (id);


--
-- Name: audit_session_log audit_session_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_session_log
    ADD CONSTRAINT audit_session_log_pkey PRIMARY KEY (id);


--
-- Name: beneficiaries beneficiaries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.beneficiaries
    ADD CONSTRAINT beneficiaries_pkey PRIMARY KEY (id);


--
-- Name: beneficiaries beneficiaries_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.beneficiaries
    ADD CONSTRAINT beneficiaries_user_id_key UNIQUE (user_id);


--
-- Name: client_documents client_documents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_documents
    ADD CONSTRAINT client_documents_pkey PRIMARY KEY (id);


--
-- Name: config_types config_types_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.config_types
    ADD CONSTRAINT config_types_name_key UNIQUE (name);


--
-- Name: config_types config_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.config_types
    ADD CONSTRAINT config_types_pkey PRIMARY KEY (id);


--
-- Name: contract_statuses contract_statuses_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contract_statuses
    ADD CONSTRAINT contract_statuses_name_key UNIQUE (name);


--
-- Name: contract_statuses contract_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contract_statuses
    ADD CONSTRAINT contract_statuses_pkey PRIMARY KEY (id);


--
-- Name: contracts contracts_document_number_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contracts
    ADD CONSTRAINT contracts_document_number_key UNIQUE (document_number);


--
-- Name: contracts contracts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contracts
    ADD CONSTRAINT contracts_pkey PRIMARY KEY (id);


--
-- Name: cut_period_statuses cut_period_statuses_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cut_period_statuses
    ADD CONSTRAINT cut_period_statuses_name_key UNIQUE (name);


--
-- Name: cut_period_statuses cut_period_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cut_period_statuses
    ADD CONSTRAINT cut_period_statuses_pkey PRIMARY KEY (id);


--
-- Name: cut_periods cut_periods_cut_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cut_periods
    ADD CONSTRAINT cut_periods_cut_code_key UNIQUE (cut_code);


--
-- Name: cut_periods cut_periods_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cut_periods
    ADD CONSTRAINT cut_periods_pkey PRIMARY KEY (id);


--
-- Name: defaulted_client_reports defaulted_client_reports_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.defaulted_client_reports
    ADD CONSTRAINT defaulted_client_reports_pkey PRIMARY KEY (id);


--
-- Name: document_statuses document_statuses_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_statuses
    ADD CONSTRAINT document_statuses_name_key UNIQUE (name);


--
-- Name: document_statuses document_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_statuses
    ADD CONSTRAINT document_statuses_pkey PRIMARY KEY (id);


--
-- Name: document_types document_types_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_types
    ADD CONSTRAINT document_types_name_key UNIQUE (name);


--
-- Name: document_types document_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_types
    ADD CONSTRAINT document_types_pkey PRIMARY KEY (id);


--
-- Name: guarantors guarantors_curp_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guarantors
    ADD CONSTRAINT guarantors_curp_key UNIQUE (curp);


--
-- Name: guarantors guarantors_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guarantors
    ADD CONSTRAINT guarantors_pkey PRIMARY KEY (id);


--
-- Name: guarantors guarantors_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guarantors
    ADD CONSTRAINT guarantors_user_id_key UNIQUE (user_id);


--
-- Name: legacy_payment_table legacy_payment_table_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legacy_payment_table
    ADD CONSTRAINT legacy_payment_table_pkey PRIMARY KEY (id);


--
-- Name: level_change_types level_change_types_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.level_change_types
    ADD CONSTRAINT level_change_types_name_key UNIQUE (name);


--
-- Name: level_change_types level_change_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.level_change_types
    ADD CONSTRAINT level_change_types_pkey PRIMARY KEY (id);


--
-- Name: loan_renewals loan_renewals_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.loan_renewals
    ADD CONSTRAINT loan_renewals_pkey PRIMARY KEY (id);


--
-- Name: loan_statuses loan_statuses_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.loan_statuses
    ADD CONSTRAINT loan_statuses_name_key UNIQUE (name);


--
-- Name: loan_statuses loan_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.loan_statuses
    ADD CONSTRAINT loan_statuses_pkey PRIMARY KEY (id);


--
-- Name: loans loans_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.loans
    ADD CONSTRAINT loans_pkey PRIMARY KEY (id);


--
-- Name: payment_methods payment_methods_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_methods
    ADD CONSTRAINT payment_methods_name_key UNIQUE (name);


--
-- Name: payment_methods payment_methods_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_methods
    ADD CONSTRAINT payment_methods_pkey PRIMARY KEY (id);


--
-- Name: payment_status_history payment_status_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_status_history
    ADD CONSTRAINT payment_status_history_pkey PRIMARY KEY (id);


--
-- Name: payment_statuses payment_statuses_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_statuses
    ADD CONSTRAINT payment_statuses_name_key UNIQUE (name);


--
-- Name: payment_statuses payment_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_statuses
    ADD CONSTRAINT payment_statuses_pkey PRIMARY KEY (id);


--
-- Name: payments payments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_pkey PRIMARY KEY (id);


--
-- Name: rate_profile_reference_table rate_profile_reference_table_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rate_profile_reference_table
    ADD CONSTRAINT rate_profile_reference_table_pkey PRIMARY KEY (id);


--
-- Name: rate_profiles rate_profiles_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rate_profiles
    ADD CONSTRAINT rate_profiles_code_key UNIQUE (code);


--
-- Name: rate_profiles rate_profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rate_profiles
    ADD CONSTRAINT rate_profiles_pkey PRIMARY KEY (id);


--
-- Name: relationships relationships_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.relationships
    ADD CONSTRAINT relationships_name_key UNIQUE (name);


--
-- Name: relationships relationships_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.relationships
    ADD CONSTRAINT relationships_pkey PRIMARY KEY (id);


--
-- Name: roles roles_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_name_key UNIQUE (name);


--
-- Name: roles roles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_pkey PRIMARY KEY (id);


--
-- Name: statement_statuses statement_statuses_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.statement_statuses
    ADD CONSTRAINT statement_statuses_name_key UNIQUE (name);


--
-- Name: statement_statuses statement_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.statement_statuses
    ADD CONSTRAINT statement_statuses_pkey PRIMARY KEY (id);


--
-- Name: system_configurations system_configurations_config_key_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.system_configurations
    ADD CONSTRAINT system_configurations_config_key_key UNIQUE (config_key);


--
-- Name: system_configurations system_configurations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.system_configurations
    ADD CONSTRAINT system_configurations_pkey PRIMARY KEY (id);


--
-- Name: legacy_payment_table uq_legacy_amount_term; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legacy_payment_table
    ADD CONSTRAINT uq_legacy_amount_term UNIQUE (amount, term_biweeks);


--
-- Name: rate_profile_reference_table uq_profile_amount_term; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rate_profile_reference_table
    ADD CONSTRAINT uq_profile_amount_term UNIQUE (profile_code, amount, term_biweeks);


--
-- Name: user_roles user_roles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_roles
    ADD CONSTRAINT user_roles_pkey PRIMARY KEY (user_id, role_id);


--
-- Name: users users_curp_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_curp_key UNIQUE (curp);


--
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- Name: users users_phone_number_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_phone_number_key UNIQUE (phone_number);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: users users_username_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_username_key UNIQUE (username);


--
-- Name: idx_agreement_items_agreement_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_agreement_items_agreement_id ON public.agreement_items USING btree (agreement_id);


--
-- Name: idx_agreement_items_loan_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_agreement_items_loan_id ON public.agreement_items USING btree (loan_id);


--
-- Name: idx_agreement_payments_agreement_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_agreement_payments_agreement_id ON public.agreement_payments USING btree (agreement_id);


--
-- Name: idx_agreement_payments_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_agreement_payments_status ON public.agreement_payments USING btree (status);


--
-- Name: idx_agreements_associate_profile_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_agreements_associate_profile_id ON public.agreements USING btree (associate_profile_id);


--
-- Name: idx_agreements_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_agreements_status ON public.agreements USING btree (status);


--
-- Name: idx_associate_profiles_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_associate_profiles_active ON public.associate_profiles USING btree (active);


--
-- Name: idx_associate_profiles_credit_used; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_associate_profiles_credit_used ON public.associate_profiles USING btree (credit_used);


--
-- Name: idx_associate_profiles_level_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_associate_profiles_level_id ON public.associate_profiles USING btree (level_id);


--
-- Name: idx_associate_profiles_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_associate_profiles_user_id ON public.associate_profiles USING btree (user_id);


--
-- Name: idx_audit_log_changed_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_audit_log_changed_at ON public.audit_log USING btree (changed_at);


--
-- Name: idx_audit_log_changed_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_audit_log_changed_by ON public.audit_log USING btree (changed_by);


--
-- Name: idx_audit_log_operation; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_audit_log_operation ON public.audit_log USING btree (operation);


--
-- Name: idx_audit_log_table_record; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_audit_log_table_record ON public.audit_log USING btree (table_name, record_id);


--
-- Name: idx_beneficiaries_relationship_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_beneficiaries_relationship_id ON public.beneficiaries USING btree (relationship_id);


--
-- Name: idx_client_documents_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_client_documents_status_id ON public.client_documents USING btree (status_id);


--
-- Name: idx_client_documents_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_client_documents_user_id ON public.client_documents USING btree (user_id);


--
-- Name: idx_config_types_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_config_types_name ON public.config_types USING btree (name);


--
-- Name: idx_contract_statuses_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_contract_statuses_name ON public.contract_statuses USING btree (name);


--
-- Name: idx_contracts_document_number; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_contracts_document_number ON public.contracts USING btree (document_number);


--
-- Name: idx_contracts_loan_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_contracts_loan_id ON public.contracts USING btree (loan_id);


--
-- Name: idx_cut_period_statuses_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_cut_period_statuses_name ON public.cut_period_statuses USING btree (name);


--
-- Name: idx_cut_periods_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_cut_periods_active ON public.cut_periods USING btree (status_id) WHERE (status_id = ANY (ARRAY[1, 2]));


--
-- Name: idx_cut_periods_cut_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_cut_periods_cut_code ON public.cut_periods USING btree (cut_code);


--
-- Name: idx_cut_periods_dates; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_cut_periods_dates ON public.cut_periods USING btree (period_start_date, period_end_date);


--
-- Name: idx_cut_periods_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_cut_periods_status_id ON public.cut_periods USING btree (status_id);


--
-- Name: idx_debt_payments_applied_items; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_debt_payments_applied_items ON public.associate_debt_payments USING gin (applied_breakdown_items);


--
-- Name: idx_debt_payments_associate_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_debt_payments_associate_date ON public.associate_debt_payments USING btree (associate_profile_id, payment_date DESC);


--
-- Name: idx_debt_payments_associate_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_debt_payments_associate_id ON public.associate_debt_payments USING btree (associate_profile_id);


--
-- Name: idx_debt_payments_method; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_debt_payments_method ON public.associate_debt_payments USING btree (payment_method_id);


--
-- Name: idx_debt_payments_payment_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_debt_payments_payment_date ON public.associate_debt_payments USING btree (payment_date);


--
-- Name: idx_debt_payments_registered_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_debt_payments_registered_by ON public.associate_debt_payments USING btree (registered_by);


--
-- Name: idx_defaulted_reports_associate_profile_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_defaulted_reports_associate_profile_id ON public.defaulted_client_reports USING btree (associate_profile_id);


--
-- Name: idx_defaulted_reports_client_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_defaulted_reports_client_user_id ON public.defaulted_client_reports USING btree (client_user_id);


--
-- Name: idx_defaulted_reports_loan_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_defaulted_reports_loan_id ON public.defaulted_client_reports USING btree (loan_id);


--
-- Name: idx_defaulted_reports_reported_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_defaulted_reports_reported_at ON public.defaulted_client_reports USING btree (reported_at DESC);


--
-- Name: idx_defaulted_reports_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_defaulted_reports_status ON public.defaulted_client_reports USING btree (status);


--
-- Name: idx_document_statuses_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_document_statuses_name ON public.document_statuses USING btree (name);


--
-- Name: idx_guarantors_relationship_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_guarantors_relationship_id ON public.guarantors USING btree (relationship_id);


--
-- Name: idx_legacy_amount; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_legacy_amount ON public.legacy_payment_table USING btree (amount);


--
-- Name: idx_legacy_amount_term_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_legacy_amount_term_unique ON public.legacy_payment_table USING btree (amount, term_biweeks);


--
-- Name: idx_legacy_term; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_legacy_term ON public.legacy_payment_table USING btree (term_biweeks);


--
-- Name: idx_level_change_types_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_level_change_types_name ON public.level_change_types USING btree (name);


--
-- Name: idx_loan_renewals_original_loan_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_loan_renewals_original_loan_id ON public.loan_renewals USING btree (original_loan_id);


--
-- Name: idx_loan_renewals_renewed_loan_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_loan_renewals_renewed_loan_id ON public.loan_renewals USING btree (renewed_loan_id);


--
-- Name: idx_loan_statuses_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_loan_statuses_active ON public.loan_statuses USING btree (is_active);


--
-- Name: idx_loan_statuses_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_loan_statuses_name ON public.loan_statuses USING btree (name);


--
-- Name: idx_loans_approved_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_loans_approved_at ON public.loans USING btree (approved_at) WHERE (approved_at IS NOT NULL);


--
-- Name: idx_loans_associate_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_loans_associate_user_id ON public.loans USING btree (associate_user_id);


--
-- Name: idx_loans_biweekly_payment; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_loans_biweekly_payment ON public.loans USING btree (biweekly_payment) WHERE (biweekly_payment IS NOT NULL);


--
-- Name: idx_loans_profile_code_biweekly; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_loans_profile_code_biweekly ON public.loans USING btree (profile_code, biweekly_payment) WHERE ((profile_code IS NOT NULL) AND (biweekly_payment IS NOT NULL));


--
-- Name: idx_loans_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_loans_status_id ON public.loans USING btree (status_id);


--
-- Name: idx_loans_status_id_approved_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_loans_status_id_approved_at ON public.loans USING btree (status_id, approved_at);


--
-- Name: idx_loans_total_payment; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_loans_total_payment ON public.loans USING btree (total_payment) WHERE (total_payment IS NOT NULL);


--
-- Name: idx_loans_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_loans_user_id ON public.loans USING btree (user_id);


--
-- Name: idx_payment_methods_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_payment_methods_name ON public.payment_methods USING btree (name);


--
-- Name: idx_payment_status_history_change_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_payment_status_history_change_type ON public.payment_status_history USING btree (change_type);


--
-- Name: idx_payment_status_history_changed_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_payment_status_history_changed_at ON public.payment_status_history USING btree (changed_at DESC);


--
-- Name: idx_payment_status_history_changed_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_payment_status_history_changed_by ON public.payment_status_history USING btree (changed_by);


--
-- Name: idx_payment_status_history_new_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_payment_status_history_new_status_id ON public.payment_status_history USING btree (new_status_id);


--
-- Name: idx_payment_status_history_payment_changed_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_payment_status_history_payment_changed_at ON public.payment_status_history USING btree (payment_id, changed_at DESC);


--
-- Name: idx_payment_status_history_payment_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_payment_status_history_payment_id ON public.payment_status_history USING btree (payment_id);


--
-- Name: idx_payment_statuses_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_payment_statuses_active ON public.payment_statuses USING btree (is_active);


--
-- Name: idx_payment_statuses_is_real; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_payment_statuses_is_real ON public.payment_statuses USING btree (is_real_payment);


--
-- Name: idx_payment_statuses_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_payment_statuses_name ON public.payment_statuses USING btree (name);


--
-- Name: idx_payments_balance_remaining; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_payments_balance_remaining ON public.payments USING btree (balance_remaining) WHERE (balance_remaining IS NOT NULL);


--
-- Name: idx_payments_cut_period_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_payments_cut_period_id ON public.payments USING btree (cut_period_id);


--
-- Name: idx_payments_due_date_status_expected; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_payments_due_date_status_expected ON public.payments USING btree (payment_due_date, status_id, expected_amount) WHERE (expected_amount IS NOT NULL);


--
-- Name: idx_payments_expected_amount; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_payments_expected_amount ON public.payments USING btree (expected_amount) WHERE (expected_amount IS NOT NULL);


--
-- Name: idx_payments_is_late; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_payments_is_late ON public.payments USING btree (is_late);


--
-- Name: idx_payments_late_loan; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_payments_late_loan ON public.payments USING btree (loan_id, is_late, payment_due_date);


--
-- Name: idx_payments_loan_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_payments_loan_id ON public.payments USING btree (loan_id);


--
-- Name: idx_payments_loan_number_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_payments_loan_number_unique ON public.payments USING btree (loan_id, payment_number) WHERE (payment_number IS NOT NULL);


--
-- Name: idx_payments_payment_due_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_payments_payment_due_date ON public.payments USING btree (payment_due_date);


--
-- Name: idx_payments_payment_number; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_payments_payment_number ON public.payments USING btree (payment_number) WHERE (payment_number IS NOT NULL);


--
-- Name: idx_payments_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_payments_status_id ON public.payments USING btree (status_id);


--
-- Name: idx_rate_profiles_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rate_profiles_code ON public.rate_profiles USING btree (code);


--
-- Name: idx_rate_profiles_display; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rate_profiles_display ON public.rate_profiles USING btree (display_order);


--
-- Name: idx_rate_profiles_enabled; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rate_profiles_enabled ON public.rate_profiles USING btree (enabled) WHERE (enabled = true);


--
-- Name: idx_session_log_is_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_session_log_is_active ON public.audit_session_log USING btree (is_active);


--
-- Name: idx_session_log_login_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_session_log_login_at ON public.audit_session_log USING btree (login_at DESC);


--
-- Name: idx_session_log_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_session_log_user_id ON public.audit_session_log USING btree (user_id);


--
-- Name: idx_statement_payments_method; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_statement_payments_method ON public.associate_statement_payments USING btree (payment_method_id);


--
-- Name: idx_statement_payments_payment_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_statement_payments_payment_date ON public.associate_statement_payments USING btree (payment_date);


--
-- Name: idx_statement_payments_registered_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_statement_payments_registered_by ON public.associate_statement_payments USING btree (registered_by);


--
-- Name: idx_statement_payments_statement_amount; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_statement_payments_statement_amount ON public.associate_statement_payments USING btree (statement_id, payment_amount);


--
-- Name: idx_statement_payments_statement_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_statement_payments_statement_id ON public.associate_statement_payments USING btree (statement_id);


--
-- Name: idx_statement_statuses_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_statement_statuses_name ON public.statement_statuses USING btree (name);


--
-- Name: idx_users_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_users_active ON public.users USING btree (active);


--
-- Name: idx_users_email_lower; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_users_email_lower ON public.users USING btree (lower((email)::text));


--
-- Name: idx_users_username_lower; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_users_username_lower ON public.users USING btree (lower((username)::text));


--
-- Name: contracts audit_contracts_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_contracts_trigger AFTER INSERT OR DELETE OR UPDATE ON public.contracts FOR EACH ROW EXECUTE FUNCTION public.audit_trigger_function();


--
-- Name: cut_periods audit_cut_periods_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_cut_periods_trigger AFTER INSERT OR DELETE OR UPDATE ON public.cut_periods FOR EACH ROW EXECUTE FUNCTION public.audit_trigger_function();


--
-- Name: loans audit_loans_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_loans_trigger AFTER INSERT OR DELETE OR UPDATE ON public.loans FOR EACH ROW EXECUTE FUNCTION public.audit_trigger_function();


--
-- Name: payments audit_payments_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_payments_trigger AFTER INSERT OR DELETE OR UPDATE ON public.payments FOR EACH ROW EXECUTE FUNCTION public.audit_trigger_function();


--
-- Name: users audit_users_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_users_trigger AFTER INSERT OR DELETE OR UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION public.audit_trigger_function();


--
-- Name: loans handle_loan_approval_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER handle_loan_approval_trigger BEFORE UPDATE ON public.loans FOR EACH ROW EXECUTE FUNCTION public.handle_loan_approval_status();


--
-- Name: loans trigger_generate_payment_schedule; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_generate_payment_schedule AFTER UPDATE OF status_id ON public.loans FOR EACH ROW EXECUTE FUNCTION public.generate_payment_schedule();


--
-- Name: legacy_payment_table trigger_legacy_payment_table_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_legacy_payment_table_updated_at BEFORE UPDATE ON public.legacy_payment_table FOR EACH ROW EXECUTE FUNCTION public.update_legacy_payment_table_timestamp();


--
-- Name: payments trigger_log_payment_status_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_log_payment_status_change AFTER UPDATE OF status_id ON public.payments FOR EACH ROW EXECUTE FUNCTION public.log_payment_status_change();


--
-- Name: associate_profiles trigger_update_associate_credit_on_level_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_update_associate_credit_on_level_change AFTER UPDATE OF level_id ON public.associate_profiles FOR EACH ROW EXECUTE FUNCTION public.trigger_update_associate_credit_on_level_change();


--
-- Name: loans trigger_update_associate_credit_on_loan_approval; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_update_associate_credit_on_loan_approval AFTER UPDATE OF status_id ON public.loans FOR EACH ROW EXECUTE FUNCTION public.trigger_update_associate_credit_on_loan_approval();


--
-- Name: payments trigger_update_associate_credit_on_payment; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_update_associate_credit_on_payment AFTER UPDATE OF amount_paid ON public.payments FOR EACH ROW EXECUTE FUNCTION public.trigger_update_associate_credit_on_payment();


--
-- Name: associate_statement_payments trigger_update_statement_on_payment; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_update_statement_on_payment AFTER INSERT ON public.associate_statement_payments FOR EACH ROW EXECUTE FUNCTION public.update_statement_on_payment();


--
-- Name: addresses update_addresses_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_addresses_updated_at BEFORE UPDATE ON public.addresses FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: associate_debt_payments update_associate_debt_payments_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_associate_debt_payments_updated_at BEFORE UPDATE ON public.associate_debt_payments FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: associate_payment_statements update_associate_payment_statements_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_associate_payment_statements_updated_at BEFORE UPDATE ON public.associate_payment_statements FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: associate_profiles update_associate_profiles_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_associate_profiles_updated_at BEFORE UPDATE ON public.associate_profiles FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: associate_statement_payments update_associate_statement_payments_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_associate_statement_payments_updated_at BEFORE UPDATE ON public.associate_statement_payments FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: beneficiaries update_beneficiaries_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_beneficiaries_updated_at BEFORE UPDATE ON public.beneficiaries FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: client_documents update_client_documents_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_client_documents_updated_at BEFORE UPDATE ON public.client_documents FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: config_types update_config_types_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_config_types_updated_at BEFORE UPDATE ON public.config_types FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: contract_statuses update_contract_statuses_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_contract_statuses_updated_at BEFORE UPDATE ON public.contract_statuses FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: contracts update_contracts_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_contracts_updated_at BEFORE UPDATE ON public.contracts FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: cut_period_statuses update_cut_period_statuses_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_cut_period_statuses_updated_at BEFORE UPDATE ON public.cut_period_statuses FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: cut_periods update_cut_periods_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_cut_periods_updated_at BEFORE UPDATE ON public.cut_periods FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: document_statuses update_document_statuses_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_document_statuses_updated_at BEFORE UPDATE ON public.document_statuses FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: guarantors update_guarantors_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_guarantors_updated_at BEFORE UPDATE ON public.guarantors FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: level_change_types update_level_change_types_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_level_change_types_updated_at BEFORE UPDATE ON public.level_change_types FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: loan_statuses update_loan_statuses_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_loan_statuses_updated_at BEFORE UPDATE ON public.loan_statuses FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: loans update_loans_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_loans_updated_at BEFORE UPDATE ON public.loans FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: payment_methods update_payment_methods_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_payment_methods_updated_at BEFORE UPDATE ON public.payment_methods FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: payments update_payments_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_payments_updated_at BEFORE UPDATE ON public.payments FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: statement_statuses update_statement_statuses_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_statement_statuses_updated_at BEFORE UPDATE ON public.statement_statuses FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: system_configurations update_system_configurations_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_system_configurations_updated_at BEFORE UPDATE ON public.system_configurations FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: users update_users_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: addresses addresses_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.addresses
    ADD CONSTRAINT addresses_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: agreement_items agreement_items_agreement_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agreement_items
    ADD CONSTRAINT agreement_items_agreement_id_fkey FOREIGN KEY (agreement_id) REFERENCES public.agreements(id) ON DELETE CASCADE;


--
-- Name: agreement_items agreement_items_client_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agreement_items
    ADD CONSTRAINT agreement_items_client_user_id_fkey FOREIGN KEY (client_user_id) REFERENCES public.users(id);


--
-- Name: agreement_items agreement_items_loan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agreement_items
    ADD CONSTRAINT agreement_items_loan_id_fkey FOREIGN KEY (loan_id) REFERENCES public.loans(id);


--
-- Name: agreement_payments agreement_payments_agreement_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agreement_payments
    ADD CONSTRAINT agreement_payments_agreement_id_fkey FOREIGN KEY (agreement_id) REFERENCES public.agreements(id) ON DELETE CASCADE;


--
-- Name: agreement_payments agreement_payments_payment_method_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agreement_payments
    ADD CONSTRAINT agreement_payments_payment_method_id_fkey FOREIGN KEY (payment_method_id) REFERENCES public.payment_methods(id);


--
-- Name: agreements agreements_approved_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agreements
    ADD CONSTRAINT agreements_approved_by_fkey FOREIGN KEY (approved_by) REFERENCES public.users(id);


--
-- Name: agreements agreements_associate_profile_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agreements
    ADD CONSTRAINT agreements_associate_profile_id_fkey FOREIGN KEY (associate_profile_id) REFERENCES public.associate_profiles(id) ON DELETE CASCADE;


--
-- Name: agreements agreements_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agreements
    ADD CONSTRAINT agreements_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);


--
-- Name: associate_accumulated_balances associate_accumulated_balances_cut_period_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.associate_accumulated_balances
    ADD CONSTRAINT associate_accumulated_balances_cut_period_id_fkey FOREIGN KEY (cut_period_id) REFERENCES public.cut_periods(id);


--
-- Name: associate_accumulated_balances associate_accumulated_balances_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.associate_accumulated_balances
    ADD CONSTRAINT associate_accumulated_balances_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: associate_debt_payments associate_debt_payments_associate_profile_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.associate_debt_payments
    ADD CONSTRAINT associate_debt_payments_associate_profile_id_fkey FOREIGN KEY (associate_profile_id) REFERENCES public.associate_profiles(id) ON DELETE CASCADE;


--
-- Name: associate_debt_payments associate_debt_payments_payment_method_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.associate_debt_payments
    ADD CONSTRAINT associate_debt_payments_payment_method_id_fkey FOREIGN KEY (payment_method_id) REFERENCES public.payment_methods(id);


--
-- Name: associate_debt_payments associate_debt_payments_registered_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.associate_debt_payments
    ADD CONSTRAINT associate_debt_payments_registered_by_fkey FOREIGN KEY (registered_by) REFERENCES public.users(id);


--
-- Name: associate_level_history associate_level_history_associate_profile_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.associate_level_history
    ADD CONSTRAINT associate_level_history_associate_profile_id_fkey FOREIGN KEY (associate_profile_id) REFERENCES public.associate_profiles(id) ON DELETE CASCADE;


--
-- Name: associate_level_history associate_level_history_change_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.associate_level_history
    ADD CONSTRAINT associate_level_history_change_type_id_fkey FOREIGN KEY (change_type_id) REFERENCES public.level_change_types(id);


--
-- Name: associate_level_history associate_level_history_new_level_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.associate_level_history
    ADD CONSTRAINT associate_level_history_new_level_id_fkey FOREIGN KEY (new_level_id) REFERENCES public.associate_levels(id);


--
-- Name: associate_level_history associate_level_history_old_level_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.associate_level_history
    ADD CONSTRAINT associate_level_history_old_level_id_fkey FOREIGN KEY (old_level_id) REFERENCES public.associate_levels(id);


--
-- Name: associate_payment_statements associate_payment_statements_cut_period_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.associate_payment_statements
    ADD CONSTRAINT associate_payment_statements_cut_period_id_fkey FOREIGN KEY (cut_period_id) REFERENCES public.cut_periods(id);


--
-- Name: associate_payment_statements associate_payment_statements_payment_method_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.associate_payment_statements
    ADD CONSTRAINT associate_payment_statements_payment_method_id_fkey FOREIGN KEY (payment_method_id) REFERENCES public.payment_methods(id);


--
-- Name: associate_payment_statements associate_payment_statements_status_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.associate_payment_statements
    ADD CONSTRAINT associate_payment_statements_status_id_fkey FOREIGN KEY (status_id) REFERENCES public.statement_statuses(id);


--
-- Name: associate_payment_statements associate_payment_statements_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.associate_payment_statements
    ADD CONSTRAINT associate_payment_statements_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: associate_profiles associate_profiles_level_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.associate_profiles
    ADD CONSTRAINT associate_profiles_level_id_fkey FOREIGN KEY (level_id) REFERENCES public.associate_levels(id);


--
-- Name: associate_profiles associate_profiles_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.associate_profiles
    ADD CONSTRAINT associate_profiles_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: associate_statement_payments associate_statement_payments_payment_method_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.associate_statement_payments
    ADD CONSTRAINT associate_statement_payments_payment_method_id_fkey FOREIGN KEY (payment_method_id) REFERENCES public.payment_methods(id);


--
-- Name: associate_statement_payments associate_statement_payments_registered_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.associate_statement_payments
    ADD CONSTRAINT associate_statement_payments_registered_by_fkey FOREIGN KEY (registered_by) REFERENCES public.users(id);


--
-- Name: associate_statement_payments associate_statement_payments_statement_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.associate_statement_payments
    ADD CONSTRAINT associate_statement_payments_statement_id_fkey FOREIGN KEY (statement_id) REFERENCES public.associate_payment_statements(id) ON DELETE CASCADE;


--
-- Name: audit_log audit_log_changed_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_log
    ADD CONSTRAINT audit_log_changed_by_fkey FOREIGN KEY (changed_by) REFERENCES public.users(id);


--
-- Name: audit_session_log audit_session_log_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_session_log
    ADD CONSTRAINT audit_session_log_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: beneficiaries beneficiaries_relationship_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.beneficiaries
    ADD CONSTRAINT beneficiaries_relationship_id_fkey FOREIGN KEY (relationship_id) REFERENCES public.relationships(id);


--
-- Name: beneficiaries beneficiaries_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.beneficiaries
    ADD CONSTRAINT beneficiaries_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: client_documents client_documents_document_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_documents
    ADD CONSTRAINT client_documents_document_type_id_fkey FOREIGN KEY (document_type_id) REFERENCES public.document_types(id);


--
-- Name: client_documents client_documents_reviewed_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_documents
    ADD CONSTRAINT client_documents_reviewed_by_fkey FOREIGN KEY (reviewed_by) REFERENCES public.users(id);


--
-- Name: client_documents client_documents_status_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_documents
    ADD CONSTRAINT client_documents_status_id_fkey FOREIGN KEY (status_id) REFERENCES public.document_statuses(id);


--
-- Name: client_documents client_documents_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_documents
    ADD CONSTRAINT client_documents_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: contracts contracts_loan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contracts
    ADD CONSTRAINT contracts_loan_id_fkey FOREIGN KEY (loan_id) REFERENCES public.loans(id) ON DELETE CASCADE;


--
-- Name: contracts contracts_status_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contracts
    ADD CONSTRAINT contracts_status_id_fkey FOREIGN KEY (status_id) REFERENCES public.contract_statuses(id);


--
-- Name: cut_periods cut_periods_closed_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cut_periods
    ADD CONSTRAINT cut_periods_closed_by_fkey FOREIGN KEY (closed_by) REFERENCES public.users(id);


--
-- Name: cut_periods cut_periods_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cut_periods
    ADD CONSTRAINT cut_periods_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);


--
-- Name: cut_periods cut_periods_status_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cut_periods
    ADD CONSTRAINT cut_periods_status_id_fkey FOREIGN KEY (status_id) REFERENCES public.cut_period_statuses(id);


--
-- Name: defaulted_client_reports defaulted_client_reports_approved_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.defaulted_client_reports
    ADD CONSTRAINT defaulted_client_reports_approved_by_fkey FOREIGN KEY (approved_by) REFERENCES public.users(id);


--
-- Name: defaulted_client_reports defaulted_client_reports_associate_profile_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.defaulted_client_reports
    ADD CONSTRAINT defaulted_client_reports_associate_profile_id_fkey FOREIGN KEY (associate_profile_id) REFERENCES public.associate_profiles(id) ON DELETE CASCADE;


--
-- Name: defaulted_client_reports defaulted_client_reports_client_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.defaulted_client_reports
    ADD CONSTRAINT defaulted_client_reports_client_user_id_fkey FOREIGN KEY (client_user_id) REFERENCES public.users(id);


--
-- Name: defaulted_client_reports defaulted_client_reports_loan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.defaulted_client_reports
    ADD CONSTRAINT defaulted_client_reports_loan_id_fkey FOREIGN KEY (loan_id) REFERENCES public.loans(id);


--
-- Name: defaulted_client_reports defaulted_client_reports_reported_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.defaulted_client_reports
    ADD CONSTRAINT defaulted_client_reports_reported_by_fkey FOREIGN KEY (reported_by) REFERENCES public.users(id);


--
-- Name: loans fk_loans_contract_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.loans
    ADD CONSTRAINT fk_loans_contract_id FOREIGN KEY (contract_id) REFERENCES public.contracts(id);


--
-- Name: loans fk_loans_profile_code; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.loans
    ADD CONSTRAINT fk_loans_profile_code FOREIGN KEY (profile_code) REFERENCES public.rate_profiles(code) ON DELETE SET NULL;


--
-- Name: guarantors guarantors_relationship_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guarantors
    ADD CONSTRAINT guarantors_relationship_id_fkey FOREIGN KEY (relationship_id) REFERENCES public.relationships(id);


--
-- Name: guarantors guarantors_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guarantors
    ADD CONSTRAINT guarantors_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: legacy_payment_table legacy_payment_table_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legacy_payment_table
    ADD CONSTRAINT legacy_payment_table_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);


--
-- Name: legacy_payment_table legacy_payment_table_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legacy_payment_table
    ADD CONSTRAINT legacy_payment_table_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.users(id);


--
-- Name: loan_renewals loan_renewals_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.loan_renewals
    ADD CONSTRAINT loan_renewals_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);


--
-- Name: loan_renewals loan_renewals_original_loan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.loan_renewals
    ADD CONSTRAINT loan_renewals_original_loan_id_fkey FOREIGN KEY (original_loan_id) REFERENCES public.loans(id);


--
-- Name: loan_renewals loan_renewals_renewed_loan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.loan_renewals
    ADD CONSTRAINT loan_renewals_renewed_loan_id_fkey FOREIGN KEY (renewed_loan_id) REFERENCES public.loans(id);


--
-- Name: loans loans_approved_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.loans
    ADD CONSTRAINT loans_approved_by_fkey FOREIGN KEY (approved_by) REFERENCES public.users(id);


--
-- Name: loans loans_associate_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.loans
    ADD CONSTRAINT loans_associate_user_id_fkey FOREIGN KEY (associate_user_id) REFERENCES public.users(id);


--
-- Name: loans loans_rejected_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.loans
    ADD CONSTRAINT loans_rejected_by_fkey FOREIGN KEY (rejected_by) REFERENCES public.users(id);


--
-- Name: loans loans_status_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.loans
    ADD CONSTRAINT loans_status_id_fkey FOREIGN KEY (status_id) REFERENCES public.loan_statuses(id);


--
-- Name: loans loans_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.loans
    ADD CONSTRAINT loans_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: payment_status_history payment_status_history_changed_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_status_history
    ADD CONSTRAINT payment_status_history_changed_by_fkey FOREIGN KEY (changed_by) REFERENCES public.users(id);


--
-- Name: payment_status_history payment_status_history_new_status_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_status_history
    ADD CONSTRAINT payment_status_history_new_status_id_fkey FOREIGN KEY (new_status_id) REFERENCES public.payment_statuses(id);


--
-- Name: payment_status_history payment_status_history_old_status_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_status_history
    ADD CONSTRAINT payment_status_history_old_status_id_fkey FOREIGN KEY (old_status_id) REFERENCES public.payment_statuses(id);


--
-- Name: payment_status_history payment_status_history_payment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_status_history
    ADD CONSTRAINT payment_status_history_payment_id_fkey FOREIGN KEY (payment_id) REFERENCES public.payments(id) ON DELETE CASCADE;


--
-- Name: payments payments_cut_period_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_cut_period_id_fkey FOREIGN KEY (cut_period_id) REFERENCES public.cut_periods(id);


--
-- Name: payments payments_loan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_loan_id_fkey FOREIGN KEY (loan_id) REFERENCES public.loans(id) ON DELETE CASCADE;


--
-- Name: payments payments_marked_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_marked_by_fkey FOREIGN KEY (marked_by) REFERENCES public.users(id);


--
-- Name: payments payments_status_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_status_id_fkey FOREIGN KEY (status_id) REFERENCES public.payment_statuses(id);


--
-- Name: rate_profiles rate_profiles_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rate_profiles
    ADD CONSTRAINT rate_profiles_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);


--
-- Name: rate_profiles rate_profiles_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rate_profiles
    ADD CONSTRAINT rate_profiles_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.users(id);


--
-- Name: system_configurations system_configurations_config_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.system_configurations
    ADD CONSTRAINT system_configurations_config_type_id_fkey FOREIGN KEY (config_type_id) REFERENCES public.config_types(id);


--
-- Name: system_configurations system_configurations_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.system_configurations
    ADD CONSTRAINT system_configurations_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.users(id);


--
-- Name: user_roles user_roles_role_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_roles
    ADD CONSTRAINT user_roles_role_id_fkey FOREIGN KEY (role_id) REFERENCES public.roles(id) ON DELETE CASCADE;


--
-- Name: user_roles user_roles_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_roles
    ADD CONSTRAINT user_roles_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

\unrestrict 5MXCZGcbiGv8fFN1bGMrTpUjmMnkzcHWHylfFuQIWWI0POuTo6uciP8cgOf6UtI

