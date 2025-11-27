# 🔒 Sistema de Seguridad y Autorización por Roles

## ⚠️ Actualización Importante (19/Nov/2025)

**Se corrigió un bug crítico** en la validación de roles del frontend. Ver: `/docs/CORRECCION_SISTEMA_ROLES.md`

**Cambio principal:** Los roles son arrays de strings `["administrador"]`, no objetos `[{name: "administrador"}]`

---

## Resumen

CrediNet V2 implementa un sistema de seguridad de **doble capa** con autenticación JWT y autorización basada en roles.

---

## 🛡️ Arquitectura de Seguridad

### Capa 1: Frontend (React)
- **Componente**: `AdminRoute`
- **Función**: Verificar que el usuario tiene rol de administrador antes de renderizar páginas
- **Ubicación**: `/frontend-mvp/src/app/routes/AdminRoute.jsx`
- **Formato de roles**: Array de strings `["administrador", "desarrollador"]`

### Capa 2: Backend (FastAPI)
- **Middleware**: `require_admin` dependency
- **Función**: Verificar JWT token y validar rol de administrador en cada petición API
- **Ubicación**: `/backend/app/core/dependencies.py`
- **Formato de roles**: Array de strings en JWT payload

---

## ✅ Estado Actual (Fase MVP)

### Backend - Módulos Protegidos

Todos los módulos requieren autenticación + rol de admin:

| Módulo | Endpoint Base | Protección |
|--------|--------------|------------|
| Préstamos | `/api/v1/loans` | ✅ `require_admin` |
| Pagos | `/api/v1/payments` | ✅ `require_admin` |
| Clientes | `/api/v1/clients` | ✅ `require_admin` |
| Asociados | `/api/v1/associates` | ✅ `require_admin` |
| Dashboard | `/api/v1/dashboard` | ✅ `require_admin` |

### Frontend - Rutas Protegidas

Todas las rutas usan `AdminRoute`:

```jsx
<AdminRoute>
  <MainLayout>
    <DashboardPage />
  </MainLayout>
</AdminRoute>
```

---

## 🔮 Escalabilidad Futura

El sistema está diseñado para agregar fácilmente roles de **Cliente** y **Asociado**.

### Ejemplo: Agregar Rol de Cliente

#### 1. Backend - Crear nuevo dependency

```python
# backend/app/core/dependencies.py
def require_client(
    roles: List[str] = Depends(get_current_user_roles)
) -> None:
    """Require user to have client role."""
    allowed_roles = ["client", "admin", "desarrollador"]
    if not any(role in roles for role in allowed_roles):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Requiere permisos de cliente",
        )
```

#### 2. Backend - Aplicar a router

```python
# backend/app/modules/client_portal/routes.py
router = APIRouter(
    prefix="/client-portal",
    tags=["Client Portal"],
    dependencies=[Depends(require_client)]  # 🔒 Solo clientes
)
```

#### 3. Frontend - Crear ClientRoute

```jsx
// frontend-mvp/src/app/routes/ClientRoute.jsx
const ClientRoute = ({ children }) => {
  const { user } = useAuth();
  
  const hasClientAccess = user?.roles?.some(role => 
    role.name === 'client' || role.name === 'cliente'
  );
  
  if (!hasClientAccess) {
    return <Navigate to="/acceso-denegado" />;
  }
  
  return children;
};
```

#### 4. Frontend - Usar en rutas

```jsx
<ClientRoute>
  <ClientLayout>
    <MyLoansPage />
  </ClientLayout>
</ClientRoute>
```

---

## 🔑 Roles Soportados

Actualmente el sistema reconoce estos roles:

| Rol | Nombre Alternativo | Acceso |
|-----|-------------------|--------|
| `admin` | `administrador` | ✅ Total |
| `desarrollador` | - | ✅ Total (bypass) |
| `associate` | `asociado` | ⏳ Futuro |
| `client` | `cliente` | ⏳ Futuro |

---

## 🧪 Pruebas de Seguridad

### Verificar que endpoints están protegidos:

```bash
# Sin token - debería dar 401
curl http://192.168.98.98:8000/api/v1/loans
# {"error":"HTTP Error","message":"Not authenticated"}

# Con token pero sin rol admin - debería dar 403
curl -H "Authorization: Bearer <token_no_admin>" \\
  http://192.168.98.98:8000/api/v1/loans
# {"error":"HTTP Error","message":"Requiere permisos de administrador"}
```

### Verificar protección en frontend:

1. Loggear con usuario sin rol admin
2. Intentar acceder a `/prestamos`
3. Debería mostrar: "🚫 Acceso Denegado"

---

## 📋 Checklist de Seguridad

- [x] Backend: Autenticación JWT implementada
- [x] Backend: Módulos críticos protegidos con `require_admin`
- [x] Frontend: Componente `AdminRoute` creado
- [x] Frontend: Todas las rutas usan `AdminRoute`
- [x] Probado: Endpoints rechazan peticiones sin auth
- [ ] Futuro: Agregar `ClientRoute` para clientes
- [ ] Futuro: Agregar `AssociateRoute` para asociados
- [ ] Futuro: Panel de cliente (vista limitada)
- [ ] Futuro: Panel de asociado (vista de sus préstamos)

---

## 🚀 Próximos Pasos

1. **Crear base de datos de roles**
   - Tabla `user_roles` con relación many-to-many
   - Seeders para roles iniciales

2. **Implementar módulos por rol**
   - `/client-portal` - Vista de cliente
   - `/associate-portal` - Vista de asociado

3. **Frontend por rol**
   - Navbar diferente según rol
   - Dashboard personalizado por rol

---

## ⚠️ Importante

**NUNCA confíes solo en la protección del frontend.** Siempre valida en el backend:

- ❌ MAL: Solo `AdminRoute` en frontend
- ✅ BIEN: `AdminRoute` en frontend + `require_admin` en backend

El frontend puede ser manipulado, el backend es la fuente de verdad.

---

Última actualización: 19 de noviembre de 2025
