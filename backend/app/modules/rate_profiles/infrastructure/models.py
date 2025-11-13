"""
Modelo SQLAlchemy para rate_profiles.

Este modelo permite que SQLAlchemy reconozca la tabla rate_profiles
y pueda establecer foreign keys desde otras tablas (como loans).

IMPORTANTE: Este modelo debe coincidir exactamente con la tabla en 
db/v2.0/modules/06_rate_profiles.sql
"""
from sqlalchemy import Column, Integer, String, Numeric, Boolean, DateTime, Text, ARRAY, ForeignKey
from sqlalchemy.sql import func

from app.core.database import Base


class RateProfileModel(Base):
    """
    Modelo SQLAlchemy para tabla rate_profiles.
    
    Fuente de verdad: db/v2.0/modules/06_rate_profiles.sql
    """
    
    __tablename__ = "rate_profiles"
    
    # Primary key
    id = Column(Integer, primary_key=True, autoincrement=True)
    
    # Unique code (used as FK in loans table)
    code = Column(String(50), unique=True, nullable=False, index=True)
    
    # Profile information
    name = Column(String(100), nullable=False)
    description = Column(Text, nullable=True)
    
    # Calculation method
    calculation_type = Column(
        String(20), 
        nullable=False,
        comment="'table_lookup' o 'formula'"
    )
    
    # Rates (precision 5,3 para soportar valores como 4.250)
    interest_rate_percent = Column(
        Numeric(5, 3), 
        nullable=True, 
        comment="Tasa de interés en porcentaje (ej: 4.250 = 4.25%)"
    )
    commission_rate_percent = Column(
        Numeric(5, 3), 
        nullable=True, 
        comment="Tasa de comisión en porcentaje (ej: 2.500 = 2.50%)"
    )
    
    # Status and display
    enabled = Column(Boolean, default=True, nullable=True, index=True)
    is_recommended = Column(Boolean, default=False, nullable=True)
    display_order = Column(Integer, default=0, nullable=True)
    
    # Constraints
    min_amount = Column(Numeric(12, 2), nullable=True, comment="Monto mínimo permitido")
    max_amount = Column(Numeric(12, 2), nullable=True, comment="Monto máximo permitido")
    valid_terms = Column(ARRAY(Integer), nullable=True, comment="Plazos válidos en quincenas")
    
    # Audit fields
    created_at = Column(
        DateTime(timezone=True), 
        server_default=func.current_timestamp(), 
        nullable=True
    )
    updated_at = Column(
        DateTime(timezone=True), 
        server_default=func.current_timestamp(), 
        nullable=True
    )
    created_by = Column(Integer, ForeignKey('users.id'), nullable=True)
    updated_by = Column(Integer, ForeignKey('users.id'), nullable=True)

