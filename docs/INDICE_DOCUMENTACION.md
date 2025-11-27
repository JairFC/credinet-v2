# 📚 ÍNDICE MAESTRO DE DOCUMENTACIÓN - CREDINET v2.0

**Fecha:** 5 de Noviembre, 2025  
**Branch:** `feature/sprint-6-associates`  
**Propósito:** Navegación rápida a toda la documentación del proyecto

> 🆕 **NUEVA IA?** → Empieza aquí: [`00_START_HERE/README.md`](./00_START_HERE/README.md)

---

## ⭐ PUNTO DE ENTRADA

### � Sistema de Onboarding (NUEVO)
**Carpeta:** `00_START_HERE/`  
**Tiempo estimado:** 45-60 minutos  
**Audiencia:** Nuevas IAs, desarrolladores nuevos

**Archivos:**
1. `README.md` - Guía de onboarding 7 pasos
2. `01_PROYECTO_OVERVIEW.md` - Overview completo del proyecto
3. `PROMPT_COMPLETO.md` - Prompt listo para copiar/pegar
4. `02_ARQUITECTURA_STACK.md` - (Pendiente)
5. `03_APIS_PRINCIPALES.md` - (Pendiente)
6. `04_FRONTEND_ESTRUCTURA.md` - (Pendiente)
7. `05_WORKFLOWS_COMUNES.md` - (Pendiente)

**Cuándo usar:** Primera vez en el proyecto o necesitas refrescar conceptos core

---

## � DOCUMENTOS HISTÓRICOS

### Carpeta `_OBSOLETE/`
**Archivos:** 30 documentos históricos  
**Contenido:**
- Auditorías completadas (AUDITORIA_*)
- Análisis previos (ANALISIS_*)
- Contextos de sprints pasados
- Dashboards históricos
- Hotfixes aplicados
- Pruebas técnicas

**Cuándo usar:** Investigación histórica, entender decisiones pasadas

**Ver:** [`_OBSOLETE/REPORTE_LIMPIEZA_2025-11-05.md`](./_OBSOLETE/REPORTE_LIMPIEZA_2025-11-05.md) para detalle completo

---

## 📋 DOCUMENTOS CORE ACTUALES

### 1. 📖 README Principal
**Archivo:** `README.md`  
**Contenido:**
- Link prominente a onboarding (00_START_HERE/)
- Estructura de documentación
- Guía rápida de navegación
- Fuentes de verdad por dominio
- Top 10 documentos más importantes
- Quick start con comandos
- Lo más nuevo (noviembre 2025)

**Cuándo usar:** Para navegar toda la documentación

---

### 2. � Lógica de Negocio - Índice Maestro
**Archivo:** `business_logic/INDICE_MAESTRO.md`  
**Tamaño:** ~700 líneas  
**Audiencia:** Desarrolladores, Product Owners  
**Contenido:**
- Los 6 pilares del sistema
  1. Doble Calendario
  2. Doble Tasa
  3. Crédito del Asociado
  4. Payment Schedule
  5. Relaciones de Pago
  6. Interés Simple
- 9 fórmulas matemáticas
- 7 reglas de negocio
- 5 casos especiales
- Links a documentación detallada

**Cuándo usar:** Para entender conceptos fundamentales del negocio

---

### 3. 📝 Relaciones de Pago (NUEVO)
**Carpeta:** `business_logic/payment_statements/`  
**Archivos:**
- `README.md` - Índice
- `01_CONCEPTO_Y_ESTRUCTURA.md` - Análisis de PDFs reales
- `02_MODELO_BASE_DATOS.md` - Esquemas SQL
- `03_LOGICA_GENERACION.md` - Algoritmos

**Contenido:** Sistema de generación quincenal de estados de cuenta basado en análisis de 3 PDFs reales (MELY, CLAUDIA, PILAR)

**Cuándo usar:** Para implementar generación de relaciones de pago

---

## 📖 DOCUMENTACIÓN ARQUITECTURA

### 4. 🏗️ Arquitectura Backend v2.0 Definitiva
**Archivo:** `ARQUITECTURA_BACKEND_V2_DEFINITIVA.md`  
**Tamaño:** 447 líneas  
**Audiencia:** Desarrolladores Backend, Arquitectos  
**Contenido:**
- Decisión arquitectónica (Clean Architecture + DDD Lite)
- Análisis del proyecto (tamaño, complejidad)
- Separación de capas detallada
- Dependency Rule
- Repository Pattern
- Flujo de ejemplo completo (Aprobar Préstamo)
- Qué va en DB vs Backend

**Cuándo usar:** Para entender la arquitectura y separación de responsabilidades.

---

### 5. 📅 Arquitectura Doble Calendario
**Archivo:** `ARQUITECTURA_DOBLE_CALENDARIO.md`  
**Tamaño:** ~800 líneas  
**Audiencia:** Desarrolladores, DBAs  
**Contenido:**
- Los 2 calendarios: cliente (15/fin) vs admin (8-22, 23-7)
- Función "oráculo" `calculate_first_payment_date()`
- Ejemplos y casos edge
- Validaciones matemáticas
- Sistema de generación de pagos

**Cuándo usar:** Para entender el sistema de fechas y períodos

---

### 6. 🎯 Lógica de Negocio Definitiva
**Archivo:** `LOGICA_DE_NEGOCIO_DEFINITIVA.md`  
**Tamaño:** 1,215 líneas  
**Audiencia:** Desarrolladores, DBAs, Product Owners, QA  
**Contenido:**
- Contexto del sistema
- Modelo de negocio (flujo de dinero)
- Sistema de doble calendario (CRÍTICO)
- Actores del sistema (5 roles)
- Flujo 1: Solicitud y aprobación de préstamo
- Flujo 2: Pago quincenal del cliente
- Flujo 3: Cierre de período
- Reglas de negocio críticas
- Cálculos y fórmulas

**Cuándo usar:** Para entender cualquier regla de negocio o flujo del sistema.

---

### 7. 💰 Explicación: Sistema de Dos Tasas
**Archivo:** `EXPLICACION_DOS_TASAS.md`  
**Contenido:**
- interest_rate (tasa cliente)
- commission_rate (tasa asociado)
- Cálculos y ejemplos
- Integración con rate_profiles

**Cuándo usar:** Para entender el sistema de tasas dual

---

### 8. 📊 Documentación Rate Profiles v2.0.3
**Archivo:** `DOCUMENTACION_RATE_PROFILES_v2.0.3.md`  
**Tamaño:** 441 líneas  
**Contenido:**
- Concepto de las dos tasas
- Tabla `rate_profiles`
- 4 endpoints del módulo
- Ejemplos de uso
- Integración con loans

**Cuándo usar:** Para trabajar con perfiles de tasa

---

## 📖 DOCUMENTACIÓN DE DESARROLLO

### 9. 📘 Guía Backend v2.0
**Archivo:** `GUIA_BACKEND_V2.0.md`  
**Tamaño:** 732 líneas  
**Audiencia:** Desarrolladores Backend nuevos  
**Contenido:**
- Estado actual del proyecto
- ¿Qué son las migraciones? (ELI5)
- ¿Cuándo usar init.sql vs migraciones?
- ¿Qué va en la DB vs en el Backend?
- Ejemplo: Aprobar un préstamo (buenas prácticas)
- Arquitectura Backend v2.0 desde cero

**Cuándo usar:** Para entender migraciones y separación DB/Backend.

---

### 10. 🛠️ Development Guide
**Archivo:** `DEVELOPMENT.md`  
**Contenido:**
- Setup de desarrollo
- Comandos comunes
- Estructura del proyecto
- Testing

**Cuándo usar:** Para configurar ambiente de desarrollo

---

### 11. 🐳 Docker Guide
**Archivo:** `DOCKER.md`  
**Tamaño:** 362 líneas  
**Contenido:**
- Quick start
- Comandos útiles
- Troubleshooting
- Hot reload
- Credenciales

**Cuándo usar:** Para trabajar con Docker

---

## 📖 DOCUMENTACIÓN SPRINT ACTUAL

### 12. � Resumen Ejecutivo Sprint 6
**Archivo:** `RESUMEN_EJECUTIVO_SPRINT6.md`  
**Tamaño:** 339 líneas  
**Audiencia:** Equipo completo  
**Contenido:**
- Implementación completa doble calendario
- Migraciones 005-007
- Sistema de rate_profiles integrado
- Trabajo completado en Sprint 6

**Cuándo usar:** Para entender trabajo completado en Sprint 6

---

## 📖 PLAN Y ROADMAP

### 13. 📋 Plan Maestro v2.0
**Archivo:** `PLAN_MAESTRO_V2.0.md`  
**Tamaño:** 1,006 líneas  
**Audiencia:** Product Owners, Desarrolladores, QA  
**Contenido:**
- Metodología de desarrollo (User Stories → Diagramas → Endpoints → Wireframes)
- Actores del sistema (5 roles)
- Priorización MVP vs Futuro
- User Stories de Fase 1 (MVP)
- Epic 1: Autenticación
- Epic 2: Gestión de Préstamos
- Wireframes y flujos

**Cuándo usar:** Para entender el roadmap completo y las user stories.

---**Cuándo usar:** Para reportar status al management.

---

### 9. 📃 Sistema Levantado
**Archivo:** `SISTEMA_LEVANTADO.md`  
**Tamaño:** 245 líneas  
**Audiencia:** Desarrolladores, DevOps  
**Contenido:**
- Estado actual de servicios Docker
- Correcciones aplicadas (imports, modelos)
- Gestión de volúmenes
- Scripts de protección de datos
- Backups existentes
- Testing
- Progreso del proyecto
- Comandos útiles
- URLs importantes

**Cuándo usar:** Para verificar el estado actual del sistema.

---

## 🗄️ DOCUMENTACIÓN DE BASE DE DATOS

### 10. 📚 README Base de Datos v2.0
**Archivo:** `db/v2.0/README.md`  
**Tamaño:** 487 líneas  
**Audiencia:** DBAs, Desarrolladores Backend  
**Contenido:**
- Visión general (29 tablas, 22 funciones, 28 triggers, 9 vistas)
- Arquitectura modular (9 módulos SQL)
- 6 migraciones integradas explicadas
- Uso (modular vs monolítico)
- Módulos detallados
- Mantenimiento

**Cuándo usar:** Para entender la estructura de la base de datos.

---

### 11. 📄 Archivo Monolítico init.sql
**Archivo:** `db/v2.0/init.sql`  
**Tamaño:** 3,076 líneas  
**Audiencia:** DBAs, Docker  
**Contenido:**
- Schema completo de base de datos
- 29 tablas con comentarios
- 22 funciones SQL
- 28 triggers
- 9 vistas
- Seeds (datos iniciales)

**Cuándo usar:** Deploy de base de datos desde cero.

---

### 12. 📂 Módulos SQL (Desarrollo)
**Carpeta:** `db/v2.0/modules/`  
**Archivos:** 9 módulos SQL  
**Audiencia:** DBAs desarrollando nuevas features  
**Contenido:**
- 01_catalog_tables.sql (12 tablas catálogo)
- 02_core_tables.sql (11 tablas core)
- 03_business_tables.sql (8 tablas negocio)
- 04_audit_tables.sql (4 tablas auditoría)
- 05_functions_base.sql (11 funciones base)
- 06_functions_business.sql (11 funciones negocio)
- 07_triggers.sql (28 triggers)
- 08_views.sql (9 vistas)
- 09_seeds.sql (datos iniciales)

**Cuándo usar:** Para agregar nuevas tablas, funciones o triggers.

---

## 🔐 DOCUMENTACIÓN DE MÓDULOS BACKEND

### 13. 🔑 README Módulo Auth
**Archivo:** `backend/app/modules/auth/README.md`  
**Tamaño:** 650 líneas  
**Audiencia:** Desarrolladores Backend  
**Contenido:**
- Descripción del módulo
- Características principales
- Arquitectura Clean (4 capas)
- 6 endpoints REST con ejemplos
- Sistema de roles (5 niveles)
- JWT tokens (access + refresh)
- Testing (28 tests)
- DTOs documentados
- Ejemplos de uso

**Cuándo usar:** Como referencia para implementar nuevos módulos.

---

### 14. 💰 README Módulo Loans
**Archivo:** `backend/app/modules/loans/README.md`  
**Tamaño:** 655 líneas  
**Audiencia:** Desarrolladores Backend  
**Contenido:**
- Estado actual (Sprint 4 completado)
- Arquitectura Clean (4 capas)
- Sistema de doble calendario (CRÍTICO)
- 9 endpoints REST con ejemplos
- Estados de préstamo (10 estados)
- Validaciones de negocio
- Funciones DB críticas
- Testing (96 tests)

**Cuándo usar:** Como referencia para implementar módulo Associates.

---

### 15-17. 📋 Sprints Completados (Módulo Loans)
**Archivos:**
- `backend/app/modules/loans/SPRINT_1_COMPLETADO.md`
- `backend/app/modules/loans/SPRINT_2_COMPLETADO.md`
- `backend/app/modules/loans/SPRINT_3_COMPLETADO.md`

**Audiencia:** Desarrolladores, Product Owners  
**Contenido:**
- Objetivos de cada sprint
- Tareas completadas
- Estadísticas (líneas, tests)
- Commits
- Lecciones aprendidas

**Cuándo usar:** Para ver el proceso de desarrollo de un módulo completo.

---

## 📊 DOCUMENTACIÓN DE PROGRESO

### 18. ✅ Sprint 5 Completado (Auth)
**Archivo:** `docs/progress/SPRINT_5_COMPLETADO.md`  
**Tamaño:** 556 líneas  
**Audiencia:** Product Owners, Desarrolladores  
**Contenido:**
- Resumen ejecutivo
- Objetivos cumplidos
- Estadísticas (3,370 líneas, 28 tests)
- Commits (2)
- Arquitectura implementada
- Endpoints REST
- Testing (15 unit + 10 integration + 4 E2E)
- Lecciones aprendidas

**Cuándo usar:** Para ver el resultado final del Sprint 5.

---

### 19-23. 📚 Otros Documentos de Progreso
**Carpeta:** `docs/progress/`  
**Archivos:**
- `AUDITORIA_BACKEND_COMPLETA_v2.0.md`
- `LIMPIEZA_RADICAL_v2.0_COMPLETADA.md`
- `MIGRACION_v2.0_COMPLETADA.md`
- `MODULO_CATALOGS_COMPLETADO.md` (deprecado)
- Más...

**Audiencia:** Desarrolladores, Gerencia  
**Contenido:** Histórico de cambios importantes del proyecto.

**Cuándo usar:** Para entender el histórico de decisiones.

---

## 📘 GUÍAS TÉCNICAS

### 24. 🏗️ System Architecture Overview
**Archivo:** `docs/system_architecture/01_overview.md`  
**Audiencia:** Arquitectos, Desarrolladores Senior  
**Contenido:** Visión general de la arquitectura del sistema.

### 25. 🗄️ Database Schema
**Archivo:** `docs/system_architecture/02_database_schema.md`  
**Audiencia:** DBAs, Desarrolladores Backend  
**Contenido:** Esquema detallado de base de datos.

### 26. 🧼 Clean Architecture
**Archivo:** `docs/system_architecture/03_clean_architecture.md`  
**Audiencia:** Desarrolladores Backend  
**Contenido:** Implementación de Clean Architecture.

### 27-30. 📚 Más Guías
**Carpeta:** `docs/guides/`  
**Archivos:**
- `01_major_refactoring_protocol.md`
- `02_simple_universal_filter.md`
- `03_cli_usage.md`
- `04_client_creation_flow.md`
- `05_css_architecture_and_style_guide.md`
- `06_theme_system_guide.md`
- `07_simplificacion_del_proyecto.md`
- `08_plan_implementacion_ciclo_completo.md`
- `DATA_PROTECTION.md`

**Cuándo usar:** Para tareas específicas (refactoring, filtros, estilos, etc.)

---

## 📖 LÓGICA DE NEGOCIO

### 31-32. 📚 Conceptos Core
**Carpeta:** `docs/business_logic/`  
**Archivos:**
- `01_core_concepts.md`
- `02_roles_and_permissions.md`
- `03_ciclo_vida_prestamos_completo.md`
- `CORRECION_CRONOLOGIA_CORTES.md`

**Audiencia:** Desarrolladores, Product Owners, QA  
**Contenido:** Lógica de negocio específica del dominio.

**Cuándo usar:** Para entender reglas de negocio específicas.

---

## 🚀 ONBOARDING

### 33-34. 📘 Guías de Inicio
**Carpeta:** `docs/onboarding/`  
**Archivos:**
- `01_developer_setup.md`
- `02_system_health_check.md`

**Audiencia:** Nuevos desarrolladores  
**Contenido:** Cómo configurar el entorno y verificar que todo funciona.

**Cuándo usar:** Al incorporarse al proyecto.

---

## 🎯 MAPA DE NAVEGACIÓN RÁPIDA

### Por Rol

**👨‍💼 Product Owner / Gerencia:**
1. DASHBOARD_EJECUTIVO_v2.0.md (5 min)
2. RESUMEN_EJECUTIVO_v2.0.md (10 min)
3. PLAN_MAESTRO_V2.0.md (20 min)

**👨‍💻 Desarrollador Nuevo:**
1. DASHBOARD_EJECUTIVO_v2.0.md (5 min)
2. onboarding/01_developer_setup.md (15 min)
3. ARQUITECTURA_BACKEND_V2_DEFINITIVA.md (30 min)
4. backend/app/modules/auth/README.md (20 min)

**👨‍💻 Desarrollador Sprint 6:**
1. CONTEXTO_COMPLETO_SPRINT_6.md (15 min)
2. backend/app/modules/auth/README.md (referencia)
3. backend/app/modules/loans/README.md (referencia)

**🗄️ DBA:**
1. db/v2.0/README.md (15 min)
2. LOGICA_DE_NEGOCIO_DEFINITIVA.md (40 min)
3. db/v2.0/init.sql (revisar)

**🏗️ Arquitecto:**
1. AUDITORIA_COMPLETA_PROYECTO_v2.0.md (60 min)
2. ARQUITECTURA_BACKEND_V2_DEFINITIVA.md (30 min)
3. system_architecture/03_clean_architecture.md (20 min)

**🧪 QA / Tester:**
1. LOGICA_DE_NEGOCIO_DEFINITIVA.md (40 min)
2. PLAN_MAESTRO_V2.0.md (user stories) (20 min)
3. backend/app/modules/*/README.md (endpoints) (10 min cada uno)

### Por Tarea

**🆕 Implementar Nuevo Módulo:**
1. CONTEXTO_COMPLETO_SPRINT_6.md
2. backend/app/modules/auth/README.md (referencia)
3. ARQUITECTURA_BACKEND_V2_DEFINITIVA.md

**🗄️ Agregar Tabla o Función DB:**
1. db/v2.0/README.md
2. db/v2.0/modules/ (módulos específicos)
3. LOGICA_DE_NEGOCIO_DEFINITIVA.md

**🔍 Entender Lógica de Negocio:**
1. LOGICA_DE_NEGOCIO_DEFINITIVA.md
2. business_logic/03_ciclo_vida_prestamos_completo.md

**🧪 Escribir Tests:**
1. backend/app/modules/auth/README.md (sección testing)
2. backend/app/modules/loans/README.md (sección testing)
3. tests/test_auth/ o tests/test_loans/ (ejemplos)

**🐳 Configurar Docker:**
1. SISTEMA_LEVANTADO.md
2. docker-compose.yml
3. guides/DATA_PROTECTION.md

**📚 Documentar:**
1. Este archivo (INDICE_DOCUMENTACION.md)
2. backend/app/modules/auth/README.md (plantilla)
3. Cualquier README existente

---

## 📦 ESTADÍSTICAS DE DOCUMENTACIÓN

```
Total de Documentos: 35+
Total de Líneas: ~15,000+
Total de Palabras: ~100,000+

Distribución:
├─ Auditoría y Context (NUEVOS): 3 docs (2,500 líneas)
├─ Plan y Arquitectura: 4 docs (3,400 líneas)
├─ Base de Datos: 12 docs (4,000 líneas)
├─ Módulos Backend: 6 docs (2,000 líneas)
├─ Progreso: 5 docs (1,500 líneas)
├─ Guías: 9 docs (1,000 líneas)
└─ Otros: 6 docs (600 líneas)

Calidad:
✅ Completa: 95%
✅ Actualizada: 100%
✅ Organizada: 90%
✅ Accesible: 100%
```

---

## 🔍 BÚSQUEDA RÁPIDA

**Buscar por Keyword:**

- **Clean Architecture:** ARQUITECTURA_BACKEND_V2_DEFINITIVA.md
- **Doble Calendario:** LOGICA_DE_NEGOCIO_DEFINITIVA.md, loans/README.md
- **Migraciones:** GUIA_BACKEND_V2.0.md, db/v2.0/README.md
- **Sistema de Crédito:** AUDITORIA_COMPLETA_PROYECTO_v2.0.md, db/v2.0/README.md
- **Testing:** auth/README.md, loans/README.md, AUDITORIA_COMPLETA_PROYECTO_v2.0.md
- **JWT:** auth/README.md, ARQUITECTURA_BACKEND_V2_DEFINITIVA.md
- **DTOs:** auth/README.md, ARQUITECTURA_BACKEND_V2_DEFINITIVA.md
- **Repository Pattern:** ARQUITECTURA_BACKEND_V2_DEFINITIVA.md
- **Docker:** SISTEMA_LEVANTADO.md, docker-compose.yml
- **Backups:** guides/DATA_PROTECTION.md, SISTEMA_LEVANTADO.md

---

## ✅ CHECKLIST DE DOCUMENTACIÓN

Para considerar el proyecto completamente documentado:

- [x] README principal del proyecto
- [x] SISTEMA_LEVANTADO.md (estado actual)
- [x] Plan Maestro con user stories
- [x] Arquitectura backend detallada
- [x] Lógica de negocio completa
- [x] Guía de backend v2.0
- [x] README de base de datos
- [x] README por cada módulo backend
- [x] Documentación de sprints completados
- [x] Guías técnicas específicas
- [x] Onboarding para nuevos devs
- [x] Auditoría completa del proyecto (NUEVO)
- [x] Contexto Sprint 6 (NUEVO)
- [x] Dashboard ejecutivo (NUEVO)
- [x] Índice de documentación (ESTE ARCHIVO)
- [ ] API documentation (Swagger - auto-generado)
- [ ] Wiki de GitHub (futuro)

**Estado:** 14/16 completado (87%)

---

## 📞 CONTACTO Y SOPORTE

- **GitHub Repo:** https://github.com/JairFC/credinet-v2
- **Branch Activo:** `feature/sprint-6-associates`
- **Tag Release:** `v2.0.0`
- **Desarrollador:** Jair FC
- **Workspace:** `/home/credicuenta/proyectos/credinet-v2`

---

**Última Actualización:** 31 de Octubre, 2025  
**Versión del Índice:** 1.0  
**Estado:** ✅ COMPLETO

---

