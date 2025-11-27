"""
Modelo SQLAlchemy para la tabla payments.

Mapea la tabla payments de db/v2.0/modules/02_core_tables.sql
"""
from sqlalchemy import (
    Column,
    Integer,
    Numeric,
    Date,
    DateTime,
    Boolean,
    Text,
    ForeignKey,
    CheckConstraint,
    UniqueConstraint,
)
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from app.core.database import Base


class PaymentModel(Base):
    """
    Modelo SQLAlchemy: payments
    
    Representa el cronograma de pagos generado automáticamente cuando un préstamo es aprobado.
    Un registro por cada quincena del plazo.
    
    Relaciones:
    - N:1 con loans (loan_id)
    - N:1 con payment_statuses (status_id)
    - N:1 con cut_periods (cut_period_id)
    - N:1 con users (marked_by)
    """
    __tablename__ = 'payments'
    
    # Identificadores
    id = Column(Integer, primary_key=True, autoincrement=True)
    loan_id = Column(
        Integer,
        ForeignKey('loans.id', ondelete='CASCADE'),
        nullable=False,
        index=True,
        comment='Préstamo al que pertenece este pago'
    )
    
    # Desglose financiero (Sprint 6 - Migración 006)
    payment_number = Column(
        Integer,
        comment='Número de pago en el cronograma (1, 2, 3, ..., term_biweeks)'
    )
    expected_amount = Column(
        Numeric(12, 2),
        comment='Monto esperado del pago (biweekly_payment del préstamo)'
    )
    interest_amount = Column(
        Numeric(10, 2),
        comment='Porción de interés en este pago'
    )
    principal_amount = Column(
        Numeric(10, 2),
        comment='Porción de capital en este pago'
    )
    commission_amount = Column(
        Numeric(10, 2),
        comment='Comisión del asociado en este pago'
    )
    associate_payment = Column(
        Numeric(10, 2),
        comment='Pago neto del cliente (expected_amount - commission_amount)'
    )
    balance_remaining = Column(
        Numeric(12, 2),
        comment='Saldo pendiente después de este pago',
        index=True
    )
    
    # Montos
    amount_paid = Column(
        Numeric(12, 2),
        nullable=False,
        default=0,
        comment='Monto efectivamente pagado'
    )
    
    # Fechas
    payment_date = Column(
        Date,
        nullable=False,
        comment='Fecha real del pago'
    )
    payment_due_date = Column(
        Date,
        nullable=False,
        index=True,
        comment='Fecha esperada (día 15 o último día)'
    )
    
    # Estado
    is_late = Column(
        Boolean,
        nullable=False,
        default=False,
        index=True,
        comment='Indica si el pago está atrasado'
    )
    status_id = Column(
        Integer,
        # ForeignKey('payment_statuses.id'),  # Comentado hasta implementar PaymentStatusModel
        index=True,
        comment='Estado del pago (pendiente, pagado, parcial, etc.)'
    )
    
    # Periodo de corte
    cut_period_id = Column(
        Integer,
        # ForeignKey('cut_periods.id'),  # Comentado hasta implementar CutPeriodModel
        index=True,
        comment='Periodo quincenal al que pertenece este pago'
    )
    
    # Tracking de marcado manual (v2.0)
    marked_by = Column(
        Integer,
        ForeignKey('users.id'),
        comment='Usuario que marcó manualmente el estado del pago'
    )
    marked_at = Column(
        DateTime(timezone=True),
        comment='Cuándo se marcó manualmente'
    )
    marking_notes = Column(
        Text,
        comment='Notas del marcado manual'
    )
    
    # Timestamps
    created_at = Column(
        DateTime(timezone=True),
        server_default=func.current_timestamp(),
        nullable=False
    )
    updated_at = Column(
        DateTime(timezone=True),
        server_default=func.current_timestamp(),
        onupdate=func.current_timestamp(),
        nullable=False
    )
    
    # Constraints
    __table_args__ = (
        CheckConstraint('amount_paid >= 0', name='check_payments_amount_paid_non_negative'),
        CheckConstraint('payment_date <= payment_due_date', name='check_payments_dates_logical'),
        CheckConstraint('payment_number IS NULL OR payment_number > 0', name='check_payment_number_positive'),
        CheckConstraint('expected_amount IS NULL OR expected_amount > 0', name='check_expected_amount_positive'),
        CheckConstraint('interest_amount IS NULL OR interest_amount >= 0', name='check_interest_amount_non_negative'),
        CheckConstraint('principal_amount IS NULL OR principal_amount >= 0', name='check_principal_amount_non_negative'),
        CheckConstraint('commission_amount IS NULL OR commission_amount >= 0', name='check_commission_amount_non_negative'),
        CheckConstraint('associate_payment IS NULL OR associate_payment >= 0', name='check_associate_payment_non_negative'),
        CheckConstraint('balance_remaining IS NULL OR balance_remaining >= 0', name='check_balance_remaining_non_negative'),
        UniqueConstraint('loan_id', 'payment_number', name='payments_unique_loan_payment_number'),
    )
