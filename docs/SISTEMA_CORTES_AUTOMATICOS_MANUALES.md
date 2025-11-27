# 🔄 SISTEMA DE CORTES AUTOMÁTICOS Y MANUALES

**Fecha**: 26 de Noviembre de 2025  
**Contexto**: Sistema de doble corte para generación de statements con periodos Dec08 y Dec23

---

## 🎯 OBJETIVO

Implementar un sistema de **doble corte** que permita:
1. **Corte Automático** a las 00:00 del día de impresión (8 y 23) → Vista preliminar
2. **Corte Manual** en horario laboral del mismo día → Versión definitiva (bloqueada)

---

## 📅 NOMENCLATURA ACTUALIZADA (Migration 024)

### Periodos Renombrados
```
ANTES (Confuso)         →  AHORA (Operativo)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Dec07-2025              →  Dec08-2025  ✅
Dec22-2025              →  Dec23-2025  ✅
Jan07-2026              →  Jan08-2026  ✅
Jan22-2026              →  Jan23-2026  ✅
```

**Significado:**
- `Dec08-2025` = Periodo que se **IMPRIME** el día 8 de diciembre
- `Dec23-2025` = Periodo que se **IMPRIME** el día 23 de diciembre

**Validación:**
```sql
SELECT cut_code, period_end_date, period_end_date + 1 as dia_impresion
FROM cut_periods
WHERE EXTRACT(YEAR FROM period_start_date) = 2025
ORDER BY period_start_date;
```

---

## 🔄 FLUJO DE CORTES: AUTOMÁTICO → MANUAL

### Calendario de Operación

```
┌──────────────────────────────────────────────────────────────────┐
│ DÍA 8 DEL MES (Periodo Dec08-YYYY)                              │
├──────────────────────────────────────────────────────────────────┤
│ 00:00 → CORTE AUTOMÁTICO                                         │
│         • Statement generado automáticamente                     │
│         • Estado: DRAFT / PREVIEW                                │
│         • Editable: ✅ SÍ                                        │
│         • Notificación: ❌ NO                                    │
│                                                                  │
│ 08:00-18:00 → HORARIO LABORAL                                    │
│         • Revisión de statements                                │
│         • Correcciones permitidas                               │
│         • Ajustes manuales                                      │
│                                                                  │
│ XX:XX → CORTE MANUAL (Admin ejecuta)                            │
│         • Statement finalizado                                  │
│         • Estado: FINALIZED / SENT                              │
│         • Editable: ❌ NO (bloqueado)                           │
│         • Notificación: ✅ SÍ (asociados reciben statement)    │
└──────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│ DÍA 23 DEL MES (Periodo Dec23-YYYY)                             │
├──────────────────────────────────────────────────────────────────┤
│ (Mismo flujo que día 8)                                          │
└──────────────────────────────────────────────────────────────────┘
```

---

## 📊 ESTADOS DE STATEMENTS

### Estados Actuales (Tabla `statement_statuses`)

| ID | Name         | Descripción                | Uso Actual           |
|----|--------------|----------------------------|----------------------|
| 1  | GENERATED    | Estado de cuenta generado  | Después de generar   |
| 2  | SENT         | Enviado al asociado        | Después de enviar    |
| 3  | PAID         | Pagado completamente       | Después de pago      |
| 4  | PARTIAL_PAID | Pago parcial recibido      | Pago parcial         |
| 5  | OVERDUE      | Vencido sin pagar          | Después de due_date  |

### Nuevos Estados Propuestos (Migration 025)

| ID | Name            | Descripción                              | Editable | Notifica | Color   |
|----|-----------------|------------------------------------------|----------|----------|---------|
| 6  | **DRAFT**       | Corte automático 00:00 - Vista preliminar| ✅ SÍ    | ❌ NO    | #FFC107 |
| 7  | **FINALIZED**   | Corte manual - Versión definitiva        | ❌ NO    | ✅ SÍ    | #2196F3 |

### Transiciones de Estado

```
┌─────────────────────────────────────────────────────────────────┐
│ CICLO DE VIDA DE UN STATEMENT                                   │
└─────────────────────────────────────────────────────────────────┘

1. DRAFT (00:00 corte automático)
   ↓ (Admin revisa y ajusta si necesario)
   
2. FINALIZED (Corte manual en horario laboral)
   ↓ (Sistema envía notificaciones)
   
3. SENT (Asociado recibe statement)
   ↓ (Asociado realiza pago)
   
4a. PAID (Pago completo) ✅
4b. PARTIAL_PAID (Pago parcial) ⚠️
   ↓ (Si pasa due_date sin pagar)
   
5. OVERDUE (Vencido) ❌
```

---

## 🔧 IMPLEMENTACIÓN TÉCNICA

### 1. Migración de Estados (Migration 025)

```sql
-- Agregar nuevos estados para sistema de doble corte
INSERT INTO statement_statuses (id, name, description, is_paid, display_order, color_code)
VALUES 
    (6, 'DRAFT', 'Corte automático - Vista preliminar (editable)', false, 0, '#FFC107'),
    (7, 'FINALIZED', 'Corte manual - Versión definitiva (bloqueada)', false, 1, '#2196F3')
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    display_order = EXCLUDED.display_order,
    color_code = EXCLUDED.color_code;
```

### 2. Función de Corte Automático (Ejecuta a las 00:00)

```sql
CREATE OR REPLACE FUNCTION auto_generate_statements_at_midnight()
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_current_day INTEGER;
    v_is_cut_day BOOLEAN;
    v_period_id INTEGER;
BEGIN
    v_current_day := EXTRACT(DAY FROM CURRENT_DATE);
    
    -- Verificar si es día de corte (8 o 23)
    v_is_cut_day := v_current_day IN (8, 23);
    
    IF NOT v_is_cut_day THEN
        RAISE NOTICE 'Hoy no es día de corte (%, esperado 8 o 23)', v_current_day;
        RETURN;
    END IF;
    
    -- Obtener periodo correspondiente a hoy
    SELECT id INTO v_period_id
    FROM cut_periods
    WHERE period_end_date + 1 = CURRENT_DATE;  -- Día de impresión
    
    IF v_period_id IS NULL THEN
        RAISE EXCEPTION 'No se encontró periodo para hoy: %', CURRENT_DATE;
    END IF;
    
    -- Generar statements automáticos con estado DRAFT
    INSERT INTO associate_payment_statements (
        cut_period_id,
        user_id,
        statement_number,
        total_payments_count,
        total_amount_collected,
        total_commission_owed,
        commission_rate_applied,
        status_id,              -- DRAFT (6)
        generated_date,
        due_date
    )
    SELECT 
        v_period_id,
        l.associate_user_id,
        CONCAT(cp.cut_code, '-', l.associate_user_id) as statement_number,
        COUNT(p.id) as total_payments,
        SUM(p.expected_amount) as total_amount,
        SUM(p.commission_amount) as total_commission,
        l.commission_rate,
        6,  -- DRAFT
        CURRENT_DATE,
        CURRENT_DATE + INTERVAL '7 days'  -- Due date 7 días después
    FROM cut_periods cp
    JOIN payments p ON p.cut_period_id = cp.id
    JOIN loans l ON p.loan_id = l.id
    WHERE cp.id = v_period_id
      AND p.status_id = 1  -- PENDING
    GROUP BY v_period_id, l.associate_user_id, cp.cut_code, l.commission_rate
    ON CONFLICT (cut_period_id, user_id) DO UPDATE SET
        updated_at = CURRENT_TIMESTAMP;
    
    RAISE NOTICE '✅ Corte automático ejecutado: % statements generados en DRAFT', 
        (SELECT COUNT(*) FROM associate_payment_statements WHERE cut_period_id = v_period_id);
END;
$$;

COMMENT ON FUNCTION auto_generate_statements_at_midnight() IS
'Función ejecutada automáticamente a las 00:00 de los días 8 y 23.
Genera statements en estado DRAFT (editable) para revisión administrativa.';
```

### 3. Función de Corte Manual (Ejecuta en horario laboral)

```sql
CREATE OR REPLACE FUNCTION finalize_statements_manual(
    p_cut_period_id INTEGER
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_draft_count INTEGER;
    v_updated_count INTEGER;
BEGIN
    -- Verificar que existan statements en DRAFT para este periodo
    SELECT COUNT(*) INTO v_draft_count
    FROM associate_payment_statements
    WHERE cut_period_id = p_cut_period_id
      AND status_id = 6;  -- DRAFT
    
    IF v_draft_count = 0 THEN
        RAISE EXCEPTION 'No hay statements en DRAFT para finalizar en periodo %', 
            (SELECT cut_code FROM cut_periods WHERE id = p_cut_period_id);
    END IF;
    
    -- Cambiar estado de DRAFT → FINALIZED
    UPDATE associate_payment_statements
    SET 
        status_id = 7,  -- FINALIZED
        updated_at = CURRENT_TIMESTAMP
    WHERE cut_period_id = p_cut_period_id
      AND status_id = 6;  -- DRAFT
    
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    
    RAISE NOTICE '✅ Corte manual ejecutado: % statements finalizados y bloqueados', 
        v_updated_count;
    
    -- TODO: Aquí se puede agregar lógica para enviar notificaciones
    -- PERFORM send_statement_notifications(p_cut_period_id);
END;
$$;

COMMENT ON FUNCTION finalize_statements_manual(INTEGER) IS
'Función ejecutada manualmente por admin en horario laboral.
Cambia statements de DRAFT → FINALIZED (bloqueados).
Después de esto, NO se permiten modificaciones.';
```

### 4. Cron Job para Corte Automático

**Usando pg_cron (si está instalado):**
```sql
-- Ejecutar a las 00:00 todos los días
SELECT cron.schedule(
    'auto-cut-statements',
    '0 0 * * *',
    $$SELECT auto_generate_statements_at_midnight()$$
);
```

**Alternativa: Script Python + crontab:**
```python
# scripts/auto_cut_statements.py
import psycopg2
from datetime import datetime

def run_auto_cut():
    conn = psycopg2.connect(
        dbname="credinet_db",
        user="credinet_user",
        password="...",
        host="localhost"
    )
    cur = conn.cursor()
    cur.execute("SELECT auto_generate_statements_at_midnight()")
    conn.commit()
    cur.close()
    conn.close()
    print(f"[{datetime.now()}] Auto-cut ejecutado")

if __name__ == "__main__":
    run_auto_cut()
```

**Crontab:**
```bash
# Ejecutar a las 00:00 todos los días
0 0 * * * /usr/bin/python3 /path/to/scripts/auto_cut_statements.py >> /var/log/auto_cut.log 2>&1
```

---

## 🎨 INTERFAZ DE USUARIO (Frontend)

### Vista de Statements en Estado DRAFT

```
┌────────────────────────────────────────────────────────────────────┐
│ 📅 PERIODO: Dec08-2025 (Generado: 08/Dic/2025 00:00)              │
│ ⚠️  ESTADO: DRAFT - Vista Preliminar (Editable)                   │
│                                                                    │
│ ┌────────────────────────────────────────────────────────────────┐│
│ │ 👤 ASOCIADO: Juan Pérez                                        ││
│ │                                                                ││
│ │ Pagos Incluidos:                                               ││
│ │  ✓ Pago #1 - Préstamo #56 - 15/Dic/25 - $614.58              ││
│ │  ✓ Pago #3 - Préstamo #47 - 15/Dic/25 - $500.00              ││
│ │                                                                ││
│ │ 💰 Total a Cobrar: $1,114.58                                   ││
│ │ 💵 Comisión Total: $150.00                                     ││
│ │                                                                ││
│ │ [✏️ Editar]  [🗑️ Remover Pago]  [➕ Agregar Nota]            ││
│ └────────────────────────────────────────────────────────────────┘│
│                                                                    │
│ [✅ Finalizar Corte]  [🔄 Recalcular]  [📋 Vista Previa PDF]     │
└────────────────────────────────────────────────────────────────────┘
```

### Vista de Statements en Estado FINALIZED

```
┌────────────────────────────────────────────────────────────────────┐
│ 📅 PERIODO: Dec08-2025 (Finalizado: 08/Dic/2025 10:30)            │
│ 🔒 ESTADO: FINALIZED - Versión Definitiva (BLOQUEADO)             │
│                                                                    │
│ ┌────────────────────────────────────────────────────────────────┐│
│ │ 👤 ASOCIADO: Juan Pérez                                        ││
│ │                                                                ││
│ │ Pagos Incluidos:                                               ││
│ │  ✓ Pago #1 - Préstamo #56 - 15/Dic/25 - $614.58              ││
│ │  ✓ Pago #3 - Préstamo #47 - 15/Dic/25 - $500.00              ││
│ │                                                                ││
│ │ 💰 Total a Cobrar: $1,114.58                                   ││
│ │ 💵 Comisión Total: $150.00                                     ││
│ │                                                                ││
│ │ ⚠️ Este statement está BLOQUEADO. No se permiten cambios.     ││
│ └────────────────────────────────────────────────────────────────┘│
│                                                                    │
│ [📧 Reenviar]  [🖨️ Imprimir PDF]  [📊 Ver Historial]             │
└────────────────────────────────────────────────────────────────────┘
```

---

## 🔐 REGLAS DE NEGOCIO

### Permisos de Edición

| Estado     | Ver | Editar | Eliminar | Finalizar | Reenviar |
|------------|-----|--------|----------|-----------|----------|
| DRAFT      | ✅  | ✅     | ✅       | ✅        | ❌       |
| FINALIZED  | ✅  | ❌     | ❌       | ❌        | ✅       |
| SENT       | ✅  | ❌     | ❌       | ❌        | ✅       |
| PAID       | ✅  | ❌     | ❌       | ❌        | ✅       |

### Validaciones Backend

```python
# backend/app/modules/statements/routes.py

@router.put("/{statement_id}")
async def update_statement(statement_id: int, data: UpdateStatementDTO):
    statement = await get_statement(statement_id)
    
    # REGLA: Solo DRAFT es editable
    if statement.status_id != 6:  # DRAFT
        raise HTTPException(
            status_code=403,
            detail=f"No se puede editar statement en estado {statement.status_name}. "
                   f"Solo statements en DRAFT son editables."
        )
    
    # ... proceder con actualización
```

```python
@router.post("/{statement_id}/finalize")
async def finalize_statement(statement_id: int):
    statement = await get_statement(statement_id)
    
    # REGLA: Solo DRAFT puede finalizarse
    if statement.status_id != 6:  # DRAFT
        raise HTTPException(
            status_code=400,
            detail=f"Statement ya está en estado {statement.status_name}"
        )
    
    # Cambiar a FINALIZED
    await update_statement_status(statement_id, 7)  # FINALIZED
    
    # Enviar notificaciones a asociados
    await send_statement_notifications(statement_id)
    
    return {"message": "Statement finalizado y enviado"}
```

---

## 📋 CASOS DE USO

### Caso 1: Corte Normal (Sin Correcciones)

```
00:00 → Sistema genera statements automáticamente en DRAFT
08:00 → Admin revisa statements
08:30 → Admin ejecuta "Finalizar Corte"
        → Statements pasan a FINALIZED
        → Asociados reciben notificaciones
```

### Caso 2: Corte con Correcciones

```
00:00 → Sistema genera statements automáticamente en DRAFT
08:00 → Admin revisa statements
08:30 → Admin detecta pago duplicado en statement de Juan Pérez
        → Admin edita statement (permitido porque está en DRAFT)
        → Admin remueve pago duplicado
        → Admin recalcula totales
10:00 → Admin ejecuta "Finalizar Corte"
        → Statements pasan a FINALIZED (con correcciones aplicadas)
        → Asociados reciben notificaciones
```

### Caso 3: Intento de Edición Después de Finalizar

```
10:00 → Statements en FINALIZED
11:00 → Admin intenta editar statement
        → Sistema muestra error: "No se puede editar statement finalizado"
        → Opciones: Reenviar, Imprimir, Ver Historial
```

---

## 🎯 PRÓXIMOS PASOS

### Migration 025: Nuevos Estados
```bash
db/v2.0/migrations/migration_025_add_draft_finalized_states.sql
```

### Implementar Funciones SQL
- `auto_generate_statements_at_midnight()`
- `finalize_statements_manual(p_cut_period_id)`

### Backend (FastAPI)
- Endpoint: `POST /api/statements/finalize/{period_id}`
- Endpoint: `PUT /api/statements/{statement_id}` (con validación DRAFT)
- Endpoint: `GET /api/statements/draft` (filtrar por estado DRAFT)

### Frontend (React)
- Componente: `StatementDraftView` (editable)
- Componente: `StatementFinalizedView` (bloqueado)
- Botón: "Finalizar Corte" (ejecuta corte manual)
- Badge: Mostrar estado (DRAFT en amarillo, FINALIZED en azul)

### Cron Job
- Script Python para ejecutar corte automático a las 00:00
- Configurar crontab o usar pg_cron

---

## ✅ VALIDACIÓN

### Query para verificar estados
```sql
-- Ver statements en DRAFT (esperando finalización)
SELECT 
    s.id,
    cp.cut_code,
    u.full_name as asociado,
    s.total_amount_collected,
    ss.name as estado,
    s.generated_date
FROM associate_payment_statements s
JOIN cut_periods cp ON s.cut_period_id = cp.id
JOIN users u ON s.user_id = u.id
JOIN statement_statuses ss ON s.status_id = ss.id
WHERE s.status_id = 6  -- DRAFT
ORDER BY s.generated_date DESC;
```

```sql
-- Ver statements finalizados hoy
SELECT 
    s.id,
    cp.cut_code,
    COUNT(sp.payment_id) as pagos,
    s.total_amount_collected,
    s.updated_at as finalized_at
FROM associate_payment_statements s
JOIN cut_periods cp ON s.cut_period_id = cp.id
JOIN associate_statement_payments sp ON sp.statement_id = s.id
WHERE s.status_id = 7  -- FINALIZED
  AND DATE(s.updated_at) = CURRENT_DATE
GROUP BY s.id, cp.cut_code, s.total_amount_collected, s.updated_at
ORDER BY s.updated_at DESC;
```

---

**Resumen:** Sistema de doble corte implementado con nomenclatura clara (Dec08, Dec23), estados DRAFT/FINALIZED, y control estricto de edición. Listo para integrar con frontend y scheduler.
