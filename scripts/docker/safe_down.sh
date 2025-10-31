#!/bin/bash
# =============================================================================
# SAFE DOWN - CrediNet v2.0
# =============================================================================
# Detiene Docker Compose de forma SEGURA con backup automático
# Uso: ./scripts/docker/safe_down.sh [opciones]
# Opciones:
#   --volumes, -v    : Eliminar volúmenes (requiere confirmación)
#   --force, -f      : Forzar sin confirmación
#   --no-backup      : No crear backup (¡PELIGROSO!)
# =============================================================================

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variables
REMOVE_VOLUMES=false
FORCE=false
CREATE_BACKUP=true

# Parsear argumentos
while [[ $# -gt 0 ]]; do
    case $1 in
        --volumes|-v)
            REMOVE_VOLUMES=true
            shift
            ;;
        --force|-f)
            FORCE=true
            shift
            ;;
        --no-backup)
            CREATE_BACKUP=false
            shift
            ;;
        *)
            echo -e "${RED}❌ Opción desconocida: $1${NC}"
            echo ""
            echo "Uso: ./scripts/docker/safe_down.sh [opciones]"
            echo "Opciones:"
            echo "  --volumes, -v    : Eliminar volúmenes (requiere confirmación)"
            echo "  --force, -f      : Forzar sin confirmación"
            echo "  --no-backup      : No crear backup (¡PELIGROSO!)"
            exit 1
            ;;
    esac
done

echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║          SAFE DOWN - CrediNet v2.0                         ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Verificar si hay contenedores corriendo
if ! docker-compose ps | grep -q "Up"; then
    echo -e "${YELLOW}⚠️  No hay contenedores corriendo${NC}"
    exit 0
fi

# Crear backup automático (si está habilitado)
if [ "$CREATE_BACKUP" = true ]; then
    echo -e "${YELLOW}📦 Paso 1/3: Creando backup automático...${NC}"
    echo ""
    
    # Verificar si el contenedor de postgres está corriendo
    if docker ps | grep -q credinet-postgres; then
        BACKUP_NAME="auto_backup_$(date +"%Y%m%d_%H%M%S")"
        
        # Ejecutar backup
        if ./scripts/database/backup_db.sh "$BACKUP_NAME"; then
            echo -e "${GREEN}✅ Backup creado: ${BACKUP_NAME}${NC}"
        else
            echo -e "${RED}❌ Error al crear backup${NC}"
            if [ "$FORCE" = false ]; then
                read -p "¿Continuar sin backup? (s/N): " -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[Ss]$ ]]; then
                    echo -e "${YELLOW}❌ Operación cancelada${NC}"
                    exit 1
                fi
            fi
        fi
    else
        echo -e "${YELLOW}⚠️  Contenedor de PostgreSQL no está corriendo, saltando backup${NC}"
    fi
    echo ""
else
    echo -e "${RED}⚠️  Backup DESHABILITADO (--no-backup)${NC}"
    echo ""
fi

# Detener contenedores
echo -e "${YELLOW}🛑 Paso 2/3: Deteniendo contenedores...${NC}"
echo ""
docker-compose down

echo -e "${GREEN}✅ Contenedores detenidos${NC}"
echo ""

# Eliminar volúmenes (si se solicitó)
if [ "$REMOVE_VOLUMES" = true ]; then
    echo -e "${RED}⚠️  Paso 3/3: ELIMINANDO VOLÚMENES${NC}"
    echo ""
    
    if [ "$FORCE" = false ]; then
        echo -e "${RED}╔═══════════════════════════════════════════════════════════╗${NC}"
        echo -e "${RED}║  ⚠️  ADVERTENCIA: OPERACIÓN DESTRUCTIVA ⚠️               ║${NC}"
        echo -e "${RED}╚═══════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo "Esta operación ELIMINARÁ PERMANENTEMENTE:"
        echo "  • credinet-postgres-data (Base de datos completa)"
        echo "  • credinet-backend-uploads (Archivos subidos)"
        echo "  • credinet-backend-logs (Logs del sistema)"
        echo ""
        echo -e "${YELLOW}Backup creado: ${BACKUP_NAME}.sql.gz${NC}"
        echo ""
        read -p "¿Estás ABSOLUTAMENTE seguro? (escribe 'SI ELIMINAR' para continuar): " -r
        echo
        if [[ ! $REPLY =~ ^SI\ ELIMINAR$ ]]; then
            echo -e "${YELLOW}❌ Operación cancelada (volúmenes conservados)${NC}"
            exit 1
        fi
    fi
    
    echo -e "${YELLOW}🗑️  Eliminando volúmenes...${NC}"
    docker volume rm credinet-postgres-data credinet-backend-uploads credinet-backend-logs 2>/dev/null || true
    echo -e "${GREEN}✅ Volúmenes eliminados${NC}"
else
    echo -e "${GREEN}✅ Paso 3/3: Volúmenes conservados (uso --volumes para eliminar)${NC}"
fi

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✅ SAFE DOWN COMPLETADO EXITOSAMENTE                      ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

if [ "$CREATE_BACKUP" = true ] && [ "$REMOVE_VOLUMES" = false ]; then
    echo -e "${YELLOW}💡 Próximos pasos:${NC}"
    echo -e "${YELLOW}   • Para reiniciar: docker-compose up -d${NC}"
    echo -e "${YELLOW}   • Para restaurar: ./scripts/database/restore_db.sh ${BACKUP_NAME}${NC}"
elif [ "$REMOVE_VOLUMES" = true ]; then
    echo -e "${YELLOW}💡 Próximos pasos:${NC}"
    echo -e "${YELLOW}   • Para reiniciar: docker-compose up -d${NC}"
    echo -e "${YELLOW}   • Para restaurar backup: ./scripts/database/restore_db.sh ${BACKUP_NAME}${NC}"
fi
echo ""
