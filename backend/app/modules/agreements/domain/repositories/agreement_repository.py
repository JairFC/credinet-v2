from abc import ABC, abstractmethod
from typing import List, Optional
from ..entities import Agreement

class AgreementRepository(ABC):
    @abstractmethod
    async def find_by_id(self, agreement_id: int) -> Optional[Agreement]:
        pass
    
    @abstractmethod
    async def find_by_associate(self, associate_profile_id: int) -> List[Agreement]:
        pass
    
    @abstractmethod
    async def find_all(self, limit: int = 50, offset: int = 0) -> List[Agreement]:
        pass
    
    @abstractmethod
    async def count(self) -> int:
        pass
    
    @abstractmethod
    async def create(self, agreement: Agreement) -> Agreement:
        pass
