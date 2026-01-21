docker exec credinet-postgres psql -U credinet_user -d credinet_db -c "
SELECT 
    id,
    user_id as client_id,
    associate_user_id as associate_id,
    amount,
    term_biweeks,
    interest_rate,
    commission_rate,
    status_id,
    -- CAMPOS DE PAGOS CRÍTICOS
    biweekly_payment,
    total_payment,
    commission_per_payment,
    associate_payment,
    -- FECHAS
    approved_at,
    created_at,
    updated_at
FROM loans 
WHERE id = 2;
"