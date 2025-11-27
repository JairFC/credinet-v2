# 📊 LÓGICA DE STATEMENTS Y PERIODOS - ARQUITECTURA COMPLETA

**Fecha**: 2025-11-25  
**Versión**: 2.0  
**Estado**: ✅ DOCUMENTACIÓN TÉCNICA DEFINITIVA

---

## 📋 ÍNDICE

1. [Estructura Jerárquica](#estructura-jerárquica)
2. [Flujo Completo](#flujo-completo)
3. [Generación de Statements](#generación-de-statements)
4. [Relación entre Entidades](#relación-entre-entidades)
5. [Queries Críticos](#queries-críticos)
6. [Frontend - Estructura Visual](#frontend---estructura-visual)

---

## 🏗️ ESTRUCTURA JERÁRQUICA

```
📅 CUT_PERIOD (Periodo General - 15 días)
│   id: 44
│   period_start_date: 2025-11-08
│   period_end_date: 2025-11-22
│   status: ACTIVE
│
├── 📄 ASSOCIATE_PAYMENT_STATEMENT (Estado de Cuenta - María)
│   │   id: 101
│   │   user_id: 3 (María)
│   │   cut_period_id: 44
│   │   total_payments_count: 15
│   │   total_amount_collected: $18,750.00
│   │   total_commission_owed: $468.75 (2.5%)
│   │   paid_amount: $0.00
│   │
│   └── 💰 PAYMENTS (15 pagos individuales de clientes de María)
│       ├── Payment #1: Cliente Ana - $1,250 → Comisión: $31.25
│       ├── Payment #2: Cliente Luis - $1,250 → Comisión: $31.25
│       └── ... (13 más)
│
├── 📄 ASSOCIATE_PAYMENT_STATEMENT (Estado de Cuenta - Ana)
│   │   id: 102
│   │   user_id: 5 (Ana)
│   │   cut_period_id: 44
│   │   total_payments_count: 8
│   │   total_amount_collected: $10,000.00
│   │   total_commission_owed: $250.00 (2.5%)
│   │
│   └── 💰 PAYMENTS (8 pagos de clientes de Ana)
│
└── 📄 ASSOCIATE_PAYMENT_STATEMENT (Estado de Cuenta - Laura)
    │   id: 103
    │   user_id: 7 (Laura)
    │   cut_period_id: 44
    │   total_payments_count: 22
    │   total_amount_collected: $27,500.00
    │   total_commission_owed: $687.50 (2.5%)
    │
    └── 💰 PAYMENTS (22 pagos de clientes de Laura)
```

---

## 🔄 FLUJO COMPLETO

### **1. Creación de Préstamo**

```sql
-- Admin crea préstamo con profile_code
INSERT INTO loans (
    user_id, associate_user_id, amount, term_biweeks,
    profile_code, status_id
) VALUES (
    100, 3, 10000, 12, 'standard', 1
);

-- Backend llama a calculate_loan_payment()
SELECT * FROM calculate_loan_payment(10000, 12, 'standard');

-- Resultado:
{
    interest_rate_percent: 3.75%,
    commission_rate_percent: 2.0%,
    biweekly_payment: $1,237.50,
    commission_per_payment: $24.75,
    associate_payment: $1,212.75
}

-- Backend actualiza el préstamo con valores calculados
UPDATE loans SET
    interest_rate = 3.75,
    commission_rate = 2.0,
    biweekly_payment = 1237.50,
    commission_per_payment = 24.75,
    associate_payment = 1212.75,
    total_payment = 14850.00
WHERE id = loan_id;
```

### **2. Aprobación de Préstamo**

```sql
-- Admin aprueba el préstamo
UPDATE loans SET
    status_id = (SELECT id FROM loan_statuses WHERE name = 'APPROVED'),
    approved_at = CURRENT_TIMESTAMP,
    approved_by = 1
WHERE id = loan_id;

-- ⚡ TRIGGER generate_payment_schedule() se ejecuta automáticamente:

1. Valida campos calculados existan
2. Calcula primera fecha: calculate_first_payment_date(approved_at)
3. Genera cronograma: generate_amortization_schedule(...)
4. Por cada pago:
   a. Busca cut_period que contenga la fecha de vencimiento
   b. Inserta en payments con todos los campos
```

### **3. Pagos se asignan a Periodos Automáticamente**

```sql
-- Al insertar cada pago, se busca su periodo:
SELECT id INTO v_period_id
FROM cut_periods
WHERE period_start_date <= payment_due_date
  AND period_end_date >= payment_due_date;

-- Ejemplo:
-- Pago vence: 15-nov-2025
-- Periodo 44: 08-nov a 22-nov
-- → payments.cut_period_id = 44
```

### **4. Generación de Statements (Manual o Automático)**

```sql
-- Opción A: Por periodo completo
SELECT generate_statements_for_period(44);

-- Opción B: Por asociado específico
SELECT generate_statement_for_associate(44, 3);
```

---

## 🔨 GENERACIÓN DE STATEMENTS

### **Función SQL Necesaria:**

```sql
CREATE OR REPLACE FUNCTION generate_statements_for_period(
    p_period_id INTEGER
)
RETURNS TABLE (
    statements_created INTEGER,
    associates_processed INTEGER
) AS $$
DECLARE
    v_period_end_date DATE;
    v_associate_record RECORD;
    v_statements_count INTEGER := 0;
BEGIN
    -- Obtener fecha de fin del periodo
    SELECT period_end_date INTO v_period_end_date
    FROM cut_periods
    WHERE id = p_period_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Periodo % no encontrado', p_period_id;
    END IF;
    
    -- Por cada asociado que tenga pagos en este periodo
    FOR v_associate_record IN
        SELECT 
            l.associate_user_id,
            COUNT(p.id) as payment_count,
            SUM(p.expected_amount) as total_collected,
            SUM(p.commission_amount) as total_commission,
            AVG(
                CASE 
                    WHEN p.expected_amount > 0 
                    THEN (p.commission_amount / p.expected_amount * 100)
                    ELSE 0 
                END
            ) as avg_commission_rate
        FROM payments p
        JOIN loans l ON p.loan_id = l.id
        WHERE p.cut_period_id = p_period_id
          AND l.associate_user_id IS NOT NULL
          AND p.expected_amount > 0
        GROUP BY l.associate_user_id
        HAVING COUNT(p.id) > 0
    LOOP
        -- Verificar si ya existe statement para este asociado y periodo
        IF NOT EXISTS (
            SELECT 1 FROM associate_payment_statements
            WHERE cut_period_id = p_period_id
              AND user_id = v_associate_record.associate_user_id
        ) THEN
            -- Crear statement
            INSERT INTO associate_payment_statements (
                cut_period_id,
                user_id,
                statement_number,
                total_payments_count,
                total_amount_collected,
                total_commission_owed,
                commission_rate_applied,
                status_id,
                generated_date,
                due_date,
                paid_amount,
                late_fee_amount,
                late_fee_applied
            ) VALUES (
                p_period_id,
                v_associate_record.associate_user_id,
                'ST-' || p_period_id || '-' || LPAD(v_associate_record.associate_user_id::TEXT, 5, '0'),
                v_associate_record.payment_count,
                v_associate_record.total_collected,
                v_associate_record.total_commission,
                COALESCE(v_associate_record.avg_commission_rate, 2.5),
                (SELECT id FROM statement_statuses WHERE name = 'GENERATED'),
                CURRENT_DATE,
                v_period_end_date + INTERVAL '7 days',
                0.00,
                0.00,
                false
            );
            
            v_statements_count := v_statements_count + 1;
            
            RAISE NOTICE 'Statement creado para asociado % - % pagos - $% comisión',
                v_associate_record.associate_user_id,
                v_associate_record.payment_count,
                v_associate_record.total_commission;
        ELSE
            RAISE NOTICE 'Statement ya existe para asociado % en periodo %',
                v_associate_record.associate_user_id, p_period_id;
        END IF;
    END LOOP;
    
    RETURN QUERY SELECT v_statements_count, 
                        (SELECT COUNT(DISTINCT l.associate_user_id)
                         FROM payments p
                         JOIN loans l ON p.loan_id = l.id
                         WHERE p.cut_period_id = p_period_id
                           AND l.associate_user_id IS NOT NULL)::INTEGER;
END;
$$ LANGUAGE plpgsql;
```

---

## 🔗 RELACIÓN ENTRE ENTIDADES

### **Diagrama de Relaciones:**

```sql
cut_periods (id: 44)
    ↓
    ├── associate_payment_statements (cut_period_id: 44, user_id: 3)
    │       ↑
    │       │ (agrupación lógica, no FK directa)
    │       │
    └── payments (cut_period_id: 44)
            ├── loan_id → loans (associate_user_id: 3)
            └── payment #1, #2, #3... para asociado 3
```

### **Query para Reconstruir Statement:**

```sql
-- Dado un periodo y un asociado, calcular su statement:
SELECT 
    :period_id as cut_period_id,
    :associate_id as user_id,
    COUNT(p.id) as total_payments_count,
    SUM(p.expected_amount) as total_amount_collected,
    SUM(p.commission_amount) as total_commission_owed,
    COALESCE(
        SUM(asp.payment_amount), 0
    ) as paid_amount
FROM payments p
JOIN loans l ON p.loan_id = l.id
LEFT JOIN associate_payment_statements aps 
    ON aps.cut_period_id = :period_id 
    AND aps.user_id = :associate_id
LEFT JOIN associate_statement_payments asp 
    ON asp.statement_id = aps.id
WHERE p.cut_period_id = :period_id
  AND l.associate_user_id = :associate_id
GROUP BY aps.id;
```

---

## 💡 QUERIES CRÍTICOS

### **1. Listar todos los statements de un periodo:**

```sql
SELECT 
    aps.id,
    aps.user_id,
    u.first_name || ' ' || u.last_name as associate_name,
    aps.statement_number,
    aps.total_payments_count,
    aps.total_amount_collected,
    aps.total_commission_owed,
    aps.paid_amount,
    aps.late_fee_amount,
    (aps.total_commission_owed + aps.late_fee_amount - COALESCE(aps.paid_amount, 0)) as remaining_amount,
    ss.name as status_name,
    aps.due_date
FROM associate_payment_statements aps
JOIN users u ON u.id = aps.user_id
JOIN statement_statuses ss ON ss.id = aps.status_id
WHERE aps.cut_period_id = :period_id
ORDER BY u.last_name, u.first_name;
```

### **2. Ver pagos individuales de un statement:**

```sql
SELECT 
    p.id,
    p.payment_number,
    l.user_id as client_id,
    u.first_name || ' ' || u.last_name as client_name,
    p.expected_amount,
    p.commission_amount,
    p.associate_payment,
    p.payment_due_date,
    ps.name as status_name
FROM payments p
JOIN loans l ON p.loan_id = l.id
JOIN users u ON u.id = l.user_id
JOIN payment_statuses ps ON ps.id = p.status_id
WHERE p.cut_period_id = :period_id
  AND l.associate_user_id = :associate_id
ORDER BY p.payment_due_date, p.payment_number;
```

### **3. Estadísticas de un periodo:**

```sql
SELECT 
    cp.id,
    cp.period_start_date,
    cp.period_end_date,
    COUNT(DISTINCT aps.user_id) as associates_count,
    COUNT(DISTINCT aps.id) as statements_count,
    SUM(aps.total_payments_count) as total_payments,
    SUM(aps.total_amount_collected) as total_collected,
    SUM(aps.total_commission_owed) as total_commission,
    SUM(aps.paid_amount) as total_paid,
    SUM(aps.late_fee_amount) as total_late_fees
FROM cut_periods cp
LEFT JOIN associate_payment_statements aps ON aps.cut_period_id = cp.id
WHERE cp.id = :period_id
GROUP BY cp.id;
```

---

## 🎨 FRONTEND - ESTRUCTURA VISUAL

### **Vista Principal: Periodos**

```jsx
<PeriodosPage>
  <PeriodList>
    {periods.map(period => (
      <PeriodCard 
        period={period}
        onExpand={() => loadStatements(period.id)}
      >
        <PeriodHeader>
          Periodo {period.cut_number}
          {period.period_start_date} - {period.period_end_date}
          Status: {period.status}
        </PeriodHeader>
        
        {expanded && (
          <StatementsSection>
            <h3>Estados de Cuenta ({statements.length} asociados)</h3>
            {statements.map(stmt => (
              <StatementCard 
                key={stmt.id}
                statement={stmt}
                onExpand={() => loadPayments(stmt.id)}
              >
                <StatementHeader>
                  {stmt.associate_name}
                  Pagos: {stmt.total_payments_count}
                  Comisión: ${stmt.total_commission_owed}
                  Estado: {stmt.status_name}
                </StatementHeader>
                
                {expandedStatement === stmt.id && (
                  <PaymentsTable>
                    {payments.map(payment => (
                      <PaymentRow key={payment.id}>
                        {payment.client_name}
                        ${payment.expected_amount}
                        Comisión: ${payment.commission_amount}
                        {payment.status_name}
                      </PaymentRow>
                    ))}
                  </PaymentsTable>
                )}
              </StatementCard>
            ))}
          </StatementsSection>
        )}
      </PeriodCard>
    ))}
  </PeriodList>
</PeriodosPage>
```

### **Flujo de Navegación:**

```
1. PeriodosPage
   └── Lista de periodos (44, 43, 42...)
       └── [Expandir Periodo 44]
           └── Lista de Statements (María, Ana, Laura...)
               └── [Expandir Statement de María]
                   └── Tabla de 15 pagos individuales
                       └── [Ver detalle de pago]
```

---

## 🎯 PRÓXIMOS PASOS

### **Backend:**

1. ✅ Corregir endpoint `/cut-periods/{id}/statements`
2. ⏳ Crear función `generate_statements_for_period()`
3. ⏳ Crear endpoint `POST /cut-periods/{id}/generate-statements`
4. ⏳ Agregar endpoint `GET /statements/{id}/payments`

### **Frontend:**

1. ✅ Corregir mapeo de datos en `PeriodosConStatementsPage`
2. ⏳ Implementar vista jerárquica (Periodo → Statements → Payments)
3. ⏳ Agregar botón "Generar Statements" por periodo
4. ⏳ Mejorar visualización con accordions/expansión

### **Base de Datos:**

1. ⏳ Agregar índice: `CREATE INDEX idx_payments_period_associate ON payments(cut_period_id, loan_id)`
2. ⏳ Considerar vista materializada para performance

**FIN DEL DOCUMENTO**
