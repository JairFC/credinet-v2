# 📚 Documentación - Proyecto Credinet# Bienvenido a la Documentación de Credinet



Esta carpeta contiene toda la documentación técnica del proyecto, organizada por tema y fecha.Este directorio es el "cerebro" del proyecto Credinet. Contiene toda la información necesaria para entender, operar y extender el sistema. Está diseñado para ser la **única fuente de verdad** para todos los colaboradores, ya sean humanos o agentes de IA.



---## Épica Actual: Modernización de Perfiles de Usuario



## 📂 EstructuraActualmente, la iniciativa principal del proyecto es la **Modernización de Perfiles de Usuario**. Esto implica la fusión de la antigua tabla `clients` en la tabla `users`, la adición de campos de perfil enriquecidos (dirección, CURP), y la implementación de entidades relacionadas como `beneficiaries` y `associate_levels`. Puedes encontrar más detalles sobre el progreso y los próximos pasos en el [Resumen de Sesión](./session_summary.md).



### `/phase3/` - Fase 3 Actual (Backend + Database)## ¿Qué Buscas? Guía Rápida

Documentación de la fase actual del proyecto (sistema de liquidación de asociados).

-   **"Quiero entender cómo funciona el negocio (las reglas, los roles, los procesos)."**

- **AUDIT.md** - Auditoría completa del proyecto (Oct 1, 2025)    -   **Empieza aquí:** Lee los documentos en la carpeta `business_logic/` en orden numérico. Son la base de todo.

- **BACKEND_DATABASE.md** - Estado completo Phase 3 (Backend + Database)

-   **"Necesito entender la arquitectura técnica (qué tecnología usamos, cómo se conectan las partes)."**

### Documentación Técnica Activa    -   **Ve a:** La carpeta `system_architecture/`. Encontrarás diagramas, descripciones de los componentes (frontend, backend) y el esquema de la base de datos.



- **CONTEXT.md** - Contexto completo del proyecto (arquitectura, stack, credenciales)-   **"¿Cómo debo escribir o estructurar el CSS?"**

- **DEVELOPMENT.md** - Guía de desarrollo (setup, workflow, testing)    -   **Consulta:** La nueva [Guía de Arquitectura CSS](./guides/05_css_architecture_and_style_guide.md).

- **DEPLOYMENT.md** - Guía de deployment con Docker

- **context.json** - Contexto en formato JSON-   **"Quiero empezar a desarrollar o configurar mi entorno."**

- **README_OLD.md** - README anterior (backup)    -   **Sigue la guía:** El directorio `onboarding/` tiene las instrucciones paso a paso. Lee primero `01_developer_setup.md` y luego `02_system_health_check.md` para entender nuestras herramientas de calidad.



### `/archive/` - Documentación Histórica-   **"¿Por qué se tomó una decisión de diseño o arquitectura específica?"**

    -   **Consulta los registros:** La carpeta `adr/` (Architectural Decision Records) documenta las decisiones importantes y su justificación.

#### `/archive/2025-09/` - Septiembre 2025

Refactorizaciones iniciales, Clean Architecture, migraciones client_id/user_id.-   **"Necesito asumir un rol específico (ej. desarrollador backend)."**

    -   **Adopta una persona:** La carpeta `personas/` define los perfiles clave del proyecto, sus responsabilidades y las herramientas que utilizan.

Archivos principales:

- REFACTORIZACION_*.md - 6 refactorizaciones completadas## Protocolo de Actualización

- ANALISIS_*.md - Análisis de tablas, UX, duplicación

- MIGRACION_*.md - Migraciones de schemaLa documentación es código. Cualquier cambio en la funcionalidad o arquitectura **debe** ir acompañado de una actualización en los documentos relevantes.

- SISTEMA_*.md - Estados del sistema

-   **Cambio en la lógica de negocio:** Actualiza `business_logic/` y crea un `adr/` si la decisión es significativa.

#### `/archive/2025-10/` - Octubre 2025-   **Cambio en el código (API, DB):** Actualiza `system_architecture/`.

Fase 2 (Frontend V2), métricas, reportes, planes.-   **Añadir una nueva dependencia o cambiar el proceso de setup:** Actualiza `onboarding/`.



Archivos principales:## Épica Actual: Refactorización del Sistema de Roles

- FASE2_*.md - Documentación Fase 2

- PLAN_*.md - Planes de implementaciónActualmente, la iniciativa principal del proyecto es la **Refactorización del Sistema de Roles a un Modelo Puro**. Esto permitirá que los usuarios tengan múltiples roles y mejorará la flexibilidad del sistema de permisos. Puedes encontrar más detalles sobre el progreso y los próximos pasos en el [Resumen de Sesión](./session_summary.md).

- METRICAS_*.md - Métricas y visuales
- AUDITORIA_*.md - Auditorías intermedias
- RESUMEN_*.md - Resúmenes ejecutivos
- SPRINT_*.md - Reportes de sprints

---

## 🎯 Guía Rápida

### Para desarrolladores nuevos
1. Lee `CONTEXT.md` primero (30 min)
2. Sigue `DEVELOPMENT.md` para setup (1 hora)
3. Revisa `phase3/AUDIT.md` para estado actual (15 min)

### Para debugging
1. `phase3/BACKEND_DATABASE.md` - Estado actual del backend
2. `phase3/AUDIT.md` - Problemas conocidos y soluciones

### Para deployment
1. `DEPLOYMENT.md` - Guía completa de Docker

---

## 📊 Documentos Clave por Tema

### Arquitectura
- **CONTEXT.md** - Arquitectura Clean, módulos, capas
- **phase3/BACKEND_DATABASE.md** - Estructura backend

### Base de Datos
- **phase3/BACKEND_DATABASE.md** - Schema actual (Phase 3)
- **archive/2025-09/ANALISIS_COMPLETO_TABLAS_UX_UI.md** - Análisis de tablas

### Testing
- **DEVELOPMENT.md** - Cómo correr tests
- **phase3/AUDIT.md** - Estado actual de tests (94.4%)

### Refactorizaciones
- **archive/2025-09/** - Todas las refactorizaciones completadas

---

## ⚠️ Notas Importantes

1. **Documentación en `/archive/`** es de solo lectura (referencia histórica)
2. **Actualizar docs activas** cuando hagas cambios mayores
3. **No eliminar `/archive/`** - contiene decisiones técnicas importantes

---

**Última actualización**: Octubre 1, 2025  
**Mantenedor**: @JairFC
