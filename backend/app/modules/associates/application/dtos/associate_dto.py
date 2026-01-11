"""Application DTOs - Associates Module"""
from datetime import datetime
from decimal import Decimal
from typing import Optional
from pydantic import BaseModel, Field


class AssociateResponseDTO(BaseModel):
    """DTO de respuesta con info completa del asociado
    
    MODELO DE DEUDA:
    - pending_payments_total: Suma de pagos PENDING (lo que debe cobrar/entregar)
    - consolidated_debt: Deuda consolidada (statements + convenios - pagos)
    - available_credit: credit_limit - pending_payments_total - consolidated_debt
    """
    id: int
    user_id: int
    level_id: int
    contact_person: Optional[str] = None
    contact_email: Optional[str] = None
    default_commission_rate: Decimal
    active: bool
    consecutive_full_credit_periods: int
    consecutive_on_time_payments: int
    clients_in_agreement: int
    last_level_evaluation_date: Optional[datetime] = None
    
    # Campos de crédito refactorizados
    pending_payments_total: Decimal  # Antes: credit_used
    credit_limit: Decimal
    available_credit: Decimal  # Antes: credit_available
    credit_last_updated: Optional[datetime] = None
    consolidated_debt: Decimal  # Antes: debt_balance
    
    created_at: datetime
    updated_at: datetime
    
    # Campos calculados
    credit_usage_percentage: Optional[float] = None
    
    # Campos del usuario (opcionales para retrocompatibilidad)
    username: Optional[str] = None
    email: Optional[str] = None
    phone_number: Optional[str] = None
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    full_name: Optional[str] = None
    
    class Config:
        from_attributes = True


class AssociateListItemDTO(BaseModel):
    """DTO simplificado para listar asociados"""
    id: int
    user_id: int
    username: Optional[str] = None
    full_name: Optional[str] = None
    email: Optional[str] = None
    level_id: Optional[int] = None
    credit_limit: Decimal
    pending_payments_total: Decimal  # Antes: credit_used
    available_credit: Decimal  # Antes: credit_available
    consolidated_debt: Decimal = Decimal('0.00')  # Antes: debt_balance
    pending_debts_count: int = 0
    active: bool
    
    class Config:
        from_attributes = True


class AssociateCreditSummaryDTO(BaseModel):
    """DTO para resumen de crédito del asociado"""
    associate_id: int
    user_id: int
    credit_limit: Decimal
    pending_payments_total: Decimal  # Antes: credit_used
    available_credit: Decimal  # Antes: credit_available
    credit_usage_percentage: float
    active_loans_count: int = 0
    total_disbursed: Decimal = Decimal('0')
    
    class Config:
        from_attributes = True


class AssociateSearchItemDTO(BaseModel):
    """DTO para búsqueda de asociados con crédito disponible"""
    id: int
    user_id: int
    username: str
    full_name: str
    email: Optional[str] = None
    phone_number: Optional[str] = None
    level_id: int
    credit_limit: Decimal
    pending_payments_total: Decimal  # Antes: credit_used
    available_credit: Decimal  # Antes: credit_available
    credit_usage_percentage: float
    active: bool
    can_grant_loans: bool = Field(True, description="Puede otorgar préstamos")
    
    class Config:
        from_attributes = True
    
    class Config:
        from_attributes = True


class PaginatedAssociatesDTO(BaseModel):
    """DTO para respuesta paginada de asociados"""
    items: list[AssociateListItemDTO]
    total: int
    limit: int
    offset: int

from datetime import date
from decimal import Decimal
from typing import Optional
from pydantic import BaseModel, EmailStr, Field, validator


class CreateAssociateRequest(BaseModel):
    """Solicitud para crear un asociado completo con usuario y perfil"""
    
    # ========== Datos del Usuario ==========
    username: str = Field(..., min_length=3, max_length=50)
    password: str = Field(..., min_length=6)
    first_name: str = Field(..., min_length=1, max_length=100)
    paternal_last_name: str = Field(..., min_length=1, max_length=100, alias="paternal_last_name")
    maternal_last_name: Optional[str] = Field(None, max_length=100, alias="maternal_last_name")
    email: EmailStr
    phone_number: str = Field(..., min_length=10, max_length=10)
    curp: Optional[str] = Field(None, min_length=18, max_length=18)
    birth_date: Optional[date] = None
    gender: Optional[str] = Field(None, min_length=1, max_length=1)  # M o F
    birth_state: Optional[str] = Field(None, min_length=2, max_length=2)  # Código del estado
    
    # ========== Datos del Perfil de Asociado ==========
    credit_limit: Decimal = Field(..., gt=0, decimal_places=2)
    contact_person: Optional[str] = Field(None, max_length=150)
    contact_email: Optional[EmailStr] = None
    default_commission_rate: Decimal = Field(Decimal("5.0"), ge=0, le=100, decimal_places=2)
    level_id: int = Field(1, ge=1, le=5)  # Default Bronce
    
    @validator('phone_number')
    def validate_phone(cls, v):
        """Valida que el teléfono sean solo dígitos"""
        if not v.isdigit():
            raise ValueError('El teléfono debe contener solo dígitos')
        if len(v) != 10:
            raise ValueError('El teléfono debe tener exactamente 10 dígitos')
        return v
    
    @validator('curp')
    def validate_curp(cls, v):
        """Valida longitud del CURP si se proporciona"""
        if v and len(v) != 18:
            raise ValueError('El CURP debe tener exactamente 18 caracteres')
        return v
    
    @validator('gender')
    def validate_gender(cls, v):
        """Valida que el género sea M o F"""
        if v and v.upper() not in ['M', 'F']:
            raise ValueError('El género debe ser M (masculino) o F (femenino)')
        return v.upper() if v else None
    
    class Config:
        populate_by_name = True  # Permite usar alias
        json_schema_extra = {
            "example": {
                "username": "asociado01",
                "password": "SecurePass123",
                "first_name": "Juan",
                "paternal_last_name": "Pérez",
                "maternal_last_name": "García",
                "email": "juan.perez@example.com",
                "phone_number": "5551234567",
                "curp": "PEGJ850101HDFRNN09",
                "birth_date": "1985-01-01",
                "gender": "M",
                "birth_state": "DF",
                "credit_limit": 50000.00,
                "contact_person": "María López",
                "contact_email": "contacto@example.com",
                "default_commission_rate": 5.0,
                "level_id": 1
            }
        }
