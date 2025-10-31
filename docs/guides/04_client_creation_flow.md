# Guía: Flujo de Creación de Clientes


La creación de un nuevo cliente es un proceso unificado y automatizado, gestionado a través de la página "Crear Nuevo Cliente" en el frontend. Todo el registro se realiza en un solo paso, sin confirmaciones intermedias, y la asignación de perfil es automática.

## Interfaz de Usuario: Secciones Colapsables

El formulario está organizado en secciones colapsables para mantener la interfaz limpia y guiar al usuario paso a paso:

1.  **Datos Personales y de Identificación**
2.  **Datos de la Cuenta y Contacto**
3.  **Dirección**
4.  **Beneficiario (Opcional)**

## Automatizaciones y Características Clave

### 1. Flujo de Validación de CURP en Ventana Modal (Identificador Principal)

La CURP es el identificador único más importante para un cliente. El sistema implementa un flujo robusto en una **ventana modal emergente** para asegurar su unicidad y corrección, mejorando la experiencia de usuario.

-   **Generación Automática:** A medida que el usuario completa los campos de `nombre`, `apellidos`, `fecha de nacimiento`, `género` y `estado de nacimiento`, el campo CURP se genera y actualiza automáticamente gracias a la utilidad `curp_generator.js`.
-   **Verificación Asistida por Modal:**
    -   Un botón "Verificar" se activa cuando la CURP tiene 18 caracteres.
    -   Al presionarlo, **una ventana modal aparece**, superponiéndose al formulario. Esto centra la atención del usuario en el importante paso de la verificación.
    -   Dentro del modal, el usuario puede confirmar la CURP generada o corregirla si es necesario (ej. la homoclave).
    -   Al hacer clic en "Confirmar y Verificar", el sistema muestra un estado de "Cargando..." y llama al endpoint del backend (`GET /api/utils/check-curp/{curp}`).
    -   El modal se actualiza para mostrar el resultado: un mensaje claro de éxito ("✅ CURP disponible") o de error ("❌ Esta CURP ya está registrada").
-   **Bloqueo Inteligente:** El botón principal "Crear Cliente" permanece deshabilitado hasta que una CURP válida y disponible ha sido confirmada a través del flujo del modal, previniendo envíos de formularios erróneos.

### 2. Autocompletado Inteligente de Usuario y Contraseña

Para minimizar la entrada de datos manual y acelerar el proceso de registro, el formulario incluye dos potentes automatizaciones:

-   **Generación de Nombre de Usuario en Tiempo Real:**
    -   A medida que el administrador escribe el nombre y apellido del cliente, el campo `Nombre de Usuario` se genera automáticamente siguiendo el formato `nombre.apellido`.
    -   El sistema verifica la disponibilidad de este nombre de usuario en tiempo real contra el endpoint `GET /api/utils/check-username/{username}`.
    -   Si el nombre de usuario ya existe, el sistema añade automáticamente un sufijo numérico (ej. `sofia.vargas1`, `sofia.vargas2`) hasta encontrar uno disponible.
-   **Autocompletado de Contraseña Condicional:**
    -   La contraseña **no se rellena automáticamente** hasta que la CURP del cliente ha sido **verificada con éxito** a través del modal.
    -   Una vez que la CURP es validada, los campos de `Contraseña` y `Confirmar Contraseña` se rellenan automáticamente con el valor de la CURP, proporcionando una contraseña inicial segura y fácil de recordar para el administrador.

### 3. Autocompletado de Dirección con Fallback Inteligente

-   **Flujo Principal:** Cuando el usuario introduce un Código Postal de 5 dígitos, el sistema autocompleta los campos de `Estado`, `Municipio` y proporciona una lista de `Colonias` para seleccionar.

-   **Flujo de Fallback:** Si el servicio de códigos postales falla, el sistema activa un modo de entrada manual mejorado:
    -   **Estado:** Se convierte en un menú desplegable con todos los estados de México.
    -   **Municipio:** Se convierte en un menú despleplegable que se carga dinámicamente según el estado seleccionado.
    -   **Colonia:** Se convierte en un campo de texto libre.
    -   Esta mejora minimiza los errores de captura de datos incluso cuando los servicios externos fallan.

### 4. Validación de Teléfono (Unicidad y Formato)

-   **Validación en Tiempo Real:** A medida que el usuario escribe en el campo de teléfono, el sistema verifica en tiempo real contra el endpoint `GET /api/utils/check-phone/{phone_number}` si el número ya está registrado.
-   **Restricción de Formato:** El campo solo permite la entrada de 10 dígitos numéricos.
-   **Feedback Centralizado:** Cualquier error de validación (formato incorrecto, número duplicado) se añade a la lista de errores que se mostrará en el modal de validación al intentar crear el cliente.

### 5. Creación Atómica y Retroalimentación por Modal

-   **Validación Centralizada:** Al hacer clic en "Crear Cliente", el sistema no envía la petición inmediatamente. Primero, una función de validación revisa todos los campos.
-   **Modal de Errores:** Si se encuentra uno o más errores (campos vacíos, CURP no validada, teléfono duplicado), se muestra una **ventana modal de errores** que lista de forma clara todo lo que el usuario debe corregir.
-   **Modal de Éxito:** Si la creación del cliente en el backend es exitosa, se muestra una **ventana modal de éxito** confirmando la operación antes de redirigir al usuario a la lista de clientes.
-   **Creación Atómica:** Al enviar el formulario, el frontend empaqueta todos los datos, incluyendo la información opcional del beneficiario, en un único objeto. El backend (`POST /api/auth/users`) está diseñado para recibir este objeto y, en una única transacción de base de datos, crear el registro en la tabla `users` y, si se proporciona, también en la tabla `beneficiaries`, asegurando la consistencia de los datos.
