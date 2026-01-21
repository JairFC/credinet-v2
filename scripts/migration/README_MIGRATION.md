# 🚀 Plan de Migración CrediNet v2.0
## Desarrollo (192.168.98.98) → Producción (10.5.26.141)

**Fecha**: Enero 2026
**Tipo**: Duplicación completa sin afectar sistema actual

---

## 📋 Resumen Ejecutivo

| Aspecto | Origen (Dev) | Destino (Prod) |
|---------|--------------|----------------|
| **IP** | 192.168.98.98 | 10.5.26.141 |
| **Red** | LAN local | Intranet VPN (ZeroTier) |
| **Acceso** | Directo | SSH remoto |
| **Docker** | Running | Vacío |
| **Datos** | 76 préstamos, 1044 pagos | Solo catálogos |

---

## 🔧 Archivos que Necesitan Cambio de IP

### Cambios REQUERIDOS (código):
1. **`.env`** - Variables de entorno (crear nuevo en destino)
2. **`docker-compose.yml`** - `VITE_API_URL` y `CORS_ORIGINS`

### Cambios OPCIONALES (código con defaults):
1. **`backend/app/core/config.py`** - CORS default (se sobrescribe con .env)

### Cambios NO necesarios (documentación):
- `docs/*.md` - Solo documentación, no afecta funcionamiento

---

## 📊 Datos Actuales en Desarrollo

### CONSERVAR (Catálogos):
| Tabla | Registros | Descripción |
|-------|-----------|-------------|
| roles | 5 | Tipos de usuario |
| loan_statuses | 8 | Estados de préstamo |
| payment_statuses | 13 | Estados de pago |
| payment_methods | 7 | Métodos de pago |
| cut_period_statuses | 6 | Estados de período |
| rate_profiles | 5 | Perfiles de tasa |
| cut_periods | 288 | Períodos hasta 2036 |

### CONSERVAR (Usuarios Admin):
| ID | Username | Rol | Nota |
|----|----------|-----|------|
| 1 | jair | desarrollador | Mantener |
| 2 | admin | administrador | Mantener |
| 7 | aux.admin | auxiliar_administrativo | Evaluar |

### ELIMINAR (Datos de prueba):
| Tabla | Registros | Dependencias |
|-------|-----------|--------------|
| payments | 1044 | → payment_status_history |
| loans | 76 | → payments, agreements |
| agreements | 2 | → agreement_items, agreement_payments |
| associate_payment_statements | 32 | → associate_statement_payments |
| users (id > 7) | ~33 | → user_roles, associate_profiles |
| associate_profiles | 14 | → loans (associate_id) |

---

## ⚠️ Problemas Identificados y Soluciones

### 1. IDs Hardcodeados
**Archivo**: `backend/app/modules/agreements/defaulted_reports_routes.py:372`
```python
"approved_by": 1  # TODO: Use current authenticated user
```
**Riesgo**: Asigna aprobaciones al user_id=1 siempre
**Solución**: Usar usuario autenticado del token JWT

### 2. JWT Secret en Desarrollo
**Archivo**: `.env` y `docker-compose.yml`
```
SECRET_KEY=dev_secret_key_change_in_production_please
```
**Riesgo**: Tokens predecibles
**Solución**: Generar secret fuerte de 64+ caracteres

### 3. Password de Base de Datos
**Archivo**: `.env`
```
POSTGRES_PASSWORD=credinet_pass_change_this_in_production
```
**Solución**: Usar password seguro de 32+ caracteres

### 4. Scheduler en Memoria
**Descripción**: APScheduler corre en memoria del backend
**Riesgo**: Si backend se reinicia en día 8/23, el job se pierde
**Mitigación**: Configurar restart policy y monitorear logs

---

## 🗂️ Estructura de Scripts de Migración

```
scripts/migration/
├── README_MIGRATION.md          # Este archivo
├── 01_pre_flight_check.sh       # Verificación pre-migración
├── 02_cleanup_data.sql          # Limpieza de datos prueba
├── 03_env_production.template   # Template de .env producción
├── 04_post_migration_test.sh    # Tests post-migración
└── 05_rollback.sql              # Script de rollback (emergencia)
```

---

## 🔒 Credenciales Producción (Generar Nuevas)

```bash
# Generar SECRET_KEY (64 chars)
openssl rand -hex 32

# Generar POSTGRES_PASSWORD (32 chars)
openssl rand -base64 24

# Output ejemplo:
# SECRET_KEY=a1b2c3d4...64chars...
# POSTGRES_PASSWORD=xYzAbCdE...32chars...
```

---

## 📅 Cronograma de Migración

### Fase 1: Preparación (Local - 30 min)
- [ ] Ejecutar script de verificación pre-vuelo
- [ ] Crear archivo .env de producción
- [ ] Commit final del código
- [ ] Push a GitHub

### Fase 2: Transferencia (Destino - 20 min)
- [ ] SSH a 10.5.26.141
- [ ] Clonar repositorio
- [ ] Copiar .env de producción
- [ ] Crear volúmenes Docker

### Fase 3: Base de Datos (Destino - 15 min)
- [ ] Levantar solo PostgreSQL
- [ ] Ejecutar init.sql (esquema + catálogos)
- [ ] Verificar catálogos creados
- [ ] Crear usuarios admin manualmente

### Fase 4: Servicios (Destino - 10 min)
- [ ] Levantar backend
- [ ] Verificar health check
- [ ] Levantar frontend
- [ ] Probar login admin

### Fase 5: Validación (30 min)
- [ ] Probar creación de asociado
- [ ] Probar creación de cliente
- [ ] Probar simulador de préstamos
- [ ] Probar aprobación de préstamo
- [ ] Verificar scheduler activo

---

## 🔙 Plan de Rollback

Si algo falla en producción:
1. El sistema de desarrollo sigue intacto
2. Simplemente apagar contenedores en destino
3. Corregir problemas y reintentar

**No hay pérdida de datos porque:**
- Sistema origen no se toca
- Sistema destino empieza vacío

