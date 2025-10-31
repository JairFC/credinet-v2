#!/bin/bash
# =============================================================================
# SCRIPT DE INICIALIZACIÓN COMPLETA Y RESISTENTE DE DB
# 
# Este script se ejecuta DESPUÉS de que Docker levanta la DB
# y es resistente a docker-compose down -v && docker-compose up --build
# =============================================================================

set -e

echo "🔄 Iniciando configuración completa de base de datos..."

# Esperar a que la base de datos esté completamente lista
echo "⏳ Esperando conexión a base de datos..."
until docker-compose exec -T db psql -U credinet_user -d credinet_db -c '\q' 2>/dev/null; do
    echo "   Esperando PostgreSQL..."
    sleep 2
done
echo "✅ Base de datos conectada"

# 1. Ejecutar esquema base (init_clean.sql)
echo "📋 Ejecutando esquema base..."
docker-compose exec -T db psql -U credinet_user -d credinet_db < db/init_clean.sql
echo "✅ Esquema base aplicado"

# 2. Ejecutar migración de campos de aprobación
echo "🔧 Aplicando migración de campos de aprobación..."
docker-compose exec -T db psql -U credinet_user -d credinet_db < db/01_add_approval_fields.sql
echo "✅ Campos de aprobación agregados"

# 3. Ejecutar períodos quincenales
echo "📅 Configurando períodos quincenales..."
docker-compose exec -T db psql -U credinet_user -d credinet_db < db/30_quincenal_periods.sql
echo "✅ Períodos quincenales configurados"

# 4. Ejecutar seeds básicos
echo "🌱 Insertando datos iniciales..."
docker-compose exec -T db psql -U credinet_user -d credinet_db < db/seeds_clean.sql
echo "✅ Datos iniciales insertados"

# 5. Verificación final
echo "🔍 Verificando integridad del sistema..."
docker-compose exec -T db psql -U credinet_user -d credinet_db -c "
SELECT 
    '📊 VERIFICACIÓN SISTEMA COMPLETO' as titulo;

SELECT 
    tablename as tabla,
    schemaname as esquema
FROM pg_tables 
WHERE schemaname = 'public' 
ORDER BY tablename;

SELECT 
    '✅ Usuarios disponibles: ' || COUNT(*) as usuarios
FROM users;

SELECT 
    '✅ Períodos configurados: ' || COUNT(*) as periodos
FROM cut_periods;

SELECT 
    '✅ Roles disponibles: ' || COUNT(*) as roles
FROM roles;

SELECT 
    'Sistema completamente inicializado y listo para uso' as resultado_final;
"

echo "🎉 ¡Sistema de base de datos completamente configurado!"
echo "📋 Para crear préstamos, use el formulario frontend o los endpoints de la API"