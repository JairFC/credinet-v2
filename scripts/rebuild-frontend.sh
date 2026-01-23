#!/bin/bash
# =============================================================================
# CrediNet V2 - Script de Rebuild Frontend para Producción
# =============================================================================
# Uso: ./rebuild-frontend.sh
# 
# Este script:
# 1. Hace build del frontend dentro del contenedor
# 2. No requiere reconstruir la imagen Docker
# 3. Los cambios se reflejan inmediatamente
# =============================================================================

set -e

echo "🔄 Rebuilding CrediNet Frontend..."

# Verificar que el contenedor está corriendo
if ! docker compose ps frontend | grep -q "Up"; then
    echo "❌ El contenedor frontend no está corriendo"
    echo "   Ejecuta: docker compose up -d frontend"
    exit 1
fi

# Ejecutar build dentro del contenedor
echo "📦 Ejecutando npm run build..."
docker compose exec frontend npm run build

echo "✅ Build completado!"
echo ""
echo "📝 El servidor 'serve' detectará automáticamente los nuevos archivos."
echo "   Si no ves los cambios, refresca con Ctrl+Shift+R"
echo ""
