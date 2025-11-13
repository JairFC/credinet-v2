from typing import List
from ...domain.entities import Agreement
from ...domain.repositories import AgreementRepository

class GetAssociateAgreementsUseCase:
    def __init__(self, repository: AgreementRepository):
        self.repository = repository
    
    async def execute(self, associate_profile_id: int) -> List[Agreement]:
        return await self.repository.find_by_associate(associate_profile_id)
