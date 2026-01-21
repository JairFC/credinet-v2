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
    
    # === CAMPOS DE CRÉDITO REFACTORIZADOS ===
    # pending_payments_total: Suma de associate_payment de pagos PENDING
    # Representa lo que el asociado aún debe cobrar a clientes y entregar a CrediCuenta
    pending_payments_total = Column(Numeric(12, 2), nullable=False, default=0)
    
    credit_limit = Column(Numeric(12, 2), nullable=False, default=0)
    
    # available_credit: Columna computada = credit_limit - pending_payments_total - consolidated_debt
    available_credit = Column(Numeric(12, 2), Computed("(credit_limit - pending_payments_total - consolidated_debt)"), nullable=False)
    
    credit_last_updated = Column(DateTime(timezone=True))
    
    # consolidated_debt: Deuda consolidada (statements cerrados + convenios - pagos)
    # Deuda firme que el asociado debe a CrediCuenta
    consolidated_debt = Column(Numeric(12, 2), nullable=False, default=0)
    created_at = Column(DateTime(timezone=True), server_default=func.current_timestamp(), nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.current_timestamp(), onupdate=func.current_timestamp(), nullable=False)
