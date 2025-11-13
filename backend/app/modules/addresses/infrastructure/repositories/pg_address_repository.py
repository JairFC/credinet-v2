"""Repositorio PostgreSQL de Addresses"""
from typing import List, Optional

from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.addresses.domain.entities.address import Address
from app.modules.addresses.domain.repositories.address_repository import AddressRepository
from app.modules.addresses.infrastructure.models import AddressModel


def _map_model_to_entity(model: AddressModel) -> Address:
    """Convierte AddressModel a Address entity"""
    return Address(
        id=model.id,
        user_id=model.user_id,
        street=model.street,
        external_number=model.external_number,
        internal_number=model.internal_number,
        colony=model.colony,
        municipality=model.municipality,
        state=model.state,
        zip_code=model.zip_code,
        created_at=model.created_at,
        updated_at=model.updated_at,
    )


class PgAddressRepository(AddressRepository):
    """Implementación PostgreSQL de AddressRepository"""
    
    def __init__(self, db: AsyncSession):
        self._db = db
    
    async def find_by_id(self, address_id: int) -> Optional[Address]:
        """Busca una dirección por ID"""
        stmt = select(AddressModel).where(AddressModel.id == address_id)
        result = await self._db.execute(stmt)
        model = result.scalar_one_or_none()
        
        return _map_model_to_entity(model) if model else None
    
    async def find_by_user_id(self, user_id: int) -> Optional[Address]:
        """Busca la dirección de un usuario"""
        stmt = (
            select(AddressModel)
            .where(AddressModel.user_id == user_id)
            .limit(1)
        )
        
        result = await self._db.execute(stmt)
        model = result.scalar_one_or_none()
        
        return _map_model_to_entity(model) if model else None
    
    async def find_all(self, limit: int = 50, offset: int = 0) -> List[Address]:
        """Lista todas las direcciones"""
        stmt = (
            select(AddressModel)
            .order_by(AddressModel.id)
            .limit(limit)
            .offset(offset)
        )
        
        result = await self._db.execute(stmt)
        models = result.scalars().all()
        
        return [_map_model_to_entity(m) for m in models]
    
    async def count(self) -> int:
        """Cuenta el total de direcciones"""
        stmt = select(func.count(AddressModel.id))
        result = await self._db.execute(stmt)
        return result.scalar() or 0
    
    async def create(self, address: Address) -> Address:
        """Crea una nueva dirección"""
        model = AddressModel(
            user_id=address.user_id,
            street=address.street,
            external_number=address.external_number,
            internal_number=address.internal_number,
            colony=address.colony,
            municipality=address.municipality,
            state=address.state,
            zip_code=address.zip_code,
        )
        
        self._db.add(model)
        await self._db.flush()
        await self._db.refresh(model)
        
        return _map_model_to_entity(model)
    
    async def update(self, address: Address) -> Address:
        """Actualiza una dirección existente"""
        stmt = select(AddressModel).where(AddressModel.id == address.id)
        result = await self._db.execute(stmt)
        model = result.scalar_one_or_none()
        
        if not model:
            raise ValueError(f"Address {address.id} not found")
        
        # Actualizar campos
        model.street = address.street
        model.external_number = address.external_number
        model.internal_number = address.internal_number
        model.colony = address.colony
        model.municipality = address.municipality
        model.state = address.state
        model.zip_code = address.zip_code
        
        await self._db.flush()
        await self._db.refresh(model)
        
        return _map_model_to_entity(model)
