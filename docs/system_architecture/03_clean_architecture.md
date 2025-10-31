# Clean Architecture en Credinet

> **Estado**: Migración gradual en progreso. Actualmente implementado parcialmente en el módulo `loans`.

## Visión General

El proyecto Credinet está migrando gradualmente de un patrón MVC tradicional hacia **Clean Architecture** para mejorar la mantenibilidad, testabilidad y escalabilidad del código.

## Estructura Clean Architecture Implementada

### Módulo `loans` - Ejemplo de Implementación

```
backend/app/loans/
├── presentation/           # Capa de Presentación (REST API)
│   ├── routes.py          # Endpoints HTTP con FastAPI
│   └── schemas.py         # DTOs para requests/responses HTTP
├── application/           # Capa de Aplicación (Casos de Uso)
│   ├── use_cases.py       # Lógica de negocio encapsulada
│   └── dtos.py            # DTOs para comunicación entre capas
├── domain/                # Capa de Dominio (Entities)
│   └── entities/          # Entidades de dominio puras
│       └── __init__.py
└── infrastructure/        # Capa de Infraestructura
    └── dependencies.py    # Inyección de dependencias
```

## Capas y Responsabilidades

### 1. **Presentation Layer** (`presentation/`)

**Responsabilidades**:
- Manejo de requests/responses HTTP
- Validación de entrada con Pydantic
- Transformación de DTOs de aplicación a DTOs de presentación
- Manejo de errores HTTP

**Ejemplo - `routes.py`**:
```python
@router.post("/", response_model=CreateLoanResponse, status_code=status.HTTP_201_CREATED)
async def create_loan(
    request: CreateLoanRequest,
    current_user: UserInDB = Depends(get_current_user),
    use_case: CreateLoanUseCase = Depends(get_create_loan_use_case)
):
    """Crear nuevo préstamo validando cliente y garante"""
    app_request = AppCreateLoanRequest(
        user_id=request.user_id,
        amount=request.amount,
        # ... mapping de DTOs
    )
    result = await use_case.execute(app_request)
    return CreateLoanResponse.from_domain(result)
```

### 2. **Application Layer** (`application/`)

**Responsabilidades**:
- Implementación de casos de uso de negocio
- Orquestación de entidades de dominio
- Manejo de reglas de negocio complejas
- Comunicación con capa de infraestructura

**Casos de Uso Implementados**:
- `CreateLoanUseCase`: Creación de préstamos con validaciones
- `ApproveLoanUseCase`: Aprobación de préstamos
- `DisburseLoanUseCase`: Desembolso de préstamos
- `GetLoanUseCase`: Obtención de préstamos
- `CalculateAmortizationUseCase`: Cálculo de amortización

**Ejemplo - `use_cases.py`**:
```python
class CreateLoanUseCase:
    def __init__(self, repository: LoanRepository):
        self.repository = repository
    
    async def execute(self, request: CreateLoanRequest) -> CreateLoanResult:
        # 1. Validar cliente existe
        client = await self.repository.get_user(request.user_id)
        if not client:
            raise ValidationError("Cliente no encontrado")
        
        # 2. Validar garante si existe
        if request.guarantor_data:
            await self._validate_guarantor(request.guarantor_data)
        
        # 3. Crear préstamo
        loan = await self.repository.create_loan(request)
        
        return CreateLoanResult.from_domain(loan)
```

### 3. **Domain Layer** (`domain/`)

**Responsabilidades**:
- Entidades de negocio puras (sin dependencias externas)
- Reglas de negocio fundamentales
- Value Objects
- Domain Services

**Estado Actual**: Estructura creada pero entidades aún no completamente implementadas.

### 4. **Infrastructure Layer** (`infrastructure/`)

**Responsabilidades**:
- Inyección de dependencias
- Configuración de repositorios
- Adaptadores para servicios externos

**Ejemplo - `dependencies.py`**:
```python
async def get_create_loan_use_case() -> CreateLoanUseCase:
    # En el futuro, aquí se inyectarían repositorios
    return CreateLoanUseCase()

async def get_approve_loan_use_case() -> ApproveLoanUseCase:
    return ApproveLoanUseCase()
```

## Estados de Migración por Módulo

### ✅ **Loans** - Parcialmente Migrado
- **Presentación**: ✅ Implementado con DTOs
- **Aplicación**: 🔄 Casos de uso básicos implementados
- **Dominio**: ❌ Entidades pendientes de implementación
- **Infraestructura**: 🔄 Inyección de dependencias básica

### 🔄 **Auth** - En Refactorización
- **Estado**: Deshabilitado en `main.py` por problemas de dependencias circulares
- **Problema**: Schemas Pydantic conflictivos entre capas
- **Plan**: Separación clara de DTOs por capa

### ❌ **Associates** - Pendiente
- **Estado**: Patrón MVC tradicional
- **Plan**: Migración posterior a loans

### ❌ **Documents** - Pendiente
- **Estado**: Versión "fixed" funcionando
- **Plan**: Migración de baja prioridad

## Beneficios Observados

### ✅ **Ventajas ya implementadas**:
- **Separación de responsabilidades**: Cada capa tiene un propósito claro
- **Testabilidad**: Los casos de uso son fáciles de probar unitariamente
- **Flexibilidad**: Cambios en la presentación no afectan la lógica de negocio

### 🔄 **Beneficios en progreso**:
- **Independencia de frameworks**: Lógica de negocio desacoplada de FastAPI
- **Inyección de dependencias**: Facilita mocking en tests

## Desafíos y Lecciones Aprendidas

### ❌ **Problemas encontrados**:
1. **Dependencias circulares**: Auth deshabilitado por imports circulares
2. **Complejidad de DTOs**: Múltiples transformaciones entre capas
3. **Migración gradual**: Convivencia difícil entre patrones

### 💡 **Soluciones aplicadas**:
1. **Múltiples implementaciones paralelas**: 3 implementaciones de loans endpoint
2. **Deshabilitación temporal**: Comentar módulos problemáticos
3. **Migración por módulos**: Un módulo completo a la vez

## Roadmap de Migración

### **Fase 1: Completar Loans** ✅ Parcial
- [ ] Implementar entidades de dominio
- [ ] Completar repositorios
- [ ] Tests unitarios para casos de uso

### **Fase 2: Refactorizar Auth** 🔄
- [ ] Resolver dependencias circulares
- [ ] Separar DTOs por capa
- [ ] Reimplementar casos de uso de autenticación

### **Fase 3: Migrar Associates**
- [ ] Aplicar patrón aprendido de loans
- [ ] Consolidar rutas duplicadas

### **Fase 4: Migrar Módulos Restantes**
- [ ] Documents, Payments, Periods
- [ ] Unificar patrones en toda la aplicación

## Referencias

- [Clean Architecture - Uncle Bob](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)
- [Hexagonal Architecture](https://alistair.cockburn.us/hexagonal-architecture/)
- [FastAPI Clean Architecture Example](https://github.com/zhanymkanov/fastapi-best-practices)