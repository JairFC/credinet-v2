"""Domain Entity: AuditLog"""
from dataclasses import dataclass
from datetime import datetime
from typing import Optional, Dict, Any


@dataclass
class AuditLog:
    """Entidad Registro de Auditoría - Historial de cambios en el sistema"""
    id: Optional[int]
    table_name: str
    record_id: int
    operation: str  # INSERT, UPDATE, DELETE
    old_data: Optional[Dict[str, Any]]
    new_data: Optional[Dict[str, Any]]
    changed_by: Optional[int]
    changed_at: datetime
    ip_address: Optional[str]
    user_agent: Optional[str]
    
    def is_insert(self) -> bool:
        """Verifica si es una operación de inserción"""
        return self.operation.upper() == 'INSERT'
    
    def is_update(self) -> bool:
        """Verifica si es una operación de actualización"""
        return self.operation.upper() == 'UPDATE'
    
    def is_delete(self) -> bool:
        """Verifica si es una operación de eliminación"""
        return self.operation.upper() == 'DELETE'
    
    def get_changed_fields(self) -> list[str]:
        """Retorna lista de campos que cambiaron en UPDATE"""
        if not self.is_update() or not self.old_data or not self.new_data:
            return []
        
        changed = []
        for key in self.new_data.keys():
            if key in self.old_data and self.old_data[key] != self.new_data[key]:
                changed.append(key)
        
        return changed
