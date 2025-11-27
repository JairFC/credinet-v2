"""
Unit Tests - Payment Entity Business Logic
"""
import pytest
from datetime import datetime, date, timedelta
from decimal import Decimal
from app.modules.payments.domain.entities import Payment


class TestPaymentEntity:
    """Test Payment entity business methods"""
    
    def test_is_paid_when_fully_paid(self):
        """Should return True when amount_paid >= expected_amount"""
        payment = Payment(
            id=1, loan_id=1, payment_number=1,
            expected_amount=Decimal("1000.00"), amount_paid=Decimal("1000.00"),
            interest_amount=Decimal("100.00"), principal_amount=Decimal("900.00"),
            commission_amount=Decimal("0.00"), associate_payment=Decimal("0.00"),
            balance_remaining=Decimal("9000.00"), payment_date=date.today(),
            payment_due_date=date.today(), is_late=False, status_id=2,
            cut_period_id=1, marked_by=1, marked_at=datetime.now(),
            marking_notes=None, created_at=datetime.now(), updated_at=datetime.now()
        )
        assert payment.is_paid() is True
    
    def test_is_paid_when_status_pending(self):
        """Should return False when amount_paid < expected_amount"""
        payment = Payment(
            id=1, loan_id=1, payment_number=1,
            expected_amount=Decimal("1000.00"), amount_paid=Decimal("0.00"),
            interest_amount=Decimal("100.00"), principal_amount=Decimal("900.00"),
            commission_amount=Decimal("0.00"), associate_payment=Decimal("0.00"),
            balance_remaining=Decimal("10000.00"), payment_date=date.today(),
            payment_due_date=date.today(), is_late=False, status_id=1,
            cut_period_id=1, marked_by=None, marked_at=None,
            marking_notes=None, created_at=datetime.now(), updated_at=datetime.now()
        )
        assert payment.is_paid() is False
    
    def test_is_overdue_when_past_due_date(self):
        """Should return True when due_date passed and still pending"""
        past_date = date.today() - timedelta(days=5)
        payment = Payment(
            id=1, loan_id=1, payment_number=1,
            expected_amount=Decimal("1000.00"), amount_paid=Decimal("0.00"),
            interest_amount=Decimal("100.00"), principal_amount=Decimal("900.00"),
            commission_amount=Decimal("0.00"), associate_payment=Decimal("0.00"),
            balance_remaining=Decimal("10000.00"), payment_date=date.today(),
            payment_due_date=past_date, is_late=True, status_id=1,
            cut_period_id=1, marked_by=None, marked_at=None,
            marking_notes=None, created_at=datetime.now(), updated_at=datetime.now()
        )
        assert payment.is_overdue() is True
    
    def test_get_remaining_amount_partial_payment(self):
        """Should calculate remaining amount correctly"""
        payment = Payment(
            id=1, loan_id=1, payment_number=1,
            expected_amount=Decimal("1000.00"), amount_paid=Decimal("600.00"),
            interest_amount=Decimal("100.00"), principal_amount=Decimal("900.00"),
            commission_amount=Decimal("0.00"), associate_payment=Decimal("0.00"),
            balance_remaining=Decimal("9400.00"), payment_date=date.today(),
            payment_due_date=date.today(), is_late=False, status_id=3,
            cut_period_id=1, marked_by=1, marked_at=None,
            marking_notes=None, created_at=datetime.now(), updated_at=datetime.now()
        )
        assert payment.get_remaining_amount() == Decimal("400.00")
    
    def test_get_remaining_amount_fully_paid(self):
        """Should return 0 when fully paid"""
        payment = Payment(
            id=1, loan_id=1, payment_number=1,
            expected_amount=Decimal("1000.00"), amount_paid=Decimal("1000.00"),
            interest_amount=Decimal("100.00"), principal_amount=Decimal("900.00"),
            commission_amount=Decimal("0.00"), associate_payment=Decimal("0.00"),
            balance_remaining=Decimal("9000.00"), payment_date=date.today(),
            payment_due_date=date.today(), is_late=False, status_id=2,
            cut_period_id=1, marked_by=1, marked_at=datetime.now(),
            marking_notes=None, created_at=datetime.now(), updated_at=datetime.now()
        )
        assert payment.get_remaining_amount() == Decimal("0.00")
    
    def test_is_first_payment(self):
        """Should return True when payment_number is 1"""
        payment = Payment(
            id=1, loan_id=1, payment_number=1,
            expected_amount=Decimal("1000.00"), amount_paid=Decimal("0.00"),
            interest_amount=Decimal("100.00"), principal_amount=Decimal("900.00"),
            commission_amount=Decimal("0.00"), associate_payment=Decimal("0.00"),
            balance_remaining=Decimal("10000.00"), payment_date=date.today(),
            payment_due_date=date.today(), is_late=False, status_id=1,
            cut_period_id=1, marked_by=None, marked_at=None,
            marking_notes=None, created_at=datetime.now(), updated_at=datetime.now()
        )
        assert payment.is_first_payment() is True
    
    def test_is_final_payment(self):
        """Should return True when balance_remaining is 0"""
        payment = Payment(
            id=1, loan_id=1, payment_number=24,
            expected_amount=Decimal("1000.00"), amount_paid=Decimal("1000.00"),
            interest_amount=Decimal("100.00"), principal_amount=Decimal("900.00"),
            commission_amount=Decimal("0.00"), associate_payment=Decimal("0.00"),
            balance_remaining=Decimal("0.00"), payment_date=date.today(),
            payment_due_date=date.today(), is_late=False, status_id=2,
            cut_period_id=24, marked_by=1, marked_at=datetime.now(),
            marking_notes=None, created_at=datetime.now(), updated_at=datetime.now()
        )
        assert payment.is_final_payment() is True
