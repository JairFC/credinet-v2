# Smoke Tester - Sistema de Validación Automática

> **Propósito**: El servicio `smoke-tester` es un sistema de pruebas automáticas que valida la salud e integridad de los componentes críticos del sistema Credinet.

## Configuración Docker

### Definición en `docker-compose.yml`

```yaml
smoke-tester:
  build:
    context: ./backend
  container_name: credinet_smoke_tester
  depends_on:
    backend:
      condition: service_healthy
  command: ["python", "smoke_test_clean.py"]
  environment:
    POSTGRES_USER: credinet_user
    POSTGRES_PASSWORD: credinet_pass
    POSTGRES_DB: credinet_db
    POSTGRES_HOST: db
  networks:
    - credinet
```

### Características Clave:
- **Dependencia**: Se ejecuta solo después de que el backend esté healthy
- **Comando**: Ejecuta `smoke_test_clean.py` (versión consolidada)
- **Red**: Conectado a la red `credinet` para acceso completo a servicios
- **Variables de entorno**: Acceso completo a la base de datos

## Archivo Principal: `smoke_test_clean.py`

### Ubicación: `/backend/smoke_test_clean.py`

**Propósito**: Script consolidado que reemplaza múltiples versiones anteriores (`smoke_test.py`, `smoke_test_robust.py`, etc.).

### Funcionalidades de Validación

#### 1. **Validación de Conectividad**
- ✅ Conexión a base de datos PostgreSQL
- ✅ Disponibilidad del API backend (`/api/ping`)
- ✅ Respuesta del frontend (si aplicable)

#### 2. **Validación de Base de Datos**
- ✅ Existencia de tablas críticas (`users`, `loans`, `payments`, etc.)
- ✅ Integridad referencial entre tablas
- ✅ Presencia de datos de prueba (seeds)

#### 3. **Validación de Endpoints API**
- ✅ Endpoints de autenticación funcionando
- ✅ Endpoints de loans accesibles
- ✅ Endpoints de associates operativos
- ✅ Validación de permisos por roles

#### 4. **Validación de Lógica de Negocio**
- ✅ Cálculos de amortización correctos
- ✅ Lógica quincenal (fechas perfectas)
- ✅ Sistema de comisiones funcionando

## Historial de Evolución

### Archivos Obsoletos (Eliminados en limpieza masiva):
- ❌ `smoke_test_old.py` - Primera versión
- ❌ `smoke_test_robust.py` - Versión con más validaciones
- ❌ `smoke_test.py` → `smoke_test_obsoleto.py` - Versión legacy

### Estado Actual:
- ✅ `smoke_test_clean.py` - **Único archivo activo**
- ✅ Consolidación de todas las pruebas críticas
- ✅ Eliminación de duplicaciones

## Proceso de Ejecución

### 1. **Inicio Automático**
```bash
# Al levantar el entorno completo
docker compose up --build

# El smoke-tester se ejecuta automáticamente después del backend
```

### 2. **Monitoreo de Logs**
```bash
# Ver ejecución en tiempo real
docker logs -f credinet_smoke_tester

# Ver logs completos
docker logs credinet_smoke_tester
```

### 3. **Ejecución Manual**
```bash
# Ejecutar smoke test independientemente
docker compose run smoke-tester

# Ejecutar desde dentro del contenedor backend
docker exec credinet_backend python smoke_test_clean.py
```

## Estructura Típica de Pruebas

### Ejemplo de Test Function:
```python
def validate_database_connectivity():
    """Valida que se puede conectar a la base de datos"""
    try:
        conn = psycopg2.connect(
            host=os.getenv('POSTGRES_HOST'),
            database=os.getenv('POSTGRES_DB'),
            user=os.getenv('POSTGRES_USER'),
            password=os.getenv('POSTGRES_PASSWORD')
        )
        cursor = conn.cursor()
        cursor.execute("SELECT 1")
        result = cursor.fetchone()
        assert result[0] == 1
        conn.close()
        return True, "✅ Conexión a base de datos exitosa"
    except Exception as e:
        return False, f"❌ Error de conexión: {e}"
```

### Ejemplo de Validación de API:
```python
def validate_api_endpoint(endpoint, expected_status=200):
    """Valida que un endpoint responde correctamente"""
    try:
        response = requests.get(f"{API_BASE_URL}{endpoint}")
        if response.status_code == expected_status:
            return True, f"✅ {endpoint} respondió correctamente"
        else:
            return False, f"❌ {endpoint} retornó {response.status_code}"
    except Exception as e:
        return False, f"❌ Error en {endpoint}: {e}"
```

## Reportes de Salida

### Formato de Logs:
```
🔥 CREDINET SMOKE TEST - INICIO
========================================

SECCIÓN 1: CONECTIVIDAD
✅ Base de datos conectada
✅ API backend respondiendo
✅ Endpoint /api/ping operativo

SECCIÓN 2: INTEGRIDAD DE DATOS
✅ Tabla users existe
✅ Tabla loans existe
✅ Datos de prueba cargados

SECCIÓN 3: ENDPOINTS CRÍTICOS
✅ /api/loans/ accesible
✅ /api/associates/ accesible
⚠️  /api/auth/users temporalmente deshabilitado

SECCIÓN 4: LÓGICA DE NEGOCIO
✅ Cálculo de amortización correcto
✅ Fechas quincenales perfectas
✅ Sistema de comisiones funcionando

========================================
RESULTADO FINAL: ✅ SISTEMA OPERATIVO
```

## Integración con CI/CD

### Health Checks:
El smoke-tester actúa como un **health check avanzado** del sistema completo, validando no solo que los servicios estén "vivos", sino que estén funcionando correctamente.

### Uso en Desarrollo:
- **Validación post-deploy**: Confirma que los cambios no rompieron funcionalidades críticas
- **Debugging**: Identifica rápidamente qué componente específico está fallando
- **Documentación viva**: Los tests actúan como documentación ejecutable de cómo debe funcionar el sistema

## Configuración de Alertas

### Variables de Entorno Opcionales:
```yaml
environment:
  SMOKE_TEST_SLACK_WEBHOOK: "https://hooks.slack.com/..."  # Notificaciones
  SMOKE_TEST_EMAIL_ALERTS: "dev-team@credinet.com"        # Email alerts
  SMOKE_TEST_RETRY_COUNT: "3"                             # Reintentos
  SMOKE_TEST_TIMEOUT: "30"                                # Timeout en segundos
```

## Mantenimiento

### Agregar Nuevas Validaciones:
1. Identificar funcionalidad crítica nueva
2. Agregar test function en `smoke_test_clean.py`
3. Integrar en el flujo principal de validaciones
4. Documentar en este archivo

### Ejemplo de Nueva Validación:
```python
def validate_quincenal_logic():
    """Valida que la lógica quincenal esté funcionando"""
    # ... implementación específica
    pass
```

> **📋 NOTA**: El smoke-tester es un componente crítico para la confiabilidad del sistema. Mantenerlo actualizado es esencial para detectar problemas tempranamente.