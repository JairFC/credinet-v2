"""
Implementaciones PostgreSQL de repositorios para catálogos.

Estas clases implementan las interfaces definidas en domain/repositories
usando SQLAlchemy para acceso a PostgreSQL.
"""

from typing import List, Optional

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.catalogs.domain.entities import (
    AssociateLevel,
    ConfigType,
    ContractStatus,
    CutPeriodStatus,
    DocumentStatus,
    DocumentType,
    LevelChangeType,
    LoanStatus,
    PaymentMethod,
    PaymentStatus,
    Role,
    StatementStatus,
)
from app.modules.catalogs.domain.repositories import (
    AssociateLevelRepository,
    ConfigTypeRepository,
    ContractStatusRepository,
    CutPeriodStatusRepository,
    DocumentStatusRepository,
    DocumentTypeRepository,
    LevelChangeTypeRepository,
    LoanStatusRepository,
    PaymentMethodRepository,
    PaymentStatusRepository,
    RoleRepository,
    StatementStatusRepository,
)
from app.modules.catalogs.infrastructure.models import (
    AssociateLevelModel,
    ConfigTypeModel,
    ContractStatusModel,
    CutPeriodStatusModel,
    DocumentStatusModel,
    DocumentTypeModel,
    LevelChangeTypeModel,
    LoanStatusModel,
    PaymentMethodModel,
    PaymentStatusModel,
    StatementStatusModel,
)
# Import RoleModel from auth module to avoid duplication
from app.modules.auth.infrastructure.models import RoleModel


# =============================================================================
# HELPER: Mapper functi ons (Model → Entity)
# =============================================================================


def _map_role_to_entity(model: RoleModel) -> Role:
    """Convierte RoleModel a Role entity."""
    return Role(
        id=model.id,
        name=model.name,
        description=model.description,
        created_at=model.created_at,
    )


def _map_loan_status_to_entity(model: LoanStatusModel) -> LoanStatus:
    """Convierte LoanStatusModel a LoanStatus entity."""
    return LoanStatus(
        id=model.id,
        name=model.name,
        description=model.description,
        is_active=model.is_active,
        display_order=model.display_order,
        color_code=model.color_code,
        icon_name=model.icon_name,
        created_at=model.created_at,
        updated_at=model.updated_at,
    )


def _map_payment_status_to_entity(model: PaymentStatusModel) -> PaymentStatus:
    """Convierte PaymentStatusModel a PaymentStatus entity."""
    return PaymentStatus(
        id=model.id,
        name=model.name,
        description=model.description,
        is_real_payment=model.is_real_payment,
        is_active=model.is_active,
        display_order=model.display_order,
        color_code=model.color_code,
        icon_name=model.icon_name,
        created_at=model.created_at,
        updated_at=model.updated_at,
    )


def _map_contract_status_to_entity(model: ContractStatusModel) -> ContractStatus:
    """Convierte ContractStatusModel a ContractStatus entity."""
    return ContractStatus(
        id=model.id,
        name=model.name,
        description=model.description,
        is_active=model.is_active,
        requires_signature=model.requires_signature,
        display_order=model.display_order,
        created_at=model.created_at,
        updated_at=model.updated_at,
    )


def _map_cut_period_status_to_entity(model: CutPeriodStatusModel) -> CutPeriodStatus:
    """Convierte CutPeriodStatusModel a CutPeriodStatus entity."""
    return CutPeriodStatus(
        id=model.id,
        name=model.name,
        description=model.description,
        is_terminal=model.is_terminal,
        allows_payments=model.allows_payments,
        display_order=model.display_order,
        created_at=model.created_at,
        updated_at=model.updated_at,
    )


def _map_payment_method_to_entity(model: PaymentMethodModel) -> PaymentMethod:
    """Convierte PaymentMethodModel a PaymentMethod entity."""
    return PaymentMethod(
        id=model.id,
        name=model.name,
        description=model.description,
        is_active=model.is_active,
        requires_reference=model.requires_reference,
        display_order=model.display_order,
        icon_name=model.icon_name,
        created_at=model.created_at,
        updated_at=model.updated_at,
    )


def _map_document_status_to_entity(model: DocumentStatusModel) -> DocumentStatus:
    """Convierte DocumentStatusModel a DocumentStatus entity."""
    return DocumentStatus(
        id=model.id,
        name=model.name,
        description=model.description,
        display_order=model.display_order,
        color_code=model.color_code,
        created_at=model.created_at,
        updated_at=model.updated_at,
    )


def _map_statement_status_to_entity(model: StatementStatusModel) -> StatementStatus:
    """Convierte StatementStatusModel a StatementStatus entity."""
    return StatementStatus(
        id=model.id,
        name=model.name,
        description=model.description,
        is_paid=model.is_paid,
        display_order=model.display_order,
        color_code=model.color_code,
        created_at=model.created_at,
        updated_at=model.updated_at,
    )


def _map_config_type_to_entity(model: ConfigTypeModel) -> ConfigType:
    """Convierte ConfigTypeModel a ConfigType entity."""
    return ConfigType(
        id=model.id,
        name=model.name,
        description=model.description,
        validation_regex=model.validation_regex,
        example_value=model.example_value,
        created_at=model.created_at,
        updated_at=model.updated_at,
    )


def _map_level_change_type_to_entity(model: LevelChangeTypeModel) -> LevelChangeType:
    """Convierte LevelChangeTypeModel a LevelChangeType entity."""
    return LevelChangeType(
        id=model.id,
        name=model.name,
        description=model.description,
        is_automatic=model.is_automatic,
        display_order=model.display_order,
        created_at=model.created_at,
        updated_at=model.updated_at,
    )


def _map_associate_level_to_entity(model: AssociateLevelModel) -> AssociateLevel:
    """Convierte AssociateLevelModel a AssociateLevel entity."""
    return AssociateLevel(
        id=model.id,
        name=model.name,
        max_loan_amount=float(model.max_loan_amount),
        credit_limit=float(model.credit_limit),
        description=model.description,
        min_clients=model.min_clients,
        min_collection_rate=float(model.min_collection_rate),
        created_at=model.created_at,
        updated_at=model.updated_at,
    )


def _map_document_type_to_entity(model: DocumentTypeModel) -> DocumentType:
    """Convierte DocumentTypeModel a DocumentType entity."""
    return DocumentType(
        id=model.id,
        name=model.name,
        description=model.description,
        is_required=model.is_required,
        created_at=model.created_at,
        updated_at=model.updated_at,
    )


# =============================================================================
# REPOSITORIOS POSTGRESQL
# =============================================================================


class PostgreSQLRoleRepository(RoleRepository):
    """Implementación PostgreSQL del repositorio de roles."""

    def __init__(self, session: AsyncSession):
        self.session = session

    async def find_all(self) -> List[Role]:
        result = await self.session.execute(select(RoleModel))
        models = result.scalars().all()
        return [_map_role_to_entity(m) for m in models]

    async def find_by_id(self, role_id: int) -> Optional[Role]:
        result = await self.session.execute(select(RoleModel).where(RoleModel.id == role_id))
        model = result.scalar_one_or_none()
        return _map_role_to_entity(model) if model else None

    async def find_by_name(self, name: str) -> Optional[Role]:
        result = await self.session.execute(select(RoleModel).where(RoleModel.name == name))
        model = result.scalar_one_or_none()
        return _map_role_to_entity(model) if model else None


class PostgreSQLLoanStatusRepository(LoanStatusRepository):
    """Implementación PostgreSQL del repositorio de estados de préstamo."""

    def __init__(self, session: AsyncSession):
        self.session = session

    async def find_all(self, active_only: bool = False) -> List[LoanStatus]:
        query = select(LoanStatusModel).order_by(LoanStatusModel.display_order)
        if active_only:
            query = query.where(LoanStatusModel.is_active == True)
        result = await self.session.execute(query)
        models = result.scalars().all()
        return [_map_loan_status_to_entity(m) for m in models]

    async def find_by_id(self, status_id: int) -> Optional[LoanStatus]:
        result = await self.session.execute(select(LoanStatusModel).where(LoanStatusModel.id == status_id))
        model = result.scalar_one_or_none()
        return _map_loan_status_to_entity(model) if model else None

    async def find_by_name(self, name: str) -> Optional[LoanStatus]:
        result = await self.session.execute(select(LoanStatusModel).where(LoanStatusModel.name == name))
        model = result.scalar_one_or_none()
        return _map_loan_status_to_entity(model) if model else None


class PostgreSQLPaymentStatusRepository(PaymentStatusRepository):
    """Implementación PostgreSQL del repositorio de estados de pago."""

    def __init__(self, session: AsyncSession):
        self.session = session

    async def find_all(self, active_only: bool = False, real_payments_only: bool = False) -> List[PaymentStatus]:
        query = select(PaymentStatusModel).order_by(PaymentStatusModel.display_order)
        if active_only:
            query = query.where(PaymentStatusModel.is_active == True)
        if real_payments_only:
            query = query.where(PaymentStatusModel.is_real_payment == True)
        result = await self.session.execute(query)
        models = result.scalars().all()
        return [_map_payment_status_to_entity(m) for m in models]

    async def find_by_id(self, status_id: int) -> Optional[PaymentStatus]:
        result = await self.session.execute(select(PaymentStatusModel).where(PaymentStatusModel.id == status_id))
        model = result.scalar_one_or_none()
        return _map_payment_status_to_entity(model) if model else None

    async def find_by_name(self, name: str) -> Optional[PaymentStatus]:
        result = await self.session.execute(select(PaymentStatusModel).where(PaymentStatusModel.name == name))
        model = result.scalar_one_or_none()
        return _map_payment_status_to_entity(model) if model else None


class PostgreSQLContractStatusRepository(ContractStatusRepository):
    """Implementación PostgreSQL del repositorio de estados de contrato."""

    def __init__(self, session: AsyncSession):
        self.session = session

    async def find_all(self, active_only: bool = False) -> List[ContractStatus]:
        query = select(ContractStatusModel).order_by(ContractStatusModel.display_order)
        if active_only:
            query = query.where(ContractStatusModel.is_active == True)
        result = await self.session.execute(query)
        models = result.scalars().all()
        return [_map_contract_status_to_entity(m) for m in models]

    async def find_by_id(self, status_id: int) -> Optional[ContractStatus]:
        result = await self.session.execute(select(ContractStatusModel).where(ContractStatusModel.id == status_id))
        model = result.scalar_one_or_none()
        return _map_contract_status_to_entity(model) if model else None


class PostgreSQLCutPeriodStatusRepository(CutPeriodStatusRepository):
    """Implementación PostgreSQL del repositorio de estados de período de corte."""

    def __init__(self, session: AsyncSession):
        self.session = session

    async def find_all(self) -> List[CutPeriodStatus]:
        result = await self.session.execute(select(CutPeriodStatusModel).order_by(CutPeriodStatusModel.display_order))
        models = result.scalars().all()
        return [_map_cut_period_status_to_entity(m) for m in models]

    async def find_by_id(self, status_id: int) -> Optional[CutPeriodStatus]:
        result = await self.session.execute(select(CutPeriodStatusModel).where(CutPeriodStatusModel.id == status_id))
        model = result.scalar_one_or_none()
        return _map_cut_period_status_to_entity(model) if model else None


class PostgreSQLPaymentMethodRepository(PaymentMethodRepository):
    """Implementación PostgreSQL del repositorio de métodos de pago."""

    def __init__(self, session: AsyncSession):
        self.session = session

    async def find_all(self, active_only: bool = False) -> List[PaymentMethod]:
        query = select(PaymentMethodModel).order_by(PaymentMethodModel.display_order)
        if active_only:
            query = query.where(PaymentMethodModel.is_active == True)
        result = await self.session.execute(query)
        models = result.scalars().all()
        return [_map_payment_method_to_entity(m) for m in models]

    async def find_by_id(self, method_id: int) -> Optional[PaymentMethod]:
        result = await self.session.execute(select(PaymentMethodModel).where(PaymentMethodModel.id == method_id))
        model = result.scalar_one_or_none()
        return _map_payment_method_to_entity(model) if model else None


class PostgreSQLDocumentStatusRepository(DocumentStatusRepository):
    """Implementación PostgreSQL del repositorio de estados de documento."""

    def __init__(self, session: AsyncSession):
        self.session = session

    async def find_all(self) -> List[DocumentStatus]:
        result = await self.session.execute(select(DocumentStatusModel).order_by(DocumentStatusModel.display_order))
        models = result.scalars().all()
        return [_map_document_status_to_entity(m) for m in models]

    async def find_by_id(self, status_id: int) -> Optional[DocumentStatus]:
        result = await self.session.execute(select(DocumentStatusModel).where(DocumentStatusModel.id == status_id))
        model = result.scalar_one_or_none()
        return _map_document_status_to_entity(model) if model else None


class PostgreSQLStatementStatusRepository(StatementStatusRepository):
    """Implementación PostgreSQL del repositorio de estados de cuenta."""

    def __init__(self, session: AsyncSession):
        self.session = session

    async def find_all(self) -> List[StatementStatus]:
        result = await self.session.execute(select(StatementStatusModel).order_by(StatementStatusModel.display_order))
        models = result.scalars().all()
        return [_map_statement_status_to_entity(m) for m in models]

    async def find_by_id(self, status_id: int) -> Optional[StatementStatus]:
        result = await self.session.execute(select(StatementStatusModel).where(StatementStatusModel.id == status_id))
        model = result.scalar_one_or_none()
        return _map_statement_status_to_entity(model) if model else None


class PostgreSQLConfigTypeRepository(ConfigTypeRepository):
    """Implementación PostgreSQL del repositorio de tipos de configuración."""

    def __init__(self, session: AsyncSession):
        self.session = session

    async def find_all(self) -> List[ConfigType]:
        result = await self.session.execute(select(ConfigTypeModel))
        models = result.scalars().all()
        return [_map_config_type_to_entity(m) for m in models]

    async def find_by_id(self, type_id: int) -> Optional[ConfigType]:
        result = await self.session.execute(select(ConfigTypeModel).where(ConfigTypeModel.id == type_id))
        model = result.scalar_one_or_none()
        return _map_config_type_to_entity(model) if model else None


class PostgreSQLLevelChangeTypeRepository(LevelChangeTypeRepository):
    """Implementación PostgreSQL del repositorio de tipos de cambio de nivel."""

    def __init__(self, session: AsyncSession):
        self.session = session

    async def find_all(self) -> List[LevelChangeType]:
        result = await self.session.execute(select(LevelChangeTypeModel).order_by(LevelChangeTypeModel.display_order))
        models = result.scalars().all()
        return [_map_level_change_type_to_entity(m) for m in models]

    async def find_by_id(self, type_id: int) -> Optional[LevelChangeType]:
        result = await self.session.execute(select(LevelChangeTypeModel).where(LevelChangeTypeModel.id == type_id))
        model = result.scalar_one_or_none()
        return _map_level_change_type_to_entity(model) if model else None


class PostgreSQLAssociateLevelRepository(AssociateLevelRepository):
    """Implementación PostgreSQL del repositorio de niveles de asociado."""

    def __init__(self, session: AsyncSession):
        self.session = session

    async def find_all(self) -> List[AssociateLevel]:
        result = await self.session.execute(select(AssociateLevelModel))
        models = result.scalars().all()
        return [_map_associate_level_to_entity(m) for m in models]

    async def find_by_id(self, level_id: int) -> Optional[AssociateLevel]:
        result = await self.session.execute(select(AssociateLevelModel).where(AssociateLevelModel.id == level_id))
        model = result.scalar_one_or_none()
        return _map_associate_level_to_entity(model) if model else None

    async def find_by_name(self, name: str) -> Optional[AssociateLevel]:
        result = await self.session.execute(select(AssociateLevelModel).where(AssociateLevelModel.name == name))
        model = result.scalar_one_or_none()
        return _map_associate_level_to_entity(model) if model else None


class PostgreSQLDocumentTypeRepository(DocumentTypeRepository):
    """Implementación PostgreSQL del repositorio de tipos de documento."""

    def __init__(self, session: AsyncSession):
        self.session = session

    async def find_all(self, required_only: bool = False) -> List[DocumentType]:
        query = select(DocumentTypeModel)
        if required_only:
            query = query.where(DocumentTypeModel.is_required == True)
        result = await self.session.execute(query)
        models = result.scalars().all()
        return [_map_document_type_to_entity(m) for m in models]

    async def find_by_id(self, type_id: int) -> Optional[DocumentType]:
        result = await self.session.execute(select(DocumentTypeModel).where(DocumentTypeModel.id == type_id))
        model = result.scalar_one_or_none()
        return _map_document_type_to_entity(model) if model else None
