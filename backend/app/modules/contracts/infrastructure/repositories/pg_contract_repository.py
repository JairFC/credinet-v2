"""Repositorio PostgreSQL de Contracts"""
from typing import List, Optional

from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.contracts.domain.entities.contract import Contract
from app.modules.contracts.domain.repositories.contract_repository import ContractRepository
from app.modules.contracts.infrastructure.models import ContractModel


def _map_model_to_entity(model: ContractModel) -> Contract:
    return Contract(
        id=model.id,
        loan_id=model.loan_id,
        file_path=model.file_path,
        start_date=model.start_date,
        sign_date=model.sign_date,
        document_number=model.document_number,
        status_id=model.status_id,
        created_at=model.created_at,
        updated_at=model.updated_at,
    )


class PgContractRepository(ContractRepository):
    def __init__(self, db: AsyncSession):
        self._db = db
    
    async def find_by_id(self, contract_id: int) -> Optional[Contract]:
        stmt = select(ContractModel).where(ContractModel.id == contract_id)
        result = await self._db.execute(stmt)
        model = result.scalar_one_or_none()
        return _map_model_to_entity(model) if model else None
    
    async def find_by_loan_id(self, loan_id: int) -> Optional[Contract]:
        stmt = select(ContractModel).where(ContractModel.loan_id == loan_id)
        result = await self._db.execute(stmt)
        model = result.scalar_one_or_none()
        return _map_model_to_entity(model) if model else None
    
    async def find_all(self, limit: int = 50, offset: int = 0) -> List[Contract]:
        stmt = (
            select(ContractModel)
            .order_by(ContractModel.id.desc())
            .limit(limit)
            .offset(offset)
        )
        result = await self._db.execute(stmt)
        models = result.scalars().all()
        return [_map_model_to_entity(m) for m in models]
    
    async def count(self) -> int:
        stmt = select(func.count(ContractModel.id))
        result = await self._db.execute(stmt)
        return result.scalar() or 0
    
    async def create(self, contract: Contract) -> Contract:
        model = ContractModel(
            loan_id=contract.loan_id,
            file_path=contract.file_path,
            start_date=contract.start_date,
            sign_date=contract.sign_date,
            document_number=contract.document_number,
            status_id=contract.status_id,
        )
        self._db.add(model)
        await self._db.flush()
        await self._db.refresh(model)
        return _map_model_to_entity(model)
