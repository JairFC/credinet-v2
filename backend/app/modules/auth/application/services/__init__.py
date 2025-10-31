"""
Authentication Service - Application layer
Handles authentication use cases: login, register, token management.
"""
from typing import Optional, Tuple
from datetime import timedelta

from app.core.security import (
    verify_password,
    get_password_hash,
    create_access_token,
    create_refresh_token,
    decode_access_token
)
from app.core.config import settings
from app.core.exceptions import (
    AuthenticationError,
    ValidationError,
    NotFoundError
)

from app.modules.auth.domain.entities import User
from app.modules.auth.domain.repositories import UserRepository
from app.modules.auth.application.dtos import (
    LoginRequest,
    LoginResponse,
    RegisterRequest,
    RefreshTokenRequest,
    TokenResponse,
    UserResponse,
    ChangePasswordRequest
)


class AuthService:
    """
    Authentication service for handling user authentication and authorization.
    
    This service implements the use cases for:
    - User login (username/password)
    - User registration
    - Token refresh
    - Password change
    - Get current user
    """
    
    def __init__(self, user_repository: UserRepository):
        """
        Initialize AuthService with user repository.
        
        Args:
            user_repository: Repository for user data access
        """
        self.user_repository = user_repository
    
    async def login(self, request: LoginRequest) -> LoginResponse:
        """
        Authenticate user and generate tokens.
        
        Args:
            request: Login credentials (username/email + password)
            
        Returns:
            LoginResponse with user data and tokens
            
        Raises:
            AuthenticationError: If credentials are invalid
            
        Example:
            >>> response = await auth_service.login(
            ...     LoginRequest(username="admin", password="Admin123!")
            ... )
            >>> print(response.user.username)
            admin
        """
        # Try to find user by username or email
        user = await self._find_user_by_username_or_email(request.username)
        
        if not user:
            raise AuthenticationError("Invalid username or password")
        
        # Check if user is active
        if not user.active:
            raise AuthenticationError("User account is inactive")
        
        # Verify password
        if not verify_password(request.password, user.password_hash):
            raise AuthenticationError("Invalid username or password")
        
        # Generate tokens
        tokens = self._generate_tokens(user)
        
        # Build response
        user_response = self._user_to_response(user)
        
        return LoginResponse(
            user=user_response,
            tokens=tokens
        )
    
    async def register(self, request: RegisterRequest, created_by: Optional[int] = None) -> UserResponse:
        """
        Register a new user in the system.
        
        Args:
            request: Registration data
            created_by: ID of user creating this account (for audit)
            
        Returns:
            UserResponse with created user data
            
        Raises:
            ValidationError: If validation fails
            
        Example:
            >>> user = await auth_service.register(
            ...     RegisterRequest(
            ...         username="juan.perez",
            ...         email="juan@example.com",
            ...         password="SecurePass123!",
            ...         first_name="Juan",
            ...         last_name="Pérez",
            ...         role_id=5  # cliente
            ...     )
            ... )
        """
        # Validate username uniqueness
        if await self.user_repository.exists_username(request.username):
            raise ValidationError(f"Username '{request.username}' already exists")
        
        # Validate email uniqueness
        if await self.user_repository.exists_email(request.email):
            raise ValidationError(f"Email '{request.email}' already exists")
        
        # Validate CURP uniqueness
        if request.curp and await self.user_repository.exists_curp(request.curp):
            raise ValidationError(f"CURP '{request.curp}' already exists")
        
        # Hash password
        password_hash = get_password_hash(request.password)
        
        # Create user entity
        user = User(
            id=0,  # Will be assigned by database
            username=request.username,
            email=request.email,
            password_hash=password_hash,
            first_name=request.first_name,
            last_name=request.last_name,
            phone_number=request.phone_number,
            curp=request.curp,
            birth_date=request.birth_date,
            active=True,
            roles=[]
        )
        
        # Save user
        created_user = await self.user_repository.create(user)
        
        # Assign role
        await self.user_repository.assign_role(created_user.id, request.role_id)
        
        # Reload user with roles
        user_with_roles = await self.user_repository.get_by_id(created_user.id)
        
        return self._user_to_response(user_with_roles)
    
    async def refresh_token(self, request: RefreshTokenRequest) -> TokenResponse:
        """
        Refresh access token using refresh token.
        
        Args:
            request: Refresh token request
            
        Returns:
            TokenResponse with new tokens
            
        Raises:
            AuthenticationError: If refresh token is invalid
        """
        # Verify refresh token
        payload = decode_access_token(request.refresh_token)
        
        if not payload:
            raise AuthenticationError("Invalid or expired refresh token")
        
        # Extract user data
        user_id = payload.get("user_id")
        if not user_id:
            raise AuthenticationError("Invalid token payload")
        
        # Get user from database
        user = await self.user_repository.get_by_id(user_id)
        
        if not user:
            raise AuthenticationError("User not found")
        
        if not user.active:
            raise AuthenticationError("User account is inactive")
        
        # Generate new tokens
        tokens = self._generate_tokens(user)
        
        return tokens
    
    async def get_current_user(self, user_id: int) -> UserResponse:
        """
        Get current authenticated user.
        
        Args:
            user_id: User ID from JWT token
            
        Returns:
            UserResponse with user data
            
        Raises:
            NotFoundError: If user not found
        """
        user = await self.user_repository.get_by_id(user_id)
        
        if not user:
            raise NotFoundError(f"User with ID {user_id} not found")
        
        if not user.active:
            raise AuthenticationError("User account is inactive")
        
        return self._user_to_response(user)
    
    async def change_password(self, user_id: int, request: ChangePasswordRequest) -> None:
        """
        Change user password.
        
        Args:
            user_id: User ID
            request: Change password request with current and new password
            
        Raises:
            AuthenticationError: If current password is invalid
            NotFoundError: If user not found
        """
        # Get user
        user = await self.user_repository.get_by_id(user_id)
        
        if not user:
            raise NotFoundError(f"User with ID {user_id} not found")
        
        # Verify current password
        if not verify_password(request.current_password, user.password_hash):
            raise AuthenticationError("Current password is incorrect")
        
        # Hash new password
        new_password_hash = get_password_hash(request.new_password)
        
        # Update user
        user.password_hash = new_password_hash
        await self.user_repository.update(user)
    
    async def get_user_by_id(self, user_id: int) -> Optional[UserResponse]:
        """
        Get user by ID.
        
        Args:
            user_id: User identifier
            
        Returns:
            UserResponse if found, None otherwise
        """
        user = await self.user_repository.get_by_id(user_id)
        return self._user_to_response(user) if user else None
    
    async def verify_user_has_role(self, user_id: int, role_name: str) -> bool:
        """
        Verify if user has a specific role.
        
        Args:
            user_id: User identifier
            role_name: Role name to check
            
        Returns:
            True if user has the role, False otherwise
        """
        user = await self.user_repository.get_by_id(user_id)
        return user.has_role(role_name) if user else False
    
    # ========================================================================
    # PRIVATE HELPER METHODS
    # ========================================================================
    
    async def _find_user_by_username_or_email(self, identifier: str) -> Optional[User]:
        """
        Find user by username or email.
        
        Args:
            identifier: Username or email
            
        Returns:
            User entity if found, None otherwise
        """
        # Try username first
        user = await self.user_repository.get_by_username(identifier)
        
        # If not found, try email
        if not user and "@" in identifier:
            user = await self.user_repository.get_by_email(identifier)
        
        return user
    
    def _generate_tokens(self, user: User) -> TokenResponse:
        """
        Generate access and refresh tokens for user.
        
        Args:
            user: User entity
            
        Returns:
            TokenResponse with both tokens
        """
        # Prepare token payload
        token_data = {
            "sub": user.username,
            "user_id": user.id,
            "email": user.email,
            "roles": user.roles
        }
        
        # Create access token
        access_token = create_access_token(
            data=token_data,
            expires_delta=timedelta(minutes=settings.access_token_expire_minutes)
        )
        
        # Create refresh token (minimal payload)
        refresh_token_data = {
            "sub": user.username,
            "user_id": user.id
        }
        refresh_token = create_refresh_token(
            data=refresh_token_data,
            expires_delta=timedelta(days=settings.refresh_token_expire_days)
        )
        
        return TokenResponse(
            access_token=access_token,
            refresh_token=refresh_token,
            token_type="bearer",
            expires_in=settings.access_token_expire_minutes * 60  # Convert to seconds
        )
    
    def _user_to_response(self, user: User) -> UserResponse:
        """
        Convert User entity to UserResponse DTO.
        
        Args:
            user: User entity
            
        Returns:
            UserResponse DTO
        """
        return UserResponse(
            id=user.id,
            username=user.username,
            email=user.email,
            first_name=user.first_name,
            last_name=user.last_name,
            full_name=user.full_name,
            phone_number=user.phone_number,
            curp=user.curp,
            birth_date=user.birth_date,
            active=user.active,
            roles=user.roles,
            created_at=user.created_at,
            updated_at=user.updated_at
        )
