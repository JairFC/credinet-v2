# 🚨 ANÁLISIS CRÍTICO - LÓGICA DE CRÉDITO CORREGIDA

**Fecha**: 2026-01-07  
**Issue**: El crédito debe rastrear lo que el asociado PAGA a CrediCuenta, no solo el capital

---

## 📊 EJEMPLO REAL - Préstamo #95

```sql
Capital prestado: $22,000
Plazo: 15 quincenas
Pago quincenal cliente: $2,401.67
Total que pagará cliente: $36,025.00
Comisión por pago: $352.00
```

### 🔍 DESGLOSE POR PAGO

```
Cliente paga al asociado: $2,401.67
├─ Comisión del asociado: $352.00 (SE QUEDA EL ASOCIADO)
└─ Asociado paga a CrediCuenta: $2,049.67 ($2,401.67 - $352.00)
```

**Verificación en BD:**
```sql
expected_amount:    $2,401.67  ← Cliente paga al asociado
commission_amount:  $352.00    ← Ganancia del asociado
associate_payment:  $2,049.67  ← Asociado paga a CrediCuenta

✅ Fórmula: associate_payment = expected_amount - commission_amount
✅ Cálculo: $2,049.67 = $2,401.67 - $352.00
```

---

## 💡 LA CORRECCIÓN NECESARIA

### ❌ LÓGICA ANTERIOR (INCORRECTA)

```
Al aprobar préstamo de $22,000:
  credit_used += $22,000  ← Solo el capital

Al pagar:
  capital_por_pago = $22,000 / 15 = $1,466.67
  credit_used -= $1,466.67  ← Solo libera capital
```

**Problema**: El asociado debe entregar $2,049.67 a CrediCuenta, pero solo liberamos $1,466.67 de crédito.

### ✅ LÓGICA CORRECTA (LO QUE DEBE PAGAR)

```
Al aprobar préstamo de $22,000:
  Lo que el asociado deberá pagar a CrediCuenta:
    = $2,049.67 × 15 pagos
    = $30,745.05
  
  credit_used += $30,745.05  ← Lo que PAGARÁ a CrediCuenta

Al pagar cada quincena:
  credit_used -= $2,049.67  ← Libera lo que entrega a CrediCuenta
```

---

## 📋 CAMPOS EN LA BD

### Tabla `payments`

| Campo | Valor | Significado |
|-------|-------|-------------|
| `expected_amount` | $2,401.67 | Cliente paga al asociado |
| `commission_amount` | $352.00 | Asociado SE QUEDA |
| `associate_payment` | $2,049.67 | Asociado PAGA a CrediCuenta |
| `principal_amount` | ~$1,466.67 | Porción de capital |
| `interest_amount` | ~$935.00 | Porción de interés |

### Relaciones

```
expected_amount = principal_amount + interest_amount
associate_payment = expected_amount - commission_amount
associate_payment = principal_amount + interest_amount - commission_amount
```

---

## 🎯 LO QUE DEBEMOS RASTREAR EN `credit_used`

**Pregunta clave**: ¿Qué rastrea `credit_used`?

### Opción A (la que teníamos):
```
credit_used = Capital prestado
            = $22,000
```

### Opción B (la correcta según usuario):
```
credit_used = Lo que el asociado debe pagar a CrediCuenta
            = Total de associate_payment
            = $2,049.67 × 15
            = $30,745.05
```

---

## 🔑 JUSTIFICACIÓN DE LA LÓGICA

### ¿Por qué rastrear `associate_payment`?

1. **Capacidad de pago del asociado**:
   - Si el asociado tiene $50,000 de límite
   - Y debe entregar $30,745 a CrediCuenta
   - Su crédito disponible debería ser: $50,000 - $30,745 = $19,255

2. **Flujo de caja**:
   - El asociado recibe $36,025 del cliente
   - Se queda con $5,280 de comisión
   - Debe entregar $30,745 a CrediCuenta
   - **Esto es lo que "ocupa" su línea de crédito**

3. **Control financiero**:
   - CrediCuenta necesita saber cuánto le deben los asociados
   - No solo el capital, sino **el total que deben pagar**

---

## 📊 COMPARATIVA

```
Préstamo de $22,000 a 15 quincenas:

┌─────────────────────────────────────────┐
│ Cliente paga (total): $36,025          │
├─────────────────────────────────────────┤
│ Comisión asociado: $5,280 (SE QUEDA)   │
├─────────────────────────────────────────┤
│ Asociado paga a CrediCuenta: $30,745   │
│   ├─ Capital: $22,000                   │
│   └─ Intereses: $8,745                  │
└─────────────────────────────────────────┘

LÓGICA ANTERIOR:
  credit_used = $22,000 ❌
  
LÓGICA CORRECTA:
  credit_used = $30,745 ✅
  (capital $22k + intereses $8.7k que paga a CrediCuenta)
```

---

## 🔧 CORRECCIONES NECESARIAS

### 1. Trigger al APROBAR préstamo

Actualmente (en `trigger_reserve_associate_credit`):
```sql
-- ❌ INCORRECTO
UPDATE associate_profiles
SET credit_used = credit_used + NEW.amount  -- Solo capital
WHERE user_id = NEW.associate_user_id;
```

Debe ser:
```sql
-- ✅ CORRECTO
DECLARE
    v_total_associate_payment DECIMAL(12,2);
BEGIN
    -- Calcular total que el asociado pagará a CrediCuenta
    v_total_associate_payment := (
        SELECT SUM(associate_payment)
        FROM payments
        WHERE loan_id = NEW.id
    );
    
    UPDATE associate_profiles
    SET credit_used = credit_used + v_total_associate_payment
    WHERE user_id = NEW.associate_user_id;
END;
```

### 2. Trigger al PAGAR

Actualmente:
```sql
-- ❌ INCORRECTO
v_capital_paid := v_loan_amount / v_loan_term;  -- Solo capital
UPDATE associate_profiles
SET credit_used = credit_used - v_capital_paid;
```

Debe ser:
```sql
-- ✅ CORRECTO
UPDATE associate_profiles
SET credit_used = credit_used - NEW.associate_payment  -- Lo que paga a CrediCuenta
WHERE id = v_associate_profile_id;
```

### 3. Función `calculate_loan_remaining_balance`

Actualmente:
```sql
-- ❌ INCORRECTO: suma expected_amount
SELECT SUM(expected_amount) 
FROM payments 
WHERE loan_id = p_loan_id AND status_id = v_pending_status_id;
```

Debe ser:
```sql
-- ✅ CORRECTO: suma associate_payment
SELECT SUM(associate_payment) 
FROM payments 
WHERE loan_id = p_loan_id AND status_id = v_pending_status_id;
```

---

## 🎯 RESUMEN EJECUTIVO

### Lo que entendíamos MAL:
- ✘ credit_used = capital prestado ($22,000)
- ✘ Liberar solo capital al pagar ($1,466.67)

### Lo que es CORRECTO:
- ✓ credit_used = lo que el asociado debe pagar a CrediCuenta ($30,745)
- ✓ Liberar associate_payment al pagar ($2,049.67)
- ✓ Este monto incluye capital + intereses - comisión

### Fórmula clave:
```
credit_used en aprobación = SUM(associate_payment de todos los pagos)
credit_used al pagar -= associate_payment del pago actual
```

---

## ✅ VALIDACIÓN CON NÚMEROS REALES

```
Préstamo $22,000 (15 quincenas):

Al APROBAR:
  credit_used += $2,049.67 × 15 = $30,745.05 ✅

Pago #1:
  Cliente paga: $2,401.67
  Asociado se queda: $352.00
  Asociado paga a CrediCuenta: $2,049.67
  credit_used -= $2,049.67 ✅

Después de 15 pagos:
  credit_used = $30,745.05 - ($2,049.67 × 15) = $0 ✅
```

---

## 🚨 IMPACTO

Este cambio afecta:
1. ✅ `trigger_reserve_associate_credit` - Al aprobar préstamo
2. ✅ `trigger_update_associate_credit_on_payment` - Al pagar
3. ✅ `calculate_loan_remaining_balance` - Cálculo de saldo
4. ✅ Toda la documentación sobre créditos

**Estado**: PENDIENTE DE CORRECCIÓN
