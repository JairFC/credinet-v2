"""Use Case: List Cut Periods"""
from typing import List

from ...domain.entities.cut_period import CutPeriod
from ...domain.repositories.cut_period_repository import CutPeriodRepository


class ListCutPeriodsUseCase:
    """Caso de uso: Listar periodos de corte"""
    
    def __init__(self, repository: CutPeriodRepository):
        self.repository = repository
    
    async def execute(self, limit: int = 50, offset: int = 0) -> List[CutPeriod]:
        """Lista periodos de corte con paginación"""
        return await self.repository.find_all(limit, offset)
