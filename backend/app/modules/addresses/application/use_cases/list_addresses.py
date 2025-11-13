"""Use Case: List Addresses"""
from typing import List

from ...domain.entities.address import Address
from ...domain.repositories.address_repository import AddressRepository


class ListAddressesUseCase:
    """Caso de uso: Listar direcciones"""
    
    def __init__(self, repository: AddressRepository):
        self.repository = repository
    
    async def execute(self, limit: int = 50, offset: int = 0) -> List[Address]:
        """Lista direcciones con paginación"""
        return await self.repository.find_all(limit, offset)
