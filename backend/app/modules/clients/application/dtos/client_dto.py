"""Application DTOs - Clients Module"""
from datetime import date, datetime
from decimal import Decimal
from typing import Optional
from pydantic import BaseModel, Field, EmailStr


class AddressNestedDTO(BaseModel):
    """DTO anidado para la dirección del cliente"""
    street: str
    external_number: str
    internal_number: Optional[str] = None
    colony: str
    municipality: str
    state: str
    zip_code: str
    
    class Config:
        from_attributes = True


class GuarantorNestedDTO(BaseModel):
    """DTO anidado para el aval del cliente"""
    full_name: str
    relationship: str
    phone_number: str
    curp: Optional[str] = None
    
    class Config:
        from_attributes = True


class BeneficiaryNestedDTO(BaseModel):
    """DTO anidado para el beneficiario del cliente"""
    full_name: str
    relationship: str
    phone_number: str
    
    class Config:
        from_attributes = True


class ClientResponseDTO(BaseModel):
    """DTO de respuesta con info completa del cliente"""
    id: int
    username: str
    first_name: str
    last_name: str
    email: EmailStr
    phone_number: Optional[str] = None
    birth_date: Optional[date] = None
    curp: Optional[str] = None
    profile_picture_url: Optional[str] = None
    active: bool
    created_at: datetime
    updated_at: datetime
    
    # Campos calculados
    full_name: Optional[str] = None
    
    # Relaciones opcionales
    address: Optional[AddressNestedDTO] = None
    guarantor: Optional[GuarantorNestedDTO] = None
    beneficiary: Optional[BeneficiaryNestedDTO] = None
    
    class Config:
        from_attributes = True


class ClientListItemDTO(BaseModel):
    """DTO simplificado para listar clientes"""
    id: int
    username: str
    full_name: str
    email: EmailStr
    phone_number: Optional[str] = None
    active: bool
    
    class Config:
        from_attributes = True


class CreateClientDTO(BaseModel):
    """DTO para crear un nuevo cliente"""
    username: str = Field(..., min_length=3, max_length=50)
    password: str = Field(..., min_length=8)
    first_name: str = Field(..., min_length=2, max_length=100)
    last_name: str = Field(..., min_length=2, max_length=100)
    email: EmailStr
    phone_number: Optional[str] = Field(None, max_length=20)
    birth_date: Optional[date] = None
    curp: Optional[str] = Field(None, max_length=18)
    
    class Config:
        json_schema_extra = {
            "example": {
                "username": "maria.gonzalez",
                "password": "SecurePass123",
                "first_name": "María",
                "last_name": "González",
                "email": "maria.gonzalez@email.com",
                "phone_number": "5551234567",
                "birth_date": "1990-05-15",
                "curp": "GOGM900515MDFNRR02"
            }
        }


class ClientSearchItemDTO(BaseModel):
    """DTO para búsqueda de clientes elegibles para préstamos"""
    id: int
    username: str
    full_name: str
    email: EmailStr
    phone_number: Optional[str] = None
    active: bool
    # Estado financiero
    has_overdue_payments: bool = Field(False, description="Tiene pagos vencidos")
    total_debt: Decimal = Field(Decimal('0.00'), description="Deuda total actual")
    active_loans: int = Field(0, description="Préstamos activos")
    
    class Config:
        from_attributes = True


class PaginatedClientsDTO(BaseModel):
    """DTO para respuesta paginada de clientes"""
    items: list[ClientListItemDTO]
    total: int
    limit: int
    offset: int


class UpdateClientDTO(BaseModel):
    """DTO para actualización parcial de datos del cliente"""
    first_name: Optional[str] = Field(None, min_length=2, max_length=100)
    last_name: Optional[str] = Field(None, min_length=2, max_length=100)
    email: Optional[EmailStr] = None
    phone_number: Optional[str] = Field(None, max_length=10, pattern=r'^\d{10}$')
    birth_date: Optional[date] = None
    curp: Optional[str] = Field(None, max_length=18, pattern=r'^[A-Z]{4}\d{6}[HM][A-Z]{5}[A-Z0-9]\d$')
    
    class Config:
        json_schema_extra = {
            "example": {
                "first_name": "María",
                "last_name": "González Pérez",
                "phone_number": "5551234567",
                "curp": "GOGM900515MDFNRR02"
            }
        }


class UpdateAddressDTO(BaseModel):
    """DTO para actualización parcial de dirección"""
    street: Optional[str] = Field(None, max_length=200)
    external_number: Optional[str] = Field(None, max_length=20)
    internal_number: Optional[str] = Field(None, max_length=20)
    colony: Optional[str] = Field(None, max_length=100)
    municipality: Optional[str] = Field(None, max_length=100)
    state: Optional[str] = Field(None, max_length=100)
    zip_code: Optional[str] = Field(None, max_length=10, pattern=r'^\d{5}$')
    
    class Config:
        json_schema_extra = {
            "example": {
                "street": "Av. Insurgentes Sur",
                "external_number": "1234",
                "colony": "Del Valle",
                "municipality": "Benito Juárez",
                "state": "Ciudad de México",
                "zip_code": "03100"
            }
        }


class UpdateGuarantorDTO(BaseModel):
    """DTO para actualización parcial de aval"""
    full_name: Optional[str] = Field(None, max_length=200)
    relationship: Optional[str] = Field(None, max_length=50)
    phone_number: Optional[str] = Field(None, max_length=20)
    curp: Optional[str] = Field(None, max_length=18, pattern=r'^[A-Z]{4}\d{6}[HM][A-Z]{5}[A-Z0-9]\d$')
    
    class Config:
        json_schema_extra = {
            "example": {
                "full_name": "Juan Pérez López",
                "relationship": "Hermano",
                "phone_number": "5559876543"
            }
        }


class UpdateBeneficiaryDTO(BaseModel):
    """DTO para actualización parcial de beneficiario"""
    full_name: Optional[str] = Field(None, max_length=200)
    relationship: Optional[str] = Field(None, max_length=50)
    phone_number: Optional[str] = Field(None, max_length=20)
    
    class Config:
        json_schema_extra = {
            "example": {
                "full_name": "Ana Pérez López",
                "relationship": "Esposa",
                "phone_number": "5553214567"
            }
        }
