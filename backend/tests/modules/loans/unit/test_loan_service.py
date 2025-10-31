"""
Tests unitarios para LoanService.

Valida la lógica de negocio del servicio de préstamos.
"""
import pytest
from datetime import datetime
from decimal import Decimal
from unittest.mock import AsyncMock, Mock, patch

from app.modules.loans.application.services import LoanService
from app.modules.loans.domain.entities import Loan, LoanStatusEnum


# =============================================================================
# FIXTURES
# =============================================================================

@pytest.fixture
def mock_session():
    """Fixture para sesión mockeada."""
    session = AsyncMock()
    session.commit = AsyncMock()
    session.rollback = AsyncMock()
    return session


@pytest.fixture
def mock_repository():
    """Fixture para repositorio mockeado."""
    repo = AsyncMock()
    return repo


@pytest.fixture
def loan_service(mock_session):
    """Fixture para LoanService con sesión mockeada."""
    return LoanService(mock_session)


@pytest.fixture
def sample_loan():
    """Fixture para préstamo de ejemplo."""
    return Loan(
        id=1,
        user_id=5,
        associate_user_id=10,
        amount=Decimal('5000.00'),
        interest_rate=Decimal('2.50'),
        commission_rate=Decimal('0.50'),
        term_biweeks=12,
        status_id=LoanStatusEnum.PENDING.value,
        contract_id=None,
        approved_at=None,
        approved_by=None,
        rejected_at=None,
        rejected_by=None,
        rejection_reason=None,
        notes="Test loan",
        created_at=datetime.utcnow(),
        updated_at=datetime.utcnow(),
    )


# =============================================================================
# TESTS: create_loan_request()
# =============================================================================

class TestCreateLoanRequest:
    """Tests para crear solicitud de préstamo."""
    
    @pytest.mark.asyncio
    async def test_create_loan_request_success(self, loan_service, mock_session):
        """Test: Crear préstamo exitosamente."""
        # Mock repositorio
        with patch.object(loan_service, 'repository') as mock_repo:
            mock_repo.check_associate_credit_available = AsyncMock(return_value=True)
            mock_repo.has_pending_loans = AsyncMock(return_value=False)
            mock_repo.is_client_defaulter = AsyncMock(return_value=False)
            
            created_loan = Loan(
                id=1,
                user_id=5,
                associate_user_id=10,
                amount=Decimal('5000.00'),
                interest_rate=Decimal('2.50'),
                commission_rate=Decimal('0.50'),
                term_biweeks=12,
                status_id=LoanStatusEnum.PENDING.value,
                contract_id=None,
                approved_at=None,
                approved_by=None,
                rejected_at=None,
                rejected_by=None,
                rejection_reason=None,
                notes="Test",
                created_at=datetime.utcnow(),
                updated_at=datetime.utcnow(),
            )
            mock_repo.create = AsyncMock(return_value=created_loan)
            
            # Ejecutar
            loan = await loan_service.create_loan_request(
                user_id=5,
                associate_user_id=10,
                amount=Decimal('5000.00'),
                interest_rate=Decimal('2.50'),
                commission_rate=Decimal('0.50'),
                term_biweeks=12,
                notes="Test"
            )
            
            # Aserciones
            assert loan.id == 1
            assert loan.user_id == 5
            assert loan.status_id == LoanStatusEnum.PENDING.value
            mock_repo.create.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_create_loan_request_associate_no_credit(self, loan_service):
        """Test: Error si asociado no tiene crédito."""
        with patch.object(loan_service, 'repository') as mock_repo:
            mock_repo.check_associate_credit_available = AsyncMock(return_value=False)
            
            with pytest.raises(ValueError, match="no tiene crédito disponible"):
                await loan_service.create_loan_request(
                    user_id=5,
                    associate_user_id=10,
                    amount=Decimal('5000.00'),
                    interest_rate=Decimal('2.50'),
                    commission_rate=Decimal('0.50'),
                    term_biweeks=12
                )
    
    @pytest.mark.asyncio
    async def test_create_loan_request_client_has_pending(self, loan_service):
        """Test: Error si cliente tiene préstamos PENDING."""
        with patch.object(loan_service, 'repository') as mock_repo:
            mock_repo.check_associate_credit_available = AsyncMock(return_value=True)
            mock_repo.has_pending_loans = AsyncMock(return_value=True)
            
            with pytest.raises(ValueError, match="ya tiene préstamos pendientes"):
                await loan_service.create_loan_request(
                    user_id=5,
                    associate_user_id=10,
                    amount=Decimal('5000.00'),
                    interest_rate=Decimal('2.50'),
                    commission_rate=Decimal('0.50'),
                    term_biweeks=12
                )
    
    @pytest.mark.asyncio
    async def test_create_loan_request_client_is_defaulter(self, loan_service):
        """Test: Error si cliente es moroso."""
        with patch.object(loan_service, 'repository') as mock_repo:
            mock_repo.check_associate_credit_available = AsyncMock(return_value=True)
            mock_repo.has_pending_loans = AsyncMock(return_value=False)
            mock_repo.is_client_defaulter = AsyncMock(return_value=True)
            
            with pytest.raises(ValueError, match="está marcado como moroso"):
                await loan_service.create_loan_request(
                    user_id=5,
                    associate_user_id=10,
                    amount=Decimal('5000.00'),
                    interest_rate=Decimal('2.50'),
                    commission_rate=Decimal('0.50'),
                    term_biweeks=12
                )


# =============================================================================
# TESTS: approve_loan()
# =============================================================================

class TestApproveLoan:
    """Tests para aprobar préstamo."""
    
    @pytest.mark.asyncio
    async def test_approve_loan_success(self, loan_service, sample_loan, mock_session):
        """Test: Aprobar préstamo exitosamente."""
        with patch.object(loan_service, 'repository') as mock_repo:
            mock_repo.find_by_id = AsyncMock(return_value=sample_loan)
            mock_repo.check_associate_credit_available = AsyncMock(return_value=True)
            mock_repo.is_client_defaulter = AsyncMock(return_value=False)
            mock_repo.count = AsyncMock(return_value=1)  # Solo este préstamo PENDING
            mock_repo.calculate_first_payment_date = AsyncMock(return_value=datetime(2024, 1, 15).date())
            
            approved_loan = Loan(
                **{**sample_loan.__dict__, 'status_id': LoanStatusEnum.APPROVED.value}
            )
            mock_repo.update = AsyncMock(return_value=approved_loan)
            
            # Ejecutar
            loan = await loan_service.approve_loan(
                loan_id=1,
                approved_by=2,
                notes="Aprobado"
            )
            
            # Aserciones
            assert loan.status_id == LoanStatusEnum.APPROVED.value
            mock_repo.update.assert_called_once()
            mock_session.commit.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_approve_loan_not_found(self, loan_service):
        """Test: Error si préstamo no existe."""
        with patch.object(loan_service, 'repository') as mock_repo:
            mock_repo.find_by_id = AsyncMock(return_value=None)
            
            with pytest.raises(ValueError, match="no encontrado"):
                await loan_service.approve_loan(
                    loan_id=999,
                    approved_by=2
                )
    
    @pytest.mark.asyncio
    async def test_approve_loan_not_pending(self, loan_service, sample_loan):
        """Test: Error si préstamo no está PENDING."""
        sample_loan.status_id = LoanStatusEnum.APPROVED.value
        
        with patch.object(loan_service, 'repository') as mock_repo:
            mock_repo.find_by_id = AsyncMock(return_value=sample_loan)
            
            with pytest.raises(ValueError, match="no está en estado PENDING"):
                await loan_service.approve_loan(
                    loan_id=1,
                    approved_by=2
                )
    
    @pytest.mark.asyncio
    async def test_approve_loan_associate_no_credit(self, loan_service, sample_loan):
        """Test: Error si asociado perdió crédito desde creación."""
        with patch.object(loan_service, 'repository') as mock_repo:
            mock_repo.find_by_id = AsyncMock(return_value=sample_loan)
            mock_repo.check_associate_credit_available = AsyncMock(return_value=False)
            
            with pytest.raises(ValueError, match="ya no tiene crédito disponible"):
                await loan_service.approve_loan(
                    loan_id=1,
                    approved_by=2
                )


# =============================================================================
# TESTS: reject_loan()
# =============================================================================

class TestRejectLoan:
    """Tests para rechazar préstamo."""
    
    @pytest.mark.asyncio
    async def test_reject_loan_success(self, loan_service, sample_loan, mock_session):
        """Test: Rechazar préstamo exitosamente."""
        with patch.object(loan_service, 'repository') as mock_repo:
            mock_repo.find_by_id = AsyncMock(return_value=sample_loan)
            
            rejected_loan = Loan(
                **{**sample_loan.__dict__, 'status_id': LoanStatusEnum.REJECTED.value}
            )
            mock_repo.update = AsyncMock(return_value=rejected_loan)
            
            # Ejecutar
            loan = await loan_service.reject_loan(
                loan_id=1,
                rejected_by=2,
                rejection_reason="Documentación incompleta"
            )
            
            # Aserciones
            assert loan.status_id == LoanStatusEnum.REJECTED.value
            mock_repo.update.assert_called_once()
            mock_session.commit.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_reject_loan_not_found(self, loan_service):
        """Test: Error si préstamo no existe."""
        with patch.object(loan_service, 'repository') as mock_repo:
            mock_repo.find_by_id = AsyncMock(return_value=None)
            
            with pytest.raises(ValueError, match="no encontrado"):
                await loan_service.reject_loan(
                    loan_id=999,
                    rejected_by=2,
                    rejection_reason="Test"
                )
    
    @pytest.mark.asyncio
    async def test_reject_loan_not_pending(self, loan_service, sample_loan):
        """Test: Error si préstamo no está PENDING."""
        sample_loan.status_id = LoanStatusEnum.APPROVED.value
        
        with patch.object(loan_service, 'repository') as mock_repo:
            mock_repo.find_by_id = AsyncMock(return_value=sample_loan)
            
            with pytest.raises(ValueError, match="no está en estado PENDING"):
                await loan_service.reject_loan(
                    loan_id=1,
                    rejected_by=2,
                    rejection_reason="Test"
                )
    
    @pytest.mark.asyncio
    async def test_reject_loan_empty_reason(self, loan_service, sample_loan):
        """Test: Error si razón de rechazo está vacía."""
        with patch.object(loan_service, 'repository') as mock_repo:
            mock_repo.find_by_id = AsyncMock(return_value=sample_loan)
            
            with pytest.raises(ValueError, match="razón del rechazo es obligatoria"):
                await loan_service.reject_loan(
                    loan_id=1,
                    rejected_by=2,
                    rejection_reason="   "  # Vacía con espacios
                )


# =============================================================================
# TESTS: UPDATE_LOAN (Sprint 3)
# =============================================================================

class TestUpdateLoan:
    """Tests para actualizar préstamos PENDING."""
    
    @pytest.mark.asyncio
    async def test_update_loan_success(self, loan_service, sample_loan, mock_session):
        """Test: Actualizar préstamo exitosamente."""
        updated_loan = Loan(**sample_loan.__dict__)
        updated_loan.amount = Decimal('6000.00')
        updated_loan.interest_rate = Decimal('3.00')
        
        with patch.object(loan_service, 'repository') as mock_repo:
            mock_repo.find_by_id = AsyncMock(return_value=sample_loan)
            mock_repo.check_associate_credit_available = AsyncMock(return_value=True)
            mock_repo.update = AsyncMock(return_value=updated_loan)
            
            loan = await loan_service.update_loan(
                loan_id=1,
                amount=Decimal('6000.00'),
                interest_rate=Decimal('3.00')
            )
            
            assert loan.amount == Decimal('6000.00')
            assert loan.interest_rate == Decimal('3.00')
            mock_session.commit.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_update_loan_not_found(self, loan_service):
        """Test: Error si préstamo no existe."""
        with patch.object(loan_service, 'repository') as mock_repo:
            mock_repo.find_by_id = AsyncMock(return_value=None)
            
            with pytest.raises(ValueError, match="no encontrado"):
                await loan_service.update_loan(
                    loan_id=999,
                    amount=Decimal('6000.00')
                )
    
    @pytest.mark.asyncio
    async def test_update_loan_not_pending(self, loan_service, sample_loan):
        """Test: Error si préstamo no está PENDING."""
        sample_loan.status_id = LoanStatusEnum.APPROVED.value
        
        with patch.object(loan_service, 'repository') as mock_repo:
            mock_repo.find_by_id = AsyncMock(return_value=sample_loan)
            
            with pytest.raises(ValueError, match="Solo se pueden actualizar préstamos en estado PENDING"):
                await loan_service.update_loan(
                    loan_id=1,
                    amount=Decimal('6000.00')
                )
    
    @pytest.mark.asyncio
    async def test_update_loan_amount_no_credit(self, loan_service, sample_loan):
        """Test: Error si asociado no tiene crédito para nuevo monto."""
        with patch.object(loan_service, 'repository') as mock_repo:
            mock_repo.find_by_id = AsyncMock(return_value=sample_loan)
            mock_repo.check_associate_credit_available = AsyncMock(return_value=False)
            
            with pytest.raises(ValueError, match="no tiene crédito disponible"):
                await loan_service.update_loan(
                    loan_id=1,
                    amount=Decimal('10000.00')  # Monto muy alto
                )


# =============================================================================
# TESTS: CANCEL_LOAN (Sprint 3)
# =============================================================================

class TestCancelLoan:
    """Tests para cancelar préstamos ACTIVE."""
    
    @pytest.mark.asyncio
    async def test_cancel_loan_success(self, loan_service, sample_loan, mock_session):
        """Test: Cancelar préstamo exitosamente."""
        sample_loan.status_id = LoanStatusEnum.ACTIVE.value
        cancelled_loan = Loan(**sample_loan.__dict__)
        cancelled_loan.status_id = LoanStatusEnum.CANCELLED.value
        cancelled_loan.cancelled_at = datetime.utcnow()
        cancelled_loan.cancelled_by = 2
        cancelled_loan.cancellation_reason = "Cancelación por liquidación anticipada"
        
        with patch.object(loan_service, 'repository') as mock_repo:
            mock_repo.find_by_id = AsyncMock(return_value=sample_loan)
            mock_repo.update = AsyncMock(return_value=cancelled_loan)
            
            loan = await loan_service.cancel_loan(
                loan_id=1,
                cancelled_by=2,
                cancellation_reason="Cancelación por liquidación anticipada"
            )
            
            assert loan.status_id == LoanStatusEnum.CANCELLED.value
            assert loan.cancelled_by == 2
            assert loan.cancellation_reason == "Cancelación por liquidación anticipada"
            mock_session.commit.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_cancel_loan_not_found(self, loan_service):
        """Test: Error si préstamo no existe."""
        with patch.object(loan_service, 'repository') as mock_repo:
            mock_repo.find_by_id = AsyncMock(return_value=None)
            
            with pytest.raises(ValueError, match="no encontrado"):
                await loan_service.cancel_loan(
                    loan_id=999,
                    cancelled_by=2,
                    cancellation_reason="Test"
                )
    
    @pytest.mark.asyncio
    async def test_cancel_loan_not_active(self, loan_service, sample_loan):
        """Test: Error si préstamo no está ACTIVE."""
        sample_loan.status_id = LoanStatusEnum.PENDING.value
        
        with patch.object(loan_service, 'repository') as mock_repo:
            mock_repo.find_by_id = AsyncMock(return_value=sample_loan)
            
            with pytest.raises(ValueError, match="Solo se pueden cancelar préstamos en estado ACTIVE"):
                await loan_service.cancel_loan(
                    loan_id=1,
                    cancelled_by=2,
                    cancellation_reason="Test"
                )
    
    @pytest.mark.asyncio
    async def test_cancel_loan_empty_reason(self, loan_service, sample_loan):
        """Test: Error si razón de cancelación está vacía."""
        sample_loan.status_id = LoanStatusEnum.ACTIVE.value
        
        with patch.object(loan_service, 'repository') as mock_repo:
            mock_repo.find_by_id = AsyncMock(return_value=sample_loan)
            
            with pytest.raises(ValueError, match="razón de cancelación es obligatoria"):
                await loan_service.cancel_loan(
                    loan_id=1,
                    cancelled_by=2,
                    cancellation_reason="   "  # Vacía con espacios
                )
    
    @pytest.mark.asyncio
    async def test_cancel_loan_short_reason(self, loan_service, sample_loan):
        """Test: Error si razón de cancelación es muy corta."""
        sample_loan.status_id = LoanStatusEnum.ACTIVE.value
        
        with patch.object(loan_service, 'repository') as mock_repo:
            mock_repo.find_by_id = AsyncMock(return_value=sample_loan)
            
            with pytest.raises(ValueError, match="debe tener al menos 10 caracteres"):
                await loan_service.cancel_loan(
                    loan_id=1,
                    cancelled_by=2,
                    cancellation_reason="Corta"  # Menos de 10 caracteres
                )


# =============================================================================
# RESUMEN
# =============================================================================

"""
COBERTURA DE TESTS (Sprint 1 + 2 + 3):
- ✅ create_loan_request(): 4 casos (success, no credit, has pending, is defaulter)
- ✅ approve_loan(): 4 casos (success, not found, not pending, no credit)
- ✅ reject_loan(): 4 casos (success, not found, not pending, empty reason)
- ✅ update_loan(): 4 casos (success, not found, not pending, no credit)
- ✅ cancel_loan(): 5 casos (success, not found, not active, empty reason, short reason)

TOTAL: 21 casos de prueba unitarios

⭐ OBJETIVO: Validar lógica de negocio completa del LoanService
"""
