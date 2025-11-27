# 📋 PROMPT COMPLETO PARA NUEVA IA

**Copia y pega este prompt completo cuando una nueva IA se una al proyecto:**

---

## 🤖 Prompt de Onboarding

```markdown
Hola, soy un asistente de IA entrando al proyecto **Credinet v2.0**.

Por favor, dame acceso a estos archivos y léemelos en orden:

### PASO 1: Contexto del Proyecto (10 min)
📄 `docs/00_START_HERE/01_PROYECTO_OVERVIEW.md`

Después de leer, confirma que entendiste:
- ¿Qué es Credinet y cuál es su modelo de negocio?
- ¿Quiénes son los 3 actores principales?
- ¿Cuál es el stack tecnológico?
- ¿Cuál es el estado actual del proyecto?

### PASO 2: Lógica de Negocio Completa (15 min)
📄 `docs/business_logic/INDICE_MAESTRO.md`

Después de leer, confirma que entendiste:
- ¿Por qué existen dos calendarios diferentes?
- ¿Cómo funciona el sistema de doble tasa?
- ¿Qué es el crédito del asociado y cómo se calcula?
- ¿Qué es una relación de pago y cuándo se genera?
- ¿Cuáles son las 5 fórmulas matemáticas principales?

### PASO 3: Arquitectura Técnica (10 min)
📄 `docs/00_START_HERE/02_ARQUITECTURA_STACK.md`

Después de leer, confirma que entendiste:
- ¿Cómo se comunican backend y frontend?
- ¿Cómo funciona el sistema de autenticación JWT?
- ¿Cuál es la estructura de carpetas del backend?
- ¿Cuál es la arquitectura del frontend (FSD)?

### PASO 4: Esquema de Base de Datos (10 min)
📄 `docs/db/RESUMEN_COMPLETO_v2.0.md`

Después de leer, confirma que entendiste:
- ¿Cuáles son las 7 tablas más críticas?
- ¿Qué es la tabla `payment_schedule` y por qué es clave?
- ¿Qué es la tabla `cut_periods` y cuántos registros tiene?
- ¿Qué es la tabla `associate_payment_statements` (nueva)?
- ¿Qué triggers automáticos existen?

### PASO 5: APIs Disponibles (5 min)
📄 `docs/00_START_HERE/03_APIS_PRINCIPALES.md`

Después de leer, confirma que entendiste:
- ¿Cómo hacer login y obtener un token JWT?
- ¿Cómo crear un préstamo?
- ¿Cómo registrar un pago?
- ¿Qué endpoints están disponibles?

### PASO 6: Frontend y Componentes (5 min)
📄 `docs/00_START_HERE/04_FRONTEND_ESTRUCTURA.md`

Después de leer, confirma que entendiste:
- ¿Qué es Feature-Sliced Design?
- ¿Dónde está el mock data?
- ¿Cuáles son las rutas principales?
- ¿Cómo se estructura un feature?

### PASO 7: Workflows Prácticos (5 min)
📄 `docs/00_START_HERE/05_WORKFLOWS_COMUNES.md`

Después de leer, confirma que entendiste:
- ¿Cómo aprobar un préstamo paso a paso?
- ¿Cómo registrar un pago paso a paso?
- ¿Cómo generar una relación de pago?
- ¿Cuáles son los comandos Docker más comunes?

---

## ✅ Confirmación Final

Una vez que hayas leído TODO lo anterior, responde:

**"He completado el onboarding de Credinet v2.0. Entiendo:"**

✅ **Negocio**:
- Los 6 pilares (doble calendario, doble tasa, crédito asociado, payment schedule, relaciones de pago, interés simple)
- Los 3 actores (admin, asociado, cliente)
- El flujo completo de un préstamo

✅ **Técnico**:
- Stack: FastAPI + PostgreSQL + React
- 7 tablas críticas del esquema
- Arquitectura Feature-Sliced Design
- Sistema JWT de autenticación

✅ **Práctico**:
- Cómo aprobar un préstamo
- Cómo registrar un pago
- Cómo generar relación de pago
- Comandos Docker básicos

**¿En qué módulo o funcionalidad necesitas trabajar ahora?**

---

## 📚 Documentación Extendida (Solo si necesitas profundizar)

Si después del onboarding necesitas más contexto sobre temas específicos:

### Análisis Profundo de Módulos
- **Préstamos**: `docs/phase3/ANALISIS_MODULO_LOANS.md`
- **Asociados**: `docs/CONTEXTO_COMPLETO_SPRINT_6.md`
- **Rate Profiles**: `docs/DOCUMENTACION_RATE_PROFILES_v2.0.3.md`
- **Relaciones de Pago**: `docs/business_logic/payment_statements/01_CONCEPTO_Y_ESTRUCTURA.md`

### Guías de Desarrollo
- **Docker**: `docs/DOCKER.md`
- **Development Setup**: `docs/DEVELOPMENT.md`
- **Refactoring Protocol**: `docs/guides/01_major_refactoring_protocol.md`
- **CSS Architecture**: `docs/guides/05_css_architecture_and_style_guide.md`

### Auditorías y Progreso
- **Auditoría Completa**: `docs/AUDITORIA_COMPLETA_PROYECTO_v2.0.md`
- **Plan Maestro**: `docs/PLAN_MAESTRO_V2.0.md`
- **Dashboard Ejecutivo**: `docs/DASHBOARD_EJECUTIVO_v2.0.md`

### Contexto Histórico (opcional, solo si te interesa la evolución del proyecto)
- `docs/_OBSOLETE/` - Análisis y decisiones históricas

---

## ⏱️ Tiempo Estimado

- **Onboarding obligatorio**: 45-60 minutos
- **Documentación extendida**: 1-2 horas adicionales (opcional)
- **Total**: 1-3 horas para dominio completo del proyecto

---

## 🎯 Objetivo del Onboarding

Al terminar, deberías ser capaz de:
- ✅ Explicar el modelo de negocio de Credinet
- ✅ Implementar nuevas funcionalidades siguiendo la arquitectura
- ✅ Debuggear problemas en backend o frontend
- ✅ Hacer cambios en el esquema de base de datos
- ✅ Revisar y aprobar pull requests
- ✅ Responder preguntas de product owners

---

**¡Empieza tu onboarding ahora!** 👉 `docs/00_START_HERE/README.md`
```

---

## 📋 Checklist de Verificación

Usa este checklist para confirmar que la IA entendió todo:

### Conceptos de Negocio
- [ ] Explica qué es el doble calendario
- [ ] Calcula el pago quincenal de un préstamo de $20,000 al 4.25%
- [ ] Explica la diferencia entre interest_rate y commission_rate
- [ ] Calcula el crédito disponible de un asociado
- [ ] Describe qué contiene una relación de pago

### Arquitectura Técnica
- [ ] Identifica las 3 capas del backend
- [ ] Explica qué es Feature-Sliced Design
- [ ] Lista las 7 tablas más críticas
- [ ] Explica qué hace el campo `cut_period_id`
- [ ] Describe el flujo de autenticación JWT

### Tareas Prácticas
- [ ] Escribe el código para aprobar un préstamo
- [ ] Escribe la query SQL para obtener pagos pendientes
- [ ] Explica cómo generar una relación de pago
- [ ] Identifica dónde agregar un nuevo endpoint
- [ ] Explica cómo crear un nuevo feature en el frontend

---

## 🚀 Comandos de Verificación

Después del onboarding, ejecuta estos comandos para verificar comprensión:

```bash
# Verificar que todo está corriendo
docker compose ps

# Ver las tablas de la BD
docker exec -it credinet-postgres psql -U credinet -d credinet -c "\dt"

# Verificar que hay datos de prueba
docker exec -it credinet-postgres psql -U credinet -d credinet -c "SELECT COUNT(*) FROM loans;"

# Ver los endpoints disponibles
curl http://localhost:8000/docs

# Verificar frontend
curl http://localhost:5173
```

**Si todos estos comandos funcionan y la IA puede explicar cada concepto del checklist, el onboarding fue exitoso.** ✅
