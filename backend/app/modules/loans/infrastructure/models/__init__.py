"""
Modelos SQLAlchemy para el módulo de préstamos.

Mapean directamente a las tablas de la base de datos.
"""
from sqlalchemy import (
    Column,
    Integer,
    Numeric,
    String,
    Text,
    DateTime,
    ForeignKey,
    Index,
    CheckConstraint,
)
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from app.core.database import Base


class LoanModel(Base):
    """
    Modelo SQLAlchemy: loans
    
    Mapea la tabla loans de db/v2.0/modules/02_core_tables.sql
    
    Relaciones:
    - N:1 con users (user_id) → Cliente
    - N:1 con users (associate_user_id) → Asociado
    - N:1 con loan_statuses (status_id) → Estado
    - 1:1 con contracts (contract_id) → Contrato
    - 1:N con payments (loan_id) → Cronograma de pagos
    """
    __tablename__ = 'loans'
    
    # =============================================================================
    # COLUMNAS
    # =============================================================================
    
    # Identificadores
    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(
        Integer,
        ForeignKey('users.id', ondelete='CASCADE'),
        nullable=False,
        comment='Cliente dueño del préstamo'
    )
    associate_user_id = Column(
        Integer,
        ForeignKey('users.id'),
        nullable=True,
        comment='Asociado gestor (puede ser NULL si es admin directo)'
    )
    
    # Datos financieros
    amount = Column(
        Numeric(12, 2),
        nullable=False,
        comment='Monto del préstamo (SIN intereses)'
    )
    interest_rate = Column(
        Numeric(5, 2),
        nullable=False,
        comment='Tasa de interés en porcentaje (0-100)'
    )
    commission_rate = Column(
        Numeric(5, 2),
        nullable=False,
        server_default='0.0',
        comment='Comisión del asociado en porcentaje (0-100)'
    )
    term_biweeks = Column(
        Integer,
        nullable=False,
        comment='Plazo en quincenas (1 quincena = 15 días, rango: 1-52)'
    )
    profile_code = Column(
        String(50),
        ForeignKey('rate_profiles.code', ondelete='SET NULL'),
        nullable=True,
        comment='Código del perfil de tasa usado para calcular el préstamo'
    )
    
    # Campos calculados (generados por calculate_loan_payment())
    biweekly_payment = Column(
        Numeric(12, 2),
        nullable=True,
        comment='Pago quincenal calculado (capital + interés)'
    )
    total_payment = Column(
        Numeric(12, 2),
        nullable=True,
        comment='Monto total que pagará el cliente (biweekly_payment * term_biweeks)'
    )
    total_interest = Column(
        Numeric(12, 2),
        nullable=True,
        comment='Interés total del préstamo (total_payment - amount)'
    )
    total_commission = Column(
        Numeric(12, 2),
        nullable=True,
        comment='Comisión total acumulada (commission_per_payment * term_biweeks)'
    )
    commission_per_payment = Column(
        Numeric(10, 2),
        nullable=True,
        comment='Comisión por pago quincenal'
    )
    associate_payment = Column(
        Numeric(10, 2),
        nullable=True,
        comment='Pago neto al asociado por periodo (biweekly_payment - commission_per_payment)'
    )
    
    # Estado y relaciones
    status_id = Column(
        Integer,
        ForeignKey('loan_statuses.id'),
        nullable=False,
        comment='Estado actual del préstamo'
    )
    contract_id = Column(
        Integer,
        nullable=True,
        comment='Contrato generado (se crea al aprobar). FK exists in DB but not in ORM until ContractModel is implemented'
    )
    
    # Tracking de aprobación
    approved_at = Column(
        DateTime(timezone=True),
        nullable=True,
        comment='Fecha/hora de aprobación (seteado por trigger)'
    )
    approved_by = Column(
        Integer,
        ForeignKey('users.id'),
        nullable=True,
        comment='Usuario que aprobó (típicamente admin)'
    )
    rejected_at = Column(
        DateTime(timezone=True),
        nullable=True,
        comment='Fecha/hora de rechazo (seteado por trigger)'
    )
    rejected_by = Column(
        Integer,
        ForeignKey('users.id'),
        nullable=True,
        comment='Usuario que rechazó'
    )
    rejection_reason = Column(
        Text,
        nullable=True,
        comment='Motivo del rechazo (obligatorio si rejected_at IS NOT NULL)'
    )
    notes = Column(
        Text,
        nullable=True,
        comment='Notas generales del préstamo'
    )
    
    # Auditoría
    created_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
        comment='Fecha de creación (inmutable)'
    )
    updated_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
        comment='Última modificación (auto-actualizado por trigger)'
    )
    
    # =============================================================================
    # RELATIONSHIPS
    # =============================================================================
    
    # Cliente (usuario dueño del préstamo)
    client = relationship(
        'UserModel',
        foreign_keys=[user_id],
        backref='loans_as_client'
    )
    
    # Asociado (gestor de la cartera)
    associate = relationship(
        'UserModel',
        foreign_keys=[associate_user_id],
        backref='loans_as_associate'
    )
    
    # Estado del préstamo (catálogo)
    status = relationship(
        'LoanStatusModel',
        foreign_keys=[status_id],
        backref='loans'
    )
    
    # Usuarios de aprobación/rechazo
    approver = relationship(
        'UserModel',
        foreign_keys=[approved_by],
        backref='loans_approved'
    )
    rejecter = relationship(
        'UserModel',
        foreign_keys=[rejected_by],
        backref='loans_rejected'
    )
    
    # Contrato (1:1) - Se crea al aprobar
    # contract = relationship(
    #     'ContractModel',
    #     foreign_keys=[contract_id],
    #     backref='loan',
    #     uselist=False
    # )
    
    # Pagos (cronograma) - Generado por trigger al aprobar
    # payments = relationship(
    #     'PaymentModel',
    #     back_populates='loan',
    #     cascade='all, delete-orphan',
    #     order_by='PaymentModel.payment_due_date'
    # )
    
    # =============================================================================
    # CONSTRAINTS E ÍNDICES
    # =============================================================================
    
    __table_args__ = (
        # Constraints de validación (CHECK)
        CheckConstraint(
            'amount > 0',
            name='check_loans_amount_positive'
        ),
        CheckConstraint(
            'interest_rate >= 0 AND interest_rate <= 100',
            name='check_loans_interest_rate_valid'
        ),
        CheckConstraint(
            'commission_rate >= 0 AND commission_rate <= 100',
            name='check_loans_commission_rate_valid'
        ),
        CheckConstraint(
            'term_biweeks BETWEEN 1 AND 52',
            name='check_loans_term_biweeks_valid'
        ),
        CheckConstraint(
            'approved_at IS NULL OR approved_at >= created_at',
            name='check_loans_approved_after_created'
        ),
        CheckConstraint(
            'rejected_at IS NULL OR rejected_at >= created_at',
            name='check_loans_rejected_after_created'
        ),
        
        # Índices para optimizar queries
        Index('idx_loans_user_id', 'user_id'),
        Index('idx_loans_associate_user_id', 'associate_user_id'),
        Index('idx_loans_status_id', 'status_id'),
        Index('idx_loans_approved_at', 'approved_at'),
        Index('idx_loans_status_id_approved_at', 'status_id', 'approved_at'),
        
        # Metadata
        {
            'comment': 'Tabla central del sistema. Registra todos los préstamos solicitados, aprobados, rechazados o completados.'
        }
    )
    
    def __repr__(self):
        return (
            f"<LoanModel(id={self.id}, "
            f"user_id={self.user_id}, "
            f"amount={self.amount}, "
            f"status_id={self.status_id})>"
        )


__all__ = ['LoanModel']
