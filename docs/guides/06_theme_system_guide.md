# Guía del Sistema de Temas Mejorado - Credinet

## Descripción General

El sistema de temas de Credinet ha sido mejorado para ser más robusto y consistente. Utiliza variables CSS personalizadas, clases utilitarias y hooks de React para proporcionar un cambio fluido entre modo claro y oscuro.

## Estructura del Sistema

### 1. Variables CSS (`frontend/src/index.css`)

#### Variables de Color
```css
/* Modo Oscuro (Predeterminado) */
--color-background: #1a1a1a
--color-surface: #242424
--color-surface-secondary: #2a2a2a
--color-surface-accent: #333333
--color-primary: #646cff
--color-text-primary: rgba(255, 255, 255, 0.87)
--color-text-secondary: rgba(255, 255, 255, 0.6)
--color-border: #444

/* Modo Claro */
--color-background: #f9f9f9
--color-surface: #ffffff
--color-surface-secondary: #f8f9fa
--color-surface-accent: #f2f2f2
--color-primary: #646cff
--color-text-primary: #213547
--color-text-secondary: #555
--color-border: #ddd
```

#### Variables de Estado
```css
--color-success: #22c55e / #16a34a
--color-warning: #f59e0b / #d97706
--color-danger: #ef4444 / #dc2626
--color-focus: #646cff
```

#### Variables de Espaciado
```css
--spacing-xs: 4px
--spacing-sm: 8px
--spacing-md: 16px
--spacing-lg: 24px
--spacing-xl: 32px
```

### 2. Clases Utilitarias

#### Formularios
- `.form-group` - Contenedor de campo de formulario
- `.form-label` - Etiquetas de campos
- `.form-input` - Campos de entrada
- `.form-select` - Elementos select
- `.form-error` - Mensajes de error
- `.form-success` - Mensajes de éxito

#### Botones
- `.btn` - Clase base para botones
- `.btn-primary` - Botón principal
- `.btn-secondary` - Botón secundario
- `.btn-success` - Botón de éxito
- `.btn-danger` - Botón de peligro
- `.btn-sm`, `.btn-lg` - Tamaños de botón

#### Layout
- `.page-container` - Contenedor principal de página
- `.card` - Contenedor de tarjeta
- `.form-grid` - Grid para formularios
- `.form-grid-2`, `.form-grid-3` - Grids de 2 y 3 columnas

#### Alertas
- `.alert` - Clase base para alertas
- `.alert-success` - Alerta de éxito
- `.alert-danger` - Alerta de error
- `.alert-warning` - Alerta de advertencia

### 3. Hook Personalizado (`useThemedStyles`)

```javascript
import { useThemedStyles } from '../hooks/useTheme';

const MyComponent = () => {
  const { formStyles, tableStyles, modalStyles } = useThemedStyles();
  
  return (
    <div style={formStyles.container}>
      <input style={formStyles.input} />
      <button style={formStyles.button}>Enviar</button>
    </div>
  );
};
```

## Migración de Componentes Existentes

### Antes (Estilos Inline)
```jsx
<div style={{
  backgroundColor: '#242424',
  color: 'white',
  padding: '16px',
  borderRadius: '8px'
}}>
  <input style={{
    backgroundColor: '#333',
    color: 'white',
    border: '1px solid #555'
  }} />
</div>
```

### Después (Clases CSS)
```jsx
<div className="page-container">
  <input className="form-input" />
</div>
```

## Componentes Actualizados

### 1. CollapsibleSection
- Usa variables CSS para colores
- Respeta automáticamente el tema activo
- Transiciones suaves

### 2. ErrorModal
- Colores y espaciado consistentes
- Sombras adaptables al tema
- Botones estilizados con clases

### 3. CreateAssociatePage (Ejemplo)
- Grid responsivo para formularios
- Validación visual mejorada
- Alertas temáticas

## Mejores Prácticas

### 1. Usar Variables CSS
```css
/* ✅ Correcto */
background-color: var(--color-surface);
color: var(--color-text-primary);

/* ❌ Evitar */
background-color: #242424;
color: white;
```

### 2. Usar Clases Utilitarias
```jsx
/* ✅ Correcto */
<button className="btn btn-primary">Enviar</button>

/* ❌ Evitar estilos inline */
<button style={{backgroundColor: '#646cff', color: 'white'}}>Enviar</button>
```

### 3. Grid Responsivo
```jsx
/* ✅ Correcto */
<div className="form-grid form-grid-2">
  <div className="form-group">...</div>
  <div className="form-group">...</div>
</div>
```

### 4. Validación Visual
```jsx
/* ✅ Correcto */
<input className={`form-input ${errors.field ? 'error' : ''}`} />
{errors.field && <div className="form-error">{errors.field}</div>}
```

## Solución de Problemas

### Problema: Los estilos no se aplican
**Solución**: Verificar que las variables CSS estén definidas y que la clase `.light-theme` se aplique correctamente al body.

### Problema: Componentes nuevos no respetan el tema
**Solución**: Usar las clases CSS proporcionadas en lugar de estilos inline.

### Problema: Transiciones bruscas entre temas
**Solución**: Agregar `transition` a los elementos que cambien de color:
```css
transition: background-color 0.2s, color 0.2s, border-color 0.2s;
```

## Ejemplo Completo

```jsx
import React, { useState } from 'react';
import { useThemedStyles } from '../hooks/useTheme';

const ExampleForm = () => {
  const [formData, setFormData] = useState({ name: '', email: '' });
  const [errors, setErrors] = useState({});
  
  return (
    <div className="page-container">
      <h1 className="section-title">Formulario Ejemplo</h1>
      
      <form className="card">
        <div className="form-grid form-grid-2">
          <div className="form-group">
            <label className="form-label">Nombre</label>
            <input 
              type="text"
              className={`form-input ${errors.name ? 'error' : ''}`}
              value={formData.name}
              onChange={(e) => setFormData({...formData, name: e.target.value})}
            />
            {errors.name && <div className="form-error">{errors.name}</div>}
          </div>
          
          <div className="form-group">
            <label className="form-label">Email</label>
            <input 
              type="email"
              className={`form-input ${errors.email ? 'error' : ''}`}
              value={formData.email}
              onChange={(e) => setFormData({...formData, email: e.target.value})}
            />
            {errors.email && <div className="form-error">{errors.email}</div>}
          </div>
        </div>
        
        <div className="text-right mt-4">
          <button type="button" className="btn btn-secondary mr-2">
            Cancelar
          </button>
          <button type="submit" className="btn btn-primary">
            Enviar
          </button>
        </div>
      </form>
    </div>
  );
};
```

Este sistema proporciona una base sólida para un diseño consistente y mantenible en toda la aplicación.
