"""Application DTOs - Addresses"""
from datetime import datetime
from typing import Optional
from pydantic import BaseModel, Field


class AddressResponseDTO(BaseModel):
    """DTO de respuesta con info de la dirección"""
    id: int
    user_id: int
    street: str
    external_number: str
    internal_number: Optional[str] = None
    colony: str
    municipality: str
    state: str
    zip_code: str
    created_at: datetime
    updated_at: datetime
    
    # Campo calculado
    full_address: Optional[str] = None
    
    class Config:
        from_attributes = True


class CreateAddressDTO(BaseModel):
    """DTO para crear una dirección"""
    user_id: int = Field(..., gt=0)
    street: str = Field(..., min_length=3, max_length=200)
    external_number: str = Field(..., min_length=1, max_length=20)
    internal_number: Optional[str] = Field(None, max_length=20)
    colony: str = Field(..., min_length=3, max_length=100)
    municipality: str = Field(..., min_length=3, max_length=100)
    state: str = Field(..., min_length=3, max_length=100)
    zip_code: str = Field(..., min_length=5, max_length=10)


class UpdateAddressDTO(BaseModel):
    """DTO para actualizar una dirección"""
    street: Optional[str] = Field(None, min_length=3, max_length=200)
    external_number: Optional[str] = Field(None, min_length=1, max_length=20)
    internal_number: Optional[str] = Field(None, max_length=20)
    colony: Optional[str] = Field(None, min_length=3, max_length=100)
    municipality: Optional[str] = Field(None, min_length=3, max_length=100)
    state: Optional[str] = Field(None, min_length=3, max_length=100)
    zip_code: Optional[str] = Field(None, min_length=5, max_length=10)


class AddressListItemDTO(BaseModel):
    """DTO simplificado para listar direcciones"""
    id: int
    user_id: int
    street: str
    colony: str
    municipality: str
    state: str
    zip_code: str
    
    class Config:
        from_attributes = True


class PaginatedAddressesDTO(BaseModel):
    """DTO para respuesta paginada"""
    items: list[AddressListItemDTO]
    total: int
    limit: int
    offset: int
