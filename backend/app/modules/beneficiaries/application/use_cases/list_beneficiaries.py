"""Use Case: List Beneficiaries"""
from typing import List

from ...domain.entities.beneficiary import Beneficiary
from ...domain.repositories.beneficiary_repository import BeneficiaryRepository


class ListBeneficiariesUseCase:
    """Caso de uso: Listar beneficiarios"""
    
    def __init__(self, repository: BeneficiaryRepository):
        self.repository = repository
    
    async def execute(self, limit: int = 50, offset: int = 0) -> List[Beneficiary]:
        """Lista beneficiarios con paginación"""
        return await self.repository.find_all(limit, offset)
