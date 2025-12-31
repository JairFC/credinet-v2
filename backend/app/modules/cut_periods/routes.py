"""Rutas FastAPI para cut_periods"""
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text
from typing import List, Dict, Any, Optional
from datetime import date, datetime
from pydantic import BaseModel
from decimal import Decimal

from app.core.database import get_async_db
from app.modules.cut_periods.application.dtos import (
    CutPeriodResponseDTO,
    CutPeriodListItemDTO,
    PaginatedCutPeriodsDTO,
)
from app.modules.cut_periods.application.use_cases import (
    ListCutPeriodsUseCase,
    GetActiveCutPeriodUseCase,
)
from app.modules.cut_periods.infrastructure.repositories.pg_cut_period_repository import PgCutPeriodRepository


router = APIRouter(prefix="/cut-periods", tags=["Cut Periods"])


# DTO para actualización de período
class UpdatePeriodStatusDTO(BaseModel):
    status_id: int


def generate_cut_code(period_start: date, cut_number: int) -> str:
    """Genera código de corte en formato MesNN-YYYY (ej: Nov01-2025)"""
    months = [
        'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
        'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ]
    month_name = months[period_start.month - 1]
    # cut_number impar = primer corte del mes (01), par = segundo corte (02)
    corte_num = '01' if cut_number % 2 == 1 else '02'
    return f"{month_name}{corte_num}-{period_start.year}"


def get_cut_period_repository(db: AsyncSession = Depends(get_async_db)) -> PgCutPeriodRepository:
    """Dependency injection del repositorio de periodos"""
    return PgCutPeriodRepository(db)


@router.get("", response_model=PaginatedCutPeriodsDTO)
async def list_cut_periods(
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0),
    repo: PgCutPeriodRepository = Depends(get_cut_period_repository),
):
    """Lista todos los periodos de corte con paginación"""
    try:
        use_case = ListCutPeriodsUseCase(repo)
        periods = await use_case.execute(limit, offset)
        total = await repo.count()
        
        items = [
            CutPeriodListItemDTO(
                id=p.id,
                cut_number=p.cut_number,
                cut_code=p.cut_code,  # Usar el código de la BD directamente
                period_start_date=p.period_start_date,
                period_end_date=p.period_end_date,
                payment_date=p.period_end_date,  # Fecha de pago es el final del período
                cut_date=p.period_end_date,      # Fecha de corte es el final del período
                status_id=p.status_id,
                collection_percentage=p.get_collection_percentage(),
            )
            for p in periods
        ]
        
        return PaginatedCutPeriodsDTO(
            items=items,
            total=total,
            limit=limit,
            offset=offset,
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error listing cut periods: {str(e)}"
        )


@router.get("/active", response_model=CutPeriodResponseDTO)
async def get_active_cut_period(
    repo: PgCutPeriodRepository = Depends(get_cut_period_repository),
):
    """Obtiene el periodo de corte activo actual"""
    try:
        use_case = GetActiveCutPeriodUseCase(repo)
        period = await use_case.execute()
        
        if not period:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="No active cut period found"
            )
        
        return CutPeriodResponseDTO(
            id=period.id,
            cut_number=period.cut_number,
            period_start_date=period.period_start_date,
            period_end_date=period.period_end_date,
            status_id=period.status_id,
            total_payments_expected=period.total_payments_expected,
            total_payments_received=period.total_payments_received,
            total_commission=period.total_commission,
            created_by=period.created_by,
            closed_by=period.closed_by,
            created_at=period.created_at,
            updated_at=period.updated_at,
            collection_percentage=period.get_collection_percentage(),
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error fetching active cut period: {str(e)}"
        )


@router.get("/{period_id}/statements")
async def get_period_statements(
    period_id: int,
    include_all_associates: bool = Query(False, description="Incluir asociados sin statement en el período"),
    db: AsyncSession = Depends(get_async_db),
):
    """
    Obtiene todos los statements de un período específico.
    
    Con include_all_associates=True también incluye asociados activos
    que no tienen statement en este período (para visualización de "sin pagos").
    """
    try:
        # Verificar que el período existe
        result = await db.execute(
            text("""
            SELECT id, cut_code FROM cut_periods WHERE id = :id
            """),
            {"id": period_id}
        )
        period = result.fetchone()
        
        if not period:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Period {period_id} not found"
            )
        
        # Usar cut_code directamente de la BD
        cut_code = period.cut_code
        
        # Obtener statements del período con información del asociado
        # ✅ CORREGIDO: Usar nombres de columnas correctos de associate_payment_statements
        result = await db.execute(
            text("""
            SELECT 
                aps.id,
                aps.user_id as associate_id,
                aps.statement_number,
                aps.total_amount_collected,
                aps.total_to_credicuenta,
                aps.commission_earned,
                aps.paid_amount,
                aps.late_fee_amount,
                aps.status_id,
                aps.total_payments_count,
                aps.commission_rate_applied,
                aps.generated_date,
                aps.due_date,
                aps.created_at,
                u.first_name || ' ' || u.last_name AS associate_name,
                ss.name AS status_name
            FROM associate_payment_statements aps
            LEFT JOIN users u ON u.id = aps.user_id
            LEFT JOIN statement_statuses ss ON ss.id = aps.status_id
            WHERE aps.cut_period_id = :period_id
            ORDER BY u.last_name, u.first_name
            """),
            {"period_id": period_id}
        )
        
        statements = result.fetchall()
        
        # Construir lista de statements con pagos
        statements_data = [
            {
                "id": s[0],
                "associate_id": s[1],
                "statement_number": s[2],
                "total_amount_collected": float(s[3]) if s[3] else 0.0,
                "total_to_credicuenta": float(s[4]) if s[4] else 0.0,
                "commission_earned": float(s[5]) if s[5] else 0.0,
                "paid_amount": float(s[6]) if s[6] else 0.0,
                "late_fee_amount": float(s[7]) if s[7] else 0.0,
                "status_id": s[8],
                "total_payments_count": s[9],
                "commission_rate_applied": float(s[10]) if s[10] else 0.0,
                "generated_date": s[11].isoformat() if s[11] else None,
                "due_date": s[12].isoformat() if s[12] else None,
                "created_at": s[13].isoformat() if s[13] else None,
                "associate_name": s[14],
                "status_name": s[15],
                "remaining_amount": float(s[4] + s[7] - (s[6] or 0)) if s[4] else 0.0,
                "cut_code": cut_code,
                "has_payments": True  # Tiene statement = tenía pagos
            }
            for s in statements
        ]
        
        # IDs de asociados con statements
        associates_with_statements = {s["associate_id"] for s in statements_data}
        
        # Si include_all_associates, agregar asociados activos sin statement
        associates_without_data = []
        if include_all_associates:
            all_associates_result = await db.execute(
                text("""
                SELECT DISTINCT 
                    u.id as associate_id,
                    u.first_name || ' ' || u.last_name as associate_name,
                    u.last_name,
                    u.first_name
                FROM users u
                JOIN user_roles ur ON ur.user_id = u.id
                JOIN roles r ON r.id = ur.role_id
                WHERE r.name = 'asociado' 
                  AND u.active = true
                ORDER BY u.last_name, u.first_name
                """)
            )
            
            all_associates = all_associates_result.fetchall()
            
            for a in all_associates:
                if a.associate_id not in associates_with_statements:
                    associates_without_data.append({
                        "id": None,  # Sin statement
                        "associate_id": a.associate_id,
                        "statement_number": None,
                        "total_amount_collected": 0.0,
                        "total_to_credicuenta": 0.0,
                        "commission_earned": 0.0,
                        "paid_amount": 0.0,
                        "late_fee_amount": 0.0,
                        "status_id": None,  # Sin estado
                        "total_payments_count": 0,
                        "commission_rate_applied": 0.0,
                        "generated_date": None,
                        "due_date": None,
                        "created_at": None,
                        "associate_name": a.associate_name,
                        "status_name": "Sin pagos",
                        "remaining_amount": 0.0,
                        "cut_code": cut_code,
                        "has_payments": False  # Sin statement = sin pagos
                    })
        
        # Combinar: primero con pagos, luego sin pagos
        all_data = statements_data + associates_without_data
        
        return {
            "success": True,
            "data": all_data,
            "counts": {
                "with_payments": len(statements_data),
                "without_payments": len(associates_without_data),
                "total": len(all_data)
            }
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error fetching period statements: {str(e)}"
        )


@router.get("/{period_id}/payments-preview")
async def get_period_payments_preview(
    period_id: int,
    include_all_associates: bool = Query(True, description="Incluir asociados sin pagos en el período"),
    include_payments_detail: bool = Query(False, description="Incluir array de pagos detallado (más pesado)"),
    db: AsyncSession = Depends(get_async_db),
):
    """
    Obtiene vista previa de pagos de préstamos para un período.
    
    Muestra los pagos individuales de préstamos que vencen en el período,
    agrupados por asociado. Con include_all_associates=True también incluye
    asociados activos sin pagos en el período (para visibilidad completa).
    
    Por defecto NO incluye el detalle de pagos (include_payments_detail=false)
    para mejor rendimiento. Los pagos se cargan on-demand al expandir.
    """
    try:
        # Verificar período y obtener datos
        period_result = await db.execute(
            text("""
            SELECT id, cut_code, period_start_date, period_end_date, cut_number, status_id 
            FROM cut_periods WHERE id = :id
            """),
            {"id": period_id}
        )
        period = period_result.fetchone()
        
        if not period:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Period {period_id} not found"
            )
        
        cut_code = period.cut_code
        
        # Obtener pagos de préstamos que vencen en este período
        payments_result = await db.execute(
            text("""
            SELECT 
                p.id,
                p.loan_id,
                p.payment_number,
                p.expected_amount,
                p.commission_amount,
                p.associate_payment,
                p.amount_paid,
                p.payment_due_date,
                p.status_id,
                l.associate_user_id as associate_id,
                COALESCE(ua.first_name || ' ' || ua.last_name, 'Sin Asociado') as associate_name,
                l.user_id as client_id,
                COALESCE(uc.first_name || ' ' || uc.last_name, 'Cliente') as client_name,
                ps.name as payment_status
            FROM payments p
            JOIN loans l ON l.id = p.loan_id
            LEFT JOIN users ua ON ua.id = l.associate_user_id
            LEFT JOIN users uc ON uc.id = l.user_id
            LEFT JOIN payment_statuses ps ON ps.id = p.status_id
            WHERE p.cut_period_id = :period_id
            ORDER BY ua.last_name, ua.first_name, p.payment_due_date
            """),
            {"period_id": period_id}
        )
        
        payments = payments_result.fetchall()
        
        # Agrupar por asociado
        associates_map = {}
        for p in payments:
            associate_id = p.associate_id or 0
            if associate_id not in associates_map:
                associates_map[associate_id] = {
                    "associate_id": associate_id,
                    "associate_name": p.associate_name,
                    "total_collected": 0.0,
                    "total_commission": 0.0,
                    "total_to_credicuenta": 0.0,
                    "total_paid": 0.0,
                    "payment_count": 0,
                    "has_payments": True,
                }
                # Solo incluir array de payments si se solicita (más pesado)
                if include_payments_detail:
                    associates_map[associate_id]["payments"] = []
            
            expected = float(p.expected_amount) if p.expected_amount else 0.0
            commission = float(p.commission_amount) if p.commission_amount else 0.0
            associate_payment = float(p.associate_payment) if p.associate_payment else 0.0
            paid = float(p.amount_paid) if p.amount_paid else 0.0
            
            associates_map[associate_id]["total_collected"] += expected
            associates_map[associate_id]["total_commission"] += commission
            associates_map[associate_id]["total_to_credicuenta"] += associate_payment
            associates_map[associate_id]["total_paid"] += paid
            associates_map[associate_id]["payment_count"] += 1
            
            # Solo agregar detalle si se solicita
            if include_payments_detail:
                associates_map[associate_id]["payments"].append({
                    "id": p.id,
                    "loan_id": p.loan_id,
                    "payment_number": p.payment_number,
                    "expected_amount": expected,
                    "commission_amount": commission,
                    "associate_payment": associate_payment,
                    "amount_paid": paid,
                    "payment_due_date": p.payment_due_date.isoformat() if p.payment_due_date else None,
                    "status_id": p.status_id,
                    "status": p.payment_status,
                    "client_id": p.client_id,
                    "client_name": p.client_name
                })
        
        # Calcular balance pendiente para cada asociado
        for assoc in associates_map.values():
            assoc["balance"] = assoc["total_to_credicuenta"] - assoc["total_paid"]
        
        # Si include_all_associates, agregar asociados activos sin pagos en este período
        if include_all_associates:
            all_associates_result = await db.execute(
                text("""
                SELECT DISTINCT 
                    u.id as associate_id,
                    u.first_name || ' ' || u.last_name as associate_name,
                    u.last_name,
                    u.first_name
                FROM users u
                JOIN user_roles ur ON ur.user_id = u.id
                JOIN roles r ON r.id = ur.role_id
                WHERE r.name = 'asociado' 
                  AND u.active = true
                  AND u.id NOT IN (
                      SELECT DISTINCT l.associate_user_id 
                      FROM loans l 
                      JOIN payments p ON p.loan_id = l.id 
                      WHERE p.cut_period_id = :period_id
                        AND l.associate_user_id IS NOT NULL
                  )
                ORDER BY u.last_name, u.first_name
                """),
                {"period_id": period_id}
            )
            
            associates_without_payments = all_associates_result.fetchall()
            
            for a in associates_without_payments:
                if a.associate_id not in associates_map:
                    associates_map[a.associate_id] = {
                        "associate_id": a.associate_id,
                        "associate_name": a.associate_name,
                        "total_collected": 0.0,
                        "total_commission": 0.0,
                        "total_to_credicuenta": 0.0,
                        "total_paid": 0.0,
                        "payment_count": 0,
                        "balance": 0.0,
                        "has_payments": False,
                        "payments": []
                    }
        
        # Ordenar: primero los que tienen pagos, luego por nombre
        sorted_associates = sorted(
            associates_map.values(),
            key=lambda x: (not x["has_payments"], x["associate_name"] or "")
        )
        
        # Contadores
        associates_with_payments = [a for a in sorted_associates if a["has_payments"]]
        associates_without = [a for a in sorted_associates if not a["has_payments"]]
        
        return {
            "success": True,
            "period": {
                "id": period.id,
                "cut_code": cut_code,
                "start_date": period.period_start_date.isoformat(),
                "end_date": period.period_end_date.isoformat(),
                "status_id": period.status_id
            },
            "data": sorted_associates,
            "totals": {
                "total_collected": sum(a["total_collected"] for a in associates_with_payments),
                "total_commission": sum(a["total_commission"] for a in associates_with_payments),
                "total_to_credicuenta": sum(a["total_to_credicuenta"] for a in associates_with_payments),
                "total_paid": sum(a["total_paid"] for a in associates_with_payments),
                "total_balance": sum(a["balance"] for a in associates_with_payments),
                "associate_count": len(associates_with_payments),
                "associate_count_total": len(sorted_associates),
                "associates_without_payments": len(associates_without),
                "payment_count": sum(a["payment_count"] for a in associates_with_payments)
            }
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error fetching payments preview: {str(e)}"
        )


@router.patch("/{period_id}")
async def update_period_status(
    period_id: int,
    data: UpdatePeriodStatusDTO,
    force: bool = Query(False, description="🧪 TEST: Forzar cambio sin validar transiciones (solo para demo)"),
    db: AsyncSession = Depends(get_async_db),
):
    """
    Actualiza el estado de un período de corte.
    
    Transiciones válidas:
    - CUTOFF (3) → COLLECTING (4): Cierra el corte, genera statements para asociados
    - COLLECTING (4) → SETTLING (6): Pone el período en modo liquidación
    - SETTLING (6) → CLOSED (5): Cierra definitivamente, transfiere deudas pendientes
    
    Estados:
    - PENDING (1): Período futuro, aún no activo
    - CUTOFF (3): Período en corte, recibiendo pagos
    - COLLECTING (4): Corte cerrado, generando cobranza
    - SETTLING (6): En liquidación final
    - CLOSED (5): Cerrado definitivamente
    
    🧪 TEST: Usar ?force=true para saltarse validaciones (solo demo)
    """
    try:
        # Verificar que el período existe y obtener estado actual
        result = await db.execute(
            text("SELECT id, status_id, cut_code FROM cut_periods WHERE id = :id"),
            {"id": period_id}
        )
        period = result.fetchone()
        
        if not period:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Período {period_id} no encontrado"
            )
        
        current_status = period.status_id
        new_status = data.status_id
        
        # 🧪 TEST: Si force=true, saltarse validación de transiciones
        if not force:
            # Validar transiciones permitidas
            valid_transitions = {
                3: [4],       # CUTOFF → COLLECTING
                4: [6],       # COLLECTING → SETTLING  
                6: [5],       # SETTLING → CLOSED
            }
            
            if current_status not in valid_transitions:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"El período está en estado {current_status} que no permite transiciones"
                )
            
            if new_status not in valid_transitions[current_status]:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Transición inválida: {current_status} → {new_status}. Permitidas: {valid_transitions[current_status]}"
                )
        
        # Ejecutar acciones específicas según la transición
        if current_status == 3 and new_status == 4:  # CUTOFF → COLLECTING
            # Generar statements para cada asociado con pagos en el período
            await _generate_statements_for_period(db, period_id)
        
        elif current_status == 4 and new_status == 6:  # COLLECTING → SETTLING
            # Marcar statements no pagados como vencidos
            await _mark_overdue_statements(db, period_id)
            
        elif current_status == 6 and new_status == 5:  # SETTLING → CLOSED
            # Transferir deudas pendientes a balances acumulados
            await _transfer_pending_debts(db, period_id)
        
        # Actualizar el estado del período
        await db.execute(
            text("UPDATE cut_periods SET status_id = :status, updated_at = NOW() WHERE id = :id"),
            {"status": new_status, "id": period_id}
        )
        await db.commit()
        
        # Obtener datos actualizados
        result = await db.execute(
            text("""
            SELECT cp.*, cps.name as status_name 
            FROM cut_periods cp
            LEFT JOIN cut_period_statuses cps ON cps.id = cp.status_id
            WHERE cp.id = :id
            """),
            {"id": period_id}
        )
        updated = result.fetchone()
        
        return {
            "success": True,
            "message": f"Período actualizado a estado {updated.status_name}",
            "data": {
                "id": updated.id,
                "cut_code": updated.cut_code,
                "status_id": updated.status_id,
                "status_name": updated.status_name
            }
        }
        
    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error actualizando período: {str(e)}"
        )


@router.post("/advance-periods")
async def advance_periods(
    dry_run: bool = Query(False, description="Solo mostrar qué cambios se harían sin ejecutarlos"),
    db: AsyncSession = Depends(get_async_db),
):
    """
    Avanza los períodos automáticamente según la fecha actual.
    
    Este endpoint debería ejecutarse con un cron job en los días de corte (8 y 23).
    
    Lógica de negocio:
    1. El período ACTUAL (donde cae la fecha de hoy) permanece en PENDING
       - Aquí se siguen registrando pagos de préstamos
    2. El período ANTERIOR INMEDIATO (recién terminado) pasa a COLLECTING
       - Se generan statements, inicia el cobro a asociados
    3. Períodos más antiguos en COLLECTING pasan a SETTLING
       - Ya pasó su tiempo de cobro, entran en liquidación
    
    Flujo de estados:
    PENDING (1) → CUTOFF (3) → COLLECTING (4) → SETTLING (6) → CLOSED (5)
    
    Estados:
    - PENDING (1): Período actual, recibiendo pagos de préstamos
    - CUTOFF (3): Corte ejecutado, statements en borrador
    - COLLECTING (4): EN COBRO - Asociados deben pagar sus statements
    - SETTLING (6): Liquidación - Preparar deudas para cierre
    - CLOSED (5): Cerrado definitivamente
    """
    try:
        today = date.today()
        changes = []
        
        # 1. Obtener el período ACTUAL (donde cae hoy)
        result = await db.execute(
            text("""
            SELECT id, cut_code, period_start_date, period_end_date, status_id
            FROM cut_periods
            WHERE period_start_date <= :today AND period_end_date >= :today
            ORDER BY period_start_date DESC
            LIMIT 1
            """),
            {"today": today}
        )
        current_period = result.fetchone()
        
        if not current_period:
            return {
                "success": True,
                "message": "No se encontró período para la fecha actual",
                "changes": [],
                "date_checked": today.isoformat()
            }
        
        # 2. Obtener el período ANTERIOR INMEDIATO (el que recién terminó)
        #    Este debería estar en COLLECTING si ya pasó su corte
        result = await db.execute(
            text("""
            SELECT id, cut_code, period_start_date, period_end_date, status_id
            FROM cut_periods
            WHERE period_end_date < :current_start
            ORDER BY period_end_date DESC
            LIMIT 1
            """),
            {"current_start": current_period.period_start_date}
        )
        previous_period = result.fetchone()
        
        # 3. Obtener períodos MÁS ANTIGUOS en COLLECTING (deben pasar a SETTLING)
        if previous_period:
            result = await db.execute(
                text("""
                SELECT id, cut_code, period_start_date, period_end_date, status_id
                FROM cut_periods
                WHERE period_end_date < :previous_start
                AND status_id = 4  -- COLLECTING
                ORDER BY period_start_date ASC
                """),
                {"previous_start": previous_period.period_start_date}
            )
            old_collecting_periods = result.fetchall()
        else:
            old_collecting_periods = []
        
        # 4. Procesar transiciones
        
        # 4a. Períodos antiguos COLLECTING → SETTLING
        for period in old_collecting_periods:
            change = {
                "period_id": period.id,
                "cut_code": period.cut_code,
                "action": "COLLECTING → SETTLING",
                "reason": "Período antiguo - tiempo de cobro terminado"
            }
            
            if not dry_run:
                await _mark_overdue_statements(db, period.id)
                await db.execute(
                    text("UPDATE cut_periods SET status_id = 6, updated_at = NOW() WHERE id = :id"),
                    {"id": period.id}
                )
                change["status"] = "APPLIED"
            else:
                change["status"] = "DRY_RUN"
            
            changes.append(change)
        
        # 4b. Período anterior: Si está en CUTOFF o PENDING, pasar a COLLECTING
        if previous_period and previous_period.status_id in [1, 3]:  # PENDING o CUTOFF
            if previous_period.status_id == 1:
                # PENDING → CUTOFF (generar statements primero)
                change = {
                    "period_id": previous_period.id,
                    "cut_code": previous_period.cut_code,
                    "action": "PENDING → CUTOFF → COLLECTING",
                    "reason": "Período terminado - iniciando cobro"
                }
                
                if not dry_run:
                    # Primero a CUTOFF
                    await db.execute(
                        text("UPDATE cut_periods SET status_id = 3, updated_at = NOW() WHERE id = :id"),
                        {"id": previous_period.id}
                    )
                    # Generar statements
                    await _generate_statements_for_period(db, previous_period.id)
                    # Luego a COLLECTING
                    await db.execute(
                        text("UPDATE cut_periods SET status_id = 4, updated_at = NOW() WHERE id = :id"),
                        {"id": previous_period.id}
                    )
                    change["status"] = "APPLIED"
                else:
                    change["status"] = "DRY_RUN"
                
                changes.append(change)
                
            elif previous_period.status_id == 3:
                # CUTOFF → COLLECTING
                change = {
                    "period_id": previous_period.id,
                    "cut_code": previous_period.cut_code,
                    "action": "CUTOFF → COLLECTING",
                    "reason": "Período en corte - iniciando cobro"
                }
                
                if not dry_run:
                    await db.execute(
                        text("UPDATE cut_periods SET status_id = 4, updated_at = NOW() WHERE id = :id"),
                        {"id": previous_period.id}
                    )
                    change["status"] = "APPLIED"
                else:
                    change["status"] = "DRY_RUN"
                
                changes.append(change)
        
        if not dry_run:
            await db.commit()
        
        return {
            "success": True,
            "message": f"Procesamiento {'simulado' if dry_run else 'completado'}",
            "current_period": {
                "id": current_period.id,
                "cut_code": current_period.cut_code,
                "period_start": current_period.period_start_date.isoformat(),
                "period_end": current_period.period_end_date.isoformat(),
                "status": "PENDING (no se modifica - período actual)"
            },
            "previous_period": {
                "id": previous_period.id,
                "cut_code": previous_period.cut_code,
                "status_id": previous_period.status_id
            } if previous_period else None,
            "changes": changes,
            "date_checked": today.isoformat()
        }
        
    except Exception as e:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error en avance de períodos: {str(e)}"
        )


@router.post("/{period_id}/close")
async def close_period(
    period_id: int,
    db: AsyncSession = Depends(get_async_db),
):
    """
    Cierra un período que está en SETTLING, transfiriendo deudas pendientes.
    
    Este es un proceso MANUAL que debe ejecutar un supervisor después de
    verificar que se hizo todo el esfuerzo de cobro posible.
    
    Acciones:
    1. Marca statements OVERDUE/PARTIAL como ABSORBED
    2. Crea registros de deuda con detalles (statement origen, montos)
    3. Actualiza el balance acumulado del asociado
    4. Cambia el período a CLOSED
    """
    try:
        # Verificar que el período existe y está en SETTLING
        result = await db.execute(
            text("SELECT id, status_id, cut_code FROM cut_periods WHERE id = :id"),
            {"id": period_id}
        )
        period = result.fetchone()
        
        if not period:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Período {period_id} no encontrado"
            )
        
        if period.status_id != 6:  # SETTLING
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Solo se pueden cerrar períodos en SETTLING (6). Estado actual: {period.status_id}"
            )
        
        # Transferir deudas pendientes con detalles
        debts_created = await _transfer_pending_debts(db, period_id)
        
        # Actualizar estado a CLOSED
        await db.execute(
            text("UPDATE cut_periods SET status_id = 5, updated_at = NOW() WHERE id = :id"),
            {"id": period_id}
        )
        
        await db.commit()
        
        return {
            "success": True,
            "message": f"Período {period.cut_code} cerrado exitosamente",
            "debts_created": debts_created,
            "data": {
                "id": period.id,
                "cut_code": period.cut_code,
                "new_status": "CLOSED"
            }
        }
        
    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error cerrando período: {str(e)}"
        )


async def _mark_overdue_statements(db: AsyncSession, period_id: int):
    """
    Mueve TODOS los statements del período a estado SETTLING (9).
    Se ejecuta cuando el período pasa a liquidación (COLLECTING → SETTLING).
    
    El estado de deuda (pagado/parcial/pendiente) se calcula dinámicamente
    basado en los campos paid_amount y total_to_credicuenta.
    """
    # Mover TODOS los statements activos a SETTLING
    await db.execute(
        text("""
        UPDATE associate_payment_statements
        SET 
            status_id = 9,  -- SETTLING
            updated_at = NOW()
        WHERE cut_period_id = :period_id
          AND status_id IN (3, 4, 5, 7, 8)  -- Cualquier estado activo (no DRAFT ni ya SETTLING/CLOSED)
        """),
        {"period_id": period_id}
    )
    
    # Log: Contar cuántos se movieron
    result = await db.execute(
        text("""
        SELECT COUNT(*) as count
        FROM associate_payment_statements
        WHERE cut_period_id = :period_id AND status_id = 9
        """),
        {"period_id": period_id}
    )
    count = result.fetchone()
    print(f"📋 Statements movidos a SETTLING para período {period_id}: {count.count if count else 0}")


async def _generate_statements_for_period(db: AsyncSession, period_id: int):
    """
    Genera statements para cada asociado que tiene pagos en el período.
    Se ejecuta cuando se cierra el corte (CUTOFF → COLLECTING).
    """
    # Obtener asociados con pagos en el período, agrupados
    result = await db.execute(
        text("""
        SELECT 
            l.associate_user_id as associate_id,
            COUNT(DISTINCT p.id) as payment_count,
            SUM(p.expected_amount) as total_collected,
            SUM(p.commission_amount) as total_commission,
            SUM(p.associate_payment) as total_to_credicuenta,
            MAX(l.commission_rate) as commission_rate
        FROM payments p
        JOIN loans l ON l.id = p.loan_id
        WHERE p.cut_period_id = :period_id
        AND l.associate_user_id IS NOT NULL
        GROUP BY l.associate_user_id
        """),
        {"period_id": period_id}
    )
    
    associates = result.fetchall()
    
    if not associates:
        return  # No hay pagos en el período
    
    # Obtener información del período para fechas
    period_result = await db.execute(
        text("SELECT cut_code, period_end_date FROM cut_periods WHERE id = :id"),
        {"id": period_id}
    )
    period = period_result.fetchone()
    
    # Generar un statement por cada asociado
    for assoc in associates:
        # Verificar si ya existe un statement para este asociado/período
        existing = await db.execute(
            text("""
            SELECT id FROM associate_payment_statements 
            WHERE user_id = :user_id AND cut_period_id = :period_id
            """),
            {"user_id": assoc.associate_id, "period_id": period_id}
        )
        
        if existing.fetchone():
            continue  # Ya existe, saltar
        
        # Generar número de statement único
        statement_number = f"ST-{period.cut_code}-{assoc.associate_id:04d}"
        
        # Crear statement en estado COLLECTING (7)
        await db.execute(
            text("""
            INSERT INTO associate_payment_statements (
                user_id,
                cut_period_id,
                statement_number,
                total_amount_collected,
                total_to_credicuenta,
                commission_earned,
                total_payments_count,
                commission_rate_applied,
                paid_amount,
                late_fee_amount,
                status_id,
                generated_date,
                due_date,
                created_at
            ) VALUES (
                :user_id,
                :period_id,
                :statement_number,
                :total_collected,
                :total_to_credicuenta,
                :commission_earned,
                :payment_count,
                :commission_rate,
                0,
                0,
                7,
                CURRENT_DATE,
                :due_date,
                NOW()
            )
            """),
            {
                "user_id": assoc.associate_id,
                "period_id": period_id,
                "statement_number": statement_number,
                "total_collected": assoc.total_collected or 0,
                "total_to_credicuenta": assoc.total_to_credicuenta or 0,  # Lo que debe pagar a Credicuenta
                "commission_earned": (assoc.total_collected or 0) - (assoc.total_to_credicuenta or 0),  # Comisión ganada
                "payment_count": assoc.payment_count,
                "commission_rate": assoc.commission_rate or 0,
                "due_date": period.period_end_date  # Fecha límite = fin del período
            }
        )


async def _transfer_pending_debts(db: AsyncSession, period_id: int) -> int:
    """
    Transfiere deudas pendientes de statements no pagados a balances acumulados.
    Se ejecuta cuando se cierra definitivamente (SETTLING → CLOSED).
    
    1. Mueve TODOS los statements a estado CLOSED (10)
    2. Para los que tienen deuda pendiente, la transfiere a associate_accumulated_balances
    
    Returns:
        int: Número de deudas creadas/actualizadas
    """
    import json
    
    # Obtener información del período
    period_result = await db.execute(
        text("SELECT cut_code FROM cut_periods WHERE id = :id"),
        {"id": period_id}
    )
    period = period_result.fetchone()
    period_code = period.cut_code if period else f"P{period_id}"
    
    # Obtener TODOS los statements del período para procesar
    result = await db.execute(
        text("""
        SELECT 
            aps.id,
            aps.user_id,
            aps.statement_number,
            aps.total_to_credicuenta,
            aps.paid_amount,
            aps.late_fee_amount,
            aps.status_id,
            u.first_name || ' ' || u.last_name as associate_name
        FROM associate_payment_statements aps
        LEFT JOIN users u ON u.id = aps.user_id
        WHERE aps.cut_period_id = :period_id
        """),
        {"period_id": period_id}
    )
    
    all_statements = result.fetchall()
    debts_created = 0
    
    for stmt in all_statements:
        total_due = Decimal(str(stmt.total_to_credicuenta or 0)) + Decimal(str(stmt.late_fee_amount or 0))
        paid = Decimal(str(stmt.paid_amount or 0))
        pending_amount = total_due - paid
        
        # Si tiene deuda pendiente, transferirla
        if pending_amount > Decimal("0.01"):
            # Crear detalle de la deuda en JSON
            debt_detail = {
                "statement_id": stmt.id,
                "statement_number": stmt.statement_number,
                "original_amount": float(stmt.total_to_credicuenta or 0),
                "late_fee": float(stmt.late_fee_amount or 0),
                "paid_amount": float(stmt.paid_amount or 0),
                "debt_amount": float(pending_amount),
                "absorbed_date": datetime.now().isoformat(),
                "period_code": period_code
            }
            
            # Verificar si ya existe un registro para este asociado y período
            existing = await db.execute(
                text("""
                SELECT id, accumulated_debt, debt_details 
                FROM associate_accumulated_balances 
                WHERE user_id = :user_id AND cut_period_id = :period_id
                """),
                {"user_id": stmt.user_id, "period_id": period_id}
            )
            existing_balance = existing.fetchone()
            
            if existing_balance:
                # Actualizar balance existente
                current_details = existing_balance.debt_details or []
                if isinstance(current_details, str):
                    current_details = json.loads(current_details)
                current_details.append(debt_detail)
                
                await db.execute(
                    text("""
                    UPDATE associate_accumulated_balances 
                    SET accumulated_debt = accumulated_debt + :amount,
                        debt_details = CAST(:details AS jsonb),
                        updated_at = NOW()
                    WHERE id = :id
                    """),
                    {
                        "id": existing_balance.id,
                        "amount": float(pending_amount),
                        "details": json.dumps(current_details)
                    }
                )
            else:
                # Crear nuevo registro de balance
                await db.execute(
                    text("""
                    INSERT INTO associate_accumulated_balances (
                        user_id, cut_period_id, accumulated_debt, debt_details, created_at, updated_at
                    ) VALUES (
                        :user_id, :period_id, :amount, CAST(:details AS jsonb), NOW(), NOW()
                    )
                    """),
                    {
                        "user_id": stmt.user_id,
                        "period_id": period_id,
                        "amount": float(pending_amount),
                        "details": json.dumps([debt_detail])
                    }
                )
            
            debts_created += 1
            print(f"💰 Deuda transferida: {stmt.associate_name} - ${float(pending_amount):.2f} ({stmt.statement_number})")
    
    # Mover TODOS los statements a CLOSED (10)
    await db.execute(
        text("""
        UPDATE associate_payment_statements 
        SET status_id = 10, updated_at = NOW()
        WHERE cut_period_id = :period_id
        """),
        {"period_id": period_id}
    )
    
    print(f"📋 Todos los statements del período {period_id} movidos a CLOSED")
    
    return debts_created
