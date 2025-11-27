"""Use Case: List Clients"""
from typing import List

from ...domain.entities.client import Client
from ...domain.repositories.client_repository import ClientRepository


class ListClientsUseCase:
    """Caso de uso: Listar clientes"""
    
    def __init__(self, repository: ClientRepository):
        self.repository = repository
    
    async def execute(
        self,
        limit: int = 50,
        offset: int = 0,
        active_only: bool = True
    ) -> List[Client]:
        """
        Lista clientes con paginación.
        
        Args:
            limit: Máximo de registros
            offset: Desplazamiento
            active_only: Solo clientes activos
            
        Returns:
            Lista de clientes
        """
        return await self.repository.find_all(limit, offset, active_only)
