-- =============================================================================
-- CREDINET DB v2.0.3 - MÓDULO 10: SISTEMA DE PERFILES DE TASA
-- =============================================================================
-- Descripción:
--   Sistema flexible de perfiles de tasa con soporte para múltiples métodos
--   de cálculo. Permite administración completa de tabla legacy y cálculos
--   basados en fórmulas matemáticas.
--
-- Componentes:
--   - rate_profiles: Perfiles configurables (legacy, standard, premium, custom)
--   - legacy_payment_table: Tabla histórica EDITABLE con 28+ montos
--   - calculate_loan_payment(): Función unificada de cálculo
--   - generate_loan_summary(): Genera tabla resumen para preview
--   - generate_amortization_schedule(): Genera tabla de amortización
--
-- Versión: 2.0.3
-- Fecha: 2025-11-04
-- =============================================================================

-- =============================================================================
-- TABLA 1: PERFILES DE TASA (Dos Tasas Independientes)
-- =============================================================================
CREATE TABLE IF NOT EXISTS rate_profiles (
    id SERIAL PRIMARY KEY,
    code VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    
    -- Tipo de cálculo: 'table_lookup' (busca en legacy_payment_table) o 'formula' (usa las dos tasas)
    calculation_type VARCHAR(20) NOT NULL CHECK (calculation_type IN ('table_lookup', 'formula')),
    
    -- ⭐ LAS DOS TASAS INDEPENDIENTES
    -- Tasa de INTERÉS al CLIENTE (lo que paga sobre el capital)
    interest_rate_percent DECIMAL(5,3),  -- Ejemplo: 4.250 = 4.25% quincenal
    
    -- Tasa de COMISIÓN al ASOCIADO (lo que cobra la empresa)
    commission_rate_percent DECIMAL(5,3),  -- Ejemplo: 2.500 = 2.5% sobre cada pago
    
    -- Configuración UI
    enabled BOOLEAN DEFAULT true,
    is_recommended BOOLEAN DEFAULT false,  -- Destacar en interfaz
    display_order INTEGER DEFAULT 0,  -- Orden de aparición
    
    -- Límites opcionales
    min_amount DECIMAL(12,2),
    max_amount DECIMAL(12,2),
    valid_terms INT[],  -- Array de plazos permitidos: [6, 12, 18, 24] o NULL = todos
    
    -- Auditoría
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_by INTEGER REFERENCES users(id),
    updated_by INTEGER REFERENCES users(id)
);

COMMENT ON TABLE rate_profiles IS 'Perfiles de tasa configurables con DOS TASAS independientes. Admin puede crear, editar, habilitar/deshabilitar perfiles.';
COMMENT ON COLUMN rate_profiles.code IS 'Código único interno. Ejemplos: legacy, standard, premium, custom_vip.';
COMMENT ON COLUMN rate_profiles.calculation_type IS 'Método de cálculo: table_lookup (busca en legacy_payment_table) o formula (usa las dos tasas fijas).';
COMMENT ON COLUMN rate_profiles.interest_rate_percent IS 'Tasa de INTERÉS quincenal que paga el CLIENTE sobre el capital. Ejemplo: 4.250 = 4.25%. NULL para perfil legacy (usa tabla).';
COMMENT ON COLUMN rate_profiles.commission_rate_percent IS 'Tasa de COMISIÓN que cobra la empresa al ASOCIADO sobre cada pago del cliente. Ejemplo: 2.500 = 2.5%. NULL para perfil legacy o usa default 2.5%.';
COMMENT ON COLUMN rate_profiles.is_recommended IS 'Si TRUE, este perfil aparece destacado como "Recomendado" en UI.';
COMMENT ON COLUMN rate_profiles.valid_terms IS 'Array de plazos permitidos en quincenas. NULL = permite cualquier plazo.';

CREATE INDEX idx_rate_profiles_code ON rate_profiles(code);
CREATE INDEX idx_rate_profiles_enabled ON rate_profiles(enabled) WHERE enabled = true;
CREATE INDEX idx_rate_profiles_display ON rate_profiles(display_order);

-- Foreign Key desde loans hacia rate_profiles
ALTER TABLE loans ADD CONSTRAINT fk_loans_profile_code 
    FOREIGN KEY (profile_code) REFERENCES rate_profiles(code) 
    ON DELETE SET NULL;

COMMENT ON COLUMN loans.profile_code IS 'Código del perfil de tasa usado para este préstamo. NULL si se usaron tasas manuales.';

-- =============================================================================
-- TABLA 2: TABLA LEGACY DE PAGOS (EDITABLE)
-- =============================================================================
CREATE TABLE IF NOT EXISTS legacy_payment_table (
    id SERIAL PRIMARY KEY,
    amount DECIMAL(12,2) NOT NULL,
    biweekly_payment DECIMAL(10,2) NOT NULL,
    term_biweeks INTEGER NOT NULL DEFAULT 12,
    
    -- Campos calculados automáticamente
    total_payment DECIMAL(12,2) GENERATED ALWAYS AS (biweekly_payment * term_biweeks) STORED,
    total_interest DECIMAL(12,2) GENERATED ALWAYS AS ((biweekly_payment * term_biweeks) - amount) STORED,
    effective_rate_percent DECIMAL(5,2) GENERATED ALWAYS AS (
        ROUND((((biweekly_payment * term_biweeks) - amount) / amount * 100)::NUMERIC, 2)
    ) STORED,
    biweekly_rate_percent DECIMAL(5,3) GENERATED ALWAYS AS (
        ROUND((((biweekly_payment * term_biweeks) - amount) / amount / term_biweeks * 100)::NUMERIC, 3)
    ) STORED,
    
    -- Auditoría
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_by INTEGER REFERENCES users(id),
    updated_by INTEGER REFERENCES users(id),
    
    -- Constraints
    CONSTRAINT uq_legacy_amount_term UNIQUE (amount, term_biweeks),
    CONSTRAINT check_legacy_amount_positive CHECK (amount > 0),
    CONSTRAINT check_legacy_payment_positive CHECK (biweekly_payment > 0),
    CONSTRAINT check_legacy_term_valid CHECK (term_biweeks BETWEEN 1 AND 52)
);

COMMENT ON TABLE legacy_payment_table IS 'Tabla histórica de pagos quincenales. TOTALMENTE EDITABLE por admin. Permite agregar montos como $7,500, $12,350, etc.';
COMMENT ON COLUMN legacy_payment_table.amount IS 'Monto del préstamo (capital). Debe ser único para cada plazo.';
COMMENT ON COLUMN legacy_payment_table.biweekly_payment IS 'Pago quincenal fijo para este monto. Admin puede editarlo.';
COMMENT ON COLUMN legacy_payment_table.effective_rate_percent IS 'Tasa efectiva total calculada automáticamente.';
COMMENT ON COLUMN legacy_payment_table.biweekly_rate_percent IS 'Tasa quincenal promedio calculada automáticamente.';

CREATE INDEX idx_legacy_amount ON legacy_payment_table(amount);
CREATE INDEX idx_legacy_term ON legacy_payment_table(term_biweeks);
CREATE UNIQUE INDEX idx_legacy_amount_term_unique ON legacy_payment_table(amount, term_biweeks);

-- =============================================================================
-- TRIGGER: Actualizar updated_at en legacy_payment_table
-- =============================================================================
CREATE OR REPLACE FUNCTION update_legacy_payment_table_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_legacy_payment_table_updated_at
BEFORE UPDATE ON legacy_payment_table
FOR EACH ROW
EXECUTE FUNCTION update_legacy_payment_table_timestamp();

-- =============================================================================
-- FUNCIÓN 1: calculate_loan_payment - Cálculo Unificado
-- =============================================================================
-- =============================================================================
-- FUNCIÓN 1: calculate_loan_payment - Calcula con las DOS TASAS
-- =============================================================================
CREATE OR REPLACE FUNCTION calculate_loan_payment(
    p_amount DECIMAL(12,2),
    p_term_biweeks INT,
    p_profile_code VARCHAR(50)
) RETURNS TABLE (
    profile_code VARCHAR(50),
    profile_name VARCHAR(100),
    calculation_method VARCHAR(20),
    
    -- ⭐ LAS DOS TASAS del perfil
    interest_rate_percent DECIMAL(5,3),
    commission_rate_percent DECIMAL(5,3),
    
    -- Cálculos CLIENTE
    biweekly_payment DECIMAL(10,2),
    total_payment DECIMAL(12,2),
    total_interest DECIMAL(12,2),
    effective_rate_percent DECIMAL(5,2),
    
    -- Cálculos ASOCIADO
    commission_per_payment DECIMAL(10,2),
    total_commission DECIMAL(12,2),
    associate_payment DECIMAL(10,2),
    associate_total DECIMAL(12,2)
) AS $$
DECLARE
    v_profile RECORD;
    v_legacy_entry RECORD;
    v_factor DECIMAL(10,6);
    v_total DECIMAL(12,2);
    v_payment DECIMAL(10,2);
    v_commission_per_payment DECIMAL(10,2);
BEGIN
    -- Obtener perfil con LAS DOS TASAS
    SELECT * INTO v_profile
    FROM rate_profiles
    WHERE code = p_profile_code AND enabled = true;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Perfil de tasa no encontrado o deshabilitado: %', p_profile_code;
    END IF;
    
    -- MÉTODO 1: Table Lookup (perfil legacy)
    IF v_profile.calculation_type = 'table_lookup' THEN
        SELECT * INTO v_legacy_entry
        FROM legacy_payment_table
        WHERE amount = p_amount AND term_biweeks = p_term_biweeks;
        
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Monto % no encontrado en tabla legacy para plazo %Q', p_amount, p_term_biweeks;
        END IF;
        
        v_payment := v_legacy_entry.biweekly_payment;
        v_total := v_legacy_entry.total_payment;
        
        -- Para legacy, usar comisión del perfil o default 2.5%
        v_commission_per_payment := v_payment * (COALESCE(v_profile.commission_rate_percent, 2.5) / 100);
        
        RETURN QUERY SELECT
            v_profile.code,
            v_profile.name,
            v_profile.calculation_type,
            
            v_legacy_entry.biweekly_rate_percent AS interest_rate,
            COALESCE(v_profile.commission_rate_percent, 2.5) AS commission_rate,
            
            v_payment,
            v_total,
            v_legacy_entry.total_interest,
            v_legacy_entry.effective_rate_percent,
            
            ROUND(v_commission_per_payment, 2),
            ROUND(v_commission_per_payment * p_term_biweeks, 2),
            ROUND(v_payment - v_commission_per_payment, 2),
            ROUND((v_payment - v_commission_per_payment) * p_term_biweeks, 2);
        
        RETURN;
    END IF;
    
    -- MÉTODO 2: Formula (perfiles transition, standard, premium, custom)
    IF v_profile.calculation_type = 'formula' THEN
        IF v_profile.interest_rate_percent IS NULL THEN
            RAISE EXCEPTION 'Perfil % tipo formula requiere interest_rate_percent configurado', p_profile_code;
        END IF;
        
        IF v_profile.commission_rate_percent IS NULL THEN
            RAISE EXCEPTION 'Perfil % tipo formula requiere commission_rate_percent configurado', p_profile_code;
        END IF;
        
        -- Calcular CLIENTE (interés simple)
        v_factor := 1 + (v_profile.interest_rate_percent / 100) * p_term_biweeks;
        v_total := p_amount * v_factor;
        v_payment := v_total / p_term_biweeks;
        
        -- Calcular ASOCIADO (comisión sobre pago)
        v_commission_per_payment := v_payment * (v_profile.commission_rate_percent / 100);
        
        RETURN QUERY SELECT
            v_profile.code,
            v_profile.name,
            v_profile.calculation_type,
            
            v_profile.interest_rate_percent,
            v_profile.commission_rate_percent,
            
            ROUND(v_payment, 2) AS biweekly_payment,
            ROUND(v_total, 2) AS total_payment,
            ROUND(v_total - p_amount, 2) AS total_interest,
            ROUND(((v_total - p_amount) / p_amount * 100)::NUMERIC, 2) AS effective_rate,
            
            ROUND(v_commission_per_payment, 2),
            ROUND(v_commission_per_payment * p_term_biweeks, 2),
            ROUND(v_payment - v_commission_per_payment, 2),
            ROUND((v_payment - v_commission_per_payment) * p_term_biweeks, 2);
        
        RETURN;
    END IF;
    
    RAISE EXCEPTION 'Tipo de cálculo no soportado: %', v_profile.calculation_type;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION calculate_loan_payment IS 
'Calcula pago quincenal según perfil. Devuelve LAS DOS TASAS (interest + commission) y todos los cálculos para cliente y asociado. Soporta table_lookup (busca en legacy_payment_table) y formula (interés simple).';

-- =============================================================================
-- FUNCIÓN 2: generate_loan_summary - Tabla Resumen (Como en foto)
-- =============================================================================
CREATE OR REPLACE FUNCTION generate_loan_summary(
    p_amount DECIMAL(12,2),
    p_term_biweeks INT,
    p_interest_rate DECIMAL(5,3),
    p_commission_rate DECIMAL(5,2)
) RETURNS TABLE (
    -- Datos básicos
    capital DECIMAL(12,2),
    plazo_quincenas INTEGER,
    
    -- Tasas
    tasa_interes_quincenal DECIMAL(5,3),
    tasa_comision DECIMAL(5,2),
    
    -- Cálculos CLIENTE (quien pide el préstamo)
    pago_quincenal_cliente DECIMAL(10,2),
    pago_total_cliente DECIMAL(12,2),
    interes_total_cliente DECIMAL(12,2),
    tasa_efectiva_cliente DECIMAL(5,2),
    
    -- Cálculos SOCIO (Asociado que gestiona)
    comision_por_pago DECIMAL(10,2),
    comision_total_socio DECIMAL(12,2),
    pago_quincenal_socio DECIMAL(10,2),
    pago_total_socio DECIMAL(12,2)
) AS $$
DECLARE
    v_factor DECIMAL(10,6);
    v_total_cliente DECIMAL(12,2);
    v_pago_q_cliente DECIMAL(10,2);
    v_interes_cliente DECIMAL(12,2);
    v_comision_por_pago DECIMAL(10,2);
    v_comision_total DECIMAL(12,2);
    v_pago_q_socio DECIMAL(10,2);
BEGIN
    -- Calcular CLIENTE (Interés Simple)
    v_factor := 1 + (p_interest_rate / 100) * p_term_biweeks;
    v_total_cliente := p_amount * v_factor;
    v_pago_q_cliente := v_total_cliente / p_term_biweeks;
    v_interes_cliente := v_total_cliente - p_amount;
    
    -- Calcular SOCIO (Comisión sobre pago del cliente)
    v_comision_por_pago := v_pago_q_cliente * (p_commission_rate / 100);
    v_comision_total := v_comision_por_pago * p_term_biweeks;
    v_pago_q_socio := v_pago_q_cliente - v_comision_por_pago;
    
    RETURN QUERY SELECT
        p_amount AS capital,
        p_term_biweeks AS plazo_quincenas,
        
        p_interest_rate AS tasa_interes_quincenal,
        p_commission_rate AS tasa_comision,
        
        ROUND(v_pago_q_cliente, 2) AS pago_quincenal_cliente,
        ROUND(v_total_cliente, 2) AS pago_total_cliente,
        ROUND(v_interes_cliente, 2) AS interes_total_cliente,
        ROUND(((v_interes_cliente / p_amount * 100)::NUMERIC), 2) AS tasa_efectiva_cliente,
        
        ROUND(v_comision_por_pago, 2) AS comision_por_pago,
        ROUND(v_comision_total, 2) AS comision_total_socio,
        ROUND(v_pago_q_socio, 2) AS pago_quincenal_socio,
        ROUND(v_pago_q_socio * p_term_biweeks, 2) AS pago_total_socio;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION generate_loan_summary IS 'Genera tabla resumen completa con cálculos de CLIENTE y SOCIO (asociado). Muestra: pagos quincenales, totales, intereses, comisiones. Similar a tabla "Importe de prestamos" de la UI.';

-- =============================================================================
-- FUNCIÓN 3: generate_amortization_schedule - Tabla de Amortización
-- =============================================================================
CREATE OR REPLACE FUNCTION generate_amortization_schedule(
    p_amount DECIMAL(12,2),
    p_biweekly_payment DECIMAL(10,2),
    p_term_biweeks INT,
    p_commission_rate DECIMAL(5,2),
    p_start_date DATE DEFAULT CURRENT_DATE
) RETURNS TABLE (
    periodo INTEGER,
    fecha_pago DATE,
    pago_cliente DECIMAL(10,2),
    interes_cliente DECIMAL(10,2),
    capital_cliente DECIMAL(10,2),
    saldo_pendiente DECIMAL(12,2),
    comision_socio DECIMAL(10,2),
    pago_socio DECIMAL(10,2)
) AS $$
DECLARE
    v_current_date DATE;
    v_balance DECIMAL(12,2);
    v_total_interest DECIMAL(12,2);
    v_period_interest DECIMAL(10,2);
    v_period_principal DECIMAL(10,2);
    v_commission DECIMAL(10,2);
    v_payment_to_associate DECIMAL(10,2);
    v_is_day_15 BOOLEAN;
BEGIN
    -- Inicializar
    v_balance := p_amount;
    v_total_interest := (p_biweekly_payment * p_term_biweeks) - p_amount;
    v_current_date := p_start_date;
    
    -- Generar cronograma completo
    FOR v_period IN 1..p_term_biweeks LOOP
        -- Calcular interés y capital del período (distribución proporcional)
        v_period_interest := v_total_interest / p_term_biweeks;
        v_period_principal := p_biweekly_payment - v_period_interest;
        
        -- Actualizar saldo
        v_balance := v_balance - v_period_principal;
        
        -- Evitar saldo negativo por redondeo
        IF v_balance < 0.01 THEN
            v_balance := 0;
        END IF;
        
        -- Calcular comisión del asociado
        v_commission := p_biweekly_payment * (p_commission_rate / 100);
        v_payment_to_associate := p_biweekly_payment - v_commission;
        
        -- Retornar fila
        RETURN QUERY SELECT
            v_period,
            v_current_date,
            p_biweekly_payment,
            ROUND(v_period_interest, 2),
            ROUND(v_period_principal, 2),
            ROUND(v_balance, 2),
            ROUND(v_commission, 2),
            ROUND(v_payment_to_associate, 2);
        
        -- Calcular siguiente fecha (alternancia día 15 ↔ último día del mes)
        v_is_day_15 := EXTRACT(DAY FROM v_current_date) = 15;
        
        IF v_is_day_15 THEN
            -- Si es día 15 → siguiente es último día del mes actual
            v_current_date := (DATE_TRUNC('month', v_current_date) + INTERVAL '1 month' - INTERVAL '1 day')::DATE;
        ELSE
            -- Si es último día → siguiente es día 15 del mes siguiente
            v_current_date := MAKE_DATE(
                EXTRACT(YEAR FROM v_current_date + INTERVAL '1 month')::INTEGER,
                EXTRACT(MONTH FROM v_current_date + INTERVAL '1 month')::INTEGER,
                15
            );
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION generate_amortization_schedule IS 'Genera tabla de amortización completa con fechas, pagos del cliente, interés, capital, saldo pendiente, comisión del asociado y pago al asociado. Usa lógica de doble calendario (día 15 y último día del mes).';

-- =============================================================================
-- INSERTAR PERFILES INICIALES (Con las DOS TASAS)
-- =============================================================================
INSERT INTO rate_profiles (
    code, 
    name, 
    description, 
    calculation_type, 
    interest_rate_percent,      -- ⭐ Tasa al CLIENTE
    commission_rate_percent,    -- ⭐ Tasa de COMISIÓN
    enabled, 
    is_recommended, 
    display_order, 
    valid_terms
)
VALUES
-- Perfil 1: Tabla Legacy (editable)
('legacy', 
 'Tabla Histórica v2.0', 
 'Sistema actual con montos predefinidos en tabla. Totalmente editable por admin. Permite agregar nuevos montos como $7,500, $12,350, etc.',
 'table_lookup', 
 NULL,    -- No usa tasa fija, consulta tabla
 2.500,   -- Comisión default 2.5%
 true, 
 false, 
 1,
 ARRAY[12]),  -- Solo 12 quincenas por ahora

-- Perfil 2: Transición Suave (3.75% + 2.5%)
('transition', 
 'Transición Suave 3.75%', 
 'Tasa reducida para facilitar adopción gradual. Cliente ahorra vs tabla actual. Ideal para primeros 6 meses de migración.',
 'formula', 
 3.750,   -- Interés al cliente
 2.500,   -- Comisión al asociado
 true, 
 false, 
 2,
 ARRAY[6,12,18,24]),

-- Perfil 3: Estándar (4.25% + 2.5%) - RECOMENDADO
('standard', 
 'Estándar 4.25% - Recomendado', 
 'Balance óptimo entre competitividad y rentabilidad. Tasa ~51% total (12Q), similar al promedio actual. Recomendado para mayoría de casos.',
 'formula', 
 4.250,   -- Interés al cliente
 2.500,   -- Comisión al asociado
 true, 
 true,    -- ⭐ RECOMENDADO
 3,
 ARRAY[3,6,9,12,15,18,21,24,30,36]),

-- Perfil 4: Premium (4.5% + 2.5%)
('premium', 
 'Premium 4.5%', 
 'Tasa objetivo con máxima rentabilidad (54% total en 12Q). Mantiene competitividad vs mercado (60-80%). Activar desde mes 7+ de migración.',
 'formula', 
 4.500,   -- Interés al cliente
 2.500,   -- Comisión al asociado
 false,   -- Deshabilitado inicialmente
 false, 
 4,
 ARRAY[3,6,9,12,15,18,21,24,30,36]),

-- Perfil 5: Personalizado (tasa variable + 2.5%)
('custom', 
 'Personalizado', 
 'Tasa ajustable manualmente para casos especiales. Requiere aprobación de gerente/admin. Rango permitido: 2.0% - 6.0% quincenal.',
 'formula', 
 NULL,    -- Se define al momento
 2.500,   -- Comisión estándar
 true, 
 false, 
 5,
 NULL);   -- Permite cualquier plazo

-- =============================================================================
-- INSERTAR DATOS LEGACY (28 montos históricos @ 12 quincenas)
-- =============================================================================
INSERT INTO legacy_payment_table (amount, biweekly_payment, term_biweeks) VALUES
(3000, 392, 12),
(4000, 510, 12),
(5000, 633, 12),
(6000, 752, 12),
(7000, 882, 12),
(8000, 1006, 12),
(9000, 1131, 12),
(10000, 1255, 12),
(11000, 1385, 12),
(12000, 1504, 12),
(13000, 1634, 12),
(14000, 1765, 12),
(15000, 1888, 12),
(16000, 2012, 12),
(17000, 2137, 12),
(18000, 2262, 12),
(19000, 2386, 12),
(20000, 2510, 12),
(21000, 2640, 12),
(22000, 2759, 12),
(23000, 2889, 12),
(24000, 3020, 12),
(25000, 3143, 12),
(26000, 3267, 12),
(27000, 3392, 12),
(28000, 3517, 12),
(29000, 3641, 12),
(30000, 3765, 12);

-- =============================================================================
-- EJEMPLOS DE USO
-- =============================================================================

-- Ejemplo 1: Calcular con perfil legacy (busca en tabla)
-- SELECT * FROM calculate_loan_payment(22000, 12, 'legacy');

-- Ejemplo 2: Calcular con perfil standard (fórmula 4.25%)
-- SELECT * FROM calculate_loan_payment(22000, 12, 'standard');

-- Ejemplo 3: Calcular con tasa personalizada
-- SELECT * FROM calculate_loan_payment(22000, 12, 'custom', 3.85);

-- Ejemplo 4: Generar tabla resumen completa (como en foto)
-- SELECT * FROM generate_loan_summary(
--     22000,           -- capital
--     12,              -- plazo
--     4.25,            -- tasa interés cliente (quincenal)
--     2.5              -- tasa comisión socio
-- );

-- Ejemplo 5: Generar tabla de amortización
-- SELECT * FROM generate_amortization_schedule(
--     22000,           -- capital
--     2765,            -- pago quincenal
--     12,              -- plazo
--     2.5,             -- tasa comisión
--     '2025-11-15'     -- fecha inicio
-- );

-- Ejemplo 6: Comparar múltiples perfiles
-- SELECT 
--     'Legacy' as perfil, * FROM calculate_loan_payment(22000, 12, 'legacy')
-- UNION ALL
-- SELECT 
--     'Transición' as perfil, * FROM calculate_loan_payment(22000, 12, 'transition')
-- UNION ALL
-- SELECT 
--     'Estándar' as perfil, * FROM calculate_loan_payment(22000, 12, 'standard')
-- UNION ALL
-- SELECT 
--     'Premium' as perfil, * FROM calculate_loan_payment(22000, 12, 'premium');

COMMENT ON SCHEMA public IS 'Schema público de CrediCuenta v2.0.3 con sistema de perfiles de tasa flexible.';
