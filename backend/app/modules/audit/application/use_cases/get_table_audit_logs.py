"""Use Case: Get Table Audit Logs"""
from typing import List

from ...domain.entities.audit_log import AuditLog
from ...domain.repositories.audit_log_repository import AuditLogRepository


class GetTableAuditLogsUseCase:
    """Caso de uso: Obtener auditoría de una tabla específica"""
    
    def __init__(self, repository: AuditLogRepository):
        self.repository = repository
    
    async def execute(self, table_name: str, limit: int = 50, offset: int = 0) -> List[AuditLog]:
        """Obtiene registros de auditoría de una tabla"""
        return await self.repository.find_by_table(table_name, limit, offset)
