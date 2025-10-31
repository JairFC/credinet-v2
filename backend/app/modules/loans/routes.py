"""
Routes para el módulo de préstamos (loans).

Sprint 1: Endpoints de lectura (GET)
Sprint 2: Endpoints de escritura (POST approve/reject)
Sprint 3: Endpoints restantes
"""
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_async_db
from app.modules.loans.application.dtos import (
    LoanFilterDTO,
    LoanCreateDTO,
    LoanApproveDTO,
    LoanRejectDTO,
    LoanUpdateDTO,
    LoanCancelDTO,
    LoanSummaryDTO,
    LoanResponseDTO,
    LoanBalanceDTO,
    PaginatedLoansDTO,
)
from app.modules.loans.application.services import LoanService
from app.modules.loans.infrastructure.repositories import PostgreSQLLoanRepository
from app.modules.loans.application.logger import log_loan_deleted, log_validation_error


router = APIRouter(prefix="/loans", tags=["loans"])


# =============================================================================
# SPRINT 1: ENDPOINTS DE LECTURA (GET)
# =============================================================================

@router.get("", response_model=PaginatedLoansDTO)
async def list_loans(
    status_id: Optional[int] = Query(None, description="Filtrar por estado del préstamo"),
    user_id: Optional[int] = Query(None, description="Filtrar por ID del cliente"),
    associate_user_id: Optional[int] = Query(None, description="Filtrar por ID del asociado"),
    limit: int = Query(50, ge=1, le=100, description="Máximo de registros a retornar"),
    offset: int = Query(0, ge=0, description="Desplazamiento para paginación"),
    db: AsyncSession = Depends(get_async_db),
):
    """
    Lista préstamos con filtros opcionales y paginación.
    
    Parámetros de filtro:
    - status_id: Estado del préstamo (1=PENDING, 2=APPROVED, 3=ACTIVE, etc.)
    - user_id: ID del cliente
    - associate_user_id: ID del asociado
    - limit: Máximo de registros (1-100, default 50)
    - offset: Desplazamiento para paginación (default 0)
    
    Retorna:
    - items: Lista de préstamos resumidos
    - total: Total de registros que coinciden con filtros
    - limit: Límite aplicado
    - offset: Desplazamiento aplicado
    
    Ejemplos:
    - GET /loans → Todos los préstamos (max 50)
    - GET /loans?status_id=1 → Solo préstamos PENDING
    - GET /loans?user_id=5&limit=20 → Préstamos del cliente 5 (max 20)
    - GET /loans?offset=50&limit=50 → Página 2
    """
    repo = PostgreSQLLoanRepository(db)
    
    # Obtener préstamos con filtros
    loans = await repo.find_all(
        status_id=status_id,
        user_id=user_id,
        associate_user_id=associate_user_id,
        limit=limit,
        offset=offset
    )
    
    # Contar total
    total = await repo.count(
        status_id=status_id,
        user_id=user_id,
        associate_user_id=associate_user_id
    )
    
    # Convertir a DTOs
    items = [
        LoanSummaryDTO(
            id=loan.id,
            user_id=loan.user_id,
            amount=loan.amount,
            interest_rate=loan.interest_rate,
            term_biweeks=loan.term_biweeks,
            status_id=loan.status_id,
            created_at=loan.created_at,
            # TODO: Agregar nombres con joins en Sprint 2
            status_name=None,
            client_name=None,
        )
        for loan in loans
    ]
    
    return PaginatedLoansDTO(
        items=items,
        total=total,
        limit=limit,
        offset=offset
    )


@router.get("/{loan_id}", response_model=LoanResponseDTO)
async def get_loan_detail(
    loan_id: int,
    db: AsyncSession = Depends(get_async_db),
):
    """
    Obtiene el detalle completo de un préstamo por su ID.
    
    Parámetros:
    - loan_id: ID del préstamo
    
    Retorna:
    - Todos los campos del préstamo
    - Cálculos de negocio (total_to_pay, payment_amount)
    
    Errores:
    - 404: Préstamo no encontrado
    
    Ejemplos:
    - GET /loans/123 → Detalle del préstamo 123
    """
    repo = PostgreSQLLoanRepository(db)
    
    loan = await repo.find_by_id(loan_id)
    
    if not loan:
        raise HTTPException(
            status_code=404,
            detail=f"Préstamo con ID {loan_id} no encontrado"
        )
    
    # Convertir a DTO
    return LoanResponseDTO(
        id=loan.id,
        user_id=loan.user_id,
        associate_user_id=loan.associate_user_id,
        amount=loan.amount,
        interest_rate=loan.interest_rate,
        commission_rate=loan.commission_rate,
        term_biweeks=loan.term_biweeks,
        status_id=loan.status_id,
        contract_id=loan.contract_id,
        approved_at=loan.approved_at,
        approved_by=loan.approved_by,
        rejected_at=loan.rejected_at,
        rejected_by=loan.rejected_by,
        rejection_reason=loan.rejection_reason,
        notes=loan.notes,
        created_at=loan.created_at,
        updated_at=loan.updated_at,
        # TODO: Agregar nombres con joins en Sprint 2
        status_name=None,
        client_name=None,
        associate_name=None,
        approver_name=None,
        rejecter_name=None,
        # Cálculos de negocio
        total_to_pay=loan.calculate_total_to_pay(),
        payment_amount=loan.calculate_payment_amount(),
    )


@router.get("/{loan_id}/balance", response_model=LoanBalanceDTO)
async def get_loan_balance(
    loan_id: int,
    db: AsyncSession = Depends(get_async_db),
):
    """
    Obtiene el balance actual de un préstamo.
    
    ⭐ CRÍTICO: Usa la función DB calculate_loan_remaining_balance()
    
    Parámetros:
    - loan_id: ID del préstamo
    
    Retorna:
    - loan_id: ID del préstamo
    - total_amount: Monto total a pagar
    - total_paid: Monto total pagado
    - remaining_balance: Saldo pendiente
    - payment_count: Total de pagos programados
    - payments_completed: Pagos completados
    - is_paid_off: ¿Está totalmente pagado?
    - completion_percentage: Porcentaje de completación
    
    Errores:
    - 404: Préstamo no encontrado
    
    Ejemplos:
    - GET /loans/123/balance → Balance del préstamo 123
    """
    repo = PostgreSQLLoanRepository(db)
    
    balance = await repo.get_balance(loan_id)
    
    if not balance:
        raise HTTPException(
            status_code=404,
            detail=f"Préstamo con ID {loan_id} no encontrado"
        )
    
    # Convertir a DTO
    return LoanBalanceDTO.from_loan_balance(balance)


# =============================================================================
# SPRINT 2: ENDPOINTS DE ESCRITURA (POST approve/reject)
# =============================================================================

@router.post("", response_model=LoanResponseDTO, status_code=201)
async def create_loan(
    loan_data: LoanCreateDTO,
    db: AsyncSession = Depends(get_async_db),
):
    """
    Crea una nueva solicitud de préstamo.
    
    Validaciones iniciales:
    - El asociado tiene crédito disponible suficiente
    - El cliente no tiene otros préstamos PENDING
    - El cliente no es moroso
    
    Body:
    ```json
    {
        "user_id": 5,
        "associate_user_id": 10,
        "amount": 5000.00,
        "interest_rate": 2.50,
        "commission_rate": 0.50,
        "term_biweeks": 12,
        "notes": "Préstamo para negocio"
    }
    ```
    
    Retorna:
    - Préstamo creado con status PENDING
    
    Errores:
    - 400: Validación fallida (asociado sin crédito, cliente con PENDING, cliente moroso)
    
    Ejemplos:
    - POST /loans → Crear nueva solicitud
    """
    service = LoanService(db)
    
    try:
        loan = await service.create_loan_request(
            user_id=loan_data.user_id,
            associate_user_id=loan_data.associate_user_id,
            amount=loan_data.amount,
            interest_rate=loan_data.interest_rate,
            commission_rate=loan_data.commission_rate,
            term_biweeks=loan_data.term_biweeks,
            notes=loan_data.notes
        )
        
        # Commit de la transacción
        await db.commit()
        
        # Convertir a DTO
        return LoanResponseDTO(
            id=loan.id,
            user_id=loan.user_id,
            associate_user_id=loan.associate_user_id,
            amount=loan.amount,
            interest_rate=loan.interest_rate,
            commission_rate=loan.commission_rate,
            term_biweeks=loan.term_biweeks,
            status_id=loan.status_id,
            contract_id=loan.contract_id,
            approved_at=loan.approved_at,
            approved_by=loan.approved_by,
            rejected_at=loan.rejected_at,
            rejected_by=loan.rejected_by,
            rejection_reason=loan.rejection_reason,
            notes=loan.notes,
            created_at=loan.created_at,
            updated_at=loan.updated_at,
            # Campos calculados
            total_to_pay=loan.calculate_total_to_pay(),
            payment_amount=loan.calculate_payment_amount(),
        )
    
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=500, detail=f"Error interno: {str(e)}")


@router.post("/{loan_id}/approve", response_model=LoanResponseDTO)
async def approve_loan(
    loan_id: int,
    approve_data: LoanApproveDTO,
    db: AsyncSession = Depends(get_async_db),
):
    """
    Aprueba un préstamo.
    
    ⭐ CRÍTICO: Ejecuta las validaciones más importantes del sistema.
    
    Proceso:
    1. Validar que esté en estado PENDING
    2. Validar pre-aprobación (crédito, morosidad)
    3. Calcular fecha del primer pago (doble calendario)
    4. Actualizar préstamo a APPROVED
    5. Trigger genera cronograma de pagos automáticamente
    
    Body:
    ```json
    {
        "approved_by": 2,
        "notes": "Aprobado por cumplir todos los requisitos"
    }
    ```
    
    Retorna:
    - Préstamo aprobado
    
    Errores:
    - 404: Préstamo no encontrado
    - 400: Validación fallida (no PENDING, asociado sin crédito, cliente moroso)
    
    Ejemplos:
    - POST /loans/123/approve → Aprobar préstamo 123
    """
    service = LoanService(db)
    
    try:
        loan = await service.approve_loan(
            loan_id=loan_id,
            approved_by=approve_data.approved_by,
            notes=approve_data.notes
        )
        
        # El commit ya se hizo dentro de approve_loan() para incluir el trigger
        
        # Convertir a DTO
        return LoanResponseDTO(
            id=loan.id,
            user_id=loan.user_id,
            associate_user_id=loan.associate_user_id,
            amount=loan.amount,
            interest_rate=loan.interest_rate,
            commission_rate=loan.commission_rate,
            term_biweeks=loan.term_biweeks,
            status_id=loan.status_id,
            contract_id=loan.contract_id,
            approved_at=loan.approved_at,
            approved_by=loan.approved_by,
            rejected_at=loan.rejected_at,
            rejected_by=loan.rejected_by,
            rejection_reason=loan.rejection_reason,
            notes=loan.notes,
            created_at=loan.created_at,
            updated_at=loan.updated_at,
            # Campos calculados
            total_to_pay=loan.calculate_total_to_pay(),
            payment_amount=loan.calculate_payment_amount(),
        )
    
    except ValueError as e:
        await db.rollback()
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=500, detail=f"Error interno: {str(e)}")


@router.post("/{loan_id}/reject", response_model=LoanResponseDTO)
async def reject_loan(
    loan_id: int,
    reject_data: LoanRejectDTO,
    db: AsyncSession = Depends(get_async_db),
):
    """
    Rechaza un préstamo.
    
    Proceso:
    1. Validar que esté en estado PENDING
    2. Actualizar préstamo a REJECTED con razón obligatoria
    3. Liberar crédito del asociado (no se consumió)
    
    Body:
    ```json
    {
        "rejected_by": 2,
        "rejection_reason": "Documentación incompleta. Falta cédula actualizada."
    }
    ```
    
    Retorna:
    - Préstamo rechazado
    
    Errores:
    - 404: Préstamo no encontrado
    - 400: Validación fallida (no PENDING, razón vacía)
    
    Ejemplos:
    - POST /loans/123/reject → Rechazar préstamo 123
    """
    service = LoanService(db)
    
    try:
        loan = await service.reject_loan(
            loan_id=loan_id,
            rejected_by=reject_data.rejected_by,
            rejection_reason=reject_data.rejection_reason
        )
        
        # El commit ya se hizo dentro de reject_loan()
        
        # Convertir a DTO
        return LoanResponseDTO(
            id=loan.id,
            user_id=loan.user_id,
            associate_user_id=loan.associate_user_id,
            amount=loan.amount,
            interest_rate=loan.interest_rate,
            commission_rate=loan.commission_rate,
            term_biweeks=loan.term_biweeks,
            status_id=loan.status_id,
            contract_id=loan.contract_id,
            approved_at=loan.approved_at,
            approved_by=loan.approved_by,
            rejected_at=loan.rejected_at,
            rejected_by=loan.rejected_by,
            rejection_reason=loan.rejection_reason,
            notes=loan.notes,
            created_at=loan.created_at,
            updated_at=loan.updated_at,
            # Campos calculados
            total_to_pay=loan.calculate_total_to_pay(),
            payment_amount=loan.calculate_payment_amount(),
        )
    
    except ValueError as e:
        await db.rollback()
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=500, detail=f"Error interno: {str(e)}")


# =============================================================================
# SPRINT 3: ENDPOINTS RESTANTES
# =============================================================================

@router.put("/{loan_id}", response_model=LoanResponseDTO)
async def update_loan(
    loan_id: int,
    update_data: LoanUpdateDTO,
    db: AsyncSession = Depends(get_async_db),
):
    """
    Actualiza un préstamo que está en estado PENDING.
    
    Solo se pueden actualizar préstamos que aún no han sido procesados (PENDING).
    Los campos permitidos para actualizar son:
    - amount: Monto del préstamo
    - interest_rate: Tasa de interés
    - commission_rate: Tasa de comisión
    - term_biweeks: Plazo en quincenas
    - notes: Notas adicionales
    
    Proceso:
    1. Verificar que el préstamo existe
    2. Verificar que está en estado PENDING
    3. Si se actualiza el monto, verificar crédito del asociado
    4. Actualizar solo los campos proporcionados
    5. Guardar cambios
    
    Body Example:
    ```json
    {
        "amount": 6000.00,
        "interest_rate": 3.0,
        "notes": "Actualizado por solicitud del cliente"
    }
    ```
    
    Validaciones:
    - Préstamo existe
    - Préstamo está PENDING
    - Si se cambia el monto, verificar crédito del asociado
    
    Errores:
    - 404: Préstamo no encontrado
    - 400: Préstamo no está PENDING o validaciones fallan
    - 500: Error interno del servidor
    
    Returns:
        LoanResponseDTO: Préstamo actualizado
    """
    try:
        service = LoanService(db)
        
        loan = await service.update_loan(
            loan_id=loan_id,
            amount=update_data.amount,
            interest_rate=update_data.interest_rate,
            commission_rate=update_data.commission_rate,
            term_biweeks=update_data.term_biweeks,
            notes=update_data.notes
        )
        
        # El commit ya se hizo dentro de update_loan()
        
        # Convertir a DTO
        return LoanResponseDTO(
            id=loan.id,
            user_id=loan.user_id,
            associate_user_id=loan.associate_user_id,
            amount=loan.amount,
            interest_rate=loan.interest_rate,
            commission_rate=loan.commission_rate,
            term_biweeks=loan.term_biweeks,
            status_id=loan.status_id,
            contract_id=loan.contract_id,
            approved_at=loan.approved_at,
            approved_by=loan.approved_by,
            rejected_at=loan.rejected_at,
            rejected_by=loan.rejected_by,
            rejection_reason=loan.rejection_reason,
            notes=loan.notes,
            created_at=loan.created_at,
            updated_at=loan.updated_at,
            # Campos calculados
            total_to_pay=loan.calculate_total_to_pay(),
            payment_amount=loan.calculate_payment_amount(),
        )
    
    except ValueError as e:
        await db.rollback()
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=500, detail=f"Error interno: {str(e)}")


@router.delete("/{loan_id}", status_code=204)
async def delete_loan(
    loan_id: int,
    db: AsyncSession = Depends(get_async_db),
):
    """
    Elimina un préstamo que está en estado PENDING o REJECTED.
    
    Solo se pueden eliminar préstamos que:
    - Están en estado PENDING (no procesados aún)
    - Están en estado REJECTED (ya fueron rechazados)
    
    NO se pueden eliminar préstamos APPROVED, ACTIVE, PAID_OFF o CANCELLED
    (ya tienen historial de negocio).
    
    Proceso:
    1. Verificar que el préstamo existe
    2. Verificar que está en estado PENDING o REJECTED
    3. Eliminar el préstamo
    
    Validaciones:
    - Préstamo existe
    - Préstamo está PENDING o REJECTED
    
    Errores:
    - 404: Préstamo no encontrado
    - 400: Préstamo no puede ser eliminado (estado incorrecto)
    - 500: Error interno del servidor
    
    Returns:
        204 No Content: Préstamo eliminado exitosamente
    """
    try:
        service = LoanService(db)
        repository = PostgreSQLLoanRepository(db)
        
        # 1. Buscar préstamo
        loan = await service.get_loan_by_id(loan_id)
        if not loan:
            raise HTTPException(status_code=404, detail=f"Préstamo {loan_id} no encontrado")
        
        # 2. Validar estado (solo PENDING o REJECTED)
        if not (loan.is_pending() or loan.is_rejected()):
            raise HTTPException(
                status_code=400,
                detail=f"Solo se pueden eliminar préstamos en estado PENDING o REJECTED. "
                       f"El préstamo {loan_id} está en estado {loan.status_id}"
            )
        
        # 3. Eliminar
        deleted = await repository.delete(loan_id)
        if not deleted:
            raise HTTPException(status_code=404, detail=f"No se pudo eliminar el préstamo {loan_id}")
        
        await db.commit()
        
        # Log de auditoría
        log_loan_deleted(loan_id=loan_id, user_id=loan.user_id, status_id=loan.status_id)
        
        # 204 No Content (sin body en response)
        return None
    
    except HTTPException:
        await db.rollback()
        raise
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=500, detail=f"Error interno: {str(e)}")


@router.post("/{loan_id}/cancel", response_model=LoanResponseDTO)
async def cancel_loan(
    loan_id: int,
    cancel_data: LoanCancelDTO,
    db: AsyncSession = Depends(get_async_db),
):
    """
    Cancela un préstamo que está en estado ACTIVE.
    
    Al cancelar un préstamo ACTIVE:
    - El préstamo pasa a estado CANCELLED
    - Se libera el crédito del asociado (credit_used se reduce)
    - Se guarda la razón de la cancelación (obligatoria)
    - Los pagos ya realizados se mantienen como histórico
    
    Este endpoint se usa cuando:
    - El cliente decide cancelar el préstamo anticipadamente
    - Se detecta un problema y se debe cancelar el préstamo
    - Por decisión administrativa se cancela el préstamo
    
    Proceso:
    1. Verificar que el préstamo existe
    2. Verificar que está en estado ACTIVE
    3. Validar razón de cancelación obligatoria
    4. Actualizar a estado CANCELLED
    5. Trigger libera crédito del asociado automáticamente
    
    Body Example:
    ```json
    {
        "cancelled_by": 2,
        "cancellation_reason": "Cliente solicitó cancelación por liquidación anticipada"
    }
    ```
    
    Validaciones:
    - Préstamo existe
    - Préstamo está ACTIVE
    - Razón de cancelación obligatoria (mínimo 10 caracteres)
    
    Errores:
    - 404: Préstamo no encontrado
    - 400: Préstamo no está ACTIVE o razón inválida
    - 500: Error interno del servidor
    
    Returns:
        LoanResponseDTO: Préstamo cancelado
    """
    try:
        service = LoanService(db)
        
        loan = await service.cancel_loan(
            loan_id=loan_id,
            cancelled_by=cancel_data.cancelled_by,
            cancellation_reason=cancel_data.cancellation_reason
        )
        
        # El commit ya se hizo dentro de cancel_loan()
        
        # Convertir a DTO
        return LoanResponseDTO(
            id=loan.id,
            user_id=loan.user_id,
            associate_user_id=loan.associate_user_id,
            amount=loan.amount,
            interest_rate=loan.interest_rate,
            commission_rate=loan.commission_rate,
            term_biweeks=loan.term_biweeks,
            status_id=loan.status_id,
            contract_id=loan.contract_id,
            approved_at=loan.approved_at,
            approved_by=loan.approved_by,
            rejected_at=loan.rejected_at,
            rejected_by=loan.rejected_by,
            rejection_reason=loan.rejection_reason,
            notes=loan.notes,
            created_at=loan.created_at,
            updated_at=loan.updated_at,
            # Campos calculados
            total_to_pay=loan.calculate_total_to_pay(),
            payment_amount=loan.calculate_payment_amount(),
        )
    
    except ValueError as e:
        await db.rollback()
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=500, detail=f"Error interno: {str(e)}")


__all__ = ["router"]
