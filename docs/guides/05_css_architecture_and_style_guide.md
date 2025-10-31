# Guía: Arquitectura CSS y Guía de Estilos

Este documento es la fuente de verdad para la estructura y la metodología de CSS en Credinet. Su propósito es asegurar un sistema de estilos consistente, mantenible y escalable.

## 1. Arquitectura Actual de Archivos

Hemos implementado una arquitectura de carga centralizada para tener un control predecible sobre la cascada de estilos. Todos los archivos CSS globales se importan en un orden específico directamente en `frontend/src/main.jsx`.

### Orden de Carga:

1.  **`index.css`**: Contiene las variables CSS globales (también conocidas como **Design Tokens**) para la paleta de colores, tipografía base y estilos fundamentales del `body`. Es la base de nuestro tema.
2.  **Estilos de Terceros** (ej. `react-datepicker/dist/react-datepicker.css`): Se importan los estilos por defecto de cualquier librería externa que lo requiera.
3.  **`styles/common.css`**: El corazón de nuestros estilos. Contiene las clases para todos los componentes reutilizables de la aplicación (tablas, formularios, botones, tarjetas, etc.).
4.  **`styles/overrides.css`**: Nuestro archivo de "alta especificidad". Se carga al final y se usa exclusivamente para **anular y personalizar** los estilos de las librerías de terceros, adaptándolos a nuestro tema sin necesidad de usar `!important`.

### ¿Cómo añadir estilos para un nuevo componente?

-   **Regla General:** Añade tus nuevas clases CSS al final del archivo `frontend/src/styles/common.css`.
-   **Componente de Terceros:** Si el nuevo componente es de una librería externa y necesita estilos personalizados, añade la importación de su CSS en `main.jsx` (Paso 2) y las reglas de anulación en `overrides.css`.

---

## 2. Planeación: Hacia un Sistema de CSS Robusto y Reutilizable

Para agilizar el desarrollo futuro y garantizar la consistencia visual, adoptaremos una metodología híbrida que combina **estilos por componente** con **clases de utilidad (utility classes)**.

### 2.1. Nomenclatura de Componentes (BEM-like)

Para evitar colisiones y hacer el CSS más legible, usaremos una convención de nombres inspirada en BEM (Block__Element--Modifier).

-   **Bloque:** El componente principal. (ej. `.card`, `.user-form`)
-   **Elemento:** Una parte del bloque. (ej. `.card__title`, `.user-form__submit-button`)
-   **Modificador:** Una variación del bloque o elemento. (ej. `.card--highlighted`, `.button--danger`)

**Ejemplo en `common.css`:**

```css
/* Bloque del componente Card */
.card {
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: 8px;
  padding: 20px;
}

/* Elemento: Título dentro del Card */
.card__title {
  margin-top: 0;
  font-size: 1.2rem;
  color: var(--color-text-primary);
}

/* Modificador: Un Card con un borde resaltado */
.card--highlighted {
  border-color: var(--color-primary);
}
```

### 2.2. Clases de Utilidad (Utility Classes)

Crearemos un conjunto de clases simples y de un solo propósito para manejar layouts y espaciados comunes, reduciendo la necesidad de escribir CSS repetitivo. Estas clases se añadirán a `common.css`.

**Propuesta de Clases de Utilidad:**

```css
/* --- Utilidades de Espaciado (Margin) --- */
.mt-1 { margin-top: 0.5rem; }
.mt-2 { margin-top: 1rem; }
.mb-1 { margin-bottom: 0.5rem; }
.mb-2 { margin-bottom: 1rem; }
/* etc. para ml, mr, mx, my, m */

/* --- Utilidades de Flexbox --- */
.d-flex { display: flex; }
.flex-column { flex-direction: column; }
.justify-between { justify-content: space-between; }
.align-center { align-items: center; }
.gap-1 { gap: 0.5rem; }
.gap-2 { gap: 1rem; }

/* --- Utilidades de Texto --- */
.text-center { text-align: center; }
.text-danger { color: #d9534f; }
.text-success { color: #5cb85c; }
```

### 2.3. Uso Práctico

Al combinar ambos enfoques, podemos construir interfaces de forma rápida y consistente.

**Ejemplo en un componente JSX:**

```jsx
// En lugar de añadir estilos complejos o en línea...
<div className="card card--highlighted">
  <h3 className="card__title mb-2">Título del Componente</h3>
  <p>Contenido del componente.</p>
  <div className="d-flex justify-between align-center mt-2">
    <button className="button">Aceptar</button>
    <button className="button button--danger">Cancelar</button>
  </div>
</div>
```

La implementación de estas clases de utilidad y la adhesión a la nomenclatura BEM se realizará de forma incremental a medida que se desarrollen nuevas funcionalidades.
