"""Modelo SQLAlchemy para addresses"""
from sqlalchemy import Column, Integer, String, DateTime, ForeignKey
from sqlalchemy.sql import func

from app.core.database import Base


class AddressModel(Base):
    """Modelo SQLAlchemy: addresses"""
    __tablename__ = 'addresses'
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey('users.id'), nullable=False)
    street = Column(String(200), nullable=False)
    external_number = Column(String(20), nullable=False)
    internal_number = Column(String(20))
    colony = Column(String(100), nullable=False)
    municipality = Column(String(100), nullable=False)
    state = Column(String(100), nullable=False)
    zip_code = Column(String(10), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.current_timestamp())
    updated_at = Column(DateTime(timezone=True), server_default=func.current_timestamp(), onupdate=func.current_timestamp())
