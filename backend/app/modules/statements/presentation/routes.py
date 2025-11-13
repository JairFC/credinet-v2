"""API routes for statements endpoints."""

from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from typing import List, Optional

from app.core.database import get_db
from app.modules.auth.routes import get_current_user

from ..application.dtos import (
    CreateStatementDTO,
    MarkStatementPaidDTO,
    ApplyLateFeeDTO,
    StatementResponseDTO,
    StatementSummaryDTO,
    PeriodStatsDTO
)
from ..application.generate_statement import GenerateStatementUseCase
from ..application.list_statements import ListStatementsUseCase
from ..application.get_statement_details import GetStatementDetailsUseCase
from ..application.mark_statement_paid import MarkStatementPaidUseCase
from ..application.apply_late_fee import ApplyLateFeeUseCase
from ..infrastructure.pg_statement_repository import PgStatementRepository


router = APIRouter(prefix="/statements", tags=["Statements"])


# Dependency: Get repository
def get_statement_repository(db: Session = Depends(get_db)) -> PgStatementRepository:
    """Get statement repository instance."""
    return PgStatementRepository(db)


@router.post(
    "/",
    response_model=StatementResponseDTO,
    status_code=status.HTTP_201_CREATED,
    summary="Generate new statement",
    description="Generate a new payment statement for an associate (typically automated)"
)
def generate_statement(
    dto: CreateStatementDTO,
    repository: PgStatementRepository = Depends(get_statement_repository),
    current_user: dict = Depends(get_current_user)
):
    """
    Generate a new statement.
    
    **Permissions**: admin, supervisor
    
    **Use case**: Typically called automatically on days 8 and 23,
    but can be manually triggered if needed.
    """
    try:
        use_case = GenerateStatementUseCase(repository)
        statement = use_case.execute(dto)
        
        # TODO: Map to response DTO with joined data
        return StatementResponseDTO(
            id=statement.id,
            statement_number=statement.statement_number,
            user_id=statement.user_id,
            associate_name="TODO",  # Fetch from user
            cut_period_id=statement.cut_period_id,
            cut_period_code="TODO",  # Fetch from cut_period
            total_payments_count=statement.total_payments_count,
            total_amount_collected=statement.total_amount_collected,
            total_commission_owed=statement.total_commission_owed,
            commission_rate_applied=statement.commission_rate_applied,
            status_id=statement.status_id,
            status_name="GENERATED",  # TODO: Fetch from status
            generated_date=statement.generated_date,
            sent_date=statement.sent_date,
            due_date=statement.due_date,
            paid_date=statement.paid_date,
            paid_amount=statement.paid_amount,
            payment_method_id=statement.payment_method_id,
            payment_method_name=None,
            payment_reference=statement.payment_reference,
            late_fee_amount=statement.late_fee_amount,
            late_fee_applied=statement.late_fee_applied,
            is_paid=statement.is_paid,
            is_overdue=statement.is_overdue,
            days_overdue=statement.days_overdue,
            remaining_amount=statement.remaining_amount,
            created_at=statement.created_at,
            updated_at=statement.updated_at
        )
        
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )


@router.get(
    "/{statement_id}",
    response_model=StatementResponseDTO,
    summary="Get statement details",
    description="Retrieve detailed information about a specific statement"
)
def get_statement(
    statement_id: int,
    repository: PgStatementRepository = Depends(get_statement_repository),
    current_user: dict = Depends(get_current_user)
):
    """
    Get statement details by ID.
    
    **Permissions**: admin, supervisor, associate (own statements only)
    """
    try:
        use_case = GetStatementDetailsUseCase(repository)
        statement = use_case.execute(statement_id)
        
        # TODO: Map to response DTO with joined data
        return StatementResponseDTO(
            id=statement.id,
            statement_number=statement.statement_number,
            user_id=statement.user_id,
            associate_name="TODO",
            cut_period_id=statement.cut_period_id,
            cut_period_code="TODO",
            total_payments_count=statement.total_payments_count,
            total_amount_collected=statement.total_amount_collected,
            total_commission_owed=statement.total_commission_owed,
            commission_rate_applied=statement.commission_rate_applied,
            status_id=statement.status_id,
            status_name="TODO",
            generated_date=statement.generated_date,
            sent_date=statement.sent_date,
            due_date=statement.due_date,
            paid_date=statement.paid_date,
            paid_amount=statement.paid_amount,
            payment_method_id=statement.payment_method_id,
            payment_method_name=None,
            payment_reference=statement.payment_reference,
            late_fee_amount=statement.late_fee_amount,
            late_fee_applied=statement.late_fee_applied,
            is_paid=statement.is_paid,
            is_overdue=statement.is_overdue,
            days_overdue=statement.days_overdue,
            remaining_amount=statement.remaining_amount,
            created_at=statement.created_at,
            updated_at=statement.updated_at
        )
        
    except LookupError as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(e)
        )


@router.get(
    "/",
    response_model=List[StatementSummaryDTO],
    summary="List statements",
    description="List statements with optional filters"
)
def list_statements(
    user_id: Optional[int] = Query(None, description="Filter by associate ID"),
    cut_period_id: Optional[int] = Query(None, description="Filter by period ID"),
    status_filter: Optional[str] = Query(None, description="Filter by status name"),
    is_overdue: Optional[bool] = Query(None, description="Filter overdue only"),
    limit: int = Query(10, ge=1, le=100, description="Results per page"),
    offset: int = Query(0, ge=0, description="Offset for pagination"),
    repository: PgStatementRepository = Depends(get_statement_repository),
    current_user: dict = Depends(get_current_user)
):
    """
    List statements with filters.
    
    **Permissions**: admin, supervisor (all), associate (own only)
    """
    try:
        use_case = ListStatementsUseCase(repository)
        
        if user_id:
            statements = use_case.by_associate(user_id, limit, offset)
        elif cut_period_id:
            statements = use_case.by_period(cut_period_id, limit, offset)
        elif status_filter:
            statements = use_case.by_status(status_filter, limit, offset)
        elif is_overdue:
            statements = use_case.overdue(limit, offset)
        else:
            # Default: list by associate (current user if associate)
            statements = use_case.by_associate(current_user.id, limit, offset)
        
        # TODO: Map to summary DTO with joined data
        return [
            StatementSummaryDTO(
                id=s.id,
                statement_number=s.statement_number,
                associate_name="TODO",
                cut_period_code="TODO",
                total_payments_count=s.total_payments_count,
                total_commission_owed=s.total_commission_owed,
                status_name="TODO",
                due_date=s.due_date,
                is_overdue=s.is_overdue,
                remaining_amount=s.remaining_amount
            )
            for s in statements
        ]
        
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )


@router.post(
    "/{statement_id}/mark-paid",
    response_model=StatementResponseDTO,
    summary="Mark statement as paid",
    description="Register payment for a statement"
)
def mark_statement_paid(
    statement_id: int,
    dto: MarkStatementPaidDTO,
    repository: PgStatementRepository = Depends(get_statement_repository),
    current_user: dict = Depends(get_current_user)
):
    """
    Mark statement as paid.
    
    **Permissions**: admin, supervisor
    """
    try:
        use_case = MarkStatementPaidUseCase(repository)
        statement = use_case.execute(statement_id, dto)
        
        # TODO: Map to response DTO
        return StatementResponseDTO(
            id=statement.id,
            statement_number=statement.statement_number,
            user_id=statement.user_id,
            associate_name="TODO",
            cut_period_id=statement.cut_period_id,
            cut_period_code="TODO",
            total_payments_count=statement.total_payments_count,
            total_amount_collected=statement.total_amount_collected,
            total_commission_owed=statement.total_commission_owed,
            commission_rate_applied=statement.commission_rate_applied,
            status_id=statement.status_id,
            status_name="TODO",
            generated_date=statement.generated_date,
            sent_date=statement.sent_date,
            due_date=statement.due_date,
            paid_date=statement.paid_date,
            paid_amount=statement.paid_amount,
            payment_method_id=statement.payment_method_id,
            payment_method_name=None,
            payment_reference=statement.payment_reference,
            late_fee_amount=statement.late_fee_amount,
            late_fee_applied=statement.late_fee_applied,
            is_paid=statement.is_paid,
            is_overdue=statement.is_overdue,
            days_overdue=statement.days_overdue,
            remaining_amount=statement.remaining_amount,
            created_at=statement.created_at,
            updated_at=statement.updated_at
        )
        
    except LookupError as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(e)
        )
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )


@router.post(
    "/{statement_id}/apply-late-fee",
    response_model=StatementResponseDTO,
    summary="Apply late fee",
    description="Apply late fee to overdue statement"
)
def apply_late_fee(
    statement_id: int,
    dto: ApplyLateFeeDTO,
    repository: PgStatementRepository = Depends(get_statement_repository),
    current_user: dict = Depends(get_current_user)
):
    """
    Apply late fee to statement.
    
    **Permissions**: admin, supervisor
    """
    try:
        use_case = ApplyLateFeeUseCase(repository)
        statement = use_case.execute(statement_id, dto)
        
        # TODO: Map to response DTO
        return StatementResponseDTO(
            id=statement.id,
            statement_number=statement.statement_number,
            user_id=statement.user_id,
            associate_name="TODO",
            cut_period_id=statement.cut_period_id,
            cut_period_code="TODO",
            total_payments_count=statement.total_payments_count,
            total_amount_collected=statement.total_amount_collected,
            total_commission_owed=statement.total_commission_owed,
            commission_rate_applied=statement.commission_rate_applied,
            status_id=statement.status_id,
            status_name="TODO",
            generated_date=statement.generated_date,
            sent_date=statement.sent_date,
            due_date=statement.due_date,
            paid_date=statement.paid_date,
            paid_amount=statement.paid_amount,
            payment_method_id=statement.payment_method_id,
            payment_method_name=None,
            payment_reference=statement.payment_reference,
            late_fee_amount=statement.late_fee_amount,
            late_fee_applied=statement.late_fee_applied,
            is_paid=statement.is_paid,
            is_overdue=statement.is_overdue,
            days_overdue=statement.days_overdue,
            remaining_amount=statement.remaining_amount,
            created_at=statement.created_at,
            updated_at=statement.updated_at
        )
        
    except LookupError as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(e)
        )
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )


@router.get(
    "/stats/period/{cut_period_id}",
    response_model=PeriodStatsDTO,
    summary="Get period statistics",
    description="Get aggregated statistics for a cut period"
)
def get_period_stats(
    cut_period_id: int,
    repository: PgStatementRepository = Depends(get_statement_repository),
    current_user: dict = Depends(get_current_user)
):
    """
    Get statistics for a period.
    
    **Permissions**: admin, supervisor
    """
    # TODO: Implement aggregation query
    raise HTTPException(
        status_code=status.HTTP_501_NOT_IMPLEMENTED,
        detail="Statistics endpoint not yet implemented"
    )


# =============================================================================
# ⭐ NUEVOS ENDPOINTS FASE 6 - ABONOS Y TRACKING
# =============================================================================

@router.post(
    "/{statement_id}/payments",
    status_code=status.HTTP_201_CREATED,
    summary="Registrar abono a saldo actual",
    description="Registra un abono parcial o total al statement. El trigger actualiza paid_amount automáticamente."
)
async def register_statement_payment(
    statement_id: int,
    payment_amount: float = Query(..., gt=0, description="Monto del abono"),
    payment_date: str = Query(..., description="Fecha del abono (YYYY-MM-DD)"),
    payment_method_id: int = Query(..., description="ID del método de pago"),
    payment_reference: Optional[str] = Query(None, description="Referencia bancaria"),
    notes: Optional[str] = Query(None, description="Notas adicionales"),
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """
    Registra un abono a saldo actual.
    
    **Lógica automática (triggers):**
    1. Suma todos los abonos del statement
    2. Actualiza paid_amount en associate_payment_statements
    3. Si paid_amount >= adeudado → PAID
    4. Si excedente → Aplica FIFO a deuda acumulada
    5. Libera crédito automáticamente
    
    **Permissions:** admin, auxiliar_administrativo
    """
    from datetime import date
    
    # Validar que el statement existe
    statement = db.execute(
        "SELECT id, total_amount_collected, total_commission_owed, paid_amount, status_id FROM associate_payment_statements WHERE id = :id",
        {"id": statement_id}
    ).fetchone()
    
    if not statement:
        raise HTTPException(status_code=404, detail=f"Statement {statement_id} no encontrado")
    
    # Insertar abono (trigger hace el resto)
    result = db.execute("""
        INSERT INTO associate_statement_payments 
        (statement_id, payment_amount, payment_date, payment_method_id, payment_reference, registered_by, notes)
        VALUES (:statement_id, :payment_amount, :payment_date, :payment_method_id, :payment_reference, :registered_by, :notes)
        RETURNING id, created_at
    """, {
        "statement_id": statement_id,
        "payment_amount": payment_amount,
        "payment_date": payment_date,
        "payment_method_id": payment_method_id,
        "payment_reference": payment_reference,
        "registered_by": current_user.id,
        "notes": notes
    })
    
    db.commit()
    payment = result.fetchone()
    
    # Obtener estado actualizado del statement
    updated_statement = db.execute("""
        SELECT 
            paid_amount,
            total_amount_collected - total_commission_owed AS total_adeudado,
            status_id
        FROM associate_payment_statements
        WHERE id = :id
    """, {"id": statement_id}).fetchone()
    
    return {
        "success": True,
        "data": {
            "payment_id": payment[0],
            "statement_id": statement_id,
            "payment_amount": payment_amount,
            "paid_amount_total": float(updated_statement[0]) if updated_statement[0] else 0.0,
            "remaining_amount": max(0, float(updated_statement[1]) - (float(updated_statement[0]) if updated_statement[0] else 0.0)),
            "status": "PAID" if updated_statement[2] == 2 else "PARTIAL_PAID" if updated_statement[2] == 3 else "PENDING",
            "registered_at": payment[1].isoformat()
        }
    }


@router.get(
    "/{statement_id}/payments",
    summary="Listar abonos del statement",
    description="Obtiene el desglose de todos los abonos realizados a un statement"
)
async def list_statement_payments(
    statement_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """
    Lista todos los abonos de un statement.
    
    **Permissions:** admin, auxiliar_administrativo, asociado (solo sus statements)
    """
    # Obtener statement
    statement = db.execute("""
        SELECT 
            aps.id,
            aps.total_amount_collected,
            aps.total_commission_owed,
            aps.paid_amount,
            aps.status_id,
            ss.name AS status_name
        FROM associate_payment_statements aps
        JOIN statement_statuses ss ON ss.id = aps.status_id
        WHERE aps.id = :id
    """, {"id": statement_id}).fetchone()
    
    if not statement:
        raise HTTPException(status_code=404, detail=f"Statement {statement_id} no encontrado")
    
    # Obtener abonos
    payments = db.execute("""
        SELECT 
            asp.id,
            asp.payment_amount,
            asp.payment_date,
            asp.payment_reference,
            pm.name AS payment_method,
            CONCAT(u.first_name, ' ', u.last_name) AS registered_by,
            asp.notes,
            asp.created_at
        FROM associate_statement_payments asp
        JOIN payment_methods pm ON pm.id = asp.payment_method_id
        JOIN users u ON u.id = asp.registered_by
        WHERE asp.statement_id = :statement_id
        ORDER BY asp.payment_date DESC, asp.created_at DESC
    """, {"statement_id": statement_id}).fetchall()
    
    total_owed = float(statement[1]) - float(statement[2])  # collected - commission
    paid_amount = float(statement[3]) if statement[3] else 0.0
    
    return {
        "success": True,
        "data": {
            "statement_id": statement_id,
            "total_owed": total_owed,
            "paid_amount": paid_amount,
            "remaining": max(0, total_owed - paid_amount),
            "status": statement[5],
            "payments": [
                {
                    "id": p[0],
                    "payment_amount": float(p[1]),
                    "payment_date": p[2].isoformat(),
                    "payment_reference": p[3],
                    "payment_method": p[4],
                    "registered_by": p[5],
                    "notes": p[6],
                    "created_at": p[7].isoformat()
                }
                for p in payments
            ]
        }
    }
