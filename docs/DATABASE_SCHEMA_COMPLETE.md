# 🗄️ ESQUEMA COMPLETO DE BASE DE DATOS CREDINET v2.0

> **Documentación exhaustiva de todas las tablas, columnas, relaciones y lógica de negocio**  
> Última actualización: 27 de Noviembre de 2025

---

## 📋 ÍNDICE

1. [Vista General](#vista-general)
2. [Tablas de Usuarios y Autenticación](#tablas-de-usuarios-y-autenticación)
3. [Tablas de Préstamos](#tablas-de-préstamos)
4. [Tablas de Pagos](#tablas-de-pagos)
5. [Tablas de Periodos y Cortes](#tablas-de-periodos-y-cortes)
6. [Tablas de Statements](#tablas-de-statements)
7. [Tablas de Contratos](#tablas-de-contratos)
8. [Tablas de Documentos](#tablas-de-documentos)
9. [Tablas de Auditoría](#tablas-de-auditoría)
10. [Catálogos del Sistema](#catálogos-del-sistema)
11. [Triggers y Funciones](#triggers-y-funciones)
12. [Índices y Constraints](#índices-y-constraints)
13. [Diagramas de Relaciones](#diagramas-de-relaciones)

---

## 1. VISTA GENERAL

### 📊 Estadísticas Globales

```sql
Total de Tablas:        50
Tablas Core:           15
Tablas de Catálogo:    18
Tablas de Auditoría:    5
Tablas de Historial:    7
Tablas Legacy:          2
Triggers:              33
Funciones:             12
```

### 🎯 Organización por Módulos

```
┌─ USUARIOS Y ROLES (7 tablas)
│  ├─ users
│  ├─ roles
│  ├─ user_roles
│  ├─ addresses
│  ├─ beneficiaries
│  ├─ associate_levels
│  └─ associate_level_history
│
┌─ PRÉSTAMOS (6 tablas)
│  ├─ loans
│  ├─ loan_statuses
│  ├─ rate_profiles
│  ├─ legacy_payment_table
│  ├─ legacy_payment_table_backup_before_pdf_fix
│  └─ loan_types
│
┌─ PAGOS (5 tablas)
│  ├─ payments
│  ├─ payment_statuses
│  ├─ payment_methods
│  ├─ payment_status_history
│  └─ payment_frequency_types
│
┌─ PERIODOS Y CORTES (3 tablas)
│  ├─ cut_periods
│  ├─ cut_period_statuses
│  └─ payment_schedule_log
│
┌─ STATEMENTS (4 tablas)
│  ├─ associate_payment_statements
│  ├─ associate_statement_payments
│  ├─ associate_accumulated_balances
│  └─ statement_statuses
│
┌─ CONTRATOS (3 tablas)
│  ├─ contracts
│  ├─ contract_statuses
│  └─ payment_destinations
│
┌─ DOCUMENTOS (3 tablas)
│  ├─ client_documents
│  ├─ document_types
│  └─ document_statuses
│
┌─ AUDITORÍA (5 tablas)
│  ├─ audit_log
│  ├─ audit_session_log
│  ├─ associate_debt_breakdown
│  ├─ payment_tracking_debt_changes
│  └─ statement_generation_log
│
└─ CATÁLOGOS GENERALES (14 tablas restantes)
```

---

## 2. TABLAS DE USUARIOS Y AUTENTICACIÓN

### 👤 `users`
**Propósito:** Almacena todos los usuarios del sistema (clientes, asociados, admins)

```sql
CREATE TABLE users (
    user_id             SERIAL PRIMARY KEY,
    full_name           VARCHAR(255) NOT NULL,
    email               VARCHAR(255) UNIQUE NOT NULL,
    phone               VARCHAR(20),
    password_hash       VARCHAR(255) NOT NULL,
    curp                VARCHAR(18) UNIQUE,
    rfc                 VARCHAR(13) UNIQUE,
    date_of_birth       DATE,
    gender              VARCHAR(10),
    occupation          VARCHAR(100),
    monthly_income      DECIMAL(12, 2),
    employment_status   VARCHAR(50),
    marital_status      VARCHAR(50),
    
    -- Timestamps
    created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_login          TIMESTAMP,
    
    -- Estado
    is_active           BOOLEAN DEFAULT TRUE,
    email_verified      BOOLEAN DEFAULT FALSE,
    
    -- Metadata
    profile_picture_url TEXT,
    notes               TEXT
);

-- Índices
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_curp ON users(curp);
CREATE INDEX idx_users_is_active ON users(is_active);
```

**Valores Comunes:**
- `gender`: 'M' (Masculino), 'F' (Femenino), 'O' (Otro)
- `employment_status`: 'employed', 'self_employed', 'unemployed', 'retired'
- `marital_status`: 'single', 'married', 'divorced', 'widowed'

**Relaciones:**
- 1:N con `loans` (como cliente)
- 1:N con `loans` (como asociado)
- 1:N con `user_roles`
- 1:1 con `addresses`
- 1:N con `beneficiaries`

---

### 🔐 `roles`
**Propósito:** Define los roles del sistema

```sql
CREATE TABLE roles (
    role_id     SERIAL PRIMARY KEY,
    role_name   VARCHAR(50) UNIQUE NOT NULL,
    description TEXT,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

**Datos Precargados:**
```sql
INSERT INTO roles (role_id, role_name, description) VALUES
(1, 'admin', 'Administrador del sistema con acceso completo'),
(2, 'associate', 'Asociado que presta dinero'),
(3, 'client', 'Cliente que solicita préstamos'),
(4, 'viewer', 'Usuario con acceso de solo lectura'),
(5, 'accountant', 'Contador con acceso a reportes financieros');
```

---

### 🔗 `user_roles`
**Propósito:** Relación N:N entre usuarios y roles

```sql
CREATE TABLE user_roles (
    user_role_id SERIAL PRIMARY KEY,
    user_id      INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    role_id      INTEGER NOT NULL REFERENCES roles(role_id) ON DELETE CASCADE,
    assigned_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    assigned_by  INTEGER REFERENCES users(user_id),
    
    UNIQUE(user_id, role_id)
);

CREATE INDEX idx_user_roles_user ON user_roles(user_id);
CREATE INDEX idx_user_roles_role ON user_roles(role_id);
```

**Lógica de Negocio:**
- Un usuario puede tener múltiples roles (ej: asociado + admin)
- Cliente que se vuelve asociado mantiene ambos roles
- Al eliminar usuario, se eliminan sus roles automáticamente

---

### 📍 `addresses`
**Propósito:** Direcciones físicas de usuarios

```sql
CREATE TABLE addresses (
    address_id       SERIAL PRIMARY KEY,
    user_id          INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    
    -- Componentes de dirección
    street           VARCHAR(255) NOT NULL,
    exterior_number  VARCHAR(20) NOT NULL,
    interior_number  VARCHAR(20),
    neighborhood     VARCHAR(100),
    city             VARCHAR(100) NOT NULL,
    state            VARCHAR(100) NOT NULL,
    postal_code      VARCHAR(10) NOT NULL,
    country          VARCHAR(100) DEFAULT 'México',
    
    -- Metadata
    address_type     VARCHAR(50) DEFAULT 'home',  -- home, work, billing
    is_primary       BOOLEAN DEFAULT TRUE,
    
    -- Timestamps
    created_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_addresses_user ON addresses(user_id);
CREATE INDEX idx_addresses_postal_code ON addresses(postal_code);
```

---

### 👨‍👩‍👧 `beneficiaries`
**Propósito:** Beneficiarios de asociados en caso de fallecimiento

```sql
CREATE TABLE beneficiaries (
    beneficiary_id   SERIAL PRIMARY KEY,
    user_id          INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    
    -- Datos del beneficiario
    full_name        VARCHAR(255) NOT NULL,
    relationship     VARCHAR(100) NOT NULL,  -- spouse, child, parent, sibling, other
    phone            VARCHAR(20),
    email            VARCHAR(255),
    percentage       DECIMAL(5, 2) NOT NULL,  -- 0.00 a 100.00
    
    -- Dirección (opcional)
    address          TEXT,
    
    -- Metadata
    is_active        BOOLEAN DEFAULT TRUE,
    created_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT beneficiary_percentage_check CHECK (percentage >= 0 AND percentage <= 100)
);

CREATE INDEX idx_beneficiaries_user ON beneficiaries(user_id);
```

**Validación de Negocio:**
- La suma de porcentajes de beneficiarios activos de un asociado debe ser 100%
- Se valida en lógica de aplicación, no en BD

---

### 📊 `associate_levels`
**Propósito:** Niveles de asociados (determinan límites de préstamos)

```sql
CREATE TABLE associate_levels (
    level_id           SERIAL PRIMARY KEY,
    level_name         VARCHAR(100) UNIQUE NOT NULL,
    
    -- Límites financieros
    min_loan_amount    DECIMAL(12, 2) NOT NULL,
    max_loan_amount    DECIMAL(12, 2) NOT NULL,
    max_active_loans   INTEGER NOT NULL,
    
    -- Requisitos
    min_months_active  INTEGER NOT NULL,
    min_loans_granted  INTEGER NOT NULL,
    min_success_rate   DECIMAL(5, 2) NOT NULL,  -- Porcentaje de préstamos sin mora
    
    -- Metadata
    description        TEXT,
    created_at         TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT level_amount_check CHECK (max_loan_amount >= min_loan_amount)
);
```

**Datos Precargados:**
```sql
INSERT INTO associate_levels (level_name, min_loan_amount, max_loan_amount, max_active_loans, min_months_active, min_loans_granted, min_success_rate) VALUES
('Bronze',   2000,  10000,  5,  0,  0,  0.00),   -- Nivel inicial
('Silver',   5000,  20000, 10,  6, 10, 85.00),   -- Intermedio
('Gold',    10000,  50000, 20, 12, 25, 90.00),   -- Avanzado
('Platinum', 20000, 100000, 50, 24, 50, 95.00);  -- Élite
```

---

### 📈 `associate_level_history`
**Propósito:** Historial de cambios de nivel de asociados

```sql
CREATE TABLE associate_level_history (
    history_id    SERIAL PRIMARY KEY,
    user_id       INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    
    -- Cambio de nivel
    from_level_id INTEGER REFERENCES associate_levels(level_id),
    to_level_id   INTEGER NOT NULL REFERENCES associate_levels(level_id),
    
    -- Metadata
    changed_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    changed_by    INTEGER REFERENCES users(user_id),
    reason        TEXT,
    notes         TEXT
);

CREATE INDEX idx_level_history_user ON associate_level_history(user_id);
CREATE INDEX idx_level_history_date ON associate_level_history(changed_at);
```

---

## 3. TABLAS DE PRÉSTAMOS

### 💰 `loans`
**Propósito:** Préstamos aprobados y en proceso

```sql
CREATE TABLE loans (
    loan_id                SERIAL PRIMARY KEY,
    
    -- Relaciones
    user_id                INTEGER NOT NULL REFERENCES users(user_id),        -- Cliente
    associate_user_id      INTEGER NOT NULL REFERENCES users(user_id),        -- Asociado
    status_id              INTEGER NOT NULL REFERENCES loan_statuses(status_id),
    profile_code           VARCHAR(20) NOT NULL REFERENCES rate_profiles(profile_code),
    
    -- Montos
    amount                 DECIMAL(12, 2) NOT NULL,  -- Monto solicitado
    total_to_repay         DECIMAL(12, 2) NOT NULL,  -- Total a pagar (amount + interest + commission)
    
    -- Configuración del préstamo
    term_months            INTEGER NOT NULL DEFAULT 6,  -- Siempre 6 meses = 12 pagos quincenales
    
    -- Tasas (para custom profile)
    custom_interest_rate   DECIMAL(5, 2),  -- Ej: 4.25 (significa 4.25%)
    custom_commission_rate DECIMAL(5, 2),  -- Ej: 1.60 (significa 1.6%)
    
    -- Fechas
    requested_date         DATE NOT NULL DEFAULT CURRENT_DATE,
    approved_date          DATE,
    first_payment_date     DATE,
    final_payment_date     DATE,
    
    -- Metadata
    purpose                TEXT,  -- Propósito del préstamo
    notes                  TEXT,
    
    -- Timestamps
    created_at             TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at             TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Constraints
    CONSTRAINT loan_amount_positive CHECK (amount > 0),
    CONSTRAINT loan_total_greater_than_amount CHECK (total_to_repay >= amount),
    CONSTRAINT custom_rates_for_custom_profile CHECK (
        (profile_code != 'custom') OR 
        (custom_interest_rate IS NOT NULL AND custom_commission_rate IS NOT NULL)
    )
);

CREATE INDEX idx_loans_user ON loans(user_id);
CREATE INDEX idx_loans_associate ON loans(associate_user_id);
CREATE INDEX idx_loans_status ON loans(status_id);
CREATE INDEX idx_loans_profile ON loans(profile_code);
CREATE INDEX idx_loans_approved_date ON loans(approved_date);
```

**Lógica de Negocio:**
- Al aprobar préstamo (status → APPROVED), trigger genera 12 pagos automáticamente
- `term_months` siempre es 6 (sistema quincenal: 6 meses × 2 = 12 pagos)
- Perfiles:
  - **legacy**: Usa `legacy_payment_table`, ignora rates
  - **standard**: Usa 4.25% interés, 1.6% comisión (hardcoded)
  - **custom**: Usa `custom_interest_rate` y `custom_commission_rate`

---

### 📋 `loan_statuses`
**Propósito:** Catálogo de estados de préstamos

```sql
CREATE TABLE loan_statuses (
    status_id   SERIAL PRIMARY KEY,
    status_name VARCHAR(50) UNIQUE NOT NULL,
    description TEXT,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

**Datos Precargados:**
```sql
INSERT INTO loan_statuses (status_id, status_name, description) VALUES
(1, 'PENDING',   'Préstamo solicitado, pendiente de aprobación'),
(2, 'APPROVED',  'Préstamo aprobado, tabla de amortización generada'),
(3, 'ACTIVE',    'Préstamo activo con pagos en proceso'),
(4, 'COMPLETED', 'Préstamo completado, todos los pagos realizados'),
(5, 'REJECTED',  'Préstamo rechazado por asociado/admin'),
(6, 'CANCELLED', 'Préstamo cancelado antes de completarse');
```

**Flujo de Estados:**
```
PENDING → APPROVED → ACTIVE → COMPLETED
   ↓
REJECTED

PENDING/APPROVED → CANCELLED (solo si no hay pagos realizados)
```

---

### 📊 `rate_profiles`
**Propósito:** Perfiles de tasas de interés y comisión

```sql
CREATE TABLE rate_profiles (
    profile_code    VARCHAR(20) PRIMARY KEY,
    profile_name    VARCHAR(100) NOT NULL,
    
    -- Tasas por defecto (para reference)
    interest_rate   DECIMAL(5, 2),      -- NULL para legacy, valores para standard
    commission_rate DECIMAL(5, 2),      -- NULL para legacy, valores para standard
    
    -- Metadata
    description     TEXT,
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Flags
    uses_table      BOOLEAN DEFAULT FALSE,  -- TRUE solo para legacy
    allows_custom   BOOLEAN DEFAULT FALSE   -- TRUE solo para custom
);
```

**Datos Precargados:**
```sql
INSERT INTO rate_profiles (profile_code, profile_name, interest_rate, commission_rate, description, uses_table, allows_custom) VALUES
(
    'legacy', 
    'Perfil Legacy (Tabla Estática)', 
    NULL, 
    NULL, 
    'Usa legacy_payment_table con comisiones fijas', 
    TRUE, 
    FALSE
),
(
    'standard', 
    'Perfil Standard', 
    4.25, 
    1.60, 
    'Tasas estándar: 4.25% interés, 1.6% comisión', 
    FALSE, 
    FALSE
),
(
    'custom', 
    'Perfil Personalizado', 
    NULL, 
    NULL, 
    'Tasas definidas por usuario en el préstamo', 
    FALSE, 
    TRUE
);
```

---

### 📄 `legacy_payment_table`
**Propósito:** Tabla estática de montos para perfil legacy

```sql
CREATE TABLE legacy_payment_table (
    legacy_id             SERIAL PRIMARY KEY,
    amount                DECIMAL(12, 2) UNIQUE NOT NULL,  -- Monto del préstamo
    
    -- Pagos quincenales
    client_biweekly       DECIMAL(10, 2) NOT NULL,  -- Pago del cliente (quincena)
    associate_biweekly    DECIMAL(10, 2) NOT NULL,  -- Pago al asociado (quincena)
    commission_per_payment DECIMAL(10, 2) NOT NULL,  -- Comisión por pago
    
    -- Totales
    total_client_pays     DECIMAL(12, 2) NOT NULL,  -- Total que paga cliente (12 pagos)
    total_associate_receives DECIMAL(12, 2) NOT NULL,  -- Total que recibe asociado
    total_commission      DECIMAL(12, 2) NOT NULL,  -- Comisión total (12 pagos)
    
    created_at            TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_legacy_amount ON legacy_payment_table(amount);
```

**Ejemplo de Datos:**
```sql
-- Préstamo de $6,000
amount: 6000.00
client_biweekly: 614.58           -- Cliente paga $614.58 quincenal
associate_biweekly: 559.58        -- Asociado recibe $559.58 quincenal
commission_per_payment: 55.00     -- CrediNet cobra $55 por pago
total_client_pays: 7375.00        -- 614.58 × 12 = $7,375
total_associate_receives: 6715.00 -- 559.58 × 12 = $6,715
total_commission: 660.00          -- 55.00 × 12 = $660
```

**Fórmulas Legacy (Migration 026):**
```sql
-- Al generar pagos legacy:
principal_amount = amount / 12                           -- 6000/12 = 500
interest_amount = expected_amount - principal_amount     -- 614.58 - 500 = 114.58
balance_remaining = balance_anterior - principal_amount  -- Decrementa cada pago
```

---

## 4. TABLAS DE PAGOS

### 💳 `payments`
**Propósito:** Tabla de amortización de préstamos (12 pagos por préstamo)

```sql
CREATE TABLE payments (
    payment_id         SERIAL PRIMARY KEY,
    
    -- Relaciones
    loan_id            INTEGER NOT NULL REFERENCES loans(loan_id) ON DELETE CASCADE,
    cut_period_id      INTEGER NOT NULL REFERENCES cut_periods(cut_period_id),
    status_id          INTEGER NOT NULL REFERENCES payment_statuses(status_id),
    
    -- Números de pago
    payment_number     INTEGER NOT NULL,  -- 1 a 12
    
    -- Fechas
    payment_due_date   DATE NOT NULL,     -- Día 15 o último día del mes
    payment_date       DATE,              -- Fecha real de pago (cuando se registra)
    
    -- Montos (calculados al generar el pago)
    expected_amount    DECIMAL(10, 2) NOT NULL,  -- Monto esperado (cliente)
    amount_to_associate DECIMAL(10, 2) NOT NULL, -- Monto para asociado
    commission_amount  DECIMAL(10, 2) NOT NULL,  -- Comisión CrediNet
    
    -- Desglose (calculado en trigger, CRITICAL para legacy)
    principal_amount   DECIMAL(10, 2),  -- Capital amortizado
    interest_amount    DECIMAL(10, 2),  -- Interés del pago
    balance_remaining  DECIMAL(10, 2),  -- Saldo pendiente después del pago
    
    -- Pago real (cuando cliente paga)
    amount_paid        DECIMAL(10, 2),
    payment_method_id  INTEGER REFERENCES payment_methods(method_id),
    payment_reference  VARCHAR(100),
    
    -- Metadata
    notes              TEXT,
    created_at         TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at         TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Constraints
    UNIQUE(loan_id, payment_number),
    CONSTRAINT payment_number_range CHECK (payment_number BETWEEN 1 AND 12),
    CONSTRAINT amounts_positive CHECK (
        expected_amount > 0 AND 
        amount_to_associate >= 0 AND 
        commission_amount >= 0
    ),
    CONSTRAINT balance_check CHECK (
        (payment_number = 12 AND balance_remaining = 0) OR
        (payment_number < 12 AND balance_remaining > 0) OR
        balance_remaining IS NULL
    )
);

CREATE INDEX idx_payments_loan ON payments(loan_id);
CREATE INDEX idx_payments_period ON payments(cut_period_id);
CREATE INDEX idx_payments_status ON payments(status_id);
CREATE INDEX idx_payments_due_date ON payments(payment_due_date);
CREATE INDEX idx_payments_payment_date ON payments(payment_date);
```

**Lógica de Generación (Trigger):**
```sql
-- Trigger: generate_payment_schedule()
-- Se ejecuta: AFTER UPDATE ON loans cuando status_id cambia a APPROVED

1. Obtener configuración del perfil (legacy/standard/custom)
2. Calcular fecha del primer pago con calculate_first_payment_date()
3. Para cada pago (1 a 12):
   a. Calcular fecha de vencimiento (alterna entre día 15 y último)
   b. Asignar periodo con get_cut_period_for_payment(fecha_vencimiento)
   c. Calcular montos según perfil:
      - Legacy: Buscar en legacy_payment_table
      - Standard/Custom: Aplicar fórmulas
   d. Calcular desglose (principal, interest, balance)
   e. Insertar pago con status = PENDING
```

**Cálculo de Desglose (Migration 026 - FIXED):**

**Para Legacy:**
```sql
v_payment_to_principal := amount / 12;
v_payment_interest := expected_amount - v_payment_to_principal;
v_current_balance := v_current_balance - v_payment_to_principal;

-- Ejemplo: Préstamo $6,000
Pago 1:  principal=500, interest=114.58, balance=5500
Pago 2:  principal=500, interest=114.58, balance=5000
...
Pago 12: principal=500, interest=114.58, balance=0
```

**Para Standard/Custom:**
```sql
-- Fórmula de interés sobre saldo decreciente (a implementar)
v_month_rate := annual_rate / 12;
v_payment_interest := v_current_balance * v_month_rate;
v_payment_to_principal := expected_amount - v_payment_interest;
v_current_balance := v_current_balance - v_payment_to_principal;
```

---

### 📊 `payment_statuses`
**Propósito:** Catálogo de estados de pagos

```sql
CREATE TABLE payment_statuses (
    status_id   SERIAL PRIMARY KEY,
    status_name VARCHAR(50) UNIQUE NOT NULL,
    description TEXT,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

**Datos Precargados:**
```sql
INSERT INTO payment_statuses (status_id, status_name, description) VALUES
(1, 'PENDING',  'Pago pendiente, aún no vence'),
(2, 'PAID',     'Pago realizado completamente'),
(3, 'LATE',     'Pago vencido, cliente en mora'),
(4, 'OVERDUE',  'Pago muy vencido (>30 días)');
```

**Transiciones de Estado:**
```
PENDING → PAID (cuando se registra pago completo)
PENDING → LATE (cuando vence y no se paga)
LATE → PAID (cuando se paga tardíamente)
LATE → OVERDUE (cuando pasan >30 días sin pagar)
```

---

### 💵 `payment_methods`
**Propósito:** Métodos de pago aceptados

```sql
CREATE TABLE payment_methods (
    method_id   SERIAL PRIMARY KEY,
    method_name VARCHAR(50) UNIQUE NOT NULL,
    description TEXT,
    is_active   BOOLEAN DEFAULT TRUE,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

**Datos Precargados:**
```sql
INSERT INTO payment_methods (method_id, method_name, description) VALUES
(1, 'CASH',          'Efectivo'),
(2, 'TRANSFER',      'Transferencia bancaria'),
(3, 'CHECK',         'Cheque'),
(4, 'CARD',          'Tarjeta de débito/crédito'),
(5, 'MOBILE_PAYMENT', 'Pago móvil (app)');
```

---

### 📜 `payment_status_history`
**Propósito:** Auditoría de cambios de estado de pagos

```sql
CREATE TABLE payment_status_history (
    history_id     SERIAL PRIMARY KEY,
    payment_id     INTEGER NOT NULL REFERENCES payments(payment_id) ON DELETE CASCADE,
    
    -- Cambio
    from_status_id INTEGER REFERENCES payment_statuses(status_id),
    to_status_id   INTEGER NOT NULL REFERENCES payment_statuses(status_id),
    
    -- Metadata
    changed_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    changed_by     INTEGER REFERENCES users(user_id),
    reason         TEXT,
    notes          TEXT
);

CREATE INDEX idx_payment_history_payment ON payment_status_history(payment_id);
CREATE INDEX idx_payment_history_date ON payment_status_history(changed_at);
```

---

## 5. TABLAS DE PERIODOS Y CORTES

### 📅 `cut_periods`
**Propósito:** Periodos de corte para estados de cuenta (72 periodos precargados)

```sql
CREATE TABLE cut_periods (
    cut_period_id      SERIAL PRIMARY KEY,
    cut_code           VARCHAR(20) UNIQUE NOT NULL,  -- Ej: "Dec08-2025"
    
    -- Fechas del periodo
    period_start_date  DATE NOT NULL,  -- Inicio del periodo
    period_end_date    DATE NOT NULL,  -- Cierre del periodo (día 7 o 22)
    print_date         DATE NOT NULL,  -- Generación de statements (día 8 o 23)
    
    -- Estado
    status_id          INTEGER NOT NULL REFERENCES cut_period_statuses(status_id),
    
    -- Metadata
    year               INTEGER NOT NULL,
    month              INTEGER NOT NULL,
    period_type        VARCHAR(10) NOT NULL,  -- 'FIRST_HALF' o 'SECOND_HALF'
    
    -- Timestamps
    created_at         TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at         TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    closed_at          TIMESTAMP,
    
    -- Constraints
    CONSTRAINT period_dates_order CHECK (period_start_date < period_end_date),
    CONSTRAINT period_type_values CHECK (period_type IN ('FIRST_HALF', 'SECOND_HALF')),
    CONSTRAINT month_range CHECK (month BETWEEN 1 AND 12)
);

CREATE INDEX idx_cut_periods_code ON cut_periods(cut_code);
CREATE INDEX idx_cut_periods_dates ON cut_periods(period_end_date, print_date);
CREATE INDEX idx_cut_periods_status ON cut_periods(status_id);
CREATE INDEX idx_cut_periods_year_month ON cut_periods(year, month);
```

**Nomenclatura (ACTUALIZADA en Migration 024):**

| Nombre Anterior | Nombre Actual | Significado |
|----------------|---------------|-------------|
| Dec07-2025 | **Dec08-2025** | Periodo que se **imprime** día 8 |
| Dec22-2025 | **Dec23-2025** | Periodo que se **imprime** día 23 |

**Ejemplo Completo:**
```sql
cut_code: "Dec08-2025"
period_start_date: 2025-11-23  -- Inicia día después del corte anterior
period_end_date: 2025-12-07    -- Cierra día 7 (23:59:59)
print_date: 2025-12-08         -- Genera statements día 8 (00:00)
period_type: 'FIRST_HALF'
status_id: 1 (ACTIVE)

-- Contiene pagos que vencen el 15 de Diciembre
```

**Regla de Asignación:**
```sql
-- Pago día 15 → Periodo que cierra ANTES del 15
15/Dic/2025 → Dec08-2025 (cierra 07/Dic, imprime 08/Dic)

-- Pago último día → Periodo que cierra ANTES del último
31/Dic/2025 → Dec23-2025 (cierra 22/Dic, imprime 23/Dic)
```

---

### 🔄 `cut_period_statuses`
**Propósito:** Estados de periodos de corte

```sql
CREATE TABLE cut_period_statuses (
    status_id   SERIAL PRIMARY KEY,
    status_name VARCHAR(50) UNIQUE NOT NULL,
    description TEXT,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

**Datos Precargados:**
```sql
INSERT INTO cut_period_statuses (status_id, status_name, description) VALUES
(1, 'ACTIVE',    'Periodo activo, recibiendo pagos'),
(2, 'DRAFT',     'Cerrado automáticamente, statements generados, editable'),
(3, 'CLOSED',    'Cerrado manualmente, inmutable, archivado');
```

**Flujo de Estados:**
```
ACTIVE → DRAFT → CLOSED
  ↑        ↓
  └────────┘ (puede reabrir si es necesario)
```

**Lógica de Transición:**
```
1. ACTIVE:
   - Estado inicial de todos los periodos
   - Pagos se van registrando
   - Admin puede ver en tiempo real
   
2. DRAFT (Corte Automático):
   - Sistema cambia a DRAFT a las 00:00 de día 8 o 23
   - Genera statements por asociado
   - Admin puede:
     * Revisar statements
     * Hacer correcciones
     * Agregar/quitar pagos
   - Editable
   
3. CLOSED (Cierre Manual):
   - Admin ejecuta cierre manual
   - Statements se marcan como finalizados
   - INMUTABLE: No se permiten cambios
   - Periodo archivado
```

---

## 6. TABLAS DE STATEMENTS

### 📄 `associate_payment_statements`
**Propósito:** Estados de cuenta por asociado en cada periodo

```sql
CREATE TABLE associate_payment_statements (
    statement_id       SERIAL PRIMARY KEY,
    
    -- Relaciones
    associate_user_id  INTEGER NOT NULL REFERENCES users(user_id),
    cut_period_id      INTEGER NOT NULL REFERENCES cut_periods(cut_period_id),
    status_id          INTEGER NOT NULL REFERENCES statement_statuses(status_id),
    
    -- Resumen financiero
    total_expected     DECIMAL(12, 2) NOT NULL DEFAULT 0,  -- Total esperado del periodo
    total_collected    DECIMAL(12, 2) NOT NULL DEFAULT 0,  -- Total cobrado
    total_pending      DECIMAL(12, 2) NOT NULL DEFAULT 0,  -- Total pendiente
    commission_total   DECIMAL(12, 2) NOT NULL DEFAULT 0,  -- Comisiones del periodo
    
    -- Contadores
    payments_count     INTEGER NOT NULL DEFAULT 0,  -- Número de pagos en el periodo
    loans_count        INTEGER NOT NULL DEFAULT 0,  -- Número de préstamos distintos
    
    -- Fechas
    generated_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    finalized_at       TIMESTAMP,
    sent_at            TIMESTAMP,
    
    -- Metadata
    notes              TEXT,
    pdf_url            TEXT,  -- URL del PDF generado (futuro)
    
    -- Constraint único
    UNIQUE(associate_user_id, cut_period_id)
);

CREATE INDEX idx_statements_associate ON associate_payment_statements(associate_user_id);
CREATE INDEX idx_statements_period ON associate_payment_statements(cut_period_id);
CREATE INDEX idx_statements_status ON associate_payment_statements(status_id);
```

**Lógica de Generación:**
```sql
-- Al cambiar periodo a DRAFT, para cada asociado:
1. Obtener todos los pagos del periodo
2. Calcular totales:
   - total_expected = SUM(expected_amount)
   - total_collected = SUM(amount_paid WHERE status = PAID)
   - total_pending = total_expected - total_collected
   - commission_total = SUM(commission_amount)
3. Contar pagos y préstamos únicos
4. Crear registro en associate_payment_statements
5. Vincular pagos en associate_statement_payments
```

**Decisión de Negocio:**
- ❌ NO se generan statements vacíos (asociados sin pagos en el periodo)
- ✅ Solo se generan statements para asociados CON pagos
- Mensaje: "Asociado sin actividad en este periodo"

---

### 🔗 `associate_statement_payments`
**Propósito:** Relación N:N entre statements y pagos

```sql
CREATE TABLE associate_statement_payments (
    id           SERIAL PRIMARY KEY,
    statement_id INTEGER NOT NULL REFERENCES associate_payment_statements(statement_id) ON DELETE CASCADE,
    payment_id   INTEGER NOT NULL REFERENCES payments(payment_id) ON DELETE CASCADE,
    
    created_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(statement_id, payment_id)
);

CREATE INDEX idx_stmt_payments_statement ON associate_statement_payments(statement_id);
CREATE INDEX idx_stmt_payments_payment ON associate_statement_payments(payment_id);
```

---

### 💰 `associate_accumulated_balances`
**Propósito:** Saldos acumulados de asociados (para tracking histórico)

```sql
CREATE TABLE associate_accumulated_balances (
    balance_id         SERIAL PRIMARY KEY,
    associate_user_id  INTEGER NOT NULL REFERENCES users(user_id),
    cut_period_id      INTEGER NOT NULL REFERENCES cut_periods(cut_period_id),
    
    -- Balances
    period_earnings    DECIMAL(12, 2) NOT NULL,  -- Ganancia del periodo
    period_commission  DECIMAL(12, 2) NOT NULL,  -- Comisión del periodo
    accumulated_total  DECIMAL(12, 2) NOT NULL,  -- Total acumulado histórico
    
    -- Metadata
    calculated_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(associate_user_id, cut_period_id)
);

CREATE INDEX idx_balances_associate ON associate_accumulated_balances(associate_user_id);
CREATE INDEX idx_balances_period ON associate_accumulated_balances(cut_period_id);
```

---

### 📊 `statement_statuses`
**Propósito:** Estados de statements

```sql
CREATE TABLE statement_statuses (
    status_id   SERIAL PRIMARY KEY,
    status_name VARCHAR(50) UNIQUE NOT NULL,
    description TEXT,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

**Datos Precargados:**
```sql
INSERT INTO statement_statuses (status_id, status_name, description) VALUES
(1, 'DRAFT',      'Statement generado, en revisión'),
(2, 'FINALIZED',  'Statement finalizado, listo para enviar'),
(3, 'SENT',       'Statement enviado al asociado'),
(4, 'ARCHIVED',   'Statement archivado');
```

---

## 7. TRIGGERS Y FUNCIONES

### 🔧 Funciones Principales

#### 1. `calculate_first_payment_date(approval_date DATE) RETURNS DATE`
**Propósito:** Calcular la primera fecha de pago basándose en la fecha de aprobación

```sql
CREATE OR REPLACE FUNCTION calculate_first_payment_date(approval_date DATE)
RETURNS DATE AS $$
DECLARE
    next_15th DATE;
    next_last_day DATE;
BEGIN
    -- Calcular próximo día 15
    IF EXTRACT(DAY FROM approval_date) < 15 THEN
        next_15th := DATE_TRUNC('month', approval_date) + INTERVAL '14 days';
    ELSE
        next_15th := DATE_TRUNC('month', approval_date + INTERVAL '1 month') + INTERVAL '14 days';
    END IF;
    
    -- Calcular último día del mes
    next_last_day := (DATE_TRUNC('month', approval_date) + INTERVAL '1 month' - INTERVAL '1 day')::DATE;
    
    -- Si ya pasó el último día, usar el del próximo mes
    IF approval_date >= next_last_day THEN
        next_last_day := (DATE_TRUNC('month', approval_date + INTERVAL '1 month') + INTERVAL '1 month' - INTERVAL '1 day')::DATE;
    END IF;
    
    -- Retornar la fecha más cercana
    IF next_15th < next_last_day THEN
        RETURN next_15th;
    ELSE
        RETURN next_last_day;
    END IF;
END;
$$ LANGUAGE plpgsql;
```

**Ejemplos:**
```sql
-- Aprobado el 5 de Diciembre → Primera pago 15 de Diciembre
-- Aprobado el 20 de Diciembre → Primer pago 31 de Diciembre
-- Aprobado el 31 de Diciembre → Primer pago 15 de Enero
```

---

#### 2. `get_cut_period_for_payment(payment_date DATE) RETURNS INTEGER`
**Propósito:** Asignar el periodo correcto basándose en la fecha de vencimiento

```sql
CREATE OR REPLACE FUNCTION get_cut_period_for_payment(payment_date DATE)
RETURNS INTEGER AS $$
DECLARE
    period_id INTEGER;
    day_of_month INTEGER;
BEGIN
    day_of_month := EXTRACT(DAY FROM payment_date);
    
    -- Pago día 15 → Periodo que cierra día 7-8
    IF day_of_month = 15 THEN
        SELECT cut_period_id INTO period_id
        FROM cut_periods
        WHERE period_end_date < payment_date
          AND period_type = 'FIRST_HALF'
          AND EXTRACT(MONTH FROM period_end_date) = EXTRACT(MONTH FROM payment_date)
          AND EXTRACT(YEAR FROM period_end_date) = EXTRACT(YEAR FROM payment_date)
        ORDER BY period_end_date DESC
        LIMIT 1;
    
    -- Pago último día → Periodo que cierra día 22-23
    ELSE
        SELECT cut_period_id INTO period_id
        FROM cut_periods
        WHERE period_end_date < payment_date
          AND period_type = 'SECOND_HALF'
          AND EXTRACT(MONTH FROM period_end_date) = EXTRACT(MONTH FROM payment_date)
          AND EXTRACT(YEAR FROM period_end_date) = EXTRACT(YEAR FROM payment_date)
        ORDER BY period_end_date DESC
        LIMIT 1;
    END IF;
    
    RETURN period_id;
END;
$$ LANGUAGE plpgsql;
```

**Lógica:**
```
Pago 15/Dic/2025:
  1. Buscar periodo FIRST_HALF de Diciembre 2025
  2. Que cierre ANTES del 15
  3. Resultado: Dec08-2025 (cierra 07/Dic)

Pago 31/Dic/2025:
  1. Buscar periodo SECOND_HALF de Diciembre 2025
  2. Que cierre ANTES del 31
  3. Resultado: Dec23-2025 (cierra 22/Dic)
```

---

#### 3. `simulate_loan()` - Simulación de Préstamo
**Propósito:** Generar vista previa de tabla de amortización SIN crear el préstamo

```sql
CREATE OR REPLACE FUNCTION simulate_loan(
    p_amount DECIMAL,
    p_profile_code VARCHAR,
    p_approval_date DATE,
    p_custom_interest DECIMAL DEFAULT NULL,
    p_custom_commission DECIMAL DEFAULT NULL
)
RETURNS TABLE (
    payment_number INTEGER,
    payment_due_date DATE,
    expected_amount DECIMAL,
    amount_to_associate DECIMAL,
    commission_amount DECIMAL,
    principal_amount DECIMAL,
    interest_amount DECIMAL,
    balance_remaining DECIMAL,
    cut_period_code VARCHAR
) AS $$
-- Implementación idéntica a generate_payment_schedule()
-- Pero retorna resultados en vez de insertar en BD
-- FIXED (Migration 023): Ahora usa get_cut_period_for_payment()
$$ LANGUAGE plpgsql;
```

---

#### 4. `generate_payment_schedule()` - Trigger de Generación
**Propósito:** Generar tabla de amortización automáticamente al aprobar préstamo

```sql
CREATE OR REPLACE FUNCTION generate_payment_schedule()
RETURNS TRIGGER AS $$
DECLARE
    -- Variables de configuración
    v_profile_code VARCHAR(20);
    v_first_payment_date DATE;
    v_current_payment_date DATE;
    v_payment_number INTEGER := 1;
    
    -- Variables de cálculo
    v_expected_amount DECIMAL(10, 2);
    v_amount_to_associate DECIMAL(10, 2);
    v_commission DECIMAL(10, 2);
    v_principal DECIMAL(10, 2);
    v_interest DECIMAL(10, 2);
    v_balance DECIMAL(10, 2);
    
    -- Periodo
    v_cut_period_id INTEGER;
    
BEGIN
    -- Solo ejecutar cuando status cambia a APPROVED
    IF NEW.status_id = 2 AND OLD.status_id != 2 THEN
        
        -- Obtener configuración
        v_profile_code := NEW.profile_code;
        v_first_payment_date := calculate_first_payment_date(NEW.approved_date);
        v_current_payment_date := v_first_payment_date;
        v_balance := NEW.amount;
        
        -- Generar 12 pagos
        FOR v_payment_number IN 1..12 LOOP
            
            -- Asignar periodo usando función correcta (FIXED Migration 023)
            v_cut_period_id := get_cut_period_for_payment(v_current_payment_date);
            
            -- Calcular montos según perfil
            IF v_profile_code = 'legacy' THEN
                -- Buscar en tabla legacy
                SELECT 
                    client_biweekly,
                    associate_biweekly,
                    commission_per_payment
                INTO 
                    v_expected_amount,
                    v_amount_to_associate,
                    v_commission
                FROM legacy_payment_table
                WHERE amount = NEW.amount;
                
                -- Calcular desglose (FIXED Migration 026)
                v_principal := NEW.amount / 12;
                v_interest := v_expected_amount - v_principal;
                v_balance := v_balance - v_principal;
                
            ELSIF v_profile_code IN ('standard', 'custom') THEN
                -- Aplicar fórmulas
                -- ... (implementación de fórmulas)
            END IF;
            
            -- Insertar pago
            INSERT INTO payments (
                loan_id, payment_number, payment_due_date,
                cut_period_id, status_id,
                expected_amount, amount_to_associate, commission_amount,
                principal_amount, interest_amount, balance_remaining
            ) VALUES (
                NEW.loan_id, v_payment_number, v_current_payment_date,
                v_cut_period_id, 1,
                v_expected_amount, v_amount_to_associate, v_commission,
                v_principal, v_interest, v_balance
            );
            
            -- Calcular próxima fecha (alterna entre 15 y último)
            v_current_payment_date := calculate_next_payment_date(v_current_payment_date);
            
        END LOOP;
        
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Asociar trigger
CREATE TRIGGER trg_generate_payment_schedule
AFTER UPDATE ON loans
FOR EACH ROW
EXECUTE FUNCTION generate_payment_schedule();
```

---

## 8. ÍNDICES Y CONSTRAINTS

### 📊 Índices Principales

```sql
-- PERFORMANCE CRÍTICA
CREATE INDEX idx_payments_loan_period ON payments(loan_id, cut_period_id);
CREATE INDEX idx_payments_status_date ON payments(status_id, payment_due_date);
CREATE INDEX idx_loans_associate_status ON loans(associate_user_id, status_id);

-- BÚSQUEDAS FRECUENTES
CREATE INDEX idx_users_email_active ON users(email, is_active);
CREATE INDEX idx_cut_periods_active ON cut_periods(status_id) WHERE status_id = 1;

-- REPORTES
CREATE INDEX idx_payments_date_range ON payments(payment_due_date, payment_date);
CREATE INDEX idx_loans_dates ON loans(approved_date, requested_date);
```

### 🔒 Constraints Críticos

```sql
-- INTEGRIDAD DE NEGOCIO
ALTER TABLE payments ADD CONSTRAINT payment_expected_formula CHECK (
    expected_amount = amount_to_associate + commission_amount
);

ALTER TABLE loans ADD CONSTRAINT loan_dates_logical CHECK (
    (approved_date IS NULL) OR 
    (approved_date >= requested_date)
);

-- VALIDACIONES DE MONTOS
ALTER TABLE payments ADD CONSTRAINT payment_amounts_positive CHECK (
    expected_amount > 0 AND
    amount_to_associate >= 0 AND
    commission_amount >= 0
);

-- ESTADO COHERENTE
ALTER TABLE payments ADD CONSTRAINT payment_paid_requires_date CHECK (
    (status_id != 2) OR (payment_date IS NOT NULL)
);
```

---

## 9. DIAGRAMAS DE RELACIONES

### 📊 Diagrama ER Simplificado

```
┌────────────┐         ┌────────────┐
│   users    │◄───────┼│   loans    │
│            │         │            │
│ user_id PK │         │ loan_id PK │
│ full_name  │         │ user_id FK │
│ email      │         │ associate  │
│ ...        │         │ amount     │
└────────────┘         └────┬───────┘
     │                      │
     │                      │ 1:N
     │                      ▼
     │                ┌────────────┐         ┌──────────────┐
     │                │  payments  │────────▶│ cut_periods  │
     │                │            │   N:1   │              │
     │                │ payment_id │         │ cut_period   │
     │                │ loan_id FK │         │ cut_code     │
     │                │ period FK  │         │ ...          │
     │                │ ...        │         └──────────────┘
     │                └────────────┘
     │                      │
     │ 1:N                  │ N:1
     ▼                      ▼
┌────────────┐         ┌────────────┐
│user_roles  │         │  payment_  │
│            │         │  statuses  │
│ user_id FK │         │            │
│ role_id FK │         │ status_id  │
└────────────┘         └────────────┘
     │
     │ N:1
     ▼
┌────────────┐
│   roles    │
│            │
│ role_id PK │
│ role_name  │
└────────────┘
```

---

## 📊 RESUMEN DE CATÁLOGOS

| Catálogo | Filas | Valores Principales |
|----------|-------|---------------------|
| `roles` | 5 | admin, associate, client, viewer, accountant |
| `loan_statuses` | 6 | PENDING, APPROVED, ACTIVE, COMPLETED, REJECTED, CANCELLED |
| `payment_statuses` | 4 | PENDING, PAID, LATE, OVERDUE |
| `cut_period_statuses` | 3 | ACTIVE, DRAFT, CLOSED |
| `statement_statuses` | 4 | DRAFT, FINALIZED, SENT, ARCHIVED |
| `rate_profiles` | 3 | legacy, standard, custom |
| `payment_methods` | 5 | CASH, TRANSFER, CHECK, CARD, MOBILE_PAYMENT |
| `associate_levels` | 4 | Bronze, Silver, Gold, Platinum |

---

**Documento actualizado:** 27 de Noviembre de 2025  
**Versión:** 2.0.4  
**Mantenedor:** Equipo de Desarrollo CrediNet
