from typing import List
from ...domain.entities import ClientDocument
from ...domain.repositories import ClientDocumentRepository

class GetUserDocumentsUseCase:
    def __init__(self, repository: ClientDocumentRepository):
        self.repository = repository
    
    async def execute(self, user_id: int) -> List[ClientDocument]:
        return await self.repository.find_by_user(user_id)
