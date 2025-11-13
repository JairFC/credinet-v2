"""
Domain Entity: CutPeriod
Representa un periodo quincenal de corte
"""
from dataclasses import dataclass
from datetime import date, datetime
from decimal import Decimal
from typing import Optional


@dataclass
class CutPeriod:
    """
    Entidad Periodo de Corte.
    
    Los periodos de corte son ventanas quincenales para el cobro de pagos.
    """
    id: Optional[int]
    cut_number: int
    period_start_date: date
    period_end_date: date
    status_id: int
    total_payments_expected: Decimal
    total_payments_received: Decimal
    total_commission: Decimal
    created_by: Optional[int]
    closed_by: Optional[int]
    created_at: datetime
    updated_at: datetime
    
    def is_active(self) -> bool:
        """Verifica si el periodo está activo"""
        return self.status_id == 1  # Ajustar según catálogo
    
    def is_closed(self) -> bool:
        """Verifica si el periodo está cerrado"""
        return self.status_id == 5  # Ajustar según catálogo
    
    def get_collection_percentage(self) -> float:
        """Calcula el porcentaje de cobro"""
        if self.total_payments_expected == 0:
            return 0.0
        return float(self.total_payments_received / self.total_payments_expected * 100)
