# 🚀 PLAN DE ACCIÓN INMEDIATO - CREDINET V2.0

**Fecha**: 2025-11-05  
**Basado en**: Análisis exhaustivo del sistema  
**Objetivo**: Completar los módulos faltantes y corregir issues críticos

---

## 📊 ESTADO ACTUAL DEL PROYECTO

### Progreso General

```
✅ Completo:          7%  (1/14 módulos)
⚠️ Backend only:     36%  (5/14 módulos)
🔴 Ausente:          57%  (8/14 módulos)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Total Completado:    7%
```

### Módulos Implementados

| Módulo | Backend | Frontend | Estado |
|--------|---------|----------|--------|
| Auth | ✅ | ✅ | ✅ Completo |
| Loans | ✅ | ❌ | ⚠️ Backend only |
| Rate Profiles | ✅ | ❌ | ⚠️ Backend only |
| Catalogs | ✅ | ❌ | ⚠️ Backend only |

### Módulos Faltantes (Críticos)

| Módulo | Prioridad | Tiempo Est. | Bloqueador |
|--------|-----------|-------------|------------|
| **Payments** | 🔥🔥🔥 | 2 semanas | Sistema no puede operar |
| **Associates** | 🔥🔥 | 2 semanas | No se puede ver crédito |
| **Clients** | 🔥 | 1.5 semanas | Arquitectura inconsistente |
| **Payment Statements** | 🟡 | 3 semanas | Operación manual posible |

---

## 🔴 ISSUES CRÍTICOS IDENTIFICADOS

### Issue #1: Plazo de Préstamo Hardcodeado a 12 Quincenas

**Descripción**: El sistema fuerza todos los préstamos a 12 quincenas, pero v2.0 debe ser flexible.

**Ubicaciones del problema**:
```
1. db/v2.0/init.sql - Función generate_payment_schedule()
2. backend/app/modules/loans/ - Código hardcodeado
3. docs/00_START_HERE/01_PROYECTO_OVERVIEW.md - Documentación
4. frontend-mvp/ - Mock data
```

**Impacto**: 🔴 **CRÍTICO**
- No se pueden crear préstamos de 6, 18 o 24 quincenas
- Limita flexibilidad del negocio
- No cumple objetivo v2.0

**Tiempo de corrección**: 3-4 días

---

### Issue #2: Módulo Payments Ausente

**Descripción**: No hay forma de registrar pagos desde el sistema.

**Impacto**: 🔴 **CRÍTICO**
- Sistema no puede operar en producción
- Asociados no pueden registrar cobros
- No hay auditoría de pagos

**Tiempo de corrección**: 2 semanas (implementación completa)

---

### Issue #3: Módulo Associates Ausente

**Descripción**: No se puede consultar crédito disponible del asociado.

**Impacto**: 🔴 **ALTO**
- Asociados no saben cuánto pueden prestar
- No hay visibilidad de deuda acumulada
- Decisiones de negocio sin información

**Tiempo de corrección**: 2 semanas (implementación completa)

---

### Issue #4: Módulo Clients Ausente

**Descripción**: Información de clientes mezclada con préstamos.

**Impacto**: 🟡 **MEDIO**
- Arquitectura inconsistente
- Dificulta escalabilidad
- No se pueden gestionar clientes independientemente

**Tiempo de corrección**: 1.5 semanas (implementación completa)

---

## 🎯 PLAN DE ACCIÓN PROPUESTO

### FASE 0: Corrección de Issues Críticos (1 semana)

#### Tarea 0.1: Flexibilizar Plazo de Préstamo (3-4 días)

**Objetivo**: Permitir préstamos de 6, 12, 18 y 24 quincenas

**Subtareas**:

1. **Modificar función `generate_payment_schedule()` en DB** (1 día)
   ```sql
   -- db/v2.0/modules/05_functions_base.sql
   
   CREATE OR REPLACE FUNCTION generate_payment_schedule()
   RETURNS TRIGGER AS $$
   DECLARE
       v_term INT;
       v_first_payment_date DATE;
       v_current_date DATE;
   BEGIN
       -- Obtener term dinámicamente
       v_term := NEW.term_biweeks;  -- En lugar de hardcodear 12
       
       -- Calcular primera fecha
       v_first_payment_date := calculate_first_payment_date(NEW.approved_at);
       v_current_date := v_first_payment_date;
       
       -- Generar pagos dinámicamente
       FOR i IN 1..v_term LOOP
           INSERT INTO payments (
               loan_id,
               payment_number,
               due_date,
               expected_amount,
               -- ... resto de campos
           ) VALUES (
               NEW.id,
               i,
               v_current_date,
               NEW.biweekly_payment,
               -- ... resto de valores
           );
           
           -- Calcular siguiente fecha (día 15 ↔ último día)
           v_current_date := calculate_next_payment_date(v_current_date);
       END LOOP;
       
       RETURN NEW;
   END;
   $$ LANGUAGE plpgsql;
   ```

2. **Agregar constraint en tabla `loans`** (0.5 días)
   ```sql
   ALTER TABLE loans
   ADD CONSTRAINT check_term_biweeks_valid 
   CHECK (term_biweeks IN (6, 12, 18, 24));
   
   COMMENT ON CONSTRAINT check_term_biweeks_valid ON loans IS
   'Valida que el plazo sea uno de los valores permitidos: 6, 12, 18 o 24 quincenas';
   ```

3. **Actualizar backend para usar `term_biweeks`** (1 día)
   ```python
   # backend/app/modules/loans/application/services/__init__.py
   
   async def create_loan(self, dto: CreateLoanDTO) -> Loan:
       # ANTES:
       # term = 12  # ❌ Hardcodeado
       
       # DESPUÉS:
       term = dto.term_biweeks  # ✅ Dinámico
       
       # Validar que sea válido
       if term not in [6, 12, 18, 24]:
           raise ValueError(f"Plazo inválido: {term}. Debe ser 6, 12, 18 o 24 quincenas")
       
       # ... resto de la lógica
   ```

4. **Actualizar DTOs** (0.5 días)
   ```python
   # backend/app/modules/loans/application/dtos/__init__.py
   
   class CreateLoanDTO(BaseModel):
       amount: Decimal
       term_biweeks: int = Field(..., ge=6, le=24)  # ✅ Validación Pydantic
       profile_code: str
       # ... resto de campos
       
       @validator('term_biweeks')
       def validate_term(cls, v):
           if v not in [6, 12, 18, 24]:
               raise ValueError('Plazo debe ser 6, 12, 18 o 24 quincenas')
           return v
   ```

5. **Actualizar documentación** (0.5 días)
   ```markdown
   # docs/00_START_HERE/01_PROYECTO_OVERVIEW.md
   
   - 📅 **Plazo**: 6, 12, 18 o 24 quincenas (flexible)
     - 6 quincenas = 3 meses
     - 12 quincenas = 6 meses (más común)
     - 18 quincenas = 9 meses
     - 24 quincenas = 12 meses
   ```

6. **Agregar tests** (1 día)
   ```python
   # backend/tests/modules/loans/test_flexible_term.py
   
   @pytest.mark.parametrize("term", [6, 12, 18, 24])
   async def test_create_loan_with_valid_term(term):
       loan = await create_loan(amount=20000, term_biweeks=term)
       assert loan.term_biweeks == term
       
       # Verificar que se generaron N pagos
       payments = await get_payment_schedule(loan.id)
       assert len(payments) == term
   
   @pytest.mark.parametrize("term", [3, 5, 8, 30, 36])
   async def test_create_loan_with_invalid_term_fails(term):
       with pytest.raises(ValueError):
           await create_loan(amount=20000, term_biweeks=term)
   ```

**Entregable**: Sistema soporta 6, 12, 18 y 24 quincenas

---

### FASE 1: Implementar Módulo Payments (2 semanas)

#### Semana 1: Core del módulo

**Tarea 1.1: Estructura del módulo** (1 día)
```bash
mkdir -p backend/app/modules/payments/{domain,application,infrastructure,presentation}
mkdir -p backend/app/modules/payments/domain/{entities,repositories}
mkdir -p backend/app/modules/payments/application/{use_cases,dtos}
mkdir -p backend/app/modules/payments/infrastructure/{models,repositories}
```

**Tarea 1.2: Domain Layer** (1 día)
```python
# backend/app/modules/payments/domain/entities/payment.py

from dataclasses import dataclass
from datetime import datetime
from decimal import Decimal
from typing import Optional

@dataclass
class Payment:
    id: int
    loan_id: int
    payment_number: int
    due_date: datetime
    expected_amount: Decimal
    associate_payment: Decimal
    commission_amount: Decimal
    balance_remaining: Decimal
    amount_paid: Optional[Decimal]
    payment_date: Optional[datetime]
    status_id: int
    status_name: str
    cut_period_id: int
    created_at: datetime
    updated_at: datetime
```

**Tarea 1.3: Repository Interface** (0.5 días)
```python
# backend/app/modules/payments/domain/repositories/payment_repository.py

from abc import ABC, abstractmethod
from typing import List, Optional
from decimal import Decimal
from ..entities.payment import Payment

class PaymentRepository(ABC):
    @abstractmethod
    async def find_by_id(self, payment_id: int) -> Optional[Payment]:
        pass
    
    @abstractmethod
    async def find_by_loan_id(self, loan_id: int) -> List[Payment]:
        pass
    
    @abstractmethod
    async def register_payment(
        self, 
        payment_id: int, 
        amount_paid: Decimal,
        payment_date: datetime
    ) -> Payment:
        pass
    
    @abstractmethod
    async def update_status(
        self, 
        payment_id: int, 
        status_id: int,
        changed_by: int,
        reason: Optional[str]
    ) -> Payment:
        pass
```

**Tarea 1.4: Use Cases** (2 días)
```python
# backend/app/modules/payments/application/use_cases/register_payment.py

class RegisterPaymentUseCase:
    def __init__(self, repository: PaymentRepository):
        self.repository = repository
    
    async def execute(self, dto: RegisterPaymentDTO) -> Payment:
        # 1. Validar que payment existe
        payment = await self.repository.find_by_id(dto.payment_id)
        if not payment:
            raise PaymentNotFoundError(dto.payment_id)
        
        # 2. Validar que está pendiente
        if payment.status_name != 'PENDING':
            raise InvalidPaymentStatusError(payment.status_name)
        
        # 3. Validar monto
        if dto.amount_paid <= 0:
            raise InvalidAmountError(dto.amount_paid)
        
        # 4. Registrar pago (trigger se ejecuta automáticamente)
        payment = await self.repository.register_payment(
            payment_id=dto.payment_id,
            amount_paid=dto.amount_paid,
            payment_date=dto.payment_date
        )
        
        return payment
```

**Tarea 1.5: DTOs** (1 día)
```python
# backend/app/modules/payments/application/dtos/payment_dto.py

from pydantic import BaseModel, Field
from datetime import datetime
from decimal import Decimal
from typing import Optional

class RegisterPaymentDTO(BaseModel):
    payment_id: int
    amount_paid: Decimal = Field(..., gt=0)
    payment_date: datetime
    payment_method: Optional[str] = None
    notes: Optional[str] = None

class PaymentResponseDTO(BaseModel):
    id: int
    loan_id: int
    payment_number: int
    due_date: datetime
    expected_amount: Decimal
    amount_paid: Optional[Decimal]
    payment_date: Optional[datetime]
    status: str
    # ... resto de campos
```

#### Semana 2: Infrastructure y API

**Tarea 1.6: Infrastructure Layer** (2 días)
```python
# backend/app/modules/payments/infrastructure/repositories/pg_payment_repository.py

class PostgreSQLPaymentRepository(PaymentRepository):
    def __init__(self, session: AsyncSession):
        self.session = session
    
    async def register_payment(
        self, 
        payment_id: int, 
        amount_paid: Decimal,
        payment_date: datetime
    ) -> Payment:
        # Actualizar payment
        query = (
            update(PaymentModel)
            .where(PaymentModel.id == payment_id)
            .values(
                amount_paid=amount_paid,
                payment_date=payment_date,
                status_id=3  # PAID
            )
            .returning(PaymentModel)
        )
        
        result = await self.session.execute(query)
        payment_model = result.scalar_one()
        
        # Triggers se ejecutan automáticamente:
        # - trigger_update_associate_credit_on_payment
        # - trigger_log_payment_status_change
        
        await self.session.commit()
        
        return self._to_entity(payment_model)
```

**Tarea 1.7: API Routes** (2 días)
```python
# backend/app/modules/payments/presentation/routes.py

from fastapi import APIRouter, Depends, HTTPException
from ..application.use_cases import RegisterPaymentUseCase
from ..application.dtos import RegisterPaymentDTO, PaymentResponseDTO

router = APIRouter(prefix="/payments", tags=["payments"])

@router.post("/", response_model=PaymentResponseDTO)
async def register_payment(
    dto: RegisterPaymentDTO,
    use_case: RegisterPaymentUseCase = Depends()
):
    """
    Registrar un pago realizado por el cliente.
    
    Flujo:
    1. Valida que el pago existe y está pendiente
    2. Registra el monto y fecha de pago
    3. Actualiza status a PAID
    4. Triggers automáticos liberan crédito del asociado
    """
    try:
        payment = await use_case.execute(dto)
        return PaymentResponseDTO.from_entity(payment)
    except PaymentNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except InvalidPaymentStatusError as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.get("/loans/{loan_id}", response_model=List[PaymentResponseDTO])
async def get_loan_payments(loan_id: int, repository = Depends()):
    """Obtener todos los pagos de un préstamo"""
    payments = await repository.find_by_loan_id(loan_id)
    return [PaymentResponseDTO.from_entity(p) for p in payments]
```

**Tarea 1.8: Tests** (1 día)
```python
# backend/tests/modules/payments/test_register_payment.py

@pytest.mark.asyncio
async def test_register_payment_success():
    # Given
    loan = await create_approved_loan(amount=20000, term=12)
    first_payment = loan.payment_schedule[0]
    
    # When
    payment = await register_payment(
        payment_id=first_payment.id,
        amount_paid=first_payment.expected_amount,
        payment_date=first_payment.due_date
    )
    
    # Then
    assert payment.status_name == "PAID"
    assert payment.amount_paid == first_payment.expected_amount
    
    # Verificar que se liberó crédito
    associate = await get_associate(loan.associate_id)
    assert associate.credit_used < initial_credit_used
```

**Entregable**: Módulo Payments 100% funcional

---

### FASE 2: Implementar Módulo Associates (2 semanas)

#### Semana 3-4: Implementación completa

**Similar a Payments**, con estas particularidades:

**Endpoints clave**:
```python
GET    /api/v1/associates                    # Listar todos
GET    /api/v1/associates/:id                # Detalles
GET    /api/v1/associates/:id/credit         # ⭐ Crédito disponible
GET    /api/v1/associates/:id/debt           # Deuda acumulada
GET    /api/v1/associates/:id/loans          # Préstamos gestionados
GET    /api/v1/associates/:id/summary        # Dashboard
```

**Use Case principal**:
```python
# GetAssociateCreditUseCase
async def execute(self, associate_id: int) -> AssociateCredit:
    # Consultar vista v_associate_credit_summary
    credit = await self.repository.get_credit_summary(associate_id)
    return credit
```

**Entregable**: Módulo Associates 100% funcional

---

### FASE 3: Implementar Módulo Clients (1.5 semanas)

#### Semana 5-6: Implementación y refactoring

**Tareas**:
1. Crear módulo clients (1 semana)
2. Refactorizar loans para usar clients (0.5 semanas)

**Entregable**: Módulo Clients 100% funcional, arquitectura limpia

---

### FASE 4: Implementar Módulo Payment Statements (3 semanas)

#### Semana 7-9: Implementación completa + Job automático

**Tareas**:
1. Módulo payment_statements (2 semanas)
2. Job cron días 8/23 (0.5 semanas)
3. Generación de PDF (0.5 semanas)

**Entregable**: Relaciones de pago automáticas

---

## 📅 CRONOGRAMA COMPLETO

```
┌─────────────────────────────────────────────────────────────┐
│                    ROADMAP 9 SEMANAS                        │
├─────────────────────────────────────────────────────────────┤
│ Semana 1:   [██████████] FASE 0 - Corrección Issues        │
│ Semana 2-3: [██████████] FASE 1 - Módulo Payments          │
│ Semana 4-5: [██████████] FASE 2 - Módulo Associates        │
│ Semana 6:   [██████████] FASE 3 - Módulo Clients           │
│ Semana 7-9: [██████████] FASE 4 - Payment Statements       │
└─────────────────────────────────────────────────────────────┘

Fecha inicio: 2025-11-06 (mañana)
Fecha fin:    2026-01-08 (9 semanas después)
```

---

## ✅ CRITERIOS DE ACEPTACIÓN

### Para Fase 0 (Flexibilizar plazo)
- [ ] Se pueden crear préstamos de 6, 12, 18 y 24 quincenas
- [ ] `generate_payment_schedule()` genera N pagos (no hardcoded)
- [ ] Tests pasan para todos los plazos
- [ ] Documentación actualizada

### Para Fase 1 (Payments)
- [ ] Endpoint `POST /payments` funciona
- [ ] Trigger libera crédito del asociado
- [ ] Auditoría registra cambio en `payment_status_history`
- [ ] Tests de integración pasan
- [ ] Documentación API completa

### Para Fase 2 (Associates)
- [ ] Endpoint `GET /associates/:id/credit` funciona
- [ ] Devuelve `credit_available`, `credit_used`, `debt_balance`
- [ ] Vista `v_associate_credit_summary` se usa correctamente
- [ ] Tests pasan
- [ ] Documentación completa

### Para Fase 3 (Clients)
- [ ] CRUD completo de clientes
- [ ] Loans refactorizado para usar clients
- [ ] Tests pasan
- [ ] Sin regresiones

### Para Fase 4 (Payment Statements)
- [ ] Job automático funciona días 8/23
- [ ] PDF se genera correctamente
- [ ] Endpoint manual funciona
- [ ] Tests pasan
- [ ] Documentación completa

---

## 🎯 PRÓXIMOS PASOS INMEDIATOS

### Para HOY (2025-11-05)

1. ✅ **Leer análisis completo** (este documento)
2. ✅ **Revisar plan de acción**
3. ⏭️ **Decidir**: ¿Empezamos mañana con FASE 0?

### Para MAÑANA (2025-11-06)

Si decides avanzar, empezamos con:

1. **Modificar `generate_payment_schedule()` en DB**
2. **Agregar constraint en tabla `loans`**
3. **Actualizar backend**
4. **Tests iniciales**

---

## 📞 NECESITAS AYUDA?

Puedo ayudarte con:

- ✅ Implementar cualquier fase
- ✅ Escribir el código completo
- ✅ Generar tests
- ✅ Actualizar documentación
- ✅ Revisar PRs
- ✅ Debugging

Solo dime: **"Empecemos con FASE 0"** o **"Empecemos con módulo Payments"**

---

**Generado**: 2025-11-05  
**Última actualización**: 2025-11-05  
**Próxima revisión**: Después de cada fase
