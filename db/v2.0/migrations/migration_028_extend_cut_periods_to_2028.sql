-- ============================================================================
-- MIGRACIÓN 028: Extender cut_periods hasta diciembre 2028
-- ============================================================================
-- Fecha: 2026-01-11
-- Descripción:
--   Agrega períodos de corte desde 2027-01-08 hasta 2028-12-31
--   para soportar préstamos con plazos largos (hasta 52 quincenas = 26 meses)
--
-- Razón:
--   El sistema estaba insertando pagos con cut_period_id = NULL
--   cuando las fechas de pago caían fuera del rango de períodos existentes.
--   Esto causaba que apareciera "N/A" en los reportes.
--
-- Estructura de períodos:
--   - Alternancia: 15 de cada mes (Periodo A) y último día (Periodo B)
--   - Status: 1 (PENDING) para períodos futuros
--   - 48 períodos nuevos (24 meses × 2 periodos/mes) = hasta Dec 2028
-- ============================================================================

BEGIN;

-- Obtener el último cut_number existente
DO $$
DECLARE
    v_last_cut_number INTEGER;
    v_current_cut_number INTEGER;
    v_year INTEGER;
    v_month INTEGER;
    v_start_date DATE;
    v_end_date DATE;
    v_status_id INTEGER := 1; -- PENDING
    v_created_by INTEGER := 1; -- Sistema
    v_period_type CHAR(1);
    v_cut_code VARCHAR(20);
BEGIN
    -- Obtener el último cut_number
    SELECT COALESCE(MAX(cut_number), 0) INTO v_last_cut_number
    FROM cut_periods;
    
    v_current_cut_number := v_last_cut_number;
    
    RAISE NOTICE 'Último cut_number existente: %', v_last_cut_number;
    RAISE NOTICE 'Generando períodos desde 2027-01-08 hasta 2028-12-31...';
    
    -- ========================================================================
    -- 2027
    -- ========================================================================
    
    -- 2027 Q01 (Jan 08-22) - Periodo A
    v_current_cut_number := v_current_cut_number + 1;
    INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission)
    VALUES (v_current_cut_number, '2027-Q01', '2027-01-08', '2027-01-22', v_status_id, v_created_by, 0.00, 0.00, 0.00);
    
    -- 2027 Q02 (Jan 23 - Feb 07) - Periodo B
    v_current_cut_number := v_current_cut_number + 1;
    INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission)
    VALUES (v_current_cut_number, '2027-Q02', '2027-01-23', '2027-02-07', v_status_id, v_created_by, 0.00, 0.00, 0.00);
    
    -- 2027 Q03 (Feb 08-22) - Periodo A
    v_current_cut_number := v_current_cut_number + 1;
    INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission)
    VALUES (v_current_cut_number, '2027-Q03', '2027-02-08', '2027-02-22', v_status_id, v_created_by, 0.00, 0.00, 0.00);
    
    -- 2027 Q04 (Feb 23 - Mar 07) - Periodo B
    v_current_cut_number := v_current_cut_number + 1;
    INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission)
    VALUES (v_current_cut_number, '2027-Q04', '2027-02-23', '2027-03-07', v_status_id, v_created_by, 0.00, 0.00, 0.00);
    
    -- 2027 Q05 (Mar 08-22) - Periodo A
    v_current_cut_number := v_current_cut_number + 1;
    INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission)
    VALUES (v_current_cut_number, '2027-Q05', '2027-03-08', '2027-03-22', v_status_id, v_created_by, 0.00, 0.00, 0.00);
    
    -- 2027 Q06 (Mar 23 - Apr 07) - Periodo B
    v_current_cut_number := v_current_cut_number + 1;
    INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission)
    VALUES (v_current_cut_number, '2027-Q06', '2027-03-23', '2027-04-07', v_status_id, v_created_by, 0.00, 0.00, 0.00);
    
    -- 2027 Q07 (Apr 08-22) - Periodo A
    v_current_cut_number := v_current_cut_number + 1;
    INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission)
    VALUES (v_current_cut_number, '2027-Q07', '2027-04-08', '2027-04-22', v_status_id, v_created_by, 0.00, 0.00, 0.00);
    
    -- 2027 Q08 (Apr 23 - May 07) - Periodo B
    v_current_cut_number := v_current_cut_number + 1;
    INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission)
    VALUES (v_current_cut_number, '2027-Q08', '2027-04-23', '2027-05-07', v_status_id, v_created_by, 0.00, 0.00, 0.00);
    
    -- 2027 Q09 (May 08-22) - Periodo A
    v_current_cut_number := v_current_cut_number + 1;
    INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission)
    VALUES (v_current_cut_number, '2027-Q09', '2027-05-08', '2027-05-22', v_status_id, v_created_by, 0.00, 0.00, 0.00);
    
    -- 2027 Q10 (May 23 - Jun 07) - Periodo B
    v_current_cut_number := v_current_cut_number + 1;
    INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission)
    VALUES (v_current_cut_number, '2027-Q10', '2027-05-23', '2027-06-07', v_status_id, v_created_by, 0.00, 0.00, 0.00);
    
    -- 2027 Q11 (Jun 08-22) - Periodo A
    v_current_cut_number := v_current_cut_number + 1;
    INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission)
    VALUES (v_current_cut_number, '2027-Q11', '2027-06-08', '2027-06-22', v_status_id, v_created_by, 0.00, 0.00, 0.00);
    
    -- 2027 Q12 (Jun 23 - Jul 07) - Periodo B
    v_current_cut_number := v_current_cut_number + 1;
    INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission)
    VALUES (v_current_cut_number, '2027-Q12', '2027-06-23', '2027-07-07', v_status_id, v_created_by, 0.00, 0.00, 0.00);
    
    -- 2027 Q13 (Jul 08-22) - Periodo A
    v_current_cut_number := v_current_cut_number + 1;
    INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission)
    VALUES (v_current_cut_number, '2027-Q13', '2027-07-08', '2027-07-22', v_status_id, v_created_by, 0.00, 0.00, 0.00);
    
    -- 2027 Q14 (Jul 23 - Aug 07) - Periodo B
    v_current_cut_number := v_current_cut_number + 1;
    INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission)
    VALUES (v_current_cut_number, '2027-Q14', '2027-07-23', '2027-08-07', v_status_id, v_created_by, 0.00, 0.00, 0.00);
    
    -- 2027 Q15 (Aug 08-22) - Periodo A
    v_current_cut_number := v_current_cut_number + 1;
    INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission)
    VALUES (v_current_cut_number, '2027-Q15', '2027-08-08', '2027-08-22', v_status_id, v_created_by, 0.00, 0.00, 0.00);
    
    -- 2027 Q16 (Aug 23 - Sep 07) - Periodo B
    v_current_cut_number := v_current_cut_number + 1;
    INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission)
    VALUES (v_current_cut_number, '2027-Q16', '2027-08-23', '2027-09-07', v_status_id, v_created_by, 0.00, 0.00, 0.00);
    
    -- 2027 Q17 (Sep 08-22) - Periodo A
    v_current_cut_number := v_current_cut_number + 1;
    INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission)
    VALUES (v_current_cut_number, '2027-Q17', '2027-09-08', '2027-09-22', v_status_id, v_created_by, 0.00, 0.00, 0.00);
    
    -- 2027 Q18 (Sep 23 - Oct 07) - Periodo B
    v_current_cut_number := v_current_cut_number + 1;
    INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission)
    VALUES (v_current_cut_number, '2027-Q18', '2027-09-23', '2027-10-07', v_status_id, v_created_by, 0.00, 0.00, 0.00);
    
    -- 2027 Q19 (Oct 08-22) - Periodo A
    v_current_cut_number := v_current_cut_number + 1;
    INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission)
    VALUES (v_current_cut_number, '2027-Q19', '2027-10-08', '2027-10-22', v_status_id, v_created_by, 0.00, 0.00, 0.00);
    
    -- 2027 Q20 (Oct 23 - Nov 07) - Periodo B
    v_current_cut_number := v_current_cut_number + 1;
    INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission)
    VALUES (v_current_cut_number, '2027-Q20', '2027-10-23', '2027-11-07', v_status_id, v_created_by, 0.00, 0.00, 0.00);
    
    -- 2027 Q21 (Nov 08-22) - Periodo A
    v_current_cut_number := v_current_cut_number + 1;
    INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission)
    VALUES (v_current_cut_number, '2027-Q21', '2027-11-08', '2027-11-22', v_status_id, v_created_by, 0.00, 0.00, 0.00);
    
    -- 2027 Q22 (Nov 23 - Dec 07) - Periodo B
    v_current_cut_number := v_current_cut_number + 1;
    INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission)
    VALUES (v_current_cut_number, '2027-Q22', '2027-11-23', '2027-12-07', v_status_id, v_created_by, 0.00, 0.00, 0.00);
    
    -- 2027 Q23 (Dec 08-22) - Periodo A
    v_current_cut_number := v_current_cut_number + 1;
    INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission)
    VALUES (v_current_cut_number, '2027-Q23', '2027-12-08', '2027-12-22', v_status_id, v_created_by, 0.00, 0.00, 0.00);
    
    -- 2027 Q24 (Dec 23 - 2028 Jan 07) - Periodo B
    v_current_cut_number := v_current_cut_number + 1;
    INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission)
    VALUES (v_current_cut_number, '2027-Q24', '2027-12-23', '2028-01-07', v_status_id, v_created_by, 0.00, 0.00, 0.00);
    
    -- ========================================================================
    -- 2028
    -- ========================================================================
    
    -- Continuar con 2028...
    -- 2028 Q01 (Jan 08-22) - Periodo A
    v_current_cut_number := v_current_cut_number + 1;
    INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission)
    VALUES (v_current_cut_number, '2028-Q01', '2028-01-08', '2028-01-22', v_status_id, v_created_by, 0.00, 0.00, 0.00);
    
    -- 2028 Q02 (Jan 23 - Feb 07) - Periodo B
    v_current_cut_number := v_current_cut_number + 1;
    INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission)
    VALUES (v_current_cut_number, '2028-Q02', '2028-01-23', '2028-02-07', v_status_id, v_created_by, 0.00, 0.00, 0.00);
    
    -- 2028 Q03 (Feb 08-22) - Periodo A
    v_current_cut_number := v_current_cut_number + 1;
    INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission)
    VALUES (v_current_cut_number, '2028-Q03', '2028-02-08', '2028-02-22', v_status_id, v_created_by, 0.00, 0.00, 0.00);
    
    -- 2028 Q04 (Feb 23 - Mar 07) - Periodo B (2028 es bisiesto!)
    v_current_cut_number := v_current_cut_number + 1;
    INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission)
    VALUES (v_current_cut_number, '2028-Q04', '2028-02-23', '2028-03-07', v_status_id, v_created_by, 0.00, 0.00, 0.00);
    
    -- 2028 Q05 (Mar 08-22) - Periodo A
    v_current_cut_number := v_current_cut_number + 1;
    INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission)
    VALUES (v_current_cut_number, '2028-Q05', '2028-03-08', '2028-03-22', v_status_id, v_created_by, 0.00, 0.00, 0.00);
    
    -- 2028 Q06 (Mar 23 - Apr 07) - Periodo B
    v_current_cut_number := v_current_cut_number + 1;
    INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission)
    VALUES (v_current_cut_number, '2028-Q06', '2028-03-23', '2028-04-07', v_status_id, v_created_by, 0.00, 0.00, 0.00);
    
    -- 2028 Q07 (Apr 08-22) - Periodo A
    v_current_cut_number := v_current_cut_number + 1;
    INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission)
    VALUES (v_current_cut_number, '2028-Q07', '2028-04-08', '2028-04-22', v_status_id, v_created_by, 0.00, 0.00, 0.00);
    
    -- 2028 Q08 (Apr 23 - May 07) - Periodo B
    v_current_cut_number := v_current_cut_number + 1;
    INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission)
    VALUES (v_current_cut_number, '2028-Q08', '2028-04-23', '2028-05-07', v_status_id, v_created_by, 0.00, 0.00, 0.00);
    
    -- 2028 Q09 (May 08-22) - Periodo A
    v_current_cut_number := v_current_cut_number + 1;
    INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission)
    VALUES (v_current_cut_number, '2028-Q09', '2028-05-08', '2028-05-22', v_status_id, v_created_by, 0.00, 0.00, 0.00);
    
    -- 2028 Q10 (May 23 - Jun 07) - Periodo B
    v_current_cut_number := v_current_cut_number + 1;
    INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission)
    VALUES (v_current_cut_number, '2028-Q10', '2028-05-23', '2028-06-07', v_status_id, v_created_by, 0.00, 0.00, 0.00);
    
    -- 2028 Q11 (Jun 08-22) - Periodo A
    v_current_cut_number := v_current_cut_number + 1;
    INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission)
    VALUES (v_current_cut_number, '2028-Q11', '2028-06-08', '2028-06-22', v_status_id, v_created_by, 0.00, 0.00, 0.00);
    
    -- 2028 Q12 (Jun 23 - Jul 07) - Periodo B
    v_current_cut_number := v_current_cut_number + 1;
    INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission)
    VALUES (v_current_cut_number, '2028-Q12', '2028-06-23', '2028-07-07', v_status_id, v_created_by, 0.00, 0.00, 0.00);
    
    -- 2028 Q13 (Jul 08-22) - Periodo A
    v_current_cut_number := v_current_cut_number + 1;
    INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission)
    VALUES (v_current_cut_number, '2028-Q13', '2028-07-08', '2028-07-22', v_status_id, v_created_by, 0.00, 0.00, 0.00);
    
    -- 2028 Q14 (Jul 23 - Aug 07) - Periodo B
    v_current_cut_number := v_current_cut_number + 1;
    INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission)
    VALUES (v_current_cut_number, '2028-Q14', '2028-07-23', '2028-08-07', v_status_id, v_created_by, 0.00, 0.00, 0.00);
    
    -- 2028 Q15 (Aug 08-22) - Periodo A
    v_current_cut_number := v_current_cut_number + 1;
    INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission)
    VALUES (v_current_cut_number, '2028-Q15', '2028-08-08', '2028-08-22', v_status_id, v_created_by, 0.00, 0.00, 0.00);
    
    -- 2028 Q16 (Aug 23 - Sep 07) - Periodo B
    v_current_cut_number := v_current_cut_number + 1;
    INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission)
    VALUES (v_current_cut_number, '2028-Q16', '2028-08-23', '2028-09-07', v_status_id, v_created_by, 0.00, 0.00, 0.00);
    
    -- 2028 Q17 (Sep 08-22) - Periodo A
    v_current_cut_number := v_current_cut_number + 1;
    INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission)
    VALUES (v_current_cut_number, '2028-Q17', '2028-09-08', '2028-09-22', v_status_id, v_created_by, 0.00, 0.00, 0.00);
    
    -- 2028 Q18 (Sep 23 - Oct 07) - Periodo B
    v_current_cut_number := v_current_cut_number + 1;
    INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission)
    VALUES (v_current_cut_number, '2028-Q18', '2028-09-23', '2028-10-07', v_status_id, v_created_by, 0.00, 0.00, 0.00);
    
    -- 2028 Q19 (Oct 08-22) - Periodo A
    v_current_cut_number := v_current_cut_number + 1;
    INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission)
    VALUES (v_current_cut_number, '2028-Q19', '2028-10-08', '2028-10-22', v_status_id, v_created_by, 0.00, 0.00, 0.00);
    
    -- 2028 Q20 (Oct 23 - Nov 07) - Periodo B
    v_current_cut_number := v_current_cut_number + 1;
    INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission)
    VALUES (v_current_cut_number, '2028-Q20', '2028-10-23', '2028-11-07', v_status_id, v_created_by, 0.00, 0.00, 0.00);
    
    -- 2028 Q21 (Nov 08-22) - Periodo A
    v_current_cut_number := v_current_cut_number + 1;
    INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission)
    VALUES (v_current_cut_number, '2028-Q21', '2028-11-08', '2028-11-22', v_status_id, v_created_by, 0.00, 0.00, 0.00);
    
    -- 2028 Q22 (Nov 23 - Dec 07) - Periodo B
    v_current_cut_number := v_current_cut_number + 1;
    INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission)
    VALUES (v_current_cut_number, '2028-Q22', '2028-11-23', '2028-12-07', v_status_id, v_created_by, 0.00, 0.00, 0.00);
    
    -- 2028 Q23 (Dec 08-22) - Periodo A
    v_current_cut_number := v_current_cut_number + 1;
    INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission)
    VALUES (v_current_cut_number, '2028-Q23', '2028-12-08', '2028-12-22', v_status_id, v_created_by, 0.00, 0.00, 0.00);
    
    -- 2028 Q24 (Dec 23 - 2029 Jan 07) - Periodo B
    v_current_cut_number := v_current_cut_number + 1;
    INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission)
    VALUES (v_current_cut_number, '2028-Q24', '2028-12-23', '2029-01-07', v_status_id, v_created_by, 0.00, 0.00, 0.00);
    
    RAISE NOTICE 'Se han agregado 48 periodos nuevos (2027-2028).';
    RAISE NOTICE 'Nuevo último cut_number: %', v_current_cut_number;
    RAISE NOTICE 'Rango de fechas: 2027-01-08 hasta 2029-01-07';
    
END $$;

-- Verificar que se insertaron correctamente
DO $$
DECLARE
    v_count INTEGER;
    v_min_date DATE;
    v_max_date DATE;
BEGIN
    SELECT COUNT(*), MIN(period_start_date), MAX(period_end_date)
    INTO v_count, v_min_date, v_max_date
    FROM cut_periods;
    
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'VERIFICACIÓN FINAL';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Total de períodos en cut_periods: %', v_count;
    RAISE NOTICE 'Fecha inicio más temprana: %', v_min_date;
    RAISE NOTICE 'Fecha fin más tardía: %', v_max_date;
    RAISE NOTICE '========================================';
    
    IF v_count < 70 THEN
        RAISE WARNING 'Se esperaban al menos 70 períodos. Verificar inserción.';
    END IF;
END $$;

COMMIT;
