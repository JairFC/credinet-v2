#!/bin/bash
# =============================================================================
# CrediNet V2 - Script de Actualización Simple
# =============================================================================
# USO: ./update.sh
#
# Este script hace todo lo necesario después de un git pull:
# 1. Detecta qué cambió (backend, frontend, o ambos)
# 2. Aplica los cambios automáticamente
# 3. NO toca la base de datos (eso es manual con migraciones)
# =============================================================================

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

PROJECT_DIR="/home/jair/proyectos/credinet-v2"
cd "$PROJECT_DIR"

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}       CrediNet V2 - Actualización de Producción           ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# 1. Verificar estado de git
echo -e "${YELLOW}📋 Estado actual:${NC}"
echo "   Rama: $(git branch --show-current)"
echo "   Último commit: $(git log -1 --format='%h - %s')"
echo ""

# 2. Guardar hash actual para comparar después
BEFORE_HASH=$(git rev-parse HEAD)
BEFORE_BACKEND=$(git log -1 --format="%H" -- backend/ 2>/dev/null || echo "none")
BEFORE_FRONTEND=$(git log -1 --format="%H" -- frontend-mvp/ 2>/dev/null || echo "none")

# 3. Hacer pull
echo -e "${YELLOW}📥 Descargando cambios de GitHub...${NC}"
git fetch origin
git pull origin main

AFTER_HASH=$(git rev-parse HEAD)

# 4. Verificar si hubo cambios
if [ "$BEFORE_HASH" = "$AFTER_HASH" ]; then
    echo ""
    echo -e "${GREEN}✅ Ya estás actualizado. No hay cambios nuevos.${NC}"
    echo ""
    exit 0
fi

# 5. Mostrar qué cambió
echo ""
echo -e "${YELLOW}📝 Cambios aplicados:${NC}"
git log --oneline "$BEFORE_HASH".."$AFTER_HASH"
echo ""

# 6. Detectar qué componentes cambiaron
AFTER_BACKEND=$(git log -1 --format="%H" -- backend/ 2>/dev/null || echo "none")
AFTER_FRONTEND=$(git log -1 --format="%H" -- frontend-mvp/ 2>/dev/null || echo "none")

BACKEND_CHANGED=false
FRONTEND_CHANGED=false

if [ "$BEFORE_BACKEND" != "$AFTER_BACKEND" ]; then
    BACKEND_CHANGED=true
fi

if [ "$BEFORE_FRONTEND" != "$AFTER_FRONTEND" ]; then
    FRONTEND_CHANGED=true
fi

# 7. Aplicar cambios según componente
if [ "$BACKEND_CHANGED" = true ]; then
    echo -e "${YELLOW}⚙️  Backend modificado - Reiniciando...${NC}"
    docker compose restart backend
    sleep 5
    
    # Verificar health
    if curl -s http://localhost:8000/health | grep -q "healthy"; then
        echo -e "${GREEN}   ✅ Backend reiniciado correctamente${NC}"
    else
        echo -e "${RED}   ⚠️  Backend puede estar iniciando, verifica logs${NC}"
    fi
    echo ""
fi

if [ "$FRONTEND_CHANGED" = true ]; then
    echo -e "${YELLOW}🎨 Frontend modificado - Reconstruyendo...${NC}"
    
    # Verificar si cambiaron dependencias
    if git diff "$BEFORE_HASH".."$AFTER_HASH" -- frontend-mvp/package.json | grep -qE '"dependencies"|"devDependencies"'; then
        echo -e "${YELLOW}   📦 Nuevas dependencias detectadas, instalando...${NC}"
        docker compose exec -T frontend npm ci
    fi
    
    # Rebuild
    docker compose exec -T frontend npm run build
    echo -e "${GREEN}   ✅ Frontend reconstruido${NC}"
    echo ""
fi

# 8. Resumen final
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ Actualización completada${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

if [ "$BACKEND_CHANGED" = true ] || [ "$FRONTEND_CHANGED" = true ]; then
    echo -e "${YELLOW}📝 Recuerda:${NC}"
    echo "   • Refresca el navegador con Ctrl+Shift+R (o ventana incógnito)"
    echo "   • Si hay errores, revisa: docker compose logs backend --tail 50"
    echo ""
fi

# 9. Health check final
echo -e "${YELLOW}🏥 Estado de los servicios:${NC}"
echo "   Backend:  $(curl -s http://localhost:8000/health 2>/dev/null | grep -q healthy && echo '✅ Healthy' || echo '❌ No responde')"
echo "   Frontend: $(curl -s http://localhost:5173/ 2>/dev/null | grep -q 'root' && echo '✅ Healthy' || echo '❌ No responde')"
echo "   Database: $(docker compose exec -T postgres pg_isready -U credinet_user -d credinet_db 2>/dev/null | grep -q 'accepting' && echo '✅ Healthy' || echo '❌ No responde')"
echo ""
