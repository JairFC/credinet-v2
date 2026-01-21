# 🚀 PLAN DE MIGRACIÓN REFINADO - CrediNet v2.0

**Fecha de Auditoría**: 2026-01-17  
**Origen**: 192.168.98.98 (Desarrollo)  
**Destino**: 10.5.26.141 (Producción via VPN)  

---

## 📊 RESUMEN DE AUDITORÍA

### Estado Actual de la BD de Desarrollo:

| Categoría | Tabla | Registros | Acción |
|-----------|-------|-----------|--------|
| **DATOS DE PRUEBA** | users | 40 | LIMPIAR (conservar 2 admin) |
| | loans | 76 | LIMPIAR |
| | payments | 1044 | LIMPIAR |
| | agreements | 2 | LIMPIAR |
| | associate_profiles | 14 | LIMPIAR |
| **CATÁLOGOS** | roles | 5 | CONSERVAR |
| | loan_statuses | 8 | CONSERVAR |
| | payment_statuses | 13 | CONSERVAR |
| | payment_methods | 7 | CONSERVAR |
| | cut_periods | 288 | CONSERVAR (auto-generados) |
| | rate_profiles | 5 | CONSERVAR |
| **BACKUP TEMPORAL** | backup_associate_* | 2 tablas | IGNORAR (no van a prod) |

---

## ✅ HALLAZGOS CRÍTICOS CORREGIDOS

### 1. ❌ BUG en init.sql (CORREGIDO)
**Problema**: El INSERT de usuarios usaba columnas incorrectas:
- `phone` en lugar de `phone_number`
- `user_type_id` que no existe
- `is_active` en lugar de `active`
- Rol `admin` en lugar de `administrador`

**Solución**: Corregido el init.sql con la estructura correcta.

### 2. ❌ Faltaba usuario `jair` (CORREGIDO)
**Problema**: El init.sql solo creaba usuario `admin`

**Solución**: Agregado INSERT para usuario `jair` con rol `desarrollador`

### 3. ❌ Hardcoded `approved_by = 1` (CORREGIDO PREVIAMENTE)
**Archivo**: `defaulted_reports_routes.py`

**Solución**: Ahora usa `current_user_id` del token JWT

---

## 🎯 ESTRATEGIA DEFINITIVA DE MIGRACIÓN

### ENFOQUE: INSTALACIÓN LIMPIA (No migración de datos)

Dado que:
1. El `init.sql` solo contiene esquema y catálogos
2. No hay datos de producción que migrar
3. Los datos actuales son de prueba

**La migración es simplemente:**
1. Clonar código desde GitHub
2. Crear .env de producción
3. `docker compose up -d`
4. Cambiar contraseñas de admin

---

## 📋 PASOS DETALLADOS

### FASE 1: Preparación en Desarrollo (Local)

```bash
# 1.1 Agregar scripts de migración al repo
cd /home/credicuenta/proyectos/credinet-v2
git add scripts/migration/
git add db/v2.0/init.sql  # Incluye correcciones
git add backend/app/modules/agreements/defaulted_reports_routes.py

# 1.2 Commit y push
git commit -m "fix: Corregir init.sql y agregar scripts de migración para producción"
git push origin main
```

### FASE 2: Preparación en Producción (10.5.26.141)

```bash
# 2.1 Conectar al servidor
ssh usuario@10.5.26.141

# 2.2 Instalar Docker (si no existe)
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
newgrp docker

# 2.3 Instalar Docker Compose plugin
sudo apt-get update && sudo apt-get install -y docker-compose-plugin

# 2.4 Crear directorio
sudo mkdir -p /opt/credinet-v2
sudo chown $USER:$USER /opt/credinet-v2
```

### FASE 3: Clonar y Configurar

```bash
# 3.1 Clonar repositorio
cd /opt/credinet-v2
git clone https://github.com/JairFC/credinet-v2.git .

# 3.2 Generar credenciales de producción
echo "SECRET_KEY=$(openssl rand -hex 32)"
echo "POSTGRES_PASSWORD=$(openssl rand -base64 24)"

# 3.3 Crear .env de producción
cp scripts/migration/03_env_production.template .env
nano .env  # Editar con las credenciales generadas
```

### FASE 4: Levantar Servicios

```bash
# 4.1 Construir imágenes
docker compose build

# 4.2 Levantar (BD se inicializa automáticamente con init.sql)
docker compose up -d

# 4.3 Verificar
docker compose ps
docker compose logs -f
```

### FASE 5: Validación

```bash
# 5.1 Verificar BD inicializada correctamente
docker compose exec postgres psql -U credinet_user -d credinet_db -c "
SELECT 
    (SELECT COUNT(*) FROM users) as usuarios,
    (SELECT COUNT(*) FROM roles) as roles,
    (SELECT COUNT(*) FROM cut_periods) as periodos;
"
# Esperado: usuarios=2, roles=5, periodos=288

# 5.2 Probar acceso
curl http://10.5.26.141:8000/docs

# 5.3 Cambiar contraseñas de admin
# Desde la UI: Login → Perfil → Cambiar contraseña
```

---

## ⚠️ RIESGOS Y MITIGACIONES

### Riesgo 1: Falla de red durante clone
**Mitigación**: El código está en GitHub, puede reintentarse

### Riesgo 2: Puerto ocupado
**Mitigación**: Verificar con `netstat -tlpn | grep -E '5173|8000|5432'`

### Riesgo 3: Permisos de Docker
**Mitigación**: Ejecutar `sudo usermod -aG docker $USER` y reiniciar sesión

### Riesgo 4: Espacio en disco insuficiente
**Mitigación**: Verificar con `df -h` (necesita ~5GB mínimo)

### Riesgo 5: Init.sql falla
**Mitigación**: 
- Revisar logs: `docker compose logs postgres`
- Corregido el init.sql con columnas correctas
- Si falla, se puede ejecutar manualmente

---

## 📁 ARCHIVOS PENDIENTES DE COMMIT

```
 M backend/app/modules/agreements/defaulted_reports_routes.py  # Fix approved_by
 M backend/app/modules/payments/infrastructure/models/payment_model.py
 M db/v2.0/init.sql  # Fix columnas usuarios

?? scripts/migration/01_pre_flight_check.sh
?? scripts/migration/02_cleanup_data.sql  # Ya no necesario para instalación limpia
?? scripts/migration/03_env_production.template
?? scripts/migration/04_post_migration_test.sh
?? scripts/migration/CHECKLIST_MIGRACION.md
?? scripts/migration/README_MIGRATION.md
?? scripts/migration/PLAN_MIGRACION_REFINADO.md
```

---

## 🔑 CREDENCIALES POR DEFECTO

| Usuario | Email | Rol | Password Inicial |
|---------|-------|-----|------------------|
| admin | admin@credinet.com | administrador | Usar hash bcrypt |
| jair | jair@dev.com | desarrollador | Usar hash bcrypt |

**⚠️ CAMBIAR CONTRASEÑAS INMEDIATAMENTE DESPUÉS DEL PRIMER LOGIN**

Para generar un hash bcrypt válido desde Python:
```python
from passlib.hash import bcrypt
password = "TuNuevaContraseña123!"
hash = bcrypt.hash(password)
print(hash)
```

---

## ✅ CHECKLIST FINAL

### Antes de migrar:
- [ ] Commit y push de todos los cambios a GitHub
- [ ] Verificar que init.sql está actualizado
- [ ] Generar credenciales de producción

### Durante la migración:
- [ ] Clonar desde GitHub
- [ ] Crear .env con credenciales de producción
- [ ] Levantar con docker compose

### Después de migrar:
- [ ] Verificar que la BD tiene usuarios admin
- [ ] Cambiar contraseñas de admin
- [ ] Probar login desde UI
- [ ] Probar flujo básico de préstamo
- [ ] Configurar firewall si es necesario

---

## 📞 ROLLBACK

Si algo falla, simplemente:
```bash
docker compose down -v  # Elimina contenedores y volúmenes
rm -rf /opt/credinet-v2/*  # Limpia todo
# Reintentar desde el paso 3.1
```

El sistema en desarrollo (192.168.98.98) NO se ve afectado.
