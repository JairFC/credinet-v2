"""Domain Entity: Contract"""
from dataclasses import dataclass
from datetime import date, datetime
from typing import Optional


@dataclass
class Contract:
    """Entidad Contrato - Documento legal del préstamo"""
    id: Optional[int]
    loan_id: int
    file_path: Optional[str]
    start_date: date
    sign_date: Optional[date]
    document_number: str
    status_id: int
    created_at: datetime
    updated_at: datetime
    
    def is_signed(self) -> bool:
        """Verifica si el contrato está firmado"""
        return self.sign_date is not None
    
    def is_active(self) -> bool:
        """Verifica si el contrato está activo (status_id = 4)"""
        return self.status_id == 4
