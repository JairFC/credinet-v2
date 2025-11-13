"""Use Case: Get User Beneficiaries"""
from typing import List

from ...domain.entities.beneficiary import Beneficiary
from ...domain.repositories.beneficiary_repository import BeneficiaryRepository


class GetUserBeneficiariesUseCase:
    """Caso de uso: Obtener beneficiarios de un usuario"""
    
    def __init__(self, repository: BeneficiaryRepository):
        self.repository = repository
    
    async def execute(self, user_id: int) -> List[Beneficiary]:
        """Obtiene todos los beneficiarios de un usuario"""
        return await self.repository.find_by_user_id(user_id)
