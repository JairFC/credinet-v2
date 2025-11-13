"""Repository Interface: GuarantorRepository"""
from abc import ABC, abstractmethod
from typing import List, Optional

from ..entities.guarantor import Guarantor


class GuarantorRepository(ABC):
    """Interface del repositorio de avales"""
    
    @abstractmethod
    async def find_by_id(self, guarantor_id: int) -> Optional[Guarantor]:
        """Busca un aval por ID"""
        pass
    
    @abstractmethod
    async def find_by_user_id(self, user_id: int) -> List[Guarantor]:
        """Busca todos los avales de un usuario"""
        pass
    
    @abstractmethod
    async def find_all(self, limit: int = 50, offset: int = 0) -> List[Guarantor]:
        """Lista todos los avales"""
        pass
    
    @abstractmethod
    async def count(self) -> int:
        """Cuenta el total de avales"""
        pass
    
    @abstractmethod
    async def create(self, guarantor: Guarantor) -> Guarantor:
        """Crea un nuevo aval"""
        pass
