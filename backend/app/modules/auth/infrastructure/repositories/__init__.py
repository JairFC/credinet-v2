"""
PostgreSQL implementation of UserRepository.
Handles user data persistence using SQLAlchemy.
"""
from typing import Optional, List
from sqlalchemy import select, exists
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.modules.auth.domain.entities import User
from app.modules.auth.domain.repositories import UserRepository
from app.modules.auth.infrastructure.models import UserModel, RoleModel


class PostgresUserRepository(UserRepository):
    """
    PostgreSQL implementation of UserRepository using SQLAlchemy ORM.
    """
    
    def __init__(self, session: AsyncSession):
        """
        Initialize repository with database session.
        
        Args:
            session: SQLAlchemy async session
        """
        self.session = session
    
    def _model_to_entity(self, model: UserModel) -> User:
        """
        Convert SQLAlchemy model to domain entity.
        
        Args:
            model: UserModel instance
            
        Returns:
            User entity
        """
        roles = [role.name for role in model.roles] if model.roles else []
        
        return User(
            id=model.id,
            username=model.username,
            email=model.email,
            password_hash=model.password_hash,
            first_name=model.first_name,
            last_name=model.last_name,
            phone_number=model.phone_number,
            curp=model.curp,
            birth_date=model.birth_date,
            active=model.active,
            roles=roles,
            created_at=model.created_at,
            updated_at=model.updated_at
        )
    
    async def get_by_id(self, user_id: int) -> Optional[User]:
        """Get user by ID with roles loaded."""
        result = await self.session.execute(
            select(UserModel)
            .options(selectinload(UserModel.roles))
            .where(UserModel.id == user_id)
        )
        model = result.scalar_one_or_none()
        return self._model_to_entity(model) if model else None
    
    async def get_by_username(self, username: str) -> Optional[User]:
        """Get user by username with roles loaded."""
        result = await self.session.execute(
            select(UserModel)
            .options(selectinload(UserModel.roles))
            .where(UserModel.username == username)
        )
        model = result.scalar_one_or_none()
        return self._model_to_entity(model) if model else None
    
    async def get_by_email(self, email: str) -> Optional[User]:
        """Get user by email with roles loaded."""
        result = await self.session.execute(
            select(UserModel)
            .options(selectinload(UserModel.roles))
            .where(UserModel.email == email)
        )
        model = result.scalar_one_or_none()
        return self._model_to_entity(model) if model else None
    
    async def get_by_curp(self, curp: str) -> Optional[User]:
        """Get user by CURP with roles loaded."""
        result = await self.session.execute(
            select(UserModel)
            .options(selectinload(UserModel.roles))
            .where(UserModel.curp == curp)
        )
        model = result.scalar_one_or_none()
        return self._model_to_entity(model) if model else None
    
    async def list_all(self, skip: int = 0, limit: int = 100) -> List[User]:
        """List all active users with pagination."""
        result = await self.session.execute(
            select(UserModel)
            .options(selectinload(UserModel.roles))
            .where(UserModel.active == True)
            .offset(skip)
            .limit(limit)
            .order_by(UserModel.created_at.desc())
        )
        models = result.scalars().all()
        return [self._model_to_entity(model) for model in models]
    
    async def list_by_role(self, role_name: str, skip: int = 0, limit: int = 100) -> List[User]:
        """List users by role with pagination."""
        result = await self.session.execute(
            select(UserModel)
            .join(UserModel.roles)
            .options(selectinload(UserModel.roles))
            .where(RoleModel.name == role_name)
            .where(UserModel.active == True)
            .offset(skip)
            .limit(limit)
            .order_by(UserModel.created_at.desc())
        )
        models = result.scalars().all()
        return [self._model_to_entity(model) for model in models]
    
    async def create(self, user: User) -> User:
        """
        Create a new user.
        
        Note: This method does NOT assign roles. Use a separate method to assign roles.
        """
        model = UserModel(
            username=user.username,
            email=user.email,
            password_hash=user.password_hash,
            first_name=user.first_name,
            last_name=user.last_name,
            phone_number=user.phone_number,
            curp=user.curp,
            birth_date=user.birth_date,
            active=user.active
        )
        
        self.session.add(model)
        await self.session.flush()
        await self.session.refresh(model, ["roles"])
        
        return self._model_to_entity(model)
    
    async def update(self, user: User) -> User:
        """Update an existing user."""
        result = await self.session.execute(
            select(UserModel).where(UserModel.id == user.id)
        )
        model = result.scalar_one_or_none()
        
        if not model:
            raise ValueError(f"User with ID {user.id} not found")
        
        # Update fields
        model.username = user.username
        model.email = user.email
        model.first_name = user.first_name
        model.last_name = user.last_name
        model.phone_number = user.phone_number
        model.curp = user.curp
        model.birth_date = user.birth_date
        model.active = user.active
        
        # Update password only if changed
        if user.password_hash != model.password_hash:
            model.password_hash = user.password_hash
        
        await self.session.flush()
        await self.session.refresh(model, ["roles"])
        
        return self._model_to_entity(model)
    
    async def delete(self, user_id: int) -> bool:
        """Soft delete user by setting active=False."""
        result = await self.session.execute(
            select(UserModel).where(UserModel.id == user_id)
        )
        model = result.scalar_one_or_none()
        
        if not model:
            return False
        
        model.active = False
        await self.session.flush()
        return True
    
    async def exists_username(self, username: str) -> bool:
        """Check if username exists."""
        result = await self.session.execute(
            select(exists().where(UserModel.username == username))
        )
        return result.scalar()
    
    async def exists_email(self, email: str) -> bool:
        """Check if email exists."""
        result = await self.session.execute(
            select(exists().where(UserModel.email == email))
        )
        return result.scalar()
    
    async def exists_curp(self, curp: str) -> bool:
        """Check if CURP exists."""
        if not curp:
            return False
        result = await self.session.execute(
            select(exists().where(UserModel.curp == curp))
        )
        return result.scalar()
    
    async def assign_role(self, user_id: int, role_id: int) -> bool:
        """
        Assign a role to a user.
        
        Args:
            user_id: User identifier
            role_id: Role identifier
            
        Returns:
            True if assigned successfully
        """
        # Get user
        user_result = await self.session.execute(
            select(UserModel).where(UserModel.id == user_id)
        )
        user_model = user_result.scalar_one_or_none()
        
        if not user_model:
            raise ValueError(f"User with ID {user_id} not found")
        
        # Get role
        role_result = await self.session.execute(
            select(RoleModel).where(RoleModel.id == role_id)
        )
        role_model = role_result.scalar_one_or_none()
        
        if not role_model:
            raise ValueError(f"Role with ID {role_id} not found")
        
        # Check if already assigned
        if role_model not in user_model.roles:
            user_model.roles.append(role_model)
            await self.session.flush()
        
        return True
    
    async def remove_role(self, user_id: int, role_id: int) -> bool:
        """
        Remove a role from a user.
        
        Args:
            user_id: User identifier
            role_id: Role identifier
            
        Returns:
            True if removed successfully
        """
        # Get user with roles
        user_result = await self.session.execute(
            select(UserModel)
            .options(selectinload(UserModel.roles))
            .where(UserModel.id == user_id)
        )
        user_model = user_result.scalar_one_or_none()
        
        if not user_model:
            raise ValueError(f"User with ID {user_id} not found")
        
        # Find and remove role
        role_to_remove = None
        for role in user_model.roles:
            if role.id == role_id:
                role_to_remove = role
                break
        
        if role_to_remove:
            user_model.roles.remove(role_to_remove)
            await self.session.flush()
            return True
        
        return False
    
    async def get_role_by_name(self, role_name: str) -> Optional[RoleModel]:
        """
        Get role by name.
        
        Args:
            role_name: Name of the role
            
        Returns:
            RoleModel if found, None otherwise
        """
        result = await self.session.execute(
            select(RoleModel).where(RoleModel.name == role_name)
        )
        return result.scalar_one_or_none()
