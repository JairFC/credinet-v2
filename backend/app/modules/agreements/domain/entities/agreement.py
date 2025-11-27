from dataclasses import dataclass
from datetime import date, datetime
from typing import Optional
from decimal import Decimal

@dataclass
class Agreement:
    id: Optional[int]
    associate_profile_id: int
    agreement_number: Optional[str]
    agreement_date: date
    total_debt_amount: Decimal
    payment_plan_months: int
    monthly_payment_amount: Decimal
    status: str
    start_date: date
    end_date: date
    created_by: Optional[int]
    approved_by: Optional[int]
    notes: Optional[str]
    created_at: datetime
    updated_at: datetime
    
    def is_active(self) -> bool:
        return self.status.upper() == 'ACTIVE'
    
    def is_completed(self) -> bool:
        return self.status.upper() == 'COMPLETED'
