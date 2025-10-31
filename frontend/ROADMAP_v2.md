# 🚀 ROADMAP RECONSTRUCCIÓN FRONTEND v2.0

> **Fecha**: 2025-10-30  
> **Estado**: Frontend limpiado radicalmente - Solo 7 componentes UI conservados  
> **Fuente de Verdad**: `/db/v2.0/modules/` (9 archivos SQL)  
> **Objetivo**: Reconstruir frontend 100% alineado con DB v2.0 y Clean Architecture backend  

---

## 📊 ESTADO ACTUAL

### ✅ Componentes Conservados (7 archivos)
```
frontend/src/components/
├── Navbar.jsx             - Navegación principal
├── Footer.jsx             - Pie de página
├── ProtectedRoute.jsx     - Guard de rutas
├── DatePicker.jsx         - Selector de fechas
├── CollapsibleSection.jsx - Sección colapsable
├── ErrorModal.jsx         - Modal de errores
└── DebugPanel.jsx         - Panel de debugging
```

### ❌ Eliminado (137 archivos)
- 27 páginas completas (LoansPage, CreateLoanPage, etc.)
- 28 componentes con lógica obsoleta
- Services completos (API vieja)
- Hooks completos
- Context completo

---

## 🎯 MÓDULOS A IMPLEMENTAR (Basados en db/v2.0/modules/)

### PRIORIDAD 1: CORE (Semanas 1-4)

#### Módulo 1: Autenticación y Usuarios
**Fuente**: `02_core_tables.sql` (users, user_roles)  
**Páginas**:
- `/login` - LoginPage.jsx
- `/dashboard` - DashboardPage.jsx (rol-aware)
- `/profile` - ProfilePage.jsx

**Componentes**:
- `UserProfile.jsx` - Datos usuario (first_name, last_name, email, phone_number, birth_date, curp, profile_picture_url)
- `RolesBadge.jsx` - Mostrar roles del usuario (JOIN con user_roles)

**API Endpoints** (Clean Architecture):
```
POST /auth/login
GET  /auth/me
PUT  /auth/me/profile
```

**Catálogos necesarios**: `roles` (5 roles)

---

#### Módulo 2: Catálogos
**Fuente**: `01_catalog_tables.sql` (12 catálogos)  
**Páginas**:
- `/admin/catalogs` - CatalogsManagementPage.jsx

**Componentes**:
- `CatalogTable.jsx` - Tabla genérica para catálogos
- `LoanStatusBadge.jsx` - Badge con color_code e icon_name
- `PaymentStatusBadge.jsx` - Badge con is_real_payment (💵 vs ⚠️)
- `AssociateLevelCard.jsx` - Tarjeta con max_loan_amount y credit_limit

**API Endpoints**:
```
GET /catalogs/roles
GET /catalogs/loan-statuses
GET /catalogs/payment-statuses (12 estados)
GET /catalogs/associate-levels (5 niveles)
GET /catalogs/payment-methods
GET /catalogs/document-types
```

**CRÍTICO**: Usar catálogos en TODOS los selects (NO hardcodear strings)

---

### PRIORIDAD 2: PRÉSTAMOS (Semanas 5-8)

#### Módulo 3: Préstamos
**Fuente**: `02_core_tables.sql` (loans, contracts, payments)  
**Páginas**:
- `/loans` - LoansListPage.jsx
- `/loans/:id` - LoanDetailsPage.jsx
- `/loans/new` - CreateLoanPage.jsx
- `/loans/:id/payments` - LoanPaymentsPage.jsx

**Componentes**:
- `LoanForm.jsx` - Formulario crear/editar (user_id, associate_user_id, amount, interest_rate, commission_rate, term_biweeks)
- `LoanStatusTimeline.jsx` - Timeline visual (created_at, approved_at, rejected_at)
- `PaymentScheduleTable.jsx` - Cronograma completo (generado por trigger `generate_payment_schedule`)
- `LoanCalculator.jsx` - Preview usando función `calculate_payment_preview()`

**API Endpoints**:
```
GET    /loans?page=1&status_id=2&user_id=4
POST   /loans
PUT    /loans/:id/approve
PUT    /loans/:id/reject
GET    /loans/:id
GET    /loans/:id/payments
GET    /loans/:id/remaining-balance (usa función DB)
```

**Funciones DB a integrar**:
- `calculate_first_payment_date()` - Oráculo del doble calendario
- `calculate_payment_preview()` - Preview del cronograma
- `calculate_loan_remaining_balance()` - Saldo pendiente

**Validaciones Frontend**:
- `term_biweeks` BETWEEN 1 AND 52
- `amount` > 0
- `interest_rate` 0-100
- `commission_rate` 0-100
- Asociado tiene crédito disponible (ver Módulo 4)

---

### PRIORIDAD 3: ASOCIADOS (Semanas 9-12)

#### Módulo 4: Asociados y Crédito
**Fuente**: `03_business_tables.sql` (associate_profiles, associate_payment_statements)  
**Páginas**:
- `/associates` - AssociatesListPage.jsx
- `/associates/:id` - AssociateDetailsPage.jsx
- `/associates/:id/credit` - AssociateCreditPage.jsx (credit_limit, credit_used, credit_available, debt_balance)
- `/associates/:id/statements` - AssociateStatementsPage.jsx

**Componentes**:
- `AssociateCreditCard.jsx` - Tarjeta con crédito disponible (vista `v_associate_credit_summary`)
- `CreditUsageProgressBar.jsx` - Barra visual (credit_usage_percentage)
- `AssociateLevelBadge.jsx` - Nivel actual con max_loan_amount y credit_limit
- `PaymentStatementCard.jsx` - Estado de cuenta (total_payments_count, total_commission_owed, late_fee_amount)

**API Endpoints**:
```
GET  /associates
GET  /associates/:id
GET  /associates/:id/credit-summary (vista v_associate_credit_summary)
GET  /associates/:id/statements?cut_period_id=5
POST /associates/:id/statements/:id/pay
```

**Funciones DB a integrar**:
- `check_associate_credit_available()` - Validar crédito antes de aprobar préstamo
- `calculate_late_fee_for_statement()` - Calcular mora del 30%

**Vista DB**: `v_associate_credit_summary` (credit_status, credit_usage_percentage)

---

### PRIORIDAD 4: PAGOS Y CORTES (Semanas 13-16)

#### Módulo 5: Pagos y Estados
**Fuente**: `02_core_tables.sql` (payments), `04_audit_tables.sql` (payment_status_history)  
**Páginas**:
- `/payments` - PaymentsListPage.jsx
- `/payments/:id` - PaymentDetailsPage.jsx
- `/payments/:id/history` - PaymentHistoryPage.jsx (auditoría completa)

**Componentes**:
- `PaymentTable.jsx` - Tabla con 12 estados posibles (PENDING, DUE_TODAY, OVERDUE, PAID, PAID_NOT_REPORTED, PAID_BY_ASSOCIATE, etc.)
- `PaymentStatusBadge.jsx` - Badge con tipo (REAL 💵 vs FICTICIO ⚠️)
- `PaymentHistoryTimeline.jsx` - Timeline forense de cambios (función `get_payment_history()`)
- `MarkPaymentModal.jsx` - Admin marca manualmente estado (función `admin_mark_payment_status()`)

**API Endpoints**:
```
GET   /payments?loan_id=1&status_id=3&cut_period_id=5
PUT   /payments/:id/mark-status (admin marca manualmente)
GET   /payments/:id/history (timeline forense)
POST  /payments/detect-suspicious (función detect_suspicious_payment_changes())
POST  /payments/:id/revert (función revert_last_payment_change())
```

**Funciones DB a integrar**:
- `admin_mark_payment_status()` - Marcar manualmente con notas
- `get_payment_history()` - Timeline completo
- `detect_suspicious_payment_changes()` - Detección de fraude
- `revert_last_payment_change()` - Reversión de emergencia

**Vistas DB**:
- `v_payments_by_status_detailed` - Pagos con tracking completo
- `v_payments_absorbed_by_associate` - Pagos absorbidos por asociado
- `v_payment_changes_summary` - Resumen estadístico
- `v_recent_payment_changes` - Últimas 24 horas
- `v_payments_multiple_changes` - Pagos sospechosos (3+ cambios)

---

#### Módulo 6: Períodos de Corte
**Fuente**: `02_core_tables.sql` (cut_periods)  
**Páginas**:
- `/cut-periods` - CutPeriodsListPage.jsx
- `/cut-periods/:id` - CutPeriodDetailsPage.jsx
- `/cut-periods/:id/close` - ClosePeriodPage.jsx

**Componentes**:
- `CutPeriodCard.jsx` - Tarjeta con período (period_start_date, period_end_date, status_id)
- `PeriodClosureSummary.jsx` - Resumen de cierre (vista `v_period_closure_summary`)
- `PeriodStatsCard.jsx` - Estadísticas (total_payments_expected, total_payments_received, total_commission)

**API Endpoints**:
```
GET  /cut-periods?year=2025
POST /cut-periods (crear período)
POST /cut-periods/:id/close (función close_period_and_accumulate_debt())
GET  /cut-periods/:id/summary (vista v_period_closure_summary)
```

**Función DB CRÍTICA**:
- `close_period_and_accumulate_debt()` - Cierra período, marca TODOS los pagos (PAID, PAID_NOT_REPORTED, PAID_BY_ASSOCIATE), acumula deuda

**Vista DB**: `v_period_closure_summary` (payments_paid, payments_not_reported, payments_by_associate, total_collected)

---

### PRIORIDAD 5: MOROSIDAD Y CONVENIOS (Semanas 17-20)

#### Módulo 7: Clientes Morosos
**Fuente**: `04_audit_tables.sql` (defaulted_client_reports), `03_business_tables.sql` (associate_debt_breakdown)  
**Páginas**:
- `/reports/defaulted-clients` - DefaultedClientsReportsPage.jsx
- `/reports/defaulted-clients/:id` - ReportDetailsPage.jsx
- `/reports/defaulted-clients/new` - CreateReportPage.jsx

**Componentes**:
- `ReportForm.jsx` - Formulario reporte moroso (loan_id, total_debt_amount, evidence_details, evidence_file_path)
- `EvidenceViewer.jsx` - Visor de evidencia (archivos, fotos, etc.)
- `ReportStatusBadge.jsx` - Badge (PENDING, APPROVED, REJECTED, IN_REVIEW)

**API Endpoints**:
```
GET  /reports/defaulted-clients?status=PENDING
POST /reports/defaulted-clients (función report_defaulted_client())
PUT  /reports/:id/approve (función approve_defaulted_client_report())
PUT  /reports/:id/reject
```

**Funciones DB**:
- `report_defaulted_client()` - Crear reporte con evidencia
- `approve_defaulted_client_report()` - Aprobar, marca pagos como PAID_BY_ASSOCIATE, crea deuda

**Vista DB**: `v_associate_debt_detailed` (deuda por tipo: UNREPORTED_PAYMENT, DEFAULTED_CLIENT, LATE_FEE)

---

#### Módulo 8: Convenios de Pago
**Fuente**: `03_business_tables.sql` (agreements, agreement_items, agreement_payments)  
**Páginas**:
- `/agreements` - AgreementsListPage.jsx
- `/agreements/:id` - AgreementDetailsPage.jsx
- `/agreements/new` - CreateAgreementPage.jsx

**Componentes**:
- `AgreementForm.jsx` - Formulario convenio (total_debt_amount, payment_plan_months, monthly_payment_amount)
- `AgreementItemsTable.jsx` - Desglose de deuda (loan_id, client_user_id, debt_amount, debt_type)
- `AgreementPaymentsSchedule.jsx` - Cronograma mensual
- `PayAgreementModal.jsx` - Registrar pago de convenio

**API Endpoints**:
```
GET  /agreements?associate_profile_id=1&status=ACTIVE
POST /agreements
GET  /agreements/:id
GET  /agreements/:id/items
POST /agreements/:id/payments (registrar pago mensual)
```

---

### PRIORIDAD 6: RENOVACIONES Y DOCUMENTOS (Semanas 21-24)

#### Módulo 9: Renovaciones
**Fuente**: `03_business_tables.sql` (loan_renewals), `06_functions_business.sql` (renew_loan)  
**Páginas**:
- `/loans/:id/renew` - RenewLoanPage.jsx

**Componentes**:
- `RenewLoanForm.jsx` - Formulario renovación (new_amount, new_term_biweeks)
- `PendingBalanceCard.jsx` - Saldo pendiente calculado
- `RenewalPreview.jsx` - Preview de nuevo préstamo

**API Endpoints**:
```
GET  /loans/:id/remaining-balance
POST /loans/:id/renew (función renew_loan())
GET  /loans/:id/renewals (historial)
```

**Función DB**: `renew_loan()` - Liquida préstamo anterior, crea nuevo

---

#### Módulo 10: Documentos de Clientes
**Fuente**: `02_core_tables.sql` (client_documents), `01_catalog_tables.sql` (document_types, document_statuses)  
**Páginas**:
- `/clients/:id/documents` - ClientDocumentsPage.jsx

**Componentes**:
- `DocumentUploader.jsx` - Cargador de archivos (file_name, file_path, mime_type)
- `DocumentsList.jsx` - Lista de documentos con estados
- `DocumentViewer.jsx` - Visor (PDF, imágenes)
- `DocumentStatusBadge.jsx` - Badge (PENDING, UNDER_REVIEW, APPROVED, REJECTED)

**API Endpoints**:
```
GET    /clients/:id/documents
POST   /clients/:id/documents (upload)
PUT    /documents/:id/status
DELETE /documents/:id
```

---

## 🛠️ TECNOLOGÍAS Y PATRONES

### Stack Frontend
- React 18
- Vite 5
- React Router v6
- Axios (API calls)
- TailwindCSS (styling)
- React Query (caching)

### Patrones de Diseño
1. **Container/Presenter**: Separar lógica de presentación
2. **Custom Hooks**: `useLoans`, `usePayments`, `useAssociates`, etc.
3. **API Service Layer**: `api/loans.js`, `api/payments.js`, etc.
4. **Global State**: Context API o Zustand
5. **Error Boundaries**: Manejo robusto de errores

### Convenciones
- **Componentes**: PascalCase (`LoanCard.jsx`)
- **Hooks**: camelCase con prefix `use` (`useLoanData.js`)
- **Services**: camelCase (`loanService.js`)
- **Constantes**: UPPER_SNAKE_CASE
- **Props**: camelCase
- **API**: snake_case (matching DB fields)

---

## 📐 ARQUITECTURA FRONTEND

```
frontend/src/
├── api/                    # API service layer
│   ├── client.js          # Axios configurado
│   ├── auth.js
│   ├── loans.js
│   ├── payments.js
│   └── catalogs.js
├── components/            # Componentes reutilizables
│   ├── ui/               # UI genéricos (conservados)
│   ├── loans/            # Componentes de préstamos
│   ├── payments/         # Componentes de pagos
│   └── associates/       # Componentes de asociados
├── hooks/                # Custom hooks
│   ├── useAuth.js
│   ├── useLoans.js
│   └── usePayments.js
├── pages/                # Páginas (rutas)
│   ├── auth/
│   ├── loans/
│   ├── payments/
│   └── associates/
├── context/              # Global state
│   ├── AuthContext.jsx
│   └── CatalogsContext.jsx
├── utils/                # Utilidades
│   ├── formatters.js     # Formateo de fechas, moneda
│   ├── validators.js     # Validaciones
│   └── constants.js      # Constantes
└── styles/               # Estilos globales
```

---

## ✅ CHECKLIST DE CALIDAD

### Por Cada Módulo
- [ ] Componentes 100% alineados con DB v2.0
- [ ] NO hardcodear estados (usar catálogos)
- [ ] Usar funciones DB para cálculos (NO duplicar lógica)
- [ ] Vistas DB para consultas complejas
- [ ] Manejo de errores robusto
- [ ] Loading states
- [ ] Validaciones frontend + backend
- [ ] Tests unitarios
- [ ] Tests E2E críticos
- [ ] Documentación de componentes

### Reglas de Oro
1. **NUNCA hardcodear**: Siempre usar catálogos
2. **NUNCA duplicar lógica**: Usar funciones DB
3. **SIEMPRE validar**: Frontend + Backend
4. **SIEMPRE usar vistas**: Para consultas complejas
5. **SIEMPRE auditoría**: Tracking de cambios críticos

---

## 📅 CRONOGRAMA ESTIMADO

| Fase | Duración | Módulos |
|------|----------|---------|
| **Fase 1: Core** | 4 semanas | Auth, Catálogos |
| **Fase 2: Préstamos** | 4 semanas | Loans, Contracts |
| **Fase 3: Asociados** | 4 semanas | Profiles, Credit, Statements |
| **Fase 4: Pagos** | 4 semanas | Payments, Cut Periods |
| **Fase 5: Morosidad** | 4 semanas | Reports, Agreements |
| **Fase 6: Extras** | 4 semanas | Renewals, Documents |
| **TOTAL** | **24 semanas** (~6 meses) |

---

## 🚀 PRÓXIMOS PASOS INMEDIATOS

1. ✅ Crear estructura de carpetas vacía
2. ✅ Configurar Vite + React Router
3. ✅ Configurar Axios con base URL
4. ✅ Implementar AuthContext
5. ✅ Crear página de login (Módulo 1)
6. ✅ Implementar catálogos (Módulo 2)
7. ✅ Continuar con Módulo 3 (Préstamos)

---

**Última actualización**: 2025-10-30  
**Basado en**: `/db/v2.0/modules/` (fuente de verdad absoluta)
