"""
Modelos de SQLAlchemy para debt_payments.
"""
from sqlalchemy import Column, Integer, String, Numeric, Date, Text, ForeignKey, TIMESTAMP
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from app.core.database import Base


class DebtPaymentModel(Base):
    """
    Modelo de pago de deuda.
    
    Representa un abono realizado para liquidar deuda acumulada.
    El trigger apply_debt_payment_fifo se encarga de:
    - Aplicar FIFO a associate_debt_breakdown
    - Actualizar consolidated_debt en associate_profiles
    - Llenar applied_breakdown_items con el detalle de items liquidados
    """
    
    __tablename__ = "associate_debt_payments"
    
    id = Column(Integer, primary_key=True, index=True)
    associate_profile_id = Column(Integer, ForeignKey("associate_profiles.id", ondelete="CASCADE"), nullable=False, index=True)
    payment_amount = Column(Numeric(12, 2), nullable=False)
    payment_date = Column(Date, nullable=False, index=True)
    payment_method_id = Column(Integer, ForeignKey("payment_methods.id"), nullable=False, index=True)
    payment_reference = Column(String(100), nullable=True)
    registered_by = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    applied_breakdown_items = Column(JSONB, nullable=False, default=list, server_default='[]')
    notes = Column(Text, nullable=True)
    created_at = Column(TIMESTAMP(timezone=True), server_default=func.now())
    updated_at = Column(TIMESTAMP(timezone=True), server_default=func.now(), onupdate=func.now())
    
    # Relationships (sin back_populates para evitar dependencias circulares)
    payment_method = relationship("PaymentMethodModel")
    registered_by_user = relationship("UserModel", foreign_keys=[registered_by])
    
    def __repr__(self):
        return f"<DebtPaymentModel(id={self.id}, associate={self.associate_profile_id}, amount={self.payment_amount})>"
