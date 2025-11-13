"""
Endpoints REST para perfiles de tasa.

Rutas:
- GET /rate-profiles → Listar perfiles
- GET /rate-profiles/{code} → Detalle perfil
- POST /rate-profiles/calculate → Calcular préstamo
- POST /rate-profiles/compare → Comparar perfiles
"""
from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from .application import (
    RateProfileDTO,
    LegacyAmountDTO,
    CalculateLoanRequest,
    LoanCalculationDTO,
    CompareProfilesRequest,
    CompareProfilesResponse
)
from .application.services import RateProfileService


router = APIRouter()


def get_rate_profile_service(db: Session = Depends(get_db)) -> RateProfileService:
    """Dependency para obtener servicio de perfiles."""
    return RateProfileService(db)


@router.get("/rate-profiles", response_model=List[RateProfileDTO])
def list_rate_profiles(
    enabled_only: bool = True,
    service: RateProfileService = Depends(get_rate_profile_service)
):
    """
    Lista todos los perfiles de tasa disponibles.
    
    Args:
        enabled_only: Si True, solo retorna perfiles habilitados (default: True)
        
    Returns:
        Lista de perfiles ordenados por display_order
    """
    profiles = service.list_profiles(enabled_only=enabled_only)
    
    return [
        RateProfileDTO(
            id=profile.id,
            code=profile.code,
            name=profile.name,
            description=profile.description,
            calculation_type=profile.calculation_type,
            interest_rate_percent=profile.interest_rate_percent,
            commission_rate_percent=profile.commission_rate_percent,
            enabled=profile.enabled,
            is_recommended=profile.is_recommended,
            display_order=profile.display_order,
            valid_terms=profile.valid_terms,
            min_amount=profile.min_amount,
            max_amount=profile.max_amount,
        )
        for profile in profiles
    ]


@router.get("/rate-profiles/{profile_code}", response_model=RateProfileDTO)
def get_rate_profile(
    profile_code: str,
    service: RateProfileService = Depends(get_rate_profile_service)
):
    """
    Obtiene detalles de un perfil específico.
    
    Args:
        profile_code: Código del perfil (legacy, standard, premium, etc.)
        
    Returns:
        Detalles completos del perfil
        
    Raises:
        404: Si el perfil no existe o está deshabilitado
    """
    try:
        profile = service.get_profile(profile_code)
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(e)
        )
    
    return RateProfileDTO(
        id=profile.id,
        code=profile.code,
        name=profile.name,
        description=profile.description,
        calculation_type=profile.calculation_type,
        interest_rate_percent=profile.interest_rate_percent,
        commission_rate_percent=profile.commission_rate_percent,
        is_recommended=profile.is_recommended,
        enabled=profile.enabled,
        display_order=profile.display_order,
        min_amount=profile.min_amount,
        max_amount=profile.max_amount,
        valid_terms=profile.valid_terms
    )


@router.post("/rate-profiles/calculate", response_model=LoanCalculationDTO)
def calculate_loan_payment(
    request: CalculateLoanRequest,
    service: RateProfileService = Depends(get_rate_profile_service)
):
    """
    Calcula un préstamo usando un perfil específico.
    
    Usa la función SQL calculate_loan_payment() para calcular:
    - Pago quincenal (cliente)
    - Pago total e intereses
    - Comisión por pago y total
    - Pago al asociado (quincenal y total)
    
    Args:
        request: Datos del préstamo (monto, plazo, código perfil)
        
    Returns:
        Cálculo completo con 14 campos
        
    Raises:
        400: Si el perfil no aplica (monto/plazo fuera de rango)
        404: Si el perfil no existe
    """
    try:
        calculation = service.calculate_loan(
            amount=request.amount,
            term_biweeks=request.term_biweeks,
            profile_code=request.profile_code
        )
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )
    
    return LoanCalculationDTO(
        profile_code=calculation.profile_code,
        profile_name=calculation.profile_name,
        calculation_method=calculation.calculation_method,
        amount=calculation.amount,
        term_biweeks=calculation.term_biweeks,
        interest_rate_percent=calculation.interest_rate_percent,
        commission_rate_percent=calculation.commission_rate_percent,
        biweekly_payment=calculation.biweekly_payment,
        total_payment=calculation.total_payment,
        total_interest=calculation.total_interest,
        effective_rate_percent=calculation.effective_rate_percent,
        commission_per_payment=calculation.commission_per_payment,
        total_commission=calculation.total_commission,
        associate_payment=calculation.associate_payment,
        associate_total=calculation.associate_total
    )


@router.post("/rate-profiles/compare", response_model=CompareProfilesResponse)
def compare_rate_profiles(
    request: CompareProfilesRequest,
    service: RateProfileService = Depends(get_rate_profile_service)
):
    """
    Compara múltiples perfiles para el mismo préstamo.
    
    Útil para mostrar al usuario opciones y ayudar a decidir.
    
    Args:
        request: Datos del préstamo + lista de códigos de perfiles
        
    Returns:
        Lista de cálculos (uno por perfil que aplique)
        
    Example:
        ```json
        {
          "amount": 22000,
          "term_biweeks": 12,
          "profile_codes": ["transition", "standard", "premium"]
        }
        ```
        
        Response:
        ```json
        {
          "calculations": [
            {
              "profile_code": "transition",
              "profile_name": "Transición 3.75%",
              "biweekly_payment": 2701.04,
              "total_payment": 32412.48,
              "total_commission": 810.26,
              ...
            },
            {
              "profile_code": "standard",
              "profile_name": "Estándar 4.25% - Recomendado",
              "biweekly_payment": 2768.33,
              "total_payment": 33220.00,
              "total_commission": 830.52,
              ...
            },
            ...
          ]
        }
        ```
    """
    calculations = service.compare_profiles(
        amount=request.amount,
        term_biweeks=request.term_biweeks,
        profile_codes=request.profile_codes
    )
    
    return CompareProfilesResponse(
        amount=request.amount,
        term_biweeks=request.term_biweeks,
        calculations=[
            LoanCalculationDTO(
                profile_code=calc.profile_code,
                profile_name=calc.profile_name,
                calculation_method=calc.calculation_method,
                amount=calc.amount,
                term_biweeks=calc.term_biweeks,
                interest_rate_percent=calc.interest_rate_percent,
                commission_rate_percent=calc.commission_rate_percent,
                biweekly_payment=calc.biweekly_payment,
                total_payment=calc.total_payment,
                total_interest=calc.total_interest,
                effective_rate_percent=calc.effective_rate_percent,
                commission_per_payment=calc.commission_per_payment,
                total_commission=calc.total_commission,
                associate_payment=calc.associate_payment,
                associate_total=calc.associate_total
            )
            for calc in calculations
        ]
    )


@router.get("/legacy-payments", response_model=List[LegacyAmountDTO])
def list_legacy_amounts(
    service: RateProfileService = Depends(get_rate_profile_service)
):
    """
    Lista todos los montos disponibles en la tabla legacy_payment_table.
    
    Estos son los montos predefinidos que se pueden usar con el perfil legacy.
    Todos los montos legacy son para 12 quincenas.
    
    Returns:
        Lista de montos disponibles ordenados por amount
        
    Example:
        ```json
        [
          {
            "amount": 3000.00,
            "biweekly_payment": 316.67,
            "total_payment": 3800.00,
            "total_interest": 800.00,
            "effective_rate_percent": 26.67
          },
          ...
        ]
        ```
    """
    from sqlalchemy import text
    
    query = text("""
        SELECT 
            amount,
            biweekly_payment,
            total_payment,
            total_interest,
            effective_rate_percent
        FROM legacy_payment_table
        ORDER BY amount
    """)
    
    result = service.db.execute(query)
    rows = result.fetchall()
    
    return [
        LegacyAmountDTO(
            amount=row.amount,
            biweekly_payment=row.biweekly_payment,
            total_payment=row.total_payment,
            total_interest=row.total_interest,
            effective_rate_percent=row.effective_rate_percent
        )
        for row in rows
    ]


__all__ = ['router']
