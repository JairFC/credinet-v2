"""
Entidad de Dominio: DebtPayment

Representa un pago realizado para liquidar deuda acumulada de un asociado.
"""
from datetime import date
from decimal import Decimal
from typing import Optional, List, Dict, Any


class DebtPayment:
    """
    Pago aplicado a deuda acumulada.
    
    La lógica FIFO se aplica automáticamente mediante trigger de base de datos,
    liquidando primero los items de deuda más antiguos.
    """
    
    def __init__(
        self,
        id: Optional[int],
        associate_profile_id: int,
        payment_amount: Decimal,
        payment_date: date,
        payment_method_id: int,
        payment_reference: Optional[str],
        registered_by: int,
        applied_breakdown_items: List[Dict[str, Any]],
        notes: Optional[str],
        created_at: Optional[date] = None,
        updated_at: Optional[date] = None
    ):
        self.id = id
        self.associate_profile_id = associate_profile_id
        self.payment_amount = payment_amount
        self.payment_date = payment_date
        self.payment_method_id = payment_method_id
        self.payment_reference = payment_reference
        self.registered_by = registered_by
        self.applied_breakdown_items = applied_breakdown_items  # JSONB con items liquidados
        self.notes = notes
        self.created_at = created_at
        self.updated_at = updated_at
    
    def __repr__(self):
        return (
            f"<DebtPayment(id={self.id}, "
            f"associate={self.associate_profile_id}, "
            f"amount={self.payment_amount}, "
            f"items_applied={len(self.applied_breakdown_items)})>"
        )
    
    @property
    def total_items_liquidated(self) -> int:
        """Cuenta cuántos items de deuda fueron liquidados completamente."""
        return sum(
            1 for item in self.applied_breakdown_items 
            if item.get('liquidated', False)
        )
    
    @property
    def total_items_partial(self) -> int:
        """Cuenta cuántos items fueron liquidados parcialmente."""
        return sum(
            1 for item in self.applied_breakdown_items 
            if not item.get('liquidated', False)
        )
