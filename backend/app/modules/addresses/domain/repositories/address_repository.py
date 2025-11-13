"""Repository Interface: AddressRepository"""
from abc import ABC, abstractmethod
from typing import List, Optional

from ..entities.address import Address


class AddressRepository(ABC):
    """Interface del repositorio de direcciones"""
    
    @abstractmethod
    async def find_by_id(self, address_id: int) -> Optional[Address]:
        """Busca una dirección por ID"""
        pass
    
    @abstractmethod
    async def find_by_user_id(self, user_id: int) -> Optional[Address]:
        """Busca la dirección de un usuario (asume 1:1)"""
        pass
    
    @abstractmethod
    async def find_all(self, limit: int = 50, offset: int = 0) -> List[Address]:
        """Lista todas las direcciones"""
        pass
    
    @abstractmethod
    async def count(self) -> int:
        """Cuenta el total de direcciones"""
        pass
    
    @abstractmethod
    async def create(self, address: Address) -> Address:
        """Crea una nueva dirección"""
        pass
    
    @abstractmethod
    async def update(self, address: Address) -> Address:
        """Actualiza una dirección existente"""
        pass
