# 🔍 ANÁLISIS: Problema de Aprobación con Perfiles No-Legacy

**Fecha**: 2025-11-13  
**Estado**: 🔴 CRÍTICO - Bloqueador  
**Afecta**: Aprobación de préstamos con perfiles `transition`, `standard`, `premium`

---

## 📋 Resumen Ejecutivo

### ✅ Lo que funciona:
- **Perfil Legacy**: Aprobación exitosa, pagos generados correctamente
- **Cálculo previo**: Todos los perfiles calculan correctamente en frontend
- **Creación de solicitud**: Todos los perfiles crean el loan request correctamente

### ❌ Lo que falla:
- **Aprobación de perfiles no-legacy**: Error 500 al intentar aprobar
- **Causa raíz**: Trigger `generate_payment_schedule()` espera campos que solo legacy calcula

---

## 🔬 Análisis Técnico

### Flujo Actual

```
1. CREACIÓN (POST /loans):
   ✅ Con profile_code → Llama calculate_loan_payment()
   ✅ Guarda: biweekly_payment, total_payment, commission_per_payment, etc.
   ✅ Status: PENDING

2. APROBACIÓN (POST /loans/:id/approve):
   ⚠️  Cambia status → APPROVED
   🔥 TRIGGER generate_payment_schedule() se dispara
   
3. TRIGGER (generate_payment_schedule):
   📍 Línea 86-88: Valida que biweekly_payment NO sea NULL
   📍 Línea 91: Valida que total_payment NO sea NULL  
   📍 Línea 95: Usa commission_per_payment (puede ser NULL → warning)
   
   ❌ PROBLEMA: Para perfiles no-legacy, estos valores son NULL en aprobación
```

### ¿Por qué legacy funciona?

**Perfil Legacy** (table_lookup):
- ✅ Usa tabla estática `legacy_payment_table`
- ✅ `calculate_loan_payment()` retorna TODOS los campos calculados
- ✅ Se guardan en `loans` durante creación
- ✅ Trigger los encuentra y genera pagos correctamente

**Perfiles Formula** (transition, standard, premium):
- ⚠️  Usan fórmulas matemáticas dinámicas
- ⚠️  `calculate_loan_payment()` SÍ calcula todo correctamente
- ⚠️  Se guardan en `loans` durante creación
- ❓ **PERO**: ¿Se están guardando realmente? Necesitamos verificar

---

## 🐛 Hipótesis del Bug

### Opción 1: No se están guardando los valores calculados

```python
# En create_loan_request() - líneas 164-177
calculated_values = {
    'biweekly_payment': Decimal(str(row.biweekly_payment)),
    'total_payment': Decimal(str(row.total_payment)),
    'total_interest': Decimal(str(row.total_interest)),
    'total_commission': Decimal(str(row.total_commission)),
    'commission_per_payment': Decimal(str(row.commission_per_payment)),
    'associate_payment': Decimal(str(row.associate_payment)),
}

# Más abajo - líneas 245-251
biweekly_payment=calculated_values['biweekly_payment'] if calculated_values else None,
total_payment=calculated_values['total_payment'] if calculated_values else None,
# ...
```

**Sospecha**: El `if calculated_values else None` siempre evalúa a `None` por alguna razón.

### Opción 2: El modelo/repositorio no persiste los campos

```python
# ¿El LoanModel tiene estos campos definidos?
# ¿El repository.create() los está insertando?
```

### Opción 3: Los campos son GENERATED y no aceptan INSERT

```sql
-- En la tabla loans, ¿hay algún campo definido como GENERATED?
-- Ejemplo problemático:
biweekly_payment DECIMAL(12,2) GENERATED ALWAYS AS (...) STORED
```

---

## 🔧 Solución Propuesta

### Fase 1: Diagnóstico (5 min)

1. **Verificar tabla `loans`**:
   ```sql
   \d loans
   -- Ver si biweekly_payment, total_payment, etc. son GENERATED
   ```

2. **Verificar LoanModel**:
   ```python
   # Ver si tiene los campos definidos correctamente
   ```

3. **Test de creación**:
   ```python
   # Crear loan con standard, verificar valores en BD
   SELECT id, biweekly_payment, total_payment, commission_per_payment
   FROM loans WHERE id = <nuevo_id>;
   ```

### Fase 2: Corrección Según Diagnóstico

#### Escenario A: Campos son GENERATED

**Problema**: PostgreSQL no permite INSERT/UPDATE en campos GENERATED

**Solución**:
```sql
-- Cambiar de GENERATED a campos normales
ALTER TABLE loans 
  ALTER COLUMN biweekly_payment DROP EXPRESSION,
  ALTER COLUMN total_payment DROP EXPRESSION,
  ALTER COLUMN commission_per_payment DROP EXPRESSION;
```

#### Escenario B: Modelo no tiene los campos

**Problema**: LoanModel no declara los campos

**Solución**:
```python
# En LoanModel, agregar:
biweekly_payment = Column(DECIMAL(12, 2), nullable=True)
total_payment = Column(DECIMAL(12, 2), nullable=True)
commission_per_payment = Column(DECIMAL(12, 2), nullable=True)
# ... resto de campos calculados
```

#### Escenario C: Repository no los persiste

**Problema**: El método `create()` no mapea los campos

**Solución**:
```python
# En PostgreSQLLoanRepository.create():
loan_model = LoanModel(
    # ... campos existentes ...
    biweekly_payment=loan.biweekly_payment,
    total_payment=loan.total_payment,
    commission_per_payment=loan.commission_per_payment,
    # ...
)
```

### Fase 3: Solución Alternativa Robusta

Si los campos no pueden ser persistidos por alguna razón de arquitectura:

**Opción**: Calcular valores DENTRO del trigger

```sql
CREATE OR REPLACE FUNCTION generate_payment_schedule()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $function$
DECLARE
    v_biweekly_payment DECIMAL(12,2);
    v_total_payment DECIMAL(12,2);
    v_commission_per_payment DECIMAL(12,2);
BEGIN
    -- Si los campos están NULL, calcularlos
    IF NEW.biweekly_payment IS NULL THEN
        -- Recalcular usando la función
        SELECT 
            biweekly_payment,
            total_payment,
            commission_per_payment
        INTO 
            v_biweekly_payment,
            v_total_payment,
            v_commission_per_payment
        FROM calculate_loan_payment(
            NEW.amount,
            NEW.term_biweeks,
            NEW.profile_code
        );
        
        -- Actualizar NEW para que tenga los valores
        NEW.biweekly_payment := v_biweekly_payment;
        NEW.total_payment := v_total_payment;
        NEW.commission_per_payment := v_commission_per_payment;
    END IF;
    
    -- Continuar con generación de pagos...
    -- ...
END;
$function$;
```

---

## 📊 Comparación de Enfoques

| Enfoque | Pros | Contras | Complejidad |
|---------|------|---------|-------------|
| **Persistir en creación** | ✅ Rápido<br>✅ Datos históricos<br>✅ No recalcula | ❌ Requiere migración si campos GENERATED | 🟢 Baja |
| **Recalcular en trigger** | ✅ Siempre correcto<br>✅ No requiere persistencia | ❌ Más lento<br>❌ Recalcula cada vez | 🟡 Media |
| **Híbrido (preferir persistido)** | ✅ Mejor de ambos mundos | ❌ Más código | 🟠 Media-Alta |

---

## 🎯 Recomendación

### Estrategia Recomendada: **Persistir en Creación + Fallback en Trigger**

1. **Verificar** que los campos NO sean GENERATED
2. **Asegurar** que el modelo y repository persistan los valores
3. **Agregar fallback** en trigger por si acaso:
   ```sql
   IF NEW.biweekly_payment IS NULL AND NEW.profile_code IS NOT NULL THEN
       -- Recalcular usando función
   ELSIF NEW.biweekly_payment IS NULL THEN
       RAISE EXCEPTION 'biweekly_payment es NULL y no hay profile_code para calcular';
   END IF;
   ```

### Ventajas:
- ✅ **Performance**: No recalcula si ya está guardado
- ✅ **Robustez**: Fallback si algo falla
- ✅ **Histórico**: Datos guardados permanentemente
- ✅ **Backward compatible**: Funciona con legacy y nuevos perfiles

---

## 🚀 Plan de Acción Inmediato

### Paso 1: Diagnóstico (AHORA - 2 min)
```sql
-- Ejecutar en DB
\d loans
-- Buscar: biweekly_payment, total_payment, commission_per_payment
-- Ver si dice GENERATED
```

### Paso 2: Verificar Persistencia (AHORA - 3 min)
```sql
-- Crear préstamo con standard en frontend
-- Luego consultar:
SELECT 
    id, 
    profile_code,
    amount,
    term_biweeks,
    biweekly_payment,
    total_payment,
    commission_per_payment,
    status_id
FROM loans 
WHERE profile_code = 'standard'
ORDER BY id DESC 
LIMIT 1;
```

### Paso 3: Aplicar Fix (5-10 min)
- Si campos son NULL → Verificar modelo y repository
- Si campos son GENERATED → Cambiar a normales
- Si todo está OK → Agregar fallback en trigger

### Paso 4: Probar (2 min)
- Crear préstamo con standard
- Aprobar
- Verificar que se generen pagos

---

## 📝 Notas Adicionales

### Diferencia Clave: Legacy vs Formula

**Legacy** (funcionando):
```
CREATE → calculate_loan_payment(5000, 12, 'legacy')
       → Busca en legacy_payment_table
       → Retorna valores estáticos
       → Se guardan en loans
APPROVE → Trigger lee valores guardados
        → Genera 12 pagos
```

**Standard** (fallando):
```
CREATE → calculate_loan_payment(22000, 12, 'standard')
       → Calcula con fórmula (4.25% interés, 5% comisión)
       → Retorna valores dinámicos
       → ⚠️  ¿Se guardan en loans?
APPROVE → Trigger intenta leer valores
        → ❌ Son NULL?
        → 🔥 EXCEPTION
```

### Pregunta Crítica

**¿Por qué funcionaba la creación pero no la aprobación?**

Respuesta: La creación NO valida que los valores se hayan guardado.
Solo valida:
1. ✅ Crédito disponible
2. ✅ No tiene PENDING
3. ✅ No es moroso

Pero NO verifica:
- ❌ Que biweekly_payment se haya guardado
- ❌ Que total_payment se haya guardado

Por eso el error aparece hasta **APROBAR**, cuando el **TRIGGER** requiere esos campos.

---

## 🔗 Archivos Relacionados

- **Servicio de creación**: `backend/app/modules/loans/application/services/__init__.py` (líneas 62-250)
- **Trigger**: `db/v2.0/modules/06_functions_business.sql` (líneas 1-250)
- **Endpoint aprobación**: `backend/app/modules/loans/routes.py` (líneas 379-450)
- **Función SQL**: `db/v2.0/modules/09_functions_calculations.sql` (calculate_loan_payment)

---

**Siguiente paso**: Ejecutar diagnóstico y reportar hallazgos.
