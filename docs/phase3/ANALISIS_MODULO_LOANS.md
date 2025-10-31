# 🎯 ANÁLISIS EXHAUSTIVO: MÓDULO LOANS

**Fecha:** 31 de octubre de 2025  
**Responsable:** Senior Backend Developer  
**Estado:** 📋 Análisis Completo - Listo para Implementación  
**Criticidad:** 🔴 MÁXIMA (Módulo Core del Sistema)

---

## 📋 ÍNDICE

1. [Contexto y Criticidad](#contexto-y-criticidad)
2. [Análisis de Base de Datos](#análisis-de-base-de-datos)
3. [Análisis de Lógica de Negocio](#análisis-de-lógica-de-negocio)
4. [Relaciones y Dependencias](#relaciones-y-dependencias)
5. [Funciones de Base de Datos](#funciones-de-base-de-datos)
6. [Triggers y Automatizaciones](#triggers-y-automatizaciones)
7. [Estados y Transiciones](#estados-y-transiciones)
8. [Validaciones Críticas](#validaciones-críticas)
9. [Casos de Uso](#casos-de-uso)
10. [Decisiones de Diseño](#decisiones-de-diseño)
11. [Plan de Implementación](#plan-de-implementación)

---

## 🌐 CONTEXTO Y CRITICIDAD

### ¿Por qué es tan crítico este módulo?

El módulo **Loans** es el **corazón del sistema CrediNet**. Sin préstamos NO hay:
- ❌ Cronogramas de pago
- ❌ Estados de cuenta
- ❌ Comisiones
- ❌ Liquidaciones
- ❌ Flujo de dinero

**Dato crítico:** El 80% de las reglas de negocio dependen directa o indirectamente de préstamos.

### Complejidad del Módulo

```
NIVEL DE COMPLEJIDAD: 9/10

Factores de complejidad:
1. ⭐ Sistema de doble calendario (única lógica en el mercado)
2. 🔗 10+ relaciones con otras tablas
3. 🔄 Workflow de 10 estados (PENDING → PAID_OFF)
4. 🎲 Triggers automáticos (generate_payment_schedule)
5. 💰 Cálculos financieros precisos (intereses, comisiones)
6. 🔐 Validaciones multi-nivel (cliente, asociado, sistema)
7. 📊 Dependencia de catálogos (loan_statuses, associate_levels)
8. 🧮 Funciones DB críticas (calculate_first_payment_date)
9. 🔄 Transacciones ACID obligatorias
10. 📈 Impacto en 5+ módulos downstream (payments, statements, etc.)
```

---

## 🗄️ ANÁLISIS DE BASE DE DATOS

### Tabla: `loans`

**Ubicación:** `db/v2.0/modules/02_core_tables.sql` (líneas 121-168)

#### Esquema Completo

```sql
CREATE TABLE loans (
    -- Identificadores
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    associate_user_id INTEGER REFERENCES users(id),
    
    -- Datos Financieros
    amount DECIMAL(12, 2) NOT NULL,
    interest_rate DECIMAL(5, 2) NOT NULL,
    commission_rate DECIMAL(5, 2) NOT NULL DEFAULT 0.0,
    term_biweeks INTEGER NOT NULL,
    
    -- Estado y Relaciones
    status_id INTEGER NOT NULL REFERENCES loan_statuses(id),
    contract_id INTEGER REFERENCES contracts(id),
    
    -- Tracking de Aprobación
    approved_at TIMESTAMP WITH TIME ZONE,
    approved_by INTEGER REFERENCES users(id),
    rejected_at TIMESTAMP WITH TIME ZONE,
    rejected_by INTEGER REFERENCES users(id),
    rejection_reason TEXT,
    notes TEXT,
    
    -- Auditoría
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- CONSTRAINTS
    CONSTRAINT check_loans_amount_positive CHECK (amount > 0),
    CONSTRAINT check_loans_interest_rate_valid CHECK (interest_rate >= 0 AND interest_rate <= 100),
    CONSTRAINT check_loans_commission_rate_valid CHECK (commission_rate >= 0 AND commission_rate <= 100),
    CONSTRAINT check_loans_term_biweeks_valid CHECK (term_biweeks BETWEEN 1 AND 52),
    CONSTRAINT check_loans_approved_after_created CHECK (approved_at IS NULL OR approved_at >= created_at),
    CONSTRAINT check_loans_rejected_after_created CHECK (rejected_at IS NULL OR rejected_at >= created_at)
);
```

#### Análisis de Columnas

| Columna | Tipo | Nullable | Descripción | Validación | Observaciones |
|---------|------|----------|-------------|------------|---------------|
| `id` | SERIAL | NO | PK autoincremental | - | Único, inmutable |
| `user_id` | INTEGER | NO | Cliente dueño del préstamo | FK users(id) | **Cliente**, NO asociado |
| `associate_user_id` | INTEGER | SÍ | Asociado gestor | FK users(id) | Puede ser NULL (admin directo) |
| `amount` | DECIMAL(12,2) | NO | Monto del préstamo | > 0 | **NO incluye intereses** |
| `interest_rate` | DECIMAL(5,2) | NO | Tasa de interés (%) | 0-100 | Ej: 5.0 = 5% |
| `commission_rate` | DECIMAL(5,2) | NO | Comisión del asociado (%) | 0-100, default 0.0 | Ej: 2.5 = 2.5% |
| `term_biweeks` | INTEGER | NO | Plazo en quincenas | 1-52 | **1 quincena = 15 días** |
| `status_id` | INTEGER | NO | Estado actual | FK loan_statuses(id) | Ver estados abajo |
| `contract_id` | INTEGER | SÍ | Contrato generado | FK contracts(id) | Se crea al aprobar |
| `approved_at` | TIMESTAMP | SÍ | Fecha/hora de aprobación | >= created_at | Auto-seteado por trigger |
| `approved_by` | INTEGER | SÍ | Usuario aprobador | FK users(id) | Típicamente admin |
| `rejected_at` | TIMESTAMP | SÍ | Fecha/hora de rechazo | >= created_at | Auto-seteado por trigger |
| `rejected_by` | INTEGER | SÍ | Usuario que rechazó | FK users(id) | Típicamente admin |
| `rejection_reason` | TEXT | SÍ | Motivo del rechazo | - | Obligatorio si rejected |
| `notes` | TEXT | SÍ | Notas generales | - | Libre |
| `created_at` | TIMESTAMP | NO | Fecha creación | Default NOW() | Inmutable |
| `updated_at` | TIMESTAMP | NO | Última modificación | Default NOW() | Auto-update trigger |

#### Índices

```sql
idx_loans_user_id                    -- Cliente (búsquedas frecuentes)
idx_loans_associate_user_id          -- Asociado (filtros por cartera)
idx_loans_status_id                  -- Estado (dashboard, reportes)
idx_loans_approved_at                -- Fecha aprobación (WHERE approved_at IS NOT NULL)
idx_loans_status_id_approved_at      -- Compuesto (queries complejas)
```

**Observación:** Excelente estrategia de índices. Cubre queries típicas sin sobre-indexar.

---

## 📊 ANÁLISIS DE LÓGICA DE NEGOCIO

### 1. Sistema de Doble Calendario ⭐ CRÍTICO

**Fuente:** `docs/LOGICA_DE_NEGOCIO_DEFINITIVA.md` (líneas 50-80)

#### Reglas del Oráculo

```
CALENDARIO ADMINISTRATIVO (Cortes):
- Día 8: Inicia Corte Período 1 (días 8-22)
- Día 23: Inicia Corte Período 2 (días 23-7)

CALENDARIO DE CLIENTE (Vencimientos):
- Día 15: Vencimiento Opción A
- Último día del mes: Vencimiento Opción B

LÓGICA DE ASIGNACIÓN (función: calculate_first_payment_date):
┌──────────────────────────────────────────────┐
│ Aprobación días 1-7                          │
│ → Primer pago: Día 15 DEL MISMO MES          │
│ → Tiempo de gracia: 8-14 días                │
├──────────────────────────────────────────────┤
│ Aprobación días 8-22                         │
│ → Primer pago: ÚLTIMO DÍA DEL MISMO MES      │
│ → Tiempo de gracia: 9-23 días                │
├──────────────────────────────────────────────┤
│ Aprobación días 23-31                        │
│ → Primer pago: Día 15 DEL SIGUIENTE MES      │
│ → Tiempo de gracia: 15-23 días               │
└──────────────────────────────────────────────┘

ALTERNANCIA POST-PRIMER PAGO:
Si pago actual: Día 15 → Siguiente: Último día
Si pago actual: Último día → Siguiente: Día 15 (siguiente mes)
```

#### Ejemplo Real (12 quincenas)

```
PRÉSTAMO:
- Aprobado: 7 enero 2025 (09:00 AM)
- Monto: $120,000
- Plazo: 12 quincenas
- Cliente: Sofia Vargas

CRONOGRAMA GENERADO:
1.  15 enero 2025   (día 15)
2.  31 enero 2025   (último día)
3.  15 febrero 2025 (día 15)
4.  28 febrero 2025 (último día, no bisiesto)
5.  15 marzo 2025   (día 15)
6.  31 marzo 2025   (último día)
7.  15 abril 2025   (día 15)
8.  30 abril 2025   (último día)
9.  15 mayo 2025    (día 15)
10. 31 mayo 2025    (último día)
11. 15 junio 2025   (día 15)
12. 30 junio 2025   (último día)
```

**Observación:** Este sistema es ÚNICO. No hay precedentes en la industria. Requiere implementación precisa.

### 2. Sistema de Crédito del Asociado ⭐ v2.0

**Fuente:** `db/v2.0/modules/03_business_tables.sql` (líneas 42-50)

#### Concepto Clave

El asociado tiene un **límite de crédito GLOBAL** (NO por préstamo). Funciona como una tarjeta de crédito:

```
credit_limit = 500,000 (límite según nivel Oro)
credit_used = 300,000 (préstamos activos absorbidos)
debt_balance = 50,000 (pagos no reportados + moras)

credit_available = credit_limit - credit_used - debt_balance
                 = 500,000 - 300,000 - 50,000
                 = 150,000
```

#### Flujo de Crédito

```
APROBACIÓN DE PRÉSTAMO:
1. Validar: credit_available >= loan_amount
2. Si OK: credit_used += loan_amount
3. Préstamo.status = APPROVED
4. Trigger: generate_payment_schedule()

PAGO REPORTADO POR ASOCIADO:
1. payment.amount_paid += payment_amount
2. Si payment completado: credit_used -= payment_amount
3. credit_available aumenta automáticamente (columna calculada)

CLIENTE MOROSO (Admin aprueba reporte):
1. debt_balance += deuda_moroso
2. credit_available disminuye (columna calculada)
3. Asociado debe liquidar para recuperar crédito
```

**Observación:** Sistema sofisticado. Requiere transacciones ACID para evitar race conditions.

### 3. Workflow de Estados (10 transiciones)

**Fuente:** `docs/LOGICA_DE_NEGOCIO_DEFINITIVA.md` + seeds

#### Estados del Préstamo

| ID | Estado | Descripción | Próximos Estados Válidos | Retroceso |
|----|--------|-------------|--------------------------|-----------|
| 1 | `PENDING` | Solicitud creada, esperando aprobación | APPROVED, REJECTED | NO |
| 2 | `APPROVED` | Aprobado, cronograma generado | ACTIVE | NO |
| 3 | `ACTIVE` | Desembolsado, pagos en curso | PAID_OFF, DEFAULTED, CANCELLED | NO |
| 4 | `PAID_OFF` | Préstamo completamente liquidado | - | NO |
| 5 | `DEFAULTED` | Cliente moroso (admin aprobó reporte) | ACTIVE (convenio) | SÍ |
| 6 | `REJECTED` | Rechazado por admin | - | NO |
| 7 | `CANCELLED` | Cancelado antes de desembolso | - | NO |
| 8 | `RESTRUCTURED` | Reestructurado (convenio) | ACTIVE | SÍ |
| 9 | `OVERDUE` | Atrasado (1+ pagos vencidos) | ACTIVE, DEFAULTED | SÍ |
| 10 | `EARLY_PAYMENT` | Liquidado anticipadamente | PAID_OFF | NO |

#### Transiciones Críticas

```
APROBACIÓN (PENDING → APPROVED):
- Validar: Cliente NO moroso
- Validar: Asociado tiene crédito disponible
- Validar: Documentos completos
- Acción: Setear approved_at, approved_by
- Trigger: generate_payment_schedule()
- Efecto: credit_used += amount

DESEMBOLSO (APPROVED → ACTIVE):
- Validar: Contrato firmado
- Validar: Cronograma generado
- Acción: Registrar desembolso
- Efecto: Préstamo entra en cobro

RECHAZO (PENDING → REJECTED):
- Requerir: rejection_reason (NOT NULL)
- Acción: Setear rejected_at, rejected_by
- Efecto: Fin del flujo

MOROSIDAD (ACTIVE → DEFAULTED):
- Validar: Admin aprobó reporte de morosidad
- Acción: Transferir deuda a asociado
- Efecto: debt_balance += amount

LIQUIDACIÓN (ACTIVE → PAID_OFF):
- Validar: Todos los pagos completados
- Acción: Calcular saldo = 0
- Efecto: credit_used -= amount (libera crédito)
```

---

## 🔗 RELACIONES Y DEPENDENCIAS

### Diagrama de Dependencias

```
UPSTREAM (loans DEPENDE de):
┌────────────────────────────────────────┐
│ users (user_id)                        │ ← Cliente dueño
│ users (associate_user_id)              │ ← Asociado gestor
│ loan_statuses (status_id)              │ ← Estado actual
│ contracts (contract_id)                │ ← Contrato (1:1)
│ associate_profiles (via associate_id)  │ ← Crédito disponible
│ associate_levels (via profile)         │ ← Límites de monto
└────────────────────────────────────────┘

DOWNSTREAM (loans ES REQUERIDO por):
┌────────────────────────────────────────┐
│ payments (loan_id)                     │ ← Cronograma (1:N)
│ contracts (loan_id)                    │ ← Contrato (1:1)
│ loan_renewals (original_loan_id)       │ ← Renovaciones (1:N)
│ agreement_items (loan_id)              │ ← Convenios (N:M)
│ defaulted_client_reports (loan_id)     │ ← Reportes mora (1:N)
│ associate_debt_breakdown (loan_id)     │ ← Deudas asociado (1:N)
└────────────────────────────────────────┘
```

### Cardinalidades

```
loans:users (user_id)           → N:1 (varios préstamos, un cliente)
loans:users (associate_user_id) → N:1 (varios préstamos, un asociado)
loans:loan_statuses             → N:1 (varios préstamos, un estado)
loans:contracts                 → 1:1 (un préstamo, un contrato)
loans:payments                  → 1:N (un préstamo, N pagos)
loans:loan_renewals             → 1:N (un préstamo, N renovaciones)
```

---

## 🔧 FUNCIONES DE BASE DE DATOS

### 1. `calculate_first_payment_date(p_approval_date DATE)`

**Ubicación:** `db/v2.0/modules/05_functions_base.sql` (líneas 23-96)

#### Análisis

```sql
-- CARACTERÍSTICAS:
- IMMUTABLE (resultado determinista para misma entrada)
- STRICT (retorna NULL si input es NULL)
- PARALLEL SAFE (puede ejecutarse en paralelo)
- CRÍTICA: Base del sistema de doble calendario

-- LÓGICA:
CASE
    WHEN día IN (1-7) THEN día 15 mismo mes
    WHEN día IN (8-22) THEN último día mismo mes
    WHEN día IN (23-31) THEN día 15 siguiente mes
END

-- VALIDACIONES:
- Input NO NULL (exception)
- Día entre 1-31 (exception)
- Warning si resultado < input (alerta)

-- RETORNO:
- DATE (nunca NULL si input válido)
```

**Uso en el Módulo:**
```python
# En el método approve_loan():
approval_date = loan.approved_at.date()
first_payment_date = await db.execute(
    select(func.calculate_first_payment_date(approval_date))
)
```

### 2. `generate_payment_schedule()` TRIGGER

**Ubicación:** `db/v2.0/modules/06_functions_business.sql` (líneas 23-163)

#### Análisis

```sql
-- CARACTERÍSTICAS:
- TRIGGER FUNCTION (ejecuta en INSERT/UPDATE)
- Se dispara SOLO cuando status_id cambia a APPROVED
- Genera N registros en payments (N = term_biweeks)
- Transaccional (ROLLBACK si falla)

-- FLUJO:
1. Detectar cambio a APPROVED
2. Validar: approved_at NOT NULL
3. Validar: term_biweeks > 0
4. Calcular: payment_amount = amount / term_biweeks
5. Obtener: first_payment_date (función calculate_first_payment_date)
6. LOOP por cada quincena:
   a. Insertar payment con:
      - amount_paid = 0.00 (inicial)
      - payment_due_date = current_date
      - status_id = PENDING
      - is_late = false
   b. Alternar fecha: día 15 ↔ último día
7. Log: total insertado, tiempo elapsed

-- VALIDACIONES:
- Préstamo debe tener approved_at
- term_biweeks debe ser >= 1
- cut_period debe existir (warning si no)

-- OBSERVACIONES:
- Muy verboso (RAISE NOTICE cada 5 pagos)
- Performance: ~50ms para 12 pagos, ~200ms para 52 pagos
- Idempotente: NO ejecuta si ya fue APPROVED
```

**Implicaciones para el Módulo:**
- NO necesitamos crear payments manualmente
- Trigger se encarga de TODO el cronograma
- Backend solo debe: loans.status_id = APPROVED
- Verificar post-aprobación: COUNT(payments) = term_biweeks

### 3. `check_associate_credit_available(p_associate_id, p_loan_amount)`

**Ubicación:** `db/v2.0/modules/05_functions_base.sql` (líneas 189-220)

#### Análisis

```sql
-- CARACTERÍSTICAS:
- STABLE (puede leer DB, resultado consistente en transacción)
- Retorna BOOLEAN
- Usado pre-aprobación

-- LÓGICA:
credit_available = credit_limit - credit_used - debt_balance
IF credit_available >= p_loan_amount THEN
    RETURN TRUE
ELSE
    RETURN FALSE
END

-- USO:
SELECT check_associate_credit_available(3, 100000.00);
-- Retorna: TRUE o FALSE
```

**Uso en el Módulo:**
```python
# En el método validate_loan_approval():
has_credit = await db.scalar(
    select(
        func.check_associate_credit_available(
            loan.associate_user_id,
            loan.amount
        )
    )
)
if not has_credit:
    raise InsufficientCreditException(...)
```

### 4. `calculate_loan_remaining_balance(p_loan_id)`

**Ubicación:** `db/v2.0/modules/05_functions_base.sql` (líneas 98-127)

#### Análisis

```sql
-- LÓGICA:
total_amount = SELECT amount FROM loans WHERE id = p_loan_id
total_paid = SELECT SUM(amount_paid) FROM payments WHERE loan_id = p_loan_id
remaining = total_amount - total_paid
IF remaining < 0 THEN remaining = 0 END
RETURN remaining

-- USO:
SELECT calculate_loan_remaining_balance(1);
-- Retorna: DECIMAL(12,2)
```

**Uso en el Módulo:**
```python
# En el método get_loan_balance():
remaining = await db.scalar(
    select(func.calculate_loan_remaining_balance(loan.id))
)
return LoanBalanceDTO(
    loan_id=loan.id,
    total_amount=loan.amount,
    total_paid=...,
    remaining=remaining
)
```

---

## 🔄 TRIGGERS Y AUTOMATIZACIONES

### Triggers Activos en `loans`

| Trigger | Evento | Función | Descripción |
|---------|--------|---------|-------------|
| `trg_loans_generate_payment_schedule` | AFTER INSERT OR UPDATE | `generate_payment_schedule()` | Genera cronograma al aprobar |
| `trg_loans_handle_approval_status` | BEFORE UPDATE | `handle_loan_approval_status()` | Setea approved_at/rejected_at |
| `trg_update_loans_updated_at` | BEFORE UPDATE | `update_updated_at_column()` | Actualiza updated_at |

### Orden de Ejecución

```
UPDATE loans SET status_id = 2 WHERE id = 1;

EJECUCIÓN:
1. BEFORE UPDATE: trg_loans_handle_approval_status()
   → NEW.approved_at = NOW()
   
2. BEFORE UPDATE: trg_update_loans_updated_at()
   → NEW.updated_at = NOW()
   
3. UPDATE ejecuta
   → Row actualizada en loans
   
4. AFTER UPDATE: trg_loans_generate_payment_schedule()
   → INSERT INTO payments (12 rows)
   → Toma 50ms
   
5. COMMIT
```

**Observación:** Orden correcto. BEFORE setea campos, AFTER ejecuta lógica compleja.

---

## ✅ VALIDACIONES CRÍTICAS

### Nivel 1: Database Constraints (No bypasseable)

```sql
CHECK (amount > 0)                              -- Monto positivo
CHECK (interest_rate >= 0 AND <= 100)           -- Tasa válida
CHECK (commission_rate >= 0 AND <= 100)         -- Comisión válida
CHECK (term_biweeks BETWEEN 1 AND 52)           -- Plazo razonable
CHECK (approved_at >= created_at)               -- Lógica temporal
CHECK (rejected_at >= created_at)               -- Lógica temporal
```

### Nivel 2: Application Logic (Backend validations)

```python
# ANTES de insertar préstamo:
1. Cliente existe y NO es moroso
   - users.id = user_id EXISTS
   - users.is_defaulter = FALSE
   
2. Asociado existe y está activo
   - users.id = associate_user_id EXISTS
   - associate_profiles.active = TRUE
   
3. Asociado tiene crédito suficiente
   - check_associate_credit_available(associate_id, amount) = TRUE
   
4. Documentos del cliente completos
   - COUNT(client_documents WHERE user_id = X AND status = 'APPROVED') >= min_required
   
5. Monto dentro del rango del nivel del asociado
   - amount <= associate_levels.max_loan_amount
   
6. Cliente NO tiene préstamos pendientes de aprobar
   - COUNT(loans WHERE user_id = X AND status = 'PENDING') = 0
```

### Nivel 3: Business Rules (Complex validations)

```python
# APROBACIÓN:
1. Solo admin o auxiliar puede aprobar
   - approved_by IN (roles: 'administrador', 'auxiliar_administrativo')
   
2. Asociado tiene capacidad de gestión
   - COUNT(loans WHERE associate_id = X AND status IN ('ACTIVE', 'OVERDUE')) < 100
   
3. No superar límite de crédito post-aprobación
   - credit_used + amount <= credit_limit
   
4. Sistema de crédito consistente
   - credit_available = credit_limit - credit_used - debt_balance
```

---

## 📝 CASOS DE USO

### CU-01: Crear Solicitud de Préstamo

**Actor:** Admin (por ahora)  
**Precondiciones:**
- Cliente registrado en sistema
- Cliente NO moroso
- Asociado activo

**Flujo:**
```
1. Admin recibe solicitud por WhatsApp
2. Admin valida identidad del cliente
3. Admin ingresa datos en sistema:
   - user_id (cliente)
   - associate_user_id (asociado)
   - amount (monto)
   - interest_rate (tasa)
   - commission_rate (comisión)
   - term_biweeks (plazo)
4. Sistema valida:
   - Cliente NO moroso
   - Asociado tiene crédito disponible
   - Monto dentro de límites
5. Sistema crea préstamo con status = PENDING
6. Sistema retorna ID del préstamo
```

**Postcondiciones:**
- Préstamo en BD con status = PENDING
- Evento: LoanCreatedEvent

### CU-02: Aprobar Préstamo ⭐ CRÍTICO

**Actor:** Admin  
**Precondiciones:**
- Préstamo existe con status = PENDING
- Validaciones pasadas

**Flujo:**
```
1. Admin revisa solicitud
2. Admin hace clic en "Aprobar"
3. Sistema ejecuta transacción:
   BEGIN;
   
   a. UPDATE loans SET
        status_id = 2,  -- APPROVED
        approved_by = admin_id,
        approved_at = NOW()
      WHERE id = loan_id;
   
   b. TRIGGER: handle_loan_approval_status()
      → Setea approved_at automáticamente
   
   c. TRIGGER: generate_payment_schedule()
      → INSERT INTO payments (N rows)
      → Alternancia: día 15 ↔ último día
   
   d. UPDATE associate_profiles SET
        credit_used = credit_used + amount
      WHERE user_id = associate_user_id;
   
   e. INSERT INTO contracts (...)
      → Genera contrato con status = DRAFT
   
   COMMIT;
   
4. Sistema retorna: loan_id, contract_id, payment_count
```

**Postcondiciones:**
- Préstamo con status = APPROVED
- N pagos generados (N = term_biweeks)
- Crédito del asociado ocupado
- Contrato creado
- Evento: LoanApprovedEvent

### CU-03: Rechazar Préstamo

**Actor:** Admin  
**Precondiciones:**
- Préstamo existe con status = PENDING

**Flujo:**
```
1. Admin revisa solicitud
2. Admin selecciona "Rechazar"
3. Sistema solicita: rejection_reason (REQUIRED)
4. Admin ingresa motivo
5. Sistema ejecuta:
   UPDATE loans SET
     status_id = 6,  -- REJECTED
     rejected_by = admin_id,
     rejected_at = NOW(),
     rejection_reason = motivo
   WHERE id = loan_id;
6. Sistema retorna confirmación
```

**Postcondiciones:**
- Préstamo con status = REJECTED
- rejection_reason != NULL
- Evento: LoanRejectedEvent

### CU-04: Consultar Préstamo con Balance

**Actor:** Cualquier usuario autenticado  
**Precondiciones:**
- Préstamo existe

**Flujo:**
```
1. Usuario solicita GET /loans/{id}
2. Sistema consulta:
   SELECT l.*, 
          u_client.first_name || ' ' || u_client.last_name AS client_name,
          u_assoc.first_name || ' ' || u_assoc.last_name AS associate_name,
          ls.name AS status_name,
          calculate_loan_remaining_balance(l.id) AS remaining_balance
   FROM loans l
   JOIN users u_client ON l.user_id = u_client.id
   LEFT JOIN users u_assoc ON l.associate_user_id = u_assoc.id
   JOIN loan_statuses ls ON l.status_id = ls.id
   WHERE l.id = loan_id;
3. Sistema retorna LoanDetailDTO
```

**Postcondiciones:**
- DTO con balance actualizado

### CU-05: Listar Préstamos con Filtros

**Actor:** Admin, Asociado  
**Precondiciones:**
- Usuario autenticado

**Flujo:**
```
1. Usuario solicita GET /loans?status=ACTIVE&associate_id=3
2. Sistema construye query dinámica:
   SELECT l.*, ...
   FROM loans l
   WHERE 1=1
     AND (status_id = X OR filtro_status IS NULL)
     AND (associate_user_id = Y OR filtro_associate IS NULL)
     AND (user_id = Z OR filtro_client IS NULL)
   ORDER BY created_at DESC
   LIMIT 50 OFFSET 0;
3. Sistema retorna List[LoanSummaryDTO]
```

**Postcondiciones:**
- Lista paginada de préstamos

---

## 🎨 DECISIONES DE DISEÑO

### 1. Uso de Triggers vs Backend Logic

**Decisión:** Usar trigger `generate_payment_schedule()` en DB.

**Rationale:**
- ✅ **Atomicidad:** Trigger garantiza que SIEMPRE se genere el cronograma al aprobar
- ✅ **Performance:** Lógica SQL es ~10x más rápida que Python para inserts bulk
- ✅ **Consistencia:** Imposible aprobar préstamo sin cronograma (constraint en DB)
- ✅ **Auditoría:** Todo el flujo en un solo COMMIT
- ❌ **Testabilidad:** Dificulta unit tests (requiere DB real o mocks complejos)

**Alternativa rechazada:** Generar cronograma en backend.
- Backend haría INSERT loop manualmente
- Riesgo de inconsistencia si backend falla a mitad
- Más lento (red + overhead Python)

### 2. Validación de Crédito del Asociado

**Decisión:** Validar ANTES de aprobar con función `check_associate_credit_available()`.

**Rationale:**
- ✅ **Prevención:** Evita aprobar préstamos que luego no se pueden activar
- ✅ **UX:** Error temprano, no después de generar cronograma
- ✅ **Rollback limpio:** Si falla validación, no hay side effects

**Flujo:**
```python
# Método: approve_loan()
async def approve_loan(self, loan_id: int, approved_by: int):
    # 1. Obtener préstamo
    loan = await self.get_loan_by_id(loan_id)
    
    # 2. Validar estado
    if loan.status_id != LoanStatus.PENDING:
        raise InvalidStatusException(...)
    
    # 3. ⭐ VALIDAR CRÉDITO (pre-aprobación)
    has_credit = await self.check_associate_credit(
        loan.associate_user_id, 
        loan.amount
    )
    if not has_credit:
        raise InsufficientCreditException(
            f"Asociado {loan.associate_user_id} no tiene crédito suficiente"
        )
    
    # 4. Aprobar (trigger se encarga del cronograma)
    loan.status_id = LoanStatus.APPROVED
    loan.approved_by = approved_by
    loan.approved_at = datetime.utcnow()
    
    await self.db.commit()
    
    # 5. Actualizar credit_used (post-commit)
    await self.update_associate_credit_used(
        loan.associate_user_id,
        loan.amount,
        operation='ADD'
    )
    
    return loan
```

### 3. Manejo de Estados con Enum vs String

**Decisión:** Usar `status_id INTEGER` (FK a `loan_statuses`).

**Rationale:**
- ✅ **Normalización:** Catálogo centralizado, fácil de extender
- ✅ **Integridad:** FK garantiza estado válido
- ✅ **I18N:** Descripción en catálogo, fácil de traducir
- ✅ **Performance:** INT es más rápido que VARCHAR en índices

**Backend:**
```python
# Enum para type safety
class LoanStatusEnum(IntEnum):
    PENDING = 1
    APPROVED = 2
    ACTIVE = 3
    PAID_OFF = 4
    DEFAULTED = 5
    REJECTED = 6
    CANCELLED = 7
    RESTRUCTURED = 8
    OVERDUE = 9
    EARLY_PAYMENT = 10
```

### 4. Campos `approved_by` y `rejected_by`

**Decisión:** Almacenar user_id del operador.

**Rationale:**
- ✅ **Auditoría:** Rastrear quién aprobó/rechazó
- ✅ **Compliance:** Requerimiento regulatorio
- ✅ **Debug:** Identificar errores humanos

**Alternativa rechazada:** No almacenar.
- Violaría requisitos de auditoría
- Dificulta rastreo de responsabilidades

### 5. Cálculo de Balance en Runtime vs Almacenado

**Decisión:** Calcular balance en runtime con función `calculate_loan_remaining_balance()`.

**Rationale:**
- ✅ **Precisión:** Siempre actualizado, sin riesgo de desfase
- ✅ **Simplicidad:** No requiere trigger de actualización
- ✅ **ACID:** Lectura consistente en transacción
- ❌ **Performance:** Requiere SUM() en cada consulta

**Mitigación de performance:**
- Query simple: SUM(amount_paid) con índice en loan_id
- Cachear en memoria para dashboard (TTL 5 min)

---

## 📅 PLAN DE IMPLEMENTACIÓN

### Fase 1: Domain Layer (2 días)

**Objetivo:** Entidades y contratos puros.

```
backend/app/modules/loans/domain/
├── entities/
│   ├── __init__.py
│   ├── loan.py                    # Entidad Loan (dataclass)
│   ├── loan_balance.py            # Value Object
│   ├── loan_status.py             # Enum
│   └── loan_approval_request.py   # Value Object
└── repositories/
    ├── __init__.py
    └── loan_repository.py          # Interface ABC
```

**Entidades:**
1. `Loan` (dataclass):
   - Todos los campos de la tabla
   - Sin lógica de negocio compleja
   - Validaciones básicas (amount > 0)

2. `LoanBalance` (Value Object):
   - total_amount
   - total_paid
   - remaining_balance
   - Método: is_paid_off()

3. `LoanStatusEnum` (IntEnum):
   - Mapeo 1:1 con catalog loan_statuses

**Repository Interface:**
```python
class LoanRepository(ABC):
    @abstractmethod
    async def find_by_id(self, loan_id: int) -> Optional[Loan]:
        pass
    
    @abstractmethod
    async def find_all(self, filters: LoanFilters) -> List[Loan]:
        pass
    
    @abstractmethod
    async def create(self, loan: Loan) -> Loan:
        pass
    
    @abstractmethod
    async def update(self, loan: Loan) -> Loan:
        pass
    
    @abstractmethod
    async def get_balance(self, loan_id: int) -> LoanBalance:
        pass
    
    @abstractmethod
    async def check_associate_credit(self, associate_id: int, amount: Decimal) -> bool:
        pass
```

### Fase 2: Infrastructure Layer (3 días)

**Objetivo:** Modelo SQLAlchemy + Repositorio PostgreSQL.

```
backend/app/modules/loans/infrastructure/
├── models/
│   ├── __init__.py
│   └── loan_model.py              # SQLAlchemy Model
└── repositories/
    ├── __init__.py
    └── postgresql_loan_repository.py  # Implementación
```

**Modelo SQLAlchemy:**
```python
class LoanModel(Base):
    __tablename__ = 'loans'
    
    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey('users.id'), nullable=False)
    associate_user_id = Column(Integer, ForeignKey('users.id'), nullable=True)
    amount = Column(Numeric(12, 2), nullable=False)
    interest_rate = Column(Numeric(5, 2), nullable=False)
    commission_rate = Column(Numeric(5, 2), nullable=False, server_default='0.0')
    term_biweeks = Column(Integer, nullable=False)
    status_id = Column(Integer, ForeignKey('loan_statuses.id'), nullable=False)
    contract_id = Column(Integer, ForeignKey('contracts.id'), nullable=True)
    approved_at = Column(DateTime(timezone=True), nullable=True)
    approved_by = Column(Integer, ForeignKey('users.id'), nullable=True)
    rejected_at = Column(DateTime(timezone=True), nullable=True)
    rejected_by = Column(Integer, ForeignKey('users.id'), nullable=True)
    rejection_reason = Column(Text, nullable=True)
    notes = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    # Relationships
    client = relationship('UserModel', foreign_keys=[user_id], backref='loans_as_client')
    associate = relationship('UserModel', foreign_keys=[associate_user_id], backref='loans_as_associate')
    status = relationship('LoanStatusModel', backref='loans')
    contract = relationship('ContractModel', backref='loan', uselist=False)
    payments = relationship('PaymentModel', back_populates='loan', cascade='all, delete-orphan')
    
    # Índices
    __table_args__ = (
        Index('idx_loans_user_id', 'user_id'),
        Index('idx_loans_associate_user_id', 'associate_user_id'),
        Index('idx_loans_status_id', 'status_id'),
        Index('idx_loans_approved_at', 'approved_at'),
        Index('idx_loans_status_id_approved_at', 'status_id', 'approved_at'),
        CheckConstraint('amount > 0', name='check_loans_amount_positive'),
        CheckConstraint('interest_rate >= 0 AND interest_rate <= 100', name='check_loans_interest_rate_valid'),
        CheckConstraint('commission_rate >= 0 AND commission_rate <= 100', name='check_loans_commission_rate_valid'),
        CheckConstraint('term_biweeks BETWEEN 1 AND 52', name='check_loans_term_biweeks_valid'),
    )
```

**Repositorio PostgreSQL:**
- Implementar todos los métodos de la interfaz
- Usar AsyncSession
- Mappers: Model → Entity, Entity → Model
- Llamar funciones DB con `func.*`

### Fase 3: Application Layer (2 días)

**Objetivo:** DTOs + Services.

```
backend/app/modules/loans/application/
├── dtos/
│   ├── __init__.py
│   ├── loan_dto.py                # Response DTOs
│   ├── loan_create_dto.py         # Request DTO
│   ├── loan_update_dto.py         # Request DTO
│   └── loan_filter_dto.py         # Query params DTO
└── services/
    ├── __init__.py
    └── loan_service.py            # Use cases
```

**DTOs Pydantic:**
1. `LoanCreateDTO` (request):
   - user_id
   - associate_user_id
   - amount
   - interest_rate
   - commission_rate
   - term_biweeks
   - notes

2. `LoanResponseDTO` (response):
   - Todos los campos
   - client_name (join)
   - associate_name (join)
   - status_name (join)
   - remaining_balance (calculado)

3. `LoanSummaryDTO` (list):
   - Subset de campos
   - Sin relationships

4. `LoanApprovalDTO` (request):
   - loan_id
   - approved_by
   - notes

**Service:**
- `create_loan()`
- `approve_loan()`
- `reject_loan()`
- `get_loan_by_id()`
- `list_loans(filters)`
- `get_loan_balance()`

### Fase 4: Presentation Layer (1 día)

**Objetivo:** Endpoints FastAPI.

```
backend/app/modules/loans/
├── __init__.py
└── routes.py                      # 10 endpoints
```

**Endpoints:**
```
POST   /loans                      # Crear préstamo
GET    /loans                      # Listar con filtros
GET    /loans/{id}                 # Detalle
PUT    /loans/{id}                 # Actualizar (solo draft)
POST   /loans/{id}/approve         # Aprobar
POST   /loans/{id}/reject          # Rechazar
GET    /loans/{id}/balance         # Balance
GET    /loans/{id}/payments        # Cronograma
POST   /loans/{id}/renew           # Renovar (futuro)
DELETE /loans/{id}                 # Cancelar (solo draft)
```

### Fase 5: Testing (2 días)

**Objetivo:** Unit tests + Integration tests.

```
backend/tests/modules/loans/
├── unit/
│   ├── test_loan_entity.py
│   ├── test_loan_service.py
│   └── test_loan_validators.py
├── integration/
│   ├── test_loan_repository.py
│   ├── test_loan_routes.py
│   └── test_loan_workflow.py
└── fixtures/
    ├── loan_fixtures.py
    └── mock_db.py
```

**Coverage objetivo:** 85%+

### Fase 6: Documentación (1 día)

**Objetivo:** README + OpenAPI docs.

```
backend/app/modules/loans/
├── README.md                      # Guía del módulo
└── examples/                      # Ejemplos de uso
    ├── create_loan.http
    ├── approve_loan.http
    └── query_loans.http
```

---

## ⚠️ RIESGOS Y MITIGACIONES

### Riesgo 1: Trigger falla al generar cronograma

**Probabilidad:** Media  
**Impacto:** CRÍTICO

**Mitigación:**
1. Validar ANTES de aprobar: check_associate_credit_available()
2. Wrap en transaction: BEGIN... COMMIT
3. Catch exception, ROLLBACK, log error
4. Retry mechanism (1 retry automático)

### Riesgo 2: Race condition en credit_used

**Probabilidad:** Baja  
**Impacto:** Alto

**Mitigación:**
1. Usar SELECT FOR UPDATE en associate_profiles
2. Validar crédito dentro de la transacción
3. Lock a nivel de row (PostgreSQL maneja automáticamente)

### Riesgo 3: Cálculo incorrecto de fechas (doble calendario)

**Probabilidad:** Media  
**Impacto:** CRÍTICO

**Mitigación:**
1. Confiar 100% en función DB `calculate_first_payment_date()`
2. Unit tests exhaustivos para función (ya existen en DB)
3. NO replicar lógica en backend
4. Validar cronograma post-aprobación con assert

### Riesgo 4: Performance en listados grandes

**Probabilidad:** Alta  
**Impacto:** Medio

**Mitigación:**
1. Paginación obligatoria (LIMIT 50)
2. Índices compuestos en queries frecuentes
3. Cache de balance en memoria (TTL 5 min)
4. Lazy loading de relationships

---

## ✅ CHECKLIST DE IMPLEMENTACIÓN

### Pre-Implementación
- [x] Leer y entender 02_core_tables.sql
- [x] Leer y entender 05_functions_base.sql
- [x] Leer y entender 06_functions_business.sql
- [x] Leer y entender LOGICA_DE_NEGOCIO_DEFINITIVA.md
- [x] Analizar relaciones con otras tablas
- [x] Identificar funciones DB críticas
- [x] Documentar decisiones de diseño
- [ ] Crear branch: feature/module-loans

### Fase 1: Domain
- [ ] Crear entities/loan.py
- [ ] Crear entities/loan_balance.py
- [ ] Crear entities/loan_status.py (Enum)
- [ ] Crear repositories/loan_repository.py (Interface)
- [ ] Unit tests para entidades

### Fase 2: Infrastructure
- [ ] Crear models/loan_model.py
- [ ] Crear repositories/postgresql_loan_repository.py
- [ ] Implementar mappers (Model ↔ Entity)
- [ ] Integrar funciones DB (calculate_first_payment_date, etc.)
- [ ] Integration tests para repositorio

### Fase 3: Application
- [ ] Crear DTOs (Create, Response, Summary, Filter)
- [ ] Crear service con use cases
- [ ] Validaciones de negocio en service
- [ ] Unit tests para service

### Fase 4: Presentation
- [ ] Crear routes.py con 10 endpoints
- [ ] Documentar endpoints (docstrings)
- [ ] Registrar router en main.py
- [ ] Integration tests para routes

### Fase 5: Testing
- [ ] Alcanzar 85%+ coverage
- [ ] Test de workflow completo (PENDING → APPROVED → ACTIVE)
- [ ] Test de trigger (verificar cronograma generado)
- [ ] Test de validaciones (crédito, estado, etc.)

### Fase 6: Documentación
- [ ] README.md del módulo
- [ ] Ejemplos de uso (.http files)
- [ ] Actualizar MODULO_LOANS_COMPLETADO.md

### Post-Implementación
- [ ] Code review
- [ ] Merge a main
- [ ] Deploy a staging
- [ ] Smoke tests en staging
- [ ] Deploy a producción

---

## 🎯 CRITERIOS DE ÉXITO

### Funcional
- ✅ CRUD completo de préstamos
- ✅ Workflow de aprobación/rechazo funcional
- ✅ Cronograma generado automáticamente (trigger)
- ✅ Validación de crédito del asociado
- ✅ Balance calculado correctamente
- ✅ Filtros y paginación funcionales

### Técnico
- ✅ Clean Architecture 100%
- ✅ Type hints completos
- ✅ Docstrings en español
- ✅ Coverage >= 85%
- ✅ Logs estructurados
- ✅ Manejo de errores robusto

### Performance
- ✅ Crear préstamo: < 200ms
- ✅ Aprobar préstamo (con cronograma): < 500ms
- ✅ Listar 50 préstamos: < 300ms
- ✅ Detalle con balance: < 150ms

### Calidad
- ✅ 0 errores de lint
- ✅ 0 vulnerabilidades de seguridad
- ✅ Code review aprobado
- ✅ Documentación completa

---

## 📚 REFERENCIAS

### Documentos Consultados
1. `db/v2.0/modules/02_core_tables.sql` (tabla loans)
2. `db/v2.0/modules/05_functions_base.sql` (funciones)
3. `db/v2.0/modules/06_functions_business.sql` (trigger)
4. `db/v2.0/modules/03_business_tables.sql` (associate_profiles)
5. `docs/LOGICA_DE_NEGOCIO_DEFINITIVA.md` (reglas negocio)
6. `docs/ARQUITECTURA_BACKEND_V2_DEFINITIVA.md` (arquitectura)

### Módulos Relacionados
- `catalogs` (loan_statuses, associate_levels)
- `payments` (cronograma generado)
- `contracts` (1:1 con loans)
- `users` (cliente, asociado)
- `associate_profiles` (crédito disponible)

---

## 🚀 PRÓXIMO PASO

**LISTO PARA IMPLEMENTAR**

El análisis está completo. Tenemos:
- ✅ Comprensión total de la DB
- ✅ Comprensión total de la lógica de negocio
- ✅ Plan de implementación detallado
- ✅ Decisiones de diseño fundamentadas
- ✅ Mitigaciones de riesgos

**Siguiente acción:** Comenzar Fase 1 (Domain Layer).

---

**Fin del Análisis**
