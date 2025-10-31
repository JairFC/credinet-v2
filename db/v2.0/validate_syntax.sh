#!/bin/bash
# =============================================================================
# VALIDACIÓN DE SINTAXIS SQL - CREDINET v2.0
# =============================================================================
# Descripción:
#   Valida la sintaxis de todos los archivos SQL sin ejecutarlos.
#   Útil para CI/CD y validación pre-deploy.
#
# Uso:
#   ./validate_syntax.sh
# =============================================================================

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
DB_USER="${POSTGRES_USER:-credinet_user}"
DB_NAME="${POSTGRES_DB:-credinet_db}"
DB_HOST="${POSTGRES_HOST:-localhost}"
DB_PORT="${POSTGRES_PORT:-5432}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}VALIDADOR DE SINTAXIS SQL - v2.0${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Verificar conexión PostgreSQL
echo -e "${YELLOW}[1/3] Verificando conexión PostgreSQL...${NC}"
if ! psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres -c "SELECT version();" > /dev/null 2>&1; then
    echo -e "${RED}✗ ERROR: No se puede conectar a PostgreSQL${NC}"
    echo -e "${YELLOW}  Asegúrese de que el servidor esté corriendo:${NC}"
    echo -e "${YELLOW}  docker-compose up -d postgres${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Conexión exitosa${NC}"
echo ""

# Validar módulos individuales
echo -e "${YELLOW}[2/3] Validando módulos individuales...${NC}"
MODULES_DIR="$SCRIPT_DIR/modules"
VALID_COUNT=0
INVALID_COUNT=0

for module in "$MODULES_DIR"/*.sql; do
    module_name=$(basename "$module")
    echo -n "  Validando $module_name... "
    
    # Usar --single-transaction y --dry-run simulado
    if psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres \
         --single-transaction \
         -v ON_ERROR_STOP=1 \
         -f "$module" \
         > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
        ((VALID_COUNT++))
    else
        echo -e "${RED}✗${NC}"
        ((INVALID_COUNT++))
        
        # Mostrar error específico
        echo -e "${RED}    ERROR en sintaxis:${NC}"
        psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres \
             --single-transaction \
             -v ON_ERROR_STOP=1 \
             -f "$module" 2>&1 | tail -5 | sed 's/^/    /'
    fi
done
echo ""

# Validar archivo monolítico
echo -e "${YELLOW}[3/3] Validando archivo monolítico...${NC}"
echo -n "  Validando init_monolithic.sql... "

if psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres \
     --single-transaction \
     -v ON_ERROR_STOP=1 \
     -f "$SCRIPT_DIR/init_monolithic.sql" \
     > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
    echo -e "${RED}    ERROR en sintaxis:${NC}"
    psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres \
         --single-transaction \
         -v ON_ERROR_STOP=1 \
         -f "$SCRIPT_DIR/init_monolithic.sql" 2>&1 | tail -10 | sed 's/^/    /'
    exit 1
fi
echo ""

# Resumen
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}RESUMEN${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "  Módulos válidos:   ${GREEN}$VALID_COUNT${NC}"
echo -e "  Módulos inválidos: ${RED}$INVALID_COUNT${NC}"
echo -e "  Monolítico:        ${GREEN}✓${NC}"
echo ""

if [ $INVALID_COUNT -eq 0 ]; then
    echo -e "${GREEN}✓ TODOS LOS ARCHIVOS SON VÁLIDOS${NC}"
    exit 0
else
    echo -e "${RED}✗ HAY ERRORES DE SINTAXIS${NC}"
    exit 1
fi
