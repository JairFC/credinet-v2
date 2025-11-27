# Análisis de legacy_payment_table - COMPLETADO ✅
**Fecha**: 2025-11-18  
**Actualizado**: 2025-11-18  
**Contexto**: Comparación exhaustiva con PDF "TABLA PRESTAMOS CREDICUENTA - CALCULO VALES.pdf"

## ✅ Análisis Completado

Se realizó una comparación detallada entre la base de datos y el PDF oficial (fuente de verdad).

## 🎯 Hallazgos Principales

### Resumen Ejecutivo
- ✅ **5 montos correctos** ($3k, $4k, $5k, $6k, $7k)
- ❌ **23 montos incorrectos** (desde $8k hasta $30k)
- 🗑️ **1 monto a eliminar** ($7,500 - NO aparece en PDF oficial)
- ✅ **Todos los pagos de cliente están correctos**
- ❌ **Los pagos de asociado tienen errores sistemáticos**
- 🎯 **Resultado final: 28 registros** (exactamente como el PDF)

### Patrón de Error Detectado

Los errores en los pagos de asociado aumentan con el monto del préstamo:

| Rango | Error Promedio | Máximo Error |
|-------|----------------|--------------|
| $8k - $10k | +$9 | +$10 |
| $11k - $15k | +$9 | +$12 |
| $16k - $20k | +$17 | +$20 |
| $21k - $25k | +$13 | +$17 |
| $26k - $30k | +$21 | +$25 |

## 📊 Comparación Detallada PDF vs Base de Datos

### ✅ Montos Correctos (5)

| Monto | Pago Cliente | Pago Asociado | Comisión | Estado |
|------:|-------------:|--------------:|---------:|--------|
| $3,000 | $392 | $337 | $55 | ✅ OK |
| $4,000 | $510 | $446 | $64 | ✅ OK |
| $5,000 | $633 | $553 | $80 | ✅ OK |
| $6,000 | $752 | $662 | $90 | ✅ OK |
| $7,000 | $882 | $770 | $112 | ✅ OK |

### ❌ Montos Incorrectos (23)

Todos tienen el **pago de cliente correcto** pero el **pago de asociado incorrecto**.

| Monto | PDF Asociado | DB Asociado | Diferencia | PDF Comisión | DB Comisión | Error |
|------:|-------------:|------------:|-----------:|-------------:|------------:|------:|
| $8,000 | $878 | $886 | +$8 | $128 | $120 | -$8 |
| $9,000 | $987 | $996 | +$9 | $144 | $135 | -$9 |
| $10,000 | $1,095 | $1,105 | +$10 | $160 | $150 | -$10 |
| $11,000 | $1,215 | $1,220 | +$5 | $170 | $165 | -$5 |
| $12,000 | $1,324 | $1,330 | +$6 | $180 | $174 | -$6 |
| $13,000 | $1,432 | $1,440 | +$8 | $202 | $194 | -$8 |
| $14,000 | $1,541 | $1,550 | +$9 | $224 | $215 | -$9 |
| $15,000 | $1,648 | $1,660 | +$12 | $240 | $228 | -$12 |
| $16,000 | $1,756 | $1,770 | +$14 | $256 | $242 | -$14 |
| $17,000 | $1,865 | $1,880 | +$15 | $272 | $257 | -$15 |
| $18,000 | $1,974 | $1,990 | +$16 | $288 | $272 | -$16 |
| $19,000 | $2,082 | $2,100 | +$18 | $304 | $286 | -$18 |
| $20,000 | $2,190 | $2,210 | +$20 | $320 | $300 | -$20 |
| $21,000 | $2,310 | $2,320 | +$10 | $330 | $320 | -$10 |
| $22,000 | $2,419 | $2,430 | +$11 | $340 | $329 | -$11 |
| $23,000 | $2,527 | $2,540 | +$13 | $362 | $349 | -$13 |
| $24,000 | $2,636 | $2,650 | +$14 | $384 | $370 | -$14 |
| $25,000 | $2,743 | $2,760 | +$17 | $400 | $383 | -$17 |
| $26,000 | $2,851 | $2,870 | +$19 | $416 | $397 | -$19 |
| $27,000 | $2,960 | $2,980 | +$20 | $432 | $412 | -$20 |
| $28,000 | $3,069 | $3,090 | +$21 | $448 | $427 | -$21 |
| $29,000 | $3,177 | $3,200 | +$23 | $464 | $441 | -$23 |
| $30,000 | $3,285 | $3,310 | +$25 | $480 | $455 | -$25 |

### 🗑️ Monto a Eliminar (1)

| Monto | DB Asociado | DB Cliente | Razón |
|------:|------------:|-----------:|-------|
| $7,500 | $827 | $962.50 | 🗑️ NO aparece en el PDF oficial - Será eliminado |

**Decisión tomada**: Este monto será **eliminado completamente** de ambas tablas (`legacy_payment_table` y `rate_profile_reference_table`) porque no aparece en el PDF oficial que es la fuente de verdad.

## 🔍 Análisis de la Discrepancia

### Causa Raíz

El error parece ser sistemático: **la base de datos tiene pagos de asociado MÁS ALTOS** de lo que debería (lo que resulta en comisiones más bajas para Credicuenta).

### Implicaciones

1. **Para el Cliente**: ✅ Los pagos son correctos
2. **Para el Asociado**: ❌ Está recibiendo más de lo que debería
3. **Para Credicuenta**: ❌ La comisión es menor de la esperada

### Ejemplo Concreto

**Monto: $30,000**
- Cliente paga: $3,765 (✅ correcto)
- PDF dice que asociado recibe: $3,285
- DB dice que asociado recibe: $3,310 (**+$25 de más**)
- Comisión PDF: $480
- Comisión DB: $455 (**-$25 menos para Credicuenta**)

## 🔧 Solución Implementada

### Archivo de Migración

`/db/v2.0/modules/migration_020_fix_legacy_associate_payments_from_pdf.sql`

### Acciones

1. ✅ Crear respaldo de la tabla actual
2. ✅ Actualizar 23 montos con valores correctos del PDF
3. ✅ Regenerar tabla de referencia `rate_profile_reference_table`
4. ⚠️ Mantener $7,500 (decisión pendiente)

### Impacto del Error

**Pérdida estimada por comisión reducida:**
- Error promedio por pago: ~$14
- Error total en 23 montos: ~$322 por ciclo quincenal
- Si hay múltiples préstamos activos, el impacto se multiplica

## 🚀 Cómo Aplicar la Corrección

### Paso 1: Ejecutar Migración

```bash
# Conectarse a la base de datos
docker compose exec postgres psql -U credinet_user -d credinet_db

# Ejecutar el archivo de migración
\i /docker-entrypoint-initdb.d/modules/migration_020_fix_legacy_associate_payments_from_pdf.sql
```

### Paso 2: Verificar Correcciones

```sql
-- Ver todos los registros corregidos
SELECT 
    amount,
    biweekly_payment as pago_cliente,
    associate_biweekly_payment as pago_asociado,
    commission_per_payment as comision,
    ROUND((commission_per_payment / biweekly_payment * 100)::NUMERIC, 2) as porcentaje
FROM legacy_payment_table
ORDER BY amount;
```

### Paso 3: Verificar Eliminación de $7,500

✅ **Decisión tomada**: El monto $7,500 será **eliminado** porque NO aparece en el PDF oficial.

La migración incluye:
```sql
-- Eliminar de tabla de referencia
DELETE FROM rate_profile_reference_table 
WHERE profile_code = 'legacy' AND amount = 7500;

-- Eliminar de tabla legacy
DELETE FROM legacy_payment_table WHERE amount = 7500;
```

Después de la migración, la tabla tendrá **exactamente 28 registros** que coinciden con el PDF.

## 📝 Archivos Creados/Modificados

### Scripts de Análisis
- ✅ `compare_legacy_data.py` - Script de comparación Python
- ✅ `datos_pdf_legacy.txt` - Datos extraídos del PDF

### Migraciones SQL
- ✅ `migration_020_fix_legacy_associate_payments_from_pdf.sql` - Corrección completa

### Documentación
- ✅ `ANALISIS_LEGACY_PAYMENT_TABLE.md` - Este documento (actualizado)

## 🔍 Uso en el Código

### Donde se Usa la Tabla Legacy

1. **Función `calculate_loan_payment()`**
   - Archivo: `/db/v2.0/modules/10_rate_profiles.sql`
   - Cuando `calculation_type = 'table_lookup'`
   - Lee directamente de `legacy_payment_table`

2. **Endpoint de Simulación**
   - Ruta: `/api/v1/loans/simulate`
   - Usa la función `calculate_loan_payment()`
   - Afectado por los valores incorrectos

3. **Endpoint de Creación de Préstamos**
   - Ruta: `/api/v1/loans/`
   - Usa la función `calculate_loan_payment()`
   - Afectado por los valores incorrectos

4. **Tabla de Referencia**
   - `rate_profile_reference_table`
   - Se regenera desde `legacy_payment_table`
   - Debe actualizarse después de la corrección

## ✅ Checklist de Validación

Después de aplicar la migración, verificar:

- [ ] ✅ Los 5 montos correctos siguen igual
- [ ] ✅ Los 23 montos incorrectos están corregidos
- [ ] ✅ El monto $7,500 fue eliminado (no está en PDF)
- [ ] ✅ La tabla tiene exactamente 28 registros (como el PDF)
- [ ] ✅ La tabla de referencia está actualizada
- [ ] ✅ El respaldo existe (`legacy_payment_table_backup_before_pdf_fix`)
- [ ] 🧪 Probar simulación con monto $10,000
- [ ] 🧪 Probar simulación con monto $30,000
- [ ] 🧪 Verificar que comisiones sean las del PDF

## 📊 Impacto en Préstamos Existentes

**IMPORTANTE**: Esta corrección **NO afecta** préstamos ya creados porque:

1. Los préstamos almacenan los valores calculados en el momento de creación
2. No recalculan usando la tabla legacy después de creados
3. Solo afecta nuevas simulaciones y nuevos préstamos

## 🎯 Conclusión

**Problema identificado**: ✅ Completamente analizado  
**Solución preparada**: ✅ Migración SQL lista  
**Fuente de verdad**: ✅ PDF oficial verificado  
**Impacto**: ⚠️ 23 montos a corregir + 1 a eliminar  
**Resultado final**: 🎯 28 registros exactos según PDF  
**Riesgo**: 🟢 Bajo - solo afecta nuevos cálculos  

**Acciones de la migración**:
1. Corregir 23 pagos de asociado ($8k - $30k)
2. Mantener 5 montos correctos ($3k - $7k)
3. **Eliminar $7,500** (no aparece en PDF)
4. Regenerar tabla de referencia

**Recomendación**: Aplicar la migración lo antes posible para asegurar que todas las nuevas simulaciones y préstamos usen los valores correctos del PDF oficial.

---

**Última actualización**: 2025-11-18  
**Estado**: ✅ Análisis completado - Migración lista para aplicar
