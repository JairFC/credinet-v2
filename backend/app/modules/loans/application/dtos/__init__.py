"""
DTOs (Data Transfer Objects) para el módulo de préstamos.

Pydantic v2 para validación y serialización.
"""
from datetime import datetime
from decimal import Decimal
from typing import Optional

from pydantic import BaseModel, Field, ConfigDict


# =============================================================================
# REQUEST DTOs
# =============================================================================

class LoanFilterDTO(BaseModel):
    """
    DTO para filtros de búsqueda de préstamos.
    
    Usado en: GET /loans?status_id=1&user_id=5&limit=20
    """
    status_id: Optional[int] = Field(None, description="Filtrar por estado del préstamo")
    user_id: Optional[int] = Field(None, description="Filtrar por ID del cliente")
    associate_user_id: Optional[int] = Field(None, description="Filtrar por ID del asociado")
    limit: int = Field(50, ge=1, le=100, description="Máximo de registros a retornar")
    offset: int = Field(0, ge=0, description="Desplazamiento para paginación")
    
    model_config = ConfigDict(from_attributes=True)


class LoanCreateDTO(BaseModel):
    """
    DTO para crear una nueva solicitud de préstamo.
    
    Usado en: POST /loans
    """
    user_id: int = Field(..., gt=0, description="ID del cliente solicitante")
    associate_user_id: int = Field(..., gt=0, description="ID del asociado que otorga el préstamo")
    amount: Decimal = Field(..., gt=0, description="Monto solicitado")
    interest_rate: Decimal = Field(..., ge=0, le=100, description="Tasa de interés (%)")
    commission_rate: Decimal = Field(0, ge=0, le=100, description="Tasa de comisión (%)")
    term_biweeks: int = Field(..., ge=1, le=52, description="Plazo en quincenas (1-52)")
    notes: Optional[str] = Field(None, max_length=1000, description="Notas adicionales")
    
    model_config = ConfigDict(from_attributes=True)


class LoanApproveDTO(BaseModel):
    """
    DTO para aprobar un préstamo.
    
    Usado en: POST /loans/{id}/approve
    """
    approved_by: int = Field(..., gt=0, description="ID del usuario que aprueba")
    notes: Optional[str] = Field(None, max_length=1000, description="Notas adicionales")
    
    model_config = ConfigDict(from_attributes=True)


class LoanRejectDTO(BaseModel):
    """
    DTO para rechazar un préstamo.
    
    Usado en: POST /loans/{id}/reject
    """
    rejected_by: int = Field(..., gt=0, description="ID del usuario que rechaza")
    rejection_reason: str = Field(..., min_length=10, max_length=1000, description="Razón del rechazo (obligatoria, mínimo 10 caracteres)")
    
    model_config = ConfigDict(from_attributes=True)


class LoanUpdateDTO(BaseModel):
    """
    DTO para actualizar un préstamo PENDING.
    
    Usado en: PUT /loans/{id}
    
    Todos los campos son opcionales. Solo se actualizan los campos proporcionados.
    """
    amount: Optional[Decimal] = Field(None, gt=0, description="Nuevo monto del préstamo")
    interest_rate: Optional[Decimal] = Field(None, ge=0, le=100, description="Nueva tasa de interés (%)")
    commission_rate: Optional[Decimal] = Field(None, ge=0, le=100, description="Nueva tasa de comisión (%)")
    term_biweeks: Optional[int] = Field(None, ge=1, le=52, description="Nuevo plazo en quincenas (1-52)")
    notes: Optional[str] = Field(None, max_length=1000, description="Notas sobre la actualización")
    
    model_config = ConfigDict(from_attributes=True)


class LoanCancelDTO(BaseModel):
    """
    DTO para cancelar un préstamo ACTIVE.
    
    Usado en: POST /loans/{id}/cancel
    """
    cancelled_by: int = Field(..., gt=0, description="ID del usuario que cancela")
    cancellation_reason: str = Field(..., min_length=10, max_length=1000, description="Razón de la cancelación (obligatoria, mínimo 10 caracteres)")
    
    model_config = ConfigDict(from_attributes=True)


# =============================================================================
# RESPONSE DTOs
# =============================================================================

class LoanSummaryDTO(BaseModel):
    """
    DTO para resumen de préstamo (usado en listas).
    
    Usado en: GET /loans (retorna lista de este DTO)
    """
    id: int = Field(..., description="ID del préstamo")
    user_id: int = Field(..., description="ID del cliente")
    amount: Decimal = Field(..., description="Monto del préstamo")
    interest_rate: Decimal = Field(..., description="Tasa de interés (%)")
    term_biweeks: int = Field(..., description="Plazo en quincenas")
    status_id: int = Field(..., description="ID del estado")
    created_at: datetime = Field(..., description="Fecha de creación")
    
    # Campos calculados (opcionales, agregar con joins si es necesario)
    status_name: Optional[str] = Field(None, description="Nombre del estado")
    client_name: Optional[str] = Field(None, description="Nombre del cliente")
    
    model_config = ConfigDict(from_attributes=True)


class LoanResponseDTO(BaseModel):
    """
    DTO para detalle completo de préstamo.
    
    Usado en: GET /loans/{id} (retorna este DTO)
    """
    id: int = Field(..., description="ID del préstamo")
    user_id: int = Field(..., description="ID del cliente")
    associate_user_id: Optional[int] = Field(None, description="ID del asociado")
    amount: Decimal = Field(..., description="Monto del préstamo")
    interest_rate: Decimal = Field(..., description="Tasa de interés (%)")
    commission_rate: Decimal = Field(..., description="Tasa de comisión (%)")
    term_biweeks: int = Field(..., description="Plazo en quincenas")
    status_id: int = Field(..., description="ID del estado")
    contract_id: Optional[int] = Field(None, description="ID del contrato asociado")
    
    # Fechas de aprobación/rechazo
    approved_at: Optional[datetime] = Field(None, description="Fecha de aprobación")
    approved_by: Optional[int] = Field(None, description="ID del usuario que aprobó")
    rejected_at: Optional[datetime] = Field(None, description="Fecha de rechazo")
    rejected_by: Optional[int] = Field(None, description="ID del usuario que rechazó")
    rejection_reason: Optional[str] = Field(None, description="Razón del rechazo")
    
    # Notas y auditoría
    notes: Optional[str] = Field(None, description="Notas adicionales")
    created_at: datetime = Field(..., description="Fecha de creación")
    updated_at: datetime = Field(..., description="Fecha de última actualización")
    
    # Campos calculados (opcionales, agregar con joins si es necesario)
    status_name: Optional[str] = Field(None, description="Nombre del estado")
    client_name: Optional[str] = Field(None, description="Nombre del cliente")
    associate_name: Optional[str] = Field(None, description="Nombre del asociado")
    approver_name: Optional[str] = Field(None, description="Nombre del aprobador")
    rejecter_name: Optional[str] = Field(None, description="Nombre del rechazador")
    
    # Cálculos de negocio
    total_to_pay: Optional[Decimal] = Field(None, description="Monto total a pagar")
    payment_amount: Optional[Decimal] = Field(None, description="Monto de cada cuota quincenal")
    
    model_config = ConfigDict(from_attributes=True)


class LoanBalanceDTO(BaseModel):
    """
    DTO para balance de un préstamo.
    
    Usado en: GET /loans/{id}/balance
    """
    loan_id: int = Field(..., description="ID del préstamo")
    total_amount: Decimal = Field(..., description="Monto total a pagar")
    total_paid: Decimal = Field(..., description="Monto total pagado")
    remaining_balance: Decimal = Field(..., description="Saldo pendiente")
    payment_count: int = Field(..., description="Total de pagos programados")
    payments_completed: int = Field(..., description="Pagos completados")
    
    # Campos calculados
    is_paid_off: bool = Field(..., description="¿Está totalmente pagado?")
    completion_percentage: Decimal = Field(..., description="Porcentaje de completación")
    
    model_config = ConfigDict(from_attributes=True)
    
    @classmethod
    def from_loan_balance(cls, balance):
        """
        Crea un LoanBalanceDTO desde LoanBalance (Value Object).
        
        Args:
            balance: Instancia de LoanBalance
            
        Returns:
            LoanBalanceDTO
        """
        return cls(
            loan_id=balance.loan_id,
            total_amount=balance.total_amount,
            total_paid=balance.total_paid,
            remaining_balance=balance.remaining_balance,
            payment_count=balance.payment_count,
            payments_completed=balance.payments_completed,
            is_paid_off=balance.is_paid_off(),
            completion_percentage=balance.completion_percentage()
        )


# =============================================================================
# PAGINACIÓN
# =============================================================================

class PaginatedLoansDTO(BaseModel):
    """
    DTO para respuestas paginadas de préstamos.
    
    Usado en: GET /loans (response wrapper)
    """
    items: list[LoanSummaryDTO] = Field(..., description="Lista de préstamos")
    total: int = Field(..., description="Total de registros que coinciden con filtros")
    limit: int = Field(..., description="Límite aplicado")
    offset: int = Field(..., description="Desplazamiento aplicado")
    
    model_config = ConfigDict(from_attributes=True)


__all__ = [
    'LoanFilterDTO',
    'LoanCreateDTO',
    'LoanApproveDTO',
    'LoanRejectDTO',
    'LoanUpdateDTO',
    'LoanCancelDTO',
    'LoanSummaryDTO',
    'LoanResponseDTO',
    'LoanBalanceDTO',
    'PaginatedLoansDTO',
]
