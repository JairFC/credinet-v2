# 🏗️ ARQUITECTURA BACKEND V2.0 - CREDINET

## 🎯 Decisión Arquitectónica: Clean Architecture + DDD Lite

Después de analizar el backend anterior y el tamaño/complejidad del proyecto, **mantenemos Clean Architecture** pero optimizada.

---

## 📊 Análisis del Proyecto

### Tamaño y Complejidad
- **Base de datos:** 36 tablas, 21 funciones, 28 triggers
- **Lógica de negocio:** 80% en DB (triggers, funciones), 20% en backend
- **Dominios principales:** 6 módulos core
- **Complejidad:** Media-Alta (sistema financiero con reglas estrictas)
- **Equipo:** 1-3 desarrolladores
- **Tiempo de vida:** 5+ años

### ¿Por qué Clean Architecture?

✅ **SÍ necesitamos Clean Architecture porque:**
1. Sistema financiero con reglas de negocio complejas
2. Proyecto a largo plazo (5+ años)
3. Necesitamos testabilidad (TDD para finanzas es crítico)
4. Múltiples dominios (loans, payments, associates, agreements)
5. Posible cambio de DB o frameworks en futuro
6. Cumplimiento normativo (auditoría, trazabilidad)

❌ **NO necesitamos DDD completo porque:**
1. Lógica compleja YA está en DB (no duplicar)
2. Equipo pequeño (overhead de DDD puro es excesivo)
3. Dominios no son tan complejos (no hay Aggregates complejos)

---

## 🏛️ Arquitectura Definitiva: **Clean Architecture + Repository Pattern**

```
backend/
├── app/
│   ├── main.py                    # FastAPI app + configuración
│   ├── config.py                  # Settings (pydantic-settings)
│   │
│   ├── core/                      # ⭐ Infraestructura compartida
│   │   ├── database.py            # SQLAlchemy setup
│   │   ├── security.py            # JWT, password hashing
│   │   ├── exceptions.py          # Custom exceptions
│   │   ├── middleware.py          # CORS, logging, error handlers
│   │   └── dependencies.py        # Dependency injection global
│   │
│   ├── shared/                    # ⭐ Código compartido entre módulos
│   │   ├── domain/
│   │   │   ├── entities/          # Base entities
│   │   │   └── value_objects/     # Shared VOs (Money, Email, etc.)
│   │   ├── infrastructure/
│   │   │   ├── repositories/      # Base repository classes
│   │   │   └── models/            # SQLAlchemy base models
│   │   └── utils/
│   │       ├── dates.py           # Date helpers
│   │       ├── validators.py      # Common validators
│   │       └── formatters.py      # Formatters
│   │
│   └── modules/                   # ⭐ Módulos por dominio (Clean Architecture)
│       │
│       ├── auth/                  # Módulo de autenticación
│       │   ├── domain/
│       │   │   ├── entities/
│       │   │   │   └── user.py          # Entity: User
│       │   │   └── repositories/
│       │   │       └── user_repository.py  # Interface
│       │   ├── application/
│       │   │   ├── dtos/
│       │   │   │   └── auth_dtos.py     # DTOs
│       │   │   └── use_cases/
│       │   │       ├── login.py         # LoginUseCase
│       │   │       ├── register.py      # RegisterUseCase
│       │   │       └── verify_token.py  # VerifyTokenUseCase
│       │   ├── infrastructure/
│       │   │   ├── models/
│       │   │   │   └── user_model.py    # SQLAlchemy User
│       │   │   ├── repositories/
│       │   │   │   └── postgresql_user_repository.py
│       │   │   └── dependencies.py      # DI for auth module
│       │   └── routes.py                # FastAPI router
│       │
│       ├── loans/                 # Módulo de préstamos
│       │   ├── domain/
│       │   │   ├── entities/
│       │   │   │   ├── loan.py          # Entity: Loan
│       │   │   │   └── payment.py       # Entity: Payment
│       │   │   └── repositories/
│       │   │       ├── loan_repository.py
│       │   │       └── payment_repository.py
│       │   ├── application/
│       │   │   ├── dtos/
│       │   │   │   ├── loan_dtos.py
│       │   │   │   └── payment_dtos.py
│       │   │   └── use_cases/
│       │   │       ├── create_loan.py
│       │   │       ├── approve_loan.py   # ⭐ Llama DB function
│       │   │       ├── get_loan_schedule.py
│       │   │       └── register_payment.py
│       │   ├── infrastructure/
│       │   │   ├── models/
│       │   │   │   ├── loan_model.py
│       │   │   │   └── payment_model.py
│       │   │   ├── repositories/
│       │   │   │   ├── postgresql_loan_repository.py
│       │   │   │   └── postgresql_payment_repository.py
│       │   │   └── dependencies.py
│       │   └── routes.py
│       │
│       ├── associates/            # Módulo de asociados
│       │   ├── domain/
│       │   │   ├── entities/
│       │   │   │   └── associate_profile.py
│       │   │   └── repositories/
│       │   │       └── associate_repository.py
│       │   ├── application/
│       │   │   ├── dtos/
│       │   │   │   └── associate_dtos.py
│       │   │   └── use_cases/
│       │   │       ├── get_associate_credit.py  # ⭐ Lee credit_available
│       │   │       └── update_associate_level.py
│       │   ├── infrastructure/
│       │   │   ├── models/
│       │   │   │   └── associate_model.py
│       │   │   ├── repositories/
│       │   │   │   └── postgresql_associate_repository.py
│       │   │   └── dependencies.py
│       │   └── routes.py
│       │
│       ├── periods/               # Módulo de períodos de corte
│       │   ├── domain/
│       │   │   ├── entities/
│       │   │   │   └── cut_period.py
│       │   │   └── repositories/
│       │   │       └── period_repository.py
│       │   ├── application/
│       │   │   ├── dtos/
│       │   │   │   └── period_dtos.py
│       │   │   └── use_cases/
│       │   │       ├── list_periods.py
│       │   │       └── close_period.py     # ⭐ Llama DB function
│       │   ├── infrastructure/
│       │   │   ├── models/
│       │   │   │   └── period_model.py
│       │   │   ├── repositories/
│       │   │   │   └── postgresql_period_repository.py
│       │   │   └── dependencies.py
│       │   └── routes.py
│       │
│       ├── agreements/            # Módulo de convenios
│       ├── documents/             # Módulo de documentos
│       └── reports/               # Módulo de reportes
│
├── tests/                         # Tests organizados por módulo
│   ├── unit/
│   │   ├── auth/
│   │   ├── loans/
│   │   └── ...
│   ├── integration/
│   └── e2e/
│
├── pyproject.toml                 # Poetry dependencies
├── pytest.ini                     # Pytest config
└── README.md                      # Documentation
```

---

## 🎨 Principios de la Arquitectura

### 1. **Separación de Capas (Clean Architecture)**

```
┌─────────────────────────────────────────────┐
│           ROUTES (Controllers)              │  ← HTTP Layer
│  - Recibe requests                          │
│  - Valida input (Pydantic)                  │
│  - Delega a Use Cases                       │
│  - Retorna responses                        │
└─────────────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────┐
│        APPLICATION (Use Cases)              │  ← Application Layer
│  - Orquesta flujo de negocio                │
│  - Coordina múltiples entidades             │
│  - Llama repositorios                       │
│  - Transforma DTOs ↔ Entities               │
└─────────────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────┐
│          DOMAIN (Entities)                  │  ← Domain Layer
│  - Reglas de negocio puras                  │
│  - Validaciones de dominio                  │
│  - Independiente de frameworks              │
│  - Sin dependencias externas                │
└─────────────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────┐
│     INFRASTRUCTURE (Repositories)           │  ← Infrastructure Layer
│  - SQLAlchemy models                        │
│  - Implementación de repositorios           │
│  - Acceso a DB                              │
│  - Llamadas a funciones SQL                 │
└─────────────────────────────────────────────┘
```

### 2. **Dependency Rule (Regla de Dependencias)**

```
Routes → Application → Domain ← Infrastructure
                          ↑
                    (interfaces)
```

- **Domain** no depende de nadie
- **Application** depende solo de Domain
- **Infrastructure** implementa interfaces de Domain
- **Routes** depende de Application

### 3. **Repository Pattern**

```python
# Domain: Define interface (contrato)
class ILoanRepository(ABC):
    @abstractmethod
    def get_by_id(self, loan_id: int) -> Optional[Loan]:
        pass
    
    @abstractmethod
    def save(self, loan: Loan) -> Loan:
        pass

# Infrastructure: Implementa con SQLAlchemy
class PostgreSQLLoanRepository(ILoanRepository):
    def get_by_id(self, loan_id: int) -> Optional[Loan]:
        # SQLAlchemy query
        db_loan = self.session.query(LoanModel).filter_by(id=loan_id).first()
        return self._to_entity(db_loan)
    
    def save(self, loan: Loan) -> Loan:
        # SQLAlchemy save
        db_loan = self._to_model(loan)
        self.session.add(db_loan)
        self.session.commit()
        return self._to_entity(db_loan)
```

---

## 💼 Flujo de Ejemplo: Aprobar Préstamo

```python
# 1. ROUTES (Controller) - Capa HTTP
@router.post("/loans/{loan_id}/approve")
def approve_loan_endpoint(
    loan_id: int,
    use_case: ApproveLoanUseCase = Depends(get_approve_loan_use_case),
    current_user: User = Depends(get_current_user)
):
    # Validar permisos
    if current_user.role not in ["admin", "desarrollador"]:
        raise ForbiddenException()
    
    # Delegar a use case
    result = use_case.execute(loan_id, approved_by=current_user.id)
    return result


# 2. APPLICATION (Use Case) - Lógica de aplicación
class ApproveLoanUseCase:
    def __init__(self, loan_repo: ILoanRepository):
        self.loan_repo = loan_repo
    
    def execute(self, loan_id: int, approved_by: int) -> LoanResponseDTO:
        # Obtener loan
        loan = self.loan_repo.get_by_id(loan_id)
        if not loan:
            raise NotFoundException("Loan", loan_id)
        
        # Validar estado (lógica de aplicación)
        if loan.status_id != 1:  # PENDING
            raise BusinessException("Préstamo ya procesado")
        
        # Aprobar (delega a DB function)
        # ⚡ Aquí NO calculamos nada, la DB lo hace
        loan.status_id = 2  # APPROVED
        loan.approved_by = approved_by
        loan.approved_at = datetime.now()
        
        # Guardar (triggers DB se encargan del resto)
        updated_loan = self.loan_repo.save(loan)
        
        # Retornar DTO
        return LoanResponseDTO.from_entity(updated_loan)


# 3. DOMAIN (Entity) - Reglas de negocio puras
@dataclass
class Loan:
    id: int
    user_id: int
    associate_id: int
    amount: Decimal
    status_id: int
    approved_by: Optional[int] = None
    approved_at: Optional[datetime] = None
    
    def is_pending(self) -> bool:
        return self.status_id == 1
    
    def can_be_approved(self) -> bool:
        """Regla de negocio: solo préstamos pendientes pueden aprobarse."""
        return self.is_pending()


# 4. INFRASTRUCTURE (Repository) - Acceso a datos
class PostgreSQLLoanRepository(ILoanRepository):
    def __init__(self, session: Session):
        self.session = session
    
    def save(self, loan: Loan) -> Loan:
        # Convertir entity → SQLAlchemy model
        db_loan = self.session.query(LoanModel).filter_by(id=loan.id).first()
        db_loan.status_id = loan.status_id
        db_loan.approved_by = loan.approved_by
        db_loan.approved_at = loan.approved_at
        
        self.session.commit()
        self.session.refresh(db_loan)
        
        # ⚡ Triggers de DB ya ejecutaron:
        #   - generate_payment_schedule()
        #   - update_associate_credit()
        #   - create_contract()
        
        # Convertir model → entity
        return self._to_entity(db_loan)
```

---

## 🎯 ¿Qué va en cada capa?

### Domain Layer (Entities)
```python
✅ Validaciones de negocio puras
✅ Reglas de dominio (ej: can_be_approved)
✅ Value Objects (Money, Email, Phone)
❌ NO acceso a DB
❌ NO dependencias de frameworks
❌ NO lógica de aplicación
```

### Application Layer (Use Cases)
```python
✅ Orquestación de flujo
✅ Coordinación de múltiples entidades
✅ Transformación DTOs ↔ Entities
✅ Validaciones de aplicación
✅ Transacciones
❌ NO lógica de negocio compleja (va en Domain)
❌ NO acceso directo a DB (usa repositorios)
```

### Infrastructure Layer (Repositories)
```python
✅ SQLAlchemy models
✅ Queries SQL
✅ Mapeo Entity ↔ Model
✅ Llamadas a funciones DB
✅ Transacciones
❌ NO lógica de negocio
```

---

## ✅ Ventajas de Esta Arquitectura

1. **Testeable:** Cada capa se testea independientemente
2. **Mantenible:** Cambios en una capa no afectan otras
3. **Escalable:** Fácil agregar módulos nuevos
4. **Flexible:** Cambiar DB o framework sin tocar domain
5. **Clara:** Cada componente tiene una responsabilidad única
6. **Profesional:** Estándar de industria para sistemas complejos

---

## 🚀 Plan de Implementación

### Orden de Desarrollo (por prioridad):

1. **Shared/Core** (2h)
   - Database setup
   - Security (JWT)
   - Exceptions
   - Base repository

2. **Auth Module** (3h)
   - Login/Register use cases
   - JWT generation
   - Role-based auth

3. **Loans Module** (4h)
   - Create/Approve loan
   - Get schedule
   - Repository con llamadas a DB functions

4. **Payments Module** (3h)
   - Register payment
   - Query payments

5. **Associates Module** (2h)
   - Get credit info
   - Update level

6. **Periods Module** (2h)
   - List periods
   - Close period (llama DB function)

**Total estimado:** ~16 horas para MVP funcional

---

## 🎓 Conclusión

**Esta arquitectura es la correcta para Credinet porque:**

✅ Separa responsabilidades claramente  
✅ Mantiene lógica crítica en DB (donde debe estar)  
✅ Backend orquesta pero no duplica lógica  
✅ Es testeable y mantenible  
✅ Es escalable para crecer  
✅ Es estándar de industria  

**NO es over-engineering porque:**
- Sistema financiero requiere rigor
- Proyecto a largo plazo (5+ años)
- Múltiples dominios de negocio
- Necesidad de cumplimiento normativo

---

¿Procedemos con esta arquitectura? 🚀
