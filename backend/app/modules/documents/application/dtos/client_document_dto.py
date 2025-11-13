from pydantic import BaseModel, ConfigDict
from datetime import datetime
from typing import List, Optional

class ClientDocumentResponseDTO(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    
    id: int
    user_id: int
    document_type_id: int
    file_name: Optional[str]
    original_file_name: str
    file_path: str
    file_size: Optional[int]
    mime_type: Optional[str]
    status_id: int
    upload_date: datetime
    reviewed_by: Optional[int]
    reviewed_at: Optional[datetime]
    comments: Optional[str]
    created_at: datetime
    updated_at: datetime

class CreateClientDocumentDTO(BaseModel):
    user_id: int
    document_type_id: int
    file_name: Optional[str] = None
    original_file_name: str
    file_path: str
    file_size: Optional[int] = None
    mime_type: Optional[str] = None
    status_id: int = 1  # PENDING
    comments: Optional[str] = None

class ClientDocumentListItemDTO(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    
    id: int
    user_id: int
    document_type_id: int
    original_file_name: str
    upload_date: datetime
    status_id: int

class PaginatedClientDocumentsDTO(BaseModel):
    items: List[ClientDocumentListItemDTO]
    total: int
    limit: int
    offset: int
