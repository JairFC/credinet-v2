"""
Repositorio PostgreSQL de Associates
"""
from decimal import Decimal
from typing import List, Optional

from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.associates.domain.entities.associate import Associate
from app.modules.associates.domain.repositories.associate_repository import AssociateRepository
from app.modules.associates.infrastructure.models import AssociateProfileModel


def _map_model_to_entity(model: AssociateProfileModel) -> Associate:
    """Convierte AssociateProfileModel a Associate entity"""
    return Associate(
        id=model.id,
        user_id=model.user_id,
        level_id=model.level_id,
        contact_person=model.contact_person,
        contact_email=model.contact_email,
        default_commission_rate=Decimal(str(model.default_commission_rate)),
        active=model.active,
        consecutive_full_credit_periods=model.consecutive_full_credit_periods,
        consecutive_on_time_payments=model.consecutive_on_time_payments,
        clients_in_agreement=model.clients_in_agreement,
        last_level_evaluation_date=model.last_level_evaluation_date,
        credit_used=Decimal(str(model.credit_used)),
        credit_limit=Decimal(str(model.credit_limit)),
        credit_available=Decimal(str(model.credit_available)),
        credit_last_updated=model.credit_last_updated,
        debt_balance=Decimal(str(model.debt_balance)),
        created_at=model.created_at,
        updated_at=model.updated_at,
    )


class PgAssociateRepository(AssociateRepository):
    """Implementación PostgreSQL de AssociateRepository"""
    
    def __init__(self, db: AsyncSession):
        self._db = db
    
    async def find_by_id(self, associate_id: int) -> Optional[Associate]:
        """Busca un asociado por su profile ID"""
        stmt = select(AssociateProfileModel).where(AssociateProfileModel.id == associate_id)
        result = await self._db.execute(stmt)
        model = result.scalar_one_or_none()
        
        return _map_model_to_entity(model) if model else None
    
    async def find_by_user_id(self, user_id: int) -> Optional[Associate]:
        """Busca un asociado por su user_id"""
        stmt = select(AssociateProfileModel).where(AssociateProfileModel.user_id == user_id)
        result = await self._db.execute(stmt)
        model = result.scalar_one_or_none()
        
        return _map_model_to_entity(model) if model else None
    
    async def find_all(
        self,
        limit: int = 50,
        offset: int = 0,
        active_only: bool = True
    ) -> List[Associate]:
        """Lista todos los asociados"""
        stmt = select(AssociateProfileModel)
        
        if active_only:
            stmt = stmt.where(AssociateProfileModel.active == True)
        
        stmt = stmt.order_by(AssociateProfileModel.id).limit(limit).offset(offset)
        
        result = await self._db.execute(stmt)
        models = result.scalars().all()
        
        return [_map_model_to_entity(m) for m in models]
    
    async def count(self, active_only: bool = True) -> int:
        """Cuenta el total de asociados"""
        stmt = select(func.count(AssociateProfileModel.id))
        
        if active_only:
            stmt = stmt.where(AssociateProfileModel.active == True)
        
        result = await self._db.execute(stmt)
        return result.scalar() or 0
    
    async def update_credit(
        self,
        associate_id: int,
        credit_used: Decimal,
        credit_available: Decimal
    ) -> Associate:
        """Actualiza el crédito usado y disponible"""
        stmt = select(AssociateProfileModel).where(AssociateProfileModel.id == associate_id)
        result = await self._db.execute(stmt)
        model = result.scalar_one_or_none()
        
        if not model:
            raise ValueError(f"Associate {associate_id} not found")
        
        model.credit_used = credit_used
        model.credit_available = credit_available
        model.credit_last_updated = func.now()
        
        await self._db.flush()
        await self._db.refresh(model)
        
        return _map_model_to_entity(model)
