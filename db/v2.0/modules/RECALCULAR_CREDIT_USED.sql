-- =============================================================================
-- RECALCULAR credit_used DE TODOS LOS ASOCIADOS
-- =============================================================================
-- Fecha: 2026-01-07
-- 
-- Problema: credit_used actual está calculado con loan.amount (solo capital)
--           Debe ser recalculado con SUM(associate_payment) de pagos PENDING
--
-- Ejemplo:
--   ANTES: credit_used = $22,000 (solo capital)
--   AHORA: credit_used = $30,745 (lo que debe pagar a CrediCuenta)
-- =============================================================================

-- Paso 1: Ver el estado actual (para comparar después)
SELECT 
    ap.id,
    (u.first_name || ' ' || u.last_name) as nombre,
    ap.credit_limit::numeric(12,2),
    ap.credit_used::numeric(12,2) as credit_used_VIEJO,
    ap.credit_available::numeric(12,2),
    -- Calcular lo que DEBERÍA ser
    COALESCE(
        (SELECT SUM(p.associate_payment)
         FROM payments p
         JOIN loans l ON l.id = p.loan_id
         JOIN payment_statuses ps ON ps.id = p.status_id
         WHERE l.associate_user_id = ap.user_id
         AND ps.name = 'PENDING'), 
        0
    )::numeric(12,2) as credit_used_NUEVO
FROM associate_profiles ap
JOIN users u ON u.id = ap.user_id
WHERE ap.credit_used > 0
ORDER BY ap.id;

-- Paso 2: Backup de valores actuales (por si acaso)
CREATE TEMP TABLE IF NOT EXISTS backup_credit_used AS
SELECT 
    id,
    user_id,
    credit_limit,
    credit_used as credit_used_old,
    credit_available as credit_available_old,
    CURRENT_TIMESTAMP as backup_timestamp
FROM associate_profiles;

-- Paso 3: RECALCULAR credit_used de todos los asociados
UPDATE associate_profiles ap
SET 
    credit_used = COALESCE(
        (SELECT SUM(p.associate_payment)
         FROM payments p
         JOIN loans l ON l.id = p.loan_id
         JOIN payment_statuses ps ON ps.id = p.status_id
         WHERE l.associate_user_id = ap.user_id
         AND ps.name = 'PENDING'), 
        0
    ),
    credit_last_updated = CURRENT_TIMESTAMP;

-- Paso 4: Mostrar el resultado de la corrección
SELECT 
    ap.id,
    (u.first_name || ' ' || u.last_name) as nombre,
    b.credit_used_old::numeric(12,2),
    ap.credit_used::numeric(12,2) as credit_used_nuevo,
    (ap.credit_used - b.credit_used_old)::numeric(12,2) as diferencia,
    ap.credit_limit::numeric(12,2),
    (ap.credit_limit - ap.credit_used)::numeric(12,2) as credit_available_nuevo,
    CASE 
        WHEN ABS(ap.credit_used - b.credit_used_old) > 0.01 THEN '✅ CORREGIDO'
        ELSE '✓ Sin cambios'
    END as estado
FROM associate_profiles ap
JOIN users u ON u.id = ap.user_id
JOIN backup_credit_used b ON b.id = ap.id
WHERE b.credit_used_old > 0 OR ap.credit_used > 0
ORDER BY ABS(ap.credit_used - b.credit_used_old) DESC;

-- =============================================================================
-- VALIDACIÓN: Confirmar que credit_used ahora refleja associate_payment
-- =============================================================================

-- Query de validación detallada para un asociado
-- SELECT 
--     u.full_name,
--     l.id as loan_id,
--     l.amount as capital,
--     COUNT(p.id) as total_pagos,
--     COUNT(CASE WHEN ps.name = 'PENDING' THEN 1 END) as pagos_pendientes,
--     SUM(CASE WHEN ps.name = 'PENDING' THEN p.expected_amount ELSE 0 END)::numeric(10,2) as pending_expected,
--     SUM(CASE WHEN ps.name = 'PENDING' THEN p.commission_amount ELSE 0 END)::numeric(10,2) as pending_commission,
--     SUM(CASE WHEN ps.name = 'PENDING' THEN p.associate_payment ELSE 0 END)::numeric(10,2) as pending_associate_payment
-- FROM loans l
-- JOIN users u ON u.id = l.associate_user_id
-- JOIN payments p ON p.loan_id = l.id
-- JOIN payment_statuses ps ON ps.id = p.status_id
-- WHERE u.id = 1  -- Cambiar por el ID del asociado
-- GROUP BY u.full_name, l.id, l.amount;

-- =============================================================================
-- FIN DE RECÁLCULO
-- =============================================================================
