"""
Módulo: Simulador de Préstamos
Proporciona endpoints para simular préstamos y generar tablas de amortización.
"""
from datetime import date
from decimal import Decimal
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text

from app.core.database import get_async_db

router = APIRouter(prefix="/simulator", tags=["Loan Simulator"])


# =============================================================================
# DTOs
# =============================================================================

class SimulatorRequest(BaseModel):
    """Request para simular un préstamo"""
    amount: Decimal = Field(..., description="Monto del préstamo", gt=0)
    term_biweeks: int = Field(..., description="Plazo en quincenas", gt=0, le=52)
    profile_code: str = Field(..., description="Código del perfil de tasa")
    approval_date: Optional[date] = Field(default=None, description="Fecha de aprobación (default: hoy)")


class AmortizationRowDTO(BaseModel):
    """Fila de la tabla de amortización"""
    payment_number: int
    payment_date: date
    cut_period: str = Field(..., description="Código del período de corte (ej: 2025-Q22)")
    client_payment: Decimal = Field(..., description="Pago del cliente")
    associate_payment: Decimal = Field(..., description="Pago del asociado")
    commission: Decimal = Field(..., description="Comisión de este pago")
    remaining_balance: Decimal = Field(..., description="Saldo restante")


class ClientTotalsDTO(BaseModel):
    """Totales del cliente"""
    biweekly_payment: Decimal
    total_payment: Decimal
    total_interest: Decimal


class AssociateTotalsDTO(BaseModel):
    """Totales del asociado"""
    biweekly_payment: Decimal
    total_payment: Decimal
    total_commission: Decimal


class LoanSummaryDTO(BaseModel):
    """Resumen del préstamo simulado"""
    profile_code: str
    profile_name: str
    loan_amount: Decimal
    term_biweeks: int
    term_months: float
    interest_rate_percent: Decimal
    commission_rate_percent: Decimal
    approval_date: date
    final_payment_date: date
    client_totals: ClientTotalsDTO
    associate_totals: AssociateTotalsDTO


class SimulatorResponseDTO(BaseModel):
    """Respuesta completa del simulador"""
    summary: LoanSummaryDTO
    amortization_table: List[AmortizationRowDTO]


# =============================================================================
# ENDPOINTS
# =============================================================================

@router.post(
    "/simulate",
    response_model=SimulatorResponseDTO,
    summary="Simular Préstamo",
    description="""
    Simula un préstamo completo con:
    - Resumen con totales del cliente, asociado y comisiones
    - Tabla de amortización completa con fechas y períodos de corte
    - Integración con doble calendario (cut_periods)
    
    **Ejemplo:**
    ```json
    {
        "amount": 10000,
        "term_biweeks": 12,
        "profile_code": "standard",
        "approval_date": "2025-11-15"
    }
    ```
    """,
)
async def simulate_loan(
    request: SimulatorRequest,
    session: AsyncSession = Depends(get_async_db),
):
    """
    Simula un préstamo y genera tabla de amortización completa.
    """
    try:
        approval_date = request.approval_date or date.today()
        
        # Llamar directamente a la función SQL con bind parameters
        calc_result = await session.execute(
            text("SELECT * FROM calculate_loan_payment(:amount, :term, :profile)"),
            {"amount": float(request.amount), "term": request.term_biweeks, "profile": request.profile_code}
        )
        calc_row = calc_result.fetchone()
        
        if not calc_row:
            raise HTTPException(
                status_code=404,
                detail=f"Perfil '{request.profile_code}' no encontrado"
            )
        
        # Obtener info del perfil
        profile_result = await session.execute(
            text("SELECT code, name FROM rate_profiles WHERE code = :code"),
            {"code": request.profile_code}
        )
        profile_row = profile_result.fetchone()
        
        if not profile_row:
            raise HTTPException(
                status_code=404,
                detail=f"Perfil '{request.profile_code}' no encontrado"
            )
        
        # Obtener tabla de amortización
        amort_result = await session.execute(
            text("SELECT * FROM simulate_loan(:amount, :term, :profile, :date)"),
            {
                "amount": float(request.amount),
                "term": request.term_biweeks,
                "profile": request.profile_code,
                "date": approval_date
            }
        )
        amort_rows = amort_result.fetchall()
        
        # Calcular fecha final (último pago)
        final_payment_date = amort_rows[-1][1] if amort_rows else approval_date
        
        # Construir respuesta
        summary = LoanSummaryDTO(
            profile_code=profile_row[0],
            profile_name=profile_row[1],
            loan_amount=Decimal(str(request.amount)),
            term_biweeks=request.term_biweeks,
            term_months=request.term_biweeks / 2,
            interest_rate_percent=Decimal(str(calc_row[3])),  # columna 4
            commission_rate_percent=Decimal(str(calc_row[4])),  # columna 5
            approval_date=approval_date,
            final_payment_date=final_payment_date,
            client_totals=ClientTotalsDTO(
                biweekly_payment=Decimal(str(calc_row[5])),  # columna 6
                total_payment=Decimal(str(calc_row[6])),  # columna 7
                total_interest=Decimal(str(calc_row[7]))  # columna 8
            ),
            associate_totals=AssociateTotalsDTO(
                biweekly_payment=Decimal(str(calc_row[11])),  # columna 12 (associate_payment)
                total_payment=Decimal(str(calc_row[12])),  # columna 13 (associate_total)
                total_commission=Decimal(str(calc_row[10]))  # columna 11
            )
        )
        
        amortization_table = [
            AmortizationRowDTO(
                payment_number=row[0],
                payment_date=row[1],
                cut_period=row[2],
                client_payment=Decimal(str(row[3])),
                associate_payment=Decimal(str(row[4])),
                commission=Decimal(str(row[5])),
                remaining_balance=Decimal(str(row[6]))
            )
            for row in amort_rows
        ]
        
        return SimulatorResponseDTO(
            summary=summary,
            amortization_table=amortization_table,
        )
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Error al simular préstamo: {str(e)}",
        )


@router.get(
    "/quick",
    summary="Simulación Rápida",
    description="Simulación rápida sin tabla de amortización, solo totales",
)
async def quick_simulation(
    amount: Decimal = Query(..., description="Monto del préstamo", gt=0),
    term_biweeks: int = Query(..., description="Plazo en quincenas", gt=0, le=52),
    profile_code: str = Query(..., description="Código del perfil"),
    session: AsyncSession = Depends(get_async_db),
):
    """
    Simulación rápida que devuelve solo los totales sin generar tabla de amortización.
    """
    try:
        query = text("""
            SELECT 
                profile_name,
                biweekly_payment as pago_quincenal_cliente,
                total_payment as total_cliente,
                associate_payment as pago_quincenal_asociado,
                associate_total as total_asociado,
                commission_per_payment as comision_por_pago,
                total_commission as comision_total
            FROM calculate_loan_payment(:amount, :term, :profile_code)
        """)
        
        result = await session.execute(
            query,
            {"amount": amount, "term": term_biweeks, "profile_code": profile_code},
        )
        row = result.fetchone()
        
        if not row:
            raise HTTPException(
                status_code=404,
                detail=f"Perfil '{profile_code}' no encontrado",
            )
        
        return {
            "perfil": row[0],
            "monto": float(amount),
            "plazo_quincenas": term_biweeks,
            "cliente": {
                "pago_quincenal": float(row[1]),
                "total": float(row[2]),
            },
            "asociado": {
                "pago_quincenal": float(row[3]),
                "total": float(row[4]),
            },
            "comision": {
                "por_pago": float(row[5]),
                "total": float(row[6]),
            },
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Error en simulación: {str(e)}",
        )
