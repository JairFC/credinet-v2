#!/bin/bash
# =============================================================================
# CrediNet v2.0 - Pre-Flight Check para Migración
# =============================================================================
# Ejecutar ANTES de iniciar la migración
# Verifica que todo esté listo para migrar
# =============================================================================

set -e

echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║     CrediNet v2.0 - Pre-Flight Check para Migración                ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""

ERRORS=0
WARNINGS=0

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

check_pass() {
    echo -e "${GREEN}✓${NC} $1"
}

check_fail() {
    echo -e "${RED}✗${NC} $1"
    ((ERRORS++))
}

check_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
    ((WARNINGS++))
}

# =============================================================================
# 1. VERIFICAR SISTEMA LOCAL
# =============================================================================
echo "═══════════════════════════════════════════════════════════════════"
echo "1. VERIFICANDO SISTEMA LOCAL"
echo "═══════════════════════════════════════════════════════════════════"

# Docker corriendo
if docker info > /dev/null 2>&1; then
    check_pass "Docker daemon corriendo"
else
    check_fail "Docker no está corriendo"
fi

# Contenedores de CrediNet activos
if docker ps | grep -q "credinet"; then
    check_pass "Contenedores CrediNet activos"
    docker ps --format "table {{.Names}}\t{{.Status}}" | grep credinet
else
    check_warn "Contenedores CrediNet no están corriendo"
fi

# Base de datos accesible
if docker exec credinet-postgres pg_isready -U credinet_user > /dev/null 2>&1; then
    check_pass "Base de datos PostgreSQL accesible"
else
    check_fail "No se puede conectar a PostgreSQL"
fi

echo ""

# =============================================================================
# 2. VERIFICAR CÓDIGO
# =============================================================================
echo "═══════════════════════════════════════════════════════════════════"
echo "2. VERIFICANDO CÓDIGO Y GIT"
echo "═══════════════════════════════════════════════════════════════════"

# Git status
if git status --porcelain | grep -q .; then
    check_warn "Hay cambios sin commitear:"
    git status --short | head -10
else
    check_pass "Código limpio (sin cambios pendientes)"
fi

# Verificar .env no está en git
if git ls-files .env | grep -q ".env"; then
    check_fail ".env está siendo trackeado por Git (peligro de seguridad)"
else
    check_pass ".env no está en Git"
fi

# Verificar .gitignore tiene .env
if grep -q "^\.env$" .gitignore; then
    check_pass ".env está en .gitignore"
else
    check_warn ".env no está en .gitignore"
fi

echo ""

# =============================================================================
# 3. VERIFICAR DATOS
# =============================================================================
echo "═══════════════════════════════════════════════════════════════════"
echo "3. VERIFICANDO DATOS EN BASE DE DATOS"
echo "═══════════════════════════════════════════════════════════════════"

# Contar registros
USERS=$(docker exec credinet-postgres psql -U credinet_user -d credinet_db -t -c "SELECT COUNT(*) FROM users;" 2>/dev/null | tr -d ' ')
LOANS=$(docker exec credinet-postgres psql -U credinet_user -d credinet_db -t -c "SELECT COUNT(*) FROM loans;" 2>/dev/null | tr -d ' ')
PAYMENTS=$(docker exec credinet-postgres psql -U credinet_user -d credinet_db -t -c "SELECT COUNT(*) FROM payments;" 2>/dev/null | tr -d ' ')
PERIODS=$(docker exec credinet-postgres psql -U credinet_user -d credinet_db -t -c "SELECT COUNT(*) FROM cut_periods;" 2>/dev/null | tr -d ' ')

echo "  📊 Usuarios: $USERS"
echo "  📊 Préstamos: $LOANS"  
echo "  📊 Pagos: $PAYMENTS"
echo "  📊 Períodos: $PERIODS"

if [ "$LOANS" -gt 0 ]; then
    check_warn "Hay $LOANS préstamos de prueba que se eliminarán en producción"
fi

if [ "$PERIODS" -gt 0 ]; then
    check_pass "Períodos de corte generados: $PERIODS"
fi

echo ""

# =============================================================================
# 4. VERIFICAR ARCHIVOS CRÍTICOS
# =============================================================================
echo "═══════════════════════════════════════════════════════════════════"
echo "4. VERIFICANDO ARCHIVOS CRÍTICOS"
echo "═══════════════════════════════════════════════════════════════════"

FILES_REQUIRED=(
    "docker-compose.yml"
    "backend/Dockerfile"
    "backend/requirements.txt"
    "frontend-mvp/Dockerfile"
    "frontend-mvp/package.json"
    "db/v2.0/init.sql"
)

for file in "${FILES_REQUIRED[@]}"; do
    if [ -f "$file" ]; then
        check_pass "Existe: $file"
    else
        check_fail "Falta: $file"
    fi
done

echo ""

# =============================================================================
# 5. VERIFICAR CONFIGURACIÓN
# =============================================================================
echo "═══════════════════════════════════════════════════════════════════"
echo "5. VERIFICANDO CONFIGURACIÓN"
echo "═══════════════════════════════════════════════════════════════════"

# Verificar que .env existe
if [ -f ".env" ]; then
    check_pass "Archivo .env existe"
    
    # Verificar SECRET_KEY no es el default
    if grep -q "dev_secret_key_change_in_production" .env; then
        check_warn "SECRET_KEY tiene valor de desarrollo (cambiar en producción)"
    fi
    
    # Verificar POSTGRES_PASSWORD no es el default
    if grep -q "credinet_pass_change_this_in_production" .env; then
        check_warn "POSTGRES_PASSWORD tiene valor de desarrollo (cambiar en producción)"
    fi
else
    check_fail "Archivo .env no existe"
fi

echo ""

# =============================================================================
# RESUMEN
# =============================================================================
echo "═══════════════════════════════════════════════════════════════════"
echo "RESUMEN PRE-FLIGHT CHECK"
echo "═══════════════════════════════════════════════════════════════════"

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✓ TODO LISTO PARA MIGRACIÓN${NC}"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠ Listo con $WARNINGS advertencias (revisar antes de producción)${NC}"
    exit 0
else
    echo -e "${RED}✗ HAY $ERRORS ERRORES QUE DEBEN CORREGIRSE${NC}"
    exit 1
fi
