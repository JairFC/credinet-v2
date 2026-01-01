#!/bin/bash
# =============================================================================
# CREDINET v2.0 - RESTAURAR BACKUP
# =============================================================================
# Uso: ./restaurar_backup.sh <archivo_backup.tar.gz> [--clean-data]
# 
# Opciones:
#   --clean-data: Restaura solo esquema y funciones, sin datos de prueba
# =============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

BACKUP_FILE="$1"
CLEAN_DATA="$2"

if [ -z "$BACKUP_FILE" ]; then
    echo -e "${RED}❌ Error: Debe especificar el archivo de backup${NC}"
    echo "Uso: $0 <archivo_backup.tar.gz> [--clean-data]"
    exit 1
fi

if [ ! -f "$BACKUP_FILE" ]; then
    echo -e "${RED}❌ Error: No se encuentra el archivo $BACKUP_FILE${NC}"
    exit 1
fi

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║           CREDINET v2.0 - RESTAURAR BACKUP                  ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Crear directorio temporal
TEMP_DIR=$(mktemp -d)
echo -e "${YELLOW}📁 Extrayendo en: ${TEMP_DIR}${NC}"

tar -xzf "$BACKUP_FILE" -C "$TEMP_DIR"
BACKUP_DIR=$(ls "$TEMP_DIR")
BACKUP_PATH="${TEMP_DIR}/${BACKUP_DIR}"

echo ""
echo -e "${YELLOW}⚠️  ADVERTENCIA: Esto sobrescribirá la base de datos actual${NC}"
read -p "¿Continuar? (s/n): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    echo "Cancelado."
    rm -rf "$TEMP_DIR"
    exit 0
fi

# =============================================================================
# 1. DETENER SERVICIOS
# =============================================================================
echo -e "${GREEN}[1/5] 🛑 Deteniendo servicios...${NC}"
cd /home/credicuenta/proyectos/credinet-v2
docker-compose stop backend frontend

# =============================================================================
# 2. RESTAURAR BASE DE DATOS
# =============================================================================
echo -e "${GREEN}[2/5] 💾 Restaurando base de datos...${NC}"

if [ "$CLEAN_DATA" == "--clean-data" ]; then
    echo -e "${YELLOW}   Modo: Solo esquema (sin datos de prueba)${NC}"
    
    # Recrear base de datos vacía
    docker exec credinet-postgres psql -U credinet_user -d postgres -c "
        DROP DATABASE IF EXISTS credinet_db;
        CREATE DATABASE credinet_db;
    "
    
    # Restaurar solo esquema
    docker cp "${BACKUP_PATH}/schema_only.sql" credinet-postgres:/tmp/
    docker exec credinet-postgres psql -U credinet_user -d credinet_db -f /tmp/schema_only.sql
    
    echo -e "${GREEN}   ✅ Esquema restaurado (base de datos vacía)${NC}"
else
    echo -e "${YELLOW}   Modo: Completo (esquema + datos)${NC}"
    
    # Recrear base de datos
    docker exec credinet-postgres psql -U credinet_user -d postgres -c "
        DROP DATABASE IF EXISTS credinet_db;
        CREATE DATABASE credinet_db;
    "
    
    # Restaurar backup completo
    docker cp "${BACKUP_PATH}/database_full.dump" credinet-postgres:/tmp/
    docker exec credinet-postgres pg_restore -U credinet_user -d credinet_db --no-owner /tmp/database_full.dump
    
    echo -e "${GREEN}   ✅ Base de datos completa restaurada${NC}"
fi

# =============================================================================
# 3. RESTAURAR VOLÚMENES
# =============================================================================
echo -e "${GREEN}[3/5] 🐳 Restaurando volúmenes...${NC}"

# Restaurar uploads
if [ -f "${BACKUP_PATH}/uploads_volume.tar.gz" ]; then
    docker run --rm \
        -v credinet-backend-uploads:/target \
        -v "${BACKUP_PATH}":/backup \
        alpine sh -c "rm -rf /target/* && tar xzf /backup/uploads_volume.tar.gz -C /target"
    echo -e "   ✅ Uploads restaurados"
fi

# Restaurar logs
if [ -f "${BACKUP_PATH}/logs_volume.tar.gz" ]; then
    docker run --rm \
        -v credinet-backend-logs:/target \
        -v "${BACKUP_PATH}":/backup \
        alpine sh -c "rm -rf /target/* && tar xzf /backup/logs_volume.tar.gz -C /target"
    echo -e "   ✅ Logs restaurados"
fi

# =============================================================================
# 4. RESTAURAR CONFIGURACIÓN
# =============================================================================
echo -e "${GREEN}[4/5] ⚙️ Restaurando configuración...${NC}"

if [ -f "${BACKUP_PATH}/env_backup" ]; then
    cp "${BACKUP_PATH}/env_backup" /home/credicuenta/proyectos/credinet-v2/.env
    echo -e "   ✅ .env restaurado"
fi

# =============================================================================
# 5. REINICIAR SERVICIOS
# =============================================================================
echo -e "${GREEN}[5/5] 🚀 Reiniciando servicios...${NC}"
docker-compose up -d

# Esperar a que estén healthy
echo -e "${YELLOW}   Esperando a que los servicios estén listos...${NC}"
sleep 10

# Verificar estado
docker-compose ps

# Limpiar
rm -rf "$TEMP_DIR"

echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║              ✅ RESTAURACIÓN COMPLETADA                      ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}🌐 Frontend: http://192.168.98.98:5173${NC}"
echo -e "${GREEN}🔧 Backend: http://192.168.98.98:8000${NC}"
echo -e "${GREEN}📊 Database: localhost:5432${NC}"
