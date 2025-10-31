# Plan de Refactorización - Credinet

Este documento detalla el plan de refactorización para mejorar la estructura y consistencia del proyecto Credinet.

## 1. Objetivos

- Eliminar código duplicado y archivos con sufijos como `_fixed`, `_updated`, `_simple`
- Estandarizar la estructura de módulos y patrones de diseño
- Mejorar la documentación interna de cada módulo
- Asegurar que todas las referencias apunten a los archivos correctos

## 2. Plan de Acción para Documentos

### Fase 1: Eliminación de archivos duplicados ✓

- [x] Eliminar `routes_simple.py` después de verificar que no es utilizado
- [x] Actualizar `main.py` para importar `routes_fixed.py` en lugar de `routes.py`
- [x] Crear/actualizar README.md para explicar la estructura del módulo

### Fase 2: Consolidación de archivos (Próximo Sprint)

- [ ] Renombrar `routes_fixed.py` a `routes.py`
- [ ] Actualizar todas las referencias en `main.py`
- [ ] Verificar funcionalidad completa después de la refactorización

## 3. Plan de Acción para Asociados

### Fase 1: Eliminación de archivos duplicados ✓

- [x] Eliminar `routes_updated.py` y `schemas_updated.py` después de verificar que no son utilizados
- [x] Crear/actualizar README.md para explicar el estado del módulo y plan de transición

### Fase 2: Transición a perfiles de asociado (Próximo Sprint)

- [ ] Crear rutas para migrar datos del modelo antiguo al nuevo
- [ ] Actualizar dependencias para usar el nuevo modelo
- [ ] Documentar APIs y cambios de esquema

## 4. Directrices Generales

### Gestión de cambios

1. **NO crear archivos con sufijos** como `_fixed`, `_updated`, etc. En su lugar:
   - Usar control de versiones (git) para rastrear cambios
   - Realizar pruebas en ramas separadas antes de integrar con main

2. **Documentar cambios importantes**:
   - Cada módulo debe tener un README.md actualizado
   - Mantener docstrings actualizados en todas las funciones
   - Usar ADRs para decisiones arquitectónicas importantes

3. **Pruebas automatizadas**:
   - Cada módulo debe tener pruebas unitarias
   - Las pruebas deben ejecutarse antes de cada commit
   - El smoke-tester debe validar la funcionalidad clave

### Recordatorio de Leyes Fundamentales

1. **"Reconstrucción Completa"**: Después de CUALQUIER cambio en Docker, SIEMPRE ejecuta:
   ```bash
   docker compose down -v && docker compose up --build
   ```

2. **"Entorno Remoto SSH"**: Este proyecto NO está en localhost. Se ejecuta en un servidor remoto:
   - Frontend: http://192.168.98.98:5174
   - Backend: http://192.168.98.98:8001
   - API Docs: http://192.168.98.98:8001/docs