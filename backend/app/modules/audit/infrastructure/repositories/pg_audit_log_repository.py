"""Repositorio PostgreSQL de Audit Logs"""
from typing import List, Optional
from datetime import datetime

from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.audit.domain.entities.audit_log import AuditLog
from app.modules.audit.domain.repositories.audit_log_repository import AuditLogRepository
from app.modules.audit.infrastructure.models import AuditLogModel


def _map_model_to_entity(model: AuditLogModel) -> AuditLog:
    """Convierte AuditLogModel a AuditLog entity"""
    return AuditLog(
        id=model.id,
        table_name=model.table_name,
        record_id=model.record_id,
        operation=model.operation,
        old_data=model.old_data,
        new_data=model.new_data,
        changed_by=model.changed_by,
        changed_at=model.changed_at,
        ip_address=str(model.ip_address) if model.ip_address else None,
        user_agent=model.user_agent,
    )


class PgAuditLogRepository(AuditLogRepository):
    """Implementación PostgreSQL de AuditLogRepository"""
    
    def __init__(self, db: AsyncSession):
        self._db = db
    
    async def find_by_id(self, audit_id: int) -> Optional[AuditLog]:
        """Busca un registro de auditoría por ID"""
        stmt = select(AuditLogModel).where(AuditLogModel.id == audit_id)
        result = await self._db.execute(stmt)
        model = result.scalar_one_or_none()
        
        return _map_model_to_entity(model) if model else None
    
    async def find_by_table(self, table_name: str, limit: int = 50, offset: int = 0) -> List[AuditLog]:
        """Busca registros de auditoría por tabla"""
        stmt = (
            select(AuditLogModel)
            .where(AuditLogModel.table_name == table_name)
            .order_by(AuditLogModel.changed_at.desc())
            .limit(limit)
            .offset(offset)
        )
        
        result = await self._db.execute(stmt)
        models = result.scalars().all()
        
        return [_map_model_to_entity(m) for m in models]
    
    async def find_by_record(self, table_name: str, record_id: int) -> List[AuditLog]:
        """Busca todo el historial de un registro específico"""
        stmt = (
            select(AuditLogModel)
            .where(
                AuditLogModel.table_name == table_name,
                AuditLogModel.record_id == record_id
            )
            .order_by(AuditLogModel.changed_at.asc())
        )
        
        result = await self._db.execute(stmt)
        models = result.scalars().all()
        
        return [_map_model_to_entity(m) for m in models]
    
    async def find_by_user(self, user_id: int, limit: int = 50, offset: int = 0) -> List[AuditLog]:
        """Busca registros de auditoría por usuario"""
        stmt = (
            select(AuditLogModel)
            .where(AuditLogModel.changed_by == user_id)
            .order_by(AuditLogModel.changed_at.desc())
            .limit(limit)
            .offset(offset)
        )
        
        result = await self._db.execute(stmt)
        models = result.scalars().all()
        
        return [_map_model_to_entity(m) for m in models]
    
    async def find_by_date_range(
        self, 
        start_date: datetime, 
        end_date: datetime,
        limit: int = 50,
        offset: int = 0
    ) -> List[AuditLog]:
        """Busca registros de auditoría por rango de fechas"""
        stmt = (
            select(AuditLogModel)
            .where(
                AuditLogModel.changed_at >= start_date,
                AuditLogModel.changed_at <= end_date
            )
            .order_by(AuditLogModel.changed_at.desc())
            .limit(limit)
            .offset(offset)
        )
        
        result = await self._db.execute(stmt)
        models = result.scalars().all()
        
        return [_map_model_to_entity(m) for m in models]
    
    async def find_all(self, limit: int = 50, offset: int = 0) -> List[AuditLog]:
        """Lista todos los registros de auditoría"""
        stmt = (
            select(AuditLogModel)
            .order_by(AuditLogModel.changed_at.desc())
            .limit(limit)
            .offset(offset)
        )
        
        result = await self._db.execute(stmt)
        models = result.scalars().all()
        
        return [_map_model_to_entity(m) for m in models]
    
    async def count(self) -> int:
        """Cuenta el total de registros de auditoría"""
        stmt = select(func.count(AuditLogModel.id))
        result = await self._db.execute(stmt)
        return result.scalar() or 0
