"""Use Case: Get Client Details"""
from typing import Optional

from ...domain.entities.client import Client
from ...domain.repositories.client_repository import ClientRepository


class GetClientDetailsUseCase:
    """Caso de uso: Obtener detalle de un cliente"""
    
    def __init__(self, repository: ClientRepository):
        self.repository = repository
    
    async def execute(self, client_id: int) -> Optional[Client]:
        """
        Obtiene el detalle de un cliente.
        
        Args:
            client_id: ID del cliente
            
        Returns:
            Client si existe, None si no
        """
        return await self.repository.find_by_id(client_id)
