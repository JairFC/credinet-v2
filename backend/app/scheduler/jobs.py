"""
CrediNet v2.0 - Scheduled Jobs
===============================================================================
Tareas programadas que se ejecutan automáticamente dentro del contenedor Docker.
No dependen del cron de Linux, corren dentro de la aplicación FastAPI.

Jobs configurados:
- auto_cut_period: Se ejecuta los días 8 y 23 a las 00:05 (5 min después de medianoche)
                   Procesa el cierre del período anterior y genera statements

Uso de APScheduler con jobstore en memoria (sin persistencia).
Si el backend se reinicia en el momento exacto del job, se ejecutará en el próximo horario.
===============================================================================
"""
import logging
from datetime import datetime, date
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.cron import CronTrigger
from sqlalchemy import text

from app.core.database import async_engine

logger = logging.getLogger(__name__)

# Crear el scheduler (se iniciará desde main.py)
scheduler = AsyncIOScheduler(
    timezone="America/Mexico_City",
    job_defaults={
        "coalesce": True,  # Si se perdieron ejecuciones, solo ejecuta una
        "max_instances": 1,  # Solo una instancia a la vez
        "misfire_grace_time": 3600,  # 1 hora de gracia si se perdió
    }
)


async def auto_cut_period_job():
    """
    Job de corte automático de períodos.
    
    Se ejecuta los días 8 y 23 a las 00:05.
    
    Lógica:
    1. Busca períodos que necesitan avanzar
    2. PENDING → CUTOFF: Marca el período como "en corte"
    3. CUTOFF → COLLECTING: Genera statements y pasa a cobro
    4. COLLECTING (antiguos) → SETTLING: Pasa a liquidación
    
    Esta lógica es la misma que el endpoint POST /api/v1/cut-periods/advance-periods
    pero ejecutada automáticamente.
    """
    job_id = f"auto_cut_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
    logger.info(f"[{job_id}] 🚀 Iniciando job de corte automático")
    
    try:
        from sqlalchemy.ext.asyncio import AsyncSession
        
        async with AsyncSession(async_engine) as db:
            today = date.today()
            changes = []
            
            logger.info(f"[{job_id}] 📅 Fecha actual: {today}, Día: {today.day}")
            
            # Solo ejecutar los días 8 y 23
            if today.day not in [8, 23]:
                logger.info(f"[{job_id}] ℹ️ No es día de corte (8 o 23), saltando ejecución")
                return {"status": "skipped", "reason": "not_cut_day"}
            
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
                logger.warning(f"[{job_id}] ⚠️ No se encontró período para la fecha actual")
                return {"status": "error", "reason": "no_current_period"}
            
            logger.info(f"[{job_id}] 📋 Período actual: {current_period.cut_code} (status_id={current_period.status_id})")
            
            # 2. Obtener el período ANTERIOR INMEDIATO
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
            
            if previous_period:
                logger.info(f"[{job_id}] 📋 Período anterior: {previous_period.cut_code} (status_id={previous_period.status_id})")
            
            # 3. Obtener períodos MÁS ANTIGUOS en COLLECTING
            if previous_period:
                result = await db.execute(
                    text("""
                    SELECT id, cut_code, period_start_date, period_end_date, status_id
                    FROM cut_periods
                    WHERE period_end_date < :previous_start
                    AND status_id = 4
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
                logger.info(f"[{job_id}] 🔄 {period.cut_code}: COLLECTING → SETTLING")
                
                # Marcar statements vencidos
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
                
                # Cambiar estado del período
                await db.execute(
                    text("UPDATE cut_periods SET status_id = 6, updated_at = NOW() WHERE id = :id"),
                    {"id": period.id}
                )
                
                changes.append({
                    "cut_code": period.cut_code,
                    "action": "COLLECTING → SETTLING",
                    "reason": "Tiempo de cobro terminado"
                })
            
            # 4b. Período anterior: PENDING o CUTOFF → COLLECTING
            if previous_period and previous_period.status_id in [1, 3]:
                if previous_period.status_id == 1:  # PENDING
                    logger.info(f"[{job_id}] 🔄 {previous_period.cut_code}: PENDING → CUTOFF → COLLECTING")
                    
                    # Primero a CUTOFF
                    await db.execute(
                        text("UPDATE cut_periods SET status_id = 3, updated_at = NOW() WHERE id = :id"),
                        {"id": previous_period.id}
                    )
                    
                    # Generar statements
                    statements_count = await _generate_statements(db, previous_period.id, previous_period.cut_code)
                    
                    # Luego a COLLECTING
                    await db.execute(
                        text("UPDATE cut_periods SET status_id = 4, updated_at = NOW() WHERE id = :id"),
                        {"id": previous_period.id}
                    )
                    
                    changes.append({
                        "cut_code": previous_period.cut_code,
                        "action": "PENDING → COLLECTING",
                        "statements_generated": statements_count
                    })
                    
                elif previous_period.status_id == 3:  # CUTOFF
                    logger.info(f"[{job_id}] 🔄 {previous_period.cut_code}: CUTOFF → COLLECTING")
                    
                    # Verificar si ya tiene statements, si no, generarlos
                    result = await db.execute(
                        text("SELECT COUNT(*) as count FROM associate_payment_statements WHERE cut_period_id = :id"),
                        {"id": previous_period.id}
                    )
                    stmt_count = result.fetchone().count
                    
                    if stmt_count == 0:
                        statements_count = await _generate_statements(db, previous_period.id, previous_period.cut_code)
                        logger.info(f"[{job_id}] ✅ Generados {statements_count} statements")
                    else:
                        statements_count = stmt_count
                        logger.info(f"[{job_id}] ℹ️ Ya existen {stmt_count} statements")
                    
                    # Pasar a COLLECTING
                    await db.execute(
                        text("UPDATE cut_periods SET status_id = 4, updated_at = NOW() WHERE id = :id"),
                        {"id": previous_period.id}
                    )
                    
                    changes.append({
                        "cut_code": previous_period.cut_code,
                        "action": "CUTOFF → COLLECTING",
                        "statements_count": statements_count
                    })
            
            await db.commit()
            
            logger.info(f"[{job_id}] ✅ Corte completado. Cambios: {len(changes)}")
            for change in changes:
                logger.info(f"[{job_id}]    - {change['cut_code']}: {change['action']}")
            
            return {
                "status": "success",
                "date": today.isoformat(),
                "changes": changes
            }
            
    except Exception as e:
        logger.error(f"[{job_id}] ❌ Error en job de corte: {str(e)}", exc_info=True)
        return {"status": "error", "error": str(e)}


async def _generate_statements(db, period_id: int, cut_code: str) -> int:
    """
    Genera statements para cada asociado que tiene pagos en el período.
    Retorna la cantidad de statements generados.
    """
    # Obtener asociados con pagos en el período
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
        return 0
    
    # Obtener fecha de vencimiento del período
    period_result = await db.execute(
        text("SELECT period_end_date FROM cut_periods WHERE id = :id"),
        {"id": period_id}
    )
    period = period_result.fetchone()
    
    count = 0
    for assoc in associates:
        # Verificar si ya existe
        existing = await db.execute(
            text("""
            SELECT id FROM associate_payment_statements 
            WHERE user_id = :user_id AND cut_period_id = :period_id
            """),
            {"user_id": assoc.associate_id, "period_id": period_id}
        )
        
        if existing.fetchone():
            continue
        
        # Generar statement
        statement_number = f"ST-{cut_code}-{assoc.associate_id:04d}"
        
        await db.execute(
            text("""
            INSERT INTO associate_payment_statements (
                user_id, cut_period_id, statement_number,
                total_amount_collected, total_to_credicuenta, commission_earned,
                total_payments_count, commission_rate_applied,
                paid_amount, late_fee_amount, status_id,
                generated_date, due_date, created_at
            ) VALUES (
                :user_id, :period_id, :statement_number,
                :total_collected, :total_to_credicuenta, :commission_earned,
                :payment_count, :commission_rate,
                0, 0, 7,
                CURRENT_DATE, :due_date, NOW()
            )
            """),
            {
                "user_id": assoc.associate_id,
                "period_id": period_id,
                "statement_number": statement_number,
                "total_collected": assoc.total_collected or 0,
                "total_to_credicuenta": assoc.total_to_credicuenta or 0,
                "commission_earned": (assoc.total_collected or 0) - (assoc.total_to_credicuenta or 0),
                "payment_count": assoc.payment_count,
                "commission_rate": assoc.commission_rate or 0,
                "due_date": period.period_end_date
            }
        )
        count += 1
    
    return count


def start_scheduler():
    """
    Inicia el scheduler con los jobs configurados.
    Se llama desde el evento startup de FastAPI.
    """
    if scheduler.running:
        logger.warning("⚠️ Scheduler ya está corriendo")
        return
    
    # Job de corte automático: días 8 y 23 a las 00:05
    scheduler.add_job(
        auto_cut_period_job,
        CronTrigger(day="8,23", hour=0, minute=5),
        id="auto_cut_period",
        name="Corte automático de períodos",
        replace_existing=True
    )
    
    scheduler.start()
    logger.info("✅ Scheduler iniciado")
    logger.info("📅 Jobs programados:")
    for job in scheduler.get_jobs():
        logger.info(f"   - {job.id}: {job.name} ({job.trigger})")


def shutdown_scheduler():
    """
    Detiene el scheduler de forma limpia.
    Se llama desde el evento shutdown de FastAPI.
    """
    if scheduler.running:
        scheduler.shutdown(wait=False)
        logger.info("🛑 Scheduler detenido")
