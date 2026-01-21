#!/bin/bash

# =============================================================================
# TEST AUTOMATIZADO COMPLETO - Sistema de Créditos
# =============================================================================
# Fecha: 2026-01-07
# Propósito: Validar que credit_used usa associate_payment correctamente
# =============================================================================

set -e  # Salir si hay error

API_URL="http://localhost:8000/api/v1"
USERNAME="admin"
PASSWORD="Sparrow20"

echo "🚀 INICIANDO TESTING AUTOMATIZADO"
echo "=================================="
echo ""

# =============================================================================
# 1. AUTENTICACIÓN
# =============================================================================
echo "1️⃣ Autenticando..."
LOGIN_RESPONSE=$(curl -s -X POST "$API_URL/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"$USERNAME\",\"password\":\"$PASSWORD\"}")

TOKEN=$(echo "$LOGIN_RESPONSE" | jq -r '.tokens.access_token')

if [ "$TOKEN" = "null" ] || [ -z "$TOKEN" ]; then
    echo "❌ ERROR: No se pudo obtener el token"
    echo "$LOGIN_RESPONSE" | jq .
    exit 1
fi

echo "✅ Token obtenido"
echo ""

# =============================================================================
# 2. BUSCAR ASOCIADO CON CRÉDITO DISPONIBLE
# =============================================================================
echo "2️⃣ Usando asociado con crédito disponible..."

# Usar asociado ID 10 que tiene $300k disponible
ASSOCIATE_ID=10
ASSOCIATE_NAME="JAIR armendariz FRANCO"

# Obtener datos del asociado
ASSOCIATE_DATA=$(curl -s "$API_URL/associates/$ASSOCIATE_ID" \
  -H "Authorization: Bearer $TOKEN")

CREDIT_USED_BEFORE=$(echo "$ASSOCIATE_DATA" | jq -r '.credit_used // "0"')
CREDIT_AVAILABLE=$(echo "$ASSOCIATE_DATA" | jq -r '.credit_available // "300000"')

echo "✅ Asociado seleccionado:"
echo "   ID: $ASSOCIATE_ID"
echo "   Nombre: $ASSOCIATE_NAME"
echo "   Crédito usado: \$$CREDIT_USED_BEFORE"
echo "   Crédito disponible: \$$CREDIT_AVAILABLE"
echo ""

# =============================================================================
# 3. USAR CLIENTE EXISTENTE
# =============================================================================
echo "3️⃣ Usando cliente existente..."

# Usar cliente ID 5 (Juan Pérez)
CLIENT_ID=5

echo "✅ Cliente seleccionado: ID $CLIENT_ID"
echo ""

# =============================================================================
# 4. CREAR PRÉSTAMO DE \$10,000
# =============================================================================
echo "4️⃣ Creando préstamo de \$10,000..."

LOAN_PAYLOAD=$(cat <<EOF
{
  "user_id": $CLIENT_ID,
  "associate_user_id": $ASSOCIATE_ID,
  "amount": 10000,
  "term_biweeks": 12,
  "profile_code": "standard"
}
EOF
)

LOAN_RESPONSE=$(curl -s -X POST "$API_URL/loans" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "$LOAN_PAYLOAD")

LOAN_ID=$(echo "$LOAN_RESPONSE" | jq -r '.id // .loan_id // .data.id')

if [ -z "$LOAN_ID" ] || [ "$LOAN_ID" = "null" ]; then
    echo "❌ ERROR: No se pudo crear el préstamo"
    echo "$LOAN_RESPONSE" | jq .
    exit 1
fi

echo "✅ Préstamo creado: ID $LOAN_ID"

# Obtener detalles del préstamo
LOAN_DETAILS=$(curl -s "$API_URL/loans/$LOAN_ID" \
  -H "Authorization: Bearer $TOKEN")

BIWEEKLY_PAYMENT=$(echo "$LOAN_DETAILS" | jq -r '.biweekly_payment')
TOTAL_PAYMENT=$(echo "$LOAN_DETAILS" | jq -r '.total_payment')
COMMISSION_PER_PAYMENT=$(echo "$LOAN_DETAILS" | jq -r '.commission_per_payment')

echo "   Pago quincenal: \$$BIWEEKLY_PAYMENT"
echo "   Total a pagar: \$$TOTAL_PAYMENT"
echo "   Comisión por pago: \$$COMMISSION_PER_PAYMENT"
echo ""

# =============================================================================
# 5. APROBAR PRÉSTAMO
# =============================================================================
echo "5️⃣ Aprobando préstamo..."

APPROVE_RESPONSE=$(curl -s -X PATCH "$API_URL/loans/$LOAN_ID/approve" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{}')

echo "✅ Préstamo aprobado"
echo ""

# Esperar un momento para que se procesen los triggers
sleep 2

# =============================================================================
# 6. OBTENER PAGOS GENERADOS
# =============================================================================
echo "6️⃣ Obteniendo cronograma de pagos..."

PAYMENTS_RESPONSE=$(curl -s "$API_URL/loans/$LOAN_ID/payments" \
  -H "Authorization: Bearer $TOKEN")

FIRST_PAYMENT=$(echo "$PAYMENTS_RESPONSE" | jq -r '.items[0] // .data[0] // .[0]')
PAYMENT_ID=$(echo "$FIRST_PAYMENT" | jq -r '.id')
EXPECTED_AMOUNT=$(echo "$FIRST_PAYMENT" | jq -r '.expected_amount')
ASSOCIATE_PAYMENT=$(echo "$FIRST_PAYMENT" | jq -r '.associate_payment')
COMMISSION_AMOUNT=$(echo "$FIRST_PAYMENT" | jq -r '.commission_amount')

echo "✅ Primer pago del cronograma:"
echo "   Payment ID: $PAYMENT_ID"
echo "   Expected amount (cliente paga): \$$EXPECTED_AMOUNT"
echo "   Commission amount (asociado se queda): \$$COMMISSION_AMOUNT"
echo "   Associate payment (asociado paga a CrediCuenta): \$$ASSOCIATE_PAYMENT"
echo ""

# Calcular total de associate_payment
TOTAL_ASSOCIATE_PAYMENT=$(echo "$PAYMENTS_RESPONSE" | jq -r '
  [.items[]? // .data[]? // .[] | .associate_payment | tonumber] | add
')

echo "   Total associate_payment del préstamo: \$$TOTAL_ASSOCIATE_PAYMENT"
echo ""

# =============================================================================
# 7. VALIDAR INCREMENTO DE credit_used
# =============================================================================
echo "7️⃣ Validando incremento de credit_used..."

ASSOCIATE_AFTER=$(curl -s "$API_URL/associates/$ASSOCIATE_ID" \
  -H "Authorization: Bearer $TOKEN")

CREDIT_USED_AFTER=$(echo "$ASSOCIATE_AFTER" | jq -r '.credit_used')

CREDIT_INCREMENT=$(echo "$CREDIT_USED_AFTER - $CREDIT_USED_BEFORE" | bc)

echo "   Crédito usado ANTES: \$$CREDIT_USED_BEFORE"
echo "   Crédito usado DESPUÉS: \$$CREDIT_USED_AFTER"
echo "   Incremento: \$$CREDIT_INCREMENT"
echo ""

# Validar que el incremento es igual a total_associate_payment
DIFF=$(echo "$CREDIT_INCREMENT - $TOTAL_ASSOCIATE_PAYMENT" | bc)
DIFF_ABS=$(echo "$DIFF" | tr -d '-')

if (( $(echo "$DIFF_ABS < 1" | bc -l) )); then
    echo "✅ CORRECTO: credit_used incrementó por associate_payment total (\$$TOTAL_ASSOCIATE_PAYMENT)"
    echo "   Diferencia: \$$DIFF (dentro del margen de redondeo)"
else
    echo "❌ ERROR: credit_used NO incrementó correctamente"
    echo "   Esperado: \$$TOTAL_ASSOCIATE_PAYMENT"
    echo "   Real: \$$CREDIT_INCREMENT"
    echo "   Diferencia: \$$DIFF"
    exit 1
fi
echo ""

# =============================================================================
# 8. SIMULAR PAGO DEL CLIENTE
# =============================================================================
echo "8️⃣ Simulando pago del primer período..."

# Marcar el primer pago como pagado
MARK_PAID_RESPONSE=$(curl -s -X PATCH "$API_URL/payments/$PAYMENT_ID" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"amount_paid\": $EXPECTED_AMOUNT}")

echo "✅ Pago marcado como pagado"
echo ""

# Esperar procesamiento
sleep 2

# =============================================================================
# 9. VALIDAR LIBERACIÓN DE CRÉDITO
# =============================================================================
echo "9️⃣ Validando liberación de crédito..."

ASSOCIATE_AFTER_PAYMENT=$(curl -s "$API_URL/associates/$ASSOCIATE_ID" \
  -H "Authorization: Bearer $TOKEN")

CREDIT_USED_AFTER_PAYMENT=$(echo "$ASSOCIATE_AFTER_PAYMENT" | jq -r '.credit_used')

CREDIT_RELEASED=$(echo "$CREDIT_USED_AFTER - $CREDIT_USED_AFTER_PAYMENT" | bc)

echo "   Crédito usado ANTES del pago: \$$CREDIT_USED_AFTER"
echo "   Crédito usado DESPUÉS del pago: \$$CREDIT_USED_AFTER_PAYMENT"
echo "   Crédito liberado: \$$CREDIT_RELEASED"
echo ""

# Validar que se liberó associate_payment (NO solo capital)
CAPITAL_PER_PAYMENT=$(echo "10000 / 12" | bc -l | xargs printf "%.2f")
DIFF_PAYMENT=$(echo "$CREDIT_RELEASED - $ASSOCIATE_PAYMENT" | bc)
DIFF_PAYMENT_ABS=$(echo "$DIFF_PAYMENT" | tr -d '-')

if (( $(echo "$DIFF_PAYMENT_ABS < 1" | bc -l) )); then
    echo "✅ CORRECTO: Se liberó associate_payment (\$$ASSOCIATE_PAYMENT)"
    echo "   Diferencia: \$$DIFF_PAYMENT (dentro del margen de redondeo)"
    echo ""
    echo "   ⚠️ Nota: Si solo se hubiera liberado capital, sería \$$CAPITAL_PER_PAYMENT"
    echo "   📊 Diferencia entre associate_payment y capital: \$$(echo "$ASSOCIATE_PAYMENT - $CAPITAL_PER_PAYMENT" | bc)"
else
    echo "❌ ERROR: No se liberó el monto correcto"
    echo "   Esperado (associate_payment): \$$ASSOCIATE_PAYMENT"
    echo "   Real: \$$CREDIT_RELEASED"
    echo "   Diferencia: \$$DIFF_PAYMENT"
    exit 1
fi

# =============================================================================
# 10. RESUMEN FINAL
# =============================================================================
echo ""
echo "══════════════════════════════════════════"
echo "✅ TESTING COMPLETADO EXITOSAMENTE"
echo "══════════════════════════════════════════"
echo ""
echo "📊 RESUMEN DE VALIDACIONES:"
echo ""
echo "1. ✅ Préstamo creado: \$10,000"
echo "2. ✅ credit_used incrementó: \$$CREDIT_INCREMENT"
echo "3. ✅ Incremento = associate_payment total: \$$TOTAL_ASSOCIATE_PAYMENT"
echo "4. ✅ Pago registrado: \$$EXPECTED_AMOUNT"
echo "5. ✅ Crédito liberado: \$$CREDIT_RELEASED"
echo "6. ✅ Liberación = associate_payment: \$$ASSOCIATE_PAYMENT"
echo ""
echo "🎯 CONFIRMADO: El sistema usa associate_payment correctamente"
echo ""
echo "💡 EXPLICACIÓN:"
echo "   Cliente paga al asociado: \$$EXPECTED_AMOUNT"
echo "   Asociado se queda (comisión): \$$COMMISSION_AMOUNT"
echo "   Asociado paga a CrediCuenta: \$$ASSOCIATE_PAYMENT ✅"
echo "   Este último es lo que ocupa y libera el crédito"
echo ""

# =============================================================================
# CLEANUP (OPCIONAL)
# =============================================================================
echo "🗑️ Limpieza..."
echo "   Préstamo ID $LOAN_ID queda en el sistema para inspección"
echo "   Cliente ID $CLIENT_ID queda en el sistema"
echo ""
echo "✅ Test finalizado"
