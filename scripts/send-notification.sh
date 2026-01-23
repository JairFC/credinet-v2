#!/bin/bash
# ==============================================================================
# 🔔 SEND-NOTIFICATION.SH - Enviar notificaciones a Telegram y Discord
# ==============================================================================
#
# ⚠️ CONTEXTO PARA IAs:
# Este script es llamado por otros scripts (backup-db.sh, deploy.sh) para
# enviar notificaciones sobre eventos del sistema. NO modifica datos ni
# ejecuta comandos Docker. Es seguro ejecutar en cualquier rama.
#
# Uso:
#   ./scripts/send-notification.sh "Título" "Mensaje" [success|error|warning|info]
#
# Ejemplos:
#   ./scripts/send-notification.sh "Backup Completado" "Tamaño: 80KB" success
#   ./scripts/send-notification.sh "Error en Deploy" "Rollback ejecutado" error
#
# ==============================================================================

set -e

# Cargar variables de entorno
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

if [ -f "$PROJECT_DIR/.env" ]; then
    export $(grep -v '^#' "$PROJECT_DIR/.env" | grep -E '^(TELEGRAM_|DISCORD_|SMTP_)' | xargs)
fi

# Parámetros
TITLE="${1:-Notificación}"
MESSAGE="${2:-Sin mensaje}"
TYPE="${3:-info}"  # success, error, warning, info

# Timestamps - UTC y Chihuahua
TIMESTAMP_UTC=$(date -u '+%Y-%m-%d %H:%M:%S UTC')
TIMESTAMP_CHI=$(TZ='America/Chihuahua' date '+%Y-%m-%d %H:%M:%S CST')
HOSTNAME=$(hostname)

# Determinar emoji según tipo
case $TYPE in
    success) EMOJI="✅" ;;
    error)   EMOJI="❌" ;;
    warning) EMOJI="⚠️" ;;
    info)    EMOJI="ℹ️" ;;
    *)       EMOJI="🔔" ;;
esac

# ==============================================================================
# TELEGRAM
# ==============================================================================
send_telegram() {
    local chat_id=$1
    
    if [ -z "$TELEGRAM_BOT_TOKEN" ] || [ -z "$chat_id" ]; then
        return 1
    fi
    
    local TG_MESSAGE="$EMOJI *$TITLE*

$MESSAGE

📍 Servidor: \`$HOSTNAME\`
🕐 Hora: \`$TIMESTAMP_CHI\`
🌐 UTC: \`$TIMESTAMP_UTC\`"
    
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d "chat_id=${chat_id}" \
        -d "text=${TG_MESSAGE}" \
        -d "parse_mode=Markdown" \
        -d "disable_web_page_preview=true" \
        > /dev/null 2>&1 || true
}

# ==============================================================================
# DISCORD
# ==============================================================================
send_discord() {
    if [ -z "$DISCORD_WEBHOOK_URL" ]; then
        return 1
    fi
    
    # Escapar el mensaje para JSON (reemplazar newlines reales)
    local MSG_ESCAPED=$(echo -e "$MESSAGE" | sed ':a;N;$!ba;s/\n/\\n/g')
    local DISCORD_CONTENT="$EMOJI **$TITLE**\n\n$MSG_ESCAPED\n\n📍 Servidor: \`$HOSTNAME\`\n🕐 Chihuahua: \`$TIMESTAMP_CHI\`\n🌐 UTC: \`$TIMESTAMP_UTC\`"
    
    curl -s -X POST "$DISCORD_WEBHOOK_URL" \
        -H "Content-Type: application/json" \
        -d "{\"username\": \"CrediNet Alertas\", \"content\": \"$DISCORD_CONTENT\"}" \
        > /dev/null 2>&1 || true
}

# ==============================================================================
# EMAIL (opcional - requiere SMTP_* en .env)
# ==============================================================================
send_email() {
    # Requiere: SMTP_TO, SMTP_FROM en .env
    # Usa msmtp o mailx si está configurado
    if [ -z "$SMTP_TO" ] || ! command -v msmtp &> /dev/null; then
        return 0  # Silenciosamente ignorar si no está configurado
    fi
    
    local EMAIL_BODY="$EMOJI $TITLE

$MESSAGE

---
📍 Servidor: $HOSTNAME
🕐 Chihuahua: $TIMESTAMP_CHI
🌐 UTC: $TIMESTAMP_UTC

-- CrediNet Alertas"
    
    echo -e "$EMAIL_BODY" | msmtp -a default "$SMTP_TO" 2>/dev/null || true
}

# ==============================================================================
# ENVIAR A TODOS LOS CANALES
# ==============================================================================

# Telegram - Chat personal (siempre)
if [ -n "$TELEGRAM_CHAT_ID" ]; then
    send_telegram "$TELEGRAM_CHAT_ID"
fi

# Telegram - Grupo (siempre - el grupo es para el equipo)
if [ -n "$TELEGRAM_GROUP_ID" ]; then
    send_telegram "$TELEGRAM_GROUP_ID"
fi

# Discord - Siempre
send_discord

# Email - Si está configurado
send_email

# Salir silenciosamente (no queremos que falle el script padre)
exit 0
