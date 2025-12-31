"""DTOs for statements module."""

from pydantic import BaseModel, Field, ConfigDict
from decimal import Decimal
from datetime import date, datetime
from typing import Optional


class CreateStatementDTO(BaseModel):
    """DTO for creating a new statement."""
    
    user_id: int = Field(..., description="Associate user ID", gt=0)
    cut_period_id: int = Field(..., description="Cut period ID", gt=0)
    total_payments_count: int = Field(0, description="Number of payments", ge=0)
    total_amount_collected: Decimal = Field(
        Decimal("0.00"),
        description="Total amount collected from clients",
        ge=0
    )
    total_to_credicuenta: Decimal = Field(
        Decimal("0.00"),
        description="Total amount owed to CrediCuenta (monto a pagar)",
        ge=0
    )
    commission_earned: Decimal = Field(
        Decimal("0.00"),
        description="Commission earned by associate (total_collected - total_to_credicuenta)",
        ge=0
    )
    commission_rate_applied: Decimal = Field(
        ...,
        description="Commission rate applied (%)",
        ge=0,
        le=100
    )
    generated_date: date = Field(..., description="Generation date")
    due_date: date = Field(..., description="Payment due date")
    
    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "user_id": 3,
                "cut_period_id": 5,
                "total_payments_count": 97,
                "total_amount_collected": "103697.00",
                "total_to_credicuenta": "91017.00",
                "commission_earned": "12680.00",
                "commission_rate_applied": "2.50",
                "generated_date": "2025-01-08",
                "due_date": "2025-01-29"
            }
        }
    )


class MarkStatementPaidDTO(BaseModel):
    """DTO for marking statement as paid."""
    
    paid_amount: Decimal = Field(..., description="Amount paid", gt=0)
    paid_date: date = Field(..., description="Payment date")
    payment_method_id: int = Field(..., description="Payment method ID", gt=0)
    payment_reference: Optional[str] = Field(
        None,
        description="Payment reference/confirmation number",
        max_length=100
    )
    
    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "paid_amount": "12680.00",
                "paid_date": "2025-01-15",
                "payment_method_id": 2,
                "payment_reference": "TRANS-2025-00123"
            }
        }
    )


class ApplyLateFeeDTO(BaseModel):
    """DTO for applying late fee."""
    
    late_fee_amount: Decimal = Field(..., description="Late fee amount", gt=0)
    reason: Optional[str] = Field(None, description="Reason for late fee")
    
    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "late_fee_amount": "500.00",
                "reason": "Payment overdue by 15 days"
            }
        }
    )


class StatementResponseDTO(BaseModel):
    """Complete statement response DTO."""
    
    id: int
    statement_number: str
    user_id: int
    associate_name: str
    cut_period_id: int
    cut_period_code: str
    
    # Statistics
    total_payments_count: int
    total_amount_collected: Decimal
    total_to_credicuenta: Decimal
    commission_earned: Decimal
    commission_rate_applied: Decimal
    
    # Status
    status_id: int
    status_name: str
    
    # Dates
    generated_date: date
    sent_date: Optional[date]
    due_date: date
    paid_date: Optional[date]
    
    # Payment
    paid_amount: Optional[Decimal]
    payment_method_id: Optional[int]
    payment_method_name: Optional[str]
    payment_reference: Optional[str]
    
    # Late fees
    late_fee_amount: Decimal
    late_fee_applied: bool
    
    # Computed
    is_paid: bool
    is_overdue: bool
    days_overdue: int
    remaining_amount: Decimal
    
    # Audit
    created_at: datetime
    updated_at: datetime
    
    model_config = ConfigDict(from_attributes=True)


class StatementSummaryDTO(BaseModel):
    """Summary statement DTO for listings."""
    
    id: int
    statement_number: str
    associate_name: str
    cut_period_code: str
    total_payments_count: int
    total_to_credicuenta: Decimal
    commission_earned: Decimal
    status_name: str
    due_date: date
    is_overdue: bool
    remaining_amount: Decimal
    
    model_config = ConfigDict(from_attributes=True)


class PeriodStatsDTO(BaseModel):
    """Statistics for a cut period."""
    
    cut_period_id: int
    cut_period_code: str
    total_statements: int
    total_associates: int
    total_payments: int
    total_collected: Decimal
    total_commissions: Decimal
    paid_statements: int
    overdue_statements: int
    pending_statements: int
    
    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "cut_period_id": 5,
                "cut_period_code": "2025-Q01",
                "total_statements": 15,
                "total_associates": 15,
                "total_payments": 342,
                "total_collected": "892450.00",
                "total_commissions": "105678.00",
                "paid_statements": 12,
                "overdue_statements": 2,
                "pending_statements": 1
            }
        }
    )
