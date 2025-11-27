"""Repository Interface: AuditLogRepository"""
from abc import ABC, abstractmethod
from typing import List, Optional
from datetime import datetime

from ..entities.audit_log import AuditLog


class AuditLogRepository(ABC):
    """Interface del repositorio de audit logs"""
    
    @abstractmethod
    async def find_by_id(self, audit_id: int) -> Optional[AuditLog]:
        """Busca un registro de auditoría por ID"""
        pass
    
    @abstractmethod
    async def find_by_table(self, table_name: str, limit: int = 50, offset: int = 0) -> List[AuditLog]:
        """Busca registros de auditoría por tabla"""
        pass
    
    @abstractmethod
    async def find_by_record(self, table_name: str, record_id: int) -> List[AuditLog]:
        """Busca todo el historial de un registro específico"""
        pass
    
    @abstractmethod
    async def find_by_user(self, user_id: int, limit: int = 50, offset: int = 0) -> List[AuditLog]:
        """Busca registros de auditoría por usuario"""
        pass
    
    @abstractmethod
    async def find_by_date_range(
        self, 
        start_date: datetime, 
        end_date: datetime,
        limit: int = 50,
        offset: int = 0
    ) -> List[AuditLog]:
        """Busca registros de auditoría por rango de fechas"""
        pass
    
    @abstractmethod
    async def find_all(self, limit: int = 50, offset: int = 0) -> List[AuditLog]:
        """Lista todos los registros de auditoría"""
        pass
    
    @abstractmethod
    async def count(self) -> int:
        """Cuenta el total de registros de auditoría"""
        pass
