# 🏗️ Arquitectura Frontend - CrediNet V2

**Framework**: React 18 + Vite 7.1.14  
**Patrón**: Feature-Sliced Design + Clean Architecture  
**Estado**: Sprint 6 - Auth Implementado

---

## 📐 Principios de Arquitectura

### 1. **Feature-Sliced Design (FSD)**
Organización por features/módulos de negocio, no por tipo técnico.

### 2. **Separation of Concerns**
- **Presentación**: Componentes React (UI)
- **Lógica de Negocio**: Hooks + Services
- **Estado**: Context API / Zustand (futuro)
- **Datos**: API calls aisladas

### 3. **Dependency Rule**
Las capas internas NO conocen las externas:
```
UI → Hooks → Services → API
```

---

## 📁 Estructura de Carpetas

```
frontend-mvp/
├── src/
│   ├── app/                    # Configuración global de la app
│   │   ├── providers/          # Context Providers (Auth, Theme, etc)
│   │   ├── routes/             # Configuración de rutas
│   │   └── App.jsx             # Componente raíz
│   │
│   ├── features/               # Módulos de negocio (CORE)
│   │   ├── auth/               # ✅ Autenticación
│   │   │   ├── components/     # LoginForm, etc
│   │   │   ├── hooks/          # useAuth, useLogin
│   │   │   ├── services/       # authService.js
│   │   │   └── pages/          # LoginPage
│   │   │
│   │   ├── dashboard/          # Dashboard principal
│   │   │   ├── components/     # StatsCard, etc
│   │   │   ├── hooks/          # useDashboardData
│   │   │   └── pages/          # DashboardPage
│   │   │
│   │   ├── loans/              # Gestión de préstamos
│   │   │   ├── components/     # LoanCard, LoanList, LoanForm
│   │   │   ├── hooks/          # useLoans, useLoanDetails
│   │   │   ├── services/       # loansService.js
│   │   │   └── pages/          # LoansPage, LoanDetailsPage
│   │   │
│   │   ├── payments/           # Gestión de pagos
│   │   │   ├── components/     # PaymentTable, PaymentForm
│   │   │   ├── hooks/          # usePayments
│   │   │   ├── services/       # paymentsService.js
│   │   │   └── pages/          # PaymentsPage
│   │   │
│   │   └── associates/         # Gestión de asociados (futuro)
│   │       └── ...
│   │
│   ├── shared/                 # Código compartido entre features
│   │   ├── components/         # UI genéricos
│   │   │   ├── layout/         # Navbar, Sidebar, Footer
│   │   │   ├── ui/             # Button, Input, Card, Modal
│   │   │   └── feedback/       # Alert, Toast, Loading
│   │   │
│   │   ├── hooks/              # Hooks genéricos
│   │   │   ├── useApi.js       # Hook para llamadas API
│   │   │   ├── useForm.js      # Manejo de formularios
│   │   │   └── useDebounce.js  # Utilidades
│   │   │
│   │   ├── utils/              # Funciones de utilidad
│   │   │   ├── auth.js         # ✅ JWT utils
│   │   │   ├── format.js       # Formateo de fechas, moneda
│   │   │   ├── validation.js   # Validadores
│   │   │   └── constants.js    # Constantes globales
│   │   │
│   │   ├── api/                # Cliente HTTP y configuración
│   │   │   ├── client.js       # Axios/Fetch wrapper
│   │   │   ├── endpoints.js    # URLs de API
│   │   │   └── interceptors.js # Token refresh, error handling
│   │   │
│   │   └── types/              # TypeScript types (futuro)
│   │       └── index.ts
│   │
│   ├── assets/                 # Recursos estáticos
│   │   ├── images/
│   │   ├── icons/
│   │   └── fonts/
│   │
│   ├── styles/                 # Estilos globales
│   │   ├── index.css           # Global CSS
│   │   ├── variables.css       # CSS Variables (colores, spacing)
│   │   └── theme.css           # Temas (dark/light)
│   │
│   └── main.jsx                # Entry point
│
├── public/                     # Archivos públicos estáticos
├── docs/                       # Documentación del frontend
│   ├── ARQUITECTURA.md         # Este archivo
│   ├── COMPONENTS.md           # Catálogo de componentes
│   └── API.md                  # Documentación de API calls
│
├── vite.config.js
├── package.json
└── README.md
```

---

## 🎯 Módulos (Features) Implementados

### ✅ Auth (Autenticación)
**Estado**: Completado (Sprint 6)

**Archivos**:
- `features/auth/pages/LoginPage.jsx`
- `features/auth/components/LoginForm.jsx` (extraer del page)
- `features/auth/hooks/useAuth.js`
- `shared/utils/auth.js` (JWT utils)

**Funcionalidad**:
- Login con credenciales
- Almacenamiento de JWT tokens
- Validación de sesión
- Logout

---

## 🚀 Próximos Módulos (Sprint 7)

### 1. Dashboard
**Archivos**:
- `features/dashboard/pages/DashboardPage.jsx`
- `features/dashboard/components/StatsCard.jsx`
- `features/dashboard/components/RecentActivity.jsx`

**Funcionalidad**:
- Resumen de métricas (préstamos activos, pagos pendientes)
- Accesos rápidos a módulos
- Gráficas (futuro)

### 2. Layout Global
**Archivos**:
- `shared/components/layout/Navbar.jsx`
- `shared/components/layout/Sidebar.jsx` (opcional)
- `shared/components/layout/MainLayout.jsx`

**Funcionalidad**:
- Navbar con usuario + logout
- Navegación entre módulos
- Responsive design

### 3. Routing
**Archivos**:
- `app/routes/index.jsx`
- `app/routes/PrivateRoute.jsx`
- `app/routes/PublicRoute.jsx`

**Rutas**:
```javascript
/login              → LoginPage (público)
/dashboard          → DashboardPage (privado)
/loans              → LoansPage (privado)
/loans/:id          → LoanDetailsPage (privado)
/loans/:id/payments → PaymentsPage (privado)
/profile            → ProfilePage (privado)
```

---

## 🔧 Tecnologías y Librerías

### Core
- **React 18**: UI library
- **Vite 7.1.14**: Build tool + dev server
- **React Router v6**: Routing (instalar)

### UI/Styling (a instalar)
- **TailwindCSS**: Utility-first CSS
- **shadcn/ui**: Componentes base
- **Lucide React**: Iconos modernos

### Estado (futuro)
- **Zustand**: Estado global ligero
- **React Query**: Cache y sincronización de datos

### Formularios (futuro)
- **React Hook Form**: Manejo de forms
- **Zod**: Validación de schemas

### Utils
- **date-fns**: Manejo de fechas
- **axios**: HTTP client

---

## 🎨 Sistema de Diseño

### Colores (del login actual)
```css
:root {
  --primary: #667eea;          /* Púrpura principal */
  --primary-dark: #764ba2;     /* Púrpura oscuro */
  --secondary: #48bb78;        /* Verde (éxito) */
  --danger: #fc8181;           /* Rojo (error) */
  --warning: #f6ad55;          /* Naranja (advertencia) */
  --info: #4299e1;             /* Azul (info) */
  
  --text-primary: #1a202c;     /* Texto principal */
  --text-secondary: #718096;   /* Texto secundario */
  --bg-primary: #ffffff;       /* Fondo principal */
  --bg-secondary: #f7fafc;     /* Fondo secundario */
  
  --border: #e2e8f0;           /* Bordes */
  --shadow: rgba(0, 0, 0, 0.1); /* Sombras */
}
```

### Espaciado
```css
--spacing-xs: 4px;
--spacing-sm: 8px;
--spacing-md: 16px;
--spacing-lg: 24px;
--spacing-xl: 32px;
```

### Typography
```css
--font-size-xs: 12px;
--font-size-sm: 14px;
--font-size-md: 16px;
--font-size-lg: 18px;
--font-size-xl: 24px;
--font-size-2xl: 32px;
```

---

## 📝 Convenciones de Código

### Naming
- **Componentes**: PascalCase (`LoginPage.jsx`)
- **Hooks**: camelCase con prefijo `use` (`useAuth.js`)
- **Services**: camelCase con sufijo `Service` (`authService.js`)
- **Utils**: camelCase (`formatCurrency.js`)
- **Constants**: UPPER_SNAKE_CASE (`API_BASE_URL`)

### Estructura de Componentes
```jsx
// 1. Imports
import { useState } from 'react';
import { useAuth } from '@/features/auth/hooks/useAuth';
import Button from '@/shared/components/ui/Button';
import './ComponentName.css';

// 2. Component
const ComponentName = ({ prop1, prop2 }) => {
  // 2.1 Hooks
  const { user } = useAuth();
  const [state, setState] = useState();

  // 2.2 Handlers
  const handleClick = () => {
    // ...
  };

  // 2.3 Effects (si hay)
  useEffect(() => {
    // ...
  }, []);

  // 2.4 Render
  return (
    <div className="component-name">
      {/* JSX */}
    </div>
  );
};

// 3. PropTypes (opcional) o TypeScript
ComponentName.propTypes = {
  prop1: PropTypes.string.isRequired,
};

// 4. Export
export default ComponentName;
```

### Manejo de Estado
- **Local**: `useState` para estado del componente
- **Compartido**: Context API para auth, theme
- **Servidor**: React Query para datos de API (futuro)

---

## 🔐 Seguridad

### Auth Flow
```
1. Login → POST /api/v1/auth/login
2. Guardar tokens en localStorage
3. Incluir Bearer token en todas las requests
4. Auto-refresh token antes de expirar
5. Logout → Limpiar localStorage + redirect /login
```

### Protected Routes
```jsx
<PrivateRoute>
  <DashboardPage />
</PrivateRoute>
```

### API Interceptors
```javascript
// Request interceptor: Agregar token
axios.interceptors.request.use(config => {
  const token = auth.getAccessToken();
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

// Response interceptor: Handle 401
axios.interceptors.response.use(
  response => response,
  error => {
    if (error.response?.status === 401) {
      // Intentar refresh o logout
    }
    return Promise.reject(error);
  }
);
```

---

## 📊 Estado Actual del Proyecto

### Sprint 6 - Completado ✅
- [x] Setup proyecto (Vite + React)
- [x] Login page con diseño moderno
- [x] Autenticación real con backend
- [x] JWT token management
- [x] CORS configurado
- [x] Mock API para desarrollo
- [x] Documentación USER_FLOWS.md

### Sprint 7 - En Progreso 🔄
- [ ] Refactorizar estructura de carpetas (FSD)
- [ ] Crear layout global (Navbar)
- [ ] Implementar routing (React Router)
- [ ] Dashboard page
- [ ] Protected routes
- [ ] Auth context provider

### Sprint 8 - Planeado 📋
- [ ] Módulo de préstamos (lista, detalle)
- [ ] Módulo de pagos
- [ ] Formularios con validación
- [ ] Componentes UI base (shadcn/ui)

---

## 🚨 Deuda Técnica

### Alta Prioridad
1. **Migrar a estructura FSD**: Actualmente archivos sueltos en `pages/`
2. **Crear API client**: Centralizar fetch con interceptors
3. **Auth Context**: Compartir estado de usuario globalmente
4. **Error boundaries**: Capturar errores de React

### Media Prioridad
1. **TypeScript**: Migrar de JS a TS
2. **Testing**: Jest + React Testing Library
3. **Accesibilidad**: ARIA labels, keyboard navigation
4. **SEO**: Meta tags, títulos dinámicos

### Baja Prioridad
1. **i18n**: Internacionalización (ES/EN)
2. **Dark mode**: Tema oscuro
3. **PWA**: Progressive Web App
4. **Analytics**: Tracking de eventos

---

## 📚 Referencias

### Documentación
- [React Docs](https://react.dev/)
- [Vite Docs](https://vitejs.dev/)
- [Feature-Sliced Design](https://feature-sliced.design/)
- [Clean Architecture](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)

### Guías Internas
- `/docs/frontend/USER_FLOWS.md` - Diagramas de flujo
- `/docs/HOTFIX_AUTH_LOGIN.md` - Solución de problemas auth
- `/frontend-mvp/README_AUTH.md` - Guía de autenticación

---

**Última actualización**: 2025-11-05  
**Responsable**: GitHub Copilot + Usuario  
**Revisión**: Pendiente

