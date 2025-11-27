# 🔄 SISTEMA DE BACKUPS AUTOMÁTICOS CREDINET

## 📋 Resumen

Sistema de respaldo automático diario que:
- ✅ Crea 3 tipos de backups: **completo**, **catálogos**, **crítico**
- ✅ Mantiene últimos **3 backups** de cada tipo (borra antiguos)
- ✅ Comprime archivos (`.gz`) para ahorrar espacio
- ✅ Se ejecuta automáticamente cada día

---

## 📂 Ubicación de Backups

```
/home/credicuenta/proyectos/credinet-v2/db/backups/
├── backup_YYYY-MM-DD_HH-MM-SS.sql.gz      # Completo (usuarios, préstamos, pagos, TODO)
├── catalogs_YYYY-MM-DD_HH-MM-SS.sql.gz    # Solo catálogos (estados, tipos, niveles, etc.)
└── critical_YYYY-MM-DD_HH-MM-SS.sql.gz    # Crítico (users, cut_periods, config)
```

**Tamaños aproximados**:
- Completo: ~50KB comprimido (~400KB descomprimido)
- Catálogos: ~7KB comprimido (~44KB descomprimido)
- Crítico: ~5KB comprimido (~28KB descomprimido)

**Total espacio**: ~200KB por día × 3 backups × 3 tipos = **~1.8MB** (mínimo)

---

## 🚀 Scripts Disponibles

### 1. Backup Manual

```bash
cd /home/credicuenta/proyectos/credinet-v2
./scripts/database/backup_daily.sh
```

**Salida**:
```
╔═══════════════════════════════════════════════════════════╗
║         BACKUP DIARIO CREDINET DATABASE                  ║
╠═══════════════════════════════════════════════════════════╣
║  Fecha: 2025-11-06 02:16:17                              ║
╚═══════════════════════════════════════════════════════════╝

[1/5] Creando backup COMPLETO de la base de datos...
✅ Backup completo creado: backup_2025-11-06_02-16-17.sql (376K)

[2/5] Creando backup de CATÁLOGOS (prioridad alta)...
✅ Catálogos respaldados: catalogs_2025-11-06_02-16-17.sql (44K)

[3/5] Creando backup de DATOS CRÍTICOS...
✅ Datos críticos respaldados: critical_2025-11-06_02-16-17.sql (28K)

[4/5] Comprimiendo backups...
✅ Backups comprimidos (.gz)

[5/5] Limpiando backups antiguos (manteniendo últimos 3)...
✅ Limpieza completada

╔═══════════════════════════════════════════════════════════╗
║              BACKUP COMPLETADO EXITOSAMENTE              ║
╠═══════════════════════════════════════════════════════════╣
║  Backups totales:      9 archivos
║  Tamaño total:         1.2M
║  Ubicación:            /home/.../db/backups
╚═══════════════════════════════════════════════════════════╝
```

### 2. Restaurar Backup

**Ver backups disponibles**:
```bash
./scripts/database/restore_backup.sh
```

**Restaurar backup específico**:
```bash
# Por número (más fácil)
./scripts/database/restore_backup.sh 1

# Por nombre de archivo
./scripts/database/restore_backup.sh backup_2025-11-06_02-16-17.sql.gz

# Restaurar solo catálogos (más rápido)
./scripts/database/restore_backup.sh catalogs

# Restaurar solo datos críticos
./scripts/database/restore_backup.sh critical
```

**Salida**:
```
╔═══════════════════════════════════════════════════════════╗
║         RESTAURACIÓN DE BACKUP - CREDINET                ║
╚═══════════════════════════════════════════════════════════╝

Archivo seleccionado: backup_2025-11-06_02-16-17.sql.gz
Tamaño: 47K

⚠️  ADVERTENCIA: Esta operación sobrescribirá datos existentes
¿Desea continuar? (escriba 'SI' para confirmar): SI

[1/3] Descomprimiendo backup...
✅ Backup descomprimido
[2/3] Restaurando en base de datos...
✅ Restauración completada
[3/3] Limpiando archivos temporales...
✅ Limpieza completada

╔═══════════════════════════════════════════════════════════╗
║            RESTAURACIÓN COMPLETADA EXITOSAMENTE          ║
╚═══════════════════════════════════════════════════════════╝
```

---

## ⏰ Configurar Backup Automático (Cronjob)

### Opción 1: Cronjob Diario a las 2 AM

```bash
# Editar crontab
crontab -e

# Agregar esta línea
0 2 * * * /home/credicuenta/proyectos/credinet-v2/scripts/database/backup_daily.sh >> /home/credicuenta/proyectos/credinet-v2/logs/backup.log 2>&1
```

**Explicación**:
- `0 2 * * *`: Todos los días a las 2:00 AM
- `>> logs/backup.log`: Guarda log de ejecución
- `2>&1`: Captura errores también

### Opción 2: Cronjob Cada 12 Horas

```bash
# A las 2 AM y 2 PM
0 2,14 * * * /home/credicuenta/proyectos/credinet-v2/scripts/database/backup_daily.sh >> /home/credicuenta/proyectos/credinet-v2/logs/backup.log 2>&1
```

### Verificar Cronjob Configurado

```bash
# Listar cronjobs activos
crontab -l

# Ver logs de ejecución
tail -f /home/credicuenta/proyectos/credinet-v2/logs/backup.log
```

---

## 🔍 Verificar Backups

### Listar backups existentes

```bash
ls -lth /home/credicuenta/proyectos/credinet-v2/db/backups/
```

### Ver contenido de un backup (sin restaurar)

```bash
gunzip -c backup_2025-11-06_02-16-17.sql.gz | less
```

### Contar registros en backup

```bash
gunzip -c catalogs_2025-11-06_02-16-17.sql.gz | grep "INSERT INTO" | wc -l
```

---

## 📊 Tablas Incluidas en Cada Tipo

### Backup Completo (`backup_*.sql.gz`)
- ✅ **TODO**: Todas las tablas, funciones, triggers, índices, constraints

### Backup de Catálogos (`catalogs_*.sql.gz`)
```
roles
loan_statuses
payment_statuses
document_types
document_statuses
contract_statuses
cut_period_statuses
statement_statuses
payment_methods
associate_levels
level_change_types
config_types
rate_profiles
```

### Backup Crítico (`critical_*.sql.gz`)
```
users                    # Usuarios del sistema (admin, clientes, asociados)
user_roles              # Asignación de roles
cut_periods             # Periodos de corte (2024-2026)
system_configurations   # Configuración del sistema
```

---

## 🆘 Escenarios de Recuperación

### Escenario 1: Recuperar Solo Catálogos (Más Común)

**Problema**: Se borraron estados o tipos por error

```bash
# Restaurar solo catálogos (rápido, ~2 segundos)
./scripts/database/restore_backup.sh catalogs
```

### Escenario 2: Recuperar Usuarios y Config

**Problema**: Se borró un usuario o se modificó configuración

```bash
# Restaurar datos críticos
./scripts/database/restore_backup.sh critical
```

### Escenario 3: Desastre Total

**Problema**: Se borró volumen de Docker o se corrompió BD

```bash
# Restaurar backup completo más reciente
./scripts/database/restore_backup.sh 1
```

### Escenario 4: Volver a Estado Específico

**Problema**: Necesitas volver a estado de hace 2 días

```bash
# Ver backups disponibles
./scripts/database/restore_backup.sh

# Seleccionar el backup correcto
./scripts/database/restore_backup.sh 7
```

---

## 🛡️ Mejores Prácticas

### ✅ Recomendaciones

1. **Verificar cronjob funcionando**:
   ```bash
   # Después de configurar, esperar 1 día y verificar
   ls -lth /home/credicuenta/proyectos/credinet-v2/db/backups/
   ```

2. **Hacer backup manual antes de cambios importantes**:
   ```bash
   # Antes de migración o cambios grandes
   ./scripts/database/backup_daily.sh
   ```

3. **Probar restauración periódicamente**:
   ```bash
   # Cada mes, probar que restauración funciona
   # En ambiente de desarrollo
   ./scripts/database/restore_backup.sh catalogs
   ```

4. **Guardar backups importantes fuera del servidor**:
   ```bash
   # Copiar a tu máquina local
   scp credinet:/home/credicuenta/.../backup_*.gz ./backups_locales/
   ```

### ⚠️ Advertencias

- ❌ **NO borrar** `/home/credicuenta/proyectos/credinet-v2/db/backups/` manualmente
- ❌ **NO restaurar** en producción sin confirmar
- ❌ **NO usar** `TRUNCATE` o `DROP` sin backup previo
- ✅ **SÍ verificar** logs después de cada backup automático
- ✅ **SÍ mantener** al menos 1 backup fuera del servidor

---

## 📝 Logs y Debugging

### Ver logs de backup

```bash
# Crear directorio de logs si no existe
mkdir -p /home/credicuenta/proyectos/credinet-v2/logs

# Ver logs en tiempo real
tail -f /home/credicuenta/proyectos/credinet-v2/logs/backup.log

# Ver últimos errores
grep -i error /home/credicuenta/proyectos/credinet-v2/logs/backup.log
```

### Backup falló - ¿Qué hacer?

1. Verificar que Docker está corriendo:
   ```bash
   docker ps | grep credinet-postgres
   ```

2. Verificar credenciales:
   ```bash
   docker exec credinet-postgres psql -U credinet_user -d credinet_db -c "\dt"
   ```

3. Verificar espacio en disco:
   ```bash
   df -h
   ```

4. Ejecutar backup manualmente con logs:
   ```bash
   ./scripts/database/backup_daily.sh 2>&1 | tee /tmp/backup_debug.log
   ```

---

## 🎯 Resumen Rápido

| Acción | Comando |
|--------|---------|
| Backup manual | `./scripts/database/backup_daily.sh` |
| Ver backups | `./scripts/database/restore_backup.sh` |
| Restaurar último | `./scripts/database/restore_backup.sh 1` |
| Restaurar catálogos | `./scripts/database/restore_backup.sh catalogs` |
| Ver cronjobs | `crontab -l` |
| Ver logs | `tail -f logs/backup.log` |

---

**✅ Sistema de backups configurado y listo para producción**
