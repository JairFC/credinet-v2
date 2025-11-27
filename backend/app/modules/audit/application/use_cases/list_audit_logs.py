"""Use Case: List Audit Logs"""
from typing import List

from ...domain.entities.audit_log import AuditLog
from ...domain.repositories.audit_log_repository import AuditLogRepository


class ListAuditLogsUseCase:
    """Caso de uso: Listar registros de auditoría"""
    
    def __init__(self, repository: AuditLogRepository):
        self.repository = repository
    
    async def execute(self, limit: int = 50, offset: int = 0) -> List[AuditLog]:
        """Lista registros de auditoría con paginación"""
        return await self.repository.find_all(limit, offset)
