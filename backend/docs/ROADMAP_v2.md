# 🚀 ROADMAP IMPLEMENTACIÓN BACKEND v2.0

> **Fecha**: 2025-10-30  
> **Estado**: Auth module implementado (5%) - 8 módulos pendientes (95%)  
> **Arquitectura**: Clean Architecture (Domain-Driven Design)  
> **Fuente de Verdad**: `/db/v2.0/modules/` (9 archivos SQL)  
> **Objetivo**: Implementar 100% de funcionalidad alineada con DB v2.0  

---

## 📊 ESTADO ACTUAL

### ✅ Módulo Implementado (1/9)
```
backend/app/modules/
└── auth/
    ├── domain/
    │   ├── entities/
    │   │   └── user.py (⚠️ Faltan campos)
    │   └── repositories/
    │       └── user_repository.py
    ├── application/
    │   ├── use_cases/
    │   │   └── login.py
    │   └── dtos/
    │       └── auth_dtos.py
    └── infrastructure/
        └── repositories/
            └── postgresql_user_repository.py
```

### ⚠️ Problema Detectado en Auth Module
**Archivo**: `/backend/app/modules/auth/domain/entities/user.py`  
**Campos faltantes** (según `db/v2.0/modules/02_core_tables.sql`):
- `birth_date` (DATE NULL)
- `curp` (VARCHAR(18) UNIQUE NULL)
- `profile_picture_url` (TEXT NULL)
- `created_at` (TIMESTAMPTZ DEFAULT NOW())
- `updated_at` (TIMESTAMPTZ DEFAULT NOW())

**Acción requerida**: Agregar campos a User entity

---

### ❌ Módulos Pendientes (8/9)

1. **catalogs** (12 catálogos) - FUNDAMENTO
2. **loans** (préstamos) - CRÍTICO
3. **payments** (pagos) - CRÍTICO
4. **associates** (perfiles asociados) - IMPORTANTE
5. **contracts** (contratos) - IMPORTANTE
6. **agreements** (convenios) - IMPORTANTE
7. **cut_periods** (cortes) - IMPORTANTE
8. **documents** (documentos) - NECESARIO

---

## 🎯 PLAN DE IMPLEMENTACIÓN

### FASE 0: Corrección Auth Module (Semana 1)

#### Fix User Entity
**Archivo**: `/backend/app/modules/auth/domain/entities/user.py`  
**Campos a agregar**:
```python
from datetime import date, datetime
from typing import Optional

@dataclass
class User:
    id: int
    email: str
    phone_number: str
    password_hash: str
    first_name: str
    last_name: str
    birth_date: Optional[date] = None              # ← AGREGAR
    curp: Optional[str] = None                      # ← AGREGAR
    profile_picture_url: Optional[str] = None       # ← AGREGAR
    is_active: bool = True
    created_at: Optional[datetime] = None           # ← AGREGAR
    updated_at: Optional[datetime] = None           # ← AGREGAR
```

**Fuente**: `db/v2.0/modules/02_core_tables.sql` (líneas 15-30)

---

### FASE 1: Catálogos (Semana 2-3) - FUNDAMENTO

#### Módulo: catalogs/
**Fuente**: `db/v2.0/modules/01_catalog_tables.sql` (12 catálogos)  
**Prioridad**: 🔴 CRÍTICA (todos los demás módulos dependen)

**Estructura**:
```
backend/app/modules/catalogs/
├── domain/
│   ├── entities/
│   │   ├── role.py
│   │   ├── loan_status.py
│   │   ├── payment_status.py
│   │   ├── associate_level.py
│   │   ├── payment_method.py
│   │   └── ... (7 más)
│   └── repositories/
│       └── catalog_repository.py (interfaz genérica)
├── application/
│   ├── use_cases/
│   │   ├── get_all_roles.py
│   │   ├── get_all_loan_statuses.py
│   │   └── ... (10 más)
│   └── dtos/
│       └── catalog_dtos.py
└── infrastructure/
    └── repositories/
        └── postgresql_catalog_repository.py
```

**Entidades a crear (12)**:
1. `Role` (id, name, description) - 5 roles
2. `LoanStatus` (id, name, description, color_code, icon_name) - 7 estados
3. `PaymentStatus` (id, name, description, **is_real_payment**) - 12 estados ⭐
4. `ContractStatus` (id, name, description) - 4 estados
5. `CutPeriodStatus` (id, name, description) - 4 estados
6. `PaymentMethod` (id, name, description) - 6 métodos
7. `DocumentStatus` (id, name, description) - 4 estados
8. `StatementStatus` (id, name, description) - 4 estados
9. `ConfigType` (id, name, description) - 3 tipos
10. `LevelChangeType` (id, name, description) - 3 tipos
11. `AssociateLevel` (id, level_name, max_loan_amount, credit_limit) - 5 niveles ⭐
12. `DocumentType` (id, type_name, is_required) - 6 tipos

**API Endpoints (12)**:
```
GET /catalogs/roles
GET /catalogs/loan-statuses
GET /catalogs/payment-statuses      ⭐ 12 estados (6 pending, 2 real, 4 fictitious)
GET /catalogs/contract-statuses
GET /catalogs/cut-period-statuses
GET /catalogs/payment-methods
GET /catalogs/document-statuses
GET /catalogs/statement-statuses
GET /catalogs/config-types
GET /catalogs/level-change-types
GET /catalogs/associate-levels      ⭐ 5 niveles con límites
GET /catalogs/document-types
```

**Características**:
- Read-only endpoints (solo GET)
- Cacheable (Redis opcional)
- Datos precargados desde `09_seeds.sql`

**Estimación**: 2 días por catálogo x 12 = 24 días (3 semanas)

---

### FASE 2: Préstamos (Semanas 4-7) - CRÍTICO

#### Módulo: loans/
**Fuente**: `db/v2.0/modules/02_core_tables.sql` (loans table)  
**Prioridad**: 🔴 CRÍTICA

**Estructura**:
```
backend/app/modules/loans/
├── domain/
│   ├── entities/
│   │   └── loan.py
│   └── repositories/
│       └── loan_repository.py
├── application/
│   ├── use_cases/
│   │   ├── create_loan.py
│   │   ├── get_loan_by_id.py
│   │   ├── list_loans.py
│   │   ├── approve_loan.py          ⭐ Trigger generate_payment_schedule
│   │   ├── reject_loan.py
│   │   ├── get_remaining_balance.py ⭐ Función DB
│   │   ├── calculate_preview.py     ⭐ Función DB
│   │   └── renew_loan.py            ⭐ Función DB
│   └── dtos/
│       └── loan_dtos.py
└── infrastructure/
    └── repositories/
        └── postgresql_loan_repository.py
```

**Entidad Loan**:
```python
@dataclass
class Loan:
    id: int
    user_id: int                    # Cliente
    associate_user_id: int          # Asociado que gestionó
    amount: Decimal
    interest_rate: Decimal          # Porcentaje
    commission_rate: Decimal        # Porcentaje
    term_biweeks: int               # 1-52 quincenas
    status_id: int                  # FK loan_statuses
    request_date: date
    approval_date: Optional[date]
    rejection_date: Optional[date]
    rejection_reason: Optional[str]
    total_amount: Decimal           # GENERATED (amount * (1 + interest_rate/100))
    biweekly_payment: Decimal       # GENERATED (total_amount / term_biweeks)
    created_at: datetime
    updated_at: datetime
```

**Use Cases críticos**:

1. **CreateLoan**
   - Validar: `term_biweeks BETWEEN 1 AND 52`
   - Validar: `amount > 0`
   - Validar: Asociado tiene crédito disponible (función `check_associate_credit_available()`)
   - Crear loan con `status_id = 1` (SOLICITADO)

2. **ApproveLoan** ⭐
   - Llamar función DB: `handle_loan_approval_status(loan_id, status_id)`
   - Trigger automático: `generate_payment_schedule()` crea todos los pagos
   - Actualizar crédito asociado automáticamente (trigger `update_associate_credit_on_loan_approval`)

3. **GetRemainingBalance** ⭐
   - Llamar función DB: `calculate_loan_remaining_balance(loan_id)`
   - NO calcular en backend (fuente de verdad es DB)

4. **CalculatePreview** ⭐
   - Llamar función DB: `calculate_payment_preview(amount, interest_rate, commission_rate, term_biweeks)`
   - Retorna: preview del cronograma completo

5. **RenewLoan** ⭐
   - Llamar función DB: `renew_loan(original_loan_id, new_amount, new_term_biweeks)`
   - Función liquida préstamo anterior + crea nuevo

**API Endpoints**:
```
POST   /loans
GET    /loans?page=1&status_id=2&user_id=4&associate_id=3
GET    /loans/:id
PUT    /loans/:id/approve
PUT    /loans/:id/reject
GET    /loans/:id/remaining-balance    ⭐ Función DB
POST   /loans/preview                  ⭐ Función DB
POST   /loans/:id/renew                ⭐ Función DB
GET    /loans/:id/payments
```

**Funciones DB a integrar** (5):
- `calculate_first_payment_date(request_date, term_biweeks)` - Oráculo doble calendario
- `check_associate_credit_available(associate_user_id, loan_amount)` - Validación crédito
- `calculate_loan_remaining_balance(loan_id)` - Saldo pendiente
- `calculate_payment_preview(...)` - Preview cronograma
- `renew_loan(original_loan_id, new_amount, new_term_biweeks)` - Renovación

**Triggers automáticos** (3):
- `generate_payment_schedule_trigger` - Crea cronograma al aprobar
- `update_associate_credit_on_loan_approval` - Actualiza credit_used
- `update_associate_credit_on_loan_deletion` - Reversa credit_used

**Estimación**: 4 semanas (CRUD + 5 funciones DB + triggers + tests)

---

### FASE 3: Pagos (Semanas 8-11) - CRÍTICO

#### Módulo: payments/
**Fuente**: `db/v2.0/modules/02_core_tables.sql` (payments), `04_audit_tables.sql` (payment_status_history)  
**Prioridad**: 🔴 CRÍTICA

**Estructura**:
```
backend/app/modules/payments/
├── domain/
│   ├── entities/
│   │   ├── payment.py
│   │   └── payment_history.py
│   └── repositories/
│       ├── payment_repository.py
│       └── payment_history_repository.py
├── application/
│   ├── use_cases/
│   │   ├── create_payment.py
│   │   ├── get_payment_by_id.py
│   │   ├── list_payments.py
│   │   ├── mark_payment_status.py        ⭐ Admin marca manualmente
│   │   ├── get_payment_history.py        ⭐ Timeline forense
│   │   ├── detect_suspicious_changes.py  ⭐ Fraude
│   │   └── revert_payment_change.py      ⭐ Reversión
│   └── dtos/
│       └── payment_dtos.py
└── infrastructure/
    └── repositories/
        ├── postgresql_payment_repository.py
        └── postgresql_payment_history_repository.py
```

**Entidad Payment**:
```python
@dataclass
class Payment:
    id: int
    loan_id: int
    cut_period_id: int
    payment_number: int             # 1, 2, 3..., term_biweeks
    scheduled_amount: Decimal
    amount_paid: Optional[Decimal]
    due_date: date                  # Calculado por Oráculo
    payment_date: Optional[date]
    status_id: int                  # FK payment_statuses (12 estados)
    payment_method_id: Optional[int]
    notes: Optional[str]
    created_at: datetime
    updated_at: datetime
```

**12 Estados de Pago** (payment_statuses):
- **Pendientes** (6): SCHEDULED, PENDING, DUE_TODAY, OVERDUE, IN_PROCESS, PENDING_VERIFICATION
- **Reales** (2): PAID, PAID_PARTIAL (`is_real_payment = true`)
- **Ficticios** (4): PAID_NOT_REPORTED, PAID_BY_ASSOCIATE, FORGIVEN, CANCELLED (`is_real_payment = false`)

**Use Cases críticos**:

1. **MarkPaymentStatus** ⭐
   - Llamar función DB: `admin_mark_payment_status(payment_id, new_status_id, admin_user_id, admin_notes)`
   - Trigger automático: `log_payment_status_change_trigger` registra en `payment_status_history`
   - Validar: Solo admin puede marcar manualmente

2. **GetPaymentHistory** ⭐
   - Llamar función DB: `get_payment_history(payment_id)`
   - Retorna: Timeline completo con usuario, timestamp, notas

3. **DetectSuspiciousChanges** ⭐
   - Llamar función DB: `detect_suspicious_payment_changes(hours_window)`
   - Retorna: Pagos con 3+ cambios en ventana temporal

4. **RevertPaymentChange** ⭐
   - Llamar función DB: `revert_last_payment_change(payment_id)`
   - Validar: Solo admin puede revertir

**API Endpoints**:
```
POST   /payments
GET    /payments?loan_id=1&status_id=3&cut_period_id=5
GET    /payments/:id
PUT    /payments/:id/mark-status       ⭐ Admin marca manualmente
GET    /payments/:id/history            ⭐ Timeline forense
POST   /payments/detect-suspicious      ⭐ Detección fraude
POST   /payments/:id/revert             ⭐ Reversión
```

**Funciones DB a integrar** (6):
- `admin_mark_payment_status(payment_id, new_status_id, admin_user_id, admin_notes)` - Marcado manual
- `log_payment_status_change(payment_id, old_status_id, new_status_id, changed_by_user_id, admin_notes)` - Log auditoría
- `get_payment_history(payment_id)` - Timeline
- `detect_suspicious_payment_changes(hours_window)` - Fraude
- `revert_last_payment_change(payment_id)` - Reversión
- `calculate_late_fee_for_statement(statement_id)` - Mora 30%

**Triggers automáticos** (2):
- `log_payment_status_change_trigger` - Auditoría automática
- `track_payment_in_associate_statement_trigger` - Actualiza statement asociado

**Vistas DB** (9):
- `v_payments_by_status_detailed` - Pagos con tracking completo
- `v_payments_absorbed_by_associate` - Pagos absorbidos
- `v_payment_changes_summary` - Resumen estadístico
- `v_recent_payment_changes` - Últimas 24 horas
- `v_payments_multiple_changes` - Pagos sospechosos (3+ cambios)
- `v_associate_late_fees` - Moras por asociado
- `v_associate_debt_detailed` - Deuda detallada
- `v_associate_credit_summary` - Resumen crédito
- `v_period_closure_summary` - Resumen cierre período

**Estimación**: 4 semanas (CRUD + 6 funciones + 2 triggers + 9 vistas + tests)

---

### FASE 4: Asociados (Semanas 12-15) - IMPORTANTE

#### Módulo: associates/
**Fuente**: `db/v2.0/modules/03_business_tables.sql` (associate_profiles, associate_payment_statements)  
**Prioridad**: 🟡 IMPORTANTE

**Estructura**:
```
backend/app/modules/associates/
├── domain/
│   ├── entities/
│   │   ├── associate_profile.py
│   │   └── payment_statement.py
│   └── repositories/
│       ├── associate_repository.py
│       └── statement_repository.py
├── application/
│   ├── use_cases/
│   │   ├── create_associate.py
│   │   ├── get_associate_by_id.py
│   │   ├── list_associates.py
│   │   ├── get_credit_summary.py         ⭐ Vista DB
│   │   ├── get_statements.py
│   │   ├── calculate_late_fee.py         ⭐ Función DB
│   │   └── check_credit_available.py     ⭐ Función DB
│   └── dtos/
│       └── associate_dtos.py
└── infrastructure/
    └── repositories/
        ├── postgresql_associate_repository.py
        └── postgresql_statement_repository.py
```

**Entidad AssociateProfile**:
```python
@dataclass
class AssociateProfile:
    user_id: int                    # FK users (1:1)
    level_id: int                   # FK associate_levels
    credit_limit: Decimal           # Límite según nivel
    credit_used: Decimal            # GENERATED (SUM loans activos)
    credit_available: Decimal       # GENERATED (credit_limit - credit_used)
    debt_balance: Decimal           # Deuda acumulada (convenios)
    created_at: datetime
    updated_at: datetime
```

**Entidad PaymentStatement**:
```python
@dataclass
class PaymentStatement:
    id: int
    associate_profile_id: int
    cut_period_id: int
    total_payments_count: int       # Total pagos en período
    paid_payments_count: int        # Pagos PAID
    not_reported_count: int         # Pagos PAID_NOT_REPORTED
    absorbed_payments_count: int    # Pagos PAID_BY_ASSOCIATE
    total_commission_owed: Decimal  # Comisión total
    late_fee_amount: Decimal        # Mora 30% (si total_payments_count = 0)
    late_fee_applied: bool
    status_id: int                  # FK statement_statuses
    created_at: datetime
    updated_at: datetime
```

**Use Cases críticos**:

1. **GetCreditSummary** ⭐
   - Usar vista DB: `v_associate_credit_summary`
   - Retorna: credit_status, active_loans_count, credit_usage_percentage, debt_balance

2. **CalculateLateFee** ⭐
   - Llamar función DB: `calculate_late_fee_for_statement(statement_id)`
   - Aplicar mora del 30% si `total_payments_count = 0` en período

3. **CheckCreditAvailable** ⭐
   - Llamar función DB: `check_associate_credit_available(associate_user_id, loan_amount)`
   - Validar antes de aprobar préstamo

**API Endpoints**:
```
POST   /associates
GET    /associates
GET    /associates/:id
GET    /associates/:id/credit-summary       ⭐ Vista v_associate_credit_summary
GET    /associates/:id/statements?cut_period_id=5
POST   /associates/:id/statements/:id/pay
```

**Funciones DB a integrar** (2):
- `check_associate_credit_available(associate_user_id, loan_amount)` - Validación crédito
- `calculate_late_fee_for_statement(statement_id)` - Mora 30%

**Vistas DB** (3):
- `v_associate_credit_summary` - Resumen crédito (credit_status, usage_percentage)
- `v_associate_debt_detailed` - Deuda por tipo (UNREPORTED, DEFAULTED, LATE_FEE)
- `v_associate_late_fees` - Moras pendientes

**Triggers automáticos** (4):
- `update_associate_credit_on_loan_approval` - Actualiza credit_used
- `update_associate_credit_on_loan_deletion` - Reversa credit_used
- `track_payment_in_associate_statement_trigger` - Actualiza statement
- `accumulate_associate_debt_trigger` - Acumula deuda al cerrar período

**Estimación**: 4 semanas (CRUD + 2 funciones + 4 triggers + 3 vistas + tests)

---

### FASE 5: Contratos (Semanas 16-18) - IMPORTANTE

#### Módulo: contracts/
**Fuente**: `db/v2.0/modules/02_core_tables.sql` (contracts)  
**Prioridad**: 🟡 IMPORTANTE

**Estructura**:
```
backend/app/modules/contracts/
├── domain/
│   ├── entities/
│   │   └── contract.py
│   └── repositories/
│       └── contract_repository.py
├── application/
│   ├── use_cases/
│   │   ├── generate_contract.py       ⭐ PDF generation
│   │   ├── get_contract_by_id.py
│   │   ├── sign_contract.py
│   │   └── list_contracts.py
│   └── dtos/
│       └── contract_dtos.py
└── infrastructure/
    └── repositories/
        └── postgresql_contract_repository.py
```

**Entidad Contract**:
```python
@dataclass
class Contract:
    id: int
    loan_id: int                    # FK loans (1:1)
    contract_number: str            # UNIQUE
    contract_text: str              # Texto completo
    status_id: int                  # FK contract_statuses
    generated_at: datetime
    signed_at: Optional[datetime]
    signature_path: Optional[str]   # Firma digitalizada
    created_at: datetime
    updated_at: datetime
```

**Use Cases críticos**:

1. **GenerateContract** ⭐
   - Template engine (Jinja2)
   - Datos desde: loan, user, associate, payments schedule
   - Generar PDF (ReportLab o WeasyPrint)
   - Almacenar contract_text y archivo PDF

2. **SignContract**
   - Upload firma digitalizada
   - Actualizar `status_id = SIGNED`
   - Timestamp `signed_at`

**API Endpoints**:
```
POST   /loans/:loan_id/contract/generate    ⭐ Genera PDF
POST   /contracts/:id/sign
GET    /contracts/:id
GET    /contracts/:id/pdf
GET    /loans/:loan_id/contract
```

**Estimación**: 3 semanas (CRUD + PDF generation + signature handling + tests)

---

### FASE 6: Convenios (Semanas 19-22) - IMPORTANTE

#### Módulo: agreements/
**Fuente**: `db/v2.0/modules/03_business_tables.sql` (agreements, agreement_items, agreement_payments)  
**Prioridad**: 🟡 IMPORTANTE

**Estructura**:
```
backend/app/modules/agreements/
├── domain/
│   ├── entities/
│   │   ├── agreement.py
│   │   ├── agreement_item.py
│   │   └── agreement_payment.py
│   └── repositories/
│       ├── agreement_repository.py
│       └── agreement_payment_repository.py
├── application/
│   ├── use_cases/
│   │   ├── create_agreement.py
│   │   ├── get_agreement_by_id.py
│   │   ├── list_agreements.py
│   │   ├── add_agreement_payment.py
│   │   └── complete_agreement.py
│   └── dtos/
│       └── agreement_dtos.py
└── infrastructure/
    └── repositories/
        ├── postgresql_agreement_repository.py
        └── postgresql_agreement_payment_repository.py
```

**Entidad Agreement**:
```python
@dataclass
class Agreement:
    id: int
    associate_profile_id: int
    total_debt_amount: Decimal
    payment_plan_months: int
    monthly_payment_amount: Decimal
    agreement_date: date
    status: str                     # ACTIVE, COMPLETED, BREACHED
    created_at: datetime
    updated_at: datetime
```

**Entidad AgreementItem**:
```python
@dataclass
class AgreementItem:
    id: int
    agreement_id: int
    loan_id: Optional[int]
    client_user_id: int
    debt_amount: Decimal
    debt_type: str                  # UNREPORTED_PAYMENT, DEFAULTED_CLIENT, LATE_FEE
```

**Entidad AgreementPayment**:
```python
@dataclass
class AgreementPayment:
    id: int
    agreement_id: int
    payment_number: int
    scheduled_date: date
    amount_paid: Optional[Decimal]
    payment_date: Optional[date]
    notes: Optional[str]
    created_at: datetime
```

**Use Cases críticos**:

1. **CreateAgreement**
   - Calcular `monthly_payment_amount = total_debt_amount / payment_plan_months`
   - Crear items de deuda (UNREPORTED, DEFAULTED, LATE_FEE)
   - Generar cronograma mensual (agreement_payments)

2. **AddAgreementPayment**
   - Registrar pago mensual
   - Actualizar saldo pendiente
   - Marcar como COMPLETED si liquidado

**API Endpoints**:
```
POST   /agreements
GET    /agreements?associate_profile_id=1&status=ACTIVE
GET    /agreements/:id
GET    /agreements/:id/items
POST   /agreements/:id/payments
PUT    /agreements/:id/complete
```

**Estimación**: 4 semanas (CRUD + calculation logic + payment tracking + tests)

---

### FASE 7: Períodos de Corte (Semanas 23-26) - IMPORTANTE

#### Módulo: cut_periods/
**Fuente**: `db/v2.0/modules/02_core_tables.sql` (cut_periods), `06_functions_business.sql` (close_period)  
**Prioridad**: 🟡 IMPORTANTE

**Estructura**:
```
backend/app/modules/cut_periods/
├── domain/
│   ├── entities/
│   │   └── cut_period.py
│   └── repositories/
│       └── cut_period_repository.py
├── application/
│   ├── use_cases/
│   │   ├── create_cut_period.py
│   │   ├── get_cut_period_by_id.py
│   │   ├── list_cut_periods.py
│   │   └── close_period.py                ⭐ Función DB crítica
│   └── dtos/
│       └── cut_period_dtos.py
└── infrastructure/
    └── repositories/
        └── postgresql_cut_period_repository.py
```

**Entidad CutPeriod**:
```python
@dataclass
class CutPeriod:
    id: int
    period_number: int              # 1, 2, 3..., 24 (año)
    year: int
    period_start_date: date         # Día 8
    period_end_date: date           # Día 23
    status_id: int                  # FK cut_period_statuses
    created_at: datetime
    updated_at: datetime
```

**Use Cases críticos**:

1. **CreateCutPeriod**
   - Validar: `period_start_date` día 8
   - Validar: `period_end_date` día 23
   - Generar 24 períodos por año (script SQL existe)

2. **ClosePeriod** ⭐
   - Llamar función DB: `close_period_and_accumulate_debt(cut_period_id)`
   - Función marca TODOS los pagos:
     - Cliente pagó → `PAID`
     - Cliente NO pagó + reportado → `PAID_NOT_REPORTED` + acumula deuda
     - Cliente NO pagó + NO reportado → `PAID_BY_ASSOCIATE` + acumula deuda
   - Trigger automático: `accumulate_associate_debt_trigger` actualiza debt_balance

**API Endpoints**:
```
POST   /cut-periods
GET    /cut-periods?year=2025
GET    /cut-periods/:id
POST   /cut-periods/:id/close              ⭐ Función DB crítica
GET    /cut-periods/:id/summary            ⭐ Vista v_period_closure_summary
```

**Función DB CRÍTICA**:
- `close_period_and_accumulate_debt(cut_period_id)` - Cierra período, marca pagos, acumula deuda

**Vista DB**:
- `v_period_closure_summary` - Resumen (payments_paid, payments_not_reported, payments_by_associate, total_collected)

**Trigger automático**:
- `accumulate_associate_debt_trigger` - Acumula deuda en associate_profiles

**Estimación**: 4 semanas (CRUD + función crítica + trigger + vista + tests)

---

### FASE 8: Documentos (Semanas 27-29) - NECESARIO

#### Módulo: documents/
**Fuente**: `db/v2.0/modules/02_core_tables.sql` (client_documents)  
**Prioridad**: 🟢 NECESARIO

**Estructura**:
```
backend/app/modules/documents/
├── domain/
│   ├── entities/
│   │   └── document.py
│   └── repositories/
│       └── document_repository.py
├── application/
│   ├── use_cases/
│   │   ├── upload_document.py
│   │   ├── get_document_by_id.py
│   │   ├── list_documents.py
│   │   ├── update_document_status.py
│   │   └── delete_document.py
│   └── dtos/
│       └── document_dtos.py
└── infrastructure/
    └── repositories/
        └── postgresql_document_repository.py
```

**Entidad ClientDocument**:
```python
@dataclass
class ClientDocument:
    id: int
    user_id: int                    # FK users (cliente)
    document_type_id: int           # FK document_types
    file_name: str
    file_path: str                  # /uploads/documents/{user_id}/{filename}
    mime_type: str
    file_size_kb: int
    status_id: int                  # FK document_statuses
    upload_date: datetime
    review_date: Optional[datetime]
    reviewed_by_user_id: Optional[int]
    review_notes: Optional[str]
    created_at: datetime
    updated_at: datetime
```

**Use Cases críticos**:

1. **UploadDocument**
   - Validar mime_type (PDF, JPG, PNG)
   - Validar file_size_kb (max 5MB)
   - Almacenar en `/uploads/documents/{user_id}/`
   - Crear registro en DB

2. **UpdateDocumentStatus**
   - Cambiar status (PENDING → UNDER_REVIEW → APPROVED/REJECTED)
   - Registrar reviewed_by_user_id y review_notes

**API Endpoints**:
```
POST   /clients/:user_id/documents/upload
GET    /clients/:user_id/documents
GET    /documents/:id
PUT    /documents/:id/status
DELETE /documents/:id
GET    /documents/:id/download
```

**Estimación**: 3 semanas (CRUD + file handling + validation + tests)

---

## 📐 ARQUITECTURA CLEAN

### Estructura de Módulo Estándar
```
backend/app/modules/{module_name}/
├── domain/
│   ├── entities/         # Objetos de negocio (dataclasses)
│   │   └── {entity}.py
│   └── repositories/     # Interfaces (ABC)
│       └── {entity}_repository.py
├── application/
│   ├── use_cases/        # Casos de uso (1 archivo = 1 acción)
│   │   ├── create_{entity}.py
│   │   ├── get_{entity}_by_id.py
│   │   └── list_{entities}.py
│   └── dtos/             # Data Transfer Objects
│       └── {module}_dtos.py
└── infrastructure/
    └── repositories/     # Implementaciones (PostgreSQL)
        └── postgresql_{entity}_repository.py
```

### Capas y Dependencias
```
Presentation Layer (FastAPI routes)
        ↓
Application Layer (Use Cases)
        ↓
Domain Layer (Entities + Repository Interfaces)
        ↑
Infrastructure Layer (Repository Implementations)
```

### Reglas de Oro
1. **Domain NO depende de nadie** (entities + interfaces)
2. **Application depende de Domain** (use cases usan entities + interfaces)
3. **Infrastructure implementa Domain** (repositories implementan interfaces)
4. **Presentation depende de Application** (routes llaman use cases)

---

## 🛠️ TECNOLOGÍAS

### Core
- Python 3.11+
- FastAPI 0.110+
- PostgreSQL 15+
- SQLAlchemy 2.0 (async)
- Pydantic v2

### Utilidades
- python-jose (JWT)
- passlib (password hashing)
- python-multipart (file uploads)
- reportlab / weasyprint (PDF generation)
- jinja2 (templates)

### Testing
- pytest
- pytest-asyncio
- httpx (async client)
- faker (test data)

### DevOps
- Docker + Docker Compose
- Alembic (migrations)
- Black (formatter)
- Ruff (linter)

---

## ✅ CHECKLIST DE CALIDAD

### Por Cada Módulo
- [ ] Entities alineadas 100% con DB v2.0
- [ ] Repository interface (ABC)
- [ ] Repository implementation (PostgreSQL)
- [ ] Use cases con validaciones
- [ ] DTOs con Pydantic
- [ ] FastAPI routes
- [ ] Funciones DB integradas (NO duplicar lógica)
- [ ] Vistas DB integradas
- [ ] Tests unitarios (use cases)
- [ ] Tests de integración (repositories)
- [ ] Tests E2E (routes)
- [ ] Documentación OpenAPI

### Reglas de Oro
1. **NUNCA duplicar lógica DB**: Usar funciones
2. **SIEMPRE usar vistas**: Para consultas complejas
3. **SIEMPRE validar**: Application + Domain
4. **SIEMPRE async**: PostgreSQL async driver
5. **SIEMPRE testear**: Cobertura mínima 80%

---

## 📅 CRONOGRAMA COMPLETO

| Fase | Duración | Módulo | Prioridad |
|------|----------|--------|-----------|
| **Fase 0** | 1 semana | Fix Auth Module | 🔴 CRÍTICA |
| **Fase 1** | 3 semanas | Catálogos (12) | 🔴 CRÍTICA |
| **Fase 2** | 4 semanas | Préstamos | 🔴 CRÍTICA |
| **Fase 3** | 4 semanas | Pagos + Auditoría | 🔴 CRÍTICA |
| **Fase 4** | 4 semanas | Asociados | 🟡 IMPORTANTE |
| **Fase 5** | 3 semanas | Contratos | 🟡 IMPORTANTE |
| **Fase 6** | 4 semanas | Convenios | 🟡 IMPORTANTE |
| **Fase 7** | 4 semanas | Períodos de Corte | 🟡 IMPORTANTE |
| **Fase 8** | 3 semanas | Documentos | 🟢 NECESARIO |
| **TOTAL** | **30 semanas** (~7.5 meses) | | |

---

## 🚀 PRÓXIMOS PASOS INMEDIATOS

1. ✅ Agregar campos faltantes a User entity (auth module)
2. ✅ Crear estructura vacía módulo catalogs/
3. ✅ Implementar CatalogRepository (genérico)
4. ✅ Implementar 12 catálogos (read-only)
5. ✅ Crear tests unitarios catalogs
6. ✅ Continuar con Fase 2 (loans)

---

**Última actualización**: 2025-10-30  
**Basado en**: `/db/v2.0/modules/` (fuente de verdad absoluta)  
**Arquitectura**: Clean Architecture + DDD
