"""Use case for generating a new statement."""

from datetime import date, timedelta
from decimal import Decimal
from typing import Optional

from ..domain import Statement, StatementRepository
from ..application.dtos import CreateStatementDTO


class GenerateStatementUseCase:
    """
    Use case for generating a payment statement for an associate.
    
    This is typically executed automatically on days 8 and 23 of each month,
    but can also be manually triggered.
    """
    
    def __init__(self, statement_repository: StatementRepository):
        self.statement_repository = statement_repository
    
    def execute(self, dto: CreateStatementDTO) -> Statement:
        """
        Generate a new statement.
        
        Args:
            dto: Statement creation data
            
        Returns:
            Statement: The created statement
            
        Raises:
            ValueError: If validation fails or statement already exists
        """
        # Validate: check if statement already exists
        if self.statement_repository.exists_for_associate_and_period(
            dto.user_id,
            dto.cut_period_id
        ):
            raise ValueError(
                f"Statement already exists for associate {dto.user_id} "
                f"and period {dto.cut_period_id}"
            )
        
        # Validate: due_date must be after generated_date
        if dto.due_date <= dto.generated_date:
            raise ValueError("Due date must be after generation date")
        
        # Validate: amounts must be non-negative
        if dto.total_amount_collected < 0 or dto.total_commission_owed < 0:
            raise ValueError("Amounts cannot be negative")
        
        # Validate: commission must not exceed collected amount
        if dto.total_commission_owed > dto.total_amount_collected:
            raise ValueError(
                "Commission cannot exceed collected amount "
                f"(commission: {dto.total_commission_owed}, "
                f"collected: {dto.total_amount_collected})"
            )
        
        # Generate statement number
        statement_number = self._generate_statement_number(
            dto.cut_period_id,
            dto.user_id
        )
        
        # Get GENERATED status ID from database
        from sqlalchemy import text
        result = self.statement_repository.db_session.execute(
            text("SELECT id FROM statement_statuses WHERE code = 'GENERATED' LIMIT 1")
        ).fetchone()
        
        if not result:
            raise ValueError("GENERATED status not found in statement_statuses table")
        
        status_id = result[0]
        
        # Create statement
        statement = self.statement_repository.create(
            statement_number=statement_number,
            user_id=dto.user_id,
            cut_period_id=dto.cut_period_id,
            total_payments_count=dto.total_payments_count,
            total_amount_collected=dto.total_amount_collected,
            total_commission_owed=dto.total_commission_owed,
            commission_rate_applied=dto.commission_rate_applied,
            status_id=status_id,
            generated_date=dto.generated_date,
            due_date=dto.due_date
        )
        
        return statement
    
    def _generate_statement_number(
        self,
        cut_period_id: int,
        user_id: int
    ) -> str:
        """
        Generate unique statement number.
        
        Format: ST-{YYYY}-{PERIOD_CODE}-{USER_ID}
        Example: ST-2025-Q01-003
        """
        from sqlalchemy import text
        
        # Obtener código del período desde la base de datos
        result = self.statement_repository.db_session.execute(
            text("SELECT cut_code FROM cut_periods WHERE id = :id"),
            {"id": cut_period_id}
        ).fetchone()
        
        if not result:
            raise ValueError(f"Cut period {cut_period_id} not found")
        
        period_code = result[0]
        
        # Generar número de statement
        return f"ST-{period_code}-{user_id:03d}"
