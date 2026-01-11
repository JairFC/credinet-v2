# Estado del Proyecto Credinet V2 - 2026-01-11

## Resumen Ejecutivo

Sistema de gestión de préstamos cooperativos funcionando en producción.

### Correcciones Aplicadas en esta Sesión

1. **Trigger `generate_payment_schedule()` corregido** - Restaurada la lógica original de búsqueda de períodos por rango de fechas
2. **102 pagos reasignados** - Préstamos 93, 94, 97, 98, 99, 100, 101 ahora tienen períodos correctos
3. **cut_periods extendidos** - De 72 a 120 períodos (hasta 2029-01-07)
4. **Organización de archivos** - Limpieza del directorio raíz

---

## Estructura del Proyecto

```
credinet-v2/
├── backend/              # API FastAPI (Python 3.11)
│   ├── app/              # Código de la aplicación
│   │   ├── api/          # Rutas y endpoints
│   │   ├── models/       # Modelos SQLAlchemy
│   │   ├── services/     # Lógica de negocio
│   │   └── core/         # Configuración, auth, etc.
│   └── tests/            # Tests unitarios
│
├── frontend-mvp/         # Frontend React (producción)
│   └── src/
│       ├── features/     # Módulos por funcionalidad
│       ├── components/   # Componentes compartidos
│       └── api/          # Servicios de API
│
├── frontend/             # Frontend legacy (no usar)
│
├── db/                   # Base de datos
│   ├── v2.0/             # Scripts de inicialización
│   │   ├── init.sql      # Script principal con triggers
│   │   └── migrations/   # Migraciones incrementales
│   ├── backups/          # Backups de la BD
│   └── backup_definitivo/
│
├── docs/                 # Documentación
│   ├── 00_START_HERE/    # ← EMPEZAR AQUÍ
│   ├── auditorias_correcciones/  # Auditorías y correcciones
│   ├── business_logic/   # Lógica de negocio
│   ├── db/               # Documentación de BD
│   ├── guides/           # Guías de desarrollo
│   └── _deprecated/      # Documentación obsoleta
│
├── scripts/              # Scripts de utilidad
│   ├── backup/           # Scripts de backup
│   ├── database/         # Scripts de BD
│   ├── legacy/           # Scripts de migración legacy
│   └── testing/          # Scripts de pruebas
│
├── logs/                 # Logs del sistema
│
├── docker-compose.yml    # Configuración Docker
├── README.md             # Readme principal
└── CHANGELOG.md          # Historial de cambios
```

---

## Estado de los Servicios

| Servicio | Puerto | Estado |
|----------|--------|--------|
| PostgreSQL | 5432 | ✅ Activo |
| Backend API | 8000 | ✅ Activo |
| Frontend MVP | 3000 | ✅ Activo |

---

## Comandos Importantes

```bash
# Levantar sistema
docker compose up -d

# Ver logs
docker compose logs -f backend

# Acceder a PostgreSQL
docker compose exec postgres psql -U credinet_user -d credinet_db

# Reiniciar backend
docker compose restart backend
```

---

## Funciones Críticas de BD

### `generate_payment_schedule()`
Trigger que se ejecuta al aprobar un préstamo. Genera la tabla de amortización y asigna períodos.

**Ubicación**: `db/v2.0/init.sql`

**Lógica de asignación de período** (CORRECTA):
```sql
SELECT id INTO v_period_id FROM cut_periods
WHERE period_start_date <= v_amortization_row.fecha_pago
  AND period_end_date >= v_amortization_row.fecha_pago
ORDER BY period_start_date DESC LIMIT 1;
```

---

## Problemas Conocidos Resueltos

### 1. N/A en Períodos de Préstamos (2026-01-11)
- **Causa**: Cambio en la lógica de búsqueda de cut_period_id
- **Solución**: Restaurar búsqueda por rango de fechas
- **Documentación**: `docs/auditorias_correcciones/CORRECCION_PRESTAMOS_2026-01-11.md`

### 2. Cálculo de Associate Payment en Preview
- **Causa**: Frontend calculaba manualmente en vez de usar valor del backend
- **Solución**: Usar `loan.associate_payment` del backend
- **Archivo**: `frontend-mvp/src/features/loans/components/LoanSummaryDisplay/`

---

## Migraciones Aplicadas

| ID | Archivo | Descripción | Fecha |
|----|---------|-------------|-------|
| 28 | migration_028_extend_cut_periods_to_2028.sql | Extiende períodos hasta 2029 | 2026-01-11 |

---

## Próximos Pasos

1. [ ] Revisar sistema de backups automáticos
2. [ ] Documentar proceso de migración a nuevo host
3. [ ] Revisar y deprecar frontend legacy
4. [ ] Crear script de verificación de integridad de datos

---

## Contacto

Para dudas sobre el sistema, revisar:
1. `docs/00_START_HERE/` - Documentación inicial
2. `docs/business_logic/` - Lógica de negocio
3. `docs/guides/` - Guías de desarrollo
