"""
Domain Entity: Associate
Representa un asociado con su perfil de crédito
"""
from dataclasses import dataclass
from datetime import datetime
from decimal import Decimal
from typing import Optional


@dataclass
class Associate:
    """
    Entidad Asociado.
    
    Los asociados son users que otorgan préstamos con su propio crédito.
    
    MODELO DE DEUDA:
    - pending_payments_total: Suma de pagos PENDING que el asociado debe cobrar/entregar
    - consolidated_debt: Deuda consolidada (statements cerrados + convenios - pagos)
    - available_credit: credit_limit - pending_payments_total - consolidated_debt
    """
    id: Optional[int]
    user_id: int
    level_id: int
    contact_person: Optional[str]
    contact_email: Optional[str]
    default_commission_rate: Decimal
    active: bool
    consecutive_full_credit_periods: int
    consecutive_on_time_payments: int
    clients_in_agreement: int
    last_level_evaluation_date: Optional[datetime]
    
    # Campos de crédito refactorizados
    pending_payments_total: Decimal  # Antes: credit_used
    credit_limit: Decimal
    available_credit: Decimal  # Antes: credit_available
    credit_last_updated: Optional[datetime]
    consolidated_debt: Decimal  # Antes: debt_balance
    
    created_at: datetime
    updated_at: datetime
    
    def get_credit_usage_percentage(self) -> float:
        """Calcula el porcentaje de crédito usado (pagos pendientes)"""
        if self.credit_limit == 0:
            return 0.0
        return float(self.pending_payments_total / self.credit_limit * 100)
    
    def has_available_credit(self, amount: Decimal) -> bool:
        """Verifica si tiene crédito disponible para un monto"""
        return self.available_credit >= amount
    
    def is_active(self) -> bool:
        """Verifica si el asociado está activo"""
        return self.active
