from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from typing import List, Optional
from ...domain.entities import Agreement
from ...domain.repositories import AgreementRepository
from ..models import AgreementModel

def _map_model_to_entity(model: AgreementModel) -> Agreement:
    return Agreement(
        id=model.id,
        associate_profile_id=model.associate_profile_id,
        agreement_number=model.agreement_number,
        agreement_date=model.agreement_date,
        total_debt_amount=model.total_debt_amount,
        payment_plan_months=model.payment_plan_months,
        monthly_payment_amount=model.monthly_payment_amount,
        status=model.status,
        start_date=model.start_date,
        end_date=model.end_date,
        created_by=model.created_by,
        approved_by=model.approved_by,
        notes=model.notes,
        created_at=model.created_at,
        updated_at=model.updated_at
    )

class PgAgreementRepository(AgreementRepository):
    def __init__(self, session: AsyncSession):
        self.session = session
    
    async def find_by_id(self, agreement_id: int) -> Optional[Agreement]:
        stmt = select(AgreementModel).where(AgreementModel.id == agreement_id)
        result = await self.session.execute(stmt)
        model = result.scalar_one_or_none()
        return _map_model_to_entity(model) if model else None
    
    async def find_by_associate(self, associate_profile_id: int) -> List[Agreement]:
        stmt = select(AgreementModel).where(
            AgreementModel.associate_profile_id == associate_profile_id
        ).order_by(AgreementModel.id.desc())
        result = await self.session.execute(stmt)
        models = result.scalars().all()
        return [_map_model_to_entity(m) for m in models]
    
    async def find_all(self, limit: int = 50, offset: int = 0) -> List[Agreement]:
        stmt = select(AgreementModel).order_by(
            AgreementModel.id.desc()
        ).limit(limit).offset(offset)
        result = await self.session.execute(stmt)
        models = result.scalars().all()
        return [_map_model_to_entity(m) for m in models]
    
    async def count(self) -> int:
        stmt = select(func.count()).select_from(AgreementModel)
        result = await self.session.execute(stmt)
        return result.scalar_one()
    
    async def create(self, agreement: Agreement) -> Agreement:
        model = AgreementModel(
            associate_profile_id=agreement.associate_profile_id,
            agreement_number=agreement.agreement_number,
            agreement_date=agreement.agreement_date,
            total_debt_amount=agreement.total_debt_amount,
            payment_plan_months=agreement.payment_plan_months,
            monthly_payment_amount=agreement.monthly_payment_amount,
            status=agreement.status,
            start_date=agreement.start_date,
            end_date=agreement.end_date,
            created_by=agreement.created_by,
            approved_by=agreement.approved_by,
            notes=agreement.notes
        )
        self.session.add(model)
        await self.session.flush()
        await self.session.refresh(model)
        return _map_model_to_entity(model)
