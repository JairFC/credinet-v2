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
    credit_used: Decimal
    credit_limit: Decimal
    credit_available: Decimal
    credit_last_updated: Optional[datetime]
    debt_balance: Decimal
    created_at: datetime
    updated_at: datetime
    
    def get_credit_usage_percentage(self) -> float:
        """Calcula el porcentaje de crédito usado"""
        if self.credit_limit == 0:
            return 0.0
        return float(self.credit_used / self.credit_limit * 100)
    
    def has_available_credit(self, amount: Decimal) -> bool:
        """Verifica si tiene crédito disponible para un monto"""
        return self.credit_available >= amount
    
    def is_active(self) -> bool:
        """Verifica si el asociado está activo"""
        return self.active
