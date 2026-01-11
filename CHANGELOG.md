# 📝 CHANGELOG - CREDINET v2.0

Registro de cambios significativos del proyecto.

---

## [2.0.6] - 2026-01-11

### 🔧 Correcciones Críticas

#### Trigger generate_payment_schedule() - Asignación de Períodos
**Problema:** El trigger fue modificado incorrectamente, cambiando la búsqueda de períodos de rango de fechas a búsqueda por cut_code con formato incorrecto.

**Causa Raíz:**
- El código generaba `JAN07-2026` pero la BD tiene `Jan08-2026`
- Diferencia: UPPER vs Title case + día incorrecto en el nombre

**Cambios:**
- ✅ **Restaurada:** Lógica original de búsqueda por rango de fechas
- ✅ **Corregidos:** 102 pagos de préstamos 93, 94, 97, 98, 99, 100, 101
- ✅ **Extendidos:** cut_periods de 72 a 120 (hasta 2029-01-07)

**Lógica Correcta:**
```sql
SELECT id INTO v_period_id FROM cut_periods
WHERE period_start_date <= v_amortization_row.fecha_pago
  AND period_end_date >= v_amortization_row.fecha_pago
ORDER BY period_start_date DESC LIMIT 1;
```

**Archivos:**
- `db/v2.0/init.sql` - Función corregida
- `db/v2.0/migrations/migration_028_extend_cut_periods_to_2028.sql`

### 📁 Organización de Archivos
- Movidos documentos de auditoría a `docs/auditorias_correcciones/`
- Movidos scripts legacy a `scripts/legacy/`
- Consolidados backups en `db/backups/`
- Eliminado script duplicado `backend/verify_amortization.py`

---

## [2.0.5] - 2026-01-07

### 🔧 Correcciones Críticas

#### Liberación de Crédito en Pagos de Asociado
**Problema:** El sistema liberaba crédito incorrectamente cuando clientes pagaban a asociados, en lugar de cuando asociados pagan a CrediCuenta.

**Cambios:**
- ❌ **Eliminado:** Trigger `trigger_update_associate_credit_on_payment` de tabla `payments`
- ✅ **Actualizado:** Función `update_statement_on_payment()` ahora libera `credit_used`
- ✅ **Validado:** Consistencia entre abonos a statements y abonos a deuda

**Impacto:**
- Crédito ahora se libera SOLO cuando asociado paga a CrediCuenta
- `credit_available` refleja correctamente el crédito disponible
- Consistencia arquitectónica en el sistema de pagos

**Archivos:**
- `db/v2.0/modules/CORRECCION_LIBERACION_CREDITO_V2.sql`
- `db/v2.0/modules/TEST_LIBERACION_CREDITO_V2.sql`
- `docs/LOGICA_LIBERACION_CREDITO_EJEMPLOS.md`
- `docs/REPORTE_CORRECCION_LIBERACION_CREDITO_V2.md`

**Tests:** ✅ 4/4 pasando  
**Validación:** ✅ Con datos reales en BD

---

## [2.0.4] - 2026-01-07 (Anterior)

### 🔧 Correcciones

#### Cálculo de credit_used con associate_payment
**Problema:** `credit_used` se calculaba con capital solamente, sin incluir intereses y comisiones que el asociado debe pagar a CrediCuenta.

**Cambios:**
- ✅ Corrección en `trigger_update_associate_credit_on_loan_approval()`
- ✅ Corrección en `trigger_update_associate_credit_on_payment()`
- ✅ Corrección en `calculate_loan_remaining_balance()`

**Archivos:**
- `db/v2.0/modules/CORRECCION_CRITICA_ASSOCIATE_PAYMENT.sql`

---

## Formato

Cada entrada de cambio debe incluir:
- **Fecha:** Formato ISO (YYYY-MM-DD)
- **Versión:** Semver (MAJOR.MINOR.PATCH)
- **Categoría:** Correcciones / Nuevas Funcionalidades / Mejoras / Deprecaciones
- **Descripción:** Qué se cambió y por qué
- **Impacto:** Cómo afecta al sistema
- **Archivos:** Lista de archivos modificados/creados
- **Tests/Validación:** Estado de pruebas

---

**Última actualización:** 2026-01-07
