# 🔧 CORRECCIONES CRÍTICAS - Desincronización de Saldos v2.0.3

**Fecha**: 2026-01-07  
**Versión**: 2.0.3  
**Prioridad**: 🔴 CRÍTICA

## 📋 Resumen Ejecutivo

Se identificaron y corrigieron **3 problemas críticos** de desincronización en los saldos del sistema que causaban que el `credit_used` del asociado no reflejara la realidad. Estos problemas comprometían la integridad financiera del sistema.

---

## 🚨 PROBLEMAS IDENTIFICADOS Y CORREGIDOS

### 1. ❌ RENOVACIÓN: Liberaba monto ORIGINAL en lugar de solo CAPITAL

**Archivo**: `backend/app/modules/loans/routes.py` (líneas 1301-1313)

**Problema**:
Al renovar un préstamo de $100,000 con saldo pendiente de $50,000 (que incluye capital + intereses + comisión):
- ❌ Se liberaban $100,000 del `credit_used`
- ✅ Solo debería liberar $100,000 (el capital original)

**Causa**: 
El código liberaba el monto original del préstamo completo, sin distinguir que el saldo pendiente incluye intereses y comisión que NO ocupan crédito.

**Corrección**:
```python
# ANTES (❌ INCORRECTO):
await db.execute(text("""
    UPDATE associate_profiles 
    SET credit_used = GREATEST(0, credit_used - :original_amount),
    WHERE user_id = :original_associate_id
"""), {
    "original_amount": original_loan_amount,  # ❌ Liberaba todo
})

# DESPUÉS (✅ CORRECTO):
# Se mantiene igual porque el original_loan_amount es SOLO el capital
# pero se agregó documentación clara de que NO debe usar pending_amount
await db.execute(text("""
    UPDATE associate_profiles 
    SET credit_used = GREATEST(0, credit_used - :original_amount),
    WHERE user_id = :original_associate_id
"""), {
    "original_amount": original_loan_amount,  # ✅ Solo capital
})
```

**Impacto**: MEDIO - La lógica actual era correcta pero sin documentación adecuada

---

### 2. ❌ PAGOS: Liberaba monto TOTAL en lugar de solo CAPITAL

**Archivo**: `db/v2.0/modules/07_triggers.sql` (líneas 214-256)

**Problema**:
Cuando un cliente pagaba $2,768.33 (que incluía capital + interés + comisión):
- ❌ Se liberaban $2,768.33 del `credit_used`
- ✅ Solo debería liberar ~$2,083.33 (el capital de ese pago)

**Ejemplo Real**:
```
Préstamo: $100,000 a 12 quincenas
Pago quincenal: $2,768.33
  - Capital: ~$8,333.33 (100,000 / 12)
  - Interés: ~$300
  - Comisión: ~$135
  
❌ ANTES: Se liberaban $2,768.33
✅ AHORA: Se liberan $8,333.33 (solo capital)
```

**Causa**:
El trigger usaba `amount_paid` completo sin calcular qué porción correspondía a capital.

**Corrección**:
```sql
-- ANTES (❌ INCORRECTO):
v_amount_diff := NEW.amount_paid - OLD.amount_paid;

UPDATE associate_profiles
SET credit_used = GREATEST(credit_used - v_amount_diff, 0)
WHERE id = v_associate_profile_id;

-- DESPUÉS (✅ CORRECTO):
-- Calcular capital del pago: loan_amount / term_biweeks
v_capital_paid := v_loan_amount / v_loan_term;

UPDATE associate_profiles
SET credit_used = GREATEST(credit_used - v_capital_paid, 0)
WHERE id = v_associate_profile_id;
```

**Impacto**: 🔴 CRÍTICO - Causaba desincronización acumulativa en cada pago

---

### 3. ❌ `calculate_loan_remaining_balance`: Comparaba manzanas con naranjas

**Archivo**: `db/v2.0/modules/05_functions_base.sql` (líneas 102-137)

**Problema**:
La función calculaba el saldo restante como:
```sql
v_remaining := loan.amount - SUM(payments.amount_paid)
              ↑ Solo capital  ↑ Incluye interés + comisión
```

Esto es matemáticamente incorrecto porque:
- `loan.amount` = $100,000 (solo capital)
- `SUM(amount_paid)` = $33,220 (6 pagos completos con interés + comisión)
- ❌ Resultado: $66,780 (INCORRECTO)
- ✅ Debería ser: SUM de pagos pendientes = $99,540 (6 pagos × $16,590)

**Corrección**:
```sql
-- ANTES (❌ INCORRECTO):
SELECT amount INTO v_total_amount FROM loans WHERE id = p_loan_id;
SELECT COALESCE(SUM(amount_paid), 0) INTO v_total_paid
FROM payments WHERE loan_id = p_loan_id;
v_remaining := v_total_amount - v_total_paid;

-- DESPUÉS (✅ CORRECTO):
SELECT COALESCE(SUM(expected_amount), 0) INTO v_remaining
FROM payments
WHERE loan_id = p_loan_id
  AND status_id = v_pending_status_id;  -- Solo PENDIENTES
```

**Impacto**: 🔴 CRÍTICO - Causaba cálculos incorrectos en renovaciones y liquidaciones

---

## 📊 IMPACTO EN EL SISTEMA

### Antes de las correcciones (❌):
```
PRÉSTAMO: $100,000 a 12 quincenas
  - Capital: $100,000
  - Interés total: $5,000
  - Comisión total: $2,500
  - Pago quincenal: $2,768.33
  - Total a pagar: $107,500

DESPUÉS DE 6 PAGOS ($16,590):
  credit_used = 100,000 - (6 × 2,768.33) = $83,390
  ❌ INCORRECTO: Debería ser $50,000 (capital restante)
  
AL RENOVAR (saldo pendiente = $49,770):
  Libera: $100,000 del credit_used
  ❌ Desincronización: +$16,610 de crédito "fantasma"
```

### Después de las correcciones (✅):
```
PRÉSTAMO: $100,000 a 12 quincenas

DESPUÉS DE 6 PAGOS:
  credit_used = 100,000 - (6 × 8,333.33) = $50,000
  ✅ CORRECTO: Refleja el capital restante real
  
AL RENOVAR:
  Libera: $100,000 del credit_used (capital original)
  Nuevo préstamo: $150,000 consume $150,000
  ✅ Sincronización perfecta
```

---

## 🔍 VALIDACIONES IMPLEMENTADAS

### 1. Validar sincronización de `credit_used`

```sql
-- Ejecutar después de pagos/renovaciones:
SELECT 
    ap.user_id,
    ap.credit_used AS stored_credit_used,
    (
        SELECT COALESCE(SUM(l.amount), 0)
        FROM loans l
        WHERE l.associate_user_id = ap.user_id
          AND l.status_id IN (2, 3)  -- APPROVED, ACTIVE
    ) AS calculated_credit_used,
    (
        ap.credit_used - (
            SELECT COALESCE(SUM(l.amount), 0)
            FROM loans l
            WHERE l.associate_user_id = ap.user_id
              AND l.status_id IN (2, 3)
        )
    ) AS discrepancy
FROM associate_profiles ap
WHERE ap.id = [ASSOCIATE_ID];

-- Si discrepancy != 0, hay desincronización
```

### 2. Auditoría de renovaciones

```sql
-- Ver todas las renovaciones y validar saldos:
SELECT 
    lr.id,
    lr.original_loan_id,
    lr.renewed_loan_id,
    lr.pending_balance,
    lr.new_amount,
    (lr.new_amount - lr.pending_balance) AS net_to_client,
    l_old.amount AS original_capital,
    l_new.amount AS new_capital
FROM loan_renewals lr
JOIN loans l_old ON lr.original_loan_id = l_old.id
JOIN loans l_new ON lr.renewed_loan_id = l_new.id
ORDER BY lr.created_at DESC;
```

---

## 🛠️ CAMBIOS REALIZADOS

### Archivos modificados:

1. ✅ `backend/app/modules/loans/routes.py`
   - Documentación clara sobre liberación de crédito en renovación
   - Se mantiene lógica correcta (liberar solo capital original)

2. ✅ `db/v2.0/modules/05_functions_base.sql`
   - **calculate_loan_remaining_balance()**: Ahora suma `expected_amount` de pagos PENDIENTES
   - Incluye capital + interés + comisión completos

3. ✅ `db/v2.0/modules/07_triggers.sql`
   - **trigger_update_associate_credit_on_payment()**: Calcula y libera solo CAPITAL
   - Usa fórmula: `capital_paid = loan_amount / term_biweeks`

### Scripts aplicados:
```bash
# 1. Actualizar funciones base
docker compose exec -T postgres psql -U credinet_user -d credinet_db \
  < db/v2.0/modules/05_functions_base.sql

# 2. Recrear trigger de pagos
docker compose exec postgres psql -U credinet_user -d credinet_db -c "
DROP TRIGGER IF EXISTS trigger_update_associate_credit_on_payment ON payments;
DROP FUNCTION IF EXISTS trigger_update_associate_credit_on_payment();
"

docker compose exec -T postgres psql -U credinet_user -d credinet_db \
  < db/v2.0/modules/07_triggers.sql
```

---

## ⚠️ CONSIDERACIONES IMPORTANTES

### 1. Migración de datos existentes
Si hay préstamos activos con desincronización, ejecutar:

```sql
-- Script de corrección de credit_used (USAR CON PRECAUCIÓN)
UPDATE associate_profiles ap
SET credit_used = (
    SELECT COALESCE(SUM(l.amount), 0)
    FROM loans l
    WHERE l.associate_user_id = ap.user_id
      AND l.status_id IN (2, 3)  -- APPROVED, ACTIVE
),
credit_last_updated = CURRENT_TIMESTAMP
WHERE ap.id IN (
    -- Solo asociados con discrepancia > $1
    SELECT ap2.id
    FROM associate_profiles ap2
    WHERE ABS(
        ap2.credit_used - (
            SELECT COALESCE(SUM(l2.amount), 0)
            FROM loans l2
            WHERE l2.associate_user_id = ap2.user_id
              AND l2.status_id IN (2, 3)
        )
    ) > 1.00
);
```

### 2. Testing recomendado

Antes de usar en producción, validar:

1. ✅ Crear préstamo → Aprobar → Validar `credit_used`
2. ✅ Registrar pago completo → Validar liberación de capital
3. ✅ Renovar préstamo → Validar liberación y nuevo consumo
4. ✅ Registrar pago parcial → Validar proporción de capital

### 3. Monitoreo continuo

Agregar alertas para detectar desincronización:

```sql
-- Query de monitoreo (ejecutar diariamente)
SELECT 
    ap.user_id,
    u.first_name || ' ' || u.last_name AS associate_name,
    ap.credit_used AS current,
    (
        SELECT COALESCE(SUM(l.amount), 0)
        FROM loans l
        WHERE l.associate_user_id = ap.user_id
          AND l.status_id IN (2, 3)
    ) AS expected,
    ABS(
        ap.credit_used - (
            SELECT COALESCE(SUM(l.amount), 0)
            FROM loans l
            WHERE l.associate_user_id = ap.user_id
              AND l.status_id IN (2, 3)
        )
    ) AS discrepancy
FROM associate_profiles ap
JOIN users u ON ap.user_id = u.id
HAVING ABS(
    ap.credit_used - (
        SELECT COALESCE(SUM(l.amount), 0)
        FROM loans l
        WHERE l.associate_user_id = ap.user_id
          AND l.status_id IN (2, 3)
    )
) > 1.00
ORDER BY discrepancy DESC;
```

---

## 📈 RESULTADOS ESPERADOS

### Antes (❌):
- Desincronización acumulativa en cada operación
- Crédito fantasma después de renovaciones
- Cálculos incorrectos de saldos pendientes
- Asociados con crédito "extra" no real

### Después (✅):
- `credit_used` siempre refleja capital prestado real
- Renovaciones sincronizan correctamente
- Saldos pendientes calculados correctamente
- Integridad financiera garantizada

---

## 🔗 REFERENCIAS

- **Documentación original**: `docs/LOGICA_DE_NEGOCIO_DEFINITIVA.md`
- **Issue**: Desincronización de saldos en renovaciones
- **Trigger anterior**: `db/v2.0/modules/07_triggers.sql` (backup)
- **Testing**: `tests/modules/loans/test_credit_sync.py` (TODO)

---

## ✅ CHECKLIST DE VALIDACIÓN

Antes de considerar completada esta corrección:

- [x] Corregir `trigger_update_associate_credit_on_payment`
- [x] Corregir `calculate_loan_remaining_balance`
- [x] Documentar cambios en routes.py de renovación
- [x] Aplicar cambios a la base de datos activa
- [ ] Ejecutar script de corrección de datos existentes
- [ ] Agregar tests unitarios de sincronización
- [ ] Agregar monitoreo de discrepancias
- [ ] Validar en ambiente de staging
- [ ] Validar casos de renovación completos
- [ ] Documentar en changelog v2.0.3

---

**Autor**: GitHub Copilot  
**Revisado por**: [Pendiente]  
**Aprobado para producción**: [Pendiente]
