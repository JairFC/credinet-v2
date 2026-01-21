# Estrategia de Ramas Git - Credinet v2.0

## Ramas Principales

### `main`
- **Propósito**: Rama de producción estable
- **Uso**: Solo código completamente probado y listo para producción
- **Deploy**: Servidor de producción (10.5.26.141)
- **Reglas**:
  - Nunca hacer commits directos
  - Solo merge desde `develop` después de testing completo
  - Tags de versión aquí: v2.0.0, v2.0.1, etc.

### `develop`
- **Propósito**: Rama de integración
- **Uso**: Código en desarrollo que funciona correctamente
- **Deploy**: Servidor de desarrollo (192.168.98.98)
- **Reglas**:
  - Merge de feature branches aquí
  - Probar antes de mergear a main

## Ramas de Trabajo

### `feature/*`
- **Propósito**: Desarrollo de nuevas funcionalidades
- **Nomenclatura**: `feature/week-XX-descripcion` o `feature/nombre-funcionalidad`
- **Flujo**:
  1. Crear desde `develop`
  2. Desarrollar y commitear
  3. Push al remoto
  4. Merge a `develop`
  5. Eliminar rama local (opcional)

## Servidores

| Servidor | IP | Rama |
|----------|-----|------|
| Desarrollo | 192.168.98.98 | `develop` |
| Producción | 10.5.26.141 (ZeroTier) | `main` |

## Flujo de Trabajo

```
feature/nueva-funcionalidad
         │
         ▼ merge
      develop  ←── testing aquí (192.168.98.98)
         │
         ▼ merge (después de QA)
       main    ←── producción (10.5.26.141)
```

## Comandos Comunes

### Crear nueva feature
```bash
git checkout develop
git pull origin develop
git checkout -b feature/mi-funcionalidad
```

### Mergear feature a develop
```bash
git checkout develop
git pull origin develop
git merge feature/mi-funcionalidad
git push origin develop
```

### Preparar para producción
```bash
git checkout main
git pull origin main
git merge develop
git push origin main
git tag -a v2.0.X -m "Descripción versión"
git push origin v2.0.X
```

### Sincronizar en servidor de producción
```bash
cd /home/credicuenta/proyectos/credinet-v2
git fetch origin
git checkout main
git pull origin main
docker compose down
docker compose up -d --build
```

## Estado Actual (2026-01-19)

- ✅ `main` = `develop` = `a711ae8` (sincronizados)
- ✅ .vite removido del tracking
- ✅ .gitignore actualizado

## Ramas Activas

| Rama | Estado | Descripción |
|------|--------|-------------|
| main | ✅ Actualizada | Producción |
| develop | ✅ Actualizada | Desarrollo |
| feature/week-03-fixes-convenios-renovaciones | ✅ Mergeada | Sistema multi-rol + correcciones UI |

---
Última actualización: 2026-01-19
