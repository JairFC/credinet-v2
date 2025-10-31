# 🎯 GUÍA BACKEND V2.0 - CREDINET

**Fecha:** 30 de Octubre, 2025  
**Autor:** Análisis Técnico Completo  
**Propósito:** Entender estado actual, explicar migraciones, y planear Backend v2.0 desde cero

---

## 📊 ESTADO ACTUAL DEL PROYECTO

### Backend Actual (OBSOLETO)
```
backend/app/
├── 225 archivos Python
├── ~15 módulos mezclados
├── ❌ Usa tablas que NO existen en DB v2.0
├── ❌ Mezcla arquitecturas (algunas Clean, otras no)
└── ❌ Desalineado con lógica de negocio actual

PROBLEMAS CRÍTICOS:
- cutoff_versions → NO existe (debe ser cut_periods)
- payment_adjustments → NO existe
- payment_evidence → NO existe (debe ser client_documents)
- liquidate_payment() → NO existe (debe ser close_period_and_accumulate_debt())
```

### Base de Datos v2.0 (SÓLIDA ✅)
```
db/v2.0/
├── 36 tablas bien diseñadas (3NF)
├── 21 funciones de negocio
├── ~28 triggers automáticos
├── 9 vistas optimizadas
└── ✅ Lógica de negocio COMPLETA implementada

LÓGICA EN LA BASE DE DATOS:
✅ Generación automática de cronogramas de pago
✅ Cálculo de fechas quincenales (día 15 vs último día)
✅ Cierre de períodos con acumulación de deuda
✅ Sistema de morosidad (30% recargo)
✅ Actualización automática de crédito disponible
✅ Auditoría completa de cambios
✅ Validaciones de negocio (constrains, checks)
```

---

## 🤔 ¿QUÉ SON LAS MIGRACIONES? (ELI5)

### Analogía Simple

Imagina que tu base de datos es una **CASA**:

```
🏠 CONSTRUCCIÓN DE UNA CASA

OPCIÓN 1: Construir todo de golpe (init.sql)
├── Día 1: Poner toda la casa completa
├── Ventaja: Rápido si empiezas desde cero
└── Desventaja: Si ya hay gente viviendo, destruyes todo

OPCIÓN 2: Remodelar paso a paso (migraciones)
├── Semana 1: Agregar una habitación nueva
├── Semana 2: Cambiar la cocina
├── Semana 3: Arreglar el baño
└── Ventaja: La familia sigue viviendo, no destruyes nada
```

### En Términos Técnicos

**Archivo inicial (`init_monolithic.sql`):**
- Es la "casa completa" desde cero
- Se ejecuta **UNA SOLA VEZ** cuando creas la BD por primera vez
- Contiene: tablas, índices, funciones, triggers, seeds iniciales

**Migraciones (`migrations/07_*.sql`, `08_*.sql`, etc.):**
- Son "remodelaciones" que haces DESPUÉS
- Se ejecutan **EN ORDEN** sobre una BD que ya existe
- Cada migración agrega/modifica sin destruir lo anterior
- Ejemplos:
  - `07_associate_credit_tracking.sql` → Agrega sistema de crédito
  - `08_fix_period_closure_logic.sql` → Corrige función de cierre
  - `12_payment_status_history.sql` → Agrega historial de cambios

### ¿Por qué NO están en init.sql?

```
ESCENARIO REAL:

Enero 2025: Creas BD con init.sql
├── Sistema funciona, tienes 100 préstamos

Marzo 2025: Necesitas nueva función "reporte de morosos"
├── Opción A: Destruir BD y recrear (❌ PIERDES TODO)
├── Opción B: Crear migración 09_defaulted_clients.sql (✅ SOLO AGREGAS)
└── Ejecutas migración 09 → Se agrega sin tocar los 100 préstamos

Abril 2025: Necesitas historial de pagos
├── Opción A: Destruir BD (❌ PIERDES TODO + lo de marzo)
├── Opción B: Migración 12_payment_history.sql (✅ SOLO AGREGAS)
└── Ejecutas migración 12 → Historial listo, data intacta
```

### ¿Cuándo usar cada uno?

| Situación | Usar |
|-----------|------|
| BD nueva desde cero | `init_monolithic.sql` |
| BD existe, quiero nueva feature | Crear nueva migración |
| BD existe, corregir algo | Crear migración de fix |
| Development (sin data importante) | Destruir y usar init.sql |
| Producción (con data real) | SOLO migraciones, NUNCA destruir |

### Tu Situación Actual

```
TU CASO HOY:

db/v2.0/init_monolithic.sql (3,066 líneas)
├── Contiene: Schema completo v2.0
└── Estado: ✅ Consolidado y limpio

db/migrations/
├── 07_associate_credit_tracking.sql
├── 08_fix_period_closure_logic.sql
├── 09_defaulted_clients_tracking.sql
├── 10_late_fee_system.sql
├── 11_payment_statuses_consolidated.sql
└── 12_payment_status_history.sql

PROBLEMA: init_monolithic.sql NO incluye migraciones 07-12
SOLUCIÓN: Tienes 2 opciones:

OPCIÓN A: Consolidar todo en init_monolithic.sql v2.1
├── Integrar migraciones 07-12 dentro de init_monolithic.sql
├── Ahora init.sql tiene TODO
└── ✅ Recomendado para Development

OPCIÓN B: Mantener separadas
├── Ejecutar init_monolithic.sql primero
├── Luego ejecutar migraciones 07-12 en orden
└── ✅ Recomendado para Producción (si BD ya existe)
```

---

## 💡 ¿QUÉ VA EN LA DB VS EN EL BACKEND?

### Separación de Responsabilidades

```
╔═══════════════════════════════════════════════════════════╗
║                    BASE DE DATOS                          ║
╠═══════════════════════════════════════════════════════════╣
║ ✅ Lógica de NEGOCIO crítica (invariantes del dominio)   ║
║ ✅ Cálculos complejos (fechas, intereses, saldos)        ║
║ ✅ Validaciones de integridad (constraints)              ║
║ ✅ Automatizaciones (triggers para auditoría)            ║
║ ✅ Reglas que NUNCA deben romperse                       ║
║                                                           ║
║ EJEMPLOS EN CREDINET:                                     ║
║ • calculate_first_payment_date() → DB ✅                 ║
║ • generate_payment_schedule() → DB ✅                    ║
║ • close_period_and_accumulate_debt() → DB ✅             ║
║ • Sistema de morosidad 30% → DB ✅                       ║
║ • Actualización automática de crédito → DB ✅            ║
╚═══════════════════════════════════════════════════════════╝

╔═══════════════════════════════════════════════════════════╗
║                      BACKEND                              ║
╠═══════════════════════════════════════════════════════════╣
║ ✅ Lógica de APLICACIÓN (orquestación)                   ║
║ ✅ Validaciones de entrada (antes de llamar DB)          ║
║ ✅ Transformación de datos (DTOs, mappers)               ║
║ ✅ Autenticación y autorización (JWT, roles)             ║
║ ✅ Integración con servicios externos (email, SMS)       ║
║ ✅ Generación de PDFs, reportes complejos                ║
║ ✅ Cache, logging, métricas                              ║
║                                                           ║
║ EJEMPLOS EN CREDINET:                                     ║
║ • POST /loans → Validar input → Llamar DB ✅             ║
║ • GET /loans/123/schedule → Query DB → Formatear ✅      ║
║ • Autenticación JWT → Backend ✅                         ║
║ • Enviar email de aprobación → Backend ✅                ║
║ • Generar contrato PDF → Backend ✅                      ║
╚═══════════════════════════════════════════════════════════╝
```

### Ejemplo Concreto: Aprobar un Préstamo

```python
# ❌ MAL: Toda la lógica en el Backend
@router.post("/loans/{loan_id}/approve")
def approve_loan(loan_id: int):
    # Backend calcula fechas (❌ RIESGO: lógica duplicada)
    first_payment = calculate_first_payment_date(loan.approved_at)
    
    # Backend genera schedule (❌ RIESGO: inconsistencias)
    for i in range(loan.term_biweeks):
        payment_date = calculate_nth_payment(first_payment, i)
        db.execute("INSERT INTO payments ...")
    
    # Backend actualiza crédito (❌ RIESGO: race conditions)
    associate.credit_used += loan.amount
    
    return {"status": "approved"}


# ✅ BIEN: Backend orquesta, DB ejecuta lógica
@router.post("/loans/{loan_id}/approve")
def approve_loan(loan_id: int, current_user: User):
    # 1. Backend valida permisos
    if current_user.role not in ["admin", "desarrollador"]:
        raise HTTPException(403, "Sin permisos")
    
    # 2. Backend valida input
    loan = db.query(Loan).filter_by(id=loan_id).first()
    if not loan:
        raise HTTPException(404, "Préstamo no encontrado")
    if loan.status_id != 1:  # PENDING
        raise HTTPException(400, "Préstamo ya procesado")
    
    # 3. DB ejecuta TODA la lógica de negocio
    db.execute("""
        UPDATE loans 
        SET status_id = 2,  -- APPROVED
            approved_by = :user_id,
            approved_at = NOW()
        WHERE id = :loan_id
    """, {"loan_id": loan_id, "user_id": current_user.id})
    
    # ⚡ TRIGGERS automáticos en DB:
    #   → Genera cronograma completo
    #   → Calcula fechas correctas (día 15 vs último día)
    #   → Actualiza crédito del asociado
    #   → Crea contrato
    #   → Audita cambio
    
    # 4. Backend agrega tareas de aplicación
    send_approval_email(loan.user_id)  # Email
    log_action("LOAN_APPROVED", loan_id)  # Logging
    
    return {"status": "approved", "loan_id": loan_id}
```

### Entonces, ¿Backend solo hace CRUDs?

**NO. El Backend hace mucho más que CRUDs:**

```
RESPONSABILIDADES DEL BACKEND:

1. SEGURIDAD (crítico)
   ├── Autenticación JWT
   ├── Validación de permisos por rol
   ├── Rate limiting
   └── Sanitización de input

2. ORQUESTACIÓN (importante)
   ├── Coordinar múltiples operaciones
   ├── Transacciones complejas
   ├── Rollback si algo falla
   └── Retry logic

3. INTEGRACIÓN (importante)
   ├── Enviar emails/SMS
   ├── Generar PDFs
   ├── Webhooks
   └── APIs externas

4. PRESENTACIÓN (importante)
   ├── Transformar data DB → DTOs
   ├── Pagination
   ├── Sorting, filtering
   └── Agregaciones complejas

5. CACHÉ Y PERFORMANCE (importante)
   ├── Redis para datos hot
   ├── Query optimization
   ├── Background jobs
   └── Rate limiting

EJEMPLO: Endpoint GET /loans/123/full-details

Backend hace:
├── 1. Validar JWT (seguridad)
├── 2. Verificar permisos (solo owner o admin)
├── 3. Query DB: loan + payments + associate + client
├── 4. Transformar a DTO (ocultar campos sensibles)
├── 5. Calcular métricas (% pagado, días restantes)
├── 6. Agregar URLs de documentos
└── 7. Retornar JSON estructurado

DB hace:
└── Retornar data raw (solo SELECT)
```

---

## 🏗️ ARQUITECTURA BACKEND V2.0 (DESDE CERO)

### Estructura Propuesta (Clean Architecture)

```
backend/
├── pyproject.toml           # Poetry dependencies
├── pytest.ini               # Test config
├── .env.example            # Environment template
├── Dockerfile              # Container
│
├── app/
│   ├── main.py             # FastAPI app entry point
│   ├── config.py           # Settings (pydantic-settings)
│   │
│   ├── core/               # Core de la aplicación (shared)
│   │   ├── database.py     # SQLAlchemy engine, session
│   │   ├── security.py     # JWT, password hashing
│   │   ├── dependencies.py # Dependency injection
│   │   ├── exceptions.py   # Custom exceptions
│   │   └── middleware.py   # CORS, logging, error handlers
│   │
│   ├── domain/             # Modelos de dominio (SQLAlchemy)
│   │   ├── models/
│   │   │   ├── user.py
│   │   │   ├── loan.py
│   │   │   ├── payment.py
│   │   │   ├── associate.py
│   │   │   └── ...         # 1 archivo por tabla
│   │   └── schemas/        # Pydantic schemas (DTOs)
│   │       ├── user_schemas.py
│   │       ├── loan_schemas.py
│   │       └── ...
│   │
│   ├── api/                # API layer (routers)
│   │   ├── v1/
│   │   │   ├── router.py          # Main router aggregator
│   │   │   ├── auth.py            # POST /auth/login, /auth/register
│   │   │   ├── loans.py           # CRUD /loans
│   │   │   ├── payments.py        # CRUD /payments
│   │   │   ├── associates.py      # CRUD /associates
│   │   │   ├── clients.py         # CRUD /clients
│   │   │   ├── periods.py         # GET /periods, POST /periods/close
│   │   │   ├── documents.py       # Upload/download documentos
│   │   │   └── reports.py         # Reportes complejos
│   │   └── deps.py                # Dependency functions
│   │
│   ├── services/           # Application services (business logic)
│   │   ├── loan_service.py        # Orquestación de préstamos
│   │   ├── payment_service.py     # Orquestación de pagos
│   │   ├── auth_service.py        # Login, JWT, permissions
│   │   ├── notification_service.py # Emails, SMS
│   │   ├── report_service.py      # Generación de reportes
│   │   └── document_service.py    # Upload, storage
│   │
│   ├── repositories/       # Data access layer (opcional, si quieres)
│   │   ├── loan_repository.py
│   │   ├── payment_repository.py
│   │   └── ...             # Abstracción sobre SQLAlchemy
│   │
│   ├── utils/              # Utilidades
│   │   ├── dates.py        # Helpers de fechas
│   │   ├── pdf_generator.py
│   │   ├── validators.py   # Validaciones custom
│   │   └── formatters.py
│   │
│   └── tests/              # Tests
│       ├── conftest.py
│       ├── test_auth.py
│       ├── test_loans.py
│       └── ...

└── deprecated/             # Backend viejo (solo referencia)
    └── app_old/            # Los 225 archivos actuales
```

### Módulos Alineados a DB v2.0

| Tabla DB | Router | Service | Responsabilidad |
|----------|--------|---------|-----------------|
| `users` | `auth.py` | `auth_service.py` | Login, JWT, roles |
| `loans` | `loans.py` | `loan_service.py` | CRUD + aprobar/rechazar |
| `payments` | `payments.py` | `payment_service.py` | Registrar pagos, consultas |
| `associate_profiles` | `associates.py` | `associate_service.py` | CRUD + niveles + crédito |
| `cut_periods` | `periods.py` | `period_service.py` | Listar + cerrar período |
| `client_documents` | `documents.py` | `document_service.py` | Upload/download |
| `agreements` | `agreements.py` | `agreement_service.py` | CRUD convenios |
| `defaulted_client_reports` | `reports.py` | `report_service.py` | Reportes morosos |

### Ejemplo: Router de Loans (Simplificado)

```python
# app/api/v1/loans.py

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.core.dependencies import get_db, get_current_user
from app.domain.schemas.loan_schemas import LoanCreate, LoanResponse
from app.services.loan_service import LoanService

router = APIRouter(prefix="/loans", tags=["loans"])

@router.post("/", response_model=LoanResponse)
def create_loan(
    loan_data: LoanCreate,
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    """
    Crear solicitud de préstamo.
    Admin crea a nombre de cliente.
    """
    service = LoanService(db)
    loan = service.create_loan(loan_data, created_by=current_user.id)
    return loan

@router.post("/{loan_id}/approve")
def approve_loan(
    loan_id: int,
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    """
    Aprobar préstamo.
    Solo admin/desarrollador.
    DB genera cronograma automáticamente.
    """
    if current_user.role not in ["admin", "desarrollador"]:
        raise HTTPException(403, "Sin permisos")
    
    service = LoanService(db)
    loan = service.approve_loan(loan_id, approved_by=current_user.id)
    return {"status": "approved", "loan": loan}

@router.get("/{loan_id}/schedule")
def get_payment_schedule(
    loan_id: int,
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    """
    Obtener cronograma de pagos.
    Cliente ve su préstamo, admin ve todos.
    """
    service = LoanService(db)
    schedule = service.get_payment_schedule(loan_id, user=current_user)
    return schedule
```

### Ejemplo: Service de Loans

```python
# app/services/loan_service.py

from sqlalchemy.orm import Session
from app.domain.models.loan import Loan
from app.domain.schemas.loan_schemas import LoanCreate
from app.core.exceptions import BusinessException

class LoanService:
    def __init__(self, db: Session):
        self.db = db
    
    def create_loan(self, data: LoanCreate, created_by: int):
        """Crear préstamo con validaciones."""
        
        # 1. Validar que cliente no sea moroso
        client = self.db.query(User).filter_by(id=data.user_id).first()
        if not client:
            raise BusinessException("Cliente no encontrado")
        if client.is_defaulter:
            raise BusinessException("Cliente moroso, no puede solicitar préstamo")
        
        # 2. Validar crédito del asociado
        result = self.db.execute("""
            SELECT * FROM check_associate_credit_available(:assoc_id, :amount)
        """, {"assoc_id": data.associate_id, "amount": data.amount}).first()
        
        if not result.has_credit:
            raise BusinessException(
                f"Asociado sin crédito suficiente. "
                f"Disponible: ${result.credit_available}, "
                f"Faltante: ${result.shortage}"
            )
        
        # 3. Crear préstamo
        loan = Loan(
            user_id=data.user_id,
            associate_id=data.associate_id,
            amount=data.amount,
            term_biweeks=data.term_biweeks,
            status_id=1,  # PENDING
            created_by=created_by
        )
        self.db.add(loan)
        self.db.commit()
        self.db.refresh(loan)
        
        return loan
    
    def approve_loan(self, loan_id: int, approved_by: int):
        """
        Aprobar préstamo.
        DB hace TODO: genera schedule, actualiza crédito, crea contrato.
        """
        loan = self.db.query(Loan).filter_by(id=loan_id).first()
        if not loan:
            raise BusinessException("Préstamo no encontrado")
        
        if loan.status_id != 1:  # PENDING
            raise BusinessException("Préstamo ya procesado")
        
        # DB hace la magia ✨
        loan.status_id = 2  # APPROVED
        loan.approved_by = approved_by
        loan.approved_at = func.now()
        
        self.db.commit()
        self.db.refresh(loan)
        
        # Triggers DB ya generaron:
        # - Cronograma completo en payments
        # - Actualización de crédito en associate_profiles
        # - Contrato en contracts
        
        # Backend agrega tareas de aplicación
        from app.services.notification_service import send_loan_approved_email
        send_loan_approved_email(loan.user_id, loan_id)
        
        return loan
```

---

## 🚀 PLAN DE ACCIÓN

### Fase 1: Preparación (15 min)

```bash
# 1. Mover backend actual a deprecated
cd /home/credicuenta/proyectos/credinet
mv backend/app backend/app_deprecated

# 2. Crear estructura limpia
mkdir -p backend/app/{core,domain/{models,schemas},api/v1,services,utils,tests}

# 3. Git checkpoint (antes de cambios grandes)
git add .
git commit -m "📦 Respaldar backend actual antes de v2.0"
git tag v2.0-pre-backend-rewrite
```

### Fase 2: Consolidar DB (30 min)

**Decidir:** ¿Integrar migraciones 07-12 en init_monolithic.sql?

**Opción A (RECOMENDADA):** Consolidar todo
```bash
# Crear init_monolithic.sql v2.1 con migraciones integradas
cd db/v2.0
cat init_monolithic.sql \
    ../migrations/07_*.sql \
    ../migrations/08_*.sql \
    ../migrations/09_*.sql \
    ../migrations/10_*.sql \
    ../migrations/11_*.sql \
    ../migrations/12_*.sql > init_monolithic_v2.1.sql

# Validar sintaxis
docker exec -i credinet-postgres psql -U credinet_user -d postgres -c "CREATE DATABASE test_db;"
docker exec -i credinet-postgres psql -U credinet_user -d test_db < init_monolithic_v2.1.sql
docker exec -i credinet-postgres psql -U credinet_user -d postgres -c "DROP DATABASE test_db;"
```

**Opción B:** Mantener separadas (si ya tienes data en producción)

### Fase 3: Crear Backend v2.0 Core (2 horas)

```bash
# Instalar dependencias
cd backend
poetry init  # o usar pip con requirements.txt

# Dependencias necesarias
poetry add fastapi uvicorn sqlalchemy psycopg2-binary pydantic-settings \
           python-jose[cryptography] passlib[bcrypt] python-multipart

# Crear archivos core
touch app/main.py
touch app/config.py
touch app/core/{database,security,dependencies,exceptions,middleware}.py
```

### Fase 4: Implementar Módulos por Prioridad (4-6 horas)

**Prioridad ALTA (implementar primero):**
1. `auth.py` + `auth_service.py` → Login, JWT
2. `loans.py` + `loan_service.py` → CRUD + aprobar
3. `payments.py` + `payment_service.py` → Registrar pagos

**Prioridad MEDIA:**
4. `associates.py` + `associate_service.py` → CRUD + crédito
5. `clients.py` + `client_service.py` → CRUD clientes
6. `periods.py` + `period_service.py` → Cerrar período

**Prioridad BAJA (después):**
7. `documents.py` → Upload docs
8. `reports.py` → Reportes morosos
9. `agreements.py` → Convenios

### Fase 5: Testing (2 horas)

```bash
# Tests básicos
pytest app/tests/test_auth.py -v
pytest app/tests/test_loans.py -v

# Test integración
docker-compose up -d
curl http://localhost:8000/docs  # Swagger UI
```

### Fase 6: Git y GitHub (30 min)

```bash
# Commit Backend v2.0
git add backend/app docs/GUIA_BACKEND_V2.0.md
git commit -m "🎉 Backend v2.0 desde cero - Clean Architecture

- Estructura modular: core, domain, api, services
- Alineado con DB v2.0 (36 tablas, 21 funciones)
- Módulos: auth, loans, payments, associates, periods
- Lógica de negocio en DB, backend orquesta
- Backend viejo movido a app_deprecated/"

# Tag v2.0.0
git tag -a v2.0.0 -m "Credinet 2.0 - DB consolidada + Backend reescrito"

# Push a GitHub
git push origin feature/frontend-v2-docker-development
git push origin v2.0.0

# Opcional: Branch nueva para 2.0
git checkout -b credinet-2.0
git push origin credinet-2.0
```

---

## 📝 RESUMEN EJECUTIVO

### ¿Qué tenemos HOY?

✅ **DB v2.0:** Sólida, 36 tablas, 21 funciones, lógica completa  
❌ **Backend:** 225 archivos obsoletos, desalineado con DB  
✅ **Frontend:** React funcional  
✅ **Docker:** Compose modernizado

### ¿Qué hacemos?

1. **Respaldar backend actual** (no borrar, solo mover)
2. **Crear Backend v2.0 desde cero** (Clean Architecture, 4-6 horas)
3. **Consolidar DB** (integrar migraciones 07-12 en init.sql)
4. **Git checkpoint** (tag v2.0.0, push a GitHub)

### ¿Por qué Backend solo "CRUDs"?

**NO es solo CRUDs.** Backend hace:
- Seguridad (JWT, permisos)
- Orquestación (coordinar operaciones complejas)
- Integración (emails, PDFs, APIs externas)
- Transformación (DTOs, formateo)
- Cache, logging, métricas

**Pero la lógica de negocio crítica está en DB:**
- Cálculos de fechas
- Generación de cronogramas
- Cierre de períodos
- Sistema de morosidad
- Actualización de crédito

**Esto es CORRECTO y profesional.**

### ¿Vamos a romper algo?

**NO, si seguimos el plan:**
1. Movemos backend actual a `app_deprecated/` (respaldo)
2. Creamos `app/` nuevo desde cero
3. Docker apunta a `app/` nuevo
4. Si algo falla, revertimos a `app_deprecated/`

### ¿Subir a Git/GitHub?

**SÍ, ahora es el momento perfecto:**
- DB v2.0 consolidada
- Backend v2.0 limpio
- Docker modernizado
- Tag `v2.0.0` marca hito importante

---

## 💬 RESPUESTAS A TUS PREGUNTAS

**1. ¿Qué son las migraciones?**
→ "Remodelaciones" que agregas a una BD existente sin destruirla. Ver sección "ELI5" arriba.

**2. ¿Por qué existen migraciones si tenemos init.sql?**
→ `init.sql` es la casa completa desde cero. Migraciones son para agregar cosas después sin destruir data.

**3. ¿Backend solo hace CRUDs?**
→ No. Hace seguridad, orquestación, integraciones, transformación. Pero lógica crítica está en DB (correcto).

**4. ¿Vamos a romper el proyecto?**
→ No si respaldamos primero (`app_deprecated/`). Creamos `app/` nuevo, probamos, y si falla revertimos.

**5. ¿Subir a Git/GitHub?**
→ Sí, ahora es el momento. Tag `v2.0.0`, push a `credinet-2.0` branch opcional.

**6. ¿Credinet 2.0?**
→ Sí, este ES Credinet 2.0: DB limpia, backend reescrito, arquitectura profesional.

---

## ✅ PRÓXIMOS PASOS

**¿Qué hacemos ahora?**

1. **¿Apruebas el plan?** (mover backend a deprecated, crear v2.0)
2. **¿Consolidar migraciones en init.sql?** (recomendado: Opción A)
3. **¿Empezamos con Fase 1?** (respaldar backend, 15 min)

**Dime y ejecutamos paso a paso. 🚀**
