#!/bin/bash
# =============================================================================
# CrediNet V2 - Script de Actualización desde GitHub
# =============================================================================
# Uso: ./update-from-github.sh [rama]
# 
# Este script:
# 1. Hace pull de los últimos cambios
# 2. Detecta si hay cambios en frontend o backend
# 3. Reconstruye/reinicia solo lo necesario
# =============================================================================

set -e

BRANCH="${1:-main}"
PROJECT_DIR="/home/jair/proyectos/credinet-v2"

cd "$PROJECT_DIR"

echo "=============================================="
echo "🔄 Actualizando CrediNet desde GitHub"
echo "=============================================="
echo "📍 Rama: $BRANCH"
echo ""

# Guardar estado actual de archivos para detectar cambios
BEFORE_FRONTEND=$(git log -1 --format="%H" -- frontend-mvp/)
BEFORE_BACKEND=$(git log -1 --format="%H" -- backend/)

# Fetch y pull
echo "📥 Descargando cambios..."
git fetch origin

# Verificar si hay cambios
LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse origin/$BRANCH)

if [ "$LOCAL" = "$REMOTE" ]; then
    echo "✅ Ya estás actualizado con origin/$BRANCH"
    exit 0
fi

# Mostrar commits que se van a aplicar
echo ""
echo "📋 Commits nuevos:"
git log --oneline HEAD..origin/$BRANCH
echo ""

# Hacer pull
echo "⬇️  Aplicando cambios..."
git pull origin $BRANCH

# Verificar qué cambió
AFTER_FRONTEND=$(git log -1 --format="%H" -- frontend-mvp/)
AFTER_BACKEND=$(git log -1 --format="%H" -- backend/)

FRONTEND_CHANGED=false
BACKEND_CHANGED=false

if [ "$BEFORE_FRONTEND" != "$AFTER_FRONTEND" ]; then
    FRONTEND_CHANGED=true
    echo "🎨 Detectados cambios en Frontend"
fi

if [ "$BEFORE_BACKEND" != "$AFTER_BACKEND" ]; then
    BACKEND_CHANGED=true
    echo "⚙️  Detectados cambios en Backend"
fi

# Aplicar cambios según lo que cambió
if [ "$BACKEND_CHANGED" = true ]; then
    echo ""
    echo "🔄 Reiniciando Backend..."
    docker compose restart backend
    sleep 5
    
    # Verificar health
    if curl -s http://localhost:8000/health | grep -q "healthy"; then
        echo "✅ Backend reiniciado correctamente"
    else
        echo "⚠️  Backend puede estar iniciando aún, verifica los logs"
    fi
fi

if [ "$FRONTEND_CHANGED" = true ]; then
    echo ""
    echo "🔄 Reconstruyendo Frontend..."
    
    # Verificar si hay nuevas dependencias
    if git diff "$BEFORE_FRONTEND".."$AFTER_FRONTEND" -- frontend-mvp/package.json | grep -q "dependencies"; then
        echo "📦 Detectadas nuevas dependencias, instalando..."
        docker compose exec frontend npm ci
    fi
    
    # Rebuild
    docker compose exec frontend npm run build
    echo "✅ Frontend reconstruido"
fi

echo ""
echo "=============================================="
echo "✅ Actualización completada"
echo "=============================================="
echo ""
echo "📝 Cambios aplicados:"
git log --oneline "$LOCAL".."$REMOTE"
echo ""
