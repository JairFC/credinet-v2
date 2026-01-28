"""
Rutas FastAPI para el módulo de associates.

Endpoints:
- POST /associates → Crear asociado completo
- GET /associates → Listar asociados
- GET /associates/:userId/credit → Resumen de crédito
- GET /associates/:id/clients → Lista de clientes del asociado
"""
from typing import Optional
import asyncio
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text
import logging

from app.core.database import get_async_db
from app.core.dependencies import require_admin
from app.core.notifications import notify
from app.modules.auth.routes import get_current_user_id
from app.modules.associates.application.dtos import (
    AssociateResponseDTO,
    AssociateListItemDTO,
    AssociateCreditSummaryDTO,
    AssociateSearchItemDTO,
    PaginatedAssociatesDTO,
    CreateAssociateRequest,
)
from app.modules.associates.application.use_cases import (
    ListAssociatesUseCase,
    GetAssociateCreditUseCase,
)
from app.modules.associates.infrastructure.repositories.pg_associate_repository import PgAssociateRepository

logger = logging.getLogger(__name__)


router = APIRouter(
    prefix="/associates",
    tags=["Associates"],
    dependencies=[Depends(require_admin)]  # 🔒 Solo admins
)


def get_associate_repository(db: AsyncSession = Depends(get_async_db)) -> PgAssociateRepository:
    """Dependency injection del repositorio de asociados"""
    return PgAssociateRepository(db)


# =============================================================================
# CREATE ASSOCIATE ENDPOINT
# =============================================================================

@router.post("", status_code=status.HTTP_201_CREATED)
async def create_associate(
    request: CreateAssociateRequest,
    db: AsyncSession = Depends(get_async_db),
):
    """
    Crea un asociado completo (usuario + perfil) en una sola transacción.
    
    Steps:
    1. Valida request
    2. Hashea contraseña
    3. Crea usuario en users
    4. Crea el perfil en associate_profiles
    5. Commit o rollback automático
    
    Returns:
        Datos del asociado creado
        
    Raises:
        400: Datos duplicados (username, email, phone, contact_email)
        500: Error interno del servidor
    """
    import logging
    logger = logging.getLogger(__name__)
    logger.info(f"📥 Datos recibidos: {request.model_dump()}")
    
    from app.modules.auth.infrastructure.models import UserModel, user_roles
    from app.modules.associates.infrastructure.models import AssociateProfileModel
    from app.core.security import get_password_hash
    from sqlalchemy import insert, select
    from sqlalchemy.exc import IntegrityError
    
    try:
        # 1. Hashear contraseña
        hashed_password = get_password_hash(request.password)
        
        # 2. Construir last_name completo a partir de los apellidos
        last_name_parts = [request.paternal_last_name]
        if request.maternal_last_name:
            last_name_parts.append(request.maternal_last_name)
        full_last_name = " ".join(last_name_parts)
        
        # 3. Crear usuario
        new_user = UserModel(
            username=request.username,
            password_hash=hashed_password,
            email=request.email,
            first_name=request.first_name,
            last_name=full_last_name,
            phone_number=request.phone_number,
            curp=request.curp,
            birth_date=request.birth_date,
            active=True,
        )
        
        db.add(new_user)
        await db.flush()  # Obtener user.id sin hacer commit
        
        # 4. Asignar rol de asociado (role_id=4)
        ASSOCIATE_ROLE_ID = 4
        await db.execute(
            insert(user_roles).values(
                user_id=new_user.id,
                role_id=ASSOCIATE_ROLE_ID
            )
        )
        
        # 5. Crear perfil de asociado
        new_profile = AssociateProfileModel(
            user_id=new_user.id,
            level_id=request.level_id,
            credit_limit=request.credit_limit,
            pending_payments_total=0,
            contact_person=request.contact_person,
            contact_email=request.contact_email,
            default_commission_rate=request.default_commission_rate,
            active=True,
        )
        
        db.add(new_profile)
        await db.commit()
        await db.refresh(new_profile)
        
        response_data = {
            "success": True,
            "message": "Asociado creado exitosamente",
            "data": {
                "associate_id": new_profile.id,
                "user_id": new_user.id,
                "username": new_user.username,
                "email": new_user.email,
                "full_name": f"{new_user.first_name} {new_user.last_name}",
                "credit_limit": float(new_profile.credit_limit),
                "level_id": new_profile.level_id,
                "default_commission_rate": float(new_profile.default_commission_rate),
            }
        }
        
        # 🔔 Notificación de nuevo asociado
        asyncio.create_task(notify.send(
            title="Nuevo Asociado Registrado",
            message=f"• Nombre: {new_user.first_name} {new_user.last_name}\n"
                    f"• Usuario: {new_user.username}\n"
                    f"• Email: {new_user.email}\n"
                    f"• Nivel: {new_profile.level_id}\n"
                    f"• Límite crédito: ${float(new_profile.credit_limit):,.2f}",
            level="success",
            to_discord=True
        ))
        
        logger.info(f"📤 Enviando respuesta: {response_data}")
        return response_data
        
    except IntegrityError as e:
        await db.rollback()
        error_msg = str(e.orig).lower()
        
        if "username" in error_msg:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="El nombre de usuario ya está en uso"
            )
        elif "email" in error_msg and "users_email_key" in error_msg:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="El correo electrónico ya está registrado"
            )
        elif "phone_number" in error_msg:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="El número de teléfono ya está registrado"
            )
        elif "contact_email" in error_msg:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="El correo de contacto ya está en uso"
            )
        else:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Error de integridad: {str(e.orig)}"
            )
    
    except Exception as e:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error creating associate: {str(e)}"
        )


# =============================================================================
# EXISTING ENDPOINTS
# =============================================================================

@router.get("/search/available", response_model=list[AssociateSearchItemDTO])
async def search_available_associates(
    q: str = Query(..., min_length=2, description="Término de búsqueda (nombre, username, email)"),
    min_credit: float = Query(0, ge=0, description="Crédito disponible mínimo requerido"),
    limit: int = Query(10, ge=1, le=50, description="Máximo de resultados"),
    db: AsyncSession = Depends(get_async_db),
):
    """
    Busca asociados con crédito disponible para otorgar préstamos.
    
    Filtros aplicados:
    - Solo asociados activos
    - Con available_credit >= min_credit
    - Búsqueda por: nombre completo, username, email
    
    Args:
        q: Término de búsqueda (mínimo 2 caracteres)
        min_credit: Crédito mínimo requerido (default 0)
        limit: Máximo de resultados (1-50)
        
    Returns:
        Lista de asociados disponibles con información de crédito
        
    Ejemplos:
    - GET /associates/search/available?q=maria → Busca "maria"
    - GET /associates/search/available?q=dist&min_credit=10000 → Con mín L.10,000
    """
    try:
        from app.modules.associates.infrastructure.models import AssociateProfileModel
        from app.modules.auth.infrastructure.models import UserModel
        from sqlalchemy import func, and_, or_, select
        
        search_term = f"%{q.lower()}%"
        
        stmt = (
            select(
                AssociateProfileModel.id,
                AssociateProfileModel.user_id,
                AssociateProfileModel.level_id,
                AssociateProfileModel.credit_limit,
                AssociateProfileModel.pending_payments_total,
                AssociateProfileModel.available_credit,
                AssociateProfileModel.active,
                UserModel.username,
                UserModel.first_name,
                UserModel.last_name,
                UserModel.email,
                UserModel.phone_number,
            )
            .join(UserModel, AssociateProfileModel.user_id == UserModel.id)
            .where(
                and_(
                    AssociateProfileModel.active == True,
                    AssociateProfileModel.available_credit >= min_credit,
                    or_(
                        func.lower(UserModel.username).like(search_term),
                        func.lower(UserModel.first_name).like(search_term),
                        func.lower(UserModel.last_name).like(search_term),
                        func.lower(func.concat(UserModel.first_name, ' ', UserModel.last_name)).like(search_term),
                        func.lower(UserModel.email).like(search_term),
                    )
                )
            )
            .order_by(AssociateProfileModel.available_credit.desc())
            .limit(limit)
        )
        
        result = await db.execute(stmt)
        rows = result.all()
        
        # Construir DTOs
        associates = []
        for row in rows:
            credit_limit = float(row.credit_limit)
            pending_payments_total = float(row.pending_payments_total)
            available_credit = float(row.available_credit)
            credit_usage_percentage = (pending_payments_total / credit_limit * 100) if credit_limit > 0 else 0
            
            associates.append(
                AssociateSearchItemDTO(
                    id=row.id,
                    user_id=row.user_id,
                    username=row.username,
                    full_name=f"{row.first_name} {row.last_name}",
                    email=row.email,
                    phone_number=row.phone_number,
                    level_id=row.level_id,
                    credit_limit=row.credit_limit,
                    pending_payments_total=row.pending_payments_total,
                    available_credit=row.available_credit,
                    credit_usage_percentage=credit_usage_percentage,
                    active=row.active,
                    can_grant_loans=available_credit > 0,
                )
            )
        
        return associates
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error searching available associates: {str(e)}"
        )


@router.get("", response_model=PaginatedAssociatesDTO)
async def list_associates(
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0),
    active_only: bool = Query(True),
    search: Optional[str] = Query(None, min_length=1, description="Buscar por nombre, username o email"),
    repo: PgAssociateRepository = Depends(get_associate_repository),
    db: AsyncSession = Depends(get_async_db),
):
    """
    Lista todos los asociados con paginación y búsqueda opcional.
    
    Args:
        limit: Máximo de registros (1-100)
        offset: Desplazamiento para paginación
        active_only: Si True, solo asociados activos
        search: Término de búsqueda (nombre, username, email)
        
    Returns:
        Lista paginada de asociados con información de usuario
    """
    from sqlalchemy import select, or_
    from app.modules.associates.infrastructure.models import AssociateProfileModel
    from app.modules.auth.infrastructure.models import UserModel
    
    try:
        # Query con JOIN para obtener datos del usuario y deuda real
        from sqlalchemy import func, text
        
        # ⭐ Subquery para contar períodos con deuda desde associate_accumulated_balances (la tabla real)
        pending_debts_subq = (
            select(func.count(text('*')))
            .select_from(text('associate_accumulated_balances aab'))
            .where(
                text('aab.user_id = users.id'),
                text('aab.accumulated_debt > 0')
            )
            .correlate(UserModel)
            .scalar_subquery()
        )
        
        stmt = (
            select(
                AssociateProfileModel.id,
                AssociateProfileModel.user_id,
                AssociateProfileModel.credit_limit,
                AssociateProfileModel.pending_payments_total,
                AssociateProfileModel.available_credit,
                AssociateProfileModel.consolidated_debt,
                pending_debts_subq.label('pending_debts_count'),
                AssociateProfileModel.active,
                AssociateProfileModel.level_id,
                UserModel.username,
                UserModel.first_name,
                UserModel.last_name,
                UserModel.email,
            )
            .join(UserModel, AssociateProfileModel.user_id == UserModel.id)
        )
        
        if active_only:
            stmt = stmt.where(AssociateProfileModel.active == True)
        
        # Filtro de búsqueda
        if search and search.strip():
            search_term = f"%{search.lower().strip()}%"
            stmt = stmt.where(
                or_(
                    func.lower(UserModel.username).like(search_term),
                    func.lower(UserModel.first_name).like(search_term),
                    func.lower(UserModel.last_name).like(search_term),
                    func.lower(func.concat(UserModel.first_name, ' ', UserModel.last_name)).like(search_term),
                    func.lower(UserModel.email).like(search_term),
                )
            )
        
        # Contar total antes de paginar (con filtros aplicados)
        count_stmt = select(func.count()).select_from(stmt.subquery())
        total_result = await db.execute(count_stmt)
        total = total_result.scalar() or 0
        
        stmt = stmt.order_by(AssociateProfileModel.id).limit(limit).offset(offset)
        
        result = await db.execute(stmt)
        rows = result.all()
        
        items = [
            AssociateListItemDTO(
                id=row.id,
                user_id=row.user_id,
                username=row.username,
                full_name=f"{row.first_name} {row.last_name}",
                email=row.email,
                level_id=row.level_id,
                credit_limit=row.credit_limit,
                pending_payments_total=row.pending_payments_total,
                available_credit=row.available_credit,
                consolidated_debt=row.consolidated_debt,
                pending_debts_count=row.pending_debts_count or 0,
                active=row.active,
            )
            for row in rows
        ]
        
        return PaginatedAssociatesDTO(
            items=items,
            total=total,
            limit=limit,
            offset=offset,
        )
    except Exception as e:
        import logging
        logger = logging.getLogger(__name__)
        logger.error(f"Error listing associates: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error listing associates: {str(e)}"
        )


@router.get("/{associate_id}", response_model=AssociateResponseDTO)
async def get_associate_detail(
    associate_id: int,
    db: AsyncSession = Depends(get_async_db),
):
    """
    Obtiene el detalle completo de un asociado por ID con información del usuario
    
    Args:
        associate_id: ID del perfil de asociado
        
    Returns:
        Detalle completo del asociado con datos del usuario
    """
    from sqlalchemy import select
    from app.modules.associates.infrastructure.models import AssociateProfileModel
    from app.modules.auth.infrastructure.models import UserModel
    
    try:
        # Query con JOIN para obtener datos del asociado y usuario
        stmt = (
            select(
                AssociateProfileModel.id,
                AssociateProfileModel.user_id,
                AssociateProfileModel.level_id,
                AssociateProfileModel.contact_person,
                AssociateProfileModel.contact_email,
                AssociateProfileModel.default_commission_rate,
                AssociateProfileModel.active,
                AssociateProfileModel.consecutive_full_credit_periods,
                AssociateProfileModel.consecutive_on_time_payments,
                AssociateProfileModel.clients_in_agreement,
                AssociateProfileModel.last_level_evaluation_date,
                AssociateProfileModel.pending_payments_total,
                AssociateProfileModel.credit_limit,
                AssociateProfileModel.available_credit,
                AssociateProfileModel.credit_last_updated,
                AssociateProfileModel.consolidated_debt,
                AssociateProfileModel.created_at,
                AssociateProfileModel.updated_at,
                UserModel.username,
                UserModel.email,
                UserModel.phone_number,
                UserModel.first_name,
                UserModel.last_name,
            )
            .join(UserModel, AssociateProfileModel.user_id == UserModel.id)
            .where(AssociateProfileModel.id == associate_id)
        )
        
        result = await db.execute(stmt)
        row = result.one_or_none()
        
        if not row:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Asociado con ID {associate_id} no encontrado"
            )
        
        # Calcular porcentaje de uso de crédito
        credit_usage_percentage = None
        if row.credit_limit and row.credit_limit > 0:
            credit_usage_percentage = float((row.pending_payments_total / row.credit_limit) * 100)
        
        return AssociateResponseDTO(
            id=row.id,
            user_id=row.user_id,
            level_id=row.level_id,
            contact_person=row.contact_person,
            contact_email=row.contact_email,
            default_commission_rate=row.default_commission_rate,
            active=row.active,
            consecutive_full_credit_periods=row.consecutive_full_credit_periods,
            consecutive_on_time_payments=row.consecutive_on_time_payments,
            clients_in_agreement=row.clients_in_agreement,
            last_level_evaluation_date=row.last_level_evaluation_date,
            pending_payments_total=row.pending_payments_total,
            credit_limit=row.credit_limit,
            available_credit=row.available_credit,
            credit_last_updated=row.credit_last_updated,
            consolidated_debt=row.consolidated_debt,
            created_at=row.created_at,
            updated_at=row.updated_at,
            credit_usage_percentage=credit_usage_percentage,
            # Datos del usuario
            username=row.username,
            email=row.email,
            phone_number=row.phone_number,
            first_name=row.first_name,
            last_name=row.last_name,
            full_name=f"{row.first_name} {row.last_name}",
        )
    except HTTPException:
        raise
    except Exception as e:
        import logging
        logger = logging.getLogger(__name__)
        logger.error(f"Error getting associate detail: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error getting associate detail: {str(e)}"
        )


@router.get("/by-user/{user_id}", response_model=AssociateResponseDTO)
async def get_associate_by_user_id(
    user_id: int,
    db: AsyncSession = Depends(get_async_db),
):
    """
    Obtiene el detalle completo de un asociado por USER_ID (no profile_id).
    Útil para enlaces desde statements donde se usa user_id.
    
    Args:
        user_id: ID del usuario (tabla users)
        
    Returns:
        Detalle completo del asociado
    """
    from sqlalchemy import select
    from app.modules.associates.infrastructure.models import AssociateProfileModel
    from app.modules.auth.infrastructure.models import UserModel
    
    try:
        stmt = (
            select(
                AssociateProfileModel.id,
                AssociateProfileModel.user_id,
                AssociateProfileModel.level_id,
                AssociateProfileModel.contact_person,
                AssociateProfileModel.contact_email,
                AssociateProfileModel.default_commission_rate,
                AssociateProfileModel.active,
                AssociateProfileModel.consecutive_full_credit_periods,
                AssociateProfileModel.consecutive_on_time_payments,
                AssociateProfileModel.clients_in_agreement,
                AssociateProfileModel.last_level_evaluation_date,
                AssociateProfileModel.pending_payments_total,
                AssociateProfileModel.credit_limit,
                AssociateProfileModel.available_credit,
                AssociateProfileModel.credit_last_updated,
                AssociateProfileModel.consolidated_debt,
                AssociateProfileModel.created_at,
                AssociateProfileModel.updated_at,
                UserModel.username,
                UserModel.email,
                UserModel.phone_number,
                UserModel.first_name,
                UserModel.last_name,
            )
            .join(UserModel, AssociateProfileModel.user_id == UserModel.id)
            .where(AssociateProfileModel.user_id == user_id)  # Buscar por user_id
        )
        
        result = await db.execute(stmt)
        row = result.one_or_none()
        
        if not row:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Associate with user_id {user_id} not found"
            )
        
        return AssociateResponseDTO(
            id=row.id,
            user_id=row.user_id,
            username=row.username,
            email=row.email,
            phone_number=row.phone_number,
            first_name=row.first_name,
            last_name=row.last_name,
            full_name=f"{row.first_name} {row.last_name}".strip(),
            level_id=row.level_id,
            contact_person=row.contact_person,
            contact_email=row.contact_email,
            default_commission_rate=float(row.default_commission_rate),
            active=row.active,
            consecutive_full_credit_periods=row.consecutive_full_credit_periods,
            consecutive_on_time_payments=row.consecutive_on_time_payments,
            clients_in_agreement=row.clients_in_agreement,
            last_level_evaluation_date=row.last_level_evaluation_date,
            pending_payments_total=float(row.pending_payments_total) if row.pending_payments_total else 0.0,
            credit_limit=float(row.credit_limit) if row.credit_limit else 0.0,
            available_credit=float(row.available_credit) if row.available_credit else 0.0,
            credit_last_updated=row.credit_last_updated,
            consolidated_debt=float(row.consolidated_debt) if row.consolidated_debt else 0.0,
            created_at=row.created_at,
            updated_at=row.updated_at,
        )
        
    except HTTPException:
        raise
    except Exception as e:
        import logging
        logger = logging.getLogger(__name__)
        logger.error(f"Error getting associate by user_id: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error getting associate: {str(e)}"
        )


@router.get("/{user_id}/credit", response_model=AssociateCreditSummaryDTO)
async def get_associate_credit(
    user_id: int,
    repo: PgAssociateRepository = Depends(get_associate_repository),
):
    """
    Obtiene el resumen de crédito de un asociado.
    
    Args:
        user_id: ID del usuario asociado
        
    Returns:
        Resumen de crédito del asociado
        
    Raises:
        404: Si el asociado no existe
    """
    try:
        use_case = GetAssociateCreditUseCase(repo)
        associate = await use_case.execute(user_id)
        
        if not associate:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Associate with user_id {user_id} not found"
            )
        
        return AssociateCreditSummaryDTO(
            associate_id=associate.id,
            user_id=associate.user_id,
            credit_limit=associate.credit_limit,
            pending_payments_total=associate.pending_payments_total,
            available_credit=associate.available_credit,
            credit_usage_percentage=associate.get_credit_usage_percentage(),
            active_loans_count=0,  # TODO: Contar loans activos
            total_disbursed=associate.pending_payments_total,
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error fetching associate credit: {str(e)}"
        )


# =============================================================================
# ⭐ LISTA DE CLIENTES POR ASOCIADO
# =============================================================================

@router.get("/{associate_id}/clients")
async def get_associate_clients(
    associate_id: int,
    db: AsyncSession = Depends(get_async_db),
    status_filter: Optional[str] = Query(None, description="Filtrar por status: ACTIVE, COMPLETED, DEFAULTED, etc"),
    limit: int = Query(50, ge=1, le=200, description="Límite de resultados"),
    offset: int = Query(0, ge=0, description="Offset para paginación"),
):
    """
    Lista todos los clientes (borrowers) que han solicitado préstamos con este asociado.
    
    Incluye información de:
    - Datos del cliente (nombre, teléfono, email)
    - Total de préstamos con el asociado
    - Monto total prestado
    - Estado actual de la relación
    
    Args:
        associate_id: ID del perfil de asociado
        status_filter: Filtrar por estado del préstamo (ACTIVE, COMPLETED, etc)
        limit: Límite de resultados (default 50)
        offset: Offset para paginación
    
    Returns:
        Lista paginada de clientes con estadísticas
    """
    from sqlalchemy import text
    import logging
    
    logger = logging.getLogger(__name__)
    
    try:
        # Verificar que existe el asociado y obtener user_id
        check = await db.execute(
            text("SELECT id, user_id FROM associate_profiles WHERE id = :id"),
            {"id": associate_id}
        )
        profile = check.fetchone()
        
        if not profile:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Asociado {associate_id} no encontrado"
            )
        
        associate_user_id = profile.user_id
        
        # Construir query base
        base_query = """
        WITH client_stats AS (
            SELECT 
                l.user_id as client_user_id,
                u.first_name,
                u.last_name,
                u.phone_number,
                u.email,
                u.curp,
                COUNT(l.id) as total_loans,
                SUM(l.amount) as total_amount_loaned,
                SUM(CASE WHEN ls.name = 'ACTIVE' THEN 1 ELSE 0 END) as active_loans,
                SUM(CASE WHEN ls.name = 'COMPLETED' OR ls.name = 'PAID' THEN 1 ELSE 0 END) as completed_loans,
                SUM(CASE WHEN ls.name = 'DEFAULTED' THEN 1 ELSE 0 END) as defaulted_loans,
                MIN(l.approved_at) as first_loan_date,
                MAX(l.approved_at) as last_loan_date,
                CASE 
                    WHEN SUM(CASE WHEN ls.name = 'ACTIVE' THEN 1 ELSE 0 END) > 0 THEN 'ACTIVE'
                    WHEN SUM(CASE WHEN ls.name = 'DEFAULTED' THEN 1 ELSE 0 END) > 0 THEN 'DEFAULTED'
                    WHEN SUM(CASE WHEN ls.name = 'COMPLETED' OR ls.name = 'PAID' THEN 1 ELSE 0 END) > 0 THEN 'GOOD_STANDING'
                    ELSE 'INACTIVE'
                END as client_status
            FROM loans l
            JOIN users u ON u.id = l.user_id
            JOIN loan_statuses ls ON ls.id = l.status_id
            WHERE l.associate_user_id = :associate_user_id
        """
        
        # Aplicar filtro por status si se especifica
        if status_filter:
            if status_filter == "GOOD_STANDING":
                base_query += " AND ls.name IN ('COMPLETED', 'PAID')"
            else:
                base_query += f" AND ls.name = '{status_filter}'"
        
        base_query += """
            GROUP BY l.user_id, u.first_name, u.last_name, u.phone_number, u.email, u.curp
        )
        SELECT 
            cs.*,
            (SELECT COUNT(*) FROM client_stats) as total_count
        FROM client_stats cs
        ORDER BY cs.last_loan_date DESC NULLS LAST
        LIMIT :limit OFFSET :offset
        """
        
        result = await db.execute(
            text(base_query),
            {
                "associate_user_id": associate_user_id,
                "limit": limit,
                "offset": offset
            }
        )
        
        rows = result.fetchall()
        
        if not rows:
            return {
                "success": True,
                "data": {
                    "associate_id": associate_id,
                    "clients": [],
                    "total": 0,
                    "limit": limit,
                    "offset": offset
                }
            }
        
        total_count = rows[0].total_count if rows else 0
        
        clients = []
        for row in rows:
            clients.append({
                "client_user_id": row.client_user_id,
                "first_name": row.first_name,
                "last_name": row.last_name,
                "full_name": f"{row.first_name} {row.last_name}".strip(),
                "phone_number": row.phone_number,
                "email": row.email,
                "curp": row.curp,
                "total_loans": row.total_loans,
                "total_amount_loaned": float(row.total_amount_loaned) if row.total_amount_loaned else 0,
                "active_loans": row.active_loans,
                "completed_loans": row.completed_loans,
                "defaulted_loans": row.defaulted_loans,
                "first_loan_date": row.first_loan_date.isoformat() if row.first_loan_date else None,
                "last_loan_date": row.last_loan_date.isoformat() if row.last_loan_date else None,
                "client_status": row.client_status
            })
        
        return {
            "success": True,
            "data": {
                "associate_id": associate_id,
                "clients": clients,
                "total": total_count,
                "limit": limit,
                "offset": offset
            }
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error listando clientes del asociado: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error obteniendo clientes del asociado: {str(e)}"
        )


# =============================================================================
# ⭐ NUEVOS ENDPOINTS FASE 6 - DEUDA Y PAGOS
# =============================================================================

from pydantic import BaseModel, Field
from typing import Optional

class RegisterDebtPaymentRequest(BaseModel):
    """DTO para registrar abono a deuda"""
    payment_amount: float = Field(..., gt=0, description="Monto del abono")
    payment_method_id: int = Field(..., description="ID del método de pago")
    payment_reference: Optional[str] = Field(None, max_length=100, description="Referencia del pago")
    notes: Optional[str] = Field(None, description="Notas adicionales")


@router.post("/{associate_id}/debt-payments", status_code=status.HTTP_201_CREATED)
async def register_debt_payment(
    associate_id: int,
    request: RegisterDebtPaymentRequest,
    db: AsyncSession = Depends(get_async_db),
):
    """
    Registra abono a deuda acumulada usando FIFO sobre balances reales.
    
    **Lógica FIFO v2 (usa associate_accumulated_balances):**
    1. Obtiene items de deuda desde associate_accumulated_balances
    2. Ordena por created_at ASC (más antiguo primero)
    3. Aplica el pago reduciendo accumulated_debt
    4. Actualiza consolidated_debt en associate_profiles
    5. Libera crédito automáticamente (available_credit aumenta)
    6. Registra detalle en JSONB applied_breakdown_items
    
    **Returns:** JSON con items liquidados, deuda restante y crédito liberado
    """
    from sqlalchemy import text
    import logging
    
    logger = logging.getLogger(__name__)
    
    try:
        # Verificar que existe el asociado
        check = await db.execute(
            text("SELECT id, consolidated_debt FROM associate_profiles WHERE id = :id"),
            {"id": associate_id}
        )
        profile = check.fetchone()
        
        if not profile:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Asociado {associate_id} no encontrado"
            )
        
        if float(profile.consolidated_debt) <= 0:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="El asociado no tiene deuda pendiente"
            )
        
        # Llamar a la función FIFO v2
        result = await db.execute(
            text("""
                SELECT * FROM apply_debt_payment_v2(
                    p_associate_profile_id := :associate_id,
                    p_payment_amount := :payment_amount,
                    p_payment_method_id := :payment_method_id,
                    p_payment_reference := :payment_reference,
                    p_registered_by := 1,
                    p_notes := :notes
                )
            """),
            {
                "associate_id": associate_id,
                "payment_amount": request.payment_amount,
                "payment_method_id": request.payment_method_id,
                "payment_reference": request.payment_reference,
                "notes": request.notes
            }
        )
        
        row = result.fetchone()
        await db.commit()
        
        logger.info(f"✅ Abono registrado: ${request.payment_amount} para asociado {associate_id}")
        
        return {
            "success": True,
            "message": f"Abono de ${request.payment_amount:,.2f} aplicado exitosamente",
            "data": {
                "payment_id": row[0],
                "amount_applied": float(row[1]),
                "remaining_debt": float(row[2]),
                "applied_items": row[3],
                "credit_released": float(row[4])
            }
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error registrando abono: {str(e)}", exc_info=True)
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error registrando abono: {str(e)}"
        )


@router.get("/{associate_id}/debt-summary")
async def get_debt_summary(
    associate_id: int,
    db: AsyncSession = Depends(get_async_db),
):
    """
    Resumen de deuda del asociado (usa vista v_associate_real_debt_summary).
    
    **Returns:**
    - Deuda total real (desde associate_accumulated_balances)
    - Períodos con deuda
    - Total pagado a deuda
    - Fechas clave
    - Crédito disponible
    """
    from sqlalchemy import text
    
    result = await db.execute(
        text("""
            SELECT 
                associate_profile_id,
                user_id,
                associate_name,
                total_debt,
                periods_with_debt,
                oldest_debt_date,
                newest_debt_date,
                profile_consolidated_debt,
                credit_limit,
                available_credit,
                pending_payments_total,
                total_paid_to_debt,
                total_payments_count,
                last_payment_date
            FROM v_associate_real_debt_summary
            WHERE associate_profile_id = :id
        """),
        {"id": associate_id}
    )
    
    row = result.fetchone()
    
    if not row:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Asociado {associate_id} no encontrado"
        )
    
    return {
        "success": True,
        "data": {
            "associate_profile_id": row[0],
            "user_id": row[1],
            "associate_name": row[2],
            "total_debt": float(row[3]),
            "periods_with_debt": row[4],
            "oldest_debt_date": row[5].isoformat() if row[5] else None,
            "newest_debt_date": row[6].isoformat() if row[6] else None,
            "profile_consolidated_debt": float(row[7]),
            "credit_limit": float(row[8]),
            "available_credit": float(row[9]),
            "pending_payments_total": float(row[10]),
            "total_paid_to_debt": float(row[11]),
            "total_payments_count": row[12],
            "last_payment_date": row[13].isoformat() if row[13] else None
        }
    }


@router.get("/{associate_id}/all-payments")
async def get_all_payments(
    associate_id: int,
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_async_db),
):
    """
    Historial unificado de TODOS los pagos (usa vista v_associate_all_payments).
    
    **Incluye:**
    - Abonos a saldo actual (associate_statement_payments)
    - Abonos a deuda acumulada (associate_debt_payments)
    """
    from sqlalchemy import text
    
    result = await db.execute(
        text("""
            SELECT 
                id, payment_type, associate_profile_id, associate_name,
                payment_amount, payment_date, payment_method, payment_reference,
                cut_period_id, period_start, period_end, notes, created_at
            FROM v_associate_all_payments
            WHERE associate_profile_id = :id
            ORDER BY payment_date DESC, created_at DESC
            LIMIT :limit OFFSET :offset
        """),
        {"id": associate_id, "limit": limit, "offset": offset}
    )
    
    rows = result.fetchall()
    
    return {
        "success": True,
        "data": {
            "associate_profile_id": associate_id,
            "total": len(rows),
            "limit": limit,
            "offset": offset,
            "payments": [
                {
                    "id": r[0],
                    "payment_type": r[1],
                    "payment_amount": float(r[4]),
                    "payment_date": r[5].isoformat(),
                    "payment_method": r[6],
                    "payment_reference": r[7],
                    "cut_period_id": r[8],
                    "period_start": r[9].isoformat() if r[9] else None,
                    "period_end": r[10].isoformat() if r[10] else None,
                    "notes": r[11],
                    "created_at": r[12].isoformat()
                }
                for r in rows
            ]
        }
    }



# =============================================================================
# VALIDATION ENDPOINT
# =============================================================================

@router.get(
    "/validate/contact-email/{email}",
    status_code=status.HTTP_200_OK,
    summary="Validate Contact Email",
    description="Check if contact email is available."
)
async def validate_contact_email(
    email: str,
    db: AsyncSession = Depends(get_async_db)
):
    """Verifica si un email de contacto está disponible"""
    try:
        from sqlalchemy import select, exists as sql_exists
        from app.modules.associates.infrastructure.models import AssociateProfileModel
        
        result = await db.execute(
            select(sql_exists().where(AssociateProfileModel.contact_email == email))
        )
        exists = result.scalar()
        
        return {
            "available": not exists,
            "message": "Email de contacto disponible" if not exists else "Email de contacto ya registrado"
        }
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error validating contact email: {str(e)}"
        )


# =============================================================================
# DEBT HISTORY ENDPOINT
# =============================================================================

@router.get(
    "/{associate_id}/debt-history",
    status_code=status.HTTP_200_OK,
    summary="Get Associate Debt History",
    description="Obtiene el historial de deudas acumuladas del asociado con detalles de cada período."
)
async def get_associate_debt_history(
    associate_id: int,
    db: AsyncSession = Depends(get_async_db)
):
    """
    Retorna el historial completo de deudas acumuladas del asociado.
    
    Incluye:
    - Balance acumulado por período
    - Detalles de cada deuda (statement origen, montos, fechas)
    - Total de deuda pendiente
    """
    from sqlalchemy import text
    
    try:
        # Verificar que existe el asociado
        associate_check = await db.execute(
            text("SELECT id, user_id FROM associate_profiles WHERE id = :id"),
            {"id": associate_id}
        )
        associate = associate_check.fetchone()
        
        if not associate:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Asociado {associate_id} no encontrado"
            )
        
        user_id = associate.user_id
        
        # Obtener historial de deudas con detalles del período
        result = await db.execute(
            text("""
            SELECT 
                aab.id,
                aab.cut_period_id,
                cp.cut_code,
                cp.period_start_date,
                cp.period_end_date,
                aab.accumulated_debt,
                aab.debt_details,
                aab.created_at,
                aab.updated_at
            FROM associate_accumulated_balances aab
            JOIN cut_periods cp ON cp.id = aab.cut_period_id
            WHERE aab.user_id = :user_id
            ORDER BY cp.period_end_date DESC
            """),
            {"user_id": user_id}
        )
        
        debts = result.fetchall()
        
        # Calcular totales
        total_debt = sum(float(d.accumulated_debt) for d in debts)
        
        # Formatear respuesta
        debt_history = []
        for d in debts:
            # Parsear debt_details si es string
            details = d.debt_details
            if isinstance(details, str):
                import json
                details = json.loads(details)
            
            debt_history.append({
                "id": d.id,
                "period_id": d.cut_period_id,
                "period_code": d.cut_code,
                "period_start": d.period_start_date.isoformat() if d.period_start_date else None,
                "period_end": d.period_end_date.isoformat() if d.period_end_date else None,
                "accumulated_debt": float(d.accumulated_debt),
                "details": details or [],
                "created_at": d.created_at.isoformat() if d.created_at else None,
                "updated_at": d.updated_at.isoformat() if d.updated_at else None
            })
        
        return {
            "success": True,
            "data": {
                "associate_id": associate_id,
                "user_id": user_id,
                "total_debt": total_debt,
                "periods_with_debt": len(debts),
                "debt_history": debt_history
            }
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error obteniendo historial de deudas: {str(e)}"
        )


# =============================================================================
# GESTIÓN DE ROLES - Promover Cliente a Asociado / Agregar rol de Cliente
# =============================================================================

from pydantic import BaseModel, Field

class PromoteToAssociateRequest(BaseModel):
    """Request body para promover cliente a asociado"""
    level_id: int = Field(..., ge=1, le=5, description="Nivel de asociado (1=Bronce, 2=Plata, 3=Oro, 4=Platino, 5=Diamante)")
    
    class Config:
        json_schema_extra = {
            "example": {
                "level_id": 2
            }
        }


# Mapeo de niveles a límites de crédito
LEVEL_CREDIT_LIMITS = {
    1: 25000,    # Bronce
    2: 300000,   # Plata
    3: 600000,   # Oro
    4: 900000,   # Platino
    5: 5000000,  # Diamante
}


@router.get("/check-user/{user_id}")
async def check_user_for_promotion(
    user_id: int,
    db: AsyncSession = Depends(get_async_db),
):
    """
    Verifica un usuario antes de promoverlo a asociado.
    
    Retorna información del usuario incluyendo:
    - Datos personales
    - Roles actuales
    - Si tiene dirección, aval, beneficiario
    - Si ya es asociado
    
    Args:
        user_id: ID del usuario a verificar
        
    Returns:
        Información completa del usuario para tomar decisión de promoción
    """
    from sqlalchemy import select
    from app.modules.auth.infrastructure.models import UserModel, user_roles
    from app.modules.associates.infrastructure.models import AssociateProfileModel
    from app.modules.addresses.infrastructure.models import AddressModel
    from app.modules.guarantors.infrastructure.models import GuarantorModel
    from app.modules.beneficiaries.infrastructure.models import BeneficiaryModel
    
    try:
        # 1. Obtener usuario
        user_query = select(UserModel).where(UserModel.id == user_id)
        result = await db.execute(user_query)
        user = result.unique().scalar_one_or_none()  # unique() requerido por lazy="joined"
        
        if not user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Usuario {user_id} no encontrado"
            )
        
        # 2. Obtener roles
        roles_query = text("""
            SELECT r.id, r.name FROM user_roles ur
            JOIN roles r ON ur.role_id = r.id
            WHERE ur.user_id = :user_id
        """)
        roles_result = await db.execute(roles_query, {"user_id": user_id})
        roles = [{"id": r.id, "name": r.name} for r in roles_result.fetchall()]
        
        # 3. Verificar perfil de asociado
        profile_query = select(AssociateProfileModel).where(AssociateProfileModel.user_id == user_id)
        profile_result = await db.execute(profile_query)
        associate_profile = profile_result.scalar_one_or_none()
        
        # 4. Verificar datos adicionales
        address_result = await db.execute(select(AddressModel).where(AddressModel.user_id == user_id))
        has_address = address_result.scalar_one_or_none() is not None
        
        guarantor_result = await db.execute(select(GuarantorModel).where(GuarantorModel.user_id == user_id))
        has_guarantor = guarantor_result.scalar_one_or_none() is not None
        
        beneficiary_result = await db.execute(select(BeneficiaryModel).where(BeneficiaryModel.user_id == user_id))
        has_beneficiary = beneficiary_result.scalar_one_or_none() is not None
        
        return {
            "success": True,
            "data": {
                "user_id": user_id,
                "username": user.username,
                "full_name": f"{user.first_name} {user.last_name}",
                "email": user.email,
                "phone": user.phone_number,
                "active": user.active,
                "roles": roles,
                "is_client": any(r["id"] == 5 for r in roles),
                "is_associate": any(r["id"] == 4 for r in roles),
                "has_associate_profile": associate_profile is not None,
                "associate_profile": {
                    "id": associate_profile.id,
                    "level_id": associate_profile.level_id,
                    "credit_limit": float(associate_profile.credit_limit),
                    "available_credit": float(associate_profile.available_credit) if associate_profile.available_credit else 0,
                } if associate_profile else None,
                "existing_data": {
                    "has_address": has_address,
                    "has_guarantor": has_guarantor,
                    "has_beneficiary": has_beneficiary,
                },
                "can_promote_to_associate": associate_profile is None,
                "can_add_client_role": not any(r["id"] == 5 for r in roles),
            }
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error verificando usuario: {str(e)}"
        )


async def _create_audit_log(
    db: AsyncSession,
    table_name: str,
    record_id: int,
    operation: str,
    old_data: dict = None,
    new_data: dict = None,
    changed_by: int = None
):
    """Helper para crear registro de auditoría."""
    from app.modules.audit.infrastructure.models import AuditLogModel
    
    audit = AuditLogModel(
        table_name=table_name,
        record_id=record_id,
        operation=operation,
        old_data=old_data,
        new_data=new_data,
        changed_by=changed_by
    )
    db.add(audit)
    # No hacemos commit aquí - se hace en la transacción principal


@router.post("/promote-to-associate/{user_id}", status_code=status.HTTP_201_CREATED)
async def promote_client_to_associate(
    user_id: int,
    request: PromoteToAssociateRequest,
    db: AsyncSession = Depends(get_async_db),
    current_user_id: int = Depends(get_current_user_id),
):
    """
    Promueve un cliente existente a asociado (agrega rol de asociado y crea perfil).
    
    El usuario mantiene su rol de cliente si lo tenía.
    
    Args:
        user_id: ID del usuario a promover
        level_id: Nivel de asociado (1-5)
        credit_limit: Límite de crédito inicial
        
    Returns:
        Datos del nuevo perfil de asociado
    """
    from sqlalchemy import insert, select
    from app.modules.auth.infrastructure.models import UserModel, user_roles
    from app.modules.associates.infrastructure.models import AssociateProfileModel
    
    try:
        # 1. Verificar que el usuario existe
        user_query = select(UserModel).where(UserModel.id == user_id)
        result = await db.execute(user_query)
        user = result.unique().scalar_one_or_none()  # unique() requerido por lazy="joined"
        
        if not user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Usuario {user_id} no encontrado"
            )
        
        # 2. Verificar que no tenga ya un perfil de asociado
        profile_query = select(AssociateProfileModel).where(AssociateProfileModel.user_id == user_id)
        result = await db.execute(profile_query)
        existing_profile = result.scalar_one_or_none()
        
        if existing_profile:
            # Ya es asociado - retornar información en lugar de error
            return {
                "success": True,
                "message": f"{user.first_name} {user.last_name} ya es asociado",
                "data": {
                    "user_id": user_id,
                    "associate_profile_id": existing_profile.id,
                    "level_id": existing_profile.level_id,
                    "credit_limit": float(existing_profile.credit_limit),
                    "already_associate": True
                }
            }
        
        # 3. Verificar si ya tiene el rol de asociado
        ASSOCIATE_ROLE_ID = 4
        role_check = await db.execute(
            select(user_roles).where(
                user_roles.c.user_id == user_id,
                user_roles.c.role_id == ASSOCIATE_ROLE_ID
            )
        )
        has_role = role_check.fetchone()
        
        role_was_added = False
        if not has_role:
            # Agregar rol de asociado
            await db.execute(
                insert(user_roles).values(
                    user_id=user_id,
                    role_id=ASSOCIATE_ROLE_ID
                )
            )
            role_was_added = True
        
        # 4. Obtener límite de crédito según el nivel
        level_id = request.level_id
        credit_limit = LEVEL_CREDIT_LIMITS.get(level_id, 25000)
        
        # 5. Crear perfil de asociado
        new_profile = AssociateProfileModel(
            user_id=user_id,
            level_id=level_id,
            credit_limit=credit_limit,
            pending_payments_total=0,
            default_commission_rate=5.0,  # Valor por defecto (no se usa realmente)
            active=True,
        )
        
        db.add(new_profile)
        await db.flush()  # Para obtener el ID del perfil
        
        # 6. Registrar en auditoría
        await _create_audit_log(
            db=db,
            table_name="associate_profiles",
            record_id=new_profile.id,
            operation="INSERT",
            new_data={
                "user_id": user_id,
                "level_id": level_id,
                "credit_limit": float(credit_limit),
                "promoted_from_client": True,
                "role_added": role_was_added
            },
            changed_by=current_user_id
        )
        
        # También registrar el cambio de rol si se agregó
        if role_was_added:
            await _create_audit_log(
                db=db,
                table_name="user_roles",
                record_id=user_id,
                operation="INSERT",
                new_data={
                    "user_id": user_id,
                    "role_id": ASSOCIATE_ROLE_ID,
                    "role_name": "asociado",
                    "action": "promote_to_associate"
                },
                changed_by=current_user_id
            )
        
        await db.commit()
        await db.refresh(new_profile)
        
        logger.info(f"Usuario {user_id} promovido a asociado por usuario {current_user_id}")
        
        # 🔔 Notificación de promoción a asociado
        asyncio.create_task(notify.send(
            title="Cliente Promovido a Asociado",
            message=f"• Nombre: {user.first_name} {user.last_name}\n"
                    f"• Usuario: {user.username}\n"
                    f"• Nivel: {new_profile.level_id}\n"
                    f"• Límite crédito: ${float(new_profile.credit_limit):,.2f}\n"
                    f"• Promovido por: Usuario #{current_user_id}",
            level="success",
            to_discord=True
        ))
        
        return {
            "success": True,
            "message": f"Usuario {user.first_name} {user.last_name} promovido a asociado",
            "data": {
                "user_id": user_id,
                "associate_profile_id": new_profile.id,
                "level_id": new_profile.level_id,
                "credit_limit": float(new_profile.credit_limit),
                "available_credit": float(new_profile.credit_limit),
                "role_added": role_was_added,
                "already_associate": False
            }
        }
        
    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        logger.error(f"Error promoviendo usuario {user_id}: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error promoviendo usuario a asociado: {str(e)}"
        )


@router.post("/add-client-role/{user_id}", status_code=status.HTTP_200_OK)
async def add_client_role_to_associate(
    user_id: int,
    db: AsyncSession = Depends(get_async_db),
    current_user_id: int = Depends(get_current_user_id),
):
    """
    Agrega el rol de cliente a un asociado existente.
    
    Esto permite que un asociado también pueda solicitar préstamos como cliente.
    
    Args:
        user_id: ID del usuario asociado
        
    Returns:
        Confirmación del rol agregado
    """
    from sqlalchemy import insert, select
    from app.modules.auth.infrastructure.models import UserModel, user_roles
    
    try:
        # 1. Verificar que el usuario existe
        user_query = select(UserModel).where(UserModel.id == user_id)
        result = await db.execute(user_query)
        user = result.unique().scalar_one_or_none()  # unique() requerido por lazy="joined"
        
        if not user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Usuario {user_id} no encontrado"
            )
        
        # 2. Verificar si ya tiene el rol de cliente
        CLIENT_ROLE_ID = 5
        role_check = await db.execute(
            select(user_roles).where(
                user_roles.c.user_id == user_id,
                user_roles.c.role_id == CLIENT_ROLE_ID
            )
        )
        has_role = role_check.fetchone()
        
        if has_role:
            return {
                "success": True,
                "message": f"{user.first_name} {user.last_name} ya tiene el rol de cliente",
                "data": {"user_id": user_id, "role_added": False, "already_client": True}
            }
        
        # 3. Agregar rol de cliente
        await db.execute(
            insert(user_roles).values(
                user_id=user_id,
                role_id=CLIENT_ROLE_ID
            )
        )
        
        # 4. Registrar en auditoría
        await _create_audit_log(
            db=db,
            table_name="user_roles",
            record_id=user_id,
            operation="INSERT",
            new_data={
                "user_id": user_id,
                "role_id": CLIENT_ROLE_ID,
                "role_name": "cliente",
                "action": "add_client_role",
                "full_name": f"{user.first_name} {user.last_name}"
            },
            changed_by=current_user_id
        )
        
        await db.commit()
        
        logger.info(f"Rol de cliente agregado a usuario {user_id} por usuario {current_user_id}")
        
        return {
            "success": True,
            "message": f"Rol de cliente agregado a {user.first_name} {user.last_name}",
            "data": {"user_id": user_id, "role_added": True, "already_client": False}
        }
        
    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        logger.error(f"Error agregando rol de cliente a usuario {user_id}: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error agregando rol de cliente: {str(e)}"
        )


@router.get("/user-roles/{user_id}")
async def get_user_roles(
    user_id: int,
    db: AsyncSession = Depends(get_async_db),
):
    """
    Obtiene los roles de un usuario.
    
    Args:
        user_id: ID del usuario
        
    Returns:
        Lista de roles del usuario
    """
    from sqlalchemy import select
    from app.modules.auth.infrastructure.models import UserModel, user_roles
    
    try:
        # Verificar que el usuario existe
        user_query = select(UserModel).where(UserModel.id == user_id)
        result = await db.execute(user_query)
        user = result.unique().scalar_one_or_none()  # unique() requerido por lazy="joined"
        
        if not user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Usuario {user_id} no encontrado"
            )
        
        # Obtener roles usando text() con parámetro bindparam
        roles_query = text("""
            SELECT r.id as role_id, r.name as role_name, r.description as role_description
            FROM user_roles ur
            JOIN roles r ON ur.role_id = r.id
            WHERE ur.user_id = :user_id
            ORDER BY r.id
        """)
        
        result = await db.execute(roles_query, {"user_id": user_id})
        roles = result.fetchall()
        
        return {
            "success": True,
            "data": {
                "user_id": user_id,
                "full_name": f"{user.first_name} {user.last_name}",
                "roles": [
                    {"role_id": r.role_id, "role_name": r.role_name, "description": r.role_description}
                    for r in roles
                ]
            }
        }
        
    except HTTPException:
        raise
    except Exception as e:
        import logging
        logging.getLogger(__name__).error(f"Error en get_user_roles: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error obteniendo roles: {str(e)}"
        )
