from typing import List
from ...domain.entities import Agreement
from ...domain.repositories import AgreementRepository

class ListAgreementsUseCase:
    def __init__(self, repository: AgreementRepository):
        self.repository = repository
    
    async def execute(self, limit: int = 50, offset: int = 0) -> tuple[List[Agreement], int]:
        agreements = await self.repository.find_all(limit, offset)
        total = await self.repository.count()
        return agreements, total
