#!/bin/bash
# ==============================================================================
# SCRIPT DE BACKUP AUTOMÁTICO DIARIO
# ==============================================================================
# Descripción: Crea backups diarios de la base de datos PostgreSQL
#              Mantiene 3 backups históricos (borra los más antiguos)
#              Prioriza catálogos y datos críticos
# 
# Uso: ./scripts/database/backup_daily.sh
# Cronjob sugerido: 0 2 * * * /ruta/backup_daily.sh  # Cada día a las 2 AM
# ==============================================================================

set -e  # Salir si hay error

# Configuración
BACKUP_DIR="/home/credicuenta/proyectos/credinet-v2/db/backups"
CONTAINER_NAME="credinet-postgres"
DB_USER="credinet_user"
DB_NAME="credinet_db"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
MAX_BACKUPS=3  # Mantener solo los últimos 3 backups

# Colores para output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║         BACKUP DIARIO CREDINET DATABASE                  ║${NC}"
echo -e "${GREEN}╠═══════════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║  Fecha: $(date '+%Y-%m-%d %H:%M:%S')                      ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

# Crear directorio de backups si no existe
mkdir -p "$BACKUP_DIR"

# Nombre del archivo de backup
BACKUP_FILE="$BACKUP_DIR/backup_${TIMESTAMP}.sql"
CATALOGS_FILE="$BACKUP_DIR/catalogs_${TIMESTAMP}.sql"
CRITICAL_FILE="$BACKUP_DIR/critical_${TIMESTAMP}.sql"

echo -e "${YELLOW}[1/5]${NC} Creando backup COMPLETO de la base de datos..."
docker exec "$CONTAINER_NAME" pg_dump -U "$DB_USER" -d "$DB_NAME" \
    --format=plain \
    --encoding=UTF8 \
    --no-owner \
    --no-acl \
    > "$BACKUP_FILE"

BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
echo -e "${GREEN}✅${NC} Backup completo creado: $BACKUP_FILE (${BACKUP_SIZE})"
echo ""

echo -e "${YELLOW}[2/5]${NC} Creando backup de CATÁLOGOS (prioridad alta)..."
docker exec "$CONTAINER_NAME" pg_dump -U "$DB_USER" -d "$DB_NAME" \
    --format=plain \
    --encoding=UTF8 \
    --no-owner \
    --no-acl \
    --table=roles \
    --table=loan_statuses \
    --table=payment_statuses \
    --table=document_types \
    --table=document_statuses \
    --table=contract_statuses \
    --table=cut_period_statuses \
    --table=statement_statuses \
    --table=payment_methods \
    --table=associate_levels \
    --table=level_change_types \
    --table=config_types \
    --table=rate_profiles \
    > "$CATALOGS_FILE"

CATALOGS_SIZE=$(du -h "$CATALOGS_FILE" | cut -f1)
echo -e "${GREEN}✅${NC} Catálogos respaldados: $CATALOGS_FILE (${CATALOGS_SIZE})"
echo ""

echo -e "${YELLOW}[3/5]${NC} Creando backup de DATOS CRÍTICOS..."
docker exec "$CONTAINER_NAME" pg_dump -U "$DB_USER" -d "$DB_NAME" \
    --format=plain \
    --encoding=UTF8 \
    --no-owner \
    --no-acl \
    --table=users \
    --table=user_roles \
    --table=cut_periods \
    --table=system_configurations \
    > "$CRITICAL_FILE"

CRITICAL_SIZE=$(du -h "$CRITICAL_FILE" | cut -f1)
echo -e "${GREEN}✅${NC} Datos críticos respaldados: $CRITICAL_FILE (${CRITICAL_SIZE})"
echo ""

echo -e "${YELLOW}[4/5]${NC} Comprimiendo backups..."
gzip -f "$BACKUP_FILE"
gzip -f "$CATALOGS_FILE"
gzip -f "$CRITICAL_FILE"
echo -e "${GREEN}✅${NC} Backups comprimidos (.gz)"
echo ""

echo -e "${YELLOW}[5/5]${NC} Limpiando backups antiguos (manteniendo últimos ${MAX_BACKUPS})..."

# Función para limpiar backups antiguos por patrón
cleanup_old_backups() {
    local pattern=$1
    local count=$(ls -1t "$BACKUP_DIR"/${pattern}_*.sql.gz 2>/dev/null | wc -l)
    
    if [ "$count" -gt "$MAX_BACKUPS" ]; then
        local to_delete=$((count - MAX_BACKUPS))
        echo -e "  Eliminando $to_delete backups antiguos de tipo ${pattern}..."
        ls -1t "$BACKUP_DIR"/${pattern}_*.sql.gz | tail -n "$to_delete" | xargs rm -f
        echo -e "  ${GREEN}✅${NC} Limpieza completada"
    else
        echo -e "  ℹ️  Solo hay $count backups de ${pattern}, manteniendo todos"
    fi
}

cleanup_old_backups "backup"
cleanup_old_backups "catalogs"
cleanup_old_backups "critical"
echo ""

# Resumen final
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              BACKUP COMPLETADO EXITOSAMENTE              ║${NC}"
echo -e "${GREEN}╠═══════════════════════════════════════════════════════════╣${NC}"

TOTAL_BACKUPS=$(ls -1 "$BACKUP_DIR"/*.gz 2>/dev/null | wc -l)
TOTAL_SIZE=$(du -sh "$BACKUP_DIR" | cut -f1)

echo -e "${GREEN}║${NC}  Backups totales:      $TOTAL_BACKUPS archivos"
echo -e "${GREEN}║${NC}  Tamaño total:         $TOTAL_SIZE"
echo -e "${GREEN}║${NC}  Ubicación:            $BACKUP_DIR"
echo -e "${GREEN}╠═══════════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║  Tipos de backup:                                        ║${NC}"
echo -e "${GREEN}║${NC}    - backup_*.sql.gz     (Base de datos completa)"
echo -e "${GREEN}║${NC}    - catalogs_*.sql.gz   (Solo catálogos)"
echo -e "${GREEN}║${NC}    - critical_*.sql.gz   (Users + cut_periods + config)"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

# Listar backups actuales
echo "Backups actuales:"
ls -lth "$BACKUP_DIR"/*.gz 2>/dev/null | head -10 | awk '{print "  "$9" ("$5")"}'
echo ""

echo -e "${GREEN}✅ BACKUP DIARIO COMPLETADO${NC}"
echo ""
