# 📊 ANÁLISIS DE LA LÓGICA DE NEGOCIO REAL DEL SISTEMA

**Fecha**: 2025-11-25  
**Revisión**: Análisis profundo basado en código real  
**Estado**: ✅ DOCUMENTACIÓN VERIFICADA

---

## 🎯 RESUMEN EJECUTIVO - CORRECCIONES CRÍTICAS

### ❌ ERROR EN MI ANÁLISIS ANTERIOR

En mi análisis previo, **MALINTERPRETÉ** el flujo de comisiones. Aquí está la **LÓGICA REAL**:

---

## 💰 FLUJO DE DINERO REAL (CORREGIDO)

### **La Comisión NO es del 5% fija - Depende del Perfil de Tasa**

```sql
-- payments table tiene estos campos:
expected_amount        -- Lo que el CLIENTE paga (incluye capital + interés)
commission_amount      -- Comisión que CREDICUENTA cobra al ASOCIADO
associate_payment      -- Lo que el ASOCIADO debe pagar a CREDICUENTA

-- RELACIÓN MATEMÁTICA REAL:
associate_payment = expected_amount - commission_amount
```

### **Ejemplo Numérico Real:**

```
Cliente paga: $1,250 (expected_amount)
  ├─ Interés del préstamo: Ya incluido en el cálculo
  └─ Capital amortizado: Parte del $1,250

De esos $1,250:
  ├─ Comisión CrediCuenta: $31.25 (2.5% según perfil)
  └─ Pago neto del Asociado a CrediCuenta: $1,218.75

El asociado NO se queda con comisión - ¡Es CrediCuenta quien cobra!
```

---

## 📐 SISTEMA DE RATE PROFILES (Dos Tasas Independientes)

### **Estructura de `rate_profiles`:**

```sql
CREATE TABLE rate_profiles (
    code VARCHAR(50) PRIMARY KEY,
    name VARCHAR(100),
    calculation_type VARCHAR(20),  -- 'table_lookup' o 'formula'
    
    -- ⭐ LAS DOS TASAS INDEPENDIENTES:
    interest_rate_percent DECIMAL(5,3),      -- Tasa para el CLIENTE
    commission_rate_percent DECIMAL(5,3),    -- Tasa para CREDICUENTA (sobre pago del cliente)
    
    enabled BOOLEAN DEFAULT true
);
```

### **Perfiles Reales del Sistema:**

| Código | Tipo | Interés Cliente | Comisión CrediCuenta | Cálculo |
|--------|------|----------------|---------------------|---------|
| `legacy` | table_lookup | Variable (tabla) | 2.5% | Tabla legacy |
| `transition` | formula | 4.25% quincenal | 2.5% | Fórmula |
| `standard` | formula | 3.75% quincenal | 2.0% | Fórmula |
| `premium` | formula | 3.25% quincenal | 1.5% | Fórmula |

### **Función `calculate_loan_payment()`:**

Esta función calcula **AMBAS TASAS** por separado:

```sql
FUNCTION calculate_loan_payment(
    p_amount DECIMAL,
    p_term_biweeks INT,
    p_profile_code VARCHAR
) RETURNS TABLE (
    -- Tasas
    interest_rate_percent DECIMAL,      -- Tasa del cliente
    commission_rate_percent DECIMAL,    -- Tasa de CrediCuenta
    
    -- Cliente
    biweekly_payment DECIMAL,           -- Pago quincenal (capital + interés)
    total_payment DECIMAL,              -- Total del préstamo
    total_interest DECIMAL,             -- Interés total pagado
    
    -- Asociado/CrediCuenta
    commission_per_payment DECIMAL,     -- Comisión por pago
    total_commission DECIMAL,           -- Comisión total
    associate_payment DECIMAL,          -- Pago neto a CrediCuenta
    associate_total DECIMAL             -- Total que el asociado paga
)
```

**Ejemplo con perfil `transition` ($10,000 a 12 quincenas):**

```sql
SELECT * FROM calculate_loan_payment(10000, 12, 'transition');

Resultado:
- interest_rate_percent: 4.250%
- commission_rate_percent: 2.500%
- biweekly_payment: $1,258.33  (cliente paga esto)
- total_payment: $15,100.00
- total_interest: $5,100.00
- commission_per_payment: $31.46  (2.5% de $1,258.33)
- total_commission: $377.52
- associate_payment: $1,226.87  (lo que paga a CrediCuenta)
- associate_total: $14,722.48
```

---

## 🔄 GENERACIÓN DE PAGOS AL APROBAR PRÉSTAMO

### **Trigger `generate_payment_schedule()`:**

Cuando un préstamo pasa a estado `APPROVED`:

```sql
1. Valida que existan campos calculados:
   - biweekly_payment (calculado por calculate_loan_payment)
   - total_payment
   - commission_per_payment
   
2. Calcula primera fecha con el ORÁCULO:
   v_first_payment_date := calculate_first_payment_date(approved_at)
   
3. Genera cronograma completo llamando a:
   generate_amortization_schedule(
       amount,                    -- Capital
       biweekly_payment,          -- Pago quincenal
       term_biweeks,              -- Plazo
       commission_rate,           -- Tasa de comisión (%)
       first_payment_date         -- Primera fecha
   )
   
4. Por cada pago del cronograma:
   - Busca el cut_period que contenga esa fecha
   - Inserta en payments con TODOS los campos
```

### **Función `generate_amortization_schedule()`:**

Genera tabla de amortización completa:

```sql
RETURNS TABLE (
    periodo INT,              -- Número de pago (1, 2, 3...)
    fecha_pago DATE,          -- Fecha de vencimiento (15 o último día)
    pago_cliente DECIMAL,     -- Monto esperado
    interes_cliente DECIMAL,  -- Interés del periodo
    capital_cliente DECIMAL,  -- Abono a capital
    saldo_pendiente DECIMAL,  -- Saldo restante
    comision_socio DECIMAL,   -- Comisión de CrediCuenta
    pago_socio DECIMAL        -- Pago neto del asociado
)
```

---

## 📅 DOBLE CALENDARIO Y ASIGNACIÓN A PERIODOS

### **Calendario del Cliente (payment_due_date):**

- Día 15 de cada mes
- Último día de cada mes
- Alternancia: 15 → 31/30/28 → 15 → 31/30/28...

### **Calendario Administrativo (cut_periods):**

- Periodo A: Día 8-22 (15 días)
- Periodo B: Día 23-7 siguiente (15-16 días)

### **Asignación de Pagos a Periodos:**

```sql
-- En generate_payment_schedule():
SELECT id INTO v_period_id
FROM cut_periods
WHERE period_start_date <= v_amortization_row.fecha_pago
  AND period_end_date >= v_amortization_row.fecha_pago
ORDER BY period_start_date DESC
LIMIT 1;
```

**Ejemplo:**
- Pago vence el 15-ene-2025 (cliente)
- Cae en periodo 08-ene a 22-ene (periodo A)
- Se asigna: `payments.cut_period_id = periodo_A`

---

## 🏢 ESTADOS DE CUENTA POR ASOCIADO Y PERIODO

### **Concepto de "Periodos Hijos":**

Tu concepto es correcto - necesitamos pensar en estructura jerárquica:

```
PERIODO GENERAL (cut_period)
└── ESTADOS DE CUENTA (associate_payment_statements) - uno por asociado
    ├── Asociada María: Statement con sus pagos
    ├── Asociada Ana: Statement con sus pagos
    └── Asociada Laura: Statement con sus pagos
```

### **Generación de Statements:**

Actualmente el sistema tiene la tabla `associate_payment_statements` con:

```sql
CREATE TABLE associate_payment_statements (
    id SERIAL PRIMARY KEY,
    cut_period_id INTEGER,          -- FK al periodo general
    user_id INTEGER,                -- Asociado (FK a users)
    statement_number VARCHAR(50),   -- Número único
    
    -- Agregados del periodo
    total_payments_count INTEGER,                  -- Cantidad de pagos
    total_amount_collected DECIMAL,                -- SUM(expected_amount)
    total_commission_owed DECIMAL,                 -- SUM(commission_amount)
    commission_rate_applied DECIMAL,               -- Tasa aplicada
    
    -- Pagos y mora
    paid_amount DECIMAL,                           -- Abonos del asociado
    late_fee_amount DECIMAL,                       -- Mora 30%
    late_fee_applied BOOLEAN,                      
    
    -- Estados
    status_id INTEGER,                             -- GENERATED, SENT, PAID, etc.
    generated_date DATE,
    due_date DATE
);
```

### **¿Cómo se relacionan los pagos con los statements?**

```sql
-- Los pagos individuales pertenecen a un periodo:
SELECT * FROM payments WHERE cut_period_id = 44;

-- Los statements agrupan por asociado:
SELECT * FROM associate_payment_statements 
WHERE cut_period_id = 44 AND user_id = 123;

-- Para generar un statement, se agregan los pagos:
SELECT 
    COUNT(*) as total_payments_count,
    SUM(expected_amount) as total_amount_collected,
    SUM(commission_amount) as total_commission_owed
FROM payments p
JOIN loans l ON p.loan_id = l.id
WHERE p.cut_period_id = 44
  AND l.associate_user_id = 123;  -- Filtro por asociado
```

---

## ⚠️ PROBLEMAS IDENTIFICADOS

### **1. Error 500 en el endpoint `/cut-periods/{id}/statements`**

**Problema:** El query busca columnas que NO existen:

```python
# ❌ QUERY ACTUAL (INCORRECTO):
SELECT 
    aps.associate_id,              -- NO EXISTE (es user_id)
    aps.cut_code,                  -- NO EXISTE
    aps.total_collected_amount,    -- NO EXISTE (es total_amount_collected)
    aps.commission_amount,         -- NO EXISTE (es total_commission_owed)
    aps.total_statement_amount,    -- NO EXISTE
    aps.paid_statement_amount,     -- NO EXISTE (es paid_amount)
    aps.statement_status_id        -- NO EXISTE (es status_id)
FROM associate_payment_statements aps
```

**Solución:** Corregir nombres de columnas según esquema real.

### **2. Falta Generación Automática de Statements**

Actualmente NO hay proceso que genere automáticamente los statements cuando:
- Se cierra un periodo
- Se crea un periodo nuevo
- Se registran pagos en un periodo activo

**Necesitamos:** Función SQL o endpoint que genere statements por periodo.

### **3. No hay diferenciación clara entre:**

- **Periodo General** (`cut_periods`) - Contiene fechas de corte
- **Statements de Asociados** (`associate_payment_statements`) - Estados de cuenta individuales

**Necesitamos:** Vista o lógica que agrupe correctamente.

---

## ✅ PLAN DE CORRECCIÓN

### **Fase 1: Corregir Error 500 (Inmediato)**

1. Arreglar query en `/cut-periods/{id}/statements`
2. Mapear correctamente columnas de `associate_payment_statements`

### **Fase 2: Generación de Statements (Crítico)**

1. Crear función SQL `generate_statements_for_period(period_id)`
2. Que recorra todos los asociados con pagos en ese periodo
3. Que genere un statement por asociado con agregados correctos

### **Fase 3: Frontend (UI/UX)**

1. Vista de Periodo General con lista de asociados
2. Expandir para ver el statement de cada asociado
3. Desglose de pagos individuales por asociado

---

## 📊 ESTRUCTURA CORRECTA DE DATOS

### **Consulta para generar un Statement:**

```sql
-- Por cada asociado que tenga pagos en el periodo:
WITH associate_payments AS (
    SELECT 
        l.associate_user_id,
        COUNT(p.id) as payment_count,
        SUM(p.expected_amount) as total_collected,
        SUM(p.commission_amount) as total_commission,
        AVG(p.commission_amount / NULLIF(p.expected_amount, 0) * 100) as avg_commission_rate
    FROM payments p
    JOIN loans l ON p.loan_id = l.id
    WHERE p.cut_period_id = :period_id
      AND l.associate_user_id IS NOT NULL
    GROUP BY l.associate_user_id
)
INSERT INTO associate_payment_statements (
    cut_period_id,
    user_id,
    statement_number,
    total_payments_count,
    total_amount_collected,
    total_commission_owed,
    commission_rate_applied,
    status_id,
    generated_date,
    due_date
)
SELECT 
    :period_id,
    associate_user_id,
    'ST-' || :period_id || '-' || associate_user_id,
    payment_count,
    total_collected,
    total_commission,
    COALESCE(avg_commission_rate, 2.5),
    (SELECT id FROM statement_statuses WHERE name = 'GENERATED'),
    CURRENT_DATE,
    (SELECT period_end_date FROM cut_periods WHERE id = :period_id) + INTERVAL '7 days'
FROM associate_payments;
```

---

## 🎯 CONCLUSIÓN

### **Lógica de Negocio Real:**

1. **Comisión** = CrediCuenta cobra al ASOCIADO (NO el asociado gana)
2. **Tasa variable** según perfil de tasa (2.5%, 2.0%, 1.5%)
3. **Dos calendarios** independientes pero sincronizados
4. **Pagos** se asignan a periodos según fecha de vencimiento
5. **Statements** agrupan pagos por asociado y periodo
6. **Generate payment schedule** crea TODO al aprobar préstamo

### **Próximos Pasos:**

1. ✅ Corregir endpoint de statements
2. 🔄 Crear generación automática de statements
3. 🔄 Mejorar frontend para reflejar jerarquía correcta
4. 🔄 Implementar PDF de statements por asociado

**FIN DEL ANÁLISIS**
