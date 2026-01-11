# 🚀 PLAN MVP CRÍTICO - CrediNet v2.0

**Fecha**: 6 Noviembre 2025  
**Objetivo**: MVP funcional en **48-72 horas**  
**Status Backend**: ✅ 95% completo  
**Status Frontend**: ⚠️ 30% completo (bloqueo crítico)

---

## 🗑️ LIMPIEZA INMEDIATA (30 min)

### Archivos Basura Detectados:

```bash
# 1. DOCUMENTACIÓN OBSOLETA (596KB)
rm -rf /home/credicuenta/proyectos/credinet-v2/docs/_OBSOLETE

# 2. CACHE PYTHON (111 carpetas)
find /home/credicuenta/proyectos/credinet-v2 -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null

# 3. NODE_MODULES DUPLICADOS
# Mantener solo: frontend-mvp/node_modules
# Eliminar: frontend/node_modules (carpeta legacy)

# 4. DOCUMENTACIÓN REDUNDANTE (102 archivos .md)
# Mantener solo:
# - README.md (raíz)
# - docs/AUDITORIA_IMPLEMENTACION_SPRINT6.md (recién creado)
# - docs/GUIA_BACKEND_V2.0.md
# - frontend-mvp/README.md
# Archivar resto a docs/_ARCHIVE/
```

**Impacto**: Libera ~200MB, reduce ruido en búsquedas, acelera indexación IDE

---

## 🎯 CAMINO CRÍTICO PARA MVP (Prioridad P0)

### ✅ BACKEND: 95% COMPLETO (Solo falta integración)

**Lo que YA tienes funcionando**:
- ✅ 15 módulos con Clean Architecture
- ✅ ~50 endpoints REST API operativos
- ✅ Autenticación JWT
- ✅ Base de datos con datos de prueba
- ✅ Docker Compose configurado
- ✅ CORS configurado

**Falta CRÍTICO para MVP** (2-3 horas):

1. **Endpoints de Creación Faltantes** (P0 - 1 hora):
   ```python
   # POST /api/v1/loans - CREAR préstamo (ya existe pero sin validación completa)
   # POST /api/v1/payments/mark - MARCAR pago como pagado
   # PUT /api/v1/loans/{id}/approve - APROBAR préstamo
   # PUT /api/v1/loans/{id}/reject - RECHAZAR préstamo
   ```

2. **Endpoint de Dashboard** (P0 - 30 min):
   ```python
   # GET /api/v1/dashboard/stats
   # Retorna: total_loans, active_loans, pending_payments, total_collected
   ```

3. **Middleware de Autenticación en Rutas** (P0 - 30 min):
   ```python
   # Agregar dependency en rutas protegidas:
   # current_user: User = Depends(get_current_user)
   ```

4. **Validación de Negocio** (P1 - 1 hora):
   - No aprobar préstamos si asociado sin crédito disponible
   - No marcar pago si ya está pagado
   - No crear préstamo con monto > límite del rate_profile

---

## 🔥 FRONTEND MVP: BLOQUEO CRÍTICO (12-18 horas)

### Estado Actual:
- ✅ Frontend corriendo en `localhost:5173`
- ✅ Vite + React 18 configurado
- ✅ Estructura FSD (Feature-Sliced Design)
- ⚠️ **PERO**: No hay pantallas funcionales conectadas al backend

### PLAN DE ATAQUE FRONTEND (Prioridad absoluta):

#### **FASE 1: Autenticación** (2 horas) - P0
```bash
frontend-mvp/src/
├── features/auth/
│   ├── Login.jsx          # Formulario login
│   ├── useAuth.js         # Hook autenticación
│   └── authService.js     # Llamadas API
├── app/AuthProvider.jsx   # Context global
└── utils/api.js           # Axios configurado
```

**Tareas**:
- [ ] Crear servicio API con axios + baseURL
- [ ] Implementar login form (username, password)
- [ ] Guardar JWT en localStorage
- [ ] Crear AuthContext para estado global
- [ ] Redirigir a /dashboard después de login

#### **FASE 2: Dashboard Principal** (3 horas) - P0
```bash
frontend-mvp/src/
├── pages/Dashboard.jsx
├── components/
│   ├── StatCard.jsx       # Tarjeta de estadística
│   ├── RecentLoans.jsx    # Lista últimos préstamos
│   └── PendingPayments.jsx # Pagos pendientes
└── services/
    └── dashboardService.js
```

**Métricas a mostrar**:
- Total préstamos activos
- Total cobrado este mes
- Pagos pendientes hoy
- Préstamos por aprobar

#### **FASE 3: Gestión de Préstamos** (4 horas) - P0
```bash
frontend-mvp/src/
├── pages/
│   ├── LoansListPage.jsx     # Lista paginada
│   ├── LoanDetailPage.jsx    # Detalle + cronograma
│   └── CreateLoanPage.jsx    # Formulario creación
├── features/loans/
│   ├── LoanForm.jsx
│   ├── LoanTable.jsx
│   ├── PaymentSchedule.jsx
│   └── loansService.js
└── components/
    └── LoanStatusBadge.jsx
```

**Flujo MVP**:
1. Ver lista de préstamos
2. Filtrar por estado (PENDING, APPROVED, ACTIVE)
3. Ver detalle de préstamo con cronograma
4. Aprobar/Rechazar préstamo (admin)
5. Crear nuevo préstamo (formulario básico)

#### **FASE 4: Pagos** (3 horas) - P0
```bash
frontend-mvp/src/
├── pages/
│   ├── PaymentsListPage.jsx
│   └── MarkPaymentPage.jsx
├── features/payments/
│   ├── PaymentTable.jsx
│   ├── MarkPaymentModal.jsx
│   └── paymentsService.js
└── components/
    └── PaymentStatusBadge.jsx
```

**Funcionalidad**:
1. Ver cronograma de pagos de un préstamo
2. Marcar pago como pagado
3. Ver historial de pagos realizados
4. Filtrar pagos vencidos

---

## 📋 ROADMAP MVP DETALLADO

### DÍA 1 (8 horas) - BACKEND + INICIO FRONTEND

**Mañana (4h)** - Backend Crítico:
- ✅ Limpiar archivos basura (30 min)
- ⏱️ Crear endpoints faltantes (1h 30min)
- ⏱️ Agregar middleware auth (30 min)
- ⏱️ Endpoint dashboard stats (30 min)
- ⏱️ Validaciones de negocio (1h)

**Tarde (4h)** - Frontend Base:
- ⏱️ Configurar axios + API client (30 min)
- ⏱️ Implementar Login + AuthContext (1h 30min)
- ⏱️ Crear Dashboard layout (1h)
- ⏱️ Conectar dashboard con stats endpoint (1h)

**Entregable EOD**: Login funcional + Dashboard con métricas reales

---

### DÍA 2 (8 horas) - FUNCIONALIDAD CORE

**Mañana (4h)** - Préstamos:
- ⏱️ Lista de préstamos (tabla paginada) (2h)
- ⏱️ Detalle de préstamo + cronograma (2h)

**Tarde (4h)** - Aprobación y Creación:
- ⏱️ Botones Aprobar/Rechazar + modal confirmación (1h 30min)
- ⏱️ Formulario crear préstamo básico (2h 30min)

**Entregable EOD**: Flujo completo préstamos (ver, crear, aprobar)

---

### DÍA 3 (6-8 horas) - PAGOS + POLISH

**Mañana (4h)** - Pagos:
- ⏱️ Tabla de cronograma de pagos (1h 30min)
- ⏱️ Modal marcar pago (1h)
- ⏱️ Integración con endpoint (1h 30min)

**Tarde (2-4h)** - Polish + Testing:
- ⏱️ Mensajes de error/éxito (30 min)
- ⏱️ Loading states (30 min)
- ⏱️ Responsive básico (1h)
- ⏱️ Testing manual de flujos (1-2h)

**Entregable EOD**: ✅ **MVP FUNCIONAL COMPLETO**

---

## 🎯 SCOPE MVP MÍNIMO (Lo que DEBE funcionar)

### Usuario Admin/Asociado:
1. ✅ Login → Dashboard
2. ✅ Ver lista de préstamos
3. ✅ Ver detalle de préstamo con cronograma
4. ✅ Aprobar/Rechazar préstamo pendiente
5. ✅ Marcar pago como cobrado
6. ✅ Ver métricas básicas

### Usuario Cliente (futuro):
- ❌ No incluir en MVP
- Implementar en Fase 2

---

## 🚫 FUERA DE SCOPE MVP

**NO implementar ahora** (posponer para v2):
- ❌ Módulo de garantors (ya existe en backend, no UI)
- ❌ Módulo de beneficiaries (ya existe en backend, no UI)
- ❌ Módulo de addresses (ya existe en backend, no UI)
- ❌ Módulo de contracts (ya existe en backend, no UI)
- ❌ Módulo de agreements (ya existe en backend, no UI)
- ❌ Módulo de documents (ya existe en backend, no UI)
- ❌ Módulo de audit (ya existe en backend, no UI)
- ❌ Perfiles de usuario completos
- ❌ Reportes avanzados
- ❌ Notificaciones
- ❌ Exportación Excel/PDF
- ❌ Búsqueda avanzada
- ❌ Filtros complejos
- ❌ Tema oscuro
- ❌ Internacionalización
- ❌ Tests automatizados (solo manuales por ahora)

---

## 🛠️ STACK TECNOLÓGICO MVP

### Backend (Ya implementado):
- ✅ FastAPI 0.104+
- ✅ SQLAlchemy 2.x (async)
- ✅ PostgreSQL 15
- ✅ JWT autenticación
- ✅ Docker Compose

### Frontend (A implementar):
- ✅ React 18
- ✅ Vite 5
- ⏱️ Axios (HTTP client)
- ⏱️ React Router v6
- ⏱️ Tailwind CSS o Material-UI (decidir)
- ⏱️ React Hook Form (formularios)
- ⏱️ date-fns (manejo fechas)

---

## 📊 CRITERIOS DE ÉXITO MVP

### Técnicos:
- [ ] Login funcional con JWT
- [ ] Dashboard muestra datos reales de BD
- [ ] CRUD préstamos operativo
- [ ] Aprobación de préstamos funciona
- [ ] Marcar pagos funciona
- [ ] Cero errores 500 en consola
- [ ] Tiempo de respuesta < 2s

### Negocio:
- [ ] Asociado puede ver sus préstamos activos
- [ ] Asociado puede aprobar préstamos nuevos
- [ ] Asociado puede registrar pagos cobrados
- [ ] Sistema refleja montos correctos
- [ ] Cronograma de pagos se muestra correctamente

---

## 🚀 SIGUIENTES PASOS INMEDIATOS

### AHORA MISMO (Siguiente 1 hora):

```bash
# 1. Limpiar archivos basura (10 min)
rm -rf docs/_OBSOLETE
find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null

# 2. Crear endpoint dashboard (30 min)
# backend/app/modules/dashboard/routes.py

# 3. Configurar axios en frontend (20 min)
# frontend-mvp/src/utils/api.js
```

### SIGUIENTES 4 HORAS:

1. **Backend** (1h):
   - Endpoint POST /api/v1/payments/mark
   - Endpoint PUT /api/v1/loans/{id}/approve
   - Middleware autenticación en rutas

2. **Frontend** (3h):
   - Login form + AuthContext
   - Dashboard con stats reales
   - Layout base con navegación

---

## 💡 DECISIONES TÉCNICAS CRÍTICAS

### 1. Librería UI:
**Recomendación**: **Tailwind CSS**
- Razón: Ya configurado en proyecto, más rápido que Material-UI
- Alternativa: Headless UI + Tailwind para componentes

### 2. Manejo de Estado:
**Recomendación**: **React Context + Custom Hooks**
- Razón: Suficiente para MVP, evita overhead de Redux
- Usar Context solo para: Auth, Theme (futuro)

### 3. Validación Formularios:
**Recomendación**: **React Hook Form**
- Razón: Menos re-renders, mejor performance

### 4. Tablas:
**Recomendación**: **TanStack Table (React Table v8)**
- Razón: Paginación, sorting built-in

---

## ⚠️ RIESGOS Y MITIGACIONES

| Riesgo | Probabilidad | Impacto | Mitigación |
|--------|--------------|---------|------------|
| Frontend toma más tiempo | Alta | Alto | Usar componentes pre-built (Shadcn/ui) |
| Bugs en validaciones negocio | Media | Medio | Testing manual exhaustivo |
| Performance con muchos datos | Baja | Medio | Paginación en todas las listas |
| CORS issues | Baja | Alto | Ya configurado en backend |

---

## 📈 MÉTRICAS DE AVANCE

### Checklist Diario:

**Día 1**:
- [ ] Login funcional
- [ ] Dashboard con 4 métricas
- [ ] Navbar con logout

**Día 2**:
- [ ] Lista préstamos (mínimo 10 visibles)
- [ ] Detalle préstamo con cronograma
- [ ] Aprobar préstamo funciona

**Día 3**:
- [ ] Marcar pago funciona
- [ ] Todas las pantallas responsive
- [ ] Testing manual 100% pasado

---

## 🎉 ENTREGABLE FINAL MVP

**URL Demo**: `http://localhost:5173`  
**Backend API**: `http://localhost:8000/docs`

**Usuarios de Prueba**:
```
Admin:
  username: admin
  password: (verificar en BD)

Asociado:
  username: asociado1
  password: (verificar en BD)
```

**Video Demo** (2-3 min):
1. Login
2. Ver dashboard
3. Aprobar préstamo
4. Ver cronograma
5. Marcar pago

---

## 📞 PREGUNTAS CLAVE PARA DECIDIR

1. **¿Qué librería UI prefieres?** (Tailwind / Material-UI / Ant Design)
2. **¿Cliente también debe poder ver sus préstamos?** (Sí/No para MVP)
3. **¿Necesitas crear USUARIOS desde UI?** (Sí/No para MVP)
4. **¿Deadline exacto?** (48h / 72h / 1 semana)

---

**PRÓXIMO COMANDO**:
```bash
# Empezar con limpieza + endpoint dashboard
# ¿Procedo? (Sí/No)
```
