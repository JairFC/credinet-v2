#!/bin/bash
# Script para levantar CrediNet Backend v2.0 con volúmenes persistentes

echo "🚀 Iniciando CrediNet Backend v2.0..."
echo ""

# Crear volúmenes persistentes si no existen
echo "📦 Verificando volúmenes persistentes..."

if ! docker volume inspect credinet-postgres-data &>/dev/null; then
    echo "   Creando volumen: credinet-postgres-data"
    docker volume create credinet-postgres-data
else
    echo "   ✓ credinet-postgres-data ya existe"
fi

if ! docker volume inspect credinet-backend-uploads &>/dev/null; then
    echo "   Creando volumen: credinet-backend-uploads"
    docker volume create credinet-backend-uploads
else
    echo "   ✓ credinet-backend-uploads ya existe"
fi

if ! docker volume inspect credinet-backend-logs &>/dev/null; then
    echo "   Creando volumen: credinet-backend-logs"
    docker volume create credinet-backend-logs
else
    echo "   ✓ credinet-backend-logs ya existe"
fi

echo ""
echo "🔨 Construyendo y levantando servicios..."
echo ""

# Levantar solo postgres y backend con rebuild
docker compose up --build -d postgres backend

echo ""
echo "⏳ Esperando a que PostgreSQL esté listo..."
sleep 5

# Verificar que postgres esté healthy
until docker exec credinet-postgres pg_isready -U credinet_user -d credinet_db &>/dev/null; do
    echo "   Esperando PostgreSQL..."
    sleep 2
done

echo "✅ PostgreSQL listo!"
echo ""
echo "⏳ Esperando a que Backend esté listo..."
sleep 3

# Verificar que backend esté healthy
until curl -sf http://localhost:8000/health &>/dev/null; do
    echo "   Esperando Backend..."
    sleep 2
done

echo "✅ Backend listo!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎉 CrediNet Backend v2.0 está corriendo!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📍 Endpoints disponibles:"
echo "   • Health:  http://localhost:8000/health"
echo "   • API:     http://localhost:8000/api/v1"
echo "   • Docs:    http://localhost:8000/docs"
echo ""
echo "🔐 Para crear usuario admin, ejecuta:"
echo "   ./scripts/create_admin_user.sh"
echo ""
echo "📊 Ver logs en tiempo real:"
echo "   docker compose logs -f backend"
echo ""
echo "🛑 Para detener (SIN borrar datos):"
echo "   docker compose down"
echo ""
echo "💾 Volúmenes persistentes creados:"
echo "   • credinet-postgres-data (DB)"
echo "   • credinet-backend-uploads (Archivos)"
echo "   • credinet-backend-logs (Logs)"
echo ""
echo "⚠️  Nota: Incluso con 'docker compose down -v', los datos"
echo "   se mantienen porque los volúmenes son externos."
echo ""
