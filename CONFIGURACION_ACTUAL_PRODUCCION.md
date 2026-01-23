# ⚠️ IMPORTANTE: Configuración Actual de Producción

**Última actualización**: 23 de enero de 2026, 00:54 CST

---

## 🔒 BACKUPS AUTOMÁTICOS CONFIGURADOS

✅ **Crontab activo** - Backup diario a las 2:00 AM
- Script: `/home/jair/proyectos/credinet-v2/scripts/backup-db.sh`
- Log: `/home/jair/proyectos/credinet-v2/logs/backups.log`
- Backups: `/home/jair/proyectos/credinet-v2/backups/`
- Retención: 30 días

**Ver configuración**:
```bash
crontab -l
```

**Ver últimos backups**:
```bash
./scripts/backup-db.sh --stats
```

---

## 🌐 CONFIGURACIÓN DE RED ACTUAL

**NO estás usando Nginx** - Acceso directo a puertos Docker:

| Servicio | Puerto | Acceso LAN | Acceso ZeroTier |
|----------|--------|------------|-----------------|
| Frontend | 5173 | `http://10.0.0.19:5173` | `http://10.5.26.141:5173` |
| Backend | 8000 | `http://10.0.0.19:8000` | `http://10.5.26.141:8000` |
| PostgreSQL | 5432 | `10.0.0.19:5432` | `10.5.26.141:5432` |

**Variables de entorno actuales** (.env):
```bash
VITE_API_URL=http://10.5.26.141:8000
```

---

## ✅ PROBLEMA DE "localhost" CORREGIDO

**Fix aplicado** (commit d684b6f):
- ✅ `docker-compose.yml`: Agregado `build.args` con VITE_API_URL
- ✅ `frontend-mvp/Dockerfile`: Agregado ARG/ENV para variables
- ✅ `scripts/rebuild-frontend.sh`: Lee .env y pasa variables

**Cómo prevenir que vuelva a pasar**:
```bash
# ✅ USAR SIEMPRE:
./scripts/deploy.sh          # Para deployments completos
./scripts/rebuild-frontend.sh  # Para rebuild solo frontend

# ❌ NO USAR (omite variables):
docker compose build frontend
docker compose up --build
```

**Verificar si el bundle tiene la URL correcta**:
```bash
docker compose exec frontend sh -c "cat /app/dist/assets/index-*.js | grep -oE 'http://[^\"]+:8000' | head -1"
# Debe mostrar: http://10.5.26.141:8000
```

---

## 🚀 PROCESO DE DEPLOYMENT CORRECTO

**Flujo recomendado** (desde develop → main):

```bash
# 1. SSH al servidor
ssh jair@10.5.26.141

# 2. Ir al proyecto
cd /home/jair/proyectos/credinet-v2

# 3. Usar el script de deploy
./scripts/deploy.sh

# Automáticamente:
# - Detecta qué cambió (backend/frontend/db)
# - Hace backup si hay cambios en BD
# - Rebuild solo lo necesario
# - Verifica health
# - Rollback si falla
```

**Logs de deployments**: `logs/deployments.log`

---

## 📋 DNS/NGINX - PENDIENTE (NO URGENTE)

**Estado**: NO implementado (no es crítico)

**Cuándo implementar**:
- ✅ Cuando tengas aprobación del admin de LAN
- ✅ Cuando haya momento de bajo uso
- ✅ Con tiempo para probar sin presión

**Qué solicitar al admin de LAN**:
```
Solicito: Agregar registro DNS en el router/servidor DNS
- Dominio: credicuenta.local
- IP destino: 10.0.0.19
- Objetivo: Acceso unificado para todos los PCs de la LAN
```

**NO implementar ahora porque**:
- Sistema actual funciona perfecto con ZeroTier
- Evita riesgo innecesario en producción
- Es mejora cosmética, no funcional

---

## ⚠️ REGLAS CRÍTICAS

### 1. SIEMPRE hacer backup antes de cambios importantes:
```bash
./scripts/backup-db.sh
```

### 2. USAR los scripts para deploy:
```bash
./scripts/deploy.sh  # Deploy completo con protecciones
```

### 3. NO tocar directamente:
- ❌ Volúmenes Docker manualmente
- ❌ Base de datos en caliente (sin backup)
- ❌ Archivos de configuración sin commitear

### 4. SI algo falla durante deploy:
```bash
./scripts/deploy.sh --rollback  # Vuelve al estado anterior
```

---

## 📊 COMANDOS DE VERIFICACIÓN RÁPIDA

```bash
# Estado de servicios
docker compose ps

# Health del backend
curl http://localhost:8000/health

# Ver scheduler
curl http://localhost:8000/api/v1/scheduler/status | jq '.'

# Ver logs
docker compose logs backend --tail 50
docker compose logs frontend --tail 50

# Ver backups
./scripts/backup-db.sh --stats

# Ver crontab
crontab -l
```

---

## 🆘 EN CASO DE EMERGENCIA

**Ver**: `docs/RUNBOOK_EMERGENCIAS.md`

**Contactos**:
- Desarrollador: Jair (agregar contacto)
- Soporte LAN: (agregar contacto)

---

## 📝 PRÓXIMOS PASOS OPCIONALES

**NO urgentes, solo cuando tengas tiempo**:

1. **DNS + Nginx** (mejora cosmética)
   - Requiere aprobación admin LAN
   - Guía: `docs/GUIA_NGINX_REVERSE_PROXY.md`
   - Tiempo: 1-2 horas

2. **Monitoreo** (opcional)
   - Uptime Kuma para alertas
   - Tiempo: 15 minutos

3. **HTTPS** (si tienes dominio)
   - Certificado autofirmado
   - Tiempo: 30 minutos

---

**Recuerda**: El sistema está funcionando correctamente. Solo son mejoras opcionales, no críticas.
