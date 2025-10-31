"""
User Repository Interface - Domain layer
Defines the contract for user data access operations.
"""
from abc import ABC, abstractmethod
from typing import Optional, List
from app.modules.auth.domain.entities import User


class UserRepository(ABC):
    """
    Abstract repository for User entity.
    
    This interface defines the contract that any User repository
    implementation must follow (PostgreSQL, MongoDB, in-memory, etc.)
    """
    
    @abstractmethod
    async def get_by_id(self, user_id: int) -> Optional[User]:
        """
        Get user by ID.
        
        Args:
            user_id: User identifier
            
        Returns:
            User entity if found, None otherwise
        """
        pass
    
    @abstractmethod
    async def get_by_username(self, username: str) -> Optional[User]:
        """
        Get user by username.
        
        Args:
            username: Username to search
            
        Returns:
            User entity if found, None otherwise
        """
        pass
    
    @abstractmethod
    async def get_by_email(self, email: str) -> Optional[User]:
        """
        Get user by email.
        
        Args:
            email: Email address to search
            
        Returns:
            User entity if found, None otherwise
        """
        pass
    
    @abstractmethod
    async def get_by_curp(self, curp: str) -> Optional[User]:
        """
        Get user by CURP.
        
        Args:
            curp: Mexican CURP identifier
            
        Returns:
            User entity if found, None otherwise
        """
        pass
    
    @abstractmethod
    async def list_all(self, skip: int = 0, limit: int = 100) -> List[User]:
        """
        List all users with pagination.
        
        Args:
            skip: Number of records to skip
            limit: Maximum number of records to return
            
        Returns:
            List of User entities
        """
        pass
    
    @abstractmethod
    async def list_by_role(self, role_name: str, skip: int = 0, limit: int = 100) -> List[User]:
        """
        List users by role.
        
        Args:
            role_name: Role name to filter by
            skip: Number of records to skip
            limit: Maximum number of records to return
            
        Returns:
            List of User entities with the specified role
        """
        pass
    
    @abstractmethod
    async def create(self, user: User) -> User:
        """
        Create a new user.
        
        Args:
            user: User entity to create
            
        Returns:
            Created User entity with ID assigned
        """
        pass
    
    @abstractmethod
    async def update(self, user: User) -> User:
        """
        Update an existing user.
        
        Args:
            user: User entity with updated data
            
        Returns:
            Updated User entity
        """
        pass
    
    @abstractmethod
    async def delete(self, user_id: int) -> bool:
        """
        Delete a user (soft delete by setting active=False).
        
        Args:
            user_id: User identifier
            
        Returns:
            True if deleted successfully, False if not found
        """
        pass
    
    @abstractmethod
    async def exists_username(self, username: str) -> bool:
        """
        Check if username already exists.
        
        Args:
            username: Username to check
            
        Returns:
            True if exists, False otherwise
        """
        pass
    
    @abstractmethod
    async def exists_email(self, email: str) -> bool:
        """
        Check if email already exists.
        
        Args:
            email: Email to check
            
        Returns:
            True if exists, False otherwise
        """
        pass
    
    @abstractmethod
    async def exists_curp(self, curp: str) -> bool:
        """
        Check if CURP already exists.
        
        Args:
            curp: CURP to check
            
        Returns:
            True if exists, False otherwise
        """
        pass
