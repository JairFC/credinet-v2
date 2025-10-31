# Credinet - Sistema de Gestión de Préstamos

## 🔐 **CREDENCIALES DE DESARROLLO**
- **Usuario:** admin (para todos los usuarios)
- **Contraseña:** Sparrow20 (para todos los usuarios)
- **Servidor Remoto:** 192.168.98.98 (acceso vía SSH)

## 🌐 **URLS DE ACCESO REMOTO**
- **Frontend:** http://192.168.98.98:5174
- **Backend API:** http://192.168.98.98:8001
- **API Documentación:** http://192.168.98.98:8001/docs
- **Database:** localhost:5432 (solo desde SSH)

## 🚨 **REGLAS FUNDAMENTALES DE DESARROLLO**

### ⚠️ **ENTORNO DOCKER ONLY**
Este proyecto funciona **EXCLUSIVAMENTE en Docker**. NO uses `.venv` ni Python local.

```bash
# ✅ CORRECTO - Siempre usar Docker
docker compose down -v && docker compose up --build

# ❌ INCORRECTO - Nunca usar Python local
python main.py  # NO HACER ESTO
pip install -r requirements.txt  # NO HACER ESTO
```

### 🔄 **RECONSTRUCCIÓN OBLIGATORIA**
SIEMPRE que hagas cambios ejecuta la secuencia completa:
```bash
docker compose down -v    # Elimina volúmenes y limpia caché
docker compose up --build # Reconstruye y levanta todo
```

### 🐘 **COMANDOS SQL EN DOCKER**
Para consultas a la base de datos, usa este formato exacto:
```bash
# ✅ CORRECTO (sin flag -t)
docker exec credinet_db psql -U credinet_user -d credinet_db -c "SELECT * FROM loans;"

# ❌ INCORRECTO (con -t se cuelga la terminal)
docker exec -t credinet_db psql...
```

### 🏗️ **ARQUITECTURA CLEAN**
El proyecto migró a Clean Architecture. Los endpoints principales están en:
- `/backend/app/loans/presentation/clean_routes.py` (nuevos)
- Lógica de negocio: `/backend/app/loans/domain/`
- Casos de uso: `/backend/app/loans/application/`

## 📋 **GUÍA DE INICIO RÁPIDO**

### 1. Conexión SSH
```bash
ssh usuario@192.168.98.98
cd /home/credicuenta/proyectos/credinet
```

### 2. Levantar Sistema
```bash
docker compose down -v && docker compose up --build
```

### 3. Verificar Estado
```bash
docker compose ps                              # Ver contenedores
curl http://192.168.98.98:8001/api/ping       # Probar backend
curl http://192.168.98.98:8001/api/loans/health # Clean Architecture
```

### 4. Acceso Frontend
Navega a: http://192.168.98.98:5174
- Usuario: admin
- Contraseña: Sparrow20

## 🎯 **CARACTERÍSTICAS IMPLEMENTADAS**

### Sistema de Cortes Exactos (Clean Architecture)
- ✅ Cortes exactos a las 00:00:00 días 8 y 23
- ✅ Fechas perfectas (solo día 15 y último día del mes)
- ✅ Secuencia alternante consistente
- ✅ Detección automática de fines de semana
- ✅ Sistema de versioning de cortes (preliminar → ajustada → final)

### Endpoints Disponibles
- `POST /api/loans/calculate-payment-schedule` - Cronograma con lógica de cortes
- `GET /api/loans/health` - Estado del sistema Clean Architecture  
- `GET /api/loans/summary` - Resumen global de préstamos
- `GET /api/loans/` - Listado paginado de préstamos
- `POST /api/loans/` - Creación de préstamos

## 🐳 **COMANDOS DOCKER ÚTILES**

```bash
# Ver logs en tiempo real
docker compose logs -f backend
docker compose logs -f frontend  
docker compose logs -f db

# Ejecutar comandos en contenedores
docker compose exec backend bash
docker compose exec db psql -U credinet_user -d credinet_db

# Reinicio completo del sistema
docker compose down -v && docker compose up --build

# Solo reconstruir un servicio
docker compose up --build backend
```

## 📁 **ESTRUCTURA DEL PROYECTO**

```
credinet/
├── backend/                    # API FastAPI
│   ├── app/
│   │   ├── loans/             # Módulo de préstamos (Clean Architecture)
│   │   │   ├── domain/        # Lógica de negocio
│   │   │   ├── application/   # Casos de uso
│   │   │   └── presentation/  # Rutas y controladores
│   │   ├── auth/              # Autenticación
│   │   ├── common/            # Utilidades compartidas
│   │   └── main.py            # Punto de entrada
│   ├── requirements.txt       # Dependencias Python
│   └── Dockerfile            # Imagen del backend
├── frontend/                  # App React
│   ├── src/
│   │   ├── components/        # Componentes reutilizables
│   │   ├── pages/             # Páginas principales
│   │   ├── services/          # API client
│   │   └── config/            # Configuración
│   ├── package.json           # Dependencias Node.js
│   └── Dockerfile            # Imagen del frontend
├── db/                       # Scripts de base de datos
│   ├── init.sql              # Esquema inicial
│   └── migrations/           # Migraciones
├── docker-compose.yml        # Orquestación de servicios
└── README.md                 # Esta documentación
```

## 🔍 **SOLUCIÓN DE PROBLEMAS COMUNES**

### Error: "Préstamos no cargan"
```bash
# 1. Verificar que todos los contenedores estén up
docker compose ps

# 2. Revisar logs del backend
docker compose logs backend --tail=50

# 3. Probar endpoint directamente
curl http://192.168.98.98:8001/api/loans/summary

# 4. Reiniciar sistema completo
docker compose down -v && docker compose up --build
```

### Error: "Terminal con (.venv)"
```bash
# Verificar configuración VS Code
cat .vscode/settings.json

# La configuración correcta debe incluir:
# "python.terminal.activateEnvironment": false
```

### Error: "No se puede conectar a la DB"
```bash
# Verificar conexión a PostgreSQL
docker exec credinet_db psql -U credinet_user -d credinet_db -c "\dt;"

# Si falla, limpiar volúmenes y reconstruir
docker compose down -v
docker volume prune -f
docker compose up --build
```

## 🔗 **ENLACES ÚTILES**

- [Documentación de la API](http://192.168.98.98:8001/docs)
- [Lógica de Negocio Final](./docs/LOGICA_NEGOCIO_FINAL.md)
- [Arquitectura Clean](./docs/system_architecture/)
- [Guías de Desarrollo](./docs/guides/)

## 🔐 **PRUEBAS DE AUTENTICACIÓN**

### Login y Tokens de Acceso
```bash
# Login con credenciales universales (IMPORTANTE: usar form-data, no JSON)
curl -X POST "http://192.168.98.98:8001/api/auth/login" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=admin&password=Sparrow20"

# Respuesta esperada:
# {"access_token": "eyJ...", "token_type": "bearer"}
```

### Endpoints Protegidos
```bash
# Resumen de préstamos (reemplazar TOKEN_AQUI con el token obtenido)
curl -X GET "http://192.168.98.98:8001/api/loans/summary" \
  -H "Authorization: Bearer TOKEN_AQUI"

# Listado de préstamos
curl -X GET "http://192.168.98.98:8001/api/loans/list" \
  -H "Authorization: Bearer TOKEN_AQUI"

# Estado del sistema
curl -X GET "http://192.168.98.98:8001/api/loans/health" \
  -H "Authorization: Bearer TOKEN_AQUI"
```

### Credenciales del Sistema
- **Usuario:** admin
- **Contraseña:** Sparrow20
- **Roles:** administrador
- **Alcance:** Todos los usuarios del sistema usan estas credenciales universales

---

> **⚠️ RECORDATORIO:** Este proyecto se desarrolla en un entorno remoto SSH (192.168.98.98) y funciona exclusivamente con Docker. Nunca uses Python/pip local.