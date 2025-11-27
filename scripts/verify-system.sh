#!/bin/bash
# Script de verificación rápida del sistema CrediNet V2
# Ejecuta: bash scripts/verify-system.sh

echo "🔍 Verificando Sistema CrediNet V2"
echo "=================================="
echo ""

# Colores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Función para verificar servicio
check_service() {
    local name=$1
    local url=$2
    local expected=$3
    
    echo -n "Verificando $name... "
    response=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null)
    
    if [ "$response" = "$expected" ]; then
        echo -e "${GREEN}✓ OK${NC} (HTTP $response)"
        return 0
    else
        echo -e "${RED}✗ FAIL${NC} (HTTP $response, esperado $expected)"
        return 1
    fi
}

# Verificar Docker
echo "📦 Verificando contenedores Docker..."
docker compose ps --format "table {{.Name}}\t{{.Status}}" 2>/dev/null || {
    echo -e "${RED}✗ Error al ejecutar docker compose${NC}"
    exit 1
}
echo ""

# Verificar servicios
echo "🌐 Verificando servicios..."
check_service "Backend Health" "http://localhost:8000/health" "200"
check_service "Backend Docs" "http://localhost:8000/docs" "200"
check_service "Frontend" "http://localhost:5173" "200"
echo ""

# Verificar endpoints de Fase 6
echo "🔌 Verificando endpoints de Fase 6..."
echo "Nota: Requiere autenticación, solo verifica que existan en Swagger"

# Obtener lista de endpoints del OpenAPI
openapi_check=$(curl -s http://localhost:8000/openapi.json 2>/dev/null)

if echo "$openapi_check" | grep -q "statements/{id}/payments"; then
    echo -e "${GREEN}✓${NC} Endpoint: /api/v1/statements/{id}/payments"
else
    echo -e "${RED}✗${NC} Endpoint: /api/v1/statements/{id}/payments NO encontrado"
fi

if echo "$openapi_check" | grep -q "associates/{id}/debt-summary"; then
    echo -e "${GREEN}✓${NC} Endpoint: /api/v1/associates/{id}/debt-summary"
else
    echo -e "${RED}✗${NC} Endpoint: /api/v1/associates/{id}/debt-summary NO encontrado"
fi

if echo "$openapi_check" | grep -q "associates/{id}/debt-payments"; then
    echo -e "${GREEN}✓${NC} Endpoint: /api/v1/associates/{id}/debt-payments"
else
    echo -e "${RED}✗${NC} Endpoint: /api/v1/associates/{id}/debt-payments NO encontrado"
fi

if echo "$openapi_check" | grep -q "associates/{id}/all-payments"; then
    echo -e "${GREEN}✓${NC} Endpoint: /api/v1/associates/{id}/all-payments"
else
    echo -e "${RED}✗${NC} Endpoint: /api/v1/associates/{id}/all-payments NO encontrado"
fi

echo ""

# Verificar axios en frontend
echo "📚 Verificando dependencias frontend..."
docker compose exec -T frontend npm list axios 2>&1 | grep -q "axios@" && {
    echo -e "${GREEN}✓${NC} axios instalado en frontend"
} || {
    echo -e "${RED}✗${NC} axios NO encontrado en frontend"
}

echo ""

# Verificar base de datos
echo "🗄️  Verificando base de datos..."
db_check=$(docker compose exec -T postgres psql -U credicoop -d credinet_v2 -c "SELECT COUNT(*) FROM pg_tables WHERE schemaname='public';" 2>/dev/null | grep -E '^\s*[0-9]+\s*$' | tr -d ' ')

if [ -n "$db_check" ] && [ "$db_check" -gt 0 ]; then
    echo -e "${GREEN}✓${NC} Base de datos accesible ($db_check tablas)"
else
    echo -e "${RED}✗${NC} Error al acceder a la base de datos"
fi

echo ""
echo "=================================="
echo "✅ Verificación completada"
echo ""
echo "URLs de acceso:"
echo "  Backend (Swagger): http://192.168.98.98:8000/docs"
echo "  Frontend:          http://192.168.98.98:5173"
echo ""
