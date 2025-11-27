# 📅 CICLO DE VIDA COMPLETO: PAGOS Y PERIODOS

**Fecha**: 26 de Noviembre de 2025  
**Contexto**: Análisis detallado del sistema de doble calendario y propuesta de nomenclatura mejorada

---

## 🎯 RESUMEN EJECUTIVO

### Estado Actual
- ✅ **72 periodos** precargados (2024-2027) → **3 años de cobertura**
- ✅ **Lógica de asignación correcta**: Pagos asignados al periodo que **CIERRA ANTES** de la fecha de pago
- ⚠️ **Nomenclatura confusa**: `Dec07-2025` representa el día que **CIERRA**, no el día que **IMPRIME**

### Problema de Nomenclatura
```
Nomenclatura Actual:  "Dec07-2025"
Representa:           Periodo que cierra el 7 de diciembre
Se imprime:           El 8 de diciembre (día siguiente al cierre)
Confusión:            ❌ Los usuarios piensan "Dec07" = día 7 de impresión
                      ✅ Pero realmente "Dec07" = día 7 de cierre
```

---

## 🔄 DOBLE CALENDARIO: CÓMO FUNCIONA

### Calendario del Cliente (Fechas de Pago)
- **Día 15** de cada mes
- **Último día** de cada mes (28, 29, 30 o 31)

### Calendario Administrativo (Fechas de Impresión)
- **Día 8** → Imprime pagos que vencen el día 15
- **Día 23** → Imprime pagos que vencen el último día

### Regla de Asignación
```
PAGO DEL DÍA 15  → Periodo que CIERRA día 7  → Se IMPRIME día 8
PAGO ÚLTIMO DÍA  → Periodo que CIERRA día 22 → Se IMPRIME día 23
```

---

## 📊 ESTRUCTURA ACTUAL DE PERIODOS

### Cobertura
```sql
Primera fecha:   2024-01-08
Última fecha:    2027-01-07
Total periodos:  72
Años cobertura:  3.0
```

### Patrón de Periodos (Ejemplo Diciembre 2025)
```
┌─────────────────────────────────────────────────────────────────┐
│ PERIODO 1: Dec07-2025                                           │
│ Inicia:    23/Nov/2025                                          │
│ Cierra:    07/Dec/2025  ← Día de cierre                         │
│ Imprime:   08/Dec/2025  ← Día de impresión de statements        │
│ Contiene:  Pagos que vencen el 15/Dec/2025                      │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ PERIODO 2: Dec22-2025                                           │
│ Inicia:    08/Dec/2025                                          │
│ Cierra:    22/Dec/2025  ← Día de cierre                         │
│ Imprime:   23/Dec/2025  ← Día de impresión de statements        │
│ Contiene:  Pagos que vencen el 31/Dec/2025                      │
└─────────────────────────────────────────────────────────────────┘
```

### Datos Reales (Primeros 20 periodos)
| ID | Cut Code    | Inicio     | Cierre     | Día Cierre | Imprime    | Duración |
|----|-------------|------------|------------|------------|------------|----------|
| 1  | Jan22-2024  | 2024-01-08 | 2024-01-22 | 22         | 23/Ene     | 15 días  |
| 2  | Feb07-2024  | 2024-01-23 | 2024-02-07 | 7          | 08/Feb     | 16 días  |
| 3  | Feb22-2024  | 2024-02-08 | 2024-02-22 | 22         | 23/Feb     | 15 días  |
| 4  | Mar07-2024  | 2024-02-23 | 2024-03-07 | 7          | 08/Mar     | 14 días  |
| 5  | Mar22-2024  | 2024-03-08 | 2024-03-22 | 22         | 23/Mar     | 15 días  |
| 6  | Apr07-2024  | 2024-03-23 | 2024-04-07 | 7          | 08/Abr     | 16 días  |
| 7  | Apr22-2024  | 2024-04-08 | 2024-04-22 | 22         | 23/Abr     | 15 días  |
| 8  | May07-2024  | 2024-04-23 | 2024-05-07 | 7          | 08/May     | 15 días  |
| 9  | May22-2024  | 2024-05-08 | 2024-05-22 | 22         | 23/May     | 15 días  |
| 10 | Jun07-2024  | 2024-05-23 | 2024-06-07 | 7          | 08/Jun     | 16 días  |

---

## 🎬 CICLO DE VIDA COMPLETO: EJEMPLO REAL

### Escenario: Préstamo aprobado el 23 de Noviembre de 2025

```
┌──────────────────────────────────────────────────────────────────────┐
│ PRÉSTAMO #56                                                         │
│ Aprobado:      23/Nov/2025                                           │
│ Monto:         $5,000                                                │
│ Perfil:        Standard                                              │
│ Plazo:         12 quincenas (6 meses)                                │
│ Primera Pago:  15/Dic/2025 (calculado por calculate_first_payment)  │
└──────────────────────────────────────────────────────────────────────┘
```

### Primeros 6 Pagos: Ciclo de Vida Detallado

#### PAGO #1: 15/Dic/2025
```
┌─────────────────────────────────────────────────────────────────────┐
│ 📅 FECHA DE PAGO (CLIENTE):   15/Dic/2025                           │
│ 📋 PERIODO ASIGNADO:          Dec07-2025                            │
│                                                                      │
│ 📍 PERIODO TIMELINE:                                                │
│    • Inicia:      23/Nov/2025                                       │
│    • Cierra:      07/Dic/2025  ← Fin del periodo                    │
│    • Se Imprime:  08/Dic/2025  ← Statement generado este día        │
│                                                                      │
│ 💰 MONTO:         $614.58                                           │
│ 📊 ESTADO:        PENDING                                           │
│                                                                      │
│ 🔄 LÓGICA:                                                          │
│    Pago del día 15 → Asignado al periodo que cierra día 7 ANTES     │
│    Razón: El statement debe generarse el 08/Dic (7 días antes)     │
└─────────────────────────────────────────────────────────────────────┘
```

#### PAGO #2: 31/Dic/2025
```
┌─────────────────────────────────────────────────────────────────────┐
│ 📅 FECHA DE PAGO (CLIENTE):   31/Dic/2025                           │
│ 📋 PERIODO ASIGNADO:          Dec22-2025                            │
│                                                                      │
│ 📍 PERIODO TIMELINE:                                                │
│    • Inicia:      08/Dic/2025                                       │
│    • Cierra:      22/Dic/2025  ← Fin del periodo                    │
│    • Se Imprime:  23/Dic/2025  ← Statement generado este día        │
│                                                                      │
│ 💰 MONTO:         $614.58                                           │
│ 📊 ESTADO:        PENDING                                           │
│                                                                      │
│ 🔄 LÓGICA:                                                          │
│    Pago último día → Asignado al periodo que cierra día 22 ANTES    │
│    Razón: El statement debe generarse el 23/Dic (8 días antes)     │
└─────────────────────────────────────────────────────────────────────┘
```

#### PAGO #3: 15/Ene/2026
```
┌─────────────────────────────────────────────────────────────────────┐
│ 📅 FECHA DE PAGO (CLIENTE):   15/Ene/2026                           │
│ 📋 PERIODO ASIGNADO:          Jan07-2026                            │
│ 📍 Se Imprime:                08/Ene/2026                           │
│ 💰 MONTO:                     $614.58                               │
└─────────────────────────────────────────────────────────────────────┘
```

#### PAGO #4: 31/Ene/2026
```
┌─────────────────────────────────────────────────────────────────────┐
│ 📅 FECHA DE PAGO (CLIENTE):   31/Ene/2026                           │
│ 📋 PERIODO ASIGNADO:          Jan22-2026                            │
│ 📍 Se Imprime:                23/Ene/2026                           │
│ 💰 MONTO:                     $614.58                               │
└─────────────────────────────────────────────────────────────────────┘
```

#### PAGO #5: 15/Feb/2026
```
┌─────────────────────────────────────────────────────────────────────┐
│ 📅 FECHA DE PAGO (CLIENTE):   15/Feb/2026                           │
│ 📋 PERIODO ASIGNADO:          Feb07-2026                            │
│ 📍 Se Imprime:                08/Feb/2026                           │
│ 💰 MONTO:                     $614.58                               │
└─────────────────────────────────────────────────────────────────────┘
```

#### PAGO #6: 28/Feb/2026 (último día de febrero)
```
┌─────────────────────────────────────────────────────────────────────┐
│ 📅 FECHA DE PAGO (CLIENTE):   28/Feb/2026                           │
│ 📋 PERIODO ASIGNADO:          Feb22-2026                            │
│ 📍 Se Imprime:                23/Feb/2026                           │
│ 💰 MONTO:                     $614.58                               │
└─────────────────────────────────────────────────────────────────────┘
```

---

## ⚠️ PROBLEMA DE NOMENCLATURA ACTUAL

### Confusión Detectada
```
Usuario ve:        "Dec07-2025"
Usuario piensa:    "Se imprime el día 7"
Realidad:          "Se imprime el día 8 (cierra el 7)"
```

### Tabla Comparativa: Nomenclatura Actual vs Realidad Operativa

| Nomenclatura Actual | Día que Cierra | Día que Imprime | Confusión |
|---------------------|----------------|-----------------|-----------|
| `Dec07-2025`        | 7              | 8               | ❌ Alta   |
| `Dec22-2025`        | 22             | 23              | ❌ Alta   |
| `Jan07-2026`        | 7              | 8               | ❌ Alta   |
| `Jan22-2026`        | 22             | 23              | ❌ Alta   |

### Propuesta de Nomenclatura Mejorada

| Nomenclatura Propuesta | Día que Cierra | Día que Imprime | Claridad |
|------------------------|----------------|-----------------|----------|
| `Dec08-2025`           | 7              | 8               | ✅ Alta  |
| `Dec23-2025`           | 22             | 23              | ✅ Alta  |
| `Jan08-2026`           | 7              | 8               | ✅ Alta  |
| `Jan23-2026`           | 22             | 23              | ✅ Alta  |

### Justificación del Cambio
```
ACTUAL:   "Dec07-2025" = Periodo que cierra el 7
PROBLEMA: Usuarios confunden "07" con día de impresión
SOLUCIÓN: "Dec08-2025" = Periodo que se imprime el 8 (operativamente relevante)

VENTAJAS:
✅ Nomenclatura alineada con operación diaria
✅ "Dec08" = Día que generamos statements
✅ "Dec23" = Día que generamos statements
✅ Mayor claridad para usuarios finales
✅ Reducción de confusión en reportes
```

---

## 🔧 IMPLEMENTACIÓN TÉCNICA ACTUAL

### Función Clave: `get_cut_period_for_payment()`
```sql
CREATE OR REPLACE FUNCTION get_cut_period_for_payment(p_payment_date DATE)
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_day INTEGER;
    v_period_id INTEGER;
BEGIN
    v_day := EXTRACT(DAY FROM p_payment_date);
    
    IF v_day = 15 THEN
        -- Pago día 15 → Buscar periodo que cierra entre días 6-8 ANTES
        SELECT id INTO v_period_id
        FROM cut_periods
        WHERE EXTRACT(DAY FROM period_end_date) BETWEEN 6 AND 8
          AND period_end_date < p_payment_date
        ORDER BY period_end_date DESC
        LIMIT 1;
    ELSE
        -- Pago último día → Buscar periodo que cierra entre días 21-23 ANTES
        SELECT id INTO v_period_id
        FROM cut_periods
        WHERE EXTRACT(DAY FROM period_end_date) BETWEEN 21 AND 23
          AND period_end_date < p_payment_date
        ORDER BY period_end_date DESC
        LIMIT 1;
    END IF;
    
    RETURN v_period_id;
END;
$$;
```

### Trigger de Generación de Pagos
```sql
-- Usado en generate_payment_schedule() trigger
v_period_id := get_cut_period_for_payment(v_current_payment_date);
```

### Función de Simulación (CORREGIDA en Migration 023)
```sql
-- Usado en simulate_loan() function
v_period_id := get_cut_period_for_payment(v_current_date);
```

---

## 📈 ESTADOS DE PAGO (Frontend)

### Ciclo de Estados
```
PENDING → PAID → LATE (si pasa fecha) → OVERDUE
```

### Tabla: `payment_statuses`
```sql
SELECT * FROM payment_statuses;
```

| ID | Name      | Descripción                           |
|----|-----------|---------------------------------------|
| 1  | PENDING   | Pago pendiente (antes de fecha)       |
| 2  | PAID      | Pago completado                       |
| 3  | LATE      | Pago atrasado (después de fecha)      |
| 4  | OVERDUE   | Pago muy atrasado (>30 días)          |

---

## 🎯 LO QUE SIGUE: STATEMENTS

### Objetivo
Mostrar gráficamente en el frontend:
- **Periodos** (Dec08-2025, Dec23-2025, etc.)
- **Asociados** asignados a cada periodo
- **Pagos** que deben cobrar en ese periodo

### Estructura Propuesta
```
┌───────────────────────────────────────────────────────────────┐
│ 📅 PERIODO: Dec08-2025 (Se imprime 08/Dic/2025)               │
│                                                                │
│ 👥 ASOCIADO: Juan Pérez                                       │
│    ├─ Pago #1 - Préstamo #56 - 15/Dic/2025 - $614.58         │
│    ├─ Pago #3 - Préstamo #47 - 15/Dic/2025 - $500.00         │
│    └─ Total: $1,114.58                                        │
│                                                                │
│ 👥 ASOCIADO: María García                                     │
│    ├─ Pago #2 - Préstamo #48 - 15/Dic/2025 - $350.00         │
│    └─ Total: $350.00                                          │
│                                                                │
│ 💰 TOTAL PERIODO: $1,464.58                                   │
└───────────────────────────────────────────────────────────────┘
```

### Query Base para Statements
```sql
SELECT 
    cp.cut_code,
    cp.period_end_date + 1 as fecha_impresion,
    u.full_name as asociado,
    l.id as loan_id,
    p.payment_number,
    p.payment_due_date,
    p.expected_amount,
    p.status_id
FROM cut_periods cp
JOIN payments p ON p.cut_period_id = cp.id
JOIN loans l ON p.loan_id = l.id
JOIN users u ON l.associate_user_id = u.id
WHERE cp.cut_code = 'Dec08-2025'
  AND p.status_id = 1  -- PENDING
ORDER BY u.full_name, p.payment_number;
```

---

## ✅ VALIDACIONES IMPLEMENTADAS

### Migration 021: Función de Asignación
```sql
-- ✅ Implementado
CREATE FUNCTION get_cut_period_for_payment(DATE) RETURNS INTEGER;
```

### Migration 022: Nomenclatura de Cierre
```sql
-- ✅ Implementado (pero confusa)
UPDATE cut_periods SET cut_code = 'Dec07-2025' WHERE ...;
-- Representa: Cierra día 7, imprime día 8
```

### Migration 023: Corrección de Simulación
```sql
-- ✅ Implementado
CREATE OR REPLACE FUNCTION simulate_loan(...) ...;
-- Ahora usa get_cut_period_for_payment() igual que el trigger real
```

---

## 💡 RECOMENDACIONES

### Acción Inmediata: Cambiar Nomenclatura
```sql
-- PROPUESTA: Migration 024
UPDATE cut_periods 
SET cut_code = REPLACE(cut_code, '07-', '08-')
WHERE EXTRACT(DAY FROM period_end_date) = 7;

UPDATE cut_periods 
SET cut_code = REPLACE(cut_code, '22-', '23-')
WHERE EXTRACT(DAY FROM period_end_date) = 22;
```

### Beneficios
1. ✅ Mayor claridad operativa
2. ✅ Nomenclatura alineada con días de impresión (8 y 23)
3. ✅ Reducción de confusión en frontend
4. ✅ Mejor comprensión para usuarios finales
5. ✅ Statements más intuitivos

### Riesgo
- ⚠️ Cambio cosmético, no afecta lógica
- ⚠️ Requiere actualizar documentación existente
- ⚠️ Frontend puede tener referencias hardcodeadas

---

## 📊 RESUMEN TÉCNICO

### Tablas Involucradas
- `cut_periods` (72 registros, 2024-2027)
- `loans` (préstamos aprobados)
- `payments` (pagos generados automáticamente)
- `payment_statuses` (estados de pago)

### Funciones Clave
- `get_cut_period_for_payment()` - Asignación correcta
- `calculate_first_payment_date()` - Primera fecha de pago
- `generate_payment_schedule()` - Trigger de generación
- `simulate_loan()` - Simulación pre-aprobación

### Migraciones Relevantes
- **021**: Creación de `get_cut_period_for_payment()`
- **022**: Renombrar periodos (Dec08→Dec07, confuso)
- **023**: Corregir `simulate_loan()`
- **024** (PROPUESTA): Renombrar a días de impresión (Dec08, Dec23)

---

## 🔍 SIGUIENTE PASO: DECISIÓN DE NOMENCLATURA

### Opción A: Mantener Actual (Dec07, Dec22)
- ✅ No requiere cambios
- ❌ Sigue siendo confuso
- ❌ "07" no representa operación real (impresión)

### Opción B: Cambiar a Día de Impresión (Dec08, Dec23) ⭐ RECOMENDADO
- ✅ Mayor claridad
- ✅ Alineado con operación diaria
- ✅ Mejor para usuarios finales
- ⚠️ Requiere migración simple
- ⚠️ Actualizar documentación

---

**¿Proceder con Migration 024 para cambiar nomenclatura a días de impresión?**
