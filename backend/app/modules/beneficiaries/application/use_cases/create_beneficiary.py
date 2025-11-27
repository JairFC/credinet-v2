"""Use case: Create Beneficiary"""
from datetime import datetime
from app.modules.beneficiaries.domain.entities.beneficiary import Beneficiary
from app.modules.beneficiaries.domain.repositories.beneficiary_repository import BeneficiaryRepository


class CreateBeneficiaryUseCase:
    """Caso de uso: Crear beneficiario"""
    
    def __init__(self, repo: BeneficiaryRepository):
        self._repo = repo
    
    async def execute(
        self,
        user_id: int,
        full_name: str,
        relationship: str,
        phone_number: str,
    ) -> Beneficiary:
        """
        Crea un nuevo beneficiario para un usuario.
        
        Args:
            user_id: ID del usuario
            full_name: Nombre completo
            relationship: Relación con el cliente
            phone_number: Teléfono
            
        Returns:
            Beneficiary creado
        """
        now = datetime.now()
        
        beneficiary = Beneficiary(
            id=None,
            user_id=user_id,
            full_name=full_name,
            relationship=relationship,
            phone_number=phone_number,
            created_at=now,  # Temporal, será reemplazado por el valor de la BD
            updated_at=now,  # Temporal, será reemplazado por el valor de la BD
        )
        
        return await self._repo.create(beneficiary)
