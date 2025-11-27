"""Use Case: Get Loan Contract"""
from typing import Optional

from ...domain.entities.contract import Contract
from ...domain.repositories.contract_repository import ContractRepository


class GetLoanContractUseCase:
    def __init__(self, repository: ContractRepository):
        self.repository = repository
    
    async def execute(self, loan_id: int) -> Optional[Contract]:
        return await self.repository.find_by_loan_id(loan_id)
