# Análisis de legacy_payment_table
**Fecha**: 2025-11-18
**Contexto**: Comparación con PDF "TABLA PRESTAMOS CREDICUENTA - CALCULO VALES.pdf"

## Problema Identificado

La columna `associate_biweekly_payment` en la tabla `legacy_payment_table` presenta inconsistencias en el porcentaje de comisión aplicado.

## Datos Actuales en Base de Datos

| Monto | Pago Quincenal | Pago Asociado | Comisión | % Comisión | Desviación |
|------:|---------------:|--------------:|---------:|-----------:|-----------:|
| 3,000 | 392.00 | 337.00 | 55.00 | 14.03% | ⚠️ +1.94% |
| 4,000 | 510.00 | 446.00 | 64.00 | 12.55% | ✅ +0.46% |
| 5,000 | 633.00 | 553.00 | 80.00 | 12.64% | ✅ +0.55% |
| 6,000 | 752.00 | 662.00 | 90.00 | 11.97% | ✅ -0.12% |
| 7,000 | 882.00 | 770.00 | 112.00 | 12.70% | ✅ +0.61% |
| 7,500 | 962.50 | 827.00 | 135.50 | 14.08% | ⚠️ +1.99% |
| 8,000 | 1,006.00 | 886.00 | 120.00 | 11.93% | ✅ -0.16% |
| 9,000 | 1,131.00 | 996.00 | 135.00 | 11.94% | ✅ -0.15% |
| 10,000 | 1,255.00 | 1,105.00 | 150.00 | 11.95% | ✅ -0.14% |
| 11,000 | 1,385.00 | 1,220.00 | 165.00 | 11.91% | ✅ -0.18% |
| 12,000 | 1,504.00 | 1,330.00 | 174.00 | 11.57% | ⚠️ -0.52% |
| 13,000 | 1,634.00 | 1,440.00 | 194.00 | 11.87% | ✅ -0.22% |
| 14,000 | 1,765.00 | 1,550.00 | 215.00 | 12.18% | ✅ +0.09% |
| 15,000 | 1,888.00 | 1,660.00 | 228.00 | 12.08% | ✅ -0.01% |
| 16,000 | 2,012.00 | 1,770.00 | 242.00 | 12.03% | ✅ -0.06% |
| 17,000 | 2,137.00 | 1,880.00 | 257.00 | 12.03% | ✅ -0.06% |
| 18,000 | 2,262.00 | 1,990.00 | 272.00 | 12.02% | ✅ -0.07% |
| 19,000 | 2,386.00 | 2,100.00 | 286.00 | 11.99% | ✅ -0.10% |
| 20,000 | 2,510.00 | 2,210.00 | 300.00 | 11.95% | ✅ -0.14% |
| 21,000 | 2,640.00 | 2,320.00 | 320.00 | 12.12% | ✅ +0.03% |
| 22,000 | 2,759.00 | 2,430.00 | 329.00 | 11.92% | ✅ -0.17% |
| 23,000 | 2,889.00 | 2,540.00 | 349.00 | 12.08% | ✅ -0.01% |
| 24,000 | 3,020.00 | 2,650.00 | 370.00 | 12.25% | ✅ +0.16% |
| 25,000 | 3,143.00 | 2,760.00 | 383.00 | 12.19% | ✅ +0.10% |
| 26,000 | 3,267.00 | 2,870.00 | 397.00 | 12.15% | ✅ +0.06% |
| 27,000 | 3,392.00 | 2,980.00 | 412.00 | 12.15% | ✅ +0.06% |
| 28,000 | 3,517.00 | 3,090.00 | 427.00 | 12.14% | ✅ +0.05% |
| 29,000 | 3,641.00 | 3,200.00 | 441.00 | 12.11% | ✅ +0.02% |
| 30,000 | 3,765.00 | 3,310.00 | 455.00 | 12.08% | ✅ -0.01% |

**Promedio de comisión**: 12.09%  
**Mínimo**: 11.57% (en $12,000)  
**Máximo**: 14.08% (en $7,500)

## Registros con Mayor Desviación

### ⚠️ Crítico - Requiere Corrección
1. **$7,500**: 14.08% (debe estar en ~12.09%)
   - Pago asociado actual: $827.00
   - Pago asociado sugerido: $846.13
   - Diferencia: **+$19.13**

2. **$3,000**: 14.03% (debe estar en ~12.09%)
   - Pago asociado actual: $337.00
   - Pago asociado sugerido: $344.61
   - Diferencia: **+$7.61**

3. **$12,000**: 11.57% (debe estar en ~12.09%)
   - Pago asociado actual: $1,330.00
   - Pago asociado sugerido: $1,322.17
   - Diferencia: **-$7.83**

## Valores Correctos según PDF

⚠️ **PENDIENTE**: Comparar con valores del PDF "TABLA PRESTAMOS CREDICUENTA - CALCULO VALES.pdf"

Por favor, proporcionar los siguientes datos del PDF para validar:

```
Monto | Pago Quincenal Cliente | Pago Quincenal Asociado | Comisión
------|------------------------|-------------------------|----------
3,000  | 392.00                | ???                     | ???
4,000  | 510.00                | ???                     | ???
5,000  | 633.00                | ???                     | ???
...
```

## Solución Propuesta

### Opción 1: Normalizar a 12.09% (Promedio Actual)
Aplicar una tasa de comisión uniforme del 12.09% a todos los registros.

**SQL**:
```sql
UPDATE legacy_payment_table
SET associate_biweekly_payment = ROUND(biweekly_payment * (1 - 0.1209), 2)
WHERE id > 0;
```

### Opción 2: Usar valores del PDF (RECOMENDADO)
Actualizar los valores según la tabla oficial del PDF.

**Pendiente**: Obtener valores reales del documento.

## Respaldo Creado

✅ Tabla de respaldo: `legacy_payment_table_backup_2025_11_18`

## Archivos Relacionados

- SQL de migración: `/db/v2.0/modules/migration_019_fix_legacy_associate_payments.sql`
- Definición de tabla: `/db/v2.0/modules/10_rate_profiles.sql`
- PDF de referencia: `TABLA PRESTAMOS CREDICUENTA - CALCULO VALES.pdf` (proporcionado por usuario)

## Impacto

### Afecta a:
- ✅ Cálculo de préstamos con perfil "legacy"
- ✅ Tabla de referencia `rate_profile_reference_table`
- ✅ Endpoint `/api/v1/rate-profiles/legacy-payments`
- ✅ Función `calculate_loan_payment()` cuando usa `profile_code='legacy'`

### NO afecta a:
- ✅ Préstamos ya creados (usan valores almacenados)
- ✅ Perfiles de tasa con fórmula (`standard`, `premium`, etc.)
- ✅ Estados de cuenta ya generados

## Próximos Pasos

1. [ ] Revisar PDF y extraer valores correctos de pagos de asociado
2. [ ] Comparar valores del PDF con valores actuales
3. [ ] Decidir estrategia de corrección (normalizar vs usar PDF)
4. [ ] Ejecutar migración en ambiente de desarrollo
5. [ ] Validar cálculos con casos de prueba
6. [ ] Aplicar en producción con respaldo
7. [ ] Regenerar `rate_profile_reference_table` si es necesario
