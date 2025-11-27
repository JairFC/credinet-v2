"""Use Case: Get Associate Credit Summary"""
from typing import Optional

from ...domain.entities.associate import Associate
from ...domain.repositories.associate_repository import AssociateRepository


class GetAssociateCreditUseCase:
    """Caso de uso: Obtener resumen de crédito de un asociado"""
    
    def __init__(self, repository: AssociateRepository):
        self.repository = repository
    
    async def execute(self, user_id: int) -> Optional[Associate]:
        """Obtiene el perfil de crédito de un asociado por user_id"""
        return await self.repository.find_by_user_id(user_id)
