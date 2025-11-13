# 🚀 START HERE - Onboarding Completo Credinet v2.0

**Para**: Nueva IA entrando al proyecto  
**Fecha**: 2025-11-05  
**Tiempo de lectura**: 45-60 minutos  
**Orden**: Obligatorio leer en secuencia

---

## 🎯 Instrucciones para la IA

**Lee estos archivos EN ORDEN** (son solo 7 documentos core):

### Paso 1: Contexto General (10 min)
📄 **[`01_PROYECTO_OVERVIEW.md`](./01_PROYECTO_OVERVIEW.md)**
- Qué es Credinet
- Actores del sistema
- Stack tecnológico
- Estado actual del proyecto

### Paso 2: Lógica de Negocio (15 min)
📄 **[`../business_logic/INDICE_MAESTRO.md`](../business_logic/INDICE_MAESTRO.md)**
- Los 6 pilares fundamentales
- Doble calendario
- Doble tasa
- Crédito del asociado
- Relaciones de pago
- Fórmulas matemáticas
- Casos especiales

### Paso 3: Arquitectura Técnica (10 min)
📄 **[`02_ARQUITECTURA_STACK.md`](./02_ARQUITECTURA_STACK.md)**
- Backend: FastAPI + PostgreSQL
- Frontend: React + Vite
- Docker Compose setup
- Estructura de carpetas
- Flujo de datos

### Paso 4: Base de Datos (10 min)
📄 **[`../db/RESUMEN_COMPLETO_v2.0.md`](../db/RESUMEN_COMPLETO_v2.0.md)**
- Esquema completo
- Tablas críticas
- Relaciones
- Migraciones

### Paso 5: APIs y Endpoints (5 min)
📄 **[`03_APIS_PRINCIPALES.md`](./03_APIS_PRINCIPALES.md)**
- Endpoints disponibles
- Autenticación JWT
- Ejemplos de uso

### Paso 6: Frontend (5 min)
📄 **[`04_FRONTEND_ESTRUCTURA.md`](./04_FRONTEND_ESTRUCTURA.md)**
- Feature-Sliced Design
- Componentes principales
- Mock data
- Rutas

### Paso 7: Workflows Comunes (5 min)
📄 **[`05_WORKFLOWS_COMUNES.md`](./05_WORKFLOWS_COMUNES.md)**
- Cómo crear un préstamo
- Cómo registrar un pago
- Cómo generar una relación de pago
- Comandos útiles

---

## 📚 Documentación Extendida (Opcional)

Después de leer lo anterior, si necesitas profundizar:

### Módulos Específicos
- **Préstamos**: [`../phase3/ANALISIS_MODULO_LOANS.md`](../phase3/ANALISIS_MODULO_LOANS.md)
- **Asociados**: [`../CONTEXTO_COMPLETO_SPRINT_6.md`](../CONTEXTO_COMPLETO_SPRINT_6.md)
- **Rate Profiles**: [`../DOCUMENTACION_RATE_PROFILES_v2.0.3.md`](../DOCUMENTACION_RATE_PROFILES_v2.0.3.md)

### Guías de Desarrollo
- **Docker**: [`../DOCKER.md`](../DOCKER.md)
- **Development**: [`../DEVELOPMENT.md`](../DEVELOPMENT.md)
- **Refactoring**: [`../guides/01_major_refactoring_protocol.md`](../guides/01_major_refactoring_protocol.md)

### Análisis Histórico (contexto)
- **Auditoría completa**: [`../AUDITORIA_COMPLETA_PROYECTO_v2.0.md`](../AUDITORIA_COMPLETA_PROYECTO_v2.0.md)
- **Plan maestro**: [`../PLAN_MAESTRO_V2.0.md`](../PLAN_MAESTRO_V2.0.md)

---

## 💬 Prompt Recomendado para Nueva IA

```
Hola, soy un asistente de IA que se unirá al proyecto Credinet v2.0.

Por favor, léeme en este orden:

1. docs/00_START_HERE/01_PROYECTO_OVERVIEW.md
2. docs/business_logic/INDICE_MAESTRO.md
3. docs/00_START_HERE/02_ARQUITECTURA_STACK.md
4. docs/db/RESUMEN_COMPLETO_v2.0.md
5. docs/00_START_HERE/03_APIS_PRINCIPALES.md
6. docs/00_START_HERE/04_FRONTEND_ESTRUCTURA.md
7. docs/00_START_HERE/05_WORKFLOWS_COMUNES.md

Después de leerlos, confirma que entendiste:
- ✅ Los 6 pilares del negocio (doble calendario, doble tasa, etc.)
- ✅ El stack tecnológico (FastAPI + PostgreSQL + React)
- ✅ Las tablas críticas (loans, payment_schedule, cut_periods, associate_payment_statements)
- ✅ Los flujos principales (aprobar préstamo, registrar pago, generar relación de pago)

Una vez confirmado, dime: "¿En qué módulo necesitas ayuda?"
```

---

## 🗺️ Mapa Mental del Sistema

```
CREDINET v2.0
│
├─ ACTORES
│  ├─ Admin (gestiona todo)
│  ├─ Asociado (otorga préstamos, cobra pagos)
│  └─ Cliente (recibe préstamo, paga quincenas)
│
├─ CONCEPTOS CORE
│  ├─ Doble Calendario (cliente: 15/30, admin: 8/23)
│  ├─ Doble Tasa (cliente: 4.25%, asociado: 2.5%)
│  ├─ Crédito del Asociado (línea global, no por préstamo)
│  ├─ Payment Schedule (12 pagos, cada uno con cut_period_id)
│  ├─ Relaciones de Pago (documento quincenal automático)
│  └─ Interés Simple (NO compuesto)
│
├─ BACKEND (FastAPI)
│  ├─ Auth (JWT)
│  ├─ Users (roles: admin, associate, client)
│  ├─ Loans (CRUD + approval + schedule generation)
│  ├─ Payments (registro, tracking, balance updates)
│  ├─ Associates (crédito, niveles, tracking)
│  └─ Rate Profiles (tasas configurables)
│
├─ FRONTEND (React + Vite)
│  ├─ Dashboard
│  ├─ Préstamos (lista, detalle, crear, aprobar)
│  ├─ Pagos (lista, registrar)
│  ├─ Asociados (perfil, crédito, relaciones de pago)
│  └─ Reportes (por periodo, morosidad)
│
└─ BASE DE DATOS (PostgreSQL)
   ├─ users
   ├─ associate_profiles
   ├─ loans
   ├─ payment_schedule ⭐
   ├─ cut_periods ⭐
   ├─ associate_payment_statements ⭐ (nuevo)
   └─ rate_profiles
```

---

## ⚡ Quick Commands

```bash
# Levantar todo
docker compose up -d

# Ver logs
docker compose logs -f backend
docker compose logs -f frontend

# Entrar a la BD
docker exec -it credinet-postgres psql -U credinet -d credinet

# Ejecutar tests
docker exec credinet-backend pytest

# Rebuild sin cache
docker compose build --no-cache
```

---

## 🎓 Nivel de Entendimiento Esperado

Después de leer todo, deberías poder responder:

### Negocio
- ✅ ¿Por qué hay dos calendarios?
- ✅ ¿Cómo se calcula el pago quincenal de un préstamo?
- ✅ ¿Qué es una relación de pago y cuándo se genera?
- ✅ ¿Cómo funciona el crédito del asociado?

### Técnico
- ✅ ¿Qué tabla vincula pagos con periodos administrativos?
- ✅ ¿Cómo se genera el payment_schedule?
- ✅ ¿Qué es un rate_profile?
- ✅ ¿Dónde está el código de autenticación?

### Práctico
- ✅ ¿Cómo aprobar un préstamo desde el backend?
- ✅ ¿Cómo registrar un pago de cliente?
- ✅ ¿Cómo generar una relación de pago?
- ✅ ¿Dónde está el mock data del frontend?

---

**Tiempo total de lectura**: ~45-60 minutos  
**Archivos a leer**: 7 documentos core  
**Resultado**: Entendimiento completo del sistema

👉 **Empieza con**: [`01_PROYECTO_OVERVIEW.md`](./01_PROYECTO_OVERVIEW.md)
