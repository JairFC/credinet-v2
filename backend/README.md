# 🚀 CrediNet Backend v2.0 - Clean Architecture

> Sistema de gestión de créditos quincenales con arquitectura limpia basada en Domain-Driven Design (DDD)

**Estado**: 🏗️ En reconstrucción - Empezando desde cero con base sólida  
**Fuente de Verdad**: [`/db/v2.0/modules/`](../db/v2.0/modules/) (9 archivos SQL - 3,240 líneas)  
**Fecha**: 2025-10-30  

---

## 📊 Estado Actual

### ✅ Implementado (Infraestructura Base)
- ✅ **Core Layer** - Configuración, Database, Security, Middleware, Exceptions
- ✅ **Clean Architecture** - Estructura base siguiendo DDD
- ✅ **FastAPI** - Framework web con OpenAPI docs
- ✅ **PostgreSQL** - Conexión con SQLAlchemy 2.0
- ✅ **JWT Auth** - Seguridad con python-jose
- ✅ **Docker** - Containerización completa

### 🔨 Por Implementar (8 módulos)
1. **catalogs/** - 12 catálogos (roles, statuses, levels, types)
2. **loans/** - Gestión préstamos (CRUD + approval + schedule)
3. **payments/** - Seguimiento pagos (CRUD + audit + fraud detection)
4. **associates/** - Perfiles asociados (credit tracking + statements)
5. **contracts/** - Generación contratos (PDF + signatures)
6. **agreements/** - Convenios de pago (debt consolidation)
7. **cut_periods/** - Períodos quincenales (closure + debt accumulation)
8. **documents/** - Gestión documentos (upload + review)

---

## 🏗️ Arquitectura Clean

### Estructura del Proyecto

```
backend/
├── app/
│   ├── core/                      # ✅ INFRAESTRUCTURA BASE
│   │   ├── config.py              # Configuración (pydantic-settings)
│   │   ├── database.py            # SQLAlchemy setup
│   │   ├── security.py            # JWT + password hashing
│   │   ├── middleware.py          # CORS + error handlers
│   │   ├── exceptions.py          # Custom exceptions
│   │   └── dependencies.py        # FastAPI dependencies
│   │
│   ├── modules/                   # 🔨 MÓDULOS DE DOMINIO (por implementar)
│   │   └── __init__.py            # Documentación módulos
│   │
│   └── main.py                    # FastAPI app principal
│
├── docs/
│   ├── README.md                  # Documentación detallada
│   └── ROADMAP_v2.md              # Plan de implementación (30 semanas)
│
├── Dockerfile                     # Containerización
├── requirements.txt               # Dependencias Python
├── pytest.ini                     # Configuración tests
├── pyproject.toml                 # Metadata proyecto
└── .env.example                   # Variables de entorno ejemplo
```

### Capas de Clean Architecture

```
┌─────────────────────────────────────┐
│   Presentation Layer (FastAPI)      │  routes.py
├─────────────────────────────────────┤
│   Application Layer                 │  use_cases/ + dtos/
├─────────────────────────────────────┤
│   Domain Layer                      │  entities/ + repositories/
├─────────────────────────────────────┤
│   Infrastructure Layer              │  postgresql/ + external/
└─────────────────────────────────────┘
```

**Reglas de Dependencia**:
1. ✅ Domain NO depende de nadie
2. ✅ Application depende solo de Domain
3. ✅ Infrastructure implementa interfaces de Domain
4. ✅ Presentation depende de Application

---

## 🗄️ Base de Datos v2.0 (Fuente de Verdad)

### Resumen Completo

| Categoría | Cantidad | Estado |
|-----------|----------|--------|
| **Tablas Totales** | 45 tables | 0% implementado |
| **Catálogos** | 12 tables | 0% implementado |
| **Core Tables** | 11 tables | 0% implementado |
| **Business Tables** | 8 tables | 0% implementado |
| **Audit Tables** | 4 tables | 0% implementado |
| **Funciones DB** | 16 functions | 0% integrado |
| **Triggers** | 28+ triggers | 0% documentado |
| **Vistas** | 9 views | 0% integrado |

### Funciones Críticas a Integrar

1. **`calculate_first_payment_date()`** ⭐ - Oráculo del doble calendario
2. **`generate_payment_schedule()`** ⭐ - Genera cronograma completo
3. **`close_period_and_accumulate_debt()`** ⭐ - Cierra período quincenal
4. **`admin_mark_payment_status()`** - Marca pagos manualmente
5. **`get_payment_history()`** - Timeline forense auditoría
6. **`check_associate_credit_available()`** - Valida crédito disponible
7. **`calculate_late_fee_for_statement()`** - Mora del 30%
8. **`renew_loan()`** - Renueva préstamo existente

Ver documentación completa en: [`/db/v2.0/modules/`](../db/v2.0/modules/)

---

## 🚀 Quick Start

### 1. Requisitos

- Python 3.11+
- PostgreSQL 15+
- Docker & Docker Compose (opcional)

### 2. Instalación

```bash
# Clonar repositorio
git clone <repo-url>
cd credinet/backend

# Crear entorno virtual
python -m venv venv
source venv/bin/activate  # Linux/Mac
# venv\Scripts\activate   # Windows

# Instalar dependencias
pip install -r requirements.txt

# Configurar variables de entorno
cp .env.example .env
# Editar .env con tus credenciales
```

### 3. Configuración Base de Datos

```bash
# Opción A: Docker (recomendado)
cd ..  # Volver a raíz del proyecto
docker-compose up -d postgres

# Opción B: PostgreSQL local
createdb credinet_db

# Inicializar DB v2.0
psql credinet_db < ../db/v2.0/init.sql
```

### 4. Ejecutar Backend

```bash
# Desarrollo
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# Producción (Docker)
docker-compose up backend
```

### 5. Verificar

- **API Docs**: http://localhost:8000/docs
- **Health Check**: http://localhost:8000/health

---

## 📚 Tecnologías

### Core Stack

| Categoría | Tecnología | Versión | Uso |
|-----------|-----------|---------|-----|
| **Framework** | FastAPI | 0.104+ | Web framework async |
| **ORM** | SQLAlchemy | 2.0+ | Database ORM |
| **Database** | PostgreSQL | 15+ | Base de datos |
| **Validation** | Pydantic | 2.5+ | Data validation |
| **Auth** | python-jose | 3.3+ | JWT tokens |
| **Security** | passlib + bcrypt | 1.7+ / 4.0+ | Password hashing |
| **Testing** | pytest | 7.4+ | Unit/integration tests |
| **Server** | uvicorn | 0.24+ | ASGI server |

### Dependencias Principales

```txt
fastapi==0.104.1
uvicorn[standard]==0.24.0
sqlalchemy==2.0.23
psycopg2-binary==2.9.9
pydantic==2.5.0
pydantic-settings==2.1.0
python-jose[cryptography]==3.3.0
passlib[bcrypt]==1.7.4
pytest==7.4.3
```

---

## 🔧 Desarrollo

### Estructura de Módulo (Ejemplo: loans)

```
app/modules/loans/
├── domain/
│   ├── entities/
│   │   └── loan.py                 # Entity alineada con DB
│   └── repositories/
│       └── loan_repository.py      # Interface (ABC)
│
├── application/
│   ├── use_cases/
│   │   ├── create_loan.py          # Use case: crear préstamo
│   │   ├── approve_loan.py         # Use case: aprobar préstamo
│   │   └── get_remaining_balance.py # Use case: calcular saldo
│   └── dtos/
│       └── loan_dtos.py            # Request/Response DTOs
│
├── infrastructure/
│   ├── repositories/
│   │   └── postgresql_loan_repository.py  # Implementación PostgreSQL
│   └── models/
│       └── loan_model.py           # SQLAlchemy model
│
└── routes.py                       # FastAPI endpoints
```

### Convenciones

- **Entities**: Dataclasses con validaciones de dominio
- **Repositories**: Interfaces ABC en domain, implementaciones en infrastructure
- **Use Cases**: Un archivo = una acción (SRP)
- **DTOs**: Pydantic models para request/response
- **Models**: SQLAlchemy models solo en infrastructure

---

## 🧪 Testing

```bash
# Ejecutar todos los tests
pytest

# Tests con cobertura
pytest --cov=app --cov-report=html

# Tests específicos
pytest tests/unit/test_loan_entity.py
pytest tests/integration/test_loan_repository.py
```

---

## 📖 Documentación Adicional

- **[ROADMAP_v2.md](./docs/ROADMAP_v2.md)** - Plan de implementación completo (30 semanas)
- **[AUDITORIA_BACKEND_COMPLETA_v2.0.md](../AUDITORIA_BACKEND_COMPLETA_v2.0.md)** - Auditoría exhaustiva backend vs DB
- **[LOGICA_DE_NEGOCIO_DEFINITIVA.md](../docs/LOGICA_DE_NEGOCIO_DEFINITIVA.md)** - Lógica de negocio completa (1,215 líneas)
- **[db/v2.0/modules/](../db/v2.0/modules/)** - SQL fuente de verdad (9 archivos, 3,240 líneas)

---

## 🤝 Contribución

### Workflow

1. Revisar [ROADMAP_v2.md](./docs/ROADMAP_v2.md) para ver qué implementar
2. Crear branch: `git checkout -b feature/module-name`
3. Implementar siguiendo Clean Architecture
4. Tests con cobertura mínima 80%
5. Pull Request con descripción detallada

### Checklist Implementación Módulo

- [ ] Entity alineada 100% con DB v2.0
- [ ] Repository interface (ABC) en domain
- [ ] Repository implementation en infrastructure
- [ ] Use cases documentados
- [ ] DTOs con validaciones Pydantic
- [ ] Routes con OpenAPI docs
- [ ] Tests unitarios (use cases)
- [ ] Tests integración (repositories)
- [ ] Tests E2E (routes)
- [ ] Funciones DB integradas (NO duplicar lógica)
- [ ] Vistas DB integradas (queries complejas)
- [ ] Documentación actualizada

---

## 📝 Licencia

Proyecto privado - Todos los derechos reservados

---

## 📞 Contacto

**Proyecto**: CrediNet v2.0  
**Repositorio**: credinet  
**Owner**: JairFC  
**Branch**: feature/frontend-v2-docker-development  

---

**Última actualización**: 2025-10-30  
**Estado**: 🏗️ Reconstrucción desde cero - Base limpia lista
