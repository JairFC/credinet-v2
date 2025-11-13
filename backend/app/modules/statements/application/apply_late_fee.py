"""Use case for applying late fees."""

from datetime import date
from ..domain import Statement, StatementRepository
from ..application.dtos import ApplyLateFeeDTO


class ApplyLateFeeUseCase:
    """Use case for applying late fee to overdue statement."""
    
    def __init__(self, statement_repository: StatementRepository):
        self.statement_repository = statement_repository
    
    def execute(self, statement_id: int, dto: ApplyLateFeeDTO) -> Statement:
        """
        Apply late fee to statement.
        
        Args:
            statement_id: Statement ID
            dto: Late fee information
            
        Returns:
            Statement: Updated statement
            
        Raises:
            ValueError: If validation fails
            LookupError: If statement not found
        """
        # Validate statement exists
        statement = self.statement_repository.find_by_id(statement_id)
        if not statement:
            raise LookupError(f"Statement #{statement_id} not found")
        
        # Validate statement is overdue
        if not statement.is_overdue:
            raise ValueError(
                f"Statement #{statement_id} is not overdue "
                f"(due date: {statement.due_date})"
            )
        
        # Validate statement is not paid
        if statement.is_paid:
            raise ValueError(
                f"Cannot apply late fee to paid statement #{statement_id}"
            )
        
        # Validate late fee not already applied
        if statement.late_fee_applied:
            raise ValueError(
                f"Late fee already applied to statement #{statement_id} "
                f"(amount: ${statement.late_fee_amount})"
            )
        
        # Validate late_fee_amount is positive
        if dto.late_fee_amount <= 0:
            raise ValueError("Late fee amount must be greater than 0")
        
        # Apply late fee
        updated_statement = self.statement_repository.apply_late_fee(
            statement_id=statement_id,
            late_fee_amount=dto.late_fee_amount
        )
        
        # Update status to OVERDUE if not already
        if statement.status_id != 5:  # 5 = OVERDUE
            updated_statement = self.statement_repository.update_status(
                statement_id=statement_id,
                status_id=5
            )
        
        return updated_statement
