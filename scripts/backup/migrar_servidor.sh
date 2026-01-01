#!/bin/bash
# =============================================================================
# CREDINET v2.0 - MIGRAR A NUEVO SERVIDOR
# =============================================================================
# Este script se ejecuta en el SERVIDOR DESTINO
# 
# Requisitos en el servidor destino:
#   - Ubuntu 20.04+ / Debian 11+
#   - Docker y Docker Compose instalados
#   - Git instalado
#   - Usuario con permisos sudo
#
# Uso:
#   1. Copiar este script al nuevo servidor
#   2. Copiar el archivo de backup (.tar.gz)
#   3. Ejecutar: ./migrar_servidor.sh <backup.tar.gz>
# =============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

BACKUP_FILE="$1"

if [ -z "$BACKUP_FILE" ]; then
    echo -e "${RED}❌ Error: Debe especificar el archivo de backup${NC}"
    echo "Uso: $0 <credinet_backup_XXXXXX.tar.gz>"
    exit 1
fi

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║      CREDINET v2.0 - MIGRACIÓN A NUEVO SERVIDOR             ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# =============================================================================
# VERIFICAR REQUISITOS
# =============================================================================
echo -e "${GREEN}[1/7] 🔍 Verificando requisitos...${NC}"

# Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker no está instalado${NC}"
    echo "Instalar con: curl -fsSL https://get.docker.com | sh"
    exit 1
fi
echo -e "   ✅ Docker: $(docker --version | cut -d' ' -f3)"

# Docker Compose
if ! command -v docker-compose &> /dev/null; then
    if ! docker compose version &> /dev/null; then
        echo -e "${RED}❌ Docker Compose no está instalado${NC}"
        exit 1
    fi
fi
echo -e "   ✅ Docker Compose disponible"

# Git
if ! command -v git &> /dev/null; then
    echo -e "${YELLOW}⚠️ Git no instalado. Instalando...${NC}"
    sudo apt-get update && sudo apt-get install -y git
fi
echo -e "   ✅ Git: $(git --version)"

# =============================================================================
# EXTRAER BACKUP
# =============================================================================
echo -e "${GREEN}[2/7] 📦 Extrayendo backup...${NC}"

TEMP_DIR=$(mktemp -d)
tar -xzf "$BACKUP_FILE" -C "$TEMP_DIR"
BACKUP_DIR=$(ls "$TEMP_DIR")
BACKUP_PATH="${TEMP_DIR}/${BACKUP_DIR}"

echo -e "   ✅ Backup extraído en ${TEMP_DIR}"

# =============================================================================
# CREAR ESTRUCTURA DE DIRECTORIOS
# =============================================================================
echo -e "${GREEN}[3/7] 📁 Creando estructura de directorios...${NC}"

PROJECT_DIR="/home/$(whoami)/proyectos/credinet-v2"
mkdir -p "$(dirname ${PROJECT_DIR})"

# Extraer código fuente
tar -xzf "${BACKUP_PATH}/source_code.tar.gz" -C "$(dirname ${PROJECT_DIR})"

echo -e "   ✅ Código fuente en ${PROJECT_DIR}"

# =============================================================================
# RESTAURAR CONFIGURACIÓN
# =============================================================================
echo -e "${GREEN}[4/7] ⚙️ Configurando entorno...${NC}"

cd "$PROJECT_DIR"

# Restaurar .env
if [ -f "${BACKUP_PATH}/env_backup" ]; then
    cp "${BACKUP_PATH}/env_backup" .env
    
    # Actualizar IP del servidor (preguntar al usuario)
    CURRENT_IP=$(hostname -I | awk '{print $1}')
    echo ""
    echo -e "${YELLOW}La IP actual de este servidor es: ${CURRENT_IP}${NC}"
    read -p "¿Usar esta IP para el sistema? (s/n): " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        # Actualizar CORS y VITE_API_URL
        sed -i "s|192.168.98.98|${CURRENT_IP}|g" .env
        echo -e "   ✅ IP actualizada a ${CURRENT_IP}"
    fi
fi

# =============================================================================
# CONSTRUIR IMÁGENES DOCKER
# =============================================================================
echo -e "${GREEN}[5/7] 🐳 Construyendo imágenes Docker...${NC}"

docker-compose build --no-cache

echo -e "   ✅ Imágenes construidas"

# =============================================================================
# INICIAR SERVICIOS (sin datos aún)
# =============================================================================
echo -e "${GREEN}[6/7] 🚀 Iniciando servicios...${NC}"

# Primero solo postgres para restaurar datos
docker-compose up -d postgres
echo -e "   ⏳ Esperando que PostgreSQL inicie..."
sleep 15

# Verificar que postgres está listo
until docker exec credinet-postgres pg_isready -U credinet_user -d credinet_db; do
    echo -e "   ⏳ Esperando PostgreSQL..."
    sleep 5
done

# =============================================================================
# RESTAURAR BASE DE DATOS
# =============================================================================
echo -e "${GREEN}[7/7] 💾 Restaurando base de datos...${NC}"

echo ""
echo -e "${YELLOW}¿Cómo desea restaurar la base de datos?${NC}"
echo "  1) Completa (con datos de prueba)"
echo "  2) Solo estructura (para empezar con datos reales)"
read -p "Opción [1/2]: " DB_OPTION

if [ "$DB_OPTION" == "2" ]; then
    # Solo esquema
    docker cp "${BACKUP_PATH}/schema_only.sql" credinet-postgres:/tmp/
    docker exec credinet-postgres psql -U credinet_user -d credinet_db -f /tmp/schema_only.sql
    echo -e "   ✅ Esquema restaurado (base de datos vacía)"
    
    # Insertar usuario admin por defecto
    docker exec credinet-postgres psql -U credinet_user -d credinet_db -c "
    INSERT INTO users (username, email, password_hash, first_name, last_name, phone, user_type_id, is_active)
    VALUES ('admin', 'admin@credinet.com', '\$2b\$12\$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/X4.SU.f.7Z.X.Z.Z.', 'Administrador', 'Sistema', '0000000000', 1, true)
    ON CONFLICT (username) DO NOTHING;
    "
    echo -e "   ✅ Usuario admin creado (cambiar contraseña después)"
else
    # Completa
    docker cp "${BACKUP_PATH}/database_full.dump" credinet-postgres:/tmp/
    docker exec credinet-postgres pg_restore -U credinet_user -d credinet_db --no-owner --clean --if-exists /tmp/database_full.dump 2>/dev/null || true
    echo -e "   ✅ Base de datos completa restaurada"
fi

# =============================================================================
# RESTAURAR VOLÚMENES
# =============================================================================
echo -e "${GREEN}[EXTRA] 🗂️ Restaurando volúmenes...${NC}"

# Uploads
if [ -f "${BACKUP_PATH}/uploads_volume.tar.gz" ]; then
    docker run --rm \
        -v credinet-backend-uploads:/target \
        -v "${BACKUP_PATH}":/backup \
        alpine sh -c "tar xzf /backup/uploads_volume.tar.gz -C /target"
    echo -e "   ✅ Uploads restaurados"
fi

# =============================================================================
# INICIAR TODOS LOS SERVICIOS
# =============================================================================
echo -e "${GREEN}[FINAL] 🚀 Iniciando todos los servicios...${NC}"

docker-compose up -d

sleep 10

# Verificar estado
echo ""
docker-compose ps

# Limpiar
rm -rf "$TEMP_DIR"

FINAL_IP=$(hostname -I | awk '{print $1}')

echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║              ✅ MIGRACIÓN COMPLETADA                         ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}🌐 Frontend: http://${FINAL_IP}:5173${NC}"
echo -e "${GREEN}🔧 Backend:  http://${FINAL_IP}:8000${NC}"
echo -e "${GREEN}📊 API Docs: http://${FINAL_IP}:8000/docs${NC}"
echo ""
echo -e "${YELLOW}⚠️ IMPORTANTE:${NC}"
echo -e "   1. Verificar que el firewall permite puertos 5173, 8000, 5432"
echo -e "   2. Actualizar DNS/hosts si es necesario"
echo -e "   3. Cambiar contraseñas de producción en .env"
echo ""
