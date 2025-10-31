"""
Entidades de dominio para catálogos.

Estas entidades representan los catálogos de la base de datos v2.0.
Son objetos de negocio puros, sin dependencias de infraestructura.
"""

from dataclasses import dataclass
from datetime import datetime
from typing import Optional


@dataclass
class Role:
    """Rol de usuario en el sistema."""

    id: int
    name: str
    description: Optional[str]
    created_at: datetime


@dataclass
class LoanStatus:
    """Estado de préstamo."""

    id: int
    name: str
    description: str
    is_active: bool
    display_order: int
    color_code: Optional[str]
    icon_name: Optional[str]
    created_at: datetime
    updated_at: datetime


@dataclass
class PaymentStatus:
    """Estado de pago (12 estados v2.0)."""

    id: int
    name: str
    description: str
    is_real_payment: bool  # TRUE si es pago real, FALSE si es ficticio
    is_active: bool
    display_order: int
    color_code: Optional[str]
    icon_name: Optional[str]
    created_at: datetime
    updated_at: datetime


@dataclass
class ContractStatus:
    """Estado de contrato."""

    id: int
    name: str
    description: str
    is_active: bool
    requires_signature: bool
    display_order: int
    created_at: datetime
    updated_at: datetime


@dataclass
class CutPeriodStatus:
    """Estado de período de corte."""

    id: int
    name: str
    description: str
    is_terminal: bool
    allows_payments: bool
    display_order: int
    created_at: datetime
    updated_at: datetime


@dataclass
class PaymentMethod:
    """Método de pago."""

    id: int
    name: str
    description: Optional[str]
    is_active: bool
    requires_reference: bool
    display_order: int
    icon_name: Optional[str]
    created_at: datetime
    updated_at: datetime


@dataclass
class DocumentStatus:
    """Estado de documento."""

    id: int
    name: str
    description: str
    display_order: int
    color_code: Optional[str]
    created_at: datetime
    updated_at: datetime


@dataclass
class StatementStatus:
    """Estado de cuenta de asociado."""

    id: int
    name: str
    description: str
    is_paid: bool
    display_order: int
    color_code: Optional[str]
    created_at: datetime
    updated_at: datetime


@dataclass
class ConfigType:
    """Tipo de configuración."""

    id: int
    name: str
    description: Optional[str]
    validation_regex: Optional[str]
    example_value: Optional[str]
    created_at: datetime
    updated_at: datetime


@dataclass
class LevelChangeType:
    """Tipo de cambio de nivel de asociado."""

    id: int
    name: str
    description: str
    is_automatic: bool
    display_order: int
    created_at: datetime
    updated_at: datetime


@dataclass
class AssociateLevel:
    """Nivel de asociado (Bronce, Plata, Oro, Platino, Diamante)."""

    id: int
    name: str
    max_loan_amount: float
    credit_limit: float
    description: Optional[str]
    min_clients: int
    min_collection_rate: float
    created_at: datetime
    updated_at: datetime


@dataclass
class DocumentType:
    """Tipo de documento."""

    id: int
    name: str
    description: Optional[str]
    is_required: bool
    created_at: datetime
    updated_at: datetime
