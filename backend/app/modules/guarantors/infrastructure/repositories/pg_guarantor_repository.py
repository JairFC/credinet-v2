"""Repositorio PostgreSQL de Guarantors"""
from typing import List, Optional

from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.guarantors.domain.entities.guarantor import Guarantor
from app.modules.guarantors.domain.repositories.guarantor_repository import GuarantorRepository
from app.modules.guarantors.infrastructure.models import GuarantorModel


def _map_model_to_entity(model: GuarantorModel) -> Guarantor:
    """Convierte GuarantorModel a Guarantor entity"""
    return Guarantor(
        id=model.id,
        user_id=model.user_id,
        full_name=model.full_name,
        first_name=model.first_name,
        paternal_last_name=model.paternal_last_name,
        maternal_last_name=model.maternal_last_name,
        relationship=model.relationship,
        phone_number=model.phone_number,
        curp=model.curp,
        created_at=model.created_at,
        updated_at=model.updated_at,
    )


class PgGuarantorRepository(GuarantorRepository):
    """Implementación PostgreSQL de GuarantorRepository"""
    
    def __init__(self, db: AsyncSession):
        self._db = db
    
    async def find_by_id(self, guarantor_id: int) -> Optional[Guarantor]:
        """Busca un aval por ID"""
        stmt = select(GuarantorModel).where(GuarantorModel.id == guarantor_id)
        result = await self._db.execute(stmt)
        model = result.scalar_one_or_none()
        
        return _map_model_to_entity(model) if model else None
    
    async def find_by_user_id(self, user_id: int) -> List[Guarantor]:
        """Busca todos los avales de un usuario"""
        stmt = (
            select(GuarantorModel)
            .where(GuarantorModel.user_id == user_id)
            .order_by(GuarantorModel.id)
        )
        
        result = await self._db.execute(stmt)
        models = result.scalars().all()
        
        return [_map_model_to_entity(m) for m in models]
    
    async def find_all(self, limit: int = 50, offset: int = 0) -> List[Guarantor]:
        """Lista todos los avales"""
        stmt = (
            select(GuarantorModel)
            .order_by(GuarantorModel.id)
            .limit(limit)
            .offset(offset)
        )
        
        result = await self._db.execute(stmt)
        models = result.scalars().all()
        
        return [_map_model_to_entity(m) for m in models]
    
    async def count(self) -> int:
        """Cuenta el total de avales"""
        stmt = select(func.count(GuarantorModel.id))
        result = await self._db.execute(stmt)
        return result.scalar() or 0
    
    async def create(self, guarantor: Guarantor) -> Guarantor:
        """Crea un nuevo aval"""
        model = GuarantorModel(
            user_id=guarantor.user_id,
            full_name=guarantor.full_name,
            first_name=guarantor.first_name,
            paternal_last_name=guarantor.paternal_last_name,
            maternal_last_name=guarantor.maternal_last_name,
            relationship=guarantor.relationship,
            phone_number=guarantor.phone_number,
            curp=guarantor.curp,
        )
        
        self._db.add(model)
        await self._db.flush()
        await self._db.refresh(model)
        
        return _map_model_to_entity(model)
