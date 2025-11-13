"""Use case for getting statement details."""

from typing import Optional
from ..domain import Statement, StatementRepository


class GetStatementDetailsUseCase:
    """Use case for retrieving detailed statement information."""
    
    def __init__(self, statement_repository: StatementRepository):
        self.statement_repository = statement_repository
    
    def execute(self, statement_id: int) -> Statement:
        """
        Get statement details by ID.
        
        Args:
            statement_id: Statement ID
            
        Returns:
            Statement: The statement entity
            
        Raises:
            ValueError: If statement_id is invalid
            LookupError: If statement not found
        """
        if statement_id <= 0:
            raise ValueError("Invalid statement_id")
        
        statement = self.statement_repository.find_by_id(statement_id)
        
        if not statement:
            raise LookupError(f"Statement #{statement_id} not found")
        
        return statement
