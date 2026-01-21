"""Modelo SQLAlchemy para cut_periods"""
from sqlalchemy import Column, Integer, Numeric, Date, DateTime, ForeignKey, String
from sqlalchemy.sql import func

from app.core.database import Base


class CutPeriodModel(Base):
    """Modelo SQLAlchemy: cut_periods"""
    __tablename__ = 'cut_periods'
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    cut_number = Column(Integer, nullable=False)
    cut_code = Column(String(10), nullable=True)  # Ej: Dec08-2025
    period_start_date = Column(Date, nullable=False)
    period_end_date = Column(Date, nullable=False)
    status_id = Column(Integer, nullable=False)
    total_payments_expected = Column(Numeric(12, 2), nullable=False, default=0)
    total_payments_received = Column(Numeric(12, 2), nullable=False, default=0)
    total_commission = Column(Numeric(12, 2), nullable=False, default=0)
    created_by = Column(Integer)
    closed_by = Column(Integer)
    created_at = Column(DateTime(timezone=True), server_default=func.current_timestamp())
    updated_at = Column(DateTime(timezone=True), server_default=func.current_timestamp(), onupdate=func.current_timestamp())
