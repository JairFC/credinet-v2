# 🏦 CrediNet v2.0 - Sistema de Gestión de Préstamos

[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-15-blue)](https://www.postgresql.org/)
[![Python](https://img.shields.io/badge/Python-3.11-blue)](https://www.python.org/)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.104-green)](https://fastapi.tiangolo.com/)
[![React](https://img.shields.io/badge/React-18-blue)](https://reactjs.org/)
[![Docker](https://img.shields.io/badge/Docker-ready-blue)](https://www.docker.com/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

**CrediNet v2.0** es un sistema integral de gestión de préstamos quincenal con arquitectura limpia (Clean Architecture), construido desde cero para CrediCuenta.

> **⚠️ NOTA:** Este es un proyecto completamente nuevo (v2.0), **NO** una actualización. Todo el código legacy fue descartado en favor de una arquitectura moderna y escalable.

---

## ✨ Características Principales

- 🏗️ **Clean Architecture**: Separación perfecta de capas (Domain, Application, Infrastructure, Presentation)
- 🔐 **JWT Authentication**: Sistema completo de autenticación con access y refresh tokens
- 💰 **Gestión de Préstamos**: Doble calendario (quincenal/mensual), amortización francesa
- 📊 **Base de Datos Robusta**: 45 tablas, 16 funciones, 28+ triggers, 9 vistas
- 🧪 **Testing Exhaustivo**: 124+ tests automatizados (unit + integration + E2E)
- 🐳 **Dockerizado**: Desarrollo y producción con Docker Compose
- 🛡️ **Protección de Datos**: Sistema automático de backups
- 📚 **Documentación Completa**: Guías, diagramas, ADRs

---

## 🎯 Estado del Proyecto

| Componente | Estado | Tests | Documentación |
|------------|--------|-------|---------------|
| 💾 Base de Datos v2.0 | ✅ 100% | N/A | ✅ Completa |
| 🔐 Módulo Auth | ✅ 100% | 28/28 | ✅ Completa |
| 💰 Módulo Loans | ✅ 100% | 96/96 | ✅ Completa |
| 🎨 Frontend (Auth + Dashboard) | ✅ 100% | 0/0 | ✅ Completa |
| 🐳 Dockerización | ✅ 100% | N/A | ✅ Completa |
| 🤝 Módulo Associates | ⏳ 0% | 0/25 | ⏳ Pendiente |
| 📅 Módulo Periods | ⏳ 0% | 0/30 | ⏳ Pendiente |
| 💳 Módulo Payments | ⏳ 0% | 0/20 | ⏳ Pendiente |

**Progreso general:** Sprint 7/12 completado (58%)

---

## 🚀 Inicio Rápido

### Prerrequisitos

- Docker 20.10+
- Docker Compose 2.0+
- 4GB RAM disponible
- Puertos libres: 5173, 8000, 5432

### Instalación con Docker (Recomendado)

```bash
# 1. Clonar el repositorio
git clone <repo-url>
cd credinet-v2

# 2. Copiar variables de entorno
cp .env.example .env

# 3. Iniciar todos los servicios (PostgreSQL + Backend + Frontend)
./scripts/docker/start.sh

# 4. Acceder a la aplicación
# Frontend: http://localhost:5173
# Backend API: http://localhost:8000/docs
```

**Credenciales de prueba:**
- Usuario: `admin`
- Contraseña: `Sparrow20`

### Ver logs y gestión

```bash
./scripts/docker/logs.sh          # Ver logs de todos los servicios
./scripts/docker/logs.sh backend  # Solo backend
./scripts/docker/restart.sh       # Reiniciar servicios
./scripts/docker/stop.sh          # Detener servicios
```
- Git

### Instalación

```bash
# 1. Clonar repositorio
git clone https://github.com/JairFC/credinet-v2.git
cd credinet-v2

# 2. Configurar variables de entorno
cp .env.example .env
# Editar .env con tus configuraciones

# 3. Levantar el sistema
docker-compose up -d

# 4. Verificar que todo está corriendo
docker-compose ps

# 5. Ver logs
docker-compose logs -f
```

### Acceso al Sistema

- **Backend API**: http://localhost:8000
- **API Docs**: http://localhost:8000/docs
- **Frontend**: http://localhost:5173
- **PostgreSQL**: localhost:5432

### Credenciales por Defecto

```
Usuario: admin
Password: admin123
```

> ⚠️ **IMPORTANTE:** Cambia las credenciales en producción.

---

## 📚 Documentación

### Guías Principales

- 📘 [Arquitectura del Sistema](docs/ARQUITECTURA_BACKEND_V2_DEFINITIVA.md)
- 📗 [Lógica de Negocio](docs/LOGICA_DE_NEGOCIO_DEFINITIVA.md)
- 📙 [Plan Maestro v2.0](docs/PLAN_MAESTRO_V2.0.md)
- 📕 [Guía de Desarrollo](docs/DEVELOPMENT.md)

### Módulos Completados

- [Módulo Auth/Users](backend/app/modules/auth/README.md) - Autenticación JWT
- [Módulo Loans](backend/app/modules/loans/README.md) - Gestión de préstamos

### Infraestructura

- [Base de Datos v2.0](db/v2.0/README.md) - Esquema completo
- [Protección de Datos](docs/guides/DATA_PROTECTION.md) - Backups y restauración
- [Docker Guide](docs/DEPLOYMENT.md) - Despliegue y configuración

---

## 🏗️ Arquitectura

### Backend (FastAPI + Clean Architecture)

```
backend/
├── app/
│   ├── core/              # Infraestructura compartida
│   │   ├── config.py      # Configuración
│   │   ├── database.py    # Conexión DB
│   │   ├── security.py    # JWT, hashing
│   │   └── exceptions.py  # Excepciones custom
│   │
│   ├── modules/           # Módulos de negocio
│   │   ├── auth/         # ✅ Autenticación (100%)
│   │   ├── loans/        # ✅ Préstamos (100%)
│   │   ├── associates/   # ⏳ Asociados (0%)
│   │   ├── periods/      # ⏳ Quincenas (0%)
│   │   └── payments/     # ⏳ Pagos (0%)
│   │
│   └── shared/           # Utilidades compartidas
│       └── utils/        # Helpers, logger, validators
│
└── tests/                # Tests automatizados
    ├── unit/            # Tests unitarios
    ├── integration/     # Tests de integración
    └── e2e/            # Tests end-to-end
```

**Cada módulo sigue Clean Architecture:**

```
module/
├── domain/              # Entidades y lógica de negocio
│   ├── entities/       # Objetos de dominio (dataclasses)
│   └── repositories/   # Interfaces (ABCs)
│
├── application/        # Casos de uso
│   ├── dtos/          # Data Transfer Objects
│   └── services/      # Lógica de aplicación
│
├── infrastructure/     # Implementación técnica
│   ├── models/        # SQLAlchemy models
│   └── repositories/  # Implementación de repos
│
└── routes.py          # Endpoints REST
```

### Frontend (React 18 + Vite 5)

```
frontend/
├── src/
│   ├── components/    # Componentes reutilizables
│   ├── pages/        # Páginas/vistas
│   ├── services/     # API client
│   └── utils/        # Helpers
└── public/           # Assets estáticos
```

### Base de Datos (PostgreSQL 15)

- **45 tablas**: Catálogos, core, business, audit
- **16 funciones**: Cálculos automáticos
- **28+ triggers**: Auditoría y validaciones
- **9 vistas**: Resúmenes y reportes

---

## 🧪 Testing

### Ejecutar Tests

```bash
# Todos los tests
docker-compose exec backend pytest

# Tests de un módulo específico
docker-compose exec backend pytest tests/modules/auth/

# Con coverage
docker-compose exec backend pytest --cov=app --cov-report=html

# Ver reporte
open backend/htmlcov/index.html
```

### Cobertura Actual

| Módulo | Tests | Coverage |
|--------|-------|----------|
| Auth | 28 | ~95% |
| Loans | 96 | ~92% |
| **Total** | **124** | **~93%** |

---

## 🛡️ Protección de Datos

### Backups Automáticos

```bash
# Crear backup manual
./scripts/database/backup_db.sh

# Down seguro (con backup automático)
./scripts/docker/safe_down.sh

# Restaurar backup
./scripts/database/restore_db.sh <nombre_backup>
```

> ⚠️ **NUNCA** ejecutes `docker-compose down -v` directamente. Usa `./scripts/docker/safe_down.sh` para evitar pérdida de datos.

📚 [Guía completa de protección de datos](docs/guides/DATA_PROTECTION.md)

---

## 🔧 Desarrollo

### Setup Local

```bash
# 1. Instalar dependencias Python (opcional, para IDE)
cd backend
pip install -r requirements.txt

# 2. Instalar dependencias Node (opcional, para IDE)
cd frontend
npm install

# 3. Configurar IDE
# - Python: Seleccionar intérprete de Docker
# - ESLint: Configurar para React
# - Prettier: Formatear al guardar
```

### Workflow Git

```bash
# 1. Crear rama feature
git checkout -b feature/nombre-feature

# 2. Desarrollar y commitear
git add .
git commit -m "feat(module): descripción"

# 3. Push y crear PR
git push origin feature/nombre-feature

# 4. Merge a main después de review
```

### Convención de Commits

Usamos [Conventional Commits](https://www.conventionalcommits.org/):

- `feat(module):` - Nueva funcionalidad
- `fix(module):` - Corrección de bug
- `docs:` - Cambios en documentación
- `test(module):` - Agregar/modificar tests
- `refactor(module):` - Refactorización de código
- `style:` - Cambios de formato (no afectan lógica)
- `chore:` - Cambios en build, configs, etc.

---

## 📈 Roadmap

### Fase 1: Backend MVP (Actual) ⏳ 25%

- [x] Sprint 1-3: Base de datos v2.0
- [x] Sprint 4: Módulo Loans
- [x] Sprint 5: Módulo Auth
- [ ] Sprint 6: Módulo Associates (En progreso)
- [ ] Sprint 7: Módulo Periods
- [ ] Sprint 8: Módulo Payments

**ETA:** 4 semanas

### Fase 2: Frontend MVP ⏳ 0%

- [ ] Sprint 9: Limpieza y setup TypeScript
- [ ] Sprint 10: Vistas principales (Dashboard, Loans, Payments)

**ETA:** 2 semanas

### Fase 3: Módulos Opcionales 📋

- [ ] Agreements (Convenios)
- [ ] Reports (Reportes avanzados)
- [ ] Documents (Gestión documental)
- [ ] Notifications (Sistema de notificaciones)

**ETA:** 4 semanas

---

## 🤝 Contribuir

### Reportar Bugs

Abre un issue con:
1. Descripción clara del problema
2. Pasos para reproducir
3. Comportamiento esperado vs actual
4. Logs relevantes
5. Entorno (OS, Docker version, etc.)

### Proponer Features

Abre un issue con:
1. Descripción de la funcionalidad
2. Justificación (por qué es necesaria)
3. Propuesta de implementación
4. Mockups/diagramas (si aplica)

### Pull Requests

1. Fork el repositorio
2. Crea rama feature (`git checkout -b feature/AmazingFeature`)
3. Escribe tests para tu código
4. Asegúrate que todos los tests pasen
5. Commit con convención (`git commit -m 'feat: Add AmazingFeature'`)
6. Push a tu fork (`git push origin feature/AmazingFeature`)
7. Abre un Pull Request

---

## 📄 Licencia

Este proyecto está bajo la Licencia MIT - ver el archivo [LICENSE](LICENSE) para detalles.

---

## 👥 Equipo

- **Desarrollo**: [JairFC](https://github.com/JairFC)
- **Arquitectura**: Clean Architecture + Domain-Driven Design
- **Stack**: FastAPI + React + PostgreSQL + Docker

---

## 📞 Soporte

- 📧 Email: [tu-email@example.com]
- 🐛 Issues: [GitHub Issues](https://github.com/JairFC/credinet-v2/issues)
- 📚 Docs: [Documentación completa](docs/)

---

## 🎓 Reconocimientos

- Clean Architecture por Robert C. Martin
- FastAPI por Sebastián Ramírez
- React por Meta/Facebook
- PostgreSQL Community

---

**Hecho con ❤️ para CrediCuenta**

**Versión:** 2.0.0  
**Última actualización:** 31 Octubre 2025
