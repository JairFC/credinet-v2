"""Repositorio PostgreSQL de Beneficiaries"""
from typing import List, Optional

from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.beneficiaries.domain.entities.beneficiary import Beneficiary
from app.modules.beneficiaries.domain.repositories.beneficiary_repository import BeneficiaryRepository
from app.modules.beneficiaries.infrastructure.models import BeneficiaryModel


def _map_model_to_entity(model: BeneficiaryModel) -> Beneficiary:
    """Convierte BeneficiaryModel a Beneficiary entity"""
    return Beneficiary(
        id=model.id,
        user_id=model.user_id,
        full_name=model.full_name,
        relationship=model.relationship,
        phone_number=model.phone_number,
        created_at=model.created_at,
        updated_at=model.updated_at,
    )


class PgBeneficiaryRepository(BeneficiaryRepository):
    """Implementación PostgreSQL de BeneficiaryRepository"""
    
    def __init__(self, db: AsyncSession):
        self._db = db
    
    async def find_by_id(self, beneficiary_id: int) -> Optional[Beneficiary]:
        """Busca un beneficiario por ID"""
        stmt = select(BeneficiaryModel).where(BeneficiaryModel.id == beneficiary_id)
        result = await self._db.execute(stmt)
        model = result.scalar_one_or_none()
        
        return _map_model_to_entity(model) if model else None
    
    async def find_by_user_id(self, user_id: int) -> List[Beneficiary]:
        """Busca todos los beneficiarios de un usuario"""
        stmt = (
            select(BeneficiaryModel)
            .where(BeneficiaryModel.user_id == user_id)
            .order_by(BeneficiaryModel.id)
        )
        
        result = await self._db.execute(stmt)
        models = result.scalars().all()
        
        return [_map_model_to_entity(m) for m in models]
    
    async def find_all(self, limit: int = 50, offset: int = 0) -> List[Beneficiary]:
        """Lista todos los beneficiarios"""
        stmt = (
            select(BeneficiaryModel)
            .order_by(BeneficiaryModel.id)
            .limit(limit)
            .offset(offset)
        )
        
        result = await self._db.execute(stmt)
        models = result.scalars().all()
        
        return [_map_model_to_entity(m) for m in models]
    
    async def count(self) -> int:
        """Cuenta el total de beneficiarios"""
        stmt = select(func.count(BeneficiaryModel.id))
        result = await self._db.execute(stmt)
        return result.scalar() or 0
    
    async def create(self, beneficiary: Beneficiary) -> Beneficiary:
        """Crea un nuevo beneficiario"""
        model = BeneficiaryModel(
            user_id=beneficiary.user_id,
            full_name=beneficiary.full_name,
            relationship=beneficiary.relationship,
            phone_number=beneficiary.phone_number,
        )
        
        self._db.add(model)
        await self._db.flush()
        await self._db.refresh(model)
        
        return _map_model_to_entity(model)
