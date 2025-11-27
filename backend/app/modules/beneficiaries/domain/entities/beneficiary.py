"""Domain Entity: Beneficiary"""
from dataclasses import dataclass
from datetime import datetime
from typing import Optional


@dataclass
class Beneficiary:
    """Entidad Beneficiario - Persona beneficiaria en caso de fallecimiento del cliente"""
    id: Optional[int]
    user_id: int
    full_name: str
    relationship: str
    phone_number: str
    created_at: datetime
    updated_at: datetime
    
    def is_direct_family(self) -> bool:
        """Verifica si es familia directa"""
        direct_relationships = ["hijo", "hija", "esposo", "esposa", "padre", "madre"]
        return self.relationship.lower() in direct_relationships
