# 🔍 AUDITORÍA COMPLETA BACKEND vs DB v2.0 - LÓGICA DE NEGOCIO

> **Fecha**: 2025-10-30  
> **Objetivo**: Comparar implementación actual del backend con TODA la lógica de negocio en db/v2.0/modules/  
> **Fuente de Verdad**: `/db/v2.0/modules/` (9 archivos SQL - 3,240 líneas)  
> **Estado Backend**: 1/9 módulos implementados (auth) - 95% PENDIENTE  

---

## 📊 RESUMEN EJECUTIVO

### Estado Actual Backend

**IMPLEMENTADO (5%)**:
- ✅ Módulo `auth/` - Parcial (solo login, faltan roles dinámicos)
- ✅ Core infrastructure (config, database, security, middleware, exceptions)

**PENDIENTE (95%)**:
- ❌ 12 Catálogos (roles, statuses, levels, types)
- ❌ Préstamos (loans) - CRÍTICO
- ❌ Pagos (payments) - CRÍTICO
- ❌ Asociados (associates) - IMPORTANTE
- ❌ Contratos (contracts)
- ❌ Convenios (agreements)
- ❌ Períodos de Corte (cut_periods)
- ❌ Documentos (documents)
- ❌ 16 Funciones DB
- ❌ 28+ Triggers
- ❌ 9 Vistas

---

## 🗄️ BASE DE DATOS v2.0 (Fuente de Verdad)

### Tablas Totales: 45 tables

#### 1. CATÁLOGOS (12 tables) - ❌ 0% IMPLEMENTADO

**Tabla: `roles`**
```sql
id | name            | description
---+----------------+----------------------------------
1  | administrador  | Acceso completo al sistema
2  | asociado       | Gestiona préstamos y clientes
3  | cliente        | Solicita préstamos
4  | auditor        | Solo lectura para auditoría
5  | desarrollador  | Acceso técnico completo
```
**Estado Backend**: ❌ NO EXISTE módulo `catalogs/`
**Problema**: User entity tiene `role` hardcoded, NO usa tabla `user_roles`
**Impacto**: NO se pueden asignar múltiples roles a un usuario

---

**Tabla: `loan_statuses`** (7 estados)
```sql
id | name                | description                       | color_code | icon_name
---+--------------------+----------------------------------+------------+-----------
1  | SOLICITADO         | Préstamo en proceso de revisión  | #FFA500    | clock
2  | APROBADO           | Préstamo aprobado                | #4CAF50    | check
3  | RECHAZADO          | Préstamo rechazado               | #F44336    | x
4  | DESEMBOLSADO       | Dinero entregado al cliente      | #2196F3    | dollar
5  | EN_PAGOS           | Cliente realizando pagos         | #FF9800    | payment
6  | LIQUIDADO          | Préstamo completamente pagado    | #8BC34A    | success
7  | VENCIDO            | Préstamo con pagos atrasados     | #D32F2F    | alert
```
**Estado Backend**: ❌ NO EXISTE módulo `loans/`
**Problema**: Sin tabla, sin flujo de estados, sin color_code/icon_name
**Impacto**: NO se puede aprobar/rechazar préstamos, NO hay workflow

---

**Tabla: `payment_statuses`** (12 estados) ⭐ CRÍTICO
```sql
id | name                  | description                              | is_real_payment
---+----------------------+-----------------------------------------+----------------
1  | SCHEDULED            | Pago programado                          | false
2  | PENDING              | Pago pendiente de realizar               | false
3  | DUE_TODAY            | Vence hoy                                | false
4  | OVERDUE              | Pago atrasado                            | false
5  | IN_PROCESS           | Pago en proceso de verificación          | false
6  | PENDING_VERIFICATION | Pago pendiente de verificación           | false
7  | PAID                 | Pago realizado (REAL)                    | true  ✅
8  | PAID_PARTIAL         | Pago parcial realizado (REAL)            | true  ✅
9  | PAID_NOT_REPORTED    | Cliente NO pagó, reportado (FICTICIO)    | false ⚠️
10 | PAID_BY_ASSOCIATE    | Cliente NO pagó, NO reportado (FICTICIO) | false ⚠️
11 | FORGIVEN             | Pago perdonado (FICTICIO)                | false ⚠️
12 | CANCELLED            | Pago cancelado (FICTICIO)                | false ⚠️
```
**Estado Backend**: ❌ NO EXISTE módulo `payments/`
**Problema**: Sistema completo de 12 estados NO implementado
**Impacto**: 
- NO se pueden marcar pagos manualmente
- NO hay distinción entre pagos REALES (💵) vs FICTICIOS (⚠️)
- NO se puede acumular deuda de pagos no reportados
- NO hay auditoría de cambios de estado

---

**Tabla: `associate_levels`** (5 niveles) ⭐ IMPORTANTE
```sql
id | level_name | max_loan_amount | credit_limit | description
---+-----------+----------------+-------------+------------------
1  | BRONCE    | 10000.00       | 30000.00    | Nivel inicial
2  | PLATA     | 25000.00       | 75000.00    | Nivel intermedio
3  | ORO       | 50000.00       | 150000.00   | Nivel avanzado
4  | PLATINO   | 100000.00      | 300000.00   | Nivel premium
5  | DIAMANTE  | 200000.00      | 600000.00   | Nivel élite
```
**Estado Backend**: ❌ NO EXISTE módulo `associates/`
**Problema**: Sistema de niveles NO implementado
**Impacto**: 
- NO se puede validar si préstamo excede `max_loan_amount` del nivel
- NO se puede validar si asociado tiene `credit_available`
- NO hay tracking de crédito usado vs límite

---

**Otras Catálogos (9 más)**: ❌ NO IMPLEMENTADOS
- `contract_statuses` (4 estados)
- `cut_period_statuses` (4 estados)
- `payment_methods` (6 métodos)
- `document_statuses` (4 estados)
- `statement_statuses` (4 estados)
- `config_types` (3 tipos)
- `level_change_types` (3 tipos)
- `document_types` (6 tipos)

**Problema General**: Sin catálogos, TODO está hardcoded (strings mágicos)

---

#### 2. CORE TABLES (11 tables) - ❌ 9% IMPLEMENTADO (solo users)

**Tabla: `users`** ✅ PARCIALMENTE IMPLEMENTADO
```sql
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(150) UNIQUE,                    -- NULLABLE ✅
    phone_number VARCHAR(20) UNIQUE NOT NULL,
    birth_date DATE,                              -- ✅ AGREGADO
    curp VARCHAR(18) UNIQUE,                      -- ✅ AGREGADO
    profile_picture_url TEXT,                     -- ✅ AGREGADO
    created_at TIMESTAMPTZ DEFAULT NOW(),         -- ✅ AGREGADO
    updated_at TIMESTAMPTZ DEFAULT NOW()          -- ✅ AGREGADO
);
```
**Estado Backend**: ✅ IMPLEMENTADO en `auth/domain/entities/user.py`
**Problemas detectados**:
1. ❌ Campos `is_active` y `is_defaulter` NO existen en DB
2. ❌ Campo `role` hardcoded, debe venir de tabla `user_roles`
3. ❌ Repository hardcodea `role="administrador"` (línea 110)

**Acción requerida**:
- Eliminar `is_active` y `is_defaulter` de User entity (NO están en DB v2.0)
- Crear JOIN con `user_roles` para obtener roles dinámicos
- Agregar método `get_user_roles(user_id)` en repository

---

**Tabla: `user_roles`** ❌ NO IMPLEMENTADO
```sql
CREATE TABLE user_roles (
    user_id INT REFERENCES users(id) ON DELETE CASCADE,
    role_id INT REFERENCES roles(id) ON DELETE CASCADE,
    PRIMARY KEY (user_id, role_id)
);
```
**Estado Backend**: ❌ NO EXISTE entity ni repository
**Problema**: User tiene 1 rol hardcoded, debe soportar múltiples roles
**Impacto**: Un usuario NO puede ser asociado+administrador simultáneamente

---

**Tabla: `loans`** ❌ NO IMPLEMENTADO ⭐ CRÍTICO
```sql
CREATE TABLE loans (
    id SERIAL PRIMARY KEY,
    user_id INT REFERENCES users(id),                    -- Cliente
    associate_user_id INT REFERENCES users(id),          -- Asociado gestor
    amount NUMERIC(12,2) NOT NULL CHECK (amount > 0),
    interest_rate NUMERIC(5,2) NOT NULL,                 -- Porcentaje
    commission_rate NUMERIC(5,2) NOT NULL,               -- Porcentaje
    term_biweeks INT NOT NULL CHECK (term_biweeks BETWEEN 1 AND 52),
    status_id INT REFERENCES loan_statuses(id),
    request_date DATE NOT NULL DEFAULT CURRENT_DATE,
    approval_date DATE,
    rejection_date DATE,
    rejection_reason TEXT,
    total_amount NUMERIC(12,2) GENERATED ALWAYS AS (amount * (1 + interest_rate/100)) STORED,
    biweekly_payment NUMERIC(12,2) GENERATED ALWAYS AS (total_amount / term_biweeks) STORED,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
```
**Estado Backend**: ❌ NO EXISTE módulo `loans/`
**Campos críticos**:
- `term_biweeks`: 1-52 quincenas (validación CHECK)
- `total_amount`: GENERATED (amount * (1 + interest_rate/100))
- `biweekly_payment`: GENERATED (total_amount / term_biweeks)
- `associate_user_id`: FK a asociado que gestionó el préstamo

**Funcionalidad faltante**:
- CRUD préstamos
- Workflow aprobación (SOLICITADO → APROBADO → DESEMBOLSADO)
- Generación automática de cronograma (trigger)
- Validación crédito asociado disponible

---

**Tabla: `payments`** ❌ NO IMPLEMENTADO ⭐ CRÍTICO
```sql
CREATE TABLE payments (
    id SERIAL PRIMARY KEY,
    loan_id INT REFERENCES loans(id) ON DELETE CASCADE,
    cut_period_id INT REFERENCES cut_periods(id),
    payment_number INT NOT NULL,                         -- 1, 2, 3..., term_biweeks
    scheduled_amount NUMERIC(12,2) NOT NULL,
    amount_paid NUMERIC(12,2),
    due_date DATE NOT NULL,
    payment_date DATE,
    status_id INT REFERENCES payment_statuses(id),       -- 12 estados
    payment_method_id INT REFERENCES payment_methods(id),
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
```
**Estado Backend**: ❌ NO EXISTE módulo `payments/`
**Campos críticos**:
- `payment_number`: Secuencia 1, 2, 3..., hasta term_biweeks
- `due_date`: Calculado por función `calculate_first_payment_date()` (ORÁCULO)
- `status_id`: 12 estados (PAID, PAID_NOT_REPORTED, PAID_BY_ASSOCIATE, etc.)
- `cut_period_id`: Asociación a período quincenal

**Funcionalidad faltante**:
- CRUD pagos
- Marcar estado manualmente (admin)
- Timeline forense (auditoría completa)
- Detección fraudes (pagos con 3+ cambios)
- Reversión de cambios

---

**Tabla: `contracts`** ❌ NO IMPLEMENTADO
```sql
CREATE TABLE contracts (
    id SERIAL PRIMARY KEY,
    loan_id INT REFERENCES loans(id) ON DELETE CASCADE UNIQUE,
    contract_number VARCHAR(50) UNIQUE NOT NULL,
    contract_text TEXT NOT NULL,
    status_id INT REFERENCES contract_statuses(id),
    generated_at TIMESTAMPTZ DEFAULT NOW(),
    signed_at TIMESTAMPTZ,
    signature_path TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
```
**Estado Backend**: ❌ NO EXISTE módulo `contracts/`
**Funcionalidad faltante**:
- Generación PDF (Jinja2 template)
- Firma digitalizada
- Almacenamiento contratos

---

**Tabla: `cut_periods`** ❌ NO IMPLEMENTADO ⭐ IMPORTANTE
```sql
CREATE TABLE cut_periods (
    id SERIAL PRIMARY KEY,
    period_number INT NOT NULL,                         -- 1-24 (año)
    year INT NOT NULL,
    period_start_date DATE NOT NULL,                    -- Día 8
    period_end_date DATE NOT NULL,                      -- Día 23
    status_id INT REFERENCES cut_period_statuses(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(period_number, year)
);
```
**Estado Backend**: ❌ NO EXISTE módulo `cut_periods/`
**Funcionalidad faltante**:
- Crear períodos quincenales (días 8-23)
- Cerrar período (función `close_period_and_accumulate_debt()`)
- Marcar TODOS los pagos (PAID, PAID_NOT_REPORTED, PAID_BY_ASSOCIATE)
- Acumular deuda asociado

---

**Otras Core Tables (5 más)**: ❌ NO IMPLEMENTADAS
- `addresses` (direcciones clientes)
- `beneficiaries` (beneficiarios préstamos)
- `guarantors` (avales)
- `client_documents` (documentos clientes)
- `system_configurations` (configuraciones sistema)

---

#### 3. BUSINESS TABLES (8 tables) - ❌ 0% IMPLEMENTADO

**Tabla: `associate_profiles`** ❌ NO IMPLEMENTADO ⭐ CRÍTICO
```sql
CREATE TABLE associate_profiles (
    user_id INT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    level_id INT REFERENCES associate_levels(id) NOT NULL,
    credit_limit NUMERIC(12,2) NOT NULL,
    credit_used NUMERIC(12,2) GENERATED ALWAYS AS (
        SELECT COALESCE(SUM(l.amount), 0)
        FROM loans l
        WHERE l.associate_user_id = associate_profiles.user_id
        AND l.status_id IN (2, 4, 5)  -- APROBADO, DESEMBOLSADO, EN_PAGOS
    ) STORED,
    credit_available NUMERIC(12,2) GENERATED ALWAYS AS (credit_limit - credit_used) STORED,
    debt_balance NUMERIC(12,2) NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
```
**Estado Backend**: ❌ NO EXISTE módulo `associates/`
**Campos CRÍTICOS**:
- `credit_used`: GENERATED (suma de préstamos activos)
- `credit_available`: GENERATED (credit_limit - credit_used)
- `debt_balance`: Deuda acumulada (convenios)

**Funcionalidad faltante**:
- Tracking crédito usado vs límite
- Validación crédito disponible antes de aprobar préstamo
- Vista `v_associate_credit_summary`
- Cálculo mora 30% (late_fee)

---

**Tabla: `associate_payment_statements`** ❌ NO IMPLEMENTADO
```sql
CREATE TABLE associate_payment_statements (
    id SERIAL PRIMARY KEY,
    associate_profile_id INT REFERENCES associate_profiles(user_id),
    cut_period_id INT REFERENCES cut_periods(id),
    total_payments_count INT NOT NULL DEFAULT 0,
    paid_payments_count INT NOT NULL DEFAULT 0,
    not_reported_count INT NOT NULL DEFAULT 0,
    absorbed_payments_count INT NOT NULL DEFAULT 0,
    total_commission_owed NUMERIC(12,2) NOT NULL DEFAULT 0,
    late_fee_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
    late_fee_applied BOOLEAN NOT NULL DEFAULT false,
    status_id INT REFERENCES statement_statuses(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
```
**Estado Backend**: ❌ NO EXISTE módulo `associates/`
**Campos CRÍTICOS**:
- `late_fee_amount`: Mora del 30% si `total_payments_count = 0`
- `not_reported_count`: Pagos PAID_NOT_REPORTED (cliente NO pagó, reportado)
- `absorbed_payments_count`: Pagos PAID_BY_ASSOCIATE (cliente NO pagó, NO reportado)

**Funcionalidad faltante**:
- Estados de cuenta por período
- Cálculo mora automático
- Tracking comisiones

---

**Tabla: `agreements`** ❌ NO IMPLEMENTADO ⭐ IMPORTANTE
```sql
CREATE TABLE agreements (
    id SERIAL PRIMARY KEY,
    associate_profile_id INT REFERENCES associate_profiles(user_id),
    total_debt_amount NUMERIC(12,2) NOT NULL,
    payment_plan_months INT NOT NULL,
    monthly_payment_amount NUMERIC(12,2) NOT NULL,
    agreement_date DATE NOT NULL DEFAULT CURRENT_DATE,
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
```
**Estado Backend**: ❌ NO EXISTE módulo `agreements/`
**Funcionalidad faltante**:
- Crear convenio de pago
- Desglose deuda (items: UNREPORTED, DEFAULTED, LATE_FEE)
- Cronograma mensual
- Pagos convenio

---

**Tabla: `loan_renewals`** ❌ NO IMPLEMENTADO
```sql
CREATE TABLE loan_renewals (
    id SERIAL PRIMARY KEY,
    original_loan_id INT REFERENCES loans(id),
    new_loan_id INT REFERENCES loans(id),
    pending_balance NUMERIC(12,2) NOT NULL,
    renewal_date DATE NOT NULL DEFAULT CURRENT_DATE,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```
**Estado Backend**: ❌ NO EXISTE módulo `loans/`
**Funcionalidad faltante**:
- Renovar préstamo (función `renew_loan()`)
- Liquidar anterior + crear nuevo

---

**Otras Business Tables (4 más)**: ❌ NO IMPLEMENTADAS
- `agreement_items` (desglose deuda convenio)
- `agreement_payments` (pagos convenio)
- `associate_accumulated_balances` (saldos acumulados)
- `associate_level_history` (historial cambios nivel)

---

#### 4. AUDIT TABLES (4 tables) - ❌ 0% IMPLEMENTADO

**Tabla: `payment_status_history`** ❌ NO IMPLEMENTADO ⭐ CRÍTICO
```sql
CREATE TABLE payment_status_history (
    id SERIAL PRIMARY KEY,
    payment_id INT REFERENCES payments(id) ON DELETE CASCADE,
    old_status_id INT REFERENCES payment_statuses(id),
    new_status_id INT REFERENCES payment_statuses(id),
    changed_by_user_id INT REFERENCES users(id),
    change_timestamp TIMESTAMPTZ DEFAULT NOW(),
    admin_notes TEXT,
    is_suspicious BOOLEAN DEFAULT false
);
```
**Estado Backend**: ❌ NO EXISTE módulo `payments/`
**Funcionalidad faltante**:
- Timeline forense (MIGRACIÓN 12)
- Log automático cambios (trigger)
- Detección fraudes
- Reversión cambios

---

**Tabla: `defaulted_client_reports`** ❌ NO IMPLEMENTADO
```sql
CREATE TABLE defaulted_client_reports (
    id SERIAL PRIMARY KEY,
    loan_id INT REFERENCES loans(id),
    reported_by_associate_id INT REFERENCES users(id),
    total_debt_amount NUMERIC(12,2) NOT NULL,
    report_date DATE NOT NULL DEFAULT CURRENT_DATE,
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    evidence_details TEXT,
    evidence_file_path TEXT,
    approval_date DATE,
    approved_by_user_id INT REFERENCES users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
```
**Estado Backend**: ❌ NO EXISTE módulo `reports/`
**Funcionalidad faltante**:
- Reportar cliente moroso (MIGRACIÓN 09)
- Subir evidencia
- Aprobar/rechazar reporte

---

**Otras Audit Tables (2 más)**: ❌ NO IMPLEMENTADAS
- `associate_debt_breakdown` (desglose deuda por tipo)
- `audit_log` (log general sistema)

---

## 🔧 FUNCIONES DB (16 functions) - ❌ 0% IMPLEMENTADO

### NIVEL 1: Funciones Base (11 functions)

#### 1. `calculate_first_payment_date()` ⭐ ORÁCULO DEL DOBLE CALENDARIO
```sql
CREATE OR REPLACE FUNCTION calculate_first_payment_date(
    p_request_date DATE,
    p_term_biweeks INT
) RETURNS DATE AS $$
DECLARE
    v_day INT := EXTRACT(DAY FROM p_request_date);
    v_first_payment DATE;
BEGIN
    -- LÓGICA COMPLEJA (30 líneas)
    -- Calcula primer vencimiento según doble calendario
    -- Cortes administrativos: días 8-23
    -- Vencimientos clientes: días 15-último
END;
$$ LANGUAGE plpgsql;
```
**Estado Backend**: ❌ NO IMPLEMENTADO
**Problema**: Sin esta función, NO se pueden calcular fechas de vencimiento correctamente
**Impacto**: Cronograma de pagos INCORRECTO

---

#### 2. `calculate_loan_remaining_balance()`
```sql
CREATE OR REPLACE FUNCTION calculate_loan_remaining_balance(p_loan_id INT)
RETURNS NUMERIC AS $$
    SELECT l.total_amount - COALESCE(SUM(p.amount_paid), 0)
    FROM loans l
    LEFT JOIN payments p ON p.loan_id = l.id
    WHERE l.id = p_loan_id AND p.status_id IN (7, 8)  -- PAID, PAID_PARTIAL
    GROUP BY l.total_amount;
$$ LANGUAGE sql;
```
**Estado Backend**: ❌ NO IMPLEMENTADO
**Problema**: Backend NO debe calcular saldo, debe llamar función DB
**Impacto**: Duplicación lógica, riesgo inconsistencia

---

#### 3. `check_associate_credit_available()` ⭐ CRÍTICO
```sql
CREATE OR REPLACE FUNCTION check_associate_credit_available(
    p_associate_user_id INT,
    p_loan_amount NUMERIC
) RETURNS BOOLEAN AS $$
DECLARE
    v_credit_available NUMERIC;
BEGIN
    SELECT credit_available INTO v_credit_available
    FROM associate_profiles
    WHERE user_id = p_associate_user_id;
    
    IF v_credit_available IS NULL THEN
        RAISE EXCEPTION 'Usuario % no es asociado', p_associate_user_id;
    END IF;
    
    RETURN v_credit_available >= p_loan_amount;
END;
$$ LANGUAGE plpgsql;
```
**Estado Backend**: ❌ NO IMPLEMENTADO
**Problema**: NO se valida crédito disponible antes de aprobar préstamo
**Impacto**: Asociado puede exceder su límite de crédito

---

#### 4. `calculate_late_fee_for_statement()` - Mora 30%
```sql
CREATE OR REPLACE FUNCTION calculate_late_fee_for_statement(p_statement_id INT)
RETURNS NUMERIC AS $$
DECLARE
    v_total_commission NUMERIC;
    v_total_payments INT;
    v_late_fee NUMERIC;
BEGIN
    SELECT total_commission_owed, total_payments_count
    INTO v_total_commission, v_total_payments
    FROM associate_payment_statements
    WHERE id = p_statement_id;
    
    IF v_total_payments = 0 THEN
        v_late_fee := v_total_commission * 0.30;  -- 30% mora
    ELSE
        v_late_fee := 0;
    END IF;
    
    RETURN v_late_fee;
END;
$$ LANGUAGE plpgsql;
```
**Estado Backend**: ❌ NO IMPLEMENTADO
**Problema**: Mora del 30% NO calculada automáticamente
**Impacto**: Asociados NO penalizados por no gestionar cobros

---

#### 5. `admin_mark_payment_status()` ⭐ CRÍTICO
```sql
CREATE OR REPLACE FUNCTION admin_mark_payment_status(
    p_payment_id INT,
    p_new_status_id INT,
    p_admin_user_id INT,
    p_admin_notes TEXT DEFAULT NULL
) RETURNS VOID AS $$
DECLARE
    v_old_status_id INT;
BEGIN
    SELECT status_id INTO v_old_status_id
    FROM payments
    WHERE id = p_payment_id;
    
    UPDATE payments SET status_id = p_new_status_id WHERE id = p_payment_id;
    
    -- Trigger automático registra en payment_status_history
END;
$$ LANGUAGE plpgsql;
```
**Estado Backend**: ❌ NO IMPLEMENTADO
**Problema**: Admin NO puede marcar manualmente estados de pago
**Impacto**: Sin control manual, sin auditoría

---

#### Otras Funciones Base (6 más): ❌ NO IMPLEMENTADAS
- `log_payment_status_change()` - Log auditoría
- `get_payment_history()` - Timeline forense
- `detect_suspicious_payment_changes()` - Detección fraudes
- `revert_last_payment_change()` - Reversión
- `calculate_payment_preview()` - Preview cronograma
- `handle_loan_approval_status()` - Manejo aprobación

---

### NIVEL 2: Funciones Business (5 functions)

#### 1. `generate_payment_schedule()` ⭐ CRÍTICA
```sql
CREATE OR REPLACE FUNCTION generate_payment_schedule(p_loan_id INT)
RETURNS VOID AS $$
DECLARE
    v_loan RECORD;
    v_payment_number INT := 1;
    v_due_date DATE;
    v_cut_period_id INT;
BEGIN
    SELECT * INTO v_loan FROM loans WHERE id = p_loan_id;
    
    -- Calcular primer vencimiento (ORÁCULO)
    v_due_date := calculate_first_payment_date(v_loan.request_date, v_loan.term_biweeks);
    
    WHILE v_payment_number <= v_loan.term_biweeks LOOP
        -- Buscar cut_period correspondiente
        SELECT id INTO v_cut_period_id
        FROM cut_periods
        WHERE v_due_date BETWEEN period_start_date AND period_end_date;
        
        -- Insertar pago
        INSERT INTO payments (
            loan_id, cut_period_id, payment_number,
            scheduled_amount, due_date, status_id
        ) VALUES (
            p_loan_id, v_cut_period_id, v_payment_number,
            v_loan.biweekly_payment, v_due_date, 1  -- SCHEDULED
        );
        
        v_payment_number := v_payment_number + 1;
        v_due_date := v_due_date + INTERVAL '15 days';  -- Siguiente quincena
    END LOOP;
END;
$$ LANGUAGE plpgsql;
```
**Estado Backend**: ❌ NO IMPLEMENTADO
**Problema**: Cronograma NO se genera automáticamente al aprobar préstamo
**Impacto**: Sin pagos, sin seguimiento, sistema ROTO

---

#### 2. `close_period_and_accumulate_debt()` ⭐ CRÍTICA
```sql
CREATE OR REPLACE FUNCTION close_period_and_accumulate_debt(p_cut_period_id INT)
RETURNS VOID AS $$
BEGIN
    -- 1. Marcar pagos PAID_NOT_REPORTED (cliente NO pagó, reportado)
    UPDATE payments SET status_id = 9  -- PAID_NOT_REPORTED
    WHERE cut_period_id = p_cut_period_id
    AND status_id IN (2, 3, 4)  -- PENDING, DUE_TODAY, OVERDUE
    AND loan_id IN (
        SELECT loan_id FROM defaulted_client_reports
        WHERE status = 'APPROVED'
    );
    
    -- 2. Marcar pagos PAID_BY_ASSOCIATE (cliente NO pagó, NO reportado)
    UPDATE payments SET status_id = 10  -- PAID_BY_ASSOCIATE
    WHERE cut_period_id = p_cut_period_id
    AND status_id IN (2, 3, 4);
    
    -- 3. Trigger automático acumula deuda en associate_profiles
    
    -- 4. Cerrar período
    UPDATE cut_periods SET status_id = 2 WHERE id = p_cut_period_id;  -- CLOSED
END;
$$ LANGUAGE plpgsql;
```
**Estado Backend**: ❌ NO IMPLEMENTADO
**Problema**: Cierre de período NO automatizado
**Impacto**: 
- NO se marcan pagos pendientes
- NO se acumula deuda de pagos no reportados
- NO se aplica mora del 30%

---

#### Otras Funciones Business (3 más): ❌ NO IMPLEMENTADAS
- `report_defaulted_client()` - Reportar cliente moroso
- `approve_defaulted_client_report()` - Aprobar reporte
- `renew_loan()` - Renovar préstamo

---

## ⚙️ TRIGGERS (28+ triggers) - ❌ 0% IMPLEMENTADO

### Categorías de Triggers

#### 1. Updated At Triggers (15 triggers) - ❌ NO IMPLEMENTADOS
```sql
CREATE TRIGGER update_users_updated_at
BEFORE UPDATE ON users
FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();
```
**Tablas con trigger**: users, loans, payments, contracts, cut_periods, associate_profiles, etc.
**Estado Backend**: ❌ NO IMPLEMENTADO
**Problema**: Campo `updated_at` NO se actualiza automáticamente

---

#### 2. Loan Approval Status Trigger ⭐ CRÍTICO
```sql
CREATE TRIGGER handle_loan_approval
BEFORE UPDATE ON loans
FOR EACH ROW
WHEN (OLD.status_id IS DISTINCT FROM NEW.status_id)
EXECUTE FUNCTION handle_loan_approval_status();
```
**Estado Backend**: ❌ NO IMPLEMENTADO
**Problema**: Aprobación/rechazo NO actualiza `approval_date`/`rejection_date` automáticamente

---

#### 3. Generate Payment Schedule Trigger ⭐ CRÍTICO
```sql
CREATE TRIGGER generate_payment_schedule_on_approval
AFTER UPDATE ON loans
FOR EACH ROW
WHEN (NEW.status_id = 2 AND OLD.status_id <> 2)  -- Status cambió a APROBADO
EXECUTE FUNCTION generate_payment_schedule(NEW.id);
```
**Estado Backend**: ❌ NO IMPLEMENTADO
**Problema**: Cronograma NO se crea automáticamente al aprobar préstamo
**Impacto**: CRÍTICO - Sistema ROTO sin cronograma

---

#### 4. Log Payment Status Change Trigger ⭐ CRÍTICO
```sql
CREATE TRIGGER log_payment_status_change
AFTER UPDATE ON payments
FOR EACH ROW
WHEN (OLD.status_id IS DISTINCT FROM NEW.status_id)
EXECUTE FUNCTION log_payment_status_change();
```
**Estado Backend**: ❌ NO IMPLEMENTADO
**Problema**: Cambios de estado de pago NO se registran en auditoría
**Impacto**: Sin timeline forense, sin detección fraudes

---

#### 5. Associate Credit Tracking Triggers (4 triggers) - ❌ NO IMPLEMENTADOS
```sql
-- Actualizar credit_used al aprobar préstamo
CREATE TRIGGER update_associate_credit_on_loan_approval
AFTER UPDATE ON loans
FOR EACH ROW
WHEN (NEW.status_id = 2 AND OLD.status_id <> 2)
EXECUTE FUNCTION update_associate_credit_used();

-- Reversar credit_used al eliminar préstamo
CREATE TRIGGER update_associate_credit_on_loan_deletion
AFTER DELETE ON loans
FOR EACH ROW
EXECUTE FUNCTION update_associate_credit_used();
```
**Estado Backend**: ❌ NO IMPLEMENTADO
**Problema**: Crédito asociado NO se actualiza automáticamente
**Impacto**: `credit_used` DESINCRONIZADO

---

#### 6. Audit Triggers (5 triggers) - ❌ NO IMPLEMENTADOS
- Statement tracking (actualiza `associate_payment_statements`)
- Debt accumulation (acumula deuda en `associate_profiles`)
- Audit log general

---

## 📊 VISTAS (9 views) - ❌ 0% IMPLEMENTADO

### 1. `v_associate_credit_summary` ⭐ IMPORTANTE
```sql
CREATE VIEW v_associate_credit_summary AS
SELECT 
    ap.user_id,
    u.first_name || ' ' || u.last_name AS associate_name,
    al.level_name,
    ap.credit_limit,
    ap.credit_used,
    ap.credit_available,
    ap.debt_balance,
    CASE
        WHEN ap.credit_available <= 0 THEN 'SIN_CREDITO'
        WHEN ap.credit_available < ap.credit_limit * 0.20 THEN 'CREDITO_BAJO'
        ELSE 'CREDITO_DISPONIBLE'
    END AS credit_status,
    ROUND((ap.credit_used / NULLIF(ap.credit_limit, 0) * 100), 2) AS credit_usage_percentage,
    COUNT(l.id) AS active_loans_count
FROM associate_profiles ap
JOIN users u ON u.id = ap.user_id
JOIN associate_levels al ON al.id = ap.level_id
LEFT JOIN loans l ON l.associate_user_id = ap.user_id 
    AND l.status_id IN (2, 4, 5)  -- APROBADO, DESEMBOLSADO, EN_PAGOS
GROUP BY ap.user_id, u.first_name, u.last_name, al.level_name, 
         ap.credit_limit, ap.credit_used, ap.credit_available, ap.debt_balance;
```
**Estado Backend**: ❌ NO IMPLEMENTADO
**Problema**: NO hay endpoint para ver resumen crédito asociado
**Impacto**: Admin NO puede monitorear crédito asociados

---

### 2. `v_period_closure_summary`
```sql
CREATE VIEW v_period_closure_summary AS
SELECT
    cp.id AS cut_period_id,
    cp.period_number,
    cp.year,
    COUNT(p.id) AS total_payments,
    COUNT(p.id) FILTER (WHERE p.status_id = 7) AS payments_paid,
    COUNT(p.id) FILTER (WHERE p.status_id = 9) AS payments_not_reported,
    COUNT(p.id) FILTER (WHERE p.status_id = 10) AS payments_by_associate,
    SUM(p.amount_paid) FILTER (WHERE p.status_id IN (7, 8)) AS total_collected
FROM cut_periods cp
LEFT JOIN payments p ON p.cut_period_id = cp.id
GROUP BY cp.id, cp.period_number, cp.year;
```
**Estado Backend**: ❌ NO IMPLEMENTADO
**Problema**: NO hay resumen automático de cierre de período
**Impacto**: Sin visibilidad de pagos cobrados vs no cobrados

---

### 3. `v_associate_debt_detailed`
```sql
CREATE VIEW v_associate_debt_detailed AS
SELECT
    ap.user_id,
    u.first_name || ' ' || u.last_name AS associate_name,
    ap.debt_balance AS total_debt,
    SUM(adb.debt_amount) FILTER (WHERE adb.debt_type = 'UNREPORTED_PAYMENT') AS unreported_debt,
    SUM(adb.debt_amount) FILTER (WHERE adb.debt_type = 'DEFAULTED_CLIENT') AS defaulted_debt,
    SUM(adb.debt_amount) FILTER (WHERE adb.debt_type = 'LATE_FEE') AS late_fee_debt
FROM associate_profiles ap
JOIN users u ON u.id = ap.user_id
LEFT JOIN associate_debt_breakdown adb ON adb.associate_profile_id = ap.user_id
GROUP BY ap.user_id, u.first_name, u.last_name, ap.debt_balance;
```
**Estado Backend**: ❌ NO IMPLEMENTADO
**Problema**: NO hay desglose de deuda por tipo
**Impacto**: Asociado NO sabe cuánto debe por mora vs clientes morosos

---

### Otras Vistas (6 más): ❌ NO IMPLEMENTADAS
- `v_associate_late_fees` - Moras pendientes
- `v_payments_by_status_detailed` - Pagos con tracking
- `v_payments_absorbed_by_associate` - Pagos absorbidos
- `v_payment_changes_summary` - Resumen cambios
- `v_recent_payment_changes` - Últimas 24h
- `v_payments_multiple_changes` - Sospechosos (3+ cambios)

---

## 🚨 PROBLEMAS CRÍTICOS DETECTADOS

### 1. User Entity - Campos Inexistentes en DB ❌
**Archivo**: `backend/app/modules/auth/domain/entities/user.py`  
**Líneas 40-41**:
```python
is_active: bool = True  # TODO: Add to DB or remove
is_defaulter: bool = False  # TODO: Add to DB or remove
```
**Problema**: Estos campos NO existen en tabla `users` de DB v2.0
**Acción**: ELIMINAR campos (no están en fuente de verdad)

---

### 2. Repository - Role Hardcoded ❌
**Archivo**: `backend/app/modules/auth/infrastructure/repositories/postgresql_user_repository.py`  
**Línea 110**:
```python
role="administrador",  # Hardcoded for now
```
**Problema**: Role debe venir de JOIN con `user_roles` table
**Acción**: Crear query JOIN con `user_roles` + `roles`

---

### 3. Repository - Update Model Incorrecto ❌
**Archivo**: `backend/app/modules/auth/infrastructure/repositories/postgresql_user_repository.py`  
**Líneas 154-156**:
```python
model.role = entity.role  # ❌ Campo NO existe en UserModel
model.is_active = entity.is_active  # ❌ Campo NO existe en UserModel
model.is_defaulter = entity.is_defaulter  # ❌ Campo NO existe en UserModel
```
**Problema**: Intentando actualizar campos inexistentes
**Acción**: ELIMINAR líneas (UserModel NO tiene estos campos)

---

### 4. Sin Validación Roles Múltiples ❌
**Problema**: User puede tener múltiples roles (admin + asociado)
**Estado Actual**: User entity tiene `role: str` (un solo rol)
**Acción**: Cambiar a `roles: List[str]`

---

### 5. Sin Sistema de Catálogos ❌
**Problema**: 12 catálogos NO implementados
**Impacto**: TODO hardcoded (strings mágicos por todas partes)
**Acción**: Crear módulo `catalogs/` con 12 entities + repositories

---

### 6. Sin Funciones DB Integradas ❌
**Problema**: 16 funciones DB NO tienen wrappers en backend
**Impacto**: 
- Duplicación lógica (cálculos en backend)
- Inconsistencias (lógica diferente en DB vs backend)
- Sin ORÁCULO de fechas
**Acción**: Crear métodos repository que llamen funciones DB

---

### 7. Sin Triggers Implementados ❌
**Problema**: 28+ triggers NO reflejados en backend
**Impacto**:
- Cronograma NO se genera automáticamente
- Auditoría NO funciona
- Crédito asociado NO se actualiza
**Acción**: Documentar triggers en README, backend debe CONFIAR en DB

---

### 8. Sin Vistas DB Integradas ❌
**Problema**: 9 vistas NO tienen endpoints
**Impacto**: Queries complejas duplicadas en backend (lógica incorrecta)
**Acción**: Crear endpoints que usen vistas directamente

---

## 📋 PLAN DE ACCIÓN INMEDIATO

### FASE 0: Corrección Auth Module (1 día)

#### 1. Limpiar User Entity
**Archivo**: `backend/app/modules/auth/domain/entities/user.py`
```python
# ELIMINAR:
is_active: bool = True  # ❌ NO existe en DB
is_defaulter: bool = False  # ❌ NO existe en DB

# CAMBIAR:
role: str = "cliente"  # ❌ Un solo rol

# POR:
roles: List[str] = field(default_factory=list)  # ✅ Múltiples roles
```

#### 2. Corregir Repository Mapping
**Archivo**: `backend/app/modules/auth/infrastructure/repositories/postgresql_user_repository.py`
```python
# En _to_entity(), ELIMINAR:
is_active=True,  # ❌
is_defaulter=False  # ❌

# AGREGAR query para roles:
def _get_user_roles(self, user_id: int) -> List[str]:
    result = self.session.execute(
        """
        SELECT r.name 
        FROM user_roles ur
        JOIN roles r ON r.id = ur.role_id
        WHERE ur.user_id = :user_id
        """,
        {"user_id": user_id}
    )
    return [row[0] for row in result]
```

#### 3. Actualizar Validaciones
**Archivo**: `backend/app/modules/auth/domain/entities/user.py`
```python
# ELIMINAR:
def _validate_role(self):  # ❌ Valida string único

# AGREGAR:
def has_role(self, role_name: str) -> bool:
    """Check if user has specific role."""
    return role_name in self.roles
```

---

### FASE 1: Implementar Catálogos (3 días)

**Crear estructura**:
```
backend/app/modules/catalogs/
├── domain/
│   ├── entities/
│   │   ├── role.py
│   │   ├── loan_status.py
│   │   ├── payment_status.py  # ⭐ 12 estados
│   │   ├── associate_level.py  # ⭐ 5 niveles
│   │   └── ... (8 más)
│   └── repositories/
│       └── catalog_repository.py
├── application/
│   └── use_cases/
│       ├── get_all_roles.py
│       └── ... (11 más)
└── infrastructure/
    └── repositories/
        └── postgresql_catalog_repository.py
```

**Endpoints**:
```
GET /catalogs/roles
GET /catalogs/loan-statuses
GET /catalogs/payment-statuses  # 12 estados
GET /catalogs/associate-levels  # 5 niveles
... (8 más)
```

---

### FASE 2: Implementar Loans + Payments (2 semanas)

**Módulos prioritarios**:
1. `loans/` - CRUD + approval workflow
2. `payments/` - CRUD + mark status + auditoría

**Funciones DB a integrar**:
- `calculate_first_payment_date()` ⭐
- `generate_payment_schedule()` ⭐
- `admin_mark_payment_status()` ⭐
- `get_payment_history()` ⭐

---

## 📊 MÉTRICAS DE DESALINEACIÓN

| Categoría | DB v2.0 | Backend | Cobertura | Estado |
|-----------|---------|---------|-----------|--------|
| **Tablas** | 45 tables | 1 table | **2.2%** | 🔴 CRÍTICO |
| **Catálogos** | 12 catálogos | 0 catálogos | **0%** | 🔴 CRÍTICO |
| **Core Tables** | 11 tables | 1 table | **9%** | 🔴 CRÍTICO |
| **Business Tables** | 8 tables | 0 tables | **0%** | 🔴 CRÍTICO |
| **Audit Tables** | 4 tables | 0 tables | **0%** | 🔴 CRÍTICO |
| **Funciones** | 16 functions | 0 functions | **0%** | 🔴 CRÍTICO |
| **Triggers** | 28+ triggers | 0 triggers | **0%** | 🔴 CRÍTICO |
| **Vistas** | 9 views | 0 views | **0%** | 🔴 CRÍTICO |
| **Endpoints** | ~80 necesarios | 2 (login, health) | **2.5%** | 🔴 CRÍTICO |

**COBERTURA TOTAL BACKEND**: **~5%** 🔴

---

## ✅ CONCLUSIÓN

### Resumen Ejecutivo

**Estado Actual**: Backend tiene infraestructura correcta (Clean Architecture) pero **solo 5% implementado**

**Problemas Críticos**:
1. ❌ Auth module tiene campos inexistentes (`is_active`, `is_defaulter`)
2. ❌ Roles hardcoded, debe usar JOIN con `user_roles`
3. ❌ 95% de lógica de negocio NO implementada
4. ❌ 0 catálogos (12 necesarios)
5. ❌ 0 funciones DB integradas (16 necesarias)
6. ❌ 0 triggers documentados (28+ necesarios)
7. ❌ 0 vistas DB integradas (9 necesarias)

**Prioridad Inmediata**:
1. 🔴 Corregir auth module (1 día)
2. 🔴 Implementar catálogos (3 días)
3. 🔴 Implementar loans + payments (2 semanas)

**Estimación Total**: 30 semanas para implementar 100% de lógica de negocio

---

**Documento generado**: 2025-10-30  
**Basado en**: db/v2.0/modules/ (9 archivos SQL - 3,240 líneas)  
**Estado**: BACKEND 5% IMPLEMENTADO - 95% PENDIENTE
