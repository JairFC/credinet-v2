"""
Domain Entity: Payment
Representa un pago individual en el cronograma de un préstamo.
"""
from dataclasses import dataclass
from datetime import date, datetime
from decimal import Decimal
from typing import Optional


@dataclass
class Payment:
    """
    Entidad de dominio que representa un pago quincenal de un préstamo.
    
    Esta entidad es inmutable y representa el estado puro de negocio,
    sin dependencias de infraestructura.
    """
    id: int
    loan_id: int
    payment_number: int
    expected_amount: Decimal
    amount_paid: Decimal
    interest_amount: Decimal
    principal_amount: Decimal
    commission_amount: Decimal
    associate_payment: Decimal
    balance_remaining: Decimal
    payment_date: date
    payment_due_date: date
    is_late: bool
    status_id: int
    cut_period_id: Optional[int]
    marked_by: Optional[int]
    marked_at: Optional[datetime]
    marking_notes: Optional[str]
    created_at: datetime
    updated_at: datetime
    
    # Relaciones (cargadas opcionalmente)
    status_name: Optional[str] = None
    loan_amount: Optional[Decimal] = None
    client_name: Optional[str] = None
    
    def is_paid(self) -> bool:
        """Verifica si el pago está completamente pagado"""
        return self.amount_paid >= self.expected_amount
    
    def is_pending(self) -> bool:
        """Verifica si el pago está pendiente"""
        return self.amount_paid < self.expected_amount
    
    def is_overdue(self, current_date: date = None) -> bool:
        """Verifica si el pago está vencido"""
        if current_date is None:
            current_date = date.today()
        return self.payment_due_date < current_date and self.is_pending()
    
    def get_remaining_amount(self) -> Decimal:
        """Calcula el monto pendiente por pagar"""
        return max(Decimal('0'), self.expected_amount - self.amount_paid)
    
    def is_first_payment(self) -> bool:
        """Verifica si es el primer pago del préstamo"""
        return self.payment_number == 1
    
    def is_final_payment(self) -> bool:
        """Verifica si es el último pago (saldo restante = 0)"""
        return self.balance_remaining == Decimal('0')
