#!/bin/bash
# =============================================================================
# CREDINET v2.0 - SCRIPT DE BACKUP COMPLETO
# =============================================================================
# Uso: ./backup_completo.sh [destino]
# Ejemplo: ./backup_completo.sh /media/usb/backups
#          ./backup_completo.sh  (usa directorio por defecto)
# =============================================================================

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuración
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
PROJECT_DIR="/home/credicuenta/proyectos/credinet-v2"
DEFAULT_BACKUP_DIR="${PROJECT_DIR}/backups"
BACKUP_DIR="${1:-$DEFAULT_BACKUP_DIR}"
BACKUP_NAME="credinet_backup_${TIMESTAMP}"
FULL_BACKUP_PATH="${BACKUP_DIR}/${BACKUP_NAME}"

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║           CREDINET v2.0 - BACKUP COMPLETO                   ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Crear directorio de backup
mkdir -p "${FULL_BACKUP_PATH}"

echo -e "${YELLOW}📁 Destino: ${FULL_BACKUP_PATH}${NC}"
echo ""

# =============================================================================
# 1. BACKUP DE BASE DE DATOS (Completo)
# =============================================================================
echo -e "${GREEN}[1/6] 💾 Respaldando base de datos completa...${NC}"

# Backup completo (esquema + datos)
docker exec credinet-postgres pg_dump -U credinet_user -d credinet_db \
    --no-owner \
    --no-privileges \
    --format=custom \
    -f /tmp/db_full.dump

docker cp credinet-postgres:/tmp/db_full.dump "${FULL_BACKUP_PATH}/database_full.dump"

# Backup solo esquema (para referencia)
docker exec credinet-postgres pg_dump -U credinet_user -d credinet_db \
    --schema-only \
    --no-owner \
    --no-privileges \
    -f /tmp/schema.sql

docker cp credinet-postgres:/tmp/schema.sql "${FULL_BACKUP_PATH}/schema_only.sql"

# Backup solo datos (INSERT statements)
docker exec credinet-postgres pg_dump -U credinet_user -d credinet_db \
    --data-only \
    --no-owner \
    --no-privileges \
    --inserts \
    -f /tmp/data.sql

docker cp credinet-postgres:/tmp/data.sql "${FULL_BACKUP_PATH}/data_only.sql"

echo -e "   ✅ database_full.dump (formato custom - restaurable)"
echo -e "   ✅ schema_only.sql (estructura)"
echo -e "   ✅ data_only.sql (datos en INSERT)"

# =============================================================================
# 2. BACKUP DE FUNCIONES Y TRIGGERS (Separado)
# =============================================================================
echo -e "${GREEN}[2/6] 🔧 Exportando funciones y triggers...${NC}"

docker exec credinet-postgres psql -U credinet_user -d credinet_db -c "
SELECT pg_get_functiondef(oid) || ';' as function_def
FROM pg_proc 
WHERE pronamespace = 'public'::regnamespace
ORDER BY proname;
" -t -A > "${FULL_BACKUP_PATH}/functions.sql"

docker exec credinet-postgres psql -U credinet_user -d credinet_db -c "
SELECT 
    'CREATE TRIGGER ' || tgname || ' ' ||
    CASE 
        WHEN tgtype & 2 = 2 THEN 'BEFORE'
        WHEN tgtype & 64 = 64 THEN 'INSTEAD OF'
        ELSE 'AFTER'
    END || ' ' ||
    CASE 
        WHEN tgtype & 4 = 4 THEN 'INSERT '
        ELSE ''
    END ||
    CASE 
        WHEN tgtype & 8 = 8 THEN 'DELETE '
        ELSE ''
    END ||
    CASE 
        WHEN tgtype & 16 = 16 THEN 'UPDATE '
        ELSE ''
    END ||
    'ON ' || relname || ' ' ||
    CASE 
        WHEN tgtype & 1 = 1 THEN 'FOR EACH ROW '
        ELSE 'FOR EACH STATEMENT '
    END ||
    'EXECUTE FUNCTION ' || proname || '();'
FROM pg_trigger t
JOIN pg_class c ON t.tgrelid = c.oid
JOIN pg_proc p ON t.tgfoid = p.oid
WHERE NOT tgisinternal
ORDER BY relname, tgname;
" -t -A > "${FULL_BACKUP_PATH}/triggers.sql"

echo -e "   ✅ functions.sql"
echo -e "   ✅ triggers.sql"

# =============================================================================
# 3. BACKUP DE CÓDIGO FUENTE
# =============================================================================
echo -e "${GREEN}[3/6] 📦 Respaldando código fuente...${NC}"

cd "${PROJECT_DIR}"

# Guardar estado de git
git rev-parse HEAD > "${FULL_BACKUP_PATH}/git_commit.txt"
git status > "${FULL_BACKUP_PATH}/git_status.txt"
git diff > "${FULL_BACKUP_PATH}/git_uncommitted_changes.patch" 2>/dev/null || true
git log --oneline -20 > "${FULL_BACKUP_PATH}/git_recent_commits.txt"

# Copiar archivos de configuración importantes
cp .env "${FULL_BACKUP_PATH}/env_backup" 2>/dev/null || echo "No .env found"
cp docker-compose.yml "${FULL_BACKUP_PATH}/"

# Comprimir código completo (excluyendo node_modules, __pycache__, .git)
tar --exclude='node_modules' \
    --exclude='__pycache__' \
    --exclude='.git' \
    --exclude='*.pyc' \
    --exclude='dist' \
    --exclude='backups' \
    -czf "${FULL_BACKUP_PATH}/source_code.tar.gz" \
    -C "$(dirname ${PROJECT_DIR})" \
    "$(basename ${PROJECT_DIR})"

echo -e "   ✅ git_commit.txt (commit actual)"
echo -e "   ✅ git_uncommitted_changes.patch (cambios no guardados)"
echo -e "   ✅ source_code.tar.gz (código completo)"

# =============================================================================
# 4. BACKUP DE VOLÚMENES DOCKER
# =============================================================================
echo -e "${GREEN}[4/6] 🐳 Respaldando volúmenes Docker...${NC}"

# Backup de uploads
docker run --rm \
    -v credinet-backend-uploads:/source:ro \
    -v "${FULL_BACKUP_PATH}":/backup \
    alpine tar czf /backup/uploads_volume.tar.gz -C /source .

# Backup de logs
docker run --rm \
    -v credinet-backend-logs:/source:ro \
    -v "${FULL_BACKUP_PATH}":/backup \
    alpine tar czf /backup/logs_volume.tar.gz -C /source .

echo -e "   ✅ uploads_volume.tar.gz"
echo -e "   ✅ logs_volume.tar.gz"

# =============================================================================
# 5. INFORMACIÓN DEL SISTEMA
# =============================================================================
echo -e "${GREEN}[5/6] 📋 Guardando información del sistema...${NC}"

{
    echo "=== CREDINET BACKUP INFO ==="
    echo "Fecha: $(date)"
    echo "Hostname: $(hostname)"
    echo "IP: $(hostname -I | awk '{print $1}')"
    echo ""
    echo "=== DOCKER CONTAINERS ==="
    docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"
    echo ""
    echo "=== DOCKER VOLUMES ==="
    docker volume ls
    echo ""
    echo "=== DOCKER IMAGES ==="
    docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}"
    echo ""
    echo "=== DATABASE SIZE ==="
    docker exec credinet-postgres psql -U credinet_user -d credinet_db -c "SELECT pg_size_pretty(pg_database_size('credinet_db'));"
    echo ""
    echo "=== TABLE COUNTS ==="
    docker exec credinet-postgres psql -U credinet_user -d credinet_db -c "
    SELECT 'users' as tabla, COUNT(*) as total FROM users
    UNION ALL SELECT 'associate_profiles', COUNT(*) FROM associate_profiles
    UNION ALL SELECT 'loans', COUNT(*) FROM loans
    UNION ALL SELECT 'payments', COUNT(*) FROM payments;
    "
} > "${FULL_BACKUP_PATH}/system_info.txt"

echo -e "   ✅ system_info.txt"

# =============================================================================
# 6. CREAR ARCHIVO FINAL COMPRIMIDO
# =============================================================================
echo -e "${GREEN}[6/6] 📦 Comprimiendo backup final...${NC}"

cd "${BACKUP_DIR}"
tar -czf "${BACKUP_NAME}.tar.gz" "${BACKUP_NAME}"

# Calcular tamaño
FINAL_SIZE=$(du -sh "${BACKUP_NAME}.tar.gz" | cut -f1)

# Limpiar directorio temporal
rm -rf "${BACKUP_NAME}"

echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                    ✅ BACKUP COMPLETADO                      ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}📁 Archivo: ${BACKUP_DIR}/${BACKUP_NAME}.tar.gz${NC}"
echo -e "${GREEN}📊 Tamaño: ${FINAL_SIZE}${NC}"
echo ""
echo -e "${YELLOW}📤 Para transferir por SSH:${NC}"
echo -e "   scp ${BACKUP_DIR}/${BACKUP_NAME}.tar.gz usuario@servidor:/destino/"
echo ""
echo -e "${YELLOW}📤 Para streaming directo (sin espacio local):${NC}"
echo -e "   ssh usuario@servidor 'cat > backup.tar.gz' < ${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"
