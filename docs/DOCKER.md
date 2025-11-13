# 🐳 CrediNet V2 - Guía Docker

## 📋 Prerequisitos

- Docker Engine 20.10+
- Docker Compose 2.0+
- 4GB RAM disponible
- Puertos libres: 5173 (frontend), 8000 (backend), 5432 (postgres)

---

## 🚀 Quick Start

### 1. Iniciar todos los servicios

```bash
./scripts/docker/start.sh
```

Esto iniciará:
- ✅ PostgreSQL (base de datos)
- ✅ Backend FastAPI
- ✅ Frontend React + Vite

### 2. Acceder a la aplicación

- **Frontend**: http://localhost:5173 o http://192.168.98.98:5173
- **Backend API**: http://localhost:8000
- **API Docs**: http://localhost:8000/docs
- **Redoc**: http://localhost:8000/redoc

### 3. Credenciales de prueba

- **Usuario**: `admin`
- **Contraseña**: `Sparrow20`

---

## 🛠️ Comandos Útiles

### Ver logs de todos los servicios
```bash
./scripts/docker/logs.sh
```

### Ver logs de un servicio específico
```bash
./scripts/docker/logs.sh backend    # Logs del backend
./scripts/docker/logs.sh frontend   # Logs del frontend
./scripts/docker/logs.sh postgres   # Logs de la base de datos
```

### Reiniciar servicios
```bash
./scripts/docker/restart.sh          # Reinicia todos
./scripts/docker/restart.sh backend  # Solo backend
./scripts/docker/restart.sh frontend # Solo frontend
```

### Detener servicios
```bash
./scripts/docker/stop.sh             # Detiene todo (mantiene datos)
./scripts/docker/stop.sh --volumes   # Detiene y elimina datos
```

### Reconstruir imágenes
```bash
docker compose build                 # Reconstruye todas las imágenes
docker compose build backend         # Solo backend
docker compose build frontend        # Solo frontend
```

### Ver estado de los contenedores
```bash
docker compose ps
```

### Ejecutar comandos dentro de los contenedores
```bash
# Backend (Python/FastAPI)
docker compose exec backend bash
docker compose exec backend python -c "print('Hello')"

# Frontend (Node/Vite)
docker compose exec frontend sh
docker compose exec frontend npm run build

# PostgreSQL
docker compose exec postgres psql -U credinet_user -d credinet_db
```

---

## 📦 Arquitectura Docker

```
credinet-v2/
├── docker-compose.yml          # Orquestación de servicios
├── .env                        # Variables de entorno
├── backend/
│   ├── Dockerfile             # Imagen del backend (Python 3.11)
│   └── requirements.txt       # Dependencias Python
├── frontend-mvp/
│   ├── Dockerfile             # Imagen del frontend (Node 20)
│   ├── package.json           # Dependencias Node
│   └── vite.config.js         # Configuración Vite
└── scripts/docker/
    ├── start.sh               # Iniciar servicios
    ├── stop.sh                # Detener servicios
    ├── logs.sh                # Ver logs
    └── restart.sh             # Reiniciar servicios
```

---

## 🔧 Configuración

### Variables de entorno (.env)

```bash
# PostgreSQL
POSTGRES_USER=credinet_user
POSTGRES_PASSWORD=credinet_pass_change_this_in_production
POSTGRES_DB=credinet_db
POSTGRES_PORT=5432

# Backend
BACKEND_PORT=8000
SECRET_KEY=your_secret_key_min_32_chars_change_this
CORS_ORIGINS=http://localhost:5173,http://192.168.98.98:5173

# Frontend
FRONTEND_PORT=5173
VITE_API_URL=http://localhost:8000
```

### Puertos

| Servicio   | Puerto Host | Puerto Container | Descripción              |
|------------|-------------|------------------|--------------------------|
| Frontend   | 5173        | 5173             | React + Vite dev server  |
| Backend    | 8000        | 8000             | FastAPI application      |
| PostgreSQL | 5432        | 5432             | Database                 |

---

## 🔍 Troubleshooting

### Error: "port is already allocated"

**Causa**: El puerto ya está en uso por otro proceso.

**Solución**:
```bash
# Ver qué proceso usa el puerto
sudo lsof -i :5173   # Frontend
sudo lsof -i :8000   # Backend
sudo lsof -i :5432   # PostgreSQL

# Cambiar el puerto en .env
FRONTEND_PORT=5174
BACKEND_PORT=8001
POSTGRES_PORT=5433
```

### Error: "Cannot connect to database"

**Causa**: PostgreSQL no está listo o las credenciales son incorrectas.

**Solución**:
```bash
# Ver logs de PostgreSQL
./scripts/docker/logs.sh postgres

# Verificar health check
docker compose ps

# Reiniciar PostgreSQL
./scripts/docker/restart.sh postgres
```

### Error: Frontend no carga (blank page)

**Causa**: Vite no puede conectar con el backend o CORS bloqueado.

**Solución**:
```bash
# 1. Verificar CORS en .env
CORS_ORIGINS=http://localhost:5173,http://192.168.98.98:5173

# 2. Reiniciar backend
./scripts/docker/restart.sh backend

# 3. Ver logs del frontend
./scripts/docker/logs.sh frontend
```

### Hot Reload no funciona en Docker

**Causa**: El sistema de archivos del host no notifica cambios al contenedor.

**Solución**: Ya configurado en `vite.config.js`:
```javascript
server: {
  watch: {
    usePolling: true,  // ✅ Ya configurado
  },
}
```

### Error: "node_modules" no encontrado

**Causa**: El volumen de `node_modules` se perdió o no se creó.

**Solución**:
```bash
# Reconstruir imagen del frontend
docker compose build frontend

# Reinstalar dependencias dentro del contenedor
docker compose exec frontend npm install
```

---

## 🏗️ Desarrollo

### Workflow recomendado

1. **Iniciar servicios**:
   ```bash
   ./scripts/docker/start.sh
   ```

2. **Desarrollar**:
   - Edita archivos en `backend/` o `frontend-mvp/`
   - Los cambios se reflejan automáticamente (hot reload)

3. **Ver logs** (en otra terminal):
   ```bash
   ./scripts/docker/logs.sh
   ```

4. **Reiniciar si es necesario**:
   ```bash
   ./scripts/docker/restart.sh backend
   ```

5. **Detener al terminar**:
   ```bash
   ./scripts/docker/stop.sh
   ```

### Agregar dependencias

#### Backend (Python)
```bash
# 1. Agregar a requirements.txt
echo "nuevo-paquete==1.0.0" >> backend/requirements.txt

# 2. Reconstruir imagen
docker compose build backend

# 3. Reiniciar
./scripts/docker/restart.sh backend
```

#### Frontend (Node)
```bash
# 1. Ejecutar npm install dentro del contenedor
docker compose exec frontend npm install nuevo-paquete

# 2. O agregar a package.json y reconstruir
docker compose build frontend
./scripts/docker/restart.sh frontend
```

---

## 🧪 Testing

### Backend Tests
```bash
docker compose exec backend pytest
docker compose exec backend pytest -v --cov=app
```

### Frontend Tests
```bash
docker compose exec frontend npm test
docker compose exec frontend npm run test:coverage
```

---

## 🚀 Producción

Para producción, considera:

1. **Usar imágenes multi-stage** (build + runtime)
2. **No usar volúmenes** de código fuente
3. **Cambiar SECRET_KEY** y contraseñas
4. **Usar docker-compose.prod.yml** separado
5. **Implementar nginx** como reverse proxy
6. **Configurar HTTPS** con Let's Encrypt
7. **Usar orquestadores** (Docker Swarm o Kubernetes)

### Ejemplo producción:
```bash
docker compose -f docker-compose.prod.yml up -d
```

---

## 📊 Volúmenes

Los datos persistentes se almacenan en volúmenes:

| Volumen                    | Contenido                  | Backup Necesario |
|----------------------------|----------------------------|------------------|
| credinet-postgres-data     | Base de datos PostgreSQL   | ✅ Sí            |
| credinet-backend-uploads   | Archivos subidos           | ✅ Sí            |

### Backup de volúmenes
```bash
# Backup PostgreSQL
docker compose exec postgres pg_dump -U credinet_user credinet_db > backup_$(date +%Y%m%d).sql

# Backup uploads
docker run --rm -v credinet-backend-uploads:/data -v $(pwd):/backup alpine tar czf /backup/uploads_backup_$(date +%Y%m%d).tar.gz -C /data .
```

---

## 🔒 Seguridad

### Checklist de seguridad:

- [ ] Cambiar `SECRET_KEY` en `.env`
- [ ] Usar contraseñas fuertes en `POSTGRES_PASSWORD`
- [ ] No exponer puertos innecesarios en producción
- [ ] Actualizar imágenes base regularmente
- [ ] Revisar logs de seguridad
- [ ] Configurar firewall (iptables/ufw)
- [ ] Usar HTTPS en producción
- [ ] Implementar rate limiting
- [ ] Configurar backups automáticos

---

## 📚 Referencias

- [Docker Compose](https://docs.docker.com/compose/)
- [FastAPI Deployment](https://fastapi.tiangolo.com/deployment/)
- [Vite Docker](https://vitejs.dev/guide/backend-integration.html)
- [PostgreSQL Docker](https://hub.docker.com/_/postgres)

---

**Última actualización**: 2025-11-05  
**Versión**: 2.0.0
