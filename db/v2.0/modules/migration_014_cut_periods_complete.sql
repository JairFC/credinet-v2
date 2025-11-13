-- =============================================================================
-- MIGRACIÓN: AGREGAR NOMENCLATURA DE PERIODOS Y GENERAR COMPLETO 2024-2026
-- =============================================================================
-- Fecha: 2025-11-06
-- Descripción: Agrega columna cut_code con formato {YYYY}-Q{NN}
--              y genera periodos completos para 3 años (72 periodos)
-- =============================================================================

-- Paso 1: Agregar columna cut_code si no existe
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'cut_periods' AND column_name = 'cut_code'
    ) THEN
        ALTER TABLE cut_periods
        ADD COLUMN cut_code VARCHAR(10) UNIQUE;
        
        COMMENT ON COLUMN cut_periods.cut_code IS
        'Código único del periodo: {YYYY}-Q{NN}. Ej: 2025-Q01 (ene 8-22), 2025-Q24 (dic 23-ene 7)';
        
        RAISE NOTICE '✅ Columna cut_code agregada';
    ELSE
        RAISE NOTICE '⚠️  Columna cut_code ya existe';
    END IF;
END $$;

-- Paso 2: Limpiar periodos existentes (son de prueba)
TRUNCATE TABLE cut_periods RESTART IDENTITY CASCADE;
RAISE NOTICE '✅ Periodos de prueba limpiados';

-- Paso 3: Insertar periodos completos 2024-2026 (72 periodos)
INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission) VALUES (1, '2024-Q01', '2024-01-08', '2024-01-22', 5, 1, 0.00, 0.00, 0.00); -- CLOSED | A | Jan 2024
INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission) VALUES (2, '2024-Q02', '2024-01-23', '2024-02-07', 5, 1, 0.00, 0.00, 0.00); -- CLOSED | B | Jan 2024
INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission) VALUES (3, '2024-Q03', '2024-02-08', '2024-02-22', 5, 1, 0.00, 0.00, 0.00); -- CLOSED | A | Feb 2024
INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission) VALUES (4, '2024-Q04', '2024-02-23', '2024-03-07', 5, 1, 0.00, 0.00, 0.00); -- CLOSED | B | Feb 2024
INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission) VALUES (5, '2024-Q05', '2024-03-08', '2024-03-22', 5, 1, 0.00, 0.00, 0.00); -- CLOSED | A | Mar 2024
INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission) VALUES (6, '2024-Q06', '2024-03-23', '2024-04-07', 5, 1, 0.00, 0.00, 0.00); -- CLOSED | B | Mar 2024
INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission) VALUES (7, '2024-Q07', '2024-04-08', '2024-04-22', 5, 1, 0.00, 0.00, 0.00); -- CLOSED | A | Apr 2024
INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission) VALUES (8, '2024-Q08', '2024-04-23', '2024-05-07', 5, 1, 0.00, 0.00, 0.00); -- CLOSED | B | Apr 2024
INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission) VALUES (9, '2024-Q09', '2024-05-08', '2024-05-22', 5, 1, 0.00, 0.00, 0.00); -- CLOSED | A | May 2024
INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission) VALUES (10, '2024-Q10', '2024-05-23', '2024-06-07', 5, 1, 0.00, 0.00, 0.00); -- CLOSED | B | May 2024
INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission) VALUES (11, '2024-Q11', '2024-06-08', '2024-06-22', 5, 1, 0.00, 0.00, 0.00); -- CLOSED | A | Jun 2024
INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission) VALUES (12, '2024-Q12', '2024-06-23', '2024-07-07', 5, 1, 0.00, 0.00, 0.00); -- CLOSED | B | Jun 2024
INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission) VALUES (13, '2024-Q13', '2024-07-08', '2024-07-22', 5, 1, 0.00, 0.00, 0.00); -- CLOSED | A | Jul 2024
INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission) VALUES (14, '2024-Q14', '2024-07-23', '2024-08-07', 5, 1, 0.00, 0.00, 0.00); -- CLOSED | B | Jul 2024
INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission) VALUES (15, '2024-Q15', '2024-08-08', '2024-08-22', 5, 1, 0.00, 0.00, 0.00); -- CLOSED | A | Aug 2024
INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission) VALUES (16, '2024-Q16', '2024-08-23', '2024-09-07', 5, 1, 0.00, 0.00, 0.00); -- CLOSED | B | Aug 2024
INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission) VALUES (17, '2024-Q17', '2024-09-08', '2024-09-22', 5, 1, 0.00, 0.00, 0.00); -- CLOSED | A | Sep 2024
INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission) VALUES (18, '2024-Q18', '2024-09-23', '2024-10-07', 5, 1, 0.00, 0.00, 0.00); -- CLOSED | B | Sep 2024
INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission) VALUES (19, '2024-Q19', '2024-10-08', '2024-10-22', 5, 1, 0.00, 0.00, 0.00); -- CLOSED | A | Oct 2024
INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission) VALUES (20, '2024-Q20', '2024-10-23', '2024-11-07', 5, 1, 0.00, 0.00, 0.00); -- CLOSED | B | Oct 2024
INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission) VALUES (21, '2024-Q21', '2024-11-08', '2024-11-22', 5, 1, 0.00, 0.00, 0.00); -- CLOSED | A | Nov 2024
INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission) VALUES (22, '2024-Q22', '2024-11-23', '2024-12-07', 5, 1, 0.00, 0.00, 0.00); -- CLOSED | B | Nov 2024
INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission) VALUES (23, '2024-Q23', '2024-12-08', '2024-12-22', 5, 1, 0.00, 0.00, 0.00); -- CLOSED | A | Dec 2024
INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission) VALUES (24, '2024-Q24', '2024-12-23', '2025-01-07', 5, 1, 0.00, 0.00, 0.00); -- CLOSED | B | Dec 2024
INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission) VALUES (1, '2025-Q01', '2025-01-08', '2025-01-22', 5, 1, 0.00, 0.00, 0.00); -- CLOSED | A | Jan 2025
INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission) VALUES (2, '2025-Q02', '2025-01-23', '2025-02-07', 5, 1, 0.00, 0.00, 0.00); -- CLOSED | B | Jan 2025
INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission) VALUES (3, '2025-Q03', '2025-02-08', '2025-02-22', 5, 1, 0.00, 0.00, 0.00); -- CLOSED | A | Feb 2025
INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission) VALUES (4, '2025-Q04', '2025-02-23', '2025-03-07', 5, 1, 0.00, 0.00, 0.00); -- CLOSED | B | Feb 2025
INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission) VALUES (5, '2025-Q05', '2025-03-08', '2025-03-22', 5, 1, 0.00, 0.00, 0.00); -- CLOSED | A | Mar 2025
INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission) VALUES (6, '2025-Q06', '2025-03-23', '2025-04-07', 5, 1, 0.00, 0.00, 0.00); -- CLOSED | B | Mar 2025
INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission) VALUES (7, '2025-Q07', '2025-04-08', '2025-04-22', 5, 1, 0.00, 0.00, 0.00); -- CLOSED | A | Apr 2025
INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission) VALUES (8, '2025-Q08', '2025-04-23', '2025-05-07', 5, 1, 0.00, 0.00, 0.00); -- CLOSED | B | Apr 2025
INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission) VALUES (9, '2025-Q09', '2025-05-08', '2025-05-22', 5, 1, 0.00, 0.00, 0.00); -- CLOSED | A | May 2025
INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission) VALUES (10, '2025-Q10', '2025-05-23', '2025-06-07', 5, 1, 0.00, 0.00, 0.00); -- CLOSED | B | May 2025
INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission) VALUES (11, '2025-Q11', '2025-06-08', '2025-06-22', 5, 1, 0.00, 0.00, 0.00); -- CLOSED | A | Jun 2025
INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission) VALUES (12, '2025-Q12', '2025-06-23', '2025-07-07', 5, 1, 0.00, 0.00, 0.00); -- CLOSED | B | Jun 2025
INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission) VALUES (13, '2025-Q13', '2025-07-08', '2025-07-22', 5, 1, 0.00, 0.00, 0.00); -- CLOSED | A | Jul 2025
INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission) VALUES (14, '2025-Q14', '2025-07-23', '2025-08-07', 5, 1, 0.00, 0.00, 0.00); -- CLOSED | B | Jul 2025
INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission) VALUES (15, '2025-Q15', '2025-08-08', '2025-08-22', 5, 1, 0.00, 0.00, 0.00); -- CLOSED | A | Aug 2025
INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission) VALUES (16, '2025-Q16', '2025-08-23', '2025-09-07', 5, 1, 0.00, 0.00, 0.00); -- CLOSED | B | Aug 2025
INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission) VALUES (17, '2025-Q17', '2025-09-08', '2025-09-22', 5, 1, 0.00, 0.00, 0.00); -- CLOSED | A | Sep 2025
INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission) VALUES (18, '2025-Q18', '2025-09-23', '2025-10-07', 5, 1, 0.00, 0.00, 0.00); -- CLOSED | B | Sep 2025
INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission) VALUES (19, '2025-Q19', '2025-10-08', '2025-10-22', 5, 1, 0.00, 0.00, 0.00); -- CLOSED | A | Oct 2025
INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission) VALUES (20, '2025-Q20', '2025-10-23', '2025-11-07', 2, 1, 0.00, 0.00, 0.00); -- ACTIVE | B | Oct 2025
INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission) VALUES (21, '2025-Q21', '2025-11-08', '2025-11-22', 1, 1, 0.00, 0.00, 0.00); -- PENDING | A | Nov 2025
INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission) VALUES (22, '2025-Q22', '2025-11-23', '2025-12-07', 1, 1, 0.00, 0.00, 0.00); -- PENDING | B | Nov 2025
INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission) VALUES (23, '2025-Q23', '2025-12-08', '2025-12-22', 1, 1, 0.00, 0.00, 0.00); -- PENDING | A | Dec 2025
INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission) VALUES (24, '2025-Q24', '2025-12-23', '2026-01-07', 1, 1, 0.00, 0.00, 0.00); -- PENDING | B | Dec 2025
INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission) VALUES (1, '2026-Q01', '2026-01-08', '2026-01-22', 1, 1, 0.00, 0.00, 0.00); -- PENDING | A | Jan 2026
INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission) VALUES (2, '2026-Q02', '2026-01-23', '2026-02-07', 1, 1, 0.00, 0.00, 0.00); -- PENDING | B | Jan 2026
INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission) VALUES (3, '2026-Q03', '2026-02-08', '2026-02-22', 1, 1, 0.00, 0.00, 0.00); -- PENDING | A | Feb 2026
INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission) VALUES (4, '2026-Q04', '2026-02-23', '2026-03-07', 1, 1, 0.00, 0.00, 0.00); -- PENDING | B | Feb 2026
INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission) VALUES (5, '2026-Q05', '2026-03-08', '2026-03-22', 1, 1, 0.00, 0.00, 0.00); -- PENDING | A | Mar 2026
INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission) VALUES (6, '2026-Q06', '2026-03-23', '2026-04-07', 1, 1, 0.00, 0.00, 0.00); -- PENDING | B | Mar 2026
INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission) VALUES (7, '2026-Q07', '2026-04-08', '2026-04-22', 1, 1, 0.00, 0.00, 0.00); -- PENDING | A | Apr 2026
INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission) VALUES (8, '2026-Q08', '2026-04-23', '2026-05-07', 1, 1, 0.00, 0.00, 0.00); -- PENDING | B | Apr 2026
INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission) VALUES (9, '2026-Q09', '2026-05-08', '2026-05-22', 1, 1, 0.00, 0.00, 0.00); -- PENDING | A | May 2026
INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission) VALUES (10, '2026-Q10', '2026-05-23', '2026-06-07', 1, 1, 0.00, 0.00, 0.00); -- PENDING | B | May 2026
INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission) VALUES (11, '2026-Q11', '2026-06-08', '2026-06-22', 1, 1, 0.00, 0.00, 0.00); -- PENDING | A | Jun 2026
INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission) VALUES (12, '2026-Q12', '2026-06-23', '2026-07-07', 1, 1, 0.00, 0.00, 0.00); -- PENDING | B | Jun 2026
INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission) VALUES (13, '2026-Q13', '2026-07-08', '2026-07-22', 1, 1, 0.00, 0.00, 0.00); -- PENDING | A | Jul 2026
INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission) VALUES (14, '2026-Q14', '2026-07-23', '2026-08-07', 1, 1, 0.00, 0.00, 0.00); -- PENDING | B | Jul 2026
INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission) VALUES (15, '2026-Q15', '2026-08-08', '2026-08-22', 1, 1, 0.00, 0.00, 0.00); -- PENDING | A | Aug 2026
INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission) VALUES (16, '2026-Q16', '2026-08-23', '2026-09-07', 1, 1, 0.00, 0.00, 0.00); -- PENDING | B | Aug 2026
INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission) VALUES (17, '2026-Q17', '2026-09-08', '2026-09-22', 1, 1, 0.00, 0.00, 0.00); -- PENDING | A | Sep 2026
INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission) VALUES (18, '2026-Q18', '2026-09-23', '2026-10-07', 1, 1, 0.00, 0.00, 0.00); -- PENDING | B | Sep 2026
INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission) VALUES (19, '2026-Q19', '2026-10-08', '2026-10-22', 1, 1, 0.00, 0.00, 0.00); -- PENDING | A | Oct 2026
INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission) VALUES (20, '2026-Q20', '2026-10-23', '2026-11-07', 1, 1, 0.00, 0.00, 0.00); -- PENDING | B | Oct 2026
INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission) VALUES (21, '2026-Q21', '2026-11-08', '2026-11-22', 1, 1, 0.00, 0.00, 0.00); -- PENDING | A | Nov 2026
INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission) VALUES (22, '2026-Q22', '2026-11-23', '2026-12-07', 1, 1, 0.00, 0.00, 0.00); -- PENDING | B | Nov 2026
INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission) VALUES (23, '2026-Q23', '2026-12-08', '2026-12-22', 1, 1, 0.00, 0.00, 0.00); -- PENDING | A | Dec 2026
INSERT INTO cut_periods (cut_number, cut_code, period_start_date, period_end_date, status_id, created_by, total_payments_expected, total_payments_received, total_commission) VALUES (24, '2026-Q24', '2026-12-23', '2027-01-07', 1, 1, 0.00, 0.00, 0.00); -- PENDING | B | Dec 2026

-- Paso 4: Crear índice en cut_code
CREATE INDEX IF NOT EXISTS idx_cut_periods_cut_code ON cut_periods(cut_code);
RAISE NOTICE '✅ Índice en cut_code creado';

-- Paso 5: Verificación y resumen
DO $$
DECLARE
    v_total_periods INT;
    v_periods_2024 INT;
    v_periods_2025 INT;
    v_periods_2026 INT;
    v_active_periods INT;
    v_closed_periods INT;
BEGIN
    SELECT COUNT(*) INTO v_total_periods FROM cut_periods;
    SELECT COUNT(*) INTO v_periods_2024 FROM cut_periods WHERE cut_code LIKE '2024-%';
    SELECT COUNT(*) INTO v_periods_2025 FROM cut_periods WHERE cut_code LIKE '2025-%';
    SELECT COUNT(*) INTO v_periods_2026 FROM cut_periods WHERE cut_code LIKE '2026-%';
    SELECT COUNT(*) INTO v_active_periods FROM cut_periods WHERE status_id = 2;
    SELECT COUNT(*) INTO v_closed_periods FROM cut_periods WHERE status_id = 5;
    
    RAISE NOTICE '';
    RAISE NOTICE '╔═══════════════════════════════════════════════════════════╗';
    RAISE NOTICE '║       PERIODOS DE CORTE GENERADOS EXITOSAMENTE           ║';
    RAISE NOTICE '╠═══════════════════════════════════════════════════════════╣';
    RAISE NOTICE '║  Total periodos:     % (esperado: 72)                    ║', v_total_periods;
    RAISE NOTICE '║  Periodos 2024:      % (2 meses: dic)                    ║', v_periods_2024;
    RAISE NOTICE '║  Periodos 2025:      % (12 meses completos)              ║', v_periods_2025;
    RAISE NOTICE '║  Periodos 2026:      % (12 meses completos)              ║', v_periods_2026;
    RAISE NOTICE '║  Estado CLOSED:      % periodos                          ║', v_closed_periods;
    RAISE NOTICE '║  Estado ACTIVE:      % periodos                          ║', v_active_periods;
    RAISE NOTICE '╠═══════════════════════════════════════════════════════════╣';
    RAISE NOTICE '║  Nomenclatura: {YYYY}-Q{NN}                              ║';
    RAISE NOTICE '║  Ejemplo: 2025-Q01 = Ene 8-22, 2025-Q02 = Ene 23-Feb 7   ║';
    RAISE NOTICE '╚═══════════════════════════════════════════════════════════╝';
    RAISE NOTICE '';
    
    -- Mostrar algunos ejemplos
    RAISE NOTICE 'Ejemplos de periodos:';
    PERFORM RAISE NOTICE '  % | % al % | Status: %', 
        cut_code, period_start_date, period_end_date, 
        CASE status_id WHEN 5 THEN 'CLOSED' WHEN 2 THEN 'ACTIVE' ELSE 'PENDING' END
    FROM cut_periods ORDER BY cut_code LIMIT 5;
END $$;

-- =============================================================================
-- FIN DE LA MIGRACIÓN
-- =============================================================================