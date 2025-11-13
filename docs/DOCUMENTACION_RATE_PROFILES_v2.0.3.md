# DOCUMENTACIÓN: Sistema de Perfiles de Tasa v2.0.3

**Fecha:** 2025-11-04  
**Módulo:** `10_rate_profiles.sql`  
**Integración:** Compatible con módulos 01-09 existentes

---

## 📊 CONCEPTO: Las Dos Tasas

### 1. **interest_rate** (Tasa del CLIENTE)

```
¿Qué es?
  • Tasa que paga el CLIENTE sobre el capital prestado
  • Se calcula sobre el monto total del préstamo
  • Genera el ingreso principal de la empresa

Ejemplo: 4.5% quincenal
  Capital: $22,000
  Plazo: 12 quincenas
  
  Cálculo:
    Factor = 1 + (4.5/100 × 12) = 1.54
    Total = $22,000 × 1.54 = $33,880
    Pago quincenal = $33,880 / 12 = $2,823.33
    Interés total = $33,880 - $22,000 = $11,880
```

### 2. **commission_rate** (Tasa del ASOCIADO)

```
¿Qué es?
  • Comisión que cobra la EMPRESA al ASOCIADO
  • Se calcula sobre el pago quincenal del cliente
  • Es el costo operativo del asociado

Ejemplo: 2.5% sobre cada pago
  Pago cliente: $2,823.33
  
  Cálculo:
    Comisión = $2,823.33 × 0.025 = $70.58
    Pago asociado = $2,823.33 - $70.58 = $2,752.75
    Comisión total = $70.58 × 12 = $846.96
```

---

## 🏗️ ARQUITECTURA DEL MÓDULO

### Tablas Creadas

```
1. rate_profiles
   • Perfiles configurables (legacy, standard, premium, custom)
   • Tipo: table_lookup o formula
   • Editable por admin

2. legacy_payment_table
   • Tabla histórica con 28 montos iniciales
   • Totalmente EDITABLE (agregar/modificar/eliminar)
   • Campos calculados automáticamente
```

### Funciones Principales

```
1. calculate_loan_payment(amount, term, profile, custom_rate)
   → Calcula pago quincenal según perfil
   → Retorna: pago, total, interés, tasas

2. generate_loan_summary(amount, term, interest_rate, commission_rate)
   → Genera tabla resumen COMPLETA (cliente + asociado)
   → Similar a tabla "Importe de prestamos" de UI

3. generate_amortization_schedule(amount, payment, term, commission, start)
   → Genera tabla de amortización período por período
   → Incluye: fechas, pagos, interés, capital, saldo, comisión
```

---

## 📋 TABLA RESUMEN (generate_loan_summary)

### Salida de la Función

```sql
SELECT * FROM generate_loan_summary(
    22000,   -- capital
    12,      -- plazo quincenas
    4.25,    -- tasa interés cliente (quincenal %)
    2.5      -- tasa comisión socio (%)
);
```

### Resultado (como en tu foto):

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                        TABLA RESUMEN DEL PRÉSTAMO                            │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  DATOS BÁSICOS:                                                              │
│    Capital:                         $22,000.00                               │
│    Plazo:                           12 quincenas (6 meses)                   │
│    Tasa interés (quincenal):       4.25%                                     │
│    Tasa comisión (sobre pago):     2.5%                                      │
│                                                                              │
│  ════════════════════════════════════════════════════════════════════════    │
│                                                                              │
│  PAGOS DEL CLIENTE:                                                          │
│    Pago quincenal:                  $2,765.00                                │
│    Pago total:                      $33,180.00                               │
│    Interés total:                   $11,180.00                               │
│    Tasa efectiva:                   50.82%                                   │
│                                                                              │
│  ════════════════════════════════════════════════════════════════════════    │
│                                                                              │
│  PAGOS DEL ASOCIADO (Socio):                                                 │
│    Comisión por pago:               $69.13                                   │
│    Comisión total:                  $829.50                                  │
│    Pago quincenal al socio:         $2,695.88                                │
│    Pago total al socio:             $32,350.50                               │
│                                                                              │
│  ════════════════════════════════════════════════════════════════════════    │
│                                                                              │
│  DISTRIBUCIÓN:                                                               │
│    Cliente paga:                    $33,180.00 (100%)                        │
│      ├─ Capital recuperado:         $22,000.00 (66.31%)                      │
│      ├─ Interés empresa:            $11,180.00 (33.69%)                      │
│      └─ Comisión empresa:           $829.50 (2.50% del total pagado)         │
│                                                                              │
│    Asociado recibe:                 $32,350.50 (97.50% de lo pagado)         │
│    Empresa retiene (comisión):      $829.50 (2.50% de lo pagado)             │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Campos Retornados

```
capital                      DECIMAL(12,2)  = $22,000.00
plazo_quincenas             INTEGER        = 12
tasa_interes_quincenal      DECIMAL(5,3)   = 4.250
tasa_comision               DECIMAL(5,2)   = 2.50

-- CLIENTE
pago_quincenal_cliente      DECIMAL(10,2)  = $2,765.00
pago_total_cliente          DECIMAL(12,2)  = $33,180.00
interes_total_cliente       DECIMAL(12,2)  = $11,180.00
tasa_efectiva_cliente       DECIMAL(5,2)   = 50.82

-- ASOCIADO (SOCIO)
comision_por_pago           DECIMAL(10,2)  = $69.13
comision_total_socio        DECIMAL(12,2)  = $829.50
pago_quincenal_socio        DECIMAL(10,2)  = $2,695.88
pago_total_socio            DECIMAL(12,2)  = $32,350.50
```

---

## 📅 TABLA DE AMORTIZACIÓN (generate_amortization_schedule)

### Salida de la Función

```sql
SELECT * FROM generate_amortization_schedule(
    22000,          -- capital
    2765,           -- pago quincenal
    12,             -- plazo
    2.5,            -- comisión %
    '2025-11-15'    -- fecha inicio
);
```

### Resultado:

```
┌────────────────────────────────────────────────────────────────────────────────┐
│                     TABLA DE AMORTIZACIÓN / PROYECCIÓN                         │
├────────────────────────────────────────────────────────────────────────────────┤
│                                                                                │
│  Período  Fecha         Pago      Interés   Capital    Saldo      Comisión  │
│                        Cliente              Cliente   Pendiente    Socio     │
│  ──────────────────────────────────────────────────────────────────────────  │
│                                                                                │
│    1     2025-11-15   $2,765.00   $931.67  $1,833.33  $20,166.67   $69.13   │
│    2     2025-11-30   $2,765.00   $931.67  $1,833.33  $18,333.33   $69.13   │
│    3     2025-12-15   $2,765.00   $931.67  $1,833.33  $16,500.00   $69.13   │
│    4     2025-12-31   $2,765.00   $931.67  $1,833.33  $14,666.67   $69.13   │
│    5     2026-01-15   $2,765.00   $931.67  $1,833.33  $12,833.33   $69.13   │
│    6     2026-01-31   $2,765.00   $931.67  $1,833.33  $11,000.00   $69.13   │
│    7     2026-02-15   $2,765.00   $931.67  $1,833.33   $9,166.67   $69.13   │
│    8     2026-02-28   $2,765.00   $931.67  $1,833.33   $7,333.33   $69.13   │
│    9     2026-03-15   $2,765.00   $931.67  $1,833.33   $5,500.00   $69.13   │
│   10     2026-03-31   $2,765.00   $931.67  $1,833.33   $3,666.67   $69.13   │
│   11     2026-04-15   $2,765.00   $931.67  $1,833.33   $1,833.33   $69.13   │
│   12     2026-04-30   $2,765.00   $931.67  $1,833.33       $0.00   $69.13   │
│  ──────────────────────────────────────────────────────────────────────────  │
│  TOTALES           $33,180.00  $11,180.00 $22,000.00              $829.56   │
│                                                                                │
│  PAGOS AL ASOCIADO:                                                            │
│    Pago quincenal al socio:  $2,695.88 ($2,765 - $69.13)                      │
│    Total al socio 12 pagos:  $32,350.50                                       │
│                                                                                │
└────────────────────────────────────────────────────────────────────────────────┘
```

### Campos Retornados

```
periodo              INTEGER        = 1, 2, 3, ..., 12
fecha_pago           DATE           = 2025-11-15, 2025-11-30, ...
pago_cliente         DECIMAL(10,2)  = $2,765.00 (constante)
interes_cliente      DECIMAL(10,2)  = $931.67 (distribución proporcional)
capital_cliente      DECIMAL(10,2)  = $1,833.33 (amortización)
saldo_pendiente      DECIMAL(12,2)  = $20,166.67 → ... → $0.00
comision_socio       DECIMAL(10,2)  = $69.13 (constante)
pago_socio           DECIMAL(10,2)  = $2,695.88 (pago - comisión)
```

---

## 🔧 INTEGRACIÓN CON SISTEMA EXISTENTE

### 1. Modificación en loans

El campo `interest_rate` ya existe en `loans` table:

```sql
-- Ya existe en db/v2.0/modules/02_core_tables.sql:
CREATE TABLE loans (
    ...
    interest_rate DECIMAL(5, 2) NOT NULL,      -- ✅ Tasa del cliente
    commission_rate DECIMAL(5, 2) NOT NULL,    -- ✅ Tasa del asociado
    ...
);
```

**NO requiere modificación.** El sistema ya está preparado.

### 2. Flujo al Crear Préstamo

```
1. Admin selecciona perfil (legacy/standard/premium/custom)
2. Backend llama: calculate_loan_payment(amount, term, profile)
3. Backend genera: generate_loan_summary(amount, term, interest_rate, commission_rate)
4. UI muestra tabla resumen + amortización
5. Admin ajusta tasas si necesario
6. Al aprobar:
   → Guarda interest_rate en loans.interest_rate
   → Guarda commission_rate en loans.commission_rate
   → Trigger generate_payment_schedule() crea cronograma
```

### 3. Compatibilidad con Funciones Existentes

```sql
-- generate_payment_schedule() en 06_functions_business.sql
-- YA usa loans.amount y loans.term_biweeks
-- SOLO calcula cuántas quincenas, NO las tasas

-- ✅ NO requiere modificación
-- Las tasas se guardan en loans.interest_rate y commission_rate
-- El cronograma usa amount / term_biweeks para calcular pago base
```

---

## 🎯 CASOS DE USO

### Caso 1: Cliente pide $22,000 a 12 quincenas con perfil Standard

```sql
-- 1. Calcular préstamo
SELECT * FROM calculate_loan_payment(22000, 12, 'standard');

-- Resultado:
--   biweekly_payment: $2,765.00
--   total_payment: $33,180.00
--   total_interest: $11,180.00
--   effective_rate: 50.82%
--   profile: "Estándar 4.25% - Recomendado"

-- 2. Generar resumen completo (con comisión 2.5%)
SELECT * FROM generate_loan_summary(22000, 12, 4.25, 2.5);

-- 3. Ver tabla de amortización
SELECT * FROM generate_amortization_schedule(
    22000, 2765, 12, 2.5, CURRENT_DATE
);

-- 4. Crear préstamo (en aplicación)
INSERT INTO loans (
    user_id, associate_user_id, amount, 
    interest_rate, commission_rate, term_biweeks, status_id
) VALUES (
    123, 456, 22000, 
    4.25, 2.5, 12, 1
);
```

### Caso 2: Admin agrega nuevo monto $7,500 a tabla legacy

```sql
-- Agregar a tabla legacy
INSERT INTO legacy_payment_table (amount, biweekly_payment, term_biweeks)
VALUES (7500, 962.50, 12);

-- Verificar cálculos automáticos
SELECT 
    amount,
    biweekly_payment,
    total_payment,           -- Auto: $11,550
    total_interest,          -- Auto: $4,050
    effective_rate_percent,  -- Auto: 54.00%
    biweekly_rate_percent    -- Auto: 4.500%
FROM legacy_payment_table
WHERE amount = 7500;

-- Ahora perfil 'legacy' puede usar $7,500
SELECT * FROM calculate_loan_payment(7500, 12, 'legacy');
```

### Caso 3: Comparar múltiples perfiles para un cliente

```sql
-- Ver todos los perfiles disponibles para $22k @ 12Q
SELECT 
    p.name AS perfil,
    calc.*
FROM rate_profiles p
CROSS JOIN LATERAL calculate_loan_payment(22000, 12, p.code) calc
WHERE p.enabled = true
  AND (p.valid_terms IS NULL OR 12 = ANY(p.valid_terms))
ORDER BY calc.biweekly_payment;

-- Resultado:
--   Legacy:     $2,759/Q (50.49%)
--   Transición: $2,642/Q (45.00%) ← Cliente AHORRA
--   Estándar:   $2,765/Q (51.00%) ← RECOMENDADO
--   Premium:    $2,823/Q (54.00%)
```

---

## 📦 INSTALACIÓN

### Opción 1: Agregar al init.sql monolítico

```sql
-- En db/v2.0/init.sql, después del módulo 09_seeds.sql:

\echo '============================================================'
\echo 'MÓDULO 10: RATE PROFILES'
\echo '============================================================'
\i modules/10_rate_profiles.sql
```

### Opción 2: Ejecutar manualmente

```bash
# Desde raíz del proyecto
psql -U postgres -d credinet_v2 -f db/v2.0/modules/10_rate_profiles.sql

# O si prefieres regenerar completo:
cd db/v2.0
./generate_monolithic.sh
psql -U postgres -d credinet_v2 -f init.sql
```

---

## ✅ VALIDACIÓN

### Tests de Funcionalidad

```sql
-- Test 1: Perfiles creados
SELECT code, name, enabled FROM rate_profiles ORDER BY display_order;
-- Esperado: 5 perfiles (legacy, transition, standard, premium, custom)

-- Test 2: Datos legacy cargados
SELECT COUNT(*) FROM legacy_payment_table;
-- Esperado: 28 montos

-- Test 3: Cálculo legacy
SELECT biweekly_payment FROM calculate_loan_payment(22000, 12, 'legacy');
-- Esperado: $2,759.00

-- Test 4: Cálculo standard
SELECT biweekly_payment FROM calculate_loan_payment(22000, 12, 'standard');
-- Esperado: $2,765.00

-- Test 5: Resumen completo
SELECT 
    pago_quincenal_cliente,
    pago_quincenal_socio,
    comision_total_socio
FROM generate_loan_summary(22000, 12, 4.25, 2.5);
-- Esperado: $2,765.00, $2,695.88, $829.50

-- Test 6: Amortización
SELECT COUNT(*) FROM generate_amortization_schedule(22000, 2765, 12, 2.5, CURRENT_DATE);
-- Esperado: 12 períodos
```

---

## 🚀 PRÓXIMOS PASOS

1. **Backend API** (Python FastAPI)
   - Endpoint `/api/loans/calculate`
   - Endpoint `/api/loans/summary`
   - Endpoint `/api/loans/amortization`
   - CRUD para `legacy_payment_table`

2. **Frontend UI** (React)
   - Selector de perfiles visual
   - Comparador lado a lado
   - Vista tabla resumen
   - Vista tabla de amortización

3. **Integración**
   - Modificar flujo crear préstamo
   - Guardar `interest_rate` y `commission_rate` en loans
   - Mostrar preview antes de aprobar

---

## 📞 SOPORTE

**Documentos relacionados:**
- `PROPUESTA_SISTEMA_TASAS_FLEXIBLE.md` - Propuesta inicial
- `PLAN_SISTEMA_TASAS_HIBRIDO_FINAL.md` - Arquitectura completa
- `ANALISIS_COMPARATIVO_COMPLETO.md` - Análisis financiero

**Versión:** 2.0.3  
**Estado:** ✅ Listo para integración  
**Compatibilidad:** 100% con módulos 01-09 existentes
