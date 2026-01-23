# 🔄 CONTEXTO DE SINCRONIZACIÓN: Producción ↔ Desarrollo
## Fecha de última actualización: 23 de Enero 2026

---

## 📍 SITUACIÓN ACTUAL

### Entorno de Producción (10.5.26.141 / credicuenta3)
- **Rama activa**: `main`
- **Último commit**: `1a94d4c` - docs + scripts de automatización
- **Estado Docker**: ✅ Corriendo (backend, frontend, postgres)
- **Datos reales**: 4 usuarios, 3 préstamos, 33 pagos

### Este documento es para: Entorno de Desarrollo (192.168.98.98)
Cuando hagas `git pull origin develop` en el entorno dev, este documento te dará todo el contexto necesario.

---

## ✅ COMPLETADO EN PRODUCCIÓN (23 Ene 2026)

### 1. Incidente Crítico Resuelto
- **Problema**: Scheduler ejecutó corte de período 6 horas antes (UTC vs CST)
- **Causa**: `CronTrigger` sin timezone explícito
- **Fix**: `timezone="America/Mexico_City"` en `scheduler/jobs.py:25`
- **Estado**: ✅ Verificado, próximo cron: 8 Feb 2026 00:05 CST

### 2. Automatización de Backups
- **Script**: `scripts/backup-db.sh` (comprime con gzip, retención 30 días)
- **Crontab**: Diario a las 2:00 AM
- **Ubicación**: `/home/jair/proyectos/credinet-v2/backups/`
- **Estado**: ✅ Funcionando

### 3. Script de Deployment
- **Script**: `scripts/deploy.sh`
- **Features**: Detección de cambios, backup pre-deploy, rollback automático
- **Uso**: `./scripts/deploy.sh [--backup|--rollback|--help]`

### 4. Sistema de Notificaciones
- **Canales configurados**:
  - ✅ Telegram (chat personal + grupo)
  - ✅ Discord (webhook)
- **Test**: `./scripts/test-notifications.sh`
- **Estado**: ✅ Funcionando

### 5. Protección de Entorno
- **Script**: `scripts/safe-docker.sh`
- **Propósito**: Bloquear comandos Docker si no estás en rama `main`
- **Uso**: `./scripts/safe-docker.sh up -d` (en lugar de `docker compose up -d`)

---

## 🎯 FEATURES PENDIENTES (Para desarrollar)

### Prioridad ALTA

#### Feature 1: Backups Externos a Google Drive
**Branch sugerido**: `feature/external-backups`
```
Objetivo: Sync de backups locales a Google Drive (protección ante desastre de hardware)
Herramienta: rclone (gratuito)
Integración: Después del backup diario (2:30 AM)
```

#### Feature 2: Integración de Notificaciones en Backend
**Branch sugerido**: `feature/notifications-backend`
```
Los webhooks ya funcionan (test-notifications.sh lo prueba)
Falta integrar con:
- Scheduler (notificar después de corte)
- Backup script (notificar éxito/fallo)
- Backend (login/logout, préstamos aprobados, pagos)
```

**Estructura propuesta**:
```
backend/app/modules/notifications/
├── domain/
│   ├── entities.py
│   └── events.py
├── application/
│   └── notification_service.py
├── infrastructure/
│   ├── telegram_notifier.py
│   ├── discord_notifier.py
│   └── email_notifier.py
└── api/
    └── routes.py
```

**Eventos a implementar**:
```python
# Críticos (notificación inmediata)
- scheduler_executed
- backup_completed / backup_failed
- service_down
- error_500

# Audit log
- user_login / user_logout
- loan_approved
- payment_registered
```

### Prioridad MEDIA

#### Feature 3: Monitoreo con Grafana
**Branch sugerido**: `feature/monitoring`
```
Recursos del servidor: 11GB RAM, 10 cores, 136GB disco
Grafana + Prometheus: ~300MB RAM (viable)
docker-compose.monitoring.yml separado
```

### Prioridad BAJA (Postergar)

#### Feature 4: Migración de Datos Legacy
```
Sistema origen: MySQL/MariaDB (credicuenta)
Dump disponible: credicuenta202512190600.sql (dic 2025)
Estado: Datos muy sucios, requiere limpieza manual
Decisión: Postergar hasta tener backups externos funcionando
⚠️ NO subir SQL a Git (datos sensibles)
```

---

## 🔒 SECRETOS (NO COMMITEAR)

Los siguientes valores están en `.env` de producción:

```bash
# Telegram
TELEGRAM_BOT_TOKEN=8286731995:AAG...  # Parcialmente oculto
TELEGRAM_CHAT_ID=1253289974
TELEGRAM_GROUP_ID=-5047597917

# Discord
DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/...  # Parcialmente oculto
```

**Para desarrollo**: Copia estos valores del archivo `.env` de producción o solicita al administrador.

---

## 📋 WORKFLOW DE DESARROLLO

### En este entorno (192.168.98.98)

```bash
# 1. Sincronizar con producción
git checkout develop
git pull origin develop
git merge main  # Traer cambios de prod (docs, scripts)

# 2. Crear feature branch
git checkout -b feature/notifications-backend

# 3. Desarrollar normalmente
docker compose up backend frontend  # ✅ Aquí SÍ puedes usar Docker
pytest backend/tests/

# 4. Commit y push
git add .
git commit -m "feat: Add notification service"
git push origin feature/notifications-backend

# 5. PR en GitHub: feature → develop

# 6. Cuando esté listo para producción
git checkout develop
git merge feature/notifications-backend
git push origin develop
```

### Para deploy en producción (10.5.26.141)

```bash
# En el servidor de producción
git checkout main
git merge develop
git push origin main
./scripts/deploy.sh
```

---

## ⚠️ REGLAS CRÍTICAS

### En Producción (10.5.26.141)
1. **Docker solo en main**: Usar `./scripts/safe-docker.sh` como wrapper
2. **No editar datos directamente**: Siempre usar la UI o scripts verificados
3. **Backup antes de deploy**: `./scripts/backup-db.sh`
4. **Verificar rama**: `git branch` antes de cualquier acción

### En Desarrollo (192.168.98.98)
1. **Sync frecuente**: `git pull` antes de empezar a trabajar
2. **Feature branches**: No trabajar directo en develop
3. **Tests**: Ejecutar antes de merge
4. **No subir secretos**: Verificar que `.env` esté en `.gitignore`

---

## 📊 DIFERENCIAS ENTRE RAMAS (al 23 Ene 2026)

| Archivo | main | develop | Notas |
|---------|------|---------|-------|
| scripts/deploy.sh | ✅ | ❌ | Merge pendiente |
| scripts/backup-db.sh | ✅ | ❌ | Merge pendiente |
| scripts/safe-docker.sh | ✅ | ❌ | Merge pendiente |
| scripts/test-notifications.sh | ✅ | ❌ | Merge pendiente |
| docs/ANALISIS_PRODUCCION*.md | ✅ | ❌ | Merge pendiente |
| docs/RUNBOOK*.md | ✅ | ❌ | Merge pendiente |
| .env (notificaciones) | ✅ | ❌ | Copiar manualmente |

**Acción requerida**: Merge main → develop para sincronizar.

---

## 🔗 RECURSOS

### Documentación
- [ANALISIS_PRODUCCION_Y_MEJORAS.md](docs/ANALISIS_PRODUCCION_Y_MEJORAS.md)
- [RUNBOOK_EMERGENCIAS.md](docs/RUNBOOK_EMERGENCIAS.md)
- [GUIA_NGINX_REVERSE_PROXY.md](docs/GUIA_NGINX_REVERSE_PROXY.md)

### Scripts
- `scripts/deploy.sh` - Deployment automatizado
- `scripts/backup-db.sh` - Backup de PostgreSQL
- `scripts/safe-docker.sh` - Wrapper de Docker seguro
- `scripts/test-notifications.sh` - Prueba de notificaciones

### APIs de Notificación
- [Telegram Bot API](https://core.telegram.org/bots/api)
- [Discord Webhooks](https://discord.com/developers/docs/resources/webhook)
- [rclone Google Drive](https://rclone.org/drive/)

---

## 💬 CONTACTO

- **Producción problemas**: Revisar logs con `docker compose logs -f backend`
- **Rollback**: `./scripts/deploy.sh --rollback`
- **Emergencias**: Ver [RUNBOOK_EMERGENCIAS.md](docs/RUNBOOK_EMERGENCIAS.md)

---

*Este documento fue generado por GitHub Copilot el 23 de Enero de 2026*
*Actualizar después de cada merge significativo*
