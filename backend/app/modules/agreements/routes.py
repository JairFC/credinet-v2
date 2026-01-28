"""
Agreements Router (Convenios de Pago)

FLUJO DE NEGOCIO:
1. Se crea convenio desde préstamos ACTIVOS del asociado
2. Se calculan pagos PENDIENTES del asociado (SUM de associate_payment)
3. pending_payments_total SE MUEVE A consolidated_debt (available_credit NO cambia)
4. Los payments del préstamo pasan a estado IN_AGREEMENT
5. El préstamo pasa a estado IN_AGREEMENT
6. Se genera plan de pagos del convenio (agreement_payments)
7. Asociado paga cuotas → consolidated_debt disminuye → available_credit aumenta
8. Cuando se completa → status = COMPLETED

FÓRMULA CLAVE:
  available_credit = credit_limit - pending_payments_total - consolidated_debt
  
  Al crear convenio por $X:
    - pending_payments_total -= $X (baja)
    - consolidated_debt += $X (sube)
    - available_credit = SIN CAMBIO (se resta en ambos lados)
    
  Al pagar convenio por $Y:
    - consolidated_debt -= $Y (baja)
    - available_credit += $Y (se libera crédito)
"""
import asyncio
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text
from pydantic import BaseModel
from typing import Optional, List
from decimal import Decimal
from datetime import date, datetime, timedelta
from dateutil.relativedelta import relativedelta
from app.core.database import get_async_db
from app.core.notifications import notify
from app.modules.auth.routes import get_current_user
from .application.dtos import AgreementResponseDTO, AgreementListItemDTO, PaginatedAgreementsDTO
from .application.use_cases import ListAgreementsUseCase, GetAssociateAgreementsUseCase
from .infrastructure.repositories import PgAgreementRepository

router = APIRouter(prefix="/agreements", tags=["agreements"])


# ============== DTOs ==============

class CreateAgreementRequestDTO(BaseModel):
    associate_profile_id: int
    debt_breakdown_ids: List[int]  # IDs from associate_debt_breakdown to include
    payment_plan_months: int
    start_date: date
    notes: Optional[str] = None


class CreateAgreementFromLoansDTO(BaseModel):
    """DTO para crear convenio desde préstamos ACTIVOS."""
    loan_ids: List[int]  # IDs de préstamos activos a incluir en el convenio
    payment_plan_biweeks: int  # 1-72 quincenas (hasta 3 años)
    associate_profile_id: Optional[int] = None  # Opcional, se deduce de los préstamos
    start_date: Optional[date] = None  # Opcional, default: hoy
    notes: Optional[str] = None
    
    # ⚠️ DEPRECATED - Mantener para compatibilidad
    payment_plan_months: Optional[int] = None  # Si se envía, se ignora


class AgreementPaymentDTO(BaseModel):
    id: int
    agreement_id: int
    payment_number: int
    payment_amount: Decimal
    payment_due_date: date
    cut_period_id: Optional[int] = None
    cut_period_code: Optional[str] = None
    payment_date: Optional[date] = None
    payment_method_id: Optional[int] = None
    payment_reference: Optional[str] = None
    status: str
    created_at: datetime


class RegisterPaymentDTO(BaseModel):
    payment_method_id: Optional[int] = None
    payment_reference: Optional[str] = None
    notes: Optional[str] = None


class AgreementDetailDTO(BaseModel):
    id: int
    associate_profile_id: int
    agreement_number: str
    agreement_date: date
    total_debt_amount: Decimal
    # Legacy (mensual) - para convenios antiguos
    payment_plan_months: Optional[int] = None
    monthly_payment_amount: Optional[Decimal] = None
    # Nuevo (quincenal) - para convenios nuevos
    payment_plan_periods: Optional[int] = None
    period_payment_amount: Optional[Decimal] = None
    payment_frequency: str = 'biweekly'  # 'monthly' o 'biweekly'
    status: str
    start_date: date
    end_date: Optional[date]
    created_by: Optional[int]
    approved_by: Optional[int]
    notes: Optional[str]
    created_at: datetime
    updated_at: datetime
    # Joined data
    associate_name: Optional[str] = None
    total_paid: Decimal = Decimal('0')
    payments_made: int = 0
    next_payment_date: Optional[date] = None
    items: List[dict] = []
    payments: List[AgreementPaymentDTO] = []


# ============== ENDPOINTS ==============

@router.get("")
async def list_agreements(
    status: Optional[str] = None,
    associate_profile_id: Optional[int] = None,
    limit: int = 50,
    offset: int = 0,
    db: AsyncSession = Depends(get_async_db)
):
    """Lista convenios con filtros opcionales."""
    query = """
        SELECT 
            ag.*,
            CONCAT(u.first_name, ' ', u.last_name) as associate_name,
            COALESCE((
                SELECT SUM(payment_amount) 
                FROM agreement_payments 
                WHERE agreement_id = ag.id AND status = 'PAID'
            ), 0) as total_paid,
            (
                SELECT COUNT(*) 
                FROM agreement_payments 
                WHERE agreement_id = ag.id AND status = 'PAID'
            ) as payments_made
        FROM agreements ag
        LEFT JOIN associate_profiles ap ON ag.associate_profile_id = ap.id
        LEFT JOIN users u ON ap.user_id = u.id
        WHERE 1=1
    """
    params = {}
    
    if status:
        query += " AND ag.status = :status"
        params["status"] = status
    
    if associate_profile_id:
        query += " AND ag.associate_profile_id = :associate_profile_id"
        params["associate_profile_id"] = associate_profile_id
    
    # Count
    count_result = await db.execute(
        text(f"SELECT COUNT(*) FROM ({query}) sub"), 
        params
    )
    total = count_result.scalar_one()
    
    # Pagination
    query += " ORDER BY ag.created_at DESC LIMIT :limit OFFSET :offset"
    params["limit"] = limit
    params["offset"] = offset
    
    result = await db.execute(text(query), params)
    rows = result.fetchall()
    
    items = []
    for row in rows:
        items.append({
            "id": row.id,
            "associate_profile_id": row.associate_profile_id,
            "agreement_number": row.agreement_number,
            "agreement_date": row.agreement_date,
            "total_debt_amount": row.total_debt_amount,
            "status": row.status,
            "associate_name": row.associate_name,
            "total_paid": row.total_paid,
            "payments_made": row.payments_made,
            # Legacy fields (for backward compatibility)
            "monthly_payment_amount": row.monthly_payment_amount,
            "payment_plan_months": row.payment_plan_months,
            # New biweekly fields
            "period_payment_amount": getattr(row, 'period_payment_amount', None),
            "payment_plan_periods": getattr(row, 'payment_plan_periods', None),
            "payment_frequency": getattr(row, 'payment_frequency', 'monthly') or 'monthly',
        })
    
    return {
        "items": items,
        "total": total,
        "limit": limit,
        "offset": offset
    }


@router.get("/{agreement_id}", response_model=AgreementDetailDTO)
async def get_agreement_detail(
    agreement_id: int,
    db: AsyncSession = Depends(get_async_db)
):
    """Obtiene detalle de un convenio con items y pagos."""
    # Get agreement
    query = text("""
        SELECT 
            ag.*,
            CONCAT(u.first_name, ' ', u.last_name) as associate_name
        FROM agreements ag
        LEFT JOIN associate_profiles ap ON ag.associate_profile_id = ap.id
        LEFT JOIN users u ON ap.user_id = u.id
        WHERE ag.id = :agreement_id
    """)
    result = await db.execute(query, {"agreement_id": agreement_id})
    agreement = result.fetchone()
    
    if not agreement:
        raise HTTPException(status_code=404, detail="Convenio no encontrado")
    
    # Get items
    items_query = text("""
        SELECT ai.*, 
               CONCAT(c.first_name, ' ', c.last_name) as client_name
        FROM agreement_items ai
        LEFT JOIN users c ON ai.client_user_id = c.id
        WHERE ai.agreement_id = :agreement_id
        ORDER BY ai.id
    """)
    items_result = await db.execute(items_query, {"agreement_id": agreement_id})
    items = [dict(row._mapping) for row in items_result.fetchall()]
    
    # Get payments with cut_period info
    payments_query = text("""
        SELECT ap.*, cp.cut_code as cut_period_code
        FROM agreement_payments ap
        LEFT JOIN cut_periods cp ON cp.id = ap.cut_period_id
        WHERE ap.agreement_id = :agreement_id
        ORDER BY ap.payment_number
    """)
    payments_result = await db.execute(payments_query, {"agreement_id": agreement_id})
    payments = []
    total_paid = Decimal('0')
    payments_made = 0
    next_payment_date = None
    
    for row in payments_result.fetchall():
        payments.append(AgreementPaymentDTO(
            id=row.id,
            agreement_id=row.agreement_id,
            payment_number=row.payment_number,
            payment_amount=row.payment_amount,
            payment_due_date=row.payment_due_date,
            cut_period_id=row.cut_period_id,
            cut_period_code=row.cut_period_code,
            payment_date=row.payment_date,
            payment_method_id=row.payment_method_id,
            payment_reference=row.payment_reference,
            status=row.status,
            created_at=row.created_at
        ))
        if row.status == 'PAID':
            total_paid += row.payment_amount
            payments_made += 1
        elif row.status == 'PENDING' and next_payment_date is None:
            next_payment_date = row.payment_due_date
    
    return AgreementDetailDTO(
        id=agreement.id,
        associate_profile_id=agreement.associate_profile_id,
        agreement_number=agreement.agreement_number,
        agreement_date=agreement.agreement_date,
        total_debt_amount=agreement.total_debt_amount,
        payment_plan_months=agreement.payment_plan_months,
        monthly_payment_amount=agreement.monthly_payment_amount,
        payment_plan_periods=getattr(agreement, 'payment_plan_periods', None),
        period_payment_amount=getattr(agreement, 'period_payment_amount', None),
        payment_frequency=getattr(agreement, 'payment_frequency', 'monthly') or 'monthly',
        status=agreement.status,
        start_date=agreement.start_date,
        end_date=agreement.end_date,
        created_by=agreement.created_by,
        approved_by=agreement.approved_by,
        notes=agreement.notes,
        created_at=agreement.created_at,
        updated_at=agreement.updated_at,
        associate_name=agreement.associate_name,
        total_paid=total_paid,
        payments_made=payments_made,
        next_payment_date=next_payment_date,
        items=items,
        payments=payments
    )


@router.post("", response_model=AgreementDetailDTO)
async def create_agreement(
    data: CreateAgreementRequestDTO,
    db: AsyncSession = Depends(get_async_db),
    current_user: dict = Depends(get_current_user)
):
    """
    Crea un nuevo convenio de pago.
    
    ACCIONES:
    1. Valida que las deudas pertenecen al asociado y no están liquidadas
    2. Calcula total de deuda y pago mensual
    3. Crea el convenio
    4. Crea los items del convenio
    5. Genera el calendario de pagos (agreement_payments)
    6. Marca las deudas originales como "en convenio"
    """
    # Validate months
    if data.payment_plan_months < 1 or data.payment_plan_months > 36:
        raise HTTPException(
            status_code=400, 
            detail="El plazo debe ser entre 1 y 36 meses"
        )
    
    # Validate associate exists
    assoc_query = text("""
        SELECT ap.*, CONCAT(u.first_name, ' ', u.last_name) as associate_name
        FROM associate_profiles ap
        LEFT JOIN users u ON ap.user_id = u.id
        WHERE ap.id = :associate_profile_id
    """)
    assoc_result = await db.execute(assoc_query, {"associate_profile_id": data.associate_profile_id})
    associate = assoc_result.fetchone()
    
    if not associate:
        raise HTTPException(status_code=404, detail="Asociado no encontrado")
    
    # Get selected debts from associate_debt_breakdown
    if not data.debt_breakdown_ids:
        raise HTTPException(status_code=400, detail="Debe seleccionar al menos una deuda")
    
    debts_query = text("""
        SELECT * FROM associate_debt_breakdown
        WHERE id = ANY(:ids)
          AND associate_profile_id = :associate_profile_id
          AND is_liquidated = false
    """)
    debts_result = await db.execute(debts_query, {
        "ids": data.debt_breakdown_ids,
        "associate_profile_id": data.associate_profile_id
    })
    debts = debts_result.fetchall()
    
    if len(debts) != len(data.debt_breakdown_ids):
        raise HTTPException(
            status_code=400,
            detail="Algunas deudas no existen, ya están liquidadas, o no pertenecen al asociado"
        )
    
    # Calculate totals
    total_debt = sum(Decimal(str(d.amount)) for d in debts)
    monthly_payment = (total_debt / data.payment_plan_months).quantize(Decimal('0.01'))
    
    # Generate agreement number (using MAX to handle gaps from deleted records)
    count_query = text("""
        SELECT COALESCE(
            MAX(CAST(SUBSTRING(agreement_number FROM 'CONV-[0-9]+-([0-9]+)') AS INTEGER)), 0
        ) + 1 as next_num 
        FROM agreements
    """)
    count_result = await db.execute(count_query)
    next_num = count_result.scalar_one()
    agreement_number = f"CONV-{datetime.now().year}-{next_num:04d}"
    
    # Calculate end date
    end_date = data.start_date + relativedelta(months=data.payment_plan_months)
    
    # Create agreement
    insert_agreement = text("""
        INSERT INTO agreements (
            associate_profile_id,
            agreement_number,
            agreement_date,
            total_debt_amount,
            payment_plan_months,
            monthly_payment_amount,
            status,
            start_date,
            end_date,
            created_by,
            notes
        ) VALUES (
            :associate_profile_id,
            :agreement_number,
            CURRENT_DATE,
            :total_debt_amount,
            :payment_plan_months,
            :monthly_payment_amount,
            'ACTIVE',
            :start_date,
            :end_date,
            :created_by,
            :notes
        )
        RETURNING id
    """)
    
    result = await db.execute(insert_agreement, {
        "associate_profile_id": data.associate_profile_id,
        "agreement_number": agreement_number,
        "total_debt_amount": total_debt,
        "payment_plan_months": data.payment_plan_months,
        "monthly_payment_amount": monthly_payment,
        "start_date": data.start_date,
        "end_date": end_date,
        "created_by": current_user["user_id"],
        "notes": data.notes
    })
    
    agreement_id = result.scalar_one()
    
    # Create agreement items from debts
    for debt in debts:
        await db.execute(text("""
            INSERT INTO agreement_items (
                agreement_id, loan_id, client_user_id, debt_amount, debt_type, description
            ) VALUES (
                :agreement_id, :loan_id, :client_user_id, :debt_amount, :debt_type, :description
            )
        """), {
            "agreement_id": agreement_id,
            "loan_id": debt.loan_id,
            "client_user_id": debt.client_user_id,
            "debt_amount": debt.amount,
            "debt_type": debt.debt_type,
            "description": debt.description
        })
        
        # Mark original debt as liquidated (now in agreement)
        await db.execute(text("""
            UPDATE associate_debt_breakdown
            SET is_liquidated = true,
                liquidation_date = CURRENT_TIMESTAMP,
                liquidation_notes = :notes
            WHERE id = :debt_id
        """), {
            "debt_id": debt.id,
            "notes": f"Incluido en convenio {agreement_number}"
        })
    
    # Generate payment schedule
    payment_date = data.start_date
    for i in range(1, data.payment_plan_months + 1):
        # Last payment adjusts for rounding differences
        if i == data.payment_plan_months:
            payment_amount = total_debt - (monthly_payment * (data.payment_plan_months - 1))
        else:
            payment_amount = monthly_payment
        
        await db.execute(text("""
            INSERT INTO agreement_payments (
                agreement_id, payment_number, payment_amount, payment_due_date, status
            ) VALUES (
                :agreement_id, :payment_number, :payment_amount, :payment_due_date, 'PENDING'
            )
        """), {
            "agreement_id": agreement_id,
            "payment_number": i,
            "payment_amount": payment_amount,
            "payment_due_date": payment_date
        })
        
        payment_date = payment_date + relativedelta(months=1)
    
    await db.commit()
    
    # Return created agreement
    return await get_agreement_detail(agreement_id, db)


@router.post("/from-loans", response_model=AgreementDetailDTO)
async def create_agreement_from_loans(
    data: CreateAgreementFromLoansDTO,
    db: AsyncSession = Depends(get_async_db),
    current_user: dict = Depends(get_current_user)
):
    """
    ⭐ NUEVO: Crea un convenio de pago desde préstamos ACTIVOS.
    
    FLUJO:
    1. Valida que los préstamos pertenecen al asociado y están activos
    2. Calcula SUM(associate_payment) de pagos PENDING del asociado
    3. MUEVE ese monto de pending_payments_total a consolidated_debt (available_credit NO cambia)
    4. Marca los payments como IN_AGREEMENT
    5. Marca los loans como IN_AGREEMENT
    6. Crea el convenio con plan de pagos
    
    FÓRMULA PROTEGIDA:
      available_credit = credit_limit - pending_payments_total - consolidated_debt
      Al crear convenio: pending_payments_total baja, consolidated_debt sube → SIN CAMBIO
      Al pagar convenio: consolidated_debt baja → available_credit SUBE (se libera)
    """
    # Validate biweeks (quincenas)
    if not data.payment_plan_biweeks or data.payment_plan_biweeks < 1 or data.payment_plan_biweeks > 72:
        raise HTTPException(
            status_code=400, 
            detail="El plazo debe ser entre 1 y 72 quincenas (hasta 3 años)"
        )
    
    # Validate loans exist
    if not data.loan_ids:
        raise HTTPException(status_code=400, detail="Debe seleccionar al menos un préstamo")
    
    # Get start_date (default to today)
    start_date = data.start_date or date.today()
    
    # If associate_profile_id not provided, get it from first loan
    associate_profile_id = data.associate_profile_id
    if not associate_profile_id:
        loan_assoc_query = text("""
            SELECT ap.id as profile_id
            FROM loans l
            JOIN associate_profiles ap ON ap.user_id = l.associate_user_id
            WHERE l.id = :loan_id
        """)
        loan_assoc_result = await db.execute(loan_assoc_query, {"loan_id": data.loan_ids[0]})
        loan_assoc = loan_assoc_result.fetchone()
        if not loan_assoc:
            raise HTTPException(status_code=400, detail="No se pudo determinar el asociado del préstamo")
        associate_profile_id = loan_assoc.profile_id
    
    # Validate associate exists
    assoc_query = text("""
        SELECT ap.*, CONCAT(u.first_name, ' ', u.last_name) as associate_name,
               ap.pending_payments_total, ap.consolidated_debt, ap.credit_limit
        FROM associate_profiles ap
        LEFT JOIN users u ON ap.user_id = u.id
        WHERE ap.id = :associate_profile_id
    """)
    assoc_result = await db.execute(assoc_query, {"associate_profile_id": associate_profile_id})
    associate = assoc_result.fetchone()
    
    if not associate:
        raise HTTPException(status_code=404, detail="Asociado no encontrado")
    
    # Get the user_id for the associate (loans use associate_user_id, not profile_id)
    associate_user_id = associate.user_id
    
    # Validate loans exist and belong to associate
    if not data.loan_ids:
        raise HTTPException(status_code=400, detail="Debe seleccionar al menos un préstamo")
    
    loans_query = text("""
        SELECT l.id, l.amount, l.status_id,
               CONCAT(c.first_name, ' ', c.last_name) as client_name,
               l.user_id as client_user_id
        FROM loans l
        LEFT JOIN users c ON l.user_id = c.id
        WHERE l.id = ANY(:ids)
          AND l.associate_user_id = :associate_user_id
          AND l.status_id = 2  -- ACTIVE only
    """)
    loans_result = await db.execute(loans_query, {
        "ids": data.loan_ids,
        "associate_user_id": associate_user_id
    })
    loans = loans_result.fetchall()
    
    if len(loans) != len(data.loan_ids):
        raise HTTPException(
            status_code=400,
            detail="Algunos préstamos no existen, no están activos, o no pertenecen al asociado"
        )
    
    # ⭐ VALIDACIÓN: Verificar que los préstamos no estén ya en un convenio ACTIVE
    existing_agreements_query = text("""
        SELECT ai.loan_id, a.agreement_number
        FROM agreement_items ai
        JOIN agreements a ON a.id = ai.agreement_id
        WHERE ai.loan_id = ANY(:loan_ids)
          AND a.status = 'ACTIVE'
    """)
    existing_result = await db.execute(existing_agreements_query, {"loan_ids": data.loan_ids})
    existing_loans = existing_result.fetchall()
    
    if existing_loans:
        conflicts = [f"Préstamo {row.loan_id} ya está en convenio {row.agreement_number}" for row in existing_loans]
        raise HTTPException(
            status_code=400,
            detail=f"Los siguientes préstamos ya están en convenios activos: {'; '.join(conflicts)}"
        )
    
    # ⭐ VALIDACIÓN: Verificar que no haya abonos parciales en el statement actual
    # Si hay un statement con paid_amount > 0, significa que el asociado ya hizo abonos
    # y esos abonos se perderían si creamos el convenio
    partial_payment_query = text("""
        SELECT 
            s.id as statement_id,
            s.statement_number,
            s.paid_amount,
            s.total_amount_collected,
            cp.cut_code,
            p.loan_id
        FROM associate_payment_statements s
        JOIN cut_periods cp ON cp.id = s.cut_period_id
        JOIN payments p ON p.loan_id = ANY(:loan_ids) AND p.cut_period_id = s.cut_period_id
        WHERE s.user_id = :associate_user_id
          AND s.paid_amount > 0
          AND p.status_id = 1  -- PENDING (aún no en convenio)
        LIMIT 1
    """)
    partial_result = await db.execute(partial_payment_query, {
        "loan_ids": data.loan_ids,
        "associate_user_id": associate_user_id
    })
    partial_row = partial_result.fetchone()
    
    if partial_row:
        raise HTTPException(
            status_code=400,
            detail=f"No se puede crear convenio: El statement {partial_row.statement_number} "
                   f"(período {partial_row.cut_code}) tiene ${float(partial_row.paid_amount):,.2f} en abonos. "
                   f"Debe primero completar o anular los abonos existentes."
        )
    
    # ⭐ Calculate SUM of associate_payment PENDING for these loans
    # This is the amount the associate owes CrediCuenta from these loans
    pending_query = text("""
        SELECT l.id as loan_id,
               COALESCE(SUM(p.associate_payment), 0) as pending_amount,
               COUNT(p.id) as pending_count
        FROM loans l
        LEFT JOIN payments p ON p.loan_id = l.id AND p.status_id = 1  -- PENDING
        WHERE l.id = ANY(:loan_ids)
        GROUP BY l.id
    """)
    pending_result = await db.execute(pending_query, {"loan_ids": data.loan_ids})
    pending_by_loan = {row.loan_id: row for row in pending_result.fetchall()}
    
    # Calculate total to move from pending_payments_total to consolidated_debt
    total_to_move = Decimal('0')
    loan_details = []
    for loan in loans:
        pending_info = pending_by_loan.get(loan.id)
        pending_amount = Decimal(str(pending_info.pending_amount)) if pending_info else Decimal('0')
        total_to_move += pending_amount
        loan_details.append({
            "loan_id": loan.id,
            "client_name": loan.client_name,
            "client_user_id": loan.client_user_id,
            "loan_amount": loan.amount,
            "pending_associate_payment": pending_amount
        })
    
    if total_to_move <= 0:
        raise HTTPException(
            status_code=400,
            detail="No hay pagos pendientes del asociado en estos préstamos"
        )
    
    # Calculate biweekly payment
    biweekly_payment = (total_to_move / data.payment_plan_biweeks).quantize(Decimal('0.01'))
    
    # Generate agreement number (using MAX to handle gaps from deleted records)
    count_query = text("""
        SELECT COALESCE(
            MAX(CAST(SUBSTRING(agreement_number FROM 'CONV-[0-9]+-([0-9]+)') AS INTEGER)), 0
        ) + 1 as next_num 
        FROM agreements
    """)
    count_result = await db.execute(count_query)
    next_num = count_result.scalar_one()
    agreement_number = f"CONV-{datetime.now().year}-{next_num:04d}"
    
    # ⭐ Calculate first payment date using the same biweekly logic as loans
    # Uses calculate_first_payment_date SQL function
    first_payment_query = text("SELECT calculate_first_payment_date(:start_date)")
    first_payment_result = await db.execute(first_payment_query, {"start_date": start_date})
    first_payment_date = first_payment_result.scalar_one()
    
    # Calculate end date (approximate based on biweeks)
    end_date = first_payment_date + timedelta(days=15 * data.payment_plan_biweeks)
    
    # ========== TRANSACCIÓN ATÓMICA ==========
    
    # 1. Capture available_credit BEFORE
    available_credit_before = Decimal(str(associate.credit_limit)) - Decimal(str(associate.pending_payments_total)) - Decimal(str(associate.consolidated_debt))
    
    # 2. Create agreement
    # NOTE: We insert BOTH legacy columns (payment_plan_months, monthly_payment_amount) AND new columns
    # (payment_plan_periods, period_payment_amount, payment_frequency) to satisfy existing constraints
    # and maintain backward compatibility. The legacy columns get equivalent values.
    insert_agreement = text("""
        INSERT INTO agreements (
            associate_profile_id,
            agreement_number,
            agreement_date,
            total_debt_amount,
            payment_plan_months,
            monthly_payment_amount,
            payment_plan_periods,
            period_payment_amount,
            payment_frequency,
            status,
            start_date,
            end_date,
            created_by,
            notes
        ) VALUES (
            :associate_profile_id,
            :agreement_number,
            CURRENT_DATE,
            :total_debt_amount,
            :payment_plan_periods,
            :period_payment_amount,
            :payment_plan_periods,
            :period_payment_amount,
            :payment_frequency,
            'ACTIVE',
            :start_date,
            :end_date,
            :created_by,
            :notes
        )
        RETURNING id
    """)
    
    result = await db.execute(insert_agreement, {
        "associate_profile_id": associate_profile_id,
        "agreement_number": agreement_number,
        "total_debt_amount": total_to_move,
        "payment_plan_periods": data.payment_plan_biweeks,
        "period_payment_amount": biweekly_payment,
        "payment_frequency": "biweekly",
        "start_date": start_date,
        "end_date": end_date,
        "created_by": current_user["user_id"],
        "notes": data.notes or f"Convenio creado desde {len(loans)} préstamo(s)"
    })
    
    agreement_id = result.scalar_one()
    
    # 3. Create agreement items from loans
    for loan_info in loan_details:
        if loan_info["pending_associate_payment"] > 0:
            await db.execute(text("""
                INSERT INTO agreement_items (
                    agreement_id, loan_id, client_user_id, debt_amount, debt_type, description
                ) VALUES (
                    :agreement_id, :loan_id, :client_user_id, :debt_amount, 'LOAN_TRANSFER', :description
                )
            """), {
                "agreement_id": agreement_id,
                "loan_id": loan_info["loan_id"],
                "client_user_id": loan_info["client_user_id"],
                "debt_amount": loan_info["pending_associate_payment"],
                "description": f"Pagos pendientes del préstamo - Cliente: {loan_info['client_name']}"
            })
    
    # 4. Mark all PENDING payments as IN_AGREEMENT
    await db.execute(text("""
        UPDATE payments
        SET status_id = 13,  -- IN_AGREEMENT
            marking_notes = :notes,
            updated_at = CURRENT_TIMESTAMP
        WHERE loan_id = ANY(:loan_ids)
          AND status_id = 1  -- Only PENDING
    """), {
        "loan_ids": data.loan_ids,
        "notes": f"Incluido en convenio {agreement_number}"
    })
    
    # 5. Mark loans as IN_AGREEMENT
    await db.execute(text("""
        UPDATE loans
        SET status_id = 9,  -- IN_AGREEMENT
            updated_at = CURRENT_TIMESTAMP
        WHERE id = ANY(:loan_ids)
    """), {
        "loan_ids": data.loan_ids
    })
    
    # 6. ⭐ MOVE from pending_payments_total to consolidated_debt (available_credit stays the same!)
    await db.execute(text("""
        UPDATE associate_profiles
        SET pending_payments_total = GREATEST(0, pending_payments_total - :amount),
            consolidated_debt = COALESCE(consolidated_debt, 0) + :amount,
            updated_at = CURRENT_TIMESTAMP
        WHERE id = :associate_profile_id
    """), {
        "associate_profile_id": associate_profile_id,
        "amount": total_to_move
    })
    
    # 7. Generate biweekly payment schedule
    payment_date = first_payment_date  # Use calculated first payment date
    
    for i in range(1, data.payment_plan_biweeks + 1):
        # Last payment adjusts for rounding differences
        if i == data.payment_plan_biweeks:
            payment_amount = total_to_move - (biweekly_payment * (data.payment_plan_biweeks - 1))
        else:
            payment_amount = biweekly_payment
        
        # ⭐ Find the correct cut_period_id for this payment date
        # Same logic as generate_payment_schedule: find period where period_end_date <= payment_date
        period_query = text("""
            SELECT id FROM cut_periods
            WHERE period_end_date < :payment_date
            ORDER BY period_end_date DESC
            LIMIT 1
        """)
        period_result = await db.execute(period_query, {"payment_date": payment_date})
        period_row = period_result.fetchone()
        cut_period_id = period_row.id if period_row else None
        
        await db.execute(text("""
            INSERT INTO agreement_payments (
                agreement_id, payment_number, payment_amount, payment_due_date, cut_period_id, status
            ) VALUES (
                :agreement_id, :payment_number, :payment_amount, :payment_due_date, :cut_period_id, 'PENDING'
            )
        """), {
            "agreement_id": agreement_id,
            "payment_number": i,
            "payment_amount": payment_amount,
            "payment_due_date": payment_date,
            "cut_period_id": cut_period_id
        })
        
        # ⭐ Calculate next biweekly date (day 15 ↔ last day of month)
        # Same logic as generate_amortization_schedule in PostgreSQL
        if payment_date.day == 15:
            # From day 15, go to last day of SAME month
            next_month_first = payment_date.replace(day=1) + relativedelta(months=1)
            payment_date = next_month_first - timedelta(days=1)
        else:
            # From last day of month, go to day 15 of NEXT month
            payment_date = (payment_date.replace(day=1) + relativedelta(months=1)).replace(day=15)
    
    # 8. Verify available_credit didn't change
    verify_query = text("""
        SELECT credit_limit, pending_payments_total, consolidated_debt,
               (credit_limit - pending_payments_total - consolidated_debt) as available_credit
        FROM associate_profiles
        WHERE id = :associate_profile_id
    """)
    verify_result = await db.execute(verify_query, {"associate_profile_id": associate_profile_id})
    verify_row = verify_result.fetchone()
    available_credit_after = Decimal(str(verify_row.available_credit))
    
    # Sanity check (should be equal or very close due to floating point)
    difference = abs(available_credit_before - available_credit_after)
    if difference > Decimal('0.01'):
        await db.rollback()
        raise HTTPException(
            status_code=500,
            detail=f"Error de integridad: available_credit cambió de {available_credit_before} a {available_credit_after}"
        )
    
    await db.commit()
    
    # 🔔 Notificación de convenio creado desde préstamos
    asyncio.create_task(notify.send(
        title="Convenio Creado desde Préstamos",
        message=f"• Número: {agreement_number}\n"
                f"• Asociado ID: {associate_profile_id}\n"
                f"• Deuda total: ${float(total_to_move):,.2f}\n"
                f"• Plazo: {data.payment_plan_biweeks} quincenas\n"
                f"• Pago quincenal: ${float(biweekly_payment):,.2f}\n"
                f"• Préstamos: {len(data.loan_ids)}\n"
                f"• Creado por: Usuario #{current_user['user_id']}",
        level="warning",
        to_discord=True
    ))
    
    # Return created agreement
    return await get_agreement_detail(agreement_id, db)


@router.get("/associates/{associate_profile_id}", response_model=list[AgreementDetailDTO])
async def get_associate_agreements(
    associate_profile_id: int,
    db: AsyncSession = Depends(get_async_db)
):
    """Obtiene convenios de un asociado específico."""
    repository = PgAgreementRepository(db)
    use_case = GetAssociateAgreementsUseCase(repository)
    agreements = await use_case.execute(associate_profile_id)
    
    # Get full details for each
    details = []
    for agreement in agreements:
        detail = await get_agreement_detail(agreement.id, db)
        details.append(detail)
    
    return details


@router.post("/{agreement_id}/payments/{payment_number}", response_model=AgreementDetailDTO)
async def register_agreement_payment(
    agreement_id: int,
    payment_number: int,
    data: RegisterPaymentDTO,
    db: AsyncSession = Depends(get_async_db)
):
    """
    Registra un pago en el convenio.
    
    ACCIONES:
    1. Valida que el pago existe y está pendiente
    2. Marca el pago como PAID
    3. Reduce consolidated_debt del asociado
    4. Si todos los pagos están hechos → convenio COMPLETED
    """
    # Get agreement
    agreement_query = text("SELECT * FROM agreements WHERE id = :agreement_id")
    agreement_result = await db.execute(agreement_query, {"agreement_id": agreement_id})
    agreement = agreement_result.fetchone()
    
    if not agreement:
        raise HTTPException(status_code=404, detail="Convenio no encontrado")
    
    if agreement.status != 'ACTIVE':
        raise HTTPException(
            status_code=400,
            detail=f"El convenio no está activo (Estado: {agreement.status})"
        )
    
    # Get payment
    payment_query = text("""
        SELECT * FROM agreement_payments
        WHERE agreement_id = :agreement_id AND payment_number = :payment_number
    """)
    payment_result = await db.execute(payment_query, {
        "agreement_id": agreement_id,
        "payment_number": payment_number
    })
    payment = payment_result.fetchone()
    
    if not payment:
        raise HTTPException(status_code=404, detail=f"Pago #{payment_number} no encontrado")
    
    if payment.status == 'PAID':
        raise HTTPException(status_code=400, detail="Este pago ya fue registrado")
    
    # Mark payment as PAID
    await db.execute(text("""
        UPDATE agreement_payments
        SET status = 'PAID',
            payment_date = CURRENT_DATE,
            payment_method_id = :payment_method_id,
            payment_reference = :payment_reference,
            updated_at = CURRENT_TIMESTAMP
        WHERE id = :payment_id
    """), {
        "payment_id": payment.id,
        "payment_method_id": data.payment_method_id,
        "payment_reference": data.payment_reference
    })
    
    # Reduce consolidated_debt
    # ⚠️ IMPORTANTE: Los pagos de convenio reducen consolidated_debt
    await db.execute(text("""
        UPDATE associate_profiles
        SET consolidated_debt = GREATEST(0, COALESCE(consolidated_debt, 0) - :amount),
            updated_at = CURRENT_TIMESTAMP
        WHERE id = :associate_profile_id
    """), {
        "associate_profile_id": agreement.associate_profile_id,
        "amount": payment.payment_amount
    })
    
    # Record in associate_debt_payments for tracking
    await db.execute(text("""
        INSERT INTO associate_debt_payments (
            associate_profile_id,
            payment_amount,
            payment_date,
            payment_method_id,
            payment_reference,
            registered_by,
            notes
        ) VALUES (
            :associate_profile_id,
            :amount,
            CURRENT_DATE,
            COALESCE(:payment_method_id, 1),
            :payment_reference,
            1,
            :notes
        )
    """), {
        "associate_profile_id": agreement.associate_profile_id,
        "amount": payment.payment_amount,
        "payment_method_id": data.payment_method_id,
        "payment_reference": data.payment_reference,
        "notes": f"Pago #{payment_number} de convenio {agreement.agreement_number}"
    })
    
    # Check if all payments are done
    pending_query = text("""
        SELECT COUNT(*) FROM agreement_payments
        WHERE agreement_id = :agreement_id AND status = 'PENDING'
    """)
    pending_result = await db.execute(pending_query, {"agreement_id": agreement_id})
    pending_count = pending_result.scalar_one()
    
    if pending_count == 0:
        # All payments done - mark as COMPLETED
        await db.execute(text("""
            UPDATE agreements
            SET status = 'COMPLETED',
                updated_at = CURRENT_TIMESTAMP
            WHERE id = :agreement_id
        """), {"agreement_id": agreement_id})
    
    await db.commit()
    
    return await get_agreement_detail(agreement_id, db)


@router.post("/{agreement_id}/cancel")
async def cancel_agreement(
    agreement_id: int,
    reason: Optional[str] = None,
    db: AsyncSession = Depends(get_async_db)
):
    """
    Cancela un convenio y revierte TODOS los cambios:
    1. Marca el convenio como CANCELLED
    2. Cancela los pagos pendientes del convenio (agreement_payments)
    3. Restaura pagos de préstamos: IN_AGREEMENT (13) → PENDING (1)
    4. Restaura préstamos: IN_AGREEMENT (9) → ACTIVE (2)
    5. Revierte saldos: consolidated_debt -= X, pending_payments_total += X
    
    IMPORTANTE: available_credit NO debe cambiar (es una operación inversa a crear convenio)
    """
    # Get agreement with all details
    query = text("""
        SELECT a.*, 
               ap.pending_payments_total, 
               ap.consolidated_debt,
               ap.credit_limit
        FROM agreements a
        JOIN associate_profiles ap ON ap.id = a.associate_profile_id
        WHERE a.id = :agreement_id
    """)
    result = await db.execute(query, {"agreement_id": agreement_id})
    agreement = result.fetchone()
    
    if not agreement:
        raise HTTPException(status_code=404, detail="Convenio no encontrado")
    
    if agreement.status in ['COMPLETED', 'CANCELLED']:
        raise HTTPException(
            status_code=400,
            detail=f"El convenio ya está {agreement.status.lower()}"
        )
    
    # ⭐ VALIDACIÓN: No permitir cancelar si el primer pago del convenio ya salió en un statement
    # Esto es más estricto: una vez que se genera el statement, el convenio no se puede cancelar
    first_payment_in_statement_query = text("""
        SELECT 
            ap.payment_due_date,
            ap.status as payment_status,
            ap.cut_period_id,
            EXISTS(
                SELECT 1 FROM associate_payment_statements aps
                WHERE aps.cut_period_id = ap.cut_period_id
                  AND aps.user_id = (
                      SELECT ap2.user_id FROM associate_profiles ap2 
                      WHERE ap2.id = a.associate_profile_id
                  )
            ) as has_statement
        FROM agreement_payments ap
        JOIN agreements a ON a.id = ap.agreement_id
        WHERE ap.agreement_id = :agreement_id
        ORDER BY ap.payment_number ASC
        LIMIT 1
    """)
    first_payment_result = await db.execute(first_payment_in_statement_query, {"agreement_id": agreement_id})
    first_payment = first_payment_result.fetchone()
    
    if first_payment and first_payment.has_statement:
        raise HTTPException(
            status_code=400,
            detail=f"No se puede cancelar el convenio: El primer pago (vencimiento: {first_payment.payment_due_date}) "
                   f"ya fue incluido en un statement generado. "
                   f"Los convenios no pueden revertirse después de aparecer en un statement."
        )
    
    # Get loan_ids from this agreement
    loans_query = text("""
        SELECT DISTINCT ai.loan_id 
        FROM agreement_items ai 
        WHERE ai.agreement_id = :agreement_id AND ai.loan_id IS NOT NULL
    """)
    loans_result = await db.execute(loans_query, {"agreement_id": agreement_id})
    loan_ids = [row.loan_id for row in loans_result.fetchall()]
    
    # Get paid amount (what was already paid shouldn't be restored)
    paid_query = text("""
        SELECT COALESCE(SUM(payment_amount), 0) as paid
        FROM agreement_payments
        WHERE agreement_id = :agreement_id AND status = 'PAID'
    """)
    paid_result = await db.execute(paid_query, {"agreement_id": agreement_id})
    paid_amount = Decimal(str(paid_result.scalar_one()))
    
    # Calculate amount to restore (what wasn't paid yet)
    remaining_debt = Decimal(str(agreement.total_debt_amount)) - paid_amount
    
    # Capture available_credit BEFORE for verification
    available_credit_before = (
        Decimal(str(agreement.credit_limit)) - 
        Decimal(str(agreement.pending_payments_total)) - 
        Decimal(str(agreement.consolidated_debt))
    )
    
    # ========== TRANSACCIÓN DE REVERSIÓN ==========
    
    # 1. Cancel agreement
    await db.execute(text("""
        UPDATE agreements
        SET status = 'CANCELLED',
            notes = COALESCE(notes, '') || E'\n[CANCELADO ' || CURRENT_TIMESTAMP || ']: ' || :reason,
            updated_at = CURRENT_TIMESTAMP
        WHERE id = :agreement_id
    """), {
        "agreement_id": agreement_id,
        "reason": reason or "Sin razón especificada"
    })
    
    # 2. Cancel pending agreement_payments
    await db.execute(text("""
        UPDATE agreement_payments
        SET status = 'CANCELLED',
            updated_at = CURRENT_TIMESTAMP
        WHERE agreement_id = :agreement_id AND status = 'PENDING'
    """), {"agreement_id": agreement_id})
    
    # 3. Restore loan payments: IN_AGREEMENT (13) → PENDING (1)
    # Solo si los préstamos NO están en OTRO convenio ACTIVE
    if loan_ids:
        # Check which loans are NOT in another ACTIVE agreement
        other_agreements_query = text("""
            SELECT DISTINCT ai.loan_id
            FROM agreement_items ai
            JOIN agreements a ON a.id = ai.agreement_id
            WHERE ai.loan_id = ANY(:loan_ids)
              AND a.id != :agreement_id
              AND a.status = 'ACTIVE'
        """)
        other_result = await db.execute(other_agreements_query, {
            "loan_ids": loan_ids,
            "agreement_id": agreement_id
        })
        loans_in_other_agreements = {row.loan_id for row in other_result.fetchall()}
        
        # Only restore loans NOT in other active agreements
        loans_to_restore = [lid for lid in loan_ids if lid not in loans_in_other_agreements]
        
        if loans_to_restore:
            # ⚠️ Desactivar trigger para evitar regeneración de pagos y doble conteo
            await db.execute(text("ALTER TABLE loans DISABLE TRIGGER trigger_generate_payment_schedule"))
            await db.execute(text("ALTER TABLE loans DISABLE TRIGGER trigger_update_associate_credit_on_loan_approval"))
            
            try:
                # Restore payments to PENDING
                await db.execute(text("""
                    UPDATE payments
                    SET status_id = 1,  -- PENDING
                        marking_notes = COALESCE(marking_notes, '') || E'\n[Restaurado por cancelación de convenio ' || :agreement_number || ']',
                        updated_at = CURRENT_TIMESTAMP
                    WHERE loan_id = ANY(:loan_ids)
                      AND status_id = 13  -- IN_AGREEMENT
                """), {
                    "loan_ids": loans_to_restore,
                    "agreement_number": agreement.agreement_number
                })
                
                # 4. Restore loans to ACTIVE
                await db.execute(text("""
                    UPDATE loans
                    SET status_id = 2,  -- ACTIVE
                        updated_at = CURRENT_TIMESTAMP
                    WHERE id = ANY(:loan_ids)
                      AND status_id = 9  -- IN_AGREEMENT
                """), {
                    "loan_ids": loans_to_restore
                })
            finally:
                # Reactivar triggers SIEMPRE
                await db.execute(text("ALTER TABLE loans ENABLE TRIGGER trigger_generate_payment_schedule"))
                await db.execute(text("ALTER TABLE loans ENABLE TRIGGER trigger_update_associate_credit_on_loan_approval"))
    
    # 5. Revert balance: MOVE from consolidated_debt BACK TO pending_payments_total
    if remaining_debt > 0:
        await db.execute(text("""
            UPDATE associate_profiles
            SET consolidated_debt = GREATEST(0, COALESCE(consolidated_debt, 0) - :remaining),
                pending_payments_total = COALESCE(pending_payments_total, 0) + :remaining,
                updated_at = CURRENT_TIMESTAMP
            WHERE id = :associate_profile_id
        """), {
            "associate_profile_id": agreement.associate_profile_id,
            "remaining": remaining_debt
        })
    
    # 6. Verify available_credit didn't change (sanity check)
    verify_query = text("""
        SELECT credit_limit, pending_payments_total, consolidated_debt,
               (credit_limit - pending_payments_total - consolidated_debt) as available_credit
        FROM associate_profiles
        WHERE id = :associate_profile_id
    """)
    verify_result = await db.execute(verify_query, {"associate_profile_id": agreement.associate_profile_id})
    verify_row = verify_result.fetchone()
    available_credit_after = Decimal(str(verify_row.available_credit))
    
    difference = abs(available_credit_before - available_credit_after)
    if difference > Decimal('0.01'):
        await db.rollback()
        raise HTTPException(
            status_code=500,
            detail=f"Error de integridad: available_credit cambió de {available_credit_before} a {available_credit_after}. Rollback ejecutado."
        )
    
    await db.commit()
    
    # 🔔 Notificación de convenio cancelado
    asyncio.create_task(notify.send(
        title="Convenio Cancelado",
        message=f"• Número: {agreement.agreement_number}\n"
                f"• ID Convenio: {agreement_id}\n"
                f"• Deuda restaurada: ${float(remaining_debt):,.2f}\n"
                f"• Préstamos restaurados: {len(loans_to_restore) if loan_ids else 0}",
        level="warning",
        to_discord=True
    ))
    
    return {
        "message": "Convenio cancelado exitosamente",
        "agreement_id": agreement_id,
        "agreement_number": agreement.agreement_number,
        "restored_amount": float(remaining_debt),
        "loans_restored": loans_to_restore if loan_ids else [],
        "available_credit_verified": float(available_credit_after)
    }


# ============== DEBT BREAKDOWN ENDPOINT ==============
# Este endpoint permite ver las deudas de un asociado que aún no están en convenio

class DebtBreakdownItemDTO(BaseModel):
    id: int
    associate_profile_id: int
    cut_period_id: Optional[int]
    debt_type: str
    loan_id: Optional[int]
    client_user_id: Optional[int]
    amount: Decimal
    description: Optional[str]
    is_liquidated: bool
    liquidation_date: Optional[datetime]
    liquidation_notes: Optional[str]
    created_at: datetime
    # Joined
    client_name: Optional[str] = None
    loan_amount: Optional[Decimal] = None


class PaginatedDebtBreakdownDTO(BaseModel):
    items: List[DebtBreakdownItemDTO]
    total: int
    total_debt: Decimal


# Este endpoint debería estar en /api/v1/associates/{id}/debt-breakdown
# pero como el frontend lo espera ahí, creamos un router secundario
debt_breakdown_router = APIRouter(prefix="/associates", tags=["debt-breakdown"])


@debt_breakdown_router.get("/{associate_profile_id}/debt-breakdown", response_model=PaginatedDebtBreakdownDTO)
async def get_debt_breakdown(
    associate_profile_id: int,
    is_liquidated: Optional[bool] = None,
    db: AsyncSession = Depends(get_async_db)
):
    """
    Obtiene el desglose de deudas de un asociado.
    
    Por defecto retorna solo deudas no liquidadas (disponibles para convenio).
    Use is_liquidated=true para ver deudas ya incluidas en convenios.
    """
    query = """
        SELECT 
            adb.*,
            CONCAT(c.first_name, ' ', c.last_name) as client_name,
            l.amount as loan_amount
        FROM associate_debt_breakdown adb
        LEFT JOIN users c ON adb.client_user_id = c.id
        LEFT JOIN loans l ON adb.loan_id = l.id
        WHERE adb.associate_profile_id = :associate_profile_id
    """
    params = {"associate_profile_id": associate_profile_id}
    
    if is_liquidated is not None:
        query += " AND adb.is_liquidated = :is_liquidated"
        params["is_liquidated"] = is_liquidated
    else:
        # Por defecto, solo no liquidadas
        query += " AND adb.is_liquidated = false"
    
    query += " ORDER BY adb.created_at DESC"
    
    result = await db.execute(text(query), params)
    rows = result.fetchall()
    
    items = []
    total_debt = Decimal('0')
    
    for row in rows:
        amount = Decimal(str(row.amount))
        if not row.is_liquidated:
            total_debt += amount
            
        items.append(DebtBreakdownItemDTO(
            id=row.id,
            associate_profile_id=row.associate_profile_id,
            cut_period_id=row.cut_period_id,
            debt_type=row.debt_type,
            loan_id=row.loan_id,
            client_user_id=row.client_user_id,
            amount=amount,
            description=row.description,
            is_liquidated=row.is_liquidated,
            liquidation_date=row.liquidation_date,
            liquidation_notes=row.liquidation_notes,
            created_at=row.created_at,
            client_name=row.client_name,
            loan_amount=row.loan_amount
        ))
    
    return PaginatedDebtBreakdownDTO(
        items=items,
        total=len(items),
        total_debt=total_debt
    )
