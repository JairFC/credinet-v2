"""
Unit Tests - Payment Use Cases
"""
import pytest
from unittest.mock import AsyncMock, MagicMock
from datetime import datetime
from decimal import Decimal
from app.modules.payments.domain.entities import Payment
from app.modules.payments.application.use_cases import RegisterPaymentUseCase


class TestRegisterPaymentUseCase:
    """Test RegisterPaymentUseCase logic"""
    
    @pytest.mark.asyncio
    async def test_register_payment_success(self):
        """Should register payment successfully when status is PENDING"""
        # Arrange
        mock_repo = AsyncMock()
        payment_entity = Payment(
            id=None, loan_id=1, cut_period_id=1, cut_number=1,
            period_number=1, payment_date=datetime.now().date(),
            due_date=datetime.now().date(), amount_due=Decimal("1000.00"),
            interest_amount=Decimal("100.00"), principal_amount=Decimal("900.00"),
            balance_before=Decimal("10000.00"), balance_after=Decimal("9000.00"),
            status_id=1, payment_type="REGULAR", marked_by=None,
            amount_paid=Decimal("0.00"), paid_at=None,
            is_overdue=False, overdue_days=0, penalty_amount=Decimal("0.00"),
            notes=None, created_at=datetime.now(), updated_at=datetime.now()
        )
        mock_repo.find_by_id.return_value = payment_entity
        
        registered_payment = Payment(
            id=1, loan_id=1, cut_period_id=1, cut_number=1,
            period_number=1, payment_date=datetime.now().date(),
            due_date=datetime.now().date(), amount_due=Decimal("1000.00"),
            interest_amount=Decimal("100.00"), principal_amount=Decimal("900.00"),
            balance_before=Decimal("10000.00"), balance_after=Decimal("9000.00"),
            status_id=2, payment_type="REGULAR", marked_by=1,
            amount_paid=Decimal("1000.00"), paid_at=datetime.now(),
            is_overdue=False, overdue_days=0, penalty_amount=Decimal("0.00"),
            notes=None, created_at=datetime.now(), updated_at=datetime.now()
        )
        mock_repo.register_payment.return_value = registered_payment
        
        use_case = RegisterPaymentUseCase(mock_repo)
        
        # Act
        result = await use_case.execute(
            payment_id=1,
            amount_paid=Decimal("1000.00"),
            status_id=2,
            marked_by=1
        )
        
        # Assert
        assert result.id == 1
        assert result.amount_paid == Decimal("1000.00")
        assert result.status_id == 2
        assert result.marked_by == 1
        mock_repo.find_by_id.assert_called_once_with(1)
        mock_repo.register_payment.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_register_payment_raises_when_not_found(self):
        """Should raise ValueError when payment not found"""
        # Arrange
        mock_repo = AsyncMock()
        mock_repo.find_by_id.return_value = None
        use_case = RegisterPaymentUseCase(mock_repo)
        
        # Act & Assert
        with pytest.raises(ValueError, match="Payment with id 999 not found"):
            await use_case.execute(
                payment_id=999,
                amount_paid=Decimal("1000.00"),
                status_id=2,
                marked_by=1
            )
    
    @pytest.mark.asyncio
    async def test_register_payment_raises_when_already_paid(self):
        """Should raise ValueError when payment already paid"""
        # Arrange
        mock_repo = AsyncMock()
        paid_payment = Payment(
            id=1, loan_id=1, cut_period_id=1, cut_number=1,
            period_number=1, payment_date=datetime.now().date(),
            due_date=datetime.now().date(), amount_due=Decimal("1000.00"),
            interest_amount=Decimal("100.00"), principal_amount=Decimal("900.00"),
            balance_before=Decimal("10000.00"), balance_after=Decimal("9000.00"),
            status_id=2, payment_type="REGULAR", marked_by=1,
            amount_paid=Decimal("1000.00"), paid_at=datetime.now(),
            is_overdue=False, overdue_days=0, penalty_amount=Decimal("0.00"),
            notes=None, created_at=datetime.now(), updated_at=datetime.now()
        )
        mock_repo.find_by_id.return_value = paid_payment
        use_case = RegisterPaymentUseCase(mock_repo)
        
        # Act & Assert
        with pytest.raises(ValueError, match="Payment 1 is already paid"):
            await use_case.execute(
                payment_id=1,
                amount_paid=Decimal("1000.00"),
                status_id=2,
                marked_by=1
            )
