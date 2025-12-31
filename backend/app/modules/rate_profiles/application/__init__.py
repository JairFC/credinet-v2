"""
DTOs (Data Transfer Objects) para el módulo de perfiles de tasa.
"""
from decimal import Decimal
from typing import Optional, List

from pydantic import BaseModel, Field, ConfigDict


class RateProfileDTO(BaseModel):
    """DTO para perfil de tasa."""
    id: int
    code: str
    name: str
    description: Optional[str] = None
    calculation_type: str
    interest_rate_percent: Optional[Decimal] = None
    commission_rate_percent: Optional[Decimal] = None
    enabled: bool
    is_recommended: bool
    display_order: int
    valid_terms: Optional[List[int]] = Field(None, description="Plazos válidos en quincenas")
    min_amount: Optional[Decimal] = Field(None, description="Monto mínimo permitido")
    max_amount: Optional[Decimal] = Field(None, description="Monto máximo permitido")
    
    model_config = ConfigDict(from_attributes=True)


class LegacyAmountDTO(BaseModel):
    """DTO para montos disponibles en legacy_payment_table."""
    amount: Decimal
    biweekly_payment: Decimal
    total_payment: Decimal
    total_interest: Decimal
    effective_rate_percent: Decimal
    
    model_config = ConfigDict(from_attributes=True)


class CalculateLoanRequest(BaseModel):
    """DTO para solicitar cálculo de préstamo."""
    amount: Decimal = Field(..., gt=0, description="Monto del préstamo")
    term_biweeks: int = Field(..., ge=1, le=52, description="Plazo en quincenas")
    profile_code: str = Field(..., description="Código del perfil de tasa")
    
    # Tasas opcionales para profile_code='custom'
    interest_rate: Decimal | None = Field(None, ge=0, le=20, description="Tasa de interés por quincena (solo para custom)")
    commission_rate: Decimal | None = Field(None, ge=0, le=10, description="Tasa de comisión % del monto (solo para custom)")
    
    model_config = ConfigDict(from_attributes=True)


class LoanCalculationDTO(BaseModel):
    """DTO para resultado de cálculo de préstamo."""
    # Datos de entrada
    profile_code: str
    profile_name: str
    calculation_method: str
    amount: Decimal
    term_biweeks: int
    
    # LAS DOS TASAS
    interest_rate_percent: Decimal
    commission_rate_percent: Decimal
    
    # Cálculos CLIENTE
    biweekly_payment: Decimal = Field(..., description="Pago quincenal del cliente")
    total_payment: Decimal = Field(..., description="Total a pagar por el cliente")
    total_interest: Decimal = Field(..., description="Interés total")
    effective_rate_percent: Decimal = Field(..., description="Tasa efectiva total (%)")
    
    # Cálculos ASOCIADO
    commission_per_payment: Decimal = Field(..., description="Comisión por pago")
    total_commission: Decimal = Field(..., description="Comisión total al asociado")
    associate_payment: Decimal = Field(..., description="Pago quincenal al asociado")
    associate_total: Decimal = Field(..., description="Total al asociado")
    
    model_config = ConfigDict(from_attributes=True)


class CompareProfilesRequest(BaseModel):
    """DTO para comparar múltiples perfiles."""
    amount: Decimal = Field(..., gt=0, description="Monto del préstamo")
    term_biweeks: int = Field(..., ge=1, le=52, description="Plazo en quincenas")
    profile_codes: list[str] = Field(
        ..., 
        min_length=2, 
        max_length=5, 
        description="Lista de códigos de perfiles a comparar (2-5)"
    )
    
    model_config = ConfigDict(from_attributes=True)


class CompareProfilesResponse(BaseModel):
    """DTO para respuesta de comparación de perfiles."""
    amount: Decimal
    term_biweeks: int
    calculations: list[LoanCalculationDTO]
    
    model_config = ConfigDict(from_attributes=True)


__all__ = [
    'RateProfileDTO',
    'LegacyAmountDTO',
    'CalculateLoanRequest',
    'LoanCalculationDTO',
    'CompareProfilesRequest',
    'CompareProfilesResponse',
]
