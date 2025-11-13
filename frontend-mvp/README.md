# 🚀 CrediNet V2 - Frontend MVP

**Versión**: 1.0  
**Framework**: React 18 + Vite 7.1.14 (Rolldown)  
**Estado**: ✅ Login implementado con autenticación real

---

## 🎯 Propósito

Frontend MVP con:
- ✅ **Autenticación real** contra backend FastAPI
- ✅ Mock data para desarrollo independiente
- ✅ Diseño moderno con animaciones
- ✅ Acceso desde LAN (192.168.98.98:5174)

---

## 🔑 Credenciales de Prueba

```
Usuario: admin
Contraseña: admin123
```

---

## 🚀 Quick Start

### Instalar dependencias
```bash
cd frontend-mvp
npm install
```

### Iniciar servidor de desarrollo
```bash
npm run dev
```

**Acceso**:
- Local: http://localhost:5174/
- LAN: http://192.168.98.98:5174/
- Docker: http://172.28.0.1:5174/

### Verificar backend
```bash
curl http://localhost:8000/health
# {"status":"healthy","version":"2.0.0"}
```

---

## ✨ Funcionalidades Implementadas

### 🔐 Autenticación (Sprint 6)

- [x] Login page con diseño moderno
- [x] Conexión real: `POST /api/auth/login`
- [x] JWT tokens (access 24h, refresh 7d)
- [x] Validaciones de formulario
- [x] Manejo de errores
- [x] Logo React animado
- [x] Utilidades auth (decode JWT, validación tokens)

**Ver documentación completa**: `README_AUTH.md`

### 🎭 Mock API

- [x] 3 préstamos (ids: 4, 5, 6)
- [x] 12 pagos para loan_id=6
- [x] 4 perfiles de tasa
- [x] CRUD completo (381 líneas)

**Uso**:
```javascript
import api from './services/api.js';

const loans = await api.loans.getAll();
await api.loans.approve(5, { associate_id: 2 });
await api.payments.register(46, { amount_paid: 3145.83 });
```

---

## � Estructura del Proyecto

```
frontend-mvp/
├── src/
│   ├── assets/           # react.svg
│   ├── components/       # (próximamente)
│   ├── pages/
│   │   └── LoginPage.jsx # ✅ Login implementado
│   ├── services/
│   │   └── api.js        # Mock API (381 líneas)
│   ├── mocks/
│   │   ├── loans.json.js
│   │   ├── payments.json.js
│   │   └── rateProfiles.json.js
│   ├── styles/
│   │   └── LoginPage.css # Gradientes + animaciones
│   ├── utils/
│   │   └── auth.js       # ✅ JWT utilities
│   ├── App.jsx
│   └── main.jsx
├── vite.config.js        # Config LAN (host: 0.0.0.0)
├── README.md             # Este archivo
└── README_AUTH.md        # ✅ Guía completa de auth
```

---

## 🎨 Documentación

- **Flujos de Usuario**: `/docs/frontend/USER_FLOWS.md` (5 diagramas Mermaid)
- **Autenticación**: `README_AUTH.md`
- **Mock API**: `src/services/api.js` (comentarios inline)

---

## 📋 Próximos Pasos

1. **Routing** (React Router v6)
   - [ ] Setup /login, /dashboard, /loans
   - [ ] Protected routes con JWT

2. **Dashboard**
   - [ ] Bienvenida + métricas
   - [ ] Navegación a secciones
   - [ ] Logout

3. **UI Library**
   - [ ] TailwindCSS + shadcn/ui
   - [ ] Componentes base (Card, Table, Button)

4. **Préstamos**
   - [ ] Lista con filtros
   - [ ] Formulario crear/aprobar
   - [ ] Detalle + calendario pagos

---

**Última actualización**: 2025-11-09  
**Estado**: ✅ Login funcional - Backend conectado  
**Siguiente**: Routing + Dashboard


