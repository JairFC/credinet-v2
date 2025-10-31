# Guía: System Health Check (SH)

El System Health Check (SH) es el sistema de diagnóstico de arranque de Credinet. Su misión es actuar como la primera línea de defensa contra regresiones, verificando la integridad de todos los componentes críticos de la aplicación después de cada cambio.

No es solo una prueba, es una simulación de una secuencia de arranque que valida desde la conectividad básica hasta las reglas de negocio más complejas y los flujos de creación de datos.

## ¿Cómo Funciona?

El servicio `smoke-tester` se ejecuta automáticamente con `docker compose up`. Realiza una serie de chequeos en un orden estricto. Si un chequeo crítico falla, el proceso se detiene y reporta un error, indicando que el sistema está en un estado inestable.

### Visualización y Registro

Puedes monitorear el SH de dos maneras:

1.  **En Tiempo Real:**
    ```bash
    docker logs -f credinet_smoke_tester
    ```
    Verás una salida clara y formateada, indicando el progreso y el resultado (`[ OK ]`, `[FAIL]` o `[SKIP]`) de cada paso.

2.  **Registro Persistente:**
    El SH genera un log detallado de cada ejecución en `backend/system_health_check.log`. Este archivo es invaluable para la depuración post-mortem.


## Cobertura de Chequeos (23 Pruebas)

El SH ha sido expandido para cubrir nuevas funcionalidades críticas y relaciones de datos.

### Sección 1: Conectividad
-   **[1/23] PING:** Verifica que el servidor backend esté en línea.

### Sección 2: Autenticación (AUTH)
-   **[2/23] Login Admin:** Confirma que el usuario `admin` puede autenticarse.
-   **[3/23] Login Asociado:** Confirma que el usuario `asociado_test` puede autenticarse.
-   **[4/23] Login Cliente:** Confirma que la usuaria `sofia.vargas` puede autenticarse.

### Sección 3: Control de Acceso Basado en Roles (RBAC)
-   **[5-7/23] Permisos de Administrador:** Verifica el acceso a listas de usuarios, asociados y al dashboard global.
-   **[8-9/23] Permisos de Asociado:** Verifica que **NO PUEDE** ver usuarios y que puede ver su propio dashboard.
-   **[10-12/23] Permisos de Cliente:** Verifica que **NO PUEDE** ver listas de usuarios/asociados y que puede ver su propio dashboard.

### Sección 4: Lógica de Negocio (Filtros)
-   **[13-15/23] Filtros de Listas:** Verifica que los filtros de búsqueda en usuarios, asociados y préstamos funcionan correctamente.

### Sección 5: Utilidades
-   **[16-17/23] Check Username:** Valida el endpoint que verifica la existencia de nombres de usuario.
-   **[18/23] Check CURP:** Valida el endpoint que verifica la existencia de CURPs.
-   **[19/23] Check Phone:** Valida el endpoint que verifica la existencia de números de teléfono.
-   **[20/23] Check Zip Code:** Valida la conectividad con la API externa de códigos postales.

### Sección 6: Integridad de Datos y Relaciones (NUEVO)
-   **[21/23] Integridad: Usuario de pruebas tiene aval correcto:** Verifica que el usuario de pruebas `aval_test` (id 40) tiene un aval correctamente relacionado y con datos válidos.
    - Esta sección está destinada a validar relaciones críticas entre entidades (avales, beneficiarios, direcciones, etc.) y puede expandirse en el futuro.

### Sección 7: Flujo E2E de Creación y Acceso
-   **[22/23] E2E: Creación de nuevo cliente:** Verifica que se puede crear un nuevo usuario con el rol `cliente` a través de la API.
-   **[23/23] E2E: Login de nuevo cliente:** Confirma que el cliente recién creado puede iniciar sesión.
-   **[SKIP] E2E: Creación de préstamo para nuevo cliente:** **Esta prueba se omite intencionadamente.** Reveló que el endpoint `POST /api/loans` no está implementado. La prueba está diseñada para pasar con un estado `[SKIP]` hasta que se implemente la funcionalidad.
-   **[PENDIENTE] E2E: Verificación de Permisos de Préstamo:** Las pruebas que verifican que el nuevo cliente puede ver su préstamo y que otros clientes no pueden, dependen de la creación del préstamo. Se activarán una vez que el endpoint sea implementado.

## Protocolo de Uso

-   **Obligatorio:** El SH **debe pasar (o mostrar SKIPS justificados)** antes de fusionar cualquier cambio a la rama principal.
-   **Expansión:** Al añadir una nueva funcionalidad o endpoint, es **mandatorio** añadir un nuevo chequeo al script `backend/smoke_test.py`.
-   **Estabilidad del Entorno:** El `docker-compose.yml` ha sido fortalecido con un `healthcheck` de base de datos que previene condiciones de carrera durante el arranque, asegurando que el SH se ejecute sobre una base estable.
