"""Use Case: List Associates"""
from typing import List

from ...domain.entities.associate import Associate
from ...domain.repositories.associate_repository import AssociateRepository


class ListAssociatesUseCase:
    """Caso de uso: Listar asociados"""
    
    def __init__(self, repository: AssociateRepository):
        self.repository = repository
    
    async def execute(
        self,
        limit: int = 50,
        offset: int = 0,
        active_only: bool = True
    ) -> List[Associate]:
        """Lista asociados con paginación"""
        return await self.repository.find_all(limit, offset, active_only)
