# 🔒 LÓGICA DE CIERRE DE PERÍODO - VERSIÓN DEFINITIVA V3 (ACTUALIZADA)

## ✅ **ENTENDIMIENTO CORRECTO - VERIFICADO CON USUARIO**
**Última actualización:** 2025-11-11 - Correcciones aplicadas según decisiones confirmadas

---

## 🎯 **REGLA PRINCIPAL AL CERRAR PERÍODO:**

```
AL TERMINAR EL PERÍODO (iniciar el siguiente corte):
  ✅ Pagos ya marcados manualmente → NO SE TOCAN
  ✅ Pagos sin marcar:
     • Si paid_amount >= total → PAID_BY_ASSOCIATE
     • Si paid_amount < total → UNPAID_ACCRUED_DEBT (NO se distribuye)
```

---

## 💳 **DOS TIPOS DE ABONOS (CRÍTICO):**

### **⭐ SIEMPRE EXISTEN DOS TIPOS:**

#### **TIPO 1: Abono al Saldo Actual**
```
Tabla: associate_statement_payments
Destino: paid_amount del statement actual
Efecto: Si paid_amount > 0, NO se aplica mora (30%)
UI: Radio button "Saldo Actual (Quincena 2025-Q04)"
```

#### **TIPO 2: Abono a Deuda Acumulada**
```
Tabla: associate_debt_payments (NUEVO)
Destino: debt_balance del asociado
Estrategia: FIFO automático (más antiguos primero)
UI: Radio button "Deuda Acumulada ($8,500)"
```

**Referencia:** Ver `TRACKING_ABONOS_DEUDA_ANALISIS.md` para diseño completo

---

## 📊 **ESTADOS DE PAGO Y SU SIGNIFICADO:**

### **1. PAID (Pagado - Marcado MANUALMENTE)**
```
✅ Admin/Asociado marcó este pago como PAGADO
✅ Cliente SÍ pagó y se reportó
✅ Todo está en orden
✅ NO va a deuda
```

### **2. PAID_NOT_REPORTED (No Pagado - Marcado MANUALMENTE)**
```
⚠️  Admin marcó este pago como NO PAGADO
⚠️  Cliente moroso / no pagó
⚠️  Marcado ANTES del cierre (raramente usado)
⚠️  VA a deuda del asociado
```

### **3. PAID_BY_ASSOCIATE (Pagado por Asociado - AUTOMÁTICO AL CERRAR)**
```
🔄 Estado AUTOMÁTICO al cerrar período
🔄 Aplicado cuando paid_amount >= associate_payment_total
🔄 NO significa necesariamente "moroso"
🔄 Simplemente: "Asociado liquidó el statement completo"
🔄 NO va a deuda
```

### **4. UNPAID_ACCRUED_DEBT (No Pagado - Deuda Acumulada - AUTOMÁTICO)**
```
❌ Estado AUTOMÁTICO al cerrar período
❌ Aplicado cuando paid_amount < associate_payment_total
❌ Puede ser paid_amount = 0 (mora aplica) o paid_amount parcial (NO mora)
❌ VA a deuda del asociado
❌ NO se distribuye (decisión 3-NUEVA.1): TODOS los pagos quedan así
```

---

## 🔄 **PROCESO DE CIERRE CORRECTO:**

### **PASO 1: Identificar pagos sin marcar**

```sql
SELECT id, loan_id, expected_amount
FROM payments
WHERE cut_period_id = p_cut_period_id
  AND status_id NOT IN (
    SELECT id FROM payment_statuses WHERE name IN ('PAID', 'PAID_NOT_REPORTED')
  );
```

**Resultado**: Pagos que quedaron en PENDING, DUE_TODAY, OVERDUE, etc.

---

### **PASO 2: Marcar pagos según paid_amount (⭐ CORREGIDO)**

```sql
-- 2.1 Calcular paid_amount del asociado (suma de abonos)
paid_amount := (
  SELECT COALESCE(SUM(payment_amount), 0)
  FROM associate_statement_payments
  WHERE statement_id = p_statement_id
);

-- 2.2 Calcular total a pagar
associate_payment_total := total_amount_collected - total_commission_owed;

-- 2.3 Decisión de estado según abono
IF paid_amount >= associate_payment_total THEN
  -- Liquidó completo → PAID_BY_ASSOCIATE
  UPDATE payments
  SET 
    status_id = (SELECT id FROM payment_statuses WHERE name = 'PAID_BY_ASSOCIATE'),
    updated_at = CURRENT_TIMESTAMP
  WHERE cut_period_id = p_cut_period_id
    AND status_id NOT IN (
      SELECT id FROM payment_statuses WHERE name IN ('PAID', 'PAID_NOT_REPORTED')
    );
    
ELSE
  -- NO liquidó (parcial o cero) → UNPAID_ACCRUED_DEBT
  -- ⭐ DECISIÓN 3-NUEVA.1: NO se distribuye, todos quedan pendientes
  UPDATE payments
  SET 
    status_id = (SELECT id FROM payment_statuses WHERE name = 'UNPAID_ACCRUED_DEBT'),
    updated_at = CURRENT_TIMESTAMP
  WHERE cut_period_id = p_cut_period_id
    AND status_id NOT IN (
      SELECT id FROM payment_statuses WHERE name IN ('PAID', 'PAID_NOT_REPORTED')
    );
END IF;
```

**Razón**: 
- Si paid_amount >= total: Asociado liquidó completo → PAID_BY_ASSOCIATE
- Si paid_amount < total: NO se distribuye (decisión confirmada) → UNPAID_ACCRUED_DEBT
- Estados PAID y PAID_NOT_REPORTED nunca se modifican (marcados manualmente)

---

### **PASO 3: Acumular SOLO los pagos PAID_NOT_REPORTED a deuda**

```sql
INSERT INTO associate_debt_breakdown (
  associate_profile_id,
  cut_period_id,
  debt_type,
  loan_id,
  client_user_id,
  amount,
  description,
  is_liquidated
)
SELECT 
  ap.id,
  p.cut_period_id,
  'UNREPORTED_PAYMENT',
  l.id,
  l.user_id,
  p.expected_amount,
  'Cliente moroso reportado manualmente',
  false
FROM payments p
JOIN loans l ON p.loan_id = l.id
JOIN associate_profiles ap ON l.associate_user_id = ap.user_id
WHERE p.cut_period_id = p_cut_period_id
  AND p.status_id = (SELECT id FROM payment_statuses WHERE name = 'PAID_NOT_REPORTED');
```

**Razón**: Solo los marcados manualmente como "no pagados" van a deuda.

---

### **PASO 4: Cerrar período**

```sql
UPDATE cut_periods
SET 
  status_id = (SELECT id FROM cut_period_statuses WHERE name = 'CLOSED'),
  closed_by = p_closed_by,
  updated_at = CURRENT_TIMESTAMP
WHERE id = p_cut_period_id;
```

---

## 📝 **EJEMPLO REAL: Statement de María López**

### **DURANTE EL PERÍODO (23-feb al 7-mar):**

```
Statement 2025-Q04 - María López

Pagos esperados:
┌─────┬──────────┬───────────┬──────────┬──────────────┬────────────────┐
│ #   │ Contrato │ Cliente   │ Préstamo │ Esperado     │ Estado         │
├─────┼──────────┼───────────┼──────────┼──────────────┼────────────────┤
│ 1   │ 12345    │ Juan P.   │ $10,000  │ $1,250       │ PAID ✅        │
│     │          │           │          │              │ (marcado manual)│
│ 2   │ 67890    │ Rosa M.   │ $15,000  │ $1,875       │ PENDING        │
│     │          │           │          │              │ (sin marcar)    │
│ 3   │ 11111    │ Luis R.   │ $8,000   │ $1,000       │ PENDING        │
│     │          │           │          │              │ (sin marcar)    │
│ 4   │ 22222    │ Ana S.    │ $12,000  │ $1,500       │ PAID_NOT_REP ⚠️│
│     │          │           │          │              │ (morosa marcada)│
└─────┴──────────┴───────────┴──────────┴──────────────┴────────────────┘

RESUMEN:
total_amount_collected: $5,625 (suma de expected_amount)
total_commission_owed: $281.25 (5%)
associate_payment_total: $5,343.75 (lo que debe entregar)

SITUACIÓN:
- Juan: Marcado PAID ✅ (admin lo marcó)
- Rosa: Sin marcar (asociado no lo reportó individualmente)
- Luis: Sin marcar (asociado no lo reportó individualmente)
- Ana: Marcada PAID_NOT_REPORTED ⚠️ (admin la marcó como morosa)
```

---

### **MARÍA LIQUIDA EL STATEMENT (antes del 22-mar):**

```
María hace transferencia/abono:
paid_amount: $5,343.75 (el monto completo que debe)

💰 Liquidación registrada en associate_statement_payments:
  - statement_id: 123
  - payment_amount: $5,343.75
  - payment_date: 15-mar
  - payment_reference: "TRANSF-XYZ123"

✅ Statement actualizado:
  - paid_amount: $5,343.75
  - status: PAID
```

---

### **AL CERRAR EL PERÍODO (8-mar 00:00:00):**

```sql
-- Ejecutar cierre automático:
SELECT close_period_and_accumulate_debt(6, 2);

PROCESO:

PASO 1: Identificar pagos sin marcar
  → Pago #2 (Rosa): PENDING
  → Pago #3 (Luis): PENDING

PASO 2: Marcar automáticamente como PAID_BY_ASSOCIATE
  UPDATE payments
  SET status_id = (SELECT id FROM payment_statuses WHERE name = 'PAID_BY_ASSOCIATE')
  WHERE id IN (pago#2, pago#3);
  
  Razón: María ya liquidó el statement completo ($5,343.75)
         Estos pagos se asumen cubiertos por la liquidación

PASO 3: Acumular SOLO los PAID_NOT_REPORTED a deuda
  INSERT INTO associate_debt_breakdown (...)
  SELECT ... WHERE status_id = 'PAID_NOT_REPORTED';
  
  → Pago #4 (Ana): $1,500 va a deuda de María

PASO 4: Cerrar período
  UPDATE cut_periods SET status_id = CLOSED;
```

---

### **DESPUÉS DEL CIERRE:**

```
Tabla: payments (RESULTADO FINAL)
┌─────┬──────────┬───────────┬──────────┬──────────────┬──────────────────────┐
│ #   │ Contrato │ Cliente   │ Préstamo │ Esperado     │ Estado FINAL         │
├─────┼──────────┼───────────┼──────────┼──────────────┼──────────────────────┤
│ 1   │ 12345    │ Juan P.   │ $10,000  │ $1,250       │ PAID ✅              │
│     │          │           │          │              │ (sin cambios)        │
│ 2   │ 67890    │ Rosa M.   │ $15,000  │ $1,875       │ PAID_BY_ASSOCIATE 🔄│
│     │          │           │          │              │ (automático)         │
│ 3   │ 11111    │ Luis R.   │ $8,000   │ $1,000       │ PAID_BY_ASSOCIATE 🔄│
│     │          │           │          │              │ (automático)         │
│ 4   │ 22222    │ Ana S.    │ $12,000  │ $1,500       │ PAID_NOT_REPORTED ⚠️│
│     │          │           │          │              │ (sin cambios)        │
└─────┴──────────┴───────────┴──────────┴──────────────┴──────────────────────┘

Tabla: associate_debt_breakdown (NUEVO REGISTRO)
┌─────┬────────────┬────────────┬───────────────────┬─────────┬────────┐
│ ID  │ Asociado   │ Período    │ Tipo              │ Cliente │ Monto  │
├─────┼────────────┼────────────┼───────────────────┼─────────┼────────┤
│ 101 │ María      │ 2025-Q04   │ UNREPORTED_PAYMENT│ Ana S.  │ $1,500 │
└─────┴────────────┴────────────┴───────────────────┴─────────┴────────┘

Tabla: associate_profiles
┌────────────┬──────────────┬─────────────┐
│ Asociado   │ debt_balance │ Cambio      │
├────────────┼──────────────┼─────────────┤
│ María      │ $1,500       │ +$1,500 ⚠️  │
└────────────┴──────────────┴─────────────┘

BALANCE FINAL DE MARÍA:
✅ Liquidó el statement: $5,343.75
✅ Pagos #2 y #3 marcados como PAID_BY_ASSOCIATE (cubiertos)
⚠️  Pago #4 (Ana morosa): $1,500 de deuda acumulada
💰 debt_balance: $1,500 (solo Ana, NO Rosa ni Luis)
```

---

## 🎯 **DIFERENCIAS CLAVE:**

### **ANTES (Lógica Incorrecta):**
```
❌ PAID_BY_ASSOCIATE = Cliente moroso
❌ Todos los no marcados van a deuda
❌ associate_payment_total no consideraba liquidación del statement
```

### **AHORA (Lógica Correcta):**
```
✅ PAID_BY_ASSOCIATE = Pago cubierto por liquidación del statement
✅ Solo PAID_NOT_REPORTED (marcados manualmente) van a deuda
✅ Statement liquidado cubre todos los pagos no marcados
✅ debt_balance solo acumula morosos REALES (marcados explícitamente)
```

---

## 📊 **FLUJO COMPLETO VISUAL:**

```
DURANTE PERÍODO:
├─ Admin marca pagos individuales (opcional):
│  ├─ Cliente pagó → PAID ✅
│  └─ Cliente moroso → PAID_NOT_REPORTED ⚠️
│
└─ Asociado liquida statement completo:
   └─ paid_amount = $5,343.75

AL CERRAR PERÍODO:
├─ Pagos ya marcados → NO SE TOCAN
├─ Pagos sin marcar → PAID_BY_ASSOCIATE 🔄
│  (cubiertos por la liquidación del statement)
└─ Pagos PAID_NOT_REPORTED → debt_balance ⚠️

RESULTADO:
├─ Statement: PAID (liquidado)
├─ Pagos individuales: Todos con estado final
└─ debt_balance: Solo morosos marcados
```

---

## 🔑 **REGLAS DEFINITIVAS:**

### **1. MARCADO MANUAL (Durante el período):**
```
✅ PAID: Admin/Asociado confirma que cliente pagó
⚠️  PAID_NOT_REPORTED: Admin marca cliente como moroso
📝 Ambos son OPCIONALES (raramente usados)
```

### **2. LIQUIDACIÓN DE STATEMENT:**
```
💰 Asociado paga el monto total: paid_amount = $5,343.75
✅ Se registra en associate_statement_payments
✅ Statement cambia a status: PAID
```

### **3. CIERRE AUTOMÁTICO:**
```
🔄 Pagos sin marcar → PAID_BY_ASSOCIATE
   (asumidos cubiertos por la liquidación)
   
⚠️  Pagos PAID_NOT_REPORTED → debt_balance
   (morosos marcados explícitamente)
```

### **4. DEUDA:**
```
✅ debt_balance = SUM(pagos marcados PAID_NOT_REPORTED)
❌ debt_balance ≠ pagos sin marcar
❌ debt_balance ≠ PAID_BY_ASSOCIATE
```

---

## 💾 **FUNCIÓN CORREGIDA:**

```sql
CREATE OR REPLACE FUNCTION close_period_and_accumulate_debt(
    p_cut_period_id INTEGER,
    p_closed_by INTEGER
)
RETURNS VOID AS $$
DECLARE
    v_paid_by_associate_id INTEGER;
    v_paid_not_reported_id INTEGER;
    v_paid_id INTEGER;
    v_auto_marked_count INTEGER := 0;
    v_debt_count INTEGER := 0;
BEGIN
    -- Obtener IDs de estados
    SELECT id INTO v_paid_id FROM payment_statuses WHERE name = 'PAID';
    SELECT id INTO v_paid_not_reported_id FROM payment_statuses WHERE name = 'PAID_NOT_REPORTED';
    SELECT id INTO v_paid_by_associate_id FROM payment_statuses WHERE name = 'PAID_BY_ASSOCIATE';
    
    RAISE NOTICE '🔒 Cerrando período %', p_cut_period_id;
    
    -- ⭐ PASO 1: Marcar automáticamente pagos sin marcar como PAID_BY_ASSOCIATE
    WITH updated AS (
        UPDATE payments
        SET 
            status_id = v_paid_by_associate_id,
            updated_at = CURRENT_TIMESTAMP
        WHERE cut_period_id = p_cut_period_id
          AND status_id NOT IN (v_paid_id, v_paid_not_reported_id, v_paid_by_associate_id)
        RETURNING id
    )
    SELECT COUNT(*) INTO v_auto_marked_count FROM updated;
    
    RAISE NOTICE '🔄 Pagos marcados automáticamente como PAID_BY_ASSOCIATE: %', v_auto_marked_count;
    RAISE NOTICE '   (Cubiertos por liquidación del statement)';
    
    -- ⭐ PASO 2: Acumular SOLO los PAID_NOT_REPORTED a deuda
    INSERT INTO associate_debt_breakdown (
        associate_profile_id,
        cut_period_id,
        debt_type,
        loan_id,
        client_user_id,
        amount,
        description,
        is_liquidated
    )
    SELECT 
        ap.id,
        p.cut_period_id,
        'UNREPORTED_PAYMENT',
        l.id,
        l.user_id,
        p.expected_amount,
        'Cliente moroso reportado manualmente',
        false
    FROM payments p
    JOIN loans l ON p.loan_id = l.id
    JOIN associate_profiles ap ON l.associate_user_id = ap.user_id
    WHERE p.cut_period_id = p_cut_period_id
      AND p.status_id = v_paid_not_reported_id;
    
    GET DIAGNOSTICS v_debt_count = ROW_COUNT;
    
    RAISE NOTICE '⚠️  Pagos morosos acumulados en deuda: %', v_debt_count;
    
    -- ⭐ PASO 3: Actualizar debt_balance
    UPDATE associate_profiles ap
    SET debt_balance = (
        SELECT COALESCE(SUM(amount), 0)
        FROM associate_debt_breakdown adb
        WHERE adb.associate_profile_id = ap.id
          AND adb.is_liquidated = false
    );
    
    -- ⭐ PASO 4: Cerrar período
    UPDATE cut_periods
    SET 
        status_id = (SELECT id FROM cut_period_statuses WHERE name = 'CLOSED'),
        closed_by = p_closed_by,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = p_cut_period_id;
    
    RAISE NOTICE '✅ Período % cerrado exitosamente', p_cut_period_id;
    RAISE NOTICE '📊 Resumen:';
    RAISE NOTICE '   - Pagos automáticos (PAID_BY_ASSOCIATE): %', v_auto_marked_count;
    RAISE NOTICE '   - Pagos morosos (deuda): %', v_debt_count;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION close_period_and_accumulate_debt(INTEGER, INTEGER) IS 
'⭐ V3 CORREGIDA: Cierra período marcando pagos sin marcar como PAID_BY_ASSOCIATE (cubiertos por liquidación). Solo PAID_NOT_REPORTED van a deuda.';
```

---

## ✅ **VALIDACIÓN FINAL:**

### **Pregunta: ¿Qué significa PAID_BY_ASSOCIATE?**
```
✅ Pago cubierto por la liquidación del statement
✅ NO necesariamente moroso
✅ Simplemente no fue marcado individualmente
✅ NO va a debt_balance
```

### **Pregunta: ¿Qué va a debt_balance?**
```
✅ SOLO pagos marcados manualmente como PAID_NOT_REPORTED
✅ Clientes morosos reportados explícitamente
✅ Cantidad: Raramente usado (admin marca explícitamente)
```

### **Pregunta: ¿Cuándo se marca PAID manualmente?**
```
✅ Cuando admin/asociado quiere tracking detallado
✅ Opcional (raramente usado)
✅ Útil para reportes granulares
```

### **Pregunta: ¿Qué pasa si NO se marca nada manualmente?**
```
✅ Asociado liquida el statement completo
✅ Al cerrar: Todos → PAID_BY_ASSOCIATE
✅ debt_balance = 0 (no hay morosos marcados)
✅ TODO OK, flujo normal
```

---

## 🎉 **CONCLUSIÓN:**

La lógica ahora es **CLARA Y SIN HUECOS**:

1. **Durante período**: Marcado manual es OPCIONAL
2. **Liquidación**: Asociado paga el statement completo
3. **Al cerrar**: Automático → PAID_BY_ASSOCIATE (cubiertos)
4. **Deuda**: Solo morosos marcados EXPLÍCITAMENTE

**Flujo normal (99% de casos):**
- Asociado NO marca pagos individuales
- Asociado liquida statement completo
- Al cerrar: Todos → PAID_BY_ASSOCIATE
- debt_balance = 0

**Flujo con moroso (1% de casos):**
- Admin marca cliente como PAID_NOT_REPORTED
- Asociado liquida statement completo (menos ese pago)
- Al cerrar: Moroso → debt_balance
- debt_balance = monto del pago moroso
