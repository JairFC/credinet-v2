"""
Repository Interface: AssociateRepository
"""
from abc import ABC, abstractmethod
from decimal import Decimal
from typing import List, Optional

from ..entities.associate import Associate


class AssociateRepository(ABC):
    """Interface del repositorio de asociados"""
    
    @abstractmethod
    async def find_by_id(self, associate_id: int) -> Optional[Associate]:
        """Busca un asociado por su profile ID"""
        pass
    
    @abstractmethod
    async def find_by_user_id(self, user_id: int) -> Optional[Associate]:
        """Busca un asociado por su user_id"""
        pass
    
    @abstractmethod
    async def find_all(
        self,
        limit: int = 50,
        offset: int = 0,
        active_only: bool = True
    ) -> List[Associate]:
        """Lista todos los asociados"""
        pass
    
    @abstractmethod
    async def count(self, active_only: bool = True) -> int:
        """Cuenta el total de asociados"""
        pass
    
    @abstractmethod
    async def update_credit(
        self,
        associate_id: int,
        credit_used: Decimal,
        credit_available: Decimal
    ) -> Associate:
        """Actualiza el crédito usado y disponible"""
        pass
