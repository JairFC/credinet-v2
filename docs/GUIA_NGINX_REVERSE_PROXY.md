# 🌐 Guía: Configurar Nginx como Reverse Proxy para CrediNet
**Objetivo**: Acceder a CrediNet con URL limpia (`http://credicuenta.local`) en lugar de `http://10.5.26.141:5173`

---

## 📋 Requisitos Previos

- ✅ Ubuntu Server con CrediNet corriendo
- ✅ Docker Compose funcionando
- ⚠️ Acceso root/sudo al servidor
- ⚠️ (Opcional) Acceso admin al router de la LAN

---

## 🔧 Opción 1: Nginx + DNS Local (Recomendada)

### Paso 1: Instalar Nginx

```bash
# En el servidor Ubuntu
sudo apt update
sudo apt install nginx -y

# Verificar instalación
nginx -v
sudo systemctl status nginx
```

### Paso 2: Configurar Nginx como Reverse Proxy

```bash
# Crear configuración de CrediNet
sudo nano /etc/nginx/sites-available/credicuenta
```

**Contenido del archivo**:

```nginx
# =============================================================================
# CrediNet v2.0 - Configuración Nginx
# =============================================================================

# Redirigir HTTP a HTTPS (descomentar cuando tengas SSL)
# server {
#     listen 80;
#     server_name credicuenta.local;
#     return 301 https://$server_name$request_uri;
# }

# Servidor principal
server {
    listen 80;
    server_name credicuenta.local;
    
    # Logs
    access_log /var/log/nginx/credicuenta_access.log;
    error_log /var/log/nginx/credicuenta_error.log;
    
    # Timeout settings para long-running requests
    proxy_connect_timeout 60s;
    proxy_send_timeout 60s;
    proxy_read_timeout 60s;
    
    # Frontend - Servir el React SPA
    location / {
        proxy_pass http://localhost:5173;
        proxy_http_version 1.1;
        
        # Headers para proxy correcto
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # WebSocket support (si Vite HMR está activo)
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_cache_bypass $http_upgrade;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    # Backend API
    location /api/ {
        proxy_pass http://localhost:8000;
        proxy_http_version 1.1;
        
        # Headers
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        # CORS (Nginx lo maneja, no necesitas configurarlo en backend)
        add_header 'Access-Control-Allow-Origin' '$http_origin' always;
        add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, PATCH, OPTIONS' always;
        add_header 'Access-Control-Allow-Headers' 'DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization' always;
        add_header 'Access-Control-Expose-Headers' 'Content-Length,Content-Range' always;
        
        # Preflight requests
        if ($request_method = 'OPTIONS') {
            add_header 'Access-Control-Max-Age' 1728000;
            add_header 'Content-Type' 'text/plain; charset=utf-8';
            add_header 'Content-Length' 0;
            return 204;
        }
    }
    
    # FastAPI Docs
    location /docs {
        proxy_pass http://localhost:8000/docs;
        proxy_set_header Host $host;
    }
    
    location /redoc {
        proxy_pass http://localhost:8000/redoc;
        proxy_set_header Host $host;
    }
    
    location /openapi.json {
        proxy_pass http://localhost:8000/openapi.json;
        proxy_set_header Host $host;
    }
    
    # Health checks (para monitoreo)
    location /health {
        proxy_pass http://localhost:8000/health;
        proxy_set_header Host $host;
        access_log off;  # No logear health checks
    }
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml text/javascript application/json application/javascript application/xml+rss application/rss+xml;
}

# =============================================================================
# SSL Configuration (descomenta cuando tengas certificado)
# =============================================================================
# server {
#     listen 443 ssl http2;
#     server_name credicuenta.local;
#     
#     # Certificados SSL
#     ssl_certificate /etc/nginx/ssl/credicuenta.crt;
#     ssl_certificate_key /etc/nginx/ssl/credicuenta.key;
#     
#     # SSL Settings
#     ssl_protocols TLSv1.2 TLSv1.3;
#     ssl_ciphers HIGH:!aNULL:!MD5;
#     ssl_prefer_server_ciphers on;
#     
#     # ... resto de la configuración igual que arriba
# }
```

### Paso 3: Activar Configuración

```bash
# Crear symlink
sudo ln -s /etc/nginx/sites-available/credicuenta /etc/nginx/sites-enabled/

# Eliminar configuración default (opcional)
sudo rm /etc/nginx/sites-enabled/default

# Verificar sintaxis
sudo nginx -t

# Si todo OK, recargar Nginx
sudo systemctl reload nginx

# Verificar estado
sudo systemctl status nginx
```

### Paso 4: Configurar DNS

#### Opción 4a: DNS en el Router (Recomendada)

**Si tu router tiene servidor DNS (mayoría lo tienen)**:

1. Accede a la interfaz web del router (ej: `http://192.168.1.1`)
2. Busca sección **"DNS"** o **"DHCP/DNS Settings"**
3. Agregar entrada:
   ```
   credicuenta.local → 10.0.0.19
   ```
4. Guardar y reiniciar router (o solo servicio DNS)

**Routers comunes**:
- **TP-Link**: Advanced → Network → DHCP Server → Address Reservation
- **Netgear**: Advanced → Setup → LAN Setup → Add Custom DNS
- **Asus**: LAN → DHCP Server → Manual Assignment

#### Opción 4b: /etc/hosts en Cada PC (Alternativa)

**Windows**:
```powershell
# Abrir como Administrador: C:\Windows\System32\drivers\etc\hosts
# Agregar línea:
10.5.26.141 credicuenta.local
```

**Linux/Mac**:
```bash
sudo nano /etc/hosts
# Agregar línea:
10.5.26.141 credicuenta.local
```

### Paso 5: Actualizar Variables de Entorno

**En el servidor**:
```bash
cd /home/jair/proyectos/credinet-v2

# Editar .env
nano .env
```

**Cambiar**:
```bash
# Antes:
VITE_API_URL=http://10.5.26.141:8000

# Después:
VITE_API_URL=http://credicuenta.local/api
```

**Rebuild frontend con nueva URL**:
```bash
./scripts/rebuild-frontend.sh

# O full rebuild:
docker compose build frontend
docker compose up -d frontend
./scripts/rebuild-frontend.sh
```

### Paso 6: Verificar Funcionamiento

```bash
# Desde el servidor o cualquier PC en la LAN:
curl http://credicuenta.local/health
# Debe devolver: {"status":"healthy","version":"2.0.0"}

# Desde navegador:
# 1. Abrir: http://credicuenta.local
#    → Debe cargar el frontend
# 
# 2. Login debe funcionar correctamente
#
# 3. Verificar API docs: http://credicuenta.local/docs
```

---

## 🔐 Opción 2: Agregar HTTPS con Certificado Autofirmado

### Paso 1: Generar Certificado SSL

```bash
# Crear directorio para certificados
sudo mkdir -p /etc/nginx/ssl

# Generar certificado autofirmado (válido por 1 año)
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/credicuenta.key \
    -out /etc/nginx/ssl/credicuenta.crt \
    -subj "/C=MX/ST=CDMX/L=CDMX/O=CrediNet/CN=credicuenta.local"

# Permisos
sudo chmod 600 /etc/nginx/ssl/credicuenta.key
sudo chmod 644 /etc/nginx/ssl/credicuenta.crt
```

### Paso 2: Actualizar Configuración de Nginx

```bash
sudo nano /etc/nginx/sites-available/credicuenta
```

**Descomentar sección SSL** (la que está al final del archivo)

### Paso 3: Actualizar Variables

```bash
# En .env
VITE_API_URL=https://credicuenta.local/api
```

Rebuild frontend.

### Paso 4: Aceptar Certificado en Navegador

**Primera vez que accedas a `https://credicuenta.local`**:

1. Navegador mostrará "Your connection is not private"
2. Click en **"Advanced"**
3. Click en **"Proceed to credicuenta.local (unsafe)"**
4. Aceptar el certificado

⚠️ **Nota**: Es certificado autofirmado, los navegadores no lo reconocen automáticamente. Solo para uso interno.

---

## 🔍 Troubleshooting

### Problema: "Connection refused" al acceder a credicuenta.local

**Diagnóstico**:
```bash
# Verificar DNS resuelve correctamente
ping credicuenta.local
# Debe mostrar: 10.5.26.141 o 10.0.0.19

# Verificar Nginx está corriendo
sudo systemctl status nginx

# Verificar puertos
sudo netstat -tlnp | grep nginx
# Debe mostrar: 0.0.0.0:80

# Ver logs de Nginx
sudo tail -f /var/log/nginx/error.log
```

**Solución**:
```bash
# Reiniciar Nginx
sudo systemctl restart nginx

# Verificar firewall
sudo ufw status
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp  # Si usas HTTPS
```

---

### Problema: Frontend carga pero API no responde

**Diagnóstico**:
```bash
# Verificar backend está corriendo
docker compose ps backend

# Verificar health
curl http://localhost:8000/health

# Ver logs de Nginx
sudo tail -f /var/log/nginx/credicuenta_error.log
```

**Solución**: Verificar que el `proxy_pass` en Nginx apunta a `http://localhost:8000` (no a la IP de ZeroTier)

---

### Problema: CORS errors después de configurar Nginx

**Causa**: Nginx maneja CORS, no debe estar configurado también en el backend.

**Solución**:

1. **Remover CORS del backend** (en `backend/app/main.py`):
   ```python
   # Comentar o remover:
   # app.add_middleware(CORSMiddleware, ...)
   ```

2. **O configurar CORS solo para acceso directo**:
   ```python
   # Solo permitir acceso desde Nginx (localhost)
   CORS_ORIGINS: http://localhost
   ```

---

## 📊 Verificación Completa

```bash
# Script de verificación
cat > /tmp/verify_nginx.sh << 'EOF'
#!/bin/bash
echo "=== Verificación de Configuración de Nginx ==="
echo ""

echo "1. DNS Resolution:"
ping -c 1 credicuenta.local 2>/dev/null && echo "  ✓ OK" || echo "  ✗ FAIL"

echo "2. Nginx Status:"
sudo systemctl is-active nginx &>/dev/null && echo "  ✓ Running" || echo "  ✗ Stopped"

echo "3. Port 80:"
sudo netstat -tlnp | grep :80 &>/dev/null && echo "  ✓ Listening" || echo "  ✗ Not listening"

echo "4. Backend Health (via Nginx):"
curl -s http://credicuenta.local/health | grep -q "healthy" && echo "  ✓ OK" || echo "  ✗ FAIL"

echo "5. Frontend (via Nginx):"
curl -s http://credicuenta.local | grep -q "CrediCuenta" && echo "  ✓ OK" || echo "  ✗ FAIL"

echo ""
echo "=== Logs recientes ==="
sudo tail -5 /var/log/nginx/credicuenta_error.log 2>/dev/null || echo "No errors"
EOF

chmod +x /tmp/verify_nginx.sh
/tmp/verify_nginx.sh
```

---

## 🎯 Resumen de Beneficios

| Antes | Después |
|-------|---------|
| `http://10.5.26.141:5173` | `http://credicuenta.local` |
| Dos puertos (:5173, :8000) | Un solo puerto (:80) |
| CORS complejo | CORS simplificado (mismo dominio) |
| Sin SSL | SSL fácil de agregar |
| IP difícil de recordar | URL memorable |
| Configurar /etc/hosts en cada PC | DNS automático (si usas router) |

---

## 📝 Próximos Pasos Opcionales

1. **Certificado SSL Let's Encrypt** (dominio público): 
   - Requiere dominio real apuntando al servidor
   - Certificado válido reconocido por navegadores
   - Herramienta: `certbot`

2. **Load Balancing** (si escala a múltiples instancias):
   ```nginx
   upstream backend {
       server localhost:8000;
       server localhost:8001;
   }
   ```

3. **Rate Limiting** (protección contra abuso):
   ```nginx
   limit_req_zone $binary_remote_addr zone=one:10m rate=10r/s;
   limit_req zone=one burst=20;
   ```

4. **Caching** (mejorar performance):
   ```nginx
   proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=credicuenta:10m;
   proxy_cache credicuenta;
   proxy_cache_valid 200 10m;
   ```

---

**¿Necesitas ayuda con algún paso? Házmelo saber y te guío en detalle.**
