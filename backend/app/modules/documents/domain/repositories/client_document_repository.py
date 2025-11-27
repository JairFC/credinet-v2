from abc import ABC, abstractmethod
from typing import List, Optional
from ..entities import ClientDocument

class ClientDocumentRepository(ABC):
    @abstractmethod
    async def find_by_id(self, document_id: int) -> Optional[ClientDocument]:
        pass
    
    @abstractmethod
    async def find_by_user(self, user_id: int) -> List[ClientDocument]:
        pass
    
    @abstractmethod
    async def find_all(self, limit: int = 50, offset: int = 0) -> List[ClientDocument]:
        pass
    
    @abstractmethod
    async def count(self) -> int:
        pass
    
    @abstractmethod
    async def create(self, document: ClientDocument) -> ClientDocument:
        pass
