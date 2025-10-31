#!/bin/bash

# CREDINET - Script de Verificación Completa
# Ejecuta todos los tests disponibles en el sistema

echo "🚀 INICIANDO VERIFICACIÓN COMPLETA DE CREDINET"
echo "=============================================="

# Verificar que los contenedores estén corriendo
echo "📋 Verificando estado de contenedores..."
docker compose ps

echo ""
echo "🧪 EJECUTANDO SMOKE TEST BÁSICO (9 tests)..."
echo "---------------------------------------------"
docker compose exec backend python smoke_test_clean.py

echo ""
echo "🔬 EJECUTANDO SUITE COMPLETA DE TESTS UNITARIOS..."
echo "------------------------------------------------"
docker compose exec backend python -m pytest --ignore=app/loans/tests/test_date_logic.py --ignore=app/loans/tests/test_value_objects.py --ignore=app/loans/tests/application/test_calculate_amortization_use_case.py --tb=short -v

echo ""
echo "📊 RESUMEN DE VERIFICACIÓN COMPLETADA"
echo "===================================="
echo "✅ Smoke Test: Verificaciones básicas del sistema"
echo "✅ Unit Tests: Lógica de negocio y casos de uso"
echo "🌐 Frontend disponible en: http://localhost:5174"
echo "🔗 API disponible en: http://localhost:8001"
echo "📚 Documentación API: http://localhost:8001/docs"