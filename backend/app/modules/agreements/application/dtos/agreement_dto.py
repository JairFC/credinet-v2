from pydantic import BaseModel, ConfigDict
from datetime import date, datetime
from decimal import Decimal
from typing import List, Optional

class AgreementResponseDTO(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    
    id: int
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

class CreateAgreementDTO(BaseModel):
    associate_profile_id: int
    agreement_number: Optional[str] = None
    agreement_date: date
    total_debt_amount: Decimal
    payment_plan_months: int
    monthly_payment_amount: Decimal
    status: str = "DRAFT"
    start_date: date
    end_date: date
    created_by: Optional[int] = None
    approved_by: Optional[int] = None
    notes: Optional[str] = None

class AgreementListItemDTO(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    
    id: int
    associate_profile_id: int
    agreement_number: Optional[str]
    agreement_date: date
    total_debt_amount: Decimal
    status: str

class PaginatedAgreementsDTO(BaseModel):
    items: List[AgreementListItemDTO]
    total: int
    limit: int
    offset: int
