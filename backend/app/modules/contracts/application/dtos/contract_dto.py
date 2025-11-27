"""Application DTOs - Contracts"""
from datetime import date, datetime
from typing import Optional
from pydantic import BaseModel, Field


class ContractResponseDTO(BaseModel):
    id: int
    loan_id: int
    file_path: Optional[str] = None
    start_date: date
    sign_date: Optional[date] = None
    document_number: str
    status_id: int
    created_at: datetime
    updated_at: datetime
    
    class Config:
        from_attributes = True


class CreateContractDTO(BaseModel):
    loan_id: int = Field(..., gt=0)
    start_date: date
    document_number: str = Field(..., min_length=5, max_length=50)
    status_id: int = Field(..., gt=0)


class ContractListItemDTO(BaseModel):
    id: int
    loan_id: int
    document_number: str
    status_id: int
    sign_date: Optional[date] = None
    
    class Config:
        from_attributes = True


class PaginatedContractsDTO(BaseModel):
    items: list[ContractListItemDTO]
    total: int
    limit: int
    offset: int
