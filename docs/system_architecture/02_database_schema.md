# Arquitectura: Esquema de la Base de Datos

Este documento describe la estructura de las tablas en la base de datos PostgreSQL, basada en el archivo `db/init_clean.sql` que es la **fuente única de verdad**.

> **⚠️ IMPORTANTE**: El sistema implementa **ÚNICAMENTE lógica quincenal**. Se ha eliminado completamente cualquier referencia a `payment_frequency` o lógica mensual.

## Tablas Principales

### `roles`
Almacena los diferentes roles de usuario en el sistema.
- `id`: SERIAL PRIMARY KEY
- `name`: VARCHAR(50) UNIQUE NOT NULL
- `created_at`: TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP

### `user_roles`
Tabla de unión que asigna roles a los usuarios, permitiendo un modelo multi-rol.
- `user_id`: INTEGER NOT NULL REFERENCES `users(id)` ON DELETE CASCADE
- `role_id`: INTEGER NOT NULL REFERENCES `roles(id)` ON DELETE CASCADE
- PRIMARY KEY (user_id, role_id)

### `associate_levels`
Define los diferentes niveles de asociados y sus límites de crédito.
- `id`: SERIAL PRIMARY KEY
- `name`: VARCHAR(50) UNIQUE NOT NULL
- `max_loan_amount`: DECIMAL(12, 2) NOT NULL
- `created_at`: TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP

### `associate_profiles`
**NUEVA TABLA**: Reemplaza la antigua tabla `associates`. Vincula usuarios con perfiles de asociado.
- `id`: SERIAL PRIMARY KEY
- `user_id`: INTEGER UNIQUE NOT NULL REFERENCES `users(id)` ON DELETE CASCADE
- `level_id`: INTEGER NOT NULL REFERENCES `associate_levels(id)`
- `contact_person`: VARCHAR(150)
- `contact_email`: VARCHAR(150) UNIQUE
- `default_commission_rate`: DECIMAL(5, 2) NOT NULL DEFAULT 5.0
- `active`: BOOLEAN NOT NULL DEFAULT true
- `consecutive_full_credit_periods`: INTEGER NOT NULL DEFAULT 0
- `consecutive_on_time_payments`: INTEGER NOT NULL DEFAULT 0
- `clients_in_agreement`: INTEGER NOT NULL DEFAULT 0
- `last_level_evaluation_date`: TIMESTAMP WITH TIME ZONE
- `created_at`: TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
- `updated_at`: TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP

### `users`
Tabla maestra que almacena información de cualquier persona en el sistema (administradores, asociados, clientes).
- `id`: SERIAL PRIMARY KEY
- `username`: VARCHAR(50) UNIQUE NOT NULL
- `password_hash`: VARCHAR(255) NOT NULL
- `first_name`: VARCHAR(100) NOT NULL
- `last_name`: VARCHAR(100) NOT NULL
- `email`: VARCHAR(150) UNIQUE NOT NULL
- `phone_number`: VARCHAR(20) UNIQUE NOT NULL
- `birth_date`: DATE
- `curp`: VARCHAR(18) UNIQUE
- `profile_picture_url`: VARCHAR(500)
- `created_at`: TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
- `updated_at`: TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP

### `addresses`
Direcciones normalizadas vinculadas a usuarios.
- `id`: SERIAL PRIMARY KEY
- `user_id`: INTEGER UNIQUE NOT NULL REFERENCES `users(id)` ON DELETE CASCADE
- `street`: VARCHAR(200) NOT NULL
- `external_number`: VARCHAR(10) NOT NULL
- `internal_number`: VARCHAR(10)
- `colony`: VARCHAR(100) NOT NULL
- `municipality`: VARCHAR(100) NOT NULL
- `state`: VARCHAR(100) NOT NULL
- `zip_code`: VARCHAR(10) NOT NULL
- `created_at`: TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
- `updated_at`: TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP

### `beneficiaries`
Almacena los beneficiarios asociados a un usuario.
- `id`: SERIAL PRIMARY KEY
- `user_id`: INTEGER UNIQUE NOT NULL REFERENCES `users(id)` ON DELETE CASCADE
- `full_name`: VARCHAR(200) NOT NULL
- `relationship`: VARCHAR(50) NOT NULL
- `phone_number`: VARCHAR(20) NOT NULL
- `created_at`: TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
- `updated_at`: TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP

### `guarantors`
Avales asociados a usuarios.
- `id`: SERIAL PRIMARY KEY
- `user_id`: INTEGER UNIQUE NOT NULL REFERENCES `users(id)` ON DELETE CASCADE
- `full_name`: VARCHAR(200) NOT NULL
- `first_name`: VARCHAR(100)
- `paternal_last_name`: VARCHAR(100)
- `maternal_last_name`: VARCHAR(100)
- `relationship`: VARCHAR(50) NOT NULL
- `phone_number`: VARCHAR(20) NOT NULL
- `curp`: VARCHAR(18) UNIQUE
- `created_at`: TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
- `updated_at`: TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP

### `loans` ⚠️ TABLA CRÍTICA - SOLO LÓGICA QUINCENAL
Préstamos del sistema. **NOTA**: Eliminado completamente `payment_frequency`.
- `id`: SERIAL PRIMARY KEY
- `user_id`: INTEGER NOT NULL REFERENCES `users(id)` ON DELETE CASCADE
- `associate_user_id`: INTEGER REFERENCES `users(id)` (referencia directa al usuario asociado)
- `amount`: DECIMAL(12, 2) NOT NULL
- `interest_rate`: DECIMAL(5, 2) NOT NULL
- `commission_rate`: DECIMAL(5, 2) NOT NULL DEFAULT 0.0
- `term_biweeks`: INTEGER NOT NULL (**CAMBIO CRÍTICO**: era `term_months`)
- `status`: VARCHAR(20) NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'ACTIVE', 'COMPLETED', 'DEFAULTED', 'CANCELLED'))
- `contract_id`: INTEGER REFERENCES `contracts(id)`
- `created_at`: TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
- `updated_at`: TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP

### `contracts`
Contratos asociados a préstamos.
- `id`: SERIAL PRIMARY KEY
- `loan_id`: INTEGER NOT NULL REFERENCES `loans(id)` ON DELETE CASCADE
- `file_path`: VARCHAR(500)
- `start_date`: DATE NOT NULL
- `sign_date`: DATE
- `document_number`: VARCHAR(50) UNIQUE NOT NULL
- `status`: VARCHAR(20) NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'signed', 'cancelled', 'completed'))
- `created_at`: TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
- `updated_at`: TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP

### `cut_periods` - SISTEMA QUINCENAL
Períodos de corte para el sistema quincenal.
- `id`: SERIAL PRIMARY KEY
- `cut_number`: INTEGER NOT NULL
- `period_start_date`: DATE NOT NULL
- `period_end_date`: DATE NOT NULL
- `status`: VARCHAR(20) NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'CLOSED'))
- `total_payments_expected`: DECIMAL(12, 2) NOT NULL DEFAULT 0.00
- `total_payments_received`: DECIMAL(12, 2) NOT NULL DEFAULT 0.00
- `total_commission`: DECIMAL(12, 2) NOT NULL DEFAULT 0.00
- `created_by`: INTEGER NOT NULL REFERENCES `users(id)`
- `closed_by`: INTEGER REFERENCES `users(id)`
- `created_at`: TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
- `updated_at`: TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP

### `payments` ⚠️ TABLA ACTUALIZADA - FECHAS PERFECTAS
Pagos realizados contra préstamos. **NUEVOS CAMPOS** para lógica quincenal.
- `id`: SERIAL PRIMARY KEY
- `loan_id`: INTEGER NOT NULL REFERENCES `loans(id)` ON DELETE CASCADE
- `amount_paid`: DECIMAL(12, 2) NOT NULL
- `payment_date`: DATE NOT NULL
- `payment_due_date`: DATE NOT NULL (**NUEVO**: fecha esperada día 15 o último día)
- `is_late`: BOOLEAN NOT NULL DEFAULT false (**NUEVO**: pago tardío)
- `cut_period_id`: INTEGER REFERENCES `cut_periods(id)`
- `created_at`: TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
- `updated_at`: TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP

### `document_types`
Tipos de documentos que pueden subir los clientes.
- `id`: SERIAL PRIMARY KEY
- `name`: VARCHAR(100) UNIQUE NOT NULL
- `description`: TEXT
- `is_required`: BOOLEAN NOT NULL DEFAULT false
- `created_at`: TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP

### `client_documents`
Documentos subidos por clientes.
- `id`: SERIAL PRIMARY KEY
- `client_id`: INTEGER NOT NULL REFERENCES `users(id)` ON DELETE CASCADE
- `document_type_id`: INTEGER NOT NULL REFERENCES `document_types(id)`
- `file_name`: VARCHAR(255) NOT NULL
- `original_file_name`: VARCHAR(255)
- `file_path`: VARCHAR(500) NOT NULL
- `file_size`: BIGINT
- `mime_type`: VARCHAR(100)
- `status`: VARCHAR(20) NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED'))
- `upload_date`: TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
- `reviewed_by`: INTEGER REFERENCES `users(id)`
- `reviewed_at`: TIMESTAMP WITH TIME ZONE
- `comments`: TEXT
- `created_at`: TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
- `updated_at`: TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP

## Índices Principales

Para optimizar consultas frecuentes:

```sql
-- Índices para associate_profiles
CREATE INDEX idx_associate_profiles_user_id ON associate_profiles(user_id);
CREATE INDEX idx_associate_profiles_level_id ON associate_profiles(level_id);

-- Índices para loans
CREATE INDEX idx_loans_user_id ON loans(user_id);
CREATE INDEX idx_loans_associate_user_id ON loans(associate_user_id);
CREATE INDEX idx_loans_status ON loans(status);

-- Índices para payments (NUEVOS - fechas perfectas)
CREATE INDEX idx_payments_loan_id ON payments(loan_id);
CREATE INDEX idx_payments_payment_due_date ON payments(payment_due_date);
CREATE INDEX idx_payments_is_late ON payments(is_late);

-- Índices para cut_periods
CREATE INDEX idx_cut_periods_status ON cut_periods(status);
CREATE INDEX idx_cut_periods_dates ON cut_periods(period_start_date, period_end_date);
```

## Cambios Críticos del Sistema

### ❌ **ELIMINADO COMPLETAMENTE**:
- Campo `payment_frequency` (toda la aplicación)
- Campo `term_months` → cambiado a `term_biweeks`
- Tabla `associates` → reemplazada por `associate_profiles`

### ✅ **AÑADIDO**:
- Campos `payment_due_date`, `is_late` en `payments`
- Tabla `associate_profiles` con métricas de rendimiento
- Sistema de períodos de corte quincenal (`cut_periods`)

> **📋 NOTA IMPORTANTE**: Este esquema refleja el sistema después de la "LIMPIEZA MASIVA" documentada en `LIMPIEZA_SISTEMA_COMPLETA.md`. Cualquier referencia a lógica mensual o `payment_frequency` en otros documentos es **OBSOLETA**.

- `updated_at`: TIMESTAMPTZ

### `loans`
Contiene la información de los préstamos.
- `id`: SERIAL PRIMARY KEY
- `user_id`: INTEGER NOT NULL REFERENCES `users(id)`
- `associate_id`: INTEGER REFERENCES `associates(id)`
- `amount`: NUMERIC(10, 2) NOT NULL
- `interest_rate`: NUMERIC(5, 2) NOT NULL
- `commission_rate`: NUMERIC(5, 2) NOT NULL
- `term_months`: NUMERIC(5, 2) NOT NULL
- `term_biweeks`: INTEGER NOT NULL (número de quincenas del préstamo)
- `status`: VARCHAR(20) NOT NULL DEFAULT 'pending'
- `updated_at`: TIMESTAMPTZ

### `payments`
Registra cada pago realizado a un préstamo.
- `id`: SERIAL PRIMARY KEY
- `loan_id`: INTEGER NOT NULL REFERENCES `loans(id)`
- `amount_paid`: NUMERIC(10, 2) NOT NULL
- `payment_date`: DATE NOT NULL
- `updated_at`: TIMESTAMPTZ
