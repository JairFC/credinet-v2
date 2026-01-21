# ESTRATEGIA DE ENTORNOS Y WORKFLOW - Credinet v2.0
**Fecha de actualización**: 2026-01-19

## 🏗️ ARQUITECTURA DE ENTORNOS

```
┌─────────────────────────────────────────────────────────────────────┐
│                        REPOSITORIO GITHUB                           │
│                 github.com/JairFC/credinet-v2                       │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  main ◄─────────────────── (releases estables)                     │
│    │                                                                │
│    └── develop ◄─────────── (integración)                          │
│           │                                                         │
│           ├── feature/week-XX-xxx ◄── (features semanales)         │
│           │                                                         │
│           └── hotfix/xxx ◄────────── (correcciones urgentes)       │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

## 🖥️ SERVIDORES

### Desarrollo (192.168.98.98)
- **Red**: LAN local (192.168.96.0/22)
- **Rama por defecto**: `develop` o `feature/xxx`
- **Propósito**: 
  - Desarrollo de nuevas features
  - Testing con datos de prueba
  - Experimentos sin miedo a romper
- **Datos**: 40 usuarios, 76 préstamos, 1044 pagos (datos de prueba)
- **Acceso VSCode**: SSH directo

### Producción (10.5.26.141)
- **Red**: ZeroTier VPN
- **Rama por defecto**: `develop` (próximamente `main`)
- **Propósito**:
  - Sistema en producción real
  - Datos de clientes reales
  - Estabilidad máxima
- **Datos**: Actualmente limpio (post factory-reset)
- **Acceso VSCode**: SSH vía ZeroTier

## 🔄 WORKFLOW DE DESARROLLO

### 1. Nueva Feature
```bash
# En DESARROLLO (192.168.98.98)
git checkout develop
git pull origin develop
git checkout -b feature/week-XX-descripcion
# ... desarrollar ...
git add . && git commit -m "feat: descripción"
git push origin feature/week-XX-descripcion
```

### 2. Integrar a Develop
```bash
# En DESARROLLO
git checkout develop
git merge feature/week-XX-descripcion
git push origin develop
```

### 3. Desplegar en Producción
```bash
# En PRODUCCIÓN (10.5.26.141)
git fetch origin
git checkout develop
git pull origin develop
docker compose up -d --build
```

### 4. Crear Release (cuando esté estable)
```bash
# En DESARROLLO o PRODUCCIÓN
git checkout main
git merge develop
git tag -a v2.1.0 -m "Release 2.1.0 - descripción"
git push origin main --tags
```

## 🔧 CORS Y CONFIGURACIÓN DE RED

### Backend (.env raíz)
```env
CORS_ORIGINS=http://localhost:5173,http://localhost:5174,http://localhost:3000,http://192.168.98.98:5173,http://192.168.98.98:5174,http://192.168.98.98:8000,http://10.5.26.141:5173,http://10.5.26.141:8000,http://172.28.0.1:5174
```

### Frontend (frontend-mvp/.env)
- **Desarrollo**: `VITE_API_URL=http://192.168.98.98:8000`
- **Producción**: `VITE_API_URL=http://10.5.26.141:8000`

### ⚠️ IMPORTANTE sobre ZeroTier
El frontend se compila estáticamente. Si cambias la IP, debes **reconstruir el contenedor**:
```bash
docker compose down frontend
docker rmi credinet-v2-frontend:latest -f
VITE_API_URL=http://IP_NUEVA:8000 docker compose build --no-cache frontend
docker compose up -d frontend
```

## 📋 RESUMEN DE RAMAS ACTUALES

| Rama | Estado | Descripción |
|------|--------|-------------|
| `main` | Estable | Versión de producción (pendiente sync) |
| `develop` | Activa | Integración, sincronizada con main |
| `feature/week-03-fixes-convenios-renovaciones` | Nueva | Features de esta semana |
| `feature/fix-rate-profiles-flexibility` | Completada | Ya mergeada a develop |

## 🐛 BUGS PENDIENTES IDENTIFICADOS

### 1. Sistema de Renovaciones
- Falta validación estricta de monto mínimo en frontend
- Archivo: `frontend-mvp/src/features/loans/pages/LoanCreatePage.jsx`

### 2. Sistema de Convenios
- El filtro funciona pero no hay asociados en producción
- Necesita datos para probar
- Archivo: `frontend-mvp/src/features/agreements/pages/NuevoConvenioPage.jsx`

## 📊 PRÓXIMOS PASOS

1. [ ] Crear datos de prueba mínimos en producción
2. [ ] Verificar flujo de renovaciones con datos reales
3. [ ] Probar sistema de convenios
4. [ ] Esperar a fecha de corte (8 o 23) para verificar scheduler
5. [ ] Importar cartera legacy si decides

---
*Documento generado automáticamente - Credinet v2.0*
