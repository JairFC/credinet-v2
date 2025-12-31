"""
Routes para el módulo de préstamos (loans).

Sprint 1: Endpoints de lectura (GET)
Sprint 2: Endpoints de escritura (POST approve/reject)
Sprint 3: Endpoints restantes
"""
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_async_db
from app.modules.auth.routes import get_current_user
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
    search: Optional[str] = Query(None, description="Buscar por ID, nombre de cliente o asociado"),
    limit: int = Query(50, ge=1, le=100, description="Máximo de registros a retornar"),
    offset: int = Query(0, ge=0, description="Desplazamiento para paginación"),
    db: AsyncSession = Depends(get_async_db),
):
    """
    Lista préstamos con filtros opcionales, búsqueda y paginación.
    
    Parámetros de filtro:
    - status_id: Estado del préstamo (1=PENDING, 2=APPROVED, 3=ACTIVE, etc.)
    - user_id: ID del cliente
    - associate_user_id: ID del asociado
    - search: Texto para buscar en ID, nombre de cliente o asociado
    - limit: Máximo de registros (1-100, default 50)
    - offset: Desplazamiento para paginación (default 0)
    
    Retorna:
    - items: Lista de préstamos resumidos CON nombres de cliente y asociado
    - total: Total de registros que coinciden con filtros
    - limit: Límite aplicado
    - offset: Desplazamiento aplicado
    
    Ejemplos:
    - GET /loans → Todos los préstamos (max 50)
    - GET /loans?status_id=1 → Solo préstamos PENDING
    - GET /loans?user_id=5&limit=20 → Préstamos del cliente 5 (max 20)
    - GET /loans?offset=50&limit=50 → Página 2
    """
    from sqlalchemy import select, and_, func as sql_func, case
    from sqlalchemy.orm import aliased
    from app.modules.loans.infrastructure.models import LoanModel
    from app.modules.auth.infrastructure.models import UserModel
    
    # Crear aliases para las tablas de usuarios
    ClientUser = aliased(UserModel)
    AssociateUser = aliased(UserModel)
    
    # Construir query con JOINs para obtener nombres
    query = select(
        LoanModel.id,
        LoanModel.user_id,
        LoanModel.associate_user_id,
        LoanModel.amount,
        LoanModel.interest_rate,
        LoanModel.term_biweeks,
        LoanModel.status_id,
        LoanModel.created_at,
        (ClientUser.first_name + ' ' + ClientUser.last_name).label('client_name'),
        case(
            (LoanModel.associate_user_id.isnot(None), AssociateUser.first_name + ' ' + AssociateUser.last_name),
            else_=None
        ).label('associate_name')
    ).select_from(LoanModel).join(
        ClientUser,
        LoanModel.user_id == ClientUser.id,
        isouter=False
    ).join(
        AssociateUser,
        LoanModel.associate_user_id == AssociateUser.id,
        isouter=True  # LEFT JOIN porque associate puede ser NULL
    )
    
    # Aplicar filtros dinámicos
    conditions = []
    if status_id is not None:
        conditions.append(LoanModel.status_id == status_id)
    if user_id is not None:
        conditions.append(LoanModel.user_id == user_id)
    if associate_user_id is not None:
        conditions.append(LoanModel.associate_user_id == associate_user_id)
    
    # Búsqueda por texto (ID, nombre cliente, nombre asociado)
    if search:
        from sqlalchemy import or_, cast, String
        search_term = f"%{search.lower()}%"
        search_conditions = or_(
            cast(LoanModel.id, String).ilike(search_term),
            (ClientUser.first_name + ' ' + ClientUser.last_name).ilike(search_term),
            (AssociateUser.first_name + ' ' + AssociateUser.last_name).ilike(search_term),
        )
        conditions.append(search_conditions)
    
    if conditions:
        query = query.where(and_(*conditions))
    
    # Ordenar por más reciente primero
    query = query.order_by(LoanModel.created_at.desc())
    
    # Contar total (con los mismos filtros incluyendo búsqueda)
    # Necesitamos recrear la query con JOINs para el conteo cuando hay búsqueda
    if search:
        count_query = select(sql_func.count()).select_from(LoanModel).join(
            ClientUser, LoanModel.user_id == ClientUser.id
        ).join(
            AssociateUser, LoanModel.associate_user_id == AssociateUser.id, isouter=True
        )
        if conditions:
            count_query = count_query.where(and_(*conditions))
    else:
        count_query = select(sql_func.count()).select_from(LoanModel)
        if conditions:
            count_query = count_query.where(and_(*conditions))
    
    count_result = await db.execute(count_query)
    total = count_result.scalar()
    
    # Paginación
    query = query.limit(limit).offset(offset)
    
    # Ejecutar
    result = await db.execute(query)
    rows = result.all()
    
    # Convertir a DTOs
    items = [
        LoanSummaryDTO(
            id=row.id,
            user_id=row.user_id,
            amount=row.amount,
            interest_rate=row.interest_rate,
            term_biweeks=row.term_biweeks,
            status_id=row.status_id,
            created_at=row.created_at,
            status_name=None,  # TODO: Agregar con JOIN a loan_statuses si es necesario
            client_name=row.client_name,
            associate_name=row.associate_name,
        )
        for row in rows
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
    db: AsyncSession = Depends(get_async_db)
    # TODO: Restaurar autenticación cuando se completen validaciones de roles
    # current_user=Depends(get_current_user)
):
    """
    Obtiene el detalle completo de un préstamo con datos relacionados.
    """
    from app.modules.loans.application.enhanced_service import LoanEnhancedService
    
    enhanced_service = LoanEnhancedService(db)
    loan_data = await enhanced_service.get_loan_with_details(loan_id)
    
    if not loan_data:
        raise HTTPException(status_code=404, detail="Préstamo no encontrado")
    
    # TODO: Restaurar validación de permisos cuando se complete autenticación
    # Verificar permisos:
    # - Admin: puede ver todos los préstamos
    # - Associate: puede ver préstamos asignados a él
    # - Regular user: puede ver solo sus propios préstamos
    #
    # is_admin = any(role.name == "admin" for role in current_user.roles)
    # is_associate = any(role.name == "associate" for role in current_user.roles)
    # 
    # if not is_admin:
    #     if is_associate:
    #         # Associate: solo préstamos asignados
    #         if loan_data["associate_user_id"] != current_user.id:
    #             raise HTTPException(
    #                 status_code=403, 
    #                 detail="No tiene permisos para ver este préstamo"
    #             )
    #     else:
    #         # Usuario regular: solo sus propios préstamos
    #         if loan_data["user_id"] != current_user.id:
    #             raise HTTPException(
    #                 status_code=403,
    #                 detail="No tiene permisos para ver este préstamo"
    #             )
    
    return LoanResponseDTO(**loan_data)


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


@router.get("/{loan_id}/amortization")
async def get_loan_amortization(
    loan_id: int,
    db: AsyncSession = Depends(get_async_db),
):
    """
    Obtiene la tabla de amortización de un préstamo.
    
    - Si el préstamo está APROBADO: devuelve los pagos reales de la tabla payments
    - Si está PENDIENTE: genera una simulación con fechas tentativas
    
    Retorna:
    - status: 'approved' o 'pending'
    - is_simulation: true si son fechas simuladas
    - schedule: array con el cronograma de pagos
    """
    from sqlalchemy import text
    
    # Obtener info del préstamo (incluyendo tasas para perfil custom)
    loan_query = text("""
        SELECT 
            l.id,
            l.amount,
            l.term_biweeks,
            l.profile_code,
            l.status_id,
            l.approved_at,
            l.created_at,
            s.name as status_name,
            l.interest_rate,
            l.commission_rate
        FROM loans l
        JOIN loan_statuses s ON l.status_id = s.id
        WHERE l.id = :loan_id
    """)
    
    result = await db.execute(loan_query, {"loan_id": loan_id})
    loan = result.fetchone()
    
    if not loan:
        raise HTTPException(status_code=404, detail="Préstamo no encontrado")
    
    loan_status_id = loan[4]
    
    # Status 2 = Approved (verificar en tu tabla loan_statuses)
    if loan_status_id == 2:
        # Préstamo aprobado: obtener pagos reales
        # Incluimos total_pending (saldo total pendiente incluyendo intereses)
        payments_query = text("""
            SELECT 
                p.payment_number,
                p.payment_due_date as payment_date,
                COALESCE(cp.cut_code, 'N/A') as cut_period,
                p.expected_amount as client_payment,
                p.associate_payment,
                p.commission_amount as commission,
                p.balance_remaining as remaining_balance,
                p.associate_balance_remaining,
                -- Saldo total pendiente: (pagos restantes incluyendo actual) × pago cliente
                ((l.term_biweeks - p.payment_number + 1) * p.expected_amount) as total_pending_balance,
                -- Saldo asociado pendiente: (pagos restantes incluyendo actual) × pago asociado
                ((l.term_biweeks - p.payment_number + 1) * p.associate_payment) as associate_total_pending
            FROM payments p
            JOIN loans l ON p.loan_id = l.id
            LEFT JOIN cut_periods cp ON p.cut_period_id = cp.id
            WHERE p.loan_id = :loan_id
            ORDER BY p.payment_number
        """)
        
        payments_result = await db.execute(payments_query, {"loan_id": loan_id})
        payments = payments_result.fetchall()
        
        schedule = [
            {
                "payment_number": row[0],
                "payment_date": row[1].isoformat() if row[1] else None,
                "cut_period": row[2],
                "client_payment": float(row[3]) if row[3] else 0,
                "associate_payment": float(row[4]) if row[4] else 0,
                "commission": float(row[5]) if row[5] else 0,
                "remaining_balance": float(row[6]) if row[6] else 0,
                "associate_remaining_balance": float(row[7]) if row[7] else 0,
                # Saldos totales pendientes (incluyendo intereses)
                "total_pending_balance": float(row[8]) if row[8] else 0,
                "associate_total_pending": float(row[9]) if row[9] else 0,
            }
            for row in payments
        ]
        
        return {
            "status": "approved",
            "is_simulation": False,
            "loan_id": loan_id,
            "schedule": schedule
        }
    
    else:
        # Préstamo pendiente: generar simulación
        from datetime import date
        approval_date = loan[6].date() if loan[6] else date.today()
        term_biweeks = loan[2]
        profile_code = loan[3]
        
        # Para perfil 'custom', usar simulate_loan_custom con las tasas del préstamo
        if profile_code == 'custom':
            interest_rate = loan[8]  # interest_rate
            commission_rate = loan[9]  # commission_rate
            
            simulation_query = text("""
                SELECT * FROM simulate_loan_custom(
                    :amount,
                    :term,
                    :interest_rate,
                    :commission_rate,
                    :approval_date
                )
            """)
            
            sim_result = await db.execute(
                simulation_query,
                {
                    "amount": float(loan[1]),
                    "term": term_biweeks,
                    "interest_rate": float(interest_rate) if interest_rate else 0,
                    "commission_rate": float(commission_rate) if commission_rate else 0,
                    "approval_date": approval_date
                }
            )
        else:
            # Perfiles estándar (legacy, standard, etc.)
            simulation_query = text("""
                SELECT * FROM simulate_loan(
                    :amount,
                    :term,
                    :profile,
                    :approval_date
                )
            """)
            
            sim_result = await db.execute(
                simulation_query,
                {
                    "amount": float(loan[1]),
                    "term": term_biweeks,
                    "profile": profile_code,
                    "approval_date": approval_date
                }
            )
        
        sim_rows = sim_result.fetchall()
        
        schedule = []
        for row in sim_rows:
            payment_num = row[0]
            client_payment = float(row[3]) if row[3] else 0
            associate_payment = float(row[4]) if row[4] else 0
            
            # Calcular saldos totales pendientes para simulación
            remaining_payments = term_biweeks - payment_num + 1
            total_pending = remaining_payments * client_payment
            associate_total_pending = remaining_payments * associate_payment
            
            # simulate_loan_custom tiene 7 columnas, simulate_loan tiene 8
            # Columna 7 (associate_remaining_balance) solo existe en simulate_loan
            associate_remaining_balance = float(row[7]) if len(row) > 7 and row[7] else 0
            
            schedule.append({
                "payment_number": payment_num,
                "payment_date": row[1].isoformat() if row[1] else None,
                "cut_period": row[2],
                "client_payment": client_payment,
                "associate_payment": associate_payment,
                "commission": float(row[5]) if row[5] else 0,
                "remaining_balance": float(row[6]) if row[6] else 0,
                "associate_remaining_balance": associate_remaining_balance,
                # Saldos totales pendientes (incluyendo intereses)
                "total_pending_balance": total_pending,
                "associate_total_pending": associate_total_pending,
            })
        
        return {
            "status": "pending",
            "is_simulation": True,
            "loan_id": loan_id,
            "approval_date_used": approval_date.isoformat(),
            "schedule": schedule
        }


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
    
    Opciones de tasas:
    1. Con profile_code: Las tasas se calculan automáticamente
    2. Sin profile_code: Usar tasas manuales (interest_rate y commission_rate obligatorias)
    
    Validaciones iniciales:
    - El asociado tiene crédito disponible suficiente
    - El cliente no tiene otros préstamos PENDING
    - El cliente no es moroso
    
    Body (Opción 1 - Con perfil):
    ```json
    {
        "user_id": 5,
        "associate_user_id": 10,
        "amount": 22000.00,
        "term_biweeks": 12,
        "profile_code": "standard",
        "notes": "Préstamo para negocio"
    }
    ```
    
    Body (Opción 2 - Tasas manuales):
    ```json
    {
        "user_id": 5,
        "associate_user_id": 10,
        "amount": 5000.00,
        "term_biweeks": 12,
        "interest_rate": 4.25,
        "commission_rate": 2.50,
        "notes": "Préstamo personalizado"
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
        # DEBUG: Log del payload recibido
        print(f"🔍 DEBUG CREATE LOAN - Payload recibido:")
        print(f"  user_id: {loan_data.user_id}")
        print(f"  associate_user_id: {loan_data.associate_user_id}")
        print(f"  amount: {loan_data.amount}")
        print(f"  term_biweeks: {loan_data.term_biweeks}")
        print(f"  profile_code: {loan_data.profile_code}")
        print(f"  interest_rate: {loan_data.interest_rate}")
        print(f"  commission_rate: {loan_data.commission_rate}")
        print(f"  notes: {loan_data.notes}")
        
        loan = await service.create_loan_request(
            user_id=loan_data.user_id,
            associate_user_id=loan_data.associate_user_id,
            amount=loan_data.amount,
            term_biweeks=loan_data.term_biweeks,
            profile_code=loan_data.profile_code,
            interest_rate=loan_data.interest_rate,
            commission_rate=loan_data.commission_rate,
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
            profile_code=loan.profile_code,
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


@router.delete("/{loan_id}/force", status_code=200)
async def force_delete_loan(
    loan_id: int,
    db: AsyncSession = Depends(get_async_db),
):
    """
    Elimina un préstamo Y todos sus pagos asociados (eliminación forzada).
    
    ⚠️ PELIGROSO: Esta acción es irreversible y elimina:
    - El préstamo
    - Todos los pagos (payments) asociados
    - Libera el crédito del asociado si aplica
    
    Solo se permite para préstamos en estado:
    - PENDING (1)
    - APPROVED (2)
    - ACTIVE (3)
    - REJECTED (6)
    
    NO se permite eliminar préstamos:
    - PAID_OFF (4) - Ya fueron liquidados
    - DEFAULTED (5) - Tienen historial de mora
    - CANCELLED (7) - Ya fueron cancelados
    
    Returns:
        Información del préstamo eliminado
    """
    try:
        # 1. Buscar préstamo
        loan_result = await db.execute(
            text("SELECT * FROM loans WHERE id = :loan_id"),
            {"loan_id": loan_id}
        )
        loan = loan_result.fetchone()
        
        if not loan:
            raise HTTPException(status_code=404, detail=f"Préstamo {loan_id} no encontrado")
        
        # 2. Validar estado (no permitir PAID_OFF, DEFAULTED, CANCELLED)
        forbidden_states = [4, 5, 7]  # PAID_OFF, DEFAULTED, CANCELLED
        if loan.status_id in forbidden_states:
            status_names = {4: 'PAID_OFF', 5: 'DEFAULTED', 7: 'CANCELLED'}
            raise HTTPException(
                status_code=400,
                detail=f"No se puede eliminar préstamo en estado {status_names.get(loan.status_id, loan.status_id)}. "
                       f"Los préstamos liquidados, en mora o cancelados deben mantenerse como histórico."
            )
        
        # 3. Contar pagos a eliminar
        payments_count_result = await db.execute(
            text("SELECT COUNT(*) as count FROM payments WHERE loan_id = :loan_id"),
            {"loan_id": loan_id}
        )
        payments_count = payments_count_result.scalar()
        
        # 4. Si tiene asociado con crédito usado, liberarlo
        credit_released = 0
        if loan.associate_user_id and loan.status_id in [2, 3]:  # APPROVED o ACTIVE
            # Liberar crédito del asociado
            await db.execute(
                text("""
                    UPDATE associate_profiles 
                    SET credit_used = GREATEST(0, credit_used - :amount),
                        updated_at = NOW()
                    WHERE user_id = :associate_id
                """),
                {"amount": float(loan.amount), "associate_id": loan.associate_user_id}
            )
            credit_released = float(loan.amount)
        
        # 5. Eliminar pagos asociados
        await db.execute(
            text("DELETE FROM payments WHERE loan_id = :loan_id"),
            {"loan_id": loan_id}
        )
        
        # 6. Eliminar el préstamo
        await db.execute(
            text("DELETE FROM loans WHERE id = :loan_id"),
            {"loan_id": loan_id}
        )
        
        await db.commit()
        
        return {
            "success": True,
            "message": f"Préstamo #{loan_id} eliminado exitosamente",
            "details": {
                "loan_id": loan_id,
                "amount": float(loan.amount),
                "status_id": loan.status_id,
                "payments_deleted": payments_count,
                "credit_released": credit_released
            }
        }
    
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
