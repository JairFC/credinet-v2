"""
Repository Interface: ClientRepository
"""
from abc import ABC, abstractmethod
from typing import List, Optional

from ..entities.client import Client


class ClientRepository(ABC):
    """Interface del repositorio de clientes"""
    
    @abstractmethod
    async def find_by_id(self, client_id: int) -> Optional[Client]:
        """Busca un cliente por ID"""
        pass
    
    @abstractmethod
    async def find_all(
        self,
        limit: int = 50,
        offset: int = 0,
        active_only: bool = True
    ) -> List[Client]:
        """Lista todos los clientes con paginación"""
        pass
    
    @abstractmethod
    async def count(self, active_only: bool = True) -> int:
        """Cuenta el total de clientes"""
        pass
    
    @abstractmethod
    async def find_by_email(self, email: str) -> Optional[Client]:
        """Busca un cliente por email"""
        pass
    
    @abstractmethod
    async def create(self, client: Client, password_hash: str) -> Client:
        """Crea un nuevo cliente"""
        pass
