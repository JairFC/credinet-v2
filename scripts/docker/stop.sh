#!/bin/bash
# =============================================================================
# CrediNet V2 - Docker Stop Script
# =============================================================================
# Detiene todos los servicios Docker
# =============================================================================

set -e

echo "🛑 Deteniendo CrediNet V2 (Docker)"
echo "===================================="
echo ""

# Colores
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Verificar argumento para eliminar volúmenes
REMOVE_VOLUMES=false
if [ "$1" == "--volumes" ] || [ "$1" == "-v" ]; then
    REMOVE_VOLUMES=true
    echo -e "${YELLOW}⚠️  Se eliminarán los volúmenes (datos de la BD)${NC}"
    echo ""
fi

# Detener servicios
echo "⏸️  Deteniendo servicios..."
docker compose down

# Eliminar volúmenes si se especificó
if [ "$REMOVE_VOLUMES" = true ]; then
    echo ""
    echo -e "${RED}🗑️  Eliminando volúmenes...${NC}"
    docker volume rm credinet-postgres-data 2>/dev/null || true
    docker volume rm credinet-backend-uploads 2>/dev/null || true
    echo "✅ Volúmenes eliminados"
fi

echo ""
echo "✅ CrediNet V2 detenido"
echo ""
echo "💡 Para reiniciar:"
echo "   ./scripts/docker/start.sh"
echo ""
echo "💡 Para eliminar también los datos:"
echo "   ./scripts/docker/stop.sh --volumes"
echo ""
