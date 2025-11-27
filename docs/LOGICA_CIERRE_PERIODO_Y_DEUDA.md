# 🔒 LÓGICA DE CIERRE DE PERÍODO Y ACUMULACIÓN DE DEUDA

## ⚠️ **DOCUMENTO OBSOLETO - Ver LOGICA_CIERRE_DEFINITIVA_V3.md**

Este documento contiene lógica INCORRECTA. La versión correcta está en:
📄 **LOGICA_CIERRE_DEFINITIVA_V3.md**

---

## ❌ **REGLA INCORRECTA (NO USAR):**

---

## 🎯 **"AL CERRAR EL PERÍODO, TODOS LOS PAGOS SE MARCAN COMO PAGADOS"**

### **Clasificación de Pagos al Cierre:**

```
┌─────────────────────────┬──────────────────────────┬──────────────────────┐
│ SITUACIÓN DEL PAGO      │ ESTADO ASIGNADO          │ ¿VA A DEUDA?         │
├─────────────────────────┼──────────────────────────┼──────────────────────┤
│ Cliente pagó Y          │ PAID                     │ NO                   │
│ asociado lo reportó     │ (status_id = PAID)       │ ✅ Todo OK           │
│ (amount_paid > 0)       │                          │                      │
├─────────────────────────┼──────────────────────────┼──────────────────────┤
│ Cliente NO pagó         │ PAID_NOT_REPORTED        │ SÍ ✅                │
│ (amount_paid = 0)       │ (status_id = PNR)        │ → debt_balance       │
│                         │                          │ Asociado debe pagar  │
├─────────────────────────┼──────────────────────────┼──────────────────────┤
│ Cliente NO pudo pagar   │ PAID_BY_ASSOCIATE        │ SÍ ✅                │
│ (moroso reportado)      │ (status_id = PBA)        │ → debt_balance       │
│                         │                          │ Asociado asume deuda │
└─────────────────────────┴──────────────────────────┴──────────────────────┘
```

---

## 🔄 **PROCESO DE CIERRE - Función: `close_period_and_accumulate_debt()`**

### **ENTRADA:**
```sql
close_period_and_accumulate_debt(
  p_cut_period_id INTEGER,    -- ID del período a cerrar
  p_closed_by INTEGER          -- Usuario admin que cierra
)
```

### **PROCESO COMPLETO:**

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
PASO 1: Marcar Pagos Reportados como PAID
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

UPDATE payments
SET status_id = (SELECT id FROM payment_statuses WHERE name = 'PAID')
WHERE cut_period_id = p_cut_period_id
  AND amount_paid > 0
  AND status_id NOT IN (PAID, PAID_NOT_REPORTED, PAID_BY_ASSOCIATE);

Resultado: ✅ Pagos reportados → PAID (sin deuda)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
PASO 2: Marcar Pagos NO Reportados como PAID_NOT_REPORTED
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

UPDATE payments
SET status_id = (SELECT id FROM payment_statuses WHERE name = 'PAID_NOT_REPORTED')
WHERE cut_period_id = p_cut_period_id
  AND (amount_paid = 0 OR amount_paid IS NULL)
  AND status_id NOT IN (PAID, PAID_NOT_REPORTED, PAID_BY_ASSOCIATE);

Resultado: ⚠️  Pagos NO reportados → PAID_NOT_REPORTED (SE ACUMULA DEUDA)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
PASO 3: Marcar Clientes Morosos como PAID_BY_ASSOCIATE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- Se ejecuta cuando hay reportes de morosidad aprobados
-- Asociado reporta cliente moroso → Se marca como PAID_BY_ASSOCIATE

Resultado: 🚨 Cliente moroso → PAID_BY_ASSOCIATE (ASOCIADO ASUME DEUDA)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
PASO 4: Actualizar Estado del Período
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

UPDATE cut_periods
SET status_id = (SELECT id FROM cut_period_statuses WHERE name = 'CLOSED'),
    closed_by = p_closed_by,
    updated_at = CURRENT_TIMESTAMP
WHERE id = p_cut_period_id;

Resultado: ✅ Período cerrado oficialmente

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
PASO 5: Acumular Deuda en associate_debt_breakdown
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

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
  p.expected_amount,  -- ⭐ EL PAGO COMPLETO
  'Pago no reportado al cierre del período',
  false
FROM payments p
JOIN loans l ON p.loan_id = l.id
JOIN associate_profiles ap ON l.associate_user_id = ap.user_id
WHERE p.cut_period_id = p_cut_period_id
  AND p.status_id = (SELECT id FROM payment_statuses WHERE name = 'PAID_NOT_REPORTED');

Resultado: ⚠️  Se crea registro detallado de deuda por cada pago NO reportado

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
PASO 6: Actualizar debt_balance en associate_profiles
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

UPDATE associate_profiles ap
SET debt_balance = (
  SELECT COALESCE(SUM(amount), 0)
  FROM associate_debt_breakdown adb
  WHERE adb.associate_profile_id = ap.id
    AND adb.is_liquidated = false
);

Resultado: 💰 debt_balance actualizado con suma de deudas pendientes
```

---

## 💰 **ACUMULACIÓN DE DEUDA - Tabla: `associate_debt_breakdown`**

### **Estructura:**

```sql
associate_debt_breakdown {
  id SERIAL PRIMARY KEY,
  associate_profile_id INTEGER,      -- Asociado que debe
  cut_period_id INTEGER,             -- Período del que proviene
  debt_type VARCHAR,                 -- 'UNREPORTED_PAYMENT', 'DEFAULTED_CLIENT', 'LATE_FEE'
  loan_id INTEGER,                   -- Préstamo relacionado
  client_user_id INTEGER,            -- Cliente relacionado
  amount DECIMAL(12,2),              -- Monto de la deuda ⭐
  description TEXT,                  -- Descripción
  is_liquidated BOOLEAN,             -- ¿Ya fue pagado?
  liquidated_date DATE,              -- Fecha de liquidación
  created_at TIMESTAMP
}
```

### **Tipos de Deuda:**

```
1. UNREPORTED_PAYMENT:
   - Pago NO reportado al cierre
   - amount = expected_amount (pago completo del cliente)
   - Ejemplo: Cliente debía pagar $1,250, asociado NO lo reportó → Deuda $1,250

2. DEFAULTED_CLIENT:
   - Cliente moroso reportado
   - amount = total_debt_amount (puede ser acumulado)
   - Ejemplo: Cliente tiene 3 pagos vencidos → Deuda $3,750

3. LATE_FEE:
   - Mora del 30% sobre comisión
   - amount = total_commission_owed × 0.30
   - Ejemplo: Comisión $937.50 → Mora $281.25
```

---

## 📊 **EJEMPLO REAL: Cierre del Período 2025-Q04 (23-feb al 7-mar)**

### **ANTES DEL CIERRE (7-mar 23:59:59):**

```
Asociado: María López
Período: 2025-Q04 (23-feb al 7-mar)

Pagos en el período:
┌─────┬──────────┬───────────┬──────────┬──────────────┬──────────┬────────┐
│ #   │ Contrato │ Cliente   │ Préstamo │ Esperado     │ Reportado│ Estado │
├─────┼──────────┼───────────┼──────────┼──────────────┼──────────┼────────┤
│ 1   │ 12345    │ Juan P.   │ $10,000  │ $1,250       │ $1,250   │ PAID   │
│ 2   │ 67890    │ Rosa M.   │ $15,000  │ $1,875       │ $0       │ PENDING│
│ 3   │ 11111    │ Luis R.   │ $8,000   │ $1,000       │ $1,000   │ PAID   │
└─────┴──────────┴───────────┴──────────┴──────────────┴──────────┴────────┘

Statement:
total_amount_collected: $4,125 (suma de expected_amount)
total_commission_owed: $206.25 (5%)
paid_amount: $2,250 (solo reportó 2 de 3 pagos)
```

### **AL CERRAR (8-mar 00:00:00):**

```sql
-- Ejecutar cierre:
SELECT close_period_and_accumulate_debt(6, 2);  -- Período Q04, cerrado por admin ID=2

-- Resultado:
✅ Pago #1 (Juan): YA ESTABA PAID → Sin cambios
⚠️  Pago #2 (Rosa): amount_paid=0 → PAID_NOT_REPORTED → DEUDA $1,875
✅ Pago #3 (Luis): YA ESTABA PAID → Sin cambios
```

### **DESPUÉS DEL CIERRE:**

```
Tabla: payments
┌─────┬──────────┬───────────┬──────────┬──────────────┬──────────┬──────────────────────┐
│ #   │ Contrato │ Cliente   │ Préstamo │ Esperado     │ Reportado│ Estado               │
├─────┼──────────┼───────────┼──────────┼──────────────┼──────────┼──────────────────────┤
│ 1   │ 12345    │ Juan P.   │ $10,000  │ $1,250       │ $1,250   │ PAID ✅              │
│ 2   │ 67890    │ Rosa M.   │ $15,000  │ $1,875       │ $0       │ PAID_NOT_REPORTED ⚠️│
│ 3   │ 11111    │ Luis R.   │ $8,000   │ $1,000       │ $1,000   │ PAID ✅              │
└─────┴──────────┴───────────┴──────────┴──────────────┴──────────┴──────────────────────┘

Tabla: associate_debt_breakdown (NUEVO REGISTRO)
┌─────┬────────────┬────────────┬───────────────────┬─────────┬────────┬───────────────────────────────┐
│ ID  │ Asociado   │ Período    │ Tipo              │ Cliente │ Monto  │ Descripción                   │
├─────┼────────────┼────────────┼───────────────────┼─────────┼────────┼───────────────────────────────┤
│ 101 │ María      │ 2025-Q04   │ UNREPORTED_PAYMENT│ Rosa M. │ $1,875 │ Pago no reportado al cierre   │
└─────┴────────────┴────────────┴───────────────────┴─────────┴────────┴───────────────────────────────┘

Tabla: associate_profiles (ACTUALIZADO)
┌────────────┬──────────────┬─────────────┐
│ Asociado   │ debt_balance │ Cambio      │
├────────────┼──────────────┼─────────────┤
│ María      │ $1,875       │ +$1,875 ⚠️  │
└────────────┴──────────────┴─────────────┘

Tabla: cut_periods (ACTUALIZADO)
┌──────────┬────────────┬──────────────────┬────────────┐
│ Período  │ Inicio     │ Fin              │ Estado     │
├──────────┼────────────┼──────────────────┼────────────┤
│ 2025-Q04 │ 23-feb     │ 7-mar            │ CLOSED 🔒  │
└──────────┴────────────┴──────────────────┴────────────┘
```

---

## 🔄 **SISTEMA DE VERSIONES Y REGENERACIÓN (PROPUESTO)**

### **PROBLEMA:**
```
❌ Pagos fuera de tiempo no pueden agregarse al período cerrado
❌ Si el asociado reporta un pago DESPUÉS del cierre, no hay forma de actualizar
```

### **SOLUCIÓN PROPUESTA:**

#### **1. Agregar Campo `revision_number` a `cut_periods`:**

```sql
ALTER TABLE cut_periods ADD COLUMN revision_number INTEGER NOT NULL DEFAULT 1;
ALTER TABLE cut_periods ADD COLUMN last_regenerated_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE cut_periods ADD COLUMN regenerated_by INTEGER REFERENCES users(id);

COMMENT ON COLUMN cut_periods.revision_number IS 'Número de versión del corte (1, 2, 3...). Se incrementa cada vez que se regenera.';
```

#### **2. Crear Tabla de Historial: `cut_period_revisions`:**

```sql
CREATE TABLE cut_period_revisions (
    id SERIAL PRIMARY KEY,
    cut_period_id INTEGER NOT NULL REFERENCES cut_periods(id),
    revision_number INTEGER NOT NULL,
    
    -- Snapshot de valores ANTES de regenerar
    previous_total_payments_expected DECIMAL(12,2),
    previous_total_payments_received DECIMAL(12,2),
    previous_total_commission DECIMAL(12,2),
    
    -- Valores DESPUÉS de regenerar
    new_total_payments_expected DECIMAL(12,2),
    new_total_payments_received DECIMAL(12,2),
    new_total_commission DECIMAL(12,2),
    
    -- Tracking
    regenerated_by INTEGER NOT NULL REFERENCES users(id),
    regeneration_reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(cut_period_id, revision_number)
);
```

#### **3. Función: `regenerate_cut_period()`:**

```sql
CREATE OR REPLACE FUNCTION regenerate_cut_period(
    p_cut_period_id INTEGER,
    p_regenerated_by INTEGER,
    p_reason TEXT
)
RETURNS INTEGER AS $$
DECLARE
    v_current_revision INTEGER;
    v_new_revision INTEGER;
BEGIN
    -- Obtener revisión actual
    SELECT revision_number INTO v_current_revision
    FROM cut_periods
    WHERE id = p_cut_period_id;
    
    v_new_revision := v_current_revision + 1;
    
    -- Guardar snapshot en historial
    INSERT INTO cut_period_revisions (
        cut_period_id,
        revision_number,
        previous_total_payments_expected,
        previous_total_payments_received,
        previous_total_commission,
        regenerated_by,
        regeneration_reason
    )
    SELECT 
        p_cut_period_id,
        v_current_revision,
        total_payments_expected,
        total_payments_received,
        total_commission,
        p_regenerated_by,
        p_reason
    FROM cut_periods
    WHERE id = p_cut_period_id;
    
    -- Recalcular pagos del período
    -- (permitir agregar pagos marcados fuera de tiempo)
    UPDATE cut_periods
    SET 
        total_payments_expected = (
            SELECT COALESCE(SUM(expected_amount), 0)
            FROM payments
            WHERE cut_period_id = p_cut_period_id
        ),
        total_payments_received = (
            SELECT COALESCE(SUM(amount_paid), 0)
            FROM payments
            WHERE cut_period_id = p_cut_period_id
              AND amount_paid > 0
        ),
        total_commission = (
            SELECT COALESCE(SUM(commission_amount), 0)
            FROM payments
            WHERE cut_period_id = p_cut_period_id
        ),
        revision_number = v_new_revision,
        last_regenerated_at = CURRENT_TIMESTAMP,
        regenerated_by = p_regenerated_by
    WHERE id = p_cut_period_id;
    
    -- Actualizar nuevo snapshot
    UPDATE cut_period_revisions
    SET 
        new_total_payments_expected = (SELECT total_payments_expected FROM cut_periods WHERE id = p_cut_period_id),
        new_total_payments_received = (SELECT total_payments_received FROM cut_periods WHERE id = p_cut_period_id),
        new_total_commission = (SELECT total_commission FROM cut_periods WHERE id = p_cut_period_id)
    WHERE cut_period_id = p_cut_period_id
      AND revision_number = v_current_revision;
    
    RAISE NOTICE '✅ Período % regenerado: Revisión % → %', p_cut_period_id, v_current_revision, v_new_revision;
    
    RETURN v_new_revision;
END;
$$ LANGUAGE plpgsql;
```

#### **4. Flujo de Uso:**

```
📅 ESCENARIO: Pago Fuera de Tiempo

1. Período 2025-Q04 cerrado el 8-mar
2. Asociado reporta pago de Rosa el 10-mar (2 días tarde)

ADMIN:
  → Marca pago manualmente con fecha real (10-mar)
  → Ejecuta: SELECT regenerate_cut_period(6, 2, 'Pago de Rosa reportado fuera de tiempo');
  → Sistema:
     ✅ Guarda snapshot de valores anteriores
     ✅ Recalcula totales del período
     ✅ Incrementa revision_number: 1 → 2
     ✅ Actualiza debt_balance si es necesario
     
RESULTADO:
  ✅ Período tiene ahora 2 versiones
  ✅ Se puede consultar historial de cambios
  ✅ Deuda del asociado se ajusta automáticamente
```

---

## ✅ **CONCLUSIÓN Y PENDIENTES:**

### **LO QUE YA EXISTE:**
- ✅ Función `close_period_and_accumulate_debt()` funcional
- ✅ Tabla `associate_debt_breakdown` para tracking de deudas
- ✅ Campo `debt_balance` en `associate_profiles`
- ✅ Estados de pago: PAID, PAID_NOT_REPORTED, PAID_BY_ASSOCIATE

### **LO QUE FALTA IMPLEMENTAR (Sistema de Versiones):**
- ❌ Campo `revision_number` en `cut_periods`
- ❌ Tabla `cut_period_revisions` para historial
- ❌ Función `regenerate_cut_period()` para reabrir y regenerar
- ❌ Interfaz de admin para regenerar períodos
- ❌ Vista de historial de revisiones

### **PRÓXIMOS PASOS:**
1. Crear migración para campos de versionado
2. Implementar función de regeneración
3. Agregar endpoint en backend: `POST /admin/cut-periods/{id}/regenerate`
4. Crear interfaz en frontend para regenerar cortes
5. Mostrar badge de "Revisión #2" en statements regenerados
