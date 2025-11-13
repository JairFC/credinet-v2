# 🏗️ ARQUITECTURA Y STACK TÉCNICO

**Tiempo de lectura:** ~10 minutos  
**Prerequisito:** Haber leído `01_PROYECTO_OVERVIEW.md`

---

## 📚 TABLA DE CONTENIDO

1. [Stack Tecnológico](#stack-tecnológico)
2. [Arquitectura Backend](#arquitectura-backend)
3. [Arquitectura Frontend](#arquitectura-frontend)
4. [Base de Datos](#base-de-datos)
5. [Infraestructura](#infraestructura)
6. [Flujo de Datos](#flujo-de-datos)

---

## 🛠️ STACK TECNOLÓGICO

### Backend
```
Framework:     FastAPI 0.104+
Lenguaje:      Python 3.11+
ORM:           SQLAlchemy 2.0
Validación:    Pydantic v2
Auth:          JWT (python-jose)
Testing:       pytest + pytest-asyncio
CORS:          fastapi-cors
```

### Frontend
```
Framework:     React 18.2+
Build Tool:    Vite 7.1+
Routing:       React Router v6
State:         Context API + hooks
UI:            TailwindCSS (planeado)
Arquitectura:  Feature-Sliced Design (FSD)
```

### Base de Datos
```
Motor:         PostgreSQL 15
Esquema:       36 tablas, 21 funciones, 28 triggers
Versión:       v2.0.3
Migraciones:   SQL scripts (módulos 01-10)
```

### DevOps
```
Containers:    Docker + Docker Compose
CI/CD:         Git (GitHub)
Backups:       Automáticos (db/backups/)
```

---

## 🏗️ ARQUITECTURA BACKEND

### Clean Architecture + DDD Lite

```
backend/app/
├── main.py                    # Entry point, FastAPI app
├── core/                      # Configuración global
│   ├── config.py              # Variables de entorno
│   ├── database.py            # Conexión DB
│   └── security.py            # JWT, hashing
│
└── modules/                   # Módulos por dominio
    ├── auth/
    │   ├── domain/            # 🟦 Entidades (modelos puros)
    │   │   └── entities/
    │   │       └── user.py    # Clase User (sin ORM)
    │   │
    │   ├── application/       # 🟩 Casos de uso (lógica negocio)
    │   │   ├── use_cases/
    │   │   │   └── login_user.py
    │   │   └── dtos/          # Data Transfer Objects
    │   │       └── login_dto.py
    │   │
    │   ├── infrastructure/    # 🟨 Implementaciones técnicas
    │   │   ├── models/
    │   │   │   └── user_model.py    # SQLAlchemy ORM
    │   │   └── repositories/
    │   │       └── user_repository.py
    │   │
    │   └── presentation/      # 🟥 API (controladores)
    │       └── routes.py      # Endpoints FastAPI
    │
    ├── loans/                 # Módulo préstamos
    ├── catalogs/              # Catálogos generales
    └── rate_profiles/         # Perfiles de tasa
```

### Dependency Rule (Clean Architecture)

```
┌─────────────────────────────────────────────────┐
│  Presentation (API Routes)                      │  🟥 Depende de →
│  ↓                                              │
│  Application (Use Cases, DTOs)                  │  🟩 Depende de →
│  ↓                                              │
│  Domain (Entities)                              │  🟦 NO depende de nada
│                                                 │
│  Infrastructure (DB, Repos, ORM)                │  🟨 Depende de Domain
└─────────────────────────────────────────────────┘

REGLA: Las flechas solo van hacia adentro (hacia Domain)
```

### Ejemplo: Flujo de Login

```python
# 1. Presentation (routes.py)
@router.post("/login")
async def login(dto: LoginDTO):
    use_case = LoginUserUseCase(user_repo)
    return await use_case.execute(dto)

# 2. Application (use_cases/login_user.py)
class LoginUserUseCase:
    async def execute(self, dto: LoginDTO):
        user = await self.repo.find_by_username(dto.username)
        # Lógica de validación
        return create_token(user)

# 3. Infrastructure (repositories/user_repository.py)
class UserRepository:
    async def find_by_username(self, username: str):
        db_user = await db.query(UserModel).filter(...)
        return User.from_orm(db_user)  # ORM → Entity

# 4. Domain (entities/user.py)
@dataclass
class User:
    id: int
    username: str
    # NO tiene dependencias de DB
```

**Beneficio:** Lógica de negocio independiente de framework/DB

---

## 🎨 ARQUITECTURA FRONTEND

### Feature-Sliced Design (FSD)

```
frontend-mvp/src/
├── app/                       # Configuración app
│   ├── App.jsx
│   └── router.jsx
│
├── pages/                     # 🟦 Páginas (rutas)
│   ├── LoginPage/
│   ├── DashboardPage/
│   ├── LoansPage/
│   └── AssociatesPage/
│
├── widgets/                   # 🟩 Widgets complejos
│   ├── LoansList/
│   ├── PaymentSchedule/
│   └── AssociateCreditCard/
│
├── features/                  # 🟨 Funcionalidades
│   ├── auth/
│   │   ├── LoginForm/
│   │   └── useAuth.js
│   ├── loans/
│   │   ├── ApproveLoan/
│   │   └── CreateLoan/
│   └── payments/
│       └── RegisterPayment/
│
├── entities/                  # 🟧 Entidades negocio
│   ├── loan/
│   ├── associate/
│   └── payment/
│
├── shared/                    # 🟥 Compartido
│   ├── ui/                    # Componentes UI
│   │   ├── Button/
│   │   ├── Input/
│   │   └── Modal/
│   ├── api/                   # Cliente API
│   └── utils/                 # Utilidades
│
└── services/                  # API services
    └── api.js                 # Mock API actual
```

### Reglas FSD

```
📊 Capas (de arriba a abajo):
   app → pages → widgets → features → entities → shared

🚫 Prohibido:
   - shared NO puede importar de features
   - entities NO puede importar de features
   - features NO puede importar de widgets

✅ Permitido:
   - pages puede importar de cualquier capa inferior
   - features puede importar de entities y shared
```

### Ejemplo: Página de Préstamos

```jsx
// pages/LoansPage/LoansPage.jsx
import { LoansList } from '@/widgets/LoansList'
import { CreateLoanButton } from '@/features/loans/CreateLoan'

export const LoansPage = () => {
  return (
    <div>
      <h1>Préstamos</h1>
      <CreateLoanButton />
      <LoansList />
    </div>
  )
}

// widgets/LoansList/LoansList.jsx
import { LoanCard } from '@/entities/loan'
import { ApproveLoanButton } from '@/features/loans/ApproveLoan'

export const LoansList = () => {
  const loans = useLoans()
  return loans.map(loan => (
    <LoanCard loan={loan}>
      <ApproveLoanButton loanId={loan.id} />
    </LoanCard>
  ))
}
```

**Beneficio:** Código predecible, escalable, fácil de mantener

---

## 🗄️ BASE DE DATOS

### Esquema v2.0.3 (36 tablas)

```sql
-- CORE (Usuarios y Auth)
users
roles
user_roles

-- CATÁLOGOS
loan_statuses
payment_statuses
agreement_statuses

-- ASOCIADOS
associates
associate_profiles
associate_accumulated_balances

-- PRÉSTAMOS
loans
loan_renewals
rate_profiles           -- ⭐ Perfiles de tasa

-- PAGOS
payments
payment_schedule        -- ⭐ 12 pagos por préstamo

-- PERÍODOS
cut_periods             -- ⭐ Períodos quincenales

-- CONVENIOS
agreements
agreement_items
agreement_payments

-- AUDITORÍA
audit_log
```

### Funciones SQL Clave (21 funciones)

```sql
-- CALENDARIO
calculate_first_payment_date()        -- "Oráculo" de fechas
generate_payment_schedule()           -- 12 pagos

-- CÁLCULOS FINANCIEROS
calculate_loan_payment()              -- Calcula pago quincenal
calculate_total_interest()
calculate_commission()

-- CONVENIOS
create_agreement_for_defaulted_loan()
finalize_agreement()

-- VALIDACIONES
validate_loan_request()
validate_associate_credit_limit()
```

### Triggers (28 triggers)

```sql
-- AUTO-LLENADO
trg_set_created_by                    -- Llenar created_by
trg_set_timestamps                    -- created_at, updated_at

-- AUDITORÍA
trg_audit_loan_changes
trg_audit_payment_changes

-- DEUDA ACUMULADA
trg_update_accumulated_balance        -- Al crear convenio
trg_decrease_balance_on_payment       -- Al pagar

-- VALIDACIONES
trg_validate_payment_amount
trg_prevent_duplicate_payment
```

**Ver:** `/db/v2.0/init.sql` (3,997 líneas, esquema completo)

---

## 🐳 INFRAESTRUCTURA

### Docker Compose (3 servicios)

```yaml
services:
  postgres:
    image: postgres:15-alpine
    ports: ["5432:5432"]
    volumes:
      - credinet-postgres-data:/var/lib/postgresql/data
      - ./db/v2.0/init.sql:/docker-entrypoint-initdb.d/init.sql
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U credinet"]

  backend:
    build: ./backend
    ports: ["8000:8000"]
    depends_on:
      postgres: {condition: service_healthy}
    environment:
      - DATABASE_URL=postgresql://...
      - SECRET_KEY=...
    command: uvicorn app.main:app --reload --host 0.0.0.0

  frontend:
    build: ./frontend-mvp
    ports: ["5173:5173"]
    volumes:
      - ./frontend-mvp:/app
    command: npm run dev -- --host 0.0.0.0
```

### Comandos Docker

```bash
# Iniciar todo
docker compose up -d

# Ver logs
docker compose logs -f backend

# Reiniciar servicio
docker compose restart backend

# Ejecutar comando en container
docker compose exec backend pytest

# Detener todo
docker compose down

# Limpiar volúmenes (⚠️ borra datos)
docker compose down -v
```

---

## 🔄 FLUJO DE DATOS

### Ejemplo Completo: Aprobar Préstamo

```
┌─────────────────────────────────────────────────────────┐
│ 1. FRONTEND (React)                                     │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Usuario hace clic en "Aprobar"                         │
│    ↓                                                    │
│  ApproveLoanButton.jsx                                  │
│    → api.loans.approve(loanId, data)                    │
│    → POST /api/v1/loans/:id/approve                     │
│                                                         │
└─────────────────────────────────────────────────────────┘
                        ↓ HTTP
┌─────────────────────────────────────────────────────────┐
│ 2. BACKEND (FastAPI)                                    │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Presentation Layer (routes.py)                         │
│    → Valida JWT token                                   │
│    → Valida DTO (Pydantic)                              │
│    → Llama use case                                     │
│                                                         │
│  Application Layer (use_cases/approve_loan.py)          │
│    → Valida estado del préstamo                         │
│    → Valida crédito del asociado                        │
│    → Actualiza préstamo                                 │
│    → Genera payment_schedule                            │
│    → Actualiza crédito asociado                         │
│    → Registra auditoría                                 │
│                                                         │
│  Infrastructure Layer (repositories/)                   │
│    → loan_repository.update()                           │
│    → associate_repository.update_credit()               │
│    → audit_repository.log()                             │
│                                                         │
└─────────────────────────────────────────────────────────┘
                        ↓ SQL
┌─────────────────────────────────────────────────────────┐
│ 3. BASE DE DATOS (PostgreSQL)                           │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  UPDATE loans SET status = 'APROBADO' WHERE id = ?      │
│    → Trigger: trg_audit_loan_changes                    │
│    → Función: generate_payment_schedule(loan_id)        │
│                                                         │
│  INSERT INTO payment_schedule (12 pagos)                │
│    → Función: calculate_first_payment_date()            │
│    → Función: calculate_loan_payment()                  │
│                                                         │
│  UPDATE associates SET available_credit -= amount       │
│    → Trigger: trg_validate_credit_limit                 │
│                                                         │
│  INSERT INTO audit_log (...)                            │
│                                                         │
└─────────────────────────────────────────────────────────┘
                        ↓ Response
┌─────────────────────────────────────────────────────────┐
│ 4. FRONTEND (React) - Actualización                     │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Recibe respuesta exitosa                               │
│    → Actualiza estado local                             │
│    → Muestra notificación                               │
│    → Refresca lista de préstamos                        │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Principios Clave

```
🔵 Backend: Lógica de negocio compleja
   • Validaciones con múltiples reglas
   • Transacciones con múltiples tablas
   • Cálculos financieros
   • Auditoría

🟢 Base de Datos: Lógica de negocio simple
   • Auto-llenado (created_at, updated_at)
   • Validaciones atómicas (límites, unicidad)
   • Integridad referencial (FK)
   • Cálculos matemáticos simples

🟡 Frontend: Validaciones UX
   • Campos requeridos
   • Formatos (email, teléfono)
   • Rangos básicos
   • Feedback inmediato
```

---

## 📊 MÉTRICAS DEL PROYECTO

### Base de Datos
- **Líneas SQL:** 3,997
- **Tablas:** 36
- **Funciones:** 21
- **Triggers:** 28
- **Vistas:** 9
- **Tamaño:** 176 KB

### Backend
- **Módulos:** 4 (auth, loans, catalogs, rate_profiles)
- **Tests:** 124 (92% coverage)
- **Endpoints:** ~20
- **Líneas Python:** ~8,000

### Frontend
- **Páginas:** 5 planeadas
- **Componentes:** ~30 planeados
- **Estado:** MVP en desarrollo

---

## 🔗 REFERENCIAS

### Documentos Relacionados
- [`ARQUITECTURA_BACKEND_V2_DEFINITIVA.md`](../ARQUITECTURA_BACKEND_V2_DEFINITIVA.md) - Decisiones arquitectónicas
- [`ARQUITECTURA_DOBLE_CALENDARIO.md`](../ARQUITECTURA_DOBLE_CALENDARIO.md) - Sistema de fechas
- [`db/RESUMEN_COMPLETO_v2.0.md`](../db/RESUMEN_COMPLETO_v2.0.md) - Esquema base de datos

### Código
- Backend: `/backend/app/`
- Frontend: `/frontend-mvp/src/`
- Base de datos: `/db/v2.0/init.sql`
- Docker: `/docker-compose.yml`

---

## ✅ VERIFICACIÓN DE COMPRENSIÓN

Antes de continuar, asegúrate de poder responder:

1. ¿Cuáles son las 4 capas de Clean Architecture en el backend?
2. ¿Qué es la "Dependency Rule"?
3. ¿Cuántas tablas tiene la base de datos v2.0.3?
4. ¿Qué función SQL calcula la primera fecha de pago?
5. ¿Cuáles son las 5 capas de Feature-Sliced Design?
6. ¿Cuántos servicios tiene el docker-compose?

---

**Siguiente:** [`03_APIS_PRINCIPALES.md`](./03_APIS_PRINCIPALES.md) - Endpoints y ejemplos de uso

**Tiempo total hasta ahora:** ~25 minutos
