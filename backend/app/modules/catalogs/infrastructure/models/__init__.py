"""
Modelos SQLAlchemy para catálogos.

Mapean las tablas de catálogo de db/v2.0/modules/01_catalog_tables.sql
a modelos ORM de SQLAlchemy.
"""

from sqlalchemy import Boolean, Column, DateTime, Integer, Numeric, String, Text
from sqlalchemy.sql import func

from app.core.database import Base


class RoleModel(Base):
    """Modelo para roles de usuario."""

    __tablename__ = "roles"
    __table_args__ = {"extend_existing": True}

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(50), unique=True, nullable=False)
    description = Column(Text)
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class LoanStatusModel(Base):
    """Modelo para estados de préstamo."""

    __tablename__ = "loan_statuses"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(50), unique=True, nullable=False, index=True)
    description = Column(Text, nullable=False)
    is_active = Column(Boolean, default=True, index=True)
    display_order = Column(Integer, default=0)
    color_code = Column(String(7))
    icon_name = Column(String(50))
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())


class PaymentStatusModel(Base):
    """Modelo para estados de pago (12 estados v2.0)."""

    __tablename__ = "payment_statuses"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(50), unique=True, nullable=False, index=True)
    description = Column(Text, nullable=False)
    is_real_payment = Column(Boolean, default=True, index=True)  # TRUE = pago real, FALSE = ficticio
    is_active = Column(Boolean, default=True, index=True)
    display_order = Column(Integer, default=0)
    color_code = Column(String(7))
    icon_name = Column(String(50))
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())


class ContractStatusModel(Base):
    """Modelo para estados de contrato."""

    __tablename__ = "contract_statuses"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(50), unique=True, nullable=False, index=True)
    description = Column(Text, nullable=False)
    is_active = Column(Boolean, default=True)
    requires_signature = Column(Boolean, default=False)
    display_order = Column(Integer, default=0)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())


class CutPeriodStatusModel(Base):
    """Modelo para estados de período de corte."""

    __tablename__ = "cut_period_statuses"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(50), unique=True, nullable=False, index=True)
    description = Column(Text, nullable=False)
    is_terminal = Column(Boolean, default=False)
    allows_payments = Column(Boolean, default=True)
    display_order = Column(Integer, default=0)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())


class PaymentMethodModel(Base):
    """Modelo para métodos de pago."""

    __tablename__ = "payment_methods"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(50), unique=True, nullable=False, index=True)
    description = Column(Text)
    is_active = Column(Boolean, default=True)
    requires_reference = Column(Boolean, default=False)
    display_order = Column(Integer, default=0)
    icon_name = Column(String(50))
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())


class DocumentStatusModel(Base):
    """Modelo para estados de documento."""

    __tablename__ = "document_statuses"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(50), unique=True, nullable=False, index=True)
    description = Column(Text, nullable=False)
    display_order = Column(Integer, default=0)
    color_code = Column(String(7))
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())


class StatementStatusModel(Base):
    """Modelo para estados de cuenta de asociado."""

    __tablename__ = "statement_statuses"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(50), unique=True, nullable=False, index=True)
    description = Column(Text, nullable=False)
    is_paid = Column(Boolean, default=False)
    display_order = Column(Integer, default=0)
    color_code = Column(String(7))
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())


class ConfigTypeModel(Base):
    """Modelo para tipos de configuración."""

    __tablename__ = "config_types"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(50), unique=True, nullable=False, index=True)
    description = Column(Text)
    validation_regex = Column(Text)
    example_value = Column(Text)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())


class LevelChangeTypeModel(Base):
    """Modelo para tipos de cambio de nivel de asociado."""

    __tablename__ = "level_change_types"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(50), unique=True, nullable=False, index=True)
    description = Column(Text, nullable=False)
    is_automatic = Column(Boolean, default=False)
    display_order = Column(Integer, default=0)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())


class AssociateLevelModel(Base):
    """Modelo para niveles de asociado (Bronce, Plata, Oro, Platino, Diamante)."""

    __tablename__ = "associate_levels"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(50), unique=True, nullable=False)
    max_loan_amount = Column(Numeric(12, 2), nullable=False)
    credit_limit = Column(Numeric(12, 2), default=0.00)
    description = Column(Text)
    min_clients = Column(Integer, default=0)
    min_collection_rate = Column(Numeric(5, 2), default=0.00)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())


class DocumentTypeModel(Base):
    """Modelo para tipos de documento."""

    __tablename__ = "document_types"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(100), unique=True, nullable=False)
    description = Column(Text)
    is_required = Column(Boolean, nullable=False, default=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
