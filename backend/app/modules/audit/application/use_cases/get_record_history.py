"""Use Case: Get Record History"""
from typing import List

from ...domain.entities.audit_log import AuditLog
from ...domain.repositories.audit_log_repository import AuditLogRepository


class GetRecordHistoryUseCase:
    """Caso de uso: Obtener historial completo de un registro"""
    
    def __init__(self, repository: AuditLogRepository):
        self.repository = repository
    
    async def execute(self, table_name: str, record_id: int) -> List[AuditLog]:
        """Obtiene todo el historial de cambios de un registro"""
        return await self.repository.find_by_record(table_name, record_id)
