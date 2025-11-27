"""Repositorio PostgreSQL de Cut Periods"""
from decimal import Decimal
from typing import List, Optional

from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.cut_periods.domain.entities.cut_period import CutPeriod
from app.modules.cut_periods.domain.repositories.cut_period_repository import CutPeriodRepository
from app.modules.cut_periods.infrastructure.models import CutPeriodModel


def _map_model_to_entity(model: CutPeriodModel) -> CutPeriod:
    """Convierte CutPeriodModel a CutPeriod entity"""
    return CutPeriod(
        id=model.id,
        cut_number=model.cut_number,
        period_start_date=model.period_start_date,
        period_end_date=model.period_end_date,
        status_id=model.status_id,
        total_payments_expected=Decimal(str(model.total_payments_expected)),
        total_payments_received=Decimal(str(model.total_payments_received)),
        total_commission=Decimal(str(model.total_commission)),
        created_by=model.created_by,
        closed_by=model.closed_by,
        created_at=model.created_at,
        updated_at=model.updated_at,
    )


class PgCutPeriodRepository(CutPeriodRepository):
    """Implementación PostgreSQL de CutPeriodRepository"""
    
    def __init__(self, db: AsyncSession):
        self._db = db
    
    async def find_by_id(self, period_id: int) -> Optional[CutPeriod]:
        """Busca un periodo por ID"""
        stmt = select(CutPeriodModel).where(CutPeriodModel.id == period_id)
        result = await self._db.execute(stmt)
        model = result.scalar_one_or_none()
        
        return _map_model_to_entity(model) if model else None
    
    async def find_all(self, limit: int = 50, offset: int = 0) -> List[CutPeriod]:
        """Lista todos los periodos"""
        stmt = (
            select(CutPeriodModel)
            .order_by(CutPeriodModel.cut_number.desc())
            .limit(limit)
            .offset(offset)
        )
        
        result = await self._db.execute(stmt)
        models = result.scalars().all()
        
        return [_map_model_to_entity(m) for m in models]
    
    async def find_active(self) -> Optional[CutPeriod]:
        """Busca el periodo activo actual"""
        # status_id = 1 es ACTIVE (ajustar según catálogo)
        stmt = (
            select(CutPeriodModel)
            .where(CutPeriodModel.status_id == 1)
            .order_by(CutPeriodModel.period_start_date.desc())
            .limit(1)
        )
        
        result = await self._db.execute(stmt)
        model = result.scalar_one_or_none()
        
        return _map_model_to_entity(model) if model else None
    
    async def count(self) -> int:
        """Cuenta el total de periodos"""
        stmt = select(func.count(CutPeriodModel.id))
        result = await self._db.execute(stmt)
        return result.scalar() or 0
