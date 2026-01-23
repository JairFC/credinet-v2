# 🚀 Flujo de Actualización de Producción - CrediNet v2

## Arquitectura Actual

```
┌─────────────────────────────────────────────────────────────────┐
│                     SERVIDOR PRODUCCIÓN                          │
│                    (10.5.26.141 - ZeroTier)                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │  PostgreSQL │  │   Backend   │  │  Frontend   │             │
│  │   :5432     │  │   :8000     │  │   :5173     │             │
│  │             │  │  (uvicorn)  │  │  (serve)    │             │
│  └─────────────┘  └─────────────┘  └─────────────┘             │
│                                                                  │
│  Volúmenes:                                                     │
│  • ./backend → /app (código Python, hot-reload automático)     │
│  • ./frontend-mvp/src → /app/src (código React, rebuild manual)│
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
                           │
                           │ ZeroTier VPN (10.5.26.0/24)
                           │
┌─────────────────────────────────────────────────────────────────┐
│                      PC REMOTA                                   │
│                    (10.5.26.45)                                  │
├─────────────────────────────────────────────────────────────────┤
│  • VS Code con Remote SSH                                        │
│  • Navegador accediendo a http://10.5.26.141:5173               │
│  • Navegador accediendo a http://10.5.26.141:8000               │
└─────────────────────────────────────────────────────────────────┘
```

## Flujo de Actualización desde GitHub

### Opción 1: Script Automático (Recomendado)

```bash
cd /home/jair/proyectos/credinet-v2
./scripts/update-from-github.sh main
```

Este script:
1. ✅ Hace `git fetch` y `git pull` de la rama especificada
2. ✅ Detecta si hay cambios en backend o frontend
3. ✅ Reinicia solo lo necesario
4. ✅ Hace rebuild del frontend si cambió

### Opción 2: Manual

```bash
# 1. Actualizar código
cd /home/jair/proyectos/credinet-v2
git fetch origin
git pull origin main

# 2. Si hay cambios en BACKEND:
docker compose restart backend

# 3. Si hay cambios en FRONTEND:
./scripts/rebuild-frontend.sh
```

## Comportamiento por Tipo de Cambio

| Componente | Tipo de Cambio | Acción Necesaria |
|------------|----------------|------------------|
| Backend | Cualquier cambio en `backend/` | `docker compose restart backend` |
| Frontend | Cambios en archivos existentes | `./scripts/rebuild-frontend.sh` |
| Frontend | Nuevos archivos/componentes | `./scripts/rebuild-frontend.sh` |
| Frontend | Nuevas dependencias (package.json) | `docker compose up -d --build frontend` |
| Base de datos | Migraciones SQL | Ejecutar manualmente |

## Scripts Disponibles

### `./scripts/update-from-github.sh [rama]`
Actualización completa desde GitHub. Detecta y aplica cambios automáticamente.

```bash
# Actualizar desde main (por defecto)
./scripts/update-from-github.sh

# Actualizar desde develop
./scripts/update-from-github.sh develop
```

### `./scripts/rebuild-frontend.sh`
Reconstruye el frontend sin recrear el contenedor.

```bash
./scripts/rebuild-frontend.sh
```

## ¿Por qué esta arquitectura?

### Problema Original
- Vite en modo desarrollo usa WebSocket para Hot Module Reload (HMR)
- WebSocket no funciona bien a través de ZeroTier/VPN
- Resultado: Página en blanco al acceder remotamente

### Solución Implementada
- **Frontend**: Modo producción con `serve` (servidor estático)
- **Código fuente**: Montado como volumen para permitir rebuilds
- **Rebuild**: Script que ejecuta `npm run build` dentro del contenedor

### Ventajas
1. ✅ Funciona perfectamente con acceso remoto (ZeroTier)
2. ✅ No requiere recrear contenedor para ver cambios
3. ✅ Build rápido (~400ms)
4. ✅ Backend sigue con hot-reload automático
5. ✅ Scripts automatizados para actualización

## Troubleshooting

### La página sigue en blanco
```bash
# 1. Verificar que serve está corriendo
docker compose exec frontend ps aux
# Debe mostrar: node /usr/local/bin/serve

# 2. Verificar que dist tiene archivos
docker compose exec frontend ls -la /app/dist/

# 3. Hacer hard refresh en navegador
# Ctrl+Shift+R o ventana incógnito
```

### Error al hacer rebuild
```bash
# Si falla el build, verificar logs
docker compose logs frontend --tail 50

# Si hay problemas de dependencias
docker compose up -d --build frontend
```

### Backend no responde después de pull
```bash
# Verificar logs
docker compose logs backend --tail 50

# Reiniciar manualmente
docker compose restart backend
```

---

**Creado:** 2026-01-22  
**Versión:** 1.0  
**Compatibilidad:** Acceso remoto via ZeroTier VPN
