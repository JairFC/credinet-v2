"""
User entity - Domain layer
Represents a user in the system with authentication capabilities.
"""
from dataclasses import dataclass
from datetime import datetime
from typing import Optional, List


@dataclass
class User:
    """
    User entity representing a system user.
    
    Attributes:
        id: Unique identifier
        username: Unique username for login
        email: User's email address
        password_hash: Hashed password (never store plain passwords)
        first_name: User's first name
        last_name: User's last name
        phone_number: Contact phone number
        curp: Mexican CURP identifier
        birth_date: Date of birth
        active: Whether user account is active
        roles: List of role names assigned to this user
        created_at: Account creation timestamp
        updated_at: Last update timestamp
    """
    id: int
    username: str
    email: str
    password_hash: str
    first_name: str
    last_name: str
    phone_number: Optional[str] = None
    curp: Optional[str] = None
    birth_date: Optional[datetime] = None
    profile_picture_url: Optional[str] = None
    active: bool = True
    roles: List[str] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
    
    def __post_init__(self):
        """Initialize default values after dataclass creation."""
        if self.roles is None:
            self.roles = []
    
    @property
    def full_name(self) -> str:
        """Get user's full name."""
        return f"{self.first_name} {self.last_name}"
    
    def has_role(self, role_name: str) -> bool:
        """
        Check if user has a specific role.
        
        Args:
            role_name: Name of the role to check (case-insensitive)
            
        Returns:
            bool: True if user has the role
            
        Example:
            >>> user.has_role("administrador")
            True
        """
        return role_name.lower() in [r.lower() for r in self.roles]
    
    def is_admin(self) -> bool:
        """Check if user is an administrator."""
        return self.has_role("administrador") or self.has_role("desarrollador")
    
    def is_associate(self) -> bool:
        """Check if user is an associate (distributor)."""
        return self.has_role("asociado")
    
    def is_client(self) -> bool:
        """Check if user is a client."""
        return self.has_role("cliente")
    
    def can_approve_loans(self) -> bool:
        """Check if user can approve loans (admins only)."""
        return self.is_admin()
    
    def can_register_payments(self) -> bool:
        """Check if user can register payments (admins and associates)."""
        return self.is_admin() or self.is_associate()
    
    def to_dict(self) -> dict:
        """
        Convert entity to dictionary (excluding password).
        
        Returns:
            dict: User data without sensitive information
        """
        return {
            "id": self.id,
            "username": self.username,
            "email": self.email,
            "first_name": self.first_name,
            "last_name": self.last_name,
            "full_name": self.full_name,
            "phone_number": self.phone_number,
            "curp": self.curp,
            "birth_date": self.birth_date.isoformat() if self.birth_date else None,
            "active": self.active,
            "roles": self.roles,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None,
        }
