#!/bin/bash
# =============================================================================
# CrediNet V2 - Docker Startup Script
# =============================================================================
# Inicia todos los servicios: PostgreSQL, Backend (FastAPI), Frontend (Vite)
# =============================================================================

set -e

echo "🚀 Iniciando CrediNet V2 (Docker)"
echo "=================================="
echo ""

# Colores para output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Verificar que existe docker-compose.yml
if [ ! -f "docker-compose.yml" ]; then
    echo "❌ Error: docker-compose.yml no encontrado"
    echo "   Ejecuta este script desde la raíz del proyecto"
    exit 1
fi

# Verificar que existe .env
if [ ! -f ".env" ]; then
    echo "⚠️  Advertencia: Archivo .env no encontrado"
    echo "   Creando .env desde .env.example..."
    if [ -f ".env.example" ]; then
        cp .env.example .env
        echo "✅ Archivo .env creado"
    else
        echo "❌ Error: .env.example no encontrado"
        exit 1
    fi
fi

echo -e "${BLUE}📦 Construyendo imágenes Docker...${NC}"
docker compose build

echo ""
echo -e "${BLUE}🔧 Iniciando servicios...${NC}"
docker compose up -d

echo ""
echo -e "${YELLOW}⏳ Esperando a que los servicios estén listos...${NC}"
sleep 10

echo ""
echo -e "${GREEN}✅ Servicios iniciados!${NC}"
echo ""
echo "════════════════════════════════════════════════"
echo -e "${GREEN}🎉 CrediNet V2 está listo!${NC}"
echo "════════════════════════════════════════════════"
echo ""
echo "📊 Frontend (React + Vite):"
echo "   → http://localhost:5173"
echo "   → http://192.168.98.98:5173"
echo ""
echo "🔧 Backend (FastAPI):"
echo "   → http://localhost:8000"
echo "   → http://192.168.98.98:8000"
echo "   → Docs: http://localhost:8000/docs"
echo ""
echo "🗄️  PostgreSQL:"
echo "   → localhost:5432"
echo "   → Database: credinet_db"
echo "   → User: credinet_user"
echo ""
echo "════════════════════════════════════════════════"
echo ""
echo "📝 Comandos útiles:"
echo "   Ver logs:        docker compose logs -f"
echo "   Ver logs backend: docker compose logs -f backend"
echo "   Ver logs frontend: docker compose logs -f frontend"
echo "   Detener todo:    docker compose down"
echo "   Reiniciar:       docker compose restart"
echo ""
echo "🔐 Credenciales de prueba:"
echo "   Usuario: admin"
echo "   Password: Sparrow20"
echo ""
