"""Use Case: List Guarantors"""
from typing import List

from ...domain.entities.guarantor import Guarantor
from ...domain.repositories.guarantor_repository import GuarantorRepository


class ListGuarantorsUseCase:
    """Caso de uso: Listar avales"""
    
    def __init__(self, repository: GuarantorRepository):
        self.repository = repository
    
    async def execute(self, limit: int = 50, offset: int = 0) -> List[Guarantor]:
        """Lista avales con paginación"""
        return await self.repository.find_all(limit, offset)
