"""
Test de integración CRÍTICO: Verificar función DB calculate_first_payment_date()

Este test valida que el sistema de doble calendario funciona correctamente.
Es el test más importante del módulo loans.

⭐ PREOCUPACIÓN DEL USUARIO: "necesitamos certeza en las fechas, no debe haber ningún error"
"""
import pytest
from datetime import date, datetime
from decimal import Decimal

from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.loans.infrastructure.repositories import PostgreSQLLoanRepository


# =============================================================================
# FIXTURES
# =============================================================================

@pytest.fixture
async def loan_repo(async_session: AsyncSession):
    """Fixture para obtener instancia del repositorio."""
    return PostgreSQLLoanRepository(async_session)


# =============================================================================
# TEST: calculate_first_payment_date() - SISTEMA DE DOBLE CALENDARIO
# =============================================================================

class TestCalculateFirstPaymentDate:
    """
    Tests para la función DB calculate_first_payment_date().
    
    ⭐ CRÍTICO: Validar sistema de doble calendario
    
    Reglas:
    1. Aprobación días 1-7 → Primer pago día 15 mismo mes
    2. Aprobación días 8-22 → Primer pago último día mismo mes
    3. Aprobación días 23-31 → Primer pago día 15 siguiente mes
    """
    
    @pytest.mark.asyncio
    async def test_approval_day_1_to_7_payment_day_15_same_month(self, loan_repo):
        """
        Test: Aprobación días 1-7 → Primer pago día 15 mismo mes
        
        Ejemplos:
        - 2024-01-05 → 2024-01-15
        - 2024-02-01 → 2024-02-15
        - 2024-03-07 → 2024-03-15
        """
        test_cases = [
            (date(2024, 1, 1), date(2024, 1, 15)),   # Día 1
            (date(2024, 1, 3), date(2024, 1, 15)),   # Día 3
            (date(2024, 1, 5), date(2024, 1, 15)),   # Día 5
            (date(2024, 1, 7), date(2024, 1, 15)),   # Día 7
            (date(2024, 2, 1), date(2024, 2, 15)),   # Febrero
            (date(2024, 3, 7), date(2024, 3, 15)),   # Marzo
            (date(2024, 12, 5), date(2024, 12, 15)), # Diciembre
        ]
        
        for approval_date, expected_payment_date in test_cases:
            result = await loan_repo.calculate_first_payment_date(approval_date)
            assert result == expected_payment_date, (
                f"Fallo para approval_date={approval_date}: "
                f"esperado {expected_payment_date}, obtenido {result}"
            )
    
    @pytest.mark.asyncio
    async def test_approval_day_8_to_22_payment_last_day_same_month(self, loan_repo):
        """
        Test: Aprobación días 8-22 → Primer pago último día mismo mes
        
        Ejemplos:
        - 2024-01-08 → 2024-01-31
        - 2024-01-15 → 2024-01-31
        - 2024-01-22 → 2024-01-31
        - 2024-02-10 → 2024-02-29 (año bisiesto)
        - 2023-02-10 → 2023-02-28 (año no bisiesto)
        """
        test_cases = [
            (date(2024, 1, 8), date(2024, 1, 31)),   # Día 8
            (date(2024, 1, 10), date(2024, 1, 31)),  # Día 10
            (date(2024, 1, 15), date(2024, 1, 31)),  # Día 15
            (date(2024, 1, 20), date(2024, 1, 31)),  # Día 20
            (date(2024, 1, 22), date(2024, 1, 31)),  # Día 22
            (date(2024, 2, 10), date(2024, 2, 29)),  # Febrero bisiesto
            (date(2023, 2, 10), date(2023, 2, 28)),  # Febrero no bisiesto
            (date(2024, 4, 15), date(2024, 4, 30)),  # Abril (30 días)
            (date(2024, 12, 20), date(2024, 12, 31)), # Diciembre
        ]
        
        for approval_date, expected_payment_date in test_cases:
            result = await loan_repo.calculate_first_payment_date(approval_date)
            assert result == expected_payment_date, (
                f"Fallo para approval_date={approval_date}: "
                f"esperado {expected_payment_date}, obtenido {result}"
            )
    
    @pytest.mark.asyncio
    async def test_approval_day_23_to_31_payment_day_15_next_month(self, loan_repo):
        """
        Test: Aprobación días 23-31 → Primer pago día 15 siguiente mes
        
        Ejemplos:
        - 2024-01-23 → 2024-02-15
        - 2024-01-25 → 2024-02-15
        - 2024-01-31 → 2024-02-15
        - 2024-12-25 → 2025-01-15 (cambio de año)
        """
        test_cases = [
            (date(2024, 1, 23), date(2024, 2, 15)),   # Día 23
            (date(2024, 1, 25), date(2024, 2, 15)),   # Día 25
            (date(2024, 1, 28), date(2024, 2, 15)),   # Día 28
            (date(2024, 1, 31), date(2024, 2, 15)),   # Día 31
            (date(2024, 2, 25), date(2024, 3, 15)),   # Febrero
            (date(2024, 4, 30), date(2024, 5, 15)),   # Abril (30 días)
            (date(2024, 12, 25), date(2025, 1, 15)),  # Diciembre → Enero (cambio año)
        ]
        
        for approval_date, expected_payment_date in test_cases:
            result = await loan_repo.calculate_first_payment_date(approval_date)
            assert result == expected_payment_date, (
                f"Fallo para approval_date={approval_date}: "
                f"esperado {expected_payment_date}, obtenido {result}"
            )
    
    @pytest.mark.asyncio
    async def test_edge_case_february_leap_year(self, loan_repo):
        """
        Test: Caso especial - Febrero bisiesto vs no bisiesto
        
        Validar que:
        - 2024-02-10 → 2024-02-29 (bisiesto)
        - 2023-02-10 → 2023-02-28 (no bisiesto)
        """
        # Año bisiesto (2024)
        approval_leap = date(2024, 2, 10)
        expected_leap = date(2024, 2, 29)
        result_leap = await loan_repo.calculate_first_payment_date(approval_leap)
        assert result_leap == expected_leap
        
        # Año no bisiesto (2023)
        approval_regular = date(2023, 2, 10)
        expected_regular = date(2023, 2, 28)
        result_regular = await loan_repo.calculate_first_payment_date(approval_regular)
        assert result_regular == expected_regular
    
    @pytest.mark.asyncio
    async def test_edge_case_december_to_january(self, loan_repo):
        """
        Test: Caso especial - Cambio de año (Diciembre → Enero)
        
        Validar que:
        - 2024-12-25 → 2025-01-15
        - 2024-12-31 → 2025-01-15
        """
        test_cases = [
            (date(2024, 12, 23), date(2025, 1, 15)),
            (date(2024, 12, 25), date(2025, 1, 15)),
            (date(2024, 12, 31), date(2025, 1, 15)),
        ]
        
        for approval_date, expected_payment_date in test_cases:
            result = await loan_repo.calculate_first_payment_date(approval_date)
            assert result == expected_payment_date, (
                f"Fallo para approval_date={approval_date}: "
                f"esperado {expected_payment_date}, obtenido {result}"
            )
    
    @pytest.mark.asyncio
    async def test_comprehensive_year_2024(self, loan_repo):
        """
        Test exhaustivo: Todo el año 2024
        
        Validar al menos un caso por mes para cada ventana.
        """
        test_cases = [
            # Enero
            (date(2024, 1, 5), date(2024, 1, 15)),
            (date(2024, 1, 10), date(2024, 1, 31)),
            (date(2024, 1, 25), date(2024, 2, 15)),
            
            # Febrero (bisiesto)
            (date(2024, 2, 5), date(2024, 2, 15)),
            (date(2024, 2, 10), date(2024, 2, 29)),
            (date(2024, 2, 25), date(2024, 3, 15)),
            
            # Marzo
            (date(2024, 3, 5), date(2024, 3, 15)),
            (date(2024, 3, 10), date(2024, 3, 31)),
            (date(2024, 3, 25), date(2024, 4, 15)),
            
            # Abril (30 días)
            (date(2024, 4, 5), date(2024, 4, 15)),
            (date(2024, 4, 10), date(2024, 4, 30)),
            (date(2024, 4, 25), date(2024, 5, 15)),
            
            # Mayo
            (date(2024, 5, 5), date(2024, 5, 15)),
            (date(2024, 5, 10), date(2024, 5, 31)),
            (date(2024, 5, 25), date(2024, 6, 15)),
            
            # Junio (30 días)
            (date(2024, 6, 5), date(2024, 6, 15)),
            (date(2024, 6, 10), date(2024, 6, 30)),
            (date(2024, 6, 25), date(2024, 7, 15)),
            
            # Julio
            (date(2024, 7, 5), date(2024, 7, 15)),
            (date(2024, 7, 10), date(2024, 7, 31)),
            (date(2024, 7, 25), date(2024, 8, 15)),
            
            # Agosto
            (date(2024, 8, 5), date(2024, 8, 15)),
            (date(2024, 8, 10), date(2024, 8, 31)),
            (date(2024, 8, 25), date(2024, 9, 15)),
            
            # Septiembre (30 días)
            (date(2024, 9, 5), date(2024, 9, 15)),
            (date(2024, 9, 10), date(2024, 9, 30)),
            (date(2024, 9, 25), date(2024, 10, 15)),
            
            # Octubre
            (date(2024, 10, 5), date(2024, 10, 15)),
            (date(2024, 10, 10), date(2024, 10, 31)),
            (date(2024, 10, 25), date(2024, 11, 15)),
            
            # Noviembre (30 días)
            (date(2024, 11, 5), date(2024, 11, 15)),
            (date(2024, 11, 10), date(2024, 11, 30)),
            (date(2024, 11, 25), date(2024, 12, 15)),
            
            # Diciembre
            (date(2024, 12, 5), date(2024, 12, 15)),
            (date(2024, 12, 10), date(2024, 12, 31)),
            (date(2024, 12, 25), date(2025, 1, 15)),
        ]
        
        for approval_date, expected_payment_date in test_cases:
            result = await loan_repo.calculate_first_payment_date(approval_date)
            assert result == expected_payment_date, (
                f"Fallo para approval_date={approval_date}: "
                f"esperado {expected_payment_date}, obtenido {result}"
            )


# =============================================================================
# RESUMEN
# =============================================================================

"""
COBERTURA DE TESTS:
- ✅ Ventana 1 (días 1-7): 7 casos
- ✅ Ventana 2 (días 8-22): 9 casos
- ✅ Ventana 3 (días 23-31): 7 casos
- ✅ Febrero bisiesto vs no bisiesto: 2 casos
- ✅ Cambio de año (Dic → Ene): 3 casos
- ✅ Cobertura completa año 2024: 36 casos (3 por mes)

TOTAL: 64 casos de prueba

⭐ OBJETIVO: Garantizar certeza absoluta en las fechas (preocupación del usuario)
"""
