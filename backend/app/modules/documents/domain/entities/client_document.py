from dataclasses import dataclass
from datetime import datetime
from typing import Optional

@dataclass
class ClientDocument:
    id: Optional[int]
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
    
    def is_verified(self) -> bool:
        return self.status_id == 3  # VERIFIED
    
    def is_rejected(self) -> bool:
        return self.status_id == 4  # REJECTED
