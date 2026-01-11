# DIAGNÓSTICO: Sistema de Convenios y Roles v2.0.5
## Fecha: 2025-11-25
## Estado Actual del Sistema

---

## 📊 RESUMEN EJECUTIVO

Este documento detalla el estado **real** del código implementado vs lo que existe solo en base de datos o documentación.

---

## 1️⃣ SISTEMA DE CONVENIOS (AGREEMENTS)

### Estado: 🟡 PARCIALMENTE IMPLEMENTADO

#### ✅ EXISTE EN BASE DE DATOS:

```sql
-- Tablas
agreements                    -- Convenio principal
agreement_items               -- Items del convenio (préstamos morosos)
agreement_payments            -- Pagos del convenio
defaulted_client_reports      -- Reportes de clientes morosos
associate_debt_breakdown      -- Desglose de deuda del asociado
```

**Tabla `agreements`:**
| Campo | Tipo | Descripción |
|-------|------|-------------|
| id | SERIAL | PK |
| associate_profile_id | INTEGER | FK al asociado |
| agreement_number | VARCHAR | Número de convenio |
| total_debt_amount | DECIMAL | Monto total de deuda |
| payment_plan_months | INTEGER | Plazo en meses |
| monthly_payment_amount | DECIMAL | Pago mensual |
| status | VARCHAR | ACTIVE, COMPLETED, DEFAULTED, CANCELLED |
| start_date, end_date | DATE | Periodo del convenio |

**Tabla `agreement_items`:**
| Campo | Tipo | Descripción |
|-------|------|-------------|
| id | SERIAL | PK |
| agreement_id | INTEGER | FK al convenio |
| loan_id | INTEGER | FK al préstamo moroso |
| client_user_id | INTEGER | FK al cliente moroso |
| debt_amount | DECIMAL | Deuda de este item |
| debt_type | VARCHAR | UNREPORTED_PAYMENT, DEFAULTED_CLIENT, LATE_FEE, OTHER |

**Tabla `defaulted_client_reports`:**
| Campo | Tipo | Descripción |
|-------|------|-------------|
| id | SERIAL | PK |
| associate_profile_id | INTEGER | FK |
| loan_id | INTEGER | Préstamo reportado |
| client_user_id | INTEGER | Cliente moroso |
| total_debt_amount | DECIMAL | Deuda total |
| evidence_details | TEXT | Descripción de evidencia |
| evidence_file_path | VARCHAR | Archivo de evidencia |
| status | VARCHAR | PENDING, APPROVED, REJECTED, IN_REVIEW |
| approved_by, approved_at | - | Aprobación |

#### ✅ FUNCIONES SQL EXISTEN:

```sql
-- Funciones implementadas
report_defaulted_client(...)      -- Reportar cliente moroso → PENDING
approve_defaulted_client_report(...)  -- Aprobar reporte → APPROVED + suma a debt_balance
```

#### ✅ BACKEND PARCIAL:

```
backend/app/modules/agreements/
├── routes.py                 -- ❌ SOLO 2 endpoints READ
├── application/
│   └── dtos/
│       └── agreement_dto.py  -- ✅ DTOs completos
│   └── use_cases/           -- ❌ Solo List y Get
├── domain/
│   └── entities/            -- ✅ Agreement entity
├── infrastructure/
│   └── repositories/        -- ✅ PgAgreementRepository
```

**Endpoints actuales:**
- `GET /agreements` - Lista convenios paginados ✅
- `GET /agreements/associates/{id}` - Convenios de un asociado ✅

**❌ FALTA:**
- `POST /agreements` - Crear convenio
- `PUT /agreements/{id}` - Actualizar convenio
- `POST /defaulted-client-reports` - Crear reporte de moroso
- `PUT /defaulted-client-reports/{id}/approve` - Aprobar reporte
- `PUT /defaulted-client-reports/{id}/reject` - Rechazar reporte
- `GET /defaulted-client-reports` - Listar reportes

#### ❌ FRONTEND: NO IMPLEMENTADO

- No hay componentes para convenios
- No hay vistas para reportar morosos
- `clients_in_agreement` se muestra en AssociateDetailPage pero solo es un contador, no funcional

---

## 2️⃣ SISTEMA DE CONVERSIÓN CLIENTE ↔ ASOCIADO

### Estado: 🟡 INFRAESTRUCTURA EXISTE, NO HAY UI

#### ✅ EXISTE EN BASE DE DATOS:

```sql
-- Sistema de roles multi-role
roles                -- 5 roles: desarrollador, administrador, auxiliar_administrativo, asociado, cliente
user_roles           -- user_id + role_id (permite múltiples roles por usuario)
```

**Roles actuales:**
| ID | Name |
|----|------|
| 1 | desarrollador |
| 2 | administrador |
| 3 | auxiliar_administrativo |
| 4 | asociado |
| 5 | cliente |

**Estado actual:** Ningún usuario tiene múltiples roles actualmente.

#### ✅ MODELO PERMITE MULTI-ROLE:

El diseño de `user_roles` (user_id, role_id) como tabla de unión **ya permite** que un usuario tenga ambos roles cliente Y asociado.

```sql
-- Ejemplo de lo que se necesita para agregar rol
INSERT INTO user_roles (user_id, role_id) 
VALUES (123, 4);  -- Agregar rol "asociado" (id=4) al usuario 123
```

#### ❌ FALTA IMPLEMENTAR:

**Backend:**
- Endpoint para agregar/quitar roles a un usuario
- Lógica para crear `associate_profile` cuando se agrega rol asociado
- Validaciones de negocio

**Frontend:**
- UI para gestionar roles de usuario
- Vista en perfil de usuario para ver roles activos
- Flujo para "promocionar" cliente a asociado

---

## 3️⃣ SISTEMA DE RENOVACIÓN

### Estado: 🟢 IMPLEMENTADO Y FUNCIONAL

#### ✅ FRONTEND COMPLETO:

**Archivo:** `frontend-mvp/src/features/loans/pages/LoanCreatePage.jsx`

**Características implementadas:**
- Detecta automáticamente si el cliente tiene préstamos activos
- Muestra sección colapsable "🔄 Renovación de Préstamo"
- Lista préstamos activos con:
  - Monto original
  - Pagos pendientes
  - Saldo a liquidar
  - Comisiones pendientes
- Validación: monto nuevo >= saldo pendiente
- Botón "🔄 Renovar este préstamo"
- Paginación si hay múltiples préstamos activos

**Flujo:**
1. Seleccionar cliente → detecta préstamos activos
2. Click en "Renovar este préstamo"
3. El sistema pre-llena monto mínimo
4. Llama a `loansService.renew(payload)`
5. Muestra resumen: préstamo liquidado, comisiones para asociado, neto para cliente

#### ✅ BACKEND COMPLETO:

**Endpoint:** `POST /loans/renew`
**Función SQL:** `renew_loan(...)`

**Lógica:**
1. Valida monto >= saldo pendiente
2. Marca pagos pendientes del préstamo anterior como PAID
3. Calcula comisiones pendientes para el asociado
4. Crea nuevo préstamo APPROVED automáticamente
5. Crea registro en `loan_renewals`
6. Retorna `renewal_info` con detalles

---

## 4️⃣ PÁGINA DE PAGOS (/pagos)

### Estado: 🔴 EXISTE PERO NO ACCESIBLE

**Ruta definida:** `/pagos` → `PaymentsPage.jsx`

**Problema:** No hay enlace en `Navbar.jsx`

**Navegación actual en Navbar:**
- Dashboard
- Préstamos (Gestión / Nuevo / Simulador)
- Estados de Cuenta
- Usuarios (Clientes / Asociados)
- Reportes

**No incluye:** `/pagos`

**Conclusión:** El componente existe pero está "huérfano" - no accesible desde la UI principal.

---

## 📋 PLAN DE IMPLEMENTACIÓN

### PRIORIDAD 1: Sistema de Convenios (Alto impacto)

**1.1 Backend (2-3 días)**
```
1. Crear endpoint POST /defaulted-client-reports
   - Llamar función SQL report_defaulted_client()
   - Subir archivo de evidencia

2. Crear endpoint PUT /defaulted-client-reports/{id}/approve
   - Llamar función SQL approve_defaulted_client_report()
   - Validar permisos admin

3. Crear endpoint PUT /defaulted-client-reports/{id}/reject
   - Actualizar status a REJECTED
   - Guardar rejection_reason

4. Crear endpoints CRUD para agreements
   - POST /agreements (crear convenio con items)
   - PUT /agreements/{id} (actualizar status, pagos)
   - GET /agreements/{id} (detalle con items)
```

**1.2 Frontend (3-4 días)**
```
1. Componente ReportDefaultedClientModal
   - Form para reportar cliente moroso
   - Upload de evidencia
   - Selección de préstamos a reportar

2. Página DefaultedClientReportsPage (/reportes/morosos)
   - Lista de reportes pendientes
   - Botones aprobar/rechazar (admin)
   - Filtros por status, asociado

3. Página AgreementsPage (/convenios)
   - Lista de convenios
   - Crear convenio (seleccionar reportes aprobados)
   - Detalle de convenio con pagos

4. Agregar a Navbar
   - Reportes → Clientes Morosos
   - Nuevo menú "Convenios" (o dentro de Asociados)
```

### PRIORIDAD 2: Conversión Cliente ↔ Asociado (Medio impacto)

**2.1 Backend (1-2 días)**
```
1. Endpoint POST /users/{id}/roles
   - Agregar rol a usuario
   - Si rol=asociado → crear associate_profile

2. Endpoint DELETE /users/{id}/roles/{role_id}
   - Quitar rol de usuario
   - Validar que no tenga préstamos activos si es asociado

3. Endpoint GET /users/{id}/roles
   - Listar roles del usuario
```

**2.2 Frontend (2 días)**
```
1. Componente UserRolesManager
   - Checkboxes para roles cliente/asociado
   - Confirmación al cambiar

2. Integrar en UserDetailPage o modal
   - Sección "Roles del usuario"
   - Botón "Hacer asociado" / "Hacer cliente"

3. Actualizar AssociateCreatePage
   - Opción de crear desde usuario existente
   - O crear nuevo usuario + rol
```

### PRIORIDAD 3: Página de Pagos (Bajo impacto)

**Decisión requerida:** ¿Activar o eliminar?

Si activar:
- Agregar enlace en Navbar
- Revisar que el componente funcione correctamente

Si eliminar:
- Quitar ruta de index.jsx
- Eliminar componente PaymentsPage.jsx
- Limpiar imports

---

## 🔧 ACCIONES INMEDIATAS RECOMENDADAS

1. **Confirmar scope** - ¿Qué implementar primero?
2. **Backend convenios** - Es la base para el flujo de morosos
3. **Frontend convenios** - Una vez que backend esté listo
4. **Testing** - Crear tests para el flujo completo

---

## 📁 ARCHIVOS CLAVE

### Backend Convenios:
- `backend/app/modules/agreements/routes.py`
- `backend/app/modules/agreements/application/use_cases/`

### Frontend Renovación:
- `frontend-mvp/src/features/loans/pages/LoanCreatePage.jsx`

### DB Funciones:
- `db/v2.0/modules/06_functions_business.sql`
- `db/v2.0/modules/04_audit_tables.sql`

### Navegación:
- `frontend-mvp/src/shared/components/layout/Navbar.jsx`
- `frontend-mvp/src/app/routes/index.jsx`
