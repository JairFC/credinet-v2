# 💰 ANÁLISIS EXHAUSTIVO: FLUJO DEL DINERO Y SALDOS

**Fecha**: 2026-01-07  
**Propósito**: Documentar y validar TODA la lógica de dinero, saldos y comisiones  
**Estado**: ✅ LÓGICA CONFIRMADA (2026-01-07)

---

## ⭐ REGLAS DE NEGOCIO CONFIRMADAS

### ✅ CONFIRMACIÓN #1: El ASOCIADO GANA la comisión
- Cliente paga $2,894.17 al **asociado**
- Asociado SE QUEDA con $368.00 (comisión - **es su ganancia**)
- Asociado entrega $2,526.17 a CrediCuenta

### ✅ CONFIRMACIÓN #2: En renovaciones, el asociado tiene SALDO A FAVOR por comisiones
- Cuando un préstamo se renueva, las comisiones de pagos pendientes quedan como **crédito del asociado**
- No se descuentan, sino que se acreditan al asociado

### ✅ CONFIRMACIÓN #3: Los pagos se marcan PAGADOS al cerrar el período
- NO importa si el cliente pagó o no
- Al cerrar período, **todos los pagos se dan por pagados**
- La deuda es **absorbida por el asociado**

### ✅ CONFIRMACIÓN #4: Solo rastreamos lo que el ASOCIADO debe a CrediCuenta
- No nos interesa si el cliente le paga al asociado
- La deuda es del **asociado a CrediCuenta**
- Los totales del cliente solo se usan para cálculos

---

## 🎯 CONCEPTOS FUNDAMENTALES

### 1. ¿QUIÉN LE PAGA A QUIÉN?

```
FLUJO DEL DINERO REAL:

CLIENTE ─────► ASOCIADO ─────► CREDICUENTA
         $2,894.17      $2,526.17
                        (cliente_paga - comisión)

COMISIÓN: $368.00 (ES LA GANANCIA DEL ASOCIADO)
```

### 2. DESCOMPOSICIÓN DE UN PAGO

Ejemplo real del sistema (pago #1131):
```
expected_amount (cliente paga):     $2,894.17
├─ principal_amount (capital):       $1,916.67  (23,000 / 12)
├─ interest_amount (interés):          $977.50
└─ commission_amount (comisión):       $368.00  (1.6% sobre expected)

associate_payment (asociado recibe): $2,526.17
                                     (2,894.17 - 368.00)
```

**VALIDACIONES MATEMÁTICAS**:
```
✅ expected_amount = principal + interest
   $2,894.17 = $1,916.67 + $977.50 ✓

✅ associate_payment = expected_amount - commission_amount
   $2,526.17 = $2,894.17 - $368.00 ✓
```

### 3. ¿QUIÉN GANA LA COMISIÓN? ⭐ CONFIRMADO

**✅ REALIDAD CONFIRMADA:**
- **EL ASOCIADO GANA LA COMISIÓN** 
- La comisión varía: 1.5%, 1.6%, 2.0%, 2.5%
- `commission_amount` = **ganancia del asociado**
- `associate_payment` = lo que debe entregar a CrediCuenta

**FLUJO CORRECTO:**
```
Cliente paga al asociado:       $2,894.17 (expected_amount)
Asociado SE QUEDA con:            $368.00 (comisión - SU GANANCIA)
Asociado entrega a CrediCuenta: $2,526.17 (associate_payment)
```

**ANALOGÍA CORRECTA:**
```
Comerciante vende producto: $100
Comerciante ganancia (margen): $20 (20%)
Comerciante paga al proveedor: $80

En nuestro sistema:
Cliente paga al asociado: $2,894.17
Asociado ganancia (comisión): $368.00 (1.6%)
Asociado paga a CrediCuenta: $2,526.17
```

---

## 💵 ESTADOS DE CUENTA (STATEMENTS)

### ¿QUÉ ES UN STATEMENT?

Es un **resumen de lo que el asociado debe entregar a CrediCuenta** por todos los pagos cobrados en un período.

```sql
-- Statement del período 23-dic al 7-ene
CREATE TABLE associate_payment_statements (
    id: 10,
    user_id: 1030 (asociado),
    cut_period_id: 5,
    statement_number: "STMT-2025-Q01",
    
    -- 📊 RESUMEN DE COBROS
    total_payments_count: 15,
    total_amount_collected: $43,412.55,  -- SUM(expected_amount)
    total_commission_owed: $5,506.00,    -- SUM(commission_amount)
    
    -- 💰 LIQUIDACIÓN
    paid_amount: $0.00,                  -- SUM(abonos del asociado)
    status_id: 1 (PENDING)
);
```

**INTERPRETACIÓN:**
```
El asociado cobró de sus clientes:  $43,412.55
CrediCuenta le cobra de comisión:    $5,506.00
El asociado debe entregar neto:     $37,906.55  (43,412.55 - 5,506.00)

Saldo pendiente: $37,906.55 (no ha abonado nada aún)
```

---

## 🔄 DOS TIPOS DE ABONOS DEL ASOCIADO

### TIPO 1: Abono al Statement Actual (Comisiones del Período)

**Tabla**: `associate_statement_payments`

```sql
-- Asociado abona $20,000 al statement del período actual
INSERT INTO associate_statement_payments (
    statement_id,
    payment_amount,
    payment_date,
    payment_method_id,
    payment_reference
) VALUES (
    10,
    20000.00,
    '2026-01-10',
    2, -- TRANSFER
    'SPEI-123456'
);
```

**¿QUÉ PASA INTERNAMENTE?**

1. **Trigger: `update_statement_on_payment()`**
   ```sql
   -- Suma TODOS los abonos del statement
   SELECT SUM(payment_amount) INTO v_total_paid
   FROM associate_statement_payments
   WHERE statement_id = 10;
   -- v_total_paid = $20,000
   
   -- Calcula saldo restante
   v_remaining = $37,906.55 - $20,000 = $17,906.55
   
   -- Actualiza statement
   UPDATE associate_payment_statements
   SET paid_amount = $20,000,
       status_id = 4  -- PARTIAL_PAID
   WHERE id = 10;
   ```

2. **Libera crédito automáticamente**
   ```sql
   UPDATE associate_profiles
   SET debt_balance = GREATEST(debt_balance - $20,000, 0)
   WHERE user_id = 1030;
   ```

3. **Liquida deuda FIFO en `associate_debt_breakdown`**
   ```sql
   -- Marca como liquidados los items más antiguos
   -- hasta cubrir los $20,000
   UPDATE associate_debt_breakdown
   SET is_liquidated = TRUE,
       liquidated_at = CURRENT_TIMESTAMP
   WHERE associate_profile_id = [id]
     AND cut_period_id = 5
     AND is_liquidated = FALSE
   ORDER BY created_at ASC
   LIMIT [hasta cubrir $20,000];
   ```

**RESULTADO:**
- ✅ Statement actualizado: paid_amount = $20,000
- ✅ debt_balance reducido: -$20,000
- ✅ Items de deuda marcados como liquidados
- ✅ credit_available aumenta automáticamente

---

### TIPO 2: Abono a Deuda Acumulada (Períodos Anteriores)

**Tabla**: `associate_debt_payments`

```sql
-- Asociado abona $50,000 a deuda de períodos anteriores
INSERT INTO associate_debt_payments (
    associate_profile_id,
    payment_amount,
    payment_date,
    payment_method_id,
    notes
) VALUES (
    [id],
    50000.00,
    '2026-01-10',
    2,
    'Abono a deuda acumulada'
);
```

**¿QUÉ PASA INTERNAMENTE?**

Similar al TIPO 1, pero aplica a deuda histórica:

1. **Libera crédito**
   ```sql
   UPDATE associate_profiles
   SET debt_balance = GREATEST(debt_balance - $50,000, 0)
   WHERE id = [id];
   ```

2. **Liquida items de deuda FIFO**
   ```sql
   -- Estrategia FIFO: oldest first
   UPDATE associate_debt_breakdown
   SET is_liquidated = TRUE
   WHERE associate_profile_id = [id]
     AND is_liquidated = FALSE
   ORDER BY created_at ASC
   LIMIT [hasta cubrir $50,000];
   ```

**DIFERENCIA CLAVE:**
- **TIPO 1**: Paga comisiones del período actual
- **TIPO 2**: Paga deuda de períodos anteriores no liquidados

---

## 🔄 RENOVACIÓN DE PRÉSTAMOS: EL CASO MÁS COMPLEJO

### Escenario Real

```
PRÉSTAMO ORIGINAL:
- Monto: $100,000
- Plazo: 12 quincenas
- Tasa interés: 4.0%
- Tasa comisión: 2.0%
- Pago quincenal: $2,768.33

ESTADO ACTUAL (después de 6 pagos):
- Pagos completados: 6 × $2,768.33 = $16,610
- Pagos pendientes: 6 × $2,768.33 = $16,610

CLIENTE QUIERE RENOVAR CON: $150,000
```

### Paso 1: Calcular Saldo Pendiente REAL

**¿Cuánto debe liquidar el cliente?**

```sql
SELECT COALESCE(SUM(expected_amount), 0) AS saldo_pendiente
FROM payments
WHERE loan_id = 123
  AND status_id = 1;  -- PENDING

-- Resultado: $16,610 (6 pagos × $2,768.33)
```

**DESCOMPOSICIÓN DEL SALDO:**
```
Pagos pendientes: 6
└─ Por cada pago:
   ├─ Capital: $8,333.33  (100,000 / 12)
   ├─ Interés: $333.33
   └─ Comisión: $101.67

Total por pago: $2,768.33
Total 6 pagos: $16,610.00
```

### Paso 2: ¿Qué pasa con el CRÉDITO del asociado?

**ANTES DE RENOVAR:**
```
credit_limit:  $500,000
credit_used:   $300,000  (incluye el préstamo de $100,000)
debt_balance:   $45,000
credit_available: $155,000  (500k - 300k - 45k)
```

**DURANTE LA RENOVACIÓN:**

1. **Liberar crédito del préstamo original**
   ```sql
   UPDATE associate_profiles
   SET credit_used = credit_used - $100,000  -- ✅ CAPITAL ORIGINAL
   WHERE user_id = 1030;
   
   -- credit_used = $200,000
   -- credit_available = $255,000 (500k - 200k - 45k)
   ```

2. **Consumir crédito del nuevo préstamo**
   ```sql
   -- El trigger lo hace automáticamente al aprobar
   UPDATE associate_profiles
   SET credit_used = credit_used + $150,000
   WHERE user_id = 1030;
   
   -- credit_used = $350,000
   -- credit_available = $105,000 (500k - 350k - 45k)
   ```

**RESULTADO NETO:**
```
credit_used: $300,000 → $350,000  (+$50,000)
credit_available: $155,000 → $105,000  (-$50,000)

✅ CORRECTO: Solo consume $50k neto de crédito
            (nuevo: $150k - viejo: $100k)
```

### Paso 3: ¿Qué pasa con las COMISIONES PENDIENTES?

**COMISIONES DEL PRÉSTAMO ORIGINAL:**
```
6 pagos pendientes × $101.67 comisión = $610.02
```

**PREGUNTA CRÍTICA:** ¿Quién absorbe estas comisiones?

**OPCIÓN A: El cliente las paga en el nuevo préstamo** ✅ (ACTUAL)
```
Nuevo préstamo: $150,000
Liquidar anterior: -$16,610
Neto al cliente: $133,390

Las comisiones pendientes ($610) están incluidas en los $16,610
El cliente efectivamente las paga como parte de la liquidación
```

**OPCIÓN B: El asociado las cobra como "saldo a favor"** ❌ (NO IMPLEMENTADO)
```
El asociado ganaría $610 adicionales
Pero esto NO está implementado actualmente
```

### Paso 4: Flujo Completo de la Renovación

```
1. Cliente solicita renovación de $150,000

2. Sistema calcula saldo pendiente:
   SELECT SUM(expected_amount) FROM payments
   WHERE loan_id = 123 AND status_id = PENDING;
   -- Resultado: $16,610

3. Validación: nuevo monto >= saldo pendiente
   $150,000 >= $16,610 ✓

4. Liberar crédito del préstamo original:
   credit_used -= $100,000 (CAPITAL original)

5. Crear nuevo préstamo de $150,000:
   - status = APPROVED (automático)
   - associate_user_id = mismo
   - Trigger genera cronograma de 12 pagos

6. Consumir crédito del nuevo préstamo:
   credit_used += $150,000 (trigger automático)

7. Marcar préstamo original como RENEWED:
   UPDATE loans SET status_id = RENEWED WHERE id = 123;

8. Marcar pagos pendientes como PAID_BY_RENEWAL:
   UPDATE payments 
   SET status_id = PAID_BY_RENEWAL,
       amount_paid = expected_amount
   WHERE loan_id = 123 AND status_id = PENDING;

9. Registrar en loan_renewals:
   INSERT INTO loan_renewals (
       original_loan_id,
       renewed_loan_id,
       pending_balance,
       new_amount
   ) VALUES (123, [nuevo_id], $16,610, $150,000);

10. Cliente recibe: $133,390
    ($150,000 - $16,610)
```

---

## 🎯 VALIDACIONES CRÍTICAS

### 1. Sincronización de `credit_used`

**Fórmula correcta:**
```sql
credit_used = SUM(loans.amount)
WHERE loans.associate_user_id = [id]
  AND loans.status_id IN (APPROVED, ACTIVE)
```

**¿Por qué solo el CAPITAL?**

Porque el `credit_used` representa cuánto dinero del crédito del asociado está "prestado" actualmente. Los intereses y comisiones NO son parte del crédito, son costos/ganancias del préstamo.

### 2. Liberación de Crédito en Pagos

**❌ INCORRECTO (antes):**
```sql
-- Se liberaba el monto TOTAL del pago
credit_used -= amount_paid  -- Incluye interés + comisión
```

**✅ CORRECTO (ahora):**
```sql
-- Se libera solo el CAPITAL
v_capital_paid = loan_amount / term_biweeks
credit_used -= v_capital_paid
```

**EJEMPLO:**
```
Pago del cliente: $2,768.33
├─ Capital: $1,916.67  ← Solo esto se libera de credit_used
├─ Interés: $777.50
└─ Comisión: $74.16

❌ ANTES: credit_used -= $2,768.33
✅ AHORA: credit_used -= $1,916.67
```

### 3. Cálculo de Saldo Pendiente

**❌ INCORRECTO (antes):**
```sql
-- Comparaba capital con pagos totales
v_remaining = loan.amount - SUM(payments.amount_paid)
             ↑ Solo capital  ↑ Incluye interés + comisión
```

**✅ CORRECTO (ahora):**
```sql
-- Suma expected_amount de pagos PENDIENTES
SELECT SUM(expected_amount) FROM payments
WHERE loan_id = [id] AND status_id = PENDING
```

---

## 🔍 CASOS DE USO A VALIDAR EN GUI

### 1. Crear y Aprobar Préstamo

**Validar:**
- [ ] `credit_used` aumenta por el monto del préstamo
- [ ] `credit_available` disminuye correctamente
- [ ] Se genera cronograma con N pagos
- [ ] Cada pago tiene `expected_amount`, `commission_amount`, `associate_payment`
- [ ] Suma de `principal_amount` = `loan.amount`

### 2. Registrar Pago de Cliente

**Validar:**
- [ ] `credit_used` disminuye solo por el CAPITAL del pago
- [ ] `credit_available` aumenta proporcionalmente
- [ ] `amount_paid` se registra correctamente
- [ ] Status del pago cambia a PAID

### 3. Cerrar Período

**Validar:**
- [ ] Se genera statement con totales correctos
- [ ] `total_amount_collected` = SUM(expected_amount)
- [ ] `total_commission_owed` = SUM(commission_amount)
- [ ] Pagos marcados como PAID, PAID_NOT_REPORTED, etc.

### 4. Abonar a Statement Actual

**Validar:**
- [ ] `paid_amount` del statement aumenta
- [ ] `debt_balance` del asociado disminuye
- [ ] Items de `associate_debt_breakdown` se marcan como liquidados (FIFO)
- [ ] `credit_available` aumenta automáticamente
- [ ] Status del statement cambia a PARTIAL_PAID o PAID

### 5. Abonar a Deuda Acumulada

**Validar:**
- [ ] `debt_balance` disminuye
- [ ] Items de deuda se liquidan en orden FIFO
- [ ] `credit_available` aumenta
- [ ] El abono NO afecta statements actuales

### 6. Renovar Préstamo

**Validar:**
- [ ] Saldo pendiente calculado correctamente (SUM expected_amount)
- [ ] `credit_used` libera capital original ($100k)
- [ ] `credit_used` consume capital nuevo ($150k)
- [ ] Crédito neto correcto (+$50k en el ejemplo)
- [ ] Préstamo anterior marcado como RENEWED
- [ ] Pagos pendientes marcados como PAID_BY_RENEWAL
- [ ] Nuevo préstamo aprobado con cronograma
- [ ] Cliente recibe neto: (nuevo - saldo_pendiente)
- [ ] Comisiones pendientes absorbidas en la liquidación

---

## ✅ PREGUNTAS RESUELTAS (2026-01-07)

### 1. ¿Quién gana la comisión? ✅ RESUELTO
**RESPUESTA**: El **ASOCIADO** gana la comisión.
- Cliente paga $2,894.17 al asociado
- Asociado se queda con $368.00 (comisión - su ganancia)
- Asociado entrega $2,526.17 a CrediCuenta

### 2. ¿Qué pasa con las comisiones en renovación? ✅ RESUELTO
**RESPUESTA**: Las comisiones quedan como **saldo a favor del asociado**.
- Si había $610 de comisiones pendientes en pagos no realizados
- Al renovar y liquidar, esas comisiones se acreditan al asociado
- Es decir, el asociado tiene derecho a ese dinero

### 3. ¿Se registran pagos individuales de clientes? ✅ RESUELTO
**RESPUESTA**: **NO** directamente.
- Solo rastreamos lo que el asociado debe a CrediCuenta
- Al cerrar período, los pagos se marcan como PAGADOS (paguen o no)
- La deuda es del ASOCIADO, no del cliente
- Si el cliente no pagó, el asociado asume la deuda

### 4. ¿Cómo se hereda la deuda del cliente al asociado? ✅ RESUELTO
**RESPUESTA**: Al **cerrar el período**.
- Al finalizar el statement, TODOS los pagos se marcan como pagados
- Si el cliente no pagó, la deuda automáticamente pasa al asociado
- Se registra en `associate_debt_breakdown`
- El asociado debe liquidar esa deuda a CrediCuenta

---

## 📋 LÓGICA DE CIERRE DE PERÍODO (CONFIRMADA)

### Proceso al Cerrar Statement:

```sql
-- PASO 1: Marcar TODOS los pagos como pagados
UPDATE payments 
SET status_id = CASE
    WHEN amount_paid > 0 THEN 3  -- PAID (cliente sí pagó)
    ELSE 10                       -- PAID_NOT_REPORTED (cliente NO pagó)
END
WHERE cut_period_id = [período_a_cerrar]
  AND status_id = 1;  -- Solo los que estaban PENDING

-- PASO 2: Acumular deuda en associate_debt_breakdown
-- Por cada pago NO reportado:
INSERT INTO associate_debt_breakdown (
    associate_profile_id,
    amount,  -- expected_amount del pago
    description
)
SELECT ap.id, p.expected_amount, 'Pago no reportado'
FROM payments p
WHERE p.status_id = 10  -- PAID_NOT_REPORTED
  AND p.cut_period_id = [período_cerrado];

-- PASO 3: Actualizar debt_balance del asociado
UPDATE associate_profiles
SET debt_balance = (
    SELECT SUM(amount) 
    FROM associate_debt_breakdown 
    WHERE is_liquidated = false
);
```

### Interpretación:
- **Cliente no paga** → Asociado asume la deuda
- **CrediCuenta cobra al asociado**, no al cliente
- **El asociado se encarga** de cobrarle al cliente después

### 3. Tracking de Pagos de Clientes

**¿Realmente NO rastreamos pagos individuales de clientes?**

Veo la tabla `payments` con campos:
- `amount_paid`
- `payment_date`
- `status_id`

¿Estos NO se usan actualmente? ¿O sí se registran?

---

## 📚 PRÓXIMOS PASOS

1. **Confirmar malentendidos con el usuario**
2. **Validar lógica de renovación en código**
3. **Testear cada caso de uso en GUI**
4. **Verificar sincronización de saldos en cada operación**
5. **Documentar hallazgos y correcciones necesarias**

---

**Estado**: 🚧 DOCUMENTO VIVO - Se actualizará conforme se valide
