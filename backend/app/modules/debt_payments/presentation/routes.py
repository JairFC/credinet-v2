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
    4. Actualiza consolidated_debt en associate_profiles
    5. Libera crédito automáticamente (available_credit se recalcula)
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
    - Deuda actual (consolidated_debt)
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


@router.get(
    "/associates-with-debt",
    summary="List all associates with pending debt",
    description="Returns a list of all associates who have accumulated debt"
)
def list_associates_with_debt(
    include_zero: bool = Query(False, description="Include associates with zero debt balance"),
    db: Session = Depends(get_db),
    current_user_id: int = Depends(get_current_user_id)
):
    """
    Lista todos los asociados que tienen deuda acumulada.
    
    Ideal para:
    - Dashboard de gestión de deudas
    - Reportes de cartera vencida
    - Identificar asociados que necesitan seguimiento
    
    **Permissions**: admin, auxiliar_administrativo
    """
    try:
        from sqlalchemy import text
        
        # Obtener asociados con deuda desde la tabla associate_accumulated_balances
        where_clause = "" if include_zero else "WHERE total_debt > 0"
        
        result = db.execute(text(f"""
            SELECT 
                aab.user_id,
                u.first_name || ' ' || u.last_name as associate_name,
                ap.id as associate_profile_id,
                COALESCE(SUM(aab.accumulated_debt), 0) as total_debt,
                COUNT(DISTINCT aab.cut_period_id) as periods_with_debt,
                MIN(aab.created_at) as oldest_debt_date,
                MAX(aab.updated_at) as last_update,
                ap.consolidated_debt as profile_consolidated_debt,
                ap.credit_limit,
                ap.available_credit
            FROM associate_accumulated_balances aab
            JOIN users u ON u.id = aab.user_id
            LEFT JOIN associate_profiles ap ON ap.user_id = aab.user_id
            GROUP BY aab.user_id, u.first_name, u.last_name, ap.id, ap.consolidated_debt, ap.credit_limit, ap.available_credit
            {where_clause}
            ORDER BY total_debt DESC
        """)).fetchall()
        
        return {
            "success": True,
            "count": len(result),
            "data": [
                {
                    "user_id": row[0],
                    "associate_name": row[1],
                    "associate_profile_id": row[2],
                    "total_debt": float(row[3]) if row[3] else 0.0,
                    "periods_with_debt": row[4],
                    "oldest_debt_date": row[5].isoformat() if row[5] else None,
                    "last_update": row[6].isoformat() if row[6] else None,
                    "profile_consolidated_debt": float(row[7]) if row[7] else 0.0,
                    "credit_limit": float(row[8]) if row[8] else 0.0,
                    "available_credit": float(row[9]) if row[9] else 0.0
                }
                for row in result
            ]
        }
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error listing associates with debt: {str(e)}"
        )


@router.get(
    "/associates/{user_id}/debt-details",
    summary="Get detailed debt breakdown for an associate",
    description="Returns detailed information about each debt item for an associate"
)
def get_associate_debt_details(
    user_id: int,
    db: Session = Depends(get_db),
    current_user_id: int = Depends(get_current_user_id)
):
    """
    Obtiene el desglose detallado de deudas de un asociado.
    
    Muestra:
    - Cada período con deuda
    - Detalles de statements que generaron la deuda
    - Montos originales, pagados y pendientes
    
    **Permissions**: admin, auxiliar_administrativo, asociado (solo su propia deuda)
    """
    try:
        from sqlalchemy import text
        
        # Obtener registros de deuda acumulada
        result = db.execute(text("""
            SELECT 
                aab.id,
                aab.cut_period_id,
                cp.cut_code,
                aab.accumulated_debt,
                aab.debt_details,
                aab.created_at,
                aab.updated_at
            FROM associate_accumulated_balances aab
            JOIN cut_periods cp ON cp.id = aab.cut_period_id
            WHERE aab.user_id = :user_id
            ORDER BY aab.created_at ASC
        """), {"user_id": user_id}).fetchall()
        
        # Calcular totales
        total_debt = sum(float(row[3]) for row in result)
        
        return {
            "success": True,
            "user_id": user_id,
            "total_debt": total_debt,
            "debt_items": [
                {
                    "id": row[0],
                    "cut_period_id": row[1],
                    "cut_code": row[2],
                    "accumulated_debt": float(row[3]),
                    "debt_details": row[4],  # JSONB con detalles de statements
                    "created_at": row[5].isoformat() if row[5] else None,
                    "updated_at": row[6].isoformat() if row[6] else None
                }
                for row in result
            ]
        }
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error fetching debt details: {str(e)}"
        )
