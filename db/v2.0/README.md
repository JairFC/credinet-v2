# 🗄️ BASE DE DATOS CREDINET v2.0

> **Arquitectura**: Single Source of Truth (Modular)  
> **PostgreSQL**: 15+  
> **Versión**: 2.0.1 (Sprint 6 - Rate Profiles)  
> **Fecha**: 2025-11-05  

---

## ⚠️ PRINCIPIO FUNDAMENTAL: SINGLE SOURCE OF TRUTH

```
┌─────────────────────────────────────────────────────────┐
│  ✅ ÚNICA FUENTE DE VERDAD: /db/v2.0/modules/*.sql     │
│  ✅ Siempre actualizado y sincronizado con BD           │
│  ✅ Genera init.sql (NO EDITAR DIRECTAMENTE)            │
│  ✅ IA debe analizar SOLO estos 10 archivos             │
└─────────────────────────────────────────────────────────┘
                           │
                           ├─ init.sql (GENERADO)
                           └─ docker-compose.yml → PostgreSQL
                           
┌─────────────────────────────────────────────────────────┐
│  📚 HISTÓRICO: /db/v2.0/archive/migrations/             │
│  📚 Solo para auditoría y rollback                      │
│  📚 NO ejecutar directamente (ya aplicados en modules/) │
└─────────────────────────────────────────────────────────┘
```

**⚠️ IMPORTANTE**:
- **NO editar** `init.sql` directamente → será sobrescrito
- **NO ejecutar** migraciones en `/archive/` → ya consolidadas
- **SÍ editar** módulos en `/modules/` → fuente de verdad
- **SÍ regenerar** `init.sql` después de cambios → `./generate_monolithic.sh`

---

## 📋 ÍNDICE

1. [Workflow de Cambios](#-workflow-de-cambios)
2. [Estructura de Archivos](#-estructura-de-archivos)
3. [Módulos Principales](#-módulos-principales)
4. [Uso y Deploy](#-uso-y-deploy)
5. [Histórico de Migraciones](#-histórico-de-migraciones)
6. [Mantenimiento](#-mantenimiento)

---

## 🔄 WORKFLOW DE CAMBIOS

### Para Desarrolladores

```bash
# 1. Editar módulo correspondiente
vim db/v2.0/modules/02_core_tables.sql

# 2. Regenerar monolítico
cd db/v2.0
./generate_monolithic.sh

# 3. Aplicar en BD (desarrollo)
docker exec credinet-postgres psql -U credinet_user -d credinet_db < init.sql

# 4. Validar cambios
docker exec credinet-postgres psql -U credinet_user -d credinet_db -c "\d loans"

# 5. Commit (incluir módulo + init.sql generado)
git add modules/02_core_tables.sql init.sql
git commit -m "feat: add new field to loans table"
```

### Para IA (Análisis de Contexto)

**Prioridad de análisis**:
1. **HIGH**: `/db/v2.0/modules/*.sql` (10 archivos, 165K) ← ÚNICA VERDAD
2. **MEDIUM**: `/db/v2.0/init.sql` (generado, solo referencia)
3. **LOW**: `/db/v2.0/archive/**` (histórico, NO sugerir ediciones)
4. **DOCS**: `/docs/ARQUITECTURA_DOBLE_CALENDARIO.md`, `/docs/DASHBOARD_VALIDACION_SPRINT6.md`

---

## 🎯 VISIÓN GENERAL

La base de datos de Credinet v2.0 implementa una **arquitectura modular con consolidación automática**:

- ✅ **Single Source of Truth**: Módulos son la única verdad
- ✅ **Desarrollo ágil**: Trabajar en módulos independientes
- ✅ **Deploy rápido**: Versión monolítica auto-generada
- ✅ **Mantenibilidad**: Cambios quirúrgicos sin afectar todo
- ✅ **Testing**: Probar módulos individuales
- ✅ **Escalabilidad**: Agregar módulos sin romper existentes
- ✅ **Trazabilidad**: Histórico completo en `/archive/`

### Estadísticas v2.0.1 (Sprint 6)
- **Tablas**: 38 (13 catálogos + 25 transaccionales)
- **Funciones**: 23 (lógica de negocio compleja)
- **Triggers**: 34 (21 updated_at + 13 lógica de negocio)
- **Vistas**: 12 (reporting y análisis)
- **Índices**: 80 (optimización de consultas, +8 Sprint 6)
- **Líneas de código**: 4,164 líneas (+158 Sprint 6)
- **Tamaño**: 185K (init.sql, +5K Sprint 6)

---

## 📂 ESTRUCTURA DE ARCHIVOS

```
db/v2.0/
├── init.sql                          # 🤖 GENERADO (NO EDITAR)
├── generate_monolithic.sh            # Script de generación
├── README.md                         # Este archivo
│
├── modules/                          # 🎯 ÚNICA FUENTE DE VERDAD (EDITAR AQUÍ)
│   ├── 01_catalog_tables.sql         # Catálogos y estados (13 tablas, 11K)
│   ├── 02_core_tables.sql            # Tablas principales (loans, payments, 21K)
│   ├── 03_business_tables.sql        # Lógica de negocio (agreements, 17K)
│   ├── 04_audit_tables.sql           # Auditoría y tracking (12K)
│   ├── 05_functions_base.sql         # Funciones base: cálculos (19K)
│   ├── 06_functions_business.sql     # Funciones negocio: triggers (29K)
│   ├── 07_triggers.sql               # Triggers updated_at + audit (15K)
│   ├── 08_views.sql                  # Vistas de reporting (22K)
│   ├── 09_seeds.sql                  # Datos iniciales (catálogos, 19K)
│   ├── 10_rate_profiles.sql          # Sistema de tasas (Sprint 6, 23K)
│   └── migrations/                   # VACÍA (consolidado en modules/)
│
├── archive/                          # 📚 HISTÓRICO (SOLO AUDITORÍA)
│   ├── migrations/
│   │   └── v2.0.0_to_v2.0.1/         # Sprint 6: Rate Profiles
│   │       ├── CHANGELOG.md          # Resumen consolidado
│   │       ├── 005_add_calculated_fields_to_loans.sql (16K)
│   │       ├── 006_add_breakdown_fields_to_payments.sql (22K)
│   │       └── 007_fix_generate_payment_schedule_trigger.sql (16K)
│   └── schemas/
│       └── (snapshots futuros)       # Backups pre-migración
│
└── docs/                             # 📖 DOCUMENTACIÓN
    └── (ver /docs/ en raíz del proyecto)
```

**Tamaños**:
- **Módulos activos**: 165K (10 archivos)
- **init.sql generado**: 185K
- **Migraciones archivadas**: 54K (histórico Sprint 6)
- **Total**: ~400K

---

## 📚 HISTÓRICO DE MIGRACIONES

### ¿Qué hay en `/archive/migrations/`?

Esta carpeta contiene migraciones **YA APLICADAS y CONSOLIDADAS** en los módulos principales. **NO ejecutar directamente**.

```
/archive/migrations/v2.0.0_to_v2.0.1/  ← Sprint 6: Rate Profiles
├── CHANGELOG.md                       ← Resumen detallado de cambios
├── 005_add_calculated_fields_to_loans.sql (16K)
├── 006_add_breakdown_fields_to_payments.sql (22K)
└── 007_fix_generate_payment_schedule_trigger.sql (16K)
```

**Propósito del archivo**:
- 📖 **Auditoría**: Histórico completo de decisiones de diseño
- 🔙 **Rollback**: Referencia para revertir cambios si necesario
- 👥 **Onboarding**: Nuevos devs entienden evolución del schema
- 🔍 **Compliance**: Trazabilidad completa de cambios

**⚠️ Estado actual**:
- ✅ Cambios **YA consolidados** en `/modules/02_core_tables.sql` y `/modules/06_functions_business.sql`
- ✅ `init.sql` **YA regenerado** con cambios aplicados
- ✅ **Validado** en producción (préstamo id=6 exitoso)
- ❌ **NO ejecutar** estas migraciones → causaría errores de "column already exists"

**Referencia rápida Sprint 6**:
```sql
-- Campos agregados a loans (6):
biweekly_payment, total_payment, total_interest, total_commission, 
commission_per_payment, associate_payment

-- Campos agregados a payments (7):
payment_number, expected_amount, interest_amount, principal_amount,
commission_amount, associate_payment, balance_remaining

-- Función reescrita:
generate_payment_schedule() - 138→251 líneas
- Bug corregido: Ahora usa biweekly_payment (con interés) vs amount/term (sin interés)
- Integración con generate_amortization_schedule()
- Validación matemática automática (±$1.00)
```

Ver documentación completa: `/archive/migrations/v2.0.0_to_v2.0.1/CHANGELOG.md`
│
├── init.sql                          # 🎯 FUENTE DE VERDAD (Producción + Docker)
├── generate_monolithic.sh            # Script para regenerar init.sql desde modules/
├── validate_syntax.sh                # Validador de sintaxis SQL
└── README.md                         # Este archivo
```

**Filosofía:**
- **`modules/`**: Para desarrollo y mantenimiento modular
- **`init.sql`**: Archivo consolidado único para producción/Docker (146K, 3,301 líneas)
- Sin archivos duplicados ni patches externos

---

## 🔄 MIGRACIONES INTEGRADAS

Esta versión integra **6 migraciones críticas** (v0.7 → v2.0):

### Migración 07: Sistema de Crédito del Asociado
**Propósito**: Rastrear crédito disponible en tiempo real

**Componentes**:
- ✅ 4 columnas en `associate_profiles`: `credit_used`, `credit_limit`, `credit_available`, `credit_last_updated`
- ✅ 5 triggers automáticos: Al aprobar préstamo, registrar pago, liquidar deuda, cambiar nivel
- ✅ 1 función: `check_associate_credit_available()`
- ✅ 1 vista: `v_associate_credit_summary`

**Fórmula**:
```
credit_available = credit_limit - credit_used - debt_balance
```

---

### Migración 08: Lógica de Cierre de Corte
**Propósito**: Al cerrar período, TODOS los pagos se marcan como pagados

**Componentes**:
- ✅ 1 estado nuevo: `PAID_NOT_REPORTED` (ID 10)
- ✅ 1 función: `close_period_and_accumulate_debt()` (versión v3)
- ✅ 1 vista: `v_period_closure_summary`

**Lógica**:
- Pagos reportados → `PAID`
- Pagos NO reportados → `PAID_NOT_REPORTED`
- Clientes morosos → `PAID_BY_ASSOCIATE`

---

### Migración 09: Sistema de Morosidad
**Propósito**: Rastrear clientes morosos con evidencia y breakdown de deuda

**Componentes**:
- ✅ 1 estado nuevo: `PAID_BY_ASSOCIATE` (ID 9)
- ✅ 2 tablas: `associate_debt_breakdown`, `defaulted_client_reports`
- ✅ 3 funciones: `report_defaulted_client()`, `approve_defaulted_client_report()`
- ✅ 1 vista: `v_associate_debt_detailed`

**Tipos de deuda**:
- `UNREPORTED_PAYMENT`: Pagos no reportados al cierre
- `DEFAULTED_CLIENT`: Cliente moroso reportado
- `LATE_FEE`: Mora del 30%
- `OTHER`: Otros tipos

---

### Migración 10: Sistema de Mora
**Propósito**: Aplicar mora del 30% sobre comisión si NO reportó ningún pago

**Componentes**:
- ✅ 2 columnas en `associate_payment_statements`: `late_fee_amount`, `late_fee_applied`
- ✅ 1 función: `calculate_late_fee_for_statement()`
- ✅ 1 vista: `v_associate_late_fees`

**Regla**:
```
IF payments_reported = 0 AND total_payments > 0 THEN
    late_fee = total_commission_owed × 30%
END IF
```

---

### Migración 11: Estados de Pago Consolidados
**Propósito**: 12 estados claramente definidos con tracking completo

**Componentes**:
- ✅ 12 estados consolidados (6 pendientes, 2 reales, 4 ficticios)
- ✅ 3 columnas en `payments`: `marked_by`, `marked_at`, `marking_notes`
- ✅ 1 columna en `payment_statuses`: `is_real_payment`
- ✅ 2 funciones: `admin_mark_payment_status()`, `get_payment_status_history()`
- ✅ 2 vistas: `v_payments_by_status_detailed`, `v_payments_absorbed_by_associate`

**Estados**:
| ID | Estado | Tipo | Descripción |
|----|--------|------|-------------|
| 1-7 | PENDING | Pendiente | Programado, vence hoy, parcial, vencido |
| 3,8 | PAID | Real 💵 | Dinero realmente cobrado |
| 9-12 | FICTITIOUS | Ficticio ⚠️ | Absorbido, no reportado, perdonado, cancelado |

---

### Migración 12: Historial de Cambios (NUEVA ⭐)
**Propósito**: Auditoría completa de cambios de estado para compliance

**Componentes**:
- ✅ 1 tabla: `payment_status_history` (registro automático)
- ✅ 1 trigger: `trigger_log_payment_status_change` (AFTER UPDATE)
- ✅ 4 funciones:
  - `log_payment_status_change()`: Registro automático
  - `get_payment_history()`: Timeline completo de un pago
  - `detect_suspicious_payment_changes()`: Detección de patrones anómalos
  - `revert_last_payment_change()`: Reversión de emergencia
- ✅ 3 vistas:
  - `v_payment_changes_summary`: Estadísticas generales
  - `v_recent_payment_changes`: Últimas 24 horas
  - `v_payments_multiple_changes`: Pagos con 3+ cambios

**Ventajas**:
- 🔍 Auditoría completa: Quién cambió qué, cuándo y por qué
- 🚨 Detección de fraude: Patrones anómalos automáticos
- 📊 Análisis forense: Reconstruir timeline completo
- ✅ Compliance: Cumplir regulaciones de trazabilidad

---

## 🚀 USO

### Opción 1: Desarrollo (Modular)

**Recomendado para**:
- Desarrollo local
- Debugging
- Testing de módulos individuales

```bash
# Inicializar BD completa
psql -U credinet -d credinet -f db/v2.0/init.sql

# Probar solo un módulo
psql -U credinet -d credinet -f db/v2.0/modules/07_triggers.sql

# Ver progreso en tiempo real
psql -U credinet -d credinet -f db/v2.0/init.sql 2>&1 | tee db_init.log
```

**Salida esperada**:
```
🚀 Iniciando creación de base de datos CrediNet v2.0...
📋 [1/9] Creando tablas de catálogo...
💾 [2/9] Creando tablas core...
🏢 [3/9] Creando tablas de negocio...
🔍 [4/9] Creando tablas de auditoría...
⚙️  [5/9] Creando funciones base...
💼 [6/9] Creando funciones de negocio...
⚡ [7/9] Creando triggers...
👁️  [8/9] Creando vistas...
🌱 [9/9] Insertando datos iniciales...
✅ Base de datos CrediNet v2.0 creada exitosamente!
📊 Estadísticas: 29 tablas, 22 funciones, 28 triggers, 9 vistas
```

---

### Opción 2: Producción (Monolítico)

**Recomendado para**:
- Deploy a producción
- Docker containers
- CI/CD pipelines

```bash
# Inicializar BD completa (más rápido)
psql -U credinet -d credinet -f db/v2.0/init_monolithic.sql
```

---

### Opción 3: Docker (Automático)

**docker-compose.yml**:
```yaml
services:
  db:
    image: postgres:15
    volumes:
      - ./db/v2.0/init_monolithic.sql:/docker-entrypoint-initdb.d/init.sql
    environment:
      POSTGRES_DB: credinet
      POSTGRES_USER: credinet
      POSTGRES_PASSWORD: ${DB_PASSWORD}
```

```bash
# Levantar BD desde cero
docker-compose up -d db

# Verificar logs
docker-compose logs db
```

---

## 📦 MÓDULOS DETALLADOS

### 01_catalog_tables.sql (Catálogos)
**Contenido**:
- `roles`: 5 roles (desarrollador, admin, aux_admin, asociado, cliente)
- `loan_statuses`: 10 estados de préstamo
- `payment_statuses`: 12 estados de pago (CONSOLIDADOS)
- `contract_statuses`: 6 estados de contrato
- `cut_period_statuses`: 3 estados de período
- `associate_levels`: 5 niveles (Bronce, Plata, Oro, Platino, Diamante)
- Otros catálogos...

**Líneas**: ~400

---

### 02_core_tables.sql (Tablas Principales)
**Contenido**:
- `users`: Usuarios del sistema
- `user_roles`: Relación usuario-rol (N:M)
- `loans`: Préstamos
- `payments`: Pagos de clientes
- `contracts`: Contratos digitales
- `cut_periods`: Períodos de corte quincenales

**Líneas**: ~600

---

### 03_business_tables.sql (Lógica de Negocio)
**Contenido**:
- `associate_profiles`: Perfiles de asociados (con crédito)
- `associate_payment_statements`: Estados de cuenta
- `associate_accumulated_balances`: Balances acumulados
- `agreements`: Convenios de pago
- `agreement_items`: Ítems de convenio
- `agreement_payments`: Pagos de convenio
- `loan_renewals`: Registro de renovaciones

**Líneas**: ~500

---

### 04_audit_tables.sql (Auditoría) ⭐ NUEVO
**Contenido**:
- `payment_status_history`: Historial completo de cambios
- `associate_debt_breakdown`: Desglose de deuda por tipo
- `defaulted_client_reports`: Reportes de morosidad

**Líneas**: ~200

---

### 05_functions_base.sql (Funciones Base)
**Contenido** (Nivel 1 - Sin dependencias):
- `calculate_first_payment_date()`: Calendario quincenal
- `calculate_loan_remaining_balance()`: Saldo pendiente
- `check_associate_credit_available()`: Validar crédito
- `calculate_late_fee_for_statement()`: Calcular mora
- `admin_mark_payment_status()`: Marcar pago manualmente
- `log_payment_status_change()`: Trigger de historial
- `get_payment_history()`: Timeline de pago
- `detect_suspicious_payment_changes()`: Detectar anomalías
- `revert_last_payment_change()`: Reversión de emergencia

**Líneas**: ~800

---

### 06_functions_business.sql (Funciones de Negocio)
**Contenido** (Nivel 2-3 - Con dependencias):
- `report_defaulted_client()`: Reportar cliente moroso
- `approve_defaulted_client_report()`: Aprobar reporte
- `renew_loan()`: Renovar préstamo
- `close_period_and_accumulate_debt()`: Cerrar período (v3)

**Líneas**: ~600

---

### 07_triggers.sql (Triggers)
**Contenido** (28 triggers):
- `trigger_log_payment_status_change`: Historial automático
- `trigger_update_associate_credit_on_loan_approval`: Crédito al aprobar
- `trigger_update_associate_credit_on_payment`: Crédito al pagar
- `trigger_update_associate_credit_on_debt_payment`: Crédito al liquidar
- `trigger_update_associate_credit_on_level_change`: Crédito al cambiar nivel
- `trigger_generate_payment_schedule`: Generar cronograma
- Triggers de timestamps (updated_at automático)
- Validaciones automáticas

**Líneas**: ~600

---

### 08_views.sql (Vistas)
**Contenido** (9 vistas):
- `v_associate_credit_summary`: Resumen de crédito
- `v_period_closure_summary`: Resumen de cierre
- `v_associate_debt_detailed`: Deuda detallada
- `v_associate_late_fees`: Moras aplicadas
- `v_payments_by_status_detailed`: Pagos por estado
- `v_payments_absorbed_by_associate`: Pagos absorbidos
- `v_payment_changes_summary`: Estadísticas de cambios
- `v_recent_payment_changes`: Cambios recientes (24h)
- `v_payments_multiple_changes`: Pagos con 3+ cambios

**Líneas**: ~400

---

### 09_seeds.sql (Datos Iniciales)
**Contenido**:
- Roles (5)
- Estados (loan, payment, contract, period)
- Niveles de asociado (5)
- Métodos de pago
- Tipos de convenio
- Usuario desarrollador inicial
- Períodos de corte (2025-2026)

**Líneas**: ~300

---

## 🔧 MANTENIMIENTO

### Regenerar Monolítico

Después de modificar módulos, regenerar versión consolidada:

```bash
# Método 1: Concatenación simple
cat db/v2.0/modules/*.sql > db/v2.0/init_monolithic.sql

# Método 2: Con header personalizado
echo "-- CREDINET DB v2.0 - Generado: $(date)" > db/v2.0/init_monolithic.sql
cat db/v2.0/modules/*.sql >> db/v2.0/init_monolithic.sql
```

### Validar Sintaxis

```bash
# Validar módulo individual
psql -U credinet -d credinet_test --set ON_ERROR_STOP=on -f db/v2.0/modules/05_functions_base.sql

# Validar todos los módulos
for file in db/v2.0/modules/*.sql; do
    echo "Validando $file..."
    psql -U credinet -d credinet_test --set ON_ERROR_STOP=on -f "$file" || exit 1
done
```

### Backup y Restore

```bash
# Backup completo
pg_dump -U credinet -d credinet -F c -b -v -f "backup_$(date +%Y%m%d_%H%M%S).backup"

# Restore
pg_restore -U credinet -d credinet -v "backup_20251030_120000.backup"
```

---

## 📚 DOCUMENTACIÓN ADICIONAL

- **Lógica de Negocio**: `docs/business/`
- **Arquitectura**: `docs/architecture/`
- **Guías**: `docs/guides/`
- **Migraciones Aplicadas**: `db/migrations/applied/`

---

## 🐛 TROUBLESHOOTING

### Error: "relation already exists"

**Causa**: BD ya tiene tablas previas

**Solución**:
```bash
# Limpiar BD
psql -U credinet -d credinet -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"

# Re-inicializar
psql -U credinet -d credinet -f db/v2.0/init.sql
```

### Error en Módulo Específico

**Causa**: Dependencia no satisfecha

**Solución**:
```bash
# Ejecutar módulos previos primero
psql -U credinet -d credinet -f db/v2.0/modules/01_catalog_tables.sql
psql -U credinet -d credinet -f db/v2.0/modules/02_core_tables.sql
# ... hasta el módulo que falla
```

### Performance Lenta

**Causa**: Falta de índices o tablas sin VACUUM

**Solución**:
```bash
# Analizar estadísticas
psql -U credinet -d credinet -c "VACUUM ANALYZE;"

# Ver queries lentas
psql -U credinet -d credinet -c "SELECT * FROM pg_stat_statements ORDER BY total_exec_time DESC LIMIT 10;"
```

---

## 📞 SOPORTE

**DBA Team**: [Email]  
**Issues**: [GitHub Issues]  
**Documentación**: `db/v2.0/README.md` (este archivo)

---

**Versión**: 2.0.0  
**Última actualización**: 2025-10-30  
**Mantenedores**: [Tu Equipo]
