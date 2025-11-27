# 🗄️ ANÁLISIS DE TRACKING: Abonos a Deuda Acumulada
**Análisis de Tablas Existentes y Propuesta**  
Versión: 1.0  
Fecha: 2025-11-11  
Estado: ✅ ANÁLISIS COMPLETO

---

## 📋 TABLA DE CONTENIDOS

1. [Tablas Existentes Relevantes](#1-tablas-existentes-relevantes)
2. [Análisis Funcional](#2-análisis-funcional)
3. [Opciones de Implementación](#3-opciones-de-implementación)
4. [Recomendación Final](#4-recomendación-final)
5. [Vistas SQL Propuestas](#5-vistas-sql-propuestas)
6. [Ejemplos de Uso](#6-ejemplos-de-uso)

---

## 1. TABLAS EXISTENTES RELEVANTES

### 1.1 `associate_debt_breakdown` ⭐ TABLA CLAVE

```sql
CREATE TABLE associate_debt_breakdown (
    id SERIAL PRIMARY KEY,
    associate_profile_id INTEGER NOT NULL REFERENCES associate_profiles(id),
    cut_period_id INTEGER NOT NULL REFERENCES cut_periods(id),
    debt_type VARCHAR(50) NOT NULL,  -- UNREPORTED_PAYMENT, DEFAULTED_CLIENT, LATE_FEE
    loan_id INTEGER REFERENCES loans(id),
    client_user_id INTEGER REFERENCES users(id),
    amount DECIMAL(12, 2) NOT NULL,
    description TEXT,
    
    -- ⭐ CAMPOS PARA TRACKING DE LIQUIDACIÓN
    is_liquidated BOOLEAN NOT NULL DEFAULT false,
    liquidated_at TIMESTAMP WITH TIME ZONE,
    liquidation_reference VARCHAR(100),
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
```

**Visualización ASCII:**
```
┌─────────────────────────────────────────────────────────────────────┐
│              associate_debt_breakdown (TABLA EXISTENTE)              │
├─────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  PROPÓSITO: Desglose detallado de deuda por tipo y origen            │
│                                                                       │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │ COLUMNA              TIPO           DESCRIPCIÓN              │    │
│  ├─────────────────────────────────────────────────────────────┤    │
│  │ id                   SERIAL         PK                       │    │
│  │ associate_profile_id INTEGER        FK → Asociado            │    │
│  │ cut_period_id        INTEGER        FK → Período origen      │    │
│  │ debt_type            VARCHAR(50)    Tipo de deuda            │    │
│  │ loan_id              INTEGER        FK → Préstamo (opcional) │    │
│  │ client_user_id       INTEGER        FK → Cliente (opcional)  │    │
│  │ amount               DECIMAL(12,2)  Monto de deuda           │    │
│  │ description          TEXT           Notas                    │    │
│  │ ─────────────────────────────────────────────────────────────│    │
│  │ ⭐ TRACKING FIFO:                                            │    │
│  │ is_liquidated        BOOLEAN        ¿Ya pagado?              │    │
│  │ liquidated_at        TIMESTAMP      Fecha de liquidación     │    │
│  │ liquidation_reference VARCHAR(100)  Referencia del pago      │    │
│  │ ─────────────────────────────────────────────────────────────│    │
│  │ created_at           TIMESTAMP      Creación                 │    │
│  │ updated_at           TIMESTAMP      Última modificación      │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                                                       │
│  ✅ VENTAJAS:                                                        │
│  • Ya tiene campos FIFO (is_liquidated, liquidated_at)               │
│  • Rastreo de origen (cut_period_id, loan_id, client_user_id)       │
│  • Desglose por tipo de deuda                                        │
│                                                                       │
│  ⚠️ LIMITACIÓN:                                                      │
│  • NO registra abonos parciales a un mismo item                      │
│  • Solo marca como liquidado (TRUE/FALSE)                            │
│                                                                       │
└─────────────────────────────────────────────────────────────────────┘
```

### 1.2 `associate_statement_payments` (Solo para Statements)

```sql
CREATE TABLE associate_statement_payments (
    id SERIAL PRIMARY KEY,
    statement_id INTEGER NOT NULL REFERENCES associate_payment_statements(id),
    payment_amount DECIMAL(12, 2) NOT NULL,
    payment_date DATE NOT NULL,
    payment_method_id INTEGER NOT NULL REFERENCES payment_methods(id),
    payment_reference VARCHAR(100),
    registered_by INTEGER NOT NULL REFERENCES users(id),
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
```

**Visualización ASCII:**
```
┌─────────────────────────────────────────────────────────────────────┐
│          associate_statement_payments (SOLO SALDO ACTUAL)            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  PROPÓSITO: Tracking de abonos al SALDO ACTUAL (statement)           │
│                                                                       │
│  ✅ FUNCIONA PARA:                                                   │
│  • Registrar abonos al statement del período                         │
│  • Múltiples abonos parciales                                        │
│  • Tracking completo (fecha, método, referencia, quien registró)     │
│                                                                       │
│  ❌ NO SIRVE PARA:                                                   │
│  • Abonos a la DEUDA ACUMULADA (no hay statement_id)                 │
│                                                                       │
└─────────────────────────────────────────────────────────────────────┘
```

### 1.3 `associate_profiles` (Resumen de Deuda)

```sql
CREATE TABLE associate_profiles (
    -- ... otros campos ...
    debt_balance DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    -- ... otros campos ...
);
```

**Visualización ASCII:**
```
┌─────────────────────────────────────────────────────────────────────┐
│              associate_profiles.debt_balance                         │
├─────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  PROPÓSITO: Campo CALCULADO (suma de associate_debt_breakdown)       │
│                                                                       │
│  debt_balance = SUM(amount) WHERE is_liquidated = false              │
│                                                                       │
│  ✅ SE ACTUALIZA:                                                    │
│  • Al cerrar período (acumula deuda nueva)                           │
│  • Al liquidar deuda (FIFO en debt_breakdown)                        │
│                                                                       │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 2. ANÁLISIS FUNCIONAL

### 2.1 Flujo Actual de Liquidación FIFO (YA EXISTE)

```sql
-- Trigger existente en 06_functions_business.sql (línea ~680)
-- Se ejecuta al insertar en associate_statement_payments

-- Pseudocódigo del trigger:
FUNCTION update_statement_and_credit_on_payment()
BEGIN
    -- 1. Sumar todos los abonos al statement
    paid_amount := SUM(payment_amount) FROM associate_statement_payments
    
    -- 2. Si paid_amount >= total adeudado:
    IF paid_amount >= (total_amount_collected - total_commission_owed) THEN
        -- 2a. Actualizar statement a PAID
        UPDATE associate_payment_statements SET status_id = 3 (PAID)
        
        -- 2b. Calcular excedente
        excess_amount := paid_amount - total_adeudado
        
        -- 2c. ⭐ APLICAR EXCEDENTE A DEUDA ACUMULADA (FIFO)
        FOR debt_item IN (
            SELECT id, amount
            FROM associate_debt_breakdown
            WHERE associate_profile_id = ...
              AND is_liquidated = false
            ORDER BY created_at ASC, id ASC  -- ⭐ FIFO
        ) LOOP
            IF excess_amount >= debt_item.amount THEN
                -- Liquidar completamente
                UPDATE associate_debt_breakdown
                SET is_liquidated = true,
                    liquidated_at = CURRENT_TIMESTAMP,
                    liquidation_reference = payment_reference
                WHERE id = debt_item.id
                
                excess_amount := excess_amount - debt_item.amount
            ELSE
                EXIT  -- No hay más excedente
            END IF
        END LOOP
        
        -- 2d. Actualizar debt_balance del asociado
        UPDATE associate_profiles
        SET debt_balance = debt_balance - amount_liquidated
    END IF
END
```

**Visualización del Flujo:**
```
┌─────────────────────────────────────────────────────────────────────┐
│              FLUJO ACTUAL DE LIQUIDACIÓN (YA EXISTE)                 │
├─────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  CASO: Abono de $20,000 al statement (total adeudado: $17,812.50)   │
│                                                                       │
│  1. INSERT INTO associate_statement_payments                         │
│     ├─ payment_amount = $20,000                                      │
│     └─ Trigger se activa automáticamente                             │
│                                                                       │
│  2. Actualizar statement                                             │
│     ├─ paid_amount = $20,000                                         │
│     ├─ status_id = 3 (PAID)                                          │
│     └─ excess_amount = $20,000 - $17,812.50 = $2,187.50             │
│                                                                       │
│  3. ⭐ Aplicar excedente a deuda FIFO                                │
│     ┌───────────────────────────────────────────────────────────┐   │
│     │ ITEM  PERÍODO   TIPO            MONTO     LIQUIDAR         │   │
│     ├───────────────────────────────────────────────────────────┤   │
│     │ #1    2025-Q01  UNREPORTED      $3,200    ✅ Total         │ ←─┤
│     │ #2    2025-Q01  LATE_FEE        $  960    ❌ (sin saldo)   │   │
│     │ #3    2025-Q02  UNREPORTED      $2,840    ❌ (sin saldo)   │   │
│     └───────────────────────────────────────────────────────────┘   │
│                                                                       │
│  4. Resultado:                                                       │
│     • Item #1: is_liquidated = true (usó $2,187.50 parcial)          │
│     • Sobrante: $2,187.50 - $3,200 = -$1,012.50 (insuficiente)      │
│     • Item #1 NO se liquida completamente                            │
│     • ⚠️ PROBLEMA: No hay liquidación parcial                        │
│                                                                       │
└─────────────────────────────────────────────────────────────────────┘
```

### 2.2 Limitación Actual

```
┌─────────────────────────────────────────────────────────────────────┐
│                    ⚠️ PROBLEMA IDENTIFICADO                          │
├─────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  associate_debt_breakdown solo maneja:                               │
│  • is_liquidated = true/false (binario)                              │
│  • liquidation_reference (una sola referencia)                       │
│                                                                       │
│  NO PUEDE:                                                           │
│  • Registrar abonos parciales a un mismo item                        │
│  • Rastrear múltiples abonos sobre la misma deuda                    │
│  • Mantener historial de abonos graduales                            │
│                                                                       │
│  EJEMPLO PROBLEMÁTICO:                                               │
│  ├─ Deuda: $5,000 (item #1)                                          │
│  ├─ Abono 1: $2,000 → ¿Cómo registrar?                               │
│  ├─ Abono 2: $1,500 → ¿Cómo registrar?                               │
│  └─ Abono 3: $1,500 → Ahora sí liquida                               │
│                                                                       │
│  ACTUAL: Solo marca is_liquidated = true al final                    │
│  NO HAY TRACKING de los 3 abonos intermedios                         │
│                                                                       │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 3. OPCIONES DE IMPLEMENTACIÓN

### OPCIÓN A: Tabla Nueva `associate_debt_payments` ⭐ RECOMENDADA

```sql
CREATE TABLE associate_debt_payments (
    id SERIAL PRIMARY KEY,
    associate_profile_id INTEGER NOT NULL REFERENCES associate_profiles(id),
    payment_amount DECIMAL(12, 2) NOT NULL,
    payment_date DATE NOT NULL,
    payment_method_id INTEGER NOT NULL REFERENCES payment_methods(id),
    payment_reference VARCHAR(100),
    registered_by INTEGER NOT NULL REFERENCES users(id),
    notes TEXT,
    
    -- ⭐ TRACKING DE APLICACIÓN FIFO
    applied_breakdown_items JSONB,  -- Array de {debt_breakdown_id, amount_applied}
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT check_debt_payment_amount_positive CHECK (payment_amount > 0)
);

-- Índices
CREATE INDEX idx_debt_payments_associate ON associate_debt_payments(associate_profile_id);
CREATE INDEX idx_debt_payments_date ON associate_debt_payments(payment_date);
```

**Ejemplo de `applied_breakdown_items`:**
```json
[
  {
    "debt_breakdown_id": 123,
    "amount_applied": 2000.00,
    "debt_type": "UNREPORTED_PAYMENT",
    "cut_period": "2025-Q01"
  },
  {
    "debt_breakdown_id": 124,
    "amount_applied": 960.00,
    "debt_type": "LATE_FEE",
    "cut_period": "2025-Q01"
  },
  {
    "debt_breakdown_id": 125,
    "amount_applied": 1040.00,
    "debt_type": "UNREPORTED_PAYMENT",
    "cut_period": "2025-Q02"
  }
]
```

**Visualización ASCII:**
```
┌─────────────────────────────────────────────────────────────────────┐
│         OPCIÓN A: associate_debt_payments (NUEVA TABLA)              │
├─────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  ✅ VENTAJAS:                                                        │
│  • Tracking completo de TODOS los abonos a deuda                     │
│  • Separa claramente abonos a saldo vs abonos a deuda                │
│  • JSONB permite rastrear aplicación FIFO exacta                     │
│  • Auditoría completa (quién, cuándo, método, referencia)            │
│  • Consultas SQL sencillas (SELECT * FROM associate_debt_payments)   │
│                                                                       │
│  ⚠️ DESVENTAJAS:                                                     │
│  • Tabla adicional (pero estructuralmente correcta)                  │
│  • Requiere migración nueva                                          │
│                                                                       │
│  📊 EJEMPLO DE DATOS:                                                │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │ ID  ASOCIADO  MONTO     FECHA      APLICADO A               │    │
│  ├─────────────────────────────────────────────────────────────┤    │
│  │ 1   Juan P.   $4,000    01/11/25   Items #123, #124         │    │
│  │ 2   Juan P.   $2,500    05/11/25   Items #125 (parcial)     │    │
│  │ 3   María L.  $1,200    07/11/25   Item #156                │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                                                       │
└─────────────────────────────────────────────────────────────────────┘
```

### OPCIÓN B: Reutilizar `associate_statement_payments` con Campo

```sql
-- Agregar campo a tabla existente
ALTER TABLE associate_statement_payments
ADD COLUMN payment_type VARCHAR(20) NOT NULL DEFAULT 'STATEMENT'
    CHECK (payment_type IN ('STATEMENT', 'DEBT'));

-- Hacer statement_id opcional (NULL si payment_type = 'DEBT')
ALTER TABLE associate_statement_payments
ALTER COLUMN statement_id DROP NOT NULL;

-- Agregar campo para tracking FIFO
ALTER TABLE associate_statement_payments
ADD COLUMN applied_breakdown_items JSONB;
```

**Visualización ASCII:**
```
┌─────────────────────────────────────────────────────────────────────┐
│    OPCIÓN B: Extender associate_statement_payments (MODIFICAR)       │
├─────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  ✅ VENTAJAS:                                                        │
│  • No requiere tabla nueva                                           │
│  • Reutiliza estructura existente                                    │
│  • Un solo lugar para consultar todos los abonos                     │
│                                                                       │
│  ❌ DESVENTAJAS:                                                     │
│  • Mezcla dos conceptos diferentes (statement vs deuda)              │
│  • statement_id queda NULL en algunos casos (confuso)                │
│  • Nombre de tabla engañoso (dice "statement" pero incluye deuda)    │
│  • Validaciones más complejas (IF payment_type = 'DEBT' THEN ...)    │
│  • Consultas más complejas (WHERE payment_type = ...)                │
│                                                                       │
│  📊 EJEMPLO DE DATOS (CONFUSO):                                      │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │ ID  STATEMENT  TIPO       MONTO     ASOCIADO                │    │
│  ├─────────────────────────────────────────────────────────────┤    │
│  │ 1   #456       STATEMENT   $10,000   Juan P.                │    │
│  │ 2   NULL       DEBT        $4,000    Juan P.  ← ⚠️ NULL     │    │
│  │ 3   #457       STATEMENT   $15,000   María L.               │    │
│  │ 4   NULL       DEBT        $2,500    Juan P.  ← ⚠️ NULL     │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                                                       │
└─────────────────────────────────────────────────────────────────────┘
```

### OPCIÓN C: Solo `associate_debt_breakdown` con Campo `amount_liquidated`

```sql
-- Agregar campo para tracking parcial
ALTER TABLE associate_debt_breakdown
ADD COLUMN amount_liquidated DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
ADD COLUMN amount_remaining DECIMAL(12, 2) GENERATED ALWAYS AS (amount - amount_liquidated) STORED;

-- Cambiar lógica de is_liquidated
ALTER TABLE associate_debt_breakdown
DROP COLUMN is_liquidated,
ADD COLUMN is_liquidated BOOLEAN GENERATED ALWAYS AS (amount_liquidated >= amount) STORED;
```

**Visualización ASCII:**
```
┌─────────────────────────────────────────────────────────────────────┐
│  OPCIÓN C: Modificar associate_debt_breakdown (PARCIAL TRACKING)     │
├─────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  ✅ VENTAJAS:                                                        │
│  • No requiere tabla nueva                                           │
│  • Permite abonos parciales                                          │
│  • amount_remaining calculado automáticamente                        │
│                                                                       │
│  ❌ DESVENTAJAS:                                                     │
│  • NO registra CUÁNDO se hizo cada abono                             │
│  • NO registra QUIÉN registró el abono                               │
│  • NO registra método de pago ni referencia                          │
│  • NO permite auditoría de abonos                                    │
│  • Solo muestra estado actual, no historial                          │
│                                                                       │
│  📊 EJEMPLO DE DATOS:                                                │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │ ID  TIPO      MONTO   LIQUIDADO  RESTANTE  IS_LIQUIDATED    │    │
│  ├─────────────────────────────────────────────────────────────┤    │
│  │ 1   UNREP.    $5,000  $3,500     $1,500    false            │    │
│  │ 2   LATE_FEE  $  960  $  960     $    0    true             │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                                                       │
│  ⚠️ PROBLEMA: No sabemos CÓMO se llegó a $3,500 liquidados          │
│              (¿1 abono? ¿3 abonos? ¿cuándo? ¿quién?)                 │
│                                                                       │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 4. RECOMENDACIÓN FINAL

### 4.1 Elección: OPCIÓN A ⭐⭐⭐⭐⭐

**RAZONES:**

1. **Separación de Responsabilidades:**
   - `associate_statement_payments` → Abonos al SALDO ACTUAL
   - `associate_debt_payments` → Abonos a la DEUDA ACUMULADA
   - Conceptos claramente diferenciados

2. **Auditoría Completa:**
   - Registro de TODOS los abonos con fecha, método, referencia
   - Rastreo de quién registró el abono (`registered_by`)
   - Historial completo para compliance

3. **Tracking FIFO Preciso:**
   - JSONB `applied_breakdown_items` permite rastrear exactamente cómo se distribuyó cada abono
   - Fácil generar reportes de "cómo se liquidó la deuda"

4. **Consultas Simples:**
   ```sql
   -- Todos los abonos a deuda de un asociado
   SELECT * FROM associate_debt_payments
   WHERE associate_profile_id = 123
   ORDER BY payment_date DESC;
   
   -- Total abonado a deuda en un mes
   SELECT SUM(payment_amount)
   FROM associate_debt_payments
   WHERE associate_profile_id = 123
     AND payment_date BETWEEN '2025-11-01' AND '2025-11-30';
   ```

5. **Escalabilidad:**
   - Si en el futuro se necesitan más campos específicos de deuda, no afecta a statements
   - Fácil agregar índices y optimizaciones específicas

### 4.2 Estructura Final Propuesta

```sql
CREATE TABLE associate_debt_payments (
    id SERIAL PRIMARY KEY,
    associate_profile_id INTEGER NOT NULL REFERENCES associate_profiles(id) ON DELETE CASCADE,
    payment_amount DECIMAL(12, 2) NOT NULL,
    payment_date DATE NOT NULL,
    payment_method_id INTEGER NOT NULL REFERENCES payment_methods(id),
    payment_reference VARCHAR(100),
    registered_by INTEGER NOT NULL REFERENCES users(id),
    notes TEXT,
    
    -- ⭐ TRACKING FIFO: Desglose de aplicación
    applied_breakdown_items JSONB NOT NULL,
    -- Ejemplo: [{"debt_breakdown_id": 123, "amount_applied": 1000.00}, ...]
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Validaciones
    CONSTRAINT check_debt_payment_amount_positive CHECK (payment_amount > 0),
    CONSTRAINT check_debt_payment_date_logical CHECK (payment_date <= CURRENT_DATE)
);

COMMENT ON TABLE associate_debt_payments IS '⭐ NUEVO: Registro de abonos del asociado para liquidar DEUDA ACUMULADA (debt_balance). Separado de associate_statement_payments (saldo actual).';
COMMENT ON COLUMN associate_debt_payments.applied_breakdown_items IS 'JSONB array con desglose FIFO de cómo se aplicó el pago: [{"debt_breakdown_id": 123, "amount_applied": 1000.00, "debt_type": "UNREPORTED_PAYMENT", "cut_period": "2025-Q01"}]';

-- Índices
CREATE INDEX idx_debt_payments_associate_profile_id ON associate_debt_payments(associate_profile_id);
CREATE INDEX idx_debt_payments_payment_date ON associate_debt_payments(payment_date);
CREATE INDEX idx_debt_payments_registered_by ON associate_debt_payments(registered_by);
CREATE INDEX idx_debt_payments_method ON associate_debt_payments(payment_method_id);

-- Índice GIN para búsquedas en JSONB
CREATE INDEX idx_debt_payments_breakdown_items ON associate_debt_payments USING gin(applied_breakdown_items);
```

---

## 5. VISTAS SQL PROPUESTAS

### 5.1 Vista: Resumen de Deuda por Asociado

```sql
CREATE OR REPLACE VIEW v_associate_debt_summary AS
SELECT 
    ap.id AS associate_profile_id,
    ap.user_id,
    u.first_name || ' ' || u.last_name AS associate_name,
    ap.debt_balance AS total_debt,
    
    -- Totales por tipo
    SUM(CASE WHEN adb.debt_type = 'UNREPORTED_PAYMENT' AND NOT adb.is_liquidated THEN adb.amount ELSE 0 END) AS unreported_debt,
    SUM(CASE WHEN adb.debt_type = 'LATE_FEE' AND NOT adb.is_liquidated THEN adb.amount ELSE 0 END) AS late_fee_debt,
    SUM(CASE WHEN adb.debt_type = 'DEFAULTED_CLIENT' AND NOT adb.is_liquidated THEN adb.amount ELSE 0 END) AS defaulted_client_debt,
    
    -- Contadores
    COUNT(CASE WHEN NOT adb.is_liquidated THEN 1 END) AS pending_items_count,
    COUNT(CASE WHEN adb.is_liquidated THEN 1 END) AS liquidated_items_count,
    
    -- Deuda más antigua
    MIN(CASE WHEN NOT adb.is_liquidated THEN adb.created_at END) AS oldest_debt_date,
    
    -- Total abonado a deuda
    COALESCE(SUM(adp.payment_amount), 0) AS total_paid_to_debt
    
FROM associate_profiles ap
JOIN users u ON u.id = ap.user_id
LEFT JOIN associate_debt_breakdown adb ON adb.associate_profile_id = ap.id
LEFT JOIN associate_debt_payments adp ON adp.associate_profile_id = ap.id
GROUP BY ap.id, ap.user_id, u.first_name, u.last_name, ap.debt_balance;
```

**Uso:**
```sql
-- Ver resumen de deuda de todos los asociados
SELECT * FROM v_associate_debt_summary
WHERE total_debt > 0
ORDER BY total_debt DESC;

-- Resultado esperado:
┌────────────────────────────────────────────────────────────────────┐
│ ASOCIADO     TOTAL      UNREP    MORA     MOROSOS  ITEMS  PAGADO  │
├────────────────────────────────────────────────────────────────────┤
│ Juan Pérez   $8,500    $6,040   $1,460   $1,000   5      $2,300   │
│ María López  $5,200    $4,200   $1,000   $0       3      $0       │
└────────────────────────────────────────────────────────────────────┘
```

### 5.2 Vista: Historial de Abonos (Ambos Tipos)

```sql
CREATE OR REPLACE VIEW v_associate_all_payments AS
-- Abonos a SALDO ACTUAL (statements)
SELECT 
    'STATEMENT' AS payment_type,
    asp.id AS payment_id,
    aps.user_id AS associate_user_id,
    aps.cut_period_id,
    aps.statement_number,
    asp.payment_amount,
    asp.payment_date,
    pm.name AS payment_method,
    asp.payment_reference,
    asp.registered_by,
    u.first_name || ' ' || u.last_name AS registered_by_name,
    asp.notes,
    asp.created_at
FROM associate_statement_payments asp
JOIN associate_payment_statements aps ON aps.id = asp.statement_id
JOIN payment_methods pm ON pm.id = asp.payment_method_id
JOIN users u ON u.id = asp.registered_by

UNION ALL

-- Abonos a DEUDA ACUMULADA
SELECT 
    'DEBT' AS payment_type,
    adp.id AS payment_id,
    ap.user_id AS associate_user_id,
    NULL AS cut_period_id,
    'DEUDA ACUMULADA' AS statement_number,
    adp.payment_amount,
    adp.payment_date,
    pm.name AS payment_method,
    adp.payment_reference,
    adp.registered_by,
    u.first_name || ' ' || u.last_name AS registered_by_name,
    adp.notes,
    adp.created_at
FROM associate_debt_payments adp
JOIN associate_profiles ap ON ap.id = adp.associate_profile_id
JOIN payment_methods pm ON pm.id = adp.payment_method_id
JOIN users u ON u.id = adp.registered_by
ORDER BY payment_date DESC, created_at DESC;
```

**Uso:**
```sql
-- Ver TODOS los abonos de un asociado (saldo + deuda)
SELECT * FROM v_associate_all_payments
WHERE associate_user_id = 123
ORDER BY payment_date DESC;

-- Resultado esperado:
┌────────────────────────────────────────────────────────────────────┐
│ TIPO       FECHA      MONTO      DESTINO              REGISTRÓ    │
├────────────────────────────────────────────────────────────────────┤
│ STATEMENT  07/11/25   $10,000    2025-Q04             Admin       │
│ DEBT       05/11/25   $2,500     DEUDA ACUMULADA      Admin       │
│ DEBT       01/11/25   $4,000     DEUDA ACUMULADA      Admin       │
│ STATEMENT  25/10/25   $5,000     2025-Q03             Admin       │
└────────────────────────────────────────────────────────────────────┘
```

---

## 6. EJEMPLOS DE USO

### 6.1 Registrar Abono a Deuda (Backend)

```python
# Python pseudocódigo
def register_debt_payment(associate_profile_id, payment_amount, payment_method_id, 
                         payment_reference, registered_by, notes=None):
    
    # 1. Obtener deuda pendiente FIFO
    pending_debts = db.query("""
        SELECT id, amount, debt_type, cut_period_id
        FROM associate_debt_breakdown
        WHERE associate_profile_id = %s
          AND is_liquidated = false
        ORDER BY created_at ASC, id ASC
    """, [associate_profile_id])
    
    # 2. Distribuir pago FIFO
    remaining_amount = payment_amount
    applied_items = []
    
    for debt in pending_debts:
        if remaining_amount <= 0:
            break
        
        if remaining_amount >= debt.amount:
            # Liquidar completamente
            amount_applied = debt.amount
            
            db.execute("""
                UPDATE associate_debt_breakdown
                SET is_liquidated = true,
                    liquidated_at = NOW(),
                    liquidation_reference = %s
                WHERE id = %s
            """, [payment_reference, debt.id])
            
        else:
            # Liquidar parcialmente (split)
            amount_applied = remaining_amount
            
            # Reducir monto original
            db.execute("""
                UPDATE associate_debt_breakdown
                SET amount = amount - %s
                WHERE id = %s
            """, [amount_applied, debt.id])
        
        applied_items.append({
            "debt_breakdown_id": debt.id,
            "amount_applied": amount_applied,
            "debt_type": debt.debt_type,
            "cut_period": debt.cut_period_id
        })
        
        remaining_amount -= amount_applied
    
    # 3. Registrar el pago
    db.execute("""
        INSERT INTO associate_debt_payments (
            associate_profile_id,
            payment_amount,
            payment_date,
            payment_method_id,
            payment_reference,
            registered_by,
            notes,
            applied_breakdown_items
        ) VALUES (%s, %s, CURRENT_DATE, %s, %s, %s, %s, %s::jsonb)
    """, [
        associate_profile_id,
        payment_amount,
        payment_method_id,
        payment_reference,
        registered_by,
        notes,
        json.dumps(applied_items)
    ])
    
    # 4. Actualizar debt_balance del asociado
    amount_liquidated = payment_amount - remaining_amount
    db.execute("""
        UPDATE associate_profiles
        SET debt_balance = debt_balance - %s
        WHERE id = %s
    """, [amount_liquidated, associate_profile_id])
    
    return {
        "payment_amount": payment_amount,
        "amount_applied": amount_liquidated,
        "remaining_credit": remaining_amount,
        "items_liquidated": len(applied_items)
    }
```

### 6.2 Consultar Desglose de Deuda (Frontend)

```javascript
// Frontend - Obtener desglose de deuda
async function fetchDebtBreakdown(associateUserId) {
  const response = await apiClient.get(
    `/api/associates/${associateUserId}/debt-breakdown`
  );
  
  // Respuesta esperada:
  // {
  //   "total_debt": 8500.00,
  //   "items": [
  //     {
  //       "id": 123,
  //       "cut_period": "2025-Q01",
  //       "debt_type": "UNREPORTED_PAYMENT",
  //       "amount": 3200.00,
  //       "is_liquidated": false,
  //       "created_at": "2025-02-08"
  //     },
  //     // ... más items
  //   ],
  //   "summary_by_type": {
  //     "UNREPORTED_PAYMENT": 6040.00,
  //     "LATE_FEE": 1460.00,
  //     "DEFAULTED_CLIENT": 1000.00
  //   }
  // }
  
  return response.data;
}
```

---

## 📌 RESUMEN EJECUTIVO

### ✅ RECOMENDACIÓN: OPCIÓN A

```
┌─────────────────────────────────────────────────────────────────────┐
│                      IMPLEMENTACIÓN RECOMENDADA                      │
├─────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  CREAR TABLA NUEVA: associate_debt_payments                          │
│                                                                       │
│  VENTAJAS:                                                           │
│  ✅ Separación clara: saldo actual vs deuda acumulada                │
│  ✅ Auditoría completa de abonos a deuda                             │
│  ✅ Tracking FIFO preciso con JSONB                                  │
│  ✅ Consultas SQL simples y eficientes                               │
│  ✅ Escalable y mantenible                                           │
│                                                                       │
│  ESTRUCTURA DE DATOS:                                                │
│  ├─ associate_statement_payments → Abonos a SALDO ACTUAL             │
│  ├─ associate_debt_payments → Abonos a DEUDA ACUMULADA ⭐ NUEVO      │
│  └─ associate_debt_breakdown → Desglose de deuda (is_liquidated)     │
│                                                                       │
│  VISTAS PROPUESTAS:                                                  │
│  ├─ v_associate_debt_summary → Resumen de deuda por asociado         │
│  └─ v_associate_all_payments → Historial unificado de abonos         │
│                                                                       │
└─────────────────────────────────────────────────────────────────────┘
```

---

**FIN DEL ANÁLISIS**  
Última actualización: 2025-11-11 por GitHub Copilot
