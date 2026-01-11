# 🔧 CORRECCIÓN DE PRÉSTAMOS - 2026-01-11

## 📋 Resumen Ejecutivo

Se identificaron y corrigieron dos problemas críticos en el sistema de préstamos:

1. ✅ **Cálculos incorrectos del asociado en preview**: Los valores del asociado se calculaban manualmente en el frontend en lugar de usar los valores pre-calculados del backend.

2. ✅ **"N/A" en períodos de préstamos**: Los préstamos con plazos largos tenían pagos que caían fuera del rango de períodos disponibles en `cut_periods`, causando que el sistema los insertara con `cut_period_id = NULL`.

---

## 🐛 Problemas Identificados

### Problema 1: Cálculos del Asociado en LoanSummaryDisplay

**Síntoma:**
- Los valores del asociado (pago quincenal, total a pagar, comisión) se mostraban incorrectos en el detalle del préstamo.

**Causa Raíz:**
- El componente `LoanSummaryDisplay.jsx` calculaba todos los valores manualmente:
  ```jsx
  const commissionPerPayment = (amount * commissionRate) / 100;
  const associatePayment = biweeklyPayment - commissionPerPayment;
  const totalCommission = commissionPerPayment * termBiweeks;
  const associateTotal = associatePayment * termBiweeks;
  ```
- Esto ignoraba los valores pre-calculados que ya venían del backend en los campos:
  - `loan.associate_payment`
  - `loan.total_commission`
  - `loan.commission_per_payment`
  - `loan.total_interest`

**Impacto:**
- Datos inconsistentes entre el backend y el frontend
- Posibles errores de redondeo
- No reflejaba la lógica compleja de cálculo del backend

---

### Problema 2: "N/A" en Períodos de Préstamos

**Síntoma:**
- Al aprobar préstamos con plazos largos (ej: 52 quincenas = 26 meses), algunos pagos aparecían con período "N/A" en los reportes y tablas de amortización.

**Causa Raíz:**
- La tabla `cut_periods` solo contenía períodos hasta `2027-01-07`.
- Si se aprobaba un préstamo en enero 2026 con 52 quincenas, las últimas fechas de pago caían en 2028, fuera del rango disponible.
- El trigger `generate_payment_schedule()` tiene esta lógica:
  ```sql
  SELECT id INTO v_period_id
  FROM cut_periods
  WHERE period_start_date <= v_amortization_row.fecha_pago
    AND period_end_date >= v_amortization_row.fecha_pago;
  
  IF v_period_id IS NULL THEN
      RAISE WARNING 'No se encontró cut_period para fecha %. 
                     Insertando pago con period_id = NULL.';
  END IF;
  ```
- Esto causaba que los pagos se insertaran con `cut_period_id = NULL`.
- En la consulta del endpoint `/loans/{id}/schedule`, el `COALESCE(cp.cut_code, 'N/A')` mostraba "N/A" para estos pagos.

**Impacto:**
- Pagos sin período asignado en la base de datos
- Reportes incompletos
- Imposibilidad de asociar pagos a períodos administrativos
- Cálculos de comisiones y statements incorrectos

---

## ✅ Soluciones Implementadas

### Solución 1: Corregir LoanSummaryDisplay para Usar Valores Pre-calculados

**Archivo Modificado:**
- `frontend-mvp/src/features/loans/components/LoanSummaryDisplay/LoanSummaryDisplay.jsx`

**Cambios:**
```jsx
// ANTES - Cálculo manual (incorrecto)
const totalInterest = totalPayment - amount;
const commissionPerPayment = (amount * commissionRate) / 100;
const associatePayment = biweeklyPayment - commissionPerPayment;
const totalCommission = commissionPerPayment * termBiweeks;
const associateTotal = associatePayment * termBiweeks;

// DESPUÉS - Usar valores pre-calculados del backend
const totalInterest = parseFloat(loan.total_interest) || (totalPayment - amount);
const commissionPerPayment = parseFloat(loan.commission_per_payment) || ((amount * commissionRate) / 100);
const associatePayment = parseFloat(loan.associate_payment) || (biweeklyPayment - commissionPerPayment);
const totalCommission = parseFloat(loan.total_commission) || (commissionPerPayment * termBiweeks);
const associateTotal = (associatePayment * termBiweeks);
```

**Beneficios:**
- ✅ Datos consistentes entre backend y frontend
- ✅ Refleja la lógica compleja de cálculo del backend (incluyendo `generate_loan_summary`, `calculate_loan_payment`, etc.)
- ✅ Fallback a cálculo manual solo si el backend no envía los valores (compatibilidad hacia atrás)

---

### Solución 2: Extender Períodos hasta 2028

**Archivo Creado:**
- `db/v2.0/migrations/migration_028_extend_cut_periods_to_2028.sql`

**Descripción:**
- Agrega 48 períodos nuevos (2027-2028), extendiendo la cobertura hasta `2029-01-07`.
- Esto garantiza que préstamos aprobados hoy con el plazo máximo (52 quincenas) tengan períodos asignados para todos sus pagos.

**Estructura:**
- Alternancia: día 15 (Período A) y último día del mes (Período B)
- Status: PENDING para períodos futuros
- Continúa la numeración secuencial desde el último `cut_number`

**Cobertura:**
- **Antes:** 2024-01-08 hasta 2027-01-07 (24 períodos de 2026-2027)
- **Después:** 2024-01-08 hasta 2029-01-07 (72 períodos totales)

**Cómo Ejecutar:**
```bash
# Opción 1: Docker
docker compose exec db psql -U credinet_user -d credinet_db -f /migrations/migration_028_extend_cut_periods_to_2028.sql

# Opción 2: Conexión directa
psql -h localhost -p 5433 -U credinet_user -d credinet_db -f db/v2.0/migrations/migration_028_extend_cut_periods_to_2028.sql
```

---

## 🔍 Verificación

### Verificar Corrección 1 (Frontend)

1. Crear un préstamo nuevo
2. Ver el detalle del préstamo
3. Comparar los valores del asociado con los del backend:
   - Abrir DevTools → Network → Ver respuesta del endpoint `GET /loans/{id}`
   - Verificar que los valores mostrados coincidan con:
     - `associate_payment`
     - `total_commission`
     - `commission_per_payment`

### Verificar Corrección 2 (Períodos)

**Antes de la migración:**
```sql
SELECT COUNT(*), MAX(period_end_date) FROM cut_periods;
-- Resultado esperado: ~24 períodos, última fecha: 2027-01-07
```

**Después de la migración:**
```sql
SELECT COUNT(*), MAX(period_end_date) FROM cut_periods;
-- Resultado esperado: ~72 períodos, última fecha: 2029-01-07
```

**Probar aprobación de préstamo largo:**
```sql
-- 1. Crear préstamo con 52 quincenas
INSERT INTO loans (..., term_biweeks) VALUES (..., 52);

-- 2. Aprobarlo (esto dispara generate_payment_schedule)
UPDATE loans SET status_id = 2, approved_at = NOW() WHERE id = {LOAN_ID};

-- 3. Verificar que todos los pagos tienen período asignado
SELECT 
    p.payment_number,
    p.payment_due_date,
    p.cut_period_id,
    cp.cut_code
FROM payments p
LEFT JOIN cut_periods cp ON p.cut_period_id = cp.id
WHERE p.loan_id = {LOAN_ID}
ORDER BY p.payment_number;

-- ✅ Todos los cut_period_id deben ser NOT NULL
-- ✅ Ningún cut_code debe ser NULL
```

---

## 📊 Análisis de Impacto

### Préstamos Afectados

**Préstamos PENDING:**
- ✅ No requieren corrección (no tienen pagos generados aún)
- ✅ Al aprobarlos ahora, tendrán todos los períodos asignados correctamente

**Préstamos ACTIVE con "N/A":**
Si hay préstamos activos con pagos sin período, se debe ejecutar un script de corrección:

```sql
-- Script de corrección (CUIDADO: ejecutar solo después de migration_028)
DO $$
DECLARE
    v_payment RECORD;
    v_period_id INTEGER;
BEGIN
    FOR v_payment IN
        SELECT id, payment_due_date
        FROM payments
        WHERE cut_period_id IS NULL
    LOOP
        -- Buscar período correspondiente
        SELECT id INTO v_period_id
        FROM cut_periods
        WHERE period_start_date <= v_payment.payment_due_date
          AND period_end_date >= v_payment.payment_due_date
        LIMIT 1;
        
        IF v_period_id IS NOT NULL THEN
            UPDATE payments
            SET cut_period_id = v_period_id,
                updated_at = NOW()
            WHERE id = v_payment.id;
            
            RAISE NOTICE 'Pago % corregido: period_id=%', v_payment.id, v_period_id;
        ELSE
            RAISE WARNING 'Pago % sin período disponible para fecha %', 
                v_payment.id, v_payment.payment_due_date;
        END IF;
    END LOOP;
END $$;
```

---

## 🎯 Recomendaciones Futuras

### 1. Monitoreo de Períodos
Crear un job o alerta que verifique si quedan suficientes períodos futuros:

```sql
CREATE OR REPLACE FUNCTION check_period_coverage()
RETURNS TABLE(
    periods_remaining INTEGER,
    last_period_date DATE,
    months_coverage NUMERIC
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_max_date DATE;
    v_count INTEGER;
BEGIN
    SELECT MAX(period_end_date), COUNT(*)
    INTO v_max_date, v_count
    FROM cut_periods
    WHERE period_end_date > CURRENT_DATE;
    
    RETURN QUERY
    SELECT 
        v_count,
        v_max_date,
        ROUND(EXTRACT(EPOCH FROM (v_max_date - CURRENT_DATE)) / 2592000, 1); -- meses
END $$;

-- Ejecutar mensualmente
SELECT * FROM check_period_coverage();
-- Si months_coverage < 24, generar más períodos
```

### 2. Generación Automática de Períodos
Modificar el sistema para que genere períodos automáticamente cuando sea necesario:

```sql
CREATE OR REPLACE FUNCTION ensure_period_for_date(p_date DATE)
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_period_id INTEGER;
    -- Lógica para generar período si no existe
BEGIN
    -- Buscar período existente
    SELECT id INTO v_period_id
    FROM cut_periods
    WHERE period_start_date <= p_date
      AND period_end_date >= p_date;
    
    -- Si no existe, generarlo dinámicamente
    IF v_period_id IS NULL THEN
        -- TODO: Lógica de generación automática
        RAISE EXCEPTION 'Período no existe para fecha %. Ejecutar migration_028.', p_date;
    END IF;
    
    RETURN v_period_id;
END $$;
```

### 3. Validación Pre-Aprobación
Agregar validación en `LoanService.approve_loan()` para verificar que existan períodos suficientes:

```python
async def _validate_period_coverage(self, loan: Loan) -> None:
    """
    Valida que existan períodos suficientes para todas las fechas de pago.
    """
    from datetime import date, timedelta
    
    # Calcular fecha del último pago (aproximado)
    approval_date = date.today()
    # 52 quincenas = ~26 meses
    last_payment_date = approval_date + timedelta(days=loan.term_biweeks * 15)
    
    # Verificar que exista un período que cubra esa fecha
    query = text("""
        SELECT COUNT(*) FROM cut_periods
        WHERE period_end_date >= :last_payment_date
    """)
    
    result = await self.session.execute(query, {"last_payment_date": last_payment_date})
    count = result.scalar()
    
    if count == 0:
        raise ValueError(
            f"No hay períodos administrativos disponibles hasta {last_payment_date}. "
            f"Contacte al administrador para extender los períodos."
        )
```

---

## 📝 Conclusión

Los cambios implementados corrigen dos problemas críticos:

1. ✅ **Datos consistentes**: Los valores del asociado ahora se toman del backend pre-calculado
2. ✅ **Períodos completos**: Todos los préstamos hasta 52 quincenas (2 años) tendrán períodos asignados

**Próximos Pasos:**
1. Ejecutar `migration_028_extend_cut_periods_to_2028.sql`
2. Verificar que no haya pagos con `cut_period_id = NULL`
3. Si existen, ejecutar el script de corrección
4. Implementar monitoreo de cobertura de períodos

**Archivos Modificados/Creados:**
- ✅ `frontend-mvp/src/features/loans/components/LoanSummaryDisplay/LoanSummaryDisplay.jsx`
- ✅ `db/v2.0/migrations/migration_028_extend_cut_periods_to_2028.sql`
