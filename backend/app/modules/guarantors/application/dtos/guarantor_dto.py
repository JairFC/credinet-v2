"""Application DTOs - Guarantors"""
from datetime import datetime
from typing import Optional
from pydantic import BaseModel, Field


class GuarantorResponseDTO(BaseModel):
    """DTO de respuesta con info del aval"""
    id: int
    user_id: int
    full_name: str
    first_name: Optional[str] = None
    paternal_last_name: Optional[str] = None
    maternal_last_name: Optional[str] = None
    relationship: str
    phone_number: str
    curp: Optional[str] = None
    created_at: datetime
    updated_at: datetime
    
    class Config:
        from_attributes = True


class CreateGuarantorDTO(BaseModel):
    """DTO para crear un aval"""
    user_id: int = Field(..., gt=0)
    full_name: str = Field(..., min_length=3, max_length=200)
    first_name: Optional[str] = Field(None, max_length=100)
    paternal_last_name: Optional[str] = Field(None, max_length=100)
    maternal_last_name: Optional[str] = Field(None, max_length=100)
    relationship: str = Field(..., min_length=3, max_length=50)
    relationship_id: Optional[int] = Field(None, gt=0)  # ID del catálogo de relaciones
    phone_number: str = Field(..., min_length=10, max_length=20)
    curp: Optional[str] = Field(None, min_length=18, max_length=18)


class GuarantorListItemDTO(BaseModel):
    """DTO simplificado para listar avales"""
    id: int
    user_id: int
    full_name: str
    relationship: str
    phone_number: str
    has_curp: bool
    
    class Config:
        from_attributes = True


class PaginatedGuarantorsDTO(BaseModel):
    """DTO para respuesta paginada"""
    items: list[GuarantorListItemDTO]
    total: int
    limit: int
    offset: int
