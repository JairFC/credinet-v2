#!/bin/bash
# ==============================================================================
# 🛡️ SAFE-DOCKER.SH - Script de Protección para Entorno de Producción
# ==============================================================================
#
# ⚠️ CONTEXTO CRÍTICO PARA CUALQUIER IA O DESARROLLADOR:
#
# Este script existe porque este servidor (10.5.26.141 / 10.0.0.19) es el
# SERVIDOR DE PRODUCCIÓN de CrediNet v2.0 - un sistema financiero real con:
#   - 4 usuarios activos
#   - 3 préstamos reales
#   - 33 pagos registrados
#   - Datos financieros sensibles
#
# El volumen de PostgreSQL (credinet-postgres-data) contiene datos REALES.
#
# 📋 SITUACIÓN ESPECIAL:
# Se decidió trabajar con múltiples ramas Git (main, develop, feature/*) 
# en este mismo servidor para evitar saltar entre entornos. PERO los comandos
# Docker solo deben ejecutarse cuando estamos en la rama 'main'.
#
# ¿Por qué? Porque ejecutar 'docker compose up' en develop haría:
#   1. Rebuild del código de develop (no probado)
#   2. Conectarse a la BD de producción (datos reales)
#   3. Potencial corrupción o pérdida de datos
#
# 🔒 REGLAS DE ORO:
#   1. Comandos Docker → SOLO en rama 'main'
#   2. En develop/feature → SOLO editar código, commit, push
#   3. Testing → Hacer en entorno 192.168.98.98 o local
#   4. Deploy → Solo con ./scripts/deploy.sh (que también valida)
#
# 📅 Creado: 23 de Enero 2026
# 🔧 Última modificación: 23 de Enero 2026
# 👤 Autor: GitHub Copilot + Jair
#
# ==============================================================================

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Obtener rama actual
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")

# Banner informativo
echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║${NC}  🛡️  SAFE-DOCKER - Protección de Entorno de Producción        ${BLUE}║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Mostrar estado actual
echo -e "${YELLOW}📍 Información del entorno:${NC}"
echo "   Rama actual:  $CURRENT_BRANCH"
echo "   Servidor:     $(hostname)"
echo "   Directorio:   $(pwd)"
echo ""

# Validación principal
if [ "$CURRENT_BRANCH" != "main" ]; then
    echo -e "${RED}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║  ❌ ERROR: NO ESTÁS EN LA RAMA 'main'                          ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${RED}⚠️  OPERACIÓN BLOQUEADA${NC}"
    echo ""
    echo "   Estás en la rama: ${YELLOW}$CURRENT_BRANCH${NC}"
    echo "   Los comandos Docker solo están permitidos en: ${GREEN}main${NC}"
    echo ""
    echo -e "${YELLOW}📋 ¿Qué puedes hacer?${NC}"
    echo ""
    echo "   Opción 1: Cambiar a main primero"
    echo "   ${BLUE}git checkout main${NC}"
    echo "   ${BLUE}./scripts/safe-docker.sh $@${NC}"
    echo ""
    echo "   Opción 2: Seguir desarrollando (sin Docker)"
    echo "   - Edita código, haz commits, push a GitHub"
    echo "   - Prueba en entorno de desarrollo (192.168.98.98)"
    echo "   - Cuando esté listo, merge a main y deploy"
    echo ""
    echo -e "${RED}🛑 Motivo de esta restricción:${NC}"
    echo "   Este es el servidor de PRODUCCIÓN con datos financieros reales."
    echo "   Ejecutar Docker en ramas de desarrollo podría:"
    echo "   - Levantar código no probado contra BD real"
    echo "   - Corromper datos de producción"
    echo "   - Causar downtime no planificado"
    echo ""
    exit 1
fi

# Si llegamos aquí, estamos en main
echo -e "${GREEN}✅ Rama verificada: main${NC}"
echo ""

# Verificar si hay cambios no commiteados
if ! git diff-index --quiet HEAD -- 2>/dev/null; then
    echo -e "${YELLOW}⚠️  ADVERTENCIA: Hay cambios no commiteados${NC}"
    echo "   Considera hacer commit antes de operaciones Docker"
    echo ""
fi

# Mostrar qué comando se va a ejecutar
echo -e "${BLUE}🐳 Ejecutando: docker compose $@${NC}"
echo ""

# Ejecutar el comando Docker
docker compose "$@"
