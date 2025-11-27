from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from typing import List, Optional
from ...domain.entities import ClientDocument
from ...domain.repositories import ClientDocumentRepository
from ..models import ClientDocumentModel

def _map_model_to_entity(model: ClientDocumentModel) -> ClientDocument:
    return ClientDocument(
        id=model.id,
        user_id=model.user_id,
        document_type_id=model.document_type_id,
        file_name=model.file_name,
        original_file_name=model.original_file_name,
        file_path=model.file_path,
        file_size=model.file_size,
        mime_type=model.mime_type,
        status_id=model.status_id,
        upload_date=model.upload_date,
        reviewed_by=model.reviewed_by,
        reviewed_at=model.reviewed_at,
        comments=model.comments,
        created_at=model.created_at,
        updated_at=model.updated_at
    )

class PgClientDocumentRepository(ClientDocumentRepository):
    def __init__(self, session: AsyncSession):
        self.session = session
    
    async def find_by_id(self, document_id: int) -> Optional[ClientDocument]:
        stmt = select(ClientDocumentModel).where(ClientDocumentModel.id == document_id)
        result = await self.session.execute(stmt)
        model = result.scalar_one_or_none()
        return _map_model_to_entity(model) if model else None
    
    async def find_by_user(self, user_id: int) -> List[ClientDocument]:
        stmt = select(ClientDocumentModel).where(
            ClientDocumentModel.user_id == user_id
        ).order_by(ClientDocumentModel.upload_date.desc())
        result = await self.session.execute(stmt)
        models = result.scalars().all()
        return [_map_model_to_entity(m) for m in models]
    
    async def find_all(self, limit: int = 50, offset: int = 0) -> List[ClientDocument]:
        stmt = select(ClientDocumentModel).order_by(
            ClientDocumentModel.upload_date.desc()
        ).limit(limit).offset(offset)
        result = await self.session.execute(stmt)
        models = result.scalars().all()
        return [_map_model_to_entity(m) for m in models]
    
    async def count(self) -> int:
        stmt = select(func.count()).select_from(ClientDocumentModel)
        result = await self.session.execute(stmt)
        return result.scalar_one()
    
    async def create(self, document: ClientDocument) -> ClientDocument:
        model = ClientDocumentModel(
            user_id=document.user_id,
            document_type_id=document.document_type_id,
            file_name=document.file_name,
            original_file_name=document.original_file_name,
            file_path=document.file_path,
            file_size=document.file_size,
            mime_type=document.mime_type,
            status_id=document.status_id,
            comments=document.comments
        )
        self.session.add(model)
        await self.session.flush()
        await self.session.refresh(model)
        return _map_model_to_entity(model)
