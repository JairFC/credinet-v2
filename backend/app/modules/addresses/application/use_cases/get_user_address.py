"""Use Case: Get User Address"""
from typing import Optional

from ...domain.entities.address import Address
from ...domain.repositories.address_repository import AddressRepository


class GetUserAddressUseCase:
    """Caso de uso: Obtener dirección de un usuario"""
    
    def __init__(self, repository: AddressRepository):
        self.repository = repository
    
    async def execute(self, user_id: int) -> Optional[Address]:
        """Obtiene la dirección de un usuario"""
        return await self.repository.find_by_user_id(user_id)
