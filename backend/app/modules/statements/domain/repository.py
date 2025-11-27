"""Repository interface for statements."""

from abc import ABC, abstractmethod
from typing import List, Optional
from datetime import date
from decimal import Decimal

from .entities import Statement


class StatementRepository(ABC):
    """Abstract repository for statement persistence."""
    
    @abstractmethod
    def find_by_id(self, statement_id: int) -> Optional[Statement]:
        """Find statement by ID."""
        pass
    
    @abstractmethod
    def find_by_associate(
        self,
        user_id: int,
        limit: int = 10,
        offset: int = 0
    ) -> List[Statement]:
        """Find statements by associate."""
        pass
    
    @abstractmethod
    def find_by_period(
        self,
        cut_period_id: int,
        limit: int = 100,
        offset: int = 0
    ) -> List[Statement]:
        """Find statements by cut period."""
        pass
    
    @abstractmethod
    def find_by_status(
        self,
        status_name: str,
        limit: int = 100,
        offset: int = 0
    ) -> List[Statement]:
        """Find statements by status."""
        pass
    
    @abstractmethod
    def find_overdue(
        self,
        limit: int = 100,
        offset: int = 0
    ) -> List[Statement]:
        """Find overdue statements."""
        pass
    
    @abstractmethod
    def exists_for_associate_and_period(
        self,
        user_id: int,
        cut_period_id: int
    ) -> bool:
        """Check if statement already exists for associate and period."""
        pass
    
    @abstractmethod
    def create(
        self,
        statement_number: str,
        user_id: int,
        cut_period_id: int,
        total_payments_count: int,
        total_amount_collected: Decimal,
        total_commission_owed: Decimal,
        commission_rate_applied: Decimal,
        status_id: int,
        generated_date: date,
        due_date: date
    ) -> Statement:
        """Create a new statement."""
        pass
    
    @abstractmethod
    def mark_as_paid(
        self,
        statement_id: int,
        paid_amount: Decimal,
        paid_date: date,
        payment_method_id: int,
        payment_reference: Optional[str] = None
    ) -> Statement:
        """Mark statement as paid."""
        pass
    
    @abstractmethod
    def apply_late_fee(
        self,
        statement_id: int,
        late_fee_amount: Decimal
    ) -> Statement:
        """Apply late fee to statement."""
        pass
    
    @abstractmethod
    def update_status(
        self,
        statement_id: int,
        status_id: int
    ) -> Statement:
        """Update statement status."""
        pass
    
    @abstractmethod
    def count_by_period(self, cut_period_id: int) -> int:
        """Count statements in period."""
        pass
    
    @abstractmethod
    def count_by_associate(self, user_id: int) -> int:
        """Count statements for associate."""
        pass
