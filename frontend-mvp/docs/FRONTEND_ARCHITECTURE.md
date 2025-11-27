# 🏗️ ARQUITECTURA FRONTEND V2 - CrediNet

**Framework**: React 19.1.1 + Vite 7.1.14  
**Patrón**: Feature-Sliced Design (FSD)  
**Estado**: Sprint 7 - En desarrollo

---

## 🎯 PRINCIPIOS DE DISEÑO

### 1. Separation of Concerns
```
UI Components → Servicios API → Backend REST
```
Cada capa tiene una responsabilidad única y no conoce detalles de implementación de otras capas.

### 2. Feature-Sliced Design (FSD)
Organización por **características de negocio**, no por tipo técnico.

❌ **Anti-patrón** (por tipo técnico):
```
src/
├── components/       # Todos los componentes mezclados
├── services/         # Todos los servicios mezclados
└── hooks/           # Todos los hooks mezclados
```

✅ **Patrón correcto** (por feature):
```
src/
├── features/
│   ├── auth/        # Todo lo relacionado a autenticación
│   ├── loans/       # Todo lo relacionado a préstamos
│   └── payments/    # Todo lo relacionado a pagos
└── shared/          # Código compartido entre features
```

### 3. Dependency Rule
Las capas internas NO conocen las externas:
```
Pages → Components → Hooks → Services → API Client → Backend
```

### 4. Reusabilidad
Componentes UI genéricos en `shared/components/ui/`:
- Spinner, Skeleton, Modal, Toast
- Independientes del dominio de negocio

---

## 📁 ESTRUCTURA COMPLETA

```
frontend-mvp/
├── public/                      # Assets estáticos
│   └── react.svg
│
├── src/
│   ├── main.jsx                 # 🚀 Entry point
│   ├── App.jsx                  # 🔧 Root component
│   ├── App.css                  # 🎨 Estilos globales app
│   ├── index.css                # 🎨 Reset CSS + variables
│   │
│   ├── app/                     # 🌐 Configuración global
│   │   ├── providers/           # Context providers
│   │   │   └── AuthProvider.jsx # Estado de autenticación
│   │   │
│   │   └── routes/              # Configuración de rutas
│   │       ├── index.jsx        # Router principal
│   │       └── PrivateRoute.jsx # Guard para rutas privadas
│   │
│   ├── features/                # 🎯 CORE - Módulos de negocio
│   │   │
│   │   ├── auth/                # Autenticación
│   │   │   ├── pages/
│   │   │   │   ├── LoginPage.jsx
│   │   │   │   └── LoginPage.css
│   │   │   ├── components/      # (futuro: RegisterForm, etc)
│   │   │   └── hooks/           # (futuro: useLogin)
│   │   │
│   │   ├── dashboard/           # Dashboard principal
│   │   │   └── pages/
│   │   │       ├── DashboardPage.jsx
│   │   │       └── DashboardPage.css
│   │   │
│   │   ├── loans/               # Gestión de préstamos
│   │   │   ├── pages/
│   │   │   │   ├── LoansPage.jsx
│   │   │   │   └── LoansPage.css
│   │   │   └── components/      # (futuro: LoanCard, ApproveModal)
│   │   │
│   │   ├── payments/            # Gestión de pagos
│   │   │   ├── pages/
│   │   │   │   ├── PaymentsPage.jsx
│   │   │   │   └── PaymentsPage.css
│   │   │   └── components/
│   │   │
│   │   └── statements/          # Estados de cuenta
│   │       ├── pages/
│   │       │   ├── StatementsPage.jsx
│   │       │   └── StatementsPage.css
│   │       └── components/
│   │
│   ├── shared/                  # 🔄 Código compartido
│   │   │
│   │   ├── api/                 # Capa de API
│   │   │   ├── apiClient.js     # Axios instance configurada
│   │   │   ├── endpoints.js     # Definición de rutas
│   │   │   └── services/        # Servicios por módulo
│   │   │       ├── authService.js
│   │   │       ├── dashboardService.js
│   │   │       ├── loansService.js
│   │   │       ├── paymentsService.js
│   │   │       └── statementsService.js
│   │   │
│   │   ├── components/          # Componentes compartidos
│   │   │   ├── layout/          # Layouts
│   │   │   │   ├── MainLayout.jsx
│   │   │   │   ├── MainLayout.css
│   │   │   │   ├── Navbar.jsx
│   │   │   │   └── Navbar.css
│   │   │   │
│   │   │   └── ui/              # UI Components genéricos
│   │   │       ├── Spinner.jsx
│   │   │       ├── Skeleton.jsx
│   │   │       ├── Modal.jsx
│   │   │       └── ErrorBoundary.jsx
│   │   │
│   │   ├── hooks/               # Custom hooks compartidos
│   │   │   ├── useDebounce.js
│   │   │   └── useClickOutside.js
│   │   │
│   │   └── utils/               # Utilidades
│   │       ├── auth.js          # Helpers de localStorage
│   │       ├── formatters.js    # Formateo de datos
│   │       └── validators.js    # Validaciones
│   │
│   ├── assets/                  # Assets importados por JS
│   │   └── react.svg
│   │
│   └── mocks/                   # ⚠️ TEMPORAL - Datos mock
│       ├── loans.json.js        # (eliminar al conectar backend)
│       ├── payments.json.js
│       └── rateProfiles.json.js
│
├── docs/                        # 📚 Documentación
│   ├── FRONTEND_AUDIT.md        # Auditoría del estado actual
│   ├── FRONTEND_ROADMAP_V2.md   # Plan de acción
│   └── FRONTEND_ARCHITECTURE.md # Este archivo
│
├── .env                         # Variables de entorno
├── .env.example                 # Template de variables
├── vite.config.js               # Configuración Vite
├── package.json                 # Dependencias
├── eslint.config.js             # Linting
└── README.md                    # Guía de inicio
```

---

## 🔌 CAPA API (shared/api/)

### apiClient.js
```javascript
import axios from 'axios';
import { auth } from '@/shared/utils/auth';

const API_BASE_URL = import.meta.env.VITE_API_URL || 'http://localhost:8000';

// Axios instance
export const apiClient = axios.create({
  baseURL: API_BASE_URL,
  timeout: 10000,
  headers: { 'Content-Type': 'application/json' },
});

// Request interceptor - Add auth token
apiClient.interceptors.request.use(
  (config) => {
    const token = auth.getAccessToken();
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  },
  (error) => Promise.reject(error)
);

// Response interceptor - Handle errors and refresh token
apiClient.interceptors.response.use(
  (response) => response,
  async (error) => {
    const originalRequest = error.config;

    // Token expired - Try refresh
    if (error.response?.status === 401 && !originalRequest._retry) {
      originalRequest._retry = true;

      const refreshToken = auth.getRefreshToken();
      if (refreshToken) {
        try {
          const { data } = await axios.post(`${API_BASE_URL}/api/v1/auth/refresh`, {
            refresh_token: refreshToken,
          });

          // Update tokens
          const currentUser = auth.getUser();
          auth.setAuth(currentUser, data.access_token, data.refresh_token);

          // Retry original request
          originalRequest.headers.Authorization = `Bearer ${data.access_token}`;
          return apiClient(originalRequest);
        } catch (refreshError) {
          // Refresh failed - Logout
          auth.clearAuth();
          window.location.href = '/login';
          return Promise.reject(refreshError);
        }
      }
    }

    return Promise.reject(error);
  }
);
```

**Características**:
- ✅ Base URL desde variable de entorno
- ✅ Timeout de 10 segundos
- ✅ Token JWT automático en headers
- ✅ Refresh token automático si expira
- ✅ Redirect a /login si no hay refresh

---

### endpoints.js
```javascript
// Centralización de todas las rutas de la API
export const ENDPOINTS = {
  auth: {
    login: '/api/v1/auth/login',
    refresh: '/api/v1/auth/refresh',
    me: '/api/v1/auth/me',
  },
  dashboard: {
    stats: '/api/v1/dashboard/stats',
    recentActivity: '/api/v1/dashboard/recent-activity',
  },
  loans: {
    list: '/api/v1/loans',
    detail: (id) => `/api/v1/loans/${id}`,
    approve: (id) => `/api/v1/loans/${id}/approve`,
    reject: (id) => `/api/v1/loans/${id}/reject`,
  },
  payments: {
    byLoan: (loanId) => `/api/v1/payments/loan/${loanId}`,
    markPaid: (id) => `/api/v1/payments/${id}/mark-paid`,
  },
  statements: {
    list: '/api/v1/statements',
    detail: (id) => `/api/v1/statements/${id}`,
    markPaid: (id) => `/api/v1/statements/${id}/mark-paid`,
    applyLateFee: (id) => `/api/v1/statements/${id}/apply-late-fee`,
  },
};
```

**Ventajas**:
- ✅ Single source of truth para URLs
- ✅ Fácil de actualizar versión de API
- ✅ Autocompletado en IDE
- ✅ Funciones dinámicas para IDs

---

### services/loansService.js
```javascript
import apiClient from '../apiClient';
import { ENDPOINTS } from '../endpoints';

export const loansService = {
  // GET /api/v1/loans?status=pending
  getAll: (params = {}) =>
    apiClient.get(ENDPOINTS.loans.list, { params }),

  // GET /api/v1/loans/{id}
  getById: (id) =>
    apiClient.get(ENDPOINTS.loans.detail(id)),

  // POST /api/v1/loans/{id}/approve
  approve: (id) =>
    apiClient.post(ENDPOINTS.loans.approve(id)),

  // POST /api/v1/loans/{id}/reject
  reject: (id, reason) =>
    apiClient.post(ENDPOINTS.loans.reject(id), { reason }),
};
```

**Patrón**:
- Cada módulo tiene su service
- Funciones nombradas por acción
- Retornan promesas de axios
- No manejan errores (eso es responsabilidad del componente)

---

## 🎨 COMPONENTES UI (shared/components/ui/)

### Spinner.jsx
```javascript
import './Spinner.css';

export default function Spinner({ size = 'md' }) {
  return (
    <div className={`spinner spinner-${size}`}>
      <div className="spinner-circle"></div>
    </div>
  );
}

// Uso:
<Spinner size="sm" />  // 20px
<Spinner size="md" />  // 40px (default)
<Spinner size="lg" />  // 60px
```

### Skeleton.jsx
```javascript
import './Skeleton.css';

export default function Skeleton({ width = '100%', height = '20px' }) {
  return <div className="skeleton" style={{ width, height }} />;
}

// Uso:
<Skeleton width="200px" height="30px" />
<Skeleton width="100%" height="50px" />
```

### Modal.jsx
```javascript
import { useEffect } from 'react';
import './Modal.css';

export default function Modal({ isOpen, onClose, title, children, size = 'md' }) {
  useEffect(() => {
    if (isOpen) {
      document.body.style.overflow = 'hidden';
    } else {
      document.body.style.overflow = 'unset';
    }
    return () => {
      document.body.style.overflow = 'unset';
    };
  }, [isOpen]);

  if (!isOpen) return null;

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className={`modal-content modal-${size}`} onClick={(e) => e.stopPropagation()}>
        {title && (
          <div className="modal-header">
            <h2>{title}</h2>
            <button className="modal-close" onClick={onClose}>×</button>
          </div>
        )}
        <div className="modal-body">{children}</div>
      </div>
    </div>
  );
}

// Uso:
const [isOpen, setIsOpen] = useState(false);
<Modal isOpen={isOpen} onClose={() => setIsOpen(false)} title="Mi Modal" size="lg">
  <p>Contenido del modal</p>
</Modal>
```

---

## 🔐 GESTIÓN DE AUTENTICACIÓN

### AuthProvider (app/providers/AuthProvider.jsx)
```javascript
import { createContext, useContext, useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { auth as authUtils } from '@/shared/utils/auth';
import { authService } from '@/shared/api/services/authService';

const AuthContext = createContext(null);

export const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);
  const navigate = useNavigate();

  // Validar user al cargar app
  useEffect(() => {
    const validateUser = async () => {
      const token = authUtils.getAccessToken();
      const storedUser = authUtils.getUser();

      if (token && storedUser) {
        try {
          // Revalidar con backend
          const { data } = await authService.me();
          setUser(data.user);
        } catch (error) {
          // Token inválido
          authUtils.clearAuth();
          setUser(null);
        }
      }
      setLoading(false);
    };

    validateUser();
  }, []);

  const login = async (credentials) => {
    try {
      const { data } = await authService.login(credentials);
      const { user: userData, tokens } = data;

      authUtils.setAuth(userData, tokens.access_token, tokens.refresh_token);
      setUser(userData);

      return { success: true, user: userData };
    } catch (error) {
      return {
        success: false,
        error: error.response?.data?.detail || 'Error al iniciar sesión',
      };
    }
  };

  const logout = () => {
    authUtils.clearAuth();
    setUser(null);
    navigate('/login', { replace: true });
  };

  return (
    <AuthContext.Provider value={{ user, loading, login, logout, isAuthenticated: !!user }}>
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within AuthProvider');
  }
  return context;
};
```

**Flujo**:
1. Al cargar app: valida token en localStorage
2. Si hay token: llama a `/auth/me` para revalidar
3. Si token válido: restaura user
4. Si token inválido: limpia localStorage

**Estado global**:
- `user`: Objeto con datos del usuario
- `loading`: Boolean mientras valida
- `isAuthenticated`: Boolean si hay user + token
- `login(credentials)`: Función para login
- `logout()`: Función para logout

---

### auth.js (shared/utils/auth.js)
```javascript
// Helpers para localStorage
const STORAGE_KEYS = {
  USER: 'credinet_user',
  ACCESS_TOKEN: 'credinet_access_token',
  REFRESH_TOKEN: 'credinet_refresh_token',
};

export const auth = {
  getUser: () => {
    const user = localStorage.getItem(STORAGE_KEYS.USER);
    return user ? JSON.parse(user) : null;
  },

  getAccessToken: () => {
    return localStorage.getItem(STORAGE_KEYS.ACCESS_TOKEN);
  },

  getRefreshToken: () => {
    return localStorage.getItem(STORAGE_KEYS.REFRESH_TOKEN);
  },

  setAuth: (user, accessToken, refreshToken) => {
    localStorage.setItem(STORAGE_KEYS.USER, JSON.stringify(user));
    localStorage.setItem(STORAGE_KEYS.ACCESS_TOKEN, accessToken);
    localStorage.setItem(STORAGE_KEYS.REFRESH_TOKEN, refreshToken);
  },

  clearAuth: () => {
    localStorage.removeItem(STORAGE_KEYS.USER);
    localStorage.removeItem(STORAGE_KEYS.ACCESS_TOKEN);
    localStorage.removeItem(STORAGE_KEYS.REFRESH_TOKEN);
  },
};
```

---

## 🛣️ ROUTING (app/routes/)

### index.jsx
```javascript
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import PrivateRoute from './PrivateRoute';
import LoginPage from '@/features/auth/pages/LoginPage';
import DashboardPage from '@/features/dashboard/pages/DashboardPage';
import LoansPage from '@/features/loans/pages/LoansPage';
import PaymentsPage from '@/features/payments/pages/PaymentsPage';
import StatementsPage from '@/features/statements/pages/StatementsPage';
import MainLayout from '@/shared/components/layout/MainLayout';

const AppRoutes = () => {
  return (
    <BrowserRouter>
      <Routes>
        {/* Ruta pública */}
        <Route path="/login" element={<LoginPage />} />

        {/* Rutas privadas con layout */}
        <Route
          path="/dashboard"
          element={
            <PrivateRoute>
              <MainLayout>
                <DashboardPage />
              </MainLayout>
            </PrivateRoute>
          }
        />

        <Route
          path="/prestamos"
          element={
            <PrivateRoute>
              <MainLayout>
                <LoansPage />
              </MainLayout>
            </PrivateRoute>
          }
        />

        <Route
          path="/pagos"
          element={
            <PrivateRoute>
              <MainLayout>
                <PaymentsPage />
              </MainLayout>
            </PrivateRoute>
          }
        />

        <Route
          path="/statements"
          element={
            <PrivateRoute>
              <MainLayout>
                <StatementsPage />
              </MainLayout>
            </PrivateRoute>
          }
        />

        {/* Redirección por defecto */}
        <Route path="/" element={<Navigate to="/dashboard" replace />} />

        {/* 404 */}
        <Route path="*" element={<Navigate to="/dashboard" replace />} />
      </Routes>
    </BrowserRouter>
  );
};

export default AppRoutes;
```

---

### PrivateRoute.jsx
```javascript
import { Navigate } from 'react-router-dom';
import { useAuth } from '@/app/providers/AuthProvider';

export default function PrivateRoute({ children }) {
  const { isAuthenticated, loading } = useAuth();

  if (loading) {
    return <div className="loading-screen">Cargando...</div>;
  }

  return isAuthenticated ? children : <Navigate to="/login" replace />;
}
```

**Lógica**:
1. Si `loading`: muestra pantalla de carga
2. Si `isAuthenticated`: renderiza children
3. Si NO autenticado: redirect a /login

---

## 🎨 ESTILOS CSS

### Estructura de estilos
```
src/
├── index.css                # Reset + Variables CSS globales
├── App.css                  # Estilos del componente App
└── features/
    └── auth/
        └── pages/
            └── LoginPage.css # Estilos específicos de LoginPage
```

**Principio**: **Colocation** - Los estilos viven junto al componente que los usa.

---

### Variables CSS (index.css)
```css
:root {
  /* Colors */
  --color-primary: #667eea;
  --color-success: #10b981;
  --color-danger: #ef4444;
  --color-warning: #f59e0b;
  --color-info: #3b82f6;

  /* Grays */
  --color-gray-50: #f9fafb;
  --color-gray-100: #f3f4f6;
  --color-gray-200: #e5e7eb;
  --color-gray-300: #d1d5db;
  --color-gray-500: #6b7280;
  --color-gray-700: #374151;
  --color-gray-900: #111827;

  /* Spacing */
  --spacing-xs: 0.25rem;
  --spacing-sm: 0.5rem;
  --spacing-md: 1rem;
  --spacing-lg: 1.5rem;
  --spacing-xl: 2rem;

  /* Border radius */
  --radius-sm: 0.25rem;
  --radius-md: 0.5rem;
  --radius-lg: 1rem;

  /* Shadows */
  --shadow-sm: 0 1px 2px rgba(0, 0, 0, 0.05);
  --shadow-md: 0 4px 6px rgba(0, 0, 0, 0.1);
  --shadow-lg: 0 10px 15px rgba(0, 0, 0, 0.1);
}
```

**Ventaja**: Consistencia visual en toda la app.

---

### Clases Utilitarias
```css
/* Flexbox */
.flex { display: flex; }
.flex-col { flex-direction: column; }
.items-center { align-items: center; }
.justify-between { justify-content: space-between; }
.gap-2 { gap: var(--spacing-sm); }
.gap-4 { gap: var(--spacing-md); }

/* Text */
.text-sm { font-size: 0.875rem; }
.text-base { font-size: 1rem; }
.text-lg { font-size: 1.125rem; }
.text-xl { font-size: 1.25rem; }
.font-bold { font-weight: 700; }

/* Colors */
.text-gray-500 { color: var(--color-gray-500); }
.text-gray-700 { color: var(--color-gray-700); }

/* Spacing */
.mt-2 { margin-top: var(--spacing-sm); }
.mt-4 { margin-top: var(--spacing-md); }
.p-4 { padding: var(--spacing-md); }
```

---

## 🔄 FLUJO DE DATOS

### Ejemplo: Lista de Préstamos

```
1. Usuario visita /prestamos
   ↓
2. LoansPage.jsx renderiza
   ↓
3. useEffect(() => loadLoans(), [])
   ↓
4. loadLoans() llama a loansService.getAll()
   ↓
5. loansService.getAll() → apiClient.get('/api/v1/loans')
   ↓
6. apiClient interceptor agrega Authorization: Bearer {token}
   ↓
7. Backend responde con { loans: [...] }
   ↓
8. setLoans(data.loans)
   ↓
9. Re-render con datos reales
```

---

### Manejo de Errores

```javascript
const loadLoans = async () => {
  try {
    setLoading(true);
    const { data } = await loansService.getAll();
    setLoans(data.loans);
  } catch (error) {
    console.error('Error loading loans:', error);
    
    // Opción 1: Toast notification
    toast.error(error.response?.data?.detail || 'Error cargando préstamos');
    
    // Opción 2: Estado de error local
    setError(error.message);
  } finally {
    setLoading(false);
  }
};
```

---

## 🧪 PATRONES DE CÓDIGO

### 1. Custom Hooks
```javascript
// useDebounce.js
import { useState, useEffect } from 'react';

export function useDebounce(value, delay = 500) {
  const [debouncedValue, setDebouncedValue] = useState(value);

  useEffect(() => {
    const handler = setTimeout(() => {
      setDebouncedValue(value);
    }, delay);

    return () => clearTimeout(handler);
  }, [value, delay]);

  return debouncedValue;
}

// Uso:
const [searchTerm, setSearchTerm] = useState('');
const debouncedSearchTerm = useDebounce(searchTerm, 500);

useEffect(() => {
  if (debouncedSearchTerm) {
    searchLoans(debouncedSearchTerm);
  }
}, [debouncedSearchTerm]);
```

---

### 2. Loading States
```javascript
const [data, setData] = useState(null);
const [loading, setLoading] = useState(true);
const [error, setError] = useState(null);

if (loading) {
  return <Spinner />;
}

if (error) {
  return <div className="error">{error}</div>;
}

return <div>{/* Render data */}</div>;
```

---

### 3. Confirm Actions
```javascript
const handleDelete = async (id) => {
  if (!confirm('¿Está seguro de eliminar este préstamo?')) {
    return;
  }

  try {
    await loansService.delete(id);
    toast.success('Préstamo eliminado');
    loadLoans(); // Refresh list
  } catch (error) {
    toast.error('Error al eliminar');
  }
};
```

---

## 🔧 CONFIGURACIÓN VITE

### vite.config.js
```javascript
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import path from 'path';

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
  server: {
    host: true,
    port: 5173,
    watch: {
      usePolling: true,
    },
  },
});
```

**Características**:
- `@` alias para imports absolutos
- Port 5173
- Hot reload con polling (necesario en Docker)

---

## 🌍 VARIABLES DE ENTORNO

### .env
```bash
VITE_API_URL=http://192.168.98.98:8000
VITE_APP_NAME=CrediNet V2
VITE_APP_VERSION=2.0.0
```

### .env.example
```bash
VITE_API_URL=http://localhost:8000
VITE_APP_NAME=CrediNet V2
VITE_APP_VERSION=2.0.0
```

**Uso en código**:
```javascript
const API_URL = import.meta.env.VITE_API_URL;
const APP_NAME = import.meta.env.VITE_APP_NAME;
```

---

## 📦 DEPENDENCIAS

### Actuales (package.json)
```json
{
  "dependencies": {
    "react": "^19.1.1",
    "react-dom": "^19.1.1",
    "react-router-dom": "^7.9.5"
  },
  "devDependencies": {
    "@vitejs/plugin-react": "^5.0.4",
    "eslint": "^9.36.0",
    "vite": "npm:rolldown-vite@7.1.14"
  }
}
```

### A instalar
```bash
npm install axios              # HTTP client
npm install react-hot-toast    # Notifications
npm install date-fns          # (opcional) Date handling
npm install lucide-react      # (opcional) Icons
```

---

## ✅ BEST PRACTICES

### 1. Naming Conventions
```javascript
// Components: PascalCase
LoginPage.jsx
ApproveRejectModal.jsx

// Files: camelCase
authService.js
useDebounce.js

// CSS: kebab-case
login-page.css
approve-reject-modal.css

// Constantes: UPPER_SNAKE_CASE
const API_BASE_URL = '...';
const MAX_RETRIES = 3;
```

---

### 2. Imports Order
```javascript
// 1. External libraries
import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';

// 2. Internal modules (absolute imports)
import { useAuth } from '@/app/providers/AuthProvider';
import { loansService } from '@/shared/api/services/loansService';

// 3. Components
import Spinner from '@/shared/components/ui/Spinner';
import Modal from '@/shared/components/ui/Modal';

// 4. Styles
import './LoansPage.css';
```

---

### 3. Component Structure
```javascript
// 1. Imports
import { useState } from 'react';
import './Component.css';

// 2. Component definition
export default function Component({ prop1, prop2 }) {
  // 3. State
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(false);

  // 4. Effects
  useEffect(() => {
    loadData();
  }, []);

  // 5. Handlers
  const loadData = async () => { ... };
  const handleClick = () => { ... };

  // 6. Render conditions
  if (loading) return <Spinner />;

  // 7. Main render
  return (
    <div className="component">
      {/* JSX */}
    </div>
  );
}
```

---

### 4. Error Handling
```javascript
// ✅ GOOD
try {
  const { data } = await loansService.getAll();
  setLoans(data.loans);
} catch (error) {
  console.error('Error loading loans:', error);
  toast.error(error.response?.data?.detail || 'Error cargando préstamos');
} finally {
  setLoading(false);
}

// ❌ BAD
const data = await loansService.getAll();
setLoans(data.loans); // Puede crashear si falla
```

---

### 5. Async/Await vs Promises
```javascript
// ✅ GOOD: async/await
const loadLoans = async () => {
  const { data } = await loansService.getAll();
  setLoans(data.loans);
};

// ❌ BAD: .then()
const loadLoans = () => {
  loansService.getAll().then(({ data }) => {
    setLoans(data.loans);
  });
};
```

---

## 🚀 PRÓXIMOS PASOS

1. ✅ Documentación completada
2. ⏳ Implementar Fase 1: API Client (4h)
3. ⏳ Implementar Fase 2: Auth mejorado (2h)
4. ⏳ Implementar Fase 3: Dashboard real (2h)
5. ⏳ Implementar Fase 4: Módulo Préstamos (6h)
6. ⏳ Implementar Fase 5: Módulo Pagos (4h)
7. ⏳ Implementar Fase 6: Módulo Statements (4h)
8. ⏳ Implementar Fase 7: UI Components (4h)
9. ⏳ Implementar Fase 8: Polish & Testing (6h)

**Total**: 32 horas (2 semanas)

---

**Última actualización**: 2025-11-06  
**Autor**: GitHub Copilot  
**Referencias**: 
- [Feature-Sliced Design](https://feature-sliced.design/)
- [React Docs](https://react.dev/)
- [Vite Docs](https://vitejs.dev/)
