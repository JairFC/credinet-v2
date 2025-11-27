# EXPLICACIÓN VISUAL: Las Dos Tasas Calculan Todo

## 🎯 CONCEPTO CLAVE

```
┌─────────────────────────────────────────────────────────────────────┐
│                                                                     │
│   ¿POR QUÉ SOLO NECESITAS 2 TASAS PARA CALCULAR TODO?              │
│                                                                     │
│   Porque el sistema usa INTERÉS SIMPLE sobre el capital total:     │
│                                                                     │
│     Total = Capital × (1 + tasa × plazo)                           │
│                                                                     │
│   NO es interés compuesto                                           │
│   NO es amortización francesa                                       │
│   ES: Interés simple distribuido equitativamente                    │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 📐 FÓRMULA BASE (Interés Simple)

### Lado CLIENTE (interest_rate)

```
DATOS INICIALES:
  Capital (C):           $22,000
  Tasa quincenal (r):    4.25% = 0.0425
  Plazo (n):             12 quincenas

PASO 1: Calcular factor de crecimiento
  Factor = 1 + (r × n)
  Factor = 1 + (0.0425 × 12)
  Factor = 1 + 0.51
  Factor = 1.51

PASO 2: Calcular monto total a pagar
  Total = C × Factor
  Total = $22,000 × 1.51
  Total = $33,220.00

PASO 3: Calcular pago quincenal (distribuido equitativamente)
  Pago/Q = Total / n
  Pago/Q = $33,220 / 12
  Pago/Q = $2,768.33

PASO 4: Calcular interés total
  Interés = Total - Capital
  Interés = $33,220 - $22,000
  Interés = $11,220.00

PASO 5: Calcular tasa efectiva (sobre plazo completo)
  Tasa Efectiva = (Interés / Capital) × 100
  Tasa Efectiva = ($11,220 / $22,000) × 100
  Tasa Efectiva = 51.00%
```

**Resultado Lado Cliente:**
```
┌─────────────────────────────────────┐
│  LADO CLIENTE                       │
├─────────────────────────────────────┤
│  Capital:            $22,000.00     │
│  Pago/Quincena:      $2,768.33      │
│  Total a pagar:      $33,220.00     │
│  Interés total:      $11,220.00     │
│  Tasa quincenal:     4.25%          │
│  Tasa efectiva:      51.00%         │
└─────────────────────────────────────┘
```

---

### Lado ASOCIADO (commission_rate)

```
DATOS INICIALES:
  Pago quincenal cliente:  $2,768.33   (del cálculo anterior)
  Tasa comisión (c):       2.5% = 0.025
  Plazo (n):               12 quincenas

PASO 1: Calcular comisión por pago
  Comisión/Pago = Pago_cliente × c
  Comisión/Pago = $2,768.33 × 0.025
  Comisión/Pago = $69.21

PASO 2: Calcular pago quincenal al socio
  Pago_socio/Q = Pago_cliente - Comisión/Pago
  Pago_socio/Q = $2,768.33 - $69.21
  Pago_socio/Q = $2,699.12

PASO 3: Calcular comisión total
  Comisión_total = Comisión/Pago × n
  Comisión_total = $69.21 × 12
  Comisión_total = $830.52

PASO 4: Calcular total al socio
  Total_socio = Pago_socio/Q × n
  Total_socio = $2,699.12 × 12
  Total_socio = $32,389.44

VERIFICACIÓN (debe sumar):
  Total_cliente = Total_socio + Comisión_total
  $33,220.00 = $32,389.44 + $830.52  ✅
```

**Resultado Lado Asociado:**
```
┌─────────────────────────────────────┐
│  LADO ASOCIADO                      │
├─────────────────────────────────────┤
│  Comisión/Pago:      $69.21         │
│  Pago/Quincena:      $2,699.12      │
│  Comisión total:     $830.52        │
│  Total al socio:     $32,389.44     │
│  Tasa comisión:      2.5%           │
└─────────────────────────────────────┘
```

---

## 🔄 FLUJO COMPLETO: De Tasas a Tabla de Amortización

```
┌──────────────────────────────────────────────────────────────────────────┐
│                         ENTRADA (Solo 2 tasas)                           │
└──────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
                ┌───────────────────────────────────────┐
                │  interest_rate = 4.25%                │
                │  commission_rate = 2.5%               │
                │  Capital = $22,000                    │
                │  Plazo = 12 quincenas                 │
                └───────────────────────────────────────┘
                                    │
                                    ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                      CÁLCULO LADO CLIENTE                                │
└──────────────────────────────────────────────────────────────────────────┘
                                    │
                    Factor = 1 + (0.0425 × 12) = 1.51
                                    │
                    Total = $22,000 × 1.51 = $33,220
                                    │
                    Pago/Q = $33,220 / 12 = $2,768.33
                                    │
                    Interés_total = $33,220 - $22,000 = $11,220
                                    │
                    Interés/Q = $11,220 / 12 = $935.00
                                    │
                    Capital/Q = $22,000 / 12 = $1,833.33
                                    │
                                    ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                      CÁLCULO LADO ASOCIADO                               │
└──────────────────────────────────────────────────────────────────────────┘
                                    │
                    Comisión/Q = $2,768.33 × 0.025 = $69.21
                                    │
                    Pago_socio/Q = $2,768.33 - $69.21 = $2,699.12
                                    │
                                    ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                   GENERAR CRONOGRAMA (12 períodos)                       │
└──────────────────────────────────────────────────────────────────────────┘
                                    │
        Para cada período p (1 a 12):
          • fecha_pago = calcular con calendario doble
          • pago_cliente = $2,768.33 (constante)
          • interes_cliente = $935.00 (proporcional)
          • capital_cliente = $1,833.33 (constante)
          • saldo_pendiente = Capital - (Capital/Q × p)
          • comision_socio = $69.21 (constante)
          • pago_socio = $2,699.12 (constante)
                                    │
                                    ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                         TABLA AMORTIZACIÓN                               │
└──────────────────────────────────────────────────────────────────────────┘

 P  | Fecha      | Pago ₵  | Int ₵  | Cap ₵    | Saldo     | Com $  | Pago $
----+------------+---------+--------+----------+-----------+--------+----------
  1 | 2025-11-15 | 2768.33 | 935.00 | 1833.33  | 20,166.67 | 69.21  | 2699.12
  2 | 2025-11-30 | 2768.33 | 935.00 | 1833.33  | 18,333.34 | 69.21  | 2699.12
  3 | 2025-12-15 | 2768.33 | 935.00 | 1833.33  | 16,500.01 | 69.21  | 2699.12
  4 | 2025-12-31 | 2768.33 | 935.00 | 1833.33  | 14,666.68 | 69.21  | 2699.12
  5 | 2026-01-15 | 2768.33 | 935.00 | 1833.33  | 12,833.35 | 69.21  | 2699.12
  6 | 2026-01-31 | 2768.33 | 935.00 | 1833.33  | 11,000.02 | 69.21  | 2699.12
  7 | 2026-02-15 | 2768.33 | 935.00 | 1833.33  | 9,166.69  | 69.21  | 2699.12
  8 | 2026-02-28 | 2768.33 | 935.00 | 1833.33  | 7,333.36  | 69.21  | 2699.12
  9 | 2026-03-15 | 2768.33 | 935.00 | 1833.33  | 5,500.03  | 69.21  | 2699.12
 10 | 2026-03-31 | 2768.33 | 935.00 | 1833.33  | 3,666.70  | 69.21  | 2699.12
 11 | 2026-04-15 | 2768.33 | 935.00 | 1833.33  | 1,833.37  | 69.21  | 2699.12
 12 | 2026-04-30 | 2768.33 | 935.00 | 1833.33  | 0.04      | 69.21  | 2699.12
----+------------+---------+--------+----------+-----------+--------+----------
TOT              | 33220   | 11220  | 22000    |           | 830.52 | 32389.44

₵ = Cliente    $ = Socio
```

---

## 🧮 COMPARACIÓN: Fórmula vs Tabla Legacy

### MÉTODO 1: Tabla Legacy (lookup)

```
Cliente pide: $22,000 @ 12Q

Búsqueda en legacy_payment_table:
  WHERE amount = 22000 AND term_biweeks = 12
  
Resultado (directo de tabla):
  ┌─────────────────────────────────────┐
  │  biweekly_payment:    $2,759.00     │
  │  total_payment:       $33,108.00    │
  │  total_interest:      $11,108.00    │
  │  rate (implícita):    4.208%        │
  └─────────────────────────────────────┘

NO calcula nada - solo retorna valores guardados
```

### MÉTODO 2: Fórmula (calculation)

```
Cliente pide: $22,000 @ 12Q con perfil "standard" (4.25%)

Cálculo matemático:
  Factor = 1 + (0.0425 × 12) = 1.51
  Total = $22,000 × 1.51 = $33,220.00
  Pago/Q = $33,220 / 12 = $2,768.33

Resultado (calculado):
  ┌─────────────────────────────────────┐
  │  biweekly_payment:    $2,768.33     │
  │  total_payment:       $33,220.00    │
  │  total_interest:      $11,220.00    │
  │  rate (aplicada):     4.25%         │
  └─────────────────────────────────────┘

Calcula en tiempo real con tasa configurada
```

### Diferencia

```
Perfil        | Pago/Q    | Diferencia vs Legacy | Notas
--------------+-----------+----------------------+-------------------------
Legacy        | $2,759.00 | $0.00 (base)         | Valor histórico guardado
Standard 4.25%| $2,768.33 | +$9.33 (+0.34%)      | Calculado matemáticamente
Transition 3.75% | $2,642.00 | -$117.00 (-4.24%) | Cliente AHORRA
Premium 4.5%  | $2,823.33 | +$64.33 (+2.33%)     | Deshabilitado
```

---

## 🔍 POR QUÉ LA TABLA LEGACY TIENE TASAS VARIABLES

```
Observación: Las tasas en legacy_payment_table varían (4.20% a 4.73%)

 Monto   | Pago/Q  | Tasa Implícita | ¿Por qué diferente?
---------+---------+----------------+------------------------------------
 $3,000  | $392    | 4.733%         | Ajuste manual histórico
 $6,000  | $752    | 4.200%         | Redondeo favorable al cliente
 $22,000 | $2,759  | 4.208%         | Equilibrio comercial
 $30,000 | $3,765  | 4.217%         | Consistencia con rango alto
```

**Razones:**
1. **Redondeos comerciales**: Pagos redondeados a cifras "bonitas"
2. **Ajustes manuales**: Decisiones de negocio caso por caso
3. **Competencia**: Igualar o mejorar tasas de la competencia
4. **Segmentación**: Mejores tasas para montos más altos
5. **Histórico**: Tasas que funcionaron bien en el pasado

**Ventaja del nuevo sistema:**
- ✅ Perfil "legacy" mantiene estos valores exactos
- ✅ Perfil "standard" ofrece tasa consistente (4.25%)
- ✅ Perfil "transition" ofrece mejora (3.75%)
- ✅ Admin puede elegir según cada caso

---

## 📊 TABLA RESUMEN: Una Tasa o Dos

```
┌─────────────────────────────────────────────────────────────────────┐
│                      ¿CUÁNTAS TASAS HAY?                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  RESPUESTA: DOS tasas independientes                                │
│                                                                     │
│  1️⃣  interest_rate (Tasa Cliente)                                  │
│     • Define cuánto paga el cliente sobre el capital                │
│     • Ejemplo: 4.25% quincenal                                      │
│     • Almacenada en: loans.interest_rate                            │
│     • Usada para calcular:                                          │
│         - pago_quincenal_cliente                                    │
│         - pago_total_cliente                                        │
│         - interes_total_cliente                                     │
│                                                                     │
│  2️⃣  commission_rate (Comisión Socio)                              │
│     • Define cuánto cobra la empresa al asociado                    │
│     • Ejemplo: 2.5% sobre cada pago                                 │
│     • Almacenada en: loans.commission_rate                          │
│     • Usada para calcular:                                          │
│         - comision_por_pago                                         │
│         - pago_quincenal_socio                                      │
│         - comision_total_socio                                      │
│                                                                     │
│  ✅ Son INDEPENDIENTES: Se pueden cambiar por separado              │
│  ✅ Son SUFICIENTES: Con estas 2 calculas todo el préstamo          │
│  ✅ Ya EXISTEN: Ya están en tabla loans (interest_rate, commission) │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 💡 EJEMPLOS PRÁCTICOS

### Ejemplo 1: Préstamo Standard

```sql
SELECT * FROM generate_loan_summary(
    22000,  -- capital
    12,     -- plazo
    4.25,   -- interest_rate (cliente)
    2.5     -- commission_rate (socio)
);
```

**Interpretación:**
```
Cliente pide:                 $22,000
Cliente paga/Q:               $2,768.33
Cliente paga total:           $33,220.00
Cliente paga interés:         $11,220.00
  ↓
Empresa cobra comisión/Q:     $69.21
Empresa cobra total:          $830.52
  ↓
Socio recibe/Q:               $2,699.12
Socio recibe total:           $32,389.44
```

### Ejemplo 2: Cambiar Solo Comisión

```sql
-- Misma tasa cliente, diferente comisión
SELECT * FROM generate_loan_summary(
    22000,  -- capital
    12,     -- plazo
    4.25,   -- interest_rate (IGUAL)
    1.5     -- commission_rate (MENOR)
);
```

**Resultado:**
```
Cliente: TODO IGUAL ($2,768.33/Q)
  ↓
Comisión: MENOR ($41.52/Q vs $69.21/Q)
  ↓
Socio: RECIBE MÁS ($2,726.81/Q vs $2,699.12/Q)
```

**Conclusión:** Puedes ajustar la comisión sin cambiar lo que paga el cliente.

### Ejemplo 3: Cambiar Solo Tasa Cliente

```sql
-- Diferente tasa cliente, misma comisión
SELECT * FROM generate_loan_summary(
    22000,  -- capital
    12,     -- plazo
    3.75,   -- interest_rate (MENOR)
    2.5     -- commission_rate (IGUAL)
);
```

**Resultado:**
```
Cliente: PAGA MENOS ($2,642.00/Q vs $2,768.33/Q)
  ↓
Comisión: $66.05/Q (2.5% de nuevo pago)
  ↓
Socio: RECIBE MENOS ($2,575.95/Q)
```

**Conclusión:** Bajar tasa cliente reduce ingreso del socio (porque hay menos para cobrar).

---

## 🎯 RESUMEN FINAL

```
╔══════════════════════════════════════════════════════════════════╗
║                                                                  ║
║  CON SOLO 2 TASAS PUEDES CALCULAR TODO EL PRÉSTAMO:             ║
║                                                                  ║
║  ✅ Pago quincenal del cliente                                   ║
║  ✅ Total a pagar del cliente                                    ║
║  ✅ Interés total del cliente                                    ║
║  ✅ Comisión por pago al socio                                   ║
║  ✅ Pago quincenal al socio                                      ║
║  ✅ Total al socio                                               ║
║  ✅ Tabla de amortización completa (12 períodos)                 ║
║  ✅ Fechas de pago (calendario doble)                            ║
║  ✅ Distribución de interés y capital por período                ║
║                                                                  ║
║  NO NECESITAS NADA MÁS                                           ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
```

---

**Autor:** Sistema Credinet v2.0  
**Fecha:** 2025-11-04  
**Documento:** Explicación matemática del sistema de dos tasas
