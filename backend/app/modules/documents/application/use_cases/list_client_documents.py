from typing import List
from ...domain.entities import ClientDocument
from ...domain.repositories import ClientDocumentRepository

class ListClientDocumentsUseCase:
    def __init__(self, repository: ClientDocumentRepository):
        self.repository = repository
    
    async def execute(self, limit: int = 50, offset: int = 0) -> tuple[List[ClientDocument], int]:
        documents = await self.repository.find_all(limit, offset)
        total = await self.repository.count()
        return documents, total
