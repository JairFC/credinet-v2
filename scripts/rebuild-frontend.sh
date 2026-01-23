#!/bin/bash
# =============================================================================
# CrediNet V2 - Script de Rebuild Frontend para Producción
# =============================================================================
# Uso: ./rebuild-frontend.sh
# 
# Este script:
# 1. Hace build del frontend dentro del contenedor
# 2. Pasa las variables VITE_* del .env correctamente
# 3. No requiere reconstruir la imagen Docker
# 4. Los cambios se reflejan inmediatamente
# =============================================================================

set -e

PROJECT_DIR="/home/jair/proyectos/credinet-v2"
cd "$PROJECT_DIR"

echo "🔄 Rebuilding CrediNet Frontend..."
echo ""

# Verificar que el contenedor está corriendo
if ! docker compose ps frontend | grep -q "Up"; then
    echo "❌ El contenedor frontend no está corriendo"
    echo "   Ejecuta: docker compose up -d frontend"
    exit 1
fi

# Leer variables del .env
if [ -f .env ]; then
    export $(grep -v '^#' .env | grep VITE_ | xargs)
fi

# Valores por defecto si no están en .env
VITE_API_URL="${VITE_API_URL:-http://10.5.26.141:8000}"
VITE_APP_NAME="${VITE_APP_NAME:-CrediCuenta}"
VITE_APP_VERSION="${VITE_APP_VERSION:-2.0.0}"

echo "📝 Variables de entorno:"
echo "   VITE_API_URL: $VITE_API_URL"
echo "   VITE_APP_NAME: $VITE_APP_NAME"
echo "   VITE_APP_VERSION: $VITE_APP_VERSION"
echo ""

# Ejecutar build dentro del contenedor con variables explícitas
echo "📦 Ejecutando npm run build..."
docker compose exec \
    -e VITE_API_URL="$VITE_API_URL" \
    -e VITE_APP_NAME="$VITE_APP_NAME" \
    -e VITE_APP_VERSION="$VITE_APP_VERSION" \
    frontend npm run build

echo ""
echo "✅ Build completado!"
echo ""
echo "📝 El servidor 'serve' detectará automáticamente los nuevos archivos."
echo "   Si no ves los cambios, refresca con Ctrl+Shift+R"
echo ""
