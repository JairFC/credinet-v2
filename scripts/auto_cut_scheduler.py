#!/usr/bin/env python3
"""
Script de Corte Automático de Períodos - CrediNet v2.0
======================================================

Este script se ejecuta automáticamente a las 00:00 de los días 8 y 23 de cada mes.
Genera statements en estado DRAFT para revisión del admin.

Uso:
    python auto_cut_scheduler.py              # Ejecuta si es día de corte
    python auto_cut_scheduler.py --force      # Fuerza ejecución aunque no sea día de corte
    python auto_cut_scheduler.py --dry-run    # Simula sin hacer cambios
    python auto_cut_scheduler.py --check      # Solo verifica períodos pendientes

Configuración cron (producción):
    0 0 * * * cd /path/to/credinet-v2 && python scripts/auto_cut_scheduler.py >> logs/auto_cut.log 2>&1

Autor: Sistema CrediNet
Fecha: 2025-12-09
"""

import os
import sys
import argparse
import logging
from datetime import datetime, date
from decimal import Decimal

# Configurar logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger(__name__)

# Intentar importar psycopg2 o psycopg
try:
    import psycopg2
    from psycopg2.extras import RealDictCursor
    DB_DRIVER = 'psycopg2'
except ImportError:
    try:
        import psycopg
        DB_DRIVER = 'psycopg3'
    except ImportError:
        logger.error("❌ No se encontró driver de PostgreSQL. Instalar: pip install psycopg2-binary")
        sys.exit(1)


def get_db_connection():
    """Obtiene conexión a la base de datos desde variables de entorno."""
    db_config = {
        'host': os.getenv('DB_HOST', 'localhost'),
        'port': os.getenv('DB_PORT', '5432'),
        'dbname': os.getenv('DB_NAME', 'credinet_db'),
        'user': os.getenv('DB_USER', 'credinet_user'),
        'password': os.getenv('DB_PASSWORD', 'credinet_pass_2024')
    }
    
    if DB_DRIVER == 'psycopg2':
        return psycopg2.connect(**db_config, cursor_factory=RealDictCursor)
    else:
        return psycopg.connect(**db_config)


def is_cut_day(target_date: date = None) -> bool:
    """Verifica si la fecha es día de corte (8 o 23)."""
    if target_date is None:
        target_date = date.today()
    return target_date.day in (8, 23)


def get_period_for_cut_day(conn, target_date: date = None) -> dict:
    """
    Obtiene el período que corresponde al día de corte.
    El día de corte es period_end_date + 1.
    """
    if target_date is None:
        target_date = date.today()
    
    query = """
        SELECT 
            cp.id,
            cp.cut_code,
            cp.period_start_date,
            cp.period_end_date,
            cp.status_id,
            cps.name as status_name,
            (SELECT COUNT(*) FROM payments WHERE cut_period_id = cp.id) as payment_count
        FROM cut_periods cp
        JOIN cut_period_statuses cps ON cps.id = cp.status_id
        WHERE cp.period_end_date + 1 = %s
    """
    
    with conn.cursor() as cur:
        cur.execute(query, (target_date,))
        result = cur.fetchone()
        return dict(result) if result else None


def get_pending_periods(conn) -> list:
    """Obtiene períodos que deberían haber tenido corte pero siguen en PENDING."""
    query = """
        SELECT 
            cp.id,
            cp.cut_code,
            cp.period_start_date,
            cp.period_end_date,
            cp.period_end_date + 1 as cut_day,
            cp.status_id,
            cps.name as status_name,
            (SELECT COUNT(*) FROM payments WHERE cut_period_id = cp.id) as payment_count,
            (SELECT COUNT(*) FROM associate_payment_statements WHERE cut_period_id = cp.id) as statement_count
        FROM cut_periods cp
        JOIN cut_period_statuses cps ON cps.id = cp.status_id
        WHERE cp.status_id = 1  -- PENDING
          AND cp.period_end_date < CURRENT_DATE  -- Ya pasó el período
        ORDER BY cp.period_start_date
    """
    
    with conn.cursor() as cur:
        cur.execute(query)
        return [dict(row) for row in cur.fetchall()]


def execute_cutoff(conn, period_id: int, dry_run: bool = False) -> dict:
    """
    Ejecuta el corte automático para un período:
    1. Cambia estado del período: PENDING → CUTOFF
    2. Genera statements en estado DRAFT para cada asociado
    
    Returns:
        dict con estadísticas del corte
    """
    result = {
        'period_id': period_id,
        'status_changed': False,
        'statements_created': 0,
        'total_commission': Decimal('0.00'),
        'associates': []
    }
    
    if dry_run:
        logger.info(f"🔍 [DRY-RUN] Simulando corte para período {period_id}")
    
    with conn.cursor() as cur:
        # 1. Cambiar estado del período a CUTOFF (3)
        if not dry_run:
            cur.execute("""
                UPDATE cut_periods 
                SET status_id = 3, updated_at = NOW() 
                WHERE id = %s AND status_id = 1
                RETURNING id, cut_code
            """, (period_id,))
            updated = cur.fetchone()
            if updated:
                result['status_changed'] = True
                result['cut_code'] = updated['cut_code'] if isinstance(updated, dict) else updated[1]
                logger.info(f"✅ Período {result.get('cut_code', period_id)} cambiado a CUTOFF")
        else:
            cur.execute("SELECT cut_code FROM cut_periods WHERE id = %s", (period_id,))
            row = cur.fetchone()
            result['cut_code'] = row['cut_code'] if isinstance(row, dict) else row[0]
            result['status_changed'] = True
        
        # 2. Generar statements en DRAFT
        cur.execute("""
            SELECT 
                l.associate_user_id,
                u.first_name || ' ' || u.last_name as associate_name,
                COUNT(p.id) as payment_count,
                SUM(p.expected_amount) as total_collected,
                SUM(p.commission_amount) as total_commission,
                MAX(l.commission_rate) as commission_rate
            FROM payments p
            JOIN loans l ON p.loan_id = l.id
            JOIN users u ON u.id = l.associate_user_id
            WHERE p.cut_period_id = %s
              AND l.associate_user_id IS NOT NULL
            GROUP BY l.associate_user_id, u.first_name, u.last_name
        """, (period_id,))
        
        associates_data = cur.fetchall()
        
        for assoc in associates_data:
            assoc_dict = dict(assoc) if not isinstance(assoc, dict) else assoc
            assoc_id = assoc_dict['associate_user_id']
            assoc_name = assoc_dict['associate_name']
            payment_count = assoc_dict['payment_count']
            total_commission = Decimal(str(assoc_dict['total_commission'] or 0))
            
            result['associates'].append({
                'id': assoc_id,
                'name': assoc_name,
                'payments': payment_count,
                'commission': float(total_commission)
            })
            result['total_commission'] += total_commission
            
            if not dry_run:
                # Insertar statement
                cur.execute("""
                    INSERT INTO associate_payment_statements (
                        cut_period_id,
                        user_id,
                        statement_number,
                        total_payments_count,
                        total_amount_collected,
                        total_commission_owed,
                        commission_rate_applied,
                        status_id,
                        generated_date,
                        due_date,
                        paid_amount,
                        late_fee_amount,
                        late_fee_applied
                    )
                    SELECT 
                        %s, %s,
                        CONCAT((SELECT cut_code FROM cut_periods WHERE id = %s), '-A', %s),
                        %s,
                        %s,
                        %s,
                        %s,
                        6,  -- DRAFT
                        CURRENT_DATE,
                        CURRENT_DATE + INTERVAL '7 days',
                        0, 0, false
                    WHERE NOT EXISTS (
                        SELECT 1 FROM associate_payment_statements 
                        WHERE cut_period_id = %s AND user_id = %s
                    )
                    RETURNING id
                """, (
                    period_id, assoc_id, period_id, assoc_id,
                    payment_count,
                    assoc_dict['total_collected'],
                    total_commission,
                    assoc_dict['commission_rate'] or 0,
                    period_id, assoc_id
                ))
                
                if cur.fetchone():
                    result['statements_created'] += 1
        
        if not dry_run:
            conn.commit()
            logger.info(f"✅ Generados {result['statements_created']} statements en DRAFT")
        else:
            logger.info(f"🔍 [DRY-RUN] Se generarían {len(associates_data)} statements")
            result['statements_created'] = len(associates_data)
    
    return result


def check_and_recover_missed_cuts(conn, dry_run: bool = False) -> list:
    """
    Verifica y recupera cortes que no se ejecutaron.
    Útil para cuando el cron falló o el sistema estuvo caído.
    """
    pending = get_pending_periods(conn)
    
    if not pending:
        logger.info("✅ No hay cortes pendientes de recuperar")
        return []
    
    logger.warning(f"⚠️ Se encontraron {len(pending)} períodos con corte pendiente")
    
    results = []
    for period in pending:
        logger.info(f"🔄 Procesando período atrasado: {period['cut_code']} (debió cortarse el {period['cut_day']})")
        result = execute_cutoff(conn, period['id'], dry_run)
        results.append(result)
    
    return results


def main():
    parser = argparse.ArgumentParser(
        description='Script de Corte Automático de Períodos - CrediNet v2.0'
    )
    parser.add_argument(
        '--force', '-f',
        action='store_true',
        help='Forzar ejecución aunque no sea día de corte'
    )
    parser.add_argument(
        '--dry-run', '-n',
        action='store_true',
        help='Simular sin hacer cambios en la base de datos'
    )
    parser.add_argument(
        '--check', '-c',
        action='store_true',
        help='Solo verificar períodos pendientes sin ejecutar'
    )
    parser.add_argument(
        '--recover', '-r',
        action='store_true',
        help='Recuperar cortes que no se ejecutaron (períodos atrasados)'
    )
    
    args = parser.parse_args()
    
    logger.info("=" * 60)
    logger.info("🚀 INICIANDO SCRIPT DE CORTE AUTOMÁTICO - CrediNet v2.0")
    logger.info(f"📅 Fecha actual: {date.today()}")
    logger.info(f"⏰ Hora: {datetime.now().strftime('%H:%M:%S')}")
    logger.info("=" * 60)
    
    try:
        conn = get_db_connection()
        logger.info("✅ Conexión a base de datos establecida")
    except Exception as e:
        logger.error(f"❌ Error conectando a la base de datos: {e}")
        sys.exit(1)
    
    try:
        # Modo verificación
        if args.check:
            logger.info("🔍 Modo VERIFICACIÓN - Solo lectura")
            pending = get_pending_periods(conn)
            if pending:
                logger.warning(f"⚠️ Hay {len(pending)} períodos con corte pendiente:")
                for p in pending:
                    logger.warning(f"   - {p['cut_code']}: {p['payment_count']} pagos, {p['statement_count']} statements")
            else:
                logger.info("✅ Todos los períodos están al día")
            conn.close()
            return
        
        # Modo recuperación
        if args.recover:
            logger.info("🔄 Modo RECUPERACIÓN - Procesando cortes atrasados")
            results = check_and_recover_missed_cuts(conn, args.dry_run)
            if results:
                total_statements = sum(r['statements_created'] for r in results)
                total_commission = sum(float(r['total_commission']) for r in results)
                logger.info(f"📊 Resumen: {len(results)} períodos, {total_statements} statements, ${total_commission:,.2f} en comisiones")
            conn.close()
            return
        
        # Modo normal: ejecutar corte del día
        today = date.today()
        
        if not is_cut_day(today) and not args.force:
            logger.info(f"📅 Hoy es día {today.day}, no es día de corte (8 o 23)")
            logger.info("💡 Usa --force para forzar ejecución o --recover para cortes atrasados")
            conn.close()
            return
        
        if args.force and not is_cut_day(today):
            logger.warning(f"⚠️ Forzando ejecución en día {today.day} (no es día de corte)")
        
        # Buscar período correspondiente
        period = get_period_for_cut_day(conn, today)
        
        if not period:
            logger.warning(f"⚠️ No se encontró período para cortar hoy ({today})")
            # Verificar si hay períodos atrasados
            pending = get_pending_periods(conn)
            if pending:
                logger.info("🔄 Ejecutando recuperación de cortes atrasados...")
                check_and_recover_missed_cuts(conn, args.dry_run)
            conn.close()
            return
        
        logger.info(f"📋 Período encontrado: {period['cut_code']}")
        logger.info(f"   - Estado actual: {period['status_name']}")
        logger.info(f"   - Pagos en período: {period['payment_count']}")
        
        if period['status_id'] != 1:  # No está en PENDING
            logger.info(f"ℹ️ El período ya no está en PENDING (estado: {period['status_name']})")
            logger.info("   El corte ya fue ejecutado anteriormente")
            conn.close()
            return
        
        # Ejecutar corte
        logger.info("🔄 Ejecutando corte automático...")
        result = execute_cutoff(conn, period['id'], args.dry_run)
        
        # Mostrar resumen
        logger.info("=" * 60)
        logger.info("📊 RESUMEN DEL CORTE")
        logger.info("=" * 60)
        logger.info(f"   Período: {result.get('cut_code', period['cut_code'])}")
        logger.info(f"   Estado cambiado: {'Sí' if result['status_changed'] else 'No'}")
        logger.info(f"   Statements generados: {result['statements_created']}")
        logger.info(f"   Total comisiones: ${float(result['total_commission']):,.2f}")
        
        if result['associates']:
            logger.info("   Asociados:")
            for assoc in result['associates']:
                logger.info(f"      - {assoc['name']}: {assoc['payments']} pagos, ${assoc['commission']:,.2f}")
        
        if args.dry_run:
            logger.info("🔍 [DRY-RUN] No se realizaron cambios reales")
        else:
            logger.info("✅ Corte completado exitosamente")
        
    except Exception as e:
        logger.error(f"❌ Error durante la ejecución: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
    finally:
        conn.close()
        logger.info("🔒 Conexión cerrada")


if __name__ == "__main__":
    main()
