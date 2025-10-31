"""
DTOs (Data Transfer Objects) para catálogos.

Schemas Pydantic para serializar las respuestas de la API.
"""

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict


class RoleDTO(BaseModel):
    """DTO para roles."""

    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    description: Optional[str] = None
    created_at: datetime


class LoanStatusDTO(BaseModel):
    """DTO para estados de préstamo."""

    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    description: str
    is_active: bool
    display_order: int
    color_code: Optional[str] = None
    icon_name: Optional[str] = None
    created_at: datetime
    updated_at: datetime


class PaymentStatusDTO(BaseModel):
    """DTO para estados de pago."""

    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    description: str
    is_real_payment: bool
    is_active: bool
    display_order: int
    color_code: Optional[str] = None
    icon_name: Optional[str] = None
    created_at: datetime
    updated_at: datetime


class ContractStatusDTO(BaseModel):
    """DTO para estados de contrato."""

    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    description: str
    is_active: bool
    requires_signature: bool
    display_order: int
    created_at: datetime
    updated_at: datetime


class CutPeriodStatusDTO(BaseModel):
    """DTO para estados de período de corte."""

    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    description: str
    is_terminal: bool
    allows_payments: bool
    display_order: int
    created_at: datetime
    updated_at: datetime


class PaymentMethodDTO(BaseModel):
    """DTO para métodos de pago."""

    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    description: Optional[str] = None
    is_active: bool
    requires_reference: bool
    display_order: int
    icon_name: Optional[str] = None
    created_at: datetime
    updated_at: datetime


class DocumentStatusDTO(BaseModel):
    """DTO para estados de documento."""

    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    description: str
    display_order: int
    color_code: Optional[str] = None
    created_at: datetime
    updated_at: datetime


class StatementStatusDTO(BaseModel):
    """DTO para estados de cuenta de asociado."""

    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    description: str
    is_paid: bool
    display_order: int
    color_code: Optional[str] = None
    created_at: datetime
    updated_at: datetime


class ConfigTypeDTO(BaseModel):
    """DTO para tipos de configuración."""

    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    description: Optional[str] = None
    validation_regex: Optional[str] = None
    example_value: Optional[str] = None
    created_at: datetime
    updated_at: datetime


class LevelChangeTypeDTO(BaseModel):
    """DTO para tipos de cambio de nivel."""

    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    description: str
    is_automatic: bool
    display_order: int
    created_at: datetime
    updated_at: datetime


class AssociateLevelDTO(BaseModel):
    """DTO para niveles de asociado."""

    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    max_loan_amount: float
    credit_limit: float
    description: Optional[str] = None
    min_clients: int
    min_collection_rate: float
    created_at: datetime
    updated_at: datetime


class DocumentTypeDTO(BaseModel):
    """DTO para tipos de documento."""

    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    description: Optional[str] = None
    is_required: bool
    created_at: datetime
    updated_at: datetime
