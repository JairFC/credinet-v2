#!/bin/bash
# =============================================================================
# CrediNet v2.0 - Script de Pruebas Post-Migración
# =============================================================================
# Ejecutar DESPUÉS de levantar los contenedores en producción
# Valida que todos los servicios estén funcionando correctamente
# =============================================================================

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuración - MODIFICAR según el servidor
PRODUCTION_IP="${PRODUCTION_IP:-10.5.26.141}"
API_PORT="${API_PORT:-8000}"
FRONTEND_PORT="${FRONTEND_PORT:-5173}"

API_URL="http://${PRODUCTION_IP}:${API_PORT}"
FRONTEND_URL="http://${PRODUCTION_IP}:${FRONTEND_PORT}"

# Credenciales de prueba (admin por defecto)
ADMIN_USER="${ADMIN_USER:-jair}"
ADMIN_PASS="${ADMIN_PASS:-root}"

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║         CrediNet v2.0 - Post-Migration Tests                    ║${NC}"
echo -e "${BLUE}╠══════════════════════════════════════════════════════════════════╣${NC}"
echo -e "${BLUE}║  Production Server: ${PRODUCTION_IP}                              ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════╝${NC}"
echo ""

TESTS_PASSED=0
TESTS_FAILED=0

# Función para ejecutar un test
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    echo -n "  ⏳ Testing: ${test_name}..."
    
    if eval "$test_command" > /dev/null 2>&1; then
        echo -e " ${GREEN}✓ PASS${NC}"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e " ${RED}✗ FAIL${NC}"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Función para test con respuesta esperada
run_api_test() {
    local test_name="$1"
    local endpoint="$2"
    local expected="$3"
    
    echo -n "  ⏳ Testing: ${test_name}..."
    
    response=$(curl -s -o /dev/null -w "%{http_code}" "${API_URL}${endpoint}" 2>/dev/null || echo "000")
    
    if [[ "$response" == "$expected" ]]; then
        echo -e " ${GREEN}✓ PASS${NC} (HTTP $response)"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e " ${RED}✗ FAIL${NC} (Expected: $expected, Got: $response)"
        ((TESTS_FAILED++))
        return 1
    fi
}

# =============================================================================
# 1. Verificar Docker Containers
# =============================================================================
echo -e "${YELLOW}1. Docker Containers Status${NC}"
echo -e "${YELLOW}─────────────────────────────${NC}"

run_test "PostgreSQL container running" "docker ps --format '{{.Names}}' | grep -q 'credinet-postgres'"
run_test "Backend container running" "docker ps --format '{{.Names}}' | grep -q 'credinet-backend'"
run_test "Frontend container running" "docker ps --format '{{.Names}}' | grep -q 'credinet-frontend'"

echo ""

# =============================================================================
# 2. Verificar Conectividad de Red
# =============================================================================
echo -e "${YELLOW}2. Network Connectivity${NC}"
echo -e "${YELLOW}─────────────────────────────${NC}"

run_test "API port reachable" "nc -z ${PRODUCTION_IP} ${API_PORT}"
run_test "Frontend port reachable" "nc -z ${PRODUCTION_IP} ${FRONTEND_PORT}"
run_test "PostgreSQL port (internal)" "docker exec credinet-backend nc -z credinet-postgres 5432"

echo ""

# =============================================================================
# 3. Verificar API Endpoints
# =============================================================================
echo -e "${YELLOW}3. API Endpoints Health${NC}"
echo -e "${YELLOW}─────────────────────────────${NC}"

run_api_test "API root endpoint" "/" "200"
run_api_test "Health check (docs)" "/docs" "200"
run_api_test "OpenAPI schema" "/openapi.json" "200"

# Test login endpoint exists (422 = expected without body)
echo -n "  ⏳ Testing: Login endpoint available..."
login_response=$(curl -s -o /dev/null -w "%{http_code}" -X POST "${API_URL}/api/auth/login" -H "Content-Type: application/json" -d '{}' 2>/dev/null || echo "000")
if [[ "$login_response" == "422" || "$login_response" == "401" ]]; then
    echo -e " ${GREEN}✓ PASS${NC} (Endpoint responds)"
    ((TESTS_PASSED++))
else
    echo -e " ${RED}✗ FAIL${NC} (Got: $login_response)"
    ((TESTS_FAILED++))
fi

echo ""

# =============================================================================
# 4. Verificar Autenticación
# =============================================================================
echo -e "${YELLOW}4. Authentication System${NC}"
echo -e "${YELLOW}─────────────────────────────${NC}"

# Intentar login con admin
echo -n "  ⏳ Testing: Admin login..."
login_result=$(curl -s -X POST "${API_URL}/api/auth/login" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "username=${ADMIN_USER}&password=${ADMIN_PASS}" 2>/dev/null)

if echo "$login_result" | grep -q "access_token"; then
    echo -e " ${GREEN}✓ PASS${NC}"
    ((TESTS_PASSED++))
    
    # Extraer token para pruebas posteriores
    ACCESS_TOKEN=$(echo "$login_result" | grep -o '"access_token":"[^"]*"' | sed 's/"access_token":"//;s/"$//')
    
    # Test protected endpoint
    echo -n "  ⏳ Testing: Protected endpoint with token..."
    me_response=$(curl -s -o /dev/null -w "%{http_code}" "${API_URL}/api/auth/me" \
        -H "Authorization: Bearer ${ACCESS_TOKEN}" 2>/dev/null)
    
    if [[ "$me_response" == "200" ]]; then
        echo -e " ${GREEN}✓ PASS${NC}"
        ((TESTS_PASSED++))
    else
        echo -e " ${RED}✗ FAIL${NC} (HTTP $me_response)"
        ((TESTS_FAILED++))
    fi
else
    echo -e " ${RED}✗ FAIL${NC} (Invalid credentials or API error)"
    ((TESTS_FAILED++))
    ACCESS_TOKEN=""
fi

echo ""

# =============================================================================
# 5. Verificar Base de Datos
# =============================================================================
echo -e "${YELLOW}5. Database Integrity${NC}"
echo -e "${YELLOW}─────────────────────────────${NC}"

# Verificar tablas existen
run_test "Database tables exist" "docker exec credinet-postgres psql -U credinet_user -d credinet_db -c '\dt' | grep -q 'users'"

# Verificar catálogos tienen datos
echo -n "  ⏳ Testing: Roles catalog populated..."
roles_count=$(docker exec credinet-postgres psql -U credinet_user -d credinet_db -t -c "SELECT COUNT(*) FROM roles" 2>/dev/null | tr -d ' ')
if [[ "$roles_count" -ge 5 ]]; then
    echo -e " ${GREEN}✓ PASS${NC} ($roles_count roles)"
    ((TESTS_PASSED++))
else
    echo -e " ${RED}✗ FAIL${NC} (Expected >= 5, Got: $roles_count)"
    ((TESTS_FAILED++))
fi

echo -n "  ⏳ Testing: Admin users exist..."
admin_count=$(docker exec credinet-postgres psql -U credinet_user -d credinet_db -t -c "SELECT COUNT(*) FROM users WHERE id IN (1,2)" 2>/dev/null | tr -d ' ')
if [[ "$admin_count" -eq 2 ]]; then
    echo -e " ${GREEN}✓ PASS${NC} (2 admin users)"
    ((TESTS_PASSED++))
else
    echo -e " ${YELLOW}⚠ WARN${NC} (Found: $admin_count)"
    ((TESTS_FAILED++))
fi

echo -n "  ⏳ Testing: No test loans in production..."
loans_count=$(docker exec credinet-postgres psql -U credinet_user -d credinet_db -t -c "SELECT COUNT(*) FROM loans" 2>/dev/null | tr -d ' ')
if [[ "$loans_count" -eq 0 ]]; then
    echo -e " ${GREEN}✓ PASS${NC} (Clean database)"
    ((TESTS_PASSED++))
else
    echo -e " ${YELLOW}⚠ WARN${NC} (Found $loans_count loans - may be intentional)"
fi

echo -n "  ⏳ Testing: No test payments in production..."
payments_count=$(docker exec credinet-postgres psql -U credinet_user -d credinet_db -t -c "SELECT COUNT(*) FROM payment_transactions" 2>/dev/null | tr -d ' ')
if [[ "$payments_count" -eq 0 ]]; then
    echo -e " ${GREEN}✓ PASS${NC} (Clean database)"
    ((TESTS_PASSED++))
else
    echo -e " ${YELLOW}⚠ WARN${NC} (Found $payments_count payments - may be intentional)"
fi

echo ""

# =============================================================================
# 6. Verificar Frontend
# =============================================================================
echo -e "${YELLOW}6. Frontend Application${NC}"
echo -e "${YELLOW}─────────────────────────────${NC}"

run_test "Frontend responds" "curl -s -o /dev/null -w '%{http_code}' ${FRONTEND_URL} | grep -q '200'"

# Verificar que el frontend puede conectar al API
echo -n "  ⏳ Testing: CORS configuration..."
cors_check=$(curl -s -I -X OPTIONS "${API_URL}/api/auth/login" \
    -H "Origin: http://${PRODUCTION_IP}:${FRONTEND_PORT}" \
    -H "Access-Control-Request-Method: POST" 2>/dev/null | grep -i "access-control-allow-origin" || echo "")

if [[ -n "$cors_check" ]]; then
    echo -e " ${GREEN}✓ PASS${NC}"
    ((TESTS_PASSED++))
else
    echo -e " ${YELLOW}⚠ WARN${NC} (CORS headers may not be configured)"
fi

echo ""

# =============================================================================
# 7. Verificar Scheduler
# =============================================================================
echo -e "${YELLOW}7. Scheduler Service${NC}"
echo -e "${YELLOW}─────────────────────────────${NC}"

echo -n "  ⏳ Testing: APScheduler initialized..."
scheduler_log=$(docker logs credinet-backend 2>&1 | grep -i "scheduler\|apscheduler\|job" | tail -5)
if echo "$scheduler_log" | grep -qi "added job\|scheduler started\|running"; then
    echo -e " ${GREEN}✓ PASS${NC}"
    ((TESTS_PASSED++))
else
    echo -e " ${YELLOW}⚠ WARN${NC} (Check logs manually)"
fi

echo ""

# =============================================================================
# RESUMEN FINAL
# =============================================================================
echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                        TEST RESULTS                              ║${NC}"
echo -e "${BLUE}╠══════════════════════════════════════════════════════════════════╣${NC}"

TOTAL_TESTS=$((TESTS_PASSED + TESTS_FAILED))

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${BLUE}║  ${GREEN}✓ ALL TESTS PASSED: ${TESTS_PASSED}/${TOTAL_TESTS}${BLUE}                                  ║${NC}"
    echo -e "${BLUE}║  ${GREEN}System is ready for production use!${BLUE}                          ║${NC}"
    EXIT_CODE=0
elif [[ $TESTS_FAILED -lt 3 ]]; then
    echo -e "${BLUE}║  ${YELLOW}⚠ PASSED: ${TESTS_PASSED}/${TOTAL_TESTS}, WARNINGS: ${TESTS_FAILED}${BLUE}                              ║${NC}"
    echo -e "${BLUE}║  ${YELLOW}Review warnings before production use${BLUE}                        ║${NC}"
    EXIT_CODE=1
else
    echo -e "${BLUE}║  ${RED}✗ FAILED: ${TESTS_FAILED}/${TOTAL_TESTS} tests${BLUE}                                      ║${NC}"
    echo -e "${BLUE}║  ${RED}System is NOT ready for production!${BLUE}                          ║${NC}"
    EXIT_CODE=2
fi

echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════╝${NC}"

echo ""
echo -e "${YELLOW}Log files for debugging:${NC}"
echo "  docker logs credinet-backend --tail 50"
echo "  docker logs credinet-frontend --tail 50"
echo "  docker logs credinet-postgres --tail 50"
echo ""

exit $EXIT_CODE
