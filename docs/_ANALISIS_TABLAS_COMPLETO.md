# Análisis Completo de Tablas - CrediNet v2.0
**Fecha**: 2025-11-05
**Total de Tablas**: 38 tablas + 11 vistas

---

## 📊 RESUMEN EJECUTIVO

### Tablas con Datos (Implementación Prioritaria)
| Tabla | Registros | Módulo Backend | Estado |
|-------|-----------|----------------|--------|
| **audit_log** | 172 | ❌ No implementado | 🔥 ALTA |
| **payments** | 60 | ✅ Implementado | ✅ COMPLETO |
| **users** | 9 | ✅ Implementado (auth) | ✅ COMPLETO |
| **cut_periods** | 8 | ✅ Implementado | ✅ COMPLETO |
| **rate_profiles** | 5 | ✅ Implementado | ✅ COMPLETO |
| **loans** | 4 | ✅ Implementado | ✅ COMPLETO |
| **addresses** | 4 | ❌ No implementado | 🔥 ALTA |
| **guarantors** | 3 | ❌ No implementado | 🔥🔥 SIGUIENTE |
| **beneficiaries** | 3 | ❌ No implementado | 🔥🔥 SIGUIENTE |
| **associate_profiles** | 2 | ✅ Implementado | ✅ COMPLETO |

### Tablas de Catálogos (Todos tienen datos)
| Tabla | Registros | Estado Backend |
|-------|-----------|----------------|
| **payment_statuses** | 12 | ✅ Implementado (catalogs) |
| **config_types** | 8 | ✅ Implementado (catalogs) |
| **loan_statuses** | 8 | ✅ Implementado (catalogs) |
| **payment_methods** | 7 | ✅ Implementado (catalogs) |
| **contract_statuses** | 6 | ✅ Implementado (catalogs) |
| **roles** | 5 | ✅ Implementado (auth) |
| **cut_period_statuses** | 5 | ✅ Implementado (catalogs) |
| **document_types** | 5 | ✅ Implementado (catalogs) |
| **associate_levels** | 5 | ✅ Implementado (catalogs) |
| **document_statuses** | 4 | ✅ Implementado (catalogs) |

### Tablas Sin Datos (Implementación Futura)
| Tabla | Módulo Propuesto | Prioridad |
|-------|------------------|-----------|
| **contracts** | contracts | 🔥 MEDIA |
| **agreements** | agreements | 🔥 MEDIA |
| **client_documents** | documents | 🟡 BAJA |
| **agreement_items** | agreements | 🟡 BAJA |
| **agreement_payments** | agreements | 🟡 BAJA |
| **loan_renewals** | loans (extensión) | 🟡 BAJA |
| **associate_level_history** | associates (extensión) | 🟡 BAJA |
| **associate_accumulated_balances** | associates (extensión) | 🟡 BAJA |
| **associate_debt_breakdown** | associates (extensión) | 🟡 BAJA |
| **associate_payment_statements** | associates (extensión) | 🟡 BAJA |
| **defaulted_client_reports** | reports | 🟡 BAJA |

---

## 📋 DETALLE DE ESQUEMAS

### 1. USERS (9 registros) ✅
**Tabla**: `users`
**Columnas** (13):
- `id` (PK, serial)
- `username` (varchar, NOT NULL, unique)
- `password_hash` (varchar, NOT NULL)
- `first_name` (varchar, NOT NULL)
- `last_name` (varchar, NOT NULL)
- `email` (varchar, unique)
- `phone_number` (varchar, NOT NULL)
- `birth_date` (date)
- `curp` (varchar, unique)
- `profile_picture_url` (varchar)
- `active` (boolean, default: true)
- `created_at` (timestamptz)
- `updated_at` (timestamptz)

**Relaciones**:
- `user_roles` (1:N) → Define rol del usuario
- `loans` → Préstamos del cliente
- `associate_profiles` → Perfil de asociado
- `addresses` → Dirección del usuario
- `guarantors` → Avales del usuario
- `beneficiaries` → Beneficiarios del usuario

---

### 2. LOANS (4 registros) ✅
**Tabla**: `loans`
**Columnas** (24):
- `id` (PK, serial)
- `user_id` (FK → users, NOT NULL)
- `associate_user_id` (FK → users)
- `amount` (numeric, NOT NULL)
- `interest_rate` (numeric, NOT NULL)
- `commission_rate` (numeric, NOT NULL, default: 0.0)
- `term_biweeks` (integer, NOT NULL)
- `status_id` (FK → loan_statuses, NOT NULL)
- `contract_id` (FK → contracts)
- `approved_at` (timestamptz)
- `approved_by` (FK → users)
- `rejected_at` (timestamptz)
- `rejected_by` (FK → users)
- `rejection_reason` (text)
- `notes` (text)
- `profile_code` (varchar) → Código del rate_profile usado
- `biweekly_payment` (numeric) → Pago quincenal calculado
- `total_payment` (numeric) → Monto total a pagar
- `total_interest` (numeric) → Total de intereses
- `total_commission` (numeric) → Total de comisiones
- `commission_per_payment` (numeric) → Comisión por pago
- `associate_payment` (numeric) → Pago al asociado
- `created_at` (timestamptz)
- `updated_at` (timestamptz)

**Relaciones**:
- `user_id` → Cliente que solicita el préstamo
- `associate_user_id` → Asociado que otorga el préstamo
- `payments` (1:N) → Pagos del préstamo

---

### 3. PAYMENTS (60 registros) ✅
**Tabla**: `payments`
**Columnas** (20):
- `id` (PK, serial)
- `loan_id` (FK → loans, NOT NULL)
- `amount_paid` (numeric, NOT NULL)
- `payment_date` (date, NOT NULL)
- `payment_due_date` (date, NOT NULL)
- `is_late` (boolean, NOT NULL, default: false)
- `status_id` (FK → payment_statuses)
- `cut_period_id` (FK → cut_periods)
- `marked_by` (FK → users)
- `marked_at` (timestamptz)
- `marking_notes` (text)
- `payment_number` (integer) → Número de pago (1, 2, 3...)
- `expected_amount` (numeric) → Monto esperado
- `interest_amount` (numeric) → Interés del pago
- `principal_amount` (numeric) → Capital del pago
- `commission_amount` (numeric) → Comisión del pago
- `associate_payment` (numeric) → Pago al asociado
- `balance_remaining` (numeric) → Saldo restante
- `created_at` (timestamptz)
- `updated_at` (timestamptz)

**Estados Posibles** (payment_statuses):
- 1: PENDING
- 2: PAID
- 3: PARTIAL
- 4: OVERDUE
- 5: CANCELLED
- 6: SUSPENDED
- 7: ABSORBED (absorbido por asociado)
- 8-12: Estados adicionales

---

### 4. GUARANTORS (3 registros) ❌ PENDIENTE
**Tabla**: `guarantors`
**Columnas** (11):
- `id` (PK, serial)
- `user_id` (FK → users, NOT NULL) → Cliente que tiene el aval
- `full_name` (varchar, NOT NULL)
- `first_name` (varchar)
- `paternal_last_name` (varchar)
- `maternal_last_name` (varchar)
- `relationship` (varchar, NOT NULL) → Ej: "Padre", "Madre", "Hermano"
- `phone_number` (varchar, NOT NULL)
- `curp` (varchar)
- `created_at` (timestamptz)
- `updated_at` (timestamptz)

**Datos Ejemplo**:
- ID 1: Carlos Alberto Vargas Hernández (Padre de user_id 4)
- ID 2: Ana María Pérez Gómez (Madre de user_id 5)
- ID 3: Jorge Luis Martínez Sánchez (Hermano de user_id 6)

---

### 5. BENEFICIARIES (3 registros) ❌ PENDIENTE
**Tabla**: `beneficiaries`
**Columnas** (7):
- `id` (PK, serial)
- `user_id` (FK → users, NOT NULL) → Cliente que tiene el beneficiario
- `full_name` (varchar, NOT NULL)
- `relationship` (varchar, NOT NULL) → Ej: "Hija", "Hijo"
- `phone_number` (varchar, NOT NULL)
- `created_at` (timestamptz)
- `updated_at` (timestamptz)

**Datos Ejemplo**:
- ID 1: María Fernanda Vargas Torres (Hija de user_id 4)
- ID 2: Luis Alberto Pérez Cruz (Hijo de user_id 5)
- ID 3: Ana Laura Martínez López (Hija de user_id 6)

---

### 6. CUT_PERIODS (8 registros) ✅
**Tabla**: `cut_periods`
**Columnas** (12):
- `id` (PK, serial)
- `cut_number` (integer, NOT NULL) → Número de corte (23, 24, 1-6)
- `period_start_date` (date, NOT NULL)
- `period_end_date` (date, NOT NULL)
- `status_id` (FK → cut_period_statuses, NOT NULL)
- `total_payments_expected` (numeric, NOT NULL, default: 0)
- `total_payments_received` (numeric, NOT NULL, default: 0)
- `total_commission` (numeric, NOT NULL, default: 0)
- `created_by` (FK → users, NOT NULL)
- `closed_by` (FK → users)
- `created_at` (timestamptz)
- `updated_at` (timestamptz)

**Estados** (cut_period_statuses):
- 1: ACTIVE (activo)
- 2: PENDING (pendiente)
- 5: CLOSED (cerrado)

**Datos Actuales**:
- Cut 23: 2024-12-08 a 2024-12-22 (CLOSED)
- Cut 24: 2024-12-23 a 2025-01-07 (CLOSED)
- Cut 1-6: 2025-01-08 a 2025-04-07 (mayoría CLOSED, algunos PENDING)

---

### 7. ASSOCIATE_PROFILES (2 registros) ✅
**Tabla**: `associate_profiles`
**Columnas** (18):
- `id` (PK, serial)
- `user_id` (FK → users, NOT NULL, unique)
- `level_id` (FK → associate_levels, NOT NULL)
- `contact_person` (varchar)
- `contact_email` (varchar)
- `default_commission_rate` (numeric, NOT NULL)
- `active` (boolean, NOT NULL)
- `consecutive_full_credit_periods` (integer, NOT NULL, default: 0)
- `consecutive_on_time_payments` (integer, NOT NULL, default: 0)
- `clients_in_agreement` (integer, NOT NULL, default: 0)
- `last_level_evaluation_date` (timestamptz)
- `credit_used` (numeric, NOT NULL, default: 0) → Crédito usado actualmente
- `credit_limit` (numeric, NOT NULL) → Límite de crédito disponible
- `credit_available` (numeric) → Crédito disponible (calculado)
- `credit_last_updated` (timestamptz)
- `debt_balance` (numeric, NOT NULL, default: 0) → Deuda pendiente
- `created_at` (timestamptz)
- `updated_at` (timestamptz)

**Datos Actuales**:
- User 3: credit_limit=200000, credit_used=25000 (12.5% uso)
- User 8: credit_limit=150000, credit_used=0 (0% uso)

---

### 8. RATE_PROFILES (5 registros) ✅
**Tabla**: `rate_profiles`
**Columnas** (17):
- `id` (PK, serial)
- `code` (varchar, NOT NULL, unique) → "FLEXIBLE_001", etc.
- `name` (varchar, NOT NULL)
- `description` (text)
- `calculation_type` (varchar, NOT NULL) → "simple_interest", "compound_interest"
- `interest_rate_percent` (numeric)
- `commission_rate_percent` (numeric)
- `enabled` (boolean, default: true)
- `is_recommended` (boolean, default: false)
- `display_order` (integer)
- `min_amount` (numeric) → Monto mínimo del préstamo
- `max_amount` (numeric) → Monto máximo del préstamo
- `valid_terms` (integer[]) → Array de plazos válidos [12, 24, 36]
- `created_at` (timestamptz)
- `updated_at` (timestamptz)
- `created_by` (FK → users)
- `updated_by` (FK → users)

---

### 9. ADDRESSES (4 registros) ❌ PENDIENTE
**Tabla**: `addresses`
**Columnas** (11):
- `id` (PK, serial)
- `user_id` (FK → users, NOT NULL)
- `street` (varchar, NOT NULL)
- `external_number` (varchar, NOT NULL)
- `internal_number` (varchar)
- `colony` (varchar, NOT NULL) → Colonia
- `municipality` (varchar, NOT NULL) → Municipio/Alcaldía
- `state` (varchar, NOT NULL) → Estado
- `zip_code` (varchar, NOT NULL) → Código postal
- `created_at` (timestamptz)
- `updated_at` (timestamptz)

---

### 10. CONTRACTS (0 registros) ❌ PENDIENTE
**Tabla**: `contracts`
**Columnas** (9):
- `id` (PK, serial)
- `loan_id` (FK → loans, NOT NULL, unique)
- `file_path` (varchar) → Ruta del archivo PDF del contrato
- `start_date` (date, NOT NULL)
- `sign_date` (date) → Fecha de firma
- `document_number` (varchar, NOT NULL, unique) → Número de contrato
- `status_id` (FK → contract_statuses, NOT NULL)
- `created_at` (timestamptz)
- `updated_at` (timestamptz)

**Estados** (contract_statuses):
- 1: DRAFT (borrador)
- 2: PENDING_SIGNATURE (pendiente firma)
- 3: SIGNED (firmado)
- 4: ACTIVE (activo)
- 5: COMPLETED (completado)
- 6: CANCELLED (cancelado)

---

### 11. AGREEMENTS (0 registros) ❌ PENDIENTE
**Tabla**: `agreements`
**Columnas** (15):
- `id` (PK, serial)
- `associate_profile_id` (FK → associate_profiles, NOT NULL)
- `agreement_number` (varchar, NOT NULL, unique)
- `agreement_date` (date, NOT NULL)
- `total_debt_amount` (numeric, NOT NULL) → Deuda total del convenio
- `payment_plan_months` (integer, NOT NULL) → Plazo del plan de pago
- `monthly_payment_amount` (numeric, NOT NULL) → Pago mensual acordado
- `status` (varchar, NOT NULL, default: 'ACTIVE')
- `start_date` (date, NOT NULL)
- `end_date` (date)
- `created_by` (FK → users, NOT NULL)
- `approved_by` (FK → users)
- `notes` (text)
- `created_at` (timestamptz)
- `updated_at` (timestamptz)

**Relaciones**:
- `agreement_items` (1:N) → Ítems del convenio
- `agreement_payments` (1:N) → Pagos del convenio

---

### 12. CLIENT_DOCUMENTS (0 registros) ❌ PENDIENTE
**Tabla**: `client_documents`
**Columnas** (15):
- `id` (PK, serial)
- `user_id` (FK → users, NOT NULL)
- `document_type_id` (FK → document_types, NOT NULL)
- `file_name` (varchar, NOT NULL)
- `original_file_name` (varchar)
- `file_path` (varchar, NOT NULL)
- `file_size` (bigint)
- `mime_type` (varchar)
- `status_id` (FK → document_statuses, NOT NULL)
- `upload_date` (timestamptz)
- `reviewed_by` (FK → users)
- `reviewed_at` (timestamptz)
- `comments` (text)
- `created_at` (timestamptz)
- `updated_at` (timestamptz)

**Tipos de Documentos** (document_types):
- INE
- Comprobante de domicilio
- Estado de cuenta
- Etc.

---

### 13. AUDIT_LOG (172 registros) ❌ PENDIENTE
**Tabla**: `audit_log`
**Columnas** (10):
- `id` (PK, serial)
- `table_name` (varchar, NOT NULL) → Nombre de la tabla auditada
- `record_id` (integer, NOT NULL) → ID del registro modificado
- `operation` (varchar, NOT NULL) → INSERT, UPDATE, DELETE
- `old_data` (jsonb) → Datos anteriores (UPDATE/DELETE)
- `new_data` (jsonb) → Datos nuevos (INSERT/UPDATE)
- `changed_by` (FK → users)
- `changed_at` (timestamptz)
- `ip_address` (inet) → IP del usuario
- `user_agent` (text) → User agent del navegador

**Uso**: Auditoría completa de cambios en el sistema

---

### 14. SYSTEM_CONFIGURATIONS (10 registros)
**Tabla**: `system_configurations`
**Columnas** (8):
- `id` (PK, serial)
- `config_type_id` (FK → config_types, NOT NULL)
- `key` (varchar, NOT NULL, unique)
- `value` (varchar, NOT NULL)
- `description` (text)
- `is_active` (boolean, default: true)
- `created_at` (timestamptz)
- `updated_at` (timestamptz)

**Ejemplos de configuraciones**:
- Tasas de interés globales
- Límites de crédito por nivel
- Comisiones del sistema
- etc.

---

## 🎯 PLAN DE IMPLEMENTACIÓN

### Prioridad 1: Módulos con Datos (Crítico)
1. ✅ **payments** - 60 registros - COMPLETADO
2. ✅ **cut_periods** - 8 registros - COMPLETADO
3. ✅ **associates** - 2 registros - COMPLETADO
4. ✅ **clients** - 9 usuarios filtrados por rol - COMPLETADO
5. 🔥🔥 **guarantors** - 3 registros - SIGUIENTE
6. 🔥🔥 **beneficiaries** - 3 registros - SIGUIENTE
7. 🔥 **addresses** - 4 registros - ALTA PRIORIDAD
8. 🔥 **audit_log** - 172 registros - ALTA PRIORIDAD

### Prioridad 2: Módulos Sin Datos (Funcionalidad Futura)
1. 🟡 **contracts** - 0 registros - Gestión de contratos
2. 🟡 **agreements** - 0 registros - Convenios de pago
3. 🟡 **client_documents** - 0 registros - Documentos de clientes

### Prioridad 3: Extensiones de Módulos Existentes
1. 🟢 **loan_renewals** - Renovaciones de préstamos
2. 🟢 **associate_level_history** - Historial de niveles de asociados
3. 🟢 **payment_status_history** - Historial de cambios de estado de pagos

---

## 📊 ESTADO ACTUAL DEL BACKEND

### Módulos Implementados (8)
1. ✅ **auth** (users, user_roles, roles)
2. ✅ **catalogs** (todos los catálogos)
3. ✅ **loans** (loans, loan_statuses)
4. ✅ **rate_profiles** (rate_profiles)
5. ✅ **payments** (payments, payment_statuses)
6. ✅ **clients** (users filtrados por rol cliente)
7. ✅ **associates** (associate_profiles)
8. ✅ **cut_periods** (cut_periods, cut_period_statuses)

### Módulos Pendientes con Datos (4)
1. ❌ **guarantors** (3 registros)
2. ❌ **beneficiaries** (3 registros)
3. ❌ **addresses** (4 registros)
4. ❌ **audit_log** (172 registros)

### Módulos Pendientes sin Datos (3)
1. ❌ **contracts** (0 registros)
2. ❌ **agreements** (0 registros)
3. ❌ **client_documents** (0 registros)

---

## 🔗 RELACIONES CRÍTICAS

### Flujo Principal de Negocio
```
users (cliente)
  ├─> addresses (dirección)
  ├─> guarantors (avales)
  ├─> beneficiaries (beneficiarios)
  ├─> client_documents (documentos)
  └─> loans (préstamos)
        ├─> contracts (contrato)
        └─> payments (pagos)
              └─> cut_periods (periodo de corte)

users (asociado)
  └─> associate_profiles
        ├─> agreements (convenios)
        │     ├─> agreement_items
        │     └─> agreement_payments
        └─> loans (préstamos otorgados)
```

### Tablas de Auditoría
```
audit_log → Registra todos los cambios
payment_status_history → Historial de cambios de pagos
associate_level_history → Historial de cambios de niveles
```

---

## 📈 COBERTURA ACTUAL

**Total Tablas**: 38 (sin contar vistas)
**Tablas con Datos**: 13 (34%)
**Módulos Implementados**: 8 (21% del total de tablas)
**Cobertura de Tablas con Datos**: 9/13 (69%) ✅

**Siguiente Objetivo**: Implementar **guarantors** y **beneficiaries** para llegar al 85% de cobertura de tablas con datos.
