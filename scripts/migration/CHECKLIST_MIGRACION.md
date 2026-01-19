# ✅ CHECKLIST DE MIGRACIÓN - CrediNet v2.0

## Información del Proyecto
- **Origen**: 192.168.98.98 (Desarrollo)
- **Destino**: 10.5.26.141 (Producción via VPN)
- **Fecha**: 2026-01-14

---

## 📋 PRE-REQUISITOS EN SERVIDOR DESTINO

### 1. Verificar Conectividad
```bash
# Desde tu máquina local
ping 10.5.26.141
ssh usuario@10.5.26.141  # Verificar acceso SSH
```

### 2. Instalar Docker y Docker Compose
```bash
# En el servidor 10.5.26.141
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Instalar Docker Compose v2
sudo apt-get update
sudo apt-get install docker-compose-plugin

# Verificar instalación
docker --version
docker compose version
```

### 3. Crear Directorio de Trabajo
```bash
sudo mkdir -p /opt/credinet-v2
sudo chown $USER:$USER /opt/credinet-v2
cd /opt/credinet-v2
```

---

## 📦 PASO 1: TRANSFERIR CÓDIGO

### Opción A: Git Clone (Recomendado si hay repo)
```bash
cd /opt/credinet-v2
git clone <url-repositorio> .
```

### Opción B: SCP desde desarrollo
```bash
# Desde 192.168.98.98
cd /home/credicuenta/proyectos
tar -czvf credinet-v2.tar.gz credinet-v2/ \
    --exclude='credinet-v2/node_modules' \
    --exclude='credinet-v2/frontend/node_modules' \
    --exclude='credinet-v2/frontend-mvp/node_modules' \
    --exclude='credinet-v2/__pycache__' \
    --exclude='credinet-v2/.git' \
    --exclude='credinet-v2/uploads/*' \
    --exclude='credinet-v2/*.log'

scp credinet-v2.tar.gz usuario@10.5.26.141:/opt/credinet-v2/

# En servidor destino
cd /opt/credinet-v2
tar -xzvf credinet-v2.tar.gz --strip-components=1
rm credinet-v2.tar.gz
```

---

## 🔒 PASO 2: CONFIGURAR CREDENCIALES PRODUCCIÓN

### 2.1 Generar Credenciales Seguras
```bash
# Generar SECRET_KEY (64 chars hex)
openssl rand -hex 32

# Generar POSTGRES_PASSWORD (32 chars base64)
openssl rand -base64 24
```

### 2.2 Crear .env de Producción
```bash
cd /opt/credinet-v2
cp scripts/migration/03_env_production.template .env

# Editar con los valores generados
nano .env
```

### 2.3 Variables a CAMBIAR OBLIGATORIAMENTE:
| Variable | Acción |
|----------|--------|
| `POSTGRES_PASSWORD` | Reemplazar con valor de `openssl rand -base64 24` |
| `SECRET_KEY` | Reemplazar con valor de `openssl rand -hex 32` |
| `VITE_API_URL` | Verificar IP: `http://10.5.26.141:8000` |
| `CORS_ORIGINS` | Verificar IP: incluye `10.5.26.141` |
| `ADMIN_PASS` | Cambiar contraseña del admin |

---

## 🐳 PASO 3: LEVANTAR CONTENEDORES

### 3.1 Construir imágenes (primera vez)
```bash
cd /opt/credinet-v2
docker compose build --no-cache
```

### 3.2 Iniciar servicios
```bash
docker compose up -d
```

### 3.3 Verificar que todo esté corriendo
```bash
docker compose ps
docker compose logs -f  # Ver logs en tiempo real (Ctrl+C para salir)
```

---

## 🧹 PASO 4: LIMPIAR DATOS DE PRUEBA

### 4.1 Verificar estado actual de BD
```bash
docker compose exec postgres psql -U credinet_user -d credinet_db -c "
SELECT 
    (SELECT COUNT(*) FROM users) as usuarios,
    (SELECT COUNT(*) FROM loans) as prestamos,
    (SELECT COUNT(*) FROM payments) as pagos;
"
```

### 4.2 Ejecutar script de limpieza
```bash
# IMPORTANTE: Solo si la BD tiene datos de prueba
docker compose exec postgres psql -U credinet_user -d credinet_db \
    -f /docker-entrypoint-initdb.d/02_cleanup_data.sql
```

### 4.3 Verificar limpieza
```bash
docker compose exec postgres psql -U credinet_user -d credinet_db -c "
SELECT 
    (SELECT COUNT(*) FROM users) as usuarios_restantes,
    (SELECT COUNT(*) FROM loans) as prestamos_restantes,
    (SELECT COUNT(*) FROM roles) as roles_catalogo,
    (SELECT COUNT(*) FROM cut_periods) as periodos_corte;
"
# Esperado: usuarios=2, prestamos=0, roles=5, periodos=288
```

---

## ✅ PASO 5: VALIDACIÓN POST-MIGRACIÓN

### 5.1 Ejecutar Tests Automáticos
```bash
cd /opt/credinet-v2/scripts/migration
chmod +x 04_post_migration_test.sh
./04_post_migration_test.sh
```

### 5.2 Verificaciones Manuales
| Test | URL | Esperado |
|------|-----|----------|
| Frontend carga | http://10.5.26.141:5173 | Página de login |
| API responde | http://10.5.26.141:8000/docs | Swagger UI |
| Login admin | Probar login con `jair` | Acceso exitoso |

### 5.3 Cambiar Contraseñas de Admin
```bash
# Conectar a BD
docker compose exec postgres psql -U credinet_user -d credinet_db

# Cambiar password (desde la aplicación es mejor)
# O generar hash bcrypt y actualizar directamente
```

---

## 🔥 PASO 6: CONFIGURACIÓN DE FIREWALL (Opcional)

```bash
# Si hay firewall, abrir puertos necesarios
sudo ufw allow 5173/tcp  # Frontend
sudo ufw allow 8000/tcp  # API
sudo ufw reload
```

---

## 📝 COMANDOS ÚTILES POST-INSTALACIÓN

### Ver logs
```bash
docker compose logs -f backend    # Solo backend
docker compose logs -f frontend   # Solo frontend
docker compose logs -f postgres   # Solo BD
```

### Reiniciar servicios
```bash
docker compose restart
```

### Parar todo
```bash
docker compose down
```

### Backup de BD
```bash
docker compose exec postgres pg_dump -U credinet_user credinet_db > backup_$(date +%Y%m%d).sql
```

---

## ⚠️ ROLLBACK (Si algo falla)

### Volver a desarrollo
El sistema en 192.168.98.98 sigue intacto. Simplemente:
```bash
# En servidor producción
docker compose down -v  # -v elimina volúmenes
```

---

## 📞 CONTACTO EN CASO DE PROBLEMAS

- Verificar logs: `docker compose logs`
- Revisar conectividad de red
- Verificar que .env tiene los valores correctos
- Asegurar que puertos 5173, 8000 no están ocupados

---

## ✅ CHECKLIST FINAL

- [ ] Docker y Docker Compose instalados
- [ ] Código transferido a /opt/credinet-v2
- [ ] .env configurado con credenciales de producción
- [ ] Contenedores corriendo (`docker compose ps`)
- [ ] Frontend accesible en http://10.5.26.141:5173
- [ ] API accesible en http://10.5.26.141:8000/docs
- [ ] Login con admin funciona
- [ ] Datos de prueba eliminados
- [ ] Contraseñas de admin cambiadas
- [ ] Firewall configurado (si aplica)
