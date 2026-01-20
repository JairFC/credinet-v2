# 📋 ESTADOS DEL SISTEMA CREDINET

## 📊 ESTADOS DE PAGOS (`payments.status_id`)

| ID | Nombre | Descripción | Comportamiento |
|----|--------|-------------|----------------|
| 1 | **PENDING** | Pendiente de pago | Cliente debe pagar, asociado debe cobrar |
| 2 | **DUE_TODAY** | Vence hoy | Notificación especial, mismo día de vencimiento |
| 3 | **PAID** | Pagado completamente | Cliente pagó, asociado recibió pago |
| 4 | **OVERDUE** | Vencido | Pasó fecha de pago, cliente en mora |
| 5 | **PARTIAL** | Pagado parcialmente | Cliente pagó parte, saldo pendiente |
| 9 | **PAID_BY_ASSOCIATE** | Asumido por asociado | ⚠️ Cliente moroso, asociado asume deuda |
| 13 | **IN_AGREEMENT** | En convenio de pago | Movido a convenio, en plan de pagos |

### ⚠️ NOTAS ESPECIALES:
- **`PAID_BY_ASSOCIATE` con `amount_paid = 0`**: Diseño intencional. Asociado asume deuda sin pago real.
- **`IN_AGREEMENT`**: Deuda movida de `pending_payments_total` → `consolidated_debt`.

---

## 🏦 ESTADOS DE PRÉSTAMOS (`loans.status_id`)

| ID | Nombre | Descripción | Impacto Crédito |
|----|--------|-------------|-----------------|
| 2 | **ACTIVE** | Activo | `pending_payments_total` aumenta |
| 9 | **IN_AGREEMENT** | En convenio | Movido a `consolidated_debt` |

---

## 📄 ESTADOS DE STATEMENTS (`statement_statuses`)

| ID | Nombre | Descripción | Impacto Deuda |
|----|--------|-------------|---------------|
| 1 | **GENERATED** | Generado | Statement creado |
| 2 | **SENT** | Enviado | Enviado al asociado |
| 3 | **PAID** | Pagado | Asociado pagó statement |
| 8 | **ABSORBED** | Absorbido | ⭐ Deuda movida a `consolidated_debt` |
| 10 | **CLOSED** | Cerrado | Proceso completado |

### ⭐ ESTADO CRÍTICO: `ABSORBED`
- Statement no pagado antes de `due_date`
- Deuda se "absorbe" como deuda consolidada
- `consolidated_debt` aumenta
- Registrado en `associate_accumulated_balances`

---

## 🤝 ESTADOS DE CONVENIOS (`agreements.status`)

| Estado | Descripción | Impacto |
|--------|-------------|---------|
| **ACTIVE** | Convenio activo | Plan de pagos en curso |
| **COMPLETED** | Completado | Todas las cuotas pagadas |
| **CANCELLED** | Cancelado | Convenio cancelado |

---

## ⚖️ TIPOS DE DEUDA (`associate_debt_breakdown.debt_type`)

| Tipo | Descripción | Origen |
|------|-------------|--------|
| **DEFAULTED_CLIENT** | Cliente moroso | Reporte aprobado de morosidad |
| **UNREPORTED_PAYMENT** | Pago no reportado | Asociado no reportó pago recibido |
| **LATE_FEE** | Multa por retraso | Penalización por pago tardío |
| **OTHER** | Otros | Deuda especial |

---

## 🔄 FLUJO DE ESTADOS CRÍTICOS

### **FLUJO NORMAL (cliente paga):**
```
PENDING (1) → PAID (3)
↓
`pending_payments_total` disminuye
`available_credit` aumenta
```

### **FLUJO MOROSIDAD (cliente no paga):**
```
PENDING (1) → OVERDUE (4) → PAID_BY_ASSOCIATE (9)
↓
Reporte moroso → Aprobación
↓
Registro en `associate_debt_breakdown` (DEFAULTED_CLIENT)
`consolidated_debt` aumenta
```

### **FLUJO CONVENIOS:**
```
Préstamo ACTIVE → IN_AGREEMENT (9)
Pagos PENDING → IN_AGREEMENT (13)
↓
`pending_payments_total` disminuye
`consolidated_debt` aumenta
`available_credit` = SIN CAMBIO (se resta en ambos lados)
↓
Asociado paga convenio → `consolidated_debt` disminuye
`available_credit` aumenta
```

### **FLUJO STATEMENTS:**
```
Statement GENERATED (1) → SENT (2)
↓
Si paga antes de due_date → PAID (3)
Si NO paga → ABSORBED (8)
↓
`consolidated_debt` aumenta
Registro en `associate_accumulated_balances`
```

---

## 🧮 FÓRMULAS DE CRÉDITO

### **CRÉDITO DISPONIBLE:**
```
available_credit = credit_limit - pending_payments_total - consolidated_debt
```

### **MOVIMIENTOS:**
- **Préstamo aprobado**: `pending_payments_total += SUM(associate_payment)`
- **Pago recibido**: `pending_payments_total -= associate_payment`
- **Moroso aprobado**: `consolidated_debt += total_debt_amount`
- **Convenio creado**: 
  ```
  pending_payments_total -= X
  consolidated_debt += X
  available_credit = SIN CAMBIO
  ```
- **Pago convenio**: `consolidated_debt -= Y`, `available_credit += Y`

---

## ⚠️ CONSTANTES HARCODEADAS (REVISAR)

### **EN CÓDIGO:**
1. `approved_by = 1` (defaulted_reports_routes.py) - ❌ Debería ser usuario autenticado
2. `cut_period_id = ... else 1` (fallback) - ⚠️ Manejar error apropiadamente
3. `paid_by_associate_id = ... else 5` (fallback) - ⚠️ Crear constante

### **RECOMENDACIONES:**
1. Usar `current_user.id` para usuario autenticado
2. Definir constantes en archivo de configuración
3. Manejar errores en lugar de fallbacks hardcodeados

---

## ✅ VERIFICACIONES DE INTEGRIDAD

### **DATOS DEBERÍAN COINCIDIR:**
1. `SUM(associate_payment WHERE status_id IN (1,2,4))` = `pending_payments_total`
2. `SUM(accumulated_debt)` = `consolidated_debt`
3. `credit_limit - pending - consolidated` = `available_credit`

### **EJEMPLOS REALES ENCONTRADOS:**
1. **Asociado 1030**: $600,000 - $510,559.29 - $16,500.02 = $72,940.69 ✅
2. **Asociado 8**: $200,000 - $110,221.57 - $19,035.60 = $70,742.83 ✅

---

## 🚀 PRÓXIMAS MEJORAS

### **PRIORIDAD ALTA:**
1. Reemplazar IDs hardcodeados por constantes/variables
2. Mejorar manejo de errores (no fallbacks hardcodeados)
3. Documentar triggers automáticos

### **PRIORIDAD MEDIA:**
1. Crear tests para verificar integridad de datos
2. Implementar monitoreo de inconsistencias
3. Mejorar logging de cambios de estado

### **PRIORIDAD BAJA:**
1. Refactorizar código con SQL en strings
2. Optimizar consultas críticas
3. Mejorar documentación de API