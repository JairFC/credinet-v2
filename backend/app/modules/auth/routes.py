"""
Authentication Routes - FastAPI endpoints for auth module.
Handles user authentication, registration, and token management.
"""
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_async_db
from app.core.security import decode_access_token
from app.core.exceptions import (
    AuthenticationError,
    ValidationError,
    NotFoundError
)

from app.modules.auth.infrastructure.repositories import PostgresUserRepository
from app.modules.auth.application.services import AuthService
from app.modules.auth.application.dtos import (
    LoginRequest,
    LoginResponse,
    RegisterRequest,
    RefreshTokenRequest,
    TokenResponse,
    UserResponse,
    ChangePasswordRequest,
    MessageResponse
)


# Create router
router = APIRouter(prefix="/auth", tags=["Authentication"])

# Security scheme
security = HTTPBearer()


# ============================================================================
# DEPENDENCY INJECTION
# ============================================================================

def get_auth_service(db: AsyncSession = Depends(get_async_db)) -> AuthService:
    """
    Dependency to get AuthService instance.
    
    Args:
        db: Database session from dependency
        
    Returns:
        Configured AuthService instance
    """
    user_repository = PostgresUserRepository(db)
    return AuthService(user_repository)


async def get_current_user_id(
    credentials: HTTPAuthorizationCredentials = Depends(security)
) -> int:
    """
    Dependency to extract current user ID from JWT token.
    
    Args:
        credentials: Authorization credentials from request header
        
    Returns:
        User ID from token
        
    Raises:
        HTTPException: If token is invalid or missing
    """
    token = credentials.credentials
    
    # Decode token
    payload = decode_access_token(token)
    
    if not payload:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
            headers={"WWW-Authenticate": "Bearer"}
        )
    
    user_id = payload.get("user_id")
    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token payload",
            headers={"WWW-Authenticate": "Bearer"}
        )
    
    return user_id


# ============================================================================
# ENDPOINTS
# ============================================================================

@router.post(
    "/login",
    response_model=LoginResponse,
    status_code=status.HTTP_200_OK,
    summary="User Login",
    description="Authenticate user with username/email and password. Returns user data and JWT tokens."
)
async def login(
    request: LoginRequest,
    auth_service: AuthService = Depends(get_auth_service)
):
    """
    **Login endpoint**
    
    Authenticates a user with username (or email) and password.
    
    **Returns:**
    - User data (id, username, email, roles, etc.)
    - Access token (JWT, expires in 24 hours)
    - Refresh token (JWT, expires in 7 days)
    
    **Errors:**
    - 401: Invalid credentials or inactive account
    """
    try:
        response = await auth_service.login(request)
        return response
    
    except AuthenticationError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=str(e),
            headers={"WWW-Authenticate": "Bearer"}
        )
    
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Login failed: {str(e)}"
        )


@router.post(
    "/register",
    response_model=UserResponse,
    status_code=status.HTTP_201_CREATED,
    summary="User Registration",
    description="Register a new user in the system. Requires admin privileges (not implemented yet)."
)
async def register(
    request: RegisterRequest,
    auth_service: AuthService = Depends(get_auth_service)
):
    """
    **Register endpoint**
    
    Creates a new user account in the system.
    
    **Required fields:**
    - username (unique)
    - email (unique)
    - password (min 8 chars, uppercase, lowercase, number)
    - first_name
    - last_name
    - role_id (5=cliente by default)
    
    **Optional fields:**
    - phone_number (10 digits)
    - curp (18 characters)
    - birth_date
    
    **Returns:**
    - Created user data
    
    **Errors:**
    - 400: Validation error (duplicate username/email/curp, weak password, etc.)
    """
    try:
        user = await auth_service.register(request)
        return user
    
    except ValidationError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )
    
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Registration failed: {str(e)}"
        )


@router.post(
    "/refresh",
    response_model=TokenResponse,
    status_code=status.HTTP_200_OK,
    summary="Refresh Token",
    description="Get new access token using refresh token."
)
async def refresh_token(
    request: RefreshTokenRequest,
    auth_service: AuthService = Depends(get_auth_service)
):
    """
    **Refresh token endpoint**
    
    Generates a new access token using a valid refresh token.
    
    **Use case:**
    When access token expires (24 hours), use this endpoint to get a new one
    without requiring user to login again.
    
    **Returns:**
    - New access token
    - New refresh token
    
    **Errors:**
    - 401: Invalid or expired refresh token
    """
    try:
        tokens = await auth_service.refresh_token(request)
        return tokens
    
    except AuthenticationError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=str(e),
            headers={"WWW-Authenticate": "Bearer"}
        )
    
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Token refresh failed: {str(e)}"
        )


@router.get(
    "/me",
    response_model=UserResponse,
    status_code=status.HTTP_200_OK,
    summary="Get Current User",
    description="Get currently authenticated user information."
)
async def get_current_user(
    user_id: int = Depends(get_current_user_id),
    auth_service: AuthService = Depends(get_auth_service)
):
    """
    **Get current user endpoint**
    
    Returns information about the currently authenticated user.
    
    **Authentication required:** Yes (Bearer token in Authorization header)
    
    **Returns:**
    - User data (id, username, email, roles, etc.)
    
    **Errors:**
    - 401: Invalid or expired token
    - 404: User not found
    """
    try:
        user = await auth_service.get_current_user(user_id)
        return user
    
    except NotFoundError as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(e)
        )
    
    except AuthenticationError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=str(e),
            headers={"WWW-Authenticate": "Bearer"}
        )
    
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get current user: {str(e)}"
        )


@router.post(
    "/change-password",
    response_model=MessageResponse,
    status_code=status.HTTP_200_OK,
    summary="Change Password",
    description="Change current user's password."
)
async def change_password(
    request: ChangePasswordRequest,
    user_id: int = Depends(get_current_user_id),
    auth_service: AuthService = Depends(get_auth_service)
):
    """
    **Change password endpoint**
    
    Allows authenticated user to change their password.
    
    **Authentication required:** Yes (Bearer token in Authorization header)
    
    **Required fields:**
    - current_password: Current password for verification
    - new_password: New password (min 8 chars, uppercase, lowercase, number)
    
    **Returns:**
    - Success message
    
    **Errors:**
    - 401: Invalid current password or token
    - 404: User not found
    """
    try:
        await auth_service.change_password(user_id, request)
        return MessageResponse(message="Password changed successfully")
    
    except AuthenticationError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=str(e),
            headers={"WWW-Authenticate": "Bearer"}
        )
    
    except NotFoundError as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(e)
        )
    
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Password change failed: {str(e)}"
        )


@router.post(
    "/logout",
    response_model=MessageResponse,
    status_code=status.HTTP_200_OK,
    summary="Logout",
    description="Logout current user (client-side token removal)."
)
async def logout(
    user_id: int = Depends(get_current_user_id)
):
    """
    **Logout endpoint**
    
    Logs out the current user.
    
    **Note:** With JWT tokens, logout is handled client-side by removing the token.
    This endpoint validates the token and returns success.
    
    For true server-side logout, implement token blacklisting (future enhancement).
    
    **Authentication required:** Yes (Bearer token in Authorization header)
    
    **Returns:**
    - Success message
    
    **Errors:**
    - 401: Invalid or expired token
    """
    return MessageResponse(
        message=f"User {user_id} logged out successfully. Remove token from client."
    )
