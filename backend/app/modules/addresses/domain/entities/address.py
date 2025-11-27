"""Domain Entity: Address"""
from dataclasses import dataclass
from datetime import datetime
from typing import Optional


@dataclass
class Address:
    """Entidad Dirección - Dirección de un usuario"""
    id: Optional[int]
    user_id: int
    street: str
    external_number: str
    internal_number: Optional[str]
    colony: str
    municipality: str
    state: str
    zip_code: str
    created_at: datetime
    updated_at: datetime
    
    def get_full_address(self) -> str:
        """Retorna la dirección completa formateada"""
        parts = [
            f"{self.street} {self.external_number}",
        ]
        if self.internal_number:
            parts[0] += f" Int. {self.internal_number}"
        
        parts.extend([
            f"Col. {self.colony}",
            self.municipality,
            self.state,
            f"C.P. {self.zip_code}"
        ])
        
        return ", ".join(parts)
    
    def is_complete(self) -> bool:
        """Verifica si la dirección está completa"""
        required_fields = [
            self.street,
            self.external_number,
            self.colony,
            self.municipality,
            self.state,
            self.zip_code
        ]
        return all(field and len(str(field).strip()) > 0 for field in required_fields)
