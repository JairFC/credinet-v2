"""Repository Interface: CutPeriodRepository"""
from abc import ABC, abstractmethod
from typing import List, Optional

from ..entities.cut_period import CutPeriod


class CutPeriodRepository(ABC):
    """Interface del repositorio de periodos de corte"""
    
    @abstractmethod
    async def find_by_id(self, period_id: int) -> Optional[CutPeriod]:
        """Busca un periodo por ID"""
        pass
    
    @abstractmethod
    async def find_all(self, limit: int = 50, offset: int = 0) -> List[CutPeriod]:
        """Lista todos los periodos"""
        pass
    
    @abstractmethod
    async def find_active(self) -> Optional[CutPeriod]:
        """Busca el periodo activo actual"""
        pass
    
    @abstractmethod
    async def count(self) -> int:
        """Cuenta el total de periodos"""
        pass
