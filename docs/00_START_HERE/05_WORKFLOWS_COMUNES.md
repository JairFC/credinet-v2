# 🛠️ WORKFLOWS COMUNES

**Tiempo de lectura:** ~10 minutos  
**Prerequisito:** Haber leído `04_FRONTEND_ESTRUCTURA.md`

---

## 📚 TABLA DE CONTENIDO

1. [Setup Inicial](#setup-inicial)
2. [Desarrollo Backend](#desarrollo-backend)
3. [Desarrollo Frontend](#desarrollo-frontend)
4. [Base de Datos](#base-de-datos)
5. [Testing](#testing)
6. [Git Workflow](#git-workflow)
7. [Troubleshooting](#troubleshooting)

---

## 🚀 SETUP INICIAL

### Primera Vez en el Proyecto

```bash
# 1. Clonar repositorio
git clone https://github.com/JairFC/credinet-v2.git
cd credinet-v2

# 2. Levantar con Docker
docker compose up -d

# 3. Verificar servicios
docker compose ps

# 4. Verificar backend
curl http://localhost:8000/health
# Response: {"status":"healthy","version":"2.0.0"}

# 5. Verificar frontend
curl http://localhost:5173
# Response: HTML

# 6. Probar login
curl -X POST http://localhost:8000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"Sparrow20"}'
```

### Credenciales de Prueba

```
Usuario Admin:
  username: admin
  password: Sparrow20

Base de Datos:
  host: localhost
  port: 5432
  database: credinet_v2
  username: credinet
  password: credinet123
```

---

## 🔧 DESARROLLO BACKEND

### Agregar Nuevo Endpoint

```bash
# Ejemplo: Agregar endpoint para listar asociados

# 1. Crear estructura del módulo (si no existe)
mkdir -p backend/app/modules/associates/{domain,application,infrastructure,presentation}

# 2. Crear entidad (domain/entities/associate.py)
@dataclass
class Associate:
    id: int
    name: str
    email: str
    available_credit: Decimal

# 3. Crear DTO (application/dtos/associate_dto.py)
class AssociateResponseDTO(BaseModel):
    id: int
    name: str
    email: str
    available_credit: float

# 4. Crear repositorio (infrastructure/repositories/associate_repository.py)
class AssociateRepository:
    async def find_all(self) -> List[Associate]:
        # Query a DB
        pass

# 5. Crear caso de uso (application/use_cases/list_associates.py)
class ListAssociatesUseCase:
    async def execute(self) -> List[Associate]:
        return await self.repo.find_all()

# 6. Crear endpoint (presentation/routes.py)
@router.get("/", response_model=List[AssociateResponseDTO])
async def list_associates():
    use_case = ListAssociatesUseCase(associate_repo)
    associates = await use_case.execute()
    return [AssociateResponseDTO.from_entity(a) for a in associates]

# 7. Registrar router en main.py
from app.modules.associates.presentation.routes import router as associates_router
app.include_router(associates_router, prefix="/api/v1/associates", tags=["associates"])
```

### Ejecutar Tests

```bash
# Todos los tests
docker compose exec backend pytest

# Con coverage
docker compose exec backend pytest --cov

# Tests específicos
docker compose exec backend pytest tests/modules/loans/

# Un test específico
docker compose exec backend pytest tests/modules/loans/test_approve_loan.py::test_approve_loan_success

# Ver output completo
docker compose exec backend pytest -v -s
```

### Debugging

```bash
# Ver logs en tiempo real
docker compose logs -f backend

# Ejecutar shell en container
docker compose exec backend bash

# Probar código Python interactivo
docker compose exec backend python
>>> from app.modules.loans.domain.entities.loan import Loan
>>> loan = Loan(id=1, amount=10000)

# Ver variables de entorno
docker compose exec backend env | grep DATABASE
```

---

## 🎨 DESARROLLO FRONTEND

### Agregar Nueva Página

```bash
# Ejemplo: Crear página de reportes

# 1. Crear carpeta y archivos
mkdir -p frontend-mvp/src/pages/ReportsPage
cd frontend-mvp/src/pages/ReportsPage

# 2. Crear componente (ReportsPage.jsx)
export const ReportsPage = () => {
  return (
    <div className="reports-page">
      <h1>Reportes</h1>
      {/* Contenido */}
    </div>
  )
}

# 3. Crear barrel export (index.js)
export { ReportsPage } from './ReportsPage'

# 4. Agregar ruta (app/router.jsx)
import { ReportsPage } from '@/pages/ReportsPage'

<Route path="/reports" element={<ReportsPage />} />

# 5. Ver en navegador
http://localhost:5173/reports
```

### Agregar Nueva Feature

```bash
# Ejemplo: Feature para generar reporte

# 1. Crear estructura
mkdir -p frontend-mvp/src/features/reports/GenerateReportButton

# 2. Crear componente (GenerateReportButton.jsx)
export const GenerateReportButton = ({ reportType }) => {
  const handleGenerate = async () => {
    const report = await api.reports.generate(reportType)
    // Descargar o mostrar
  }
  
  return <Button onClick={handleGenerate}>Generar Reporte</Button>
}

# 3. Usar en página
import { GenerateReportButton } from '@/features/reports/GenerateReportButton'

<GenerateReportButton reportType="loans" />
```

### Hot Reload

```bash
# El frontend tiene hot reload automático
# Solo guarda el archivo y verás los cambios

# Si no funciona, reinicia el servicio
docker compose restart frontend

# Ver logs del frontend
docker compose logs -f frontend
```

---

## 🗄️ BASE DE DATOS

### Conectarse a PostgreSQL

```bash
# Desde terminal
docker compose exec postgres psql -U credinet -d credinet_v2

# Listar tablas
\dt

# Describir tabla
\d loans

# Ver datos
SELECT * FROM loans LIMIT 5;

# Salir
\q
```

### Ejecutar Scripts SQL

```bash
# Ejecutar archivo SQL
docker compose exec -T postgres psql -U credinet -d credinet_v2 < script.sql

# Ejecutar comando directo
docker compose exec postgres psql -U credinet -d credinet_v2 -c "SELECT COUNT(*) FROM loans;"

# Ver funciones
docker compose exec postgres psql -U credinet -d credinet_v2 -c "\df"
```

### Hacer Backup

```bash
# Backup automático (ya configurado)
# Se guarda en: /db/backups/backup_YYYY-MM-DD_HH-MM-SS/

# Backup manual
docker compose exec postgres pg_dump -U credinet credinet_v2 > backup.sql

# Restaurar backup
docker compose exec -T postgres psql -U credinet -d credinet_v2 < backup.sql
```

### Resetear Base de Datos

```bash
# ⚠️ CUIDADO: Esto borra todos los datos

# 1. Detener servicios
docker compose down

# 2. Eliminar volumen
docker volume rm credinet-v2_credinet-postgres-data

# 3. Iniciar de nuevo (ejecutará init.sql)
docker compose up -d

# 4. Verificar
docker compose exec postgres psql -U credinet -d credinet_v2 -c "SELECT COUNT(*) FROM users;"
```

### Agregar Nueva Migración

```bash
# 1. Crear archivo en db/v2.0/modules/
# Ejemplo: 11_add_reports_table.sql

CREATE TABLE reports (
    id SERIAL PRIMARY KEY,
    report_type VARCHAR(50) NOT NULL,
    generated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

# 2. Agregar al script monolítico
cd db/v2.0
./generate_monolithic.sh

# 3. Aplicar migración (si DB ya existe)
docker compose exec -T postgres psql -U credinet -d credinet_v2 < modules/11_add_reports_table.sql
```

---

## 🧪 TESTING

### Tests Backend

```bash
# Setup de test (si no está)
cd backend
python -m pytest --version

# Correr todos los tests
docker compose exec backend pytest

# Tests con coverage HTML
docker compose exec backend pytest --cov --cov-report=html
# Ver: backend/htmlcov/index.html

# Tests de un módulo
docker compose exec backend pytest tests/modules/loans/

# Tests con marker específico
docker compose exec backend pytest -m "slow"

# Ver tests disponibles sin ejecutar
docker compose exec backend pytest --collect-only
```

### Crear Nuevo Test

```python
# tests/modules/associates/test_list_associates.py
import pytest
from httpx import AsyncClient

@pytest.mark.asyncio
async def test_list_associates_success(client: AsyncClient, admin_token):
    """Test listar asociados con autenticación"""
    headers = {"Authorization": f"Bearer {admin_token}"}
    response = await client.get("/api/v1/associates", headers=headers)
    
    assert response.status_code == 200
    data = response.json()
    assert isinstance(data, list)
    assert len(data) > 0
    assert "name" in data[0]

@pytest.mark.asyncio
async def test_list_associates_unauthorized(client: AsyncClient):
    """Test sin autenticación debe fallar"""
    response = await client.get("/api/v1/associates")
    assert response.status_code == 401
```

---

## 🌿 GIT WORKFLOW

### Trabajo Diario

```bash
# 1. Actualizar main
git checkout main
git pull origin main

# 2. Crear feature branch
git checkout -b feature/add-reports-module

# 3. Hacer cambios y commits
git add .
git commit -m "feat: Add reports module with PDF generation"

# 4. Push a remote
git push origin feature/add-reports-module

# 5. Crear Pull Request en GitHub
# (Usar interfaz web)

# 6. Después de merge, actualizar local
git checkout main
git pull origin main
git branch -d feature/add-reports-module
```

### Convenciones de Commits

```bash
# Formato: <tipo>: <descripción>

# Tipos:
feat:     Nueva funcionalidad
fix:      Corrección de bug
docs:     Cambios en documentación
style:    Formato, espacios (no afecta código)
refactor: Refactorización (no cambia funcionalidad)
test:     Agregar o modificar tests
chore:    Tareas de mantenimiento

# Ejemplos:
git commit -m "feat: Add associate credit limit validation"
git commit -m "fix: Correct payment schedule calculation for 12 periods"
git commit -m "docs: Update API documentation with new endpoints"
git commit -m "test: Add integration tests for loan approval"
```

### Ver Cambios

```bash
# Ver archivos modificados
git status

# Ver diferencias
git diff

# Ver diferencias de archivo específico
git diff backend/app/main.py

# Ver commits recientes
git log --oneline -10

# Ver cambios de un commit
git show abc123
```

---

## 🔧 TROUBLESHOOTING

### Backend no responde

```bash
# 1. Ver logs
docker compose logs backend

# 2. Verificar que esté corriendo
docker compose ps

# 3. Reiniciar servicio
docker compose restart backend

# 4. Verificar variables de entorno
docker compose exec backend env | grep DATABASE

# 5. Probar conexión a DB desde backend
docker compose exec backend python -c "
from app.core.database import engine
from sqlalchemy import text
with engine.connect() as conn:
    result = conn.execute(text('SELECT 1'))
    print('DB OK')
"
```

### Frontend no carga

```bash
# 1. Ver logs
docker compose logs frontend

# 2. Verificar puerto
curl http://localhost:5173

# 3. Reinstalar dependencias
docker compose exec frontend npm install

# 4. Limpiar cache
docker compose exec frontend npm cache clean --force

# 5. Reconstruir imagen
docker compose up -d --build frontend
```

### Base de datos no inicia

```bash
# 1. Ver logs
docker compose logs postgres

# 2. Verificar volumen
docker volume ls | grep credinet

# 3. Verificar permisos
ls -la db/v2.0/

# 4. Recrear contenedor
docker compose down
docker compose up -d postgres

# 5. Verificar conexión
docker compose exec postgres pg_isready -U credinet
```

### Puerto ya en uso

```bash
# Ver qué está usando el puerto
lsof -i :8000

# Matar proceso
kill -9 <PID>

# O cambiar puerto en docker-compose.yml
ports:
  - "8001:8000"  # Host:Container
```

### Tests fallan

```bash
# 1. Ver error completo
docker compose exec backend pytest -v -s

# 2. Correr solo ese test
docker compose exec backend pytest tests/path/to/test.py::test_name -v -s

# 3. Ver fixtures disponibles
docker compose exec backend pytest --fixtures

# 4. Limpiar cache de pytest
docker compose exec backend pytest --cache-clear

# 5. Verificar que DB de test esté limpia
docker compose exec backend pytest --create-db
```

---

## 💡 COMANDOS ÚTILES

### Docker

```bash
# Ver todos los contenedores
docker ps -a

# Ver uso de recursos
docker stats

# Limpiar todo (⚠️ cuidado)
docker system prune -a --volumes

# Ver logs de todos los servicios
docker compose logs -f

# Ejecutar comando en contenedor
docker compose exec backend <comando>

# Reconstruir imágenes
docker compose build --no-cache
```

### Python

```bash
# Instalar nueva dependencia
docker compose exec backend pip install <package>

# Actualizar requirements.txt
docker compose exec backend pip freeze > requirements.txt

# Verificar imports
docker compose exec backend python -c "import sqlalchemy; print(sqlalchemy.__version__)"
```

### Node

```bash
# Instalar nueva dependencia
docker compose exec frontend npm install <package>

# Ver paquetes instalados
docker compose exec frontend npm list --depth=0

# Verificar versión
docker compose exec frontend node --version
docker compose exec frontend npm --version
```

---

## 📋 CHECKLIST DE DESARROLLO

### Antes de Empezar Tarea
- [ ] Git: Branch actualizado con `main`
- [ ] Docker: Servicios corriendo
- [ ] Tests: Todos pasan
- [ ] DB: Datos de prueba cargados

### Antes de Commit
- [ ] Tests: Nuevos tests agregados
- [ ] Tests: Todos pasan (incluidos nuevos)
- [ ] Linting: Código formateado
- [ ] Docs: Documentación actualizada si es necesario

### Antes de Pull Request
- [ ] Branch: Actualizado con `main`
- [ ] Conflicts: Resueltos
- [ ] Tests: Todos pasan
- [ ] Commit message: Sigue convención

---

## 🔗 REFERENCIAS

### Documentos Relacionados
- [`DEVELOPMENT.md`](../DEVELOPMENT.md) - Guía de desarrollo completa
- [`DOCKER.md`](../DOCKER.md) - Guía Docker detallada
- [`GUIA_BACKEND_V2.0.md`](../GUIA_BACKEND_V2.0.md) - Guía backend

### Comandos Frecuentes
```bash
# Iniciar proyecto
docker compose up -d

# Ver logs
docker compose logs -f backend

# Tests
docker compose exec backend pytest

# Base de datos
docker compose exec postgres psql -U credinet -d credinet_v2

# Git
git status
git add .
git commit -m "feat: descripción"
git push
```

---

## ✅ VERIFICACIÓN DE COMPRENSIÓN

Antes de empezar a desarrollar, asegúrate de poder:

1. Levantar el proyecto con Docker
2. Hacer login y obtener un token
3. Ejecutar tests del backend
4. Conectarte a la base de datos
5. Crear un feature branch
6. Hacer commit siguiendo convenciones

---

## 🎉 ¡ONBOARDING COMPLETO!

Has completado el onboarding de Credinet v2.0.

### Lo que aprendiste:
1. ✅ Overview del proyecto (actores, conceptos, stack)
2. ✅ Arquitectura backend y frontend
3. ✅ APIs principales y cómo usarlas
4. ✅ Estructura del frontend (FSD)
5. ✅ Workflows comunes para desarrollo

### Tiempo total: ~55 minutos

### Próximos pasos:
1. Explorar el código en `/backend/app/` y `/frontend-mvp/src/`
2. Leer documentación detallada según necesites
3. Empezar tu primera tarea

### ¿Preguntas?
- Revisa: [`business_logic/INDICE_MAESTRO.md`](../business_logic/INDICE_MAESTRO.md)
- Consulta: [`README.md`](../README.md)
- Busca: [`INDICE_DOCUMENTACION.md`](../INDICE_DOCUMENTACION.md)

---

**¡Bienvenido al equipo! 🚀**
