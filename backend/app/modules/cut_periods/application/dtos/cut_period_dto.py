"""Application DTOs - Cut Periods Module"""
from datetime import date, datetime
from decimal import Decimal
from typing import Optional
from pydantic import BaseModel


class CutPeriodResponseDTO(BaseModel):
    """DTO de respuesta con info completa del periodo"""
    id: int
    cut_number: int
    period_start_date: date
    period_end_date: date
    status_id: int
    total_payments_expected: Decimal
    total_payments_received: Decimal
    total_commission: Decimal
    created_by: Optional[int] = None
    closed_by: Optional[int] = None
    created_at: datetime
    updated_at: datetime
    
    # Campos calculados
    collection_percentage: Optional[float] = None
    
    class Config:
        from_attributes = True


class CutPeriodListItemDTO(BaseModel):
    """DTO simplificado para listar periodos"""
    id: int
    cut_number: int
    cut_code: str
    period_start_date: date
    period_end_date: date
    payment_date: date
    cut_date: date
    status_id: int
    collection_percentage: float
    
    class Config:
        from_attributes = True


class PaginatedCutPeriodsDTO(BaseModel):
    """DTO para respuesta paginada de periodos"""
    items: list[CutPeriodListItemDTO]
    total: int
    limit: int
    offset: int
