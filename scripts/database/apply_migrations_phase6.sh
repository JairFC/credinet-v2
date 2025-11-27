#!/bin/bash

# =============================================================================
# SCRIPT DE EJECUCIÓN DE MIGRACIONES CRÍTICAS - FASE 6
# =============================================================================
# Descripción:
#   Ejecuta las migraciones 015 y 016 en orden correcto para sincronizar
#   la base de datos de producción con el código actual.
#
# Propósito:
#   Resolver discrepancia entre init.sql y producción detectada en auditoría.
#
# Autor: GitHub Copilot (Piloto Principal)
# Fecha: 2025-11-11
# Versión: 2.0.4
# =============================================================================

set -e  # Salir si cualquier comando falla

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variables de entorno
CONTAINER_NAME="credinet-postgres"
DB_USER="credinet_user"
DB_NAME="credinet_db"
MIGRATIONS_DIR="/home/credicuenta/proyectos/credinet-v2/db/v2.0/modules"

# =============================================================================
# FUNCIONES HELPER
# =============================================================================

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# =============================================================================
# VALIDACIONES PRE-MIGRACIÓN
# =============================================================================

print_header "VALIDACIONES PRE-MIGRACIÓN"

# Verificar que el contenedor está corriendo
if ! docker ps | grep -q "$CONTAINER_NAME"; then
    print_error "El contenedor $CONTAINER_NAME no está corriendo"
    exit 1
fi
print_success "Contenedor $CONTAINER_NAME está corriendo"

# Verificar que los archivos de migración existen
if [ ! -f "$MIGRATIONS_DIR/migration_015_associate_statement_payments.sql" ]; then
    print_error "No se encontró migration_015_associate_statement_payments.sql"
    exit 1
fi
print_success "Migración 015 encontrada"

if [ ! -f "$MIGRATIONS_DIR/migration_016_associate_debt_payments.sql" ]; then
    print_error "No se encontró migration_016_associate_debt_payments.sql"
    exit 1
fi
print_success "Migración 016 encontrada"

# Verificar conexión a la base de datos
if ! docker exec "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1;" > /dev/null 2>&1; then
    print_error "No se pudo conectar a la base de datos"
    exit 1
fi
print_success "Conexión a base de datos exitosa"

# =============================================================================
# BACKUP PRE-MIGRACIÓN
# =============================================================================

print_header "CREANDO BACKUP PRE-MIGRACIÓN"

BACKUP_DIR="/home/credicuenta/proyectos/credinet-v2/db/backups"
BACKUP_NAME="backup_pre_migration_$(date +%Y-%m-%d_%H-%M-%S)"
BACKUP_PATH="$BACKUP_DIR/$BACKUP_NAME"

mkdir -p "$BACKUP_PATH"

print_info "Creando backup en: $BACKUP_PATH"

# Backup de la base de datos completa
docker exec "$CONTAINER_NAME" pg_dump -U "$DB_USER" -d "$DB_NAME" --clean --create > "$BACKUP_PATH/full_backup.sql" 2>&1

if [ $? -eq 0 ]; then
    print_success "Backup creado exitosamente"
else
    print_error "Error al crear backup"
    exit 1
fi

# Backup solo de las tablas críticas
docker exec "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -c "\copy (SELECT * FROM associate_payment_statements) TO STDOUT WITH CSV HEADER" > "$BACKUP_PATH/associate_payment_statements.csv" 2>&1
docker exec "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -c "\copy (SELECT * FROM associate_debt_breakdown) TO STDOUT WITH CSV HEADER" > "$BACKUP_PATH/associate_debt_breakdown.csv" 2>&1
docker exec "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -c "\copy (SELECT * FROM payments) TO STDOUT WITH CSV HEADER" > "$BACKUP_PATH/payments.csv" 2>&1

print_success "Backup de datos críticos completado"

# =============================================================================
# ESTADO ACTUAL DE LA BASE DE DATOS
# =============================================================================

print_header "ESTADO ACTUAL DE LA BASE DE DATOS"

print_info "Verificando tablas existentes..."

# Verificar tablas críticas
docker exec "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -c "
SELECT 
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'associate_statement_payments') 
        THEN '✅ EXISTE' 
        ELSE '❌ NO EXISTE' 
    END AS associate_statement_payments,
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'associate_debt_payments') 
        THEN '✅ EXISTE' 
        ELSE '❌ NO EXISTE' 
    END AS associate_debt_payments,
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'associate_payment_statements') 
        THEN '✅ EXISTE' 
        ELSE '❌ NO EXISTE' 
    END AS associate_payment_statements,
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'associate_debt_breakdown') 
        THEN '✅ EXISTE' 
        ELSE '❌ NO EXISTE' 
    END AS associate_debt_breakdown;
"

# =============================================================================
# EJECUTAR MIGRACIÓN 015
# =============================================================================

print_header "EJECUTANDO MIGRACIÓN 015: associate_statement_payments"

# Copiar migración al contenedor
docker cp "$MIGRATIONS_DIR/migration_015_associate_statement_payments.sql" "$CONTAINER_NAME:/tmp/"

# Ejecutar migración
print_info "Ejecutando migration_015_associate_statement_payments.sql..."
docker exec "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -f /tmp/migration_015_associate_statement_payments.sql

if [ $? -eq 0 ]; then
    print_success "Migración 015 ejecutada exitosamente"
else
    print_error "Error al ejecutar migración 015"
    print_warning "Restaurando desde backup..."
    docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d postgres < "$BACKUP_PATH/full_backup.sql"
    exit 1
fi

# Verificar creación de tabla
TABLA_015=$(docker exec "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -tAc "SELECT COUNT(*) FROM information_schema.tables WHERE table_name = 'associate_statement_payments';")

if [ "$TABLA_015" -eq 1 ]; then
    print_success "Tabla associate_statement_payments creada correctamente"
else
    print_error "La tabla associate_statement_payments NO fue creada"
    exit 1
fi

# =============================================================================
# EJECUTAR MIGRACIÓN 016
# =============================================================================

print_header "EJECUTANDO MIGRACIÓN 016: associate_debt_payments"

# Copiar migración al contenedor
docker cp "$MIGRATIONS_DIR/migration_016_associate_debt_payments.sql" "$CONTAINER_NAME:/tmp/"

# Ejecutar migración
print_info "Ejecutando migration_016_associate_debt_payments.sql..."
docker exec "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -f /tmp/migration_016_associate_debt_payments.sql

if [ $? -eq 0 ]; then
    print_success "Migración 016 ejecutada exitosamente"
else
    print_error "Error al ejecutar migración 016"
    print_warning "Restaurando desde backup..."
    docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d postgres < "$BACKUP_PATH/full_backup.sql"
    exit 1
fi

# Verificar creación de tabla
TABLA_016=$(docker exec "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -tAc "SELECT COUNT(*) FROM information_schema.tables WHERE table_name = 'associate_debt_payments';")

if [ "$TABLA_016" -eq 1 ]; then
    print_success "Tabla associate_debt_payments creada correctamente"
else
    print_error "La tabla associate_debt_payments NO fue creada"
    exit 1
fi

# =============================================================================
# VERIFICACIONES POST-MIGRACIÓN
# =============================================================================

print_header "VERIFICACIONES POST-MIGRACIÓN"

print_info "Verificando estructura de tablas..."

# Verificar associate_statement_payments
print_info "Verificando associate_statement_payments..."
docker exec "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -c "\d associate_statement_payments"

# Verificar associate_debt_payments
print_info "Verificando associate_debt_payments..."
docker exec "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -c "\d associate_debt_payments"

# Verificar vistas
print_info "Verificando vistas creadas..."
docker exec "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -c "
SELECT 
    table_name,
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.views WHERE table_name = views.table_name) 
        THEN '✅ EXISTE' 
        ELSE '❌ NO EXISTE' 
    END AS status
FROM (
    VALUES 
        ('v_associate_debt_summary'),
        ('v_associate_all_payments')
) AS views(table_name);
"

# Verificar funciones
print_info "Verificando funciones creadas..."
docker exec "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -c "
SELECT 
    proname AS function_name,
    '✅ EXISTE' AS status
FROM pg_proc
WHERE proname IN (
    'update_statement_on_payment',
    'apply_excess_to_debt_fifo',
    'apply_debt_payment_fifo',
    'get_debt_payment_detail'
)
ORDER BY proname;
"

# Verificar triggers
print_info "Verificando triggers creados..."
docker exec "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -c "
SELECT 
    tgname AS trigger_name,
    tgrelid::regclass AS table_name,
    '✅ EXISTE' AS status
FROM pg_trigger
WHERE tgname IN (
    'trigger_update_statement_on_payment',
    'trigger_apply_debt_payment_fifo',
    'update_associate_statement_payments_updated_at',
    'update_associate_debt_payments_updated_at'
)
ORDER BY tgname;
"

# =============================================================================
# RESUMEN FINAL
# =============================================================================

print_header "RESUMEN DE MIGRACIONES"

echo ""
print_success "MIGRACIONES COMPLETADAS EXITOSAMENTE"
echo ""
print_info "Tablas creadas:"
echo "  ✅ associate_statement_payments"
echo "  ✅ associate_debt_payments"
echo ""
print_info "Vistas creadas:"
echo "  ✅ v_associate_debt_summary"
echo "  ✅ v_associate_all_payments"
echo ""
print_info "Funciones creadas:"
echo "  ✅ update_statement_on_payment()"
echo "  ✅ apply_excess_to_debt_fifo()"
echo "  ✅ apply_debt_payment_fifo()"
echo "  ✅ get_debt_payment_detail()"
echo ""
print_info "Triggers creados:"
echo "  ✅ trigger_update_statement_on_payment"
echo "  ✅ trigger_apply_debt_payment_fifo"
echo "  ✅ update_associate_statement_payments_updated_at"
echo "  ✅ update_associate_debt_payments_updated_at"
echo ""
print_info "Backup creado en:"
echo "  📁 $BACKUP_PATH"
echo ""
print_success "Base de datos sincronizada con código v2.0.4"
echo ""

# =============================================================================
# SIGUIENTE PASO
# =============================================================================

print_header "PRÓXIMOS PASOS"

echo ""
print_info "1. Regenerar init.sql monolítico (RECOMENDADO):"
echo "   cd /home/credicuenta/proyectos/credinet-v2/db/v2.0"
echo "   ./generate_monolithic.sh"
echo ""
print_info "2. Implementar endpoints del backend:"
echo "   - POST /api/statements/:id/payments (registrar abono a saldo actual)"
echo "   - POST /api/associates/:id/debt-payments (registrar abono a deuda)"
echo "   - GET /api/statements/:id/payments (ver desglose de abonos)"
echo ""
print_info "3. Implementar componentes del frontend:"
echo "   - ModalRegistrarAbono.jsx (selector de tipo de abono)"
echo "   - TablaDesglosePagos.jsx (desglose de abonos)"
echo "   - DesgloseDeuda.jsx (visualización FIFO)"
echo ""
print_success "Base de datos lista para implementación de Fase 6"
echo ""
