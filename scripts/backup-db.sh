#!/bin/bash
# =============================================================================
# CrediNet V2 - Script de Backup Automático de Base de Datos
# =============================================================================
# Autor: GitHub Copilot + Jair
# Fecha: 2026-01-23
#
# Uso:
#   ./scripts/backup-db.sh              # Backup normal
#   ./scripts/backup-db.sh --retention 30  # Cambiar días de retención
#
# Configurar en crontab para backups automáticos:
#   0 2 * * * /home/jair/proyectos/credinet-v2/scripts/backup-db.sh >> /home/jair/proyectos/credinet-v2/logs/backups.log 2>&1
#
# =============================================================================

set -e

# =============================================================================
# CONFIGURACIÓN
# =============================================================================
PROJECT_DIR="/home/jair/proyectos/credinet-v2"
BACKUP_DIR="$PROJECT_DIR/backups"
LOG_FILE="$PROJECT_DIR/logs/backups.log"
RETENTION_DAYS=30  # Mantener backups por 30 días
DB_CONTAINER="credinet-postgres"
DB_USER="credinet_user"
DB_NAME="credinet_db"

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# =============================================================================
# FUNCIONES
# =============================================================================

log() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} $@" | tee -a "$LOG_FILE"
}

log_success() {
    log "${GREEN}✅${NC} $@"
}

log_warning() {
    log "${YELLOW}⚠${NC} $@"
}

log_error() {
    log "${RED}❌${NC} $@"
}

create_backup() {
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local backup_file="$BACKUP_DIR/backup_${timestamp}.sql"
    local backup_compressed="${backup_file}.gz"
    
    log "Iniciando backup de base de datos..."
    
    # Crear directorio de backups si no existe
    mkdir -p "$BACKUP_DIR"
    mkdir -p "$(dirname "$LOG_FILE")"
    
    # Verificar que el contenedor está corriendo
    if ! docker ps | grep -q "$DB_CONTAINER"; then
        log_error "El contenedor $DB_CONTAINER no está corriendo"
        return 1
    fi
    
    # Crear backup
    log "Exportando datos..."
    if docker exec "$DB_CONTAINER" pg_dump \
        -U "$DB_USER" \
        -d "$DB_NAME" \
        --clean --if-exists \
        --verbose \
        > "$backup_file" 2>> "$LOG_FILE"; then
        
        # Comprimir backup
        log "Comprimiendo backup..."
        gzip "$backup_file"
        
        # Verificar tamaño
        local size=$(du -h "$backup_compressed" | cut -f1)
        log_success "Backup creado: $backup_compressed ($size)"
        
        # Verificar integridad (que el archivo no esté vacío y sea válido)
        if [ -s "$backup_compressed" ] && gunzip -t "$backup_compressed" 2>/dev/null; then
            log_success "Integridad del backup verificada"
        else
            log_error "El backup está corrupto o vacío"
            rm -f "$backup_compressed"
            return 1
        fi
        
        return 0
    else
        log_error "Falló la creación del backup"
        rm -f "$backup_file" "$backup_compressed"
        return 1
    fi
}

cleanup_old_backups() {
    log "Limpiando backups antiguos (retención: $RETENTION_DAYS días)..."
    
    local count_before=$(ls -1 "$BACKUP_DIR"/backup_*.sql.gz 2>/dev/null | wc -l)
    
    # Eliminar backups más antiguos que RETENTION_DAYS
    find "$BACKUP_DIR" -name "backup_*.sql.gz" -type f -mtime +$RETENTION_DAYS -delete
    
    local count_after=$(ls -1 "$BACKUP_DIR"/backup_*.sql.gz 2>/dev/null | wc -l)
    local deleted=$((count_before - count_after))
    
    if [ $deleted -gt 0 ]; then
        log_success "Eliminados $deleted backups antiguos"
    fi
    
    log "Backups actuales: $count_after"
}

show_backup_stats() {
    log "═══════════════════════════════════════════════════════════════"
    log "Estadísticas de Backups"
    log "═══════════════════════════════════════════════════════════════"
    
    if [ -d "$BACKUP_DIR" ] && [ "$(ls -A $BACKUP_DIR/backup_*.sql.gz 2>/dev/null)" ]; then
        log ""
        log "Últimos 5 backups:"
        ls -lht "$BACKUP_DIR"/backup_*.sql.gz | head -5 | awk '{print "  " $9 " - " $5 " - " $6 " " $7 " " $8}'
        log ""
        
        local total_size=$(du -sh "$BACKUP_DIR" | cut -f1)
        local total_count=$(ls -1 "$BACKUP_DIR"/backup_*.sql.gz | wc -l)
        
        log "Total backups: $total_count"
        log "Espacio usado: $total_size"
        log ""
        
        # Backup más antiguo y más reciente
        local oldest=$(ls -t "$BACKUP_DIR"/backup_*.sql.gz | tail -1)
        local newest=$(ls -t "$BACKUP_DIR"/backup_*.sql.gz | head -1)
        
        if [ -n "$oldest" ]; then
            local oldest_date=$(stat -c %y "$oldest" | cut -d' ' -f1)
            log "Backup más antiguo: $(basename $oldest) ($oldest_date)"
        fi
        
        if [ -n "$newest" ]; then
            local newest_date=$(stat -c %y "$newest" | cut -d' ' -f1)
            log "Backup más reciente: $(basename $newest) ($newest_date)"
        fi
    else
        log_warning "No hay backups en $BACKUP_DIR"
    fi
    
    log "═══════════════════════════════════════════════════════════════"
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    # Parsear argumentos
    while [ $# -gt 0 ]; do
        case "$1" in
            --retention)
                RETENTION_DAYS="$2"
                shift 2
                ;;
            --stats)
                show_backup_stats
                exit 0
                ;;
            --help)
                cat << EOF
CrediNet V2 - Script de Backup Automático

Uso:
    $0 [opciones]

Opciones:
    --retention N    Mantener backups por N días (default: 30)
    --stats          Mostrar estadísticas de backups
    --help           Mostrar esta ayuda

Ejemplos:
    $0                      # Backup con retención de 30 días
    $0 --retention 60       # Backup con retención de 60 días
    $0 --stats              # Ver estadísticas

Configurar backup automático diario:
    crontab -e
    # Agregar línea:
    0 2 * * * $PROJECT_DIR/scripts/backup-db.sh >> $LOG_FILE 2>&1

Restaurar un backup:
    gunzip -c $BACKUP_DIR/backup_YYYYMMDD_HHMMSS.sql.gz | \\
        docker exec -i $DB_CONTAINER psql -U $DB_USER -d $DB_NAME

EOF
                exit 0
                ;;
            *)
                log_error "Opción desconocida: $1"
                exit 1
                ;;
        esac
    done
    
    log "═══════════════════════════════════════════════════════════════"
    log "CrediNet V2 - Backup de Base de Datos"
    log "$(date '+%Y-%m-%d %H:%M:%S')"
    log "═══════════════════════════════════════════════════════════════"
    log ""
    
    # Crear backup
    if create_backup; then
        # Limpiar backups antiguos
        cleanup_old_backups
        
        log ""
        log_success "═══════════════════════════════════════════════════════════════"
        log_success "  BACKUP COMPLETADO EXITOSAMENTE"
        log_success "═══════════════════════════════════════════════════════════════"
        log ""
        
        # Mostrar stats
        show_backup_stats
        
        exit 0
    else
        log ""
        log_error "═══════════════════════════════════════════════════════════════"
        log_error "  BACKUP FALLÓ"
        log_error "═══════════════════════════════════════════════════════════════"
        log ""
        exit 1
    fi
}

# Ejecutar
main "$@"
