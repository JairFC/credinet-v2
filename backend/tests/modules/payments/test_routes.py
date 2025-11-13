"""
Integration Tests - Payment Routes (Endpoints)
"""
import pytest
from httpx import AsyncClient
from app.main import app


class TestPaymentRoutes:
    """Test Payment API endpoints"""
    
    @pytest.mark.asyncio
    async def test_list_payments_by_loan(self):
        """Should return list of payments for a loan"""
        async with AsyncClient(app=app, base_url="http://test") as client:
            response = await client.get("/api/v1/payments/loans/10")
            assert response.status_code == 200
            data = response.json()
            assert "items" in data
            assert "total" in data
            assert isinstance(data["items"], list)
    
    @pytest.mark.asyncio
    async def test_get_payment_details(self):
        """Should return payment details when exists"""
        async with AsyncClient(app=app, base_url="http://test") as client:
            response = await client.get("/api/v1/payments/37")
            if response.status_code == 200:
                data = response.json()
                assert "id" in data
                assert "loan_id" in data
                assert "amount_due" in data
            else:
                assert response.status_code == 404
    
    @pytest.mark.asyncio
    async def test_register_payment_invalid_loan(self):
        """Should return 400/500 when registering payment for non-existent loan"""
        async with AsyncClient(app=app, base_url="http://test") as client:
            response = await client.post(
                "/api/v1/payments/register",
                json={
                    "loan_id": 99999,
                    "amount_paid": 1000.00,
                    "status_id": 2,
                    "marked_by": 1
                }
            )
            assert response.status_code in [400, 404, 500]
    
    @pytest.mark.asyncio
    async def test_get_loan_payment_summary(self):
        """Should return payment summary for a loan"""
        async with AsyncClient(app=app, base_url="http://test") as client:
            response = await client.get("/api/v1/payments/loans/10/summary")
            assert response.status_code == 200
            data = response.json()
            assert "loan_id" in data
            assert "total_payments" in data
            assert "total_paid" in data
            assert "total_pending" in data
