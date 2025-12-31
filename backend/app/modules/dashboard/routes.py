"""
Dashboard Routes - Métricas principales del sistema
"""
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, and_
from datetime import datetime, date
from decimal import Decimal

from app.core.database import get_async_db
from app.core.dependencies import require_admin
from app.modules.loans.infrastructure.models import LoanModel
from app.modules.payments.infrastructure.models import PaymentModel
from pydantic import BaseModel


class DashboardStatsDTO(BaseModel):
    """Estadísticas principales del dashboard"""
    total_loans: int
    active_loans: int
    pending_loans: int
    total_clients: int
    pending_payments_count: int
    pending_payments_amount: Decimal
    overdue_payments_count: int
    overdue_payments_amount: Decimal
    collected_today: Decimal
    collected_this_month: Decimal
    total_disbursed: Decimal


router = APIRouter(
    prefix="/dashboard",
    tags=["dashboard"],
    dependencies=[Depends(require_admin)]  # 🔒 Solo admins
)


@router.get("/stats", response_model=DashboardStatsDTO)
async def get_dashboard_stats(db: AsyncSession = Depends(get_async_db)):
    """
    Obtiene estadísticas principales para el dashboard.
    
    Retorna:
    - total_loans: Total de préstamos en sistema
    - active_loans: Préstamos activos (status 3)
    - pending_loans: Préstamos pendientes aprobación (status 1)
    - total_clients: Total de clientes únicos
    - pending_payments_count: Pagos pendientes
    - pending_payments_amount: Monto total pendiente
    - overdue_payments_count: Pagos vencidos
    - overdue_payments_amount: Monto vencido
    - collected_today: Cobrado hoy
    - collected_this_month: Cobrado este mes
    - total_disbursed: Total desembolsado
    """
    
    # Total préstamos
    total_loans_query = select(func.count()).select_from(LoanModel)
    total_loans = (await db.execute(total_loans_query)).scalar_one()
    
    # Préstamos activos (status_id = 3)
    active_loans_query = select(func.count()).select_from(LoanModel).where(LoanModel.status_id == 3)
    active_loans = (await db.execute(active_loans_query)).scalar_one()
    
    # Préstamos pendientes (status_id = 1)
    pending_loans_query = select(func.count()).select_from(LoanModel).where(LoanModel.status_id == 1)
    pending_loans = (await db.execute(pending_loans_query)).scalar_one()
    
    # Total clientes únicos
    total_clients_query = select(func.count(func.distinct(LoanModel.user_id))).select_from(LoanModel)
    total_clients = (await db.execute(total_clients_query)).scalar_one()
    
    # Pagos pendientes (amount_paid < expected_amount)
    pending_payments_query = select(
        func.count(PaymentModel.id),
        func.coalesce(func.sum(PaymentModel.expected_amount - PaymentModel.amount_paid), 0)
    ).where(PaymentModel.amount_paid < PaymentModel.expected_amount)
    pending_result = (await db.execute(pending_payments_query)).first()
    pending_payments_count = pending_result[0] or 0
    pending_payments_amount = Decimal(str(pending_result[1] or 0))
    
    # Pagos vencidos (payment_due_date < hoy AND amount_paid < expected_amount)
    today = date.today()
    overdue_payments_query = select(
        func.count(PaymentModel.id),
        func.coalesce(func.sum(PaymentModel.expected_amount - PaymentModel.amount_paid), 0)
    ).where(
        and_(
            PaymentModel.payment_due_date < today,
            PaymentModel.amount_paid < PaymentModel.expected_amount
        )
    )
    overdue_result = (await db.execute(overdue_payments_query)).first()
    overdue_payments_count = overdue_result[0] or 0
    overdue_payments_amount = Decimal(str(overdue_result[1] or 0))
    
    # Cobrado hoy (marked_at today)
    collected_today_query = select(
        func.coalesce(func.sum(PaymentModel.amount_paid), 0)
    ).where(
        func.date(PaymentModel.marked_at) == today
    )
    collected_today_result = (await db.execute(collected_today_query)).scalar_one()
    collected_today = Decimal(str(collected_today_result or 0))
    
    # Cobrado este mes
    first_day_of_month = today.replace(day=1)
    collected_month_query = select(
        func.coalesce(func.sum(PaymentModel.amount_paid), 0)
    ).where(
        func.date(PaymentModel.marked_at) >= first_day_of_month
    )
    collected_month_result = (await db.execute(collected_month_query)).scalar_one()
    collected_this_month = Decimal(str(collected_month_result or 0))
    
    # Total desembolsado (suma de todos los préstamos aprobados)
    total_disbursed_query = select(
        func.coalesce(func.sum(LoanModel.amount), 0)
    ).where(LoanModel.status_id.in_([2, 3, 4]))  # APPROVED, ACTIVE, COMPLETED
    total_disbursed_result = (await db.execute(total_disbursed_query)).scalar_one()
    total_disbursed = Decimal(str(total_disbursed_result or 0))
    
    return DashboardStatsDTO(
        total_loans=total_loans,
        active_loans=active_loans,
        pending_loans=pending_loans,
        total_clients=total_clients,
        pending_payments_count=pending_payments_count,
        pending_payments_amount=pending_payments_amount,
        overdue_payments_count=overdue_payments_count,
        overdue_payments_amount=overdue_payments_amount,
        collected_today=collected_today,
        collected_this_month=collected_this_month,
        total_disbursed=total_disbursed
    )
