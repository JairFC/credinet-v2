#!/bin/bash
# ==============================================================================
# SCRIPT DE RESTAURACIÓN DE BACKUP
# ==============================================================================
# Descripción: Restaura la base de datos desde un backup específico
# Uso: ./scripts/database/restore_backup.sh [archivo_backup]
# ==============================================================================

set -e

# Configuración
BACKUP_DIR="/home/credicuenta/proyectos/credinet-v2/db/backups"
CONTAINER_NAME="credinet-postgres"
DB_USER="credinet_user"
DB_NAME="credinet_db"

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║         RESTAURACIÓN DE BACKUP - CREDINET                ║${NC}"
echo -e "${YELLOW}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

# Si no se proporciona archivo, mostrar lista
if [ -z "$1" ]; then
    echo -e "${YELLOW}Backups disponibles:${NC}"
    echo ""
    ls -lth "$BACKUP_DIR"/*.gz 2>/dev/null | nl | awk '{print "  ["$1"] "$10" ("$6")"}'
    echo ""
    echo -e "Uso: $0 ${GREEN}<numero>${NC} o ${GREEN}<ruta_completa>${NC}"
    echo ""
    echo "Ejemplos:"
    echo "  $0 1                                    # Restaurar backup #1"
    echo "  $0 backup_2025-11-06_02-16-17.sql.gz   # Restaurar backup específico"
    echo "  $0 catalogs                             # Restaurar solo catálogos (más reciente)"
    echo ""
    exit 0
fi

# Determinar archivo a restaurar
if [[ "$1" =~ ^[0-9]+$ ]]; then
    # Es un número - seleccionar de la lista
    BACKUP_FILE=$(ls -1t "$BACKUP_DIR"/*.gz 2>/dev/null | sed -n "${1}p")
    if [ -z "$BACKUP_FILE" ]; then
        echo -e "${RED}❌ Error: No se encontró backup #$1${NC}"
        exit 1
    fi
elif [ "$1" == "catalogs" ]; then
    # Restaurar catálogos más reciente
    BACKUP_FILE=$(ls -1t "$BACKUP_DIR"/catalogs_*.gz 2>/dev/null | head -1)
    if [ -z "$BACKUP_FILE" ]; then
        echo -e "${RED}❌ Error: No se encontró backup de catálogos${NC}"
        exit 1
    fi
elif [ "$1" == "critical" ]; then
    # Restaurar crítico más reciente
    BACKUP_FILE=$(ls -1t "$BACKUP_DIR"/critical_*.gz 2>/dev/null | head -1)
    if [ -z "$BACKUP_FILE" ]; then
        echo -e "${RED}❌ Error: No se encontró backup crítico${NC}"
        exit 1
    fi
elif [ -f "$BACKUP_DIR/$1" ]; then
    # Archivo específico en directorio de backups
    BACKUP_FILE="$BACKUP_DIR/$1"
elif [ -f "$1" ]; then
    # Ruta completa
    BACKUP_FILE="$1"
else
    echo -e "${RED}❌ Error: Archivo no encontrado: $1${NC}"
    exit 1
fi

echo -e "${GREEN}Archivo seleccionado:${NC} $BACKUP_FILE"
BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
echo -e "${GREEN}Tamaño:${NC} $BACKUP_SIZE"
echo ""

# Confirmación
echo -e "${RED}⚠️  ADVERTENCIA: Esta operación sobrescribirá datos existentes${NC}"
echo -e "${YELLOW}¿Desea continuar? (escriba 'SI' para confirmar):${NC} "
read -r CONFIRM

if [ "$CONFIRM" != "SI" ]; then
    echo -e "${YELLOW}Operación cancelada${NC}"
    exit 0
fi

echo ""
echo -e "${YELLOW}[1/3]${NC} Descomprimiendo backup..."
TEMP_SQL="/tmp/restore_temp_$$.sql"
gunzip -c "$BACKUP_FILE" > "$TEMP_SQL"
echo -e "${GREEN}✅${NC} Backup descomprimido"

echo -e "${YELLOW}[2/3]${NC} Restaurando en base de datos..."
docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" < "$TEMP_SQL"
echo -e "${GREEN}✅${NC} Restauración completada"

echo -e "${YELLOW}[3/3]${NC} Limpiando archivos temporales..."
rm -f "$TEMP_SQL"
echo -e "${GREEN}✅${NC} Limpieza completada"

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║            RESTAURACIÓN COMPLETADA EXITOSAMENTE          ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
