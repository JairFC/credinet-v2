"""Use case: Create Address"""
from datetime import datetime
from app.modules.addresses.domain.entities.address import Address
from app.modules.addresses.domain.repositories.address_repository import AddressRepository


class CreateAddressUseCase:
    """Caso de uso: Crear dirección"""
    
    def __init__(self, repo: AddressRepository):
        self._repo = repo
    
    async def execute(
        self,
        user_id: int,
        street: str,
        external_number: str,
        internal_number: str | None,
        colony: str,
        municipality: str,
        state: str,
        zip_code: str,
    ) -> Address:
        """
        Crea una nueva dirección para un usuario.
        
        Args:
            user_id: ID del usuario
            street: Calle
            external_number: Número exterior
            internal_number: Número interior (opcional)
            colony: Colonia
            municipality: Municipio
            state: Estado
            zip_code: Código postal
            
        Returns:
            Address creada
        """
        # El repositorio manejará created_at y updated_at
        address = Address(
            id=None,
            user_id=user_id,
            street=street,
            external_number=external_number,
            internal_number=internal_number,
            colony=colony,
            municipality=municipality,
            state=state,
            zip_code=zip_code,
            created_at=datetime.now(),  # Temporal, el repo lo reemplaza
            updated_at=datetime.now(),  # Temporal, el repo lo reemplaza
        )
        
        return await self._repo.create(address)
