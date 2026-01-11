# 📊 LÓGICA DE LIBERACIÓN DE CRÉDITO - EJEMPLOS NUMÉRICOS

**Fecha:** 2026-01-07  
**Basado en:** Datos reales del asociado user_id=8

---

## 🎯 CONCEPTOS CLAVE

### Diferencia entre `debt_balance` y `credit_used`

```
credit_used     = Crédito COMPROMETIDO en préstamos activos
debt_balance    = Deuda ACUMULADA que el asociado debe pagar
credit_available = credit_limit - credit_used - debt_balance
```

**Son independientes pero relacionados:**
- `credit_used` crece al APROBAR préstamo → disminuye al PAGAR a CrediCuenta
- `debt_balance` crece al CERRAR período con saldo → disminuye al PAGAR a CrediCuenta

---

## 📈 EJEMPLO REAL: Asociado user_id=8

### Estado Actual
```
credit_limit     = $200,000.00
credit_used      = $149,938.61  (préstamos activos)
debt_balance     = $9,692.27    (deuda acumulada)
credit_available = $40,369.12
```

**Cálculo:**
```
$200,000 - $149,938.61 - $9,692.27 = $40,369.12 ✓
```

### Préstamos Activos
```
Loan #93: $6,000.00 @ $429.71/quincena = $5,156.52 associate_payment total
Loan #91: $3,000.00 @ $337.00/quincena = $4,044.00 associate_payment total
... otros préstamos ...
-----------
Total credit_used: $149,938.61
```

### Deuda Acumulada
```
Statement #6 (Dec08-2025):
  - Total a CrediCuenta: $10,591.27
  - Abonado:             $899.00
  - Balance pendiente:   $9,692.27 ← Este es el debt_balance
```

---

## 🔄 FLUJO COMPLETO: ¿CUÁNDO SE LIBERA CRÉDITO?

### CASO 1: Aprobación de Préstamo

```
ANTES: credit_used = $149,938.61

Se aprueba loan #93: $6,000 a 12 quincenas
associate_payment = $429.71 × 12 = $5,156.52

DESPUÉS: credit_used = $149,938.61 + $5,156.52 = $155,095.13
```

**Trigger:** `trigger_update_associate_credit_on_loan_approval()`  
**Libera crédito:** ❌ NO (aumenta credit_used)

---

### CASO 2: Cliente Paga al Asociado

```
Loan #91, Payment #1: $392.00
Cliente deposita $392.00 en cuenta del asociado

UPDATE payments SET amount_paid = 392.00 WHERE id = 1212;
```

**¿Debe liberarse crédito en este momento?**

🚫 **NO** porque:
1. Es pago **cliente → asociado** (no llega a CrediCuenta)
2. El asociado aún debe pagar $337.00 a CrediCuenta
3. El crédito sigue "comprometido" hasta que asociado pague

**Problema actual:** El trigger `trigger_update_associate_credit_on_payment()` SÍ libera crédito aquí ❌

**Tu decisión correcta:** NO debe liberarse

---

### CASO 3: Cierre de Período (Pagos Marcados PAID)

```
Period Dec08-2025 cierra el 2025-12-08

Loan #91 tenía 12 pagos:
- Payment #1: expected=$392.00, amount_paid=$392.00
- Payment #2: expected=$392.00, amount_paid=$100.00
- Payment #3: expected=$392.00, amount_paid=$0.00
... etc ...

TOTAL esperado de asociado: $337.00 × 12 = $4,044.00
TOTAL cobrado por asociado: (ejemplo) $3,500.00
DIFERENCIA: $544.00 ← Se convierte en deuda
```

**Función:** `close_period_and_accumulate_debt()`

**Acciones:**
1. Marca todos los payments como PAID o PAID_NOT_REPORTED
2. Crea deuda: $544.00 en `associate_accumulated_balances`
3. Actualiza: `debt_balance += $544.00`

**¿Debe liberarse credit_used en este momento?**

🚫 **NO** porque:
1. Son pagos **cliente → asociado** (rastreados mínimamente)
2. El asociado AÚN NO pagó a CrediCuenta
3. El préstamo sigue activo con pagos futuros
4. La deuda pasa al asociado pero el crédito sigue usado

**Tu lógica correcta:** "el credito es del asociado no del cliente, pasamos la deuda al asociado, y dicho credito sigue used"

✅ **CORRECTO:** NO liberar crédito al marcar PAID

---

### CASO 4: Asociado Abona a Statement Actual

```
Statement #16 (Dec23-2025):
  Total a CrediCuenta: $11,458.71
  
Asociado hace abono de $2,000.00

INSERT INTO associate_statement_payments 
  (statement_id, payment_amount, ...) 
VALUES (16, 2000.00, ...);
```

**Trigger:** `update_statement_on_payment()`

**Acciones actuales:**
```sql
UPDATE associate_profiles 
SET debt_balance = GREATEST(debt_balance - 2000.00, 0)
WHERE id = 2;

-- debt_balance: $9,692.27 → $7,692.27 ✓
```

**¿Debe liberarse credit_used?**

✅ **SÍ** porque:
1. Es pago **asociado → CrediCuenta**
2. El asociado está cumpliendo su obligación
3. Ese crédito ya NO está comprometido en préstamos activos de ese período

**Problema actual:** NO se libera credit_used ❌

**Tu decisión correcta:** SÍ debe liberarse (igual que deuda)

---

### CASO 5: Asociado Abona a Deuda Acumulada

```
Deuda acumulada período Dec08-2025: $9,692.27

Asociado hace abono de $3,000.00

INSERT INTO associate_debt_payments 
  (associate_profile_id, payment_amount, target_period_id, ...) 
VALUES (2, 3000.00, 46, ...);
```

**Trigger:** `apply_debt_payment_v2()`

**Acciones actuales:**
```sql
-- FIFO: Aplica a deudas más antiguas primero
UPDATE associate_profiles 
SET 
  debt_balance = debt_balance - 3000.00,
  credit_used = credit_used - 3000.00,  ✓
  credit_available = credit_available + 3000.00
WHERE id = 2;

-- debt_balance: $9,692.27 → $6,692.27 ✓
-- credit_used: $149,938.61 → $146,938.61 ✓
```

**¿Debe liberarse credit_used?**

✅ **SÍ** porque:
1. Es pago **asociado → CrediCuenta**
2. La deuda corresponde a préstamos que ya cerraron
3. Ese crédito puede volver a usarse

**Estado actual:** ✅ SÍ se libera correctamente

---

## 🎯 RESUMEN: ¿CUÁNDO SE LIBERA CREDIT_USED?

| Evento | ¿Libera credit_used? | Estado Actual | ¿Correcto? |
|--------|---------------------|---------------|------------|
| Aprobación de préstamo | ❌ NO (aumenta) | ❌ NO | ✅ Correcto |
| Cliente paga a asociado (amount_paid) | ❌ NO | ✅ SÍ | ❌ **INCORRECTO** |
| Cierre período (PAID) | ❌ NO | ❌ NO | ✅ Correcto |
| Abono a statement actual | ✅ SÍ | ❌ NO | ❌ **INCORRECTO** |
| Abono a deuda acumulada | ✅ SÍ | ✅ SÍ | ✅ Correcto |

---

## 📝 PUNTO 4: RELACIÓN debt_balance vs credit_used

### ¿Son independientes o relacionados?

**Respuesta: Son RELACIONADOS pero DIFERENTES**

```
┌─────────────────────────────────────────────────────────┐
│                  CREDIT_LIMIT = $200,000                │
└─────────────────────────────────────────────────────────┘
                          │
         ┌────────────────┴────────────────┐
         ▼                                 ▼
┌──────────────────┐            ┌──────────────────┐
│   CREDIT_USED    │            │   DEBT_BALANCE   │
│   $149,938.61    │            │    $9,692.27     │
│                  │            │                  │
│ Préstamos ACTIVOS│            │ Deuda ACUMULADA  │
│ con pagos futuros│            │ de períodos      │
│ pendientes       │            │ cerrados         │
└──────────────────┘            └──────────────────┘
         │                                 │
         └────────────────┬────────────────┘
                          ▼
              ┌────────────────────┐
              │  CREDIT_AVAILABLE  │
              │    $40,369.12      │
              └────────────────────┘
```

### Ejemplo Numérico:

**Situación Inicial:**
```
credit_limit = $200,000
credit_used = $150,000 (préstamos activos)
debt_balance = $10,000 (deuda acumulada)
credit_available = $40,000
```

**Evento 1: Asociado abona $5,000 a deuda**
```
credit_used = $150,000 - $5,000 = $145,000
debt_balance = $10,000 - $5,000 = $5,000
credit_available = $200,000 - $145,000 - $5,000 = $50,000 ✓
```

**Evento 2: Asociado abona $8,000 a statement actual**
```
Supongamos statement tiene:
- $8,000 corresponde a 3 préstamos que ya cerraron (associate_payment total)

credit_used = $145,000 - $8,000 = $137,000
debt_balance = $5,000 (sin cambio, porque es statement no deuda)
credit_available = $200,000 - $137,000 - $5,000 = $58,000 ✓
```

### Lógica de Negocio:

1. **credit_used** rastrea el compromiso TOTAL que el asociado tiene con CrediCuenta
   - Incluye pagos futuros de préstamos activos
   - Se reduce SOLO cuando asociado paga a CrediCuenta

2. **debt_balance** rastrea saldos VENCIDOS o de períodos cerrados
   - Es un "sub-componente" del crédito usado
   - Ayuda a identificar asociados morosos

3. **Ambos reducen credit_available** porque ambos son obligaciones del asociado

### ¿Por qué ambos afectan credit_available?

```
Si asociado tiene:
- credit_used = $100,000 (préstamos activos)
- debt_balance = $20,000 (deuda vencida)

No puedes darle $80,000 más ($200k - $100k - $20k = $80k)
Porque aunque los $20k son de períodos pasados, 
el asociado DEBE pagarlos antes de tener más crédito.
```

---

## ✅ CONCLUSIONES

### Punto 3: Pagos marcados PAID
Tu lógica es **100% CORRECTA**:
- NO deben liberar crédito
- Son pagos cliente → asociado (rastreados mínimamente)
- El crédito es del asociado, no del cliente
- Solo abonos a CrediCuenta liberan crédito

### Punto 4: debt_balance vs credit_used
- Son **relacionados**: ambos son obligaciones del asociado
- Son **diferentes**: credit_used = compromisos totales, debt_balance = vencidos
- Ambos **reducen** credit_available
- Ambos se **liberan** cuando asociado paga a CrediCuenta

---

## 🔧 CORRECCIONES NECESARIAS

### 1. Remover trigger de payments.amount_paid ❌
```sql
-- Este trigger NO debe existir
DROP TRIGGER IF EXISTS trigger_update_associate_credit_on_payment ON payments;
DROP FUNCTION IF EXISTS trigger_update_associate_credit_on_payment();
```

### 2. Actualizar update_statement_on_payment() ✅
```sql
-- DEBE actualizar credit_used (actualmente NO lo hace)
UPDATE associate_profiles 
SET 
  debt_balance = GREATEST(debt_balance - v_payment_amount, 0),
  credit_used = GREATEST(credit_used - v_payment_amount, 0),  ← AGREGAR
  credit_available = credit_available + v_payment_amount       ← AGREGAR
WHERE id = v_associate_profile_id;
```

### 3. Mantener apply_debt_payment_v2() ✅
Ya funciona correctamente, no requiere cambios.

---

**Validado con datos reales del sistema en producción.**
