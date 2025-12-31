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
from ..application.enhanced_service import StatementEnhancedService
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
    db: Session = Depends(get_db),
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
        
        # Obtener datos completos con JOINs
        enhanced_service = StatementEnhancedService(db)
        statement_data = enhanced_service.get_statement_with_details(statement.id)
        
        if not statement_data:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Failed to retrieve generated statement {statement.id}"
            )
        
        return StatementResponseDTO(**statement_data)
        
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
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """
    Get statement details by ID.
    
    **Permissions**: admin, supervisor, associate (own statements only)
    """
    try:
        # Usar servicio mejorado con JOINs
        enhanced_service = StatementEnhancedService(db)
        statement_data = enhanced_service.get_statement_with_details(statement_id)
        
        if not statement_data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Statement {statement_id} not found"
            )
        
        # Retornar datos completos (sin TODOs)
        return StatementResponseDTO(**statement_data)
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error fetching statement: {str(e)}"
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
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """
    List statements with filters.
    
    **Permissions**: admin, supervisor (all), associate (own only)
    """
    try:
        # Usar servicio mejorado con JOINs
        enhanced_service = StatementEnhancedService(db)
        
        statements_data = enhanced_service.list_statements_with_details(
            user_id=user_id,
            cut_period_id=cut_period_id,
            status_filter=status_filter,
            is_overdue=is_overdue,
            limit=limit,
            offset=offset
        )
        
        # Retornar datos completos (sin TODOs)
        return [StatementSummaryDTO(**s) for s in statements_data]
        
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
    db: Session = Depends(get_db),
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
        
        # Obtener datos completos con JOINs
        enhanced_service = StatementEnhancedService(db)
        statement_data = enhanced_service.get_statement_with_details(statement_id)
        
        if not statement_data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Statement {statement_id} not found after update"
            )
        
        return StatementResponseDTO(**statement_data)
        
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
    db: Session = Depends(get_db),
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
        
        # Obtener datos completos con JOINs
        enhanced_service = StatementEnhancedService(db)
        statement_data = enhanced_service.get_statement_with_details(statement_id)
        
        if not statement_data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Statement {statement_id} not found after update"
            )
        
        return StatementResponseDTO(**statement_data)
        
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
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """
    Get statistics for a period.
    
    **Permissions**: admin, supervisor
    """
    from sqlalchemy import text
    
    # Verificar que el período existe y obtener su código
    period = db.execute(
        text("SELECT cut_code FROM cut_periods WHERE id = :id"),
        {"id": cut_period_id}
    ).fetchone()
    
    if not period:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Cut period {cut_period_id} not found"
        )
    
    # Obtener estadísticas agregadas
    stats = db.execute(text("""
        SELECT 
            COUNT(DISTINCT s.id) AS total_statements,
            COUNT(DISTINCT s.user_id) AS total_associates,
            COALESCE(SUM(s.total_payments_count), 0) AS total_payments,
            COALESCE(SUM(s.total_amount_collected), 0) AS total_collected,
            COALESCE(SUM(s.commission_earned), 0) AS total_commissions,
            COUNT(DISTINCT CASE WHEN st.code = 'PAID' THEN s.id END) AS paid_statements,
            COUNT(DISTINCT CASE WHEN s.is_overdue = true THEN s.id END) AS overdue_statements,
            COUNT(DISTINCT CASE WHEN st.code IN ('GENERATED', 'SENT') THEN s.id END) AS pending_statements
        FROM associate_payment_statements s
        JOIN statement_statuses st ON st.id = s.status_id
        WHERE s.cut_period_id = :cut_period_id
    """), {"cut_period_id": cut_period_id}).fetchone()
    
    if not stats:
        # Si no hay statements para este período, retornar ceros
        return PeriodStatsDTO(
            cut_period_id=cut_period_id,
            cut_period_code=period[0],
            total_statements=0,
            total_associates=0,
            total_payments=0,
            total_collected=0,
            total_commissions=0,
            paid_statements=0,
            overdue_statements=0,
            pending_statements=0
        )
    
    return PeriodStatsDTO(
        cut_period_id=cut_period_id,
        cut_period_code=period[0],
        total_statements=stats[0] or 0,
        total_associates=stats[1] or 0,
        total_payments=stats[2] or 0,
        total_collected=stats[3] or 0,
        total_commissions=stats[4] or 0,
        paid_statements=stats[5] or 0,
        overdue_statements=stats[6] or 0,
        pending_statements=stats[7] or 0
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
    from sqlalchemy import text
    
    # Validar que el statement existe
    statement = db.execute(
        text("SELECT id, total_amount_collected, total_to_credicuenta, paid_amount, status_id FROM associate_payment_statements WHERE id = :id"),
        {"id": statement_id}
    ).fetchone()
    
    if not statement:
        raise HTTPException(status_code=404, detail=f"Statement {statement_id} no encontrado")
    
    # Insertar abono (trigger hace el resto)
    result = db.execute(text("""
        INSERT INTO associate_statement_payments 
        (statement_id, payment_amount, payment_date, payment_method_id, payment_reference, registered_by, notes)
        VALUES (:statement_id, :payment_amount, :payment_date, :payment_method_id, :payment_reference, :registered_by, :notes)
        RETURNING id, created_at
    """), {
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
    updated_statement = db.execute(text("""
        SELECT 
            paid_amount,
            total_to_credicuenta AS total_adeudado,
            status_id
        FROM associate_payment_statements
        WHERE id = :id
    """), {"id": statement_id}).fetchone()
    
    return {
        "success": True,
        "data": {
            "payment_id": payment[0],
            "statement_id": statement_id,
            "payment_amount": payment_amount,
            "paid_amount_total": float(updated_statement[0]) if updated_statement[0] else 0.0,
            "remaining_amount": max(0, float(updated_statement[1]) - (float(updated_statement[0]) if updated_statement[0] else 0.0)),
            "status": "PAID" if updated_statement[2] == 3 else "PARTIAL" if updated_statement[2] == 4 else "COLLECTING",
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
    from sqlalchemy import text
    
    # Obtener statement
    statement = db.execute(text("""
        SELECT 
            aps.id,
            aps.total_amount_collected,
            aps.total_to_credicuenta,
            aps.paid_amount,
            aps.status_id,
            ss.name AS status_name
        FROM associate_payment_statements aps
        JOIN statement_statuses ss ON ss.id = aps.status_id
        WHERE aps.id = :id
    """), {"id": statement_id}).fetchone()
    
    if not statement:
        raise HTTPException(status_code=404, detail=f"Statement {statement_id} no encontrado")
    
    # Obtener abonos
    payments = db.execute(text("""
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
    """), {"statement_id": statement_id}).fetchall()
    
    total_owed = float(statement[2])  # total_to_credicuenta (ya es el adeudo directo)
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

@router.delete(
    "/{statement_id}/payments/{payment_id}",
    summary="Eliminar un abono del statement",
    description="Elimina un abono registrado. Solo permitido en períodos EN COBRO."
)
async def delete_statement_payment(
    statement_id: int,
    payment_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """
    Elimina un abono de un statement.
    
    **Restricciones:**
    - Solo se pueden eliminar abonos de statements en períodos EN COBRO (status 4)
    - Se actualiza automáticamente el paid_amount del statement
    
    **Permissions:** admin, auxiliar_administrativo
    """
    from sqlalchemy import text
    
    # Verificar que el abono existe y obtener info
    payment = db.execute(text("""
        SELECT 
            asp.id,
            asp.statement_id,
            asp.payment_amount,
            aps.status_id AS statement_status,
            cp.status_id AS period_status
        FROM associate_statement_payments asp
        JOIN associate_payment_statements aps ON aps.id = asp.statement_id
        JOIN cut_periods cp ON cp.id = aps.cut_period_id
        WHERE asp.id = :payment_id AND asp.statement_id = :statement_id
    """), {"payment_id": payment_id, "statement_id": statement_id}).fetchone()
    
    if not payment:
        raise HTTPException(
            status_code=404, 
            detail=f"Abono {payment_id} no encontrado en statement {statement_id}"
        )
    
    # Solo permitir eliminar en períodos EN COBRO (4) o LIQUIDACIÓN (6)
    if payment.period_status not in [4, 6]:  # COLLECTING or SETTLING
        raise HTTPException(
            status_code=400,
            detail="Solo se pueden eliminar abonos de períodos EN COBRO o LIQUIDACIÓN"
        )
    
    # Obtener el monto antes de eliminar
    payment_amount = float(payment.payment_amount)
    
    # Eliminar el abono
    db.execute(text("""
        DELETE FROM associate_statement_payments
        WHERE id = :payment_id
    """), {"payment_id": payment_id})
    
    # Actualizar paid_amount del statement (restar el monto eliminado)
    db.execute(text("""
        UPDATE associate_payment_statements
        SET 
            paid_amount = GREATEST(0, COALESCE(paid_amount, 0) - :amount),
            updated_at = NOW()
        WHERE id = :statement_id
    """), {"statement_id": statement_id, "amount": payment_amount})
    
    # Verificar si el statement debe cambiar de estado
    # Si paid_amount = 0 y estaba en PARTIAL, volver a COLLECTING
    db.execute(text("""
        UPDATE associate_payment_statements
        SET status_id = CASE
            WHEN paid_amount = 0 AND status_id = 4 THEN 7  -- PARTIAL → COLLECTING
            WHEN paid_amount > 0 AND paid_amount < total_to_credicuenta AND status_id = 3 THEN 4  -- PAID → PARTIAL
            ELSE status_id
        END
        WHERE id = :statement_id
    """), {"statement_id": statement_id})
    
    db.commit()
    
    # Obtener estado actualizado
    updated = db.execute(text("""
        SELECT paid_amount, total_to_credicuenta, status_id
        FROM associate_payment_statements
        WHERE id = :id
    """), {"id": statement_id}).fetchone()
    
    return {
        "success": True,
        "message": f"Abono de ${payment_amount:.2f} eliminado correctamente",
        "data": {
            "deleted_payment_id": payment_id,
            "deleted_amount": payment_amount,
            "new_paid_amount": float(updated[0]) if updated[0] else 0.0,
            "total_owed": float(updated[1]) if updated[1] else 0.0,
            "new_status_id": updated[2]
        }
    }