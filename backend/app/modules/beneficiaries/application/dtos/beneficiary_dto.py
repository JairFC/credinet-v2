"""Application DTOs - Beneficiaries"""
from datetime import datetime
from typing import Optional
from pydantic import BaseModel, Field


class BeneficiaryResponseDTO(BaseModel):
    """DTO de respuesta con info del beneficiario"""
    id: int
    user_id: int
    full_name: str
    relationship: str
    phone_number: str
    created_at: datetime
    updated_at: datetime
    
    class Config:
        from_attributes = True


class CreateBeneficiaryDTO(BaseModel):
    """DTO para crear un beneficiario"""
    user_id: int = Field(..., gt=0)
    full_name: str = Field(..., min_length=3, max_length=200)
    relationship: str = Field(..., min_length=3, max_length=50)
    relationship_id: Optional[int] = Field(None, gt=0)  # ID del catálogo de relaciones
    phone_number: str = Field(..., min_length=10, max_length=20)


class BeneficiaryListItemDTO(BaseModel):
    """DTO simplificado para listar beneficiarios"""
    id: int
    user_id: int
    full_name: str
    relationship: str
    phone_number: str
    
    class Config:
        from_attributes = True


class PaginatedBeneficiariesDTO(BaseModel):
    """DTO para respuesta paginada"""
    items: list[BeneficiaryListItemDTO]
    total: int
    limit: int
    offset: int
