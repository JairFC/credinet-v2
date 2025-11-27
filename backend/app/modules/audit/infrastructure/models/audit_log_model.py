"""Modelo SQLAlchemy para audit_log"""
from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, Text
from sqlalchemy.dialects.postgresql import JSONB, INET
from sqlalchemy.sql import func

from app.core.database import Base


class AuditLogModel(Base):
    """Modelo SQLAlchemy: audit_log"""
    __tablename__ = 'audit_log'
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    table_name = Column(String(100), nullable=False)
    record_id = Column(Integer, nullable=False)
    operation = Column(String(20), nullable=False)  # INSERT, UPDATE, DELETE
    old_data = Column(JSONB)
    new_data = Column(JSONB)
    changed_by = Column(Integer, ForeignKey('users.id'))
    changed_at = Column(DateTime(timezone=True), server_default=func.current_timestamp())
    ip_address = Column(INET)
    user_agent = Column(Text)
