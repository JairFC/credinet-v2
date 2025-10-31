#!/bin/bash
# =============================================================================
# RESTORE DATABASE - CrediNet v2.0
# =============================================================================
# Restaura respaldo de la base de datos PostgreSQL
# Uso: ./scripts/database/restore_db.sh <nombre_backup>
# =============================================================================

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuración
BACKUP_DIR="./db/backups"
BACKUP_NAME="$1"

if [ -z "$BACKUP_NAME" ]; then
    echo -e "${RED}❌ Error: Debes especificar el nombre del backup${NC}"
    echo ""
    echo -e "${YELLOW}Uso: ./scripts/database/restore_db.sh <nombre_backup>${NC}"
    echo ""
    echo -e "${YELLOW}📋 Backups disponibles:${NC}"
    ls -lht "$BACKUP_DIR"/*.sql.gz 2>/dev/null | head -10 || echo "  (ninguno)"
    exit 1
fi

BACKUP_FILE="${BACKUP_DIR}/${BACKUP_NAME}.sql"
BACKUP_FILE_GZ="${BACKUP_FILE}.gz"

# Verificar que existe el backup
if [ ! -f "$BACKUP_FILE_GZ" ]; then
    echo -e "${RED}❌ Error: Backup no encontrado: ${BACKUP_FILE_GZ}${NC}"
    echo ""
    echo -e "${YELLOW}📋 Backups disponibles:${NC}"
    ls -lht "$BACKUP_DIR"/*.sql.gz 2>/dev/null | head -10 || echo "  (ninguno)"
    exit 1
fi

echo -e "${YELLOW}🔄 Iniciando restauración de base de datos...${NC}"
echo -e "${YELLOW}📁 Backup: ${BACKUP_FILE_GZ}${NC}"
echo ""

# Verificar que el contenedor está corriendo
if ! docker ps | grep -q credinet-postgres; then
    echo -e "${RED}❌ Error: Contenedor de PostgreSQL no está corriendo${NC}"
    echo -e "${YELLOW}💡 Ejecuta: docker-compose up -d postgres${NC}"
    exit 1
fi

# Confirmación (solo si no es modo silencioso)
if [ "$2" != "--yes" ]; then
    echo -e "${RED}⚠️  ADVERTENCIA: Esta operación ELIMINARÁ todos los datos actuales${NC}"
    read -p "¿Estás seguro? (escribe 'SI' para continuar): " -r
    echo
    if [[ ! $REPLY =~ ^SI$ ]]; then
        echo -e "${YELLOW}❌ Operación cancelada${NC}"
        exit 1
    fi
fi

# Descomprimir backup temporalmente
echo -e "${YELLOW}🗜️  Descomprimiendo backup...${NC}"
gunzip -c "$BACKUP_FILE_GZ" > "$BACKUP_FILE"

# Restaurar backup
echo -e "${YELLOW}📦 Restaurando base de datos...${NC}"
docker exec -i credinet-postgres psql \
    -U credinet_user \
    -d credinet_db \
    < "$BACKUP_FILE"

# Limpiar archivo temporal
rm -f "$BACKUP_FILE"

echo ""
echo -e "${GREEN}✅ Base de datos restaurada exitosamente!${NC}"
echo ""
echo -e "${YELLOW}💡 Próximos pasos:${NC}"
echo -e "${YELLOW}   1. Reinicia el backend: docker-compose restart backend${NC}"
echo -e "${YELLOW}   2. Verifica logs: docker-compose logs -f backend${NC}"
echo ""
