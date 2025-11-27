"""Application DTOs - Audit"""
from datetime import datetime
from typing import Optional, Dict, Any
from pydantic import BaseModel


class AuditLogResponseDTO(BaseModel):
    """DTO de respuesta con info del registro de auditoría"""
    id: int
    table_name: str
    record_id: int
    operation: str
    old_data: Optional[Dict[str, Any]] = None
    new_data: Optional[Dict[str, Any]] = None
    changed_by: Optional[int] = None
    changed_at: datetime
    ip_address: Optional[str] = None
    user_agent: Optional[str] = None
    
    # Campos calculados
    changed_fields: Optional[list[str]] = None
    
    class Config:
        from_attributes = True


class AuditLogListItemDTO(BaseModel):
    """DTO simplificado para listar registros de auditoría"""
    id: int
    table_name: str
    record_id: int
    operation: str
    changed_by: Optional[int] = None
    changed_at: datetime
    
    class Config:
        from_attributes = True


class PaginatedAuditLogsDTO(BaseModel):
    """DTO para respuesta paginada"""
    items: list[AuditLogListItemDTO]
    total: int
    limit: int
    offset: int


class AuditStatsDTO(BaseModel):
    """DTO con estadísticas de auditoría"""
    total_records: int
    operations_by_type: Dict[str, int]
    tables_audited: list[str]
    most_active_users: list[Dict[str, Any]]
