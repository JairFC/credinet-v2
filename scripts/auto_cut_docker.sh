#!/bin/bash
# =============================================================================
# Script wrapper para ejecutar el corte automático usando Docker
# =============================================================================
# Uso:
#   ./auto_cut_docker.sh              # Ejecuta el corte (si es día de corte)
#   ./auto_cut_docker.sh --check      # Solo verifica estado
#   ./auto_cut_docker.sh --recover    # Recupera cortes atrasados
#   ./auto_cut_docker.sh --dry-run    # Simula sin cambios
#   ./auto_cut_docker.sh --advance    # Avanzar períodos vía API
#
# Configuración cron (producción):
#   0 0 * * * cd /home/credicuenta/proyectos/credinet-v2 && ./scripts/auto_cut_docker.sh >> logs/auto_cut.log 2>&1
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

# Crear directorio de logs si no existe
mkdir -p logs

# URL del backend
API_URL="${API_URL:-http://localhost:8000}"

# Función para ejecutar SQL en el contenedor
run_sql() {
    docker compose exec -T postgres psql -U credinet_user -d credinet_db -t -c "$1" 2>/dev/null
}

# Función para logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Función para llamar al API de avance de períodos
advance_periods_api() {
    local dry_run_param=""
    if [ "$1" = "dry-run" ]; then
        dry_run_param="?dry_run=true"
    fi
    
    log "🔄 Llamando API de avance de períodos..."
    response=$(curl -s -X POST "${API_URL}/api/v1/cut-periods/advance-periods${dry_run_param}" 2>/dev/null || echo '{"error": "API no disponible"}')
    
    if echo "$response" | grep -q '"success": true'; then
        log "✅ API respondió exitosamente"
        # Mostrar cambios si los hay
        changes=$(echo "$response" | grep -o '"action"[^}]*' | sed 's/"action": "//g' | sed 's/".*//g')
        if [ -n "$changes" ]; then
            log "📋 Cambios aplicados:"
            echo "$response" | jq -r '.changes[]? | "   - \(.cut_code): \(.action)"' 2>/dev/null || echo "   (ver respuesta completa en logs)"
        fi
    else
        log "⚠️ Error en API: $response"
    fi
}

log "============================================================"
log "🚀 SCRIPT DE CORTE AUTOMÁTICO - CrediNet v2.0"
log "📅 Fecha: $(date '+%Y-%m-%d')"
log "============================================================"

# Verificar que Docker está corriendo
if ! docker compose ps postgres | grep -q "Up"; then
    log "❌ El contenedor de PostgreSQL no está corriendo"
    exit 1
fi

# Parsear argumentos
CHECK_ONLY=false
DRY_RUN=false
RECOVER=false
FORCE=false
ADVANCE_ONLY=false

for arg in "$@"; do
    case $arg in
        --check|-c)
            CHECK_ONLY=true
            ;;
        --dry-run|-n)
            DRY_RUN=true
            ;;
        --recover|-r)
            RECOVER=true
            ;;
        --force|-f)
            FORCE=true
            ;;
    esac
done

# Obtener día actual
TODAY_DAY=$(date '+%d')
TODAY=$(date '+%Y-%m-%d')

# Modo verificación
if [ "$CHECK_ONLY" = true ]; then
    log "🔍 Modo VERIFICACIÓN"
    
    pending=$(run_sql "
        SELECT COUNT(*) 
        FROM cut_periods 
        WHERE status_id = 1 
          AND period_end_date < CURRENT_DATE
    " | tr -d ' ')
    
    if [ "$pending" -gt 0 ]; then
        log "⚠️ Hay $pending período(s) con corte pendiente:"
        run_sql "
            SELECT 
                cut_code || ': ' || 
                (SELECT COUNT(*) FROM payments WHERE cut_period_id = cp.id) || ' pagos, ' ||
                (SELECT COUNT(*) FROM associate_payment_statements WHERE cut_period_id = cp.id) || ' statements'
            FROM cut_periods cp
            WHERE status_id = 1 
              AND period_end_date < CURRENT_DATE
            ORDER BY period_start_date
        "
    else
        log "✅ Todos los períodos están al día"
    fi
    exit 0
fi

# Modo recuperación
if [ "$RECOVER" = true ]; then
    log "🔄 Modo RECUPERACIÓN - Procesando cortes atrasados"
    
    # Obtener períodos pendientes
    pending_ids=$(run_sql "
        SELECT id FROM cut_periods 
        WHERE status_id = 1 
          AND period_end_date < CURRENT_DATE
        ORDER BY period_start_date
    " | tr -d ' ' | grep -v '^$')
    
    if [ -z "$pending_ids" ]; then
        log "✅ No hay cortes pendientes de recuperar"
        exit 0
    fi
    
    for period_id in $pending_ids; do
        cut_code=$(run_sql "SELECT cut_code FROM cut_periods WHERE id = $period_id" | tr -d ' ')
        log "🔄 Procesando período: $cut_code (ID: $period_id)"
        
        if [ "$DRY_RUN" = true ]; then
            log "🔍 [DRY-RUN] Simulando corte para $cut_code"
            continue
        fi
        
        # Cambiar estado a CUTOFF
        run_sql "UPDATE cut_periods SET status_id = 3, updated_at = NOW() WHERE id = $period_id"
        log "✅ Período $cut_code cambiado a CUTOFF"
        
        # Generar statements
        result=$(run_sql "
            INSERT INTO associate_payment_statements (
                cut_period_id, user_id, statement_number,
                total_payments_count, total_amount_collected, total_commission_owed,
                commission_rate_applied, status_id, generated_date, due_date,
                paid_amount, late_fee_amount, late_fee_applied
            )
            SELECT 
                $period_id, l.associate_user_id,
                CONCAT('$cut_code', '-A', l.associate_user_id),
                COUNT(p.id), SUM(p.expected_amount), SUM(p.commission_amount),
                MAX(l.commission_rate), 6, CURRENT_DATE, CURRENT_DATE + INTERVAL '7 days',
                0, 0, false
            FROM payments p
            JOIN loans l ON p.loan_id = l.id
            WHERE p.cut_period_id = $period_id
              AND l.associate_user_id IS NOT NULL
            GROUP BY l.associate_user_id
            ON CONFLICT DO NOTHING;
            SELECT COUNT(*) FROM associate_payment_statements WHERE cut_period_id = $period_id;
        " | tail -1 | tr -d ' ')
        
        log "✅ Generados $result statements para $cut_code"
    done
    
    exit 0
fi

# Modo normal: ejecutar corte del día
log "📅 Hoy es día $TODAY_DAY"

# Verificar si es día de corte
if [ "$TODAY_DAY" != "08" ] && [ "$TODAY_DAY" != "23" ] && [ "$FORCE" != true ]; then
    log "ℹ️ No es día de corte (esperado: 8 o 23)"
    log "💡 Usa --force para forzar, --recover para cortes atrasados, o --check para verificar"
    exit 0
fi

if [ "$FORCE" = true ] && [ "$TODAY_DAY" != "08" ] && [ "$TODAY_DAY" != "23" ]; then
    log "⚠️ Forzando ejecución en día $TODAY_DAY"
fi

# Buscar período correspondiente
period_info=$(run_sql "
    SELECT 
        id || '|' || cut_code || '|' || status_id || '|' || 
        (SELECT name FROM cut_period_statuses WHERE id = cp.status_id) || '|' ||
        (SELECT COUNT(*) FROM payments WHERE cut_period_id = cp.id)
    FROM cut_periods cp
    WHERE period_end_date + 1 = '$TODAY'
" | tr -d ' ' | head -1)

if [ -z "$period_info" ]; then
    log "⚠️ No se encontró período para cortar hoy"
    log "🔄 Verificando períodos atrasados..."
    exec "$0" --recover ${DRY_RUN:+--dry-run}
fi

# Parsear información del período
IFS='|' read -r PERIOD_ID CUT_CODE STATUS_ID STATUS_NAME PAYMENT_COUNT <<< "$period_info"

log "📋 Período encontrado: $CUT_CODE"
log "   - Estado actual: $STATUS_NAME (ID: $STATUS_ID)"
log "   - Pagos en período: $PAYMENT_COUNT"

if [ "$STATUS_ID" != "1" ]; then
    log "ℹ️ El período ya no está en PENDING (estado: $STATUS_NAME)"
    log "   El corte ya fue ejecutado anteriormente"
    exit 0
fi

if [ "$DRY_RUN" = true ]; then
    log "🔍 [DRY-RUN] Simulando corte para $CUT_CODE"
    
    count=$(run_sql "
        SELECT COUNT(DISTINCT l.associate_user_id)
        FROM payments p
        JOIN loans l ON p.loan_id = l.id
        WHERE p.cut_period_id = $PERIOD_ID
          AND l.associate_user_id IS NOT NULL
    " | tr -d ' ')
    
    log "🔍 [DRY-RUN] Se generarían $count statements"
    exit 0
fi

# Ejecutar corte
log "🔄 Ejecutando corte automático..."

# 1. Cambiar estado a CUTOFF
run_sql "UPDATE cut_periods SET status_id = 3, updated_at = NOW() WHERE id = $PERIOD_ID"
log "✅ Período $CUT_CODE cambiado a CUTOFF"

# 2. Generar statements
statements_created=$(run_sql "
    INSERT INTO associate_payment_statements (
        cut_period_id, user_id, statement_number,
        total_payments_count, total_amount_collected, total_commission_owed,
        commission_rate_applied, status_id, generated_date, due_date,
        paid_amount, late_fee_amount, late_fee_applied
    )
    SELECT 
        $PERIOD_ID, l.associate_user_id,
        CONCAT('$CUT_CODE', '-A', l.associate_user_id),
        COUNT(p.id), SUM(p.expected_amount), SUM(p.commission_amount),
        MAX(l.commission_rate), 6, CURRENT_DATE, CURRENT_DATE + INTERVAL '7 days',
        0, 0, false
    FROM payments p
    JOIN loans l ON p.loan_id = l.id
    WHERE p.cut_period_id = $PERIOD_ID
      AND l.associate_user_id IS NOT NULL
    GROUP BY l.associate_user_id
    ON CONFLICT DO NOTHING;
    SELECT COUNT(*) FROM associate_payment_statements WHERE cut_period_id = $PERIOD_ID AND status_id = 6;
" | tail -1 | tr -d ' ')

# Obtener total de comisiones
total_commission=$(run_sql "
    SELECT COALESCE(SUM(total_commission_owed), 0)::numeric(12,2)
    FROM associate_payment_statements 
    WHERE cut_period_id = $PERIOD_ID
" | tr -d ' ')

log "============================================================"
log "📊 RESUMEN DEL CORTE"
log "============================================================"
log "   Período: $CUT_CODE"
log "   Statements generados: $statements_created"
log "   Total comisiones: \$$total_commission"
log "============================================================"
log "✅ Corte completado exitosamente"
