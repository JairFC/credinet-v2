# PROMPT PARA SERVIDOR DESTINO (credicuenta3)

Copia y pega todo este bloque en el chat de Claude/Copilot en el VSCode conectado al servidor destino:

---

## CONTEXTO

Necesito migrar el sistema Credinet v2.0 a este servidor. El código está en GitHub y debo:
1. Verificar el entorno de red y Docker
2. Clonar el repositorio desde GitHub
3. Configurar las variables de entorno
4. Levantar el sistema con Docker Compose
5. Ejecutar limpieza de datos de prueba (factory reset)
6. Verificar que todo funcione

## DATOS DEL PROYECTO

- **Repositorio**: https://github.com/JairFC/credinet-v2.git
- **Rama**: `feature/fix-rate-profiles-flexibility`
- **Usuario GitHub**: JairFC

## PASO 1: DIAGNÓSTICO DEL SERVIDOR

Ejecuta estos comandos y dame los resultados:

```bash
# 1. Información del sistema
echo "=== SISTEMA ===" && uname -a && echo ""

# 2. Usuario actual y permisos
echo "=== USUARIO ===" && whoami && groups && echo ""

# 3. Docker instalado y funcionando
echo "=== DOCKER ===" && docker --version && docker compose version && echo ""

# 4. Contenedores actuales
echo "=== CONTENEDORES ACTUALES ===" && docker ps -a && echo ""

# 5. Redes
echo "=== RED ===" && ip addr show | grep -E "inet |ens|eth|docker" && echo ""

# 6. Espacio en disco
echo "=== DISCO ===" && df -h / /home && echo ""

# 7. Git instalado
echo "=== GIT ===" && git --version && echo ""

# 8. Directorio actual y contenido
echo "=== DIRECTORIO ===" && pwd && ls -la && echo ""

# 9. GitHub SSH configurado
echo "=== GITHUB SSH ===" && ls -la ~/.ssh/ 2>/dev/null || echo "No hay claves SSH" && echo ""

# 10. Variables de entorno relevantes
echo "=== ENV ===" && printenv | grep -iE "docker|git|home|user" && echo ""
```

## PASO 2: CLONAR REPOSITORIO

```bash
# Ir al directorio de proyectos
cd ~/proyectos

# Clonar el repositorio (rama específica)
git clone -b feature/fix-rate-profiles-flexibility https://github.com/JairFC/credinet-v2.git

# Entrar al proyecto
cd credinet-v2

# Verificar rama
git branch -a
```

## PASO 3: CONFIGURAR VARIABLES DE ENTORNO

Crea el archivo `.env` en la raíz del proyecto con estos valores (ajusta la IP según la red):

```bash
# Crear .env desde template
cp .env.example .env

# Editar con los valores correctos
nano .env
```

**Valores a cambiar en .env:**
```env
# Base de datos
POSTGRES_PASSWORD=TU_PASSWORD_SEGURO_AQUI

# Backend
ENVIRONMENT=production
DEBUG=false
SECRET_KEY=GENERA_CON_openssl_rand_-hex_32

# CORS - cambiar IP según la red del servidor
CORS_ORIGINS=http://10.5.26.141:5173,http://10.5.26.141:8000,http://localhost:5173

# Frontend
VITE_API_URL=http://10.5.26.141:8000
```

También crea `.env` en `backend/` y `frontend-mvp/`:
```bash
cp backend/.env.example backend/.env
cp frontend-mvp/.env.example frontend-mvp/.env
```

## PASO 4: LEVANTAR DOCKER

```bash
# Construir y levantar
docker compose up -d --build

# Ver logs
docker compose logs -f
```

Espera a que los 3 contenedores estén healthy:
- credinet-postgres
- credinet-backend
- credinet-frontend

## PASO 5: EJECUTAR FACTORY RESET (LIMPIEZA)

Una vez levantado, ejecutar la limpieza de datos de prueba:

```bash
# Ejecutar factory reset
docker exec -i credinet-postgres psql -U credinet_user -d credinet_db < db/v2.0/scripts/factory_reset.sql
```

Esto:
- ✅ Elimina préstamos, pagos, usuarios de prueba
- ✅ Preserva catálogos (roles, niveles, legacy_payment_table, etc.)
- ✅ Preserva usuarios del sistema (admin, dev, jair)
- ✅ Reinicia secuencias

## PASO 6: VERIFICACIÓN

```bash
# Verificar tablas
docker exec credinet-postgres psql -U credinet_user -d credinet_db -c "
SELECT 
    (SELECT COUNT(*) FROM users) as usuarios,
    (SELECT COUNT(*) FROM loans) as prestamos,
    (SELECT COUNT(*) FROM payments) as pagos,
    (SELECT COUNT(*) FROM legacy_payment_table) as legacy_table,
    (SELECT COUNT(*) FROM cut_periods) as periodos;
"

# Probar API
curl http://localhost:8000/api/v1/health

# Probar Frontend
curl -I http://localhost:5173
```

**Resultado esperado después del factory reset:**
- usuarios: 3 (admin, dev, jair)
- prestamos: 0
- pagos: 0
- legacy_table: 28
- periodos: 288

## PASO 7: PROBAR LOGIN

Acceder a `http://10.5.26.141:5173` (o la IP que corresponda)

Credenciales:
- Usuario: `admin` / Password: `Admin123!`
- Usuario: `dev` / Password: `Dev123!`

---

## NOTAS SOBRE FECHAS DE CORTE

El sistema usa un cron job para procesar cortes automáticamente. Los días de corte son:
- Día 8 de cada mes
- Día 23 de cada mes

El cron está configurado en `backend/app/core/scheduler.py`. Para pruebas, puedes:
1. Ajustar la fecha del servidor (no recomendado)
2. Ejecutar el proceso de corte manualmente desde el código
3. Simplemente esperar al próximo corte real

---

**Cuando tengas los resultados del diagnóstico (Paso 1), compártelos para continuar.**
