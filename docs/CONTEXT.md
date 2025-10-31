# 📊 CREDINET - CONTEXTO INTEGRAL DEL PROYECTO

## 🎯 VISIÓN GENERAL

**Credinet** es un sistema integral de gestión de préstamos desarrollado para CrediCuenta, que maneja el ciclo completo desde solicitud hasta liquidación, incluyendo cálculo de comisiones para asociados.

### Estado Actual
- ✅ **Sistema 100% operativo** en entorno remoto SSH (192.168.98.98)
- ✅ **Clean Architecture implementada** sin dependencias legacy
- ✅ **Frontend V2.0 completado** con validación CURP avanzada
- ✅ **Docker containerization** completa y funcional

---

## 🏗️ ARQUITECTURA TÉCNICA

### Stack Tecnológico
```yaml
Backend:
  - FastAPI + Python 3.11
  - Clean Architecture pattern
  - asyncpg + PostgreSQL 15
  - JWT authentication
  - Puerto: 8001

Frontend:
  - React 18 + Vite
  - Formularios V2.0 sin legacy
  - Direct Clean Architecture endpoints
  - Puerto: 5174

Database:
  - PostgreSQL 15
  - Esquema 3NF normalizado
  - Seeds incluidos
  - Puerto: 5432

Deployment:
  - Docker Compose
  - Hot reload activado
  - Entorno SSH remoto
```

### Servicios Docker
```bash
credinet_backend    # FastAPI API
credinet_frontend   # React SPA
credinet_db         # PostgreSQL
credinet_smoke_tester # Testing automático
```

---

## 🔐 SISTEMA DE AUTENTICACIÓN

### Credenciales Universales
```yaml
Administrador:
  username: admin
  password: Sparrow20
  roles: [administrador]

Asociado:
  username: asociado_test
  password: Sparrow20
  roles: [asociado]

Cliente:
  username: sofia.vargas
  password: Sparrow20
  roles: [cliente]
```

### Tecnología Auth
- **JWT Bearer tokens** con expiración
- **bcrypt** para hashing de contraseñas
- **Role-based access control** implementado

---

## 📋 API ENDPOINTS PRINCIPALES

### 🔐 Auth & Users (`/api/auth`)
```http
POST /api/auth/login                    # Login con form-data
POST /api/auth/users                    # Crear usuario (cliente/asociado)
GET  /api/auth/users/search             # Buscar usuarios
GET  /api/auth/users/{id}               # Usuario específico
GET  /api/auth/me                       # Usuario actual
```

### 🛠️ Utilities (`/api/utils`)
```http
GET /api/utils/check-curp/{curp}        # Verificar CURP existe
GET /api/utils/check-username/{user}    # Verificar username
GET /api/utils/check-phone/{phone}      # Verificar teléfono
GET /api/utils/check-email/{email}      # Verificar email
GET /api/utils/zip-code/{code}          # Info código postal
```

### 💰 Loans (`/api/loans`)
```http
POST /api/loans                         # Crear préstamo
GET  /api/loans                         # Listar préstamos
POST /api/loans/payment-preview         # Preview pagos (requiere body con datos)
GET  /api/loans/{id}                    # Obtener préstamo específico
POST /api/loans/{id}/approve            # Aprobar préstamo
GET  /api/loans/health                  # Health check
```

### 🏢 Associates (`/api/associates`)
```http
POST /api/associates                    # Crear asociado
GET  /api/associates                    # Listar asociados
GET  /api/associates/search             # Buscar asociados
```

---

## 🎨 FRONTEND V2.0 - CARACTERÍSTICAS CLAVE

### 🔍 Validación CURP Avanzada
```yaml
Funcionalidades:
  - Generación automática desde datos personales
  - Modal administrativo con desglose visual
  - Edición de homoclave (últimos 2 dígitos)
  - Validación contra base de datos en tiempo real
  - Resolución de conflictos de CURP duplicada
  - Estados visuales claros (pendiente/validada/error)
```

### 📝 Formularios Inteligentes
```yaml
Características:
  - Validación en tiempo real
  - Auto-generación de username único
  - Auto-generación de contraseñas desde CURP
  - Lookup automático de códigos postales
  - Secciones colapsables con indicadores de progreso
  - Dark mode support
  - Responsive design mobile-first
```

### 🔄 Integración API Sin Legacy
```yaml
Mejoras:
  - Conexión directa a Clean Architecture
  - Sin capas de compatibilidad
  - Manejo robusto de errores
  - Interceptores JWT automáticos
  - Performance optimizada
  - Type safety con Pydantic schemas
```

---

## 🗃️ ESTRUCTURA BASE DE DATOS

### Tablas Principales
```sql
-- Usuarios y Roles
users, user_roles, associates, associate_levels

-- Préstamos y Pagos  
loans, payments, contracts

-- Documentos y Direcciones
documents, client_documents, addresses

-- Beneficiarios y Avales
beneficiaries, guarantors

-- Sistema de Cortes
cutoff_periods, cutoff_assignments
```

### Características DB
- **Normalización 3NF** completa
- **Foreign keys** y constraints de integridad
- **Triggers automáticos** para timestamps
- **Índices optimizados** en campos de búsqueda
- **Seeds incluidos** para testing

---

## 💼 LÓGICA DE NEGOCIO CRÍTICA

### Sistema de Préstamos
```yaml
Frecuencia: Solo quincenal (eliminado mensual)
Cálculo: Amortización capital + intereses
Fechas: PreciseCutoffService con manejo fines de semana
Estados: PENDING, ACTIVE, COMPLETED, DEFAULTED, CANCELLED
Períodos de Gracia: Implementados
```

### Roles de Usuario
```yaml
Administrador: Control total del sistema
Asociado: Crear préstamos, ganar comisiones por niveles
Cliente: Solicitar préstamos, realizar pagos
```

### Validaciones Obligatorias
- **CURP única** y validada para todos los usuarios
- **Username único** con verificación en tiempo real
- **Email y teléfono únicos** en el sistema
- **Documentos obligatorios** según tipo de usuario

---

## 🚀 FLUJO DE DESARROLLO

### Comandos Esenciales
```bash
# Restart completo (OBLIGATORIO tras cambios)
docker compose down -v && docker compose up --build

# Verificar estado
docker compose ps

# Ver logs
docker logs -f credinet_backend
docker logs -f credinet_frontend

# Queries SQL
docker exec credinet_db psql -U credinet_user -d credinet_db -c "SELECT COUNT(*) FROM users;"
```

### URLs de Acceso
```yaml
Frontend: http://192.168.98.98:5174
Backend API: http://192.168.98.98:8001
API Docs: http://192.168.98.98:8001/docs
Database: localhost:5432 (desde contenedores)
```

### Git Workflow
```yaml
main: Solo código de producción
develop: Rama principal de desarrollo  
feature/*: Nuevas funcionalidades
```

---

## ⚡ FUNCIONALIDADES IMPLEMENTADAS

### ✅ Completado y Funcional
- [x] Sistema de autenticación JWT completo
- [x] Formulario cliente V2.0 sin legacy
- [x] Validación CURP con modal administrativo
- [x] Edición de homoclave para resolver conflictos
- [x] Validaciones en tiempo real (username, email, phone)
- [x] Sistema de códigos postales automático
- [x] Clean Architecture backend completa
- [x] Docker containerization funcional
- [x] Base de datos normalizada con seeds
- [x] Smoke testing automático

### 🔄 En Progreso/Pendiente
- [ ] Automatización de contratos al aprobar préstamo
- [ ] Casos de uso faltantes (RejectLoan, CancelLoan)
- [ ] Generación automática de PDFs de contrato
- [ ] Sistema de notificaciones automáticas
- [ ] Seguimiento automático de pagos
- [ ] Testing exhaustivo de todos los flujos

---

## 🎯 CASOS DE USO IMPLEMENTADOS

### Backend Clean Architecture
```python
# ✅ Implementados
CreateLoanUseCase
ApproveLoanUseCase
DisburseLoanUseCase
CalculateAmortizationUseCase
GetLoanUseCase

# ❌ Faltantes
RejectLoanUseCase
CancelLoanUseCase
DefaultLoanUseCase
CompletePaymentUseCase
GenerateContractUseCase (automático)
```

---

## 🔍 TESTING Y MONITOREO

### Smoke Testing Automático
```yaml
Servicio: credinet_smoke_tester
Ejecuta: Validación automática post-deployment
Valida: 
  - Conectividad de servicios
  - Endpoints principales
  - Autenticación funcional
  - Base de datos accesible
```

### Health Checks
```yaml
Backend: GET /api/ping
Loans: GET /api/loans/health
Database: SELECT 1 FROM users
Frontend: HTTP 200 response
```

---

## 📚 DOCUMENTACIÓN PRINCIPAL

### Archivos Clave
```yaml
README.md: Información general
FRONTEND_V2_COMPLETADO.md: Estado frontend V2.0
SISTEMA_VERIFICADO.md: Verificación completa
ANALISIS_PROFUNDO_SISTEMA_CORE.md: Análisis arquitectura
docs/CONTEXTO_GENERAL.md: Contexto y propósito
DOCKER_DEVELOPMENT_GUIDE.md: Guía Docker
```

### Estructura Documentación
```
docs/
├── system_architecture/    # Diagramas y arquitectura
├── business_logic/         # Reglas de negocio
├── guides/                 # Procedimientos desarrollo
└── onboarding/             # Guías nuevos desarrolladores
```

---

## 🎪 DEMOSTRACIÓN DEL SISTEMA

### Flujo Cliente Completo
1. **Acceder**: `http://192.168.98.98:5174/clients/new`
2. **Datos Personales**: Llenar nombre, apellidos, fecha nacimiento
3. **CURP**: Auto-generación + validación modal administrativo
4. **Cuenta**: Username auto-generado + password desde CURP
5. **Dirección**: Código postal con lookup automático
6. **Beneficiario/Aval**: Opcional con auto-CURP
7. **Envío**: Direct call a `/api/auth/users`

### Validaciones en Tiempo Real
- ✅ CURP única con edición de homoclave
- ✅ Username disponibilidad instantánea
- ✅ Email verificación contra BD
- ✅ Teléfono unicidad
- ✅ Códigos postales automáticos

---

## 🏆 LOGROS TÉCNICOS PRINCIPALES

### Eliminación Completa de Legacy
- 🚫 **Eliminado**: `legacyApiAdapter.js`, capas compatibilidad
- ✅ **Creado**: Frontend directo Clean Architecture
- 🎯 **Replicado**: Funcionalidad original + mejoras
- 🚀 **Resultado**: Código limpio, mantenible, extensible

### Performance y Maintainability
- ⚡ **Sin capas wrapper**: Calls directos a API
- 🔧 **Type safety**: Pydantic schemas
- 🎨 **Modern UX**: Estados visuales, animaciones
- 📱 **Responsive**: Mobile-first design

---

## 🚨 REGLAS FUNDAMENTALES DEL PROYECTO

### 1. Reconstrucción Docker Obligatoria
```bash
# SIEMPRE ejecutar tras CUALQUIER cambio
docker compose down -v && docker compose up --build
```

### 2. Entorno Remoto SSH
```yaml
IP: 192.168.98.98
Acceso: VS Code SSH remoto
Configuración: Docker-only sin .venv local
```

### 3. Consultas SQL Sin -t
```bash
# CORRECTO
docker exec credinet_db psql -U credinet_user -d credinet_db -c "QUERY;"

# INCORRECTO (se cuelga)
docker exec -it credinet_db psql
```

---

## 📊 MÉTRICAS DE ÉXITO

### Técnicas
- [x] 100% Clean Architecture implementada
- [x] 0 dependencias legacy en frontend V2.0
- [x] Todos los contenedores Docker funcionando
- [x] API endpoints respondiendo correctamente
- [x] Validaciones CURP funcionando perfectamente

### Funcionales
- [x] Formulario cliente completamente operativo
- [x] Validaciones tiempo real funcionando
- [x] Sistema autenticación robusto
- [x] Base datos completamente normalizada
- [x] Smoke tests automáticos pasando

---

> **🎉 SISTEMA CREDINET - ESTADO: TOTALMENTE OPERATIVO**  
> Clean Architecture implementada, Frontend V2.0 sin legacy, Docker funcionando.  
> Listo para desarrollo continuo y nuevas funcionalidades.