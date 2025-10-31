# Guía de Inicio Rápido para Desarrolladores

Esta guía contiene los pasos esenciales para levantar el entorno de desarrollo de Credinet en tu máquina local.

## Prerrequisitos

-   **Docker:** Debes tener Docker y Docker Compose instalados.
    -   [Instruir Docker Engine](https://docs.docker.com/engine/install/)
    -   [Instruir Docker Compose](https://docs.docker.com/compose/install/)

## Levantando el Entorno

El proyecto está completamente containerizado, lo que simplifica enormemente la configuración.

1.  **Clona el Repositorio:**
    ```bash
    git clone <URL_DEL_REPOSITORIO>
    cd credinet
    ```

2.  **Levanta los Servicios con Docker Compose:**
    Desde la raíz del proyecto, ejecuta el siguiente comando:
    ```bash
    docker compose up --build
    ```
    -   `--build`: Esta bandera fuerza la reconstrucción de las imágenes de Docker si ha habido cambios en los `Dockerfile` o en los archivos de dependencias (`requirements.txt`, `package.json`). Es buena práctica usarla la primera vez o después de actualizar dependencias.

### Reinicio completo (estado limpio)

Cuando sea necesario garantizar un estado completamente limpio (por ejemplo, después de cambiar `init.sql`, seed data, o cuando quieras reiniciar la base de datos), usa el comando que elimina volúmenes y fuerza la reconstrucción:

```bash
docker compose down -v && docker compose up --build -d
```

Este comando elimina los volúmenes asociados (por ejemplo el volumen de la base de datos) y recrea los contenedores con una build fresca. Úsalo con precaución porque borra los datos persistidos en los volúmenes.

3.  **¡Listo!** Una vez que los contenedores se hayan construido y levantado, la aplicación estará disponible en las siguientes URLs:

    -   **Frontend (Aplicación React):** [http://192.168.98.98:5174](http://192.168.98.98:5174)
    -   **Backend (API FastAPI):** [http://192.168.98.98:8001](http://192.168.98.98:8001)
    -   **Documentación de la API (Swagger):** [http://192.168.98.98:8001/docs](http://192.168.98.98:8001/docs)

## Acceso a la Base de Datos

-   La base de datos PostgreSQL está expuesta en el puerto `5432` de tu máquina local. Puedes conectarte a ella usando tu cliente de base de datos preferido (como DBeaver, pgAdmin, o la terminal) con las siguientes credenciales (definidas en `docker-compose.yml`):
    -   **Host:** `localhost`
    -   **Puerto:** `5432`
    -   **Usuario:** `credinet_user`
    -   **Contraseña:** `credinet_pass`
    -   **Base de datos:** `credinet_db`

## Aplicando Cambios (Flujo de Trabajo Estándar)

Debido a la forma en que Docker maneja los volúmenes y el código fuente, el método más confiable para asegurar que **cualquier cambio** (backend, frontend, o `init.sql`) se aplique correctamente es realizar un reinicio completo del entorno.

**Comando de Actualización Universal:**
```bash
docker compose down --volumes && docker compose up --build -d
```

Este comando garantiza que te encuentres en un estado limpio y actualizado. Úsalo siempre que realices cambios en el código o en la configuración.

## Deteniendo el Entorno

-   Para detener los contenedores, presiona `Ctrl + C` en la terminal donde ejecutaste `docker compose up`.
-   Para detenerlos y eliminar los contenedores (pero no los datos del volumen de la base de datos), puedes ejecutar:
    ```bash
    docker compose down
    ```
-   Si quieres eliminar también el volumen de la base de datos para empezar de cero:
    ```bash
    docker compose down --volumes
    ```
