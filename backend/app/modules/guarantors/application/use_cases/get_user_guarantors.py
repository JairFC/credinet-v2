"""Use Case: Get User Guarantors"""
from typing import List

from ...domain.entities.guarantor import Guarantor
from ...domain.repositories.guarantor_repository import GuarantorRepository


class GetUserGuarantorsUseCase:
    """Caso de uso: Obtener avales de un usuario"""
    
    def __init__(self, repository: GuarantorRepository):
        self.repository = repository
    
    async def execute(self, user_id: int) -> List[Guarantor]:
        """Obtiene todos los avales de un usuario"""
        return await self.repository.find_by_user_id(user_id)
