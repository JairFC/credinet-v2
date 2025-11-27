"""Rutas FastAPI para contracts"""
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_async_db
from app.modules.contracts.application.dtos import (
    ContractResponseDTO,
    ContractListItemDTO,
    PaginatedContractsDTO,
)
from app.modules.contracts.application.use_cases import (
    ListContractsUseCase,
    GetLoanContractUseCase,
)
from app.modules.contracts.infrastructure.repositories.pg_contract_repository import PgContractRepository


router = APIRouter(prefix="/contracts", tags=["Contracts"])


def get_contract_repository(db: AsyncSession = Depends(get_async_db)) -> PgContractRepository:
    return PgContractRepository(db)


@router.get("", response_model=PaginatedContractsDTO)
async def list_contracts(
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0),
    repo: PgContractRepository = Depends(get_contract_repository),
):
    """Lista todos los contratos"""
    try:
        use_case = ListContractsUseCase(repo)
        contracts = await use_case.execute(limit, offset)
        total = await repo.count()
        
        items = [
            ContractListItemDTO(
                id=c.id,
                loan_id=c.loan_id,
                document_number=c.document_number,
                status_id=c.status_id,
                sign_date=c.sign_date,
            )
            for c in contracts
        ]
        
        return PaginatedContractsDTO(items=items, total=total, limit=limit, offset=offset)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error listing contracts: {str(e)}"
        )


@router.get("/loans/{loan_id}", response_model=ContractResponseDTO)
async def get_loan_contract(
    loan_id: int,
    repo: PgContractRepository = Depends(get_contract_repository),
):
    """Obtiene el contrato de un préstamo específico"""
    try:
        use_case = GetLoanContractUseCase(repo)
        contract = await use_case.execute(loan_id)
        
        if not contract:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Contract for loan {loan_id} not found"
            )
        
        return ContractResponseDTO(
            id=contract.id,
            loan_id=contract.loan_id,
            file_path=contract.file_path,
            start_date=contract.start_date,
            sign_date=contract.sign_date,
            document_number=contract.document_number,
            status_id=contract.status_id,
            created_at=contract.created_at,
            updated_at=contract.updated_at,
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error fetching loan contract: {str(e)}"
        )
