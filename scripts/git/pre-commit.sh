#!/bin/bash

# Pre-commit hook para validar frontend
# Instalar con: cp pre-commit.sh .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit

echo "🔍 Validando frontend antes del commit..."

# Función para verificar archivos JSX/JS
validate_js_files() {
    local has_errors=false
    
    # Obtener archivos JSX/JS modificados
    changed_files=$(git diff --cached --name-only --diff-filter=ACM | grep -E "\.(jsx?|tsx?)$")
    
    if [[ -z "$changed_files" ]]; then
        echo "✓ No hay archivos JS/JSX modificados"
        return 0
    fi
    
    echo "📝 Validando archivos modificados:"
    
    for file in $changed_files; do
        if [[ -f "$file" ]]; then
            echo -n "  $file... "
            
            # Verificar que no esté vacío
            if [[ ! -s "$file" ]]; then
                echo "❌ ARCHIVO VACÍO"
                has_errors=true
                continue
            fi
            
            # Verificar sintaxis básica con Node.js
            if node -c "$file" 2>/dev/null; then
                echo "✓"
            else
                echo "❌ ERROR DE SINTAXIS"
                has_errors=true
            fi
        fi
    done
    
    if [[ "$has_errors" == true ]]; then
        return 1
    fi
    
    return 0
}

# Función para build test rápido
quick_build_test() {
    echo "🏗️ Test de build rápido..."
    
    cd frontend || return 1
    
    # Build silencioso
    if npm run build > /dev/null 2>&1; then
        echo "✓ Build exitoso"
        cd ..
        return 0
    else
        echo "❌ Build falló"
        echo "💡 Ejecuta 'npm run build' para ver errores detallados"
        cd ..
        return 1
    fi
}

# Función principal
main() {
    validate_js_files
    js_valid=$?
    
    if [[ $js_valid -ne 0 ]]; then
        echo "❌ Errores en archivos JavaScript/JSX"
        echo "💡 Corrige los errores antes de hacer commit"
        exit 1
    fi
    
    quick_build_test
    build_valid=$?
    
    if [[ $build_valid -ne 0 ]]; then
        echo "❌ El build falló"
        echo "💡 Corrige los errores de build antes de hacer commit"
        exit 1
    fi
    
    echo "✅ Validación exitosa - proceder con commit"
    exit 0
}

# Solo ejecutar si estamos en un repositorio git
if [[ -d ".git" ]]; then
    main
else
    echo "⚠️ No es un repositorio git, saltando validación"
    exit 0
fi
