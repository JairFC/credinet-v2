"""
Modelo SQLAlchemy para associate_profiles
"""
from sqlalchemy import (
    Computed,
    Column,
    Integer,
    Numeric,
    String,
    Boolean,
    DateTime,
    ForeignKey,
)
from sqlalchemy.sql import func

from app.core.database import Base


class AssociateProfileModel(Base):
    """Modelo SQLAlchemy: associate_profiles"""
    __tablename__ = 'associate_profiles'
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey('users.id', ondelete='CASCADE'), nullable=False, unique=True)
    level_id = Column(Integer, nullable=False)
    contact_person = Column(String(255))
    contact_email = Column(String(255))
    default_commission_rate = Column(Numeric(5, 2), nullable=False)
    active = Column(Boolean, nullable=False, default=True)
    consecutive_full_credit_periods = Column(Integer, default=0)
    consecutive_on_time_payments = Column(Integer, default=0)
    clients_in_agreement = Column(Integer, default=0)
    last_level_evaluation_date = Column(DateTime(timezone=True))
    credit_used = Column(Numeric(12, 2), nullable=False, default=0)
    credit_limit = Column(Numeric(12, 2), nullable=False, default=0)
    credit_available = Column(Numeric(12, 2), Computed("(credit_limit - credit_used)"), nullable=False)
    credit_last_updated = Column(DateTime(timezone=True))
    debt_balance = Column(Numeric(12, 2), nullable=False, default=0)
    created_at = Column(DateTime(timezone=True), server_default=func.current_timestamp(), nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.current_timestamp(), onupdate=func.current_timestamp(), nullable=False)
