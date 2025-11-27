# 🗺️ MAPA DE RELACIONES ENTRE MÓDULOS - CREDINET V2.0

**Fecha**: 2025-11-05  
**Propósito**: Diagrama visual de cómo se relacionan los módulos del sistema

---

## 📊 DIAGRAMA DE MÓDULOS Y FLUJOS

```
┌──────────────────────────────────────────────────────────────────────┐
│                           CREDINET V2.0                              │
│                    Arquitectura de Módulos                           │
└──────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                        CAPA DE PRESENTACIÓN                          │
│                         (REST APIs - FastAPI)                        │
└─────────────────────────────────────────────────────────────────────┘
           │                  │                  │                │
           ▼                  ▼                  ▼                ▼
    ┌──────────┐      ┌──────────┐      ┌──────────┐    ┌──────────┐
    │   AUTH   │      │  LOANS   │      │  RATE    │    │ CATALOGS │
    │   (✅)   │      │   (✅)   │      │ PROFILES │    │   (✅)   │
    │          │      │          │      │   (✅)   │    │          │
    └────┬─────┘      └────┬─────┘      └────┬─────┘    └────┬─────┘
         │                 │                  │               │
         │                 │ ┌────────────────┴───────────┐   │
         │                 │ │                            │   │
         │                 ▼ ▼                            ▼   │
         │          ┌──────────────┐             ┌──────────────┐
         │          │  PAYMENTS    │             │  CLIENTS     │
         │          │    (❌)      │◄────────────┤    (❌)      │
         │          │              │             │              │
         │          └──────┬───────┘             └──────────────┘
         │                 │                            │
         │                 │ ┌──────────────────────────┘
         │                 │ │
         │                 ▼ ▼
         │          ┌──────────────┐
         │          │  ASSOCIATES  │
         │          │    (❌)      │
         │          │              │
         │          └──────┬───────┘
         │                 │
         │                 ▼
         │          ┌──────────────┐
         └──────────┤   PAYMENT    │
                    │  STATEMENTS  │
                    │    (❌)      │
                    └──────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                        CAPA DE BASE DE DATOS                         │
│                         (PostgreSQL 15)                              │
└─────────────────────────────────────────────────────────────────────┘
    ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌────────────┐
    │   users    │  │   loans    │  │  payments  │  │  associate │
    │            │  │            │  │            │  │  _profiles │
    └────────────┘  └────────────┘  └────────────┘  └────────────┘

Legend:
✅ Implementado    ❌ No implementado
```

---

## 🔗 MATRIZ DE DEPENDENCIAS

| Módulo              | Depende de                                    | Lo usan                          |
|---------------------|-----------------------------------------------|----------------------------------|
| **AUTH** ✅         | users (DB)                                    | Todos los módulos                |
| **LOANS** ✅        | rate_profiles, associates*, clients*          | payments*, payment_statements*   |
| **RATE_PROFILES** ✅| associate_levels (DB)                         | loans                            |
| **CATALOGS** ✅     | -                                             | loans, payments*                 |
| **PAYMENTS** ❌     | loans, associates*, payment_schedule (DB)     | payment_statements*              |
| **CLIENTS** ❌      | users (DB)                                    | loans                            |
| **ASSOCIATES** ❌   | associate_profiles (DB), users                | loans, payments*, statements*    |
| **STATEMENTS** ❌   | associates*, cut_periods (DB), payments*      | -                                |

\* = Módulo no implementado

---

## 📈 FLUJO 1: CREAR PRÉSTAMO

```
Usuario (Admin)
    │
    │ 1. POST /loans
    ▼
┌──────────┐
│  LOANS   │ ──────► Valida datos (Pydantic)
└────┬─────┘         Verifica cliente existe*
     │                Verifica associate_id
     │ 2. Valida crédito
     ▼
┌──────────────────┐
│ DB: Función      │
│ check_associate_ │ ──────► Consulta credit_available
│ credit_available │         Retorna TRUE/FALSE
└────┬─────────────┘
     │ 3. Si OK
     ▼
┌──────────────────┐
│ RATE_PROFILES    │ ──────► Obtiene interest_rate
└────┬─────────────┘         Obtiene commission_rate
     │
     │ 4. Calcula montos
     ▼
┌──────────────────┐
│ DB: INSERT loans │ ──────► Status = PENDING
└────┬─────────────┘
     │
     │ 5. Retorna Loan DTO
     ▼
Usuario recibe préstamo creado

* Actualmente se valida manualmente, debería ser módulo clients
```

---

## 📈 FLUJO 2: APROBAR PRÉSTAMO

```
Admin
    │
    │ 1. PUT /loans/:id/approve
    ▼
┌──────────┐
│  LOANS   │ ──────► Valida préstamo existe
└────┬─────┘         Valida status = PENDING
     │
     │ 2. Valida crédito NUEVAMENTE
     ▼
┌──────────────────┐
│ DB: check_       │ ──────► credit_available >= amount?
│ associate_credit │
└────┬─────────────┘
     │ 3. Si OK
     ▼
┌──────────────────┐
│ DB: UPDATE loans │ ──────► status = APPROVED
│                  │         approval_date = NOW()
└────┬─────────────┘
     │
     │ 4. TRIGGER automático
     ▼
┌──────────────────┐
│ DB: Función      │ ──────► calculate_first_payment_date()
│ generate_payment │         Genera 12 pagos
│ _schedule()      │         Asigna cut_period_id
└────┬─────────────┘
     │
     │ 5. TRIGGER actualiza crédito
     ▼
┌──────────────────┐
│ DB: UPDATE       │ ──────► credit_used += amount
│ associate_       │
│ profiles         │
└────┬─────────────┘
     │
     │ 6. Retorna Loan con schedule
     ▼
Admin recibe préstamo aprobado
```

---

## 📈 FLUJO 3: REGISTRAR PAGO (IDEAL)

```
Asociado (o Admin)
    │
    │ 1. POST /payments  (❌ NO EXISTE)
    ▼
┌──────────┐
│ PAYMENTS │ ──────► Valida payment_id existe
└────┬─────┘         Valida status = PENDING
     │                Valida amount_paid > 0
     │
     │ 2. Registra pago
     ▼
┌──────────────────┐
│ DB: UPDATE       │ ──────► amount_paid += amount
│ payments         │         payment_date = NOW()
│                  │         status = PAID
└────┬─────────────┘
     │
     │ 3. TRIGGER automático
     ▼
┌──────────────────┐
│ DB: UPDATE       │ ──────► credit_used -= amount_paid
│ associate_       │         (libera crédito)
│ profiles         │
└────┬─────────────┘
     │
     │ 4. TRIGGER auditoría
     ▼
┌──────────────────┐
│ DB: INSERT       │ ──────► Registra cambio de estado
│ payment_status_  │         old_status → new_status
│ history          │         changed_by, changed_at
└────┬─────────────┘
     │
     │ 5. Actualiza loan
     ▼
┌──────────────────┐
│ DB: Recalcula    │ ──────► balance_remaining -= principal
│ loan balance     │         Si balance = 0 → status = COMPLETED
└────┬─────────────┘
     │
     │ 6. Retorna Payment DTO
     ▼
Asociado recibe confirmación
```

**Estado actual**: ❌ Este flujo NO existe porque no hay módulo `payments`.

---

## 📈 FLUJO 4: GENERAR RELACIÓN DE PAGO (IDEAL)

```
Job Automático (días 8 y 23)
    │
    │ 1. Se activa a las 6 AM
    ▼
┌──────────────────┐
│ PAYMENT          │ ──────► Obtiene período actual
│ STATEMENTS       │         (cut_period_id)
└────┬─────────────┘
     │
     │ 2. Para cada asociado activo
     ▼
┌──────────────────┐
│ DB: SELECT       │ ──────► Obtiene pagos del período
│ payments WHERE   │         cut_period_id = current
│ cut_period_id    │         associate_id = X
└────┬─────────────┘
     │
     │ 3. Calcula totales
     ▼
┌──────────────────┐
│ Lógica de        │ ──────► total_client_payment
│ negocio          │         total_associate_payment
│                  │         commission_amount
│                  │         insurance_fee
└────┬─────────────┘
     │
     │ 4. Obtiene snapshot de crédito
     ▼
┌──────────────────┐
│ DB: SELECT       │ ──────► credit_limit
│ v_associate_     │         credit_used
│ credit_summary   │         credit_available
│                  │         debt_balance
└────┬─────────────┘
     │
     │ 5. Genera documento
     ▼
┌──────────────────┐
│ DB: INSERT       │ ──────► Crea associate_payment_statement
│ associate_       │         status = GENERATED
│ payment_         │
│ statements       │
└────┬─────────────┘
     │
     │ 6. Genera PDF
     ▼
┌──────────────────┐
│ PDF Generator    │ ──────► Usa plantilla
│                  │         Incluye tabla de préstamos
│                  │         Totales, firmas
└────┬─────────────┘
     │
     │ 7. Notifica
     ▼
Supervisor recibe notificación
Asociado recibe PDF por email
```

**Estado actual**: ❌ Este flujo NO existe porque no hay módulo `payment_statements`.

---

## 🎯 INTERACCIONES CRÍTICAS

### 1. Loans ↔ Associates

```
LOANS necesita ASSOCIATES para:
✓ Validar crédito disponible
✓ Ocupar crédito al aprobar
✓ Liberar crédito al pagar

Estado actual:
✅ Funciona vía triggers en DB
❌ No hay endpoints para consultar
❌ No hay UI para ver crédito
```

### 2. Loans ↔ Payments

```
LOANS genera PAYMENT_SCHEDULE pero:
✓ Schedule se crea automáticamente (trigger)
✗ No hay forma de registrar pagos (no hay módulo)
✗ No hay forma de consultar pagos pendientes

Estado actual:
✅ Tabla payments existe
✅ Triggers funcionan
❌ No hay módulo backend
❌ No hay endpoints
```

### 3. Associates ↔ Payment Statements

```
ASSOCIATES reciben PAYMENT_STATEMENTS pero:
✗ No se generan automáticamente (no hay job)
✗ No hay endpoint para generarlas manualmente
✗ No hay PDF

Estado actual:
✅ Tabla associate_payment_statements existe
✅ Lógica documentada
❌ No hay módulo backend
❌ No hay automatización
```

### 4. Clients ↔ Loans

```
CLIENTS solicitan LOANS pero:
✗ No hay módulo clients
✗ Información del cliente está en loans
✗ No hay validación estructurada

Estado actual:
⚠️ Funciona, pero no escalable
⚠️ Cliente debería ser entidad independiente
```

---

## 📊 COBERTURA DE CASOS DE USO

| Caso de Uso                    | Backend | DB | Frontend | Estado |
|--------------------------------|---------|----|----|---------|
| Login                          | ✅      | ✅ | ✅ | ✅ Completo |
| Crear préstamo                 | ✅      | ✅ | ❌ | ⚠️ Backend only |
| Aprobar préstamo               | ✅      | ✅ | ❌ | ⚠️ Backend only |
| Registrar pago                 | ❌      | ✅ | ❌ | 🔴 Solo DB |
| Ver crédito asociado           | ❌      | ✅ | ❌ | 🔴 Solo DB |
| Generar relación de pago       | ❌      | ✅ | ❌ | 🔴 Solo DB |
| Gestionar cliente              | ❌      | ✅ | ❌ | 🔴 Solo DB |
| Consultar payment schedule     | ❌      | ✅ | ❌ | 🔴 Solo DB |
| Ver historial de pagos         | ❌      | ✅ | ❌ | 🔴 Solo DB |

---

## 🔧 ESTRATEGIA DE INTEGRACIÓN

### Fase 1: Backend Core (sin frontend)

```
1. Implementar módulo PAYMENTS
   ├── Domain: Payment entity
   ├── Application: RegisterPaymentUseCase
   ├── Infrastructure: PostgreSQLPaymentRepository
   └── Presentation: POST /payments

2. Implementar módulo ASSOCIATES
   ├── Domain: Associate entity
   ├── Application: GetAssociateCreditUseCase
   ├── Infrastructure: PostgreSQLAssociateRepository
   └── Presentation: GET /associates/:id/credit

3. Implementar módulo CLIENTS
   ├── Domain: Client entity
   ├── Application: CreateClientUseCase
   ├── Infrastructure: PostgreSQLClientRepository
   └── Presentation: CRUD /clients

4. Implementar módulo PAYMENT_STATEMENTS
   ├── Domain: PaymentStatement entity
   ├── Application: GenerateStatementUseCase
   ├── Infrastructure: PostgreSQLStatementRepository
   ├── Jobs: generate_statements_job.py
   └── Presentation: POST /statements/generate
```

### Fase 2: Frontend (después del backend)

```
1. Setup Feature-Sliced Design
   ├── app/
   ├── pages/
   ├── widgets/
   ├── features/
   ├── entities/
   └── shared/

2. Páginas principales
   ├── DashboardPage
   ├── LoansPage
   ├── PaymentsPage
   ├── AssociatesPage
   └── ClientsPage

3. Integración con backend
   ├── API client
   ├── State management
   └── Error handling
```

---

## 🎓 APRENDIZAJES CLAVE

### ✅ Lo que está funcionando bien

1. **Lógica de negocio en DB**: Triggers mantienen integridad
2. **Clean Architecture**: Separación clara de capas
3. **Documentación**: Exhaustiva y coherente
4. **Esquema de BD**: Robusto y bien normalizado

### ⚠️ Lo que necesita atención

1. **Módulos faltantes**: 4 módulos críticos sin implementar
2. **Exposición de APIs**: Lógica existe pero no está expuesta
3. **Frontend**: Solo login, resto por hacer
4. **Tests**: Faltan tests de módulos no implementados

### 🎯 Próximos pasos inmediatos

1. ✅ **Leer este análisis completo**
2. ✅ **Priorizar módulo PAYMENTS** (más crítico)
3. ✅ **Implementar ASSOCIATES** (segundo más crítico)
4. ⏳ **Decidir sobre CLIENTS** (puede esperar)
5. ⏳ **Planificar PAYMENT_STATEMENTS** (puede hacerse manual)

---

**Generado**: 2025-11-05  
**Próxima revisión**: Después de implementar módulos faltantes

---

## 📚 REFERENCIAS

- Análisis completo: `docs/00_START_HERE/ANALISIS_COMPLETO_SISTEMA.md`
- Índice maestro: `docs/business_logic/INDICE_MAESTRO.md`
- Arquitectura: `docs/00_START_HERE/02_ARQUITECTURA_STACK.md`
