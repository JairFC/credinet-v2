"""Use Case: List Contracts"""
from typing import List

from ...domain.entities.contract import Contract
from ...domain.repositories.contract_repository import ContractRepository


class ListContractsUseCase:
    def __init__(self, repository: ContractRepository):
        self.repository = repository
    
    async def execute(self, limit: int = 50, offset: int = 0) -> List[Contract]:
        return await self.repository.find_all(limit, offset)
