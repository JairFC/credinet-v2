from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.database import get_async_db
from .application.dtos import AgreementResponseDTO, AgreementListItemDTO, PaginatedAgreementsDTO
from .application.use_cases import ListAgreementsUseCase, GetAssociateAgreementsUseCase
from .infrastructure.repositories import PgAgreementRepository

router = APIRouter(prefix="/agreements", tags=["agreements"])

@router.get("", response_model=PaginatedAgreementsDTO)
async def list_agreements(
    limit: int = 50,
    offset: int = 0,
    db: AsyncSession = Depends(get_async_db)
):
    repository = PgAgreementRepository(db)
    use_case = ListAgreementsUseCase(repository)
    agreements, total = await use_case.execute(limit, offset)
    return PaginatedAgreementsDTO(
        items=[AgreementListItemDTO.model_validate(a) for a in agreements],
        total=total,
        limit=limit,
        offset=offset
    )

@router.get("/associates/{associate_profile_id}", response_model=list[AgreementResponseDTO])
async def get_associate_agreements(
    associate_profile_id: int,
    db: AsyncSession = Depends(get_async_db)
):
    repository = PgAgreementRepository(db)
    use_case = GetAssociateAgreementsUseCase(repository)
    agreements = await use_case.execute(associate_profile_id)
    return [AgreementResponseDTO.model_validate(a) for a in agreements]
