# Contexto General del Proyecto CrediNet

Bienvenido a la documentación de **CrediNet**, un sistema integral de gestión de créditos y préstamos diseñado para la empresa "CrediCuenta".

Este documento sirve como el punto de partida para entender la arquitectura, funcionalidades y objetivos del proyecto.

## Propósito del Proyecto

El objetivo principal de CrediNet es proporcionar una plataforma robusta y fácil de usar para que los administradores, socios y clientes de CrediCuenta puedan gestionar todo el ciclo de vida de un préstamo, desde la solicitud inicial hasta su completa liquidación, incluyendo el cálculo de comisiones para los socios.

## Arquitectura de Alto Nivel

El sistema sigue una arquitectura de microservicios desacoplada, orquestada a través de Docker.

- **[Frontend](./FRONTEND.md)**: Una Single-Page Application (SPA) construida con **React** que proporciona una interfaz de usuario moderna e interactiva.
- **[Backend](./BACKEND.md)**: Una API RESTful desarrollada con **FastAPI** (Python) que maneja toda la lógica de negocio.
- **Base de Datos**: Una base de datos **PostgreSQL** que persiste todos los datos de la aplicación.
- **[Infraestructura](./INFRAESTRUCTURA.md)**: Todo el sistema se ejecuta en contenedores **Docker**, lo que garantiza un entorno consistente y facilita el despliegue.

Para una explicación detallada de cada componente, por favor, consulta los documentos enlazados.

## Flujo de Trabajo con Git

Para mantener el código organizado y la rama principal (`main`) siempre estable, seguimos el siguiente flujo:

- **`main`**: Esta rama está reservada exclusivamente para el código de producción. No se debe hacer push directamente a ella.
- **`develop`**: Es la rama principal de desarrollo. Todas las nuevas funcionalidades se integran aquí a través de Pull Requests.
- **`feature/...`**: Para cada nueva tarea o funcionalidad, se debe crear una nueva rama a partir de `develop` (por ejemplo, `feature/calculo-comisiones`).

## Tareas y Hoja de Ruta

La lista de tareas pendientes, en progreso y completadas se encuentra en el documento [**`tareas.md`**](./tareas.md). Este archivo sirve como nuestra hoja de ruta para el desarrollo futuro.

## Cómo Empezar

1.  **Clona el repositorio.**
2.  **Asegúrate de tener Docker y Docker Compose instalados.**
3.  **Crea un archivo `.env`** en la raíz del proyecto si es necesario (consulta `core/config.py` en el backend para ver las variables requeridas).
4.  **Ejecuta el comando:**
    ```bash
    docker-compose up --build
    ```
5.  **Accede a los servicios:**
    - Frontend: `http://192.168.98.98:5174`
    - Backend (API Docs): `http://192.168.98.98:8001/docs`
