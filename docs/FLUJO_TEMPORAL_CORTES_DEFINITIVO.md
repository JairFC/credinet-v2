# 📅 FLUJO TEMPORAL DE CORTES - VERSIÓN DEFINITIVA

## ✅ **ENTENDIMIENTO CORRECTO CONFIRMADO**

---

## 🔄 **CICLO QUINCENAL:**

### **DOS PERÍODOS POR MES:**

```
PERÍODO 1: Del día 8 al día 22
PERÍODO 2: Del día 23 al día 7 (del mes siguiente)
```

### **FECHAS CLAVE:**

- **Día 8**: Se GENERA el corte del período anterior (23 al 7)
  - ⚠️  **AL CERRAR**: TODOS los pagos se marcan como "pagados"
  - Reportados → PAID (sin deuda)
  - NO reportados → PAID_NOT_REPORTED (van a `debt_balance` del asociado)
  
- **Día 23**: Se GENERA el corte del período anterior (8 al 22)
  - ⚠️  **AL CERRAR**: TODOS los pagos se marcan como "pagados"
  - Reportados → PAID (sin deuda)
  - NO reportados → PAID_NOT_REPORTED (van a `debt_balance` del asociado)

---

## 📊 **ESTRUCTURA DE LA TABLA `cut_periods`:**

```sql
cut_periods {
  id: SERIAL PRIMARY KEY,
  cut_number: INTEGER,           -- 1-24 por año
  period_start_date: DATE,       -- Día que INICIA el período ⭐
  period_end_date: DATE,         -- Día que TERMINA el período ⭐
  status_id: INTEGER,
  ...
}
```

### **Ejemplos de la base de datos:**

```sql
-- 2024
(1, 23, '2024-12-08', '2024-12-22', CLOSED),  -- Período del 8-dic al 22-dic
(2, 24, '2024-12-23', '2025-01-07', CLOSED),  -- Período del 23-dic al 7-ene

-- 2025
(3, 1, '2025-01-08', '2025-01-22', CLOSED),   -- Período del 8-ene al 22-ene
(4, 2, '2025-01-23', '2025-02-07', CLOSED),   -- Período del 23-ene al 7-feb
(5, 3, '2025-02-08', '2025-02-22', CLOSED),   -- Período del 8-feb al 22-feb
(6, 4, '2025-02-23', '2025-03-07', ACTIVE),   -- Período del 23-feb al 7-mar ⭐
```

---

## 📅 **EJEMPLO COMPLETO: Préstamo de Juan**

### **DATOS DEL PRÉSTAMO:**

```
Monto: $10,000
Plazo: 12 quincenas
Aprobado: 15-noviembre-2024
Cuota quincenal: $1,250 (expected_amount)
```

### **CRONOGRAMA COMPLETO:**

```
┌──────┬─────────────────┬─────────────────────────┬──────────────────┬───────────────────┐
│ No.  │ Cliente Paga    │ Período (PAGO VÁLIDO)   │ Aparece en Corte │ Corte Generado el │
│ Pago │ (fecha sugerida)│ period_start → end      │ cut_number       │ (día que cierra)  │
├──────┼─────────────────┼─────────────────────────┼──────────────────┼───────────────────┤
│  1   │ 30-nov          │ 23-nov → 7-dic          │ 2024-Q24         │ 23-nov (inicio)   │
│  2   │ 15-dic          │ 8-dic → 22-dic          │ 2024-Q23         │ 8-dic (inicio)    │
│  3   │ 31-dic          │ 23-dic → 7-ene          │ 2024-Q24         │ 23-dic (inicio)   │
│  4   │ 15-ene          │ 8-ene → 22-ene          │ 2025-Q01         │ 8-ene (inicio)    │
│  5   │ 31-ene          │ 23-ene → 7-feb          │ 2025-Q02         │ 23-ene (inicio)   │
│  6   │ 15-feb          │ 8-feb → 22-feb          │ 2025-Q03         │ 8-feb (inicio)    │
│  7   │ 28-feb          │ 23-feb → 7-mar          │ 2025-Q04         │ 23-feb (inicio) ⭐│
│  8   │ 15-mar          │ 8-mar → 22-mar          │ 2025-Q05         │ 8-mar (inicio)    │
│  9   │ 31-mar          │ 23-mar → 7-abr          │ 2025-Q06         │ 23-mar (inicio)   │
│ 10   │ 15-abr          │ 8-abr → 22-abr          │ 2025-Q07         │ 8-abr (inicio)    │
│ 11   │ 30-abr          │ 23-abr → 7-may          │ 2025-Q08         │ 23-abr (inicio)   │
│ 12   │ 15-may          │ 8-may → 22-may          │ 2025-Q09         │ 8-may (inicio)    │
└──────┴─────────────────┴─────────────────────────┴──────────────────┴───────────────────┘
```

---

## 🎯 **EXPLICACIÓN DETALLADA - Pago #7 de Juan:**

### **Contexto:**
```
Fecha sugerida al cliente: 28-feb (último día del mes)
Período de pago VÁLIDO: 23-feb al 7-mar (23:59:59)
```

### **Timeline Completa:**

```
📅 23-FEB (00:00:00):
   ✅ Período 2025-Q04 INICIA
   ✅ Pago #7 de Juan aparece en la relación de este corte
   ✅ Estado: PENDING
   ✅ El asociado VE este pago en su relación del día 23-feb

🕐 23-FEB al 7-MAR:
   ⏰ Cliente tiene 13 días para pagar
   ⏰ Fecha sugerida: 28-feb (pero puede pagar hasta el 7-mar)
   ⏰ Si cliente paga el 28-feb → pago #7 cambia a PAID
   ⏰ Si cliente paga el 5-mar → pago #7 cambia a PAID (aún dentro del período)

📅 7-MAR (23:59:59):
   ⚠️  Último minuto para que cliente pague SIN PENALIZACIÓN
   ⚠️  Si no paga hasta las 23:59:59 → queda OVERDUE

📅 8-MAR (00:00:00):
   🚨 Período 2025-Q04 CIERRA
   🚨 Se ejecuta: close_period_and_accumulate_debt()
   🚨 TODOS los pagos se marcan como "pagados":
      ✅ Si asociado reportó (amount_paid > 0) → PAID
      ⚠️  Si NO reportó (amount_paid = 0) → PAID_NOT_REPORTED
      ⚠️  Pagos NO reportados van a debt_balance del asociado
   🚨 Se genera el SIGUIENTE corte: 2025-Q05 (8-mar al 22-mar)

📅 HASTA 22-MAR:
   💰 Asociado tiene plazo para LIQUIDAR el corte 2025-Q04
   💰 Debe entregar: total_amount_collected - commission_amount
   💰 Si no liquida → Mora del 30% sobre su comisión
```

---

## 💰 **RELACIÓN DE PAGO DEL CORTE 2025-Q04:**

### **Generada el: 23-feb**

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
RELACIÓN DE PAGO: 2025-Q04
Período: 23-febrero al 7-marzo
Fecha de Generación: 23-febrero
Fecha Límite Liquidación: 22-marzo
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

PAGOS INCLUIDOS (payment_due_date entre 23-feb y 7-mar):

┌──────────┬───────────┬──────────┬─────────┬──────────────┬───────────┬────────────────┐
│ Contrato │ Cliente   │ Préstamo │ No.Pago │ Fecha Sug.   │ Cliente   │ Comisión 5%    │
│          │           │          │         │              │ Paga      │                │
├──────────┼───────────┼──────────┼─────────┼──────────────┼───────────┼────────────────┤
│ 12345    │ Juan P.   │ $10,000  │ 7/12    │ 28-feb       │ $1,250    │ $62.50         │
│ 67890    │ María G.  │ $15,000  │ 4/12    │ 28-feb       │ $1,875    │ $93.75         │
│ 11111    │ Luis R.   │ $8,000   │ 8/12    │ 5-mar        │ $1,000    │ $50.00         │
└──────────┴───────────┴──────────┴─────────┴──────────────┴───────────┴────────────────┘

RESUMEN FINANCIERO:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Total Cobrado (clientes):        $4,125  ← total_amount_collected
Comisión Ganada (5%):             $206.25 ← total_commission_owed
                                 ─────────
Debe Entregar a CrediCuenta:     $3,918.75 ← (4,125 - 206.25)

📅 Plazo de Liquidación: Hasta 22-marzo
⚠️  Mora (si no liquida): $61.88 (30% de $206.25)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## 🔑 **REGLAS CLAVE:**

### **1. Aparición en Relación:**
```
✅ Pago aparece en relación el PRIMER DÍA del período (period_start_date)
❌ NO aparece el día que se CIERRA el período anterior
```

### **2. Período de Validez:**
```
✅ Cliente puede pagar desde period_start_date hasta period_end_date (23:59:59)
⚠️  Si paga DESPUÉS de period_end_date → queda OVERDUE
```

### **3. Generación de Corte:**
```
✅ Corte se GENERA el día period_start_date
✅ Corte se CIERRA el día siguiente (period_end_date + 1 día, 00:00:00)
```

### **4. Liquidación del Asociado:**
```
✅ Asociado tiene ~15 días para liquidar DESPUÉS del cierre
✅ Plazo: Hasta el día 22 (si período termina el 7)
✅ Plazo: Hasta el día 7 del siguiente mes (si período termina el 22)
```

### **5. Mora:**
```
✅ Se aplica sobre la COMISIÓN (commission_amount), NO sobre el total
✅ Porcentaje: 30% de la comisión ganada
✅ Se cobra si paid_amount = 0 al vencimiento
```

---

## 🎯 **RELACIÓN ENTRE CAMPOS:**

```javascript
// Pago individual:
payment {
  expected_amount: $1,250,        // Lo que CLIENTE paga al asociado
  commission_amount: $62.50,      // 5% - Lo que ASOCIADO gana
  associate_payment: $1,187.50    // Lo que ASOCIADO paga a CrediCuenta
}

// Validación:
expected_amount = commission_amount + associate_payment
$1,250 = $62.50 + $1,187.50 ✅

// Statement del corte:
associate_payment_statements {
  total_payments_count: 3,              // Cantidad de pagos en el período
  total_amount_collected: $4,125,       // SUM(expected_amount)
  total_commission_owed: $206.25,       // SUM(commission_amount)
  
  // Implícito: SUM(associate_payment) = $3,918.75
  // = total_amount_collected - total_commission_owed
}

// Mora (si no liquida):
late_fee_amount = total_commission_owed × 0.30
late_fee_amount = $206.25 × 0.30 = $61.88
```

---

## ✅ **VALIDACIÓN FINAL:**

### **Pregunta: ¿Cuándo aparece el pago en la relación?**
```
✅ El día que INICIA el período (period_start_date)
✅ Ejemplo: Período 23-feb al 7-mar → Aparece el 23-feb
```

### **Pregunta: ¿Hasta cuándo puede pagar el cliente?**
```
✅ Hasta el ÚLTIMO DÍA del período (period_end_date, 23:59:59)
✅ Ejemplo: Período 23-feb al 7-mar → Puede pagar hasta 7-mar 23:59:59
```

### **Pregunta: ¿Cuándo se cierra el período?**
```
✅ El día SIGUIENTE al period_end_date (00:00:00)
✅ Ejemplo: Período 23-feb al 7-mar → Se cierra 8-mar 00:00:00
⚠️  AL CERRAR: TODOS los pagos se marcan como "pagados"
   - Reportados → PAID (sin deuda)
   - NO reportados → PAID_NOT_REPORTED (van a debt_balance)
```

### **Pregunta: ¿Qué pasa con pagos NO reportados?**
```
⚠️  Se marcan como PAID_NOT_REPORTED
⚠️  Se acumulan en associate_debt_breakdown
⚠️  Se suman a debt_balance del asociado
⚠️  Asociado DEBE ese dinero a CrediCuenta
✅ Se puede regenerar el corte si reporta pagos fuera de tiempo
```

### **Pregunta: ¿Hasta cuándo liquida el asociado?**
```
✅ ~15 días después del cierre
✅ Si cierra el 8 → Liquida hasta el 22
✅ Si cierra el 23 → Liquida hasta el 7 del siguiente mes
```

### **Pregunta: ¿La mora es sobre qué monto?**
```
✅ Sobre la COMISIÓN (commission_amount), NO sobre el total
✅ Porcentaje: 30%
✅ Ejemplo: Comisión $206.25 → Mora $61.88
```

---

## 📝 **CORRECCIONES NECESARIAS:**

### **EN DOCUMENTACIÓN:**
- ✅ Confirmado: `period_start_date` es cuando INICIA el período
- ✅ Confirmado: Pagos aparecen en relación el día `period_start_date`
- ✅ Confirmado: Mora es 30% de la comisión
- ✅ Confirmado: Cronograma de 12 pagos es consecutivo

### **EN CÓDIGO:**
- ⚠️  Verificar que frontend muestre `total_amount_collected` (NO solo `total_commission_owed`)
- ⚠️  Verificar que mora se calcule sobre `total_commission_owed × 0.30`
- ⚠️  Agregar tabla desglosada de pagos individuales
- ⚠️  Mostrar balance completo: collected - commission - paid + late_fee + debt_balance

---

## 🎉 **CONCLUSIÓN:**

La lógica está **CORRECTA** en la base de datos y documentación principal.

**REGLA CRÍTICA AL CERRAR PERÍODO:**
- ✅ TODOS los pagos se marcan como "pagados"
- ✅ Reportados → PAID (sin deuda)
- ⚠️  NO reportados → PAID_NOT_REPORTED (acumulan en debt_balance)

**DOCUMENTACIÓN COMPLETA:**
- 📄 Este documento: Flujo temporal y cronogramas
- 📄 LOGICA_CIERRE_PERIODO_Y_DEUDA.md: Proceso de cierre detallado
- 📄 LOGICA_RELACIONES_PAGO_CORREGIDA.md: Flujos de dinero y cálculos

**PENDIENTE IMPLEMENTAR:**
- ⚠️  Sistema de versiones para regenerar cortes
- ⚠️  Interfaz de admin para cerrar/regenerar períodos
- ⚠️  Vista de historial de revisiones (revision_number)

**FRONTEND NECESITA:**
- ⚠️  Mostrar `total_amount_collected` correctamente
- ⚠️  Mostrar `debt_balance` del asociado
- ⚠️  Tabla desglosada de pagos individuales
- ⚠️  Badge de versión si el corte fue regenerado
