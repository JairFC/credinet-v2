"""
Integration tests for Auth endpoints.

Tests all REST endpoints:
- POST /auth/login - Login with tokens
- POST /auth/register - User registration
- POST /auth/refresh - Renew tokens
- GET /auth/me - Current user
- POST /auth/change-password - Change password
- POST /auth/logout - Logout
"""

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from datetime import datetime

from app.main import app
from app.core.database import Base, get_db
from app.core.security import get_password_hash, create_access_token, create_refresh_token
from app.modules.auth.infrastructure.models import UserModel, RoleModel


# ========================================
# TEST DATABASE SETUP
# ========================================

SQLALCHEMY_TEST_DATABASE_URL = "sqlite:///./test_auth.db"

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
def test_user(test_db):
    """Create a test user in database."""
    db = TestingSessionLocal()

    # Create associate role
    role = RoleModel(
        name="associate",
        description="Associate user",
        hierarchy_level=3,
    )
    db.add(role)
    db.commit()
    db.refresh(role)

    # Create user
    user = UserModel(
        username="testuser",
        email="test@example.com",
        full_name="Test User",
        password_hash=get_password_hash("Password123"),
        phone="5512345678",
        curp="ABCD123456HDFRRL09",
        rfc="ABCD123456ABC",
        is_active=True,
    )
    user.roles.append(role)
    db.add(user)
    db.commit()
    db.refresh(user)

    user_id = user.id
    db.close()

    return {
        "id": user_id,
        "username": "testuser",
        "email": "test@example.com",
        "password": "Password123",
    }


@pytest.fixture
def admin_user(test_db):
    """Create an admin user in database."""
    db = TestingSessionLocal()

    # Create admin role
    role = RoleModel(
        name="admin",
        description="Administrator",
        hierarchy_level=2,
    )
    db.add(role)
    db.commit()
    db.refresh(role)

    # Create admin user
    user = UserModel(
        username="admin",
        email="admin@example.com",
        full_name="Admin User",
        password_hash=get_password_hash("AdminPass123"),
        phone="5598765432",
        curp="WXYZ123456HDFRRL09",
        rfc="WXYZ123456ABC",
        is_active=True,
    )
    user.roles.append(role)
    db.add(user)
    db.commit()
    db.refresh(user)

    user_id = user.id
    db.close()

    return {
        "id": user_id,
        "username": "admin",
        "email": "admin@example.com",
        "password": "AdminPass123",
    }


@pytest.fixture
def auth_token(test_user):
    """Generate valid JWT token for test user."""
    token = create_access_token(
        data={"sub": str(test_user["id"]), "roles": ["associate"]}
    )
    return token


# ========================================
# TESTS: POST /auth/login
# ========================================


def test_post_login_success_with_username(client, test_user):
    """Test successful login with username."""
    # Arrange
    payload = {"username_or_email": "testuser", "password": "Password123"}

    # Act
    response = client.post("/api/v1/auth/login", json=payload)

    # Assert
    assert response.status_code == 200
    data = response.json()
    assert "user" in data
    assert data["user"]["username"] == "testuser"
    assert data["user"]["email"] == "test@example.com"
    assert "tokens" in data
    assert "access_token" in data["tokens"]
    assert "refresh_token" in data["tokens"]
    assert data["tokens"]["token_type"] == "bearer"


def test_post_login_success_with_email(client, test_user):
    """Test successful login with email."""
    # Arrange
    payload = {"username_or_email": "test@example.com", "password": "Password123"}

    # Act
    response = client.post("/api/v1/auth/login", json=payload)

    # Assert
    assert response.status_code == 200
    data = response.json()
    assert data["user"]["email"] == "test@example.com"
    assert "access_token" in data["tokens"]


def test_post_login_invalid_credentials(client, test_user):
    """Test login with invalid credentials."""
    # Arrange
    payload = {"username_or_email": "testuser", "password": "WrongPassword"}

    # Act
    response = client.post("/api/v1/auth/login", json=payload)

    # Assert
    assert response.status_code == 401
    data = response.json()
    assert "detail" in data


def test_post_login_user_not_found(client):
    """Test login with non-existent user."""
    # Arrange
    payload = {"username_or_email": "nonexistent", "password": "Password123"}

    # Act
    response = client.post("/api/v1/auth/login", json=payload)

    # Assert
    assert response.status_code == 401
    data = response.json()
    assert "detail" in data


# ========================================
# TESTS: POST /auth/register
# ========================================


def test_post_register_success(client, test_db):
    """Test successful user registration."""
    # Arrange
    db = TestingSessionLocal()
    role = RoleModel(
        name="associate",
        description="Associate user",
        hierarchy_level=3,
    )
    db.add(role)
    db.commit()
    db.close()

    payload = {
        "username": "newuser",
        "email": "newuser@example.com",
        "password": "SecurePass123",
        "full_name": "New User",
        "phone": "5511112222",
        "curp": "NWUS123456HDFRRL09",
        "rfc": "NWUS123456ABC",
    }

    # Act
    response = client.post("/api/v1/auth/register", json=payload)

    # Assert
    assert response.status_code == 201
    data = response.json()
    assert data["username"] == "newuser"
    assert data["email"] == "newuser@example.com"
    assert "associate" in data["roles"]
    assert "password" not in data  # Password should not be in response


def test_post_register_duplicate_username(client, test_user):
    """Test registration with duplicate username."""
    # Arrange
    payload = {
        "username": "testuser",  # Already exists
        "email": "different@example.com",
        "password": "SecurePass123",
        "full_name": "Different User",
        "phone": "5511112222",
        "curp": "DIFF123456HDFRRL09",
        "rfc": "DIFF123456ABC",
    }

    # Act
    response = client.post("/api/v1/auth/register", json=payload)

    # Assert
    assert response.status_code == 400
    data = response.json()
    assert "already exists" in data["detail"].lower()


def test_post_register_duplicate_email(client, test_user):
    """Test registration with duplicate email."""
    # Arrange
    payload = {
        "username": "differentuser",
        "email": "test@example.com",  # Already exists
        "password": "SecurePass123",
        "full_name": "Different User",
        "phone": "5511112222",
        "curp": "DIFF123456HDFRRL09",
        "rfc": "DIFF123456ABC",
    }

    # Act
    response = client.post("/api/v1/auth/register", json=payload)

    # Assert
    assert response.status_code == 400
    data = response.json()
    assert "already exists" in data["detail"].lower()


def test_post_register_weak_password(client):
    """Test registration with weak password."""
    # Arrange
    payload = {
        "username": "newuser",
        "email": "newuser@example.com",
        "password": "weak",  # Too short, no uppercase, no number
        "full_name": "New User",
        "phone": "5511112222",
        "curp": "NWUS123456HDFRRL09",
        "rfc": "NWUS123456ABC",
    }

    # Act
    response = client.post("/api/v1/auth/register", json=payload)

    # Assert
    assert response.status_code == 422  # Pydantic validation error


# ========================================
# TESTS: POST /auth/refresh
# ========================================


def test_post_refresh_success(client, test_user):
    """Test successful token refresh."""
    # Arrange
    refresh_token = create_refresh_token(data={"sub": str(test_user["id"])})
    payload = {"refresh_token": refresh_token}

    # Act
    response = client.post("/api/v1/auth/refresh", json=payload)

    # Assert
    assert response.status_code == 200
    data = response.json()
    assert "access_token" in data
    assert "refresh_token" in data
    assert data["token_type"] == "bearer"


def test_post_refresh_invalid_token(client):
    """Test refresh with invalid token."""
    # Arrange
    payload = {"refresh_token": "invalid_token"}

    # Act
    response = client.post("/api/v1/auth/refresh", json=payload)

    # Assert
    assert response.status_code == 401
    data = response.json()
    assert "detail" in data


# ========================================
# TESTS: GET /auth/me
# ========================================


def test_get_me_success(client, test_user, auth_token):
    """Test GET /auth/me with valid token."""
    # Arrange
    headers = {"Authorization": f"Bearer {auth_token}"}

    # Act
    response = client.get("/api/v1/auth/me", headers=headers)

    # Assert
    assert response.status_code == 200
    data = response.json()
    assert data["username"] == "testuser"
    assert data["email"] == "test@example.com"
    assert "associate" in data["roles"]


def test_get_me_no_token(client):
    """Test GET /auth/me without token."""
    # Act
    response = client.get("/api/v1/auth/me")

    # Assert
    assert response.status_code == 403  # Forbidden (no Authorization header)


def test_get_me_invalid_token(client):
    """Test GET /auth/me with invalid token."""
    # Arrange
    headers = {"Authorization": "Bearer invalid_token"}

    # Act
    response = client.get("/api/v1/auth/me", headers=headers)

    # Assert
    assert response.status_code == 401


# ========================================
# TESTS: POST /auth/change-password
# ========================================


def test_post_change_password_success(client, test_user, auth_token):
    """Test successful password change."""
    # Arrange
    headers = {"Authorization": f"Bearer {auth_token}"}
    payload = {"current_password": "Password123", "new_password": "NewSecure456"}

    # Act
    response = client.post("/api/v1/auth/change-password", json=payload, headers=headers)

    # Assert
    assert response.status_code == 200
    data = response.json()
    assert "successfully" in data["message"].lower()


def test_post_change_password_wrong_current(client, test_user, auth_token):
    """Test password change with wrong current password."""
    # Arrange
    headers = {"Authorization": f"Bearer {auth_token}"}
    payload = {"current_password": "WrongPassword", "new_password": "NewSecure456"}

    # Act
    response = client.post("/api/v1/auth/change-password", json=payload, headers=headers)

    # Assert
    assert response.status_code == 401
    data = response.json()
    assert "detail" in data


def test_post_change_password_no_token(client):
    """Test password change without token."""
    # Arrange
    payload = {"current_password": "Password123", "new_password": "NewSecure456"}

    # Act
    response = client.post("/api/v1/auth/change-password", json=payload)

    # Assert
    assert response.status_code == 403


# ========================================
# TESTS: POST /auth/logout
# ========================================


def test_post_logout_success(client, auth_token):
    """Test successful logout."""
    # Arrange
    headers = {"Authorization": f"Bearer {auth_token}"}

    # Act
    response = client.post("/api/v1/auth/logout", headers=headers)

    # Assert
    assert response.status_code == 200
    data = response.json()
    assert "successfully" in data["message"].lower()


def test_post_logout_no_token(client):
    """Test logout without token."""
    # Act
    response = client.post("/api/v1/auth/logout")

    # Assert
    assert response.status_code == 403
