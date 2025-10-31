"""
SQLAlchemy models for auth module.
Maps database tables to Python classes.
"""
from sqlalchemy import Column, Integer, String, Boolean, DateTime, Date, ForeignKey, Table
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.core.database import Base


# Association table for many-to-many relationship between users and roles
user_roles = Table(
    'user_roles',
    Base.metadata,
    Column('user_id', Integer, ForeignKey('users.id', ondelete='CASCADE'), primary_key=True),
    Column('role_id', Integer, ForeignKey('roles.id', ondelete='CASCADE'), primary_key=True)
)


class UserModel(Base):
    """
    SQLAlchemy model for users table.
    
    Represents a user in the system with authentication capabilities.
    """
    __tablename__ = "users"
    
    # Primary Key
    id = Column(Integer, primary_key=True, index=True)
    
    # Authentication fields
    username = Column(String(50), unique=True, nullable=False, index=True)
    password_hash = Column(String(255), nullable=False)
    email = Column(String(100), unique=True, nullable=False, index=True)
    
    # Personal information
    first_name = Column(String(100), nullable=False)
    last_name = Column(String(100), nullable=False)
    phone_number = Column(String(10), unique=True, nullable=True)
    curp = Column(String(18), unique=True, nullable=True)
    birth_date = Column(Date, nullable=True)
    
    # Status
    active = Column(Boolean, default=True, nullable=False)
    
    # Timestamps
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)
    
    # Relationships
    roles = relationship(
        "RoleModel",
        secondary=user_roles,
        back_populates="users",
        lazy="joined"  # Eager load roles with user
    )
    
    def __repr__(self):
        return f"<User(id={self.id}, username='{self.username}', email='{self.email}')>"


class RoleModel(Base):
    """
    SQLAlchemy model for roles table.
    
    Represents a role that can be assigned to users.
    """
    __tablename__ = "roles"
    
    # Primary Key
    id = Column(Integer, primary_key=True, index=True)
    
    # Role information
    name = Column(String(50), unique=True, nullable=False, index=True)
    description = Column(String(255), nullable=True)
    
    # Hierarchy level (lower number = higher priority)
    # 1: Desarrollador, 2: Administrador, 3: Auxiliar, 4: Asociado, 5: Cliente
    hierarchy_level = Column(Integer, nullable=False, default=5)
    
    # Timestamps
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    
    # Relationships
    users = relationship(
        "UserModel",
        secondary=user_roles,
        back_populates="roles"
    )
    
    def __repr__(self):
        return f"<Role(id={self.id}, name='{self.name}', level={self.hierarchy_level})>"
