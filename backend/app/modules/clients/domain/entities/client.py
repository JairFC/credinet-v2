"""
Domain Entity: Client
Representa un cliente del sistema (user con role_id específico)
"""
from dataclasses import dataclass
from datetime import date, datetime
from typing import Optional


@dataclass
class Client:
    """
    Entidad Cliente (User filtrado por role).
    
    Los clientes son users que solicitan préstamos.
    """
    id: Optional[int]
    username: str
    first_name: str
    last_name: str
    email: str
    phone_number: Optional[str]
    birth_date: Optional[date]
    curp: Optional[str]
    profile_picture_url: Optional[str]
    active: bool
    created_at: datetime
    updated_at: datetime
    
    def get_full_name(self) -> str:
        """Retorna el nombre completo del cliente"""
        return f"{self.first_name} {self.last_name}"
    
    def is_active(self) -> bool:
        """Verifica si el cliente está activo"""
        return self.active
