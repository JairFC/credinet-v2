"""
Rutas FastAPI para el módulo de clients.

Endpoints:
- GET /clients → Listar clientes
- GET /clients/:id → Detalle de un cliente
"""
from typing import List

from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.core.database import get_async_db
from app.core.dependencies import require_admin
from app.modules.clients.application.dtos import (
    ClientResponseDTO,
    ClientListItemDTO,
    ClientSearchItemDTO,
    PaginatedClientsDTO,
)
from app.modules.clients.application.use_cases import (
    ListClientsUseCase,
    GetClientDetailsUseCase,
)
from app.modules.clients.infrastructure.repositories.pg_client_repository import PgClientRepository
from app.modules.addresses.infrastructure.models.address_model import AddressModel
from app.modules.guarantors.infrastructure.models.guarantor_model import GuarantorModel
from app.modules.beneficiaries.infrastructure.models.beneficiary_model import BeneficiaryModel


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
    repo: PgClientRepository = Depends(get_client_repository),
):
    """
    Lista todos los clientes con paginación.
    
    Args:
        limit: Máximo de registros (1-100)
        offset: Desplazamiento para paginación
        active_only: Si True, solo clientes activos
        
    Returns:
        Lista paginada de clientes
        
    Ejemplos:
    - GET /clients → Primeros 50 clientes activos
    - GET /clients?limit=20&offset=40 → Página 3
    - GET /clients?active_only=false → Todos los clientes
    """
    try:
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
                        (LoanModel.status_id.in_([2, 3, 4]), LoanModel.id),  # APPROVED, ACTIVE o IN_COLLECTION
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
