#!/bin/bash

echo "=== DIAGNÓSTICO CREDINET v2.0 ==="
echo "Containers detectados: credinet-backend, credinet-frontend, credinet-postgres"
echo "Puertos: Backend=8000, Frontend=5173, DB=5432"
echo ""

echo "1. LOGS DEL BACKEND (últimas 20 líneas):"
docker logs credinet-backend --tail 20 2>/dev/null || echo "ERROR: No se pudo obtener logs del backend"
echo ""

echo "2. LOGS DEL FRONTEND (últimas 10 líneas):"
docker logs credinet-frontend --tail 10 2>/dev/null || echo "ERROR: No se pudo obtener logs del frontend"
echo ""

echo "3. CONEXIÓN A BASE DE DATOS:"
echo "3.1 Tablas principales:"
docker exec credinet-postgres psql -U credinet_user -d credinet_db -c "
SELECT table_name, 
       COUNT(*) as row_count,
       pg_size_pretty(pg_total_relation_size('\"' || table_name || '\"')) as size
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('payments', 'loans', 'associates', 'clients', 'users', 'payment_statuses', 'cut_periods')
GROUP BY table_name
ORDER BY table_name;
" 2>/dev/null || echo "ERROR: No se pudo conectar a la base de datos"
echo ""

echo "3.2 Estructura de tabla 'payments':"
docker exec credinet-postgres psql -U credinet_user -d credinet_db -c "
SELECT column_name, data_type, is_nullable, 
       CASE WHEN column_default IS NOT NULL THEN 'Sí' ELSE 'No' END as tiene_default
FROM information_schema.columns
WHERE table_name = 'payments'
ORDER BY ordinal_position
LIMIT 15;
" 2>/dev/null || echo "ERROR: No se pudo obtener estructura de payments"
echo ""

echo "4. ESTADO DE LA API:"
echo "4.1 Health check:"
curl -s -o /dev/null -w "HTTP Status: %{http_code}\nTiempo respuesta: %{time_total}s\n" http://localhost:8000/health || echo "API no responde"
echo ""

echo "4.2 Endpoints disponibles (OpenAPI):"
curl -s http://localhost:8000/openapi.json 2>/dev/null | python3 -c "
import sys, json;
try:
    data = json.load(sys.stdin);
    paths = list(data.get('paths', {}).keys());
    print(f'Total endpoints: {len(paths)}');
    for path in paths[:10]:
        print(f'  {path}');
    if len(paths) > 10:
        print(f'  ... y {len(paths)-10} más');
except:
    print('No se pudo obtener o parsear OpenAPI');
" 2>/dev/null || echo "ERROR: No se pudo obtener endpoints o python3 no disponible"
echo ""

echo "5. ESTRUCTURA DEL PROYECTO:"
echo "5.1 Backend - Módulos existentes:"
find backend/app -type d -name "*" 2>/dev/null | grep -v __pycache__ | head -20 || echo "Directorio backend/app no encontrado"
echo ""

echo "5.2 Archivos de payments:"
find backend/app -type f -name "*.py" 2>/dev/null | grep -i payment | head -10 || echo "No se encontraron archivos de payments"
echo ""

echo "6. FRONTEND - Estructura básica:"
if [ -d "frontend/src" ]; then
    echo "Componentes relacionados con pagos/préstamos:"
    find frontend/src -name "*.jsx" -o -name "*.js" 2>/dev/null | grep -i "payment\|loan\|associate" | head -5 || echo "No se encontraron componentes específicos"
else
    echo "Directorio frontend/src no encontrado"
fi
echo ""

echo "7. VERIFICACIÓN DE DEPENDENCIAS PENDIENTES:"
echo "7.1 Buscando TODOs en código crítico:"
grep -r "TODO\|FIXME\|XXX" backend/app/modules/ --include="*.py" 2>/dev/null | head -5 || echo "No se encontraron TODOs o directorio no existe"
echo ""

echo "=== DIAGNÓSTICO COMPLETADO ==="