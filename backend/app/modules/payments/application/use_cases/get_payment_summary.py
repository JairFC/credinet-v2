"""
Use Case: Get Payment Summary
Obtiene resumen de pagos de un préstamo.
"""
from ...domain.repositories.payment_repository import PaymentRepository


class GetPaymentSummaryUseCase:
    """
    Caso de uso: Obtener resumen de pagos.
    """
    
    def __init__(self, repository: PaymentRepository):
        self.repository = repository
    
    async def execute(self, loan_id: int) -> dict:
        """
        Ejecuta la consulta del resumen.
        
        Args:
            loan_id: ID del préstamo
            
        Returns:
            Dict con resumen de pagos
        """
        return await self.repository.get_payment_summary(loan_id)
