# 📊 MODELO DE DEUDA Y CRÉDITO - DOCUMENTACIÓN DEFINITIVA

**Sistema:** CrediNet v2.0  
**Última actualización:** 2026-01-08  
**Estado:** ✅ REFACTORIZADO Y VALIDADO

---

## 🔴 RELACIONES DE DEUDA - IMPORTANTE

```
┌────────────────────────────────────────────────────────────────────────────────┐
│                     RELACIONES DE DEUDA EN CREDICUENTA                         │
├────────────────────────────────────────────────────────────────────────────────┤
│                                                                                │
│   ┌───────────┐         ┌───────────────┐         ┌───────────────┐           │
│   │  CLIENTE  │  ───►   │   ASOCIADO    │  ───►   │  CREDICUENTA  │           │
│   └───────────┘         └───────────────┘         └───────────────┘           │
│        │                       │                         │                     │
│        │                       │                         │                     │
│   Paga cuotas            Intermedia y          Recibe el associate_payment    │
│   del préstamo           cobra comisión        de cada cuota                  │
│                                                                                │
│   ⚠️ SEGUIMIENTO         ⭐ RELACIÓN            ⭐ RELACIÓN                     │
│      MÍNIMO               PRINCIPAL              PRINCIPAL                     │
│   (solo para que                                                               │
│    el asociado sepa)                                                           │
│                                                                                │
├────────────────────────────────────────────────────────────────────────────────┤
│   A CREDICUENTA SOLO LE INTERESA:                                              │
│   • ¿Cuánto debe el ASOCIADO? (pending_payments_total + consolidated_debt)     │
│   • ¿Cuánto crédito tiene disponible? (available_credit)                       │
│                                                                                │
│   A CREDICUENTA NO LE INTERESA MUCHO:                                          │
│   • ¿Cuánto debe el cliente al asociado? (solo seguimiento informativo)        │
└────────────────────────────────────────────────────────────────────────────────┘
```

### ¿Quién Paga a Quién?

| Pago | Quién Paga | A Quién | Efecto en associate_profiles |
|------|------------|---------|------------------------------|
| Cuota de préstamo | **Cliente** | Asociado (y CrediCuenta indirectamente) | pending_payments_total -= associate_payment |
| Cuota de convenio | **ASOCIADO** | CrediCuenta | consolidated_debt -= pago |
| Pago directo de deuda | **ASOCIADO** | CrediCuenta | consolidated_debt -= pago |

> **🔑 CLAVE:** Los **CONVENIOS** son para que el **ASOCIADO** reestructure su deuda con CrediCuenta.
> NO son para clientes. Los clientes solo pagan cuotas de préstamos.

---

## 📋 ÍNDICE

1. [Relaciones de Deuda](#-relaciones-de-deuda---importante)
2. [Resumen Ejecutivo](#-resumen-ejecutivo)
3. [Modelo de Datos](#-modelo-de-datos)
4. [Fórmulas Fundamentales](#-fórmulas-fundamentales)
5. [Ciclo de Vida del Crédito](#-ciclo-de-vida-del-crédito)
6. [Triggers y Automatización](#-triggers-y-automatización)
7. [Sistemas de Crédito](#-sistemas-de-crédito)
8. [Validaciones](#-validaciones)
9. [Glosario de Términos](#-glosario-de-términos)

---

## 🎯 RESUMEN EJECUTIVO

El sistema CrediNet maneja el crédito de los asociados mediante **tres columnas principales** que representan diferentes estados de la deuda:

| Columna | Antes | Descripción |
|---------|-------|-------------|
| `pending_payments_total` | credit_used | Pagos futuros que el asociado debe cobrar/entregar |
| `consolidated_debt` | debt_balance | Deuda firme (statements cerrados + convenios) |
| `available_credit` | credit_available | Crédito que puede usar para nuevos préstamos |

### Fórmula Maestra JUST WORKING ;3 XD

```
available_credit = credit_limit - pending_payments_total - consolidated_debt
```

---

## 💾 MODELO DE DATOS

### Tabla: `associate_profiles`

```sql
CREATE TABLE associate_profiles (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    credit_limit NUMERIC(12,2) NOT NULL,
    
    -- Pagos pendientes por cobrar (suma de associate_payment WHERE status=PENDING)
    pending_payments_total NUMERIC(12,2) NOT NULL DEFAULT 0,
    
    -- Deuda consolidada (statements cerrados + convenios - pagos realizados)
    consolidated_debt NUMERIC(12,2) NOT NULL DEFAULT 0,
    
    -- Crédito disponible (GENERADO AUTOMÁTICAMENTE)
    available_credit NUMERIC(12,2) GENERATED ALWAYS AS 
        (credit_limit - pending_payments_total - consolidated_debt) STORED,
    
    credit_last_updated TIMESTAMPTZ,
    ...
);
```

### Comentarios de Columnas

```sql
COMMENT ON COLUMN associate_profiles.pending_payments_total IS 
    'Suma de associate_payment de pagos PENDING. Representa cuánto el asociado 
     aún debe cobrar a sus clientes y entregar a CrediCuenta.';

COMMENT ON COLUMN associate_profiles.consolidated_debt IS 
    'Deuda consolidada: statements_cerrados + convenios_activos - pagos_realizados. 
     Deuda firme que el asociado debe a CrediCuenta.';

COMMENT ON COLUMN associate_profiles.available_credit IS 
    'Crédito disponible = credit_limit - pending_payments_total - consolidated_debt. 
     Lo que el asociado puede usar para nuevos préstamos.';
```

---

## 🔢 FÓRMULAS FUNDAMENTALES

### 1. pending_payments_total (Antes: credit_used)

```sql
pending_payments_total = SUM(p.associate_payment)
                         FROM payments p
                         JOIN loans l ON p.loan_id = l.id
                         WHERE l.associate_user_id = {user_id}
                           AND p.status_id = 1  -- PENDING
```

**¿Qué representa?**
- Total de pagos futuros que el asociado debe **cobrar a sus clientes**
- Lo que el asociado debe **entregar a CrediCuenta** cuando sus clientes paguen

### 2. consolidated_debt (Antes: debt_balance)

```sql
consolidated_debt = (
    -- Statements cerrados no pagados
    COALESCE(SUM(s.total_to_credicuenta - s.paid_amount) 
             WHERE status = 'CLOSED', 0)
    
    -- + Convenios activos
    + COALESCE(SUM(a.total_debt_amount) WHERE status = 'ACTIVE', 0)
    
    -- - Pagos a convenios
    - COALESCE(SUM(agp.payment_amount) WHERE status = 'PAID', 0)
    
    -- - Pagos directos a deuda
    - COALESCE(SUM(adp.payment_amount), 0)
)
```

**¿Qué representa?**
- Deuda **ya consolidada** que el asociado debe a CrediCuenta
- No depende de que los clientes paguen
- Puede pagarse en cualquier momento

### 3. available_credit (Columna Computada)

```sql
available_credit = credit_limit - pending_payments_total - consolidated_debt
```

**¿Qué representa?**
- Crédito que el asociado puede usar para **nuevos préstamos**
- Se actualiza automáticamente (columna GENERATED)

### 4. DEUDA TOTAL del Asociado

```sql
DEUDA_TOTAL = pending_payments_total + consolidated_debt
```

---

## 🔄 CICLO DE VIDA DEL CRÉDITO

### Diagrama de Flujo

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     CICLO DE VIDA DEL CRÉDITO                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────┐     APROBACIÓN      ┌──────────────────────┐               │
│  │  PRÉSTAMO   │ ─────────────────> │  pending_payments_   │               │
│  │   NUEVO     │    +$X             │  total += $X         │               │
│  └─────────────┘                    │  available_credit    │               │
│                                      │  -= $X (automático)  │               │
│                                      └──────────┬───────────┘               │
│                                                 │                           │
│                        CLIENTE PAGA             │                           │
│                    (al asociado)                │                           │
│                    ┌────────────────────────────┼────────────────┐          │
│                    │                            │                │          │
│                    ▼                            ▼                ▼          │
│          ┌─────────────────┐          ┌────────────────┐  ┌──────────────┐  │
│          │  PAGO COMPLETO  │          │  PERÍODO CIERRA│  │   CONVENIO   │  │
│          │  (asociado      │          │   SIN PAGO     │  │   CREADO     │  │
│          │   reporta)      │          │  REPORTADO     │  │  (ASOCIADO)  │  │
│          └────────┬────────┘          └───────┬────────┘  └──────┬───────┘  │
│                   │                           │                   │         │
│                   ▼                           ▼                   ▼         │
│          ┌─────────────────┐          ┌────────────────┐  ┌──────────────┐  │
│          │ pending_payments│          │ pending_payments│  │pending_payments│
│          │ _total -= $X    │          │ _total -= $X   │  │_total -= $X  │  │
│          │ (Crédito se     │          │ consolidated   │  │consolidated  │  │
│          │  libera)        │          │ _debt += $X    │  │_debt += $X   │  │
│          └─────────────────┘          │ (available_    │  │(available_   │  │
│                                       │ credit igual)  │  │credit igual) │  │
│                                       └───────┬────────┘  └──────┬───────┘  │
│                                               │                   │         │
│                          ASOCIADO PAGA        │                   │         │
│                          A CREDICUENTA        │                   │         │
│                       ◄───────────────────────┴───────────────────┘         │
│                                               │                             │
│                                               ▼                             │
│                                      ┌────────────────┐                     │
│                                      │ consolidated   │                     │
│                                      │ _debt -= $Y    │                     │
│                                      │ available_     │                     │
│                                      │ credit += $Y   │                     │
│                                      │ (automático)   │                     │
│                                      └────────────────┘                     │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Escenarios Detallados

#### Escenario 1: Préstamo Aprobado
```
ANTES:  credit_limit=100,000 | pending_payments=20,000 | consolidated=5,000 | available=75,000
EVENTO: Préstamo de $10,000 aprobado (total_associate_payment = $11,500)
DESPUÉS: credit_limit=100,000 | pending_payments=31,500 | consolidated=5,000 | available=63,500
```

#### Escenario 2: Cliente Paga Cuota (y Asociado Reporta)
```
ANTES:  pending_payments=31,500 | consolidated=5,000 | available=63,500
EVENTO: Cliente paga cuota al asociado, asociado reporta ($1,150 associate_payment)
DESPUÉS: pending_payments=30,350 | consolidated=5,000 | available=64,650
         (Crédito se libera porque asociado cumplió con entregar a CrediCuenta)
```

#### Escenario 3: Período Cierra sin Reporte
```
ANTES:  pending_payments=30,350 | consolidated=5,000 | available=64,650
EVENTO: Período cierra, asociado no reportó $2,300 (2 cuotas). 
        El asociado ASUME la deuda (haya cobrado o no al cliente)
DESPUÉS: pending_payments=28,050 | consolidated=7,300 | available=64,650
         (available_credit NO cambia, la deuda solo se "mueve" de pendiente a consolidada)
```

#### Escenario 4: Convenio Creado (para el ASOCIADO)
```
ANTES:  pending_payments=28,050 | consolidated=7,300 | available=64,650
EVENTO: Convenio de $5,000 creado de préstamos activos del ASOCIADO
        (Asociado reestructura su deuda con CrediCuenta en cuotas mensuales)
DESPUÉS: pending_payments=23,050 | consolidated=12,300 | available=64,650
         (available_credit NO cambia, la deuda solo se mueve)
```

#### Escenario 5: Asociado Paga Cuota de Convenio
```
ANTES:  pending_payments=23,050 | consolidated=12,300 | available=64,650
EVENTO: ASOCIADO paga $1,000 (cuota mensual del convenio a CrediCuenta)
DESPUÉS: pending_payments=23,050 | consolidated=11,300 | available=65,650
         (available_credit AUMENTA - el asociado pagó su deuda)
```

#### Escenario 6: Asociado Paga Deuda Directamente
```
ANTES:  pending_payments=23,050 | consolidated=11,300 | available=65,650
EVENTO: Asociado paga $2,000 directamente a su deuda consolidada (sin convenio)
DESPUÉS: pending_payments=23,050 | consolidated=9,300 | available=67,650
         (available_credit AUMENTA)
```

---

## ⚙️ TRIGGERS Y AUTOMATIZACIÓN

### Lista de Triggers

| Trigger | Tabla | Evento | Acción |
|---------|-------|--------|--------|
| `trigger_update_credit_on_loan_approval` | loans | UPDATE | +pending_payments_total al aprobar |
| `trigger_update_credit_on_payment` | payments | UPDATE | -pending_payments_total al registrar pago |
| `trigger_update_credit_on_loan_cancel` | loans | UPDATE | -pending_payments_total al cancelar |
| `trigger_update_credit_on_loan_delete` | loans | DELETE | -pending_payments_total al borrar |
| `trigger_update_statement_on_payment` | associate_statement_payments | INSERT | -consolidated_debt al pagar statement |
| `trigger_update_credit_on_debt_payment` | associate_debt_breakdown | UPDATE | -consolidated_debt al liquidar deuda |

### Detalle de Triggers Principales

#### 1. Aprobación de Préstamo

```sql
CREATE OR REPLACE FUNCTION trigger_update_associate_credit_on_loan_approval()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status_id = APPROVED AND OLD.status_id != APPROVED THEN
        -- Calcular total que el asociado pagará a CrediCuenta
        SELECT SUM(associate_payment) INTO v_total
        FROM payments WHERE loan_id = NEW.id;
        
        -- Incrementar pending_payments_total
        UPDATE associate_profiles
        SET pending_payments_total = pending_payments_total + v_total
        WHERE user_id = NEW.associate_user_id;
    END IF;
    RETURN NEW;
END;
$$;
```

#### 2. Pago de Cliente

```sql
CREATE OR REPLACE FUNCTION trigger_update_associate_credit_on_payment()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.amount_paid != OLD.amount_paid THEN
        -- Calcular liberación proporcional
        IF NEW.amount_paid >= NEW.expected_amount THEN
            v_liberation := NEW.associate_payment;  -- Pago completo
        ELSE
            v_liberation := NEW.associate_payment * (amount_diff / expected_amount);
        END IF;
        
        -- Reducir pending_payments_total
        UPDATE associate_profiles
        SET pending_payments_total = GREATEST(0, pending_payments_total - v_liberation)
        WHERE user_id = {associate_user_id};
    END IF;
    RETURN NEW;
END;
$$;
```

#### 3. Pago a Statement (Deuda Consolidada)

```sql
CREATE OR REPLACE FUNCTION update_statement_on_payment()
RETURNS TRIGGER AS $$
BEGIN
    -- Solo reducir consolidated_debt
    -- pending_payments_total NO se modifica aquí
    UPDATE associate_profiles
    SET consolidated_debt = GREATEST(0, consolidated_debt - NEW.payment_amount)
    WHERE id = v_associate_profile_id;
    
    RETURN NEW;
END;
$$;
```

---

## 🔄 SISTEMAS DE CRÉDITO

### Sistema de Renovación de Préstamos

**Ubicación:** `/backend/app/modules/loans/routes.py` líneas 1193-1456

**Flujo:**
1. Se valida crédito disponible para el nuevo préstamo
2. Se liquida el préstamo original (pagos PENDING → PAID_BY_RENEWAL)
3. pending_payments_total -= monto_original
4. Se crea nuevo préstamo con nuevo cronograma
5. pending_payments_total += monto_nuevo (via trigger de aprobación)
6. Se desembolsa la diferencia al cliente

```
RENOVACIÓN: Préstamo $10,000 → $15,000

PASO 1: Liquidar original
        pending_payments -= $11,500 (associate_payment del original)

PASO 2: Aprobar nuevo
        pending_payments += $17,250 (associate_payment del nuevo)

RESULTADO NETO:
        pending_payments += $5,750
        available_credit -= $5,750
```

### Sistema de Convenios

**Ubicación:** `/backend/app/modules/agreements/routes.py`

**⚠️ IMPORTANTE:** Los convenios son para que el **ASOCIADO** pague a **CREDICUENTA**, NO para clientes.

**Flujo:**
1. Se seleccionan préstamos en mora o activos del asociado
2. Se calculan pagos PENDING de esos préstamos
3. pending_payments_total -= total_seleccionado
4. consolidated_debt += total_seleccionado
5. Se crea convenio con nuevo plan de pagos para el **ASOCIADO**
6. **ASOCIADO paga cuotas del convenio** → consolidated_debt disminuye → available_credit aumenta

```
CONVENIO: $5,000 de préstamos activos

ANTES:   pending_payments=30,000 | consolidated=10,000 | available=60,000
         
CAMBIO:  pending_payments -= $5,000  (ya no espera cobrar eso de clientes)
         consolidated_debt += $5,000  (asociado ahora debe a CrediCuenta)
         
DESPUÉS: pending_payments=25,000 | consolidated=15,000 | available=60,000
         (available_credit NO CAMBIA, la deuda solo se "mueve")

CUANDO ASOCIADO PAGA:
ANTES:   pending_payments=25,000 | consolidated=15,000 | available=60,000
PAGO:    $1,000 (cuota mensual del convenio)
DESPUÉS: pending_payments=25,000 | consolidated=14,000 | available=61,000
         (available_credit AUMENTA cuando asociado paga)
```

---

## ✅ VALIDACIONES

### Verificación de Saldos

```sql
-- Query para validar que todos los saldos están correctos
WITH calculos AS (
    SELECT 
        ap.id,
        ap.credit_limit,
        ap.pending_payments_total,
        ap.consolidated_debt,
        ap.available_credit,
        
        -- Cálculo de pending_payments_total
        COALESCE((
            SELECT SUM(p.associate_payment)
            FROM payments p
            JOIN loans l ON p.loan_id = l.id
            WHERE l.associate_user_id = ap.user_id AND p.status_id = 1
        ), 0) as calc_pending,
        
        -- Cálculo de consolidated_debt
        (
            COALESCE((SELECT SUM(total_to_credicuenta - paid_amount)
                      FROM associate_payment_statements 
                      WHERE user_id = ap.user_id AND status_id = 3), 0) +
            COALESCE((SELECT SUM(total_debt_amount) 
                      FROM agreements WHERE associate_profile_id = ap.id 
                      AND status = 'ACTIVE'), 0) -
            COALESCE((SELECT SUM(payment_amount) 
                      FROM agreement_payments WHERE status = 'PAID'), 0) -
            COALESCE((SELECT SUM(payment_amount) 
                      FROM associate_debt_payments 
                      WHERE associate_profile_id = ap.id), 0)
        ) as calc_consolidated
        
    FROM associate_profiles ap
)
SELECT 
    id,
    pending_payments_total, calc_pending,
    CASE WHEN pending_payments_total = calc_pending THEN '✅' ELSE '❌' END,
    consolidated_debt, calc_consolidated,
    CASE WHEN ABS(consolidated_debt - calc_consolidated) < 0.01 THEN '✅' ELSE '❌' END,
    available_credit,
    (credit_limit - pending_payments_total - consolidated_debt) as calc_available,
    CASE WHEN available_credit = (credit_limit - pending_payments_total - consolidated_debt) 
         THEN '✅' ELSE '❌' END
FROM calculos;
```

### Función de Verificación de Crédito

```sql
CREATE FUNCTION check_associate_credit_available(
    p_associate_profile_id INTEGER,
    p_requested_amount DECIMAL(12,2)
) RETURNS BOOLEAN AS $$
BEGIN
    SELECT available_credit INTO v_available
    FROM associate_profiles
    WHERE id = p_associate_profile_id;
    
    RETURN v_available >= p_requested_amount;
END;
$$;
```

---

## 📚 GLOSARIO DE TÉRMINOS

| Término | Definición |
|---------|------------|
| **pending_payments_total** | Total de `associate_payment` de pagos con status PENDING. Representa el compromiso futuro del asociado con CrediCuenta - lo que debe cobrar y entregar. |
| **consolidated_debt** | Deuda consolidada y firme del **ASOCIADO** con CrediCuenta. Incluye statements cerrados no pagados y convenios activos, menos pagos realizados por el asociado. |
| **available_credit** | Crédito que el asociado puede usar para nuevos préstamos. Calculado automáticamente. |
| **associate_payment** | Monto que el asociado debe entregar a CrediCuenta por un pago de cliente. Es `expected_amount - commission_amount`. |
| **expected_amount** | Monto total que el cliente debe pagar en una cuota (capital + interés). |
| **commission_amount** | Comisión que el asociado retiene por gestionar el préstamo. |
| **Convenio** | Acuerdo para que el **ASOCIADO** pague su deuda consolidada a CrediCuenta en cuotas mensuales. NO es para clientes. |
| **agreement_payment** | Cuota del convenio que el **ASOCIADO** paga a CrediCuenta. |
| **PAID_BY_ASSOCIATE** | Estado de pago que indica que el asociado asumió la deuda del cliente (periodo cerrado sin reporte). |
| **PAID_BY_RENEWAL** | Estado de pago que indica que el pago fue liquidado por una renovación del préstamo. |
| **IN_AGREEMENT** | Estado de pago/préstamo incluido en un convenio. El asociado ya no espera cobrar al cliente, asumió la deuda. |

---

## 📝 NOTAS IMPORTANTES

1. **available_credit es GENERATED**: No se puede modificar directamente, se calcula automáticamente.

2. **El crédito se "mueve", no desaparece**: Cuando se crea un convenio o cierra un período, la deuda pasa de `pending_payments_total` a `consolidated_debt`, manteniendo `available_credit` igual.

3. **Solo pagos del ASOCIADO liberan crédito real**: Cuando el asociado paga su `consolidated_debt` (ya sea cuotas de convenio o pagos directos), el `available_credit` aumenta.

4. **Clientes NO pagan convenios**: Los convenios son exclusivamente para que el ASOCIADO reestructure su deuda con CrediCuenta. Los clientes solo pagan cuotas de sus préstamos.

5. **Los triggers manejan todo**: No es necesario actualizar manualmente los saldos en el código de aplicación.

6. **Backup antes de cambios masivos**: Siempre crear backup de `associate_profiles` antes de correcciones.

---

**Documento generado automáticamente - Sistema CrediNet v2.0**
