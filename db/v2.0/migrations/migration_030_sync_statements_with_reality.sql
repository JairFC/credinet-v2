-- =====================================================================
-- MIGRACIÓN: Sincronizar statements con datos reales de payments
-- Fecha: 2026-01-11
-- =====================================================================
-- 
-- PROBLEMA: Los associate_payment_statements tienen datos desincronizados
-- después de las migraciones que cambiaron la asignación de períodos.
-- Los totales guardados ya no corresponden a los payments reales.
--
-- SOLUCIÓN: Recalcular todos los totales desde los payments reales.
-- =====================================================================

-- Recalcular con la lógica correcta (filtrar por associate_user_id)
WITH statement_reality AS (
    SELECT 
        aps.id as statement_id,
        (
            SELECT COUNT(*)
            FROM payments p
            JOIN loans l ON p.loan_id = l.id
            WHERE p.cut_period_id = aps.cut_period_id 
              AND l.associate_user_id = aps.user_id
        ) as real_payments_count,
        (
            SELECT COALESCE(SUM(p.expected_amount), 0)
            FROM payments p
            JOIN loans l ON p.loan_id = l.id
            WHERE p.cut_period_id = aps.cut_period_id 
              AND l.associate_user_id = aps.user_id
        ) as real_total_collected,
        (
            SELECT COALESCE(SUM(p.commission_amount), 0)
            FROM payments p
            JOIN loans l ON p.loan_id = l.id
            WHERE p.cut_period_id = aps.cut_period_id 
              AND l.associate_user_id = aps.user_id
        ) as real_commission,
        (
            SELECT COALESCE(SUM(p.associate_payment), 0)
            FROM payments p
            JOIN loans l ON p.loan_id = l.id
            WHERE p.cut_period_id = aps.cut_period_id 
              AND l.associate_user_id = aps.user_id
        ) as real_to_credicuenta
    FROM associate_payment_statements aps
)
UPDATE associate_payment_statements aps
SET 
    total_payments_count = sr.real_payments_count,
    total_amount_collected = sr.real_total_collected,
    commission_earned = sr.real_commission,
    total_to_credicuenta = sr.real_to_credicuenta,
    updated_at = NOW()
FROM statement_reality sr
WHERE aps.id = sr.statement_id;

-- =====================================================================
-- Verificación
-- =====================================================================
DO $$
DECLARE
    v_desync_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_desync_count
    FROM associate_payment_statements aps
    WHERE aps.total_payments_count != (
        SELECT COUNT(*) FROM payments p JOIN loans l ON p.loan_id = l.id 
        WHERE p.cut_period_id = aps.cut_period_id AND l.associate_user_id = aps.user_id
    );
    
    IF v_desync_count > 0 THEN
        RAISE EXCEPTION 'VERIFICACIÓN FALLIDA: % statements desincronizados', v_desync_count;
    ELSE
        RAISE NOTICE 'VERIFICACIÓN OK: Todos los statements sincronizados';
    END IF;
END $$;
