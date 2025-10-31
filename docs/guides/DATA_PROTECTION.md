# 🛡️ GUÍA DE PROTECCIÓN DE DATOS - CrediNet v2.0

## ⚠️ ADVERTENCIA CRÍTICA

**NUNCA ejecutes `docker-compose down -v` sin hacer backup primero.**

Este comando **ELIMINA PERMANENTEMENTE**:
- ❌ Base de datos completa (usuarios, préstamos, pagos, etc.)
- ❌ Archivos subidos (documentos, imágenes)
- ❌ Logs del sistema

---

## 🔒 Scripts de Protección Implementados

### 1. Backup Manual

Crea respaldo completo de la base de datos:

```bash
./scripts/database/backup_db.sh [nombre_opcional]
```

**Ejemplo:**
```bash
# Backup con nombre automático (timestamp)
./scripts/database/backup_db.sh

# Backup con nombre personalizado
./scripts/database/backup_db.sh antes_de_migracion
```

**Salida:**
```
✅ Backup completado exitosamente!
📁 Archivo: ./db/backups/backup_20251031_001329.sql.gz
📊 Tamaño: 36K
```

---

### 2. Restaurar Backup

Restaura base de datos desde un backup:

```bash
./scripts/database/restore_db.sh <nombre_backup>
```

**Ejemplo:**
```bash
# Ver backups disponibles
ls -lht db/backups/

# Restaurar backup específico
./scripts/database/restore_db.sh backup_20251031_001329

# Restaurar sin confirmación (automatización)
./scripts/database/restore_db.sh backup_20251031_001329 --yes
```

**⚠️ ADVERTENCIA:** Esta operación ELIMINA todos los datos actuales.

---

### 3. Safe Down (Down Seguro) ⭐ RECOMENDADO

Detiene Docker Compose **CON BACKUP AUTOMÁTICO**:

```bash
./scripts/docker/safe_down.sh [opciones]
```

**Opciones:**
- `--volumes` o `-v`: Eliminar volúmenes (requiere confirmación)
- `--force` o `-f`: Forzar sin confirmación
- `--no-backup`: NO crear backup (¡PELIGROSO!)

**Ejemplos:**

```bash
# 1. Down normal (conserva volúmenes, hace backup automático)
./scripts/docker/safe_down.sh

# 2. Down CON eliminación de volúmenes (requiere confirmación)
./scripts/docker/safe_down.sh --volumes

# 3. Down forzado sin confirmación (automatización)
./scripts/docker/safe_down.sh --force

# 4. Down CON eliminación de volúmenes forzado
./scripts/docker/safe_down.sh --volumes --force

# 5. Down sin backup (¡NO RECOMENDADO!)
./scripts/docker/safe_down.sh --no-backup
```

**Flujo de Safe Down:**
1. ✅ Crea backup automático
2. ✅ Detiene contenedores
3. ✅ (Opcional) Elimina volúmenes con confirmación

---

## 📂 Ubicación de Backups

```
db/
├── backups/
│   ├── backup_20251031_001329.sql.gz    # Backup automático
│   ├── antes_de_migracion.sql.gz        # Backup manual
│   └── auto_backup_20251031_002245.sql.gz  # Safe down automático
```

**Tamaño típico:** 30-50 KB (comprimido con gzip)

---

## 🔄 Workflows Recomendados

### Desarrollo Diario

```bash
# Iniciar
docker-compose up -d

# Trabajar...

# Detener (conserva datos)
./scripts/docker/safe_down.sh
```

### Antes de Cambios Grandes

```bash
# 1. Crear backup manual
./scripts/database/backup_db.sh antes_de_sprint_6

# 2. Hacer cambios (migraciones, etc.)
# ...

# 3. Si algo sale mal, restaurar
./scripts/database/restore_db.sh antes_de_sprint_6
```

### Limpieza Total (Reset Completo)

```bash
# 1. Backup automático + eliminar volúmenes
./scripts/docker/safe_down.sh --volumes

# 2. Reiniciar desde cero
docker-compose up -d

# 3. (Opcional) Restaurar datos antiguos
./scripts/database/restore_db.sh auto_backup_20251031_002245
```

---

## 🚨 Situaciones de Emergencia

### "Borré los volúmenes por accidente"

```bash
# 1. Verificar backups disponibles
ls -lht db/backups/

# 2. Iniciar PostgreSQL
docker-compose up -d postgres

# 3. Esperar que PostgreSQL esté listo
docker-compose logs -f postgres
# (Ctrl+C cuando veas "database system is ready to accept connections")

# 4. Restaurar último backup
./scripts/database/restore_db.sh <nombre_backup_mas_reciente>

# 5. Reiniciar backend
docker-compose restart backend
```

### "La base de datos está corrupta"

```bash
# 1. Detener todo
docker-compose down

# 2. Eliminar volúmenes corruptos
docker volume rm credinet-postgres-data

# 3. Iniciar PostgreSQL
docker-compose up -d postgres

# 4. Restaurar backup
./scripts/database/restore_db.sh <backup_conocido_bueno>

# 5. Iniciar todo
docker-compose up -d
```

---

## 📊 Volúmenes de Docker

| Volumen | Contenido | Crítico | Tamaño Aprox |
|---------|-----------|---------|--------------|
| `credinet-postgres-data` | Base de datos completa | ⚠️ **CRÍTICO** | 50-200 MB |
| `credinet-backend-uploads` | Archivos subidos | ⚠️ **IMPORTANTE** | Variable |
| `credinet-backend-logs` | Logs del sistema | ℹ️ Regenerable | 10-50 MB |

**Comandos útiles:**
```bash
# Ver volúmenes
docker volume ls | grep credinet

# Ver tamaño de volúmenes
docker system df -v | grep credinet

# Inspeccionar volumen
docker volume inspect credinet-postgres-data
```

---

## ⚙️ Configuración de Backups Automáticos

### Opción 1: Cron Job (Linux)

```bash
# Editar crontab
crontab -e

# Agregar backup diario a las 2 AM
0 2 * * * cd /home/credicuenta/proyectos/credinet && ./scripts/database/backup_db.sh auto_daily_$(date +\%Y\%m\%d)

# Agregar backup cada 6 horas
0 */6 * * * cd /home/credicuenta/proyectos/credinet && ./scripts/database/backup_db.sh auto_6h_$(date +\%Y\%m\%d_\%H\%M)
```

### Opción 2: Systemd Timer (Linux)

```bash
# Crear timer en /etc/systemd/system/credinet-backup.timer
[Unit]
Description=CrediNet Daily Backup Timer

[Timer]
OnCalendar=daily
OnCalendar=02:00
Persistent=true

[Install]
WantedBy=timers.target

# Habilitar
sudo systemctl enable credinet-backup.timer
sudo systemctl start credinet-backup.timer
```

---

## 🧹 Limpieza de Backups Antiguos

```bash
# Eliminar backups mayores a 30 días
find db/backups/ -name "*.sql.gz" -mtime +30 -delete

# Mantener solo los últimos 10 backups
cd db/backups/ && ls -t *.sql.gz | tail -n +11 | xargs rm -f
```

---

## 📝 Buenas Prácticas

✅ **HACER:**
- Usar `./scripts/docker/safe_down.sh` en lugar de `docker-compose down`
- Crear backup manual antes de migraciones grandes
- Verificar que existe el backup antes de operaciones destructivas
- Mantener al menos 7 días de backups
- Probar restauración periódicamente

❌ **NO HACER:**
- Ejecutar `docker-compose down -v` directamente
- Confiar en que "no pasará nada malo"
- Borrar backups sin verificar antes
- Modificar scripts de backup sin probarlos

---

## 🎯 Resumen

**Comandos que debes recordar:**

```bash
# Backup manual
./scripts/database/backup_db.sh

# Down seguro (conserva datos)
./scripts/docker/safe_down.sh

# Down con limpieza total
./scripts/docker/safe_down.sh --volumes

# Restaurar
./scripts/database/restore_db.sh <nombre_backup>
```

**Regla de oro:** 
> "Si vas a ejecutar algo que empiece con `docker-compose down`, primero ejecuta `./scripts/database/backup_db.sh`"

---

## 📞 Soporte

Si tienes problemas:
1. Verifica logs: `docker-compose logs -f postgres`
2. Lista backups: `ls -lht db/backups/`
3. Verifica volúmenes: `docker volume ls | grep credinet`
4. Consulta este documento

**Última actualización:** 31 octubre 2025  
**Versión:** 2.0
