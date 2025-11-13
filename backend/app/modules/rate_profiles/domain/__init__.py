"""
Entidades del dominio de perfiles de tasa.
"""
from dataclasses import dataclass
from datetime import datetime
from decimal import Decimal
from typing import Optional


@dataclass
class RateProfile:
    """
    Entidad: Perfil de Tasa.
    
    Representa un perfil de tasa configurable con dos tasas independientes:
    - interest_rate_percent: Tasa que paga el CLIENTE
    - commission_rate_percent: Tasa que cobra la EMPRESA al ASOCIADO
    """
    id: Optional[int]
    code: str
    name: str
    description: Optional[str]
    calculation_type: str  # 'table_lookup' o 'formula'
    
    # LAS DOS TASAS
    interest_rate_percent: Optional[Decimal]    # Para cliente
    commission_rate_percent: Optional[Decimal]  # Para asociado
    
    # Configuración UI
    enabled: bool = True
    is_recommended: bool = False
    display_order: int = 0
    
    # Límites opcionales
    min_amount: Optional[Decimal] = None
    max_amount: Optional[Decimal] = None
    valid_terms: Optional[list[int]] = None
    
    # Auditoría
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
    created_by: Optional[int] = None
    updated_by: Optional[int] = None
    
    def __post_init__(self):
        """Validaciones de negocio."""
        if not self.code or self.code.strip() == "":
            raise ValueError("code es obligatorio")
        
        if self.calculation_type not in ('table_lookup', 'formula'):
            raise ValueError(f"calculation_type debe ser 'table_lookup' o 'formula', recibido: {self.calculation_type}")
        
        # Nota: Perfiles 'formula' pueden tener interest_rate NULL si dependen de tabla externa
        # (ej: legacy, custom que usan legacy_rate_table)
        
        # Validar rangos de tasas (solo si están definidas)
        if self.interest_rate_percent is not None:
            if not (0 <= self.interest_rate_percent <= 100):
                raise ValueError(f"interest_rate_percent debe estar entre 0 y 100, recibido: {self.interest_rate_percent}")
        
        if self.commission_rate_percent is not None:
            if not (0 <= self.commission_rate_percent <= 100):
                raise ValueError(f"commission_rate_percent debe estar entre 0 y 100, recibido: {self.commission_rate_percent}")
    
    def is_formula_based(self) -> bool:
        """Verifica si el perfil usa fórmula."""
        return self.calculation_type == 'formula'
    
    def is_legacy_based(self) -> bool:
        """Verifica si el perfil usa tabla legacy."""
        return self.calculation_type == 'table_lookup'


@dataclass(frozen=True)
class LoanCalculation:
    """
    Value Object: Resultado de cálculo de préstamo.
    
    Encapsula todos los cálculos para un préstamo dado un perfil.
    Inmutable para garantizar consistencia.
    """
    # Datos de entrada
    profile_code: str
    profile_name: str
    calculation_method: str
    amount: Decimal
    term_biweeks: int
    
    # LAS DOS TASAS
    interest_rate_percent: Decimal
    commission_rate_percent: Decimal
    
    # Cálculos CLIENTE
    biweekly_payment: Decimal
    total_payment: Decimal
    total_interest: Decimal
    effective_rate_percent: Decimal
    
    # Cálculos ASOCIADO
    commission_per_payment: Decimal
    total_commission: Decimal
    associate_payment: Decimal
    associate_total: Decimal


__all__ = [
    'RateProfile',
    'LoanCalculation',
]
