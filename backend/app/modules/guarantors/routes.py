"""Rutas FastAPI para guarantors"""
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_async_db
from app.modules.guarantors.application.dtos import (
    GuarantorResponseDTO,
    GuarantorListItemDTO,
    PaginatedGuarantorsDTO,
    CreateGuarantorDTO,
)
from app.modules.guarantors.application.use_cases import (
    ListGuarantorsUseCase,
    GetUserGuarantorsUseCase,
    CreateGuarantorUseCase,
)
from app.modules.guarantors.infrastructure.repositories.pg_guarantor_repository import PgGuarantorRepository


router = APIRouter(prefix="/guarantors", tags=["Guarantors"])


def get_guarantor_repository(db: AsyncSession = Depends(get_async_db)) -> PgGuarantorRepository:
    """Dependency injection del repositorio"""
    return PgGuarantorRepository(db)


@router.get("", response_model=PaginatedGuarantorsDTO)
async def list_guarantors(
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0),
    repo: PgGuarantorRepository = Depends(get_guarantor_repository),
):
    """Lista todos los avales con paginación"""
    try:
        use_case = ListGuarantorsUseCase(repo)
        guarantors = await use_case.execute(limit, offset)
        total = await repo.count()
        
        items = [
            GuarantorListItemDTO(
                id=g.id,
                user_id=g.user_id,
                full_name=g.full_name,
                relationship=g.relationship,
                phone_number=g.phone_number,
                has_curp=g.has_curp(),
            )
            for g in guarantors
        ]
        
        return PaginatedGuarantorsDTO(
            items=items,
            total=total,
            limit=limit,
            offset=offset,
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error listing guarantors: {str(e)}"
        )


@router.get("/users/{user_id}", response_model=list[GuarantorResponseDTO])
async def get_user_guarantors(
    user_id: int,
    repo: PgGuarantorRepository = Depends(get_guarantor_repository),
):
    """Obtiene todos los avales de un usuario específico"""
    try:
        use_case = GetUserGuarantorsUseCase(repo)
        guarantors = await use_case.execute(user_id)
        
        return [
            GuarantorResponseDTO(
                id=g.id,
                user_id=g.user_id,
                full_name=g.full_name,
                first_name=g.first_name,
                paternal_last_name=g.paternal_last_name,
                maternal_last_name=g.maternal_last_name,
                relationship=g.relationship,
                phone_number=g.phone_number,
                curp=g.curp,
                created_at=g.created_at,
                updated_at=g.updated_at,
            )
            for g in guarantors
        ]
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error fetching user guarantors: {str(e)}"
        )


@router.post("", response_model=GuarantorResponseDTO, status_code=status.HTTP_201_CREATED)
async def create_guarantor(
    data: CreateGuarantorDTO,
    db: AsyncSession = Depends(get_async_db),
):
    """Crea un nuevo aval/garante para un usuario"""
    from app.modules.guarantors.infrastructure.models import GuarantorModel
    
    try:
        new_guarantor = GuarantorModel(
            user_id=data.user_id,
            full_name=data.full_name,
            first_name=data.first_name,
            paternal_last_name=data.paternal_last_name,
            maternal_last_name=data.maternal_last_name,
            relationship=data.relationship,
            relationship_id=data.relationship_id,  # Guardar ID del catálogo
            phone_number=data.phone_number,
            curp=data.curp,
        )
        
        db.add(new_guarantor)
        await db.commit()
        await db.refresh(new_guarantor)
        
        return GuarantorResponseDTO(
            id=new_guarantor.id,
            user_id=new_guarantor.user_id,
            full_name=new_guarantor.full_name,
            first_name=new_guarantor.first_name,
            paternal_last_name=new_guarantor.paternal_last_name,
            maternal_last_name=new_guarantor.maternal_last_name,
            relationship=new_guarantor.relationship,
            phone_number=new_guarantor.phone_number,
            curp=new_guarantor.curp,
            created_at=new_guarantor.created_at,
            updated_at=new_guarantor.updated_at,
        )
    except Exception as e:
        await db.rollback()
        import logging
        logger = logging.getLogger(__name__)
        logger.error(f"Error creating guarantor: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error creating guarantor: {str(e)}"
        )
