-- =============================================================================
-- MIGRACIÓN 016: ASSOCIATE_DEBT_PAYMENTS - Tracking de Abonos a Deuda Acumulada
-- =============================================================================
-- Descripción:
--   Crea la tabla associate_debt_payments para registrar abonos directos
--   a la deuda acumulada (FIFO) y las vistas de resumen.
--
-- Propósito:
--   Implementar el tracking completo de abonos a "DEUDA ACUMULADA".
--   Permite abonos directos a deuda sin pasar por statements.
--
-- Dependencias:
--   - associate_profiles (debe existir)
--   - associate_debt_breakdown (debe existir)
--   - payment_methods (debe existir)
--   - users (debe existir)
--
-- Autor: GitHub Copilot (Piloto Principal)
-- Fecha: 2025-11-11
-- Versión: 2.0.4
-- =============================================================================

-- =============================================================================
-- PASO 1: CREAR TABLA associate_debt_payments
-- =============================================================================

CREATE TABLE IF NOT EXISTS associate_debt_payments (
    id SERIAL PRIMARY KEY,
    associate_profile_id INTEGER NOT NULL REFERENCES associate_profiles(id) ON DELETE CASCADE,
    payment_amount DECIMAL(12, 2) NOT NULL,
    payment_date DATE NOT NULL,
    payment_method_id INTEGER NOT NULL REFERENCES payment_methods(id),
    payment_reference VARCHAR(100),
    registered_by INTEGER NOT NULL REFERENCES users(id),
    applied_breakdown_items JSONB NOT NULL DEFAULT '[]'::jsonb,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Validaciones
    CONSTRAINT check_debt_payments_amount_positive CHECK (payment_amount > 0),
    CONSTRAINT check_debt_payments_date_logical CHECK (payment_date <= CURRENT_DATE)
);

COMMENT ON TABLE associate_debt_payments IS '⭐ NUEVO v2.0.4: Registro de abonos directos a DEUDA ACUMULADA. Permite al asociado pagar deuda antigua sin tener que pagar saldo actual primero. Aplica FIFO automáticamente.';
COMMENT ON COLUMN associate_debt_payments.associate_profile_id IS 'Asociado que realiza el abono a su deuda acumulada.';
COMMENT ON COLUMN associate_debt_payments.payment_amount IS 'Monto del abono a deuda acumulada. Se distribuye automáticamente en FIFO.';
COMMENT ON COLUMN associate_debt_payments.applied_breakdown_items IS 'JSON con detalle de items de deuda liquidados: [{"breakdown_id": 123, "amount_applied": 500.00, "liquidated": true}, ...]';
COMMENT ON COLUMN associate_debt_payments.payment_reference IS 'Referencia bancaria o número de recibo del abono a deuda.';
COMMENT ON COLUMN associate_debt_payments.registered_by IS 'Usuario que registró el abono a deuda.';
COMMENT ON COLUMN associate_debt_payments.notes IS 'Notas adicionales (ej: "Abono voluntario a deuda acumulada").';

-- =============================================================================
-- PASO 2: CREAR ÍNDICES
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_debt_payments_associate_id ON associate_debt_payments(associate_profile_id);
CREATE INDEX IF NOT EXISTS idx_debt_payments_payment_date ON associate_debt_payments(payment_date);
CREATE INDEX IF NOT EXISTS idx_debt_payments_registered_by ON associate_debt_payments(registered_by);
CREATE INDEX IF NOT EXISTS idx_debt_payments_method ON associate_debt_payments(payment_method_id);

-- Índice GIN para búsquedas en JSONB
CREATE INDEX IF NOT EXISTS idx_debt_payments_applied_items ON associate_debt_payments USING GIN (applied_breakdown_items);

-- Índice compuesto para consultas de resumen
CREATE INDEX IF NOT EXISTS idx_debt_payments_associate_date ON associate_debt_payments(associate_profile_id, payment_date DESC);

-- =============================================================================
-- PASO 3: CREAR FUNCIÓN PARA APLICAR ABONO A DEUDA (FIFO)
-- =============================================================================

CREATE OR REPLACE FUNCTION apply_debt_payment_fifo()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_remaining_amount DECIMAL(12,2);
    v_debt_record RECORD;
    v_applied_items JSONB := '[]'::jsonb;
    v_item JSONB;
    v_amount_to_apply DECIMAL(12,2);
BEGIN
    v_remaining_amount := NEW.payment_amount;
    
    -- Aplicar FIFO: liquidar deudas más antiguas primero
    FOR v_debt_record IN (
        SELECT id, amount, cut_period_id, created_at
        FROM associate_debt_breakdown
        WHERE associate_profile_id = NEW.associate_profile_id
          AND is_liquidated = false
        ORDER BY created_at ASC, id ASC  -- ⭐ FIFO
    )
    LOOP
        EXIT WHEN v_remaining_amount <= 0;
        
        IF v_remaining_amount >= v_debt_record.amount THEN
            -- Liquidar completamente este item
            v_amount_to_apply := v_debt_record.amount;
            
            UPDATE associate_debt_breakdown
            SET 
                is_liquidated = true,
                liquidated_at = NEW.payment_date,
                liquidation_reference = NEW.payment_reference,
                updated_at = CURRENT_TIMESTAMP
            WHERE id = v_debt_record.id;
            
            v_remaining_amount := v_remaining_amount - v_debt_record.amount;
            
            -- Agregar al JSON de items aplicados
            v_item := jsonb_build_object(
                'breakdown_id', v_debt_record.id,
                'cut_period_id', v_debt_record.cut_period_id,
                'original_amount', v_debt_record.amount,
                'amount_applied', v_amount_to_apply,
                'liquidated', true,
                'applied_at', NEW.payment_date
            );
            
            v_applied_items := v_applied_items || v_item;
            
            RAISE NOTICE 'Deuda % liquidada completamente (monto: %)', 
                         v_debt_record.id, v_debt_record.amount;
        ELSE
            -- Liquidar parcialmente (reducir monto del item)
            v_amount_to_apply := v_remaining_amount;
            
            UPDATE associate_debt_breakdown
            SET 
                amount = amount - v_remaining_amount,
                updated_at = CURRENT_TIMESTAMP
            WHERE id = v_debt_record.id;
            
            -- Agregar al JSON de items aplicados
            v_item := jsonb_build_object(
                'breakdown_id', v_debt_record.id,
                'cut_period_id', v_debt_record.cut_period_id,
                'original_amount', v_debt_record.amount,
                'amount_applied', v_amount_to_apply,
                'liquidated', false,
                'remaining_amount', v_debt_record.amount - v_remaining_amount,
                'applied_at', NEW.payment_date
            );
            
            v_applied_items := v_applied_items || v_item;
            
            RAISE NOTICE 'Deuda % liquidada parcialmente (abono: %, restante: %)', 
                         v_debt_record.id, v_remaining_amount, v_debt_record.amount - v_remaining_amount;
            
            v_remaining_amount := 0;
        END IF;
    END LOOP;
    
    -- Actualizar debt_balance del asociado
    UPDATE associate_profiles
    SET 
        debt_balance = (
            SELECT COALESCE(SUM(amount), 0)
            FROM associate_debt_breakdown
            WHERE associate_profile_id = NEW.associate_profile_id
              AND is_liquidated = false
        ),
        updated_at = CURRENT_TIMESTAMP
    WHERE id = NEW.associate_profile_id;
    
    -- Actualizar el campo applied_breakdown_items con el JSON construido
    NEW.applied_breakdown_items := v_applied_items;
    
    RAISE NOTICE 'Abono a deuda aplicado: % (items liquidados: %)', 
                 NEW.payment_amount, jsonb_array_length(v_applied_items);
    
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION apply_debt_payment_fifo() IS '⭐ v2.0.4: Trigger que aplica automáticamente el abono a deuda usando estrategia FIFO (más antiguos primero). Actualiza debt_balance y genera JSON detallado de items liquidados.';

-- =============================================================================
-- PASO 4: CREAR TRIGGER
-- =============================================================================

CREATE TRIGGER trigger_apply_debt_payment_fifo
BEFORE INSERT ON associate_debt_payments
FOR EACH ROW
EXECUTE FUNCTION apply_debt_payment_fifo();

COMMENT ON TRIGGER trigger_apply_debt_payment_fifo ON associate_debt_payments IS
'Aplica FIFO automáticamente cuando se registra un abono a deuda acumulada.';

-- =============================================================================
-- PASO 5: CREAR TRIGGER PARA updated_at
-- =============================================================================

CREATE TRIGGER update_associate_debt_payments_updated_at
BEFORE UPDATE ON associate_debt_payments
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- PASO 6: CREAR VISTA DE RESUMEN DE DEUDA POR ASOCIADO
-- =============================================================================

CREATE OR REPLACE VIEW v_associate_debt_summary AS
SELECT 
    ap.id AS associate_profile_id,
    u.full_name AS associate_name,
    ap.debt_balance AS current_debt_balance,
    
    -- Contadores
    COUNT(DISTINCT adb.id) FILTER (WHERE adb.is_liquidated = false) AS pending_debt_items,
    COUNT(DISTINCT adb.id) FILTER (WHERE adb.is_liquidated = true) AS liquidated_debt_items,
    
    -- Montos desglosados
    COALESCE(SUM(adb.amount) FILTER (WHERE adb.is_liquidated = false), 0) AS total_pending_debt,
    COALESCE(SUM(adp.payment_amount), 0) AS total_paid_to_debt,
    
    -- Fechas
    MIN(adb.created_at) FILTER (WHERE adb.is_liquidated = false) AS oldest_debt_date,
    MAX(adp.payment_date) AS last_payment_date,
    
    -- Estadísticas
    COUNT(DISTINCT adp.id) AS total_debt_payments_count,
    ap.available_credit,
    ap.credit_limit
    
FROM associate_profiles ap
JOIN users u ON u.id = ap.user_id
LEFT JOIN associate_debt_breakdown adb ON adb.associate_profile_id = ap.id
LEFT JOIN associate_debt_payments adp ON adp.associate_profile_id = ap.id

GROUP BY 
    ap.id,
    u.full_name,
    ap.debt_balance,
    ap.available_credit,
    ap.credit_limit;

COMMENT ON VIEW v_associate_debt_summary IS '⭐ v2.0.4: Vista de resumen de deuda por asociado. Muestra deuda actual, items pendientes/liquidados, total pagado, y fechas clave.';

-- =============================================================================
-- PASO 7: CREAR VISTA DE TODOS LOS PAGOS DEL ASOCIADO (UNIFICADA)
-- =============================================================================

CREATE OR REPLACE VIEW v_associate_all_payments AS
-- Pagos a SALDO ACTUAL (statements)
SELECT 
    asp.id,
    'SALDO_ACTUAL' AS payment_type,
    ap.id AS associate_profile_id,
    u.full_name AS associate_name,
    asp.payment_amount,
    asp.payment_date,
    pm.name AS payment_method,
    asp.payment_reference,
    aps.cut_period_id,
    cp.start_date AS period_start,
    cp.end_date AS period_end,
    asp.notes,
    asp.created_at
FROM associate_statement_payments asp
JOIN associate_payment_statements aps ON aps.id = asp.statement_id
JOIN users u ON u.id = aps.user_id
JOIN associate_profiles ap ON ap.user_id = u.id
JOIN payment_methods pm ON pm.id = asp.payment_method_id
LEFT JOIN cut_periods cp ON cp.id = aps.cut_period_id

UNION ALL

-- Pagos a DEUDA ACUMULADA
SELECT 
    adp.id,
    'DEUDA_ACUMULADA' AS payment_type,
    adp.associate_profile_id,
    u.full_name AS associate_name,
    adp.payment_amount,
    adp.payment_date,
    pm.name AS payment_method,
    adp.payment_reference,
    NULL AS cut_period_id,  -- Los abonos a deuda no tienen período específico
    NULL AS period_start,
    NULL AS period_end,
    adp.notes,
    adp.created_at
FROM associate_debt_payments adp
JOIN associate_profiles ap ON ap.id = adp.associate_profile_id
JOIN users u ON u.id = ap.user_id
JOIN payment_methods pm ON pm.id = adp.payment_method_id

ORDER BY payment_date DESC, created_at DESC;

COMMENT ON VIEW v_associate_all_payments IS '⭐ v2.0.4: Vista unificada de TODOS los pagos del asociado (saldo actual + deuda acumulada). Útil para historial completo y reportes.';

-- =============================================================================
-- PASO 8: CREAR FUNCIÓN HELPER PARA OBTENER DETALLE DE APLICACIÓN
-- =============================================================================

CREATE OR REPLACE FUNCTION get_debt_payment_detail(
    p_debt_payment_id INTEGER
)
RETURNS TABLE (
    breakdown_id INTEGER,
    cut_period_id INTEGER,
    period_description VARCHAR,
    original_amount DECIMAL(12,2),
    amount_applied DECIMAL(12,2),
    liquidated BOOLEAN,
    remaining_amount DECIMAL(12,2)
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        (item->>'breakdown_id')::INTEGER AS breakdown_id,
        (item->>'cut_period_id')::INTEGER AS cut_period_id,
        COALESCE(
            cp.description,
            'Período ' || TO_CHAR(cp.start_date, 'DD/MM/YYYY') || ' - ' || TO_CHAR(cp.end_date, 'DD/MM/YYYY')
        ) AS period_description,
        (item->>'original_amount')::DECIMAL(12,2) AS original_amount,
        (item->>'amount_applied')::DECIMAL(12,2) AS amount_applied,
        (item->>'liquidated')::BOOLEAN AS liquidated,
        COALESCE((item->>'remaining_amount')::DECIMAL(12,2), 0) AS remaining_amount
    FROM associate_debt_payments adp
    CROSS JOIN jsonb_array_elements(adp.applied_breakdown_items) AS item
    LEFT JOIN cut_periods cp ON cp.id = (item->>'cut_period_id')::INTEGER
    WHERE adp.id = p_debt_payment_id;
END;
$$;

COMMENT ON FUNCTION get_debt_payment_detail(INTEGER) IS '⭐ v2.0.4: Función helper para obtener el detalle desglosado de items de deuda liquidados por un abono específico. Retorna tabla con breakdown_id, montos aplicados, y estado de liquidación.';

-- =============================================================================
-- PASO 9: VALIDACIONES POST-MIGRACIÓN
-- =============================================================================

DO $$
BEGIN
    -- Validar tabla
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_name = 'associate_debt_payments'
    ) THEN
        RAISE EXCEPTION 'MIGRACIÓN FALLIDA: Tabla associate_debt_payments no fue creada';
    END IF;
    
    -- Validar vistas
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.views 
        WHERE table_name = 'v_associate_debt_summary'
    ) THEN
        RAISE EXCEPTION 'MIGRACIÓN FALLIDA: Vista v_associate_debt_summary no fue creada';
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.views 
        WHERE table_name = 'v_associate_all_payments'
    ) THEN
        RAISE EXCEPTION 'MIGRACIÓN FALLIDA: Vista v_associate_all_payments no fue creada';
    END IF;
    
    RAISE NOTICE '✅ Migración 016 completada exitosamente';
    RAISE NOTICE '   - Tabla: associate_debt_payments';
    RAISE NOTICE '   - Índices: 6 índices creados (incluye GIN para JSONB)';
    RAISE NOTICE '   - Funciones: 2 funciones creadas';
    RAISE NOTICE '   - Triggers: 2 triggers creados';
    RAISE NOTICE '   - Vistas: 2 vistas creadas';
    RAISE NOTICE '   - Campo JSONB: applied_breakdown_items (tracking FIFO detallado)';
END $$;

-- =============================================================================
-- FIN DE LA MIGRACIÓN 016
-- =============================================================================
