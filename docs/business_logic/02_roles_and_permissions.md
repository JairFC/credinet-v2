# Roles y Permisos del Sistema

Este documento detalla los roles de usuario en Credinet y los permisos asociados a cada uno, reflejando el modelo actual de múltiples roles por usuario.

## 1. Resumen de Roles

El sistema utiliza un modelo de roles puro, donde los permisos no están atados a una única columna en la tabla `users`, sino a las relaciones en la tabla `user_roles`. Esto permite que un usuario pueda tener múltiples roles simultáneamente (ej. un `administrador` que también es `cliente`).

| Rol                       | Propósito                                                                    | Acceso Principal                                                                 |
|---------------------------|------------------------------------------------------------------------------|----------------------------------------------------------------------------------|
| `desarrollador`           | Acceso total para desarrollo y depuración.                                   | Todas las rutas y funcionalidades, sin restricciones.                            |
| `administrador`           | Gestión completa del negocio. Control casi total.                            | CRUD completo de Asociados, Clientes, Préstamos y Usuarios.                      |
| `auxiliar_administrativo` | Apoyo al administrador con permisos para crear y editar.                     | Puede crear/editar entidades, pero no eliminar usuarios o asociados. |
| `asociado`                | Usuario de una empresa asociada para ver su cartera.                         | Acceso de solo lectura a sus préstamos, clientes y comisiones.                   |
| `cliente`                 | Cliente final que accede para ver sus propios productos.         | Acceso de solo lectura a sus préstamos, historial de pagos y perfil.             |

---

## 2. Permisos Detallados

### `desarrollador`
- **Acceso Total:** Omite todas las comprobaciones de permisos.

### `administrador`
- **Usuarios:** CRUD completo (Crear, Leer, Actualizar, Eliminar).
- **Asociados:** CRUD completo.
- **Clientes:** CRUD completo.
- **Préstamos:** CRUD completo.
- **Pagos:** CRUD completo.
- **Dashboards:** Vista completa del dashboard general.

### `auxiliar_administrativo`
- **Usuarios:** No tiene acceso a la gestión de usuarios.
- **Asociados:** Puede Crear, Leer y Actualizar. **No puede eliminar**.
- **Clientes:** CRUD completo.
- **Préstamos:** CRUD completo.
- **Pagos:** CRUD completo.
- **Dashboards:** Vista completa del dashboard general.

### `asociado`
- **Acceso:** De solo lectura (Read-Only).
- **Dashboard:** Ve un dashboard personalizado con el resumen de su cartera.
- **Asociados:** Solo puede ver la información del asociado al que pertenece.
- **Clientes:** Solo puede ver los clientes vinculados a los préstamos que ha originado.
- **Préstamos:** Solo puede ver los préstamos que ha originado. No puede crear, editar ni eliminar.
- **Pagos:** Solo puede ver los pagos de sus préstamos.

### `cliente` (Nuevo Rol)
- **Acceso:** De solo lectura (Read-Only).
- **Dashboard:** Ve un dashboard personalizado con el resumen de sus préstamos y pagos.
- **Perfil:** Puede ver y (en el futuro) editar su propia información de contacto.
- **Préstamos:** Solo puede ver la lista de sus propios préstamos (activos e históricos).
- **Pagos:** Puede ver el historial de pagos de cada uno de sus préstamos.
- **Tabla de Amortización:** Puede consultar la tabla de amortización de sus préstamos.
- **No puede ver información de otros clientes, asociados o usuarios.**
