"""
Entidades del dominio de préstamos.

Estas son las entidades de negocio puras, sin dependencias de infraestructura.
"""
from dataclasses import dataclass
from datetime import datetime, date
from decimal import Decimal
from enum import IntEnum
from typing import Optional


# =============================================================================
# ENUMS
# =============================================================================

class LoanStatusEnum(IntEnum):
    """
    Estados posibles de un préstamo.
    
    Mapea directamente a la tabla catalog: loan_statuses
    """
    PENDING = 1          # Solicitud creada, esperando aprobación
    APPROVED = 2         # Aprobado, cronograma generado
    ACTIVE = 3           # Desembolsado, pagos en curso
    PAID_OFF = 4         # Completamente liquidado
    DEFAULTED = 5        # Cliente moroso (admin aprobó reporte)
    REJECTED = 6         # Rechazado por admin
    CANCELLED = 7        # Cancelado antes de desembolso
    RESTRUCTURED = 8     # Reestructurado (convenio)
    OVERDUE = 9          # Atrasado (1+ pagos vencidos)
    EARLY_PAYMENT = 10   # Liquidado anticipadamente


# =============================================================================
# VALUE OBJECTS
# =============================================================================

@dataclass(frozen=True)
class LoanBalance:
    """
    Value Object: Balance de un préstamo.
    
    Representa el estado financiero actual del préstamo.
    Inmutable para garantizar consistencia.
    """
    loan_id: int
    total_amount: Decimal
    total_paid: Decimal
    remaining_balance: Decimal
    payment_count: int
    payments_completed: int
    
    def __post_init__(self):
        """Validaciones de consistencia."""
        if self.total_amount < 0:
            raise ValueError("total_amount debe ser >= 0")
        if self.total_paid < 0:
            raise ValueError("total_paid debe ser >= 0")
        if self.remaining_balance < 0:
            raise ValueError("remaining_balance debe ser >= 0")
        if self.payment_count < 0:
            raise ValueError("payment_count debe ser >= 0")
        if self.payments_completed < 0:
            raise ValueError("payments_completed debe ser >= 0")
        if self.payments_completed > self.payment_count:
            raise ValueError("payments_completed no puede ser mayor que payment_count")
    
    def is_paid_off(self) -> bool:
        """Verifica si el préstamo está completamente liquidado."""
        return self.remaining_balance == 0 and self.payments_completed == self.payment_count
    
    def is_overdue(self) -> bool:
        """Verifica si hay pagos atrasados (simplificado, requiere más lógica)."""
        return self.payments_completed < self.payment_count
    
    def completion_percentage(self) -> Decimal:
        """Calcula el porcentaje de completitud del préstamo."""
        if self.payment_count == 0:
            return Decimal('0.00')
        return Decimal(self.payments_completed / self.payment_count * 100).quantize(Decimal('0.01'))


@dataclass(frozen=True)
class LoanApprovalRequest:
    """
    Value Object: Solicitud de aprobación de préstamo.
    
    Encapsula toda la información necesaria para aprobar un préstamo.
    """
    loan_id: int
    approved_by: int
    notes: Optional[str] = None
    
    def __post_init__(self):
        """Validaciones."""
        if self.loan_id <= 0:
            raise ValueError("loan_id debe ser > 0")
        if self.approved_by <= 0:
            raise ValueError("approved_by debe ser > 0")


@dataclass(frozen=True)
class LoanRejectionRequest:
    """
    Value Object: Solicitud de rechazo de préstamo.
    
    Encapsula toda la información necesaria para rechazar un préstamo.
    """
    loan_id: int
    rejected_by: int
    rejection_reason: str
    
    def __post_init__(self):
        """Validaciones."""
        if self.loan_id <= 0:
            raise ValueError("loan_id debe ser > 0")
        if self.rejected_by <= 0:
            raise ValueError("rejected_by debe ser > 0")
        if not self.rejection_reason or self.rejection_reason.strip() == "":
            raise ValueError("rejection_reason es obligatorio")


# =============================================================================
# ENTITIES
# =============================================================================

@dataclass
class Loan:
    """
    Entidad: Préstamo.
    
    Representa un préstamo del sistema. Es la entidad más crítica de CrediNet.
    
    Reglas de negocio:
    - amount debe ser > 0
    - interest_rate debe estar entre 0 y 100
    - commission_rate debe estar entre 0 y 100
    - term_biweeks debe estar entre 1 y 52 (1-4 años)
    - approved_at debe ser >= created_at
    - rejected_at debe ser >= created_at
    - Solo puede estar aprobado O rechazado, no ambos
    """
    # Identificadores
    id: Optional[int]
    user_id: int                              # Cliente dueño del préstamo
    associate_user_id: Optional[int]          # Asociado gestor (puede ser NULL)
    
    # Datos financieros
    amount: Decimal                           # Monto del préstamo (SIN intereses)
    interest_rate: Decimal                    # Tasa de interés (%)
    commission_rate: Decimal                  # Comisión del asociado (%)
    term_biweeks: int                         # Plazo en quincenas (1 quincena = 15 días)
    
    # Estado y relaciones
    status_id: int                            # FK a loan_statuses
    contract_id: Optional[int] = None         # FK a contracts (se crea al aprobar)
    
    # Tracking de aprobación
    approved_at: Optional[datetime] = None
    approved_by: Optional[int] = None
    rejected_at: Optional[datetime] = None
    rejected_by: Optional[int] = None
    rejection_reason: Optional[str] = None
    notes: Optional[str] = None
    
    # Auditoría
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
    
    def __post_init__(self):
        """Validaciones de negocio en la entidad."""
        # Validar monto
        if self.amount <= 0:
            raise ValueError(f"amount debe ser > 0, recibido: {self.amount}")
        
        # Validar tasa de interés
        if not (0 <= self.interest_rate <= 100):
            raise ValueError(f"interest_rate debe estar entre 0 y 100, recibido: {self.interest_rate}")
        
        # Validar comisión
        if not (0 <= self.commission_rate <= 100):
            raise ValueError(f"commission_rate debe estar entre 0 y 100, recibido: {self.commission_rate}")
        
        # Validar plazo
        if not (1 <= self.term_biweeks <= 52):
            raise ValueError(f"term_biweeks debe estar entre 1 y 52, recibido: {self.term_biweeks}")
        
        # Validar lógica temporal (solo si fechas existen)
        if self.approved_at and self.created_at and self.approved_at < self.created_at:
            raise ValueError("approved_at no puede ser anterior a created_at")
        
        if self.rejected_at and self.created_at and self.rejected_at < self.created_at:
            raise ValueError("rejected_at no puede ser anterior a created_at")
        
        # Validar que no esté aprobado Y rechazado
        if self.approved_at and self.rejected_at:
            raise ValueError("Un préstamo no puede estar aprobado y rechazado simultáneamente")
        
        # Validar rejection_reason si está rechazado
        if self.rejected_at and not self.rejection_reason:
            raise ValueError("rejection_reason es obligatorio si el préstamo está rechazado")
    
    def is_pending(self) -> bool:
        """Verifica si el préstamo está pendiente de aprobación."""
        return self.status_id == LoanStatusEnum.PENDING
    
    def is_approved(self) -> bool:
        """Verifica si el préstamo está aprobado."""
        return self.status_id == LoanStatusEnum.APPROVED
    
    def is_active(self) -> bool:
        """Verifica si el préstamo está activo (en cobro)."""
        return self.status_id == LoanStatusEnum.ACTIVE
    
    def is_rejected(self) -> bool:
        """Verifica si el préstamo fue rechazado."""
        return self.status_id == LoanStatusEnum.REJECTED
    
    def is_paid_off(self) -> bool:
        """Verifica si el préstamo está completamente liquidado."""
        return self.status_id == LoanStatusEnum.PAID_OFF
    
    def can_be_approved(self) -> bool:
        """Verifica si el préstamo puede ser aprobado."""
        return self.status_id == LoanStatusEnum.PENDING and not self.approved_at and not self.rejected_at
    
    def can_be_rejected(self) -> bool:
        """Verifica si el préstamo puede ser rechazado."""
        return self.status_id == LoanStatusEnum.PENDING and not self.approved_at and not self.rejected_at
    
    def can_be_cancelled(self) -> bool:
        """Verifica si el préstamo puede ser cancelado."""
        return self.status_id in (LoanStatusEnum.PENDING, LoanStatusEnum.APPROVED)
    
    def calculate_total_to_pay(self) -> Decimal:
        """
        Calcula el monto total a pagar (capital + intereses).
        
        Fórmula simplificada: amount * (1 + interest_rate/100)
        """
        return self.amount * (Decimal('1') + self.interest_rate / Decimal('100'))
    
    def calculate_payment_amount(self) -> Decimal:
        """
        Calcula el monto de cada pago quincenal.
        
        Fórmula: total_to_pay / term_biweeks
        Redondeo: 2 decimales
        """
        total = self.calculate_total_to_pay()
        return (total / self.term_biweeks).quantize(Decimal('0.01'))


__all__ = [
    'Loan',
    'LoanBalance',
    'LoanApprovalRequest',
    'LoanRejectionRequest',
    'LoanStatusEnum',
]
