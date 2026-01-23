"""
Notification Routes - Endpoints para el sistema de notificaciones.
Permite verificar estado y enviar notificaciones de prueba.
"""
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from typing import Optional, Literal
import os

from app.modules.auth.routes import get_current_user
from app.core.notifications import notify

router = APIRouter(prefix="/notifications", tags=["Notifications"])


class NotificationStatus(BaseModel):
    """Estado de los canales de notificación."""
    telegram: dict
    discord: dict
    email: dict


class TestNotificationRequest(BaseModel):
    """Request para enviar notificación de prueba."""
    channel: Literal["telegram", "discord", "all"]
    title: Optional[str] = "🧪 Test desde UI"
    message: Optional[str] = "Notificación de prueba enviada desde la interfaz web."


class TestNotificationResponse(BaseModel):
    """Response de notificación de prueba."""
    success: bool
    channel: str
    message: str
    details: Optional[dict] = None


@router.get(
    "/status",
    response_model=NotificationStatus,
    summary="Estado de canales de notificación",
    description="Verifica el estado de configuración de cada canal."
)
async def get_notification_status(
    current_user: dict = Depends(get_current_user)
):
    """
    Obtiene el estado de configuración de los canales de notificación.
    
    Verifica si las variables de entorno necesarias están configuradas.
    """
    telegram_token = os.getenv("TELEGRAM_BOT_TOKEN", "")
    telegram_chat = os.getenv("TELEGRAM_CHAT_ID", "")
    telegram_group = os.getenv("TELEGRAM_GROUP_ID", "")
    discord_webhook = os.getenv("DISCORD_WEBHOOK_URL", "")
    
    return NotificationStatus(
        telegram={
            "configured": bool(telegram_token and (telegram_chat or telegram_group)),
            "has_personal": bool(telegram_chat),
            "has_group": bool(telegram_group),
            "bot_configured": bool(telegram_token)
        },
        discord={
            "configured": bool(discord_webhook),
            "webhook_configured": bool(discord_webhook)
        },
        email={
            "configured": False,
            "smtp_configured": False
        }
    )


@router.post(
    "/test",
    response_model=TestNotificationResponse,
    summary="Enviar notificación de prueba",
    description="Envía una notificación de prueba al canal especificado."
)
async def send_test_notification(
    request: TestNotificationRequest,
    current_user: dict = Depends(get_current_user)
):
    """
    Envía una notificación de prueba para verificar la configuración.
    
    **Canales disponibles:**
    - telegram: Envía a Telegram (personal + grupo)
    - discord: Envía a Discord webhook
    - all: Envía a todos los canales configurados
    """
    username = current_user.username if hasattr(current_user, 'username') else 'Admin'
    
    message = f"{request.message}\n\n👤 Enviado por: {username}"
    
    try:
        if request.channel == "telegram":
            result = await notify.send(
                title=request.title,
                message=message,
                level="info",
                to_personal=True,
                to_group=True,
                to_discord=False
            )
        elif request.channel == "discord":
            result = await notify.send(
                title=request.title,
                message=message,
                level="info",
                to_personal=False,
                to_group=False,
                to_discord=True
            )
        else:  # all
            result = await notify.send(
                title=request.title,
                message=message,
                level="info",
                to_personal=True,
                to_group=True,
                to_discord=True
            )
        
        success = any([
            result.get("telegram_personal"),
            result.get("telegram_group"),
            result.get("discord")
        ])
        
        return TestNotificationResponse(
            success=success,
            channel=request.channel,
            message="Notificación enviada correctamente" if success else "Error al enviar notificación",
            details=result
        )
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error enviando notificación: {str(e)}"
        )


@router.get(
    "/health",
    summary="Health check de notificaciones",
    description="Verifica rápidamente si los servicios están disponibles."
)
async def notification_health():
    """
    Health check rápido para verificar si los canales están configurados.
    Útil para el indicador LED en la UI.
    """
    telegram_token = os.getenv("TELEGRAM_BOT_TOKEN", "")
    telegram_group = os.getenv("TELEGRAM_GROUP_ID", "")
    discord_webhook = os.getenv("DISCORD_WEBHOOK_URL", "")
    
    return {
        "telegram": "ok" if (telegram_token and telegram_group) else "not_configured",
        "discord": "ok" if discord_webhook else "not_configured",
        "email": "not_configured"
    }
