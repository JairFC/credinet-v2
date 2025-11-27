"""
Rutas FastAPI para el módulo de associates.

Endpoints:
- POST /associates → Crear asociado completo
- GET /associates → Listar asociados
- GET /associates/:userId/credit → Resumen de crédito
"""
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_async_db
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


router = APIRouter(prefix="/associates", tags=["Associates"])


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
            credit_used=0,
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
    - Con credit_available >= min_credit
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
                AssociateProfileModel.credit_used,
                AssociateProfileModel.credit_available,
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
                    AssociateProfileModel.credit_available >= min_credit,
                    or_(
                        func.lower(UserModel.username).like(search_term),
                        func.lower(UserModel.first_name).like(search_term),
                        func.lower(UserModel.last_name).like(search_term),
                        func.lower(func.concat(UserModel.first_name, ' ', UserModel.last_name)).like(search_term),
                        func.lower(UserModel.email).like(search_term),
                    )
                )
            )
            .order_by(AssociateProfileModel.credit_available.desc())
            .limit(limit)
        )
        
        result = await db.execute(stmt)
        rows = result.all()
        
        # Construir DTOs
        associates = []
        for row in rows:
            credit_limit = float(row.credit_limit)
            credit_used = float(row.credit_used)
            credit_available = float(row.credit_available)
            credit_usage_percentage = (credit_used / credit_limit * 100) if credit_limit > 0 else 0
            
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
                    credit_used=row.credit_used,
                    credit_available=row.credit_available,
                    credit_usage_percentage=credit_usage_percentage,
                    active=row.active,
                    can_grant_loans=credit_available > 0,
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
    repo: PgAssociateRepository = Depends(get_associate_repository),
    db: AsyncSession = Depends(get_async_db),
):
    """
    Lista todos los asociados con paginación.
    
    Args:
        limit: Máximo de registros (1-100)
        offset: Desplazamiento para paginación
        active_only: Si True, solo asociados activos
        
    Returns:
        Lista paginada de asociados con información de usuario
    """
    from sqlalchemy import select
    from app.modules.associates.infrastructure.models import AssociateProfileModel
    from app.modules.auth.infrastructure.models import UserModel
    
    try:
        # Query con JOIN para obtener datos del usuario y deuda
        from sqlalchemy import func, text
        
        # Subquery para contar deudas pendientes usando text() para evitar importar el modelo
        pending_debts_subq = (
            select(func.count(text('*')))
            .select_from(text('associate_debt_breakdown'))
            .where(
                text('associate_debt_breakdown.associate_profile_id = associate_profiles.id'),
                text('associate_debt_breakdown.is_liquidated = false')
            )
            .correlate(AssociateProfileModel)
            .scalar_subquery()
        )
        
        stmt = (
            select(
                AssociateProfileModel.id,
                AssociateProfileModel.user_id,
                AssociateProfileModel.credit_limit,
                AssociateProfileModel.credit_used,
                AssociateProfileModel.credit_available,
                AssociateProfileModel.debt_balance,
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
        
        stmt = stmt.order_by(AssociateProfileModel.id).limit(limit).offset(offset)
        
        result = await db.execute(stmt)
        rows = result.all()
        
        total = await repo.count(active_only)
        
        items = [
            AssociateListItemDTO(
                id=row.id,
                user_id=row.user_id,
                username=row.username,
                full_name=f"{row.first_name} {row.last_name}",
                email=row.email,
                level_id=row.level_id,
                credit_limit=row.credit_limit,
                credit_used=row.credit_used,
                credit_available=row.credit_available,
                debt_balance=row.debt_balance,
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
                AssociateProfileModel.credit_used,
                AssociateProfileModel.credit_limit,
                AssociateProfileModel.credit_available,
                AssociateProfileModel.credit_last_updated,
                AssociateProfileModel.debt_balance,
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
            credit_usage_percentage = float((row.credit_used / row.credit_limit) * 100)
        
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
            credit_used=row.credit_used,
            credit_limit=row.credit_limit,
            credit_available=row.credit_available,
            credit_last_updated=row.credit_last_updated,
            debt_balance=row.debt_balance,
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
            credit_used=associate.credit_used,
            credit_available=associate.credit_available,
            credit_usage_percentage=associate.get_credit_usage_percentage(),
            active_loans_count=0,  # TODO: Contar loans activos
            total_disbursed=associate.credit_used,
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error fetching associate credit: {str(e)}"
        )


# =============================================================================
# ⭐ NUEVOS ENDPOINTS FASE 6 - DEUDA Y PAGOS
# =============================================================================

@router.post("/{associate_id}/debt-payments", status_code=status.HTTP_201_CREATED)
async def register_debt_payment(
    associate_id: int,
    payment_amount: float = Query(..., gt=0),
    payment_date: str = Query(...),
    payment_method_id: int = Query(...),
    payment_reference: str = Query(None),
    notes: str = Query(None),
    db: AsyncSession = Depends(get_async_db),
):
    """
    Registra abono a deuda acumulada (FIFO automático).
    
    **Trigger aplica FIFO:**
    1. Obtiene items de deuda pendientes (is_liquidated = false)
    2. Ordena por created_at ASC
    3. Liquida de más antiguos a más recientes
    4. Guarda detalle en JSONB applied_breakdown_items
    5. Actualiza debt_balance del asociado
    
    **Returns:** JSON con items liquidados
    """
    from sqlalchemy import text
    
    result = await db.execute(
        text("""
            INSERT INTO associate_debt_payments 
            (associate_profile_id, payment_amount, payment_date, payment_method_id, 
             payment_reference, registered_by, notes)
            VALUES (:associate_id, :payment_amount, :payment_date, :payment_method_id,
                    :payment_reference, 1, :notes)
            RETURNING id, applied_breakdown_items, created_at
        """),
        {
            "associate_id": associate_id,
            "payment_amount": payment_amount,
            "payment_date": payment_date,
            "payment_method_id": payment_method_id,
            "payment_reference": payment_reference,
            "notes": notes
        }
    )
    
    await db.commit()
    row = result.fetchone()
    
    # Obtener deuda actualizada
    debt_result = await db.execute(
        text("SELECT debt_balance FROM associate_profiles WHERE id = :id"),
        {"id": associate_id}
    )
    debt_row = debt_result.fetchone()
    
    return {
        "success": True,
        "data": {
            "payment_id": row[0],
            "associate_profile_id": associate_id,
            "payment_amount": payment_amount,
            "applied_breakdown_items": row[1],
            "debt_balance_after": float(debt_row[0]) if debt_row else 0.0,
            "registered_at": row[2].isoformat()
        }
    }


@router.get("/{associate_id}/debt-summary")
async def get_debt_summary(
    associate_id: int,
    db: AsyncSession = Depends(get_async_db),
):
    """
    Resumen de deuda del asociado (usa vista v_associate_debt_summary).
    
    **Returns:**
    - Deuda actual
    - Items pendientes/liquidados
    - Total pagado
    - Fechas clave
    """
    from sqlalchemy import text
    
    result = await db.execute(
        text("""
            SELECT 
                associate_profile_id,
                associate_name,
                current_debt_balance,
                pending_debt_items,
                liquidated_debt_items,
                total_pending_debt,
                total_paid_to_debt,
                oldest_debt_date,
                last_payment_date,
                total_debt_payments_count,
                credit_available,
                credit_limit
            FROM v_associate_debt_summary
            WHERE associate_profile_id = :id
        """),
        {"id": associate_id}
    )
    
    row = result.fetchone()
    
    if not row:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Associate {associate_id} not found"
        )
    
    return {
        "success": True,
        "data": {
            "associate_profile_id": row[0],
            "associate_name": row[1],
            "current_debt_balance": float(row[2]),
            "pending_debt_items": row[3],
            "liquidated_debt_items": row[4],
            "total_pending_debt": float(row[5]),
            "total_paid_to_debt": float(row[6]),
            "oldest_debt_date": row[7].isoformat() if row[7] else None,
            "last_payment_date": row[8].isoformat() if row[8] else None,
            "total_debt_payments_count": row[9],
            "credit_available": float(row[10]),
            "credit_limit": float(row[11])
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
