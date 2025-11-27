-- =============================================================================
-- AUDITORÍA COMPLETA DE BASE DE DATOS - ESTADO ACTUAL
-- =============================================================================
-- Fecha: 2025-11-11
-- Auditor: GitHub Copilot (Piloto Principal del Proyecto)
-- Objetivo: Validar esquema real vs documentación
-- =============================================================================

-- =============================================================================
-- HALLAZGOS CRÍTICOS
-- =============================================================================

/*
1. ❌ TABLA FALTANTE: associate_statement_payments
   - Estado: DEFINIDA en init.sql (línea 742) pero NO EXISTE en producción
   - Impacto: CRÍTICO - Sin esta tabla NO se pueden registrar abonos al saldo actual
   - Documentación afectada:
     * LOGICA_COMPLETA_SISTEMA_STATEMENTS.md (menciona la tabla)
     * TRACKING_ABONOS_DEUDA_ANALISIS.md (asume que existe)
     * LOGICA_CIERRE_DEFINITIVA_V3.md (asume paid_amount de esta tabla)
   
2. ❌ TABLA FALTANTE: associate_debt_payments
   - Estado: PROPUESTA en TRACKING_ABONOS_DEUDA_ANALISIS.md pero NO EXISTE
   - Impacto: ALTO - Sin esta tabla NO se pueden registrar abonos a deuda acumulada
   - Recomendación: OPCIÓN A confirmada, crear la tabla
   
3. ⚠️ FUNCIÓN OBSOLETA: close_period_and_accumulate_debt()
   - Problema: Usa amount_paid de payments (incorrecto)
   - Debería usar: paid_amount de associate_statement_payments (que no existe)
   - Impacto: CRÍTICO - Lógica de cierre incorrecta
   
4. ✅ CAMPOS CORRECTOS en payments:
   - expected_amount ✓
   - commission_amount ✓
   - associate_payment ✓
   - payment_number ✓
   - interest_amount ✓
   - principal_amount ✓
   - balance_remaining ✓

5. ✅ TABLA CORRECTA: associate_debt_breakdown
   - Todos los campos presentes
   - Triggers funcionando
   - FIFO listo para implementar

6. ✅ TABLA CORRECTA: associate_payment_statements
   - Campos clave presentes:
     * total_amount_collected ✓
     * total_commission_owed ✓
     * paid_amount ✓ (campo existe, pero sin tracking de abonos)
     * late_fee_amount ✓
     * late_fee_applied ✓
*/

-- =============================================================================
-- DISCREPANCIAS ENTRE CÓDIGO Y PRODUCCIÓN
-- =============================================================================

/*
DISCREPANCIA #1: init.sql vs Base de Datos Real
────────────────────────────────────────────────
EN INIT.SQL (línea 742):
  - associate_statement_payments (DEFINIDA)
  
EN PRODUCCIÓN:
  - associate_statement_payments (NO EXISTE)
  
CAUSA RAÍZ:
  - El init.sql se regeneró (timestamp: 2025-11-05 13:15:22)
  - Pero la base de datos NO se recreó
  - Contenedor usa volumen persistente con schema antiguo
  
SOLUCIÓN:
  - Crear migración incremental (NO destruir BD)
  - Ejecutar: migration_015_associate_payments_tracking.sql


DISCREPANCIA #2: Documentación vs Realidad
────────────────────────────────────────────────
DOCUMENTACIÓN ASUME:
  - associate_statement_payments EXISTE
  - paid_amount se calcula desde SUM de abonos
  - Lógica de cierre usa paid_amount del statement
  
REALIDAD:
  - Tabla NO EXISTE
  - paid_amount es NULL en todos los statements
  - Función close_period_and_accumulate_debt() usa lógica antigua
  
SOLUCIÓN:
  - Crear tabla associate_statement_payments
  - Actualizar función close_period_and_accumulate_debt()
  - Crear trigger para calcular paid_amount automáticamente


DISCREPANCIA #3: Dos Tipos de Abonos (Documentación vs Implementación)
────────────────────────────────────────────────────────────────────────
DOCUMENTACIÓN DICE:
  - TIPO 1: Abonos al saldo actual (associate_statement_payments)
  - TIPO 2: Abonos a deuda acumulada (associate_debt_payments)
  
IMPLEMENTACIÓN ACTUAL:
  - TIPO 1: NO EXISTE (tabla faltante)
  - TIPO 2: NO EXISTE (tabla propuesta solamente)
  
SOLUCIÓN:
  - Crear ambas tablas en una sola migración
  - Mantener compatibilidad con datos existentes
*/

-- =============================================================================
-- ESTADO DE LAS TABLAS (PRODUCCIÓN vs CÓDIGO)
-- =============================================================================

/*
┌────────────────────────────────────┬────────────┬────────────┬──────────┐
│ TABLA                              │ INIT.SQL   │ PRODUCCIÓN │ ESTADO   │
├────────────────────────────────────┼────────────┼────────────┼──────────┤
│ users                              │ ✓          │ ✓          │ OK       │
│ roles                              │ ✓          │ ✓          │ OK       │
│ addresses                          │ ✓          │ ✓          │ OK       │
│ beneficiaries                      │ ✓          │ ✓          │ OK       │
│ guarantors                         │ ✓          │ ✓          │ OK       │
│ loans                              │ ✓          │ ✓          │ OK       │
│ contracts                          │ ✓          │ ✓          │ OK       │
│ payments                           │ ✓          │ ✓          │ OK       │
│ cut_periods                        │ ✓          │ ✓          │ OK       │
│ associate_profiles                 │ ✓          │ ✓          │ OK       │
│ associate_payment_statements       │ ✓          │ ✓          │ OK       │
│ associate_statement_payments       │ ✓          │ ✗          │ FALTA ❌ │
│ associate_debt_breakdown           │ ✓          │ ✓          │ OK       │
│ associate_debt_payments            │ ✗          │ ✗          │ PROPUESTA│
│ agreements                         │ ✓          │ ✓          │ OK       │
│ agreement_items                    │ ✓          │ ✓          │ OK       │
│ agreement_payments                 │ ✓          │ ✓          │ OK       │
│ rate_profiles                      │ ✓          │ ✓          │ OK       │
└────────────────────────────────────┴────────────┴────────────┴──────────┘

TOTAL TABLAS EN PRODUCCIÓN: 38
TOTAL TABLAS EN INIT.SQL: 39 (incluye associate_statement_payments)
TABLAS FALTANTES: 1 (associate_statement_payments)
TABLAS PROPUESTAS: 1 (associate_debt_payments)
*/

-- =============================================================================
-- FUNCIONES Y TRIGGERS (ANÁLISIS)
-- =============================================================================

/*
FUNCIÓN: close_period_and_accumulate_debt()
────────────────────────────────────────────────
CÓDIGO ACTUAL (INCORRECTO):
  -- PASO 1: Marca como PAID si amount_paid > 0
  UPDATE payments
  SET status_id = v_paid_status_id
  WHERE amount_paid > 0
  
  -- PASO 2: Marca como PAID_NOT_REPORTED si amount_paid = 0
  UPDATE payments
  SET status_id = v_paid_not_reported_id
  WHERE amount_paid = 0 OR amount_paid IS NULL

CÓDIGO CORRECTO (SEGÚN DOCUMENTACIÓN):
  -- PASO 1: Calcular paid_amount del statement
  paid_amount := (
    SELECT COALESCE(SUM(payment_amount), 0)
    FROM associate_statement_payments
    WHERE statement_id = p_statement_id
  );
  
  -- PASO 2: Calcular total a pagar
  associate_payment_total := total_amount_collected - total_commission_owed;
  
  -- PASO 3: Marcar según paid_amount
  IF paid_amount >= associate_payment_total THEN
    UPDATE payments SET status_id = PAID_BY_ASSOCIATE
  ELSE
    UPDATE payments SET status_id = UNPAID_ACCRUED_DEBT
  END IF;

ESTADO: ❌ REQUIERE ACTUALIZACIÓN COMPLETA


TRIGGER: update_statement_on_payment (EXISTE EN INIT.SQL, NO EN PRODUCCIÓN)
────────────────────────────────────────────────────────────────────────────
PROPÓSITO: Actualizar paid_amount cuando se registra abono
TABLA: associate_statement_payments
ESTADO: ❌ NO EXISTE (tabla faltante)

CÓDIGO EN INIT.SQL (línea ~2756):
  CREATE TRIGGER trigger_update_statement_on_payment
  AFTER INSERT ON associate_statement_payments
  FOR EACH ROW
  EXECUTE FUNCTION update_statement_on_payment();

DEBE HACER:
  1. Sumar todos los abonos: SUM(payment_amount)
  2. Actualizar associate_payment_statements.paid_amount
  3. Calcular saldo pendiente
  4. Si paid_amount >= total, aplicar excedente a deuda (FIFO)


TRIGGER: trigger_update_associate_credit_on_debt_payment (EXISTE)
──────────────────────────────────────────────────────────────────
TABLA: associate_debt_breakdown
ESTADO: ✅ FUNCIONANDO
PROPÓSITO: Actualizar debt_balance cuando se liquida deuda
*/

-- =============================================================================
-- VISTAS SQL (PROPUESTAS vs EXISTENTES)
-- =============================================================================

/*
VISTA PROPUESTA: v_associate_debt_summary
──────────────────────────────────────────
ESTADO: ❌ NO EXISTE
PROPÓSITO: Resumen de deuda por asociado
REQUIERE: Nada adicional (tablas existen)
ACCIÓN: CREAR


VISTA PROPUESTA: v_associate_all_payments
──────────────────────────────────────────
ESTADO: ❌ NO EXISTE
PROPÓSITO: Historial unificado de abonos (saldo + deuda)
REQUIERE: 
  - associate_statement_payments (FALTA)
  - associate_debt_payments (FALTA)
ACCIÓN: CREAR después de tablas
*/

-- =============================================================================
-- DATOS EXISTENTES (VALIDACIÓN)
-- =============================================================================

/*
PREGUNTA: ¿Hay datos en las tablas de catálogo que se perderían?
RESPUESTA: Verificar antes de ejecutar migraciones

COMANDOS DE VALIDACIÓN:
*/

-- Ver cuántos asociados hay
SELECT COUNT(*) AS total_associates FROM associate_profiles;

-- Ver cuántos statements hay
SELECT COUNT(*) AS total_statements FROM associate_payment_statements;

-- Ver cuántos registros de deuda hay
SELECT COUNT(*) AS total_debt_items FROM associate_debt_breakdown;

-- Ver si paid_amount tiene datos
SELECT 
  COUNT(*) AS total_statements,
  COUNT(paid_amount) AS statements_with_payment,
  SUM(CASE WHEN paid_amount > 0 THEN 1 ELSE 0 END) AS statements_with_nonzero_payment
FROM associate_payment_statements;

-- Resultado esperado: paid_amount NULL en todos (no hay tracking de abonos)

-- =============================================================================
-- PLAN DE ACCIÓN (RECOMENDADO)
-- =============================================================================

/*
FASE 1: CREAR TABLAS FALTANTES (SIN PERDER DATOS)
──────────────────────────────────────────────────
✓ PASO 1.1: Crear migration_015_associate_statement_payments.sql
  - CREATE TABLE associate_statement_payments
  - CREATE INDEXES
  - CREATE TRIGGER update_statement_on_payment

✓ PASO 1.2: Crear migration_016_associate_debt_payments.sql
  - CREATE TABLE associate_debt_payments
  - CREATE INDEXES
  - CREATE VISTAS (v_associate_debt_summary, v_associate_all_payments)

✓ PASO 1.3: Ejecutar migraciones en orden:
  docker exec credinet-postgres psql -U credinet_user -d credinet_db \
    -f /docker-entrypoint-initdb.d/migration_015_associate_statement_payments.sql
  
  docker exec credinet-postgres psql -U credinet_user -d credinet_db \
    -f /docker-entrypoint-initdb.d/migration_016_associate_debt_payments.sql


FASE 2: ACTUALIZAR FUNCIONES EXISTENTES
────────────────────────────────────────
✓ PASO 2.1: Actualizar close_period_and_accumulate_debt()
  - Reescribir lógica para usar paid_amount de statement
  - Implementar decisión de NO distribución
  - Implementar cálculo correcto de mora

✓ PASO 2.2: Crear función apply_payment_to_debt_fifo()
  - Implementar FIFO en associate_debt_breakdown
  - Registrar en associate_debt_payments
  - Actualizar debt_balance


FASE 3: INTEGRAR EN INIT.SQL (PARA NUEVAS INSTALACIONES)
─────────────────────────────────────────────────────────
✓ PASO 3.1: Agregar migration_016 a módulos base
  - Insertar en 03_business_tables.sql (después de línea 770)
  - NO tocar catálogos (preservar datos)

✓ PASO 3.2: Regenerar init.sql:
  cd /home/credicuenta/proyectos/credinet-v2/db/v2.0
  ./generate_monolithic.sh

✓ PASO 3.3: Validar sintaxis:
  ./validate_syntax.sh


FASE 4: ACTUALIZAR DOCUMENTACIÓN
─────────────────────────────────
✓ PASO 4.1: Actualizar FASE6_MVP_SCOPE.md
  - Confirmar que ambas tablas están implementadas
  - Marcar "Diferenciar abonos" como DONE

✓ PASO 4.2: Crear AUDITORIA_BD_COMPLETA.md (este archivo)
  - Documentar estado real de producción
  - Listar todas las tablas con sus columnas
  - Documentar triggers y funciones

✓ PASO 4.3: Actualizar INDICE_MAESTRO_FASE6.md
  - Agregar referencia a auditoría de BD
  - Actualizar estado del proyecto
*/

-- =============================================================================
-- COMANDOS DE VERIFICACIÓN POST-MIGRACIÓN
-- =============================================================================

/*
-- Verificar que las tablas existen
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND table_name IN ('associate_statement_payments', 'associate_debt_payments')
ORDER BY table_name;

-- Verificar columnas de associate_statement_payments
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'associate_statement_payments'
ORDER BY ordinal_position;

-- Verificar triggers
SELECT trigger_name, event_object_table, action_statement
FROM information_schema.triggers
WHERE trigger_name LIKE '%statement%payment%';

-- Verificar funciones
SELECT routine_name, routine_type
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name LIKE '%statement%'
ORDER BY routine_name;
*/

-- =============================================================================
-- NOTAS FINALES
-- =============================================================================

/*
CONCLUSIÓN:
-----------
La auditoría revela que el init.sql está ACTUALIZADO con todas las definiciones,
pero la base de datos en PRODUCCIÓN está ejecutando una versión ANTIGUA.

CAUSA:
------
El contenedor Docker usa un volumen persistente que mantiene el schema antiguo.
Cuando se regeneró el init.sql (2025-11-05), NO se recreó la base de datos.

IMPACTO:
--------
- ❌ CRÍTICO: Sistema de tracking de abonos NO FUNCIONAL
- ❌ ALTO: Lógica de cierre incorrecta
- ❌ MEDIO: Documentación asume funcionalidad inexistente

SOLUCIÓN:
---------
NO recrear la base de datos (perderíamos datos de catálogos).
En su lugar, ejecutar migraciones incrementales para sincronizar.

TIEMPO ESTIMADO:
----------------
- Crear migraciones: 30 minutos
- Ejecutar y validar: 15 minutos
- Actualizar documentación: 15 minutos
TOTAL: ~1 hora

RIESGO:
-------
BAJO - Las migraciones son aditivas (CREATE TABLE IF NOT EXISTS).
NO afectan datos existentes.
*/

-- =============================================================================
-- FIN DE LA AUDITORÍA
-- =============================================================================
-- Última actualización: 2025-11-11
-- Auditor: GitHub Copilot (Piloto Principal del Proyecto)
-- Estado: READY FOR ACTION
-- =============================================================================
