#!/bin/bash
# =============================================================================
# SCRIPT DE BACKUP - VOLÚMENES DOCKER
# =============================================================================
# Descripción:
#   Respalda volúmenes Docker críticos (PostgreSQL, uploads, etc.)
#   Protege contra pérdida accidental (docker-compose down -v)
#
# Uso:
#   ./backup_volumes.sh                    # Backup manual
#   ./backup_volumes.sh restore FECHA      # Restaurar backup
#
# Ubicación backups: /home/credicuenta/proyectos/credinet-v2/db/backups/
# Retención: Últimos 30 días
# =============================================================================

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuración
PROJECT_ROOT="/home/credicuenta/proyectos/credinet-v2"
BACKUP_DIR="$PROJECT_ROOT/db/backups"
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
BACKUP_NAME="backup_${TIMESTAMP}"
BACKUP_PATH="$BACKUP_DIR/$BACKUP_NAME"

# Contenedores y volúmenes
DB_CONTAINER="credinet-postgres"
DB_VOLUME="credinet-v2_postgres_data"
UPLOADS_DIR="$PROJECT_ROOT/backend/uploads"

# Retención (días)
RETENTION_DAYS=30

# =============================================================================
# FUNCIONES
# =============================================================================

print_header() {
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}============================================${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

check_docker() {
    if ! docker ps &> /dev/null; then
        print_error "Docker no está corriendo o no tienes permisos"
        exit 1
    fi
}

check_container() {
    if ! docker ps --format '{{.Names}}' | grep -q "^${DB_CONTAINER}$"; then
        print_warning "Contenedor '$DB_CONTAINER' no está corriendo"
        return 1
    fi
    return 0
}

# =============================================================================
# BACKUP
# =============================================================================

do_backup() {
    print_header "BACKUP DE VOLÚMENES DOCKER"
    
    check_docker
    
    # Crear directorio de backup
    mkdir -p "$BACKUP_PATH"
    print_info "Directorio de backup: $BACKUP_PATH"
    echo ""
    
    # 1. Backup de PostgreSQL (pg_dump)
    echo -e "${YELLOW}[1/4] Respaldando base de datos PostgreSQL...${NC}"
    if check_container; then
        docker exec "$DB_CONTAINER" pg_dump \
            -U credinet_user \
            -d credinet_db \
            --format=custom \
            --compress=9 \
            --file=/tmp/db_backup.dump
        
        docker cp "$DB_CONTAINER:/tmp/db_backup.dump" "$BACKUP_PATH/postgres.dump"
        docker exec "$DB_CONTAINER" rm /tmp/db_backup.dump
        
        # También backup en SQL plano
        docker exec "$DB_CONTAINER" pg_dump \
            -U credinet_user \
            -d credinet_db \
            --format=plain \
            --file=/tmp/db_backup.sql
        
        docker cp "$DB_CONTAINER:/tmp/db_backup.sql" "$BACKUP_PATH/postgres.sql"
        docker exec "$DB_CONTAINER" rm /tmp/db_backup.sql
        
        print_success "Base de datos respaldada (formato binario + SQL)"
    else
        print_error "No se pudo respaldar PostgreSQL - contenedor no disponible"
    fi
    echo ""
    
    # 2. Backup de volumen Docker (tar)
    echo -e "${YELLOW}[2/4] Respaldando volumen Docker...${NC}"
    if docker volume ls | grep -q "$DB_VOLUME"; then
        docker run --rm \
            -v "$DB_VOLUME:/data" \
            -v "$BACKUP_PATH:/backup" \
            alpine tar czf /backup/postgres_volume.tar.gz -C /data .
        
        print_success "Volumen Docker respaldado (tar.gz)"
    else
        print_warning "Volumen '$DB_VOLUME' no encontrado"
    fi
    echo ""
    
    # 3. Backup de archivos subidos
    echo -e "${YELLOW}[3/4] Respaldando archivos subidos...${NC}"
    if [ -d "$UPLOADS_DIR" ]; then
        tar czf "$BACKUP_PATH/uploads.tar.gz" -C "$PROJECT_ROOT/backend" uploads
        print_success "Archivos subidos respaldados"
    else
        print_warning "Directorio uploads no encontrado"
    fi
    echo ""
    
    # 4. Backup de configuración
    echo -e "${YELLOW}[4/4] Respaldando configuración...${NC}"
    cp "$PROJECT_ROOT/docker-compose.yml" "$BACKUP_PATH/docker-compose.yml" 2>/dev/null || true
    cp "$PROJECT_ROOT/.env" "$BACKUP_PATH/.env" 2>/dev/null || true
    print_success "Configuración respaldada"
    echo ""
    
    # Generar manifest
    cat > "$BACKUP_PATH/MANIFEST.txt" << EOF
# BACKUP CREDINET v2.0
# ===================
Fecha: $(date '+%Y-%m-%d %H:%M:%S')
Host: $(hostname)
Usuario: $(whoami)

# CONTENIDO
- postgres.dump (formato binario, pg_restore)
- postgres.sql (formato SQL plano)
- postgres_volume.tar.gz (volumen Docker completo)
- uploads.tar.gz (archivos subidos por usuarios)
- docker-compose.yml (configuración)
- .env (variables de entorno)

# RESTAURACIÓN
Para restaurar este backup:
  ./backup_volumes.sh restore $BACKUP_NAME

# VERIFICACIÓN
EOF
    
    # Agregar tamaños
    du -h "$BACKUP_PATH"/* >> "$BACKUP_PATH/MANIFEST.txt"
    
    print_success "Manifest generado"
    echo ""
    
    # Resumen
    print_header "RESUMEN DEL BACKUP"
    TOTAL_SIZE=$(du -sh "$BACKUP_PATH" | cut -f1)
    echo -e "  Nombre:     ${GREEN}$BACKUP_NAME${NC}"
    echo -e "  Ubicación:  ${GREEN}$BACKUP_PATH${NC}"
    echo -e "  Tamaño:     ${GREEN}$TOTAL_SIZE${NC}"
    echo ""
    
    print_info "Archivos respaldados:"
    ls -lh "$BACKUP_PATH" | tail -n +2 | awk '{printf "  - %-30s %s\n", $9, $5}'
    echo ""
    
    print_success "BACKUP COMPLETADO EXITOSAMENTE"
}

# =============================================================================
# RESTAURACIÓN
# =============================================================================

do_restore() {
    local backup_name=$1
    local restore_path="$BACKUP_DIR/$backup_name"
    
    print_header "RESTAURAR BACKUP"
    
    if [ ! -d "$restore_path" ]; then
        print_error "Backup no encontrado: $backup_name"
        echo ""
        print_info "Backups disponibles:"
        ls -1 "$BACKUP_DIR" | grep "^backup_"
        exit 1
    fi
    
    check_docker
    
    if ! check_container; then
        print_error "Contenedor '$DB_CONTAINER' debe estar corriendo"
        exit 1
    fi
    
    print_warning "⚠️  ESTA OPERACIÓN SOBRESCRIBIRÁ LA BASE DE DATOS ACTUAL"
    echo ""
    read -p "¿Continuar? (escriba 'SI' para confirmar): " confirm
    
    if [ "$confirm" != "SI" ]; then
        print_info "Restauración cancelada"
        exit 0
    fi
    
    echo ""
    echo -e "${YELLOW}[1/3] Restaurando base de datos...${NC}"
    
    # Copiar dump al contenedor
    docker cp "$restore_path/postgres.dump" "$DB_CONTAINER:/tmp/restore.dump"
    
    # Desconectar usuarios activos
    docker exec "$DB_CONTAINER" psql -U credinet_user -d postgres -c \
        "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='credinet_db' AND pid <> pg_backend_pid();"
    
    # Recrear base de datos
    docker exec "$DB_CONTAINER" psql -U credinet_user -d postgres -c "DROP DATABASE IF EXISTS credinet_db;"
    docker exec "$DB_CONTAINER" psql -U credinet_user -d postgres -c "CREATE DATABASE credinet_db OWNER credinet_user;"
    
    # Restaurar
    docker exec "$DB_CONTAINER" pg_restore \
        -U credinet_user \
        -d credinet_db \
        --no-owner \
        --no-acl \
        /tmp/restore.dump
    
    docker exec "$DB_CONTAINER" rm /tmp/restore.dump
    
    print_success "Base de datos restaurada"
    echo ""
    
    echo -e "${YELLOW}[2/3] Restaurando archivos subidos...${NC}"
    if [ -f "$restore_path/uploads.tar.gz" ]; then
        rm -rf "$UPLOADS_DIR"
        tar xzf "$restore_path/uploads.tar.gz" -C "$PROJECT_ROOT/backend"
        print_success "Archivos subidos restaurados"
    else
        print_warning "No hay backup de uploads"
    fi
    echo ""
    
    echo -e "${YELLOW}[3/3] Verificando...${NC}"
    docker exec "$DB_CONTAINER" psql -U credinet_user -d credinet_db -c \
        "SELECT COUNT(*) as total_tables FROM information_schema.tables WHERE table_schema='public';"
    print_success "Verificación completada"
    echo ""
    
    print_success "RESTAURACIÓN COMPLETADA"
    print_warning "Reinicia los servicios: docker-compose restart"
}

# =============================================================================
# LIMPIEZA DE BACKUPS ANTIGUOS
# =============================================================================

cleanup_old_backups() {
    print_header "LIMPIEZA DE BACKUPS ANTIGUOS"
    
    print_info "Eliminando backups con más de $RETENTION_DAYS días..."
    
    find "$BACKUP_DIR" -maxdepth 1 -type d -name "backup_*" -mtime +$RETENTION_DAYS -print0 | while IFS= read -r -d '' backup; do
        backup_name=$(basename "$backup")
        backup_size=$(du -sh "$backup" | cut -f1)
        echo "  - Eliminando: $backup_name ($backup_size)"
        rm -rf "$backup"
    done
    
    print_success "Limpieza completada"
    echo ""
    
    # Mostrar backups restantes
    print_info "Backups actuales:"
    ls -lht "$BACKUP_DIR" | grep "^d" | head -10 | awk '{printf "  - %-35s %s\n", $9, $6" "$7" "$8}'
}

# =============================================================================
# LISTAR BACKUPS
# =============================================================================

list_backups() {
    print_header "BACKUPS DISPONIBLES"
    
    if [ ! -d "$BACKUP_DIR" ]; then
        print_warning "No hay backups disponibles"
        exit 0
    fi
    
    echo -e "${CYAN}Ubicación: $BACKUP_DIR${NC}"
    echo ""
    
    ls -lht "$BACKUP_DIR" | grep "^d" | awk '{
        printf "%-35s %10s  %s %s %s\n", $9, $5, $6, $7, $8
    }'
    
    echo ""
    total=$(ls -1d "$BACKUP_DIR"/backup_* 2>/dev/null | wc -l)
    total_size=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1)
    echo -e "Total: ${GREEN}$total${NC} backups (${GREEN}$total_size${NC})"
}

# =============================================================================
# MAIN
# =============================================================================

case "${1:-backup}" in
    backup)
        do_backup
        cleanup_old_backups
        ;;
    restore)
        if [ -z "$2" ]; then
            print_error "Especifica el nombre del backup a restaurar"
            echo ""
            list_backups
            exit 1
        fi
        do_restore "$2"
        ;;
    list)
        list_backups
        ;;
    cleanup)
        cleanup_old_backups
        ;;
    *)
        echo "Uso: $0 {backup|restore NOMBRE|list|cleanup}"
        exit 1
        ;;
esac
