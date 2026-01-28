#!/bin/bash
#
# CrediNet Health Check Runner
# ============================
# 
# Ejecuta todos los health checks del sistema.
#
# USO:
#   ./check-health.sh           # Ejecutar todos los checks
#   ./check-health.sh -v        # Modo verbose
#   ./check-health.sh quick     # Solo checks rápidos (sin pytest)
#   ./check-health.sh infra     # Solo infraestructura
#   ./check-health.sh database  # Solo base de datos
#   ./check-health.sh backend   # Solo backend
#   ./check-health.sh business  # Solo lógica de negocio
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BACKEND_DIR="$PROJECT_ROOT/backend"

# Colores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Status indicators
OK="[  ${GREEN}OK${NC}  ]"
FAIL="[${RED}FAILED${NC}]"
SKIP="[ ${YELLOW}SKIP${NC} ]"

print_header() {
    echo -e "\n${BOLD}╔═══════════════════════════════════════════════════════════════╗"
    echo -e "║           CrediNet v2.0 - System Health Check                 ║"
    echo -e "║                    $(date '+%Y-%m-%d %H:%M:%S')                      ║"
    echo -e "╚═══════════════════════════════════════════════════════════════╝${NC}\n"
}

print_status() {
    local name="$1"
    local status="$2"
    
    # Pad name with dots
    local padded_name=$(printf "%-50s" "$name" | tr ' ' '.')
    
    case "$status" in
        "OK")   echo -e "  $padded_name $OK" ;;
        "FAIL") echo -e "  $padded_name $FAIL" ;;
        "SKIP") echo -e "  $padded_name $SKIP" ;;
        *)      echo -e "  $padded_name [$status]" ;;
    esac
}

print_section() {
    echo -e "\n${BLUE}${BOLD}▸ $1${NC}"
    echo -e "  $(printf '─%.0s' {1..58})"
}

check_container() {
    local container=$1
    if docker inspect -f '{{.State.Running}}' "$container" 2>/dev/null | grep -q "true"; then
        print_status "Container $container" "OK"
        return 0
    else
        print_status "Container $container" "FAIL"
        return 1
    fi
}

check_port() {
    local name=$1
    local port=$2
    if nc -z localhost "$port" 2>/dev/null; then
        print_status "$name (port $port)" "OK"
        return 0
    else
        print_status "$name (port $port)" "FAIL"
        return 1
    fi
}

run_quick_checks() {
    local passed=0
    local failed=0
    
    print_section "Quick System Checks"
    
    # Docker daemon
    if docker info >/dev/null 2>&1; then
        print_status "Docker daemon" "OK"
        ((passed++))
    else
        print_status "Docker daemon" "FAIL"
        ((failed++))
    fi
    
    # Containers
    for container in credinet-backend credinet-frontend credinet-postgres; do
        if check_container "$container"; then
            ((passed++))
        else
            ((failed++))
        fi
    done
    
    # PostgreSQL
    if docker exec credinet-postgres psql -U credinet_user -d credinet_db -c "SELECT 1" >/dev/null 2>&1; then
        print_status "PostgreSQL connection" "OK"
        ((passed++))
    else
        print_status "PostgreSQL connection" "FAIL"
        ((failed++))
    fi
    
    # Backend API
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/ | grep -q "200"; then
        print_status "Backend API" "OK"
        ((passed++))
    else
        print_status "Backend API" "FAIL"
        ((failed++))
    fi
    
    # Frontend
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:5173/ | grep -q "200"; then
        print_status "Frontend" "OK"
        ((passed++))
    else
        print_status "Frontend" "FAIL"
        ((failed++))
    fi
    
    echo ""
    echo -e "${BOLD}Quick Checks: ${GREEN}$passed passed${NC}, ${RED}$failed failed${NC}"
    
    return $failed
}

run_pytest_checks() {
    local category=$1
    local test_file=""
    
    case "$category" in
        "infra")    test_file="tests/health/test_infrastructure.py" ;;
        "database") test_file="tests/health/test_database.py" ;;
        "backend")  test_file="tests/health/test_backend.py" ;;
        "business") test_file="tests/health/test_business_logic.py" ;;
        "all"|"")   test_file="tests/health/" ;;
        *)          test_file="$category" ;;
    esac
    
    print_section "Running pytest: $test_file"
    
    cd "$BACKEND_DIR"
    
    # Check if running inside Docker container
    if [ -f "/.dockerenv" ]; then
        python -m pytest "$test_file" -v --tb=short 2>&1
    else
        # Run in Docker container for consistency
        docker exec -w /app credinet-backend python -m pytest "$test_file" -v --tb=short 2>&1
    fi
}

# Main
print_header

case "$1" in
    "quick")
        run_quick_checks
        ;;
    "infra"|"database"|"backend"|"business")
        run_quick_checks
        run_pytest_checks "$1"
        ;;
    "-v"|"--verbose")
        run_quick_checks
        run_pytest_checks "all"
        ;;
    ""|"all")
        run_quick_checks
        echo ""
        echo -e "${YELLOW}Tip: Run './check-health.sh quick' for fast checks only${NC}"
        echo -e "${YELLOW}     Run 'cd backend && pytest tests/health/ -v' for full tests${NC}"
        ;;
    "-h"|"--help")
        echo "Usage: $0 [option]"
        echo ""
        echo "Options:"
        echo "  quick     - Run quick checks only (no pytest)"
        echo "  infra     - Run infrastructure tests"
        echo "  database  - Run database tests"
        echo "  backend   - Run backend API tests"
        echo "  business  - Run business logic tests"
        echo "  all       - Run all tests (default)"
        echo "  -v        - Verbose mode"
        echo "  -h        - Show this help"
        ;;
    *)
        echo "Unknown option: $1"
        echo "Run '$0 --help' for usage"
        exit 1
        ;;
esac
