# 🎯 LÓGICA DE NEGOCIO CRÍTICA PARA FRONTEND

**Versión**: 1.0  
**Fecha**: 2025-11-05  
**Audiencia**: Desarrollo Frontend  
**Status**: ✅ Resumen Ejecutivo Consolidado

---

## 📚 DOCUMENTOS FUENTE ANALIZADOS

- ✅ `LOGICA_DE_NEGOCIO_DEFINITIVA.md` (1215 líneas)
- ✅ `ARQUITECTURA_DOBLE_CALENDARIO.md` (1062 líneas)
- ✅ `EXPLICACION_DOS_TASAS.md` (427 líneas)
- ✅ `PLAN_SISTEMA_TASAS_HIBRIDO_FINAL.md`
- ✅ `CORRECCION_DOS_TASAS_COMPLETO.md`

---

## 🔴 CONCEPTOS CRÍTICOS QUE EL FRONTEND DEBE IMPLEMENTAR

### 1. **DOBLE CALENDARIO QUINCENAL** ⭐⭐⭐

El sistema tiene **DOS calendarios simultáneos**:

#### 📆 Calendario del Cliente (payment_due_date)
**Fechas de vencimiento de pagos:**
- **Día 15** de cada mes
- **Último día** del mes (28/29/30/31 según mes)

**Alternancia:**
```
Pago 1: 15-Ene
Pago 2: 31-Ene  
Pago 3: 15-Feb
Pago 4: 28-Feb (29 si bisiesto)
Pago 5: 15-Mar
Pago 6: 31-Mar
... etc
```

#### 🏢 Calendario Administrativo (cut_periods)
**Periodos de corte contable:**
- **Periodo A**: Día 8-22 de cada mes (15 días)
- **Periodo B**: Día 23-7 del mes siguiente (15-16 días)

**Ejemplo:**
```
Periodo 3: 2025-01-08 → 2025-01-22 (15 días)
Periodo 4: 2025-01-23 → 2025-02-07 (16 días)
Periodo 5: 2025-02-08 → 2025-02-22 (15 días)
```

#### 🔮 Lógica de Sincronización (calculate_first_payment_date)

**Regla de Oro:**
```
SI préstamo aprobado días 1-7
  → Primer pago: día 15 del MISMO mes
  → Pertenece al corte del día 8

SI préstamo aprobado días 8-22
  → Primer pago: ÚLTIMO día del MISMO mes
  → Pertenece al corte del día 23

SI préstamo aprobado días 23-31
  → Primer pago: día 15 del SIGUIENTE mes
  → Pertenece al corte del día 8 siguiente
```

**Ejemplo Real:**
```
Aprobación: 7-Ene-2025 09:00 AM
Día: 7 (entre 1-7)
→ Primer pago: 15-Ene-2025
→ Segundo pago: 31-Ene-2025
→ Tercer pago: 15-Feb-2025
→ Cuarto pago: 28-Feb-2025
```

**⚠️ IMPLICACIONES PARA EL FRONTEND:**
- Al crear préstamo, mostrar preview del **primer vencimiento** según fecha de aprobación
- En cronograma, mostrar **alternancia 15 ↔ último día**
- En pagos, vincular con el **periodo de corte correcto**
- En reportes, agrupar por **periodo administrativo** (no por mes natural)

---

### 2. **SISTEMA DE DOBLE TASA** ⭐⭐⭐

El sistema usa **INTERÉS SIMPLE** (NO compuesto, NO amortización francesa).

#### 🧮 Fórmulas Básicas

**Lado CLIENTE (interest_rate):**
```javascript
// Ejemplo: $22,000 @ 4.25% por 12 quincenas

const capital = 22000;
const interestRate = 0.0425; // 4.25% quincenal
const term = 12; // quincenas

// PASO 1: Factor de crecimiento
const factor = 1 + (interestRate * term);
// factor = 1 + (0.0425 × 12) = 1.51

// PASO 2: Total a pagar
const totalAmount = capital * factor;
// totalAmount = $22,000 × 1.51 = $33,220.00

// PASO 3: Pago quincenal (distribuido equitativamente)
const biweeklyPayment = totalAmount / term;
// biweeklyPayment = $33,220 / 12 = $2,768.33

// PASO 4: Interés total
const totalInterest = totalAmount - capital;
// totalInterest = $33,220 - $22,000 = $11,220.00

// PASO 5: Distribución por pago
const interestPerPayment = totalInterest / term;
const capitalPerPayment = capital / term;
// interestPerPayment = $11,220 / 12 = $935.00
// capitalPerPayment = $22,000 / 12 = $1,833.33
```

**Lado ASOCIADO (commission_rate):**
```javascript
// Comisión sobre pago del cliente

const clientPayment = 2768.33; // del cálculo anterior
const commissionRate = 0.025; // 2.5%

// Comisión por pago
const commissionPerPayment = clientPayment * commissionRate;
// commissionPerPayment = $2,768.33 × 0.025 = $69.21

// Pago al socio
const associatePayment = clientPayment - commissionPerPayment;
// associatePayment = $2,768.33 - $69.21 = $2,699.12

// Totales
const totalCommission = commissionPerPayment * term;
const totalToAssociate = associatePayment * term;
// totalCommission = $69.21 × 12 = $830.52
// totalToAssociate = $2,699.12 × 12 = $32,389.44

// VERIFICACIÓN (debe sumar):
// totalAmount = totalToAssociate + totalCommission
// $33,220.00 = $32,389.44 + $830.52 ✅
```

#### 📊 Estructura de Cronograma (Amortization Schedule)

**Frontend debe mostrar:**
```javascript
const schedule = [
  {
    period: 1,
    paymentDueDate: '2025-11-15',
    // CLIENTE
    clientPayment: 2768.33,
    clientInterest: 935.00,
    clientCapital: 1833.33,
    remainingBalance: 20166.67,
    // ASOCIADO
    commission: 69.21,
    associatePayment: 2699.12,
    // ESTADO
    status: 'pending',
    cutPeriodId: 3
  },
  // ... 11 períodos más
];
```

**⚠️ IMPLICACIONES PARA EL FRONTEND:**
- Mostrar **preview de cálculos** antes de crear préstamo
- Permitir cambiar **rate profile** y recalcular en tiempo real
- Mostrar **cronograma completo** con alternancia de fechas
- Distinguir visualmente **interés vs capital** en cada pago
- Mostrar **comisión del asociado** en sección separada
- Calcular y mostrar **saldo pendiente** actualizado

---

### 3. **ASOCIACIÓN DE PAGOS CON PERIODO** ⭐⭐

#### 🔗 Relación payments ↔ cut_periods

**Cada pago se vincula con un periodo de corte:**
```javascript
// Ejemplo de estructura payment
{
  id: 456,
  loan_id: 123,
  payment_due_date: '2025-01-15', // Calendario cliente
  cut_period_id: 3,                // Calendario administrativo
  period_start_date: '2025-01-08',
  period_end_date: '2025-01-22',
  biweekly_payment: 2768.33,
  status: 'pending'
}
```

**Lógica de asignación:**
```javascript
function assignCutPeriod(paymentDueDate) {
  // Buscar periodo que contenga la fecha de vencimiento
  const period = cutPeriods.find(p => 
    paymentDueDate >= p.period_start_date &&
    paymentDueDate <= p.period_end_date
  );
  
  return period.id;
}

// Ejemplo:
// paymentDueDate = '2025-01-15'
// → cutPeriodId = 3 (periodo 2025-01-08 a 2025-01-22)

// paymentDueDate = '2025-01-31'
// → cutPeriodId = 4 (periodo 2025-01-23 a 2025-02-07)
```

**⚠️ IMPLICACIONES PARA EL FRONTEND:**
- En lista de pagos, permitir filtrar por **periodo de corte**
- En reportes, agrupar pagos por **cut_period_id**
- Mostrar **rango de fechas del periodo** junto al pago
- Al cerrar periodo, mostrar solo pagos de ese **cut_period_id**
- En estados de cuenta, usar periodos como **agrupador principal**

---

### 4. **SISTEMA DE CRÉDITO DEL ASOCIADO** ⭐⭐⭐

#### 💳 Límite de Crédito Global

**NO es por préstamo, es por asociado:**
```javascript
const associate = {
  id: 3,
  level: 'Gold',          // Bronze, Silver, Gold, Platinum, Diamond
  credit_limit: 500000,   // Límite total
  credit_used: 280000,    // En préstamos activos
  debt_balance: 50000,    // Deuda pendiente
  credit_available: null  // Calculado en tiempo real
};

// FÓRMULA CRÍTICA:
credit_available = credit_limit - credit_used - debt_balance
                 = 500,000 - 280,000 - 50,000
                 = 170,000

// ¿Puede aprobar préstamo de $100,000?
const canApprove = credit_available >= 100000;
// canApprove = 170,000 >= 100,000 = TRUE ✅
```

#### 🔄 Flujo de Crédito

**Al APROBAR préstamo:**
```javascript
// ANTES
credit_used = 280,000
credit_available = 170,000

// ACCIÓN: Aprobar préstamo de $100,000
credit_used += loan_amount;
credit_used = 280,000 + 100,000 = 380,000

// DESPUÉS
credit_used = 380,000
credit_available = 120,000 ⬇️
```

**Al RECIBIR pago:**
```javascript
// ANTES
credit_used = 380,000
credit_available = 120,000

// ACCIÓN: Cliente paga $2,768.33
credit_used -= payment_amount;
credit_used = 380,000 - 2,768.33 = 377,231.67

// DESPUÉS
credit_used = 377,231.67
credit_available = 122,768.33 ⬆️
```

**⚠️ IMPLICACIONES PARA EL FRONTEND:**
- Mostrar **barra de progreso** de crédito usado vs límite
- Al crear préstamo, validar **credit_available en tiempo real**
- Mostrar alerta si **crédito insuficiente**
- En dashboard del asociado, destacar **crédito disponible**
- Actualizar **credit_available** después de cada pago registrado

---

### 5. **DEUDA DEL ASOCIADO A LA EMPRESA** ⭐⭐

#### 💰 Concepto de debt_balance

**El asociado tiene deuda cuando:**
1. **Cliente no paga** → Asociado asume la deuda (es su responsabilidad)
2. **Reporte de cliente moroso** → Se convierte en deuda del asociado
3. **Liquidación parcial** → Paga menos de lo que debe en el periodo

**Estructura:**
```javascript
const associate = {
  id: 3,
  debt_balance: 50000,  // Deuda acumulada
  credit_available: null // Se reduce por deuda
};

// IMPACTO EN CRÉDITO DISPONIBLE:
credit_available = credit_limit - credit_used - debt_balance
                 = 500,000 - 280,000 - 50,000
                 = 170,000

// Si debt_balance aumenta:
debt_balance = 70,000 (antes 50,000, +$20,000)
credit_available = 500,000 - 280,000 - 70,000
                 = 150,000 ⬇️ (se reduce por aumento de deuda)
```

#### 📉 Tipos de Deuda

**1. Morosidad de Cliente:**
```javascript
// Cliente no paga → Se reporta como moroso
const defaultClient = {
  loan_id: 123,
  client_id: 45,
  associate_id: 3,
  overdue_amount: 15000,
  days_overdue: 45
};

// Al aprobar reporte:
associate.debt_balance += defaultClient.overdue_amount;
// debt_balance = 50,000 + 15,000 = 65,000
```

**2. Liquidación Parcial:**
```javascript
// Estado de cuenta del periodo
const statement = {
  cut_period_id: 5,
  total_due: 80000,        // Debe pagar
  total_paid: 60000,       // Pagó
  balance: 20000           // Falta
};

// Si no liquida el saldo:
associate.debt_balance += statement.balance;
// debt_balance = 65,000 + 20,000 = 85,000
```

**3. Pago de Deuda:**
```javascript
// Asociado hace abono específico a deuda
const debtPayment = {
  associate_id: 3,
  amount: 30000,
  type: 'debt_payment'
};

// Reduce deuda:
associate.debt_balance -= debtPayment.amount;
// debt_balance = 85,000 - 30,000 = 55,000

// Libera crédito:
credit_available = 500,000 - 280,000 - 55,000
                 = 165,000 ⬆️ (aumenta al reducir deuda)
```

**⚠️ IMPLICACIONES PARA EL FRONTEND:**
- Mostrar **debt_balance** prominente en dashboard del asociado
- Alerta visual si **debt_balance > 0**
- Permitir **pagos específicos de deuda** (no confundir con liquidaciones)
- En estados de cuenta, distinguir **liquidación vs pago de deuda**
- Mostrar impacto de deuda en **credit_available**
- Historial de **origen de la deuda** (cliente moroso, liquidación parcial, etc)

---

## 🛠️ CHECKLIST DE IMPLEMENTACIÓN FRONTEND

### ✅ Módulo de Préstamos

- [ ] **Formulario Crear Préstamo:**
  - [ ] Preview de **primer vencimiento** según fecha de aprobación
  - [ ] Selector de **rate profile** con tasas
  - [ ] Calculadora en tiempo real (capital → total con interés)
  - [ ] Validación de **credit_available del asociado**
  - [ ] Mostrar cronograma completo con alternancia 15 ↔ último día

- [ ] **Lista de Préstamos:**
  - [ ] Filtro por **cut_period_id** (periodo de corte)
  - [ ] Badge de estado (pending, approved, active, completed)
  - [ ] Mostrar **remaining_balance** actualizado
  - [ ] Indicador de **días de atraso** si aplica

- [ ] **Detalle de Préstamo:**
  - [ ] Cronograma completo con **dos calendarios visibles**
  - [ ] Distinguir **interés vs capital** en cada pago
  - [ ] Mostrar **comisión del asociado** en sección separada
  - [ ] Timeline de eventos (aprobación, pagos, morosidad)
  - [ ] Calcular y mostrar **tasa efectiva**

### ✅ Módulo de Pagos

- [ ] **Registro de Pago:**
  - [ ] Buscar préstamo por ID o cliente
  - [ ] Mostrar **payment_due_date vs payment_date** (calcular atraso)
  - [ ] Calcular automáticamente **remaining_balance**
  - [ ] Asignar **cut_period_id** correcto
  - [ ] Validar que pago corresponda al **periodo actual o pasado**

- [ ] **Lista de Pagos:**
  - [ ] Agrupar por **cut_period** (no por mes natural)
  - [ ] Filtro por estado (pending, paid, late, overdue)
  - [ ] Mostrar días de **atraso** con color
  - [ ] Indicador de **comisión calculada**

### ✅ Módulo de Asociados

- [ ] **Dashboard Asociado:**
  - [ ] **Barra de progreso:** credit_used / credit_limit
  - [ ] **Crédito disponible** prominente (con fórmula)
  - [ ] **Deuda pendiente** (debt_balance) si > 0
  - [ ] Lista de **préstamos activos** bajo su responsabilidad
  - [ ] Comisiones ganadas por periodo

- [ ] **Estados de Cuenta:**
  - [ ] Agrupar por **cut_period_id**
  - [ ] Total cobrado vs total esperado
  - [ ] **Saldo pendiente de liquidar**
  - [ ] Opción de **liquidar** o **pago parcial**

- [ ] **Gestión de Deuda:**
  - [ ] Historial de **origen de deuda** (clientes morosos, liquidaciones parciales)
  - [ ] Opción de **pago de deuda** específico
  - [ ] Impacto en **credit_available** en tiempo real

### ✅ Módulo de Reportes

- [ ] **Por Periodo de Corte:**
  - [ ] Selector de **cut_period_id**
  - [ ] Total de pagos recibidos en el periodo
  - [ ] Comisiones generadas
  - [ ] Morosidad por periodo

- [ ] **Por Asociado:**
  - [ ] Cartera total (**credit_used**)
  - [ ] Deuda acumulada (**debt_balance**)
  - [ ] Tasa de recuperación
  - [ ] Clientes morosos bajo su cargo

---

## 🚨 VALIDACIONES CRÍTICAS

### Frontend debe PREVENIR:

1. **Aprobar préstamo si:**
   ```javascript
   credit_available < loan_amount
   ```

2. **Registrar pago si:**
   ```javascript
   payment_date < loan.start_date  // Pago antes de inicio
   amount_paid > biweekly_payment * 1.5  // Pago excesivo (sospechoso)
   ```

3. **Cerrar periodo si:**
   ```javascript
   cutPeriod.status === 'closed'  // Ya cerrado
   hasOpenPayments === true       // Pagos pendientes sin registrar
   ```

4. **Liquidar estado de cuenta si:**
   ```javascript
   amountPaid > totalDue  // Pago excesivo
   cutPeriod.status !== 'open'  // Periodo no abierto
   ```

---

## 📚 REFERENCIAS TÉCNICAS

- **Función SQL clave**: `calculate_first_payment_date()`
- **Trigger**: `generate_payment_schedule()`
- **Tabla crítica**: `cut_periods` (periodos de corte)
- **Campo calculado**: `credit_available` (en tiempo real, NO guardado)

---

## ✅ SIGUIENTE PASO RECOMENDADO

**Antes de continuar con el frontend:**
1. ✅ Revisar este documento
2. ⏳ Crear **mocks actualizados** con lógica de doble calendario
3. ⏳ Actualizar **API mock** para soportar `cut_period_id`
4. ⏳ Implementar **calculadora de cronograma** en frontend
5. ⏳ Crear componentes de **preview de préstamo** con validaciones

---

**¿Listo para continuar? Confirma que entendiste estos 5 conceptos críticos.** 🚀
