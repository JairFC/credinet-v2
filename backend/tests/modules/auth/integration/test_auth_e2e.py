"""
End-to-End (E2E) tests for Auth module.

Tests complete user flows:
1. Full authentication flow: Login → Get Me → Change Password → Logout
2. Token refresh flow: Login → Expire → Refresh → Get Me
3. Registration and login flow: Register → Login → Get Me
"""

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from datetime import datetime
import time

from app.main import app
from app.core.database import Base, get_db
from app.core.security import get_password_hash
from app.modules.auth.infrastructure.models import UserModel, RoleModel


# ========================================
# TEST DATABASE SETUP
# ========================================

SQLALCHEMY_TEST_DATABASE_URL = "sqlite:///./test_auth_e2e.db"

engine = create_engine(
    SQLALCHEMY_TEST_DATABASE_URL, connect_args={"check_same_thread": False}
)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


def override_get_db():
    """Override database dependency for testing."""
    try:
        db = TestingSessionLocal()
        yield db
    finally:
        db.close()


app.dependency_overrides[get_db] = override_get_db


@pytest.fixture(scope="function")
def test_db():
    """Create test database and tables."""
    Base.metadata.create_all(bind=engine)
    yield
    Base.metadata.drop_all(bind=engine)


@pytest.fixture
def client(test_db):
    """Create test client."""
    return TestClient(app)


@pytest.fixture
def setup_roles(test_db):
    """Create necessary roles in database."""
    db = TestingSessionLocal()

    # Create associate role
    associate_role = RoleModel(
        name="associate",
        description="Associate user",
        hierarchy_level=3,
    )
    db.add(associate_role)

    # Create admin role
    admin_role = RoleModel(
        name="admin",
        description="Administrator",
        hierarchy_level=2,
    )
    db.add(admin_role)

    db.commit()
    db.close()


# ========================================
# E2E TEST 1: Full Authentication Flow
# ========================================


def test_full_auth_flow(client, setup_roles):
    """
    Test complete authentication flow:
    1. Register new user
    2. Login with credentials
    3. Get current user info
    4. Change password
    5. Login with new password
    6. Logout
    """
    # Step 1: Register new user
    register_payload = {
        "username": "e2euser",
        "email": "e2e@example.com",
        "password": "InitialPass123",
        "full_name": "E2E Test User",
        "phone": "5511112222",
        "curp": "E2EU123456HDFRRL09",
        "rfc": "E2EU123456ABC",
    }
    register_response = client.post("/api/v1/auth/register", json=register_payload)
    assert register_response.status_code == 201
    user_data = register_response.json()
    assert user_data["username"] == "e2euser"
    print("✓ Step 1: User registered successfully")

    # Step 2: Login with credentials
    login_payload = {"username_or_email": "e2euser", "password": "InitialPass123"}
    login_response = client.post("/api/v1/auth/login", json=login_payload)
    assert login_response.status_code == 200
    login_data = login_response.json()
    access_token = login_data["tokens"]["access_token"]
    assert access_token is not None
    print("✓ Step 2: Login successful, access token received")

    # Step 3: Get current user info
    headers = {"Authorization": f"Bearer {access_token}"}
    me_response = client.get("/api/v1/auth/me", headers=headers)
    assert me_response.status_code == 200
    me_data = me_response.json()
    assert me_data["username"] == "e2euser"
    assert me_data["email"] == "e2e@example.com"
    print("✓ Step 3: Current user info retrieved successfully")

    # Step 4: Change password
    change_password_payload = {
        "current_password": "InitialPass123",
        "new_password": "NewSecure456",
    }
    change_response = client.post(
        "/api/v1/auth/change-password", json=change_password_payload, headers=headers
    )
    assert change_response.status_code == 200
    assert "successfully" in change_response.json()["message"].lower()
    print("✓ Step 4: Password changed successfully")

    # Step 5: Login with new password
    login_new_payload = {"username_or_email": "e2euser", "password": "NewSecure456"}
    login_new_response = client.post("/api/v1/auth/login", json=login_new_payload)
    assert login_new_response.status_code == 200
    new_access_token = login_new_response.json()["tokens"]["access_token"]
    assert new_access_token is not None
    print("✓ Step 5: Login with new password successful")

    # Step 6: Logout
    new_headers = {"Authorization": f"Bearer {new_access_token}"}
    logout_response = client.post("/api/v1/auth/logout", headers=new_headers)
    assert logout_response.status_code == 200
    assert "successfully" in logout_response.json()["message"].lower()
    print("✓ Step 6: Logout successful")

    print("\n🎉 Full authentication flow completed successfully!")


# ========================================
# E2E TEST 2: Token Refresh Flow
# ========================================


def test_token_refresh_flow(client, setup_roles):
    """
    Test token refresh flow:
    1. Register and login
    2. Get refresh token
    3. Use refresh token to get new access token
    4. Access protected endpoint with new token
    """
    # Step 1: Register and login
    register_payload = {
        "username": "refreshuser",
        "email": "refresh@example.com",
        "password": "RefreshPass123",
        "full_name": "Refresh Test User",
        "phone": "5522223333",
        "curp": "RFSH123456HDFRRL09",
        "rfc": "RFSH123456ABC",
    }
    client.post("/api/v1/auth/register", json=register_payload)

    login_payload = {"username_or_email": "refreshuser", "password": "RefreshPass123"}
    login_response = client.post("/api/v1/auth/login", json=login_payload)
    assert login_response.status_code == 200
    tokens = login_response.json()["tokens"]
    initial_access_token = tokens["access_token"]
    refresh_token = tokens["refresh_token"]
    print("✓ Step 1: User registered and logged in")

    # Step 2: Verify initial access token works
    headers = {"Authorization": f"Bearer {initial_access_token}"}
    me_response = client.get("/api/v1/auth/me", headers=headers)
    assert me_response.status_code == 200
    print("✓ Step 2: Initial access token works")

    # Step 3: Use refresh token to get new access token
    refresh_payload = {"refresh_token": refresh_token}
    refresh_response = client.post("/api/v1/auth/refresh", json=refresh_payload)
    assert refresh_response.status_code == 200
    new_tokens = refresh_response.json()
    new_access_token = new_tokens["access_token"]
    new_refresh_token = new_tokens["refresh_token"]
    assert new_access_token is not None
    assert new_refresh_token is not None
    print("✓ Step 3: Refresh token used, new tokens received")

    # Step 4: Access protected endpoint with new token
    new_headers = {"Authorization": f"Bearer {new_access_token}"}
    new_me_response = client.get("/api/v1/auth/me", headers=new_headers)
    assert new_me_response.status_code == 200
    user_data = new_me_response.json()
    assert user_data["username"] == "refreshuser"
    print("✓ Step 4: New access token works correctly")

    print("\n🎉 Token refresh flow completed successfully!")


# ========================================
# E2E TEST 3: Registration and Login Flow
# ========================================


def test_register_and_login_flow(client, setup_roles):
    """
    Test registration and immediate login:
    1. Register new user
    2. Verify user data in response
    3. Login immediately after registration
    4. Access protected endpoint
    5. Verify user permissions
    """
    # Step 1: Register new user
    register_payload = {
        "username": "quickuser",
        "email": "quick@example.com",
        "password": "QuickPass123",
        "full_name": "Quick Test User",
        "phone": "5533334444",
        "curp": "QCKR123456HDFRRL09",
        "rfc": "QCKR123456ABC",
    }
    register_response = client.post("/api/v1/auth/register", json=register_payload)
    assert register_response.status_code == 201
    user_data = register_response.json()
    assert user_data["username"] == "quickuser"
    assert user_data["email"] == "quick@example.com"
    assert user_data["is_active"] is True
    assert "associate" in user_data["roles"]
    print("✓ Step 1: User registered with correct data")

    # Step 2: Verify user data integrity
    assert "password" not in user_data  # Password should NOT be in response
    assert "password_hash" not in user_data  # Password hash should NOT be in response
    assert user_data["full_name"] == "Quick Test User"
    print("✓ Step 2: User data integrity verified (no password exposed)")

    # Step 3: Login immediately after registration
    login_payload = {"username_or_email": "quickuser", "password": "QuickPass123"}
    login_response = client.post("/api/v1/auth/login", json=login_payload)
    assert login_response.status_code == 200
    login_data = login_response.json()
    assert "user" in login_data
    assert "tokens" in login_data
    access_token = login_data["tokens"]["access_token"]
    print("✓ Step 3: Login successful immediately after registration")

    # Step 4: Access protected endpoint
    headers = {"Authorization": f"Bearer {access_token}"}
    me_response = client.get("/api/v1/auth/me", headers=headers)
    assert me_response.status_code == 200
    current_user = me_response.json()
    assert current_user["id"] == user_data["id"]
    assert current_user["username"] == "quickuser"
    print("✓ Step 4: Protected endpoint accessible with token")

    # Step 5: Verify user permissions
    assert current_user["is_active"] is True
    assert "associate" in current_user["roles"]
    assert current_user["email"] == "quick@example.com"
    print("✓ Step 5: User permissions verified (associate role)")

    print("\n🎉 Registration and login flow completed successfully!")


# ========================================
# E2E TEST 4: Invalid Flows (Negative Testing)
# ========================================


def test_invalid_auth_flows(client, setup_roles):
    """
    Test various invalid authentication scenarios:
    1. Login with non-existent user
    2. Register with duplicate username
    3. Access protected endpoint without token
    4. Use invalid refresh token
    """
    # Step 1: Login with non-existent user
    login_payload = {
        "username_or_email": "nonexistent",
        "password": "DoesNotMatter123",
    }
    login_response = client.post("/api/v1/auth/login", json=login_payload)
    assert login_response.status_code == 401
    print("✓ Step 1: Login with non-existent user rejected correctly")

    # Step 2: Register first user
    register_payload = {
        "username": "existinguser",
        "email": "existing@example.com",
        "password": "ExistingPass123",
        "full_name": "Existing User",
        "phone": "5544445555",
        "curp": "EXST123456HDFRRL09",
        "rfc": "EXST123456ABC",
    }
    client.post("/api/v1/auth/register", json=register_payload)

    # Step 3: Try to register with duplicate username
    duplicate_payload = {
        "username": "existinguser",  # Duplicate
        "email": "different@example.com",
        "password": "DifferentPass123",
        "full_name": "Different User",
        "phone": "5555556666",
        "curp": "DIFF123456HDFRRL09",
        "rfc": "DIFF123456ABC",
    }
    duplicate_response = client.post("/api/v1/auth/register", json=duplicate_payload)
    assert duplicate_response.status_code == 400
    print("✓ Step 2-3: Duplicate username registration rejected correctly")

    # Step 4: Access protected endpoint without token
    me_response = client.get("/api/v1/auth/me")
    assert me_response.status_code == 403
    print("✓ Step 4: Protected endpoint blocked without token")

    # Step 5: Use invalid refresh token
    refresh_payload = {"refresh_token": "totally_invalid_token"}
    refresh_response = client.post("/api/v1/auth/refresh", json=refresh_payload)
    assert refresh_response.status_code == 401
    print("✓ Step 5: Invalid refresh token rejected correctly")

    print("\n🎉 Invalid flows handled correctly!")
