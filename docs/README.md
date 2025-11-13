# 📚 DOCUMENTACIÓN CREDINET v2.0# 📚 DOCUMENTACIÓN CREDINET v2.0



## 🚀 ¿NUEVA IA? EMPIEZA AQUÍ## 🚀 NUEVA IA? EMPIEZA AQUÍ



### Onboarding Completo (45-60 min)👉 **[`00_START_HERE/README.md`](./00_START_HERE/README.md)** - Onboarding completo (45-60 min)

👉 **[`00_START_HERE/README.md`](./00_START_HERE/README.md)**

### Prompt completo

### Prompt Listo para Copiar📋 **[`00_START_HERE/PROMPT_COMPLETO.md`](./00_START_HERE/PROMPT_COMPLETO.md)** - Copia y pega este prompt

📋 **[`00_START_HERE/PROMPT_COMPLETO.md`](./00_START_HERE/PROMPT_COMPLETO.md)**

---

---

## 🎯 Filosofía: Una Sola Fuente de Verdad por Dominio

## 🎯 Filosofía del Proyecto

Este documento define las **ÚNICAS fuentes de verdad** del proyecto. Todo está consolidado y organizado para que desarrolladores y agentes de IA puedan entender el sistema completo.

**Una Sola Fuente de Verdad por Dominio**



Este directorio contiene TODA la documentación necesaria para entender, operar y extender Credinet v2.0. Está organizado para que tanto desarrolladores humanos como agentes de IA puedan navegar eficientemente.



------



## 📂 Estructura de Documentación



```## 🗄️ BASE DE DATOS---## Épica Actual: Modernización de Perfiles de Usuario

docs/

├── 00_START_HERE/              ⭐ EMPIEZA AQUÍ (Nueva IA)

│   ├── README.md               # Guía de onboarding (7 docs)

│   ├── PROMPT_COMPLETO.md      # Prompt para copiar/pegar### Fuente de Verdad: `/db/v2.0/init.sql`

│   ├── 01_PROYECTO_OVERVIEW.md # Qué es Credinet, actores, stack

│   ├── 02_ARQUITECTURA_STACK.md

│   ├── 03_APIS_PRINCIPALES.md

│   ├── 04_FRONTEND_ESTRUCTURA.md**Archivo monolítico generado automáticamente** que contiene toda la estructura de la base de datos:## 📂 EstructuraActualmente, la iniciativa principal del proyecto es la **Modernización de Perfiles de Usuario**. Esto implica la fusión de la antigua tabla `clients` en la tabla `users`, la adición de campos de perfil enriquecidos (dirección, CURP), y la implementación de entidades relacionadas como `beneficiaries` y `associate_levels`. Puedes encontrar más detalles sobre el progreso y los próximos pasos en el [Resumen de Sesión](./session_summary.md).

│   └── 05_WORKFLOWS_COMUNES.md

│

├── business_logic/             📊 LÓGICA DE NEGOCIO CORE

│   ├── INDICE_MAESTRO.md       # ⭐ Los 6 pilares del sistema```

│   ├── payment_statements/     # Relaciones de pago (nuevo)

│   │   ├── README.md├── 3,997 líneas

│   │   ├── 01_CONCEPTO_Y_ESTRUCTURA.md

│   │   ├── 02_MODELO_BASE_DATOS.md├── 176 KB### `/phase3/` - Fase 3 Actual (Backend + Database)## ¿Qué Buscas? Guía Rápida

│   │   └── 03_LOGICA_GENERACION.md

│   └── ...├── 10 módulos consolidados

│

├── db/                         🗄️ BASE DE DATOS└── Generación: automática desde /modules/Documentación de la fase actual del proyecto (sistema de liquidación de asociados).

│   ├── RESUMEN_COMPLETO_v2.0.md # Esquema completo, tablas, relaciones

│   └── PROGRESO_FINAL.md```

│

├── system_architecture/        🏗️ ARQUITECTURA TÉCNICA-   **"Quiero entender cómo funciona el negocio (las reglas, los roles, los procesos)."**

│   ├── 02_database_schema.md   # ERD y explicación

│   ├── 03_clean_architecture.md**Contenido:**

│   └── 05_cortes_quincenales.md

│- ✅ 38 tablas (catálogos, core, business, audit)- **AUDIT.md** - Auditoría completa del proyecto (Oct 1, 2025)    -   **Empieza aquí:** Lee los documentos en la carpeta `business_logic/` en orden numérico. Son la base de todo.

├── frontend/                   🎨 FRONTEND

│   ├── LOGICA_NEGOCIO_FRONTEND.md- ✅ Todas las funciones SQL (calculate_loan_payment, generate_loan_summary, etc.)

│   └── USER_FLOWS.md

│- ✅ Todos los triggers- **BACKEND_DATABASE.md** - Estado completo Phase 3 (Backend + Database)

├── guides/                     📖 GUÍAS DE DESARROLLO

│   ├── 01_major_refactoring_protocol.md- ✅ Todas las vistas

│   ├── 08_plan_implementacion_ciclo_completo.md

│   └── DATA_PROTECTION.md- ✅ Seeds iniciales (usuarios, roles, catálogos)-   **"Necesito entender la arquitectura técnica (qué tecnología usamos, cómo se conectan las partes)."**

│

├── onboarding/                 👋 SETUP INICIAL- ✅ Sistema de perfiles de tasa (módulo 10)

│   ├── 01_developer_setup.md

│   └── 02_system_health_check.md### Documentación Técnica Activa    -   **Ve a:** La carpeta `system_architecture/`. Encontrarás diagramas, descripciones de los componentes (frontend, backend) y el esquema de la base de datos.

│

├── progress/                   📈 PROGRESO Y AUDITORÍAS**⚠️ NO EDITAR DIRECTAMENTE** → Modificar módulos y regenerar

│   ├── AUDITORIA_BACKEND_COMPLETA_v2.0.md

│   └── SPRINT_5_COMPLETADO.md

│

├── phase3/                     🚧 FASE ACTUAL---

│   └── ANALISIS_MODULO_LOANS.md

│- **CONTEXT.md** - Contexto completo del proyecto (arquitectura, stack, credenciales)-   **"¿Cómo debo escribir o estructurar el CSS?"**

└── _OBSOLETE/                  📦 ARCHIVOS HISTÓRICOS

    └── (análisis y decisiones previas)### Arquitectura Modular: `/db/v2.0/modules/`

```

- **DEVELOPMENT.md** - Guía de desarrollo (setup, workflow, testing)    -   **Consulta:** La nueva [Guía de Arquitectura CSS](./guides/05_css_architecture_and_style_guide.md).

---

Los módulos se ensamblan en orden para generar `init.sql`:

## 🗺️ Guía Rápida: ¿Qué Buscas?

- **DEPLOYMENT.md** - Guía de deployment con Docker

### 🆕 Soy nuevo en el proyecto

→ [`00_START_HERE/README.md`](./00_START_HERE/README.md)```



### 📊 Quiero entender la lógica de negocio01_catalog_tables.sql      → Catálogos (roles, statuses, etc.)- **context.json** - Contexto en formato JSON-   **"Quiero empezar a desarrollar o configurar mi entorno."**

→ [`business_logic/INDICE_MAESTRO.md`](./business_logic/INDICE_MAESTRO.md)

02_core_tables.sql         → Tablas principales (users, loans, payments)

### 🗄️ Necesito info de base de datos

→ [`db/RESUMEN_COMPLETO_v2.0.md`](./db/RESUMEN_COMPLETO_v2.0.md)  03_business_tables.sql     → Lógica de negocio (associates, commissions)- **README_OLD.md** - README anterior (backup)    -   **Sigue la guía:** El directorio `onboarding/` tiene las instrucciones paso a paso. Lee primero `01_developer_setup.md` y luego `02_system_health_check.md` para entender nuestras herramientas de calidad.

→ `/db/v2.0/init.sql` (esquema SQL completo)

04_audit_tables.sql        → Auditoría y trazabilidad

### 🏗️ Quiero entender la arquitectura

→ [`system_architecture/02_database_schema.md`](./system_architecture/02_database_schema.md)  05_functions_base.sql      → Funciones básicas

→ [`system_architecture/03_clean_architecture.md`](./system_architecture/03_clean_architecture.md)

06_functions_business.sql  → Funciones de negocio

### 🎨 Necesito info del frontend

→ [`frontend/LOGICA_NEGOCIO_FRONTEND.md`](./frontend/LOGICA_NEGOCIO_FRONTEND.md)  07_triggers.sql            → Triggers automáticos### `/archive/` - Documentación Histórica-   **"¿Por qué se tomó una decisión de diseño o arquitectura específica?"**

→ [`frontend/USER_FLOWS.md`](./frontend/USER_FLOWS.md)

08_views.sql               → Vistas consolidadas

### 📖 Quiero una guía de desarrollo

→ [`DEVELOPMENT.md`](./DEVELOPMENT.md)  09_seeds.sql               → Datos iniciales    -   **Consulta los registros:** La carpeta `adr/` (Architectural Decision Records) documenta las decisiones importantes y su justificación.

→ [`DOCKER.md`](./DOCKER.md)  

→ [`guides/01_major_refactoring_protocol.md`](./guides/01_major_refactoring_protocol.md)10_rate_profiles.sql       → Sistema de perfiles de tasa ⭐ NUEVO



### 🔍 Busco un tema específico```#### `/archive/2025-09/` - Septiembre 2025

→ [`INDICE_DOCUMENTACION.md`](./INDICE_DOCUMENTACION.md) (índice completo)



---

**Para hacer cambios:**Refactorizaciones iniciales, Clean Architecture, migraciones client_id/user_id.-   **"Necesito asumir un rol específico (ej. desarrollador backend)."**

## 🗄️ Fuentes de Verdad por Dominio

```bash

### Base de Datos

- **Esquema**: `/db/v2.0/init.sql` (3,997 líneas, 176 KB)# 1. Editar el módulo correspondiente    -   **Adopta una persona:** La carpeta `personas/` define los perfiles clave del proyecto, sus responsabilidades y las herramientas que utilizan.

- **Documentación**: [`db/RESUMEN_COMPLETO_v2.0.md`](./db/RESUMEN_COMPLETO_v2.0.md)

- **Tablas críticas**: 15+ tablas normalizadasvim db/v2.0/modules/02_core_tables.sql

- **Status**: ✅ Productivo

Archivos principales:

### Lógica de Negocio

- **Documento maestro**: [`business_logic/INDICE_MAESTRO.md`](./business_logic/INDICE_MAESTRO.md)# 2. Regenerar archivo monolítico

- **6 Pilares**:

  1. Doble Calendario (cliente vs admin)cd db/v2.0- REFACTORIZACION_*.md - 6 refactorizaciones completadas## Protocolo de Actualización

  2. Doble Tasa (interest_rate vs commission_rate)

  3. Crédito del Asociado (línea global)./generate_monolithic.sh

  4. Payment Schedule (12 pagos con cut_period_id)

  5. Relaciones de Pago (documento quincenal)- ANALISIS_*.md - Análisis de tablas, UX, duplicación

  6. Interés Simple (NO compuesto)

- **Status**: ✅ Documentado y validado con PDFs reales# 3. Aplicar cambios (si DB ya existe)



### Backenddocker exec -i credinet-postgres psql -U credinet_user -d credinet_db < modules/02_core_tables.sql- MIGRACION_*.md - Migraciones de schemaLa documentación es código. Cualquier cambio en la funcionalidad o arquitectura **debe** ir acompañado de una actualización en los documentos relevantes.

- **Framework**: FastAPI 0.104+

- **Código**: `/backend/app/````

- **Documentación**: [`ARQUITECTURA_BACKEND_V2_DEFINITIVA.md`](./ARQUITECTURA_BACKEND_V2_DEFINITIVA.md)

- **APIs**: http://localhost:8000/docs (Swagger)- SISTEMA_*.md - Estados del sistema

- **Status**: ✅ Core completo, en expansión

---

### Frontend

- **Framework**: React 18 + Vite 7.1-   **Cambio en la lógica de negocio:** Actualiza `business_logic/` y crea un `adr/` si la decisión es significativa.

- **Código**: `/frontend-mvp/src/`

- **Arquitectura**: Feature-Sliced Design (FSD)## 🐍 BACKEND (Python/FastAPI)

- **Documentación**: [`frontend/USER_FLOWS.md`](./frontend/USER_FLOWS.md)

- **Status**: 🔄 MVP en desarrollo#### `/archive/2025-10/` - Octubre 2025-   **Cambio en el código (API, DB):** Actualiza `system_architecture/`.



### Docker### Fuente de Verdad: `/backend/app/`

- **Compose**: `/docker-compose.yml`

- **Documentación**: [`DOCKER.md`](./DOCKER.md)Fase 2 (Frontend V2), métricas, reportes, planes.-   **Añadir una nueva dependencia o cambiar el proceso de setup:** Actualiza `onboarding/`.

- **Servicios**: postgres, backend, frontend

- **Status**: ✅ FuncionalArquitectura limpia en capas:



---



## 📊 Documentos Más Importantes (Top 10)```



1. **[`00_START_HERE/README.md`](./00_START_HERE/README.md)** - Onboarding completobackend/app/Archivos principales:## Épica Actual: Refactorización del Sistema de Roles

2. **[`business_logic/INDICE_MAESTRO.md`](./business_logic/INDICE_MAESTRO.md)** - Los 6 pilares

3. **[`db/RESUMEN_COMPLETO_v2.0.md`](./db/RESUMEN_COMPLETO_v2.0.md)** - Esquema BD├── main.py                 → Punto de entrada (FastAPI app)

4. **[`ARQUITECTURA_DOBLE_CALENDARIO.md`](./ARQUITECTURA_DOBLE_CALENDARIO.md)** - Calendario dual

5. **[`EXPLICACION_DOS_TASAS.md`](./EXPLICACION_DOS_TASAS.md)** - Sistema de tasas├── core/                   → Núcleo del sistema- FASE2_*.md - Documentación Fase 2

6. **[`LOGICA_DE_NEGOCIO_DEFINITIVA.md`](./LOGICA_DE_NEGOCIO_DEFINITIVA.md)** - Reglas completas

7. **[`payment_statements/README.md`](./business_logic/payment_statements/README.md)** - Relaciones de pago│   ├── config.py          → Configuración global

8. **[`DEVELOPMENT.md`](./DEVELOPMENT.md)** - Setup de desarrollo

9. **[`DOCKER.md`](./DOCKER.md)** - Cómo levantar el proyecto│   ├── database.py        → Conexión PostgreSQL- PLAN_*.md - Planes de implementaciónActualmente, la iniciativa principal del proyecto es la **Refactorización del Sistema de Roles a un Modelo Puro**. Esto permitirá que los usuarios tengan múltiples roles y mejorará la flexibilidad del sistema de permisos. Puedes encontrar más detalles sobre el progreso y los próximos pasos en el [Resumen de Sesión](./session_summary.md).

10. **[`PLAN_MAESTRO_V2.0.md`](./PLAN_MAESTRO_V2.0.md)** - Roadmap completo

│   ├── security.py        → JWT, passwords, permisos

---

│   └── exceptions.py      → Excepciones personalizadas- METRICAS_*.md - Métricas y visuales

## 🚀 Quick Start

│- AUDITORIA_*.md - Auditorías intermedias

```bash

# 1. Leer onboarding (45-60 min)└── modules/               → Módulos de negocio (Clean Architecture)- RESUMEN_*.md - Resúmenes ejecutivos

cat docs/00_START_HERE/README.md

    ├── auth/              → Autenticación y autorización- SPRINT_*.md - Reportes de sprints

# 2. Leer lógica de negocio (15 min)

cat docs/business_logic/INDICE_MAESTRO.md    ├── users/             → Gestión de usuarios



# 3. Levantar proyecto    ├── associates/        → Asociados y comisiones---

docker compose up -d

    ├── loans/             → Préstamos (CORREGIDO ✅)

# 4. Verificar

docker compose ps    ├── payments/          → Pagos y cobranza## 🎯 Guía Rápida

curl http://localhost:8000/docs

curl http://localhost:5173    └── rate_profiles/     → Perfiles de tasa ⏳ PENDIENTE



# 5. Empezar a desarrollar```### Para desarrolladores nuevos

```

1. Lee `CONTEXT.md` primero (30 min)

---

**Cada módulo sigue:**2. Sigue `DEVELOPMENT.md` para setup (1 hora)

## 🆕 ¿Qué hay de nuevo?

```3. Revisa `phase3/AUDIT.md` para estado actual (15 min)

### Noviembre 2025

- ✅ **Nueva estructura de onboarding** (`00_START_HERE/`)module/

- ✅ **Documentación de Relaciones de Pago** (basada en PDFs reales)

- ✅ **INDICE_MAESTRO.md** consolidado├── domain/### Para debugging

- ✅ **Limpieza**: Archivos obsoletos movidos a `_OBSOLETE/`

│   └── entities/          → Modelos de dominio (dataclasses)1. `phase3/BACKEND_DATABASE.md` - Estado actual del backend

### Octubre 2025

- ✅ Sprint 6: Asociados completo├── application/2. `phase3/AUDIT.md` - Problemas conocidos y soluciones

- ✅ Sistema de doble calendario documentado

- ✅ Sistema de doble tasa validado│   ├── dtos/             → Data Transfer Objects

- ✅ Frontend MVP con FSD

│   └── services/         → Lógica de negocio### Para deployment

---

├── infrastructure/1. `DEPLOYMENT.md` - Guía completa de Docker

## 📞 Contacto y Contribución

│   └── repositories/     → Acceso a datos (SQL)

**Mantenedor**: Equipo Credinet  

**Branch actual**: `feature/sprint-6-associates`  └── routes.py             → Endpoints REST API---

**Última actualización**: 2025-11-05

```

### Cómo contribuir a la documentación

## 📊 Documentos Clave por Tema

1. **Documenta en el lugar correcto**:

   - Lógica de negocio → `business_logic/`---

   - Arquitectura técnica → `system_architecture/`

   - Guías de desarrollo → `guides/`### Arquitectura

   - Base de datos → `db/`

## ⚛️ FRONTEND (React + Vite)- **CONTEXT.md** - Arquitectura Clean, módulos, capas

2. **Mantén el principio**: Una fuente de verdad por tema

- **phase3/BACKEND_DATABASE.md** - Estructura backend

3. **Usa Markdown** con formato consistente

### Fuente de Verdad: `/frontend/src/`

4. **Actualiza índices** cuando agregues documentos nuevos

### Base de Datos

---

```- **phase3/BACKEND_DATABASE.md** - Schema actual (Phase 3)

**👉 Empieza tu onboarding**: [`00_START_HERE/README.md`](./00_START_HERE/README.md)

frontend/src/- **archive/2025-09/ANALISIS_COMPLETO_TABLAS_UX_UI.md** - Análisis de tablas

├── main.jsx               → Punto de entrada

├── App.jsx                → Router principal### Testing

├── components/            → Componentes reutilizables- **DEVELOPMENT.md** - Cómo correr tests

├── pages/                 → Vistas completas- **phase3/AUDIT.md** - Estado actual de tests (94.4%)

├── services/              → Consumo de API

├── hooks/                 → React hooks personalizados### Refactorizaciones

├── utils/                 → Utilidades- **archive/2025-09/** - Todas las refactorizaciones completadas

└── styles/                → Estilos globales

```---



---## ⚠️ Notas Importantes



## 📖 DOCUMENTACIÓN1. **Documentación en `/archive/`** es de solo lectura (referencia histórica)

2. **Actualizar docs activas** cuando hagas cambios mayores

### Índice Maestro: Este archivo3. **No eliminar `/archive/`** - contiene decisiones técnicas importantes



Documentación consolidada en `/docs/`:---



```**Última actualización**: Octubre 1, 2025  

docs/**Mantenedor**: @JairFC

├── README.md                              → ESTE ARCHIVO (índice maestro)
├── CONTEXT.md                             → Contexto general del proyecto
├── ARQUITECTURA_BACKEND_V2_DEFINITIVA.md  → Arquitectura backend completa
├── LOGICA_DE_NEGOCIO_DEFINITIVA.md        → Reglas de negocio
├── EXPLICACION_DOS_TASAS.md               → Sistema de dos tasas (matemática)
├── CORRECCION_DOS_TASAS_COMPLETO.md       → Corrección crítica aplicada
└── business_logic/                        → Lógica detallada por dominio
    ├── 01_core_concepts.md
    ├── 02_roles_and_permissions.md
    └── 03_ciclo_vida_prestamos_completo.md
```

---

## 🔒 RESPALDO DE DATOS

### Sistema de Backup Automático

**Script:** `/scripts/database/backup_volumes.sh`

**Uso:**
```bash
# Backup manual
./scripts/database/backup_volumes.sh backup

# Listar backups
./scripts/database/backup_volumes.sh list

# Restaurar backup
./scripts/database/backup_volumes.sh restore backup_2025-11-05_02-38-44

# Limpiar backups antiguos (>30 días)
./scripts/database/backup_volumes.sh cleanup
```

**Ubicación backups:** `/db/backups/`

**Contenido de cada backup:**
- `postgres.dump` → Formato binario (pg_restore)
- `postgres.sql` → Formato SQL plano (más portable)
- `uploads.tar.gz` → Archivos subidos por usuarios
- `docker-compose.yml` → Configuración
- `.env` → Variables de entorno
- `MANIFEST.txt` → Metadatos

**Retención:** 30 días automático

**✅ Los backups persisten aunque hagas `docker-compose down -v`**

---

## 🔄 FLUJO DE DESARROLLO

### 1. Cambios en Base de Datos

```bash
# Editar módulo
vim db/v2.0/modules/10_rate_profiles.sql

# Regenerar monolítico
cd db/v2.0 && ./generate_monolithic.sh

# Aplicar (si DB existe)
docker exec -i credinet-postgres psql -U credinet_user -d credinet_db \
  < modules/10_rate_profiles.sql

# Backup de seguridad
./scripts/database/backup_volumes.sh backup
```

### 2. Cambios en Backend

```bash
# Editar entidad/servicio
vim backend/app/modules/loans/domain/entities/__init__.py

# Reiniciar para aplicar
docker-compose restart backend
```

### 3. Cambios en Frontend

```bash
# Editar componente
vim frontend/src/pages/Loans/LoanForm.jsx

# Hot reload automático con Vite
```

---

## 🎓 Para IAs: Cómo Leer Este Proyecto

### Orden de Lectura Recomendado

1. **Contexto General:**
   - `/docs/README.md` (este archivo)
   - `/docs/CONTEXT.md`

2. **Arquitectura:**
   - `/docs/ARQUITECTURA_BACKEND_V2_DEFINITIVA.md`
   - `/docs/LOGICA_DE_NEGOCIO_DEFINITIVA.md`

3. **Base de Datos:**
   - `/db/v2.0/init.sql` (archivo completo)
   - `/db/v2.0/modules/10_rate_profiles.sql` (módulo crítico)

4. **Backend:**
   - `/backend/app/main.py`
   - `/backend/app/core/` (todos los archivos)
   - `/backend/app/modules/loans/` (ejemplo completo)

5. **Lógica de Negocio Específica:**
   - `/docs/EXPLICACION_DOS_TASAS.md`
   - `/docs/business_logic/03_ciclo_vida_prestamos_completo.md`

### Preguntas Frecuentes

**P: ¿Dónde está la definición de `rate_profiles`?**  
R: `/db/v2.0/modules/10_rate_profiles.sql` y consolidada en `/db/v2.0/init.sql`

**P: ¿Cómo se calculan pagos con dos tasas?**  
R: Función SQL `calculate_loan_payment()` + `/docs/EXPLICACION_DOS_TASAS.md`

**P: ¿Dónde está la entidad `Loan` del backend?**  
R: `/backend/app/modules/loans/domain/entities/__init__.py`

**P: ¿Hay migraciones sueltas tipo Alembic/Flyway?**  
R: NO. Todo está en `init.sql` y sus módulos fuente.

---

## 🚀 Comandos Rápidos

```bash
# DESARROLLO
docker-compose up -d              # Levantar todo
docker-compose logs -f backend    # Ver logs backend
docker-compose restart backend    # Reiniciar backend

# BASE DE DATOS
./db/v2.0/generate_monolithic.sh  # Regenerar init.sql
docker exec -it credinet-postgres psql -U credinet_user -d credinet_db

# BACKUPS
./scripts/database/backup_volumes.sh backup
./scripts/database/backup_volumes.sh list
./scripts/database/backup_volumes.sh restore NOMBRE

# LIMPIEZA
docker-compose down               # Apagar (mantiene volúmenes)
docker-compose down -v            # ⚠️ BORRA volúmenes (backup antes!)
```

---

**Última actualización:** 2025-11-05  
**Versión:** 2.0.3  
**Estado:** ✅ SQL Consolidado | ✅ Backups Activos | ⏳ Backend Pendiente
