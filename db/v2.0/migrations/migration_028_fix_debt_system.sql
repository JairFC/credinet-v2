-- =============================================================================
-- Migration 028: Fix Debt System - Use Real Debt from associate_accumulated_balances
-- =============================================================================
-- 
-- PROBLEMA:
-- - El campo debt_balance en associate_profiles siempre estaba en 0
-- - La vista v_associate_debt_summary usaba associate_debt_breakdown (vacía)
-- - Los abonos a deuda no funcionaban porque no había datos
--
-- SOLUCIÓN:
-- 1. Nueva vista v_associate_real_debt_summary que usa associate_accumulated_balances
-- 2. Función sync_associate_debt_balance para mantener debt_balance actualizado
-- 3. Función apply_debt_payment_v2 para aplicar abonos con FIFO real
-- 4. Sincronización inicial de todos los debt_balance
--
-- =============================================================================

-- 1. NUEVA VISTA: v_associate_real_debt_summary
-- =============================================================================
DROP VIEW IF EXISTS v_associate_real_debt_summary;

CREATE VIEW v_associate_real_debt_summary AS
SELECT 
    ap.id AS associate_profile_id,
    ap.user_id,
    CONCAT(u.first_name, ' ', u.last_name) AS associate_name,
    -- Deuda real desde associate_accumulated_balances
    COALESCE(debt_agg.total_accumulated_debt, 0) AS total_debt,
    COALESCE(debt_agg.periods_with_debt, 0) AS periods_with_debt,
    debt_agg.oldest_debt_date,
    debt_agg.newest_debt_date,
    -- Datos de associate_profiles para info de crédito
    ap.debt_balance AS profile_debt_balance,
    ap.credit_limit,
    ap.credit_available,
    ap.credit_used,
    -- Info de pagos a deuda
    COALESCE(payments_agg.total_paid_to_debt, 0) AS total_paid_to_debt,
    COALESCE(payments_agg.total_payments_count, 0) AS total_payments_count,
    payments_agg.last_payment_date
FROM associate_profiles ap
JOIN users u ON u.id = ap.user_id
LEFT JOIN (
    SELECT 
        user_id,
        SUM(accumulated_debt) AS total_accumulated_debt,
        COUNT(*) AS periods_with_debt,
        MIN(created_at) AS oldest_debt_date,
        MAX(created_at) AS newest_debt_date
    FROM associate_accumulated_balances
    WHERE accumulated_debt > 0
    GROUP BY user_id
) debt_agg ON debt_agg.user_id = ap.user_id
LEFT JOIN (
    SELECT 
        associate_profile_id,
        SUM(payment_amount) AS total_paid_to_debt,
        COUNT(*) AS total_payments_count,
        MAX(payment_date) AS last_payment_date
    FROM associate_debt_payments
    GROUP BY associate_profile_id
) payments_agg ON payments_agg.associate_profile_id = ap.id;


-- 2. FUNCIÓN: sync_associate_debt_balance
-- =============================================================================
CREATE OR REPLACE FUNCTION sync_associate_debt_balance(p_associate_profile_id INTEGER)
RETURNS DECIMAL(12,2) AS $$
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
$$ LANGUAGE plpgsql;


-- 3. FUNCIÓN: apply_debt_payment_v2
-- =============================================================================
CREATE OR REPLACE FUNCTION apply_debt_payment_v2(
    p_associate_profile_id INTEGER,
    p_payment_amount DECIMAL(12,2),
    p_payment_method_id INTEGER,
    p_payment_reference VARCHAR(100),
    p_registered_by INTEGER,
    p_notes TEXT DEFAULT NULL
)
RETURNS TABLE(
    payment_id INTEGER,
    amount_applied DECIMAL(12,2),
    remaining_debt DECIMAL(12,2),
    applied_items JSONB,
    credit_released DECIMAL(12,2)
) AS $$
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
$$ LANGUAGE plpgsql;


-- 4. SINCRONIZACIÓN INICIAL: Actualizar debt_balance para todos los asociados
-- =============================================================================
DO $$
DECLARE
    v_profile RECORD;
    v_new_debt DECIMAL(12,2);
BEGIN
    FOR v_profile IN (SELECT id FROM associate_profiles) LOOP
        v_new_debt := sync_associate_debt_balance(v_profile.id);
        RAISE NOTICE 'Profile %: debt_balance actualizado a %', v_profile.id, v_new_debt;
    END LOOP;
END;
$$;


-- =============================================================================
-- VERIFICACIÓN
-- =============================================================================
DO $$
DECLARE
    v_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_count FROM v_associate_real_debt_summary;
    RAISE NOTICE '✅ Vista v_associate_real_debt_summary creada con % registros', v_count;
    
    SELECT COUNT(*) INTO v_count FROM associate_profiles WHERE debt_balance > 0;
    RAISE NOTICE '✅ Asociados con deuda actualizada: %', v_count;
END;
$$;
