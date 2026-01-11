# Análisis Sistema de Tracking de Deudas - 2026-01-08

## Resumen Ejecutivo

Se realizó un análisis completo del sistema de tracking de deudas y se encontraron y corrigieron varias inconsistencias críticas.

## Estructura del Sistema de Deudas

El sistema maneja **DOS TIPOS** de deuda separados:

### 1. Deudas por Statements No Pagados
| Campo | Descripción |
|-------|-------------|
| **Tabla** | `associate_accumulated_balances` |
| **Origen** | Statements cerrados con saldo pendiente |
| **Trigger** | Cierre de período (SETTLING → CLOSED) |
| **Destino** | Se suma a `debt_balance` del perfil |

### 2. Deudas por Clientes Morosos
| Campo | Descripción |
|-------|-------------|
| **Tabla** | `associate_debt_breakdown` |
| **Origen** | Aprobación manual de reportes de morosos |
| **Trigger** | POST `/defaulted-reports/{id}/approve` |
| **Destino** | Se suma a `debt_balance` del perfil |

## Flujo de Datos

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    STATEMENTS NO PAGADOS                                 │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  1. Statement queda con saldo pendiente                                 │
│                     ↓                                                   │
│  2. Al cerrar período (SETTLING → CLOSED):                              │
│     ├── Se registra en associate_accumulated_balances                   │
│     ├── Se suma a debt_balance del perfil  ← CORREGIDO                  │
│     └── Pagos de clientes → PAID_BY_ASSOCIATE                           │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│                    CLIENTES MOROSOS                                      │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  1. Admin aprueba reporte de cliente moroso                             │
│                     ↓                                                   │
│  2. Se crea registro en associate_debt_breakdown                        │
│                     ↓                                                   │
│  3. Se suma a debt_balance del perfil                                   │
│                     ↓                                                   │
│  4. Se puede crear convenio desde debt_breakdown                        │
│                     ↓                                                   │
│  5. Pagos de convenio reducen debt_balance                              │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

## Problema Encontrado

### Descripción
La función `_transfer_pending_debts` en el cierre de períodos **NO actualizaba** el campo `debt_balance` del `associate_profiles`. Solo:
1. ✅ Creaba registro en `associate_accumulated_balances`
2. ✅ Marcaba pagos como `PAID_BY_ASSOCIATE`
3. ❌ **NO sumaba la deuda a `debt_balance`**

### Impacto
- Los asociados tenían deudas registradas en `associate_accumulated_balances` que NO aparecían en su `debt_balance`
- Esto causaba que el `credit_available` fuera incorrecto (no se restaba toda la deuda real)

### Corrección Aplicada

**Archivo:** `backend/app/modules/cut_periods/routes.py`

**Cambio:** Se agregó la actualización del `debt_balance` después de insertar/actualizar `associate_accumulated_balances`:

```python
# ⭐ IMPORTANTE: Actualizar debt_balance del associate_profile
# La deuda del statement no pagado se suma al debt_balance
await db.execute(
    text("""
    UPDATE associate_profiles
    SET debt_balance = COALESCE(debt_balance, 0) + :amount,
        updated_at = NOW()
    WHERE user_id = :user_id
    """),
    {
        "user_id": stmt.user_id,
        "amount": float(pending_amount)
    }
)
```

## Datos Corregidos

Se corrigieron los `debt_balance` de los siguientes asociados:

| Profile ID | Username | debt_balance Anterior | debt_balance Corregido |
|------------|----------|----------------------|----------------------|
| 1 | asociado_test | 20,547.19 | 41,594.38 |
| 2 | asociado_norte | 8,076.89 | 19,535.60 |
| 3 | asociado_test01 | 4,991.67 | 10,483.34 |
| 6 | asociado.test | 0.00 | 1,971.01 |
| 7 | asociado.plata | 0.00 | 6,916.92 |
| 8 | asociado.oro | 0.00 | 16,500.02 |
| 11 | jairnoel.juanes | 1,877.00 | 5,054.00 |
| 13 | jairnoel.perez | 4,912.35 | 12,207.20 |

## Fórmula de Verificación

Para verificar que `debt_balance` es correcto:

```sql
debt_balance = SUM(associate_accumulated_balances.accumulated_debt) 
             - SUM(associate_debt_payments.payment_amount)
```

## Tablas Involucradas

1. **`associate_accumulated_balances`** - Historial de deudas por período
2. **`associate_debt_breakdown`** - Desglose de deudas individuales (morosos)
3. **`associate_debt_payments`** - Pagos realizados a deudas
4. **`associate_profiles`** - Perfil con `debt_balance` (campo que ahora se actualiza)
5. **`associate_payment_statements`** - Statements de cada período
6. **`agreements`** - Convenios de pago
7. **`agreement_payments`** - Pagos de convenios (reducen `debt_balance`)

## Scripts de Cron

### `scripts/auto_cut_scheduler.py`
- **Ejecuta:** días 8 y 23 de cada mes
- **Función:** PENDING → CUTOFF, genera statements en DRAFT
- **Estado:** ✅ Correcto

### Cierre Manual de Períodos
- **Endpoint:** PATCH `/api/v1/cut-periods/{id}` con status_id=5 (CLOSED)
- **Función:** SETTLING → CLOSED, transfiere deudas pendientes
- **Estado:** ✅ Corregido (ahora actualiza `debt_balance`)

## Relación credit_used vs debt_balance

| Campo | Descripción |
|-------|-------------|
| **credit_used** | Lo que debe el asociado por préstamos ACTIVOS (sum of `associate_payment` de pagos pendientes) |
| **debt_balance** | Deuda ADICIONAL (statements no pagados, morosos aprobados, penalizaciones) |
| **credit_available** | `credit_limit - credit_used - debt_balance` |

## Recomendaciones

1. ✅ **Corrección aplicada** - `debt_balance` se actualiza en cierre de período
2. ⚠️ **Monitoreo** - Crear un reporte que compare `debt_balance` vs `accumulated_balances` para detectar discrepancias
3. 📝 **Documentación** - Mantener actualizado este documento cuando haya cambios en el flujo de deudas

## Fecha de Corrección
- **Fecha:** 2026-01-08
- **Commit:** (pendiente de commit)
- **Autor:** Sistema
