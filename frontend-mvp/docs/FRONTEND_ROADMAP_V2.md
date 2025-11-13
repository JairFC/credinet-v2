# 🗺️ FRONTEND ROADMAP V2 - CrediNet

**Fecha inicio**: 2025-11-06  
**Sprint**: 7  
**Duración estimada**: 32 horas (2 semanas)

---

## 🎯 OBJETIVO GENERAL

Transformar el frontend-mvp de **datos MOCK estáticos** a **aplicación completamente funcional** conectada al backend FastAPI.

**Meta final**: Sistema production-ready con todos los módulos operativos.

---

## 📊 ESTADO ACTUAL → ESTADO OBJETIVO

```
ACTUAL (32% completo):
├── ✅ Login (conectado a backend)
├── ⚠️ Dashboard (UI lista, DATOS MOCK)
├── ⚠️ Préstamos (UI lista, DATOS MOCK)
├── ❌ Pagos (0%)
├── ❌ Statements (0%)
└── ❌ API Layer (100% mock)

OBJETIVO (100% completo):
├── ✅ Login (con refresh token)
├── ✅ Dashboard (datos reales)
├── ✅ Préstamos (CRUD completo)
├── ✅ Pagos (gestión completa)
├── ✅ Statements (gestión completa)
└── ✅ API Layer (axios + interceptors)
```

---

## 🚀 FASE 1: INFRAESTRUCTURA API (4h)

**Objetivo**: Migrar de MOCK API a backend real con axios

### 1.1 Configuración Base (1h)

**Archivo**: `.env`
```bash
# Crear frontend-mvp/.env
VITE_API_URL=http://192.168.98.98:8000
VITE_APP_NAME=CrediNet V2
VITE_APP_VERSION=2.0.0
VITE_ENABLE_MOCK=false
```

**Archivo**: `vite.config.js`
```javascript
// Agregar env al config
export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      '@': '/src',
    },
  },
  server: {
    host: true,
    port: 5173,
  },
  envPrefix: 'VITE_', // Importante para variables de entorno
});
```

---

### 1.2 API Client Core (2h)

**Archivo**: `src/shared/api/apiClient.js`
```javascript
import axios from 'axios';
import { auth } from '@/shared/utils/auth';

const API_BASE_URL = import.meta.env.VITE_API_URL || 'http://localhost:8000';

// Create axios instance
export const apiClient = axios.create({
  baseURL: API_BASE_URL,
  timeout: 10000,
  headers: {
    'Content-Type': 'application/json',
  },
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
  (error) => {
    return Promise.reject(error);
  }
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

    // Handle other errors
    return Promise.reject(error);
  }
);

export default apiClient;
```

---

### 1.3 API Services Reales (1h)

**Archivo**: `src/shared/api/endpoints.js`
```javascript
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

**Archivo**: `src/shared/api/services/authService.js`
```javascript
import apiClient from '../apiClient';
import { ENDPOINTS } from '../endpoints';

export const authService = {
  login: (credentials) => 
    apiClient.post(ENDPOINTS.auth.login, credentials),

  refreshToken: (refreshToken) => 
    apiClient.post(ENDPOINTS.auth.refresh, { refresh_token: refreshToken }),

  me: () => 
    apiClient.get(ENDPOINTS.auth.me),
};
```

**Archivo**: `src/shared/api/services/dashboardService.js`
```javascript
import apiClient from '../apiClient';
import { ENDPOINTS } from '../endpoints';

export const dashboardService = {
  getStats: () => 
    apiClient.get(ENDPOINTS.dashboard.stats),

  getRecentActivity: (params = {}) => 
    apiClient.get(ENDPOINTS.dashboard.recentActivity, { params }),
};
```

**Archivo**: `src/shared/api/services/loansService.js`
```javascript
import apiClient from '../apiClient';
import { ENDPOINTS } from '../endpoints';

export const loansService = {
  getAll: (params = {}) => 
    apiClient.get(ENDPOINTS.loans.list, { params }),

  getById: (id) => 
    apiClient.get(ENDPOINTS.loans.detail(id)),

  approve: (id) => 
    apiClient.post(ENDPOINTS.loans.approve(id)),

  reject: (id, reason) => 
    apiClient.post(ENDPOINTS.loans.reject(id), { reason }),
};
```

**Checklist Fase 1**:
- [ ] Crear `.env` con variables
- [ ] Crear `apiClient.js` con axios
- [ ] Crear `endpoints.js` con rutas
- [ ] Crear `authService.js`
- [ ] Crear `dashboardService.js`
- [ ] Crear `loansService.js`
- [ ] Verificar interceptors funcionan

---

## 🔐 FASE 2: AUTH MEJORADO (2h)

**Objetivo**: Refresh token automático + validación user

### 2.1 Actualizar AuthProvider (1h)

**Archivo**: `src/app/providers/AuthProvider.jsx`
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
          // Token inválido - limpiar
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

  const value = {
    user,
    loading,
    login,
    logout,
    isAuthenticated: !!user && !!authUtils.getAccessToken(),
  };

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
};

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within AuthProvider');
  }
  return context;
};
```

---

### 2.2 Actualizar LoginPage (30min)

**Archivo**: `src/features/auth/pages/LoginPage.jsx`
```javascript
import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '@/app/providers/AuthProvider';
import reactLogo from '@/assets/react.svg';
import './LoginPage.css';

const LoginPage = () => {
  const navigate = useNavigate();
  const { login } = useAuth();

  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    const result = await login({ username, password });

    if (result.success) {
      navigate('/dashboard', { replace: true });
    } else {
      setError(result.error);
    }

    setLoading(false);
  };

  return (
    <div className="login-container">
      {/* ... resto del JSX igual ... */}
    </div>
  );
};

export default LoginPage;
```

**Checklist Fase 2**:
- [ ] Actualizar AuthProvider con revalidación
- [ ] Actualizar LoginPage con nuevo login
- [ ] Verificar refresh token funciona
- [ ] Verificar logout limpia todo
- [ ] Test: token expirado → refresh automático

---

## 📊 FASE 3: DASHBOARD REAL (2h)

**Objetivo**: Conectar dashboard a endpoints reales

### 3.1 Actualizar DashboardPage (2h)

**Archivo**: `src/features/dashboard/pages/DashboardPage.jsx`
```javascript
import { useState, useEffect } from 'react';
import { useAuth } from '@/app/providers/AuthProvider';
import { dashboardService } from '@/shared/api/services/dashboardService';
import './DashboardPage.css';

const DashboardPage = () => {
  const { user } = useAuth();
  const [stats, setStats] = useState(null);
  const [recentActivity, setRecentActivity] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    loadDashboardData();
  }, []);

  const loadDashboardData = async () => {
    try {
      setLoading(true);
      const [statsRes, activityRes] = await Promise.all([
        dashboardService.getStats(),
        dashboardService.getRecentActivity({ limit: 5 }),
      ]);

      setStats(statsRes.data);
      setRecentActivity(activityRes.data.activities || []);
    } catch (err) {
      setError(err.response?.data?.detail || 'Error cargando dashboard');
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return <div className="dashboard-loading">Cargando...</div>;
  }

  if (error) {
    return <div className="dashboard-error">{error}</div>;
  }

  return (
    <div className="dashboard-page">
      <div className="dashboard-header">
        <div className="welcome-section">
          <h1>¡Bienvenido, {user?.first_name}! 👋</h1>
          <p>Aquí está el resumen de tu sistema de préstamos</p>
        </div>
      </div>

      {/* Stats Cards */}
      <div className="stats-grid">
        <div className="stat-card" style={{ borderLeftColor: '#667eea' }}>
          <div className="stat-icon" style={{ background: '#667eea20', color: '#667eea' }}>
            💰
          </div>
          <div className="stat-content">
            <p className="stat-title">Préstamos Activos</p>
            <h2 className="stat-value">{stats?.active_loans_count || 0}</h2>
            <p className="stat-trend">Total: ${stats?.active_loans_total?.toLocaleString()}</p>
          </div>
        </div>

        {/* ... más stat cards ... */}
      </div>

      {/* Recent Activity */}
      <div className="recent-activity-section">
        <h2 className="section-title">Actividad Reciente</h2>
        <div className="activity-list">
          {recentActivity.map((activity) => (
            <div key={activity.id} className={`activity-item ${activity.type}`}>
              <div className="activity-icon">{activity.icon}</div>
              <div className="activity-content">
                <p className="activity-description">{activity.description}</p>
                <p className="activity-time">{activity.time_ago}</p>
              </div>
              {activity.amount && (
                <div className="activity-amount">
                  ${activity.amount.toLocaleString()}
                </div>
              )}
            </div>
          ))}
        </div>
      </div>
    </div>
  );
};

export default DashboardPage;
```

**Checklist Fase 3**:
- [ ] Actualizar DashboardPage con useEffect
- [ ] Llamar dashboardService.getStats()
- [ ] Llamar dashboardService.getRecentActivity()
- [ ] Mostrar loading state
- [ ] Mostrar error state
- [ ] Verificar datos reales se muestran

---

## 💰 FASE 4: MÓDULO PRÉSTAMOS (6h)

**Objetivo**: CRUD completo de préstamos con aprobar/rechazar

### 4.1 Conectar Lista de Préstamos (2h)

**Archivo**: `src/features/loans/pages/LoansPage.jsx`
```javascript
import { useState, useEffect } from 'react';
import { loansService } from '@/shared/api/services/loansService';
import './LoansPage.css';

export default function LoansPage() {
  const [loans, setLoans] = useState([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState('all');
  const [searchTerm, setSearchTerm] = useState('');

  useEffect(() => {
    loadLoans();
  }, [filter]);

  const loadLoans = async () => {
    try {
      setLoading(true);
      const params = {};
      if (filter !== 'all') {
        params.status = filter;
      }

      const { data } = await loansService.getAll(params);
      setLoans(data.loans || data); // Adaptable al formato del backend
    } catch (error) {
      console.error('Error loading loans:', error);
      // TODO: Mostrar toast de error
    } finally {
      setLoading(false);
    }
  };

  const filteredLoans = loans.filter((loan) => {
    if (searchTerm) {
      const term = searchTerm.toLowerCase();
      return (
        loan.id.toString().includes(term) ||
        loan.client_name?.toLowerCase().includes(term)
      );
    }
    return true;
  });

  return (
    <div className="loans-page">
      {/* ... UI igual pero con datos reales ... */}
    </div>
  );
}
```

---

### 4.2 Modal Aprobar/Rechazar (2h)

**Archivo**: `src/features/loans/components/ApproveRejectModal.jsx`
```javascript
import { useState } from 'react';
import './ApproveRejectModal.css';

export default function ApproveRejectModal({ loan, onClose, onSuccess }) {
  const [action, setAction] = useState('approve'); // 'approve' | 'reject'
  const [reason, setReason] = useState('');
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);

    try {
      if (action === 'approve') {
        await loansService.approve(loan.id);
      } else {
        await loansService.reject(loan.id, reason);
      }

      onSuccess(`Préstamo ${action === 'approve' ? 'aprobado' : 'rechazado'} exitosamente`);
      onClose();
    } catch (error) {
      console.error('Error:', error);
      // TODO: Toast error
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal-content" onClick={(e) => e.stopPropagation()}>
        <div className="modal-header">
          <h2>Gestionar Préstamo #{loan.id}</h2>
          <button className="modal-close" onClick={onClose}>×</button>
        </div>

        <form onSubmit={handleSubmit}>
          <div className="action-selector">
            <button
              type="button"
              className={action === 'approve' ? 'active' : ''}
              onClick={() => setAction('approve')}
            >
              ✅ Aprobar
            </button>
            <button
              type="button"
              className={action === 'reject' ? 'active' : ''}
              onClick={() => setAction('reject')}
            >
              ❌ Rechazar
            </button>
          </div>

          {action === 'reject' && (
            <div className="form-group">
              <label>Razón del rechazo *</label>
              <textarea
                value={reason}
                onChange={(e) => setReason(e.target.value)}
                required
                rows="4"
                placeholder="Explica por qué se rechaza el préstamo..."
              />
            </div>
          )}

          <div className="modal-actions">
            <button type="button" onClick={onClose} disabled={loading}>
              Cancelar
            </button>
            <button
              type="submit"
              className={action === 'approve' ? 'btn-success' : 'btn-danger'}
              disabled={loading}
            >
              {loading ? 'Procesando...' : action === 'approve' ? 'Aprobar' : 'Rechazar'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
```

---

### 4.3 Modal Detalle (2h)

**Archivo**: `src/features/loans/components/LoanDetailModal.jsx`
```javascript
import { useState, useEffect } from 'react';
import { loansService } from '@/shared/api/services/loansService';
import './LoanDetailModal.css';

export default function LoanDetailModal({ loanId, onClose }) {
  const [loan, setLoan] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadLoanDetail();
  }, [loanId]);

  const loadLoanDetail = async () => {
    try {
      const { data } = await loansService.getById(loanId);
      setLoan(data);
    } catch (error) {
      console.error('Error loading loan:', error);
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return <div className="modal-loading">Cargando...</div>;
  }

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal-content modal-large" onClick={(e) => e.stopPropagation()}>
        <div className="modal-header">
          <h2>Detalle del Préstamo #{loan.id}</h2>
          <button className="modal-close" onClick={onClose}>×</button>
        </div>

        <div className="loan-detail-grid">
          <div className="detail-section">
            <h3>Información General</h3>
            <div className="detail-item">
              <span className="label">Cliente:</span>
              <span className="value">{loan.client_name}</span>
            </div>
            <div className="detail-item">
              <span className="label">Monto:</span>
              <span className="value">${loan.amount.toLocaleString()}</span>
            </div>
            {/* ... más campos ... */}
          </div>
        </div>
      </div>
    </div>
  );
}
```

**Checklist Fase 4**:
- [ ] Conectar lista a loansService.getAll()
- [ ] Filtros funcionales (status)
- [ ] Búsqueda funcional
- [ ] Crear ApproveRejectModal
- [ ] Integrar modal en LoansPage
- [ ] Crear LoanDetailModal
- [ ] Verificar aprobar/rechazar funciona

---

## 💳 FASE 5: MÓDULO PAGOS (4h)

**Objetivo**: Gestión completa de pagos por préstamo

### 5.1 Crear PaymentsPage (4h)

**Archivo**: `src/features/payments/pages/PaymentsPage.jsx`
```javascript
import { useState, useEffect } from 'react';
import { useSearchParams } from 'react-router-dom';
import { paymentsService } from '@/shared/api/services/paymentsService';
import './PaymentsPage.css';

export default function PaymentsPage() {
  const [searchParams] = useSearchParams();
  const loanId = searchParams.get('loan_id');

  const [payments, setPayments] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (loanId) {
      loadPayments();
    }
  }, [loanId]);

  const loadPayments = async () => {
    try {
      setLoading(true);
      const { data } = await paymentsService.getByLoanId(loanId);
      setPayments(data.payments || data);
    } catch (error) {
      console.error('Error loading payments:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleMarkPaid = async (paymentId) => {
    if (!confirm('¿Marcar este pago como pagado?')) return;

    try {
      await paymentsService.markAsPaid(paymentId, {
        paid_date: new Date().toISOString(),
        payment_method_id: 1, // TODO: Modal para seleccionar método
      });

      // Reload payments
      loadPayments();
      // TODO: Toast success
    } catch (error) {
      console.error('Error marking payment:', error);
      // TODO: Toast error
    }
  };

  return (
    <div className="payments-page">
      <div className="payments-header">
        <h1>💳 Gestión de Pagos</h1>
        {loanId && <p>Préstamo #{loanId}</p>}
      </div>

      {loading ? (
        <div>Cargando pagos...</div>
      ) : (
        <div className="payments-table">
          <table>
            <thead>
              <tr>
                <th>#</th>
                <th>Fecha Vencimiento</th>
                <th>Monto</th>
                <th>Estado</th>
                <th>Acciones</th>
              </tr>
            </thead>
            <tbody>
              {payments.map((payment) => (
                <tr key={payment.id}>
                  <td>{payment.payment_number}</td>
                  <td>{new Date(payment.due_date).toLocaleDateString()}</td>
                  <td>${payment.amount.toLocaleString()}</td>
                  <td>
                    <span className={`badge badge-${payment.status}`}>
                      {payment.status}
                    </span>
                  </td>
                  <td>
                    {payment.status === 'pending' && (
                      <button
                        className="btn-success btn-sm"
                        onClick={() => handleMarkPaid(payment.id)}
                      >
                        ✅ Marcar Pagado
                      </button>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
```

**Archivo**: `src/shared/api/services/paymentsService.js`
```javascript
import apiClient from '../apiClient';
import { ENDPOINTS } from '../endpoints';

export const paymentsService = {
  getByLoanId: (loanId) =>
    apiClient.get(ENDPOINTS.payments.byLoan(loanId)),

  markAsPaid: (id, data) =>
    apiClient.post(ENDPOINTS.payments.markPaid(id), data),
};
```

**Checklist Fase 5**:
- [ ] Crear paymentsService
- [ ] Crear PaymentsPage
- [ ] Tabla de pagos funcional
- [ ] Botón marcar como pagado
- [ ] Refresh después de marcar
- [ ] Agregar ruta en router

---

## 📄 FASE 6: MÓDULO STATEMENTS (4h)

**Objetivo**: Gestión completa de statements

### 6.1 Crear StatementsPage (4h)

**Archivo**: `src/features/statements/pages/StatementsPage.jsx`
```javascript
import { useState, useEffect } from 'react';
import { statementsService } from '@/shared/api/services/statementsService';
import './StatementsPage.css';

export default function StatementsPage() {
  const [statements, setStatements] = useState([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState({ status: 'all' });

  useEffect(() => {
    loadStatements();
  }, [filter]);

  const loadStatements = async () => {
    try {
      setLoading(true);
      const params = filter.status !== 'all' ? { status: filter.status } : {};
      const { data } = await statementsService.getAll(params);
      setStatements(data.statements || data);
    } catch (error) {
      console.error('Error loading statements:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleMarkPaid = async (statementId) => {
    // TODO: Modal para ingresar monto y método de pago
    try {
      await statementsService.markAsPaid(statementId, {
        paid_amount: 0, // TODO: desde modal
        paid_date: new Date().toISOString(),
        payment_method_id: 1,
      });

      loadStatements();
      // TODO: Toast success
    } catch (error) {
      console.error('Error:', error);
    }
  };

  return (
    <div className="statements-page">
      <div className="statements-header">
        <h1>📄 Estados de Cuenta</h1>
      </div>

      {/* Filtros */}
      <div className="filters">
        <select value={filter.status} onChange={(e) => setFilter({ status: e.target.value })}>
          <option value="all">Todos</option>
          <option value="pending">Pendientes</option>
          <option value="paid">Pagados</option>
          <option value="partial_paid">Parcialmente Pagados</option>
          <option value="overdue">Vencidos</option>
        </select>
      </div>

      {/* Tabla */}
      {loading ? (
        <div>Cargando...</div>
      ) : (
        <table className="statements-table">
          <thead>
            <tr>
              <th>Statement #</th>
              <th>Asociado</th>
              <th>Periodo</th>
              <th>Total</th>
              <th>Estado</th>
              <th>Acciones</th>
            </tr>
          </thead>
          <tbody>
            {statements.map((statement) => (
              <tr key={statement.id}>
                <td>{statement.statement_number}</td>
                <td>{statement.associate_name}</td>
                <td>{statement.cut_period_code}</td>
                <td>${statement.total_commission_owed?.toLocaleString()}</td>
                <td>
                  <span className={`badge badge-${statement.status}`}>
                    {statement.status_name}
                  </span>
                </td>
                <td>
                  {statement.status === 'pending' && (
                    <button
                      className="btn-success btn-sm"
                      onClick={() => handleMarkPaid(statement.id)}
                    >
                      ✅ Marcar Pagado
                    </button>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  );
}
```

**Archivo**: `src/shared/api/services/statementsService.js`
```javascript
import apiClient from '../apiClient';
import { ENDPOINTS } from '../endpoints';

export const statementsService = {
  getAll: (params = {}) =>
    apiClient.get(ENDPOINTS.statements.list, { params }),

  getById: (id) =>
    apiClient.get(ENDPOINTS.statements.detail(id)),

  markAsPaid: (id, data) =>
    apiClient.post(ENDPOINTS.statements.markPaid(id), data),

  applyLateFee: (id, data) =>
    apiClient.post(ENDPOINTS.statements.applyLateFee(id), data),
};
```

**Checklist Fase 6**:
- [ ] Crear statementsService
- [ ] Crear StatementsPage
- [ ] Tabla con filtros funcionales
- [ ] Botón marcar como pagado
- [ ] Modal de pago (opcional)
- [ ] Agregar ruta en router

---

## 🎨 FASE 7: UI/UX COMPONENTS (4h)

**Objetivo**: Componentes reutilizables para mejorar UX

### 7.1 Loading Components (1h)

**Archivo**: `src/shared/components/ui/Spinner.jsx`
```javascript
import './Spinner.css';

export default function Spinner({ size = 'md' }) {
  return (
    <div className={`spinner spinner-${size}`}>
      <div className="spinner-circle"></div>
    </div>
  );
}
```

**Archivo**: `src/shared/components/ui/Skeleton.jsx`
```javascript
import './Skeleton.css';

export default function Skeleton({ width = '100%', height = '20px', className = '' }) {
  return (
    <div
      className={`skeleton ${className}`}
      style={{ width, height }}
    />
  );
}
```

---

### 7.2 Toast Notifications (2h)

**Instalar**: `npm install react-hot-toast`

**Archivo**: `src/App.jsx`
```javascript
import { Toaster } from 'react-hot-toast';

function App() {
  return (
    <AuthProvider>
      <Toaster
        position="top-right"
        toastOptions={{
          duration: 3000,
          success: { iconTheme: { primary: '#10b981', secondary: '#fff' } },
          error: { iconTheme: { primary: '#ef4444', secondary: '#fff' } },
        }}
      />
      <AppRoutes />
    </AuthProvider>
  );
}
```

**Uso en componentes**:
```javascript
import toast from 'react-hot-toast';

// Success
toast.success('Préstamo aprobado exitosamente');

// Error
toast.error('Error al aprobar préstamo');

// Loading
const toastId = toast.loading('Procesando...');
// ... operación async
toast.success('Completado', { id: toastId });
```

---

### 7.3 Modal Base Component (1h)

**Archivo**: `src/shared/components/ui/Modal.jsx`
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
      <div
        className={`modal-content modal-${size}`}
        onClick={(e) => e.stopPropagation()}
      >
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
```

**Checklist Fase 7**:
- [ ] Crear Spinner component
- [ ] Crear Skeleton component
- [ ] Instalar react-hot-toast
- [ ] Integrar Toaster en App
- [ ] Reemplazar console.error con toast.error
- [ ] Crear Modal base component

---

## 🚀 FASE 8: POLISH & TESTING (6h)

### 8.1 Error Handling (2h)

**Archivo**: `src/shared/components/ErrorBoundary.jsx`
```javascript
import React from 'react';

class ErrorBoundary extends React.Component {
  constructor(props) {
    super(props);
    this.state = { hasError: false, error: null };
  }

  static getDerivedStateFromError(error) {
    return { hasError: true, error };
  }

  componentDidCatch(error, errorInfo) {
    console.error('ErrorBoundary caught:', error, errorInfo);
  }

  render() {
    if (this.state.hasError) {
      return (
        <div className="error-boundary">
          <h1>Algo salió mal</h1>
          <p>{this.state.error?.message}</p>
          <button onClick={() => window.location.reload()}>
            Recargar página
          </button>
        </div>
      );
    }

    return this.props.children;
  }
}

export default ErrorBoundary;
```

**Integrar en main.jsx**:
```javascript
import ErrorBoundary from '@/shared/components/ErrorBoundary';

ReactDOM.createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <ErrorBoundary>
      <App />
    </ErrorBoundary>
  </React.StrictMode>
);
```

---

### 8.2 Formatters Utils (1h)

**Archivo**: `src/shared/utils/formatters.js`
```javascript
export const formatCurrency = (amount, currency = 'COP') => {
  return new Intl.NumberFormat('es-CO', {
    style: 'currency',
    currency,
    minimumFractionDigits: 0,
  }).format(amount);
};

export const formatDate = (date, options = {}) => {
  return new Date(date).toLocaleDateString('es-CO', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
    ...options,
  });
};

export const formatDateTime = (date) => {
  return new Date(date).toLocaleString('es-CO', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
};

export const formatPercentage = (value, decimals = 2) => {
  return `${value.toFixed(decimals)}%`;
};

export const timeAgo = (date) => {
  const now = new Date();
  const diffMs = now - new Date(date);
  const diffMins = Math.floor(diffMs / 60000);
  const diffHours = Math.floor(diffMs / 3600000);
  const diffDays = Math.floor(diffMs / 86400000);

  if (diffMins < 60) return `Hace ${diffMins} minuto${diffMins !== 1 ? 's' : ''}`;
  if (diffHours < 24) return `Hace ${diffHours} hora${diffHours !== 1 ? 's' : ''}`;
  return `Hace ${diffDays} día${diffDays !== 1 ? 's' : ''}`;
};
```

---

### 8.3 Testing Manual (2h)

**Checklist de pruebas**:
- [ ] Login correcto
- [ ] Login incorrecto (credenciales inválidas)
- [ ] Logout limpia tokens
- [ ] Token expirado → refresh automático
- [ ] Dashboard carga stats reales
- [ ] Préstamos lista funcional
- [ ] Préstamos filtros funcionan
- [ ] Préstamos búsqueda funciona
- [ ] Aprobar préstamo funciona
- [ ] Rechazar préstamo funciona
- [ ] Ver detalle de préstamo
- [ ] Pagos lista por préstamo
- [ ] Marcar pago como pagado
- [ ] Statements lista con filtros
- [ ] Marcar statement como pagado

---

### 8.4 Code Review & Refactor (1h)

**Checklist**:
- [ ] Eliminar código comentado
- [ ] Eliminar console.log innecesarios
- [ ] Revisar nombres de variables
- [ ] Verificar imports ordenados
- [ ] Verificar CSS no duplicado
- [ ] Eliminar archivos mock (loans.json.js, etc)
- [ ] Actualizar ARQUITECTURA.md
- [ ] Actualizar README.md

---

## 📈 CRONOGRAMA DETALLADO

### Semana 1

| Día | Fase | Horas | Tareas |
|-----|------|-------|--------|
| **Lunes** | Fase 1 | 4h | API Client + Services |
| **Martes** | Fase 2 + 3 | 4h | Auth mejorado + Dashboard real |
| **Miércoles** | Fase 4 | 4h | Loans lista + aprobar/rechazar |
| **Jueves** | Fase 4 | 2h | Loans modales + polish |

### Semana 2

| Día | Fase | Horas | Tareas |
|-----|------|-------|--------|
| **Lunes** | Fase 5 | 4h | Módulo Payments completo |
| **Martes** | Fase 6 | 4h | Módulo Statements completo |
| **Miércoles** | Fase 7 | 4h | UI Components + Toast |
| **Jueves** | Fase 8 | 6h | Error handling + Testing + Polish |

**Total**: 32 horas

---

## 🎯 CRITERIOS DE ÉXITO

### ✅ Fase completada cuando:

1. **API Client**
   - ✅ axios configurado con base URL desde .env
   - ✅ Interceptor auth agrega token automáticamente
   - ✅ Interceptor refresh actualiza token expirado
   - ✅ Manejo de errores centralizado

2. **Auth**
   - ✅ Login conecta a backend real
   - ✅ Tokens se guardan en localStorage
   - ✅ Refresh token automático funciona
   - ✅ Logout limpia todo

3. **Dashboard**
   - ✅ Stats cards muestran datos reales
   - ✅ Actividad reciente es real
   - ✅ Loading state mientras carga
   - ✅ Error state si falla

4. **Préstamos**
   - ✅ Lista conectada a backend
   - ✅ Filtros funcionan (status)
   - ✅ Búsqueda funciona (id, nombre)
   - ✅ Aprobar préstamo funciona
   - ✅ Rechazar préstamo funciona
   - ✅ Modal de detalle muestra info completa

5. **Pagos**
   - ✅ Lista de pagos por préstamo
   - ✅ Marcar como pagado funciona
   - ✅ Tabla actualiza después de cambio

6. **Statements**
   - ✅ Lista con filtros por status
   - ✅ Marcar como pagado funciona
   - ✅ Tabla actualiza después de cambio

7. **UI/UX**
   - ✅ Spinner/Skeleton en loading states
   - ✅ Toast notifications en acciones
   - ✅ Error boundary captura crashes
   - ✅ Modal component reutilizable

---

## 🔧 DEPENDENCIAS A INSTALAR

```bash
cd frontend-mvp

# HTTP Client
npm install axios

# Notifications
npm install react-hot-toast

# Date handling (opcional)
npm install date-fns

# Icons (opcional)
npm install lucide-react
```

---

## 📝 NOTAS IMPORTANTES

### 1. Migración Gradual
- No eliminar archivos mock hasta verificar que la nueva versión funciona
- Mantener ambas versiones (mock y real) durante desarrollo
- Variable de entorno `VITE_ENABLE_MOCK=false` para controlar

### 2. Manejo de Errores
- Todos los servicios deben usar try/catch
- Mostrar toast.error en caso de fallo
- Logging en consola para debugging

### 3. Loading States
- Todas las llamadas async deben tener loading state
- Usar Spinner o Skeleton según contexto
- Deshabilitar botones durante operaciones

### 4. Consistencia
- Usar formatters.js para fechas y monedas
- Usar mismos estilos de badges y botones
- Mantener nomenclatura consistente

---

## ✅ CHECKLIST FINAL

### Configuración
- [ ] Crear `.env` con `VITE_API_URL`
- [ ] Actualizar `vite.config.js`
- [ ] Instalar axios
- [ ] Instalar react-hot-toast

### API Layer
- [ ] Crear `apiClient.js` con axios
- [ ] Crear `endpoints.js` con rutas
- [ ] Crear todos los services (auth, dashboard, loans, payments, statements)
- [ ] Configurar interceptors (auth + refresh)

### Módulos Frontend
- [ ] Auth: login mejorado con refresh
- [ ] Dashboard: datos reales
- [ ] Loans: CRUD + aprobar/rechazar
- [ ] Payments: lista + marcar pagado
- [ ] Statements: lista + gestión

### UI/UX
- [ ] Spinner component
- [ ] Skeleton component
- [ ] Toast notifications integradas
- [ ] Modal base component
- [ ] Error boundary

### Testing & Polish
- [ ] Pruebas manuales completas
- [ ] Eliminar código mock
- [ ] Actualizar documentación
- [ ] Code review final

---

**Última actualización**: 2025-11-06  
**Próximo paso**: Ejecutar Fase 1 - Infraestructura API
