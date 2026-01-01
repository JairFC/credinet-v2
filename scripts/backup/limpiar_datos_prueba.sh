#!/bin/bash
# =============================================================================
# CREDINET v2.0 - LIMPIAR DATOS DE PRUEBA
# =============================================================================
# Elimina todos los datos de prueba para empezar con datos reales
# MANTIENE: estructura, funciones, triggers, catálogos
# ELIMINA: usuarios, préstamos, pagos, statements, auditoría
# =============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     CREDINET v2.0 - LIMPIAR DATOS DE PRUEBA                 ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${RED}⚠️  ADVERTENCIA: Esta operación eliminará TODOS los datos:${NC}"
echo -e "   - Usuarios (excepto admin)"
echo -e "   - Perfiles de asociados"
echo -e "   - Préstamos"
echo -e "   - Pagos"
echo -e "   - Statements"
echo -e "   - Deudas acumuladas"
echo -e "   - Historial de auditoría"
echo ""
echo -e "${YELLOW}Los catálogos y configuraciones se MANTIENEN.${NC}"
echo ""

read -p "¿Está SEGURO de continuar? Escriba 'LIMPIAR' para confirmar: " CONFIRM

if [ "$CONFIRM" != "LIMPIAR" ]; then
    echo "Operación cancelada."
    exit 0
fi

echo ""
echo -e "${GREEN}[1/4] 📸 Creando backup de seguridad...${NC}"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="/home/credicuenta/proyectos/credinet-v2/db/backups/pre_clean_${TIMESTAMP}.sql"

docker exec credinet-postgres pg_dump -U credinet_user -d credinet_db > "$BACKUP_FILE"
gzip "$BACKUP_FILE"

echo -e "   ✅ Backup guardado en ${BACKUP_FILE}.gz"

echo -e "${GREEN}[2/4] 🧹 Limpiando datos...${NC}"

docker exec credinet-postgres psql -U credinet_user -d credinet_db << 'EOF'
-- Deshabilitar triggers temporalmente para velocidad
SET session_replication_role = replica;

-- ============================================================
-- ELIMINAR DATOS EN ORDEN (por dependencias de FK)
-- ============================================================

-- Auditoría
TRUNCATE TABLE audit_log CASCADE;
RAISE NOTICE '✓ audit_log limpiado';

-- Sistema de deudas
TRUNCATE TABLE associate_debt_payments CASCADE;
TRUNCATE TABLE associate_accumulated_balances CASCADE;
RAISE NOTICE '✓ Sistema de deudas limpiado';

-- Sistema de statements
TRUNCATE TABLE associate_statement_payments CASCADE;
TRUNCATE TABLE associate_payment_statements CASCADE;
RAISE NOTICE '✓ Statements limpiados';

-- Sistema de pagos y préstamos
TRUNCATE TABLE payment_status_history CASCADE;
TRUNCATE TABLE payments CASCADE;
TRUNCATE TABLE loans CASCADE;
RAISE NOTICE '✓ Préstamos y pagos limpiados';

-- Garantías y documentos
TRUNCATE TABLE guarantors CASCADE;
TRUNCATE TABLE client_documents CASCADE;
TRUNCATE TABLE contracts CASCADE;
RAISE NOTICE '✓ Garantías y documentos limpiados';

-- Perfiles de asociados
TRUNCATE TABLE associate_profiles CASCADE;
RAISE NOTICE '✓ Perfiles de asociados limpiados';

-- Usuarios (mantener admin)
DELETE FROM users WHERE username != 'admin' AND user_type_id != 1;
RAISE NOTICE '✓ Usuarios limpiados (admin preservado)';

-- Limpiar períodos de corte (pero mantener estructura)
-- Opcionalmente regenerar períodos limpios
TRUNCATE TABLE cut_periods CASCADE;
RAISE NOTICE '✓ Períodos de corte limpiados';

-- Resetear secuencias
SELECT setval(pg_get_serial_sequence('users', 'id'), 1, false);
SELECT setval(pg_get_serial_sequence('associate_profiles', 'id'), 1, false);
SELECT setval(pg_get_serial_sequence('loans', 'id'), 1, false);
SELECT setval(pg_get_serial_sequence('payments', 'id'), 1, false);
SELECT setval(pg_get_serial_sequence('cut_periods', 'id'), 1, false);
SELECT setval(pg_get_serial_sequence('associate_payment_statements', 'id'), 1, false);
RAISE NOTICE '✓ Secuencias reseteadas';

-- Rehabilitar triggers
SET session_replication_role = DEFAULT;

-- Verificar
SELECT 'users' as tabla, COUNT(*) as registros FROM users
UNION ALL SELECT 'associate_profiles', COUNT(*) FROM associate_profiles
UNION ALL SELECT 'loans', COUNT(*) FROM loans
UNION ALL SELECT 'payments', COUNT(*) FROM payments;
EOF

echo -e "${GREEN}[3/4] 🔄 Regenerando períodos de corte...${NC}"

docker exec credinet-postgres psql -U credinet_user -d credinet_db << 'EOF'
-- Generar períodos de corte para el año actual y siguiente
DO $$
DECLARE
    v_year INTEGER;
    v_month INTEGER;
    v_period_num INTEGER := 1;
    v_start_date DATE;
    v_end_date DATE;
    v_cut_code VARCHAR(20);
BEGIN
    -- Generar para año actual y siguiente
    FOR v_year IN EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER .. (EXTRACT(YEAR FROM CURRENT_DATE) + 1)::INTEGER LOOP
        FOR v_month IN 1..12 LOOP
            -- Primera quincena (1-7 -> corte 8)
            v_start_date := make_date(v_year, v_month, 1);
            v_end_date := make_date(v_year, v_month, 7);
            v_cut_code := TO_CHAR(v_end_date + 1, 'MonDD-YYYY');
            
            INSERT INTO cut_periods (cut_number, period_start_date, period_end_date, cut_date, cut_code, status_id)
            VALUES (v_period_num, v_start_date, v_end_date, v_end_date + 1, v_cut_code, 
                    CASE WHEN v_end_date < CURRENT_DATE THEN 5 ELSE 1 END)
            ON CONFLICT DO NOTHING;
            v_period_num := v_period_num + 1;
            
            -- Segunda quincena (8-22 -> corte 23)
            v_start_date := make_date(v_year, v_month, 8);
            v_end_date := make_date(v_year, v_month, 22);
            v_cut_code := TO_CHAR(v_end_date + 1, 'MonDD-YYYY');
            
            INSERT INTO cut_periods (cut_number, period_start_date, period_end_date, cut_date, cut_code, status_id)
            VALUES (v_period_num, v_start_date, v_end_date, v_end_date + 1, v_cut_code,
                    CASE WHEN v_end_date < CURRENT_DATE THEN 5 ELSE 1 END)
            ON CONFLICT DO NOTHING;
            v_period_num := v_period_num + 1;
            
            -- Tercera quincena (23-fin de mes -> corte día 8 siguiente mes)
            v_start_date := make_date(v_year, v_month, 23);
            v_end_date := (make_date(v_year, v_month, 1) + INTERVAL '1 month - 1 day')::DATE;
            
            IF v_month = 12 THEN
                v_cut_code := TO_CHAR(make_date(v_year + 1, 1, 8), 'MonDD-YYYY');
            ELSE
                v_cut_code := TO_CHAR(make_date(v_year, v_month + 1, 8), 'MonDD-YYYY');
            END IF;
            
            INSERT INTO cut_periods (cut_number, period_start_date, period_end_date, cut_date, cut_code, status_id)
            VALUES (v_period_num, v_start_date, v_end_date, v_end_date + 1, v_cut_code,
                    CASE WHEN v_end_date < CURRENT_DATE THEN 5 ELSE 1 END)
            ON CONFLICT DO NOTHING;
            v_period_num := v_period_num + 1;
        END LOOP;
    END LOOP;
    
    RAISE NOTICE 'Períodos generados: %', v_period_num - 1;
END $$;

SELECT COUNT(*) as total_periodos FROM cut_periods;
EOF

echo -e "${GREEN}[4/4] ✅ Verificando estado final...${NC}"

docker exec credinet-postgres psql -U credinet_user -d credinet_db -c "
SELECT 
    (SELECT COUNT(*) FROM users) as usuarios,
    (SELECT COUNT(*) FROM associate_profiles) as asociados,
    (SELECT COUNT(*) FROM loans) as prestamos,
    (SELECT COUNT(*) FROM payments) as pagos,
    (SELECT COUNT(*) FROM cut_periods) as periodos;
"

echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║          ✅ LIMPIEZA COMPLETADA                             ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}El sistema está listo para datos de producción.${NC}"
echo -e "${YELLOW}Usuario admin preservado. Verificar credenciales.${NC}"
echo ""
