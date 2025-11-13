"""Modelo SQLAlchemy para guarantors"""
from sqlalchemy import Column, Integer, String, DateTime, ForeignKey
from sqlalchemy.sql import func

from app.core.database import Base
from app.modules.shared.infrastructure.models import RelationshipModel  # Import para FK


class GuarantorModel(Base):
    """Modelo SQLAlchemy: guarantors"""
    __tablename__ = 'guarantors'
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey('users.id'), nullable=False)
    full_name = Column(String(200), nullable=False)
    first_name = Column(String(100))
    paternal_last_name = Column(String(100))
    maternal_last_name = Column(String(100))
    relationship = Column(String(50), nullable=False)
    relationship_id = Column(Integer, ForeignKey('relationships.id'), nullable=True)  # FK al catálogo
    phone_number = Column(String(20), nullable=False)
    curp = Column(String(18))
    created_at = Column(DateTime(timezone=True), server_default=func.current_timestamp())
    updated_at = Column(DateTime(timezone=True), server_default=func.current_timestamp(), onupdate=func.current_timestamp())
