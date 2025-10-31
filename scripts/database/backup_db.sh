#!/bin/bash
# =============================================================================
# BACKUP DATABASE - CrediNet v2.0
# =============================================================================
# Crea respaldo completo de la base de datos PostgreSQL
# Uso: ./scripts/database/backup_db.sh [nombre_backup]
# =============================================================================

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuración
BACKUP_DIR="./db/backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="${1:-backup_${TIMESTAMP}}"
BACKUP_FILE="${BACKUP_DIR}/${BACKUP_NAME}.sql"

echo -e "${YELLOW}🔄 Iniciando backup de base de datos...${NC}"

# Crear directorio de backups si no existe
mkdir -p "$BACKUP_DIR"

# Verificar que el contenedor está corriendo
if ! docker ps | grep -q credinet-postgres; then
    echo -e "${RED}❌ Error: Contenedor de PostgreSQL no está corriendo${NC}"
    echo -e "${YELLOW}💡 Ejecuta: docker-compose up -d postgres${NC}"
    exit 1
fi

# Crear backup
echo -e "${YELLOW}📦 Creando backup: ${BACKUP_FILE}${NC}"
docker exec credinet-postgres pg_dump \
    -U credinet_user \
    -d credinet_db \
    --clean \
    --if-exists \
    --no-owner \
    --no-privileges \
    > "$BACKUP_FILE"

# Comprimir backup
echo -e "${YELLOW}🗜️  Comprimiendo backup...${NC}"
gzip -f "$BACKUP_FILE"
BACKUP_FILE_GZ="${BACKUP_FILE}.gz"

# Verificar tamaño
BACKUP_SIZE=$(du -h "$BACKUP_FILE_GZ" | cut -f1)

echo ""
echo -e "${GREEN}✅ Backup completado exitosamente!${NC}"
echo -e "${GREEN}📁 Archivo: ${BACKUP_FILE_GZ}${NC}"
echo -e "${GREEN}📊 Tamaño: ${BACKUP_SIZE}${NC}"
echo ""
echo -e "${YELLOW}💡 Para restaurar:${NC}"
echo -e "${YELLOW}   ./scripts/database/restore_db.sh ${BACKUP_NAME}${NC}"
echo ""

# Listar últimos 5 backups
echo -e "${YELLOW}📋 Últimos backups disponibles:${NC}"
ls -lht "$BACKUP_DIR"/*.sql.gz 2>/dev/null | head -5 || echo "  (ninguno)"
