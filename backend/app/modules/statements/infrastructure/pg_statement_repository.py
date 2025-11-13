"""PostgreSQL implementation of StatementRepository."""

from typing import List, Optional
from datetime import date
from decimal import Decimal
from sqlalchemy.orm import Session, joinedload
from sqlalchemy import and_

from ..domain import Statement, StatementRepository
from .models import StatementModel


class PgStatementRepository(StatementRepository):
    """PostgreSQL implementation of statement repository."""
    
    def __init__(self, db: Session):
        self.db = db
    
    def _to_entity(self, model: StatementModel) -> Statement:
        """Convert SQLAlchemy model to domain entity."""
        return Statement(
            id=model.id,
            statement_number=model.statement_number,
            user_id=model.user_id,
            cut_period_id=model.cut_period_id,
            total_payments_count=model.total_payments_count,
            total_amount_collected=model.total_amount_collected,
            total_commission_owed=model.total_commission_owed,
            commission_rate_applied=model.commission_rate_applied,
            status_id=model.status_id,
            generated_date=model.generated_date,
            sent_date=model.sent_date,
            due_date=model.due_date,
            paid_date=model.paid_date,
            paid_amount=model.paid_amount,
            payment_method_id=model.payment_method_id,
            payment_reference=model.payment_reference,
            late_fee_amount=model.late_fee_amount,
            late_fee_applied=model.late_fee_applied,
            created_at=model.created_at,
            updated_at=model.updated_at
        )
    
    def find_by_id(self, statement_id: int) -> Optional[Statement]:
        """Find statement by ID."""
        model = self.db.query(StatementModel).filter(
            StatementModel.id == statement_id
        ).first()
        
        return self._to_entity(model) if model else None
    
    def find_by_associate(
        self,
        user_id: int,
        limit: int = 10,
        offset: int = 0
    ) -> List[Statement]:
        """Find statements by associate."""
        models = self.db.query(StatementModel).filter(
            StatementModel.user_id == user_id
        ).order_by(
            StatementModel.generated_date.desc()
        ).limit(limit).offset(offset).all()
        
        return [self._to_entity(m) for m in models]
    
    def find_by_period(
        self,
        cut_period_id: int,
        limit: int = 100,
        offset: int = 0
    ) -> List[Statement]:
        """Find statements by cut period."""
        models = self.db.query(StatementModel).filter(
            StatementModel.cut_period_id == cut_period_id
        ).order_by(
            StatementModel.user_id
        ).limit(limit).offset(offset).all()
        
        return [self._to_entity(m) for m in models]
    
    def find_by_status(
        self,
        status_name: str,
        limit: int = 100,
        offset: int = 0
    ) -> List[Statement]:
        """Find statements by status."""
        # TODO: Join with statement_statuses table to filter by name
        # For now, we'll need to import the status model
        from app.modules.statements.infrastructure.models import StatementModel
        
        models = self.db.query(StatementModel).join(
            StatementModel.status
        ).filter(
            StatementModel.status.has(name=status_name)
        ).order_by(
            StatementModel.due_date
        ).limit(limit).offset(offset).all()
        
        return [self._to_entity(m) for m in models]
    
    def find_overdue(
        self,
        limit: int = 100,
        offset: int = 0
    ) -> List[Statement]:
        """Find overdue statements."""
        today = date.today()
        
        models = self.db.query(StatementModel).filter(
            and_(
                StatementModel.due_date < today,
                StatementModel.paid_date.is_(None)
            )
        ).order_by(
            StatementModel.due_date
        ).limit(limit).offset(offset).all()
        
        return [self._to_entity(m) for m in models]
    
    def exists_for_associate_and_period(
        self,
        user_id: int,
        cut_period_id: int
    ) -> bool:
        """Check if statement already exists for associate and period."""
        count = self.db.query(StatementModel).filter(
            and_(
                StatementModel.user_id == user_id,
                StatementModel.cut_period_id == cut_period_id
            )
        ).count()
        
        return count > 0
    
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
        model = StatementModel(
            statement_number=statement_number,
            user_id=user_id,
            cut_period_id=cut_period_id,
            total_payments_count=total_payments_count,
            total_amount_collected=total_amount_collected,
            total_commission_owed=total_commission_owed,
            commission_rate_applied=commission_rate_applied,
            status_id=status_id,
            generated_date=generated_date,
            due_date=due_date
        )
        
        self.db.add(model)
        self.db.commit()
        self.db.refresh(model)
        
        return self._to_entity(model)
    
    def mark_as_paid(
        self,
        statement_id: int,
        paid_amount: Decimal,
        paid_date: date,
        payment_method_id: int,
        payment_reference: Optional[str] = None
    ) -> Statement:
        """Mark statement as paid."""
        model = self.db.query(StatementModel).filter(
            StatementModel.id == statement_id
        ).first()
        
        if not model:
            raise LookupError(f"Statement #{statement_id} not found")
        
        model.paid_amount = paid_amount
        model.paid_date = paid_date
        model.payment_method_id = payment_method_id
        model.payment_reference = payment_reference
        
        self.db.commit()
        self.db.refresh(model)
        
        return self._to_entity(model)
    
    def apply_late_fee(
        self,
        statement_id: int,
        late_fee_amount: Decimal
    ) -> Statement:
        """Apply late fee to statement."""
        model = self.db.query(StatementModel).filter(
            StatementModel.id == statement_id
        ).first()
        
        if not model:
            raise LookupError(f"Statement #{statement_id} not found")
        
        model.late_fee_amount = late_fee_amount
        model.late_fee_applied = True
        
        self.db.commit()
        self.db.refresh(model)
        
        return self._to_entity(model)
    
    def update_status(
        self,
        statement_id: int,
        status_id: int
    ) -> Statement:
        """Update statement status."""
        model = self.db.query(StatementModel).filter(
            StatementModel.id == statement_id
        ).first()
        
        if not model:
            raise LookupError(f"Statement #{statement_id} not found")
        
        model.status_id = status_id
        
        self.db.commit()
        self.db.refresh(model)
        
        return self._to_entity(model)
    
    def count_by_period(self, cut_period_id: int) -> int:
        """Count statements in period."""
        return self.db.query(StatementModel).filter(
            StatementModel.cut_period_id == cut_period_id
        ).count()
    
    def count_by_associate(self, user_id: int) -> int:
        """Count statements for associate."""
        return self.db.query(StatementModel).filter(
            StatementModel.user_id == user_id
        ).count()
