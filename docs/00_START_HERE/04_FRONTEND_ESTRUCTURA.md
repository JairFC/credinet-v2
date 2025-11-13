# 🎨 ESTRUCTURA DEL FRONTEND

**Tiempo de lectura:** ~8 minutos  
**Prerequisito:** Haber leído `03_APIS_PRINCIPALES.md`

---

## 📚 TABLA DE CONTENIDO

1. [Arquitectura FSD](#arquitectura-fsd)
2. [Estructura de Carpetas](#estructura-de-carpetas)
3. [Componentes Principales](#componentes-principales)
4. [Routing](#routing)
5. [Estado Global](#estado-global)
6. [Mock API](#mock-api)
7. [Próximos Pasos](#próximos-pasos)

---

## 🏗️ ARQUITECTURA FSD

### Feature-Sliced Design

Credinet usa **Feature-Sliced Design (FSD)**, una metodología de arquitectura frontend que organiza el código en **capas** y **slices**.

```
Capas (Layers):          Responsabilidad:
─────────────────────    ────────────────────────────────────
app                      Configuración global, providers
pages                    Rutas/pantallas completas
widgets                  Componentes complejos reutilizables
features                 Funcionalidades de negocio
entities                 Entidades del dominio
shared                   Código compartido (UI, utils, API)
```

### Reglas FSD

```
✅ PERMITIDO:
   • pages puede importar de widgets, features, entities, shared
   • widgets puede importar de features, entities, shared
   • features puede importar de entities, shared
   • entities puede importar de shared
   • shared NO importa de nadie

❌ PROHIBIDO:
   • shared NO puede importar de features
   • entities NO puede importar de features
   • Imports entre slices del mismo layer
```

**Beneficio:** Código predecible, escalable, fácil de mantener

---

## 📂 ESTRUCTURA DE CARPETAS

```
frontend-mvp/
├── public/                      # Assets estáticos
│   └── logo.svg
│
├── src/
│   ├── app/                     # 🔵 Configuración app
│   │   ├── App.jsx              # Componente principal
│   │   ├── router.jsx           # Configuración rutas
│   │   └── providers/           # Context providers
│   │       └── AuthProvider.jsx
│   │
│   ├── pages/                   # 🟦 Páginas (rutas)
│   │   ├── LoginPage/
│   │   │   ├── index.js
│   │   │   └── LoginPage.jsx
│   │   │
│   │   ├── DashboardPage/
│   │   │   ├── index.js
│   │   │   └── DashboardPage.jsx
│   │   │
│   │   ├── LoansPage/
│   │   │   ├── index.js
│   │   │   ├── LoansPage.jsx
│   │   │   └── LoansPage.module.css
│   │   │
│   │   ├── AssociatesPage/
│   │   └── PaymentsPage/
│   │
│   ├── widgets/                 # 🟩 Widgets complejos
│   │   ├── LoansList/
│   │   │   ├── index.js
│   │   │   ├── LoansList.jsx
│   │   │   └── LoanCard.jsx
│   │   │
│   │   ├── PaymentSchedule/
│   │   │   ├── index.js
│   │   │   ├── PaymentSchedule.jsx
│   │   │   └── PaymentRow.jsx
│   │   │
│   │   └── AssociateCreditCard/
│   │       ├── index.js
│   │       └── AssociateCreditCard.jsx
│   │
│   ├── features/                # 🟨 Funcionalidades
│   │   ├── auth/
│   │   │   ├── LoginForm/
│   │   │   │   ├── index.js
│   │   │   │   └── LoginForm.jsx
│   │   │   ├── useAuth.js       # Hook custom
│   │   │   └── authService.js   # Lógica auth
│   │   │
│   │   ├── loans/
│   │   │   ├── CreateLoanForm/
│   │   │   ├── ApproveLoanButton/
│   │   │   ├── RejectLoanButton/
│   │   │   ├── LoanCalculator/
│   │   │   └── useLoans.js
│   │   │
│   │   └── payments/
│   │       ├── RegisterPaymentForm/
│   │       └── usePayments.js
│   │
│   ├── entities/                # 🟧 Entidades
│   │   ├── loan/
│   │   │   ├── model/
│   │   │   │   └── loanModel.js
│   │   │   └── ui/
│   │   │       ├── LoanCard.jsx
│   │   │       └── LoanBadge.jsx
│   │   │
│   │   ├── associate/
│   │   │   ├── model/
│   │   │   │   └── associateModel.js
│   │   │   └── ui/
│   │   │       └── AssociateCard.jsx
│   │   │
│   │   └── payment/
│   │       ├── model/
│   │       │   └── paymentModel.js
│   │       └── ui/
│   │           └── PaymentCard.jsx
│   │
│   ├── shared/                  # 🟥 Compartido
│   │   ├── ui/                  # Componentes UI base
│   │   │   ├── Button/
│   │   │   │   ├── index.js
│   │   │   │   ├── Button.jsx
│   │   │   │   └── Button.module.css
│   │   │   ├── Input/
│   │   │   ├── Modal/
│   │   │   ├── Card/
│   │   │   └── Badge/
│   │   │
│   │   ├── api/                 # Cliente API
│   │   │   ├── apiClient.js
│   │   │   └── endpoints.js
│   │   │
│   │   ├── utils/               # Utilidades
│   │   │   ├── formatters.js
│   │   │   ├── validators.js
│   │   │   └── dates.js
│   │   │
│   │   └── config/
│   │       └── constants.js
│   │
│   ├── services/                # API Services (actual)
│   │   └── api.js               # Mock API
│   │
│   ├── main.jsx                 # Entry point
│   └── index.css                # Estilos globales
│
├── package.json
├── vite.config.js
└── README.md
```

---

## 🧩 COMPONENTES PRINCIPALES

### 1. App Component (`app/App.jsx`)

```jsx
import { BrowserRouter } from 'react-router-dom'
import { AuthProvider } from './providers/AuthProvider'
import { AppRouter } from './router'

function App() {
  return (
    <BrowserRouter>
      <AuthProvider>
        <AppRouter />
      </AuthProvider>
    </BrowserRouter>
  )
}

export default App
```

### 2. Router (`app/router.jsx`)

```jsx
import { Routes, Route, Navigate } from 'react-router-dom'
import { LoginPage } from '@/pages/LoginPage'
import { DashboardPage } from '@/pages/DashboardPage'
import { LoansPage } from '@/pages/LoansPage'
import { PrivateRoute } from '@/features/auth/PrivateRoute'

export const AppRouter = () => {
  return (
    <Routes>
      {/* Rutas públicas */}
      <Route path="/login" element={<LoginPage />} />
      
      {/* Rutas privadas */}
      <Route element={<PrivateRoute />}>
        <Route path="/dashboard" element={<DashboardPage />} />
        <Route path="/loans" element={<LoansPage />} />
        <Route path="/associates" element={<AssociatesPage />} />
        <Route path="/payments" element={<PaymentsPage />} />
      </Route>
      
      {/* Redirect */}
      <Route path="/" element={<Navigate to="/dashboard" />} />
    </Routes>
  )
}
```

### 3. LoginPage (`pages/LoginPage/LoginPage.jsx`)

```jsx
import { LoginForm } from '@/features/auth/LoginForm'
import { Card } from '@/shared/ui/Card'

export const LoginPage = () => {
  return (
    <div className="login-page">
      <div className="login-container">
        <Card>
          <h1>Credinet</h1>
          <p>Ingresa tus credenciales</p>
          <LoginForm />
        </Card>
      </div>
    </div>
  )
}
```

### 4. LoginForm (`features/auth/LoginForm/LoginForm.jsx`)

```jsx
import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useAuth } from '../useAuth'
import { Button } from '@/shared/ui/Button'
import { Input } from '@/shared/ui/Input'

export const LoginForm = () => {
  const [username, setUsername] = useState('')
  const [password, setPassword] = useState('')
  const { login, loading, error } = useAuth()
  const navigate = useNavigate()

  const handleSubmit = async (e) => {
    e.preventDefault()
    const success = await login(username, password)
    if (success) {
      navigate('/dashboard')
    }
  }

  return (
    <form onSubmit={handleSubmit}>
      <Input
        label="Usuario"
        value={username}
        onChange={(e) => setUsername(e.target.value)}
        required
      />
      <Input
        label="Contraseña"
        type="password"
        value={password}
        onChange={(e) => setPassword(e.target.value)}
        required
      />
      {error && <p className="error">{error}</p>}
      <Button type="submit" loading={loading}>
        Iniciar Sesión
      </Button>
    </form>
  )
}
```

### 5. LoansPage (`pages/LoansPage/LoansPage.jsx`)

```jsx
import { LoansList } from '@/widgets/LoansList'
import { CreateLoanButton } from '@/features/loans/CreateLoanButton'
import { useLoans } from '@/features/loans/useLoans'

export const LoansPage = () => {
  const { loans, loading, filters, setFilters } = useLoans()

  return (
    <div className="loans-page">
      <header>
        <h1>Préstamos</h1>
        <CreateLoanButton />
      </header>
      
      <div className="filters">
        <select 
          value={filters.status} 
          onChange={(e) => setFilters({ status: e.target.value })}
        >
          <option value="">Todos</option>
          <option value="PENDIENTE">Pendientes</option>
          <option value="APROBADO">Aprobados</option>
          <option value="RECHAZADO">Rechazados</option>
        </select>
      </div>

      <LoansList loans={loans} loading={loading} />
    </div>
  )
}
```

### 6. LoansList Widget (`widgets/LoansList/LoansList.jsx`)

```jsx
import { LoanCard } from '@/entities/loan/ui/LoanCard'
import { ApproveLoanButton } from '@/features/loans/ApproveLoanButton'
import { RejectLoanButton } from '@/features/loans/RejectLoanButton'

export const LoansList = ({ loans, loading }) => {
  if (loading) return <div>Cargando...</div>

  return (
    <div className="loans-list">
      {loans.map(loan => (
        <LoanCard key={loan.id} loan={loan}>
          {loan.status === 'PENDIENTE' && (
            <div className="actions">
              <ApproveLoanButton loanId={loan.id} />
              <RejectLoanButton loanId={loan.id} />
            </div>
          )}
        </LoanCard>
      ))}
    </div>
  )
}
```

---

## 🛣️ ROUTING

### Rutas Definidas

```
/                        → Redirect a /dashboard
/login                   → Página de login (pública)
/dashboard               → Dashboard principal (privada)
/loans                   → Lista de préstamos (privada)
/loans/:id               → Detalle de préstamo (privada)
/associates              → Lista de asociados (privada)
/associates/:id          → Detalle de asociado (privada)
/payments                → Pagos pendientes (privada)
```

### Navegación

```jsx
import { useNavigate } from 'react-router-dom'

const navigate = useNavigate()

// Navegar a otra página
navigate('/loans')

// Navegar con parámetros
navigate(`/loans/${loanId}`)

// Navegar hacia atrás
navigate(-1)

// Replace (no agrega al historial)
navigate('/dashboard', { replace: true })
```

---

## 🗂️ ESTADO GLOBAL

### AuthContext (`app/providers/AuthProvider.jsx`)

```jsx
import { createContext, useState, useContext } from 'react'

const AuthContext = createContext()

export const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(null)
  const [token, setToken] = useState(localStorage.getItem('token'))

  const login = async (username, password) => {
    const response = await api.auth.login(username, password)
    setToken(response.access_token)
    setUser(response.user)
    localStorage.setItem('token', response.access_token)
    return true
  }

  const logout = () => {
    setToken(null)
    setUser(null)
    localStorage.removeItem('token')
  }

  return (
    <AuthContext.Provider value={{ user, token, login, logout }}>
      {children}
    </AuthContext.Provider>
  )
}

export const useAuth = () => useContext(AuthContext)
```

### Custom Hooks

```jsx
// features/loans/useLoans.js
import { useState, useEffect } from 'react'
import api from '@/services/api'

export const useLoans = (filters = {}) => {
  const [loans, setLoans] = useState([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const fetchLoans = async () => {
      setLoading(true)
      const data = await api.loans.getAll(filters)
      setLoans(data)
      setLoading(false)
    }
    fetchLoans()
  }, [filters])

  return { loans, loading }
}
```

---

## 🎭 MOCK API

### Mock API Actual (`services/api.js`)

```javascript
// Mock data
const mockLoans = [
  {
    id: 4,
    client_name: "Juan Pérez",
    amount: 22000.00,
    status: "APROBADO"
  }
]

// Mock API
const api = {
  auth: {
    login: async (username, password) => {
      await delay(500)
      return {
        access_token: "mock-token-123",
        user: { id: 1, username, role: "ADMIN" }
      }
    }
  },
  
  loans: {
    getAll: async (filters = {}) => {
      await delay(300)
      return mockLoans.filter(loan => 
        !filters.status || loan.status === filters.status
      )
    },
    
    approve: async (loanId, data) => {
      await delay(500)
      const loan = mockLoans.find(l => l.id === loanId)
      loan.status = "APROBADO"
      return loan
    }
  }
}

export default api
```

**Beneficio:** Desarrollo frontend sin backend

---

## 🎨 COMPONENTES UI BASE

### Button (`shared/ui/Button/Button.jsx`)

```jsx
export const Button = ({ 
  children, 
  variant = 'primary',
  loading = false,
  disabled = false,
  onClick,
  ...props 
}) => {
  return (
    <button
      className={`btn btn-${variant}`}
      disabled={disabled || loading}
      onClick={onClick}
      {...props}
    >
      {loading ? 'Cargando...' : children}
    </button>
  )
}
```

### Input (`shared/ui/Input/Input.jsx`)

```jsx
export const Input = ({ 
  label, 
  error, 
  type = 'text',
  ...props 
}) => {
  return (
    <div className="input-group">
      {label && <label>{label}</label>}
      <input type={type} {...props} />
      {error && <span className="error">{error}</span>}
    </div>
  )
}
```

---

## 📋 PRÓXIMOS PASOS

### Fase 1: Setup UI (Pendiente)
```bash
# Instalar TailwindCSS
npm install -D tailwindcss postcss autoprefixer
npx tailwindcss init -p

# Instalar shadcn/ui (opcional)
npx shadcn-ui@latest init
```

### Fase 2: Implementar Páginas
1. ✅ LoginPage (estructura básica)
2. ⏳ DashboardPage
3. ⏳ LoansPage
4. ⏳ AssociatesPage
5. ⏳ PaymentsPage

### Fase 3: Conectar Backend
```javascript
// Reemplazar mock API con real API
const api = {
  auth: {
    login: async (username, password) => {
      const response = await fetch('http://localhost:8000/api/v1/auth/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ username, password })
      })
      return response.json()
    }
  }
}
```

---

## 🔗 REFERENCIAS

### Documentos Relacionados
- [`frontend/USER_FLOWS.md`](../frontend/USER_FLOWS.md) - Diagramas de flujo
- [`frontend/LOGICA_NEGOCIO_FRONTEND.md`](../frontend/LOGICA_NEGOCIO_FRONTEND.md) - Lógica negocio

### Código
- Frontend: `/frontend-mvp/src/`
- Mock API: `/frontend-mvp/src/services/api.js`

### Recursos Externos
- [Feature-Sliced Design](https://feature-sliced.design/)
- [React Router v6](https://reactrouter.com/)
- [Vite](https://vitejs.dev/)

---

## ✅ VERIFICACIÓN DE COMPRENSIÓN

Antes de continuar, asegúrate de entender:

1. ¿Cuáles son las 6 capas de FSD?
2. ¿Qué capa NO puede importar de ninguna otra?
3. ¿Dónde van las páginas completas?
4. ¿Dónde van los componentes UI base?
5. ¿Cómo funciona el mock API?

---

**Siguiente:** [`05_WORKFLOWS_COMUNES.md`](./05_WORKFLOWS_COMUNES.md) - Tareas frecuentes

**Tiempo total hasta ahora:** ~45 minutos
