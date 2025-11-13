"""Use case: Create Guarantor"""
from datetime import datetime
from app.modules.guarantors.domain.entities.guarantor import Guarantor
from app.modules.guarantors.domain.repositories.guarantor_repository import GuarantorRepository


class CreateGuarantorUseCase:
    """Caso de uso: Crear aval/garante"""
    
    def __init__(self, repo: GuarantorRepository):
        self._repo = repo
    
    async def execute(
        self,
        user_id: int,
        full_name: str,
        first_name: str | None,
        paternal_last_name: str | None,
        maternal_last_name: str | None,
        relationship: str,
        phone_number: str,
        curp: str | None,
    ) -> Guarantor:
        """
        Crea un nuevo aval/garante para un usuario.
        
        Args:
            user_id: ID del usuario
            full_name: Nombre completo
            first_name: Nombre(s)
            paternal_last_name: Apellido paterno
            maternal_last_name: Apellido materno
            relationship: Relación con el cliente
            phone_number: Teléfono
            curp: CURP (opcional)
            
        Returns:
            Guarantor creado
        """
        now = datetime.now()
        
        guarantor = Guarantor(
            id=None,
            user_id=user_id,
            full_name=full_name,
            first_name=first_name,
            paternal_last_name=paternal_last_name,
            maternal_last_name=maternal_last_name,
            relationship=relationship,
            phone_number=phone_number,
            curp=curp,
            created_at=now,  # Temporal, será reemplazado por el valor de la BD
            updated_at=now,  # Temporal, será reemplazado por el valor de la BD
        )
        
        return await self._repo.create(guarantor)
