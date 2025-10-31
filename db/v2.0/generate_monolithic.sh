#!/bin/bash
# =============================================================================
# GENERADOR DE ARCHIVO MONOLÍTICO - CREDINET v2.0
# =============================================================================
# Descripción:
#   Concatena todos los módulos SQL en un solo archivo monolítico.
#   Útil después de modificar módulos individuales.
#
# Uso:
#   ./generate_monolithic.sh
# =============================================================================

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
MODULES_DIR="$SCRIPT_DIR/modules"
OUTPUT_FILE="$SCRIPT_DIR/init.sql"
TEMP_FILE="$SCRIPT_DIR/.temp_monolithic.sql"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}GENERADOR ARCHIVO MONOLÍTICO - v2.0${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Header
echo -e "${YELLOW}[1/3] Generando header...${NC}"
cat > "$TEMP_FILE" << EOF
-- =============================================================================
-- CREDINET DB v2.0 - ARCHIVO MONOLÍTICO
-- =============================================================================
-- Descripción:
--   Base de datos completa consolidada en un solo archivo.
--   Generado automáticamente desde arquitectura modular.
--
-- Generación: $(date '+%Y-%m-%d %H:%M:%S')
-- Versión: 2.0.0
-- Módulos incluidos: 9 (01_catalog → 09_seeds)
-- Migraciones integradas: 6 (07-12)
--
-- ADVERTENCIA:
--   Este archivo es GENERADO AUTOMÁTICAMENTE.
--   NO editar directamente - modificar módulos en /modules/ y regenerar.
-- =============================================================================

EOF
echo -e "${GREEN}✓ Header generado${NC}"

# Concatenar módulos
echo -e "${YELLOW}[2/3] Concatenando módulos...${NC}"
for i in {01..09}; do
    module="$MODULES_DIR/${i}_*.sql"
    if [ -f $module ]; then
        module_name=$(basename $module)
        echo "  + $module_name"
        cat $module >> "$TEMP_FILE"
        echo "" >> "$TEMP_FILE"
    fi
done
echo -e "${GREEN}✓ Módulos concatenados${NC}"

# Mover archivo
echo -e "${YELLOW}[3/3] Finalizando...${NC}"
mv "$TEMP_FILE" "$OUTPUT_FILE"
LINES=$(wc -l < "$OUTPUT_FILE")
SIZE=$(du -h "$OUTPUT_FILE" | cut -f1)
echo -e "${GREEN}✓ Archivo generado exitosamente${NC}"
echo ""

# Resumen
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}RESUMEN${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "  Archivo:  ${GREEN}init_monolithic.sql${NC}"
echo -e "  Líneas:   ${GREEN}$LINES${NC}"
echo -e "  Tamaño:   ${GREEN}$SIZE${NC}"
echo -e "  Módulos:  ${GREEN}9${NC}"
echo ""
echo -e "${GREEN}✓ LISTO PARA PRODUCCIÓN${NC}"
