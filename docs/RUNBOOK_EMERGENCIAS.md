# 🚨 Runbook: Procedimientos de Emergencia CrediNet

**Para**: Administradores del sistema  
**Última actualización**: 23 de enero de 2026

---

## 📞 Información de Contactos

| Rol | Nombre | Contacto |
|-----|--------|----------|
| **Desarrollador Principal** | Jair | [Agregar] |
| **Administrador Backup** | [Agregar] | [Agregar] |
| **Soporte Técnico LAN** | [Agregar] | [Agregar] |

---

## 🔍 Diagnóstico Rápido

### ¿El sistema está caído?

```bash
# Verificar servicios Docker
docker compose ps

# Todos deben mostrar "Up" y "healthy"
# Si alguno dice "Exited" o "Unhealthy", ver sección correspondiente abajo
```

---

## 🆘 ESCENARIO 1: Backend No Responde

### Síntomas:
- Frontend carga pero no puede hacer login
- API devuelve "Connection refused"
- Backend health check falla

### Diagnóstico:
```bash
# Ver si el contenedor está corriendo
docker compose ps backend

# Ver logs del backend (últimas 50 líneas)
docker compose logs backend --tail 50

# Verificar health endpoint
curl http://localhost:8000/health
```

### Solución Rápida:
```bash
# Reiniciar backend
docker compose restart backend

# Esperar 10-15 segundos
sleep 15

# Verificar que volvió
curl http://localhost:8000/health
# Debe devolver: {"status":"healthy","version":"2.0.0"}
```

### Si sigue sin funcionar:
```bash
# Ver logs completos
docker compose logs backend | tail -100

# Buscar errores comunes:
# - "Connection refused" → PostgreSQL no responde
# - "ModuleNotFoundError" → Falta dependencia
# - "Port already in use" → Otro proceso usa el puerto 8000

# Rebuild completo
docker compose build backend
docker compose up -d backend
```

---

## 🆘 ESCENARIO 2: Frontend No Carga

### Síntomas:
- Navegador muestra "Connection refused" o página en blanco
- `http://10.5.26.141:5173` no responde

### Diagnóstico:
```bash
# Ver si está corriendo
docker compose ps frontend

# Ver logs
docker compose logs frontend --tail 50
```

### Solución Rápida:
```bash
# Reiniciar frontend
docker compose restart frontend

# Verificar
curl http://localhost:5173
```

### Si muestra "localhost:8000" en vez de la IP correcta:
```bash
# Rebuild con variables correctas
cd /home/jair/proyectos/credinet-v2
./scripts/rebuild-frontend.sh
```

---

## 🆘 ESCENARIO 3: Base de Datos No Responde

### Síntomas:
- Backend logs muestran "connection to server failed"
- Backend dice "database unavailable"

### Diagnóstico:
```bash
# Ver estado de PostgreSQL
docker compose ps postgres

# Ver logs
docker compose logs postgres --tail 50

# Verificar conectividad
docker compose exec postgres pg_isready -U credinet_user
# Debe devolver: "accepting connections"
```

### Solución Rápida:
```bash
# Reiniciar PostgreSQL (CUIDADO: puede tomar 30s-1min)
docker compose restart postgres

# Esperar a que esté listo
sleep 30

# Verificar
docker compose exec postgres pg_isready -U credinet_user
```

### ⚠️ Si PostgreSQL no inicia:

**CUIDADO**: Posible corrupción de datos

```bash
# Ver logs para identificar el error
docker compose logs postgres | grep -i error

# Errores comunes:
# - "data directory has wrong ownership" → Permisos incorrectos
# - "could not create shared memory" → Falta memoria
# - "database system was not properly shut down" → Crash anterior

# Si dice "was not properly shut down":
docker compose down postgres
docker compose up -d postgres
# PostgreSQL hará recovery automático
```

### 🔴 CRÍTICO: Si hay corrupción de datos:

```bash
# 1. DETENER TODO
docker compose down

# 2. RESTAURAR ÚLTIMO BACKUP
cd /home/jair/proyectos/credinet-v2

# Ver backups disponibles
ls -lht backups/

# Restaurar el más reciente
gunzip -c backups/backup_YYYYMMDD_HHMMSS.sql.gz | \
    docker compose exec -T postgres psql -U credinet_user -d credinet_db

# 3. Reiniciar servicios
docker compose up -d

# 4. DOCUMENTAR en logs/incidents.log qué pasó
```

---

## 🆘 ESCENARIO 4: Deployment Falló

### Síntomas:
- Después de `git pull` el sistema no funciona
- Cambios se aplicaron pero hay errores

### Solución: Rollback Automático

```bash
cd /home/jair/proyectos/credinet-v2

# Ver último commit
git log -1

# Rollback con script
./scripts/deploy.sh --rollback

# El script automáticamente:
# 1. Vuelve al commit anterior
# 2. Rebuild de servicios
# 3. Ofrece restaurar backup de BD
```

### Rollback Manual (si el script falla):

```bash
# 1. Ver commit anterior
git log --oneline -5

# 2. Volver a ese commit (reemplaza COMMIT_ID)
git reset --hard COMMIT_ID

# 3. Rebuild
docker compose build
docker compose up -d

# 4. Restaurar BD (si hubo cambios en schema)
gunzip -c backups/backup_latest.sql.gz | \
    docker compose exec -T postgres psql -U credinet_user -d credinet_db
```

---

## 🆘 ESCENARIO 5: Servidor Sin Espacio en Disco

### Síntomas:
- Docker no puede iniciar contenedores
- Error: "no space left on device"

### Diagnóstico:
```bash
# Ver espacio disponible
df -h

# Ver tamaño de Docker
docker system df
```

### Solución:

```bash
# Limpiar contenedores detenidos
docker container prune -f

# Limpiar imágenes no usadas
docker image prune -a -f

# Limpiar volúmenes huérfanos (CUIDADO: no borra volúmenes externos)
docker volume prune -f

# Limpiar build cache
docker builder prune -a -f

# Limpiar logs de Docker
sudo sh -c 'truncate -s 0 /var/lib/docker/containers/*/*-json.log'

# Limpiar backups antiguos manualmente
cd /home/jair/proyectos/credinet-v2/backups
ls -lht
# Eliminar manualmente los más antiguos si es necesario
```

---

## 🆘 ESCENARIO 6: Scheduler No Ejecutó el Corte

### Síntomas:
- Hoy es día 8 o 23 pero el corte no se ejecutó
- Períodos no cambiaron de estado

### Diagnóstico:
```bash
# Verificar estado del scheduler
curl http://localhost:8000/api/v1/scheduler/status | jq '.'

# Ver si el job está configurado
# Debe mostrar: "running": true, "jobs_count": 1

# Ver logs de ejecución
docker compose logs backend | grep "auto_cut" | tail -20
```

### Solución: Ejecutar Corte Manual

```bash
# Ejecutar corte forzado (ignora validación de día)
curl -X POST "http://localhost:8000/api/v1/scheduler/run-cut-now?force=true"

# Verificar resultado en logs
docker compose logs backend --tail 50 | grep "auto_cut"
```

### Si el scheduler está detenido:

```bash
# Reiniciar backend (recarga el scheduler)
docker compose restart backend

# Verificar que se inició
curl http://localhost:8000/api/v1/scheduler/status
```

---

## 🆘 ESCENARIO 7: No Puedo Acceder por SSH

### Síntomas:
- `ssh jair@10.5.26.141` da timeout o "Connection refused"

### Diagnóstico:

**Opción 1: Si estás en la LAN física**:
```bash
# Probar acceso por IP local (no ZeroTier)
ssh jair@10.0.0.19
```

**Opción 2: Verificar ZeroTier**:
```bash
# En tu PC, verificar conexión ZeroTier
zerotier-cli status
zerotier-cli listnetworks

# Debe mostrar: ONLINE

# Ping al servidor
ping 10.5.26.141
```

### Solución:

1. **Si ZeroTier está OFFLINE**: Reconectar
   ```bash
   # Windows: Reiniciar servicio ZeroTier desde Services
   # Linux/Mac:
   sudo zerotier-cli leave NETWORK_ID
   sudo zerotier-cli join NETWORK_ID
   ```

2. **Si es problema de SSH**: Acceso físico al servidor
   - Conectar monitor/teclado al servidor
   - Login local: `jair` + contraseña
   - Verificar SSH: `sudo systemctl status ssh`
   - Reiniciar SSH: `sudo systemctl restart ssh`

---

## 📊 Verificación Post-Incidente

Después de resolver cualquier incidente, ejecutar este checklist:

```bash
# 1. Verificar servicios corriendo
docker compose ps
# Todos deben estar "Up" y "healthy"

# 2. Verificar backend
curl http://localhost:8000/health

# 3. Verificar frontend
curl http://localhost:5173

# 4. Verificar scheduler
curl http://localhost:8000/api/v1/scheduler/status

# 5. Login en el navegador
# http://10.5.26.141:5173
# Probar login con usuario de prueba

# 6. Crear backup post-incidente
cd /home/jair/proyectos/credinet-v2
./scripts/backup-db.sh

# 7. DOCUMENTAR en logs/incidents.log
echo "$(date): [INCIDENTE] Descripción breve del problema y solución" >> logs/incidents.log
```

---

## 📝 Template de Reporte de Incidente

```markdown
# Incidente: [TÍTULO]
**Fecha**: YYYY-MM-DD HH:MM
**Reportado por**: [Nombre]
**Severidad**: [Crítico/Alto/Medio/Bajo]

## Síntomas Observados:
- [Describir qué falló]

## Diagnóstico:
- [Qué encontraste al investigar]

## Solución Aplicada:
- [Qué pasos seguiste]

## Tiempo de Resolución:
- [Minutos/horas]

## Datos Perdidos:
- [Sí/No - describir si aplicable]

## Backup Restaurado:
- [Sí/No - cuál backup]

## Prevención Futura:
- [Qué cambiar para evitar que vuelva a pasar]

## Lecciones Aprendidas:
- [Qué aprendiste del incidente]
```

Guardar en: `logs/incidents.log`

---

## 🔍 Comandos Útiles para Diagnóstico

```bash
# Ver todos los contenedores
docker compose ps

# Ver logs de todos los servicios
docker compose logs --tail 100

# Ver logs en tiempo real
docker compose logs -f

# Ver uso de recursos
docker stats

# Ver espacio en disco
df -h

# Ver tamaño de volúmenes Docker
docker system df -v

# Inspeccionar contenedor específico
docker inspect credinet-backend

# Entrar a un contenedor
docker compose exec backend bash
docker compose exec postgres bash
docker compose exec frontend sh

# Ver variables de entorno de un contenedor
docker compose exec backend env

# Ver red de Docker
docker network ls
docker network inspect credinet-network

# Ver procesos en un contenedor
docker compose exec backend ps aux
```

---

## 📞 Escalación

**Nivel 1**: Intentar soluciones de este runbook (15-30 min)

**Nivel 2**: Si no se resuelve, contactar a:
- Desarrollador principal: [Agregar contacto]
- Documentar todo lo que intentaste

**Nivel 3**: Si es CRÍTICO y no hay respuesta:
1. Hacer backup inmediato: `./scripts/backup-db.sh`
2. Apagar servicios si hay riesgo de corrupción: `docker compose down`
3. Esperar a desarrollador antes de reiniciar

---

## 🎓 Referencias Rápidas

| Documento | Propósito |
|-----------|-----------|
| `docs/RESUMEN_PLAN_ACCION.md` | Plan de mejoras y acción |
| `docs/ANALISIS_PRODUCCION_Y_MEJORAS.md` | Análisis completo del entorno |
| `docs/GUIA_NGINX_REVERSE_PROXY.md` | Configurar URL limpia |
| `scripts/deploy.sh --help` | Ayuda del script de deploy |
| `scripts/backup-db.sh --help` | Ayuda del script de backup |

---

**Este runbook debe actualizarse cada vez que se resuelve un nuevo incidente.**
