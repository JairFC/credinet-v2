# 🚀 Guía de Merge a Producción - 2026-01-21

## Resumen Ejecutivo

Esta guía documenta los cambios realizados en `develop` que deben mergearse a `main` para producción.

**Rama origen:** `develop`  
**Rama destino:** `main`  
**Commits a mergear:** 5 commits (desde `3aa0e09` hasta `f03c15b`)

---

## 📋 Lista de Cambios

### 1. Sistema Multi-Rol Cliente ↔ Asociado

**Funcionalidad:** Permite que un usuario tenga simultáneamente los roles de "cliente" y "asociado".

| Archivo | Cambio |
|---------|--------|
| `backend/app/modules/associates/routes.py` | Nuevos endpoints para gestión de roles |
| `frontend-mvp/src/shared/components/PromoteRoleModal.jsx` | Modal para asignar roles |
| `frontend-mvp/src/shared/components/PromoteRoleModal.css` | Estilos del modal |

**Endpoints nuevos:**
- `GET /api/v1/associates/user-roles/{user_id}` - Obtener roles de usuario
- `GET /api/v1/associates/check-user/{user_id}` - Verificar estado de usuario
- `POST /api/v1/associates/promote-to-associate/{user_id}` - Promover cliente a asociado
- `POST /api/v1/associates/add-client-role/{user_id}` - Agregar rol cliente a asociado

### 2. Sistema de Auditoría Mejorado

**Funcionalidad:** Registra quién realizó cambios de roles y cuándo.

| Archivo | Cambio |
|---------|--------|
| `backend/app/modules/associates/routes.py` | Función `_create_audit_log()` para registrar cambios |
| `backend/app/modules/audit/routes.py` | Endpoint mejorado con nombre de usuario |
| `frontend-mvp/src/shared/components/AuditHistory.jsx` | Muestra nombre del usuario que hizo cambios |
| `frontend-mvp/src/shared/components/AuditHistory.css` | Estilos para descripciones |

### 3. Fixes Técnicos

| Commit | Fix |
|--------|-----|
| `3374557` | Importar `text` de SQLAlchemy en routes.py |
| `63b3c3f` | Agregar `.unique()` a queries con UserModel (requerido por `lazy="joined"`) |
| `c42c70d` | Corregir backticks escapados en PromoteRoleModal.jsx |

---

## ✅ Validaciones Pre-Merge

### 1. Verificar estructura de base de datos

```sql
-- La tabla roles debe tener estos IDs exactos:
SELECT id, name FROM roles ORDER BY id;
-- Esperado:
-- 1 | desarrollador
-- 2 | administrador
-- 3 | auxiliar_administrativo
-- 4 | asociado
-- 5 | cliente

-- La tabla user_roles debe tener PK compuesto:
SELECT conname FROM pg_constraint WHERE conrelid = 'user_roles'::regclass AND contype = 'p';
-- Esperado: user_roles_pkey

-- La tabla audit_log debe existir:
SELECT column_name FROM information_schema.columns WHERE table_name = 'audit_log' ORDER BY ordinal_position;
-- Debe incluir: id, table_name, record_id, operation, old_data, new_data, changed_by, changed_at
```

### 2. Verificar que no hay conflictos de código

```bash
git fetch origin
git checkout main
git merge --no-commit --no-ff origin/develop
# Si hay conflictos, resolverlos manualmente
# Si no hay conflictos: git merge --abort (para hacer el merge real después)
```

### 3. Verificar archivos modificados

```bash
git diff --name-only main..develop
```

**Archivos esperados:**
```
backend/app/modules/associates/routes.py
backend/app/modules/audit/routes.py
frontend-mvp/src/features/associates/pages/AssociateDetailPage.jsx
frontend-mvp/src/features/users/clients/pages/ClientDetailPage.jsx
frontend-mvp/src/features/users/clients/pages/ClientDetailPage.css
frontend-mvp/src/shared/components/AuditHistory.jsx
frontend-mvp/src/shared/components/AuditHistory.css
frontend-mvp/src/shared/components/PromoteRoleModal.jsx
frontend-mvp/src/shared/components/PromoteRoleModal.css
```

---

## ⚠️ Posibles Problemas y Soluciones

### Problema 1: IDs de roles diferentes
**Síntoma:** Error 500 al asignar roles  
**Causa:** Los IDs de roles en producción no coinciden (4≠asociado, 5≠cliente)  
**Solución:** Verificar tabla `roles` y ajustar constantes en código si es necesario

### Problema 2: Tabla audit_log no existe
**Síntoma:** Error al registrar auditoría  
**Causa:** La tabla no fue creada en producción  
**Solución:** Crear la tabla con el script en `db/v2.0/`

### Problema 3: Error "unique() method must be invoked"
**Síntoma:** 500 Internal Server Error en endpoints de roles  
**Causa:** Falta el commit `63b3c3f`  
**Solución:** Asegurar que todos los commits estén incluidos

### Problema 4: Frontend no carga PromoteRoleModal
**Síntoma:** Error de sintaxis en consola  
**Causa:** Backticks mal escapados  
**Solución:** Asegurar que el commit `c42c70d` esté incluido

---

## 🔄 Proceso de Merge Recomendado

```bash
# 1. Actualizar repositorio
cd /home/credicuenta/proyectos/credinet-v2
git fetch origin

# 2. Verificar estado actual
git branch -a
git log --oneline main -5
git log --oneline origin/develop -5

# 3. Checkout a main
git checkout main

# 4. Merge desde develop
git merge origin/develop -m "Merge develop: Sistema multi-rol y auditoría mejorada"

# 5. Push a origin
git push origin main

# 6. Reiniciar servicios
docker compose restart backend
docker compose restart frontend  # Solo si está en modo producción
```

---

## 🧪 Validaciones Post-Merge

### 1. Backend funcionando
```bash
curl -s http://localhost:8000/health
# Esperado: {"status":"healthy",...}
```

### 2. Endpoints de roles funcionando
```bash
# Login
TOKEN=$(curl -s -X POST "http://localhost:8000/api/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"TU_PASSWORD"}' | \
  python3 -c "import sys,json; print(json.load(sys.stdin)['tokens']['access_token'])")

# Test endpoint
curl -s -H "Authorization: Bearer $TOKEN" \
  "http://localhost:8000/api/v1/associates/user-roles/2" | python3 -m json.tool
```

### 3. Frontend cargando sin errores
- Abrir DevTools (F12) → Console
- Navegar a detalle de asociado
- Verificar que no hay errores de JavaScript

---

## 📊 Datos NO Migrados (Solo Código)

Los siguientes datos son de prueba en DEV y **NO deben replicarse** en producción:

- Usuarios con múltiples roles (fueron pruebas)
- Registros de auditoría de pruebas
- Perfiles de asociados creados en pruebas

**Solo el código se migra. Los datos de producción permanecen intactos.**

---

## 📞 Rollback si hay problemas

```bash
# Volver al commit anterior de main
git checkout main
git reset --hard HEAD~1
git push origin main --force

# Reiniciar servicios
docker compose restart backend
```

---

**Documento creado:** 2026-01-21  
**Autor:** Sistema de desarrollo  
**Versión:** 1.0
