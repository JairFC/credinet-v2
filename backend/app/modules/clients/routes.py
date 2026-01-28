"""
Rutas FastAPI para el módulo de clients.

Endpoints:
- GET /clients → Listar clientes
- GET /clients/:id → Detalle de un cliente
- PATCH /clients/:id → Actualizar datos de un cliente
"""
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update

from app.core.database import get_async_db
from app.core.dependencies import require_admin, get_current_user_id
from app.core.notifications import notify
from app.core.constants import RoleId
from app.modules.clients.application.dtos import (
    ClientResponseDTO,
    ClientListItemDTO,
    ClientSearchItemDTO,
    PaginatedClientsDTO,
    UpdateClientDTO,
    UpdateAddressDTO,
    UpdateGuarantorDTO,
    UpdateBeneficiaryDTO,
)
from app.modules.clients.application.use_cases import (
    ListClientsUseCase,
    GetClientDetailsUseCase,
)
from app.modules.clients.infrastructure.repositories.pg_client_repository import PgClientRepository
from app.modules.addresses.infrastructure.models.address_model import AddressModel
from app.modules.guarantors.infrastructure.models.guarantor_model import GuarantorModel
from app.modules.beneficiaries.infrastructure.models.beneficiary_model import BeneficiaryModel
from app.modules.auth.infrastructure.models import UserModel


router = APIRouter(
    prefix="/clients",
    tags=["Clients"],
    dependencies=[Depends(require_admin)]  # 🔒 Solo admins
)


def get_client_repository(db: AsyncSession = Depends(get_async_db)) -> PgClientRepository:
    """Dependency injection del repositorio de clientes"""
    return PgClientRepository(db)


@router.get("", response_model=PaginatedClientsDTO)
async def list_clients(
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0),
    active_only: bool = Query(True),
    search: Optional[str] = Query(None, min_length=1, description="Buscar por nombre, username, email o teléfono"),
    repo: PgClientRepository = Depends(get_client_repository),
    db: AsyncSession = Depends(get_async_db),
):
    """
    Lista todos los clientes con paginación y búsqueda opcional.
    
    Args:
        limit: Máximo de registros (1-100)
        offset: Desplazamiento para paginación
        active_only: Si True, solo clientes activos
        search: Término de búsqueda (nombre, username, email, teléfono)
        
    Returns:
        Lista paginada de clientes
        
    Ejemplos:
    - GET /clients → Primeros 50 clientes activos
    - GET /clients?limit=20&offset=40 → Página 3
    - GET /clients?active_only=false → Todos los clientes
    - GET /clients?search=juan → Busca "juan" en todos los campos
    """
    from sqlalchemy import select, func, or_
    from app.modules.auth.infrastructure.models import UserModel, user_roles
    
    try:
        # Si hay búsqueda, usar query directa con filtros
        if search and search.strip():
            search_term = f"%{search.lower().strip()}%"
            
            # Subquery para obtener user_ids con rol CLIENTE (role_id=5)
            client_role_subq = (
                select(user_roles.c.user_id)
                .where(user_roles.c.role_id == RoleId.CLIENTE)
                .scalar_subquery()
            )
            
            stmt = (
                select(
                    UserModel.id,
                    UserModel.username,
                    UserModel.first_name,
                    UserModel.last_name,
                    UserModel.email,
                    UserModel.phone_number,
                    UserModel.active,
                )
                .where(
                    UserModel.id.in_(client_role_subq),
                    or_(
                        func.lower(UserModel.username).like(search_term),
                        func.lower(UserModel.first_name).like(search_term),
                        func.lower(UserModel.last_name).like(search_term),
                        func.lower(func.concat(UserModel.first_name, ' ', UserModel.last_name)).like(search_term),
                        func.lower(UserModel.email).like(search_term),
                        UserModel.phone_number.like(search_term),
                    )
                )
            )
            
            if active_only:
                stmt = stmt.where(UserModel.active == True)
            
            # Contar total antes de paginar
            count_stmt = select(func.count()).select_from(stmt.subquery())
            total_result = await db.execute(count_stmt)
            total = total_result.scalar() or 0
            
            # Aplicar paginación
            stmt = stmt.order_by(UserModel.id).limit(limit).offset(offset)
            result = await db.execute(stmt)
            rows = result.all()
            
            items = [
                ClientListItemDTO(
                    id=row.id,
                    username=row.username,
                    full_name=f"{row.first_name or ''} {row.last_name or ''}".strip() or row.username,
                    email=row.email,
                    phone_number=row.phone_number,
                    active=row.active,
                )
                for row in rows
            ]
        else:
            # Sin búsqueda, usar el use case normal
            use_case = ListClientsUseCase(repo)
            clients = await use_case.execute(limit, offset, active_only)
            total = await repo.count(active_only)
            
            items = [
                ClientListItemDTO(
                    id=c.id,
                    username=c.username,
                    full_name=c.get_full_name(),
                    email=c.email,
                    phone_number=c.phone_number,
                    active=c.active,
                )
                for c in clients
            ]
        
        return PaginatedClientsDTO(
            items=items,
            total=total,
            limit=limit,
            offset=offset,
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error listing clients: {str(e)}"
        )


@router.get("/search/eligible", response_model=List[ClientSearchItemDTO])
async def search_eligible_clients(
    q: str = Query(..., min_length=2, description="Término de búsqueda (nombre, username, teléfono, email)"),
    limit: int = Query(10, ge=1, le=50, description="Máximo de resultados"),
    db: AsyncSession = Depends(get_async_db),
):
    """
    Busca clientes elegibles para préstamos.
    
    Filtros aplicados:
    - Solo clientes activos con rol CLIENTE
    - Búsqueda por: nombre completo, username, teléfono, email
    
    Nota: Actualmente NO filtra por morosidad ya que esto se gestiona
    mediante reportes de clientes morosos (defaulted_client_reports).
    La validación de elegibilidad puede hacerse en el frontend o backend
    según reglas de negocio específicas.
    
    Args:
        q: Término de búsqueda (mínimo 2 caracteres)
        limit: Máximo de resultados (1-50)
        
    Returns:
        Lista de clientes con información básica y conteo de préstamos activos
        
    Ejemplos:
    - GET /clients/search/eligible?q=juan → Busca "juan" en todos los campos
    - GET /clients/search/eligible?q=555123&limit=5 → Busca por teléfono
    """
    try:
        from app.modules.auth.infrastructure.models import UserModel, user_roles
        from app.modules.loans.infrastructure.models import LoanModel
        from sqlalchemy import func, and_, or_, case
        from decimal import Decimal
        
        CLIENTE_ROLE_ID = 5  # Rol "cliente" en la tabla roles
        
        search_term = f"%{q.lower()}%"
        
        # Query simplificada - solo busca clientes activos con el término
        query = (
            select(
                UserModel.id,
                UserModel.username,
                UserModel.first_name,
                UserModel.last_name,
                UserModel.email,
                UserModel.phone_number,
                UserModel.active,
                # Contar préstamos activos
                func.count(
                    case(
                        (LoanModel.status_id.in_([2, 4]), LoanModel.id),  # ACTIVE o COMPLETED
                        else_=None
                    )
                ).label('active_loans'),
            )
            .select_from(UserModel)
            .join(user_roles, UserModel.id == user_roles.c.user_id)
            .outerjoin(LoanModel, LoanModel.user_id == UserModel.id)
            .where(
                and_(
                    UserModel.active == True,
                    user_roles.c.role_id == CLIENTE_ROLE_ID,
                    or_(
                        func.lower(UserModel.username).like(search_term),
                        func.lower(UserModel.first_name).like(search_term),
                        func.lower(UserModel.last_name).like(search_term),
                        func.lower(func.concat(UserModel.first_name, ' ', UserModel.last_name)).like(search_term),
                        func.lower(UserModel.email).like(search_term),
                        func.lower(UserModel.phone_number).like(search_term),
                    )
                )
            )
            .group_by(
                UserModel.id,
                UserModel.username,
                UserModel.first_name,
                UserModel.last_name,
                UserModel.email,
                UserModel.phone_number,
                UserModel.active,
            )
            .order_by(UserModel.first_name, UserModel.last_name)
            .limit(limit)
        )
        
        result = await db.execute(query)
        rows = result.all()
        
        # Construir DTOs
        clients = []
        for row in rows:
            clients.append(
                ClientSearchItemDTO(
                    id=row.id,
                    username=row.username,
                    full_name=f"{row.first_name} {row.last_name}",
                    email=row.email,
                    phone_number=row.phone_number,
                    active=row.active,
                    has_overdue_payments=False,  # Simplificado por ahora
                    total_debt=Decimal('0.00'),
                    active_loans=row.active_loans,
                )
            )
        
        return clients
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error searching eligible clients: {str(e)}"
        )


@router.get("/{client_id}", response_model=ClientResponseDTO)
async def get_client_details(
    client_id: int,
    repo: PgClientRepository = Depends(get_client_repository),
    db: AsyncSession = Depends(get_async_db),
):
    """
    Obtiene el detalle completo de un cliente.
    
    Args:
        client_id: ID del cliente
        
    Returns:
        Detalle completo del cliente
        
    Raises:
        404: Si el cliente no existe
        
    Ejemplo:
    - GET /clients/5 → Detalle del cliente 5
    """
    try:
        use_case = GetClientDetailsUseCase(repo)
        client = await use_case.execute(client_id)
        
        if not client:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Client {client_id} not found"
            )
        
        # Importar DTOs anidados
        from app.modules.clients.application.dtos.client_dto import (
            AddressNestedDTO,
            GuarantorNestedDTO,
            BeneficiaryNestedDTO,
        )
        
        # Cargar las relaciones directamente desde la base de datos
        address_result = await db.execute(
            select(AddressModel).where(AddressModel.user_id == client_id)
        )
        address_model = address_result.scalar_one_or_none()
        
        guarantor_result = await db.execute(
            select(GuarantorModel).where(GuarantorModel.user_id == client_id)
        )
        guarantor_model = guarantor_result.scalar_one_or_none()
        
        beneficiary_result = await db.execute(
            select(BeneficiaryModel).where(BeneficiaryModel.user_id == client_id)
        )
        beneficiary_model = beneficiary_result.scalar_one_or_none()
        
        # Construir DTOs anidados si existen las relaciones
        address_dto = None
        if address_model:
            address_dto = AddressNestedDTO(
                street=address_model.street,
                external_number=address_model.external_number,
                internal_number=address_model.internal_number,
                colony=address_model.colony,
                municipality=address_model.municipality,
                state=address_model.state,
                zip_code=address_model.zip_code,
            )
        
        guarantor_dto = None
        if guarantor_model:
            guarantor_dto = GuarantorNestedDTO(
                full_name=guarantor_model.full_name,
                relationship=guarantor_model.relationship,
                phone_number=guarantor_model.phone_number,
                curp=guarantor_model.curp,
            )
        
        beneficiary_dto = None
        if beneficiary_model:
            beneficiary_dto = BeneficiaryNestedDTO(
                full_name=beneficiary_model.full_name,
                relationship=beneficiary_model.relationship,
                phone_number=beneficiary_model.phone_number,
            )
        
        return ClientResponseDTO(
            id=client.id,
            username=client.username,
            first_name=client.first_name,
            last_name=client.last_name,
            email=client.email,
            phone_number=client.phone_number,
            birth_date=client.birth_date,
            curp=client.curp,
            profile_picture_url=client.profile_picture_url,
            active=client.active,
            created_at=client.created_at,
            updated_at=client.updated_at,
            full_name=client.get_full_name(),
            address=address_dto,
            guarantor=guarantor_dto,
            beneficiary=beneficiary_dto,
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error fetching client details: {str(e)}"
        )


# Mapeo de nombres de campos para notificaciones legibles
FIELD_LABELS = {
    # Datos personales
    "first_name": "Nombre",
    "last_name": "Apellidos",
    "email": "Correo electrónico",
    "phone_number": "Teléfono",
    "curp": "CURP",
    "birth_date": "Fecha de nacimiento",
    # Dirección
    "street": "Calle",
    "exterior_number": "Número exterior",
    "interior_number": "Número interior",
    "colony": "Colonia",
    "municipality": "Municipio",
    "state": "Estado",
    "zip_code": "Código postal",
    # Aval
    "full_name": "Nombre completo",
    "relationship": "Parentesco",
    # Beneficiario - usa los mismos campos que aval
}


def format_change_details(old_values: dict, new_values: dict) -> str:
    """Formatea los cambios para notificación de Discord."""
    lines = []
    for field, new_val in new_values.items():
        old_val = old_values.get(field, "(vacío)")
        if old_val is None:
            old_val = "(vacío)"
        if new_val is None:
            new_val = "(vacío)"
        label = FIELD_LABELS.get(field, field)
        lines.append(f"• **{label}**: `{old_val}` → `{new_val}`")
    return "\n".join(lines)


@router.patch("/{client_id}", response_model=dict)
async def update_client(
    client_id: int,
    data: UpdateClientDTO,
    db: AsyncSession = Depends(get_async_db),
    current_user_id: int = Depends(get_current_user_id),
):
    """
    Actualiza parcialmente los datos de un cliente.
    
    Solo actualiza los campos proporcionados (null = no cambiar).
    Los cambios se registran automáticamente en audit_log.
    
    Args:
        client_id: ID del cliente a actualizar
        data: Campos a actualizar
        
    Returns:
        Mensaje de éxito
        
    Raises:
        404: Si el cliente no existe
        409: Si el email/teléfono ya está en uso
    """
    try:
        # Verificar que el cliente existe
        result = await db.execute(
            select(UserModel).where(UserModel.id == client_id)
        )
        client = result.unique().scalar_one_or_none()
        
        if not client:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Cliente {client_id} no encontrado"
            )
        
        # Construir datos de actualización (solo campos proporcionados)
        update_data = data.model_dump(exclude_unset=True, exclude_none=True)
        
        if not update_data:
            return {"message": "No hay cambios para aplicar"}
        
        # Verificar unicidad de email si se cambió
        if 'email' in update_data and update_data['email'] != client.email:
            email_check = await db.execute(
                select(UserModel.id).where(
                    UserModel.email == update_data['email'],
                    UserModel.id != client_id
                )
            )
            if email_check.scalar_one_or_none():
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f"El email {update_data['email']} ya está en uso"
                )
        
        # Verificar unicidad de teléfono si se cambió
        if 'phone_number' in update_data and update_data['phone_number'] != client.phone_number:
            phone_check = await db.execute(
                select(UserModel.id).where(
                    UserModel.phone_number == update_data['phone_number'],
                    UserModel.id != client_id
                )
            )
            if phone_check.scalar_one_or_none():
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f"El teléfono {update_data['phone_number']} ya está en uso"
                )
        
        # Verificar unicidad de CURP si se cambió
        if 'curp' in update_data and update_data['curp'] != client.curp:
            curp_check = await db.execute(
                select(UserModel.id).where(
                    UserModel.curp == update_data['curp'],
                    UserModel.id != client_id
                )
            )
            if curp_check.scalar_one_or_none():
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f"El CURP {update_data['curp']} ya está en uso"
                )
        
        # Guardar valores anteriores para notificación
        old_values = {}
        for field in update_data.keys():
            old_values[field] = getattr(client, field, None)
        
        # Aplicar actualización
        await db.execute(
            update(UserModel)
            .where(UserModel.id == client_id)
            .values(**update_data)
        )
        await db.commit()
        
        # Obtener nombre del admin que hace el cambio
        admin_result = await db.execute(
            select(UserModel.first_name, UserModel.last_name).where(UserModel.id == current_user_id)
        )
        admin = admin_result.first()
        admin_name = f"{admin.first_name} {admin.last_name}" if admin else f"Usuario #{current_user_id}"
        
        # Enviar notificación a Discord
        change_details = format_change_details(old_values, update_data)
        await notify.send(
            title="📝 Datos de Cliente Modificados",
            message=(
                f"**Cliente:** {client.first_name} {client.last_name} (ID: {client_id})\n"
                f"**Sección:** Datos Personales\n\n"
                f"**Cambios realizados:**\n{change_details}"
            ),
            level="warning",
            to_discord=True,
            to_group=False,
            to_personal=False,
            entity_type="user",
            entity_id=client_id,
            created_by=current_user_id,
            created_by_name=admin_name,
            metadata={"old_values": old_values, "new_values": update_data}
        )
        
        return {
            "message": "Cliente actualizado correctamente",
            "updated_fields": list(update_data.keys())
        }
        
    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error actualizando cliente: {str(e)}"
        )


@router.patch("/{client_id}/address", response_model=dict)
async def update_client_address(
    client_id: int,
    data: UpdateAddressDTO,
    db: AsyncSession = Depends(get_async_db),
    current_user_id: int = Depends(get_current_user_id),
):
    """
    Actualiza parcialmente la dirección de un cliente.
    
    Args:
        client_id: ID del cliente (user_id)
        data: Campos de dirección a actualizar
        
    Returns:
        Mensaje de éxito
        
    Raises:
        404: Si la dirección no existe
    """
    try:
        # Verificar que la dirección existe
        result = await db.execute(
            select(AddressModel).where(AddressModel.user_id == client_id)
        )
        address = result.scalar_one_or_none()
        
        if not address:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Dirección del cliente {client_id} no encontrada"
            )
        
        # Construir datos de actualización
        update_data = data.model_dump(exclude_unset=True, exclude_none=True)
        
        if not update_data:
            return {"message": "No hay cambios para aplicar"}
        
        # Guardar valores anteriores para notificación
        old_values = {}
        for field in update_data.keys():
            old_values[field] = getattr(address, field, None)
        
        # Aplicar actualización
        await db.execute(
            update(AddressModel)
            .where(AddressModel.user_id == client_id)
            .values(**update_data)
        )
        await db.commit()
        
        # Obtener datos del cliente y admin
        client_result = await db.execute(
            select(UserModel.first_name, UserModel.last_name).where(UserModel.id == client_id)
        )
        client = client_result.unique().first()
        client_name = f"{client.first_name} {client.last_name}" if client else f"Cliente #{client_id}"
        
        admin_result = await db.execute(
            select(UserModel.first_name, UserModel.last_name).where(UserModel.id == current_user_id)
        )
        admin = admin_result.first()
        admin_name = f"{admin.first_name} {admin.last_name}" if admin else f"Usuario #{current_user_id}"
        
        # Enviar notificación a Discord
        change_details = format_change_details(old_values, update_data)
        await notify.send(
            title="🏠 Dirección de Cliente Modificada",
            message=(
                f"**Cliente:** {client_name} (ID: {client_id})\n"
                f"**Sección:** Dirección\n\n"
                f"**Cambios realizados:**\n{change_details}"
            ),
            level="warning",
            to_discord=True,
            to_group=False,
            to_personal=False,
            entity_type="address",
            entity_id=client_id,
            created_by=current_user_id,
            created_by_name=admin_name,
            metadata={"old_values": old_values, "new_values": update_data}
        )
        
        return {
            "message": "Dirección actualizada correctamente",
            "updated_fields": list(update_data.keys())
        }
        
    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error actualizando dirección: {str(e)}"
        )


@router.patch("/{client_id}/guarantor", response_model=dict)
async def update_client_guarantor(
    client_id: int,
    data: UpdateGuarantorDTO,
    db: AsyncSession = Depends(get_async_db),
    current_user_id: int = Depends(get_current_user_id),
):
    """
    Actualiza parcialmente el aval de un cliente.
    
    Args:
        client_id: ID del cliente (user_id)
        data: Campos del aval a actualizar
        
    Returns:
        Mensaje de éxito
        
    Raises:
        404: Si el aval no existe
    """
    try:
        # Verificar que el aval existe
        result = await db.execute(
            select(GuarantorModel).where(GuarantorModel.user_id == client_id)
        )
        guarantor = result.scalar_one_or_none()
        
        if not guarantor:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Aval del cliente {client_id} no encontrado"
            )
        
        # Construir datos de actualización
        update_data = data.model_dump(exclude_unset=True, exclude_none=True)
        
        if not update_data:
            return {"message": "No hay cambios para aplicar"}
        
        # Guardar valores anteriores para notificación
        old_values = {}
        for field in update_data.keys():
            old_values[field] = getattr(guarantor, field, None)
        
        # Aplicar actualización
        await db.execute(
            update(GuarantorModel)
            .where(GuarantorModel.user_id == client_id)
            .values(**update_data)
        )
        await db.commit()
        
        # Obtener datos del cliente y admin
        client_result = await db.execute(
            select(UserModel.first_name, UserModel.last_name).where(UserModel.id == client_id)
        )
        client = client_result.unique().first()
        client_name = f"{client.first_name} {client.last_name}" if client else f"Cliente #{client_id}"
        
        admin_result = await db.execute(
            select(UserModel.first_name, UserModel.last_name).where(UserModel.id == current_user_id)
        )
        admin = admin_result.first()
        admin_name = f"{admin.first_name} {admin.last_name}" if admin else f"Usuario #{current_user_id}"
        
        # Enviar notificación a Discord
        change_details = format_change_details(old_values, update_data)
        await notify.send(
            title="🛡️ Aval de Cliente Modificado",
            message=(
                f"**Cliente:** {client_name} (ID: {client_id})\n"
                f"**Sección:** Aval/Fiador\n\n"
                f"**Cambios realizados:**\n{change_details}"
            ),
            level="warning",
            to_discord=True,
            to_group=False,
            to_personal=False,
            entity_type="guarantor",
            entity_id=client_id,
            created_by=current_user_id,
            created_by_name=admin_name,
            metadata={"old_values": old_values, "new_values": update_data}
        )
        
        return {
            "message": "Aval actualizado correctamente",
            "updated_fields": list(update_data.keys())
        }
        
    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error actualizando aval: {str(e)}"
        )


@router.patch("/{client_id}/beneficiary", response_model=dict)
async def update_client_beneficiary(
    client_id: int,
    data: UpdateBeneficiaryDTO,
    db: AsyncSession = Depends(get_async_db),
    current_user_id: int = Depends(get_current_user_id),
):
    """
    Actualiza parcialmente el beneficiario de un cliente.
    
    Args:
        client_id: ID del cliente (user_id)
        data: Campos del beneficiario a actualizar
        
    Returns:
        Mensaje de éxito
        
    Raises:
        404: Si el beneficiario no existe
    """
    try:
        # Verificar que el beneficiario existe
        result = await db.execute(
            select(BeneficiaryModel).where(BeneficiaryModel.user_id == client_id)
        )
        beneficiary = result.scalar_one_or_none()
        
        if not beneficiary:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Beneficiario del cliente {client_id} no encontrado"
            )
        
        # Construir datos de actualización
        update_data = data.model_dump(exclude_unset=True, exclude_none=True)
        
        if not update_data:
            return {"message": "No hay cambios para aplicar"}
        
        # Guardar valores anteriores para notificación
        old_values = {}
        for field in update_data.keys():
            old_values[field] = getattr(beneficiary, field, None)
        
        # Aplicar actualización
        await db.execute(
            update(BeneficiaryModel)
            .where(BeneficiaryModel.user_id == client_id)
            .values(**update_data)
        )
        await db.commit()
        
        # Obtener datos del cliente y admin
        client_result = await db.execute(
            select(UserModel.first_name, UserModel.last_name).where(UserModel.id == client_id)
        )
        client = client_result.unique().first()
        client_name = f"{client.first_name} {client.last_name}" if client else f"Cliente #{client_id}"
        
        admin_result = await db.execute(
            select(UserModel.first_name, UserModel.last_name).where(UserModel.id == current_user_id)
        )
        admin = admin_result.first()
        admin_name = f"{admin.first_name} {admin.last_name}" if admin else f"Usuario #{current_user_id}"
        
        # Enviar notificación a Discord
        change_details = format_change_details(old_values, update_data)
        await notify.send(
            title="👥 Beneficiario de Cliente Modificado",
            message=(
                f"**Cliente:** {client_name} (ID: {client_id})\n"
                f"**Sección:** Beneficiario\n\n"
                f"**Cambios realizados:**\n{change_details}"
            ),
            level="warning",
            to_discord=True,
            to_group=False,
            to_personal=False,
            entity_type="beneficiary",
            entity_id=client_id,
            created_by=current_user_id,
            created_by_name=admin_name,
            metadata={"old_values": old_values, "new_values": update_data}
        )
        
        return {
            "message": "Beneficiario actualizado correctamente",
            "updated_fields": list(update_data.keys())
        }
        
    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error actualizando beneficiario: {str(e)}"
        )
