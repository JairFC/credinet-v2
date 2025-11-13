# 🎯 FASE 6 MVP - SCOPE DEFINIDO

## ✅ **LO QUE VAMOS A IMPLEMENTAR AHORA (MVP)**

---

## 📊 **FRONTEND - StatementsPage:**

### **1. Vista Principal (Statement Card):**

```jsx
<StatementCard>
  {/* INFORMACIÓN BÁSICA */}
  <StatementHeader>
    Período: 23-feb al 7-mar (Corte 2025-Q04)
    Número: STMT-2025-Q01-0003
    Estado: GENERATED / PAID / PARTIAL_PAID
  </StatementHeader>

  {/* RESUMEN FINANCIERO */}
  <FinancialSummary>
    📊 COBROS DEL PERÍODO:
    Total Cobrado (clientes): $4,125 ← total_amount_collected ⭐
    Comisión Ganada (5%): $206.25 ← total_commission_owed
    ────────────────────────────────
    Debe Entregar: $3,918.75 ← (collected - commission)

    💰 LIQUIDACIÓN:
    Abonos Realizados: $2,000 ← paid_amount
    Saldo Pendiente: $1,918.75 ← (debe_entregar - paid)

    ⚠️  MORA (si aplica):
    Mora 30%: $61.88 ← (si paid_amount = 0 al vencimiento)

    📦 DEUDA ANTERIOR:
    Adeudo Acumulado: $1,200 ← debt_balance (de associate_profiles)

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    TOTAL ADEUDADO: $3,179.88
    = $1,918.75 (pendiente período)
    + $61.88 (mora)
    + $1,200 (deuda anterior)
    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  </FinancialSummary>

  {/* ACCIONES */}
  <Actions>
    <Button onClick={handleRegistrarAbono}>
      💰 Registrar Abono
    </Button>
    <Button onClick={handleVerDesglose}>
      📋 Ver Desglose de Pagos
    </Button>
  </Actions>
</StatementCard>
```

### **2. Modal: Registrar Abono**

```jsx
<ModalRegistrarAbono>
  <Input 
    label="Monto del Abono"
    type="number"
    placeholder="$5,343.75"
  />
  <Input 
    label="Fecha del Abono"
    type="date"
  />
  <Select 
    label="Método de Pago"
    options={['Transferencia', 'Efectivo', 'Cheque']}
  />
  <Input 
    label="Referencia"
    placeholder="TRANSF-XYZ123"
  />
  <Textarea 
    label="Notas (opcional)"
  />

  {/* SIMPLE - Solo aplicar al statement */}
  <Button onClick={handleGuardarAbono}>
    Guardar Abono
  </Button>
</ModalRegistrarAbono>
```

### **3. Tabla de Desglose de Pagos:**

```jsx
<TablaDesglosePagos>
  <thead>
    <tr>
      <th>Contrato</th>
      <th>Cliente</th>
      <th>Préstamo</th>
      <th>No. Pago</th>
      <th>Cliente Paga</th>
      <th>Comisión</th>
      <th>Asociado Debe</th>
      <th>Estado</th>
    </tr>
  </thead>
  <tbody>
    {payments.map(payment => (
      <tr key={payment.id}>
        <td>{payment.contract_number}</td>
        <td>{payment.client_name}</td>
        <td>${formatMoney(payment.loan_amount)}</td>
        <td>{payment.payment_number}/{payment.total_payments}</td>
        <td>${formatMoney(payment.expected_amount)}</td>
        <td>${formatMoney(payment.commission_amount)}</td>
        <td>${formatMoney(payment.associate_payment)}</td>
        <td><Badge status={payment.status_id} /></td>
      </tr>
    ))}
  </tbody>
  <tfoot>
    <tr>
      <td colSpan="4">TOTALES:</td>
      <td>${formatMoney(totals.expected_amount)}</td>
      <td>${formatMoney(totals.commission)}</td>
      <td>${formatMoney(totals.associate_payment)}</td>
      <td></td>
    </tr>
  </tfoot>
</TablaDesglosePagos>
```

---

## 🔧 **BACKEND - Endpoints Necesarios:**

### **1. GET /api/statements (ya existe)**
```javascript
// Retorna lista de statements del asociado
Response: {
  statements: [
    {
      id, statement_number, cut_period_id,
      total_payments_count,
      total_amount_collected, ⭐
      total_commission_owed,
      paid_amount,
      late_fee_amount,
      status_id,
      due_date,
      // ... otros campos
    }
  ]
}
```

### **2. GET /api/statements/:id (ya existe)**
```javascript
// Retorna detalle de un statement
Response: {
  statement: { ... },
  cut_period: {
    period_start_date,
    period_end_date,
    cut_number
  },
  associate_profile: {
    debt_balance ⭐
  }
}
```

### **3. GET /api/statements/:id/payments (NUEVO)**
```javascript
// Retorna desglose de pagos del statement
Response: {
  payments: [
    {
      id,
      payment_number,
      expected_amount, ⭐
      commission_amount, ⭐
      associate_payment, ⭐
      balance_remaining,
      payment_due_date,
      status_id,
      loan: {
        id,
        amount,
        contract: {
          document_number
        },
        client: {
          full_name
        }
      }
    }
  ]
}
```

### **4. POST /api/statements/:id/payments (NUEVO)**
```javascript
// Registra abono al statement
Request: {
  payment_amount: 2000.00,
  payment_date: "2025-03-15",
  payment_method_id: 1,
  payment_reference: "TRANSF-XYZ",
  notes: "Abono parcial"
}

Response: {
  payment: { ... },
  statement: {
    paid_amount: 2000.00, // actualizado
    status_id: 2 // PARTIAL_PAID
  }
}
```

---

## 📦 **BACKEND - DTOs Necesarios:**

### **StatementResponseDTO (actualizar):**
```python
class StatementResponseDTO(BaseModel):
    id: int
    statement_number: str
    cut_period_id: int
    
    # ⭐ Campos financieros
    total_payments_count: int
    total_amount_collected: Decimal  # ⭐ AGREGAR
    total_commission_owed: Decimal
    commission_rate_applied: Decimal
    
    # Liquidación
    paid_amount: Optional[Decimal]
    late_fee_amount: Decimal
    
    # Estado
    status_id: int
    status_name: str
    
    # Fechas
    generated_date: date
    due_date: date
    paid_date: Optional[date]
    
    # ⭐ Relaciones
    cut_period: CutPeriodDTO
    associate_profile: Optional[AssociateProfileSummaryDTO]  # ⭐ AGREGAR
    
    # Calculated
    @property
    def associate_payment_total(self) -> Decimal:
        """Monto que debe entregar (collected - commission)"""
        return self.total_amount_collected - self.total_commission_owed
    
    @property
    def pending_amount(self) -> Decimal:
        """Saldo pendiente del statement"""
        paid = self.paid_amount or Decimal('0.00')
        return self.associate_payment_total - paid
    
    @property
    def total_debt(self) -> Decimal:
        """Deuda total (statement + mora + deuda anterior)"""
        debt_balance = Decimal('0.00')
        if self.associate_profile:
            debt_balance = self.associate_profile.debt_balance
        
        return self.pending_amount + self.late_fee_amount + debt_balance
```

### **PaymentDetailDTO (nuevo):**
```python
class PaymentDetailDTO(BaseModel):
    id: int
    payment_number: int
    
    # ⭐ Campos financieros
    expected_amount: Decimal  # Lo que cliente paga
    commission_amount: Decimal  # Comisión del asociado
    associate_payment: Decimal  # Lo que asociado entrega
    
    balance_remaining: Decimal
    payment_due_date: date
    
    # Estado
    status_id: int
    status_name: str
    
    # Relaciones
    loan: LoanSummaryDTO
    contract: ContractSummaryDTO
    client: UserSummaryDTO
```

### **AssociateProfileSummaryDTO (nuevo):**
```python
class AssociateProfileSummaryDTO(BaseModel):
    id: int
    user_id: int
    debt_balance: Decimal  # ⭐ Deuda acumulada
    credit_used: Decimal
    credit_limit: Decimal
    credit_available: Decimal
```

---

## 🎨 **FRONTEND - Componentes:**

### **Archivos a modificar:**

1. **`/src/pages/StatementsPage.jsx`** (ya existe)
   - Agregar display de `total_amount_collected`
   - Agregar display de `debt_balance`
   - Cambiar cálculo de totales
   - Agregar botón "Ver Desglose"
   - Agregar botón "Registrar Abono"

2. **`/src/components/statements/ModalRegistrarAbono.jsx`** (NUEVO)
   - Form para registrar abono
   - Validaciones de monto
   - Llamada a API POST /statements/:id/payments

3. **`/src/components/statements/TablaDesglosePagos.jsx`** (NUEVO)
   - Tabla con pagos individuales
   - Totales al pie
   - Badges de estado

4. **`/src/services/statementsService.js`** (actualizar)
   - Agregar `getStatementPayments(id)`
   - Agregar `registerPayment(id, data)`

---

## ✅ **ALCANCE DEL MVP:**

### **LO QUE SÍ VAMOS A HACER:**

```
✅ Mostrar total_amount_collected (suma de expected_amount)
✅ Mostrar total_commission_owed (suma de commission_amount)
✅ Calcular associate_payment_total (collected - commission)
✅ Mostrar debt_balance del asociado
✅ Calcular total_debt (pending + late_fee + debt_balance)
✅ Tabla desglosada de pagos individuales
✅ Modal para registrar abonos al statement
✅ Actualizar paid_amount y status del statement
```

### **LO QUE NO VAMOS A HACER (Pendiente):**

```
❌ Marcar pagos individuales como PAID/PAID_NOT_REPORTED (manual)
❌ Diferenciar abonos a deuda vs abonos a statement
❌ Cerrar períodos automáticamente
❌ Marcar clientes como morosos
❌ Sistema de convenios de pago
❌ Liquidación parcial con distribución
❌ Estados adicionales (UNPAID_ACCRUED_DEBT)
```

---

## 🚀 **PLAN DE IMPLEMENTACIÓN:**

### **PASO 1: Backend (DTOs y Endpoints)**
1. Actualizar `StatementResponseDTO` con campos faltantes
2. Crear `PaymentDetailDTO`
3. Crear `AssociateProfileSummaryDTO`
4. Implementar endpoint `GET /statements/:id/payments`
5. Implementar endpoint `POST /statements/:id/payments`

### **PASO 2: Frontend (StatementsPage)**
1. Actualizar display de totales (usar `total_amount_collected`)
2. Agregar sección de deuda anterior (`debt_balance`)
3. Agregar cálculo de `total_debt`
4. Crear botón "Ver Desglose"

### **PASO 3: Frontend (Componentes Nuevos)**
1. Crear `ModalRegistrarAbono.jsx`
2. Crear `TablaDesglosePagos.jsx`
3. Integrar modales en `StatementsPage`

### **PASO 4: Servicio**
1. Actualizar `statementsService.js`
2. Agregar funciones de desglose y abonos

### **PASO 5: Testing**
1. Probar display de totales
2. Probar registro de abonos
3. Probar actualización de status
4. Verificar cálculos matemáticos

---

## 📝 **DOCUMENTACIÓN PARA FUTURO:**

Casos especiales documentados en:
- **CASOS_ESPECIALES_PENDIENTES.md**: Análisis completo de pendientes
- **LOGICA_CIERRE_DEFINITIVA_V3.md**: Lógica de cierre (MVP simplificado)

---

¿Estás de acuerdo con este alcance de MVP? ¿Procedemos con la implementación? 🚀
