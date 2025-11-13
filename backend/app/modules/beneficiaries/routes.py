"""Rutas FastAPI para beneficiaries"""
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession
import logging

from app.core.database import get_async_db
from app.modules.beneficiaries.application.dtos import (
    BeneficiaryResponseDTO,
    BeneficiaryListItemDTO,
    PaginatedBeneficiariesDTO,
    CreateBeneficiaryDTO,
)
from app.modules.beneficiaries.application.use_cases import (
    ListBeneficiariesUseCase,
    GetUserBeneficiariesUseCase,
)
from app.modules.beneficiaries.infrastructure.repositories.pg_beneficiary_repository import PgBeneficiaryRepository
from app.modules.beneficiaries.infrastructure.models.beneficiary_model import BeneficiaryModel

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/beneficiaries", tags=["Beneficiaries"])


def get_beneficiary_repository(db: AsyncSession = Depends(get_async_db)) -> PgBeneficiaryRepository:
    """Dependency injection del repositorio"""
    return PgBeneficiaryRepository(db)


@router.get("", response_model=PaginatedBeneficiariesDTO)
async def list_beneficiaries(
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0),
    repo: PgBeneficiaryRepository = Depends(get_beneficiary_repository),
):
    """Lista todos los beneficiarios con paginación"""
    try:
        use_case = ListBeneficiariesUseCase(repo)
        beneficiaries = await use_case.execute(limit, offset)
        total = await repo.count()
        
        items = [
            BeneficiaryListItemDTO(
                id=b.id,
                user_id=b.user_id,
                full_name=b.full_name,
                relationship=b.relationship,
                phone_number=b.phone_number,
            )
            for b in beneficiaries
        ]
        
        return PaginatedBeneficiariesDTO(
            items=items,
            total=total,
            limit=limit,
            offset=offset,
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error listing beneficiaries: {str(e)}"
        )


@router.get("/users/{user_id}", response_model=list[BeneficiaryResponseDTO])
async def get_user_beneficiaries(
    user_id: int,
    repo: PgBeneficiaryRepository = Depends(get_beneficiary_repository),
):
    """Obtiene todos los beneficiarios de un usuario específico"""
    try:
        use_case = GetUserBeneficiariesUseCase(repo)
        beneficiaries = await use_case.execute(user_id)
        
        return [
            BeneficiaryResponseDTO(
                id=b.id,
                user_id=b.user_id,
                full_name=b.full_name,
                relationship=b.relationship,
                phone_number=b.phone_number,
                created_at=b.created_at,
                updated_at=b.updated_at,
            )
            for b in beneficiaries
        ]
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error fetching user beneficiaries: {str(e)}"
        )


@router.post("", response_model=BeneficiaryResponseDTO, status_code=status.HTTP_201_CREATED)
async def create_beneficiary(
    data: CreateBeneficiaryDTO,
    db: AsyncSession = Depends(get_async_db),
):
    """Crea un nuevo beneficiario para un usuario"""
    try:
        logger.info(f"Creating beneficiary for user_id={data.user_id} with relationship={data.relationship}, relationship_id={data.relationship_id}")
        
        # Crear beneficiario directamente con el modelo
        new_beneficiary = BeneficiaryModel(
            user_id=data.user_id,
            full_name=data.full_name,
            relationship=data.relationship,
            relationship_id=data.relationship_id,
            phone_number=data.phone_number,
        )
        
        db.add(new_beneficiary)
        await db.commit()
        await db.refresh(new_beneficiary)
        
        logger.info(f"Beneficiary created successfully with id={new_beneficiary.id}, relationship_id={new_beneficiary.relationship_id}")
        
        return BeneficiaryResponseDTO(
            id=new_beneficiary.id,
            user_id=new_beneficiary.user_id,
            full_name=new_beneficiary.full_name,
            relationship=new_beneficiary.relationship,
            phone_number=new_beneficiary.phone_number,
            created_at=new_beneficiary.created_at,
            updated_at=new_beneficiary.updated_at,
        )
    except Exception as e:
        logger.error(f"Error creating beneficiary: {str(e)}", exc_info=True)
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error creating beneficiary: {str(e)}"
        )

