#!/bin/bash
# ==============================================================================
# 🔔 TEST-NOTIFICATIONS.SH - Prueba de Sistema de Notificaciones
# ==============================================================================
#
# Este script prueba el envío de notificaciones a Telegram y Discord
# sin necesidad de levantar Docker o modificar el backend.
#
# Uso:
#   ./scripts/test-notifications.sh           # Prueba ambos canales
#   ./scripts/test-notifications.sh telegram  # Solo Telegram
#   ./scripts/test-notifications.sh discord   # Solo Discord
#
# ==============================================================================

set -e

# Cargar variables de entorno
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
else
    echo "❌ Error: No se encontró archivo .env"
    exit 1
fi

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Timestamp
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S %Z')
HOSTNAME=$(hostname)

echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║${NC}  🔔  CrediNet v2.0 - Test de Notificaciones                    ${BLUE}║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}📅 Timestamp:${NC} $TIMESTAMP"
echo -e "${YELLOW}🖥️  Servidor:${NC} $HOSTNAME"
echo ""

# Función para enviar a Telegram
send_telegram() {
    local chat_id=$1
    local chat_name=$2
    
    echo -e "${BLUE}📱 Enviando a Telegram ($chat_name)...${NC}"
    
    # Mensaje formateado en Markdown
    MESSAGE="🔔 *CrediNet v2.0 - Test de Notificaciones*

✅ El sistema de notificaciones está funcionando correctamente.

📍 *Detalles:*
• Servidor: \`$HOSTNAME\`
• Timestamp: \`$TIMESTAMP\`
• Chat ID: \`$chat_id\`
• Tipo: Mensaje de prueba

🎯 Este mensaje confirma que las alertas de:
• Scheduler (cortes de período)
• Backups automáticos
• Errores críticos
• Eventos de auditoría

...llegarán correctamente a este chat."

    RESPONSE=$(curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d "chat_id=${chat_id}" \
        -d "text=${MESSAGE}" \
        -d "parse_mode=Markdown" \
        -d "disable_web_page_preview=true")
    
    if echo "$RESPONSE" | grep -q '"ok":true'; then
        echo -e "${GREEN}   ✅ Enviado exitosamente a $chat_name${NC}"
        return 0
    else
        echo -e "${RED}   ❌ Error al enviar a $chat_name${NC}"
        echo "   Respuesta: $RESPONSE"
        return 1
    fi
}

# Función para enviar a Discord
send_discord() {
    echo -e "${BLUE}💬 Enviando a Discord...${NC}"
    
    # Payload JSON para Discord (embed rico)
    PAYLOAD=$(cat <<EOF
{
    "username": "CrediNet Alertas",
    "avatar_url": "https://cdn-icons-png.flaticon.com/512/2331/2331970.png",
    "embeds": [{
        "title": "🔔 Test de Notificaciones",
        "description": "El sistema de notificaciones de CrediNet v2.0 está funcionando correctamente.",
        "color": 5763719,
        "fields": [
            {
                "name": "🖥️ Servidor",
                "value": "\`$HOSTNAME\`",
                "inline": true
            },
            {
                "name": "📅 Timestamp",
                "value": "\`$TIMESTAMP\`",
                "inline": true
            },
            {
                "name": "🎯 Eventos monitoreados",
                "value": "• Scheduler (cortes de período)\n• Backups automáticos\n• Errores críticos\n• Login/Logout\n• Préstamos aprobados\n• Pagos registrados",
                "inline": false
            }
        ],
        "footer": {
            "text": "CrediNet v2.0 • Sistema de Créditos"
        },
        "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    }]
}
EOF
)

    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$DISCORD_WEBHOOK_URL" \
        -H "Content-Type: application/json" \
        -d "$PAYLOAD")
    
    if [ "$RESPONSE" = "204" ] || [ "$RESPONSE" = "200" ]; then
        echo -e "${GREEN}   ✅ Enviado exitosamente a Discord${NC}"
        return 0
    else
        echo -e "${RED}   ❌ Error al enviar a Discord (HTTP $RESPONSE)${NC}"
        return 1
    fi
}

# Determinar qué canales probar
CHANNEL=${1:-all}
SUCCESS=true

case $CHANNEL in
    telegram)
        send_telegram "$TELEGRAM_CHAT_ID" "Chat Personal" || SUCCESS=false
        ;;
    telegram-group)
        send_telegram "$TELEGRAM_GROUP_ID" "Grupo" || SUCCESS=false
        ;;
    discord)
        send_discord || SUCCESS=false
        ;;
    all)
        echo -e "${YELLOW}Probando todos los canales...${NC}"
        echo ""
        send_telegram "$TELEGRAM_CHAT_ID" "Chat Personal" || SUCCESS=false
        echo ""
        send_telegram "$TELEGRAM_GROUP_ID" "Grupo" || SUCCESS=false
        echo ""
        send_discord || SUCCESS=false
        ;;
    *)
        echo "Uso: $0 [telegram|telegram-group|discord|all]"
        exit 1
        ;;
esac

echo ""
if [ "$SUCCESS" = true ]; then
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  ✅ TODAS LAS PRUEBAS COMPLETADAS EXITOSAMENTE                 ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
else
    echo -e "${YELLOW}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║  ⚠️  ALGUNAS PRUEBAS FALLARON - Revisa los errores arriba      ║${NC}"
    echo -e "${YELLOW}╚════════════════════════════════════════════════════════════════╝${NC}"
fi
echo ""
