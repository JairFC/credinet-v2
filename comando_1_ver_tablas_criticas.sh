docker exec credinet-postgres psql -U credinet_user -d credinet_db -c "
-- Ver payment_statuses
SELECT 'payment_statuses' as tabla, id, name, description FROM payment_statuses;

-- Ver cut_periods  
SELECT 'cut_periods' as tabla, id, period_name, start_date, end_date FROM cut_periods LIMIT 5;

-- Ver payments (primeros registros)
SELECT 'payments' as tabla, id, loan_id, status_id, cut_period_id, payment_number, amount_paid, expected_amount
FROM payments LIMIT 5;
"