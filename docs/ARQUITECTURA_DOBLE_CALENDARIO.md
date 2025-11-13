# 🗓️ ARQUITECTURA DEL DOBLE CALENDARIO QUINCENAL

**Autor**: Análisis Técnico Sprint 6  
**Fecha**: 2025-11-05  
**Versión**: 2.0  
**Estado**: ✅ DOCUMENTACIÓN TÉCNICA DEFINITIVA

---

## 📋 TABLA DE CONTENIDOS

1. [Resumen Ejecutivo](#resumen-ejecutivo)
2. [Los Dos Calendarios](#los-dos-calendarios)
3. [El Oráculo: calculate_first_payment_date()](#el-oráculo)
4. [Generación de Cronogramas](#generación-de-cronogramas)
5. [Trigger de Pagos](#trigger-de-pagos)
6. [Mapeo entre Calendarios](#mapeo-entre-calendarios)
7. [Problemas Identificados](#problemas-identificados)
8. [Plan de Corrección](#plan-de-corrección)
9. [Casos de Prueba](#casos-de-prueba)

---

## 🎯 RESUMEN EJECUTIVO

El sistema Credinet v2.0 utiliza **dos calendarios simultáneos** para gestionar préstamos quincenales:

| Calendario | Propósito | Fechas Clave | Tabla/Campo |
|-----------|-----------|--------------|-------------|
| **Cliente** | Vencimientos de pago | Día 15 y último día del mes | `payments.payment_due_date` |
| **Administrativo** | Cortes contables | Día 8-22 y 23-7 | `cut_periods.period_start_date/end_date` |

**¿Por qué dos calendarios?**
- **Clientes** necesitan fechas predecibles y fáciles de recordar (15 y fin de mes)
- **Administración** necesita periodos de corte para reportes, comisiones, cierres contables

**Sincronización**: La función `calculate_first_payment_date()` actúa como "oráculo" que mapea la fecha de aprobación del préstamo al primer vencimiento del cliente, garantizando coherencia entre ambos calendarios.

---

## 🗓️ LOS DOS CALENDARIOS

### 📆 CALENDARIO DEL CLIENTE (payment_due_date)

**Patrón de fechas:**
- **Día 15** de cada mes
- **Último día** de cada mes (28, 29, 30 o 31 según mes/año)

**Alternancia:**
```
Pago 1: 15-ene
Pago 2: 31-ene
Pago 3: 15-feb
Pago 4: 28-feb  (o 29 si es bisiesto)
Pago 5: 15-mar
Pago 6: 31-mar
...
```

**Características:**
- ✅ Fechas predecibles y fáciles de recordar
- ✅ Siempre 2 pagos por mes
- ✅ Intervalo aproximado de 14-16 días
- ✅ Cliente puede planificar pagos con anticipación

**Implementación:**
- Función SQL: `generate_amortization_schedule()`
- Trigger: `generate_payment_schedule()`
- Campo: `payments.payment_due_date`

**Algoritmo de alternancia:**
```sql
IF EXTRACT(DAY FROM v_current_payment_date) = 15 THEN
    -- Si es día 15 → siguiente es último día del mes actual
    v_current_payment_date := (
        DATE_TRUNC('month', v_current_payment_date) 
        + INTERVAL '1 month' 
        - INTERVAL '1 day'
    )::DATE;
ELSE
    -- Si es último día → siguiente es día 15 del mes siguiente
    v_current_payment_date := MAKE_DATE(
        EXTRACT(YEAR FROM v_current_payment_date + INTERVAL '1 month')::INTEGER,
        EXTRACT(MONTH FROM v_current_payment_date + INTERVAL '1 month')::INTEGER,
        15
    );
END IF;
```

---

### 🏢 CALENDARIO ADMINISTRATIVO (cut_periods)

**Patrón de periodos:**
- **Periodo A**: Día 8-22 (15 días)
- **Periodo B**: Día 23-7 del mes siguiente (15-16 días)

**Ejemplo real de base de datos:**
```
| id | period_start_date | period_end_date | Días |
|----|-------------------|-----------------|------|
| 3  | 2025-01-08        | 2025-01-22      | 15   |
| 4  | 2025-01-23        | 2025-02-07      | 16   |
| 5  | 2025-02-08        | 2025-02-22      | 15   |
| 6  | 2025-02-23        | 2025-03-07      | 13*  |
| 7  | 2025-03-08        | 2025-03-22      | 15   |
| 8  | 2025-03-23        | 2025-04-07      | 16   |
```
*Febrero tiene menos días

**Características:**
- ✅ Periodos fijos para cierres contables
- ✅ Facilita cálculo de comisiones de asociados
- ✅ Permite reportes periódicos consistentes
- ✅ Independiente de fechas de pago de clientes

**Implementación:**
- Tabla: `cut_periods`
- Campos: `id`, `period_start_date`, `period_end_date`, `status_id`
- Relación: `payments.cut_period_id → cut_periods.id`

---

## 🔮 EL ORÁCULO: calculate_first_payment_date()

Esta función es el **núcleo de la sincronización** entre ambos calendarios.

### LÓGICA DE DECISIÓN

**Recibe:** Fecha de aprobación del préstamo  
**Retorna:** Primer vencimiento de pago del cliente

```sql
CREATE OR REPLACE FUNCTION calculate_first_payment_date(p_approval_date date)
RETURNS date
LANGUAGE plpgsql
IMMUTABLE PARALLEL SAFE STRICT
AS $function$
DECLARE
    v_approval_day INTEGER;
    v_first_payment_date DATE;
BEGIN
    v_approval_day := EXTRACT(DAY FROM p_approval_date)::INTEGER;
    
    v_first_payment_date := CASE
        -- CASO 1: Aprobación días 1-7 → Primer pago día 15 del mes ACTUAL
        WHEN v_approval_day >= 1 AND v_approval_day < 8 THEN
            MAKE_DATE(
                EXTRACT(YEAR FROM p_approval_date)::INTEGER,
                EXTRACT(MONTH FROM p_approval_date)::INTEGER,
                15
            )
        
        -- CASO 2: Aprobación días 8-22 → Primer pago ÚLTIMO día del mes ACTUAL
        WHEN v_approval_day >= 8 AND v_approval_day < 23 THEN
            (DATE_TRUNC('month', p_approval_date) 
             + INTERVAL '1 month' 
             - INTERVAL '1 day')::DATE
        
        -- CASO 3: Aprobación día 23+ → Primer pago día 15 del mes SIGUIENTE
        WHEN v_approval_day >= 23 THEN
            MAKE_DATE(
                EXTRACT(YEAR FROM p_approval_date + INTERVAL '1 month')::INTEGER,
                EXTRACT(MONTH FROM p_approval_date + INTERVAL '1 month')::INTEGER,
                15
            )
        
        ELSE NULL
    END;
    
    RETURN v_first_payment_date;
END;
$function$
```

### TABLA DE MAPEO

| Día de Aprobación | Periodo Admin Activo | Primer Pago Cliente | Días de Gracia |
|-------------------|---------------------|---------------------|----------------|
| 1-7               | Periodo B (23-7)    | Día 15 mes actual   | 8-14 días      |
| 8-22              | Periodo A (8-22)    | Último día mes actual| 9-23 días      |
| 23-31             | Periodo B (23-7)    | Día 15 mes siguiente| 23-37 días     |

### EJEMPLOS REALES

**Ejemplo 1: Aprobación 05-ene-2025 (día 5)**
- Cae en rango: 1-7
- Periodo admin: 23-dic-2024 a 07-ene-2025 (id=2)
- **Primer pago: 15-ene-2025** ✅
- Días de gracia: 10 días

**Ejemplo 2: Aprobación 10-ene-2025 (día 10)**
- Cae en rango: 8-22
- Periodo admin: 08-ene-2025 a 22-ene-2025 (id=3)
- **Primer pago: 31-ene-2025** ✅
- Días de gracia: 21 días

**Ejemplo 3: Aprobación 25-ene-2025 (día 25)**
- Cae en rango: 23-31
- Periodo admin: 23-ene-2025 a 07-feb-2025 (id=4)
- **Primer pago: 15-feb-2025** ✅
- Días de gracia: 21 días

**Ejemplo 4: Aprobación 28-feb-2025 (último día)**
- Cae en rango: 23-31
- Periodo admin: 23-feb-2025 a 07-mar-2025 (id=6)
- **Primer pago: 15-mar-2025** ✅
- Días de gracia: 15 días

---

## 📊 GENERACIÓN DE CRONOGRAMAS

### generate_amortization_schedule()

**Propósito:** Calcular el desglose financiero completo de cada pago.

**Parámetros:**
```sql
p_amount NUMERIC           -- Monto del préstamo
p_biweekly_payment NUMERIC -- Pago quincenal (con interés)
p_term_biweeks INTEGER     -- Plazo en quincenas
p_commission_rate NUMERIC  -- Tasa de comisión (%)
p_start_date DATE          -- Primera fecha de pago
```

**Retorna TABLE:**
```sql
periodo INTEGER           -- Número de pago (1, 2, 3...)
fecha_pago DATE          -- Fecha de vencimiento (15 o último día)
pago_cliente NUMERIC     -- Total a pagar por cliente
interes_cliente NUMERIC  -- Interés del periodo
capital_cliente NUMERIC  -- Abono a capital del periodo
saldo_pendiente NUMERIC  -- Saldo restante después del pago
comision_socio NUMERIC   -- Comisión del asociado
pago_socio NUMERIC       -- Pago neto al asociado
```

**Lógica de cálculo:**
```sql
-- Interés se distribuye proporcionalmente en todos los periodos
v_total_interest := (p_biweekly_payment * p_term_biweeks) - p_amount;
v_period_interest := v_total_interest / p_term_biweeks;
v_period_principal := p_biweekly_payment - v_period_interest;

-- Comisión se calcula sobre el pago total
v_commission := p_biweekly_payment * (p_commission_rate / 100);
v_payment_to_associate := p_biweekly_payment - v_commission;

-- Saldo disminuye con cada abono a capital
v_balance := v_balance - v_period_principal;
```

**Ejemplo de salida (préstamo $25,000, 12 quincenas, perfil standard):**

```
| periodo | fecha_pago | pago_cliente | interes_cliente | capital_cliente | saldo_pendiente | comision_socio | pago_socio |
|---------|------------|--------------|-----------------|-----------------|-----------------|----------------|------------|
| 1       | 2025-01-15 | 2768.33      | 685.42          | 2082.91         | 22917.09        | 138.42         | 2629.91    |
| 2       | 2025-01-31 | 2768.33      | 685.42          | 2082.91         | 20834.18        | 138.42         | 2629.91    |
| 3       | 2025-02-15 | 2768.33      | 685.42          | 2082.91         | 18751.27        | 138.42         | 2629.91    |
| ...     | ...        | ...          | ...             | ...             | ...             | ...            | ...        |
| 12      | 2025-06-30 | 2768.33      | 685.42          | 2082.91         | 0.00            | 138.42         | 2629.91    |
```

**Validación:**
```
SUM(pago_cliente) = $33,219.96
Capital total = $25,000
Interés total = $8,219.96
Comisión total = $1,661.04
```

---

## ⚙️ TRIGGER DE PAGOS: generate_payment_schedule()

**Propósito:** Crear automáticamente todos los registros de pagos cuando un préstamo es aprobado.

**Evento disparador:**
```sql
CREATE TRIGGER trigger_generate_payment_schedule
AFTER UPDATE OF status_id ON loans
FOR EACH ROW
EXECUTE FUNCTION generate_payment_schedule();
```

**Condición de ejecución:**
```sql
IF NEW.status_id = v_approved_status_id 
   AND (OLD.status_id IS NULL OR OLD.status_id != v_approved_status_id)
THEN
    -- Generar schedule
END IF;
```

### FLUJO ACTUAL (CON PROBLEMAS ❌)

```sql
-- 1. Calcular primera fecha con el oráculo
v_first_payment_date := calculate_first_payment_date(NEW.approved_at::DATE);

-- 2. ❌ PROBLEMA: Calcula monto SIN interés
v_payment_amount := ROUND(NEW.amount / NEW.term_biweeks, 2);

-- 3. Generar fechas y buscar cut_period
FOR v_payment_count IN 1..NEW.term_biweeks LOOP
    -- Buscar periodo administrativo que contiene esta fecha
    SELECT id INTO v_period_id
    FROM cut_periods
    WHERE period_start_date <= v_current_payment_date
      AND period_end_date >= v_current_payment_date;
    
    -- ❌ PROBLEMA: Inserta solo campos básicos
    INSERT INTO payments (
        loan_id, amount_paid, payment_date, payment_due_date,
        is_late, status_id, cut_period_id, created_at, updated_at
    ) VALUES (
        NEW.id, 0.00, v_current_payment_date, v_current_payment_date,
        false, v_pending_status_id, v_period_id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
    );
    
    -- Calcular siguiente fecha (alternancia 15 ↔ último día)
    IF EXTRACT(DAY FROM v_current_payment_date) = 15 THEN
        v_current_payment_date := (último día del mes actual);
    ELSE
        v_current_payment_date := (día 15 del mes siguiente);
    END IF;
END LOOP;
```

### PROBLEMAS IDENTIFICADOS

#### ❌ Problema 1: Cálculo Incorrecto del Monto
```sql
v_payment_amount := ROUND(NEW.amount / NEW.term_biweeks, 2);
```
- Solo divide el capital entre periodos
- **NO incluye interés**
- Ejemplo: $25,000 / 12 = $2,083.33 ❌
- Debería ser: $2,768.33 (con interés) ✅

#### ❌ Problema 2: Campos Faltantes en Tabla payments

**Campos actuales:**
- loan_id, amount_paid, payment_date, payment_due_date, is_late, status_id, cut_period_id, created_at, updated_at

**Campos necesarios:**
- ❌ `payment_number` - número de pago (1-12)
- ❌ `expected_amount` - monto esperado ($2,768.33)
- ❌ `interest_amount` - interés del periodo ($685.42)
- ❌ `principal_amount` - capital del periodo ($2,082.91)
- ❌ `commission_amount` - comisión ($138.42)
- ❌ `associate_payment` - pago al asociado ($2,629.91)
- ❌ `balance_remaining` - saldo pendiente

#### ❌ Problema 3: No Usa generate_amortization_schedule()

El trigger calcula fechas manualmente cuando ya existe una función que:
1. ✅ Calcula el desglose completo
2. ✅ Genera las fechas correctamente
3. ✅ Retorna 8 campos por periodo

---

## 🔗 MAPEO ENTRE CALENDARIOS

### LÓGICA DE ASOCIACIÓN

```sql
SELECT id INTO v_period_id
FROM cut_periods
WHERE period_start_date <= v_current_payment_date
  AND period_end_date >= v_current_payment_date
ORDER BY period_start_date DESC
LIMIT 1;
```

**Esta lógica es CORRECTA** ✅ - busca el periodo administrativo que **contiene** la fecha de vencimiento del cliente.

### TABLA DE MAPEO REAL

| payment_due_date (Cliente) | cut_period_id | period_start_date (Admin) | period_end_date (Admin) |
|----------------------------|---------------|---------------------------|-------------------------|
| 2025-01-15                 | 3             | 2025-01-08                | 2025-01-22              |
| 2025-01-31                 | 4             | 2025-01-23                | 2025-02-07              |
| 2025-02-15                 | 5             | 2025-02-08                | 2025-02-22              |
| 2025-02-28                 | 6             | 2025-02-23                | 2025-03-07              |
| 2025-03-15                 | 7             | 2025-03-08                | 2025-03-22              |
| 2025-03-31                 | 8             | 2025-03-23                | 2025-04-07              |
| 2025-04-15                 | 9             | 2025-04-08                | 2025-04-22              |
| 2025-04-30                 | 10            | 2025-04-23                | 2025-05-07              |

### VISUALIZACIÓN DEL MAPEO

```
Enero 2025:
┌──────────────────────────────────────┐
│ Periodo Admin 3: 08-ene a 22-ene     │
│   └─ Contiene: payment_due_date 15-ene │
├──────────────────────────────────────┤
│ Periodo Admin 4: 23-ene a 07-feb     │
│   └─ Contiene: payment_due_date 31-ene │
└──────────────────────────────────────┘

Febrero 2025:
┌──────────────────────────────────────┐
│ Periodo Admin 5: 08-feb a 22-feb     │
│   └─ Contiene: payment_due_date 15-feb │
├──────────────────────────────────────┤
│ Periodo Admin 6: 23-feb a 07-mar     │
│   └─ Contiene: payment_due_date 28-feb │
└──────────────────────────────────────┘
```

### CASOS ESPECIALES

**Febrero en año NO bisiesto:**
- Último día = 28-feb
- Periodo admin que lo contiene: 23-feb a 07-mar

**Febrero en año bisiesto (2024, 2028):**
- Último día = 29-feb
- Periodo admin que lo contiene: 23-feb a 07-mar

**Meses con 30 días (abril, junio, septiembre, noviembre):**
- Último día = 30
- Ejemplo: 30-abr en periodo 23-abr a 07-may

**Meses con 31 días:**
- Último día = 31
- Ejemplo: 31-ene en periodo 23-ene a 07-feb

---

## 🚨 PROBLEMAS IDENTIFICADOS

### 1. TABLA `loans` - Campos Faltantes

**Problema:** Los valores calculados por `calculate_loan_payment()` no se guardan.

**Impacto:**
- ❌ Trigger recalcula mal el pago
- ❌ No hay histórico de lo acordado originalmente
- ❌ Cambios futuros en tasas afectan préstamos antiguos

**Solución:** Agregar columnas:
```sql
ALTER TABLE loans ADD COLUMN biweekly_payment DECIMAL(12,2);
ALTER TABLE loans ADD COLUMN total_payment DECIMAL(12,2);
ALTER TABLE loans ADD COLUMN total_interest DECIMAL(12,2);
ALTER TABLE loans ADD COLUMN total_commission DECIMAL(12,2);
ALTER TABLE loans ADD COLUMN commission_per_payment DECIMAL(10,2);
ALTER TABLE loans ADD COLUMN associate_payment DECIMAL(10,2);
```

### 2. TABLA `payments` - Campos Faltantes

**Problema:** No se guarda el desglose financiero de cada pago.

**Impacto:**
- ❌ No sabemos cuánto debe pagar el cliente
- ❌ No sabemos cuánto es interés vs capital
- ❌ Reportes y auditorías incompletas
- ❌ No podemos validar pagos parciales

**Solución:** Agregar columnas:
```sql
ALTER TABLE payments ADD COLUMN payment_number INTEGER NOT NULL;
ALTER TABLE payments ADD COLUMN expected_amount DECIMAL(12,2);
ALTER TABLE payments ADD COLUMN interest_amount DECIMAL(10,2);
ALTER TABLE payments ADD COLUMN principal_amount DECIMAL(10,2);
ALTER TABLE payments ADD COLUMN commission_amount DECIMAL(10,2);
ALTER TABLE payments ADD COLUMN associate_payment DECIMAL(10,2);
ALTER TABLE payments ADD COLUMN balance_remaining DECIMAL(12,2);
```

### 3. TRIGGER `generate_payment_schedule()` - Lógica Incorrecta

**Problemas:**
1. ❌ Calcula `v_payment_amount := NEW.amount / NEW.term_biweeks` (solo capital)
2. ❌ No usa `generate_amortization_schedule()`
3. ❌ No inserta campos de desglose
4. ❌ No valida consistencia de sumas

**Solución:** Reescribir para:
1. ✅ Leer `loans.biweekly_payment` (pre-calculado)
2. ✅ Llamar `generate_amortization_schedule()`
3. ✅ Insertar TODOS los campos
4. ✅ Validar `SUM(expected_amount) = loans.total_payment`

### 4. SERVICIO `create_loan` - No Guarda Cálculos

**Problema:** Cuando se usa `profile_code`, se calcula pero no se guarda.

**Código actual:**
```python
if profile_code:
    result = await session.execute(
        text("SELECT * FROM calculate_loan_payment(:amount, :term, :profile_code)"),
        {"amount": amount, "term": term_biweeks, "profile_code": profile_code}
    )
    calc = result.fetchone()
    # ❌ Se usa calc pero NO se guarda en loans
```

**Solución:**
```python
if profile_code:
    calc = await session.execute(...).fetchone()
    # ✅ Guardar en loans
    loan.biweekly_payment = calc.biweekly_payment
    loan.total_payment = calc.total_payment
    loan.total_interest = calc.total_interest
    # ... etc
```

---

## 🛠️ PLAN DE CORRECCIÓN

### FASE 1: MIGRACIONES DE BASE DE DATOS

#### Migración 1: Campos Calculados en `loans`
```sql
-- File: db/v2.0/modules/migrations/005_add_calculated_fields_to_loans.sql

ALTER TABLE loans ADD COLUMN biweekly_payment DECIMAL(12,2);
ALTER TABLE loans ADD COLUMN total_payment DECIMAL(12,2);
ALTER TABLE loans ADD COLUMN total_interest DECIMAL(12,2);
ALTER TABLE loans ADD COLUMN total_commission DECIMAL(12,2);
ALTER TABLE loans ADD COLUMN commission_per_payment DECIMAL(10,2);
ALTER TABLE loans ADD COLUMN associate_payment DECIMAL(10,2);

COMMENT ON COLUMN loans.biweekly_payment IS 'Pago quincenal calculado (incluye interés)';
COMMENT ON COLUMN loans.total_payment IS 'Monto total a pagar (capital + interés)';
COMMENT ON COLUMN loans.total_interest IS 'Interés total del préstamo';
COMMENT ON COLUMN loans.total_commission IS 'Comisión total acumulada';
COMMENT ON COLUMN loans.commission_per_payment IS 'Comisión por pago';
COMMENT ON COLUMN loans.associate_payment IS 'Pago neto al asociado por periodo';
```

#### Migración 2: Campos de Desglose en `payments`
```sql
-- File: db/v2.0/modules/migrations/006_add_breakdown_fields_to_payments.sql

ALTER TABLE payments ADD COLUMN payment_number INTEGER;
ALTER TABLE payments ADD COLUMN expected_amount DECIMAL(12,2);
ALTER TABLE payments ADD COLUMN interest_amount DECIMAL(10,2);
ALTER TABLE payments ADD COLUMN principal_amount DECIMAL(10,2);
ALTER TABLE payments ADD COLUMN commission_amount DECIMAL(10,2);
ALTER TABLE payments ADD COLUMN associate_payment DECIMAL(10,2);
ALTER TABLE payments ADD COLUMN balance_remaining DECIMAL(12,2);

-- Constraint: payment_number debe ser positivo
ALTER TABLE payments ADD CONSTRAINT chk_payment_number_positive 
    CHECK (payment_number > 0);

-- Index para ordenar pagos por número
CREATE INDEX idx_payments_loan_number ON payments(loan_id, payment_number);

COMMENT ON COLUMN payments.payment_number IS 'Número secuencial del pago (1, 2, 3...)';
COMMENT ON COLUMN payments.expected_amount IS 'Monto esperado a pagar (capital + interés)';
COMMENT ON COLUMN payments.interest_amount IS 'Interés del periodo';
COMMENT ON COLUMN payments.principal_amount IS 'Abono a capital del periodo';
COMMENT ON COLUMN payments.commission_amount IS 'Comisión del asociado';
COMMENT ON COLUMN payments.associate_payment IS 'Pago neto al asociado (pago - comisión)';
COMMENT ON COLUMN payments.balance_remaining IS 'Saldo pendiente después de este pago';
```

### FASE 2: ACTUALIZAR MODELOS BACKEND

#### Actualizar `LoanModel`
```python
# File: /backend/app/modules/loans/infrastructure/models/__init__.py

class LoanModel(Base):
    __tablename__ = "loans"
    
    # ... campos existentes ...
    
    # Nuevos campos calculados
    biweekly_payment = Column(DECIMAL(12, 2), nullable=True)
    total_payment = Column(DECIMAL(12, 2), nullable=True)
    total_interest = Column(DECIMAL(12, 2), nullable=True)
    total_commission = Column(DECIMAL(12, 2), nullable=True)
    commission_per_payment = Column(DECIMAL(10, 2), nullable=True)
    associate_payment = Column(DECIMAL(10, 2), nullable=True)
```

#### Actualizar Mappers de `LoanRepository`
```python
# File: /backend/app/modules/loans/infrastructure/repositories/__init__.py

def _map_loan_model_to_entity(model: LoanModel) -> Loan:
    return Loan(
        # ... campos existentes ...
        biweekly_payment=model.biweekly_payment,
        total_payment=model.total_payment,
        total_interest=model.total_interest,
        total_commission=model.total_commission,
        commission_per_payment=model.commission_per_payment,
        associate_payment=model.associate_payment,
    )

def _map_loan_entity_to_model(entity: Loan) -> dict:
    return {
        # ... campos existentes ...
        "biweekly_payment": entity.biweekly_payment,
        "total_payment": entity.total_payment,
        "total_interest": entity.total_interest,
        "total_commission": entity.total_commission,
        "commission_per_payment": entity.commission_per_payment,
        "associate_payment": entity.associate_payment,
    }
```

#### Crear/Actualizar `PaymentModel`
```python
# File: /backend/app/modules/payments/infrastructure/models/__init__.py

class PaymentModel(Base):
    __tablename__ = "payments"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    loan_id = Column(Integer, ForeignKey('loans.id', ondelete='CASCADE'), nullable=False)
    
    # Campos de montos
    payment_number = Column(Integer, nullable=False)
    expected_amount = Column(DECIMAL(12, 2), nullable=True)
    amount_paid = Column(DECIMAL(12, 2), default=0.00, nullable=False)
    
    # Desglose financiero
    interest_amount = Column(DECIMAL(10, 2), nullable=True)
    principal_amount = Column(DECIMAL(10, 2), nullable=True)
    commission_amount = Column(DECIMAL(10, 2), nullable=True)
    associate_payment = Column(DECIMAL(10, 2), nullable=True)
    balance_remaining = Column(DECIMAL(12, 2), nullable=True)
    
    # Fechas
    payment_date = Column(Date, nullable=True)
    payment_due_date = Column(Date, nullable=False)
    
    # Estado y periodo
    is_late = Column(Boolean, default=False, nullable=False)
    status_id = Column(Integer, ForeignKey('payment_statuses.id'), nullable=False)
    cut_period_id = Column(Integer, ForeignKey('cut_periods.id'), nullable=True)
    
    # Auditoría
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)
```

### FASE 3: ACTUALIZAR SERVICIO DE PRÉSTAMOS

```python
# File: /backend/app/modules/loans/application/services/__init__.py

async def create_loan(
    session: AsyncSession,
    user_id: int,
    amount: Decimal,
    term_biweeks: int,
    profile_code: Optional[str] = None,
    # ... otros parámetros
) -> Loan:
    # Si tiene profile_code, calcular con función SQL
    if profile_code:
        result = await session.execute(
            text("""
                SELECT 
                    biweekly_payment, total_payment, total_interest,
                    total_client_interest, total_associate_interest,
                    client_interest_per_payment, associate_interest_per_payment,
                    total_commission, commission_per_payment,
                    associate_payment, effective_client_rate_percent,
                    effective_associate_rate_percent, associate_total_payment
                FROM calculate_loan_payment(:amount, :term_biweeks, :profile_code)
            """),
            {"amount": amount, "term_biweeks": term_biweeks, "profile_code": profile_code}
        )
        calc = result.fetchone()
        
        # ✅ GUARDAR valores calculados
        loan_data = {
            "user_id": user_id,
            "amount": amount,
            "term_biweeks": term_biweeks,
            "profile_code": profile_code,
            # Valores calculados
            "biweekly_payment": calc.biweekly_payment,
            "total_payment": calc.total_payment,
            "total_interest": calc.total_interest,
            "total_commission": calc.total_commission,
            "commission_per_payment": calc.commission_per_payment,
            "associate_payment": calc.associate_payment,
            # ... otros campos
        }
    else:
        # Lógica manual con interest_rate y commission_rate
        loan_data = {
            # ... calcular manualmente
        }
    
    # Crear préstamo con todos los campos
    loan_entity = await loan_repository.create(loan_data)
    return loan_entity
```

### FASE 4: REESCRIBIR TRIGGER

```sql
-- File: db/v2.0/modules/migrations/007_fix_generate_payment_schedule_trigger.sql

CREATE OR REPLACE FUNCTION generate_payment_schedule()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $function$
DECLARE
    v_approval_date DATE;
    v_first_payment_date DATE;
    v_approved_status_id INTEGER;
    v_pending_status_id INTEGER;
    v_amortization_row RECORD;
    v_total_inserted INTEGER := 0;
    v_sum_expected DECIMAL(12,2) := 0;
BEGIN
    -- Obtener IDs de estados
    SELECT id INTO v_approved_status_id FROM loan_statuses WHERE name = 'APPROVED';
    SELECT id INTO v_pending_status_id FROM payment_statuses WHERE name = 'PENDING';
    
    -- Solo ejecutar si el préstamo acaba de ser aprobado
    IF NEW.status_id = v_approved_status_id 
       AND (OLD.status_id IS NULL OR OLD.status_id != v_approved_status_id) 
    THEN
        -- Validaciones
        IF NEW.approved_at IS NULL THEN
            RAISE EXCEPTION 'CRITICAL: Préstamo % marcado como APPROVED pero approved_at es NULL', NEW.id;
        END IF;
        
        IF NEW.term_biweeks IS NULL OR NEW.term_biweeks <= 0 THEN
            RAISE EXCEPTION 'CRITICAL: Préstamo % tiene term_biweeks inválido: %', NEW.id, NEW.term_biweeks;
        END IF;
        
        -- ✅ VALIDAR que los campos calculados existen
        IF NEW.biweekly_payment IS NULL OR NEW.total_payment IS NULL THEN
            RAISE EXCEPTION 'CRITICAL: Préstamo % no tiene biweekly_payment o total_payment calculados', NEW.id;
        END IF;
        
        v_approval_date := NEW.approved_at::DATE;
        
        RAISE NOTICE '🎯 Generando schedule para préstamo %: Monto=%, Plazo=%, Pago quincenal=%, Aprobado=%',
            NEW.id, NEW.amount, NEW.term_biweeks, NEW.biweekly_payment, v_approval_date;
        
        -- ✅ Calcular primera fecha usando el oráculo
        v_first_payment_date := calculate_first_payment_date(v_approval_date);
        
        RAISE NOTICE '📅 Primera fecha de pago: % (aprobado el %)', v_first_payment_date, v_approval_date;
        
        -- ✅ USAR generate_amortization_schedule() para obtener desglose completo
        FOR v_amortization_row IN
            SELECT 
                periodo, fecha_pago, pago_cliente, interes_cliente, 
                capital_cliente, saldo_pendiente, comision_socio, pago_socio
            FROM generate_amortization_schedule(
                NEW.amount,
                NEW.biweekly_payment,
                NEW.term_biweeks,
                NEW.commission_per_payment,
                v_first_payment_date
            )
        LOOP
            -- ✅ Buscar periodo administrativo que contiene esta fecha
            DECLARE
                v_period_id INTEGER;
            BEGIN
                SELECT id INTO v_period_id
                FROM cut_periods
                WHERE period_start_date <= v_amortization_row.fecha_pago
                  AND period_end_date >= v_amortization_row.fecha_pago
                ORDER BY period_start_date DESC
                LIMIT 1;
                
                IF v_period_id IS NULL THEN
                    RAISE WARNING 'No se encontró cut_period para fecha %. Insertando con period_id = NULL',
                        v_amortization_row.fecha_pago;
                END IF;
                
                -- ✅ Insertar pago con TODOS los campos
                INSERT INTO payments (
                    loan_id,
                    payment_number,
                    expected_amount,
                    amount_paid,
                    interest_amount,
                    principal_amount,
                    commission_amount,
                    associate_payment,
                    balance_remaining,
                    payment_date,
                    payment_due_date,
                    is_late,
                    status_id,
                    cut_period_id,
                    created_at,
                    updated_at
                ) VALUES (
                    NEW.id,
                    v_amortization_row.periodo,
                    v_amortization_row.pago_cliente,
                    0.00,  -- Aún no ha pagado
                    v_amortization_row.interes_cliente,
                    v_amortization_row.capital_cliente,
                    v_amortization_row.comision_socio,
                    v_amortization_row.pago_socio,
                    v_amortization_row.saldo_pendiente,
                    v_amortization_row.fecha_pago,  -- payment_date inicial = due_date
                    v_amortization_row.fecha_pago,  -- payment_due_date
                    false,
                    v_pending_status_id,
                    v_period_id,
                    CURRENT_TIMESTAMP,
                    CURRENT_TIMESTAMP
                );
                
                v_total_inserted := v_total_inserted + 1;
                v_sum_expected := v_sum_expected + v_amortization_row.pago_cliente;
            END;
        END LOOP;
        
        -- ✅ VALIDAR consistencia de sumas
        IF v_total_inserted != NEW.term_biweeks THEN
            RAISE EXCEPTION 'INCONSISTENCIA: Se insertaron % pagos pero se esperaban %. Préstamo %',
                v_total_inserted, NEW.term_biweeks, NEW.id;
        END IF;
        
        IF ABS(v_sum_expected - NEW.total_payment) > 0.10 THEN  -- Tolerancia de 10 centavos
            RAISE EXCEPTION 'INCONSISTENCIA: SUM(expected_amount)=% pero total_payment=%. Diferencia: %. Préstamo %',
                v_sum_expected, NEW.total_payment, (v_sum_expected - NEW.total_payment), NEW.id;
        END IF;
        
        RAISE NOTICE '✅ Schedule generado correctamente: % pagos, Total esperado=$%, Total préstamo=$%',
            v_total_inserted, v_sum_expected, NEW.total_payment;
    END IF;
    
    RETURN NEW;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'ERROR al generar payment schedule para préstamo %: % (%)',
            NEW.id, SQLERRM, SQLSTATE;
        RETURN NULL;
END;
$function$;
```

---

## ✅ CASOS DE PRUEBA

### Test 1: Préstamo con profile_code="standard"

**Entrada:**
```json
{
  "user_id": 5,
  "amount": 25000,
  "term_biweeks": 12,
  "profile_code": "standard"
}
```

**Validaciones esperadas:**

1. **Cálculo automático:**
   ```
   biweekly_payment = $2,768.33
   total_payment = $33,219.96
   total_interest = $8,219.96
   commission_per_payment = $138.42
   associate_payment = $2,629.91
   ```

2. **Campos guardados en `loans`:**
   - ✅ `loans.biweekly_payment = 2768.33`
   - ✅ `loans.total_payment = 33219.96`
   - ✅ `loans.profile_code = 'standard'`

3. **Estado inicial:**
   - ✅ `loans.status_id = PENDING`
   - ✅ NO se crean payments aún

### Test 2: Aprobación de Préstamo (10-ene-2025)

**Acción:**
```json
PATCH /loans/123
{
  "status": "APPROVED",
  "approved_at": "2025-01-10T10:30:00Z"
}
```

**Validaciones esperadas:**

1. **Primer pago calculado por oráculo:**
   - Aprobación: 10-ene (día 10, rango 8-22)
   - ✅ Primer pago: **31-ene-2025**

2. **12 pagos creados con alternancia correcta:**
   ```
   Pago 1:  31-ene-2025 (último día)
   Pago 2:  15-feb-2025 (día 15)
   Pago 3:  28-feb-2025 (último día, no bisiesto)
   Pago 4:  15-mar-2025 (día 15)
   Pago 5:  31-mar-2025 (último día)
   Pago 6:  15-abr-2025 (día 15)
   Pago 7:  30-abr-2025 (último día)
   Pago 8:  15-may-2025 (día 15)
   Pago 9:  31-may-2025 (último día)
   Pago 10: 15-jun-2025 (día 15)
   Pago 11: 30-jun-2025 (último día)
   Pago 12: 15-jul-2025 (día 15)
   ```

3. **Campos completos en cada payment:**
   ```sql
   SELECT 
       payment_number, payment_due_date, expected_amount,
       interest_amount, principal_amount, balance_remaining,
       cut_period_id
   FROM payments
   WHERE loan_id = 123
   ORDER BY payment_number;
   ```
   
   Resultado esperado:
   ```
   | # | payment_due_date | expected | interest | principal | balance    | cut_period_id |
   |---|------------------|----------|----------|-----------|------------|---------------|
   | 1 | 2025-01-31       | 2768.33  | 685.42   | 2082.91   | 22917.09   | 4             |
   | 2 | 2025-02-15       | 2768.33  | 685.42   | 2082.91   | 20834.18   | 5             |
   | 3 | 2025-02-28       | 2768.33  | 685.42   | 2082.91   | 18751.27   | 6             |
   | ..| ...              | ...      | ...      | ...       | ...        | ...           |
   | 12| 2025-07-15       | 2768.33  | 685.42   | 2082.91   | 0.00       | 15            |
   ```

4. **Validación de sumas:**
   ```sql
   SELECT 
       SUM(expected_amount) as suma_pagos,
       (SELECT total_payment FROM loans WHERE id=123) as total_prestamo,
       SUM(expected_amount) - (SELECT total_payment FROM loans WHERE id=123) as diferencia
   FROM payments
   WHERE loan_id = 123;
   ```
   
   Resultado esperado:
   ```
   suma_pagos: $33,219.96
   total_prestamo: $33,219.96
   diferencia: $0.00 ✅
   ```

### Test 3: Oráculo con Diferentes Fechas de Aprobación

**Test 3a: Aprobación 05-ene-2025 (día 5)**
- Rango: 1-7
- ✅ Primer pago: **15-ene-2025**
- ✅ Periodo admin: id=3 (08-ene a 22-ene)

**Test 3b: Aprobación 15-ene-2025 (día 15)**
- Rango: 8-22
- ✅ Primer pago: **31-ene-2025**
- ✅ Periodo admin: id=3 (08-ene a 22-ene)

**Test 3c: Aprobación 25-ene-2025 (día 25)**
- Rango: 23-31
- ✅ Primer pago: **15-feb-2025**
- ✅ Periodo admin: id=4 (23-ene a 07-feb)

**Test 3d: Aprobación 28-feb-2025 (último día febrero)**
- Rango: 23-31
- ✅ Primer pago: **15-mar-2025**
- ✅ Periodo admin: id=6 (23-feb a 07-mar)

### Test 4: Validación de cut_period_id

**Query:**
```sql
SELECT 
    p.payment_number,
    p.payment_due_date,
    p.cut_period_id,
    cp.period_start_date,
    cp.period_end_date,
    (p.payment_due_date BETWEEN cp.period_start_date AND cp.period_end_date) as fecha_en_periodo
FROM payments p
LEFT JOIN cut_periods cp ON p.cut_period_id = cp.id
WHERE p.loan_id = 123
ORDER BY p.payment_number;
```

**Validación:**
- ✅ Todos los registros deben tener `fecha_en_periodo = true`
- ✅ Ningún pago debe tener `cut_period_id = NULL` (a menos que falten periodos en BD)

### Test 5: Febrero en Año Bisiesto (2024)

**Préstamo aprobado: 10-feb-2024**
- ✅ Primer pago: 29-feb-2024 (día bisiesto)
- ✅ Segundo pago: 15-mar-2024
- ✅ `payment_due_date` alterna correctamente

---

## 📚 REFERENCIAS

### Archivos SQL Relevantes
```
/db/v2.0/modules/functions/calculate_loan_payment.sql
/db/v2.0/modules/functions/calculate_first_payment_date.sql
/db/v2.0/modules/functions/generate_amortization_schedule.sql
/db/v2.0/modules/triggers/generate_payment_schedule.sql
```

### Archivos Backend Relevantes
```
/backend/app/modules/loans/infrastructure/models/__init__.py
/backend/app/modules/loans/infrastructure/repositories/__init__.py
/backend/app/modules/loans/application/services/__init__.py
/backend/app/modules/rate_profiles/infrastructure/models.py
```

### Documentación Relacionada
```
/docs/business_logic/03_ciclo_vida_prestamos_completo.md
/docs/PLAN_SISTEMA_TASAS_HIBRIDO_FINAL.md
/docs/DOCUMENTACION_RATE_PROFILES_v2.0.3.md
```

---

## 🎓 GLOSARIO

- **Doble Calendario**: Sistema que mantiene dos calendarios simultáneos (cliente y admin)
- **Oráculo**: Función `calculate_first_payment_date()` que sincroniza ambos calendarios
- **Cliente**: Usuario que solicita el préstamo y debe realizar pagos
- **Administración**: Equipo interno que gestiona periodos de corte y reportes
- **Cut Period**: Periodo administrativo (8-22 o 23-7) para cierres contables
- **Payment Due Date**: Fecha de vencimiento del pago del cliente (15 o último día)
- **Quincena**: Periodo de aproximadamente 15 días (término usado por clientes)
- **Biweek**: Periodo de 2 semanas (término técnico del sistema)
- **Profile Code**: Código del perfil de tasas (ej: "standard", "premium")
- **Amortización**: Desglose de cada pago en capital, interés y comisión

---

**DOCUMENTO CREADO**: 2025-11-05  
**ÚLTIMA ACTUALIZACIÓN**: 2025-11-05  
**ESTADO**: ✅ COMPLETO - LISTO PARA IMPLEMENTACIÓN
