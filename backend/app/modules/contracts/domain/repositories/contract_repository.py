"""Repository Interface: ContractRepository"""
from abc import ABC, abstractmethod
from typing import List, Optional

from ..entities.contract import Contract


class ContractRepository(ABC):
    """Interface del repositorio de contratos"""
    
    @abstractmethod
    async def find_by_id(self, contract_id: int) -> Optional[Contract]:
        pass
    
    @abstractmethod
    async def find_by_loan_id(self, loan_id: int) -> Optional[Contract]:
        pass
    
    @abstractmethod
    async def find_all(self, limit: int = 50, offset: int = 0) -> List[Contract]:
        pass
    
    @abstractmethod
    async def count(self) -> int:
        pass
    
    @abstractmethod
    async def create(self, contract: Contract) -> Contract:
        pass
