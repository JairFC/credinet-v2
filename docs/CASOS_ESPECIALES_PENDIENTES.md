# 🎯 ANÁLISIS CRÍTICO: CASOS ESPECIALES Y LÓGICA PENDIENTE

## ⚠️ **PUNTOS CRÍTICOS IDENTIFICADOS POR EL USUARIO:**

---

## 1️⃣ **MARCADO DE MOROSIDAD: ¿Pago o Cliente?**

### **OBSERVACIÓN DEL USUARIO:**
> "Dices 'admin marcó cliente como MOROSO', pero más bien sería el pago, aunque por consecuencia el cliente también debería marcarse"

### **ANÁLISIS:**

```
CASO A: Marcar PAGO como moroso
├─ Acción: Admin marca pago #3 del préstamo 12345 como PAID_NOT_REPORTED
├─ Efecto: Solo ESE pago va a deuda ($1,250)
└─ Pregunta: ¿El cliente tiene otros préstamos con pagos al día?

CASO B: Marcar CLIENTE como moroso
├─ Acción: Admin marca cliente "Juan Pérez" como moroso
├─ Efecto: ¿TODOS los pagos de TODOS sus préstamos van a deuda?
└─ Pregunta: ¿O solo los del período actual?

CASO C: Cascada automática
├─ Admin marca pago #3 como moroso
├─ Sistema detecta: Juan tiene 5 préstamos activos
├─ Sistema pregunta: "¿Marcar TODOS los pagos de Juan como morosos?"
└─ Admin decide: Sí/No
```

### **PROPUESTA:**

#### **Opción 1: Granular (Pago por pago)**
```sql
-- Tabla: payments
UPDATE payments
SET status_id = (SELECT id FROM payment_statuses WHERE name = 'PAID_NOT_REPORTED'),
    marked_as_defaulter_by = admin_user_id,
    marked_as_defaulter_at = CURRENT_TIMESTAMP,
    defaulter_notes = 'Cliente no localizables'
WHERE id = pago_id;

-- NO afecta otros pagos del cliente
```

#### **Opción 2: Cliente completo**
```sql
-- Tabla: clients (nueva columna)
ALTER TABLE users ADD COLUMN is_defaulter BOOLEAN DEFAULT false;
ALTER TABLE users ADD COLUMN defaulter_marked_at TIMESTAMP;
ALTER TABLE users ADD COLUMN defaulter_notes TEXT;

-- Al marcar cliente como moroso:
UPDATE users SET is_defaulter = true WHERE id = client_id;

-- Efecto en pagos:
UPDATE payments
SET status_id = 'PAID_NOT_REPORTED'
WHERE loan_id IN (
  SELECT id FROM loans WHERE user_id = client_id
)
AND cut_period_id = periodo_actual;
```

#### **Opción 3: Híbrida (Recomendada)**
```
1. Admin puede marcar PAGO individual como moroso
2. Admin puede marcar CLIENTE completo como moroso
   → Afecta TODOS los pagos del período actual
3. Sistema pregunta confirmación si cliente tiene múltiples pagos
```

---

## 2️⃣ **ASOCIADO NO LIQUIDA → ¿Va a Deuda?**

### **OBSERVACIÓN DEL USUARIO:**
> "Creo que debería haber otro estado donde pasa a la deuda del asociado, pero no fue reportado... habrá casos especiales donde el asociado no liquide y pase a su deuda"

### **ANÁLISIS DEL ESCENARIO:**

```
ESCENARIO:
María tiene statement 2025-Q04:
- total_amount_collected: $5,625
- total_commission_owed: $281.25
- associate_payment_total: $5,343.75
- due_date: 22-mar

POSIBILIDADES:

A) María liquida completo (FLUJO NORMAL):
   ✅ paid_amount: $5,343.75
   ✅ Al cerrar: Todos → PAID_BY_ASSOCIATE
   ✅ debt_balance: 0

B) María NO liquida NADA (CASO ESPECIAL 1):
   ⚠️  paid_amount: 0
   ⚠️  Al cerrar: ¿Qué hacer?
   ❓ ¿Todos los pagos van a deuda?
   ❓ ¿O se aplica mora del 30%?

C) María liquida PARCIAL (CASO ESPECIAL 2):
   ⚠️  paid_amount: $2,000 (de $5,343.75)
   ⚠️  Al cerrar: ¿Qué hacer?
   ❓ ¿Se aplica a pagos específicos?
   ❓ ¿O se distribuye proporcional?

D) María NO liquida Y tiene mora aplicada:
   🚨 paid_amount: 0
   🚨 late_fee_amount: $84.38 (30% de $281.25)
   ❓ ¿Va TODO a deuda? ($5,343.75 + $84.38)
   ❓ ¿O solo la mora?
```

### **PROBLEMA IDENTIFICADO:**

```
CONFUSIÓN:
1. PAID_BY_ASSOCIATE actualmente significa: "Cubierto por liquidación"
2. PERO: ¿Qué pasa si NO hubo liquidación?
3. ¿Necesitamos un estado: "UNPAID_ACCRUED_DEBT"?
```

### **PROPUESTA DE ESTADOS ADICIONALES:**

```sql
-- Nuevo estado:
INSERT INTO payment_statuses (name, description) VALUES
('UNPAID_ACCRUED_DEBT', 'Pago no liquidado por asociado, acumulado en deuda');

-- Lógica al cerrar:
IF statement.paid_amount = 0 THEN
  -- Asociado NO liquidó NADA
  UPDATE payments
  SET status_id = 'UNPAID_ACCRUED_DEBT'
  WHERE cut_period_id = X
    AND status_id NOT IN ('PAID', 'PAID_NOT_REPORTED');
  
  -- TODOS van a debt_balance
  INSERT INTO associate_debt_breakdown (...)
  SELECT ... WHERE status_id IN ('UNPAID_ACCRUED_DEBT', 'PAID_NOT_REPORTED');
  
ELSE IF statement.paid_amount < statement.associate_payment_total THEN
  -- Asociado liquidó PARCIAL
  -- ❓ ¿Cómo distribuir?
  
ELSE
  -- Asociado liquidó COMPLETO
  UPDATE payments
  SET status_id = 'PAID_BY_ASSOCIATE'
  WHERE cut_period_id = X
    AND status_id NOT IN ('PAID', 'PAID_NOT_REPORTED');
END IF;
```

---

## 3️⃣ **TIPOS DE ABONOS: Deuda vs Statement Actual**

### **OBSERVACIÓN DEL USUARIO:**
> "Hay 2 tipos de abonos: a la deuda que tiene y al saldo del corte actual. Tenemos que diferenciar muy bien esos 2 abonos"

### **ANÁLISIS:**

```
SITUACIÓN DE MARÍA:
├─ Deuda acumulada (períodos anteriores): $3,500 (debt_balance)
├─ Statement actual (2025-Q04): $5,343.75 (associate_payment_total)
└─ TOTAL ADEUDADO: $8,843.75

MARÍA HACE ABONO: $2,000

PREGUNTA CRÍTICA:
¿A QUÉ se aplica este abono?

OPCIÓN A: Prioridad a Statement Actual
  ✅ Abono $2,000 → Statement 2025-Q04
  ⚠️  Deuda anterior: $3,500 (sin cambios)
  ⚠️  Statement: $3,343.75 pendiente
  
OPCIÓN B: Prioridad a Deuda (FIFO)
  ✅ Abono $2,000 → debt_balance
  ⚠️  Deuda anterior: $1,500 (reducida)
  ⚠️  Statement: $5,343.75 (sin cambios)
  
OPCIÓN C: Usuario decide
  📝 Modal: "¿Aplicar a: [Deuda anterior] [Statement actual]?"
  ✅ Usuario selecciona destino
```

### **TABLAS NECESARIAS:**

#### **Tabla Actual: `associate_statement_payments`**
```sql
-- Solo registra abonos al STATEMENT
CREATE TABLE associate_statement_payments (
    id SERIAL PRIMARY KEY,
    statement_id INTEGER REFERENCES associate_payment_statements(id),
    payment_amount DECIMAL(12,2),
    payment_date DATE,
    payment_method_id INTEGER,
    payment_reference VARCHAR(100),
    registered_by INTEGER REFERENCES users(id),
    notes TEXT
);
```

#### **Tabla Nueva Propuesta: `associate_debt_payments`**
```sql
-- Registra abonos a la DEUDA ACUMULADA
CREATE TABLE associate_debt_payments (
    id SERIAL PRIMARY KEY,
    associate_profile_id INTEGER REFERENCES associate_profiles(id),
    payment_amount DECIMAL(12,2),
    payment_date DATE,
    payment_method_id INTEGER,
    payment_reference VARCHAR(100),
    
    -- ⭐ Tracking de qué deudas se liquidaron (FIFO)
    applied_to_debt_breakdown_ids INTEGER[], -- Array de IDs liquidados
    
    registered_by INTEGER REFERENCES users(id),
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE associate_debt_payments IS 
'Abonos del asociado aplicados a DEUDA ACUMULADA (debt_balance). Diferente de abonos a statements actuales.';
```

### **FLUJO PROPUESTO:**

```
ADMIN REGISTRA ABONO:

PASO 1: Identificar totales
  ├─ debt_balance: $3,500
  ├─ statement_pending: $5,343.75
  └─ TOTAL: $8,843.75

PASO 2: Admin ingresa abono
  ├─ Monto: $2,000
  ├─ Fecha: 15-mar
  ├─ Referencia: "TRANSF-XYZ"
  └─ Destino: [Seleccionar]

PASO 3: Modal de selección
  ┌─────────────────────────────────────────────┐
  │ ¿A qué aplicar el abono de $2,000?          │
  ├─────────────────────────────────────────────┤
  │ ( ) Deuda acumulada ($3,500)                │
  │     └─ Prioridad FIFO (pagos más antiguos)  │
  │                                              │
  │ (•) Statement actual 2025-Q04 ($5,343.75)   │
  │     └─ Reducir saldo del período actual     │
  │                                              │
  │ ( ) Dividir proporcional                    │
  │     └─ 39.5% deuda, 60.5% statement         │
  └─────────────────────────────────────────────┘

PASO 4A: Si selecciona DEUDA
  INSERT INTO associate_debt_payments (...)
  VALUES ($2,000, ...);
  
  -- Liquidar deudas FIFO
  UPDATE associate_debt_breakdown
  SET is_liquidated = true,
      liquidated_date = CURRENT_DATE
  WHERE associate_profile_id = X
    AND is_liquidated = false
  ORDER BY created_at ASC
  LIMIT (hasta cubrir $2,000);
  
  -- Actualizar debt_balance
  UPDATE associate_profiles
  SET debt_balance = debt_balance - $2,000;

PASO 4B: Si selecciona STATEMENT
  INSERT INTO associate_statement_payments (...)
  VALUES ($2,000, ...);
  
  -- Actualizar statement
  UPDATE associate_payment_statements
  SET paid_amount = paid_amount + $2,000;
```

---

## 📋 **RESUMEN DE PENDIENTES CRÍTICOS:**

### **🔴 ALTA PRIORIDAD (Definir YA):**

1. **Marcado de morosidad:**
   - ¿Por pago individual o por cliente completo?
   - Recomendación: Híbrido (ambos)

2. **Tipos de abonos:**
   - ¿Cómo diferenciar abono a deuda vs statement?
   - Recomendación: Tablas separadas + modal de selección

3. **Asociado NO liquida:**
   - ¿Qué estado tienen los pagos?
   - ¿Van TODOS a deuda?
   - Recomendación: Nuevo estado `UNPAID_ACCRUED_DEBT`

### **🟡 MEDIA PRIORIDAD (Definir después):**

4. **Liquidación parcial:**
   - ¿Cómo distribuir abonos parciales?
   - FIFO, proporcional, o manual?

5. **Mora sobre deuda:**
   - ¿Se cobra mora sobre debt_balance?
   - ¿O solo sobre statements actuales?

### **🟢 BAJA PRIORIDAD (Puede esperar):**

6. **Sistema de versiones** (ya documentado)
7. **Reportes de morosidad** (flujo completo)
8. **Convenios de pago** (para deudas grandes)

---

## 🎯 **PROPUESTA DE DECISIÓN:**

### **PARA CONTINUAR CON FASE 6 (MVP):**

```
✅ IMPLEMENTAR AHORA:
1. Mostrar total_amount_collected en frontend
2. Mostrar debt_balance en frontend
3. Tabla desglosada de pagos
4. Registro de abonos a statements (tabla actual)

⚠️  MARCAR COMO PENDIENTE:
1. Marcado de pagos individuales (PAID / PAID_NOT_REPORTED)
2. Diferenciación de abonos (deuda vs statement)
3. Estado UNPAID_ACCRUED_DEBT
4. Liquidación parcial de statements

📝 CONTINUAR CON:
- Logica actual (PAID_BY_ASSOCIATE al cerrar)
- debt_balance solo para casos manuales
- Sin cerrar períodos automáticamente (manual por admin)
```

### **PARA FASE POSTERIOR (Post-MVP):**

```
🔮 IMPLEMENTAR DESPUÉS:
1. Sistema completo de marcado de morosidad
2. Tablas separadas de abonos
3. Estados adicionales de pagos
4. Cierre automático de períodos
5. Sistema de convenios de pago
```

---

## ✅ **RECOMENDACIÓN FINAL:**

> **"Continuemos con la lógica actual para Fase 6 MVP, pero documentemos claramente estos casos especiales como PENDIENTES en un documento separado para implementar en fases posteriores."**

¿Estás de acuerdo en continuar con MVP y dejar estos casos especiales documentados para después? 🎯

O prefieres que definamos TODA la lógica ahora antes de implementar el frontend? 🤔
