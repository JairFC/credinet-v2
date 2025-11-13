#!/bin/bash
# =============================================================================
# CrediNet V2 - Docker Logs Script
# =============================================================================
# Muestra logs de los servicios Docker
# =============================================================================

SERVICE=${1:-all}

echo "📋 Logs de CrediNet V2"
echo "======================="
echo ""

case $SERVICE in
    backend|api)
        echo "🔧 Logs del Backend (FastAPI):"
        docker compose logs -f backend
        ;;
    frontend|web)
        echo "📊 Logs del Frontend (Vite):"
        docker compose logs -f frontend
        ;;
    db|database|postgres)
        echo "🗄️  Logs de PostgreSQL:"
        docker compose logs -f postgres
        ;;
    all|*)
        echo "📋 Logs de todos los servicios:"
        docker compose logs -f
        ;;
esac
