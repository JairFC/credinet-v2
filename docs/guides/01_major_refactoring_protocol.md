# Guía de Campo: Protocolo de Refactorización Mayor

Este documento detalla el proceso paso a paso para ejecutar refactorizaciones a gran escala en el sistema Credinet. Está basado en la exitosa (aunque ardua) refactorización del sistema de autenticación a un modelo multi-rol.

> **[LEY FUNDAMENTAL #1: "ESTABILIDAD ANTE TODO"]**
> 
> Una refactorización mayor no está completa hasta que el `System Health Check` (`smoke_test.py`) vuelve a un estado **exitoso**. Cada paso debe tener como objetivo final la restauración de la estabilidad verificada del sistema.
>
> Esta es la ley primordial que rige todo desarrollo en Credinet. Ninguna funcionalidad, sin importar cuán urgente sea, puede comprometer la estabilidad del sistema.

---

## Fase 0: Seguridad y Preparación

**Objetivo:** Aislar el trabajo y crear un punto de retorno seguro.

1.  **Verificar Estado Limpio:** Asegúrate de que no haya cambios sin confirmar en tu rama actual (`git status`).
2.  **Crear un Commit de Checkpoint:** Guarda el último estado funcional conocido.
    ```bash
    git add .
    git commit -m "checkpoint: Preparando para refactorización de <nombre_funcionalidad>"
    ```
3.  **Crear una Nueva Rama:** NUNCA trabajes directamente sobre la rama principal.
    ```bash
    git checkout -b feature/refactor-<nombre_funcionalidad>
    ```

---

## Fase 1: Análisis de Impacto

**Objetivo:** Entender cada punto del sistema que será afectado por el cambio. No escribas código de la nueva funcionalidad aún.

1.  **Mapeo del Backend:** Usa `search_file_content` para encontrar todas las ocurrencias de las palabras clave relacionadas con la funcionalidad a cambiar.
    -   *Ejemplo (Multi-Rol):* Buscamos `role`, `UserRole`, `require_role`.
2.  **Mapeo del Frontend:** Realiza la misma búsqueda en los archivos `.jsx` y `.js`.
    -   *Ejemplo (Multi-Rol):* Buscamos `user.role`.
3.  **Análisis de la Base de Datos:** Revisa `db/init.sql` y los archivos de `seeds` para entender la estructura de datos actual.
4.  **Plan de Acción:** Basado en el mapeo, escribe un plan detallado de los archivos que modificarás y en qué orden.

---

## Fase 2: Implementación Iterativa y Depuración

**Objetivo:** Realizar los cambios de forma incremental, sabiendo que el sistema se romperá temporalmente.

1.  **Primero la Base de Datos:** Modifica `db/init.sql` y los `seeds` para reflejar la nueva estructura.
2.  **Luego el Backend:** Actualiza los modelos (`schemas.py`), la lógica de negocio y los endpoints (`routes.py`).
3.  **Finalmente el Frontend:** Adapta la interfaz de usuario a los nuevos modelos y lógica del backend.
4.  **Ciclo de Depuración:** Este es el paso más importante.
    a.  **Reconstruye el Entorno:** Ejecuta `docker compose down --volumes && docker compose up --build -d`.
    b.  **Ejecuta el Health Check:** `docker logs credinet_smoke_tester`.
    c.  **Lee el Error:** El test fallará. Lee el mensaje de error (ej. `Connection refused`, `500 Internal Server Error`).
    d.  **Diagnostica el Error del Backend:** Si el test no puede conectar, lee los logs del backend: `docker logs credinet_backend`. El traceback te dirá la causa exacta (ej. `ImportError`, `NameError`).
    e.  **Aplica la Corrección:** Haz el cambio necesario en el código.
    f.  **Repite:** Vuelve al paso `a`. Continúa este ciclo hasta que el `smoke_tester` reporte un fallo de lógica (ej. `403 Forbidden`) en lugar de un fallo de arranque.

---

## Fase 3: Actualización de Pruebas y Verificación Final

**Objetivo:** Asegurar que la nueva funcionalidad está cubierta por las pruebas y que el sistema es estable.

1.  **Actualiza el Health Check:** Modifica `smoke_test.py` para que se alinee con la nueva lógica. Añade nuevas pruebas si es necesario para cubrir los cambios.
    -   *Ejemplo (Multi-Rol):* Se actualizó el test de login para esperar una lista de roles y se añadió una prueba de acceso dual.
2.  **Ciclo de Verificación Final:**
    a.  **Reconstruye y Prueba:** `docker compose down --volumes && docker compose up --build -d` y luego `docker logs credinet_smoke_tester`.
    b.  **Depura el Test:** Si el test falla, lee el error, corrige el `smoke_test.py` o el código de la aplicación, y repite.
    c.  **Éxito:** El ciclo termina cuando el `smoke_tester` se ejecuta de forma **exitosa**.

---

## Fase 4: Documentación y Fusión

**Objetivo:** Integrar el trabajo y asegurar que el conocimiento no se pierda.

1.  **Actualiza la Documentación:** Modifica todos los documentos (`business_logic`, `system_architecture`, `personas`) que fueron afectados por el cambio.
2.  **Commit Final y Fusión:**
    ```bash
    git add .
    git commit -m "feat(refactor): Implementa <nombre_funcionalidad>"
    git checkout <rama_principal>
    git merge feature/refactor-<nombre_funcionalidad>
    git branch -d feature/refactor-<nombre_funcionalidad>
    ```
