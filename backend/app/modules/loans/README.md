# Módulo de Préstamos (Loans) - v2.0

## 📋 Estado Actual: Sprint 4 COMPLETADO ✅

**Fecha:** Octubre 2025
**Complejidad:** 9/10
**Criticidad:** MÁXIMA (Corazón del sistema)

---

## 🎯 Objetivos Completados

### Sprint 1 ✅
- ✅ Domain Layer completo (entities + repository interfaces)
- ✅ Infrastructure Layer (models SQLAlchemy + PostgreSQL repository)
- ✅ Application Layer (DTOs para request/response)
- ✅ Presentation Layer (3 endpoints GET funcionales)
- ✅ Tests de integración críticos (64 casos para fechas)

### Sprint 2 ✅
- ✅ Application Service (LoanService con validaciones de negocio)
- ✅ POST /loans (crear solicitud con validaciones)
- ✅ POST /loans/{id}/approve (aprobar con transacción ACID)
- ✅ POST /loans/{id}/reject (rechazar con razón obligatoria)
- ✅ Tests unitarios (12 casos para LoanService)

### Sprint 3 ✅
- ✅ PUT /loans/{id} (actualizar préstamo PENDING)
- ✅ DELETE /loans/{id} (eliminar préstamo PENDING o REJECTED)
- ✅ POST /loans/{id}/cancel (cancelar préstamo ACTIVE)
- ✅ LoanService.update_loan() (actualizar con validaciones)
- ✅ LoanService.cancel_loan() (cancelar y liberar crédito)
- ✅ Tests unitarios adicionales (9 casos nuevos)

### Sprint 4 ✅ (Optimizaciones)
- ✅ Integration tests para endpoints (10 tests + 1 E2E)
- ✅ Logger profesional (reemplazó prints)
- ✅ Logging estructurado (INFO, WARNING, ERROR)
- ✅ Helpers para log de auditoría
- ✅ Documentación completa de Sprints 2, 3 y 4

---

## 🏗️ Arquitectura

```
app/modules/loans/
├── domain/
│   ├── entities/__init__.py         ✅ Loan, LoanBalance, Enums, Value Objects
│   └── repositories/__init__.py     ✅ LoanRepository (interface ABC)
├── infrastructure/
│   ├── models/__init__.py           ✅ LoanModel (SQLAlchemy)
│   └── repositories/__init__.py     ✅ PostgreSQLLoanRepository (13 métodos)
├── application/
│   ├── dtos/__init__.py             ✅ 10 DTOs (Request/Response)
│   ├── services/__init__.py         ✅ LoanService (7 métodos principales)
│   └── logger.py                    ✅ Sistema de logging estructurado
└── routes.py                        ✅ 9 endpoints (3 GET + 6 POST/PUT/DELETE)
```

---

## 📊 Sistema de Doble Calendario ⭐

**CRÍTICO:** Sistema único en la industria para calcular fechas de pagos quincenales.

### Reglas del Doble Calendario

| Ventana de Aprobación | Primer Pago |
|----------------------|-------------|
| Días **1-7** del mes | Día **15** del **mismo** mes |
| Días **8-22** del mes | **Último día** del **mismo** mes |
| Días **23-31** del mes | Día **15** del **siguiente** mes |

### Ejemplos Prácticos

```
2024-01-05 (día 5)  → 2024-01-15
2024-01-10 (día 10) → 2024-01-31
2024-01-25 (día 25) → 2024-02-15
```

### Casos Especiales

- **Febrero bisiesto:** 2024-02-10 → 2024-02-29
- **Febrero no bisiesto:** 2023-02-10 → 2023-02-28
- **Cambio de año:** 2024-12-25 → 2025-01-15

### Implementación

La lógica está implementada en la **función DB** `calculate_first_payment_date()`:

```sql
-- db/v2.0/modules/05_functions_base.sql (líneas 23-96)
CREATE OR REPLACE FUNCTION calculate_first_payment_date(
    approval_date DATE
) RETURNS DATE AS $$
BEGIN
    -- Reglas del doble calendario
    ...
END;
$$ LANGUAGE plpgsql IMMUTABLE STRICT PARALLEL SAFE;
```

**Backend:** Confía 100% en esta función, **NO replica la lógica**.

```python
# Infrastructure Repository
async def calculate_first_payment_date(self, approval_date: date) -> date:
    """Delega a la función DB (oráculo del sistema)."""
    query = select(func.calculate_first_payment_date(approval_date))
    result = await self.session.execute(query)
    return result.scalar()
```

---

## 🔐 Funciones DB Críticas

### 1. `calculate_first_payment_date(approval_date)` ⭐ ORÁCULO
- **Propósito:** Calcula fecha del primer pago según doble calendario
- **Input:** Fecha de aprobación
- **Output:** Fecha del primer pago
- **Cobertura:** 64 tests de integración

### 2. `generate_payment_schedule()` TRIGGER
- **Propósito:** Genera cronograma completo de pagos automáticamente
- **Trigger:** AFTER INSERT OR UPDATE ON loans (cuando status → APPROVED)
- **Efecto:** Crea N registros en `payments` (N = term_biweeks)
- **Backend:** Solo cambia `status_id`, trigger hace todo

### 3. `check_associate_credit_available(associate_id, amount)`
- **Propósito:** Valida si asociado tiene crédito disponible
- **Input:** ID asociado, monto solicitado
- **Output:** Boolean
- **Regla:** `credit_limit - credit_used >= amount`

### 4. `calculate_loan_remaining_balance(loan_id)`
- **Propósito:** Calcula saldo pendiente del préstamo
- **Input:** ID préstamo
- **Output:** Decimal (saldo restante)
- **Regla:** `SUM(payments.amount) - SUM(payments.amount_paid)`

---

## 📦 Entidades de Dominio

### Loan (Entity)

```python
@dataclass
class Loan:
    id: int
    user_id: int                    # Cliente
    associate_user_id: int          # Asociado
    amount: Decimal                 # Monto del préstamo
    interest_rate: Decimal          # Tasa de interés (%)
    commission_rate: Decimal        # Tasa de comisión (%)
    term_biweeks: int              # Plazo en quincenas (1-52)
    status_id: int                 # Estado (1-10)
    
    # Aprobación/Rechazo
    approved_at: datetime
    approved_by: int
    rejected_at: datetime
    rejected_by: int
    rejection_reason: str
    
    # Métodos de consulta
    is_pending() → bool
    is_approved() → bool
    can_be_approved() → bool
    
    # Cálculos de negocio
    calculate_total_to_pay() → Decimal
    calculate_payment_amount() → Decimal
```

### LoanBalance (Value Object)

```python
@dataclass(frozen=True)
class LoanBalance:
    loan_id: int
    total_amount: Decimal
    total_paid: Decimal
    remaining_balance: Decimal
    payment_count: int
    payments_completed: int
    
    # Métodos
    is_paid_off() → bool
    completion_percentage() → Decimal
```

### LoanStatusEnum

```python
class LoanStatusEnum(IntEnum):
    PENDING = 1        # Pendiente de aprobación
    APPROVED = 2       # Aprobado (trigger genera pagos)
    ACTIVE = 3         # Activo (cliente pagando)
    PAID_OFF = 4       # Totalmente pagado
    DEFAULTED = 5      # En mora
    REJECTED = 6       # Rechazado
    CANCELLED = 7      # Cancelado
    RESTRUCTURED = 8   # Reestructurado
    OVERDUE = 9        # Vencido
    EARLY_PAYMENT = 10 # Pago anticipado
```

---

## 🌐 API Endpoints

### Sprint 1: Endpoints de Lectura (GET)

#### GET /loans

Lista préstamos con filtros y paginación.

**Query Parameters:**
- `status_id`: Filtrar por estado (opcional)
- `user_id`: Filtrar por cliente (opcional)
- `associate_user_id`: Filtrar por asociado (opcional)
- `limit`: Máximo de registros (1-100, default 50)
- `offset`: Desplazamiento para paginación (default 0)

**Response:**
```json
{
    "items": [...],
    "total": 150,
    "limit": 50,
    "offset": 0
}
```

**Ejemplos:**
```bash
GET /api/v1/loans
GET /api/v1/loans?status_id=1
GET /api/v1/loans?user_id=5&limit=20
```

#### GET /loans/{loan_id}

Obtiene detalle completo de un préstamo.

**Errores:**
- `404`: Préstamo no encontrado

#### GET /loans/{loan_id}/balance

Obtiene el balance actual de un préstamo.

**Errores:**
- `404`: Préstamo no encontrado

### Sprint 2: Endpoints de Escritura (POST)

#### POST /loans

Crea una nueva solicitud de préstamo.

**Validaciones:**
- ✅ Asociado tiene crédito disponible
- ✅ Cliente no tiene préstamos PENDING
- ✅ Cliente no es moroso

**Body:**
```json
{
    "user_id": 5,
    "associate_user_id": 10,
    "amount": 5000.00,
    "interest_rate": 2.50,
    "commission_rate": 0.50,
    "term_biweeks": 12,
    "notes": "Préstamo para negocio"
}
```

**Response:** `201 Created` con préstamo en estado PENDING

**Errores:**
- `400`: Validación fallida

**Ejemplo:**
```bash
curl -X POST http://localhost:8000/api/v1/loans \
  -H "Content-Type: application/json" \
  -d '{"user_id": 5, "associate_user_id": 10, "amount": 5000, ...}'
```

#### POST /loans/{loan_id}/approve ⭐

Aprueba un préstamo.

**Proceso:**
1. Validar que esté PENDING
2. Validar pre-aprobación (crédito, morosidad)
3. Calcular fecha primer pago (doble calendario)
4. Actualizar a APPROVED
5. Trigger genera cronograma automáticamente

**Body:**
```json
{
    "approved_by": 2,
    "notes": "Aprobado por cumplir requisitos"
}
```

**Response:** Préstamo aprobado

**Errores:**
- `404`: Préstamo no encontrado
- `400`: Validación fallida

**Ejemplo:**
```bash
curl -X POST http://localhost:8000/api/v1/loans/123/approve \
  -H "Content-Type: application/json" \
  -d '{"approved_by": 2}'
```

#### POST /loans/{loan_id}/reject

Rechaza un préstamo.

**Body:**
```json
{
    "rejected_by": 2,
    "rejection_reason": "Documentación incompleta. Falta cédula actualizada."
}
```

**Response:** Préstamo rechazado

**Errores:**
- `404`: Préstamo no encontrado
- `400`: Validación fallida (razón vacía)

**Ejemplo:**
```bash
curl -X POST http://localhost:8000/api/v1/loans/123/reject \
  -H "Content-Type: application/json" \
  -d '{"rejected_by": 2, "rejection_reason": "..."}'
```

### Sprint 3: Endpoints Adicionales

#### PUT /loans/{loan_id}

Actualiza un préstamo que está en estado PENDING.

**Campos actualizables:**
- `amount`: Nuevo monto
- `interest_rate`: Nueva tasa de interés
- `commission_rate`: Nueva tasa de comisión
- `term_biweeks`: Nuevo plazo
- `notes`: Notas sobre la actualización

**Validaciones:**
- ✅ Préstamo existe y está PENDING
- ✅ Si se cambia el monto, verificar crédito del asociado

**Body:**
```json
{
    "amount": 6000.00,
    "interest_rate": 3.0,
    "notes": "Actualizado por solicitud del cliente"
}
```

**Response:** Préstamo actualizado

**Errores:**
- `404`: Préstamo no encontrado
- `400`: No está PENDING o validación fallida

**Ejemplo:**
```bash
curl -X PUT http://localhost:8000/api/v1/loans/123 \
  -H "Content-Type: application/json" \
  -d '{"amount": 6000, "interest_rate": 3.0}'
```

#### DELETE /loans/{loan_id}

Elimina un préstamo que está en estado PENDING o REJECTED.

**Validaciones:**
- ✅ Préstamo existe
- ✅ Préstamo está PENDING o REJECTED (no se pueden eliminar APPROVED/ACTIVE)

**Response:** `204 No Content`

**Errores:**
- `404`: Préstamo no encontrado
- `400`: Estado incorrecto

**Ejemplo:**
```bash
curl -X DELETE http://localhost:8000/api/v1/loans/123
```

#### POST /loans/{loan_id}/cancel

Cancela un préstamo que está en estado ACTIVE.

**Proceso:**
1. Validar que esté ACTIVE
2. Validar razón de cancelación (obligatoria, mínimo 10 caracteres)
3. Actualizar a CANCELLED
4. Trigger libera crédito del asociado automáticamente
5. Pagos ya realizados se mantienen como histórico

**Body:**
```json
{
    "cancelled_by": 2,
    "cancellation_reason": "Cliente solicitó cancelación por liquidación anticipada"
}
```

**Response:** Préstamo cancelado

**Errores:**
- `404`: Préstamo no encontrado
- `400`: No está ACTIVE o razón inválida

**Ejemplo:**
```bash
curl -X POST http://localhost:8000/api/v1/loans/123/cancel \
  -H "Content-Type: application/json" \
  -d '{"cancelled_by": 2, "cancellation_reason": "..."}'
```

---

## 📊 Resumen de Endpoints Implementados

| Método | Endpoint | Descripción | Sprint | Estado |
|--------|----------|-------------|--------|--------|
| GET | /loans | Listar préstamos con filtros | 1 | ✅ |
| GET | /loans/{id} | Detalle de préstamo | 1 | ✅ |
| GET | /loans/{id}/balance | Balance de préstamo | 1 | ✅ |
| POST | /loans | Crear solicitud | 2 | ✅ |
| POST | /loans/{id}/approve | Aprobar préstamo ⭐ | 2 | ✅ |
| POST | /loans/{id}/reject | Rechazar préstamo | 2 | ✅ |
| PUT | /loans/{id} | Actualizar PENDING | 3 | ✅ |
| DELETE | /loans/{id} | Eliminar PENDING/REJECTED | 3 | ✅ |
| POST | /loans/{id}/cancel | Cancelar ACTIVE | 3 | ✅ |

**Total:** 9 endpoints funcionales (API REST completa)

---

## 🧪 Tests

### Tests de Integración - Fechas (CRÍTICO)

**test_calculate_first_payment_date_integration.py** - 64 casos:

- ✅ Ventana 1 (días 1-7): 7 casos
- ✅ Ventana 2 (días 8-22): 9 casos
- ✅ Ventana 3 (días 23-31): 7 casos
- ✅ Febrero bisiesto vs no bisiesto: 2 casos
- ✅ Cambio de año (Dic → Ene): 3 casos
- ✅ Cobertura completa año 2024: 36 casos (3 por mes)

**Objetivo:** Garantizar certeza absoluta en las fechas.

### Tests de Integración - Endpoints (Sprint 4)

**test_loan_endpoints_integration.py** - 10 casos + 1 E2E:

- ✅ create_loan_request: 1 caso (DB real)
- ✅ approve_loan: 2 casos (trigger payments, fecha cálculo)
- ✅ reject_loan: 1 caso (razón obligatoria)
- ✅ update_loan: 1 caso (partial update)
- ✅ delete_loan: 2 casos (PENDING, REJECTED)
- ✅ cancel_loan: 1 caso (liberar crédito trigger)
- ✅ full_workflow: 1 caso (E2E completo)

**Objetivo:** Validar que endpoints funcionan con DB real y triggers se ejecutan.

### Tests Unitarios (LoanService)

**test_loan_service.py** - 21 casos:

- ✅ create_loan_request(): 4 casos
- ✅ approve_loan(): 4 casos
- ✅ reject_loan(): 4 casos
- ✅ update_loan(): 4 casos (Sprint 3)
- ✅ cancel_loan(): 5 casos (Sprint 3)

**Objetivo:** Validar lógica de negocio completa del servicio.

### Ejecutar Tests

```bash
# Solo tests de loans
pytest tests/modules/loans/ -v

# Solo test crítico de fechas
pytest tests/modules/loans/integration/test_calculate_first_payment_date_integration.py -v

# Con cobertura
pytest tests/modules/loans/ --cov=app.modules.loans --cov-report=html
```

---

## 🗃️ Modelo de Base de Datos

### Tabla: loans

```sql
CREATE TABLE loans (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id),
    associate_user_id INTEGER REFERENCES users(id),
    amount NUMERIC(12, 2) NOT NULL CHECK (amount > 0),
    interest_rate NUMERIC(5, 2) NOT NULL CHECK (interest_rate >= 0 AND interest_rate <= 100),
    commission_rate NUMERIC(5, 2) NOT NULL DEFAULT 0.0 CHECK (commission_rate >= 0 AND commission_rate <= 100),
    term_biweeks INTEGER NOT NULL CHECK (term_biweeks >= 1 AND term_biweeks <= 52),
    status_id INTEGER NOT NULL REFERENCES loan_statuses(id),
    contract_id INTEGER REFERENCES contracts(id),
    approved_at TIMESTAMPTZ CHECK (approved_at >= created_at),
    approved_by INTEGER REFERENCES users(id),
    rejected_at TIMESTAMPTZ CHECK (rejected_at >= created_at),
    rejected_by INTEGER REFERENCES users(id),
    rejection_reason TEXT,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

### Índices (Optimización)

```sql
CREATE INDEX idx_loans_user_id ON loans(user_id);
CREATE INDEX idx_loans_associate_user_id ON loans(associate_user_id);
CREATE INDEX idx_loans_status_id ON loans(status_id);
CREATE INDEX idx_loans_approved_at ON loans(approved_at) WHERE approved_at IS NOT NULL;
CREATE INDEX idx_loans_status_id_approved_at ON loans(status_id, approved_at);
```

---

## ⏳ Roadmap

### ✅ Sprint 1 (3 días) - COMPLETADO
- ✅ Domain Layer (entities + repository interfaces)
- ✅ Infrastructure Layer (models SQLAlchemy + PostgreSQL repository)
- ✅ Application Layer (DTOs)
- ✅ Presentation Layer (3 endpoints GET)
- ✅ Tests de integración críticos (64 casos para fechas)

### ✅ Sprint 2 (5 días) - COMPLETADO
- ✅ Application Service (LoanService)
- ✅ POST /loans (crear solicitud con validaciones)
- ✅ POST /loans/{id}/approve (aprobar con ACID)
- ✅ POST /loans/{id}/reject (rechazar con razón)
- ✅ Validaciones pre-aprobación (crédito, morosidad)
- ✅ Transacciones ACID con triggers
- ✅ Tests unitarios (12 casos)

### ✅ Sprint 3 (3 días) - COMPLETADO
- ✅ PUT /loans/{id} (actualizar préstamo PENDING)
- ✅ DELETE /loans/{id} (eliminar PENDING/REJECTED)
- ✅ POST /loans/{id}/cancel (cancelar ACTIVE)
- ✅ LoanService.update_loan() con validaciones
- ✅ LoanService.cancel_loan() con liberación de crédito
- ✅ Tests unitarios adicionales (9 casos nuevos)

### ✅ Sprint 4 (Optimizaciones) - COMPLETADO
- ✅ Integration tests para endpoints POST/PUT/DELETE (10 casos)
- ✅ Test E2E del flujo completo (1 caso)
- ✅ Logger profesional con formato estructurado (logger.py)
- ✅ Migración completa de prints a logging estructurado
- ✅ 8 helper functions para auditoría de eventos
- ⏳ Optimizaciones de queries (joins, eager loading) - OPCIONAL
- ⏳ Validación de documentos completos (depende módulo documents) - PENDIENTE
- ⏳ Rate limiting y caché (Redis) - PENDIENTE

---

## 📚 Documentación Adicional

- **Análisis Completo:** `docs/phase3/ANALISIS_MODULO_LOANS.md` (50+ páginas)
- **Lógica de Negocio:** `docs/LOGICA_DE_NEGOCIO_DEFINITIVA.md`
- **Arquitectura Backend:** `docs/ARQUITECTURA_BACKEND_V2_DEFINITIVA.md`
- **Base de Datos:**
  - `db/v2.0/modules/02_core_tables.sql` (tabla loans)
  - `db/v2.0/modules/05_functions_base.sql` (funciones)
  - `db/v2.0/modules/06_functions_business.sql` (triggers)

---

## ⚠️ Consideraciones Críticas

### ⭐ Fechas (PREOCUPACIÓN DEL USUARIO)

> "Necesitamos certeza en las fechas, este módulo es el más importante, no debe haber ningún error."

**Estrategia Implementada:**

1. ✅ **Confiar 100% en función DB** `calculate_first_payment_date()`
2. ✅ **NO replicar lógica** de doble calendario en backend
3. ✅ **64 tests de integración** para validar fechas
4. ✅ **Documentación exhaustiva** del sistema

### Sistema de Crédito del Asociado

- SELECT FOR UPDATE en `associate_profiles` para evitar race conditions
- Validar `credit_limit - credit_used >= amount` ANTES de aprobar
- Actualizar `credit_used` en transacción ACID

### Trigger Automático

- Backend solo cambia `status_id` a APPROVED
- Trigger `generate_payment_schedule()` hace el resto:
  - Crea N registros en `payments`
  - Calcula fechas quincenales
  - Asigna montos de cuota

### Validaciones en 3 Niveles

1. **DB:** CheckConstraints, ForeignKeys, Triggers
2. **Application:** Lógica de negocio en services
3. **Domain:** Validaciones en entidades (__post_init__)

---

## 🎓 Aprendizajes

- Análisis exhaustivo PREVIO a implementación previene errores críticos
- Confiar en funciones DB probadas > replicar lógica compleja en backend
- Enfoque incremental permite validar arquitectura temprano
- Documentar decisiones de diseño facilita debugging futuro
- Tests de integración para funciones DB aseguran certeza en fechas

---

**Estado:** Sprint 1 COMPLETADO ✅  
**Próximo paso:** Sprint 2 - Implementar aprobación/rechazo de préstamos  
**Fecha:** Actualizado 2025
