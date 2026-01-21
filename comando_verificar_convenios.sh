docker exec credinet-postgres psql -U credinet_user -d credinet_db -c "
-- 1. Ver si existe tabla agreements
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'public' AND table_name LIKE '%agreement%';

-- 2. Si existe, ver datos
SELECT 'AGREEMENTS' as tipo, COUNT(*) as cantidad FROM agreements;

-- 3. Ver associate_debt_breakdown con tipo AGREEMENT
SELECT debt_type, COUNT(*) as cantidad, SUM(amount) as monto_total 
FROM associate_debt_breakdown 
WHERE debt_type = 'AGREEMENT_DEBT' OR description LIKE '%convenio%'
GROUP BY debt_type;"