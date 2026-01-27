#!/bin/bash
# =============================================================================
# CrediNet V2 - Script de Restauración de Backup
# =============================================================================
# Uso:
#   ./scripts/restore-db.sh                     # Listar backups disponibles
#   ./scripts/restore-db.sh backup_XXX.sql.gz   # Restaurar backup específico
#   ./scripts/restore-db.sh --latest            # Restaurar el más reciente
#   ./scripts/restore-db.sh --from-drive        # Listar backups en Google Drive
# =============================================================================

set -e

PROJECT_DIR="/home/jair/proyectos/credinet-v2"
BACKUP_DIR="$PROJECT_DIR/backups"
DB_CONTAINER="credinet-postgres"
DB_USER="credinet_user"
DB_NAME="credinet_db"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

show_help() {
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}  CrediNet V2 - Restauración de Backup${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "Uso:"
    echo "  $0                           # Listar backups disponibles"
    echo "  $0 <archivo.sql.gz>          # Restaurar backup específico"
    echo "  $0 --latest                  # Restaurar el más reciente"
    echo "  $0 --from-drive              # Listar backups en Google Drive"
    echo "  $0 --download <archivo>      # Descargar backup de Drive"
    echo ""
}

list_local_backups() {
    echo -e "${GREEN}📁 Backups locales disponibles:${NC}"
    echo ""
    if [ -d "$BACKUP_DIR" ] && ls "$BACKUP_DIR"/*.sql.gz &>/dev/null; then
        ls -lht "$BACKUP_DIR"/*.sql.gz | awk '{printf "  %-45s %6s  %s %s %s\n", $NF, $5, $6, $7, $8}'
    else
        echo "  (No hay backups locales)"
    fi
    echo ""
}

list_drive_backups() {
    echo -e "${GREEN}☁️  Backups en Google Drive:${NC}"
    echo ""
    if command -v rclone &>/dev/null; then
        rclone ls gdrive:credinet-backups/ 2>/dev/null | awk '{printf "  %-45s %10s bytes\n", $2, $1}'
    else
        echo "  (rclone no está instalado)"
    fi
    echo ""
}

download_from_drive() {
    local file="$1"
    echo -e "${YELLOW}Descargando $file desde Google Drive...${NC}"
    rclone copy "gdrive:credinet-backups/$file" "$BACKUP_DIR/" --progress
    echo -e "${GREEN}✅ Descargado a $BACKUP_DIR/$file${NC}"
}

restore_backup() {
    local backup_file="$1"
    
    # Si es ruta relativa, buscar en BACKUP_DIR
    if [[ ! "$backup_file" = /* ]]; then
        if [ -f "$BACKUP_DIR/$backup_file" ]; then
            backup_file="$BACKUP_DIR/$backup_file"
        elif [ -f "$backup_file" ]; then
            backup_file="$(pwd)/$backup_file"
        fi
    fi
    
    if [ ! -f "$backup_file" ]; then
        echo -e "${RED}❌ Error: No se encontró el archivo $backup_file${NC}"
        exit 1
    fi
    
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}  ⚠️  ADVERTENCIA: RESTAURACIÓN DE BASE DE DATOS${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "Archivo: $(basename $backup_file)"
    echo "Tamaño:  $(du -h "$backup_file" | cut -f1)"
    echo ""
    echo -e "${RED}ESTO REEMPLAZARÁ TODOS LOS DATOS ACTUALES${NC}"
    echo ""
    read -p "¿Estás seguro? Escribe 'SI' para continuar: " confirm
    
    if [ "$confirm" != "SI" ]; then
        echo "Cancelado."
        exit 0
    fi
    
    echo ""
    echo -e "${YELLOW}Creando backup de seguridad antes de restaurar...${NC}"
    local safety_backup="$BACKUP_DIR/pre_restore_$(date '+%Y%m%d_%H%M%S').sql.gz"
    docker exec "$DB_CONTAINER" pg_dump -U "$DB_USER" -d "$DB_NAME" --clean --if-exists | gzip > "$safety_backup"
    echo -e "${GREEN}✅ Backup de seguridad: $safety_backup${NC}"
    
    echo ""
    echo -e "${YELLOW}Restaurando base de datos...${NC}"
    
    # Descomprimir y restaurar
    gunzip -c "$backup_file" | docker exec -i "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" --quiet 2>&1 | grep -v "^DROP" | grep -v "^ALTER" | head -20
    
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  ✅ RESTAURACIÓN COMPLETADA${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # Verificar
    echo "Verificando datos restaurados..."
    docker exec "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -c "SELECT COUNT(*) as usuarios FROM users;" 2>/dev/null
    docker exec "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -c "SELECT COUNT(*) as prestamos FROM loans;" 2>/dev/null
}

# Main
case "${1:-}" in
    "")
        show_help
        list_local_backups
        ;;
    --help|-h)
        show_help
        ;;
    --latest)
        latest=$(ls -t "$BACKUP_DIR"/*.sql.gz 2>/dev/null | head -1)
        if [ -z "$latest" ]; then
            echo -e "${RED}❌ No hay backups disponibles${NC}"
            exit 1
        fi
        restore_backup "$latest"
        ;;
    --from-drive)
        list_drive_backups
        ;;
    --download)
        if [ -z "$2" ]; then
            echo -e "${RED}❌ Especifica el archivo a descargar${NC}"
            list_drive_backups
            exit 1
        fi
        download_from_drive "$2"
        ;;
    *)
        restore_backup "$1"
        ;;
esac
