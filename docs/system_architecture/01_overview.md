# Arquitectura del Sistema: Vista General

Credinet es una aplicación web full-stack diseñada para la gestión de préstamos. Sigue una arquitectura moderna de tres capas, completamente containerizada con Docker para un desarrollo y despliegue consistentes.

> **[LEYES FUNDAMENTALES DEL PROYECTO CREDINET]**
>
> 1. **"Reconstrucción Completa"**: Después de CUALQUIER cambio en Docker, SIEMPRE ejecuta: `docker compose down -v && docker compose up --build`. Es crucial eliminar volúmenes (`-v`) para limpiar la caché completamente.
>
> 2. **"Entorno Remoto SSH"**: Este proyecto NO está en localhost. Se ejecuta en un servidor remoto (192.168.98.98) conectado vía SSH. Para verificar el funcionamiento, SIEMPRE usa:
>    - Frontend: http://192.168.98.98:5174
>    - Backend: http://192.168.98.98:8001
>
> 3. **"Consultas SQL en Docker sin -t"**: Para ejecutar comandos SQL en el contenedor de base de datos, NUNCA uses el flag `-t` porque deja la consola pegada. SIEMPRE usa:
>    ```bash
>    docker exec credinet_db psql -U credinet_user -d credinet_db -c "TU_QUERY_AQUI;"
>    ```
>
> Estas leyes son inviolables y rigen cualquier acción de desarrollo o prueba.

## 1. Componentes Principales

![Diagrama de Arquitectura Simple](https://i.imgur.com/9yZ3B8r.png)

1.  **Frontend:**
    *   **Framework:** React (con Vite)
    *   **Lenguaje:** JavaScript (JSX)
    *   **Descripción:** Una Aplicación de Página Única (SPA) que consume la API del backend. Es responsable de toda la interfaz de usuario y la experiencia del cliente. Se comunica con el backend a través de una API RESTful.

2.  **Backend:**
    *   **Framework:** FastAPI
    *   **Lenguaje:** Python 3.11
    *   **Descripción:** Una API RESTful asíncrona que maneja toda la lógica de negocio, la autenticación de usuarios (JWT), la autorización por roles (RBAC) y la comunicación con la base de datos.

3.  **Base de Datos:**
    *   **Motor:** PostgreSQL 15
    *   **Descripción:** Base de datos relacional que persiste todos los datos de la aplicación: usuarios, clientes, préstamos, etc.

## 2. Orquestación y Despliegue

-   **Docker:** Cada componente (frontend, backend, db) tiene su propio `Dockerfile`, lo que permite empaquetar la aplicación y sus dependencias en imágenes de contenedor portátiles.
-   **Docker Compose:** El archivo `docker-compose.yml` orquesta el levantamiento de los tres servicios, configura las redes, los volúmenes y las variables de entorno, permitiendo levantar todo el entorno de desarrollo con un solo comando (`docker compose up`).
