# 📊 LÓGICA COMPLETA DEL SISTEMA - DOCUMENTACIÓN REAL

**Fecha:** 25 Noviembre 2025  
**Estado:** ✅ CORREGIDO - Basado en análisis de código y datos legacy reales

---

## 🎯 CORRECCIÓN DE CONCEPTOS ERRÓNEOS

### ❌ Conceptos INCORRECTOS (documentación previa)

1. **ERROR:** "El asociado gana 5% de comisión por cada pago"
2. **ERROR:** "Los statements son estados de cuenta que el asociado recibe"
3. **ERROR:** "La comisión es lo que el asociado cobra al cliente"

### ✅ Conceptos CORRECTOS (sistema real)

1. **CORRECTO:** CrediCuenta cobra comisión AL asociado (2.5% del pago del cliente)
2. **CORRECTO:** Los statements son estados de cuenta que el asociado DEBE PAGAR a CrediCuenta
3. **CORRECTO:** La comisión es lo que el asociado PAGA a CrediCuenta por usar el servicio

---

## 📖 GLOSARIO DE TÉRMINOS CLAVE

### Doble Calendario

El sistema maneja **DOS calendarios diferentes pero sincronizados**:

#### 1️⃣ **Calendario del Cliente** (Vencimientos de Pagos)
- **Días de pago:** 15 y último día del mes
- **Alternancia:** 15 → último día → 15 → último día...
- **Ejemplo:** Pago 1 (31 Ene), Pago 2 (15 Feb), Pago 3 (28 Feb)

#### 2️⃣ **Calendario Administrativo** (Periodos de Corte)
- **Periodos:** Día 8-22 y día 23-7
- **Propósito:** Agrupar pagos que vencen dentro del mismo periodo
- **Ejemplo:** Periodo 26 (23 Ene - 7 Feb) contiene el pago que vence el 31 Ene

### Términos Financieros

| Término | Significado Real | Ejemplo ($5000 @ 12Q) |
|---------|------------------|----------------------|
| **Capital** | Monto prestado al cliente | $5,000 |
| **Pago Quincenal (pago_cliente)** | Lo que el cliente paga cada quincena | $633 |
| **Total a Pagar** | Capital + intereses | $7,596 |
| **Interés Total** | Ganancia de CrediCuenta | $2,596 |
| **Comisión por Pago** | Lo que cobra CrediCuenta al asociado | $15.83 (2.5% de $633) |
| **Pago al Asociado** | Lo que recibe el asociado | $617.17 ($633 - $15.83) |
| **Comisión Total** | Total que paga el asociado | $189.96 ($15.83 × 12) |

---

## 🔄 FLUJO COMPLETO DEL SISTEMA

### 1. Creación del Préstamo

```
Cliente solicita $5,000
↓
Admin/Asociado crea préstamo usando profile_code='legacy'
↓
Sistema consulta legacy_payment_table
  → $5000 @ 12Q = $633 quincenal
↓
Se calcula:
  - biweekly_payment = $633
  - total_payment = $7,596 ($633 × 12)
  - commission_per_payment = $15.83 (2.5% de $633)
  - associate_payment = $617.17 ($633 - $15.83)
```

### 2. Aprobación del Préstamo

```
Admin aprueba préstamo el 10 Enero 2025
↓
Trigger: handle_loan_approval_status()
  → SET approved_at = CURRENT_TIMESTAMP
↓
Trigger: generate_payment_schedule()
  ↓
  Paso 1: Calcular primera fecha de pago
    calculate_first_payment_date('2025-01-10')
    → Aprobado día 10 (entre 8-22)
    → Primera fecha = último día mes actual = 31 Ene 2025
  
  Paso 2: Generar tabla de amortización
    generate_amortization_schedule(5000, 633, 12, 2.5, '2025-01-31')
    → Genera 12 filas con fechas alternadas (15 ↔ último día)
  
  Paso 3: Insertar pagos en tabla payments
    Para cada periodo de la amortización:
      → Buscar cut_period donde fecha_pago BETWEEN start_date AND end_date
      → Insertar pago con cut_period_id correspondiente
```

### 3. Tabla de Amortización Generada

| # | Fecha Vencimiento | Pago Cliente | Interés | Capital | Saldo | Comisión | Pago Asociado | Periodo Admin |
|---|-------------------|--------------|---------|---------|-------|----------|---------------|---------------|
| 1 | 31 Ene 2025 | $633 | $216.33 | $416.67 | $4,583.33 | **$15.83** | **$617.17** | 26 (23 Ene-7 Feb) |
| 2 | 15 Feb 2025 | $633 | $216.33 | $416.67 | $4,166.66 | **$15.83** | **$617.17** | 27 (8 Feb-22 Feb) |
| 3 | 28 Feb 2025 | $633 | $216.33 | $416.67 | $3,749.99 | **$15.83** | **$617.17** | 28 (23 Feb-7 Mar) |
| 4 | 15 Mar 2025 | $633 | $216.33 | $416.67 | $3,333.32 | **$15.83** | **$617.17** | 29 (8 Mar-22 Mar) |
| ... | ... | ... | ... | ... | ... | ... | ... | ... |
| 12 | 15 Jul 2025 | $633 | $216.33 | $416.67 | $0.00 | **$15.83** | **$617.17** | 37 (8 Jul-22 Jul) |

**TOTALES:**
- Cliente paga: **$7,596** ($633 × 12)
- CrediCuenta recibe de intereses: **$2,596** (ganancia del préstamo)
- Asociado paga comisión: **$189.96** ($15.83 × 12)
- Asociado recibe neto: **$7,406.04** ($617.17 × 12)

---

## 🗂️ ASIGNACIÓN A PERIODOS ADMINISTRATIVOS

### Lógica de Asignación

Cada pago se asigna al periodo cuyo rango contiene la fecha de vencimiento:

```sql
SELECT id INTO v_period_id
FROM cut_periods
WHERE period_start_date <= fecha_vencimiento
  AND period_end_date >= fecha_vencimiento
```

### Ejemplo Visual

```
PERIODO 26 (23 Ene - 7 Feb)
  ├─ Pago #1: vence 31 Ene ✓ (31 Ene está entre 23 Ene y 7 Feb)

PERIODO 27 (8 Feb - 22 Feb)
  ├─ Pago #2: vence 15 Feb ✓ (15 Feb está entre 8 Feb y 22 Feb)

PERIODO 28 (23 Feb - 7 Mar)
  ├─ Pago #3: vence 28 Feb ✓ (28 Feb está entre 23 Feb y 7 Mar)
```

### Múltiples Asociados en un Periodo

Un periodo puede contener pagos de múltiples asociados:

```
PERIODO 27 (8 Feb - 22 Feb)
  ├─ Asociado 1
  │   ├─ Cliente A: Pago #2 vence 15 Feb → $633
  │   └─ Cliente B: Pago #5 vence 15 Feb → $1,255
  │
  ├─ Asociado 2
  │   ├─ Cliente C: Pago #1 vence 15 Feb → $392
  │   └─ Cliente D: Pago #3 vence 15 Feb → $752
  │
  └─ Asociado 3
      └─ Cliente E: Pago #8 vence 15 Feb → $1,006
```

---

## 📋 ESTADOS DE CUENTA (associate_payment_statements)

### ¿Qué son los Statements?

Los statements son **resúmenes por asociado** de cuánto debe pagar a CrediCuenta por las comisiones de los pagos recibidos en un periodo.

### Estructura de un Statement

```
STATEMENT #2025-027-A001
Periodo: 27 (8 Feb - 22 Feb 2025)
Asociado: María García (#1)

PAGOS RECIBIDOS EN ESTE PERIODO:
┌─────────────┬────────────┬──────────────┬───────────┬─────────────────┐
│ Cliente     │ Préstamo   │ Pago Cliente │ Comisión  │ Pago a Asociado │
├─────────────┼────────────┼──────────────┼───────────┼─────────────────┤
│ Juan Pérez  │ Pago #2    │    $633.00   │  $15.83   │     $617.17     │
│ Ana López   │ Pago #5    │  $1,255.00   │  $31.38   │   $1,223.62     │
└─────────────┴────────────┴──────────────┴───────────┴─────────────────┘

RESUMEN:
  Total cobrado a clientes:     $1,888.00  (expected_amount)
  Total comisión adeudada:        $47.21   (commission_amount)
  Total para asociado:          $1,840.79  (associate_payment)

ESTADO: PENDING (asociado aún no ha pagado la comisión)
```

### Campos del Statement

```sql
CREATE TABLE associate_payment_statements (
    id SERIAL PRIMARY KEY,
    cut_period_id INTEGER,              -- FK al periodo (ej: 27)
    user_id INTEGER,                    -- FK al asociado
    statement_number VARCHAR(50),       -- ej: "2025-027-A001"
    total_payments_count INTEGER,       -- Cantidad de pagos (ej: 2)
    total_amount_collected DECIMAL,     -- Total cobrado ($1,888)
    total_commission_owed DECIMAL,      -- Comisión adeudada ($47.21)
    commission_rate_applied DECIMAL,    -- Tasa aplicada (2.5%)
    status_id INTEGER,                  -- PENDING/PAID/OVERDUE
    paid_amount DECIMAL,                -- Cuánto ha pagado
    late_fee_amount DECIMAL             -- Multas por retraso
);
```

---

## 🔄 RELACIÓN ENTRE TABLAS

```
cut_periods (Periodos Administrativos)
    ├── id: 27
    ├── period_start_date: 2025-02-08
    └── period_end_date: 2025-02-22
        │
        ├─► payments (Pagos de clientes que vencen en este periodo)
        │       ├── loan_id: 123, payment_due_date: 2025-02-15, expected_amount: 633, commission_amount: 15.83
        │       ├── loan_id: 124, payment_due_date: 2025-02-15, expected_amount: 1255, commission_amount: 31.38
        │       └── ...
        │
        └─► associate_payment_statements (Resúmenes por asociado)
                ├── user_id: 1 (Asociado 1)
                │   ├── total_amount_collected: 1888.00
                │   ├── total_commission_owed: 47.21
                │   └── status: PENDING
                │
                ├── user_id: 2 (Asociado 2)
                │   ├── total_amount_collected: 2639.00
                │   ├── total_commission_owed: 65.98
                │   └── status: PAID
                │
                └── ...
```

---

## 💰 FLUJO DE DINERO REAL

### Ejemplo: Cliente paga $633

```
1. CLIENTE PAGA AL ASOCIADO
   Cliente → $633 → Asociado
   
2. ASOCIADO REGISTRA EL PAGO
   UPDATE payments 
   SET amount_paid = 633, 
       payment_date = CURRENT_DATE
   WHERE id = xxx

3. AL CERRAR PERIODO, SE GENERA STATEMENT
   Statement del Asociado:
   - Total cobrado: $633
   - Comisión adeudada: $15.83 (2.5%)
   - Pago neto: $617.17
   
4. ASOCIADO PAGA COMISIÓN A CREDICUENTA
   Asociado → $15.83 → CrediCuenta
   
   UPDATE associate_payment_statements
   SET paid_amount = 15.83,
       status_id = PAID
   WHERE id = yyy

5. RESULTADO FINAL
   ✅ Cliente pagó: $633
   ✅ Asociado recibió: $633
   ✅ Asociado pagó comisión: $15.83
   ✅ Asociado se queda con: $617.17
   ✅ CrediCuenta recibió: $15.83
```

---

## 🎯 FUNCIONES SQL CLAVE

### 1. calculate_first_payment_date()

**Propósito:** Determina cuándo vence el primer pago según la fecha de aprobación

**Lógica del Oráculo:**
```
Aprobación día 1-7   → Primer pago día 15 mes ACTUAL
Aprobación día 8-22  → Primer pago ÚLTIMO día mes ACTUAL  
Aprobación día 23-31 → Primer pago día 15 mes SIGUIENTE
```

**Ejemplos:**
- Aprobado 5 Ene → Primera fecha: 15 Ene
- Aprobado 10 Ene → Primera fecha: 31 Ene
- Aprobado 25 Ene → Primera fecha: 15 Feb

### 2. generate_amortization_schedule()

**Propósito:** Genera tabla completa de pagos con fechas alternadas

**Parámetros:**
- `p_amount`: Capital ($5,000)
- `p_biweekly_payment`: Pago quincenal ($633)
- `p_term_biweeks`: Plazo (12)
- `p_commission_rate`: Tasa comisión (2.5%)
- `p_start_date`: Primera fecha (31 Ene)

**Retorna:** 12 filas con:
- periodo: 1, 2, 3, ..., 12
- fecha_pago: 31 Ene, 15 Feb, 28 Feb, 15 Mar, ...
- pago_cliente: $633
- interes_cliente: $216.33
- capital_cliente: $416.67
- saldo_pendiente: $4,583.33, $4,166.66, ...
- comision_socio: $15.83
- pago_socio: $617.17

### 3. generate_payment_schedule() (Trigger)

**Propósito:** Se ejecuta automáticamente al aprobar un préstamo

**Flujo:**
1. Detecta cambio a status = APPROVED
2. Llama a `calculate_first_payment_date(approved_at)`
3. Llama a `generate_amortization_schedule(...)`
4. Para cada fila de la amortización:
   - Busca el `cut_period_id` correspondiente
   - Inserta en tabla `payments`
5. Valida que se insertaron todos los pagos

---

## 📊 GENERACIÓN DE STATEMENTS

### Proceso Manual (Pendiente Implementar)

```sql
-- FUNCIÓN A CREAR: generate_statements_for_period()
CREATE FUNCTION generate_statements_for_period(p_period_id INTEGER)
AS $$
BEGIN
  -- Para cada asociado que tenga pagos en este periodo
  FOR v_associate IN 
    SELECT DISTINCT l.associate_user_id
    FROM payments p
    JOIN loans l ON p.loan_id = l.id
    WHERE p.cut_period_id = p_period_id
  LOOP
    -- Agregar datos del asociado
    INSERT INTO associate_payment_statements (
      cut_period_id,
      user_id,
      statement_number,
      total_payments_count,
      total_amount_collected,
      total_commission_owed,
      commission_rate_applied,
      status_id
    )
    SELECT
      p_period_id,
      v_associate.id,
      generate_statement_number(p_period_id, v_associate.id),
      COUNT(p.id),
      SUM(p.expected_amount),
      SUM(p.commission_amount),
      2.50,  -- o calcular promedio
      (SELECT id FROM statement_statuses WHERE name = 'PENDING')
    FROM payments p
    JOIN loans l ON p.loan_id = l.id
    WHERE p.cut_period_id = p_period_id
      AND l.associate_user_id = v_associate.id;
  END LOOP;
END;
$$;
```

---

## 🎨 VISTA JERÁRQUICA EN FRONTEND

### Estructura de Datos

```
Periodo 27 (8 Feb - 22 Feb 2025)
│
├─► Statement Asociado 1
│   ├─ Total cobrado: $1,888.00
│   ├─ Comisión: $47.21
│   ├─ Estado: PENDING
│   └─► Pagos individuales
│       ├─ Cliente A - Préstamo #123 - Pago #2 - $633 - Comisión $15.83
│       └─ Cliente B - Préstamo #124 - Pago #5 - $1,255 - Comisión $31.38
│
├─► Statement Asociado 2
│   ├─ Total cobrado: $2,639.00
│   ├─ Comisión: $65.98
│   ├─ Estado: PAID
│   └─► Pagos individuales
│       ├─ Cliente C - Préstamo #125 - Pago #1 - $392 - Comisión $9.80
│       ├─ Cliente D - Préstamo #126 - Pago #3 - $752 - Comisión $18.80
│       └─ Cliente E - Préstamo #127 - Pago #7 - $1,495 - Comisión $37.38
│
└─► Statement Asociado 3
    └─ ...
```

### Endpoints Necesarios

```
GET /api/v1/cut-periods                    # Listar periodos
GET /api/v1/cut-periods/{id}/statements    # Statements del periodo
GET /api/v1/statements/{id}/payments       # Pagos del statement
POST /api/v1/cut-periods/{id}/generate-statements  # Generar statements
```

---

## ✅ RESUMEN EJECUTIVO

### Conceptos Clave Corregidos

1. **Comisión = Costo para el asociado** (NO ganancia)
2. **Statement = Cuenta por pagar del asociado** (NO estado de cuenta de ganancia)
3. **Doble calendario sincroniza:**
   - Fechas de vencimiento del cliente (15 y último día)
   - Con periodos administrativos (8-22 y 23-7)

### Flujo de Generación de Pagos

```
Aprobación → Oráculo (primera fecha) → Amortización (12 pagos) → 
Asignación a periodos → Inserción en payments
```

### Próximos Pasos

1. ✅ Implementar función `generate_statements_for_period()`
2. ✅ Crear endpoint `POST /cut-periods/{id}/generate-statements`
3. ✅ Crear endpoint `GET /statements/{id}/payments`
4. ✅ Frontend jerárquico: Periodo → Statements → Pagos
5. ✅ Generación de PDF para asociados

---

**Documentado por:** GitHub Copilot  
**Fecha:** 25 Noviembre 2025  
**Versión:** 2.0 - CORREGIDA
