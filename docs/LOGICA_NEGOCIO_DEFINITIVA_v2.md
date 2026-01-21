# 📘 Lógica de Negocio Definitiva - CrediNet v2.0

> **Última actualización**: 2026-01-12
> **Versión**: 2.0.4
> **Estado**: Producción

---

## 🏛️ Descripción General

CrediNet es un sistema de gestión de préstamos cooperativos diseñado para manejar:

1. **Préstamos a clientes** - Otorgados a través de asociados
2. **Comisiones** - Los asociados ganan comisión por cada pago cobrado
3. **Cortes quincenales** - Sistema de períodos para liquidación
4. **Estados de cuenta** - Relaciones de pago entre CrediCuenta y asociados

---

## 👥 Actores del Sistema

### Roles
| ID | Nombre | Descripción |
|----|--------|-------------|
| 1 | desarrollador | Acceso total al sistema |
| 2 | administrador | Gestión operativa completa |
| 3 | auxiliar_administrativo | Operaciones básicas |
| 4 | asociado | Gestiona sus clientes y préstamos |
| 5 | cliente | Solo recibe préstamos |

### Jerarquía de Permisos
```
Desarrollador > Administrador > Auxiliar > Asociado > Cliente
```

---

## 💰 Flujo de Préstamos

### Estados del Préstamo
```
PENDING(1) ─┬─> REJECTED(7)
            │
            └─> ACTIVE(2) ─┬─> COMPLETED(4)/PAID(5)
                           │
                           ├─> DEFAULTED(6)
                           │
                           └─> IN_AGREEMENT(9) ─> COMPLETED(4)
```

### Proceso de Aprobación
1. Cliente solicita préstamo
2. Asociado envía solicitud
3. Admin aprueba → Trigger `generate_payment_schedule()`
4. Sistema genera tabla de amortización
5. Préstamo pasa a ACTIVE(2)

### Cálculo de Amortización
```
Tasa Quincenal = tasa_anual / 24

Para cada pago:
  interés = saldo_pendiente × tasa_quincenal
  capital = pago_fijo - interés
  saldo_nuevo = saldo_pendiente - capital

Comisión Asociado = expected_amount × commission_rate
Associate Payment = expected_amount - comisión
```

---

## 📅 Sistema de Cortes Quincenales

### Días de Corte
- **Día 8**: Primer corte del mes
- **Día 23**: Segundo corte del mes

### Estados del Período
```
PENDING(1) ─> CUTOFF(3) ─> COLLECTING(4) ─> SETTLING(6) ─> CLOSED(5)
   │             │              │               │
   │             │              │               └─> Transfiere deuda
   │             │              │                   pendiente
   │             │              │
   │             │              └─> Admin cierra cobro
   │             │                  Statements finalizados
   │             │
   │             └─> Corte automático (00:05)
   │                 Genera statements borrador
   │
   └─> Período futuro
       Pagos pre-asignados
```

### Asignación de Pagos a Períodos
```sql
-- Un pago pertenece al período donde vence su fecha
SELECT id INTO v_period_id FROM cut_periods
WHERE period_start_date <= payment_due_date
  AND period_end_date >= payment_due_date
ORDER BY period_start_date DESC LIMIT 1;
```

---

## 💳 Estados de Cuenta (Statements)

### ¿Qué es un Statement?
Un statement representa lo que un **asociado debe pagar a CrediCuenta** por los pagos de clientes en un período específico.

### Campos Clave
| Campo | Descripción |
|-------|-------------|
| `total_amount_collected` | Total cobrado a clientes |
| `commission_earned` | Comisión que gana el asociado |
| `total_to_credicuenta` | Lo que debe pagar a CrediCuenta |
| `paid_amount` | Lo que ya ha pagado |
| `remaining_amount` | Saldo pendiente |

### Fórmula
```
total_to_credicuenta = total_amount_collected - commission_earned
remaining_amount = total_to_credicuenta - paid_amount
```

### Estados del Statement
| ID | Estado | Descripción |
|----|--------|-------------|
| 6 | DRAFT | Borrador (período en CUTOFF) |
| 7 | COLLECTING | En cobro (período COLLECTING) |
| 9 | SETTLING | En liquidación |
| 10 | CLOSED | Cerrado |
| 3 | PAID | Pagado completamente |

---

## 🏦 Sistema de Deuda

### Tipos de Deuda del Asociado

1. **Deuda por Statements** - Saldo pendiente de statements
2. **Deuda Heredada** - De períodos cerrados sin pago total
3. **Deuda por Convenios** - De préstamos en convenio

### Cálculo de Deuda Total
```sql
SELECT 
  SUM(remaining_amount) as statement_debt,
  accumulated_debt as inherited_debt,
  agreement_debt
FROM associate_payment_statements
WHERE associate_id = ?
  AND status_id NOT IN (3, 10)  -- No PAID ni CLOSED
```

### Flujo de Deuda al Cerrar Período
```
SETTLING → CLOSED:
  1. Para cada statement con remaining_amount > 0:
     - Agregar a associate.accumulated_debt
     - Marcar statement como ABSORBED(8)
  2. Período queda en CLOSED
```

---

## 🤝 Convenios de Pago

### ¿Qué es un Convenio?
Un convenio permite que un asociado asuma la deuda de préstamos morosos de sus clientes, pagando en cuotas.

### Flujo
```
1. Préstamo entra en mora (DEFAULTED)
2. Admin crea convenio:
   - Selecciona pagos pendientes
   - Transfiere deuda al asociado
   - Préstamo → IN_AGREEMENT(9)
   - Pagos → IN_AGREEMENT(13)
3. Asociado paga cuotas del convenio
4. Al completar → Préstamo COMPLETED(4)
```

---

## 📊 Tasas y Comisiones

### Perfiles de Tasa (rate_profiles)
```json
{
  "name": "Estándar",
  "annual_rate": 48.0,
  "commission_rate": 12.75,
  "is_active": true
}
```

### Tasas Legacy (montos fijos)
Para préstamos de sistema anterior, se usa `legacy_payments`:
```json
{
  "amount": 2000,
  "term_weeks": 12,
  "weekly_payment": 200,
  "commission": 25.50
}
```

---

## 🔐 Seguridad

### Autenticación
- JWT con refresh token
- Expiración: 24 horas (configurable)
- Refresh: 7 días

### Validaciones
- CURP único por usuario
- Email único por usuario
- Teléfono único por usuario

---

## 🗄️ Tablas Principales

### Entidades Core
| Tabla | Descripción |
|-------|-------------|
| `users` | Usuarios del sistema |
| `user_roles` | Asignación de roles |
| `associate_profiles` | Datos adicionales de asociados |

### Préstamos
| Tabla | Descripción |
|-------|-------------|
| `loans` | Préstamos otorgados |
| `payments` | Tabla de amortización |
| `rate_profiles` | Perfiles de tasa |

### Cortes y Statements
| Tabla | Descripción |
|-------|-------------|
| `cut_periods` | Períodos de corte |
| `associate_payment_statements` | Estados de cuenta |
| `statement_payments` | Abonos a statements |

### Convenios
| Tabla | Descripción |
|-------|-------------|
| `agreements` | Convenios de pago |
| `agreement_payments` | Cuotas del convenio |

---

## ⚙️ Triggers y Funciones

### `generate_payment_schedule()`
- **Evento**: INSERT en `loans` cuando `status_id = 2`
- **Acción**: Genera filas en `payments` con amortización francesa
- **Asigna**: `cut_period_id` basado en fecha de vencimiento

### `update_loan_status()`
- **Evento**: UPDATE en `payments`
- **Acción**: Si todos los pagos están PAID → préstamo COMPLETED

### `generate_statements_for_period()`
- **Llamado por**: Cierre de corte manual
- **Acción**: Crea statements para cada asociado con pagos en el período

---

## 📈 Métricas Clave

### Dashboard
- Préstamos activos
- Colocación del mes
- Cartera total
- Mora total
- Asociados activos

### Por Período
- Total esperado
- Total cobrado
- Comisiones generadas
- Saldo pendiente

---

## 🚀 Endpoints Principales

### Auth
- `POST /api/v1/auth/login`
- `POST /api/v1/auth/logout`
- `GET /api/v1/auth/me`

### Loans
- `GET /api/v1/loans` - Lista préstamos
- `POST /api/v1/loans` - Crear préstamo
- `POST /api/v1/loans/{id}/approve` - Aprobar
- `GET /api/v1/payments/loans/{id}` - Tabla de amortización

### Cut Periods
- `GET /api/v1/cut-periods` - Lista períodos
- `GET /api/v1/cut-periods/{id}/statements` - Statements del período
- `GET /api/v1/cut-periods/{id}/payments-preview` - Vista previa

### Statements
- `GET /api/v1/statements/{id}` - Detalle statement
- `POST /api/v1/statements/{id}/payments` - Registrar abono

### Agreements
- `GET /api/v1/agreements` - Lista convenios
- `POST /api/v1/agreements` - Crear convenio
- `POST /api/v1/agreements/{id}/payments/{n}` - Pagar cuota

---

## ✅ Reglas de Negocio

### Préstamos
1. Solo admin puede aprobar préstamos
2. Un préstamo requiere asociado asignado
3. Plazo máximo: 52 quincenas (2 años)
4. Monto mínimo: $1,000

### Pagos
1. No se puede pagar más del saldo pendiente
2. Pagos parciales permitidos
3. Fecha de pago no puede ser futura

### Períodos
1. Solo un período puede estar en COLLECTING
2. No se puede revertir un período CLOSED
3. Corte automático solo si día es 8 o 23

### Statements
1. Se generan al cerrar corte (CUTOFF → COLLECTING)
2. Solo asociados con pagos en el período
3. Abono no puede exceder remaining_amount

---

## 📋 Configuración

### Variables de Entorno
```bash
# Base de datos
POSTGRES_USER=credinet_user
POSTGRES_PASSWORD=****
POSTGRES_DB=credinet_db
POSTGRES_PORT=5432

# JWT
JWT_SECRET=****
JWT_ALGORITHM=HS256
JWT_ACCESS_TOKEN_EXPIRE_MINUTES=1440
JWT_REFRESH_TOKEN_EXPIRE_DAYS=7

# CORS
CORS_ORIGINS=http://localhost:5173,http://192.168.98.98:5173
```

---

## 📝 Notas de Implementación

### Valores Hardcoded
Ver `backend/app/core/constants.py` para constantes centralizadas.

### Zonas Horarias
El sistema usa UTC internamente. Las fechas de corte se calculan en hora local de México (UTC-6).

### Precisión Decimal
Todos los cálculos monetarios usan `Decimal` con precisión de 2 decimales.
Tolerancia para comparaciones: `$0.01`

---

*Documento generado automáticamente. Mantener actualizado con cada cambio de lógica.*
