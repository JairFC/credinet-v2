"""Use case for marking statement as paid."""

from datetime import date
from ..domain import Statement, StatementRepository
from ..application.dtos import MarkStatementPaidDTO


class MarkStatementPaidUseCase:
    """Use case for marking a statement as paid."""
    
    def __init__(self, statement_repository: StatementRepository):
        self.statement_repository = statement_repository
    
    def execute(self, statement_id: int, dto: MarkStatementPaidDTO) -> Statement:
        """
        Mark statement as paid.
        
        Args:
            statement_id: Statement ID
            dto: Payment information
            
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
        
        # Validate statement is not already paid
        if statement.is_paid:
            raise ValueError(
                f"Statement #{statement_id} is already paid "
                f"(paid on {statement.paid_date})"
            )
        
        # Validate paid_amount is positive
        if dto.paid_amount <= 0:
            raise ValueError("Paid amount must be greater than 0")
        
        # Validate paid_date
        if dto.paid_date < statement.generated_date:
            raise ValueError("Paid date cannot be before generation date")
        
        # Mark as paid
        updated_statement = self.statement_repository.mark_as_paid(
            statement_id=statement_id,
            paid_amount=dto.paid_amount,
            paid_date=dto.paid_date,
            payment_method_id=dto.payment_method_id,
            payment_reference=dto.payment_reference
        )
        
        # Update status based on payment amount
        total_owed = statement.total_commission_owed + statement.late_fee_amount
        
        if dto.paid_amount >= total_owed:
            # Fully paid
            status_id = 3  # PAID
        else:
            # Partially paid
            status_id = 4  # PARTIAL_PAID
        
        # Update status
        updated_statement = self.statement_repository.update_status(
            statement_id=statement_id,
            status_id=status_id
        )
        
        return updated_statement
