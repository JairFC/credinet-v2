"""Use case for listing statements."""

from typing import List, Optional
from ..domain import Statement, StatementRepository


class ListStatementsUseCase:
    """Use case for listing statements with filters."""
    
    def __init__(self, statement_repository: StatementRepository):
        self.statement_repository = statement_repository
    
    def by_associate(
        self,
        user_id: int,
        limit: int = 10,
        offset: int = 0
    ) -> List[Statement]:
        """List statements for a specific associate."""
        if user_id <= 0:
            raise ValueError("Invalid user_id")
        
        return self.statement_repository.find_by_associate(
            user_id=user_id,
            limit=limit,
            offset=offset
        )
    
    def by_period(
        self,
        cut_period_id: int,
        limit: int = 100,
        offset: int = 0
    ) -> List[Statement]:
        """List statements for a specific period."""
        if cut_period_id <= 0:
            raise ValueError("Invalid cut_period_id")
        
        return self.statement_repository.find_by_period(
            cut_period_id=cut_period_id,
            limit=limit,
            offset=offset
        )
    
    def by_status(
        self,
        status_name: str,
        limit: int = 100,
        offset: int = 0
    ) -> List[Statement]:
        """List statements by status."""
        valid_statuses = ['GENERATED', 'SENT', 'PAID', 'PARTIAL_PAID', 'OVERDUE', 'CANCELLED']
        
        if status_name not in valid_statuses:
            raise ValueError(
                f"Invalid status '{status_name}'. "
                f"Valid values: {', '.join(valid_statuses)}"
            )
        
        return self.statement_repository.find_by_status(
            status_name=status_name,
            limit=limit,
            offset=offset
        )
    
    def overdue(
        self,
        limit: int = 100,
        offset: int = 0
    ) -> List[Statement]:
        """List overdue statements."""
        return self.statement_repository.find_overdue(
            limit=limit,
            offset=offset
        )
