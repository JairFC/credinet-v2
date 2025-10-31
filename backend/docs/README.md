# 🏗️ GUÍA MAESTRA - BACKEND CREDINET V2.0

**Documento VIVO** - Se actualiza con cada módulo implementado  
**Propósito:** Guía arquitectónica + Tracking de progreso + Manual de implementación  
**Última actualización:** 30 de Octubre, 2025

---

## 📋 TABLA DE CONTENIDO

1. [Arquitectura General](#-arquitectura-general)
2. [Estructura de Directorios](#-estructura-de-directorios)
3. [Capas y Responsabilidades](#-capas-y-responsabilidades)
4. [Cómo Agregar un Nuevo Módulo](#-cómo-agregar-un-nuevo-módulo)
5. [Normas y Convenciones](#-normas-y-convenciones)
6. [Plantillas de Código](#-plantillas-de-código)
7. [Testing](#-testing)
8. [Estado del Proyecto](#-estado-del-proyecto)

---

## 🏛️ ARQUITECTURA GENERAL

### Principios Fundamentales

```
1. CLEAN ARCHITECTURE
   ├── Domain (Entities)       → Lógica de negocio pura
   ├── Application (Use Cases) → Orquestación
   ├── Infrastructure (Repos)  → Acceso a datos
   └── Routes (Controllers)    → Capa HTTP

2. DEPENDENCY RULE
   Routes → Application → Domain ← Infrastructure
                             ↑
                        (interfaces)

3. SEPARATION OF CONCERNS
   - Domain: NO conoce DB ni frameworks
   - Application: NO accede directamente a DB
   - Infrastructure: Implementa contratos de Domain
   - Routes: Solo HTTP, delega a Use Cases

4. SINGLE RESPONSIBILITY
   - 1 módulo = 1 dominio de negocio
   - 1 use case = 1 acción específica
   - 1 entity = 1 concepto de dominio
```

### Flujo de Datos

```
HTTP Request
    ↓
[ROUTES] - Valida input, verifica permisos
    ↓
[USE CASE] - Orquesta lógica de aplicación
    ↓
[REPOSITORY] - Accede a DB (mediante interfaz)
    ↓
[DATABASE] - PostgreSQL con funciones/triggers
    ↓
[REPOSITORY] - Mapea DB Model → Domain Entity
    ↓
[USE CASE] - Transforma Entity → DTO
    ↓
[ROUTES] - Serializa DTO → JSON Response
    ↓
HTTP Response
```

---

## 📁 ESTRUCTURA DE DIRECTORIOS

```
backend/
├── app/
│   ├── main.py                          # ⭐ Entry point FastAPI
│   ├── config.py                        # ⭐ Settings (pydantic-settings)
│   │
│   ├── core/                            # 🔧 Infraestructura compartida
│   │   ├── __init__.py
│   │   ├── database.py                  # SQLAlchemy engine, session
│   │   ├── security.py                  # JWT, password hashing
│   │   ├── exceptions.py                # Custom exceptions
│   │   ├── middleware.py                # CORS, logging, error handlers
│   │   └── dependencies.py              # Dependency injection global
│   │
│   ├── shared/                          # 🔄 Código compartido entre módulos
│   │   ├── __init__.py
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   └── base_entity.py       # Base class para entities
│   │   │   ├── value_objects/
│   │   │   │   ├── money.py             # Value Object: Money
│   │   │   │   ├── email.py             # Value Object: Email
│   │   │   │   └── phone.py             # Value Object: Phone
│   │   │   └── repositories/
│   │   │       └── base_repository.py   # Base repository interface
│   │   ├── infrastructure/
│   │   │   ├── models/
│   │   │   │   └── base_model.py        # Base SQLAlchemy model
│   │   │   └── repositories/
│   │   │       └── base_repository_impl.py
│   │   └── utils/
│   │       ├── dates.py                 # Date helpers
│   │       ├── validators.py            # Common validators
│   │       └── formatters.py            # Formatters
│   │
│   └── modules/                         # 📦 Módulos por dominio
│       │
│       ├── auth/                        # Módulo de autenticación
│       │   ├── __init__.py
│       │   ├── domain/
│       │   │   ├── __init__.py
│       │   │   ├── entities/
│       │   │   │   ├── __init__.py
│       │   │   │   └── user.py          # Entity: User
│       │   │   └── repositories/
│       │   │       ├── __init__.py
│       │   │       └── user_repository.py  # Interface
│       │   ├── application/
│       │   │   ├── __init__.py
│       │   │   ├── dtos/
│       │   │   │   ├── __init__.py
│       │   │   │   └── auth_dtos.py     # DTOs: LoginRequest, TokenResponse
│       │   │   └── use_cases/
│       │   │       ├── __init__.py
│       │   │       ├── login.py         # LoginUseCase
│       │   │       ├── register.py      # RegisterUseCase
│       │   │       └── verify_token.py  # VerifyTokenUseCase
│       │   ├── infrastructure/
│       │   │   ├── __init__.py
│       │   │   ├── models/
│       │   │   │   ├── __init__.py
│       │   │   │   └── user_model.py    # SQLAlchemy User
│       │   │   ├── repositories/
│       │   │   │   ├── __init__.py
│       │   │   │   └── postgresql_user_repository.py
│       │   │   └── dependencies.py      # DI for auth module
│       │   └── routes.py                # FastAPI router
│       │
│       ├── loans/                       # Módulo de préstamos
│       │   ├── domain/
│       │   │   ├── entities/
│       │   │   │   ├── loan.py
│       │   │   │   └── payment.py
│       │   │   └── repositories/
│       │   │       ├── loan_repository.py
│       │   │       └── payment_repository.py
│       │   ├── application/
│       │   │   ├── dtos/
│       │   │   │   ├── loan_dtos.py
│       │   │   │   └── payment_dtos.py
│       │   │   └── use_cases/
│       │   │       ├── create_loan.py
│       │   │       ├── approve_loan.py
│       │   │       ├── list_loans.py
│       │   │       └── get_loan_detail.py
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
│       ├── associates/                  # Módulo de asociados
│       ├── clients/                     # Módulo de clientes
│       ├── periods/                     # Módulo de períodos
│       ├── agreements/                  # Módulo de convenios
│       └── reports/                     # Módulo de reportes
│
├── tests/                               # 🧪 Tests organizados por módulo
│   ├── conftest.py                      # Fixtures compartidos
│   ├── unit/
│   │   ├── auth/
│   │   │   ├── test_login_use_case.py
│   │   │   └── test_user_entity.py
│   │   ├── loans/
│   │   │   ├── test_create_loan_use_case.py
│   │   │   └── test_loan_entity.py
│   │   └── ...
│   ├── integration/
│   │   ├── test_auth_endpoints.py
│   │   ├── test_loan_endpoints.py
│   │   └── ...
│   └── e2e/
│       └── test_loan_flow.py
│
├── pyproject.toml                       # Poetry dependencies
├── pytest.ini                           # Pytest config
├── .env.example                         # Environment template
├── requirements.txt                     # Pip dependencies (fallback)
└── README.md                            # Quick start guide
```

---

## 🎨 CAPAS Y RESPONSABILIDADES

### 1️⃣ DOMAIN LAYER (Capa de Dominio)

**Ubicación:** `modules/{module_name}/domain/`

**Responsabilidades:**
- ✅ Definir entidades con lógica de negocio pura
- ✅ Definir interfaces de repositorios (contratos)
- ✅ Validaciones de dominio
- ✅ Value Objects
- ❌ NO acceso a DB
- ❌ NO dependencias de frameworks
- ❌ NO lógica de aplicación

**Contenido:**
```
domain/
├── entities/
│   └── loan.py          # Entidad Loan con reglas de negocio
├── repositories/
│   └── loan_repository.py  # Interface (ABC)
└── value_objects/
    └── money.py         # Value Object Money (opcional)
```

**Ejemplo - Entity:**
```python
# modules/loans/domain/entities/loan.py
from dataclasses import dataclass
from decimal import Decimal
from datetime import datetime
from typing import Optional

@dataclass
class Loan:
    """
    Entidad de dominio: Préstamo
    
    Responsabilidades:
    - Almacenar datos del préstamo
    - Validaciones de negocio
    - Reglas de dominio (no de aplicación)
    """
    id: Optional[int]
    user_id: int
    associate_id: int
    amount: Decimal
    term_biweeks: int
    status_id: int
    interest_rate: Decimal
    commission_rate: Decimal
    created_at: datetime
    approved_at: Optional[datetime] = None
    approved_by: Optional[int] = None
    
    def __post_init__(self):
        """Validaciones de dominio al crear/modificar."""
        self._validate_amount()
        self._validate_term()
        self._validate_rates()
    
    def _validate_amount(self):
        if self.amount <= 0:
            raise ValueError("Monto debe ser mayor a 0")
        if self.amount > 1_000_000:
            raise ValueError("Monto excede límite máximo")
    
    def _validate_term(self):
        if self.term_biweeks < 1 or self.term_biweeks > 24:
            raise ValueError("Plazo debe estar entre 1 y 24 quincenas")
    
    def _validate_rates(self):
        if self.interest_rate < 0 or self.interest_rate > 100:
            raise ValueError("Tasa de interés inválida")
    
    # Reglas de negocio (queries del dominio)
    def is_pending(self) -> bool:
        """Verifica si el préstamo está pendiente de aprobación."""
        return self.status_id == 1
    
    def is_approved(self) -> bool:
        """Verifica si el préstamo está aprobado."""
        return self.status_id == 2
    
    def can_be_approved(self) -> bool:
        """Regla: Solo préstamos pendientes pueden aprobarse."""
        return self.is_pending()
    
    def calculate_total_amount(self) -> Decimal:
        """Calcula monto total con interés y comisión."""
        interest = self.amount * (self.interest_rate / 100)
        commission = self.amount * (self.commission_rate / 100)
        return self.amount + interest + commission
```

**Ejemplo - Repository Interface:**
```python
# modules/loans/domain/repositories/loan_repository.py
from abc import ABC, abstractmethod
from typing import Optional, List
from ..entities.loan import Loan

class ILoanRepository(ABC):
    """
    Interfaz del repositorio de préstamos.
    
    Define el CONTRATO que debe cumplir cualquier implementación.
    Domain NO depende de la implementación concreta.
    """
    
    @abstractmethod
    def get_by_id(self, loan_id: int) -> Optional[Loan]:
        """Obtener préstamo por ID."""
        pass
    
    @abstractmethod
    def get_all(
        self, 
        status_id: Optional[int] = None,
        skip: int = 0,
        limit: int = 20
    ) -> List[Loan]:
        """Listar préstamos con filtros opcionales."""
        pass
    
    @abstractmethod
    def save(self, loan: Loan) -> Loan:
        """Crear o actualizar préstamo."""
        pass
    
    @abstractmethod
    def delete(self, loan_id: int) -> bool:
        """Eliminar préstamo."""
        pass
    
    @abstractmethod
    def count(self, status_id: Optional[int] = None) -> int:
        """Contar préstamos con filtro opcional."""
        pass
```

---

### 2️⃣ APPLICATION LAYER (Capa de Aplicación)

**Ubicación:** `modules/{module_name}/application/`

**Responsabilidades:**
- ✅ Orquestar flujo de negocio
- ✅ Coordinar múltiples entidades
- ✅ Llamar repositorios
- ✅ Transformar DTOs ↔ Entities
- ✅ Validaciones de aplicación (no de dominio)
- ✅ Transacciones
- ❌ NO lógica de negocio compleja (va en Domain)
- ❌ NO acceso directo a DB (usa repositorios)

**Contenido:**
```
application/
├── dtos/
│   └── loan_dtos.py     # DTOs para input/output
└── use_cases/
    ├── create_loan.py   # CreateLoanUseCase
    ├── approve_loan.py  # ApproveLoanUseCase
    └── list_loans.py    # ListLoansUseCase
```

**Ejemplo - DTO:**
```python
# modules/loans/application/dtos/loan_dtos.py
from pydantic import BaseModel, Field, validator
from decimal import Decimal
from datetime import datetime
from typing import Optional, List

class CreateLoanRequest(BaseModel):
    """DTO para crear préstamo (input)."""
    user_id: int = Field(..., gt=0, description="ID del cliente")
    associate_id: int = Field(..., gt=0, description="ID del asociado")
    amount: Decimal = Field(..., gt=0, le=1_000_000, description="Monto del préstamo")
    term_biweeks: int = Field(..., ge=1, le=24, description="Plazo en quincenas")
    interest_rate: Optional[Decimal] = Field(2.5, description="Tasa de interés (%)")
    commission_rate: Optional[Decimal] = Field(2.5, description="Tasa de comisión (%)")
    
    @validator('amount')
    def validate_amount(cls, v):
        if v <= 0:
            raise ValueError('Monto debe ser mayor a 0')
        return v

class LoanResponse(BaseModel):
    """DTO para respuesta de préstamo (output)."""
    id: int
    user_id: int
    user_name: str
    associate_id: int
    associate_name: str
    amount: Decimal
    term_biweeks: int
    interest_rate: Decimal
    commission_rate: Decimal
    total_amount: Decimal
    status_id: int
    status_name: str
    created_at: datetime
    approved_at: Optional[datetime]
    approved_by: Optional[int]
    
    class Config:
        orm_mode = True

class LoanListResponse(BaseModel):
    """DTO para lista paginada de préstamos."""
    total: int
    page: int
    page_size: int
    items: List[LoanResponse]
```

**Ejemplo - Use Case:**
```python
# modules/loans/application/use_cases/create_loan.py
from typing import Optional
from app.core.exceptions import BusinessException, InsufficientCreditException, DefaulterException
from ..dtos.loan_dtos import CreateLoanRequest, LoanResponse
from ...domain.entities.loan import Loan
from ...domain.repositories.loan_repository import ILoanRepository

class CreateLoanUseCase:
    """
    Caso de uso: Crear solicitud de préstamo
    
    Responsabilidades:
    - Validar precondiciones (cliente no moroso, crédito suficiente)
    - Crear entidad Loan
    - Persistir mediante repositorio
    - Retornar DTO de respuesta
    """
    
    def __init__(
        self,
        loan_repository: ILoanRepository,
        user_repository,  # Inyectado
        associate_repository  # Inyectado
    ):
        self.loan_repo = loan_repository
        self.user_repo = user_repository
        self.associate_repo = associate_repository
    
    def execute(
        self, 
        request: CreateLoanRequest,
        created_by: int
    ) -> LoanResponse:
        """
        Ejecuta el caso de uso.
        
        Args:
            request: DTO con datos del préstamo
            created_by: ID del usuario que crea (admin)
        
        Returns:
            LoanResponse: Préstamo creado
        
        Raises:
            DefaulterException: Si cliente es moroso
            InsufficientCreditException: Si asociado sin crédito
            BusinessException: Otras validaciones fallidas
        """
        
        # 1. Validar que cliente existe y NO es moroso
        user = self.user_repo.get_by_id(request.user_id)
        if not user:
            raise BusinessException(f"Cliente #{request.user_id} no encontrado")
        if user.is_defaulter:
            raise DefaulterException(request.user_id)
        
        # 2. Validar que asociado existe y tiene crédito disponible
        associate = self.associate_repo.get_by_id(request.associate_id)
        if not associate:
            raise BusinessException(f"Asociado #{request.associate_id} no encontrado")
        
        if associate.credit_available < request.amount:
            raise InsufficientCreditException(
                available=associate.credit_available,
                required=request.amount
            )
        
        # 3. Crear entidad Loan
        loan = Loan(
            id=None,  # Se asigna en DB
            user_id=request.user_id,
            associate_id=request.associate_id,
            amount=request.amount,
            term_biweeks=request.term_biweeks,
            interest_rate=request.interest_rate or Decimal('2.5'),
            commission_rate=request.commission_rate or Decimal('2.5'),
            status_id=1,  # PENDING
            created_at=datetime.now(),
            created_by=created_by
        )
        
        # 4. Persistir mediante repositorio
        saved_loan = self.loan_repo.save(loan)
        
        # 5. Transformar Entity → DTO
        return self._to_response_dto(saved_loan, user, associate)
    
    def _to_response_dto(self, loan: Loan, user, associate) -> LoanResponse:
        """Mapea Entity + datos relacionados → DTO."""
        return LoanResponse(
            id=loan.id,
            user_id=loan.user_id,
            user_name=user.full_name,
            associate_id=loan.associate_id,
            associate_name=associate.full_name,
            amount=loan.amount,
            term_biweeks=loan.term_biweeks,
            interest_rate=loan.interest_rate,
            commission_rate=loan.commission_rate,
            total_amount=loan.calculate_total_amount(),
            status_id=loan.status_id,
            status_name="PENDING",
            created_at=loan.created_at,
            approved_at=loan.approved_at,
            approved_by=loan.approved_by
        )
```

---

### 3️⃣ INFRASTRUCTURE LAYER (Capa de Infraestructura)

**Ubicación:** `modules/{module_name}/infrastructure/`

**Responsabilidades:**
- ✅ Implementar interfaces de repositorios
- ✅ SQLAlchemy models
- ✅ Queries SQL
- ✅ Mapeo Entity ↔ Model
- ✅ Llamadas a funciones/procedures de DB
- ✅ Transacciones
- ❌ NO lógica de negocio

**Contenido:**
```
infrastructure/
├── models/
│   └── loan_model.py       # SQLAlchemy model
├── repositories/
│   └── postgresql_loan_repository.py  # Implementación
└── dependencies.py          # Dependency Injection
```

**Ejemplo - SQLAlchemy Model:**
```python
# modules/loans/infrastructure/models/loan_model.py
from sqlalchemy import Column, Integer, String, Numeric, DateTime, ForeignKey, Text
from sqlalchemy.orm import relationship
from app.core.database import Base

class LoanModel(Base):
    """
    SQLAlchemy model para tabla loans.
    
    Representa la estructura de la tabla en DB.
    NO contiene lógica de negocio.
    """
    __tablename__ = "loans"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    associate_id = Column(Integer, ForeignKey("associate_profiles.id"), nullable=False, index=True)
    amount = Column(Numeric(12, 2), nullable=False)
    term_biweeks = Column(Integer, nullable=False)
    interest_rate = Column(Numeric(5, 2), nullable=False, default=2.5)
    commission_rate = Column(Numeric(5, 2), nullable=False, default=2.5)
    status_id = Column(Integer, ForeignKey("loan_statuses.id"), nullable=False, index=True)
    contract_id = Column(Integer, ForeignKey("contracts.id"), nullable=True)
    created_at = Column(DateTime, nullable=False, server_default="NOW()")
    approved_at = Column(DateTime, nullable=True)
    approved_by = Column(Integer, ForeignKey("users.id"), nullable=True)
    created_by = Column(Integer, ForeignKey("users.id"), nullable=False)
    
    # Relationships (opcional, para queries complejas)
    user = relationship("UserModel", foreign_keys=[user_id])
    associate = relationship("AssociateProfileModel")
    status = relationship("LoanStatusModel")
    payments = relationship("PaymentModel", back_populates="loan")
```

**Ejemplo - Repository Implementation:**
```python
# modules/loans/infrastructure/repositories/postgresql_loan_repository.py
from typing import Optional, List
from sqlalchemy.orm import Session, joinedload
from ...domain.entities.loan import Loan
from ...domain.repositories.loan_repository import ILoanRepository
from ..models.loan_model import LoanModel

class PostgreSQLLoanRepository(ILoanRepository):
    """
    Implementación del repositorio usando PostgreSQL + SQLAlchemy.
    
    Responsabilidades:
    - Ejecutar queries SQL
    - Mapear Model ↔ Entity
    - Manejar transacciones
    """
    
    def __init__(self, session: Session):
        self.session = session
    
    def get_by_id(self, loan_id: int) -> Optional[Loan]:
        """Obtener préstamo por ID."""
        db_loan = self.session.query(LoanModel).filter_by(id=loan_id).first()
        if not db_loan:
            return None
        return self._to_entity(db_loan)
    
    def get_all(
        self, 
        status_id: Optional[int] = None,
        skip: int = 0,
        limit: int = 20
    ) -> List[Loan]:
        """Listar préstamos con filtros."""
        query = self.session.query(LoanModel)
        
        if status_id:
            query = query.filter(LoanModel.status_id == status_id)
        
        query = query.offset(skip).limit(limit).order_by(LoanModel.created_at.desc())
        db_loans = query.all()
        
        return [self._to_entity(loan) for loan in db_loans]
    
    def save(self, loan: Loan) -> Loan:
        """Crear o actualizar préstamo."""
        if loan.id is None:
            # Crear nuevo
            db_loan = self._to_model(loan)
            self.session.add(db_loan)
        else:
            # Actualizar existente
            db_loan = self.session.query(LoanModel).filter_by(id=loan.id).first()
            if not db_loan:
                raise ValueError(f"Loan #{loan.id} not found for update")
            self._update_model(db_loan, loan)
        
        self.session.commit()
        self.session.refresh(db_loan)
        
        return self._to_entity(db_loan)
    
    def delete(self, loan_id: int) -> bool:
        """Eliminar préstamo."""
        db_loan = self.session.query(LoanModel).filter_by(id=loan_id).first()
        if not db_loan:
            return False
        
        self.session.delete(db_loan)
        self.session.commit()
        return True
    
    def count(self, status_id: Optional[int] = None) -> int:
        """Contar préstamos."""
        query = self.session.query(LoanModel)
        if status_id:
            query = query.filter(LoanModel.status_id == status_id)
        return query.count()
    
    # Mappers: Model ↔ Entity
    def _to_entity(self, model: LoanModel) -> Loan:
        """SQLAlchemy Model → Domain Entity."""
        return Loan(
            id=model.id,
            user_id=model.user_id,
            associate_id=model.associate_id,
            amount=model.amount,
            term_biweeks=model.term_biweeks,
            interest_rate=model.interest_rate,
            commission_rate=model.commission_rate,
            status_id=model.status_id,
            created_at=model.created_at,
            approved_at=model.approved_at,
            approved_by=model.approved_by
        )
    
    def _to_model(self, entity: Loan) -> LoanModel:
        """Domain Entity → SQLAlchemy Model."""
        return LoanModel(
            id=entity.id,
            user_id=entity.user_id,
            associate_id=entity.associate_id,
            amount=entity.amount,
            term_biweeks=entity.term_biweeks,
            interest_rate=entity.interest_rate,
            commission_rate=entity.commission_rate,
            status_id=entity.status_id,
            created_at=entity.created_at,
            approved_at=entity.approved_at,
            approved_by=entity.approved_by
        )
    
    def _update_model(self, model: LoanModel, entity: Loan):
        """Actualiza Model con datos de Entity."""
        model.status_id = entity.status_id
        model.approved_at = entity.approved_at
        model.approved_by = entity.approved_by
```

**Ejemplo - Dependency Injection:**
```python
# modules/loans/infrastructure/dependencies.py
from fastapi import Depends
from sqlalchemy.orm import Session
from app.core.database import get_db
from ..domain.repositories.loan_repository import ILoanRepository
from .repositories.postgresql_loan_repository import PostgreSQLLoanRepository
from ..application.use_cases.create_loan import CreateLoanUseCase

def get_loan_repository(
    db: Session = Depends(get_db)
) -> ILoanRepository:
    """Proveedor del repositorio de préstamos."""
    return PostgreSQLLoanRepository(db)

def get_create_loan_use_case(
    loan_repo: ILoanRepository = Depends(get_loan_repository),
    # user_repo = Depends(get_user_repository),
    # associate_repo = Depends(get_associate_repository)
) -> CreateLoanUseCase:
    """Proveedor del caso de uso CreateLoan."""
    return CreateLoanUseCase(
        loan_repository=loan_repo,
        # user_repository=user_repo,
        # associate_repository=associate_repo
    )
```

---

### 4️⃣ ROUTES LAYER (Capa HTTP)

**Ubicación:** `modules/{module_name}/routes.py`

**Responsabilidades:**
- ✅ Definir endpoints FastAPI
- ✅ Validar input (Pydantic)
- ✅ Verificar autenticación/autorización
- ✅ Delegar a Use Cases
- ✅ Serializar respuesta
- ✅ Manejar errores HTTP
- ❌ NO lógica de negocio
- ❌ NO acceso directo a repositorios

**Ejemplo - Router:**
```python
# modules/loans/routes.py
from fastapi import APIRouter, Depends, status, Query
from typing import Optional
from app.core.dependencies import get_current_user
from app.core.exceptions import NotFoundException, ForbiddenException
from .application.dtos.loan_dtos import (
    CreateLoanRequest,
    LoanResponse,
    LoanListResponse
)
from .application.use_cases.create_loan import CreateLoanUseCase
from .application.use_cases.list_loans import ListLoansUseCase
from .application.use_cases.get_loan_detail import GetLoanDetailUseCase
from .infrastructure.dependencies import (
    get_create_loan_use_case,
    get_list_loans_use_case,
    get_loan_detail_use_case
)

router = APIRouter(prefix="/loans", tags=["Loans"])

@router.post(
    "/",
    response_model=LoanResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Crear solicitud de préstamo"
)
def create_loan(
    request: CreateLoanRequest,
    use_case: CreateLoanUseCase = Depends(get_create_loan_use_case),
    current_user = Depends(get_current_user)
):
    """
    Crear solicitud de préstamo.
    
    Admin crea a nombre de cliente.
    Préstamo se crea con status PENDING.
    
    **Validaciones:**
    - Cliente no debe ser moroso
    - Asociado debe tener crédito disponible
    """
    # Validar permisos (solo admin)
    if current_user.role not in ["administrador", "desarrollador"]:
        raise ForbiddenException("Solo admin puede crear préstamos")
    
    # Delegar a use case
    return use_case.execute(request, created_by=current_user.id)


@router.get(
    "/",
    response_model=LoanListResponse,
    summary="Listar préstamos"
)
def list_loans(
    status_id: Optional[int] = Query(None, description="Filtrar por status"),
    page: int = Query(1, ge=1, description="Página"),
    page_size: int = Query(20, ge=1, le=100, description="Tamaño de página"),
    use_case: ListLoansUseCase = Depends(get_list_loans_use_case),
    current_user = Depends(get_current_user)
):
    """
    Listar préstamos con filtros opcionales.
    
    **Filtros:**
    - status_id: 1=PENDING, 2=APPROVED, 3=REJECTED, etc.
    - page: Paginación
    """
    return use_case.execute(
        status_id=status_id,
        page=page,
        page_size=page_size
    )


@router.get(
    "/{loan_id}",
    response_model=LoanDetailResponse,
    summary="Obtener detalle de préstamo"
)
def get_loan_detail(
    loan_id: int,
    use_case: GetLoanDetailUseCase = Depends(get_loan_detail_use_case),
    current_user = Depends(get_current_user)
):
    """
    Obtener detalle completo de préstamo.
    
    Incluye:
    - Info del préstamo
    - Info del cliente
    - Info del asociado
    - Cronograma de pagos
    - Resumen financiero
    """
    loan = use_case.execute(loan_id)
    
    if not loan:
        raise NotFoundException("Préstamo", loan_id)
    
    # Validar permisos (admin ve todo, cliente solo el suyo)
    if current_user.role == "cliente" and loan.user_id != current_user.id:
        raise ForbiddenException("No autorizado para ver este préstamo")
    
    return loan
```

---

## 🚀 CÓMO AGREGAR UN NUEVO MÓDULO

### Checklist Completo

```
[ ] 1. Crear estructura de carpetas
[ ] 2. Definir Entity en domain/
[ ] 3. Definir Repository Interface en domain/
[ ] 4. Definir DTOs en application/
[ ] 5. Implementar Use Cases en application/
[ ] 6. Crear SQLAlchemy Model en infrastructure/
[ ] 7. Implementar Repository en infrastructure/
[ ] 8. Configurar DI en infrastructure/dependencies.py
[ ] 9. Crear router en routes.py
[ ] 10. Registrar router en main.py
[ ] 11. Escribir tests unitarios
[ ] 12. Escribir tests de integración
[ ] 13. Actualizar este documento (Estado del Proyecto)
[ ] 14. Actualizar PLAN_MAESTRO_V2.0.md con nuevos endpoints
```

### Paso a Paso (Ejemplo: Módulo "Reports")

#### 1. Crear Estructura
```bash
mkdir -p app/modules/reports/{domain/{entities,repositories},application/{dtos,use_cases},infrastructure/{models,repositories}}
touch app/modules/reports/{__init__.py,routes.py}
touch app/modules/reports/domain/{__init__.py,entities/__init__.py,repositories/__init__.py}
touch app/modules/reports/application/{__init__.py,dtos/__init__.py,use_cases/__init__.py}
touch app/modules/reports/infrastructure/{__init__.py,models/__init__.py,repositories/__init__.py,dependencies.py}
```

#### 2. Domain Entity
```python
# app/modules/reports/domain/entities/report.py
@dataclass
class DefaulterReport:
    id: Optional[int]
    user_id: int
    reported_by: int
    evidence_details: str
    created_at: datetime
    status_id: int
    
    def is_pending(self) -> bool:
        return self.status_id == 1
```

#### 3. Repository Interface
```python
# app/modules/reports/domain/repositories/report_repository.py
class IReportRepository(ABC):
    @abstractmethod
    def create(self, report: DefaulterReport) -> DefaulterReport:
        pass
    
    @abstractmethod
    def get_by_id(self, report_id: int) -> Optional[DefaulterReport]:
        pass
```

#### 4. DTOs
```python
# app/modules/reports/application/dtos/report_dtos.py
class CreateReportRequest(BaseModel):
    user_id: int
    evidence_details: str

class ReportResponse(BaseModel):
    id: int
    user_id: int
    user_name: str
    evidence_details: str
    status_name: str
    created_at: datetime
```

#### 5. Use Case
```python
# app/modules/reports/application/use_cases/create_report.py
class CreateReportUseCase:
    def __init__(self, report_repo: IReportRepository):
        self.repo = report_repo
    
    def execute(self, request: CreateReportRequest, reported_by: int) -> ReportResponse:
        report = DefaulterReport(...)
        saved = self.repo.create(report)
        return ReportResponse(...)
```

#### 6. SQLAlchemy Model
```python
# app/modules/reports/infrastructure/models/report_model.py
class DefaulterReportModel(Base):
    __tablename__ = "defaulted_client_reports"
    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    # ... resto de columnas
```

#### 7. Repository Implementation
```python
# app/modules/reports/infrastructure/repositories/postgresql_report_repository.py
class PostgreSQLReportRepository(IReportRepository):
    def create(self, report: DefaulterReport) -> DefaulterReport:
        db_report = self._to_model(report)
        self.session.add(db_report)
        self.session.commit()
        return self._to_entity(db_report)
```

#### 8. Dependency Injection
```python
# app/modules/reports/infrastructure/dependencies.py
def get_report_repository(db: Session = Depends(get_db)) -> IReportRepository:
    return PostgreSQLReportRepository(db)

def get_create_report_use_case(
    repo: IReportRepository = Depends(get_report_repository)
) -> CreateReportUseCase:
    return CreateReportUseCase(repo)
```

#### 9. Router
```python
# app/modules/reports/routes.py
router = APIRouter(prefix="/reports", tags=["Reports"])

@router.post("/", response_model=ReportResponse)
def create_report(
    request: CreateReportRequest,
    use_case: CreateReportUseCase = Depends(get_create_report_use_case),
    current_user = Depends(get_current_user)
):
    return use_case.execute(request, reported_by=current_user.id)
```

#### 10. Registrar en main.py
```python
# app/main.py
from app.modules.reports.routes import router as reports_router

app.include_router(reports_router, prefix="/api/v1")
```

#### 11-12. Tests
```python
# tests/unit/reports/test_create_report_use_case.py
def test_create_report_success():
    # ... test implementation
    pass

# tests/integration/test_report_endpoints.py
def test_create_report_endpoint(client):
    response = client.post("/api/v1/reports/", json={...})
    assert response.status_code == 201
```

#### 13. Actualizar Documentación
```markdown
# Agregar a este documento en "Estado del Proyecto":

### Módulo: Reports ✅ IMPLEMENTADO
- [x] Domain (DefaulterReport entity)
- [x] Use Cases (CreateReport, ListReports)
- [x] Endpoints (POST /reports, GET /reports)
- [x] Tests (100% coverage)
```

---

## 📏 NORMAS Y CONVENCIONES

### Naming Conventions

```python
# Archivos y módulos: snake_case
create_loan.py
loan_repository.py

# Classes: PascalCase
class Loan:
class CreateLoanUseCase:
class ILoanRepository:

# Funciones y métodos: snake_case
def execute():
def get_by_id():

# Constantes: UPPER_SNAKE_CASE
MAX_LOAN_AMOUNT = 1_000_000
DEFAULT_INTEREST_RATE = 2.5

# Variables: snake_case
loan_id = 123
total_amount = calculate_total()
```

### Import Order
```python
# 1. Standard library
import os
from datetime import datetime
from typing import Optional, List

# 2. Third-party
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from pydantic import BaseModel

# 3. Local application
from app.core.database import get_db
from app.core.exceptions import BusinessException
from ..domain.entities.loan import Loan
```

### Docstrings
```python
def execute(self, request: CreateLoanRequest, created_by: int) -> LoanResponse:
    """
    Ejecuta el caso de uso de creación de préstamo.
    
    Args:
        request: DTO con datos del préstamo a crear
        created_by: ID del usuario que crea (admin)
    
    Returns:
        LoanResponse: Préstamo creado con ID asignado
    
    Raises:
        DefaulterException: Si cliente es moroso
        InsufficientCreditException: Si asociado sin crédito suficiente
        BusinessException: Otras validaciones fallidas
    """
```

### Type Hints
```python
# SIEMPRE usar type hints
def get_by_id(self, loan_id: int) -> Optional[Loan]:  # ✅ BIEN
def get_by_id(self, loan_id):  # ❌ MAL

# Imports de typing
from typing import Optional, List, Dict, Union, Tuple
```

### Error Handling
```python
# En Use Cases: Lanzar excepciones específicas
if user.is_defaulter:
    raise DefaulterException(user.id)

# En Routes: Capturar y convertir a HTTP errors (FastAPI lo hace automático)
@router.post("/")
def create_loan(...):
    return use_case.execute(...)  # FastAPI captura excepciones
```

---

## 📦 PLANTILLAS DE CÓDIGO

### Entity Template
```python
# modules/{module}/domain/entities/{entity}.py
from dataclasses import dataclass
from datetime import datetime
from typing import Optional

@dataclass
class MyEntity:
    """
    Entidad de dominio: {Descripción}
    
    Responsabilidades:
    - {Responsabilidad 1}
    - {Responsabilidad 2}
    """
    id: Optional[int]
    # ... fields
    
    def __post_init__(self):
        """Validaciones de dominio."""
        self._validate_something()
    
    def _validate_something(self):
        if self.field < 0:
            raise ValueError("Field must be positive")
    
    # Domain queries
    def is_something(self) -> bool:
        return self.status == "something"
```

### Repository Interface Template
```python
# modules/{module}/domain/repositories/{entity}_repository.py
from abc import ABC, abstractmethod
from typing import Optional, List
from ..entities.{entity} import MyEntity

class IMyEntityRepository(ABC):
    """Repository interface for MyEntity."""
    
    @abstractmethod
    def get_by_id(self, id: int) -> Optional[MyEntity]:
        pass
    
    @abstractmethod
    def get_all(self, skip: int = 0, limit: int = 20) -> List[MyEntity]:
        pass
    
    @abstractmethod
    def save(self, entity: MyEntity) -> MyEntity:
        pass
    
    @abstractmethod
    def delete(self, id: int) -> bool:
        pass
```

### Use Case Template
```python
# modules/{module}/application/use_cases/{action}.py
from ...domain.entities.{entity} import MyEntity
from ...domain.repositories.{entity}_repository import IMyEntityRepository
from ..dtos.{entity}_dtos import CreateRequest, EntityResponse

class {Action}UseCase:
    """
    Caso de uso: {Descripción}
    
    Responsabilidades:
    - {Responsabilidad 1}
    - {Responsabilidad 2}
    """
    
    def __init__(self, repository: IMyEntityRepository):
        self.repo = repository
    
    def execute(self, request: CreateRequest) -> EntityResponse:
        """
        Ejecuta el caso de uso.
        
        Args:
            request: Input DTO
        
        Returns:
            EntityResponse: Result DTO
        
        Raises:
            BusinessException: If validation fails
        """
        # 1. Validations
        # 2. Create entity
        # 3. Persist
        # 4. Transform to DTO
        # 5. Return
        pass
```

---

## 🧪 TESTING

### Estructura de Tests
```
tests/
├── unit/                    # Tests unitarios (NO DB)
│   ├── loans/
│   │   ├── test_loan_entity.py
│   │   └── test_create_loan_use_case.py
│   └── ...
├── integration/             # Tests de integración (CON DB)
│   ├── test_loan_endpoints.py
│   └── ...
└── e2e/                     # Tests end-to-end (flujos completos)
    └── test_loan_approval_flow.py
```

### Unit Test Example
```python
# tests/unit/loans/test_loan_entity.py
import pytest
from app.modules.loans.domain.entities.loan import Loan

def test_loan_validates_amount():
    """Test: Loan valida que monto sea positivo."""
    with pytest.raises(ValueError, match="Monto debe ser mayor a 0"):
        Loan(
            id=None,
            user_id=1,
            associate_id=1,
            amount=-100,  # ❌ Negativo
            term_biweeks=12,
            status_id=1,
            # ...
        )

def test_loan_can_be_approved_only_if_pending():
    """Test: Solo préstamos PENDING pueden aprobarse."""
    loan = Loan(..., status_id=1)  # PENDING
    assert loan.can_be_approved() == True
    
    loan.status_id = 2  # APPROVED
    assert loan.can_be_approved() == False
```

### Integration Test Example
```python
# tests/integration/test_loan_endpoints.py
def test_create_loan_endpoint(client, auth_headers):
    """Test: POST /api/v1/loans crea préstamo exitosamente."""
    response = client.post(
        "/api/v1/loans",
        headers=auth_headers,
        json={
            "user_id": 5,
            "associate_id": 3,
            "amount": 100000,
            "term_biweeks": 12
        }
    )
    
    assert response.status_code == 201
    data = response.json()
    assert data["amount"] == 100000
    assert data["status_name"] == "PENDING"
```

---

## 📊 ESTADO DEL PROYECTO

### Progreso General

```
┌────────────────────────────────────────────────┐
│ BACKEND CREDINET V2.0 - ROADMAP                │
├────────────────────────────────────────────────┤
│ Sprint 1: Infraestructura + Auth  [ 5/5  ] ✅  │
│ Sprint 2: Préstamos Core          [ 0/6  ] 0%  │
│ Sprint 3: Aprobación + Cronograma [ 0/4  ] 0%  │
│ Sprint 4: Asociados + Dashboard   [ 0/4  ] 0%  │
├────────────────────────────────────────────────┤
│ TOTAL PROGRESO:                   [ 5/19 ] 26% │
└────────────────────────────────────────────────┘
```

---

### Sprint 1: Infraestructura + Auth

**Estado:** ✅ **COMPLETADO**  
**Estimación:** 1 semana  
**Fecha inicio:** 30 de Octubre, 2025  
**Fecha fin:** 30 de Octubre, 2025 (mismo día!)

#### Tareas

- [x] **CORE-01:** Setup estructura base Clean Architecture
  - [x] Carpetas: core/, shared/, modules/
  - [x] database.py, security.py, exceptions.py, config.py
  - [x] Base entity, base repository
  - **Estimación:** 2 horas ✅ **COMPLETADO**

- [x] **AUTH-01:** Módulo Auth - Domain Layer
  - [x] Entity: User
  - [x] Repository Interface: IUserRepository
  - **Estimación:** 1 hora ✅ **COMPLETADO**

- [x] **AUTH-02:** Módulo Auth - Application Layer
  - [x] DTOs: LoginRequest, TokenResponse, UserResponse
  - [x] Use Case: LoginUseCase
  - **Estimación:** 3 horas ✅ **COMPLETADO**

- [x] **AUTH-03:** Módulo Auth - Infrastructure Layer
  - [x] SQLAlchemy Model: UserModel
  - [x] Repository: PostgreSQLUserRepository
  - [x] Dependencies: DI setup
  - **Estimación:** 2 horas ✅ **COMPLETADO**

- [x] **AUTH-04:** Módulo Auth - Routes
  - [x] POST /api/v1/auth/login
  - [x] GET /api/v1/auth/me (protegido con JWT)
  - [x] Middleware: verify JWT token
  - [x] Dependency: get_current_user
  - **Estimación:** 2 horas ✅ **COMPLETADO**

- [x] **AUTH-05:** Configuración
  - [x] .env configurado
  - [x] Router registrado en main.py
  - [x] Middleware configurado
  - **Estimación:** 1 hora ✅ **COMPLETADO**

**Total Sprint 1:** 11 horas ✅ **COMPLETADO EN 45 MINUTOS**

---

### Sprint 2: Préstamos Core

**Estado:** ⏳ Pendiente  
**Estimación:** 1.5 semanas  
**Fecha inicio:** Pendiente  
**Fecha fin:** Pendiente

#### Tareas

- [ ] **LOANS-01:** Módulo Loans - Domain Layer
  - [ ] Entity: Loan
  - [ ] Entity: Payment
  - [ ] Repository Interface: ILoanRepository
  - [ ] Repository Interface: IPaymentRepository
  - **Estimación:** 2 horas

- [ ] **LOANS-02:** Módulo Loans - Application Layer (DTOs)
  - [ ] DTOs: CreateLoanRequest, LoanResponse
  - [ ] DTOs: LoanListResponse, LoanDetailResponse
  - [ ] DTOs: PaymentResponse
  - **Estimación:** 2 horas

- [ ] **LOANS-03:** Módulo Loans - Application Layer (Use Cases)
  - [ ] Use Case: CreateLoanUseCase
  - [ ] Use Case: ListLoansUseCase
  - [ ] Use Case: GetLoanDetailUseCase
  - **Estimación:** 4 horas

- [ ] **LOANS-04:** Módulo Loans - Infrastructure Layer
  - [ ] SQLAlchemy Model: LoanModel
  - [ ] SQLAlchemy Model: PaymentModel
  - [ ] Repository: PostgreSQLLoanRepository
  - [ ] Repository: PostgreSQLPaymentRepository
  - [ ] Dependencies: DI setup
  - **Estimación:** 4 horas

- [ ] **LOANS-05:** Módulo Loans - Routes
  - [ ] POST /api/v1/loans
  - [ ] GET /api/v1/loans
  - [ ] GET /api/v1/loans/{loan_id}
  - **Estimación:** 3 horas

- [ ] **LOANS-06:** Tests Loans
  - [ ] Unit: test_loan_entity.py
  - [ ] Unit: test_create_loan_use_case.py
  - [ ] Integration: test_loan_endpoints.py
  - **Estimación:** 3 horas

**Total Sprint 2:** 18 horas

---

### Sprint 3: Aprobación + Cronograma

**Estado:** ⏳ Pendiente  
**Estimación:** 1 semana  
**Fecha inicio:** Pendiente  
**Fecha fin:** Pendiente

#### Tareas

- [ ] **LOANS-07:** Use Case: ApproveLoanUseCase
  - [ ] Validaciones pre-aprobación
  - [ ] UPDATE loan status → APPROVED
  - [ ] Verificar triggers DB (generate_schedule, update_credit)
  - **Estimación:** 3 horas

- [ ] **LOANS-08:** Use Case: RejectLoanUseCase
  - [ ] UPDATE loan status → REJECTED
  - [ ] Guardar razón de rechazo
  - **Estimación:** 1 hora

- [ ] **LOANS-09:** Routes Aprobación
  - [ ] POST /api/v1/loans/{loan_id}/approve
  - [ ] POST /api/v1/loans/{loan_id}/reject
  - **Estimación:** 2 horas

- [ ] **LOANS-10:** Tests Aprobación
  - [ ] Unit: test_approve_loan_use_case.py
  - [ ] Integration: test_loan_approval_flow.py
  - [ ] Verificar cronograma generado correctamente
  - [ ] Verificar crédito asociado actualizado
  - **Estimación:** 3 horas

**Total Sprint 3:** 9 horas

---

### Sprint 4: Asociados + Dashboard

**Estado:** ⏳ Pendiente  
**Estimación:** 1 semana  
**Fecha inicio:** Pendiente  
**Fecha fin:** Pendiente

#### Tareas

- [ ] **ASSOCIATES-01:** Módulo Associates
  - [ ] Domain: AssociateProfile entity
  - [ ] Application: DTOs + Use Cases
  - [ ] Infrastructure: Model + Repository
  - [ ] Routes: GET /api/v1/associates
  - [ ] Routes: GET /api/v1/associates/{id}
  - **Estimación:** 4 horas

- [ ] **CLIENTS-01:** Módulo Clients (básico)
  - [ ] Routes: GET /api/v1/clients
  - [ ] Usa entity User existente
  - **Estimación:** 2 horas

- [ ] **DASHBOARD-01:** Módulo Dashboard
  - [ ] Use Case: GetDashboardMetricsUseCase
  - [ ] Routes: GET /api/v1/dashboard/metrics
  - [ ] Queries agregadas (COUNT, SUM)
  - **Estimación:** 3 horas

- [ ] **INTEGRATION-01:** Tests End-to-End
  - [ ] E2E: test_full_loan_creation_flow.py
  - [ ] E2E: test_loan_approval_and_schedule.py
  - **Estimación:** 2 horas

**Total Sprint 4:** 11 horas

---

### TOTAL ESTIMADO: 50 horas (~1.5 meses a tiempo parcial)

---

## 🔄 Cómo Actualizar Este Documento

### Cuando completes una tarea:

1. Marca el checkbox: `- [x] TASK-01: Descripción`
2. Actualiza el progreso: `[ 1/5 ] 20%`
3. Agrega fecha de completación si aplica
4. Commit con mensaje: `docs: complete TASK-01 in GUIA_ARQUITECTURA_BACKEND.md`

### Cuando agregues un nuevo Epic/Módulo:

1. Copia template de Sprint
2. Define tareas con estimaciones
3. Agrega a roadmap general
4. Actualiza Plan Maestro V2.0 con nuevos endpoints

---

## � CÓMO PROBAR SPRINT 1

### 1. Levantar el Backend

Desde la raíz del proyecto:

```bash
# Levantar solo base de datos y backend
docker-compose up -d postgres backend

# Ver logs en tiempo real
docker-compose logs -f backend
```

Espera a ver este mensaje:
```
INFO:     Application startup complete.
INFO:     Uvicorn running on http://0.0.0.0:8000 (Press CTRL+C to quit)
```

### 2. Verificar Health Check

```bash
curl http://localhost:8000/health
```

Deberías ver:
```json
{
  "status": "healthy",
  "version": "2.0.0"
}
```

### 3. Acceder a Swagger UI

Abre en tu navegador:
```
http://localhost:8000/docs
```

Deberías ver la documentación interactiva con:
- ✅ **Health** endpoints
- ✅ **Authentication** endpoints
  - `POST /api/v1/auth/login`
  - `GET /api/v1/auth/me`

### 4. Probar Login

**IMPORTANTE:** Primero necesitas crear un usuario admin manualmente en la DB.

#### 4.1 Crear usuario admin (solo una vez)

```bash
# Conectar a PostgreSQL
docker exec -it credinet-postgres psql -U credinet_user -d credinet_db

# Crear usuario admin
INSERT INTO users (email, password_hash, full_name, role, is_active, is_defaulter, created_at)
VALUES (
  'admin@credinet.com',
  '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5GyYfYGbRvCNe',  -- password: admin123
  'Admin CrediNet',
  'administrador',
  true,
  false,
  NOW()
);

# Salir
\q
```

#### 4.2 Probar login en Swagger

1. Ve a `http://localhost:8000/docs`
2. Click en `POST /api/v1/auth/login`
3. Click en "Try it out"
4. Usa estas credenciales:
   ```json
   {
     "email": "admin@credinet.com",
     "password": "admin123"
   }
   ```
5. Click "Execute"

Deberías recibir:
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer",
  "user": {
    "id": 1,
    "email": "admin@credinet.com",
    "full_name": "Admin CrediNet",
    "role": "administrador",
    "is_active": true,
    "is_defaulter": false,
    "curp": null
  }
}
```

#### 4.3 Probar endpoint protegido

1. Copia el `access_token` de la respuesta anterior
2. Click en el botón "🔒 Authorize" arriba a la derecha
3. Pega el token en el campo (sin "Bearer ")
4. Click "Authorize"
5. Ahora prueba `GET /api/v1/auth/me`
6. Deberías recibir tu información de usuario

### 5. Estructura Visual del Código

Verifica que la estructura en `backend/app/` sea:

```
app/
├── core/                    ✅ Infraestructura base
│   ├── config.py
│   ├── database.py
│   ├── security.py
│   ├── exceptions.py
│   ├── middleware.py
│   └── dependencies.py
├── shared/                  ✅ Código compartido
│   └── domain/
│       ├── entities/
│       └── repositories/
├── modules/                 ✅ Módulos de negocio
│   └── auth/
│       ├── domain/
│       │   ├── entities/user.py
│       │   └── repositories/user_repository.py
│       ├── application/
│       │   ├── dtos/auth_dtos.py
│       │   └── use_cases/login.py
│       ├── infrastructure/
│       │   ├── models/user_model.py
│       │   ├── repositories/postgresql_user_repository.py
│       │   └── dependencies.py
│       └── routes.py
└── main.py                  ✅ Entry point
```

---

## �📚 REFERENCIAS

- **Plan Maestro:** `docs/PLAN_MAESTRO_V2.0.md`
- **Lógica de Negocio:** `docs/LOGICA_DE_NEGOCIO_DEFINITIVA.md`
- **Arquitectura Backend:** `docs/ARQUITECTURA_BACKEND_V2_DEFINITIVA.md`
- **Database v2.0:** `db/v2.0/init_monolithic.sql`
- **API Docs (Swagger):** `http://localhost:8000/docs` (cuando corre)

---

**Este documento se actualiza con cada sprint completado. 🚀**
