"""
Rutas del módulo de catálogos.
Proporciona endpoints read-only para los 12 catálogos del sistema.
"""
from typing import List
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_async_db

from typing import List

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.modules.catalogs.application.dtos import (
    AssociateLevelDTO,
    ConfigTypeDTO,
    ContractStatusDTO,
    CutPeriodStatusDTO,
    DocumentStatusDTO,
    DocumentTypeDTO,
    LevelChangeTypeDTO,
    LoanStatusDTO,
    PaymentMethodDTO,
    PaymentStatusDTO,
    RoleDTO,
    StatementStatusDTO,
)
from app.modules.catalogs.infrastructure.repositories import (
    PostgreSQLAssociateLevelRepository,
    PostgreSQLConfigTypeRepository,
    PostgreSQLContractStatusRepository,
    PostgreSQLCutPeriodStatusRepository,
    PostgreSQLDocumentStatusRepository,
    PostgreSQLDocumentTypeRepository,
    PostgreSQLLevelChangeTypeRepository,
    PostgreSQLLoanStatusRepository,
    PostgreSQLPaymentMethodRepository,
    PostgreSQLPaymentStatusRepository,
    PostgreSQLRoleRepository,
    PostgreSQLStatementStatusRepository,
)

router = APIRouter(prefix="/catalogs", tags=["Catalogs"])


# =============================================================================
# ROLES
# =============================================================================


@router.get("/roles", response_model=List[RoleDTO], summary="Obtener todos los roles")
async def get_all_roles(db: AsyncSession = Depends(get_async_db)):
    """Obtiene la lista completa de roles del sistema."""
    repository = PostgreSQLRoleRepository(db)
    roles = await repository.find_all()
    return roles


@router.get("/roles/{role_id}", response_model=RoleDTO, summary="Obtener rol por ID")
async def get_role_by_id(role_id: int, db: AsyncSession = Depends(get_async_db)):
    """Obtiene un rol específico por su ID."""
    repository = PostgreSQLRoleRepository(db)
    role = await repository.find_by_id(role_id)
    if not role:
        raise HTTPException(status_code=404, detail=f"Rol con ID {role_id} no encontrado")
    return role


# =============================================================================
# LOAN STATUSES
# =============================================================================


@router.get("/loan-statuses", response_model=List[LoanStatusDTO], summary="Obtener estados de préstamo")
async def get_all_loan_statuses(
    active_only: bool = Query(False, description="Filtrar solo estados activos"), db: AsyncSession = Depends(get_async_db)
):
    """Obtiene la lista de estados de préstamo."""
    repository = PostgreSQLLoanStatusRepository(db)
    statuses = await repository.find_all(active_only=active_only)
    return statuses


@router.get("/loan-statuses/{status_id}", response_model=LoanStatusDTO, summary="Obtener estado de préstamo por ID")
async def get_loan_status_by_id(status_id: int, db: AsyncSession = Depends(get_async_db)):
    """Obtiene un estado de préstamo específico por su ID."""
    repository = PostgreSQLLoanStatusRepository(db)
    status = await repository.find_by_id(status_id)
    if not status:
        raise HTTPException(status_code=404, detail=f"Estado de préstamo con ID {status_id} no encontrado")
    return status


# =============================================================================
# PAYMENT STATUSES
# =============================================================================


@router.get("/payment-statuses", response_model=List[PaymentStatusDTO], summary="Obtener estados de pago")
async def get_all_payment_statuses(
    active_only: bool = Query(False, description="Filtrar solo estados activos"),
    real_payments_only: bool = Query(False, description="Filtrar solo pagos reales (excluir ficticios)"),
    db: AsyncSession = Depends(get_async_db),
):
    """Obtiene la lista de estados de pago (12 estados v2.0)."""
    repository = PostgreSQLPaymentStatusRepository(db)
    statuses = await repository.find_all(active_only=active_only, real_payments_only=real_payments_only)
    return statuses


@router.get("/payment-statuses/{status_id}", response_model=PaymentStatusDTO, summary="Obtener estado de pago por ID")
async def get_payment_status_by_id(status_id: int, db: AsyncSession = Depends(get_async_db)):
    """Obtiene un estado de pago específico por su ID."""
    repository = PostgreSQLPaymentStatusRepository(db)
    status = await repository.find_by_id(status_id)
    if not status:
        raise HTTPException(status_code=404, detail=f"Estado de pago con ID {status_id} no encontrado")
    return status


# =============================================================================
# CONTRACT STATUSES
# =============================================================================


@router.get("/contract-statuses", response_model=List[ContractStatusDTO], summary="Obtener estados de contrato")
async def get_all_contract_statuses(
    active_only: bool = Query(False, description="Filtrar solo estados activos"), db: AsyncSession = Depends(get_async_db)
):
    """Obtiene la lista de estados de contrato."""
    repository = PostgreSQLContractStatusRepository(db)
    statuses = await repository.find_all(active_only=active_only)
    return statuses


@router.get(
    "/contract-statuses/{status_id}", response_model=ContractStatusDTO, summary="Obtener estado de contrato por ID"
)
async def get_contract_status_by_id(status_id: int, db: AsyncSession = Depends(get_async_db)):
    """Obtiene un estado de contrato específico por su ID."""
    repository = PostgreSQLContractStatusRepository(db)
    status = await repository.find_by_id(status_id)
    if not status:
        raise HTTPException(status_code=404, detail=f"Estado de contrato con ID {status_id} no encontrado")
    return status


# =============================================================================
# CUT PERIOD STATUSES
# =============================================================================


@router.get("/cut-period-statuses", response_model=List[CutPeriodStatusDTO], summary="Obtener estados de período de corte")
async def get_all_cut_period_statuses(db: AsyncSession = Depends(get_async_db)):
    """Obtiene la lista de estados de período de corte."""
    repository = PostgreSQLCutPeriodStatusRepository(db)
    statuses = await repository.find_all()
    return statuses


@router.get(
    "/cut-period-statuses/{status_id}",
    response_model=CutPeriodStatusDTO,
    summary="Obtener estado de período de corte por ID",
)
async def get_cut_period_status_by_id(status_id: int, db: AsyncSession = Depends(get_async_db)):
    """Obtiene un estado de período de corte específico por su ID."""
    repository = PostgreSQLCutPeriodStatusRepository(db)
    status = await repository.find_by_id(status_id)
    if not status:
        raise HTTPException(status_code=404, detail=f"Estado de período de corte con ID {status_id} no encontrado")
    return status


# =============================================================================
# PAYMENT METHODS
# =============================================================================


@router.get("/payment-methods", response_model=List[PaymentMethodDTO], summary="Obtener métodos de pago")
async def get_all_payment_methods(
    active_only: bool = Query(False, description="Filtrar solo métodos activos"), db: AsyncSession = Depends(get_async_db)
):
    """Obtiene la lista de métodos de pago."""
    repository = PostgreSQLPaymentMethodRepository(db)
    methods = await repository.find_all(active_only=active_only)
    return methods


@router.get("/payment-methods/{method_id}", response_model=PaymentMethodDTO, summary="Obtener método de pago por ID")
async def get_payment_method_by_id(method_id: int, db: AsyncSession = Depends(get_async_db)):
    """Obtiene un método de pago específico por su ID."""
    repository = PostgreSQLPaymentMethodRepository(db)
    method = await repository.find_by_id(method_id)
    if not method:
        raise HTTPException(status_code=404, detail=f"Método de pago con ID {method_id} no encontrado")
    return method


# =============================================================================
# DOCUMENT STATUSES
# =============================================================================


@router.get("/document-statuses", response_model=List[DocumentStatusDTO], summary="Obtener estados de documento")
async def get_all_document_statuses(db: AsyncSession = Depends(get_async_db)):
    """Obtiene la lista de estados de documento."""
    repository = PostgreSQLDocumentStatusRepository(db)
    statuses = await repository.find_all()
    return statuses


@router.get(
    "/document-statuses/{status_id}", response_model=DocumentStatusDTO, summary="Obtener estado de documento por ID"
)
async def get_document_status_by_id(status_id: int, db: AsyncSession = Depends(get_async_db)):
    """Obtiene un estado de documento específico por su ID."""
    repository = PostgreSQLDocumentStatusRepository(db)
    status = await repository.find_by_id(status_id)
    if not status:
        raise HTTPException(status_code=404, detail=f"Estado de documento con ID {status_id} no encontrado")
    return status


# =============================================================================
# STATEMENT STATUSES
# =============================================================================


@router.get("/statement-statuses", response_model=List[StatementStatusDTO], summary="Obtener estados de cuenta de asociado")
async def get_all_statement_statuses(db: AsyncSession = Depends(get_async_db)):
    """Obtiene la lista de estados de cuenta de asociado."""
    repository = PostgreSQLStatementStatusRepository(db)
    statuses = await repository.find_all()
    return statuses


@router.get(
    "/statement-statuses/{status_id}", response_model=StatementStatusDTO, summary="Obtener estado de cuenta por ID"
)
async def get_statement_status_by_id(status_id: int, db: AsyncSession = Depends(get_async_db)):
    """Obtiene un estado de cuenta específico por su ID."""
    repository = PostgreSQLStatementStatusRepository(db)
    status = await repository.find_by_id(status_id)
    if not status:
        raise HTTPException(status_code=404, detail=f"Estado de cuenta con ID {status_id} no encontrado")
    return status


# =============================================================================
# CONFIG TYPES
# =============================================================================


@router.get("/config-types", response_model=List[ConfigTypeDTO], summary="Obtener tipos de configuración")
async def get_all_config_types(db: AsyncSession = Depends(get_async_db)):
    """Obtiene la lista de tipos de configuración."""
    repository = PostgreSQLConfigTypeRepository(db)
    types = await repository.find_all()
    return types


@router.get("/config-types/{type_id}", response_model=ConfigTypeDTO, summary="Obtener tipo de configuración por ID")
async def get_config_type_by_id(type_id: int, db: AsyncSession = Depends(get_async_db)):
    """Obtiene un tipo de configuración específico por su ID."""
    repository = PostgreSQLConfigTypeRepository(db)
    config_type = await repository.find_by_id(type_id)
    if not config_type:
        raise HTTPException(status_code=404, detail=f"Tipo de configuración con ID {type_id} no encontrado")
    return config_type


# =============================================================================
# LEVEL CHANGE TYPES
# =============================================================================


@router.get("/level-change-types", response_model=List[LevelChangeTypeDTO], summary="Obtener tipos de cambio de nivel")
async def get_all_level_change_types(db: AsyncSession = Depends(get_async_db)):
    """Obtiene la lista de tipos de cambio de nivel."""
    repository = PostgreSQLLevelChangeTypeRepository(db)
    types = await repository.find_all()
    return types


@router.get(
    "/level-change-types/{type_id}", response_model=LevelChangeTypeDTO, summary="Obtener tipo de cambio de nivel por ID"
)
async def get_level_change_type_by_id(type_id: int, db: AsyncSession = Depends(get_async_db)):
    """Obtiene un tipo de cambio de nivel específico por su ID."""
    repository = PostgreSQLLevelChangeTypeRepository(db)
    change_type = await repository.find_by_id(type_id)
    if not change_type:
        raise HTTPException(status_code=404, detail=f"Tipo de cambio de nivel con ID {type_id} no encontrado")
    return change_type


# =============================================================================
# ASSOCIATE LEVELS
# =============================================================================


@router.get("/associate-levels", response_model=List[AssociateLevelDTO], summary="Obtener niveles de asociado")
async def get_all_associate_levels(db: AsyncSession = Depends(get_async_db)):
    """Obtiene la lista de niveles de asociado (Bronce, Plata, Oro, Platino, Diamante)."""
    repository = PostgreSQLAssociateLevelRepository(db)
    levels = await repository.find_all()
    return levels


@router.get("/associate-levels/{level_id}", response_model=AssociateLevelDTO, summary="Obtener nivel de asociado por ID")
async def get_associate_level_by_id(level_id: int, db: AsyncSession = Depends(get_async_db)):
    """Obtiene un nivel de asociado específico por su ID."""
    repository = PostgreSQLAssociateLevelRepository(db)
    level = await repository.find_by_id(level_id)
    if not level:
        raise HTTPException(status_code=404, detail=f"Nivel de asociado con ID {level_id} no encontrado")
    return level


# =============================================================================
# DOCUMENT TYPES
# =============================================================================


@router.get("/document-types", response_model=List[DocumentTypeDTO], summary="Obtener tipos de documento")
async def get_all_document_types(
    required_only: bool = Query(False, description="Filtrar solo documentos requeridos"),
    db: AsyncSession = Depends(get_async_db),
):
    """Obtiene la lista de tipos de documento."""
    repository = PostgreSQLDocumentTypeRepository(db)
    types = await repository.find_all(required_only=required_only)
    return types


@router.get("/document-types/{type_id}", response_model=DocumentTypeDTO, summary="Obtener tipo de documento por ID")
async def get_document_type_by_id(type_id: int, db: AsyncSession = Depends(get_async_db)):
    """Obtiene un tipo de documento específico por su ID."""
    repository = PostgreSQLDocumentTypeRepository(db)
    doc_type = await repository.find_by_id(type_id)
    if not doc_type:
        raise HTTPException(status_code=404, detail=f"Tipo de documento con ID {type_id} no encontrado")
    return doc_type
