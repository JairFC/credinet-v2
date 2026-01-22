# 📋 Flujo de Trabajo para Correcciones UI/UX

## Resumen

Este documento establece el proceso estándar para aplicar correcciones de interfaz de usuario, estilos y mejoras visuales en el proyecto Credinet v2.

---

## 🌳 Estructura de Ramas

```
main (producción) ← develop ← feature/nombre-descriptivo
```

| Rama | Propósito | Servidor |
|------|-----------|----------|
| `main` | Producción | 10.5.26.141:5173 |
| `develop` | Integración/QA | 192.168.98.98:5173 |
| `feature/*` | Desarrollo activo | Local/Dev |

---

## 🔄 Proceso Paso a Paso

### Paso 1: Crear Rama Feature

```bash
cd /home/credicuenta/proyectos/credinet-v2
git checkout develop
git pull origin develop
git checkout -b feature/nombre-descriptivo
```

**Nomenclatura de ramas:**
- `feature/ui-polish-*` - Mejoras visuales generales
- `feature/fix-*` - Correcciones de bugs
- `feature/loader-*` - Mejoras de loaders/spinners
- `feature/style-*` - Cambios de estilos CSS

### Paso 2: Desarrollo

1. Identificar archivos afectados
2. Hacer cambios incrementales
3. Probar localmente o en dev (192.168.98.98)
4. Commits atómicos con mensajes descriptivos

```bash
# Ejemplo de commits
git add .
git commit -m "style: Mejorar loader de página clientes"
git commit -m "style: Rediseñar badge de estado activo"
git commit -m "fix: Corregir fondo de secciones colapsables"
```

### Paso 3: Push a Feature Branch

```bash
git push origin feature/nombre-descriptivo
```

### Paso 4: Merge a Develop

```bash
git checkout develop
git pull origin develop
git merge feature/nombre-descriptivo
git push origin develop
```

### Paso 5: Validar en Develop (Dev Server)

```bash
# En servidor dev (192.168.98.98)
docker compose restart frontend
```

**Checklist de validación:**
- [ ] Loaders funcionan correctamente
- [ ] Estilos se ven bien en Chrome/Firefox
- [ ] No hay errores en consola
- [ ] Responsive design funciona

### Paso 6: Merge a Main (Producción)

```bash
git checkout main
git pull origin main
git merge develop
git push origin main
```

### Paso 7: Deploy en Producción

```bash
# En servidor producción (10.5.26.141)
cd /home/credicuenta/proyectos/credinet-v2
git pull origin main
docker compose restart frontend
```

---

## 📁 Archivos Comunes a Modificar

### Loaders y Spinners
```
frontend-mvp/src/shared/components/Loader.jsx
frontend-mvp/src/shared/components/Loader.css
frontend-mvp/src/shared/components/PageLoader.jsx (si existe)
```

### Badges y Estados
```
frontend-mvp/src/shared/styles/badges.css
frontend-mvp/src/features/*/pages/*.css
```

### Formularios
```
frontend-mvp/src/shared/components/CollapsibleSection.jsx
frontend-mvp/src/shared/components/CollapsibleSection.css
frontend-mvp/src/shared/styles/forms.css
```

### Título y Favicon
```
frontend-mvp/index.html
frontend-mvp/public/favicon.ico
frontend-mvp/public/logo.png
```

---

## 🎨 Guía de Estilos

### Colores del Sistema
```css
/* Primarios */
--primary: #4F46E5;      /* Indigo - Acciones principales */
--primary-hover: #4338CA;

/* Estados */
--success: #10B981;      /* Verde - Activo/OK */
--warning: #F59E0B;      /* Amarillo - Advertencia */
--error: #EF4444;        /* Rojo - Error/Inactivo */
--info: #3B82F6;         /* Azul - Información */

/* Fondos */
--bg-dark: #0F172A;      /* Fondo principal */
--bg-card: #1E293B;      /* Cards */
--bg-hover: #334155;     /* Hover states */
```

### Loader Estándar
```jsx
<div className="loader-container">
  <div className="loader-spinner"></div>
  <span className="loader-text">Cargando...</span>
</div>
```

### Badge de Estado
```jsx
<span className={`status-badge status-${estado}`}>
  {estado === 'activo' ? '✓ Activo' : '✗ Inactivo'}
</span>
```

---

## ⚠️ Precauciones

1. **No modificar lógica de negocio** en cambios de UI
2. **Probar en dev antes de producción**
3. **Commits pequeños y descriptivos**
4. **Documentar cambios visuales significativos**
5. **Verificar que no rompe responsive**

---

## 🔙 Rollback si hay problemas

```bash
# En producción
git checkout main
git reset --hard HEAD~1
git push origin main --force
docker compose restart frontend
```

---

## 📝 Template de Commit Messages

```
style: Descripción breve del cambio visual

- Detalle 1
- Detalle 2

Archivos: archivo1.css, archivo2.jsx
```

---

**Documento creado:** 2026-01-22  
**Versión:** 1.0
