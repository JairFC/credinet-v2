"""Rutas FastAPI para cut_periods"""
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession

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
                period_start_date=p.period_start_date,
                period_end_date=p.period_end_date,
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
