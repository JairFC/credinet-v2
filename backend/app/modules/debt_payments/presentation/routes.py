"""
Endpoints para Debt Payments.

Gestiona el registro y consulta de pagos aplicados a deuda acumulada.
"""
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.modules.auth.routes import get_current_user_id

from ..application.dtos import (
    RegisterDebtPaymentDTO,
    DebtPaymentResponseDTO,
    DebtPaymentSummaryDTO,
    AssociateDebtSummaryDTO
)
from ..application.register_payment import RegisterDebtPaymentUseCase
from ..application.enhanced_service import DebtPaymentEnhancedService
from ..infrastructure.pg_repository import PgDebtPaymentRepository


router = APIRouter(prefix="/debt-payments", tags=["Debt Payments"])


def get_repository(db: Session = Depends(get_db)) -> PgDebtPaymentRepository:
    """Dependency para obtener el repositorio."""
    return PgDebtPaymentRepository(db)


@router.post(
    "/",
    response_model=DebtPaymentResponseDTO,
    status_code=status.HTTP_201_CREATED,
    summary="Register debt payment",
    description="Register a payment to liquidate accumulated debt using FIFO logic"
)
def register_debt_payment(
    dto: RegisterDebtPaymentDTO,
    db: Session = Depends(get_db),
    repository: PgDebtPaymentRepository = Depends(get_repository),
    current_user_id: int = Depends(get_current_user_id)
):
    """
    Registra un pago de deuda.
    
    **Lógica FIFO automática (trigger de BD):**
    1. Liquida primero los items de deuda más antiguos (created_at ASC)
    2. Si el pago cubre completamente un item → is_liquidated = true
    3. Si el pago es parcial → reduce el amount del item
    4. Actualiza debt_balance en associate_profiles
    5. Libera crédito automáticamente (credit_available se recalcula)
    6. Registra el detalle en applied_breakdown_items (JSONB)
    
    **Permissions**: admin, auxiliar_administrativo
    """
    try:
        # Ejecutar use case
        use_case = RegisterDebtPaymentUseCase(repository)
        payment = use_case.execute(dto, registered_by=current_user_id)
        
        # Obtener datos completos con JOINs
        enhanced_service = DebtPaymentEnhancedService(db)
        payment_data = enhanced_service.get_payment_with_details(payment.id)
        
        if not payment_data:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Failed to retrieve payment {payment.id} after creation"
            )
        
        return DebtPaymentResponseDTO(**payment_data)
        
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error registering debt payment: {str(e)}"
        )


@router.get(
    "/{payment_id}",
    response_model=DebtPaymentResponseDTO,
    summary="Get debt payment details",
    description="Retrieve detailed information about a specific debt payment"
)
def get_debt_payment(
    payment_id: int,
    db: Session = Depends(get_db),
    current_user_id: int = Depends(get_current_user_id)
):
    """
    Obtiene detalles de un pago de deuda.
    
    **Permissions**: admin, auxiliar_administrativo, asociado (solo sus propios pagos)
    """
    try:
        enhanced_service = DebtPaymentEnhancedService(db)
        payment_data = enhanced_service.get_payment_with_details(payment_id)
        
        if not payment_data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Debt payment {payment_id} not found"
            )
        
        return DebtPaymentResponseDTO(**payment_data)
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error fetching debt payment: {str(e)}"
        )


@router.get(
    "/",
    response_model=List[DebtPaymentSummaryDTO],
    summary="List debt payments",
    description="List debt payments with optional filters"
)
def list_debt_payments(
    associate_profile_id: Optional[int] = Query(None, description="Filter by associate profile ID"),
    limit: int = Query(50, ge=1, le=100, description="Results per page"),
    offset: int = Query(0, ge=0, description="Offset for pagination"),
    db: Session = Depends(get_db),
    current_user_id: int = Depends(get_current_user_id)
):
    """
    Lista pagos de deuda con filtros.
    
    **Permissions**: admin, auxiliar_administrativo (all), asociado (own only)
    """
    try:
        enhanced_service = DebtPaymentEnhancedService(db)
        payments_data = enhanced_service.list_payments_with_details(
            associate_profile_id=associate_profile_id,
            limit=limit,
            offset=offset
        )
        
        return [DebtPaymentSummaryDTO(**p) for p in payments_data]
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error listing debt payments: {str(e)}"
        )


@router.get(
    "/associates/{associate_profile_id}/summary",
    response_model=AssociateDebtSummaryDTO,
    summary="Get associate debt summary",
    description="Get comprehensive debt summary for an associate"
)
def get_associate_debt_summary(
    associate_profile_id: int,
    repository: PgDebtPaymentRepository = Depends(get_repository),
    current_user_id: int = Depends(get_current_user_id)
):
    """
    Obtiene resumen completo de deuda de un asociado.
    
    Utiliza la vista v_associate_debt_summary que incluye:
    - Deuda actual (debt_balance)
    - Items pendientes y liquidados
    - Total pagado a deuda
    - Fechas de deuda más antigua y último pago
    - Crédito disponible
    
    **Permissions**: admin, auxiliar_administrativo, asociado (solo su propio resumen)
    """
    try:
        summary = repository.get_associate_debt_summary(associate_profile_id)
        
        if not summary:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Associate profile {associate_profile_id} not found"
            )
        
        return AssociateDebtSummaryDTO(**summary)
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error fetching debt summary: {str(e)}"
        )
