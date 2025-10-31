#!/bin/bash

# Script para aplicar optimizaciones de performance
# Ejecutar desde el directorio raíz del proyecto

echo "🚀 APLICANDO OPTIMIZACIONES DE PERFORMANCE"
echo "========================================"

# Aplicar optimizaciones de base de datos
echo "📊 Aplicando índices y vistas materializadas..."
docker compose exec postgres psql -U credinet -d credinet -f /docker-entrypoint-initdb.d/performance_optimizations.sql

if [ $? -eq 0 ]; then
    echo "✅ Optimizaciones de DB aplicadas exitosamente"
else
    echo "❌ Error aplicando optimizaciones de DB"
    exit 1
fi

# Verificar índices creados
echo "🔍 Verificando índices creados..."
docker compose exec postgres psql -U credinet -d credinet -c "
SELECT schemaname, tablename, indexname, indexdef 
FROM pg_indexes 
WHERE tablename = 'loans' 
AND indexname LIKE 'idx_%';"

# Verificar vistas materializadas
echo "📈 Verificando vistas materializadas..."
docker compose exec postgres psql -U credinet -d credinet -c "
SELECT matviewname, ispopulated 
FROM pg_matviews 
WHERE matviewname LIKE 'loan_stats_%';"

# Refrescar estadísticas
echo "📊 Refrescando estadísticas..."
docker compose exec postgres psql -U credinet -d credinet -c "ANALYZE loans;"

echo ""
echo "🎉 OPTIMIZACIONES APLICADAS EXITOSAMENTE"
echo "========================================"
echo ""
echo "📋 Resumen de mejoras:"
echo "  ✅ Índices optimizados para consultas frecuentes"
echo "  ✅ Vistas materializadas para reportes"
echo "  ✅ Funciones PL/pgSQL para queries complejas"
echo "  ✅ Triggers para mantener estadísticas actualizadas"
echo "  ✅ Repositorio actualizado con consultas optimizadas"
echo ""
echo "🔍 Monitoreo recomendado:"
echo "  - Ejecutar EXPLAIN ANALYZE en queries principales"
echo "  - Monitorear pg_stat_user_indexes para uso de índices"
echo "  - Refrescar vistas materializadas periódicamente"
echo ""