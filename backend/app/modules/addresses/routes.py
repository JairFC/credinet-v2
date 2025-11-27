"""Rutas FastAPI para addresses"""
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_async_db
from app.modules.addresses.application.dtos import (
    AddressResponseDTO,
    AddressListItemDTO,
    PaginatedAddressesDTO,
    CreateAddressDTO,
)
from app.modules.addresses.application.use_cases import (
    ListAddressesUseCase,
    GetUserAddressUseCase,
    CreateAddressUseCase,
)
from app.modules.addresses.infrastructure.repositories.pg_address_repository import PgAddressRepository


router = APIRouter(prefix="/addresses", tags=["Addresses"])


def get_address_repository(db: AsyncSession = Depends(get_async_db)) -> PgAddressRepository:
    """Dependency injection del repositorio"""
    return PgAddressRepository(db)


@router.get("", response_model=PaginatedAddressesDTO)
async def list_addresses(
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0),
    repo: PgAddressRepository = Depends(get_address_repository),
):
    """Lista todas las direcciones con paginación"""
    try:
        use_case = ListAddressesUseCase(repo)
        addresses = await use_case.execute(limit, offset)
        total = await repo.count()
        
        items = [
            AddressListItemDTO(
                id=a.id,
                user_id=a.user_id,
                street=a.street,
                colony=a.colony,
                municipality=a.municipality,
                state=a.state,
                zip_code=a.zip_code,
            )
            for a in addresses
        ]
        
        return PaginatedAddressesDTO(
            items=items,
            total=total,
            limit=limit,
            offset=offset,
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error listing addresses: {str(e)}"
        )


@router.get("/users/{user_id}", response_model=AddressResponseDTO)
async def get_user_address(
    user_id: int,
    repo: PgAddressRepository = Depends(get_address_repository),
):
    """Obtiene la dirección de un usuario específico"""
    try:
        use_case = GetUserAddressUseCase(repo)
        address = await use_case.execute(user_id)
        
        if not address:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Address for user {user_id} not found"
            )
        
        return AddressResponseDTO(
            id=address.id,
            user_id=address.user_id,
            street=address.street,
            external_number=address.external_number,
            internal_number=address.internal_number,
            colony=address.colony,
            municipality=address.municipality,
            state=address.state,
            zip_code=address.zip_code,
            created_at=address.created_at,
            updated_at=address.updated_at,
            full_address=address.get_full_address(),
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error fetching user address: {str(e)}"
        )


@router.post("", response_model=AddressResponseDTO, status_code=status.HTTP_201_CREATED)
async def create_address(
    data: CreateAddressDTO,
    repo: PgAddressRepository = Depends(get_address_repository),
):
    """Crea una nueva dirección para un usuario"""
    try:
        use_case = CreateAddressUseCase(repo)
        address = await use_case.execute(
            user_id=data.user_id,
            street=data.street,
            external_number=data.external_number,
            internal_number=data.internal_number,
            colony=data.colony,
            municipality=data.municipality,
            state=data.state,
            zip_code=data.zip_code,
        )
        
        return AddressResponseDTO(
            id=address.id,
            user_id=address.user_id,
            street=address.street,
            external_number=address.external_number,
            internal_number=address.internal_number,
            colony=address.colony,
            municipality=address.municipality,
            state=address.state,
            zip_code=address.zip_code,
            created_at=address.created_at,
            updated_at=address.updated_at,
            full_address=address.get_full_address(),
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error creating address: {str(e)}"
        )
