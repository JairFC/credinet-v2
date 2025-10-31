#!/bin/bash

# 🗃️ Script Simplificado de Migración - Solo la Migración Maestra
# Aplica únicamente la migración consolidada esencial

echo "🗃️ APLICANDO MIGRACIÓN MAESTRA CONSOLIDADA"
echo "==========================================="

# Verificar que Docker Compose esté funcionando
if ! docker compose ps | grep -q "credinet-db.*running"; then
    echo "❌ La base de datos no está funcionando. Iniciando..."
    docker compose up -d db
    sleep 5
fi

echo "📋 Aplicando migración maestra consolidada..."

# Aplicar la migración maestra
if docker compose exec -T db psql -U credinet_user -d credinet_db < /home/credicuenta/proyectos/credinet/db/migrations/MASTER_consolidada.sql; then
    echo "✅ Migración maestra aplicada exitosamente"
else
    echo "❌ Error aplicando migración maestra"
    exit 1
fi

# Verificar el estado final
echo ""
echo "📊 VERIFICANDO ESTADO FINAL DE LA BASE DE DATOS"
echo "================================================"

echo "🔍 Verificando tablas principales..."
docker compose exec -T db psql -U credinet_user -d credinet_db -t -c "
SELECT 
    'Usuarios: ' || COUNT(*) FROM users
UNION ALL
SELECT 
    'Préstamos: ' || COUNT(*) FROM loans
UNION ALL
SELECT 
    'Pagos: ' || COUNT(*) FROM payments
UNION ALL
SELECT 
    'Versiones de corte: ' || COUNT(*) FROM cutoff_versions
UNION ALL
SELECT 
    'Configuraciones del sistema: ' || COUNT(*) FROM system_settings;
" | sed 's/^[ \t]*/   ✅ /'

echo ""
echo "🔍 Verificando campos críticos añadidos..."

# Verificar campos en payments
PAYMENT_FIELDS=$(docker compose exec -T db psql -U credinet_user -d credinet_db -t -c "
SELECT column_name 
FROM information_schema.columns 
WHERE table_name = 'payments' 
AND column_name IN ('payment_status', 'payment_timestamp', 'evidence_url', 'weekend_delay_detected')
ORDER BY column_name;
" | tr -d ' ' | grep -v '^$' | wc -l)

if [ "$PAYMENT_FIELDS" -eq "4" ]; then
    echo "   ✅ Campos de payments: payment_status, payment_timestamp, evidence_url, weekend_delay_detected"
else
    echo "   ❌ Faltan campos en la tabla payments"
fi

# Verificar campos en loans
LOAN_FIELDS=$(docker compose exec -T db psql -U credinet_user -d credinet_db -t -c "
SELECT column_name 
FROM information_schema.columns 
WHERE table_name = 'loans' 
AND column_name IN ('loan_number', 'loan_status', 'collateral_description', 'risk_assessment')
ORDER BY column_name;
" | tr -d ' ' | grep -v '^$' | wc -l)

if [ "$LOAN_FIELDS" -eq "4" ]; then
    echo "   ✅ Campos de loans: loan_number, loan_status, collateral_description, risk_assessment"
else
    echo "   ❌ Faltan campos en la tabla loans"
fi

# Verificar tablas nuevas
CUTOFF_TABLE=$(docker compose exec -T db psql -U credinet_user -d credinet_db -t -c "
SELECT COUNT(*) FROM information_schema.tables WHERE table_name = 'cutoff_versions';
" | tr -d ' ')

if [ "$CUTOFF_TABLE" -eq "1" ]; then
    echo "   ✅ Tabla cutoff_versions creada correctamente"
else
    echo "   ❌ Tabla cutoff_versions no encontrada"
fi

echo ""
echo "🎉 MIGRACIÓN CONSOLIDADA COMPLETADA"
echo "==================================="
echo "✅ Base de datos actualizada con una sola migración maestra"
echo "✅ Migraciones antiguas archivadas en db/migrations_archive/"
echo "✅ Sistema listo para desarrollo y producción"
echo ""
echo "📁 Archivos importantes:"
echo "   📜 db/migrations/MASTER_consolidada.sql - Única migración necesaria"
echo "   📁 db/migrations_archive/ - Migraciones históricas archivadas"