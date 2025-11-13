"""
Servicio de perfiles de tasa.

Integra con funciones SQL:
- calculate_loan_payment(amount, term, profile_code)
- generate_loan_summary(amount, term, interest_rate, commission_rate)
"""
from decimal import Decimal
from typing import List

from sqlalchemy import text
from sqlalchemy.orm import Session

from ..domain import RateProfile, LoanCalculation


class RateProfileService:
    """Servicio para gestión de perfiles de tasa."""
    
    def __init__(self, db: Session):
        self.db = db
    
    def list_profiles(self, enabled_only: bool = True) -> List[RateProfile]:
        """
        Lista todos los perfiles de tasa.
        
        Args:
            enabled_only: Si True, solo retorna perfiles habilitados
            
        Returns:
            Lista de RateProfile ordenados por display_order
        """
        query = text("""
            SELECT 
                id, code, name, description, calculation_type,
                interest_rate_percent, commission_rate_percent,
                enabled, is_recommended, display_order,
                min_amount, max_amount, valid_terms,
                created_at, updated_at, created_by, updated_by
            FROM rate_profiles
            WHERE (:enabled_only = false OR enabled = true)
            ORDER BY display_order
        """)
        
        result = self.db.execute(query, {"enabled_only": enabled_only})
        rows = result.fetchall()
        
        return [
            RateProfile(
                id=row.id,
                code=row.code,
                name=row.name,
                description=row.description,
                calculation_type=row.calculation_type,
                interest_rate_percent=row.interest_rate_percent,
                commission_rate_percent=row.commission_rate_percent,
                enabled=row.enabled,
                is_recommended=row.is_recommended,
                display_order=row.display_order,
                min_amount=row.min_amount,
                max_amount=row.max_amount,
                valid_terms=row.valid_terms,
                created_at=row.created_at,
                updated_at=row.updated_at,
                created_by=row.created_by,
                updated_by=row.updated_by
            )
            for row in rows
        ]
    
    def get_profile(self, profile_code: str) -> RateProfile:
        """
        Obtiene un perfil por su código.
        
        Args:
            profile_code: Código del perfil (legacy, standard, etc.)
            
        Returns:
            RateProfile
            
        Raises:
            ValueError: Si el perfil no existe o está deshabilitado
        """
        query = text("""
            SELECT 
                id, code, name, description, calculation_type,
                interest_rate_percent, commission_rate_percent,
                enabled, is_recommended, display_order,
                min_amount, max_amount, valid_terms,
                created_at, updated_at, created_by, updated_by
            FROM rate_profiles
            WHERE code = :profile_code
        """)
        
        result = self.db.execute(query, {"profile_code": profile_code})
        row = result.fetchone()
        
        if not row:
            raise ValueError(f"Perfil de tasa '{profile_code}' no encontrado")
        
        if not row.enabled:
            raise ValueError(f"Perfil de tasa '{profile_code}' está deshabilitado")
        
        return RateProfile(
            id=row.id,
            code=row.code,
            name=row.name,
            description=row.description,
            calculation_type=row.calculation_type,
            interest_rate_percent=row.interest_rate_percent,
            commission_rate_percent=row.commission_rate_percent,
            enabled=row.enabled,
            is_recommended=row.is_recommended,
            display_order=row.display_order,
            min_amount=row.min_amount,
            max_amount=row.max_amount,
            valid_terms=row.valid_terms,
            created_at=row.created_at,
            updated_at=row.updated_at,
            created_by=row.created_by,
            updated_by=row.updated_by
        )
    
    def calculate_loan(
        self, 
        amount: Decimal, 
        term_biweeks: int, 
        profile_code: str
    ) -> LoanCalculation:
        """
        Calcula un préstamo usando un perfil de tasa.
        
        Llama a la función SQL: calculate_loan_payment(amount, term, profile)
        
        Args:
            amount: Monto del préstamo
            term_biweeks: Plazo en quincenas
            profile_code: Código del perfil
            
        Returns:
            LoanCalculation con todos los cálculos
            
        Raises:
            ValueError: Si el perfil no existe o cálculo falla
        """
        query = text("""
            SELECT * FROM calculate_loan_payment(:amount, :term_biweeks, :profile_code)
        """)
        
        result = self.db.execute(
            query,
            {"amount": amount, "term_biweeks": term_biweeks, "profile_code": profile_code}
        )
        
        row = result.fetchone()
        
        if not row:
            raise ValueError(f"No se pudo calcular préstamo con perfil '{profile_code}'")
        
        return LoanCalculation(
            profile_code=row.profile_code,
            profile_name=row.profile_name,
            calculation_method=row.calculation_method,
            amount=amount,
            term_biweeks=term_biweeks,
            interest_rate_percent=row.interest_rate_percent,
            commission_rate_percent=row.commission_rate_percent,
            biweekly_payment=row.biweekly_payment,
            total_payment=row.total_payment,
            total_interest=row.total_interest,
            effective_rate_percent=row.effective_rate_percent,
            commission_per_payment=row.commission_per_payment,
            total_commission=row.total_commission,
            associate_payment=row.associate_payment,
            associate_total=row.associate_total
        )
    
    def compare_profiles(
        self,
        amount: Decimal,
        term_biweeks: int,
        profile_codes: List[str]
    ) -> List[LoanCalculation]:
        """
        Compara múltiples perfiles para el mismo préstamo.
        
        Args:
            amount: Monto del préstamo
            term_biweeks: Plazo en quincenas
            profile_codes: Lista de códigos de perfiles a comparar
            
        Returns:
            Lista de LoanCalculation (uno por perfil)
        """
        results = []
        
        for profile_code in profile_codes:
            try:
                calc = self.calculate_loan(amount, term_biweeks, profile_code)
                results.append(calc)
            except ValueError as e:
                # Omitir perfiles que fallen (ej: monto no en tabla legacy)
                continue
        
        return results


__all__ = ['RateProfileService']
