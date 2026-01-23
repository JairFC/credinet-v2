"""
CrediNet v2.0 - Sistema de Notificaciones
===============================================================================
Módulo centralizado para enviar notificaciones a:
- Telegram (personal y grupo)
- Discord (webhook)
- Email (opcional, via SMTP)

Uso:
    from app.core.notifications import notify
    
    await notify.send(
        title="Préstamo Aprobado",
        message="Se aprobó préstamo #1234 por $5,000",
        level="success"  # success, error, warning, info
    )

Variables de entorno requeridas (.env):
    TELEGRAM_BOT_TOKEN=xxx
    TELEGRAM_CHAT_ID=xxx (personal)
    TELEGRAM_GROUP_ID=xxx (grupo)
    DISCORD_WEBHOOK_URL=xxx
    
Opcionales para email:
    SMTP_HOST=smtp.gmail.com
    SMTP_PORT=587
    SMTP_USER=xxx
    SMTP_PASSWORD=xxx
    SMTP_FROM=xxx
    SMTP_TO=xxx
===============================================================================
"""
import os
import logging
import httpx
from datetime import datetime
from typing import Optional, Literal
from zoneinfo import ZoneInfo

logger = logging.getLogger(__name__)

# Configuración desde variables de entorno
TELEGRAM_BOT_TOKEN = os.getenv("TELEGRAM_BOT_TOKEN", "")
TELEGRAM_CHAT_ID = os.getenv("TELEGRAM_CHAT_ID", "")
TELEGRAM_GROUP_ID = os.getenv("TELEGRAM_GROUP_ID", "")
DISCORD_WEBHOOK_URL = os.getenv("DISCORD_WEBHOOK_URL", "")
HOSTNAME = os.getenv("HOSTNAME", "credinet-backend")

# Mapeo de niveles a emojis
LEVEL_EMOJIS = {
    "success": "✅",
    "error": "❌",
    "warning": "⚠️",
    "info": "ℹ️",
}


class NotificationService:
    """Servicio de notificaciones para CrediNet."""
    
    def __init__(self):
        self.telegram_token = TELEGRAM_BOT_TOKEN
        self.telegram_chat_id = TELEGRAM_CHAT_ID
        self.telegram_group_id = TELEGRAM_GROUP_ID
        self.discord_webhook = DISCORD_WEBHOOK_URL
        self.hostname = HOSTNAME
        
    def _get_timestamps(self) -> tuple[str, str]:
        """Obtener timestamps en UTC y Chihuahua."""
        now = datetime.now(ZoneInfo("UTC"))
        chihuahua = now.astimezone(ZoneInfo("America/Chihuahua"))
        
        utc_str = now.strftime("%Y-%m-%d %H:%M:%S UTC")
        chi_str = chihuahua.strftime("%Y-%m-%d %H:%M:%S CST")
        
        return utc_str, chi_str
    
    async def _send_telegram(self, chat_id: str, title: str, message: str, emoji: str) -> bool:
        """Enviar mensaje a Telegram."""
        if not self.telegram_token or not chat_id:
            return False
            
        utc_ts, chi_ts = self._get_timestamps()
        
        text = f"""{emoji} *{title}*

{message}

📍 Servidor: `{self.hostname}`
🕐 Chihuahua: `{chi_ts}`
🌐 UTC: `{utc_ts}`"""
        
        url = f"https://api.telegram.org/bot{self.telegram_token}/sendMessage"
        payload = {
            "chat_id": chat_id,
            "text": text,
            "parse_mode": "Markdown",
            "disable_web_page_preview": True,
        }
        
        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                response = await client.post(url, data=payload)
                return response.status_code == 200
        except Exception as e:
            logger.warning(f"Error enviando Telegram: {e}")
            return False
    
    async def _send_discord(self, title: str, message: str, emoji: str) -> bool:
        """Enviar mensaje a Discord."""
        if not self.discord_webhook:
            return False
            
        utc_ts, chi_ts = self._get_timestamps()
        
        # Discord usa newlines normales en content, no hay que escapar
        content = f"{emoji} **{title}**\n\n{message}\n\n📍 Servidor: `{self.hostname}`\n🕐 Chihuahua: `{chi_ts}`\n🌐 UTC: `{utc_ts}`"
        
        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                response = await client.post(
                    self.discord_webhook,
                    json={
                        "username": "CrediNet Backend",
                        "content": content
                    }
                )
                return response.status_code in [200, 204]
        except Exception as e:
            logger.warning(f"Error enviando Discord: {e}")
            return False
    
    async def send(
        self,
        title: str,
        message: str,
        level: Literal["success", "error", "warning", "info"] = "info",
        to_group: bool = True,
        to_personal: bool = True,
        to_discord: bool = True,
    ) -> dict:
        """
        Enviar notificación a todos los canales configurados.
        
        Args:
            title: Título del mensaje
            message: Contenido del mensaje
            level: Nivel de severidad (success, error, warning, info)
            to_group: Enviar al grupo de Telegram
            to_personal: Enviar al chat personal de Telegram
            to_discord: Enviar a Discord
            
        Returns:
            dict con resultados de cada canal
        """
        emoji = LEVEL_EMOJIS.get(level, "🔔")
        results = {}
        
        # Telegram personal
        if to_personal and self.telegram_chat_id:
            results["telegram_personal"] = await self._send_telegram(
                self.telegram_chat_id, title, message, emoji
            )
        
        # Telegram grupo
        if to_group and self.telegram_group_id:
            results["telegram_group"] = await self._send_telegram(
                self.telegram_group_id, title, message, emoji
            )
        
        # Discord
        if to_discord and self.discord_webhook:
            results["discord"] = await self._send_discord(title, message, emoji)
        
        # Log resultado
        success_count = sum(1 for v in results.values() if v)
        total_count = len(results)
        
        if success_count == total_count:
            logger.info(f"Notificación enviada: {title} ({success_count}/{total_count} canales)")
        else:
            logger.warning(f"Notificación parcial: {title} ({success_count}/{total_count} canales)")
        
        return results


# Instancia global
notify = NotificationService()
