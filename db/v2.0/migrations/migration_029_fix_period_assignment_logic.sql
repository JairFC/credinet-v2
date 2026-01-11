-- =====================================================================
-- MIGRACIÓN: Corregir lógica de asignación de períodos
-- Fecha: 2026-01-11
-- =====================================================================
-- 
-- PROBLEMA: La función generate_payment_schedule() estaba usando la lógica
-- incorrecta para asignar períodos. Buscaba el período donde la fecha
-- de pago caía dentro del rango (period_start_date <= fecha <= period_end_date),
-- pero la lógica correcta es buscar el período cuyo period_end_date sea
-- INMEDIATAMENTE ANTERIOR a la payment_due_date.
--
-- EJEMPLOS CORRECTOS (préstamo 84 que funcionaba):
--   - Pago 2025-12-15 → Dec08-2025 (termina 2025-12-07) → 8 días después
--   - Pago 2025-12-31 → Dec23-2025 (termina 2025-12-22) → 9 días después
--
-- LÓGICA:
--   El pago del día 15 va al corte del 8 (período anterior)
--   El pago del día 31 va al corte del 23 (período anterior)
-- =====================================================================

-- Corregir la función
CREATE OR REPLACE FUNCTION generate_payment_schedule()
RETURNS TRIGGER AS $$
DECLARE
    v_approval_date DATE;
    v_first_payment_date DATE;
    v_active_status_id INTEGER;
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
BEGIN
    -- Get status IDs
    SELECT id INTO v_active_status_id FROM loan_statuses WHERE name = 'ACTIVE';
    SELECT id INTO v_pending_status_id FROM payment_statuses WHERE name = 'PENDING';

    IF v_active_status_id IS NULL THEN
        RAISE EXCEPTION 'CRITICAL: loan_statuses.ACTIVE not found';
    END IF;

    IF v_pending_status_id IS NULL THEN
        RAISE EXCEPTION 'CRITICAL: payment_statuses.PENDING not found';
    END IF;

    -- Only execute if loan just got activated
    IF NEW.status_id = v_active_status_id
       AND (OLD.status_id IS NULL OR OLD.status_id != v_active_status_id)
    THEN
        v_start_time := CLOCK_TIMESTAMP();

        -- Validations
        IF NEW.approved_at IS NULL THEN
            RAISE EXCEPTION 'CRITICAL: Loan % marked as ACTIVE but approved_at is NULL', NEW.id;
        END IF;

        IF NEW.term_biweeks IS NULL OR NEW.term_biweeks <= 0 THEN
            RAISE EXCEPTION 'CRITICAL: Loan % has invalid term_biweeks: %', NEW.id, NEW.term_biweeks;
        END IF;

        IF NEW.biweekly_payment IS NULL THEN
            RAISE EXCEPTION 'CRITICAL: Loan % does not have biweekly_payment calculated', NEW.id;
        END IF;

        v_approval_date := NEW.approved_at::DATE;
        v_first_payment_date := calculate_first_payment_date(v_approval_date);

        -- Calculate commission rate for the function
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
            -- Accumulate associate payment
            v_cumulative_associate_paid := v_cumulative_associate_paid + v_amortization_row.pago_socio;

            -- ✅ LÓGICA CORRECTA: Buscar el período cuyo period_end_date sea 
            -- INMEDIATAMENTE ANTERIOR a la fecha de pago
            -- (El pago del día 15 va al corte del 8, el del 31 va al corte del 23)
            SELECT id INTO v_period_id
            FROM cut_periods
            WHERE period_end_date < v_amortization_row.fecha_pago
            ORDER BY period_end_date DESC
            LIMIT 1;

            IF v_period_id IS NULL THEN
                RAISE WARNING 'No cut_period found for date %. Payment will have NULL period.',
                    v_amortization_row.fecha_pago;
            END IF;

            -- Insert payment
            INSERT INTO payments (
                loan_id, payment_number, expected_amount,
                principal_amount, interest_amount, commission_amount, associate_payment,
                cumulative_associate_paid, total_associate_payment,
                payment_due_date, status_id, cut_period_id, notes
            ) VALUES (
                NEW.id, v_amortization_row.periodo, v_amortization_row.pago_cliente,
                v_amortization_row.capital_cliente, v_amortization_row.interes_cliente,
                v_amortization_row.comision_socio, v_amortization_row.pago_socio,
                v_cumulative_associate_paid, v_total_associate_payment,
                v_amortization_row.fecha_pago, v_pending_status_id, v_period_id,
                FORMAT('Generado automáticamente - Perfil: %s', COALESCE(NEW.profile_code, 'N/A'))
            );

            v_total_inserted := v_total_inserted + 1;
            v_sum_expected := v_sum_expected + v_amortization_row.pago_cliente;
        END LOOP;

        v_end_time := CLOCK_TIMESTAMP();
        RAISE NOTICE 'Generated % payments in % ms - Total=$%',
            v_total_inserted,
            EXTRACT(MILLISECONDS FROM (v_end_time - v_start_time)),
            v_sum_expected;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- =====================================================================
-- Corregir pagos existentes que estén mal asignados
-- =====================================================================

-- Corregir cualquier pago cuyo cut_period_id tenga period_end_date >= payment_due_date
UPDATE payments p
SET cut_period_id = (
    SELECT cp.id 
    FROM cut_periods cp 
    WHERE cp.period_end_date < p.payment_due_date
    ORDER BY cp.period_end_date DESC 
    LIMIT 1
)
WHERE EXISTS (
    SELECT 1 FROM cut_periods cp 
    WHERE cp.id = p.cut_period_id 
    AND cp.period_end_date >= p.payment_due_date
);

-- Corregir pagos sin período asignado
UPDATE payments p
SET cut_period_id = (
    SELECT cp.id 
    FROM cut_periods cp 
    WHERE cp.period_end_date < p.payment_due_date
    ORDER BY cp.period_end_date DESC 
    LIMIT 1
)
WHERE p.cut_period_id IS NULL;

-- =====================================================================
-- Verificación
-- =====================================================================
DO $$
DECLARE
    v_wrong_count INTEGER;
    v_null_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_wrong_count
    FROM payments p
    JOIN cut_periods cp ON p.cut_period_id = cp.id
    WHERE p.payment_due_date <= cp.period_end_date;
    
    SELECT COUNT(*) INTO v_null_count
    FROM payments
    WHERE cut_period_id IS NULL;
    
    IF v_wrong_count > 0 OR v_null_count > 0 THEN
        RAISE EXCEPTION 'VERIFICACIÓN FALLIDA: % pagos mal asignados, % sin período',
            v_wrong_count, v_null_count;
    ELSE
        RAISE NOTICE 'VERIFICACIÓN OK: Todos los pagos tienen período correcto';
    END IF;
END $$;
