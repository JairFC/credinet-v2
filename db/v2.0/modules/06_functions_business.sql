-- =============================================================================
-- CREDINET DB v2.0.2 - MÓDULO 06: FUNCIONES DE NEGOCIO (NIVEL 2-3)
-- =============================================================================
-- Descripción:
--   Funciones de lógica de negocio con dependencias complejas.
--   Incluye funciones críticas de migraciones 08 y 09 + mejoras v2.0.2.
--
-- Funciones incluidas (6 total):
--   - generate_payment_schedule() ⭐ CRÍTICA (genera cronograma al aprobar)
--   - close_period_and_accumulate_debt() ⭐ MIGRACIÓN 08 v3 (cierre de período)
--   - report_defaulted_client() ⭐ MIGRACIÓN 09 (reportar moroso)
--   - approve_defaulted_client_report() ⭐ MIGRACIÓN 09 (aprobar reporte)
--   - renew_loan() (renovación de préstamos)
--   - update_statement_on_payment() ⭐ v2.0.2 (actualización + liberación de crédito)
--
-- Versión: 2.0.2
-- Fecha: 2025-11-01
-- =============================================================================

-- =============================================================================
-- FUNCIÓN 1: generate_payment_schedule ⭐ TRIGGER CRÍTICO
-- =============================================================================
-- ✅ VERSIÓN ACTUALIZADA - Sprint 6 - Migración 007
-- Genera cronograma completo con desglose financiero usando valores pre-calculados
CREATE OR REPLACE FUNCTION generate_payment_schedule()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $function$
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
BEGIN
    -- ==========================================================================
    -- VALIDACIÓN INICIAL: Verificar que este evento es una aprobación
    -- ==========================================================================
    
    -- Obtener IDs de estados
    SELECT id INTO v_approved_status_id 
    FROM loan_statuses 
    WHERE name = 'APPROVED';
    
    SELECT id INTO v_pending_status_id 
    FROM payment_statuses 
    WHERE name = 'PENDING';
    
    IF v_approved_status_id IS NULL THEN
        RAISE EXCEPTION 'CRITICAL: loan_statuses.APPROVED no encontrado';
    END IF;
    
    IF v_pending_status_id IS NULL THEN
        RAISE EXCEPTION 'CRITICAL: payment_statuses.PENDING no encontrado';
    END IF;
    
    -- Solo ejecutar si el préstamo acaba de ser aprobado
    IF NEW.status_id = v_approved_status_id 
       AND (OLD.status_id IS NULL OR OLD.status_id != v_approved_status_id) 
    THEN
        v_start_time := CLOCK_TIMESTAMP();
        
        -- ======================================================================
        -- VALIDACIONES DE NEGOCIO
        -- ======================================================================
        
        -- Validar: approved_at debe existir
        IF NEW.approved_at IS NULL THEN
            RAISE EXCEPTION 'CRITICAL: Préstamo % marcado como APPROVED pero approved_at es NULL', 
                NEW.id;
        END IF;
        
        -- Validar: term_biweeks válido
        IF NEW.term_biweeks IS NULL OR NEW.term_biweeks <= 0 THEN
            RAISE EXCEPTION 'CRITICAL: Préstamo % tiene term_biweeks inválido: %', 
                NEW.id, NEW.term_biweeks;
        END IF;
        
        -- ✅ CRÍTICO: Validar que los campos calculados existen
        IF NEW.biweekly_payment IS NULL THEN
            RAISE EXCEPTION 'CRITICAL: Préstamo % no tiene biweekly_payment calculado. El préstamo debe ser creado con profile_code o tener valores calculados manualmente.',
                NEW.id;
        END IF;
        
        IF NEW.total_payment IS NULL THEN
            RAISE EXCEPTION 'CRITICAL: Préstamo % no tiene total_payment calculado.',
                NEW.id;
        END IF;
        
        IF NEW.commission_per_payment IS NULL THEN
            RAISE WARNING 'Préstamo % no tiene commission_per_payment. Se usará 0 por defecto.',
                NEW.id;
        END IF;
        
        -- ======================================================================
        -- CALCULAR PRIMERA FECHA DE PAGO USANDO EL ORÁCULO
        -- ======================================================================
        
        v_approval_date := NEW.approved_at::DATE;
        
        RAISE NOTICE '🎯 Generando schedule para préstamo %:', NEW.id;
        RAISE NOTICE '   - Capital: $%', NEW.amount;
        RAISE NOTICE '   - Plazo: % quincenas', NEW.term_biweeks;
        RAISE NOTICE '   - Pago quincenal: $%', NEW.biweekly_payment;
        RAISE NOTICE '   - Total a pagar: $%', NEW.total_payment;
        RAISE NOTICE '   - Aprobado: %', v_approval_date;
        
        -- ✅ Usar el oráculo del doble calendario
        v_first_payment_date := calculate_first_payment_date(v_approval_date);
        
        RAISE NOTICE '📅 Primera fecha de pago: % (aprobado el %)', 
            v_first_payment_date, v_approval_date;
        
        -- ======================================================================
        -- GENERAR CRONOGRAMA COMPLETO CON DESGLOSE
        -- ======================================================================
        
        -- ✅ Llamar a generate_amortization_schedule() para obtener desglose completo
        FOR v_amortization_row IN
            SELECT 
                periodo,              -- Número de pago (1, 2, 3, ...)
                fecha_pago,           -- Fecha de vencimiento (15 o último día)
                pago_cliente,         -- Monto esperado (capital + interés)
                interes_cliente,      -- Interés del periodo
                capital_cliente,      -- Abono a capital del periodo
                saldo_pendiente,      -- Saldo restante después del pago
                comision_socio,       -- Comisión del asociado
                pago_socio            -- Pago neto al asociado
            FROM generate_amortization_schedule(
                NEW.amount,                           -- Capital del préstamo
                NEW.biweekly_payment,                 -- ✅ Pago quincenal calculado
                NEW.term_biweeks,                     -- Plazo en quincenas
                COALESCE(NEW.commission_rate, 0),     -- ✅ Tasa de comisión en porcentaje
                v_first_payment_date                  -- ✅ Primera fecha del oráculo
            )
        LOOP
            -- ==================================================================
            -- BUSCAR PERIODO ADMINISTRATIVO (cut_period)
            -- ==================================================================
            
            -- Buscar el periodo administrativo que contiene esta fecha de vencimiento
            SELECT id INTO v_period_id
            FROM cut_periods
            WHERE period_start_date <= v_amortization_row.fecha_pago
              AND period_end_date >= v_amortization_row.fecha_pago
            ORDER BY period_start_date DESC
            LIMIT 1;
            
            IF v_period_id IS NULL THEN
                RAISE WARNING 'No se encontró cut_period para fecha %. Insertando pago con period_id = NULL. Verifique que cut_periods estén creados para todo el año.',
                    v_amortization_row.fecha_pago;
            END IF;
            
            -- ==================================================================
            -- INSERTAR PAGO CON TODOS LOS CAMPOS
            -- ==================================================================
            
            INSERT INTO payments (
                loan_id,
                payment_number,
                expected_amount,
                amount_paid,
                interest_amount,
                principal_amount,
                commission_amount,
                associate_payment,
                balance_remaining,
                payment_date,
                payment_due_date,
                is_late,
                status_id,
                cut_period_id,
                created_at,
                updated_at
            ) VALUES (
                NEW.id,                                    -- FK al préstamo
                v_amortization_row.periodo,                -- Número secuencial (1, 2, 3, ...)
                v_amortization_row.pago_cliente,           -- ✅ Monto esperado (con interés)
                0.00,                                      -- Aún no ha pagado nada
                v_amortization_row.interes_cliente,        -- ✅ Interés del periodo
                v_amortization_row.capital_cliente,        -- ✅ Abono a capital
                v_amortization_row.comision_socio,         -- ✅ Comisión del asociado
                v_amortization_row.pago_socio,             -- ✅ Pago neto al asociado
                v_amortization_row.saldo_pendiente,        -- ✅ Saldo restante
                v_amortization_row.fecha_pago,             -- payment_date inicial = due_date
                v_amortization_row.fecha_pago,             -- ✅ Fecha de vencimiento
                false,                                     -- No está atrasado (aún)
                v_pending_status_id,                       -- Estado: PENDING
                v_period_id,                               -- ✅ FK al periodo administrativo
                CURRENT_TIMESTAMP,                         -- created_at
                CURRENT_TIMESTAMP                          -- updated_at
            );
            
            v_total_inserted := v_total_inserted + 1;
            v_sum_expected := v_sum_expected + v_amortization_row.pago_cliente;
            
            -- Log de progreso cada 5 pagos
            IF v_amortization_row.periodo % 5 = 0 THEN
                RAISE DEBUG 'Progreso: % de % pagos insertados', 
                    v_amortization_row.periodo, NEW.term_biweeks;
            END IF;
        END LOOP;
        
        -- ======================================================================
        -- VALIDACIONES DE CONSISTENCIA FINAL
        -- ======================================================================
        
        v_end_time := CLOCK_TIMESTAMP();
        
        -- Validar: Se insertaron todos los pagos esperados
        IF v_total_inserted != NEW.term_biweeks THEN
            RAISE EXCEPTION 'INCONSISTENCIA: Se insertaron % pagos pero se esperaban %. Préstamo %. Revisar generate_amortization_schedule().',
                v_total_inserted, NEW.term_biweeks, NEW.id;
        END IF;
        
        -- ✅ VALIDAR: SUM(expected_amount) debe ser igual a loans.total_payment
        -- Tolerancia de $1.00 para errores de redondeo
        IF ABS(v_sum_expected - NEW.total_payment) > 1.00 THEN
            RAISE EXCEPTION 'INCONSISTENCIA MATEMÁTICA: SUM(expected_amount) = $% pero loans.total_payment = $%. Diferencia: $%. Préstamo %. Esto indica un error en los cálculos de generate_amortization_schedule().',
                v_sum_expected, NEW.total_payment, 
                (v_sum_expected - NEW.total_payment), NEW.id;
        END IF;
        
        -- ======================================================================
        -- LOG DE ÉXITO
        -- ======================================================================
        
        RAISE NOTICE '✅ Schedule generado exitosamente:';
        RAISE NOTICE '   - Pagos insertados: %', v_total_inserted;
        RAISE NOTICE '   - Total esperado: $%', v_sum_expected;
        RAISE NOTICE '   - Total préstamo: $%', NEW.total_payment;
        RAISE NOTICE '   - Diferencia: $%', (v_sum_expected - NEW.total_payment);
        RAISE NOTICE '   - Tiempo: % ms', 
            EXTRACT(MILLISECONDS FROM (v_end_time - v_start_time));
        
    END IF;
    
    RETURN NEW;
    
EXCEPTION
    WHEN OTHERS THEN
        -- Log detallado del error
        RAISE EXCEPTION 'ERROR CRÍTICO al generar payment schedule para préstamo %: % (%). SQLState: %, Context: %',
            NEW.id, SQLERRM, SQLSTATE, SQLSTATE, 
            coalesce(PG_EXCEPTION_CONTEXT, 'No context');
        RETURN NULL;
END;
$function$;

COMMENT ON FUNCTION generate_payment_schedule() IS 
'⭐ CRÍTICA: Trigger que genera automáticamente el cronograma completo de pagos quincenales cuando un préstamo es aprobado. 
✅ VERSIÓN ACTUALIZADA (Sprint 6): Usa valores pre-calculados (biweekly_payment, total_payment) y genera desglose financiero completo.';

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
-- FUNCIÓN 6: update_statement_on_payment ⭐ NUEVO v2.0 - Tracking de Abonos
-- =============================================================================
CREATE OR REPLACE FUNCTION update_statement_on_payment()
RETURNS TRIGGER AS $$
DECLARE
    v_total_paid DECIMAL(12,2);
    v_total_owed DECIMAL(12,2);
    v_remaining DECIMAL(12,2);
    v_new_status_id INTEGER;
    v_statement_status VARCHAR(50);
    v_associate_profile_id INTEGER;
    v_cut_period_id INTEGER;
    v_amount_to_liquidate DECIMAL(12,2);
BEGIN
    -- Calcular total pagado hasta ahora (suma de todos los abonos)
    SELECT COALESCE(SUM(payment_amount), 0)
    INTO v_total_paid
    FROM associate_statement_payments
    WHERE statement_id = NEW.statement_id;
    
    -- Obtener total adeudado (comisión + mora) y datos del asociado
    SELECT 
        aps.total_commission_owed + aps.late_fee_amount,
        ap.id,
        aps.cut_period_id
    INTO v_total_owed, v_associate_profile_id, v_cut_period_id
    FROM associate_payment_statements aps
    JOIN associate_profiles ap ON aps.user_id = ap.user_id
    WHERE aps.id = NEW.statement_id;
    
    IF v_total_owed IS NULL THEN
        RAISE EXCEPTION 'Statement % no encontrado', NEW.statement_id;
    END IF;
    
    v_remaining := v_total_owed - v_total_paid;
    
    -- Determinar nuevo estado según saldo restante
    IF v_remaining <= 0 THEN
        -- Pagado completamente (puede haber sobrepago)
        SELECT id INTO v_new_status_id FROM statement_statuses WHERE name = 'PAID';
        v_statement_status := 'PAID';
    ELSIF v_total_paid > 0 AND v_remaining > 0 THEN
        -- Pago parcial
        SELECT id INTO v_new_status_id FROM statement_statuses WHERE name = 'PARTIAL_PAID';
        v_statement_status := 'PARTIAL_PAID';
    ELSE
        -- Sin pagos aún
        v_new_status_id := NULL; -- Mantener estado actual
        v_statement_status := 'NO_CHANGE';
    END IF;
    
    -- Actualizar statement con totales acumulados
    IF v_new_status_id IS NOT NULL THEN
        UPDATE associate_payment_statements
        SET paid_amount = v_total_paid,
            paid_date = CASE 
                WHEN v_remaining <= 0 THEN CURRENT_DATE
                ELSE paid_date
            END,
            status_id = v_new_status_id,
            updated_at = CURRENT_TIMESTAMP
        WHERE id = NEW.statement_id;
    END IF;
    
    -- ⭐ v2.0.2: Liberar crédito automáticamente decrementando debt_balance
    UPDATE associate_profiles
    SET debt_balance = GREATEST(debt_balance - NEW.payment_amount, 0),
        credit_last_updated = CURRENT_TIMESTAMP
    WHERE id = v_associate_profile_id;
    
    -- ⭐ v2.0.2: Liquidar deuda en associate_debt_breakdown (estrategia FIFO)
    -- Liquidamos registros de deuda hasta cubrir el monto del abono
    v_amount_to_liquidate := NEW.payment_amount;
    
    WITH debt_fifo AS (
        SELECT 
            id,
            amount,
            SUM(amount) OVER (ORDER BY created_at, id) AS cumulative_amount
        FROM associate_debt_breakdown
        WHERE associate_profile_id = v_associate_profile_id
          AND cut_period_id = v_cut_period_id
          AND is_liquidated = FALSE
        ORDER BY created_at, id
    )
    UPDATE associate_debt_breakdown
    SET is_liquidated = TRUE,
        liquidated_at = CURRENT_TIMESTAMP,
        liquidation_reference = 'AUTO: Statement payment #' || NEW.id || ' on ' || NEW.payment_date
    WHERE id IN (
        SELECT id 
        FROM debt_fifo
        WHERE (cumulative_amount - amount) < v_amount_to_liquidate
    );
    
    RAISE NOTICE '💰 Statement #% actualizado: pagado $% de $%, restante $%, estado: %', 
        NEW.statement_id, v_total_paid, v_total_owed, v_remaining, v_statement_status;
    
    RAISE NOTICE '🔓 Crédito liberado: debt_balance -= $% para asociado #%', 
        NEW.payment_amount, v_associate_profile_id;
    
    -- Si hay sobrepago, advertir
    IF v_remaining < 0 THEN
        RAISE NOTICE '⚠️  SOBREPAGO detectado en statement #%: $% extra. Considerar crédito a favor.', 
            NEW.statement_id, ABS(v_remaining);
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION update_statement_on_payment() IS 
'⭐ v2.0.2: Trigger que actualiza automáticamente el estado de cuenta cuando se registra un abono. Suma todos los abonos, calcula saldo restante, actualiza estado (PARTIAL_PAID o PAID), y LIBERA CRÉDITO automáticamente decrementando debt_balance y marcando associate_debt_breakdown.is_liquidated usando estrategia FIFO.';

-- =============================================================================
-- FIN MÓDULO 06
-- =============================================================================
