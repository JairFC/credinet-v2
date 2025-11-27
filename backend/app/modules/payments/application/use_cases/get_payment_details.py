"""
Use Case: Get Payment Details
Obtiene detalles de un pago específico.
"""
from typing import Optional

from ...domain.repositories.payment_repository import PaymentRepository
from ...domain.entities.payment import Payment


class GetPaymentDetailsUseCase:
    """
    Caso de uso: Obtener detalles de un pago.
    """
    
    def __init__(self, repository: PaymentRepository):
        self.repository = repository
    
    async def execute(self, payment_id: int) -> Optional[Payment]:
        """
        Ejecuta la consulta.
        
        Args:
            payment_id: ID del pago
            
        Returns:
            Payment si existe, None si no
        """
        return await self.repository.find_by_id(payment_id)
