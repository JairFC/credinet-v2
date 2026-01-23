#!/bin/bash
# =============================================================================
# CrediNet V2 - Script de Deployment Inteligente para Producción
# =============================================================================
# Autor: GitHub Copilot + Jair
# Fecha: 2026-01-23
# 
# Uso:
#   ./scripts/deploy.sh              # Deploy normal desde origin/main
#   ./scripts/deploy.sh --backup     # Forzar backup antes de deploy
#   ./scripts/deploy.sh --rollback   # Rollback al commit anterior
#   ./scripts/deploy.sh --help       # Mostrar ayuda
#
# Qué hace:
# 1. Verifica estado de Git y Docker
# 2. Hace backup automático de BD (si hay cambios en db/ o migrations/)
# 3. Pull de cambios desde GitHub
# 4. Detecta qué cambió (backend/frontend/db) y rebuild solo lo necesario
# 5. Reinicia servicios afectados con zero-downtime cuando posible
# 6. Verifica health después del deploy
# 7. Rollback automático si algo falla
# 8. Log de cada deployment en logs/deployments.log
# =============================================================================

set -e  # Exit on any error

# =============================================================================
# CONFIGURACIÓN
# =============================================================================
PROJECT_DIR="/home/jair/proyectos/credinet-v2"
LOG_FILE="$PROJECT_DIR/logs/deployments.log"
BACKUP_DIR="$PROJECT_DIR/backups"
BRANCH="main"
REMOTE="origin"

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# =============================================================================
# FUNCIONES AUXILIARES
# =============================================================================

log() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} [${level}] ${message}" | tee -a "$LOG_FILE"
}

log_info() {
    echo -e "${BLUE}ℹ${NC} $@"
    log "INFO" "$@"
}

log_success() {
    echo -e "${GREEN}✅${NC} $@"
    log "SUCCESS" "$@"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $@"
    log "WARNING" "$@"
}

log_error() {
    echo -e "${RED}❌${NC} $@"
    log "ERROR" "$@"
}

confirm() {
    local prompt="$1"
    read -p "$prompt [y/N]: " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]]
}

check_prerequisites() {
    log_info "Verificando prerequisitos..."
    
    # Verificar que estamos en el directorio correcto
    if [ ! -f "$PROJECT_DIR/docker-compose.yml" ]; then
        log_error "No se encontró docker-compose.yml en $PROJECT_DIR"
        exit 1
    fi
    
    # Verificar Docker
    if ! docker compose version &> /dev/null; then
        log_error "Docker Compose no está instalado o no está funcionando"
        exit 1
    fi
    
    # Verificar Git
    if ! git --version &> /dev/null; then
        log_error "Git no está instalado"
        exit 1
    fi
    
    # Crear directorio de logs si no existe
    mkdir -p "$(dirname "$LOG_FILE")"
    mkdir -p "$BACKUP_DIR"
    
    log_success "Prerequisitos verificados"
}

check_git_status() {
    log_info "Verificando estado de Git..."
    
    cd "$PROJECT_DIR"
    
    # Verificar que estamos en la branch correcta
    local current_branch=$(git branch --show-current)
    if [ "$current_branch" != "$BRANCH" ]; then
        log_warning "No estás en la branch '$BRANCH' (actual: $current_branch)"
        if ! confirm "¿Cambiar a $BRANCH?"; then
            log_error "Deploy cancelado"
            exit 1
        fi
        git checkout "$BRANCH"
    fi
    
    # Verificar cambios locales sin commitear
    if ! git diff-index --quiet HEAD --; then
        log_warning "Hay cambios locales sin commitear"
        git status --short
        if ! confirm "¿Continuar de todas formas?"; then
            log_error "Deploy cancelado. Commitea o descarta los cambios primero."
            exit 1
        fi
    fi
    
    log_success "Estado de Git verificado"
}

backup_database() {
    local reason="${1:-manual}"
    log_info "Creando backup de base de datos (razón: $reason)..."
    
    local backup_file="$BACKUP_DIR/backup_$(date '+%Y%m%d_%H%M%S').sql"
    
    if docker compose exec -T postgres pg_dump \
        -U credinet_user \
        -d credinet_db \
        --clean --if-exists \
        > "$backup_file" 2>/dev/null; then
        
        # Comprimir backup
        gzip "$backup_file"
        backup_file="${backup_file}.gz"
        
        local size=$(du -h "$backup_file" | cut -f1)
        log_success "Backup creado: $backup_file ($size)"
        
        # Guardar referencia al último backup para posible rollback
        echo "$backup_file" > "$BACKUP_DIR/.last_backup"
        
        # Limpiar backups antiguos (mantener últimos 10)
        cd "$BACKUP_DIR"
        ls -t backup_*.sql.gz 2>/dev/null | tail -n +11 | xargs -r rm
        
        return 0
    else
        log_error "Falló el backup de la base de datos"
        return 1
    fi
}

detect_changes() {
    log_info "Detectando cambios desde el último deploy..."
    
    cd "$PROJECT_DIR"
    
    # Obtener commit actual antes del pull
    local current_commit=$(git rev-parse HEAD)
    echo "$current_commit" > /tmp/credinet_last_commit
    
    # Fetch para ver qué hay nuevo
    git fetch "$REMOTE" "$BRANCH"
    
    local remote_commit=$(git rev-parse "$REMOTE/$BRANCH")
    
    if [ "$current_commit" == "$remote_commit" ]; then
        log_info "Ya estás en la última versión (commit: ${current_commit:0:7})"
        return 1
    fi
    
    log_info "Cambios detectados:"
    log_info "  Commit actual:  ${current_commit:0:7}"
    log_info "  Commit remoto:  ${remote_commit:0:7}"
    
    # Mostrar commits nuevos
    echo ""
    git log --oneline "$current_commit..$remote_commit"
    echo ""
    
    # Detectar archivos cambiados
    local changed_files=$(git diff --name-only "$current_commit" "$remote_commit")
    
    export NEEDS_BACKEND_REBUILD=false
    export NEEDS_FRONTEND_REBUILD=false
    export NEEDS_DB_BACKUP=false
    
    while IFS= read -r file; do
        case "$file" in
            backend/*|requirements.txt|backend.Dockerfile)
                NEEDS_BACKEND_REBUILD=true
                ;;
            frontend-mvp/*|package.json|frontend.Dockerfile)
                NEEDS_FRONTEND_REBUILD=true
                ;;
            db/*|*migration*|*alembic*)
                NEEDS_DB_BACKUP=true
                ;;
        esac
    done <<< "$changed_files"
    
    log_info "Análisis de cambios:"
    log_info "  Backend:  $([ "$NEEDS_BACKEND_REBUILD" == "true" ] && echo "🔄 Rebuild necesario" || echo "✓ Sin cambios")"
    log_info "  Frontend: $([ "$NEEDS_FRONTEND_REBUILD" == "true" ] && echo "🔄 Rebuild necesario" || echo "✓ Sin cambios")"
    log_info "  Database: $([ "$NEEDS_DB_BACKUP" == "true" ] && echo "💾 Backup recomendado" || echo "✓ Sin cambios")"
    
    return 0
}

pull_changes() {
    log_info "Descargando cambios desde GitHub..."
    
    cd "$PROJECT_DIR"
    
    if git pull "$REMOTE" "$BRANCH"; then
        local new_commit=$(git rev-parse HEAD)
        log_success "Código actualizado a commit ${new_commit:0:7}"
        return 0
    else
        log_error "Falló git pull"
        return 1
    fi
}

rebuild_services() {
    log_info "Reconstruyendo servicios..."
    
    cd "$PROJECT_DIR"
    
    local services_to_rebuild=()
    
    if [ "$NEEDS_BACKEND_REBUILD" == "true" ]; then
        services_to_rebuild+=("backend")
    fi
    
    if [ "$NEEDS_FRONTEND_REBUILD" == "true" ]; then
        services_to_rebuild+=("frontend")
    fi
    
    if [ ${#services_to_rebuild[@]} -eq 0 ]; then
        log_info "No hay servicios que reconstruir"
        return 0
    fi
    
    log_info "Rebuild de: ${services_to_rebuild[*]}"
    
    # Build sin cache para asegurar que tome los cambios
    if docker compose build --no-cache "${services_to_rebuild[@]}"; then
        log_success "Build completado"
    else
        log_error "Falló el build"
        return 1
    fi
    
    # Reiniciar servicios
    log_info "Reiniciando servicios..."
    if docker compose up -d "${services_to_rebuild[@]}"; then
        log_success "Servicios reiniciados"
    else
        log_error "Falló el reinicio de servicios"
        return 1
    fi
    
    # Si frontend cambió, hacer rebuild explícito del bundle
    if [ "$NEEDS_FRONTEND_REBUILD" == "true" ]; then
        log_info "Rebuilding frontend bundle..."
        sleep 5  # Esperar a que el contenedor esté listo
        if [ -f "$PROJECT_DIR/scripts/rebuild-frontend.sh" ]; then
            "$PROJECT_DIR/scripts/rebuild-frontend.sh"
        fi
    fi
}

verify_health() {
    log_info "Verificando health de servicios..."
    
    local max_attempts=12
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        log_info "Intento $attempt/$max_attempts..."
        
        # Verificar backend
        if curl -f -s http://localhost:8000/health > /dev/null 2>&1; then
            log_success "Backend: ✓ Healthy"
            
            # Verificar frontend (solo que responda, no necesita /health)
            if curl -f -s http://localhost:5173 > /dev/null 2>&1; then
                log_success "Frontend: ✓ Respondiendo"
                return 0
            else
                log_warning "Frontend: ✗ No responde aún"
            fi
        else
            log_warning "Backend: ✗ No responde aún"
        fi
        
        sleep 5
        ((attempt++))
    done
    
    log_error "Los servicios no pasaron el health check después de 60s"
    return 1
}

rollback() {
    log_error "Iniciando rollback..."
    
    cd "$PROJECT_DIR"
    
    # Obtener commit anterior
    if [ -f /tmp/credinet_last_commit ]; then
        local last_commit=$(cat /tmp/credinet_last_commit)
        log_info "Volviendo a commit $last_commit..."
        
        if git reset --hard "$last_commit"; then
            log_success "Código revertido"
            
            # Rebuild servicios
            log_info "Reconstruyendo servicios..."
            docker compose build --no-cache
            docker compose up -d
            
            # Restaurar backup de BD si existe
            if [ -f "$BACKUP_DIR/.last_backup" ]; then
                local backup_file=$(cat "$BACKUP_DIR/.last_backup")
                if [ -f "$backup_file" ]; then
                    log_info "¿Deseas restaurar el backup de BD? $backup_file"
                    if confirm "Restaurar BD"; then
                        gunzip -c "$backup_file" | docker compose exec -T postgres psql -U credinet_user -d credinet_db
                        log_success "Base de datos restaurada"
                    fi
                fi
            fi
            
            log_success "Rollback completado"
        else
            log_error "Falló el rollback"
        fi
    else
        log_error "No se encontró información del commit anterior"
    fi
}

show_help() {
    cat << EOF
CrediNet V2 - Script de Deployment

Uso:
    $0 [opciones]

Opciones:
    --backup        Forzar backup de BD antes de deploy
    --rollback      Rollback al commit anterior
    --help          Mostrar esta ayuda

Ejemplos:
    $0                  # Deploy normal
    $0 --backup         # Deploy con backup forzado
    $0 --rollback       # Deshacer último deploy

El script automáticamente:
  ✓ Verifica estado de Git y Docker
  ✓ Detecta qué cambió (backend/frontend/db)
  ✓ Hace backup si hay cambios en BD
  ✓ Rebuild solo lo necesario
  ✓ Verifica health después del deploy
  ✓ Rollback si algo falla

Logs: $LOG_FILE
Backups: $BACKUP_DIR
EOF
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    local force_backup=false
    local do_rollback=false
    
    # Parsear argumentos
    while [ $# -gt 0 ]; do
        case "$1" in
            --backup)
                force_backup=true
                shift
                ;;
            --rollback)
                do_rollback=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                log_error "Opción desconocida: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  CrediNet V2 - Deployment Script"
    echo "  $(date '+%Y-%m-%d %H:%M:%S')"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    
    # Rollback
    if [ "$do_rollback" == "true" ]; then
        rollback
        exit $?
    fi
    
    # Deploy normal
    check_prerequisites
    check_git_status
    
    if ! detect_changes; then
        log_info "No hay nada que deployar"
        exit 0
    fi
    
    # Backup si es necesario
    if [ "$force_backup" == "true" ] || [ "$NEEDS_DB_BACKUP" == "true" ]; then
        if ! backup_database "pre-deployment"; then
            log_warning "Falló el backup, pero continuamos..."
        fi
    fi
    
    # Confirmar deploy
    echo ""
    if ! confirm "¿Proceder con el deployment?"; then
        log_info "Deploy cancelado por el usuario"
        exit 0
    fi
    
    # Pull changes
    if ! pull_changes; then
        log_error "Falló el deployment en fase: pull"
        exit 1
    fi
    
    # Rebuild services
    if ! rebuild_services; then
        log_error "Falló el deployment en fase: rebuild"
        log_error "¿Deseas hacer rollback?"
        if confirm "Rollback"; then
            rollback
        fi
        exit 1
    fi
    
    # Verify health
    if ! verify_health; then
        log_error "Los servicios no están healthy después del deploy"
        log_error "¿Deseas hacer rollback?"
        if confirm "Rollback"; then
            rollback
        fi
        exit 1
    fi
    
    # Success!
    echo ""
    log_success "═══════════════════════════════════════════════════════════════"
    log_success "  ✅ DEPLOYMENT EXITOSO"
    log_success "═══════════════════════════════════════════════════════════════"
    echo ""
    log_info "Servicios disponibles:"
    log_info "  Frontend: http://10.5.26.141:5173"
    log_info "  Backend:  http://10.5.26.141:8000"
    log_info "  Docs:     http://10.5.26.141:8000/docs"
    echo ""
    log_info "Próximos pasos:"
    log_info "  1. Verificar funcionamiento en el navegador"
    log_info "  2. Revisar logs: docker compose logs -f backend frontend"
    log_info "  3. Monitorear scheduler: curl http://localhost:8000/api/v1/scheduler/status"
    echo ""
}

# Ejecutar
main "$@"
