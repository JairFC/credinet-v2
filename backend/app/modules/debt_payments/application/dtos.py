"""
DTOs para el módulo de Debt Payments.
"""
from datetime import date
from decimal import Decimal
from typing import Optional, List, Dict, Any
from pydantic import BaseModel, Field, field_validator


class RegisterDebtPaymentDTO(BaseModel):
    """DTO para registrar un nuevo pago de deuda."""
    
    associate_profile_id: int = Field(..., gt=0, description="ID del perfil del asociado")
    payment_amount: Decimal = Field(..., gt=0, description="Monto del abono")
    payment_date: date = Field(..., description="Fecha del pago")
    payment_method_id: int = Field(..., gt=0, description="Método de pago")
    payment_reference: Optional[str] = Field(None, max_length=100, description="Referencia bancaria")
    notes: Optional[str] = Field(None, description="Notas adicionales")
    
    @field_validator('payment_date')
    @classmethod
    def validate_payment_date(cls, v: date) -> date:
        """Validar que la fecha no sea futura."""
        from datetime import date as date_type
        if v > date_type.today():
            raise ValueError("payment_date no puede ser una fecha futura")
        return v
    
    class Config:
        json_schema_extra = {
            "example": {
                "associate_profile_id": 5,
                "payment_amount": "50000.00",
                "payment_date": "2025-11-13",
                "payment_method_id": 1,
                "payment_reference": "TRF-20251113-001",
                "notes": "Abono a deuda acumulada"
            }
        }


class DebtPaymentResponseDTO(BaseModel):
    """DTO de respuesta con detalles del pago registrado."""
    
    id: int
    associate_profile_id: int
    associate_name: str
    payment_amount: Decimal
    payment_date: date
    payment_method_id: int
    payment_method_name: str
    payment_reference: Optional[str]
    registered_by: int
    registered_by_name: str
    applied_breakdown_items: List[Dict[str, Any]]
    total_items_liquidated: int
    total_items_partial: int
    notes: Optional[str]
    created_at: date
    
    class Config:
        json_schema_extra = {
            "example": {
                "id": 1,
                "associate_profile_id": 5,
                "associate_name": "Juan Pérez",
                "payment_amount": "50000.00",
                "payment_date": "2025-11-13",
                "payment_method_id": 1,
                "payment_method_name": "Transferencia",
                "payment_reference": "TRF-20251113-001",
                "registered_by": 1,
                "registered_by_name": "Admin User",
                "applied_breakdown_items": [
                    {
                        "breakdown_id": 10,
                        "cut_period_id": 5,
                        "original_amount": "30000.00",
                        "amount_applied": "30000.00",
                        "liquidated": True,
                        "applied_at": "2025-11-13"
                    },
                    {
                        "breakdown_id": 11,
                        "cut_period_id": 6,
                        "original_amount": "25000.00",
                        "amount_applied": "20000.00",
                        "liquidated": False,
                        "remaining_amount": "5000.00",
                        "applied_at": "2025-11-13"
                    }
                ],
                "total_items_liquidated": 1,
                "total_items_partial": 1,
                "notes": "Abono a deuda acumulada",
                "created_at": "2025-11-13T10:30:00"
            }
        }


class DebtPaymentSummaryDTO(BaseModel):
    """DTO resumido para listados."""
    
    id: int
    associate_name: str
    payment_amount: Decimal
    payment_date: date
    payment_method_name: str
    items_liquidated: int
    registered_by_name: str
    created_at: date


class AssociateDebtSummaryDTO(BaseModel):
    """DTO con resumen de deuda de un asociado."""
    
    associate_profile_id: int
    associate_name: str
    current_debt_balance: Decimal
    pending_debt_items: int
    liquidated_debt_items: int
    total_paid_to_debt: Decimal
    oldest_debt_date: Optional[date]
    last_payment_date: Optional[date]
    total_payments_count: int
    credit_available: Decimal
    credit_limit: Decimal
    
    class Config:
        json_schema_extra = {
            "example": {
                "associate_profile_id": 5,
                "associate_name": "Juan Pérez",
                "current_debt_balance": "15000.00",
                "pending_debt_items": 2,
                "liquidated_debt_items": 5,
                "total_paid_to_debt": "85000.00",
                "oldest_debt_date": "2025-09-15",
                "last_payment_date": "2025-11-13",
                "total_payments_count": 8,
                "credit_available": "250000.00",
                "credit_limit": "300000.00"
            }
        }
