# 🔧 Corrección Sistema de Roles

**Fecha:** 19 de noviembre de 2025  
**Problema:** Usuario admin mostraba "Sin rol asignado" en la interfaz

## 📋 Resumen del Problema

El sistema mostraba "Acceso Denegado - Rol actual: Sin rol asignado" cuando el usuario `admin` intentaba acceder al dashboard, a pesar de estar autenticado correctamente con credenciales válidas (admin/Sparrow20).

## 🔍 Diagnóstico

### 1. Base de Datos ✅
- **Tabla:** `user_roles` (relación N:M)
- **Estado:** Usuario `admin` (id=2) tiene asignado el rol `administrador` (role_id=2)
- **Verificación:**
  ```sql
  SELECT u.id, u.username, r.name as role 
  FROM users u 
  JOIN user_roles ur ON u.id = ur.user_id 
  JOIN roles r ON ur.role_id = r.id 
  WHERE u.username = 'admin';
  
  -- Resultado: id=2, username=admin, role=administrador ✓
  ```

### 2. Backend ✅
- **Login endpoint:** Devuelve roles correctamente como array de strings
  ```json
  {
    "user": {
      "roles": ["administrador"]  // ✓ Correcto
    }
  }
  ```

- **JWT Token:** Contiene roles en el payload
  ```json
  {
    "sub": "admin",
    "user_id": 2,
    "roles": ["administrador"]  // ✓ Correcto
  }
  ```

- **Endpoint /me:** Devuelve usuario con roles desde la BD
  ```json
  {
    "id": 2,
    "username": "admin",
    "roles": ["administrador"]  // ✓ Correcto
  }
  ```

### 3. Frontend ❌ (PROBLEMA ENCONTRADO)
- **Archivo:** `frontend-mvp/src/app/routes/AdminRoute.jsx`
- **Error:** Esperaba `roles` como array de objetos `{name: "admin"}` pero el backend devuelve array de strings `["administrador"]`

**Código incorrecto:**
```jsx
const hasAdminAccess = userRoles.some(role =>
  role.name === 'admin' ||        // ❌ role.name es undefined
  role.name === 'desarrollador' ||  // ❌ role es un string, no objeto
  role.name === 'administrador'
);

<p>Rol actual: {userRoles.map(r => r.name).join(', ')}</p>  // ❌
```

**Código corregido:**
```jsx
const hasAdminAccess = userRoles.some(role =>
  role === 'admin' ||              // ✓ Compara strings directamente
  role === 'desarrollador' ||
  role === 'administrador'
);

<p>Rol actual: {userRoles.join(', ')}</p>  // ✓ Join directo de strings
```

## ✅ Correcciones Aplicadas

### 1. Frontend
**Archivo:** `/frontend-mvp/src/app/routes/AdminRoute.jsx`

- ✅ Cambiado `role.name` a `role` (líneas 40-43)
- ✅ Cambiado `userRoles.map(r => r.name).join(', ')` a `userRoles.join(', ')` (línea 60)

### 2. Backend
**Archivo:** `/backend/app/core/dependencies.py`

Agregado "administrador" a las validaciones de roles:

- ✅ `require_admin()` - Ahora acepta: "admin", "desarrollador", "administrador"
- ✅ `require_associate_or_admin()` - Ahora acepta: "asociado", "admin", "desarrollador", "administrador"
- ✅ `require_role()` - Factory que también permite "administrador" como bypass

## 🧪 Verificación

### Test 1: Login
```bash
curl -X POST http://192.168.98.98:8000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"Sparrow20"}'

# Resultado esperado: 
# { "user": { "roles": ["administrador"] }, "tokens": {...} }
```

### Test 2: Token JWT
```bash
# Decodificar payload del token
echo "<TOKEN>" | cut -d'.' -f2 | base64 -d

# Resultado esperado:
# { "roles": ["administrador"], "user_id": 2, ... }
```

### Test 3: Endpoint /me
```bash
curl -X GET http://192.168.98.98:8000/api/v1/auth/me \
  -H "Authorization: Bearer <TOKEN>"

# Resultado esperado:
# { "username": "admin", "roles": ["administrador"], ... }
```

### Test 4: Frontend
1. ✅ Login con admin/Sparrow20
2. ✅ Dashboard debe cargarse correctamente (no mostrar "Acceso Denegado")
3. ✅ Mensaje de rol debe mostrar: "Rol actual: administrador"

## 📊 Estructura de Roles en el Sistema

### Base de Datos (tabla `roles`)
```
id | name                    | description
---+------------------------+-------------
 1 | desarrollador          |
 2 | administrador          |
 3 | auxiliar_administrativo|
 4 | asociado               |
 5 | cliente                |
```

### Roles de Administrador (tienen acceso completo)
- `desarrollador` (id=1)
- `administrador` (id=2)
- `admin` (solo para compatibilidad futura)

### Arquitectura de Datos

```
┌─────────────┐
│   Backend   │
│  (FastAPI)  │
└──────┬──────┘
       │
       │ 1. Login: SELECT u.*, r.name FROM users u JOIN user_roles ur JOIN roles r
       │ 2. Token: { "roles": ["administrador"] }  ← Array de strings
       │ 3. Response: { "user": { "roles": ["administrador"] } }
       │
       ▼
┌─────────────┐
│  Frontend   │
│   (React)   │
└─────────────┘
       │
       │ user.roles = ["administrador"]  ← Array de strings
       │
       ▼
┌──────────────────────────────┐
│ AdminRoute.jsx               │
│ - Valida: role === "admin"   │ ✓ Corregido
│         || role === "admin"  │
│ - Muestra: roles.join(', ')  │ ✓ Corregido
└──────────────────────────────┘
```

## 🎯 Lecciones Aprendidas

1. **Consistencia de tipos:** El backend devuelve `roles` como `List[str]`, el frontend debe tratarlo igual
2. **Documentación:** El UserResponse DTO ya tenía `roles: List[str]` documentado, pero el frontend no lo respetaba
3. **Testing:** Los tests de integración habrían detectado este error al validar la estructura de datos
4. **Estandarización:** Usar los mismos nombres de roles en toda la aplicación:
   - ✅ "administrador" (usado en BD y actual)
   - ❌ "admin" (solo para compatibilidad)

## 📝 Próximos Pasos

1. **Crear tests de integración** para validar flujo completo de autenticación
2. **Documentar contratos de API** con ejemplos de respuesta
3. **Estandarizar nombres de roles** en todo el sistema
4. **Implementar validación de tipos** con TypeScript en frontend

## ⚠️ Notas Importantes

- Los roles en el sistema son **case-sensitive**
- Los roles se guardan en minúsculas en la BD: "administrador", "desarrollador", "asociado", "cliente"
- El token JWT contiene una copia de los roles del momento del login
- El endpoint `/me` obtiene roles frescos de la BD en cada llamada

---

**Estado:** ✅ Resuelto  
**Impacto:** Crítico - bloqueaba acceso a todo el sistema  
**Tiempo de resolución:** ~30 minutos  
**Componentes afectados:** AdminRoute.jsx, dependencies.py
