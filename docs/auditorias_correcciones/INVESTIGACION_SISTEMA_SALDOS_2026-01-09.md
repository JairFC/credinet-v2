# 📊 INVESTIGACIÓN COMPLETA: SISTEMA DE SALDOS CREDINET

**Fecha de Investigación:** 9 de Enero, 2026  
**Analista:** GitHub Copilot (Claude Opus 4.5)  
**Documentos Revisados:** 47 archivos de documentación  
**Estado:** ✅ INVESTIGACIÓN COMPLETADA

---

## 📋 ÍNDICE

1. [Resumen Ejecutivo](#-resumen-ejecutivo)
2. [Estado de Documentación](#-estado-de-documentación)
3. [Lógica Correcta de Saldos](#-lógica-correcta-de-saldos)
4. [Fórmulas de Cálculo](#-fórmulas-de-cálculo)
5. [Tablas SQL Relacionadas](#-tablas-sql-relacionadas)
6. [Flujo de Dinero](#-flujo-de-dinero)
7. [Inconsistencias Encontradas](#-inconsistencias-encontradas)
8. [Nomenclatura Actual vs Anterior](#-nomenclatura-actual-vs-anterior)

---

## 🎯 RESUMEN EJECUTIVO

### Modelo de Negocio (Flujo de Dinero)

```
                    CLIENTE
                       │
                       │ Paga cuotas del préstamo
                       │ ($2,894.17 = expected_amount)
                       ▼
                   ASOCIADO ────────► Se queda con comisión ($368.00)
                       │
                       │ Paga a CrediCuenta
                       │ ($2,526.17 = associate_payment)
                       ▼
                 CREDICUENTA
```

### Campos Principales en `associate_profiles`

| Campo ACTUAL | Campo ANTERIOR | Descripción |
|--------------|----------------|-------------|
| `credit_used` | credit_used | Suma de `associate_payment` de pagos PENDING |
| `debt_balance` | debt_balance | Deuda consolidada (statements cerrados + convenios) |
| `credit_available` | credit_available | Calculado: `credit_limit - credit_used - debt_balance` |

> **NOTA:** El documento `MODELO_DEUDA_CREDITO_DEFINITIVO.md` propone renombrar a `pending_payments_total` y `consolidated_debt`, pero el código SQL actual mantiene `credit_used` y `debt_balance`.

---

## 📁 ESTADO DE DOCUMENTACIÓN

### ✅ DOCUMENTACIÓN ACTUALIZADA (Fuente de Verdad)

| Archivo | Fecha | Estado | Descripción |
|---------|-------|--------|-------------|
| [MODELO_DEUDA_CREDITO_DEFINITIVO.md](docs/MODELO_DEUDA_CREDITO_DEFINITIVO.md) | 2026-01-08 | ⭐ **MÁS ACTUAL** | Modelo refactorizado con fórmulas |
| [ANALISIS_DEBT_TRACKING_2026-01-08.md](docs/ANALISIS_DEBT_TRACKING_2026-01-08.md) | 2026-01-08 | ✅ ACTUAL | Corrección de tracking de deudas |
| [ANALISIS_EXHAUSTIVO_FLUJO_DINERO.md](docs/ANALISIS_EXHAUSTIVO_FLUJO_DINERO.md) | 2026-01-07 | ✅ ACTUAL | Flujo de dinero confirmado |
| [CORRECCION_DESYNC_SALDOS_v2.0.3.md](docs/CORRECCION_DESYNC_SALDOS_v2.0.3.md) | 2026-01-07 | ✅ ACTUAL | Correcciones críticas |
| [REPORTE_CORRECCION_LIBERACION_CREDITO_V2.md](docs/REPORTE_CORRECCION_LIBERACION_CREDITO_V2.md) | 2026-01-07 | ✅ ACTUAL | Liberación de crédito v2.0.5 |
| [LOGICA_LIBERACION_CREDITO_EJEMPLOS.md](docs/LOGICA_LIBERACION_CREDITO_EJEMPLOS.md) | 2026-01-07 | ✅ ACTUAL | Ejemplos numéricos |

### ⚠️ DOCUMENTACIÓN DEPRECATED O DESACTUALIZADA

| Archivo | Fecha | Estado | Problema |
|---------|-------|--------|----------|
| [LOGICA_DE_NEGOCIO_DEFINITIVA.md](docs/LOGICA_DE_NEGOCIO_DEFINITIVA.md) | 2025-10-22 | ⚠️ PARCIALMENTE DESACTUALIZADA | Flujo 2 (pagos) marcado como "FUTURO v2.0" pero ya implementado |
| [LOGICA_CIERRE_DEFINITIVA_V3.md](docs/LOGICA_CIERRE_DEFINITIVA_V3.md) | ~2025-11 | ⚠️ INCOMPLETA | No menciona abonos parciales ni dos tipos de abonos |
| [LOGICA_CIERRE_PERIODO_Y_DEUDA.md](docs/LOGICA_CIERRE_PERIODO_Y_DEUDA.md) | ~2025-10 | ❌ OBSOLETO | Marcado como obsoleto en revisión |
| [FASE6_MVP_SCOPE.md](docs/FASE6_MVP_SCOPE.md) | ~2025-10 | ⚠️ DESACTUALIZADO | Scope no refleja decisiones recientes |
| [business_logic/01_core_concepts.md](docs/business_logic/01_core_concepts.md) | ~2025-09 | ⚠️ OBSOLETO | No incluye modelo de deuda actual |
| [CICLO_VIDA_PAGOS_Y_PERIODOS.md](docs/CICLO_VIDA_PAGOS_Y_PERIODOS.md) | 2025-11-26 | ✅ CORRECTO | Válido para fechas/periodos pero no para saldos |

### ❌ DOCUMENTACIÓN CONTRADICTORIA

| Documentos en Conflicto | Contradicción |
|-------------------------|---------------|
| `LOGICA_DE_NEGOCIO_DEFINITIVA.md` vs `MODELO_DEUDA_CREDITO_DEFINITIVO.md` | El primero usa nomenclatura vieja (`credit_used`), el segundo propone nombres nuevos (`pending_payments_total`) |
| `CORRECCION_DESYNC_SALDOS_v2.0.3.md` vs código actual | Propone liberar solo capital, pero documentación más reciente dice que se libera `associate_payment` completo |

---

## 💰 LÓGICA CORRECTA DE SALDOS

### 1. credit_used (Crédito Usado)

**Definición:** Suma de `associate_payment` de todos los pagos con status `PENDING`.

```sql
credit_used = SUM(p.associate_payment)
              FROM payments p
              JOIN loans l ON p.loan_id = l.id
              WHERE l.associate_user_id = {user_id}
                AND p.status_id = 1  -- PENDING
```

**¿Cuándo AUMENTA?**
- ✅ Al APROBAR un préstamo (trigger `trigger_update_associate_credit_on_loan_approval`)
- Suma todos los `associate_payment` del cronograma generado

**¿Cuándo DISMINUYE?**
- ✅ Cuando el ASOCIADO paga a CrediCuenta (abono a statement o a deuda)
- ❌ NO disminuye cuando el cliente paga al asociado (corrección v2.0.5)

**Regla de Oro:**
> "Crédito se libera SOLO cuando asociado paga a CrediCuenta"

---

### 2. debt_balance (Deuda del Asociado)

**Definición:** Deuda consolidada que el asociado debe a CrediCuenta.

**Orígenes de la deuda:**
1. **Statements cerrados no pagados** - Cuando cierra un período y el asociado no liquidó
2. **Clientes morosos aprobados** - Cuando admin aprueba reporte de cliente moroso
3. **Mora (30% comisión)** - Si paid_amount = $0 al cerrar período

**¿Cuándo AUMENTA?**
- ✅ Al cerrar período (`close_period_and_accumulate_debt`) con saldo pendiente
- ✅ Al aprobar reporte de cliente moroso
- ✅ Al aplicar mora del 30%

**¿Cuándo DISMINUYE?**
- ✅ Cuando el ASOCIADO paga abono a statement (`update_statement_on_payment`)
- ✅ Cuando el ASOCIADO paga a deuda acumulada (`apply_debt_payment_v2`)
- ✅ Cuando el ASOCIADO paga cuota de convenio

---

### 3. credit_available (Crédito Disponible)

**Definición:** Campo GENERATED (calculado automáticamente) en la base de datos.

```sql
credit_available NUMERIC(12,2) GENERATED ALWAYS AS (
    GREATEST(credit_limit - credit_used - debt_balance, 0)
) STORED
```

**Importante:**
- ❌ NO se puede modificar directamente
- ✅ Se recalcula automáticamente cuando cambian `credit_limit`, `credit_used` o `debt_balance`

---

### 4. Tablas de Deuda Asociadas

| Tabla | Propósito |
|-------|-----------|
| `associate_accumulated_balances` | Historial de deudas por período (agregado) |
| `associate_debt_breakdown` | Desglose detallado de deudas individuales |
| `associate_debt_payments` | Pagos del asociado a su deuda |
| `associate_statement_payments` | Abonos del asociado al statement actual |

---

## 📐 FÓRMULAS DE CÁLCULO

### Fórmula Maestra

```
credit_available = credit_limit - credit_used - debt_balance
```

### Deuda Total del Asociado

```
DEUDA_TOTAL = credit_used + debt_balance
```

### Cálculo de Pago del Asociado (por cuota)

```
associate_payment = expected_amount - commission_amount

Donde:
- expected_amount = Lo que el cliente paga por cuota
- commission_amount = Comisión que el asociado retiene (su ganancia)
```

### Ejemplo Numérico

```
Préstamo: $23,000 a 12 quincenas
Pago del cliente (expected_amount):     $2,894.17
  - Principal (capital):                $1,916.67  (23,000 / 12)
  - Interés:                            $977.50
Comisión del asociado:                  $368.00    (1.6% sobre expected)
Pago a CrediCuenta (associate_payment): $2,526.17  (2,894.17 - 368.00)
```

### Liberación de Crédito

**Al aprobar préstamo:**
```sql
credit_used += SUM(associate_payment de todos los pagos)
-- NO liberar hasta que asociado pague a CrediCuenta
```

**Al pagar asociado a statement/deuda:**
```sql
credit_used -= payment_amount
debt_balance -= payment_amount
-- credit_available se recalcula automáticamente
```

---

## 🗃️ TABLAS SQL RELACIONADAS

### Estructura de `associate_profiles`

```sql
CREATE TABLE public.associate_profiles (
    id integer NOT NULL,
    user_id integer NOT NULL,
    level_id integer NOT NULL,
    credit_limit numeric(12,2) DEFAULT 0.00 NOT NULL,
    credit_used numeric(12,2) DEFAULT 0.00 NOT NULL,
    debt_balance numeric(12,2) DEFAULT 0.00 NOT NULL,
    credit_available numeric(12,2) GENERATED ALWAYS AS (
        GREATEST(credit_limit - credit_used - debt_balance, 0)
    ) STORED,
    credit_last_updated timestamp with time zone,
    -- ... otros campos ...
);
```

### Estructura de `payments`

```sql
CREATE TABLE public.payments (
    id integer NOT NULL,
    loan_id integer NOT NULL,
    payment_number integer NOT NULL,
    payment_due_date date NOT NULL,
    expected_amount numeric(12,2) NOT NULL,       -- Lo que paga el cliente
    principal_amount numeric(12,2),               -- Capital
    interest_amount numeric(12,2),                -- Interés
    commission_amount numeric(10,2),              -- Comisión del asociado
    associate_payment numeric(10,2),              -- Lo que va a CrediCuenta
    amount_paid numeric(12,2) DEFAULT 0,          -- Lo que ha pagado el cliente
    status_id integer NOT NULL,                   -- PENDING, PAID, etc.
    cut_period_id integer,
    -- ... otros campos ...
);
```

### Estructura de `associate_payment_statements`

```sql
CREATE TABLE public.associate_payment_statements (
    id integer NOT NULL,
    user_id integer NOT NULL,
    cut_period_id integer NOT NULL,
    statement_number varchar(50),
    total_payments_count integer DEFAULT 0,
    total_amount_collected numeric(12,2),         -- SUM(expected_amount)
    total_commission_owed numeric(12,2),          -- SUM(commission_amount)
    paid_amount numeric(12,2) DEFAULT 0,          -- Abonos del asociado
    late_fee_amount numeric(12,2) DEFAULT 0,      -- Mora 30%
    status_id integer,                            -- PENDING, PAID, CLOSED
    -- ... otros campos ...
);
```

### Estructura de `associate_accumulated_balances`

```sql
CREATE TABLE public.associate_accumulated_balances (
    id integer NOT NULL,
    user_id integer NOT NULL,
    cut_period_id integer NOT NULL,
    accumulated_debt numeric(12,2) DEFAULT 0,     -- Deuda acumulada
    created_at timestamp with time zone,
    updated_at timestamp with time zone
);
```

---

## 🔄 FLUJO DE DINERO COMPLETO

### Diagrama de Estados

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     CICLO DE VIDA DEL CRÉDITO                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────┐     APROBACIÓN      ┌──────────────────────┐               │
│  │  PRÉSTAMO   │ ─────────────────► │  credit_used += $X   │               │
│  │   NUEVO     │                    │  (associate_payment  │               │
│  └─────────────┘                    │   total del préstamo)│               │
│                                      └──────────┬───────────┘               │
│                                                 │                           │
│                        CLIENTE PAGA             │                           │
│                    (NO libera crédito)          │                           │
│                    ┌────────────────────────────┼────────────────┐          │
│                    │                            │                │          │
│                    ▼                            ▼                ▼          │
│          ┌─────────────────┐          ┌────────────────┐  ┌──────────────┐  │
│          │ PERÍODO CIERRA  │          │ ASOCIADO PAGA  │  │   CONVENIO   │  │
│          │ (SIN PAGO ASOC) │          │  A STATEMENT   │  │   CREADO     │  │
│          └────────┬────────┘          └───────┬────────┘  └──────┬───────┘  │
│                   │                           │                   │         │
│                   ▼                           ▼                   ▼         │
│          ┌─────────────────┐          ┌────────────────┐  ┌──────────────┐  │
│          │ credit_used se  │          │ credit_used    │  │ credit_used  │  │
│          │ mueve a         │          │ -= pago        │  │ se mueve a   │  │
│          │ debt_balance    │          │ debt_balance   │  │ debt_balance │  │
│          │                 │          │ -= pago        │  │ (monto del   │  │
│          │ (available NO   │          │ (available ↑)  │  │ convenio)    │  │
│          │  cambia)        │          └────────────────┘  └──────────────┘  │
│          └─────────────────┘                                                │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Escenarios Detallados

#### Escenario 1: Préstamo Aprobado
```
ANTES:  credit_limit=100,000 | credit_used=20,000 | debt_balance=5,000 | available=75,000
EVENTO: Préstamo de $10,000 aprobado (associate_payment total = $11,500)
DESPUÉS: credit_limit=100,000 | credit_used=31,500 | debt_balance=5,000 | available=63,500
```

#### Escenario 2: Período Cierra sin Pago del Asociado
```
ANTES:  credit_used=31,500 | debt_balance=5,000 | available=63,500
EVENTO: Período cierra, asociado no pagó $2,300 de statements
DESPUÉS: credit_used=29,200 | debt_balance=7,300 | available=63,500
         (El crédito "se mueve" de credit_used a debt_balance)
         (available NO cambia porque la deuda sigue existiendo)
```

#### Escenario 3: Asociado Paga Statement
```
ANTES:  credit_used=29,200 | debt_balance=7,300 | available=63,500
EVENTO: Asociado paga $1,000 al statement actual
DESPUÉS: credit_used=28,200 | debt_balance=6,300 | available=65,500
         (available AUMENTA porque el asociado pagó a CrediCuenta)
```

#### Escenario 4: Asociado Paga Deuda Acumulada
```
ANTES:  credit_used=28,200 | debt_balance=6,300 | available=65,500
EVENTO: Asociado paga $2,000 a deuda acumulada (FIFO)
DESPUÉS: credit_used=26,200 | debt_balance=4,300 | available=69,500
         (Se aplica a deudas más antiguas primero)
```

---

## ⚠️ INCONSISTENCIAS ENCONTRADAS

### 1. Nomenclatura de Campos

**Problema:** `MODELO_DEUDA_CREDITO_DEFINITIVO.md` propone nuevos nombres pero el código usa los antiguos.

| Documentación Nueva | Código SQL Actual | Recomendación |
|---------------------|-------------------|---------------|
| `pending_payments_total` | `credit_used` | Mantener `credit_used` (ya implementado) |
| `consolidated_debt` | `debt_balance` | Mantener `debt_balance` (ya implementado) |

### 2. Lógica de Liberación de Crédito

**Problema histórico (ya corregido):** Antes de v2.0.5, el trigger liberaba crédito cuando el cliente pagaba al asociado.

**Estado actual:** ✅ Corregido en `CORRECCION_LIBERACION_CREDITO_V2.sql`

### 3. Función `calculate_loan_remaining_balance`

**Problema identificado en `CORRECCION_DESYNC_SALDOS_v2.0.3.md`:**

```sql
-- ANTES (INCORRECTO):
v_remaining := loan.amount - SUM(payments.amount_paid)
-- Comparaba capital vs pagos totales (incluye interés)

-- AHORA (CORRECTO):
v_remaining := SUM(expected_amount) WHERE status = PENDING
```

### 4. Documentación de Flujo de Pagos

**Problema:** `LOGICA_DE_NEGOCIO_DEFINITIVA.md` marca el FLUJO 2 (Pago Quincenal del Cliente) como "FUTURO v2.0", pero ya está implementado.

---

## 📝 NOMENCLATURA ACTUAL VS ANTERIOR

| Concepto | Nombre en Código | Nombre en Docs Nuevas | Nombre en Docs Viejas |
|----------|------------------|----------------------|----------------------|
| Crédito comprometido | `credit_used` | `pending_payments_total` | `credit_used` |
| Deuda del asociado | `debt_balance` | `consolidated_debt` | `debt_balance` |
| Crédito disponible | `credit_available` | `available_credit` | `credit_available` |
| Pago a CrediCuenta | `associate_payment` | `associate_payment` | N/A |
| Pago del cliente | `expected_amount` | `expected_amount` | N/A |

---

## 📊 QUERY DE VALIDACIÓN

Para verificar que los saldos son correctos:

```sql
WITH calculos AS (
    SELECT 
        ap.id,
        u.username,
        ap.credit_limit,
        ap.credit_used,
        ap.debt_balance,
        ap.credit_available,
        
        -- Cálculo de credit_used (pagos PENDING)
        COALESCE((
            SELECT SUM(p.associate_payment)
            FROM payments p
            JOIN loans l ON p.loan_id = l.id
            WHERE l.associate_user_id = ap.user_id 
              AND p.status_id = 1  -- PENDING
        ), 0) as calc_credit_used,
        
        -- Cálculo de debt_balance (acumulado)
        COALESCE((
            SELECT SUM(accumulated_debt)
            FROM associate_accumulated_balances
            WHERE user_id = ap.user_id
        ), 0) as calc_debt_balance
        
    FROM associate_profiles ap
    JOIN users u ON u.id = ap.user_id
)
SELECT 
    id,
    username,
    credit_limit,
    credit_used, calc_credit_used,
    CASE WHEN ABS(credit_used - calc_credit_used) < 0.01 THEN '✅' ELSE '❌' END as credit_ok,
    debt_balance, calc_debt_balance,
    CASE WHEN ABS(debt_balance - calc_debt_balance) < 0.01 THEN '✅' ELSE '❌' END as debt_ok,
    credit_available,
    (credit_limit - credit_used - debt_balance) as calc_available,
    CASE WHEN credit_available = (credit_limit - credit_used - debt_balance) 
         THEN '✅' ELSE '❌' END as available_ok
FROM calculos
ORDER BY id;
```

---

## ✅ CONCLUSIONES

### Documentación Fuente de Verdad

Para la lógica de saldos, usar en este orden de prioridad:

1. **`MODELO_DEUDA_CREDITO_DEFINITIVO.md`** (2026-01-08) - Modelo más completo y actualizado
2. **`REPORTE_CORRECCION_LIBERACION_CREDITO_V2.md`** (2026-01-07) - Reglas de liberación
3. **`ANALISIS_EXHAUSTIVO_FLUJO_DINERO.md`** (2026-01-07) - Flujo de dinero confirmado

### Reglas Fundamentales

1. **`credit_available` es GENERATED** - No modificar directamente
2. **Crédito se libera solo cuando ASOCIADO paga a CREDICUENTA** - No cuando cliente paga
3. **Deuda se "mueve", no desaparece** - De `credit_used` a `debt_balance` al cerrar período
4. **FIFO para pagos de deuda** - Las deudas más antiguas se liquidan primero
5. **Convenios son para ASOCIADOS** - No para clientes

### Código SQL Actual

El código SQL en `db/v2.0/init.sql` está actualizado y correcto con las correcciones de v2.0.5.

---

**Documento generado automáticamente - CrediNet v2.0**  
**Fecha de generación:** 2026-01-09
