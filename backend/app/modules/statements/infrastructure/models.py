"""SQLAlchemy model for statements."""

from sqlalchemy import (
    Column,
    Integer,
    String,
    DECIMAL,
    Date,
    TIMESTAMP,
    ForeignKey,
    Boolean,
    CheckConstraint
)
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from app.core.database import Base


class StatementModel(Base):
    """
    SQLAlchemy model for associate_payment_statements table.
    
    Maps to the real database structure.
    """
    
    __tablename__ = "associate_payment_statements"
    
    id = Column(Integer, primary_key=True, index=True)
    statement_number = Column(String(50), nullable=False, index=True)
    
    # Relationships
    user_id = Column(
        Integer,
        ForeignKey("users.id"),
        nullable=False,
        index=True
    )
    cut_period_id = Column(
        Integer,
        ForeignKey("cut_periods.id"),
        nullable=False,
        index=True
    )
    
    # Statistics
    total_payments_count = Column(Integer, nullable=False, default=0)
    total_amount_collected = Column(DECIMAL(12, 2), nullable=False, default=0.00)
    total_to_credicuenta = Column(DECIMAL(12, 2), nullable=False, default=0.00)  # Lo que debe pagar a CrediCuenta
    commission_earned = Column(DECIMAL(12, 2), nullable=False, default=0.00)  # Comisión ganada por el asociado
    commission_rate_applied = Column(DECIMAL(5, 2), nullable=False)
    
    # Status
    status_id = Column(
        Integer,
        ForeignKey("statement_statuses.id"),
        nullable=False,
        index=True
    )
    
    # Dates
    generated_date = Column(Date, nullable=False)
    sent_date = Column(Date, nullable=True)
    due_date = Column(Date, nullable=False)
    paid_date = Column(Date, nullable=True)
    
    # Payment information
    paid_amount = Column(DECIMAL(12, 2), nullable=True)
    payment_method_id = Column(
        Integer,
        ForeignKey("payment_methods.id"),
        nullable=True
    )
    payment_reference = Column(String(100), nullable=True)
    
    # Late fees
    late_fee_amount = Column(DECIMAL(12, 2), nullable=False, default=0.00)
    late_fee_applied = Column(Boolean, nullable=False, default=False)
    
    # Audit
    created_at = Column(
        TIMESTAMP(timezone=True),
        server_default=func.current_timestamp(),
        nullable=False
    )
    updated_at = Column(
        TIMESTAMP(timezone=True),
        server_default=func.current_timestamp(),
        onupdate=func.current_timestamp(),
        nullable=False
    )
    
    # Relationships (for eager loading)
    associate = relationship("UserModel", foreign_keys=[user_id])
    cut_period = relationship("CutPeriodModel", foreign_keys=[cut_period_id])
    status = relationship("StatementStatusModel", foreign_keys=[status_id])
    payment_method = relationship("PaymentMethodModel", foreign_keys=[payment_method_id])
    
    # Table constraints
    __table_args__ = (
        CheckConstraint(
            "total_payments_count >= 0 AND "
            "total_amount_collected >= 0 AND "
            "total_to_credicuenta >= 0 AND "
            "commission_earned >= 0 AND "
            "late_fee_amount >= 0",
            name="check_statements_totals_non_negative"
        ),
    )
