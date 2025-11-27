# 🗺️ Mapa Rápido de Base de Datos - Para IA y Desarrolladores

**Versión**: v2.0.1 (Sprint 6)  
**Propósito**: Localizar rápidamente cualquier elemento del schema

---

## 📍 REGLA DE ORO

```
¿Necesitas editar algo? → Busca en /modules/*.sql
¿Solo consultar? → Puedes usar /init.sql (generado)
¿Histórico? → Revisa /archive/migrations/
```

---

## 🗂️ Tablas Principales

### Core Business

| Tabla | Ubicación | Líneas | Propósito |
|-------|-----------|--------|-----------|
| `users` | `02_core_tables.sql` | 20-85 | Usuarios del sistema |
| `loans` | `02_core_tables.sql` | 150-280 | Préstamos (CON rate_profiles Sprint 6) |
| `payments` | `02_core_tables.sql` | 281-410 | Pagos (CON desglose Sprint 6) |
| `contracts` | `02_core_tables.sql` | 420-500 | Contratos digitales |
| `cut_periods` | `02_core_tables.sql` | 510-580 | Períodos administrativos (quincenales) |

### Associates & Agreements

| Tabla | Ubicación | Líneas | Propósito |
|-------|-----------|--------|-----------|
| `associate_profiles` | `03_business_tables.sql` | 10-120 | Socios inversionistas |
| `agreements` | `03_business_tables.sql` | 130-210 | Acuerdos de comisión |
| `associate_payment_statements` | `03_business_tables.sql` | 220-300 | Estados de cuenta quincenales |
| `associate_accumulated_balances` | `03_business_tables.sql` | 310-380 | Saldo acumulado por socio |
| `associate_debt_breakdown` | `03_business_tables.sql` | 390-460 | Detalle de deudas |

### Rate Profiles (Sprint 6) ⭐

| Tabla | Ubicación | Líneas | Propósito |
|-------|-----------|--------|-----------|
| `rate_profiles` | `10_rate_profiles.sql` | 1-80 | Perfiles de tasas (standard, vip, premium) |
| `rate_profile_details` | `10_rate_profiles.sql` | 90-150 | Detalle por término (6-24 quincenas) |

### Catálogos

| Tabla | Ubicación | Líneas | Propósito |
|-------|-----------|--------|-----------|
| `roles` | `01_catalog_tables.sql` | 20-40 | Roles del sistema |
| `loan_statuses` | `01_catalog_tables.sql` | 50-80 | Estados de préstamos |
| `payment_statuses` | `01_catalog_tables.sql` | 90-140 | Estados de pagos (12 estados) |
| `agreement_statuses` | `01_catalog_tables.sql` | 150-180 | Estados de acuerdos |
| `cut_period_statuses` | `01_catalog_tables.sql` | 190-220 | Estados de períodos |

### Auditoría

| Tabla | Ubicación | Líneas | Propósito |
|-------|-----------|--------|-----------|
| `audit_log` | `04_audit_tables.sql` | 10-80 | Log general de cambios |
| Triggers audit | `07_triggers.sql` | (distribuidos) | 21 triggers `audit_*_trigger` |

---

## ⚙️ Funciones Clave

### Cálculos Financieros (BASE)

| Función | Ubicación | Líneas | Propósito | Retorna |
|---------|-----------|--------|-----------|---------|
| `calculate_loan_payment()` | `05_functions_base.sql` | 45-120 | Calcula pago quincenal y totales | 13 campos (JSON) |
| `generate_amortization_schedule()` | `05_functions_base.sql` | 121-250 | Genera tabla de amortización | TABLE (8 cols) |
| `calculate_first_payment_date()` | `05_functions_base.sql` | 260-320 | Oracle: fecha aprobación → primera fecha pago | DATE |

**Detalle `calculate_loan_payment()`**:
```sql
-- Entrada: amount, term_biweeks, profile_code
-- Salida (13 campos):
biweekly_payment           -- Pago quincenal del cliente
total_payment              -- Total a pagar (capital + interés + comisión)
total_interest             -- Total de intereses
total_commission           -- Total de comisión Credicuenta
commission_per_payment     -- Comisión por pago
associate_payment          -- Pago al socio por período
client_rate                -- Tasa anual cliente (ej: 85%)
associate_rate             -- Tasa anual socio (ej: 60%)
commission_rate            -- Tasa comisión (ej: 25%)
biweekly_client_rate       -- Tasa quincenal cliente (ej: 8.5%)
biweekly_associate_rate    -- Tasa quincenal socio (ej: 6.0%)
biweekly_commission_rate   -- Tasa quincenal comisión (ej: 2.5%)
term_biweeks               -- Plazo en quincenas
```

### Lógica de Negocio (BUSINESS)

| Función | Ubicación | Líneas | Propósito | Trigger |
|---------|-----------|--------|-----------|---------|
| `generate_payment_schedule()` | `06_functions_business.sql` | 1-251 | Genera 12-24 payments al aprobar préstamo | ✅ ON loans UPDATE |
| `check_associate_credit_available()` | `06_functions_business.sql` | 260-320 | Valida crédito disponible | ✅ BEFORE INSERT |
| `close_cut_period()` | `06_functions_business.sql` | 330-450 | Cierra período y genera estados de cuenta | Manual |
| `report_defaulted_client()` | `06_functions_business.sql` | 460-550 | Reporta cliente moroso a socio | Manual |

**⭐ Función crítica Sprint 6**: `generate_payment_schedule()`
- **Trigger**: Ejecuta automáticamente cuando `loans.status_id` cambia a `APPROVED`
- **Proceso**:
  1. Lee `loans.biweekly_payment` (pre-calculado por `calculate_loan_payment()`)
  2. Llama `generate_amortization_schedule()` para desglose completo
  3. Calcula primera fecha con `calculate_first_payment_date()` (oracle)
  4. Genera alternancia 15th ↔ último día (calendario dual)
  5. Inserta 16 campos por payment (payment_number, expected_amount, interest_amount, etc.)
  6. Valida: `SUM(expected_amount) ≈ loans.total_payment` (±$1.00)
- **Performance**: ~8.93ms para 12 payments
- **Bug corregido**: Ahora usa `biweekly_payment` (CON interés) vs `amount/term` (SIN interés)

### Vistas de Reporting

| Vista | Ubicación | Líneas | Propósito |
|-------|-----------|--------|-----------|
| `v_active_loans_summary` | `08_views.sql` | 1-40 | Préstamos activos con cálculos |
| `v_payments_by_status_detailed` | `08_views.sql` | 50-100 | Pagos por estado (12 estados) |
| `v_associate_credit_summary` | `08_views.sql` | 110-160 | Crédito disponible por socio |
| `v_associate_debt_detailed` | `08_views.sql` | 170-230 | Detalle de deudas por socio |
| `v_cut_period_summary` | `08_views.sql` | 240-290 | Resumen de períodos de corte |

---

## 🔧 Triggers

### Audit Triggers (21 automáticos)

Patrón: `audit_<table>_trigger AFTER INSERT/UPDATE/DELETE → audit_trigger_function()`

**Ubicación**: `07_triggers.sql` líneas 10-200 (distribuidos)

**Tablas auditadas**: loans, payments, contracts, agreements, associate_profiles, etc.

### Business Logic Triggers (13 específicos)

| Trigger | Tabla | Evento | Función | Propósito |
|---------|-------|--------|---------|-----------|
| `trigger_generate_payment_schedule` | `loans` | UPDATE | `generate_payment_schedule()` | Genera pagos al aprobar ⭐ |
| `trigger_update_credit_on_loan_approval` | `loans` | INSERT/UPDATE | `update_associate_credit()` | Actualiza crédito usado |
| `trigger_update_credit_on_payment` | `payments` | INSERT/UPDATE | `update_associate_credit()` | Actualiza crédito al pagar |
| `trigger_check_credit_before_loan` | `loans` | BEFORE INSERT | `check_associate_credit_available()` | Valida crédito |

**Ubicación**: `07_triggers.sql` líneas 210-450

### Updated_at Triggers (automáticos)

Patrón: `update_<table>_updated_at BEFORE UPDATE → update_updated_at_column()`

**Ubicación**: `07_triggers.sql` líneas 460-550

**Todas las tablas**: 35 triggers (uno por tabla)

---

## 📊 Datos Iniciales (Seeds)

| Tipo | Ubicación | Líneas | Registros |
|------|-----------|--------|-----------|
| Roles | `09_seeds.sql` | 10-30 | 5 (ADMIN, ASSOCIATE, CLIENT, etc.) |
| Loan Statuses | `09_seeds.sql` | 40-80 | 7 (PENDING, APPROVED, ACTIVE, etc.) |
| Payment Statuses | `09_seeds.sql` | 90-150 | 12 (PENDING, PAID, ABSORBED, etc.) |
| Agreement Statuses | `09_seeds.sql` | 160-190 | 5 (DRAFT, ACTIVE, etc.) |
| Cut Period Statuses | `09_seeds.sql` | 200-230 | 3 (OPEN, CLOSED, RECONCILED) |
| Rate Profiles | `09_seeds.sql` | 240-350 | 4 profiles × 4 términos = 16 |
| Usuario Admin | `09_seeds.sql` | 360-380 | 1 (admin@credinet.com) |
| Cut Periods 2024-2025 | `09_seeds.sql` | 390-460 | 8 períodos (dic-2024 a abr-2025) |

**⚠️ Pendiente**: Cut periods para nov-2025 a dic-2026 (ver `/scripts/generate_periods.py`)

---

## 🎯 Casos de Uso Frecuentes

### 1. Agregar campo a tabla existente

```bash
# 1. Editar módulo
vim db/v2.0/modules/02_core_tables.sql

# Buscar tabla (ej: loans línea 150-280)
# Agregar después de última columna:
ALTER TABLE loans ADD COLUMN new_field VARCHAR(100);

# 2. Regenerar
cd db/v2.0 && ./generate_monolithic.sh

# 3. Aplicar
docker exec credinet-postgres psql -U credinet_user -d credinet_db < init.sql
```

### 2. Modificar función existente

```bash
# 1. Buscar función en INDEX.md (ej: calculate_loan_payment en 05_functions_base.sql líneas 45-120)
vim db/v2.0/modules/05_functions_base.sql

# 2. Modificar lógica (reemplazar CREATE OR REPLACE FUNCTION completo)

# 3. Regenerar y aplicar (igual que arriba)
```

### 3. Crear nueva migración (futuro Sprint)

```bash
# 1. Aplicar cambios directamente en módulo correspondiente
vim db/v2.0/modules/0X_module.sql

# 2. Regenerar monolítico
./generate_monolithic.sh

# 3. Aplicar en BD
docker exec ... < init.sql

# 4. Documentar en /archive/migrations/v2.0.X_to_v2.0.Y/CHANGELOG.md
```

### 4. Consultar esquema de tabla

```bash
# Opción A: En BD
docker exec credinet-postgres psql -U credinet_user -d credinet_db -c "\d loans"

# Opción B: En código (buscar en INDEX.md)
# loans → 02_core_tables.sql líneas 150-280
cat db/v2.0/modules/02_core_tables.sql | sed -n '150,280p'
```

---

## 🔍 Búsqueda Rápida por Palabra Clave

| Necesitas | Buscar en | Keyword |
|-----------|-----------|---------|
| Cálculo de intereses | `05_functions_base.sql` | `calculate_loan_payment` |
| Generación de pagos | `06_functions_business.sql` | `generate_payment_schedule` |
| Oracle de fechas | `05_functions_base.sql` | `calculate_first_payment_date` |
| Calendario dual | `05_functions_base.sql` | `generate_amortization_schedule` |
| Crédito de socio | `06_functions_business.sql` | `check_associate_credit` |
| Cierre de período | `06_functions_business.sql` | `close_cut_period` |
| Estados de pago | `01_catalog_tables.sql` + `09_seeds.sql` | `payment_statuses` |
| Rate profiles | `10_rate_profiles.sql` | `rate_profiles`, `rate_profile_details` |
| Auditoría | `04_audit_tables.sql` + `07_triggers.sql` | `audit_log`, `audit_trigger_function` |

---

## 📚 Documentación Relacionada

### Arquitectura y Diseño
- `/docs/ARQUITECTURA_DOBLE_CALENDARIO.md` - Diseño técnico del calendario dual
- `/docs/ESTRATEGIA_MIGRACION_LIMPIA.md` - Plan de consolidación

### Validación y Testing
- `/docs/DASHBOARD_VALIDACION_SPRINT6.md` - Resultados validación E2E
- `/docs/AUDITORIA_FUENTES_VERDAD.md` - Análisis de duplicaciones

### Histórico de Cambios
- `/db/v2.0/archive/migrations/v2.0.0_to_v2.0.1/CHANGELOG.md` - Sprint 6 consolidado
- `/docs/REPORTE_SINCRONIZACION_MODULOS.md` - Cambios aplicados Sprint 6

---

## 🚨 Errores Comunes

### "column already exists"
→ El campo YA está en módulos principales, NO ejecutar migración de `/archive/`

### "function does not exist"
→ Verificar en módulo correcto (`05_functions_base.sql` vs `06_functions_business.sql`)

### "init.sql no refleja mis cambios"
→ Olvidaste ejecutar `./generate_monolithic.sh`

### "IA analiza archivos obsoletos"
→ Verificar que use `.aicontext` (prioridad HIGH para `/modules/`, LOW para `/archive/`)

---

**Actualizado**: 2025-11-05  
**Mantenedor**: GitHub Copilot + Equipo Credinet  
**Próxima revisión**: Sprint 7
