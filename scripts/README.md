# 🛠️ Scripts - Utilidades del Proyecto

Esta carpeta contiene scripts de utilidad para desarrollo, testing y deployment del proyecto Credinet.

---

## 📜 Scripts Disponibles

### 🚀 Setup y Desarrollo

#### `setup_db.sh`
**Propósito**: Setup inicial de base de datos  
**Uso**: `./scripts/setup_db.sh`  
**Qué hace**:
- Crea base de datos credinet_db
- Ejecuta schema (init_clean.sql)
- Aplica seeds (seeds_clean.sql)
- Ejecuta migraciones pendientes

#### `reset_dev_environment.sh`
**Propósito**: Reset completo del entorno de desarrollo  
**Uso**: `./scripts/reset_dev_environment.sh`  
**Qué hace**:
- Docker compose down -v (elimina volúmenes)
- Rebuild completo de containers
- Reaplica schema + seeds + migraciones
- Verifica servicios funcionando

**⚠️ CUIDADO**: Elimina TODA la data. Solo usar en desarrollo.

---

### 🧪 Testing

#### `run_full_tests.sh`
**Propósito**: Ejecuta suite completa de tests  
**Uso**: `./scripts/run_full_tests.sh`  
**Qué hace**:
- Tests unitarios (backend/tests/unit/)
- Tests de integración (backend/tests/integration/)
- Reporte de cobertura
- Validación de linting

#### `validate_frontend.sh`
**Propósito**: Valida el código del frontend  
**Uso**: `./scripts/validate_frontend.sh`  
**Qué hace**:
- ESLint check
- TypeScript check
- Build test
- Reporte de errores

---

### 🔄 Migraciones (Legacy - Mover a db/)

#### `apply_master_migration.sh`
**Propósito**: Aplica migración master (legacy)  
**Estado**: ⚠️ DEPRECADO - Usar migrations en db/migrations/ directamente  
**Reemplazo**: 
```bash
docker exec -i credinet_db psql -U credinet_user -d credinet_db < db/migrations/02_associate_deadline.sql
```

---

### 🔐 Git Hooks

#### `pre-commit.sh`
**Propósito**: Hook de pre-commit (si está configurado)  
**Uso**: Automático en git commit  
**Qué hace**:
- Valida formato de código
- Corre tests rápidos
- Previene commits con errores

---

## 🆕 Scripts Recomendados para Crear

### `validate_system.sh` (TODO)
Validación completa del sistema:
```bash
#!/bin/bash
# Verificar Docker containers
docker compose ps
# Verificar DB accesible
docker exec credinet_db psql -U credinet_user -d credinet_db -c "SELECT 1"
# Verificar API funcionando
curl -f http://192.168.98.98:8001/health
# Verificar Frontend accesible
curl -f http://192.168.98.98:5174
```

### `seed_realistic_data.sh` (TODO)
Popular DB con datos realistas para desarrollo:
```bash
#!/bin/bash
docker exec -i credinet_db psql -U credinet_user -d credinet_db < db/seeds_realistic.sql
```

---

## 📋 Convenciones

### Nomenclatura
- **snake_case** para nombres de scripts
- **Descripción clara** en primera línea del archivo
- **set -e** para salir en errores
- **Mensajes informativos** con echo

### Estructura Típica
```bash
#!/bin/bash
set -e

# Script: Descripción corta
# Uso: ./scripts/nombre_script.sh [args]

echo "🚀 Iniciando [nombre del proceso]..."

# Comandos...

echo "✅ [Proceso] completado exitosamente"
```

### Variables de Entorno
Usar `.env` files cuando sea posible:
```bash
source .env
echo "Usando BD: $POSTGRES_DB"
```

---

## ⚠️ Seguridad

1. **Nunca commitear credenciales** en scripts
2. **Usar variables de entorno** para datos sensibles
3. **Validar entrada del usuario** en scripts interactivos
4. **Logs claros** pero sin exponer secretos

---

## 📖 Agregar Nuevo Script

1. Crear archivo en `/scripts/nombre_script.sh`
2. Agregar shebang: `#!/bin/bash`
3. Hacer ejecutable: `chmod +x scripts/nombre_script.sh`
4. Documentar aquí en README.md
5. Agregar comentarios en el script

---

**Última actualización**: Octubre 1, 2025  
**Mantenedor**: @JairFC
