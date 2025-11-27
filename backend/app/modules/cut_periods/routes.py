"""Rutas FastAPI para cut_periods"""
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text
from typing import List, Dict, Any
from datetime import date

from app.core.database import get_async_db
from app.modules.cut_periods.application.dtos import (
    CutPeriodResponseDTO,
    CutPeriodListItemDTO,
    PaginatedCutPeriodsDTO,
)
from app.modules.cut_periods.application.use_cases import (
    ListCutPeriodsUseCase,
    GetActiveCutPeriodUseCase,
)
from app.modules.cut_periods.infrastructure.repositories.pg_cut_period_repository import PgCutPeriodRepository


router = APIRouter(prefix="/cut-periods", tags=["Cut Periods"])


def generate_cut_code(period_start: date, cut_number: int) -> str:
    """Genera código de corte en formato MesNN-YYYY (ej: Nov01-2025)"""
    months = [
        'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
        'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ]
    month_name = months[period_start.month - 1]
    # cut_number impar = primer corte del mes (01), par = segundo corte (02)
    corte_num = '01' if cut_number % 2 == 1 else '02'
    return f"{month_name}{corte_num}-{period_start.year}"


def get_cut_period_repository(db: AsyncSession = Depends(get_async_db)) -> PgCutPeriodRepository:
    """Dependency injection del repositorio de periodos"""
    return PgCutPeriodRepository(db)


@router.get("", response_model=PaginatedCutPeriodsDTO)
async def list_cut_periods(
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0),
    repo: PgCutPeriodRepository = Depends(get_cut_period_repository),
):
    """Lista todos los periodos de corte con paginación"""
    try:
        use_case = ListCutPeriodsUseCase(repo)
        periods = await use_case.execute(limit, offset)
        total = await repo.count()
        
        items = [
            CutPeriodListItemDTO(
                id=p.id,
                cut_number=p.cut_number,
                cut_code=generate_cut_code(p.period_start_date, p.cut_number),
                period_start_date=p.period_start_date,
                period_end_date=p.period_end_date,
                payment_date=p.period_end_date,  # Fecha de pago es el final del período
                cut_date=p.period_end_date,      # Fecha de corte es el final del período
                status_id=p.status_id,
                collection_percentage=p.get_collection_percentage(),
            )
            for p in periods
        ]
        
        return PaginatedCutPeriodsDTO(
            items=items,
            total=total,
            limit=limit,
            offset=offset,
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error listing cut periods: {str(e)}"
        )


@router.get("/active", response_model=CutPeriodResponseDTO)
async def get_active_cut_period(
    repo: PgCutPeriodRepository = Depends(get_cut_period_repository),
):
    """Obtiene el periodo de corte activo actual"""
    try:
        use_case = GetActiveCutPeriodUseCase(repo)
        period = await use_case.execute()
        
        if not period:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="No active cut period found"
            )
        
        return CutPeriodResponseDTO(
            id=period.id,
            cut_number=period.cut_number,
            period_start_date=period.period_start_date,
            period_end_date=period.period_end_date,
            status_id=period.status_id,
            total_payments_expected=period.total_payments_expected,
            total_payments_received=period.total_payments_received,
            total_commission=period.total_commission,
            created_by=period.created_by,
            closed_by=period.closed_by,
            created_at=period.created_at,
            updated_at=period.updated_at,
            collection_percentage=period.get_collection_percentage(),
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error fetching active cut period: {str(e)}"
        )


@router.get("/{period_id}/statements")
async def get_period_statements(
    period_id: int,
    db: AsyncSession = Depends(get_async_db),
):
    """Obtiene todos los statements de un período específico"""
    try:
        # Verificar que el período existe
        result = await db.execute(
            text("""
            SELECT id FROM cut_periods WHERE id = :id
            """),
            {"id": period_id}
        )
        period = result.fetchone()
        
        if not period:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Period {period_id} not found"
            )
        
        # Calcular cut_code dinámicamente
        period_result = await db.execute(
            text("""
            SELECT period_start_date, cut_number FROM cut_periods WHERE id = :id
            """),
            {"id": period_id}
        )
        period_data = period_result.fetchone()
        if not period_data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Period {period_id} not found"
            )
        
        cut_code = generate_cut_code(period_data.period_start_date, period_data.cut_number)
        
        # Obtener statements del período con información del asociado
        result = await db.execute(
            text("""
            SELECT 
                aps.id,
                aps.associate_id,
                aps.cut_code,
                aps.total_collected_amount,
                aps.commission_amount,
                aps.total_statement_amount,
                aps.paid_statement_amount,
                aps.statement_status_id,
                aps.late_fee_amount,
                aps.created_at,
                u.first_name || ' ' || u.last_name AS associate_name
            FROM associate_payment_statements aps
            LEFT JOIN users u ON u.id = aps.associate_id
            WHERE aps.cut_code = :cut_code
            ORDER BY u.last_name, u.first_name
            """),
            {"cut_code": cut_code}
        )
        
        statements = result.fetchall()
        
        return {
            "success": True,
            "data": [
                {
                    "id": s[0],
                    "associate_id": s[1],
                    "cut_code": s[2],
                    "total_collected_amount": float(s[3]) if s[3] else 0.0,
                    "commission_amount": float(s[4]) if s[4] else 0.0,
                    "total_statement_amount": float(s[5]) if s[5] else 0.0,
                    "paid_statement_amount": float(s[6]) if s[6] else 0.0,
                    "statement_status_id": s[7],
                    "late_fee_amount": float(s[8]) if s[8] else 0.0,
                    "created_at": s[9].isoformat() if s[9] else None,
                    "associate_name": s[10]
                }
                for s in statements
            ]
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error fetching period statements: {str(e)}"
        )
