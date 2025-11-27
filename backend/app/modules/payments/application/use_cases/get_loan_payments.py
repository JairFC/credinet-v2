"""
Use Case: Get Loan Payments
Obtiene todos los pagos de un préstamo.
"""
from typing import List

from ...domain.repositories.payment_repository import PaymentRepository
from ...domain.entities.payment import Payment


class GetLoanPaymentsUseCase:
    """
    Caso de uso: Obtener pagos de un préstamo.
    
    Retorna el cronograma completo ordenado por payment_number.
    """
    
    def __init__(self, repository: PaymentRepository):
        self.repository = repository
    
    async def execute(self, loan_id: int, only_pending: bool = False) -> List[Payment]:
        """
        Ejecuta la consulta de pagos.
        
        Args:
            loan_id: ID del préstamo
            only_pending: Si True, solo retorna pagos pendientes
            
        Returns:
            Lista de pagos
        """
        if only_pending:
            return await self.repository.find_pending_by_loan_id(loan_id)
        else:
            return await self.repository.find_by_loan_id(loan_id)
