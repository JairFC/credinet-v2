from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.database import get_async_db
from .application.dtos import ClientDocumentResponseDTO, ClientDocumentListItemDTO, PaginatedClientDocumentsDTO
from .application.use_cases import ListClientDocumentsUseCase, GetUserDocumentsUseCase
from .infrastructure.repositories import PgClientDocumentRepository

router = APIRouter(prefix="/documents", tags=["documents"])

@router.get("", response_model=PaginatedClientDocumentsDTO)
async def list_client_documents(
    limit: int = 50,
    offset: int = 0,
    db: AsyncSession = Depends(get_async_db)
):
    repository = PgClientDocumentRepository(db)
    use_case = ListClientDocumentsUseCase(repository)
    documents, total = await use_case.execute(limit, offset)
    return PaginatedClientDocumentsDTO(
        items=[ClientDocumentListItemDTO.model_validate(d) for d in documents],
        total=total,
        limit=limit,
        offset=offset
    )

@router.get("/users/{user_id}", response_model=list[ClientDocumentResponseDTO])
async def get_user_documents(
    user_id: int,
    db: AsyncSession = Depends(get_async_db)
):
    repository = PgClientDocumentRepository(db)
    use_case = GetUserDocumentsUseCase(repository)
    documents = await use_case.execute(user_id)
    return [ClientDocumentResponseDTO.model_validate(d) for d in documents]
