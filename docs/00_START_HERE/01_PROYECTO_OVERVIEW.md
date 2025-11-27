# 01 - Overview del Proyecto Credinet v2.0

## 🎯 ¿Qué es Credinet?

**Credinet** es una plataforma de **microcréditos quincenales** operada por asociados independientes.

### Modelo de Negocio

```
CREDICUENTA (empresa)
    ↓ otorga línea de crédito
ASOCIADOS (intermediarios)
    ↓ otorgan préstamos con ese crédito
CLIENTES (usuarios finales)
    ↓ pagan quincenalmente
ASOCIADOS (cobran y pagan comisión)
    ↓ entregan pagos menos comisión
CREDICUENTA (recibe capital + comisión)
```

### Características Principales

- 💰 **Préstamos**: $3,000 - $60,000
- 📅 **Plazo**: 6, 12, 18 o 24 quincenas (3, 6, 9 o 12 meses) - **Flexible en v2.0**
- 📊 **Interés**: Simple, NO compuesto
- 🔄 **Pagos**: Cada 15 días (día 15 o día 30/31)
- 👥 **Asociados**: Tienen línea de crédito global
- 📄 **Relaciones de pago**: Documento quincenal automático

---

## 👥 Actores del Sistema

### 1. Admin (Gerente de Credicuenta)
**Permisos**:
- ✅ Gestiona asociados (alta, crédito, niveles)
- ✅ Aprueba préstamos grandes
- ✅ Ve todos los reportes
- ✅ Genera relaciones de pago
- ✅ Registra entregas de asociados
- ✅ Gestiona mora y deudas

**Casos de uso principales**:
- Crear asociado con línea de crédito
- Ver dashboard ejecutivo
- Generar corte quincenal (días 8 y 23)
- Revisar morosidad

### 2. Asociado (Intermediario)
**Permisos**:
- ✅ Crea clientes
- ✅ Solicita préstamos para sus clientes
- ✅ Cobra pagos quincenales
- ✅ Registra pagos en el sistema
- ✅ Ve su estado de cuenta
- ✅ Ve su crédito disponible

**Casos de uso principales**:
- Solicitar préstamo para cliente
- Registrar pago de cliente
- Ver relación de pago quincenal
- Consultar crédito disponible

### 3. Cliente (Usuario final)
**Permisos**:
- ✅ Ve su préstamo activo
- ✅ Ve su tabla de pagos
- ✅ Ve su historial

**Casos de uso principales**:
- Ver cuánto debe
- Ver fechas de pago
- Consultar saldo

---

## 🏗️ Stack Tecnológico

### Backend
- **Framework**: FastAPI 0.104+
- **Base de datos**: PostgreSQL 15
- **ORM**: SQLAlchemy 2.0
- **Auth**: JWT (python-jose)
- **Testing**: pytest
- **Docs**: OpenAPI / Swagger automático

### Frontend
- **Framework**: React 18
- **Build tool**: Vite 7.1 (Rolldown)
- **Router**: React Router 6
- **Arquitectura**: Feature-Sliced Design (FSD)
- **State**: useState + Context (por ahora)
- **Styling**: CSS Modules

### Infraestructura
- **Containerización**: Docker + Docker Compose
- **Desarrollo**: Hot reload en backend y frontend
- **Base de datos**: PostgreSQL en container con volumen persistente
- **Networking**: Red interna Docker

---

## 📊 Estado Actual del Proyecto

### ✅ Completado (Sprints 1-6)

**Backend**:
- ✅ Autenticación JWT completa
- ✅ Sistema de roles (admin, associate, client)
- ✅ CRUD de usuarios
- ✅ Módulo de asociados con niveles y crédito
- ✅ CRUD de préstamos
- ✅ Sistema de rate_profiles (tasas configurables)
- ✅ Generación automática de payment_schedule
- ✅ Registro de pagos
- ✅ Cálculos de doble tasa
- ✅ Tabla cut_periods (periodos administrativos)

**Base de Datos**:
- ✅ Esquema normalizado
- ✅ 15+ tablas principales
- ✅ Triggers para payment_schedule
- ✅ Función calculate_first_payment_date()
- ✅ Constraints y validaciones

**Frontend MVP**:
- ✅ Diseño desktop-first
- ✅ Feature-Sliced Design implementado
- ✅ Mock API completo
- ✅ Páginas: Dashboard, Préstamos, Login
- ✅ Componentes reutilizables

### 🔄 En Progreso (Sprint 6 - Actual)

**Backend**:
- 🔄 Tabla `associate_payment_statements` (relaciones de pago)
- 🔄 Job automático días 8/23 para generar relaciones
- 🔄 Generación de PDFs

**Frontend**:
- 🔄 Módulo de asociados completo
- 🔄 Página de relaciones de pago
- 🔄 Calculadora de préstamos
- 🔄 Integración con backend real

### ⏳ Pendiente (Sprints 7+)

- ⏳ Módulo de reportes avanzados
- ⏳ Notificaciones automáticas
- ⏳ Dashboard de morosidad
- ⏳ Exportación de datos
- ⏳ App móvil para asociados

---

## 🔑 Conceptos Clave del Negocio

### 1. Doble Calendario ⭐⭐⭐

**Problema**: Clientes pagan en fechas fijas (15/30), pero Credicuenta necesita cortar quincenas en fechas diferentes para operación administrativa.

**Solución**: Dos calendarios simultáneos:

```
CALENDARIO DEL CLIENTE (fechas de pago)
├─ Día 15 del mes
└─ Último día del mes (30 o 31)
   Alternan cada quincena

CALENDARIO ADMINISTRATIVO (cortes)
├─ Periodo A: Día 8-22
└─ Periodo B: Día 23-7
   24 periodos por año
```

**Implementación**:
- Función `calculate_first_payment_date()` sincroniza ambos
- Campo `cut_period_id` en cada pago vincula con periodo administrativo
- Los pagos se agrupan por periodo admin para relaciones de pago

### 2. Doble Tasa ⭐⭐⭐

**Problema**: El asociado presta dinero de Credicuenta, cobra interés al cliente, pero debe pagar comisión a Credicuenta.

**Solución**: Dos tasas diferentes:

```
TASA DEL CLIENTE (interest_rate)
Ejemplo: 4.25% quincenal
→ Cliente paga más

TASA DEL ASOCIADO (commission_rate)  
Ejemplo: 2.5% quincenal
→ Asociado recibe menos

DIFERENCIA = COMISIÓN para Credicuenta
```

**Fórmula**:
```javascript
// Interés simple
total_cliente = capital × (1 + interest_rate × term)
total_asociado = capital × (1 + commission_rate × term)

pago_quincenal_cliente = total_cliente / term
pago_quincenal_asociado = total_asociado / term

comision_por_pago = pago_cliente - pago_asociado
```

### 3. Crédito del Asociado ⭐⭐⭐

**Problema**: ¿Cómo controlar cuánto puede prestar cada asociado?

**Solución**: Línea de crédito global (NO por préstamo):

```
CRÉDITO OTORGADO: $700,000 (límite del asociado)
CRÉDITO UTILIZADO: $552,297 (suma de saldos actuales)
DEUDA ACUMULADA: $0 (mora, comisiones pendientes)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CRÉDITO DISPONIBLE: $147,703 (puede otorgar nuevos préstamos)
```

**Fórmula**:
```javascript
credit_available = credit_limit - credit_used - debt_balance
```

**Dinámica**:
- Al **aprobar** préstamo: `credit_used += monto_total`
- Al **recibir pago**: `credit_used -= capital_pagado`
- Si cliente **no paga**: `debt_balance += monto_adeudado`

### 4. Relaciones de Pago (Estados de Cuenta) ⭐⭐⭐

**Problema**: ¿Cómo sabe el asociado qué cobrar cada quincena?

**Solución**: Documento automático generado cada corte (días 8 y 23):

```
RELACIÓN DE PAGO - MELY RIVERO
Periodo: 23/Sept - 7/Oct/2025

TABLA DE PRÉSTAMOS:
Contrato | Cliente         | Pago Cliente | Pago Asociado
25744    | NORMA LETICIA   | $633.00      | $553.00
25743    | MIGUEL ANGEL    | $1,006.00    | $878.00
...      | ...             | ...          | ...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CANTIDAD RECIBOS: 97
TOTAL PAGO CLIENTE: $103,697.00
TOTAL CORTE: $91,017.00
COMISIÓN: $12,680.00
SEGURO: $380.00
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
TOTAL A PAGAR: $91,397.00
```

**Propósito**:
- **Para el asociado**: Lista de clientes a cobrar
- **Para Credicuenta**: Control de comisiones
- **Para auditoría**: Registro histórico

---

## 📂 Estructura del Proyecto

```
credinet-v2/
├── backend/                    # FastAPI
│   ├── app/
│   │   ├── api/               # Endpoints REST
│   │   ├── models/            # SQLAlchemy models
│   │   ├── schemas/           # Pydantic schemas
│   │   ├── services/          # Business logic
│   │   ├── core/              # Config, security, database
│   │   └── main.py
│   ├── requirements.txt
│   └── pytest.ini
│
├── frontend-mvp/              # React + Vite
│   ├── src/
│   │   ├── app/              # Router, providers
│   │   ├── features/         # Feature-Sliced Design
│   │   │   ├── auth/
│   │   │   ├── dashboard/
│   │   │   ├── loans/
│   │   │   └── payments/
│   │   ├── shared/           # Componentes comunes
│   │   └── services/         # API, mock data
│   └── package.json
│
├── db/                        # Base de datos
│   └── v2.0/
│       └── init.sql          # Esquema completo
│
├── docs/                      # Documentación
│   ├── 00_START_HERE/        # 👈 EMPIEZAS AQUÍ
│   ├── business_logic/       # Lógica de negocio
│   ├── system_architecture/  # Arquitectura técnica
│   ├── guides/               # Guías de desarrollo
│   └── db/                   # Docs de BD
│
└── docker-compose.yml        # Setup completo
```

---

## 🚀 Quick Start

```bash
# 1. Clonar repo
git clone <repo-url>
cd credinet-v2

# 2. Levantar todo
docker compose up -d

# 3. Verificar
docker compose ps
# Deberías ver: postgres (healthy), backend (healthy), frontend (healthy)

# 4. Acceder
# Backend: http://localhost:8000/docs (Swagger)
# Frontend: http://localhost:5173
# PostgreSQL: localhost:5432 (user: credinet, pass: credinet123)

# 5. Login default
# Email: admin@credicuenta.com
# Password: Admin123!
```

---

## 🎓 Recursos de Aprendizaje

### Para entender el negocio
1. [`../business_logic/INDICE_MAESTRO.md`](../business_logic/INDICE_MAESTRO.md) - LOS 6 PILARES
2. [`../business_logic/payment_statements/README.md`](../business_logic/payment_statements/README.md) - Relaciones de pago
3. PDFs reales en [`../guides/`](../guides/) (MELY.pdf, CLAUDIA.pdf, PILAR.pdf)

### Para entender la arquitectura
1. [`02_ARQUITECTURA_STACK.md`](./02_ARQUITECTURA_STACK.md) - Stack completo
2. [`../system_architecture/02_database_schema.md`](../system_architecture/02_database_schema.md) - Esquema BD
3. [`../DOCKER.md`](../DOCKER.md) - Setup Docker

### Para desarrollar
1. [`../DEVELOPMENT.md`](../DEVELOPMENT.md) - Setup de desarrollo
2. [`../guides/01_major_refactoring_protocol.md`](../guides/01_major_refactoring_protocol.md) - Protocolo refactoring
3. [`05_WORKFLOWS_COMUNES.md`](./05_WORKFLOWS_COMUNES.md) - Comandos útiles

---

**Siguiente**: [`02_ARQUITECTURA_STACK.md`](./02_ARQUITECTURA_STACK.md)
