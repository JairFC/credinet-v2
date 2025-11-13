"""Modelo SQLAlchemy para contracts"""
from sqlalchemy import Column, Integer, String, Date, DateTime, ForeignKey
from sqlalchemy.sql import func

from app.core.database import Base


class ContractModel(Base):
    __tablename__ = 'contracts'
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    loan_id = Column(Integer, ForeignKey('loans.id'), nullable=False, unique=True)
    file_path = Column(String(500))
    start_date = Column(Date, nullable=False)
    sign_date = Column(Date)
    document_number = Column(String(50), nullable=False, unique=True)
    status_id = Column(Integer, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.current_timestamp())
    updated_at = Column(DateTime(timezone=True), server_default=func.current_timestamp(), onupdate=func.current_timestamp())
