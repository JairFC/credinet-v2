#!/bin/bash

echo "=== INVESTIGACIÓN associate_debt_breakdown ==="
echo ""

echo "1. BUSCAR EN CÓDIGO BACKEND:"
find backend/app -name "*.py" -type f -exec grep -l "associate_debt_breakdown" {} \;

echo ""
echo "2. BUSCAR EN FRONTEND:"
find frontend/src -type f \( -name "*.jsx" -o -name "*.js" -o -name "*.tsx" -o -name "*.ts" \) -exec grep -l "debt_breakdown\|associateDebt\|debtBreakdown" {} \; 2>/dev/null || echo "No encontrado en frontend"

echo ""
echo "3. VER TRIGGERS EN BD:"
docker exec credinet-postgres psql -U credinet_user -d credinet_db -c "SELECT tgname, tgrelid::regclass FROM pg_trigger WHERE tgrelid = 'associate_debt_breakdown'::regclass;"