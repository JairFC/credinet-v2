#!/bin/bash

echo "🔍 VALIDACIÓN FRONTEND - CREDINET"
echo "=================================="

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para verificar sintaxis básica
check_syntax() {
    echo -e "${BLUE}📝 Verificando sintaxis básica...${NC}"
    
    # Verificar archivos JSX principales
    jsx_files=(
        "frontend/src/components/DocumentPreviewModal.jsx"
        "frontend/src/components/SimpleDocuments.jsx"
        "frontend/src/App.jsx"
        "frontend/src/components/DebugPanel.jsx"
    )
    
    for file in "${jsx_files[@]}"; do
        if [[ -f "$file" ]]; then
            echo -n "  Verificando $file... "
            
            # Verificar export default
            if grep -q "export default" "$file"; then
                echo -e "${GREEN}✓ Export OK${NC}"
            else
                echo -e "${RED}✗ Falta export default${NC}"
            fi
            
            # Verificar imports básicos
            if grep -q "import React" "$file"; then
                echo -e "    ${GREEN}✓ React import OK${NC}"
            else
                echo -e "    ${YELLOW}⚠ Sin React import${NC}"
            fi
            
            # Verificar balance de llaves
            open_braces=$(grep -o '{' "$file" | wc -l)
            close_braces=$(grep -o '}' "$file" | wc -l)
            if [[ $open_braces -eq $close_braces ]]; then
                echo -e "    ${GREEN}✓ Llaves balanceadas ($open_braces)${NC}"
            else
                echo -e "    ${RED}✗ Llaves desbalanceadas (${open_braces} vs ${close_braces})${NC}"
            fi
        else
            echo -e "  ${RED}✗ Archivo no encontrado: $file${NC}"
        fi
        echo
    done
}

# Función para verificar imports/exports
check_imports() {
    echo -e "${BLUE}🔗 Verificando imports/exports...${NC}"
    
    # Verificar que DocumentPreviewModal sea importado correctamente
    if grep -q "import DocumentPreviewModal from './DocumentPreviewModal'" "frontend/src/components/SimpleDocuments.jsx"; then
        echo -e "  ${GREEN}✓ DocumentPreviewModal import OK${NC}"
    else
        echo -e "  ${RED}✗ DocumentPreviewModal import incorrecto${NC}"
    fi
    
    # Verificar que DebugPanel sea importado en App.jsx
    if grep -q "import DebugPanel" "frontend/src/App.jsx"; then
        echo -e "  ${GREEN}✓ DebugPanel import OK${NC}"
    else
        echo -e "  ${YELLOW}⚠ DebugPanel no importado${NC}"
    fi
}

# Función para verificar el build
check_build() {
    echo -e "${BLUE}🏗️ Verificando build del frontend...${NC}"
    
    cd frontend || exit 1
    
    # Verificar que node_modules exista
    if [[ -d "node_modules" ]]; then
        echo -e "  ${GREEN}✓ node_modules existe${NC}"
    else
        echo -e "  ${RED}✗ node_modules no encontrado${NC}"
        echo -e "  ${YELLOW}💡 Ejecutar: npm install${NC}"
    fi
    
    # Verificar package.json
    if [[ -f "package.json" ]]; then
        echo -e "  ${GREEN}✓ package.json existe${NC}"
        
        # Verificar dependencias críticas
        if grep -q "react" package.json; then
            echo -e "    ${GREEN}✓ React dependency OK${NC}"
        else
            echo -e "    ${RED}✗ React dependency missing${NC}"
        fi
        
        if grep -q "vite" package.json; then
            echo -e "    ${GREEN}✓ Vite dependency OK${NC}"
        else
            echo -e "    ${RED}✗ Vite dependency missing${NC}"
        fi
    fi
    
    cd ..
}

# Función para limpiar caché
clean_cache() {
    echo -e "${BLUE}🧹 Limpiando caché...${NC}"
    
    cd frontend || exit 1
    
    # Limpiar caché de Vite
    if [[ -d "node_modules/.vite" ]]; then
        rm -rf node_modules/.vite
        echo -e "  ${GREEN}✓ Caché de Vite limpiado${NC}"
    fi
    
    # Limpiar dist
    if [[ -d "dist" ]]; then
        rm -rf dist
        echo -e "  ${GREEN}✓ Directorio dist limpiado${NC}"
    fi
    
    cd ..
}

# Función para test rápido
quick_test() {
    echo -e "${BLUE}⚡ Test rápido de compilación...${NC}"
    
    cd frontend || exit 1
    
    # Intentar build
    echo -e "  ${YELLOW}Compilando...${NC}"
    if npm run build > /tmp/build.log 2>&1; then
        echo -e "  ${GREEN}✓ Build exitoso${NC}"
    else
        echo -e "  ${RED}✗ Build falló${NC}"
        echo -e "  ${YELLOW}Errores:${NC}"
        tail -10 /tmp/build.log | sed 's/^/    /'
    fi
    
    cd ..
}

# Función principal
main() {
    echo -e "${YELLOW}Iniciando validación...${NC}"
    echo
    
    check_syntax
    echo
    check_imports
    echo
    check_build
    echo
    
    read -p "¿Limpiar caché y probar build? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        clean_cache
        echo
        quick_test
    fi
    
    echo
    echo -e "${GREEN}🎯 Validación completada${NC}"
}

# Ejecutar
main
