"""Rutas FastAPI para audit logs"""
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_async_db
from app.modules.audit.application.dtos import (
    AuditLogResponseDTO,
    AuditLogListItemDTO,
    PaginatedAuditLogsDTO,
)
from app.modules.audit.application.use_cases import (
    ListAuditLogsUseCase,
    GetRecordHistoryUseCase,
    GetTableAuditLogsUseCase,
)
from app.modules.audit.infrastructure.repositories.pg_audit_log_repository import PgAuditLogRepository


router = APIRouter(prefix="/audit", tags=["Audit"])


def get_audit_repository(db: AsyncSession = Depends(get_async_db)) -> PgAuditLogRepository:
    """Dependency injection del repositorio"""
    return PgAuditLogRepository(db)


@router.get("", response_model=PaginatedAuditLogsDTO)
async def list_audit_logs(
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0),
    repo: PgAuditLogRepository = Depends(get_audit_repository),
):
    """Lista todos los registros de auditoría con paginación"""
    try:
        use_case = ListAuditLogsUseCase(repo)
        logs = await use_case.execute(limit, offset)
        total = await repo.count()
        
        items = [
            AuditLogListItemDTO(
                id=log.id,
                table_name=log.table_name,
                record_id=log.record_id,
                operation=log.operation,
                changed_by=log.changed_by,
                changed_at=log.changed_at,
            )
            for log in logs
        ]
        
        return PaginatedAuditLogsDTO(
            items=items,
            total=total,
            limit=limit,
            offset=offset,
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error listing audit logs: {str(e)}"
        )


@router.get("/tables/{table_name}", response_model=list[AuditLogResponseDTO])
async def get_table_audit_logs(
    table_name: str,
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0),
    repo: PgAuditLogRepository = Depends(get_audit_repository),
):
    """Obtiene registros de auditoría de una tabla específica"""
    try:
        use_case = GetTableAuditLogsUseCase(repo)
        logs = await use_case.execute(table_name, limit, offset)
        
        return [
            AuditLogResponseDTO(
                id=log.id,
                table_name=log.table_name,
                record_id=log.record_id,
                operation=log.operation,
                old_data=log.old_data,
                new_data=log.new_data,
                changed_by=log.changed_by,
                changed_at=log.changed_at,
                ip_address=log.ip_address,
                user_agent=log.user_agent,
                changed_fields=log.get_changed_fields(),
            )
            for log in logs
        ]
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error fetching table audit logs: {str(e)}"
        )


@router.get("/records/{table_name}/{record_id}", response_model=list[AuditLogResponseDTO])
async def get_record_history(
    table_name: str,
    record_id: int,
    repo: PgAuditLogRepository = Depends(get_audit_repository),
    db: AsyncSession = Depends(get_async_db),
):
    """Obtiene historial completo de cambios de un registro específico"""
    from sqlalchemy import select
    from app.modules.auth.infrastructure.models import UserModel
    
    try:
        use_case = GetRecordHistoryUseCase(repo)
        logs = await use_case.execute(table_name, record_id)
        
        # Obtener nombres de usuarios que hicieron cambios
        user_ids = list(set(log.changed_by for log in logs if log.changed_by))
        user_names = {}
        
        if user_ids:
            user_query = select(UserModel).where(UserModel.id.in_(user_ids))
            result = await db.execute(user_query)
            users = result.unique().scalars().all()
            user_names = {u.id: f"{u.first_name} {u.last_name}" for u in users}
        
        response_list = []
        for log in logs:
            response = AuditLogResponseDTO(
                id=log.id,
                table_name=log.table_name,
                record_id=log.record_id,
                operation=log.operation,
                old_data=log.old_data,
                new_data=log.new_data,
                changed_by=log.changed_by,
                changed_at=log.changed_at,
                ip_address=log.ip_address,
                user_agent=log.user_agent,
                changed_fields=log.get_changed_fields(),
            )
            # Agregar nombre del usuario como extra en new_data
            if log.changed_by and log.changed_by in user_names:
                if response.new_data is None:
                    response.new_data = {}
                response.new_data['_changed_by_name'] = user_names[log.changed_by]
            response_list.append(response)
        
        return response_list
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error fetching record history: {str(e)}"
        )


@router.get("/users/{user_id}/full-history", response_model=list[AuditLogResponseDTO])
async def get_user_full_history(
    user_id: int,
    db: AsyncSession = Depends(get_async_db),
):
    """
    Obtiene historial completo de un usuario incluyendo tablas relacionadas.
    
    Busca en: users, addresses, guarantors, beneficiaries
    """
    from sqlalchemy import select, or_, and_
    from app.modules.auth.infrastructure.models import UserModel
    from app.modules.addresses.infrastructure.models.address_model import AddressModel
    from app.modules.guarantors.infrastructure.models.guarantor_model import GuarantorModel
    from app.modules.beneficiaries.infrastructure.models.beneficiary_model import BeneficiaryModel
    from app.modules.audit.infrastructure.models.audit_log_model import AuditLogModel
    
    try:
        # Obtener IDs de registros relacionados
        address_result = await db.execute(
            select(AddressModel.id).where(AddressModel.user_id == user_id)
        )
        address_ids = [r[0] for r in address_result.all()]
        
        guarantor_result = await db.execute(
            select(GuarantorModel.id).where(GuarantorModel.user_id == user_id)
        )
        guarantor_ids = [r[0] for r in guarantor_result.all()]
        
        beneficiary_result = await db.execute(
            select(BeneficiaryModel.id).where(BeneficiaryModel.user_id == user_id)
        )
        beneficiary_ids = [r[0] for r in beneficiary_result.all()]
        
        # Construir condiciones de búsqueda
        conditions = [
            and_(AuditLogModel.table_name == 'users', AuditLogModel.record_id == user_id)
        ]
        
        if address_ids:
            conditions.append(
                and_(AuditLogModel.table_name == 'addresses', AuditLogModel.record_id.in_(address_ids))
            )
        if guarantor_ids:
            conditions.append(
                and_(AuditLogModel.table_name == 'guarantors', AuditLogModel.record_id.in_(guarantor_ids))
            )
        if beneficiary_ids:
            conditions.append(
                and_(AuditLogModel.table_name == 'beneficiaries', AuditLogModel.record_id.in_(beneficiary_ids))
            )
        
        # Buscar todos los logs
        query = (
            select(AuditLogModel)
            .where(or_(*conditions))
            .order_by(AuditLogModel.changed_at.desc())
            .limit(100)
        )
        
        result = await db.execute(query)
        logs = result.scalars().all()
        
        # Obtener nombres de usuarios que hicieron cambios
        user_ids_set = list(set(log.changed_by for log in logs if log.changed_by))
        user_names = {}
        
        if user_ids_set:
            user_query = select(UserModel).where(UserModel.id.in_(user_ids_set))
            user_result = await db.execute(user_query)
            users = user_result.unique().scalars().all()
            user_names = {u.id: f"{u.first_name} {u.last_name}" for u in users}
        
        # Construir respuesta
        response_list = []
        for log in logs:
            # Calcular campos cambiados
            changed_fields = []
            if log.old_data and log.new_data:
                for key in log.new_data:
                    if key.startswith('_'):
                        continue
                    old_val = log.old_data.get(key)
                    new_val = log.new_data.get(key)
                    if old_val != new_val:
                        changed_fields.append(key)
            
            response = AuditLogResponseDTO(
                id=log.id,
                table_name=log.table_name,
                record_id=log.record_id,
                operation=log.operation,
                old_data=log.old_data,
                new_data=log.new_data,
                changed_by=log.changed_by,
                changed_at=log.changed_at,
                ip_address=log.ip_address,
                user_agent=log.user_agent,
                changed_fields=changed_fields,
            )
            # Agregar nombre del usuario
            if log.changed_by and log.changed_by in user_names:
                if response.new_data is None:
                    response.new_data = {}
                response.new_data['_changed_by_name'] = user_names[log.changed_by]
            response_list.append(response)
        
        return response_list
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error fetching user full history: {str(e)}"
        )
