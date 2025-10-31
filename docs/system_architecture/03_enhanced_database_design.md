# 📊 DIAGRAMA ENTIDAD-RELACIÓN (ER) - CREDINET v2.0
# ========================================================================
# Sistema completo para gestión de préstamos, distribuidoras y cortes de pago
# ========================================================================

## 🏗️ **ENTIDADES PRINCIPALES**

### **1. GESTIÓN DE USUARIOS Y ROLES**
```
roles
├── id (PK)
├── name (desarrollador, administrador, auxiliar_administrativo, asociado, cliente)
└── created_at

users
├── id (PK)
├── username (UNIQUE)
├── password_hash
├── first_name
├── last_name
├── email (UNIQUE)
├── phone_number (UNIQUE)
├── birth_date
├── curp (UNIQUE)
├── profile_picture_url
├── associate_id (FK -> associates.id)
├── created_at
└── updated_at

user_roles (M:N)
├── user_id (PK, FK -> users.id)
└── role_id (PK, FK -> roles.id)

addresses
├── id (PK)
├── user_id (FK -> users.id) [UNIQUE]
├── street
├── external_number
├── internal_number
├── colony
├── municipality
├── state
├── zip_code
├── created_at
└── updated_at

beneficiaries
├── id (PK)
├── user_id (FK -> users.id)
├── full_name
├── relationship
├── phone_number
├── created_at
└── updated_at

guarantors
├── id (PK)
├── user_id (FK -> users.id)
├── full_name
├── relationship
├── phone_number
├── curp
├── created_at
└── updated_at
```

### **2. GESTIÓN DE DISTRIBUIDORAS/ASOCIADOS**
```
associate_levels
├── id (PK)
├── name (Bronce, Plata, Oro)
├── max_loan_amount
└── created_at

associates
├── id (PK)
├── name
├── level_id (FK -> associate_levels.id)
├── contact_person
├── contact_email (UNIQUE)
├── default_commission_rate
├── consecutive_full_credit_periods
├── consecutive_on_time_payments
├── clients_in_agreement
├── last_level_evaluation_date
├── created_at
└── updated_at

associate_level_history
├── id (PK)
├── associate_id (FK -> associates.id)
├── old_level_id (FK -> associate_levels.id)
├── new_level_id (FK -> associate_levels.id)
├── reason
├── change_type (UPGRADE, DOWNGRADE, MANUAL)
└── created_at
```

### **3. GESTIÓN DE DOCUMENTOS**
```
document_types
├── id (PK)
├── name
├── description
├── is_required
└── created_at

client_documents
├── id (PK)
├── client_id (FK -> users.id)
├── document_type_id (FK -> document_types.id)
├── file_name
├── original_file_name
├── file_path
├── file_size
├── mime_type
├── status (pending, approved, rejected)
├── upload_date
├── reviewed_by (FK -> users.id)
├── reviewed_at
├── comments
├── created_at
└── updated_at
```

### **4. ⭐ GESTIÓN DE PRÉSTAMOS (CORE BUSINESS)**
```
loans
├── id (PK)
├── user_id (FK -> users.id)
├── associate_id (FK -> associates.id)
├── amount
├── interest_rate
├── term_months
├── monthly_payment
├── total_amount
├── remaining_balance
├── next_payment_date
├── status (pending, active, paid, defaulted, cancelled)
├── commission_rate
├── approval_date
├── first_payment_date
├── created_at
└── updated_at

payments
├── id (PK)
├── loan_id (FK -> loans.id)
├── payment_number
├── amount_paid
├── principal_amount
├── interest_amount
├── commission_amount
├── payment_date
├── due_date
├── payment_method (cash, transfer, check)
├── status (pending, paid, late, missed)
├── associate_commission
├── processed_by (FK -> users.id)
├── cut_period_id (FK -> cut_periods.id) **NUEVO**
├── created_at
└── updated_at
```

### **5. 🆕 SISTEMA DE CORTES DE PAGO (NUEVA FUNCIONALIDAD)**
```
cut_periods
├── id (PK)
├── cut_number (2025-01, 2025-02, etc.)
├── period_start_date
├── period_end_date
├── status (active, closed, processing, finalized)
├── total_payments_expected
├── total_payments_received
├── total_commission_amount
├── created_by (FK -> users.id)
├── closed_by (FK -> users.id)
├── closed_at
├── created_at
└── updated_at

associate_payment_statements
├── id (PK)
├── cut_period_id (FK -> cut_periods.id)
├── associate_id (FK -> associates.id)
├── statement_number
├── total_payments_count
├── total_amount_collected
├── total_commission_owed
├── commission_rate_applied
├── status (generated, sent, paid, overdue)
├── generated_date
├── sent_date
├── due_date
├── paid_date
├── paid_amount
├── payment_method
├── payment_reference
├── late_fee_amount
├── created_at
└── updated_at

statement_payment_details
├── id (PK)
├── statement_id (FK -> associate_payment_statements.id)
├── payment_id (FK -> payments.id)
├── loan_id (FK -> loans.id)
├── client_name
├── payment_amount
├── commission_amount
├── payment_date
└── created_at

associate_payments_to_company
├── id (PK)
├── associate_id (FK -> associates.id)
├── statement_id (FK -> associate_payment_statements.id)
├── amount_paid
├── payment_date
├── payment_method (transfer, cash, check)
├── reference_number
├── received_by (FK -> users.id)
├── status (pending, confirmed, rejected)
├── notes
├── created_at
└── updated_at
```

### **6. 🆕 CONFIGURACIONES Y PARÁMETROS DEL SISTEMA**
```
system_configurations
├── id (PK)
├── config_key
├── config_value
├── description
├── config_type (string, number, boolean, date)
├── updated_by (FK -> users.id)
├── created_at
└── updated_at

-- Ejemplos de configuraciones:
-- cut_frequency_days: 15
-- payment_grace_period_days: 5
-- late_fee_percentage: 2.5
-- commission_payment_due_days: 7
```

## 🔗 **RELACIONES PRINCIPALES**

### **Cardinalidades:**
- **users** 1:N **loans** (Un usuario puede tener múltiples préstamos)
- **associates** 1:N **loans** (Una distribuidora maneja múltiples préstamos)
- **loans** 1:N **payments** (Un préstamo tiene múltiples pagos)
- **cut_periods** 1:N **payments** (Los pagos se agrupan por cortes)
- **cut_periods** 1:N **associate_payment_statements** (Un corte genera múltiples relaciones)
- **associates** 1:N **associate_payment_statements** (Una distribuidora tiene múltiples relaciones)
- **associate_payment_statements** 1:N **statement_payment_details** (Una relación detalla múltiples pagos)
- **associate_payment_statements** 1:N **associate_payments_to_company** (Una relación puede tener múltiples pagos)

## 📈 **FLUJO DE NEGOCIO COMPLETO**

### **Fase 1: Originación del Préstamo**
1. Cliente registra documentos → `client_documents`
2. Asociado evalúa y solicita préstamo → `loans` (status: pending)
3. Administrador aprueba → `loans` (status: active)

### **Fase 2: Ciclo de Pagos**
1. Cliente hace pago → `payments` (vinculado a `cut_period_id`)
2. Sistema calcula comisiones automáticamente
3. Pagos se acumulan en el corte activo

### **Fase 3: ⭐ Proceso de Cortes (NUEVO)**
1. **Inicio de Corte**: Cada 15 días, sistema crea nuevo `cut_periods`
2. **Acumulación**: Todos los `payments` se vinculan al corte activo
3. **Cierre de Corte**: Sistema genera `associate_payment_statements`
4. **Detalle de Relaciones**: Se crean `statement_payment_details` por cada pago
5. **Envío a Distribuidoras**: Relaciones se envían con fecha límite de pago
6. **Recepción de Pagos**: Distribuidoras pagan → `associate_payments_to_company`
7. **Conciliación**: Sistema confirma pagos y cierra el ciclo

## 🎯 **BENEFICIOS DEL NUEVO DISEÑO**

### **✅ Trazabilidad Completa**
- Cada pago está vinculado a un corte específico
- Historial completo de relaciones de pago
- Auditoría de pagos de distribuidoras

### **✅ Automatización**
- Generación automática de relaciones cada 15 días
- Cálculo automático de comisiones
- Alertas de pagos vencidos

### **✅ Reportes Avanzados**
- Estado financiero por corte
- Performance de distribuidoras
- Análisis de morosidad por períodos

### **✅ Escalabilidad**
- Soporte para múltiples distribuidoras
- Configuraciones flexibles de cortes
- Sistema preparado para crecimiento

## 🚀 **PRÓXIMOS DESARROLLOS SUGERIDOS**

1. **Módulo de Cortes**: Implementar lógica de `cut_periods`
2. **Generador de Relaciones**: Crear `associate_payment_statements` automáticamente
3. **Dashboard Financiero**: Vista gerencial de cortes y comisiones
4. **Notificaciones**: Sistema de alertas para pagos vencidos
5. **Reportes**: Exportación de relaciones en PDF/Excel
6. **API de Conciliación**: Endpoint para confirmar pagos de distribuidoras

Este diseño ER está preparado para manejar la complejidad completa del negocio de préstamos con distribuidoras, manteniendo la integridad de datos y permitiendo escalabilidad futura.
