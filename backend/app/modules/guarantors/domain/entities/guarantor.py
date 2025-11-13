"""Domain Entity: Guarantor"""
from dataclasses import dataclass
from datetime import datetime
from typing import Optional


@dataclass
class Guarantor:
    """Entidad Aval - Persona que avala a un cliente"""
    id: Optional[int]
    user_id: int
    full_name: str
    first_name: Optional[str]
    paternal_last_name: Optional[str]
    maternal_last_name: Optional[str]
    relationship: str
    phone_number: str
    curp: Optional[str]
    created_at: datetime
    updated_at: datetime
    
    def get_full_name_parts(self) -> dict:
        """Retorna las partes del nombre completo"""
        return {
            "first_name": self.first_name,
            "paternal_last_name": self.paternal_last_name,
            "maternal_last_name": self.maternal_last_name,
        }
    
    def has_curp(self) -> bool:
        """Verifica si tiene CURP registrado"""
        return self.curp is not None and len(self.curp) > 0
