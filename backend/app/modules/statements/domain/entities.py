"""Domain entities for statements module."""

from dataclasses import dataclass
from datetime import date, datetime
from decimal import Decimal
from typing import Optional


@dataclass
class Statement:
    """
    Associate Payment Statement entity.
    
    Represents a fortnight statement generated for an associate,
    containing all pending payments for that period.
    """
    
    id: int
    statement_number: str
    user_id: int
    cut_period_id: int
    
    # Statistics
    total_payments_count: int
    total_amount_collected: Decimal
    total_commission_owed: Decimal
    commission_rate_applied: Decimal
    
    # Status
    status_id: int
    
    # Dates
    generated_date: date
    sent_date: Optional[date]
    due_date: date
    paid_date: Optional[date]
    
    # Payment information
    paid_amount: Optional[Decimal]
    payment_method_id: Optional[int]
    payment_reference: Optional[str]
    
    # Late fees
    late_fee_amount: Decimal
    late_fee_applied: bool
    
    # Audit
    created_at: datetime
    updated_at: datetime
    
    # Computed properties
    @property
    def is_paid(self) -> bool:
        """Check if statement is fully paid."""
        return self.paid_date is not None and self.paid_amount == self.total_commission_owed
    
    @property
    def is_overdue(self) -> bool:
        """Check if statement is overdue."""
        from datetime import date as date_class
        return self.due_date < date_class.today() and not self.is_paid
    
    @property
    def days_overdue(self) -> int:
        """Calculate days overdue (0 if not overdue)."""
        if not self.is_overdue:
            return 0
        from datetime import date as date_class
        return (date_class.today() - self.due_date).days
    
    @property
    def remaining_amount(self) -> Decimal:
        """Calculate remaining amount to pay."""
        paid = self.paid_amount or Decimal("0.00")
        return self.total_commission_owed + self.late_fee_amount - paid
