"""Repository Interface: BeneficiaryRepository"""
from abc import ABC, abstractmethod
from typing import List, Optional

from ..entities.beneficiary import Beneficiary


class BeneficiaryRepository(ABC):
    """Interface del repositorio de beneficiarios"""
    
    @abstractmethod
    async def find_by_id(self, beneficiary_id: int) -> Optional[Beneficiary]:
        """Busca un beneficiario por ID"""
        pass
    
    @abstractmethod
    async def find_by_user_id(self, user_id: int) -> List[Beneficiary]:
        """Busca todos los beneficiarios de un usuario"""
        pass
    
    @abstractmethod
    async def find_all(self, limit: int = 50, offset: int = 0) -> List[Beneficiary]:
        """Lista todos los beneficiarios"""
        pass
    
    @abstractmethod
    async def count(self) -> int:
        """Cuenta el total de beneficiarios"""
        pass
    
    @abstractmethod
    async def create(self, beneficiary: Beneficiary) -> Beneficiary:
        """Crea un nuevo beneficiario"""
        pass
