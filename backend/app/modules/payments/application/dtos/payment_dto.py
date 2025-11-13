"""
Application DTOs: Payment Data Transfer Objects
"""
from datetime import date, datetime
from decimal import Decimal
from typing import Optional
from pydantic import BaseModel, Field, validator


class RegisterPaymentDTO(BaseModel):
    """DTO para registrar un pago"""
    payment_id: int = Field(..., gt=0, description="ID del pago a registrar")
    amount_paid: Decimal = Field(..., gt=0, description="Monto pagado")
    payment_date: date = Field(..., description="Fecha en que se realizó el pago")
    marked_by: int = Field(..., gt=0, description="Usuario que registra el pago")
    notes: Optional[str] = Field(None, max_length=500, description="Notas opcionales")
    
    class Config:
        json_schema_extra = {
            "example": {
                "payment_id": 123,
                "amount_paid": 1733.33,
                "payment_date": "2025-11-15",
                "marked_by": 1,
                "notes": "Pago realizado en efectivo"
            }
        }


class UpdatePaymentStatusDTO(BaseModel):
    """DTO para actualizar estado de un pago"""
    status_id: int = Field(..., gt=0, description="Nuevo status_id")
    reason: Optional[str] = Field(None, max_length=500, description="Razón del cambio")
    
    @validator('status_id')
    def validate_status(cls, v):
        # 1=PENDING, 2=PARTIAL, 3=PAID, 4=OVERDUE, 5=CANCELLED
        if v not in [1, 2, 3, 4, 5]:
            raise ValueError('status_id debe ser 1-5')
        return v


class PaymentResponseDTO(BaseModel):
    """DTO de respuesta con info completa del pago"""
    id: int
    loan_id: int
    payment_number: int
    expected_amount: Decimal
    amount_paid: Decimal
    interest_amount: Decimal
    principal_amount: Decimal
    commission_amount: Decimal
    associate_payment: Decimal
    balance_remaining: Decimal
    payment_date: date
    payment_due_date: date
    is_late: bool
    status_id: int
    status_name: Optional[str] = None
    cut_period_id: Optional[int] = None
    marked_by: Optional[int] = None
    marked_at: Optional[datetime] = None
    marking_notes: Optional[str] = None
    created_at: datetime
    updated_at: datetime
    
    # Campos calculados
    remaining_amount: Optional[Decimal] = None
    is_paid: Optional[bool] = None
    is_overdue: Optional[bool] = None
    
    class Config:
        from_attributes = True
        json_schema_extra = {
            "example": {
                "id": 123,
                "loan_id": 10,
                "payment_number": 1,
                "expected_amount": 1733.33,
                "amount_paid": 1733.33,
                "interest_amount": 66.67,
                "principal_amount": 1666.66,
                "commission_amount": 43.33,
                "associate_payment": 1690.00,
                "balance_remaining": 8333.34,
                "payment_date": "2025-11-15",
                "payment_due_date": "2025-11-15",
                "is_late": False,
                "status_id": 3,
                "status_name": "PAID",
                "remaining_amount": 0.00,
                "is_paid": True
            }
        }


class PaymentSummaryDTO(BaseModel):
    """DTO con resumen de pagos de un préstamo"""
    loan_id: int
    total_payments: int
    payments_paid: int
    payments_pending: int
    payments_overdue: int
    total_expected: Decimal
    total_paid: Decimal
    total_pending: Decimal
    next_payment_due_date: Optional[date] = None
    next_payment_amount: Optional[Decimal] = None
    
    class Config:
        json_schema_extra = {
            "example": {
                "loan_id": 10,
                "total_payments": 24,
                "payments_paid": 5,
                "payments_pending": 19,
                "payments_overdue": 2,
                "total_expected": 51500.00,
                "total_paid": 8666.65,
                "total_pending": 42833.35,
                "next_payment_due_date": "2025-12-15",
                "next_payment_amount": 2145.83
            }
        }


class PaymentListItemDTO(BaseModel):
    """DTO para listar pagos (versión simplificada)"""
    id: int
    payment_number: int
    payment_due_date: date
    expected_amount: Decimal
    amount_paid: Decimal
    status_name: str
    is_late: bool
    
    class Config:
        from_attributes = True
