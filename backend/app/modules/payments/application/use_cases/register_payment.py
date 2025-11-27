"""
Use Case: Register Payment
Registra un pago realizado por un cliente.
"""
from datetime import date
from decimal import Decimal
from typing import Optional

from ...domain.repositories.payment_repository import PaymentRepository
from ...domain.entities.payment import Payment
from ..dtos.payment_dto import RegisterPaymentDTO


class RegisterPaymentUseCase:
    """
    Caso de uso: Registrar un pago.
    
    Flujo:
    1. Valida que el pago existe
    2. Valida que está pendiente (no pagado completamente)
    3. Valida el monto
    4. Registra el pago
    5. Los triggers de DB liberan crédito automáticamente
    """
    
    def __init__(self, repository: PaymentRepository):
        self.repository = repository
    
    async def execute(
        self,
        payment_id: int,
        amount_paid: Decimal,
        payment_date: date,
        marked_by: int,
        notes: Optional[str] = None
    ) -> Payment:
        """
        Ejecuta el registro de pago.
        
        Args:
            payment_id: ID del pago
            amount_paid: Monto pagado
            payment_date: Fecha del pago
            marked_by: Usuario que registra
            notes: Notas adicionales
            
        Returns:
            Payment actualizado
            
        Raises:
            ValueError: Si el pago no existe o validaciones fallan
        """
        # 1. Buscar el pago
        payment = await self.repository.find_by_id(payment_id)
        if not payment:
            raise ValueError(f"Pago {payment_id} no encontrado")
        
        # 2. Validar que no esté completamente pagado
        if payment.is_paid():
            raise ValueError(
                f"Pago {payment_id} ya está completamente pagado "
                f"(amount_paid: {payment.amount_paid}, expected: {payment.expected_amount})"
            )
        
        # 3. Validar monto
        remaining = payment.get_remaining_amount()
        if amount_paid > remaining:
            raise ValueError(
                f"Monto pagado ({amount_paid}) excede el monto pendiente ({remaining})"
            )
        
        if amount_paid <= 0:
            raise ValueError("El monto pagado debe ser mayor a 0")
        
        # 4. Registrar pago
        # El repository actualizará amount_paid, status_id, y los triggers harán el resto
        updated_payment = await self.repository.register_payment(
            payment_id=payment_id,
            amount_paid=amount_paid,
            payment_date=payment_date,
            marked_by=marked_by,
            notes=notes,
        )
        
        return updated_payment
