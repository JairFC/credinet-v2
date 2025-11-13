from sqlalchemy import Column, Integer, String, Numeric, Date, DateTime, ForeignKey, Text
from sqlalchemy.sql import func
from app.core.database import Base

class AgreementModel(Base):
    __tablename__ = "agreements"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    associate_profile_id = Column(Integer, ForeignKey("associate_profiles.id"), nullable=False)
    agreement_number = Column(String(50), nullable=True)
    agreement_date = Column(Date, nullable=False)
    total_debt_amount = Column(Numeric(10, 2), nullable=False)
    payment_plan_months = Column(Integer, nullable=False)
    monthly_payment_amount = Column(Numeric(10, 2), nullable=False)
    status = Column(String(50), nullable=False)
    start_date = Column(Date, nullable=False)
    end_date = Column(Date, nullable=False)
    created_by = Column(Integer, ForeignKey("users.id"), nullable=True)
    approved_by = Column(Integer, ForeignKey("users.id"), nullable=True)
    notes = Column(Text, nullable=True)
    created_at = Column(DateTime, nullable=False, server_default=func.current_timestamp())
    updated_at = Column(DateTime, nullable=False, server_default=func.current_timestamp(), onupdate=func.current_timestamp())
