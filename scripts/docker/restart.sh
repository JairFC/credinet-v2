#!/bin/bash
# =============================================================================
# CrediNet V2 - Docker Restart Script
# =============================================================================
# Reinicia servicios Docker específicos o todos
# =============================================================================

SERVICE=${1:-all}

echo "🔄 Reiniciando servicios de CrediNet V2"
echo "========================================"
echo ""

case $SERVICE in
    backend|api)
        echo "🔧 Reiniciando Backend..."
        docker compose restart backend
        echo "✅ Backend reiniciado"
        ;;
    frontend|web)
        echo "📊 Reiniciando Frontend..."
        docker compose restart frontend
        echo "✅ Frontend reiniciado"
        ;;
    db|database|postgres)
        echo "🗄️  Reiniciando PostgreSQL..."
        docker compose restart postgres
        echo "✅ PostgreSQL reiniciado"
        ;;
    all|*)
        echo "🔄 Reiniciando todos los servicios..."
        docker compose restart
        echo "✅ Todos los servicios reiniciados"
        ;;
esac

echo ""
echo "💡 Ver logs: ./scripts/docker/logs.sh $SERVICE"
echo ""
