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
    - status_id: Estado del préstamo (1=PENDING, 2=ACTIVE, 4=COMPLETED, etc.)
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
    
    # Status 2 = ACTIVE (préstamo activo con pagos en curso)
    if loan_status_id == 2:
        # Préstamo activo: obtener pagos reales
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
    4. Actualizar préstamo a ACTIVE
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
    
    NO se pueden eliminar préstamos ACTIVE, PAID_OFF o CANCELLED
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
    - ACTIVE (2)
    - REJECTED (7)
    
    NO se permite eliminar préstamos:
    - COMPLETED (4) - Ya fueron liquidados
    - DEFAULTED (6) - Tienen historial de mora
    - CANCELLED (8) - Ya fueron cancelados
    
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
        if loan.associate_user_id and loan.status_id == 2:  # ACTIVE
            # Liberar crédito del asociado
            await db.execute(
                text("""
                    UPDATE associate_profiles 
                    SET pending_payments_total = GREATEST(0, pending_payments_total - :amount),
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
    - Se libera el crédito del asociado (pending_payments_total se reduce)
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


# =============================================================================
# RENOVACIÓN DE PRÉSTAMOS
# =============================================================================

@router.get("/client/{client_user_id}/active-loans")
async def get_client_active_loans(
    client_user_id: int,
    db: AsyncSession = Depends(get_async_db),
):
    """
    Obtiene los préstamos activos de un cliente con información para renovación.
    
    Retorna para cada préstamo activo:
    - Información básica del préstamo
    - Pagos pendientes y su monto total
    - Comisiones pendientes para el asociado
    - Información necesaria para calcular la renovación
    
    Se usa cuando:
    - Al crear un nuevo préstamo, verificar si el cliente tiene préstamos activos
    - Mostrar la opción de "renovar" liquidando el préstamo anterior
    
    Ejemplos:
    - GET /loans/client/5/active-loans → Préstamos activos del cliente 5
    """
    query = text("""
        SELECT 
            l.id as loan_id,
            l.amount as original_amount,
            l.term_biweeks,
            l.interest_rate,
            l.commission_rate,
            l.biweekly_payment,
            l.commission_per_payment,
            l.profile_code,
            l.created_at,
            l.approved_at,
            ls.name as status_name,
            -- Asociado
            l.associate_user_id,
            ua.first_name || ' ' || ua.last_name as associate_name,
            -- Total de pagos del préstamo
            (SELECT COUNT(*) FROM payments p WHERE p.loan_id = l.id) as total_payments,
            -- Contar pagos pendientes (status 1 = PENDING)
            (SELECT COUNT(*) FROM payments p WHERE p.loan_id = l.id AND p.status_id = 1) as pending_payments_count,
            -- Total a liquidar (suma de expected_amount de pagos pendientes)
            (SELECT COALESCE(SUM(expected_amount), 0) FROM payments p WHERE p.loan_id = l.id AND p.status_id = 1) as total_pending_amount,
            -- Comisiones pendientes para el asociado
            (SELECT COALESCE(SUM(commission_amount), 0) FROM payments p WHERE p.loan_id = l.id AND p.status_id = 1) as pending_commissions,
            -- Siguiente fecha de pago
            (SELECT MIN(payment_due_date) FROM payments p WHERE p.loan_id = l.id AND p.status_id = 1) as next_payment_date
        FROM loans l
        JOIN loan_statuses ls ON l.status_id = ls.id
        LEFT JOIN users ua ON l.associate_user_id = ua.id
        WHERE l.user_id = :client_user_id
          AND ls.name = 'ACTIVE'
        ORDER BY l.created_at DESC
    """)
    
    result = await db.execute(query, {"client_user_id": client_user_id})
    rows = result.fetchall()
    
    active_loans = []
    for row in rows:
        active_loans.append({
            "loan_id": row.loan_id,
            "original_amount": float(row.original_amount),
            "term_biweeks": row.term_biweeks,
            "interest_rate": float(row.interest_rate) if row.interest_rate else None,
            "commission_rate": float(row.commission_rate) if row.commission_rate else None,
            "biweekly_payment": float(row.biweekly_payment) if row.biweekly_payment else None,
            "commission_per_payment": float(row.commission_per_payment) if row.commission_per_payment else None,
            "profile_code": row.profile_code,
            "created_at": row.created_at.isoformat() if row.created_at else None,
            "approved_at": row.approved_at.isoformat() if row.approved_at else None,
            "status_name": row.status_name,
            "associate_user_id": row.associate_user_id,
            "associate_name": row.associate_name,
            # Información para renovación
            "total_payments": row.total_payments,
            "pending_payments_count": row.pending_payments_count,
            "total_pending_amount": float(row.total_pending_amount),
            "pending_commissions": float(row.pending_commissions),
            "next_payment_date": row.next_payment_date.isoformat() if row.next_payment_date else None,
            # Resumen para UI - Usamos 'loan_amount' como alias de original_amount para consistencia con el frontend
            "loan_amount": float(row.original_amount),
            "can_renew": row.pending_payments_count > 0,
            "renewal_summary": {
                "payments_remaining": row.pending_payments_count,
                "amount_to_liquidate": float(row.total_pending_amount),
                "commissions_owed_to_associate": float(row.pending_commissions),
            }
        })
    
    return {
        "client_user_id": client_user_id,
        "has_active_loans": len(active_loans) > 0,
        "active_loans_count": len(active_loans),
        "active_loans": active_loans
    }


@router.post("/renew", response_model=LoanResponseDTO, status_code=201)
async def renew_loan(
    renewal_data: dict,
    db: AsyncSession = Depends(get_async_db),
):
    """
    Crea un nuevo préstamo que liquida uno anterior (renovación).
    
    ⭐ IMPORTANTE: Los préstamos renovados se APRUEBAN AUTOMÁTICAMENTE
    porque el cliente ya tiene un préstamo activo validado.
    
    Proceso de renovación:
    1. Se libera el crédito del asociado (del préstamo original)
    2. Se crea el nuevo préstamo (status PENDING)
    3. Se marcan los pagos pendientes del préstamo anterior como PAID_BY_RENEWAL
    4. Se marca el préstamo anterior como RENEWED
    5. Se registra en loan_renewals para tracking
    6. Se APRUEBA AUTOMÁTICAMENTE el nuevo préstamo (genera cronograma de pagos)
    7. Las comisiones pendientes quedan como "saldo a favor" del asociado
    
    REGLA DE NEGOCIO - LIQUIDACIÓN:
    El cliente debe liquidar TODOS los pagos pendientes completos (capital + interés).
    NO hay descuento por pago anticipado de intereses.
    
    Body Example:
    ```json
    {
        "original_loan_id": 95,
        "user_id": 1019,
        "associate_user_id": 10,
        "amount": 40000.00,
        "term_biweeks": 12,
        "profile_code": "standard",
        "notes": "Renovación de préstamo"
    }
    ```
    
    Validaciones:
    - El préstamo original existe y está ACTIVE
    - El nuevo monto es suficiente para cubrir la suma de pagos pendientes (capital + interés)
    - El asociado tiene crédito suficiente
    
    Returns:
        LoanResponseDTO: Nuevo préstamo APROBADO con cronograma de pagos generado
    """
    from datetime import datetime
    
    original_loan_id = renewal_data.get("original_loan_id")
    
    if not original_loan_id:
        raise HTTPException(status_code=400, detail="original_loan_id es requerido para renovación")
    
    # 1. Obtener información del préstamo original
    original_query = text("""
        SELECT 
            l.id,
            l.user_id,
            l.associate_user_id,
            l.amount,
            ls.name as status_name,
            -- Pagos pendientes
            (SELECT COUNT(*) FROM payments p WHERE p.loan_id = l.id AND p.status_id = 1) as pending_count,
            (SELECT COALESCE(SUM(expected_amount), 0) FROM payments p WHERE p.loan_id = l.id AND p.status_id = 1) as pending_amount,
            (SELECT COALESCE(SUM(commission_amount), 0) FROM payments p WHERE p.loan_id = l.id AND p.status_id = 1) as pending_commissions
        FROM loans l
        JOIN loan_statuses ls ON l.status_id = ls.id
        WHERE l.id = :loan_id
    """)
    
    result = await db.execute(original_query, {"loan_id": original_loan_id})
    original = result.fetchone()
    
    if not original:
        raise HTTPException(status_code=404, detail=f"Préstamo original {original_loan_id} no encontrado")
    
    if original.status_name != 'ACTIVE':
        raise HTTPException(
            status_code=400, 
            detail=f"El préstamo {original_loan_id} no puede renovarse. Estado actual: {original.status_name}"
        )
    
    # Validar que el cliente sea el mismo
    if renewal_data.get("user_id") != original.user_id:
        raise HTTPException(
            status_code=400,
            detail="El nuevo préstamo debe ser para el mismo cliente que el préstamo original"
        )
    
    new_amount = float(renewal_data.get("amount", 0))
    pending_amount = float(original.pending_amount)
    pending_commissions = float(original.pending_commissions)
    original_loan_amount = float(original.amount)  # Monto del préstamo original
    
    # El nuevo monto debe cubrir al menos el saldo pendiente
    if new_amount < pending_amount:
        raise HTTPException(
            status_code=400,
            detail=f"El monto del nuevo préstamo (${new_amount:,.2f}) debe ser mayor o igual al saldo pendiente (${pending_amount:,.2f})"
        )
    
    # Capital neto que necesita el asociado = nuevo_monto - monto_original
    # Porque al cerrar el préstamo original se libera su crédito
    net_capital_needed = new_amount - original_loan_amount
    
    # ⭐ 2. PRIMERO: Liberar el crédito del préstamo original
    # Esto permite que el asociado tenga crédito disponible para el nuevo préstamo
    # IMPORTANTE: Si el asociado cambia, el original libera y el nuevo consume
    # ⚠️ CRÍTICO: Liberar SOLO el capital original (amount), NO el saldo pendiente completo
    # porque el saldo pendiente incluye intereses y comisión que no ocupan crédito
    await db.execute(text("""
        UPDATE associate_profiles 
        SET pending_payments_total = GREATEST(0, pending_payments_total - :original_amount),
            credit_last_updated = CURRENT_TIMESTAMP
        WHERE user_id = :original_associate_id
    """), {
        "original_amount": original_loan_amount,  # ✅ CORRECTO: Solo capital, no incluye intereses/comisión
        "original_associate_id": original.associate_user_id
    })
    
    print(f"✅ Crédito liberado del asociado {original.associate_user_id}: ${original_loan_amount:,.2f} (capital del préstamo original)")
    print(f"   Nota: Saldo pendiente total (con intereses/comisión): ${pending_amount:,.2f}")
    
    # 3. Crear el nuevo préstamo usando el servicio existente
    service = LoanService(db)
    
    try:
        new_loan = await service.create_loan_request(
            user_id=renewal_data.get("user_id"),
            associate_user_id=renewal_data.get("associate_user_id"),
            amount=new_amount,
            term_biweeks=renewal_data.get("term_biweeks"),
            profile_code=renewal_data.get("profile_code"),
            interest_rate=renewal_data.get("interest_rate"),
            commission_rate=renewal_data.get("commission_rate"),
            notes=f"RENOVACIÓN de préstamo #{original_loan_id}. Saldo liquidado: ${pending_amount:,.2f}. {renewal_data.get('notes', '')}"
        )
        
        # ⭐ IMPORTANTE: Hacer las operaciones de renovación ANTES del approve
        # porque approve hace commit() y queremos todo en una sola transacción
        
        # 3. Marcar pagos pendientes del préstamo original como PAID_BY_RENEWAL (status 14)
        # Primero verificar si existe el status PAID_BY_RENEWAL
        status_check = await db.execute(text("SELECT id FROM payment_statuses WHERE name = 'PAID_BY_RENEWAL'"))
        renewal_status = status_check.fetchone()
        
        if not renewal_status:
            # Crear el status si no existe
            await db.execute(text("""
                INSERT INTO payment_statuses (id, name, description, is_active, is_real_payment)
                VALUES (14, 'PAID_BY_RENEWAL', 'Pago liquidado por renovación de préstamo', true, false)
                ON CONFLICT (id) DO NOTHING
            """))
        
        # Marcar los pagos como liquidados por renovación
        await db.execute(text("""
            UPDATE payments 
            SET status_id = 14,
                marking_notes = :notes,
                updated_at = CURRENT_TIMESTAMP
            WHERE loan_id = :original_loan_id 
              AND status_id = 1
        """), {
            "original_loan_id": original_loan_id,
            "notes": f"Liquidado por renovación. Nuevo préstamo: #{new_loan.id}"
        })
        
        # 4. Marcar préstamo original como RENEWED (si no existe el status, usar COMPLETED)
        await db.execute(text("""
            UPDATE loans 
            SET status_id = COALESCE(
                (SELECT id FROM loan_statuses WHERE name = 'RENEWED'),
                4  -- COMPLETED como fallback
            ),
            notes = COALESCE(notes, '') || E'\n[RENOVADO] ' || :renewal_note,
            updated_at = CURRENT_TIMESTAMP
            WHERE id = :original_loan_id
        """), {
            "original_loan_id": original_loan_id,
            "renewal_note": f"Renovado como préstamo #{new_loan.id} el {datetime.now().strftime('%Y-%m-%d %H:%M')}"
        })
        
        # 5. Registrar en loan_renewals
        await db.execute(text("""
            INSERT INTO loan_renewals (
                original_loan_id,
                renewed_loan_id,
                renewal_date,
                pending_balance,
                new_amount,
                reason,
                created_by
            ) VALUES (
                :original_id,
                :renewed_id,
                CURRENT_DATE,
                :pending_balance,
                :new_amount,
                :reason,
                :created_by
            )
        """), {
            "original_id": original_loan_id,
            "renewed_id": new_loan.id,
            "pending_balance": pending_amount,
            "new_amount": new_amount,
            "reason": f"Renovación estándar. Comisiones pendientes: ${pending_commissions:,.2f}",
            "created_by": renewal_data.get("associate_user_id")
        })
        
        # ⭐ 6. APROBAR el nuevo préstamo (genera cronograma de pagos via trigger)
        # El commit de approve_loan incluirá TODAS las operaciones anteriores
        approved_loan = await service.approve_loan(
            loan_id=new_loan.id,
            approved_by=renewal_data.get("associate_user_id"),
            notes=f"Aprobación automática por renovación de préstamo #{original_loan_id}"
        )
        
        # Usar el préstamo aprobado
        new_loan = approved_loan
        
        # Retornar el nuevo préstamo
        return LoanResponseDTO(
            id=new_loan.id,
            user_id=new_loan.user_id,
            associate_user_id=new_loan.associate_user_id,
            amount=new_loan.amount,
            interest_rate=new_loan.interest_rate,
            commission_rate=new_loan.commission_rate,
            term_biweeks=new_loan.term_biweeks,
            status_id=new_loan.status_id,
            contract_id=new_loan.contract_id,
            approved_at=new_loan.approved_at,
            approved_by=new_loan.approved_by,
            rejected_at=new_loan.rejected_at,
            rejected_by=new_loan.rejected_by,
            rejection_reason=new_loan.rejection_reason,
            notes=new_loan.notes,
            created_at=new_loan.created_at,
            updated_at=new_loan.updated_at,
            total_to_pay=new_loan.calculate_total_to_pay(),
            payment_amount=new_loan.calculate_payment_amount(),
            # Información adicional de renovación
            renewal_info={
                "is_renewal": True,
                "original_loan_id": original_loan_id,
                "amount_liquidated": pending_amount,  # Capital + intereses liquidados
                "commissions_owed_to_associate": pending_commissions,  # Saldo a favor del asociado
                "net_to_client": new_amount - pending_amount,  # Lo que le queda al cliente después de liquidar
                "original_loan_amount": original_loan_amount  # Monto original del préstamo liquidado
            }
        )
        
    except ValueError as e:
        await db.rollback()
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        await db.rollback()
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Error interno: {str(e)}")


__all__ = ["router"]
