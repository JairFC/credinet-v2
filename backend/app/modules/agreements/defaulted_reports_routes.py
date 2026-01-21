"""
Defaulted Client Reports Router

FLUJO DE NEGOCIO:
1. Asociado reporta cliente moroso (POST /defaulted-reports)
   - Estado: PENDING
   - Requiere: loan_id, total_debt_amount (calculado en frontend), evidence_details

2. Admin revisa y aprueba/rechaza:
   - POST /defaulted-reports/{id}/approve
     - Pagos del préstamo → PAID_BY_ASSOCIATE
     - consolidated_debt del asociado aumenta
     - Se crea registro en associate_debt_breakdown
   
   - POST /defaulted-reports/{id}/reject
     - Estado → REJECTED
     - Se guarda rejection_reason

IMPORTANTE sobre consolidated_debt:
- consolidated_debt es SEPARADO de pending_payments_total
- pending_payments_total: lo que debe por préstamos activos (suma de associate_payment pendientes)
- consolidated_debt: deuda adicional (morosos aprobados, penalizaciones, etc.)
"""
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text
from pydantic import BaseModel
from typing import Optional, List
from decimal import Decimal
from datetime import datetime
from app.modules.auth.routes import get_current_user_id
from app.core.database import get_async_db

router = APIRouter(prefix="/defaulted-reports", tags=["defaulted-reports"])


# ============== DTOs ==============

class DefaultedReportCreateDTO(BaseModel):
    loan_id: int
    total_debt_amount: Decimal
    evidence_details: str

class DefaultedReportResponseDTO(BaseModel):
    id: int
    associate_profile_id: int
    loan_id: int
    client_user_id: int
    reported_at: datetime
    reported_by: int
    total_debt_amount: Decimal
    evidence_details: Optional[str]
    evidence_file_path: Optional[str]
    status: str
    approved_by: Optional[int]
    approved_at: Optional[datetime]
    rejection_reason: Optional[str]
    created_at: datetime
    updated_at: datetime
    # Joined fields
    client_name: Optional[str] = None
    associate_name: Optional[str] = None
    loan_amount: Optional[Decimal] = None

class PaginatedDefaultedReportsDTO(BaseModel):
    items: List[DefaultedReportResponseDTO]
    total: int
    limit: int
    offset: int


# ============== ENDPOINTS ==============

@router.get("", response_model=PaginatedDefaultedReportsDTO)
async def list_defaulted_reports(
    status: Optional[str] = None,
    associate_profile_id: Optional[int] = None,
    limit: int = 50,
    offset: int = 0,
    db: AsyncSession = Depends(get_async_db)
):
    """
    Lista todos los reportes de clientes morosos.
    Filtros opcionales: status, associate_profile_id
    """
    # Build query with joins to get names
    query = """
        SELECT 
            dcr.*,
            CONCAT(c.first_name, ' ', c.last_name) as client_name,
            CONCAT(a.first_name, ' ', a.last_name) as associate_name,
            l.amount as loan_amount
        FROM defaulted_client_reports dcr
        LEFT JOIN users c ON dcr.client_user_id = c.id
        LEFT JOIN associate_profiles ap ON dcr.associate_profile_id = ap.id
        LEFT JOIN users a ON ap.user_id = a.id
        LEFT JOIN loans l ON dcr.loan_id = l.id
        WHERE 1=1
    """
    params = {}
    
    if status:
        query += " AND dcr.status = :status"
        params["status"] = status
    
    if associate_profile_id:
        query += " AND dcr.associate_profile_id = :associate_profile_id"
        params["associate_profile_id"] = associate_profile_id
    
    # Count total
    count_query = f"SELECT COUNT(*) FROM ({query}) sub"
    count_result = await db.execute(text(count_query), params)
    total = count_result.scalar_one()
    
    # Add pagination and ordering
    query += " ORDER BY dcr.reported_at DESC LIMIT :limit OFFSET :offset"
    params["limit"] = limit
    params["offset"] = offset
    
    result = await db.execute(text(query), params)
    rows = result.fetchall()
    
    items = []
    for row in rows:
        items.append(DefaultedReportResponseDTO(
            id=row.id,
            associate_profile_id=row.associate_profile_id,
            loan_id=row.loan_id,
            client_user_id=row.client_user_id,
            reported_at=row.reported_at,
            reported_by=row.reported_by,
            total_debt_amount=row.total_debt_amount,
            evidence_details=row.evidence_details,
            evidence_file_path=row.evidence_file_path,
            status=row.status,
            approved_by=row.approved_by,
            approved_at=row.approved_at,
            rejection_reason=row.rejection_reason,
            created_at=row.created_at,
            updated_at=row.updated_at,
            client_name=row.client_name,
            associate_name=row.associate_name,
            loan_amount=row.loan_amount
        ))
    
    return PaginatedDefaultedReportsDTO(
        items=items,
        total=total,
        limit=limit,
        offset=offset
    )


@router.get("/{report_id}", response_model=DefaultedReportResponseDTO)
async def get_defaulted_report(
    report_id: int,
    db: AsyncSession = Depends(get_async_db)
):
    """Obtiene detalle de un reporte específico."""
    query = text("""
        SELECT 
            dcr.*,
            CONCAT(c.first_name, ' ', c.last_name) as client_name,
            CONCAT(a.first_name, ' ', a.last_name) as associate_name,
            l.amount as loan_amount
        FROM defaulted_client_reports dcr
        LEFT JOIN users c ON dcr.client_user_id = c.id
        LEFT JOIN associate_profiles ap ON dcr.associate_profile_id = ap.id
        LEFT JOIN users a ON ap.user_id = a.id
        LEFT JOIN loans l ON dcr.loan_id = l.id
        WHERE dcr.id = :report_id
    """)
    
    result = await db.execute(query, {"report_id": report_id})
    row = result.fetchone()
    
    if not row:
        raise HTTPException(status_code=404, detail=f"Reporte #{report_id} no encontrado")
    
    return DefaultedReportResponseDTO(
        id=row.id,
        associate_profile_id=row.associate_profile_id,
        loan_id=row.loan_id,
        client_user_id=row.client_user_id,
        reported_at=row.reported_at,
        reported_by=row.reported_by,
        total_debt_amount=row.total_debt_amount,
        evidence_details=row.evidence_details,
        evidence_file_path=row.evidence_file_path,
        status=row.status,
        approved_by=row.approved_by,
        approved_at=row.approved_at,
        rejection_reason=row.rejection_reason,
        created_at=row.created_at,
        updated_at=row.updated_at,
        client_name=row.client_name,
        associate_name=row.associate_name,
        loan_amount=row.loan_amount
    )


@router.post("", response_model=DefaultedReportResponseDTO, status_code=201)
async def create_defaulted_report(
    data: DefaultedReportCreateDTO,
    db: AsyncSession = Depends(get_async_db),
    current_user_id: int = Depends(get_current_user_id)
):
    """
    Crea un nuevo reporte de cliente moroso.
    
    IMPORTANTE:
    - total_debt_amount debe ser la suma de associate_payment de los pagos pendientes
    - El reporte se crea en estado PENDING
    - Requiere aprobación de admin para afectar el consolidated_debt
    
    Body:
    - loan_id: ID del préstamo con el cliente moroso
    - total_debt_amount: Suma de associate_payment de pagos pendientes (calculado en frontend)
    - evidence_details: Descripción de la evidencia de morosidad
    """
    # Validate loan exists and get associate_profile_id
    loan_query = text("""
        SELECT 
            l.id, l.user_id, l.associate_user_id,
            ap.id as associate_profile_id,
            ls.name as status_name
        FROM loans l
        JOIN loan_statuses ls ON l.status_id = ls.id
        JOIN associate_profiles ap ON ap.user_id = l.associate_user_id
        WHERE l.id = :loan_id
    """)
    
    result = await db.execute(loan_query, {"loan_id": data.loan_id})
    loan = result.fetchone()
    
    if not loan:
        raise HTTPException(status_code=404, detail=f"Préstamo #{data.loan_id} no encontrado")
    
    if loan.status_name not in ('APPROVED', 'ACTIVE'):
        raise HTTPException(
            status_code=400, 
            detail=f"El préstamo #{data.loan_id} no está activo (Estado: {loan.status_name})"
        )
    
    # Check if there's already a pending/approved report for this loan
    existing_query = text("""
        SELECT id, status FROM defaulted_client_reports 
        WHERE loan_id = :loan_id AND status IN ('PENDING', 'IN_REVIEW', 'APPROVED')
    """)
    existing = await db.execute(existing_query, {"loan_id": data.loan_id})
    existing_report = existing.fetchone()
    
    if existing_report:
        raise HTTPException(
            status_code=400,
            detail=f"Ya existe un reporte ({existing_report.status}) para el préstamo #{data.loan_id}"
        )
    
    # Validate evidence
    if not data.evidence_details or len(data.evidence_details.strip()) < 20:
        raise HTTPException(
            status_code=400,
            detail="La descripción de evidencia debe tener al menos 20 caracteres"
        )
    
    # Create report using SQL function
    # Note: reported_by should be the current user, but for simplicity we use associate_user_id
    insert_query = text("""
        INSERT INTO defaulted_client_reports (
            associate_profile_id,
            loan_id,
            client_user_id,
            reported_by,
            total_debt_amount,
            evidence_details,
            status
        ) VALUES (
            :associate_profile_id,
            :loan_id,
            :client_user_id,
            :reported_by,
            :total_debt_amount,
            :evidence_details,
            'PENDING'
        )
        RETURNING id
    """)
    
    result = await db.execute(insert_query, {
        "associate_profile_id": loan.associate_profile_id,
        "loan_id": data.loan_id,
        "client_user_id": loan.user_id,
        "reported_by": current_user_id,
        "total_debt_amount": data.total_debt_amount,
        "evidence_details": data.evidence_details.strip()
    })
    
    report_id = result.scalar_one()
    await db.commit()
    
    # Fetch and return the created report
    return await get_defaulted_report(report_id, db)


@router.post("/{report_id}/approve", response_model=DefaultedReportResponseDTO)
async def approve_defaulted_report(
    report_id: int,
    notes: Optional[str] = None,
    db: AsyncSession = Depends(get_async_db),
    current_user_id: int = Depends(get_current_user_id)
):
    """
    Aprueba un reporte de cliente moroso.
    
    ACCIONES:
    1. Cambia status del reporte a APPROVED
    2. Marca los pagos pendientes del préstamo como PAID_BY_ASSOCIATE
    3. Crea registro en associate_debt_breakdown
    4. Aumenta consolidated_debt del asociado
    
    IMPORTANTE sobre consolidated_debt:
    - consolidated_debt representa deuda ADICIONAL del asociado (no relacionada con pending_payments_total)
    - pending_payments_total se calcula de los préstamos activos (sum of associate_payment)
    - consolidated_debt se usa para morosos aprobados, penalizaciones, etc.
    """
    # Get report
    report_query = text("""
        SELECT * FROM defaulted_client_reports WHERE id = :report_id
    """)
    result = await db.execute(report_query, {"report_id": report_id})
    report = result.fetchone()
    
    if not report:
        raise HTTPException(status_code=404, detail=f"Reporte #{report_id} no encontrado")
    
    if report.status != 'PENDING':
        raise HTTPException(
            status_code=400,
            detail=f"El reporte ya fue procesado (Estado: {report.status})"
        )
    
    # Get current cut period
    period_query = text("SELECT id FROM cut_periods WHERE is_open = true ORDER BY id DESC LIMIT 1")
    period_result = await db.execute(period_query)
    period_row = period_result.fetchone()
    cut_period_id = period_row.id if period_row else 1  # Fallback to 1
    
    # Get PAID_BY_ASSOCIATE status id
    status_query = text("SELECT id FROM payment_statuses WHERE name = 'PAID_BY_ASSOCIATE'")
    status_result = await db.execute(status_query)
    status_row = status_result.fetchone()
    
    if not status_row:
        # Create the status if it doesn't exist
        await db.execute(text("""
            INSERT INTO payment_statuses (name, description, is_active, is_real_payment)
            VALUES ('PAID_BY_ASSOCIATE', 'Pago asumido por asociado (cliente moroso)', true, false)
            ON CONFLICT (name) DO NOTHING
        """))
        status_result = await db.execute(status_query)
        status_row = status_result.fetchone()
    
    paid_by_associate_id = status_row.id if status_row else 5  # Fallback
    
    # 1. Update report status to APPROVED
    await db.execute(text("""
        UPDATE defaulted_client_reports
        SET status = 'APPROVED',
            approved_by = :approved_by,
            approved_at = CURRENT_TIMESTAMP,
            updated_at = CURRENT_TIMESTAMP
        WHERE id = :report_id
    """), {
        "report_id": report_id,
        "approved_by": current_user_id
    })
    
    # 2. Mark pending payments as PAID_BY_ASSOCIATE
    # This effectively "closes" the payments without actual payment
    await db.execute(text("""
        UPDATE payments
        SET status_id = :paid_by_associate_id,
            marking_notes = :notes,
            updated_at = CURRENT_TIMESTAMP
        WHERE loan_id = :loan_id
          AND status_id = 1  -- Only PENDING payments
    """), {
        "loan_id": report.loan_id,
        "paid_by_associate_id": paid_by_associate_id,
        "notes": f"Cliente moroso aprobado - Reporte #{report_id}"
    })
    
    # 3. Create record in associate_debt_breakdown
    await db.execute(text("""
        INSERT INTO associate_debt_breakdown (
            associate_profile_id,
            cut_period_id,
            debt_type,
            loan_id,
            client_user_id,
            amount,
            description,
            is_liquidated
        ) VALUES (
            :associate_profile_id,
            :cut_period_id,
            'DEFAULTED_CLIENT',
            :loan_id,
            :client_user_id,
            :amount,
            :description,
            false
        )
    """), {
        "associate_profile_id": report.associate_profile_id,
        "cut_period_id": cut_period_id,
        "loan_id": report.loan_id,
        "client_user_id": report.client_user_id,
        "amount": report.total_debt_amount,
        "description": f"Cliente moroso aprobado - Reporte #{report_id}"
    })
    
    # 4. Update consolidated_debt of associate
    # ⚠️ IMPORTANTE: Esto es ADICIONAL a pending_payments_total
    await db.execute(text("""
        UPDATE associate_profiles
        SET consolidated_debt = COALESCE(consolidated_debt, 0) + :debt_amount,
            updated_at = CURRENT_TIMESTAMP
        WHERE id = :associate_profile_id
    """), {
        "associate_profile_id": report.associate_profile_id,
        "debt_amount": report.total_debt_amount
    })
    
    # 5. Mark loan as having defaulted client (optional: change loan status)
    await db.execute(text("""
        UPDATE loans
        SET notes = COALESCE(notes, '') || E'\n[MOROSO] Cliente reportado como moroso - Reporte #' || :report_id || ' aprobado el ' || CURRENT_DATE,
            updated_at = CURRENT_TIMESTAMP
        WHERE id = :loan_id
    """), {
        "loan_id": report.loan_id,
        "report_id": report_id
    })
    
    await db.commit()
    
    # Return updated report
    return await get_defaulted_report(report_id, db)


@router.post("/{report_id}/reject", response_model=DefaultedReportResponseDTO)
async def reject_defaulted_report(
    report_id: int,
    rejection_reason: str,
    db: AsyncSession = Depends(get_async_db)
):
    """
    Rechaza un reporte de cliente moroso.
    
    El préstamo continúa activo y los pagos siguen pendientes.
    """
    if not rejection_reason or len(rejection_reason.strip()) < 10:
        raise HTTPException(
            status_code=400,
            detail="Debe proporcionar una razón de rechazo (mínimo 10 caracteres)"
        )
    
    # Get report
    report_query = text("""
        SELECT * FROM defaulted_client_reports WHERE id = :report_id
    """)
    result = await db.execute(report_query, {"report_id": report_id})
    report = result.fetchone()
    
    if not report:
        raise HTTPException(status_code=404, detail=f"Reporte #{report_id} no encontrado")
    
    if report.status != 'PENDING':
        raise HTTPException(
            status_code=400,
            detail=f"El reporte ya fue procesado (Estado: {report.status})"
        )
    
    # Update report status to REJECTED
    await db.execute(text("""
        UPDATE defaulted_client_reports
        SET status = 'REJECTED',
            rejection_reason = :rejection_reason,
            updated_at = CURRENT_TIMESTAMP
        WHERE id = :report_id
    """), {
        "report_id": report_id,
        "rejection_reason": rejection_reason.strip()
    })
    
    await db.commit()
    
    # Return updated report
    return await get_defaulted_report(report_id, db)


@router.get("/associate/{associate_profile_id}", response_model=List[DefaultedReportResponseDTO])
async def get_associate_defaulted_reports(
    associate_profile_id: int,
    db: AsyncSession = Depends(get_async_db)
):
    """Lista reportes de morosos de un asociado específico."""
    result = await list_defaulted_reports(
        associate_profile_id=associate_profile_id,
        limit=100,
        offset=0,
        db=db
    )
    return result.items
