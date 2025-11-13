"""Use Case: Get Active Cut Period"""
from typing import Optional

from ...domain.entities.cut_period import CutPeriod
from ...domain.repositories.cut_period_repository import CutPeriodRepository


class GetActiveCutPeriodUseCase:
    """Caso de uso: Obtener periodo de corte activo"""
    
    def __init__(self, repository: CutPeriodRepository):
        self.repository = repository
    
    async def execute(self) -> Optional[CutPeriod]:
        """Obtiene el periodo de corte activo actual"""
        return await self.repository.find_active()
