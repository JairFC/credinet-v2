"""
CrediNet v2.0 - Scheduler Routes
Endpoints para administrar y monitorear el scheduler de tareas programadas.
"""
from fastapi import APIRouter, HTTPException, status
from datetime import datetime
import logging

from app.scheduler.jobs import scheduler, auto_cut_period_job

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/scheduler", tags=["Scheduler"])


@router.get("/status")
async def get_scheduler_status():
    """
    Obtiene el estado actual del scheduler y sus jobs programados.
    """
    jobs = []
    for job in scheduler.get_jobs():
        next_run = job.next_run_time
        jobs.append({
            "id": job.id,
            "name": job.name,
            "trigger": str(job.trigger),
            "next_run": next_run.isoformat() if next_run else None,
            "pending": job.pending
        })
    
    return {
        "success": True,
        "scheduler": {
            "running": scheduler.running,
            "timezone": str(scheduler.timezone),
            "jobs_count": len(jobs)
        },
        "jobs": jobs
    }


@router.post("/run-cut-now")
async def run_cut_now(force: bool = False):
    """
    Ejecuta el job de corte automático manualmente.
    
    Útil para:
    - Probar el job sin esperar al día 8 o 23
    - Recuperar cortes atrasados
    - Ejecutar después de mantenimiento
    
    Args:
        force: Si es True, ejecuta aunque no sea día de corte (8 o 23)
    """
    logger.info(f"🔧 Ejecución manual del job de corte (force={force})")
    
    try:
        # Ejecutar el job directamente
        if force:
            # Modificar temporalmente la lógica para forzar
            from datetime import date
            today = date.today()
            
            # Ejecutar la lógica del job ignorando el día
            from sqlalchemy.ext.asyncio import AsyncSession
            from sqlalchemy import text
            from app.core.database import async_engine
            from app.scheduler.jobs import _generate_statements
            
            async with AsyncSession(async_engine) as db:
                changes = []
                
                # 1. Obtener el período ACTUAL
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
                    return {"success": False, "error": "No se encontró período actual"}
                
                # 2. Obtener el período ANTERIOR
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
                
                # 3. Obtener períodos antiguos en COLLECTING
                if previous_period:
                    result = await db.execute(
                        text("""
                        SELECT id, cut_code, status_id
                        FROM cut_periods
                        WHERE period_end_date < :previous_start
                        AND status_id = 4
                        """),
                        {"previous_start": previous_period.period_start_date}
                    )
                    old_collecting = result.fetchall()
                else:
                    old_collecting = []
                
                # 4a. Procesar períodos antiguos COLLECTING → SETTLING
                for period in old_collecting:
                    await db.execute(
                        text("""
                        UPDATE associate_payment_statements 
                        SET status_id = 9
                        WHERE cut_period_id = :period_id 
                        AND status_id IN (7, 8)
                        AND (total_to_credicuenta + COALESCE(late_fee_amount, 0) - COALESCE(paid_amount, 0)) > 0.01
                        """),
                        {"period_id": period.id}
                    )
                    await db.execute(
                        text("UPDATE cut_periods SET status_id = 6, updated_at = NOW() WHERE id = :id"),
                        {"id": period.id}
                    )
                    changes.append({
                        "cut_code": period.cut_code,
                        "action": "COLLECTING → SETTLING"
                    })
                
                # 4b. Procesar período anterior
                if previous_period and previous_period.status_id in [1, 3]:
                    if previous_period.status_id == 1:  # PENDING
                        await db.execute(
                            text("UPDATE cut_periods SET status_id = 3, updated_at = NOW() WHERE id = :id"),
                            {"id": previous_period.id}
                        )
                        stmt_count = await _generate_statements(db, previous_period.id, previous_period.cut_code)
                        await db.execute(
                            text("UPDATE cut_periods SET status_id = 4, updated_at = NOW() WHERE id = :id"),
                            {"id": previous_period.id}
                        )
                        changes.append({
                            "cut_code": previous_period.cut_code,
                            "action": "PENDING → COLLECTING",
                            "statements": stmt_count
                        })
                        
                    elif previous_period.status_id == 3:  # CUTOFF
                        # Verificar/generar statements
                        result = await db.execute(
                            text("SELECT COUNT(*) as count FROM associate_payment_statements WHERE cut_period_id = :id"),
                            {"id": previous_period.id}
                        )
                        existing = result.fetchone().count
                        
                        if existing == 0:
                            stmt_count = await _generate_statements(db, previous_period.id, previous_period.cut_code)
                        else:
                            stmt_count = existing
                        
                        await db.execute(
                            text("UPDATE cut_periods SET status_id = 4, updated_at = NOW() WHERE id = :id"),
                            {"id": previous_period.id}
                        )
                        changes.append({
                            "cut_code": previous_period.cut_code,
                            "action": "CUTOFF → COLLECTING",
                            "statements": stmt_count
                        })
                
                await db.commit()
                
                return {
                    "success": True,
                    "mode": "forced",
                    "date": today.isoformat(),
                    "current_period": current_period.cut_code,
                    "previous_period": previous_period.cut_code if previous_period else None,
                    "changes": changes
                }
        else:
            # Ejecutar el job normal (respeta día 8/23)
            result = await auto_cut_period_job()
            return {
                "success": True,
                "mode": "normal",
                "result": result
            }
            
    except Exception as e:
        logger.error(f"Error en ejecución manual: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error ejecutando job: {str(e)}"
        )
