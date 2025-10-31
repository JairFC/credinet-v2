"""
Data Transfer Objects (DTOs) for auth module.
Define request/response schemas for authentication endpoints.
"""
from pydantic import BaseModel, EmailStr, Field, validator
from datetime import datetime, date
from typing import Optional, List


# ============================================================================
# REQUEST DTOs
# ============================================================================

class LoginRequest(BaseModel):
    """Request schema for user login."""
    username: str = Field(..., min_length=3, max_length=50, description="Username or email")
    password: str = Field(..., min_length=6, description="User password")
    
    class Config:
        json_schema_extra = {
            "example": {
                "username": "admin",
                "password": "Admin123!"
            }
        }


class RegisterRequest(BaseModel):
    """Request schema for user registration."""
    username: str = Field(..., min_length=3, max_length=50, description="Unique username")
    email: EmailStr = Field(..., description="Email address")
    password: str = Field(..., min_length=8, description="Password (min 8 characters)")
    first_name: str = Field(..., min_length=2, max_length=100, description="First name")
    last_name: str = Field(..., min_length=2, max_length=100, description="Last name")
    phone_number: Optional[str] = Field(None, min_length=10, max_length=10, description="Phone number (10 digits)")
    curp: Optional[str] = Field(None, min_length=18, max_length=18, description="Mexican CURP (18 characters)")
    birth_date: Optional[date] = Field(None, description="Date of birth")
    role_id: int = Field(..., description="Role ID to assign (5=cliente by default)")
    
    @validator('phone_number')
    def validate_phone(cls, v):
        """Validate phone number is numeric."""
        if v and not v.isdigit():
            raise ValueError('Phone number must contain only digits')
        return v
    
    @validator('curp')
    def validate_curp(cls, v):
        """Validate CURP format."""
        if v and len(v) != 18:
            raise ValueError('CURP must be exactly 18 characters')
        return v.upper() if v else None
    
    @validator('password')
    def validate_password(cls, v):
        """Validate password strength."""
        if len(v) < 8:
            raise ValueError('Password must be at least 8 characters')
        if not any(c.isupper() for c in v):
            raise ValueError('Password must contain at least one uppercase letter')
        if not any(c.islower() for c in v):
            raise ValueError('Password must contain at least one lowercase letter')
        if not any(c.isdigit() for c in v):
            raise ValueError('Password must contain at least one number')
        return v
    
    class Config:
        json_schema_extra = {
            "example": {
                "username": "juan.perez",
                "email": "juan.perez@example.com",
                "password": "SecurePass123!",
                "first_name": "Juan",
                "last_name": "Pérez",
                "phone_number": "5512345678",
                "curp": "PEPJ900101HDFLRN09",
                "birth_date": "1990-01-01",
                "role_id": 5
            }
        }


class RefreshTokenRequest(BaseModel):
    """Request schema for token refresh."""
    refresh_token: str = Field(..., description="Refresh token")
    
    class Config:
        json_schema_extra = {
            "example": {
                "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
            }
        }


class ChangePasswordRequest(BaseModel):
    """Request schema for changing password."""
    current_password: str = Field(..., description="Current password")
    new_password: str = Field(..., min_length=8, description="New password (min 8 characters)")
    
    @validator('new_password')
    def validate_password(cls, v):
        """Validate password strength."""
        if len(v) < 8:
            raise ValueError('Password must be at least 8 characters')
        if not any(c.isupper() for c in v):
            raise ValueError('Password must contain at least one uppercase letter')
        if not any(c.islower() for c in v):
            raise ValueError('Password must contain at least one lowercase letter')
        if not any(c.isdigit() for c in v):
            raise ValueError('Password must contain at least one number')
        return v


# ============================================================================
# RESPONSE DTOs
# ============================================================================

class TokenResponse(BaseModel):
    """Response schema for authentication tokens."""
    access_token: str = Field(..., description="JWT access token")
    refresh_token: str = Field(..., description="JWT refresh token")
    token_type: str = Field(default="bearer", description="Token type")
    expires_in: int = Field(..., description="Token expiration time in seconds")
    
    class Config:
        json_schema_extra = {
            "example": {
                "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
                "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
                "token_type": "bearer",
                "expires_in": 86400
            }
        }


class UserResponse(BaseModel):
    """Response schema for user data."""
    id: int
    username: str
    email: str
    first_name: str
    last_name: str
    full_name: str
    phone_number: Optional[str]
    curp: Optional[str]
    birth_date: Optional[date]
    active: bool
    roles: List[str]
    created_at: datetime
    updated_at: datetime
    
    class Config:
        from_attributes = True
        json_schema_extra = {
            "example": {
                "id": 2,
                "username": "admin",
                "email": "admin@credinet.com",
                "first_name": "Admin",
                "last_name": "CrediNet",
                "full_name": "Admin CrediNet",
                "phone_number": "5512345678",
                "curp": None,
                "birth_date": None,
                "active": True,
                "roles": ["administrador"],
                "created_at": "2025-01-01T00:00:00",
                "updated_at": "2025-01-01T00:00:00"
            }
        }


class LoginResponse(BaseModel):
    """Response schema for successful login."""
    user: UserResponse
    tokens: TokenResponse
    
    class Config:
        json_schema_extra = {
            "example": {
                "user": UserResponse.Config.json_schema_extra["example"],
                "tokens": TokenResponse.Config.json_schema_extra["example"]
            }
        }


class MessageResponse(BaseModel):
    """Generic message response."""
    message: str = Field(..., description="Response message")
    
    class Config:
        json_schema_extra = {
            "example": {
                "message": "Operation completed successfully"
            }
        }
