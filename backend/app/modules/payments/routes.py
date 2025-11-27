"""
Rutas FastAPI para el módulo de pagos (payments).

Endpoints:
- GET /payments/loans/:loanId → Listar pagos de un préstamo
- GET /payments/:id → Detalle de un pago
- POST /payments/register → Registrar un pago
- GET /payments/:id/summary → Resumen de pagos de un préstamo
"""
from typing import Optional, List
from pydantic import BaseModel

from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_async_db
from app.modules.payments.application.dtos import (
    RegisterPaymentDTO,
    PaymentResponseDTO,
    PaymentSummaryDTO,
    PaymentListItemDTO,
)
from app.modules.payments.application.use_cases import (
    RegisterPaymentUseCase,
    GetLoanPaymentsUseCase,
    GetPaymentDetailsUseCase,
    GetPaymentSummaryUseCase,
)
from app.modules.payments.infrastructure.repositories.pg_payment_repository import PgPaymentRepository


router = APIRouter(prefix="/payments", tags=["Payments"])


# =============================================================================
# DEPENDENCIAS
# =============================================================================

def get_payment_repository(db: AsyncSession = Depends(get_async_db)) -> PgPaymentRepository:
    """Dependency injection del repositorio de pagos."""
    return PgPaymentRepository(db)


# =============================================================================
# ENDPOINTS
# =============================================================================

@router.get("/loans/{loan_id}", response_model=List[PaymentListItemDTO])
async def list_loan_payments(
    loan_id: int,
    pending_only: bool = Query(False, description="Si True, solo pagos pendientes"),
    repo: PgPaymentRepository = Depends(get_payment_repository),
):
    """
    Lista todos los pagos de un préstamo.
    
    Args:
        loan_id: ID del préstamo
        pending_only: Si True, solo retorna pagos pendientes
        
    Returns:
        Lista de pagos del préstamo ordenados por payment_number
        
    Ejemplos:
    - GET /payments/loans/123 → Todos los pagos del préstamo 123
    - GET /payments/loans/123?pending_only=true → Solo pagos pendientes
    """
    try:
        use_case = GetLoanPaymentsUseCase(repo)
        payments = await use_case.execute(loan_id, pending_only)
        
        # Convertir entidades a DTOs
        return [
            PaymentListItemDTO(
                id=p.id,
                payment_number=p.payment_number,
                expected_amount=p.expected_amount,
                amount_paid=p.amount_paid,
                payment_due_date=p.payment_due_date,
                status_name="",  # TODO: Agregar join con payment_statuses
                is_late=p.is_late,
                balance_remaining=p.balance_remaining,
            )
            for p in payments
        ]
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error listing payments: {str(e)}"
        )


@router.get("/{payment_id}", response_model=PaymentResponseDTO)
async def get_payment_details(
    payment_id: int,
    repo: PgPaymentRepository = Depends(get_payment_repository),
):
    """
    Obtiene el detalle completo de un pago.
    
    Args:
        payment_id: ID del pago
        
    Returns:
        Detalle completo del pago
        
    Raises:
        404: Si el pago no existe
        
    Ejemplo:
    - GET /payments/456 → Detalle del pago 456
    """
    try:
        use_case = GetPaymentDetailsUseCase(repo)
        payment = await use_case.execute(payment_id)
        
        if not payment:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Payment {payment_id} not found"
            )
        
        # Convertir entidad a DTO
        return PaymentResponseDTO(
            id=payment.id,
            loan_id=payment.loan_id,
            payment_number=payment.payment_number,
            expected_amount=payment.expected_amount,
            interest_amount=payment.interest_amount,
            principal_amount=payment.principal_amount,
            commission_amount=payment.commission_amount,
            associate_payment=payment.associate_payment,
            balance_remaining=payment.balance_remaining,
            amount_paid=payment.amount_paid,
            payment_date=payment.payment_date,
            payment_due_date=payment.payment_due_date,
            is_late=payment.is_late,
            status_id=payment.status_id,
            cut_period_id=payment.cut_period_id,
            marked_by=payment.marked_by,
            marked_at=payment.marked_at,
            marking_notes=payment.marking_notes,
            created_at=payment.created_at,
            updated_at=payment.updated_at,
            # Campos calculados
            remaining_amount=payment.get_remaining_amount(),
            is_paid=payment.is_paid(),
            is_pending=payment.is_pending(),
            is_overdue=payment.is_overdue(),
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error fetching payment details: {str(e)}"
        )


@router.post("/register", response_model=PaymentResponseDTO, status_code=status.HTTP_200_OK)
async def register_payment(
    payload: RegisterPaymentDTO,
    repo: PgPaymentRepository = Depends(get_payment_repository),
):
    """
    Registra un pago (marca como pagado).
    
    ⚠️ IMPORTANTE: Este endpoint NO actualiza manualmente el crédito del asociado.
    El trigger update_associate_credit_on_payment en PostgreSQL lo hace automáticamente.
    
    Args:
        payload: Datos del pago a registrar
        
    Returns:
        Payment actualizado
        
    Raises:
        400: Si el pago ya está completado o el monto excede el esperado
        404: Si el pago no existe
        
    Ejemplo:
    ```json
    POST /payments/register
    {
        "payment_id": 123,
        "amount_paid": 1500.00,
        "payment_date": "2025-11-06",
        "marked_by": 1,
        "notes": "Pago recibido en efectivo"
    }
    ```
    """
    try:
        use_case = RegisterPaymentUseCase(repo)
        payment = await use_case.execute(
            payment_id=payload.payment_id,
            amount_paid=payload.amount_paid,
            payment_date=payload.payment_date,
            marked_by=payload.marked_by,
            notes=payload.notes,
        )
        
        # Convertir entidad a DTO
        return PaymentResponseDTO(
            id=payment.id,
            loan_id=payment.loan_id,
            payment_number=payment.payment_number,
            expected_amount=payment.expected_amount,
            interest_amount=payment.interest_amount,
            principal_amount=payment.principal_amount,
            commission_amount=payment.commission_amount,
            associate_payment=payment.associate_payment,
            balance_remaining=payment.balance_remaining,
            amount_paid=payment.amount_paid,
            payment_date=payment.payment_date,
            payment_due_date=payment.payment_due_date,
            is_late=payment.is_late,
            status_id=payment.status_id,
            cut_period_id=payment.cut_period_id,
            marked_by=payment.marked_by,
            marked_at=payment.marked_at,
            marking_notes=payment.marking_notes,
            created_at=payment.created_at,
            updated_at=payment.updated_at,
            # Campos calculados
            remaining_amount=payment.get_remaining_amount(),
            is_paid=payment.is_paid(),
            is_pending=payment.is_pending(),
            is_overdue=payment.is_overdue(),
        )
    except ValueError as e:
        # Errores de validación de negocio
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error registering payment: {str(e)}"
        )


@router.get("/loans/{loan_id}/summary", response_model=PaymentSummaryDTO)
async def get_payment_summary(
    loan_id: int,
    repo: PgPaymentRepository = Depends(get_payment_repository),
):
    """
    Obtiene el resumen de pagos de un préstamo.
    
    Args:
        loan_id: ID del préstamo
        
    Returns:
        Resumen con estadísticas de pagos del préstamo
        
    Ejemplo:
    - GET /payments/loans/123/summary → Resumen de pagos del préstamo 123
    
    Respuesta:
    ```json
    {
        "loan_id": 123,
        "total_payments": 24,
        "payments_paid": 10,
        "payments_pending": 14,
        "payments_overdue": 2,
        "total_paid_amount": 15000.00,
        "total_expected_amount": 36000.00,
        "completion_percentage": 41.67
    }
    ```
    """
    try:
        use_case = GetPaymentSummaryUseCase(repo)
        summary = await use_case.execute(loan_id)
        
        total_expected = summary['total_expected_amount']
        total_paid = summary['total_paid_amount']
        total_pending = total_expected - total_paid
        
        return PaymentSummaryDTO(
            loan_id=loan_id,
            total_payments=summary['total_payments'],
            payments_paid=summary['payments_paid'],
            payments_pending=summary['payments_pending'],
            payments_overdue=summary['payments_overdue'],
            total_expected=total_expected,
            total_paid=total_paid,
            total_pending=total_pending,
            next_payment_due_date=None,  # TODO: implementar próximo pago
            next_payment_amount=None,
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error fetching payment summary: {str(e)}"
        )


# DTO para marcar pago
class MarkPaymentRequestDTO(BaseModel):
    """Request para marcar un pago como cobrado."""
    marked_by: int
    amount_paid: Optional[float] = None
    notes: Optional[str] = None


@router.put("/{payment_id}/mark", response_model=PaymentResponseDTO)
async def mark_payment_as_paid(
    payment_id: int,
    data: MarkPaymentRequestDTO,
    repo: PgPaymentRepository = Depends(get_payment_repository),
):
    """
    Marca un pago como pagado (total o parcial).
    
    Este endpoint permite registrar que un pago fue cobrado.
    Si no se especifica monto, se marca como pagado el monto esperado completo.
    
    Args:
        payment_id: ID del pago a marcar
        data: Datos del pago (marked_by, amount_paid, notes)
        
    Returns:
        Pago actualizado con la información de cobro
        
    Raises:
        404: Si el pago no existe
        400: Si el pago ya está pagado completamente
        
    Ejemplo:
    ```json
    PUT /payments/123/mark
    {
        "marked_by": 1,
        "amount_paid": 2145.83,
        "notes": "Pago recibido en efectivo"
    }
    ```
    """
    try:
        # Obtener pago actual
        payment = await repo.find_by_id(payment_id)
        if not payment:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Payment {payment_id} not found"
            )
        
        # Validar que no esté completamente pagado
        if payment.is_paid():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Payment {payment_id} is already fully paid"
            )
        
        # Si no se especifica monto, usar el remaining
        from decimal import Decimal
        if data.amount_paid is None:
            amount_to_add = payment.get_remaining_amount()
        else:
            amount_to_add = Decimal(str(data.amount_paid))
        
        # Calcular nuevo amount_paid
        new_amount_paid = payment.amount_paid + amount_to_add
        
        # Validar que no exceda el esperado
        if new_amount_paid > payment.expected_amount:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Amount paid ({new_amount_paid}) exceeds expected amount ({payment.expected_amount})"
            )
        
        # Actualizar pago
        from datetime import datetime
        updated_payment = await repo.mark_payment(
            payment_id=payment_id,
            amount_paid=new_amount_paid,
            marked_by=data.marked_by,
            marked_at=datetime.now(),
            notes=data.notes
        )
        
        # Retornar DTO
        return PaymentResponseDTO(
            id=updated_payment.id,
            loan_id=updated_payment.loan_id,
            payment_number=updated_payment.payment_number,
            expected_amount=updated_payment.expected_amount,
            interest_amount=updated_payment.interest_amount,
            principal_amount=updated_payment.principal_amount,
            commission_amount=updated_payment.commission_amount,
            associate_payment=updated_payment.associate_payment,
            balance_remaining=updated_payment.balance_remaining,
            amount_paid=updated_payment.amount_paid,
            payment_date=updated_payment.payment_date,
            payment_due_date=updated_payment.payment_due_date,
            is_late=updated_payment.is_late,
            status_id=updated_payment.status_id,
            cut_period_id=updated_payment.cut_period_id,
            marked_by=updated_payment.marked_by,
            marked_at=updated_payment.marked_at,
            marking_notes=updated_payment.marking_notes,
            created_at=updated_payment.created_at,
            updated_at=updated_payment.updated_at,
            remaining_amount=updated_payment.get_remaining_amount(),
            is_paid=updated_payment.is_paid(),
            is_pending=updated_payment.is_pending(),
            is_overdue=updated_payment.is_overdue(),
        )
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error marking payment: {str(e)}"
        )
