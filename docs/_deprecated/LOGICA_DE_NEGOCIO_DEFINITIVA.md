# 🎯 LÓGICA DE NEGOCIO DEFINITIVA - CREDINET

> **Documento Maestro de Lógica de Negocio**  
> **Versión**: 2.0.0  
> **Fecha**: 2025-10-22  
> **Propósito**: Fuente única de verdad para TODA la lógica de negocio  
> **Audiencia**: Desarrolladores, DBAs, Product Owners, QA  

---

## 📋 TABLA DE CONTENIDO

1. [Contexto del Sistema](#contexto-del-sistema)
2. [Actores del Sistema](#actores-del-sistema)
3. [Flujos Principales de Negocio](#flujos-principales-de-negocio)
4. [Reglas de Negocio Críticas](#reglas-de-negocio-críticas)
5. [Casos de Uso Detallados](#casos-de-uso-detallados)
6. [Cálculos y Fórmulas](#cálculos-y-fórmulas)
7. [Estados y Transiciones](#estados-y-transiciones)
8. [Validaciones Automáticas](#validaciones-automáticas)
9. [Ejemplos Paso a Paso](#ejemplos-paso-a-paso)

---

## 🌐 CONTEXTO DEL SISTEMA

### ¿Qué es Credinet?

**Credinet** es un sistema de microcréditos que opera mediante **asociados (distribuidoras)** que gestionan carteras de clientes. El sistema tiene una característica única: **pagos quincenales** con un doble calendario muy específico.

### Modelo de Negocio

```
FLUJO DE DINERO:
1. CrediCuenta → Presta dinero a Cliente (a través de Asociado)
2. Cliente → Paga quincenas a Asociado
3. Asociado → Reporta cobros y paga a CrediCuenta

ROLES FINANCIEROS:
- CrediCuenta: Prestamista (dueño del capital)
- Asociado: Gestor de cartera (cobra comisión)
- Cliente: Deudor final (paga el préstamo)
```

### Sistema de Doble Calendario (CRÍTICO)

Este es el **corazón del sistema** y la lógica más importante:

```
CALENDARIO ADMINISTRATIVO (Cortes):
- Día 8 del mes (00:00:00): Corte período 1
- Día 23 del mes (00:00:00): Corte período 2

CALENDARIO DE CLIENTE (Vencimientos):
- Día 15 del mes: Vencimiento opción A
- Último día del mes: Vencimiento opción B

LÓGICA DE ASIGNACIÓN:
┌─────────────────────────────────────────────────┐
│ Si préstamo aprobado días 1-7                   │
│ → Primer pago: día 15 del MISMO mes            │
│ → Pertenece al corte del día 8                 │
├─────────────────────────────────────────────────┤
│ Si préstamo aprobado días 8-22                  │
│ → Primer pago: ÚLTIMO día del MISMO mes        │
│ → Pertenece al corte del día 23                │
├─────────────────────────────────────────────────┤
│ Si préstamo aprobado días 23-31                 │
│ → Primer pago: día 15 del SIGUIENTE mes        │
│ → Pertenece al corte del día 8 siguiente       │
└─────────────────────────────────────────────────┘

ALTERNANCIA:
Después del primer pago, las fechas alternan:
Día 15 → Último día → Día 15 → Último día → ...
```

**Ejemplo Real**:
```
Préstamo aprobado: 7 enero 2025 (09:00 AM)
Día: 7 (entre 1-7)
→ Primer pago: 15 enero 2025
→ Segundo pago: 31 enero 2025
→ Tercer pago: 15 febrero 2025
→ Cuarto pago: 28 febrero 2025 (último día, no bisiesto)
→ Quinto pago: 15 marzo 2025
→ ... así sucesivamente
```

---

## 👥 ACTORES DEL SISTEMA

### 1. Desarrollador (Rol: `desarrollador`)
- **Permisos**: Acceso total al sistema
- **Responsabilidad**: Mantenimiento técnico
- **Usuario ejemplo**: `jair` (ID: 1)

### 2. Administrador (Rol: `administrador`)
- **Permisos**: Gestión completa de préstamos y operaciones
- **Responsabilidades**:
  - ✅ Crear solicitudes de préstamo a nombre de clientes (vía WhatsApp)
  - ✅ Aprobar/rechazar préstamos
  - ✅ Registrar pagos de clientes reportados por asociados
  - ✅ Registrar abonos/liquidaciones de asociados
  - ✅ Aprobar reportes de clientes morosos
  - ✅ Crear convenios para asociados con clientes morosos
  - ✅ Cerrar períodos de corte
  - ✅ Gestionar usuarios y asignar roles
- **Usuario ejemplo**: `admin` (ID: 2)
- **Nota**: Por el momento, el admin opera TODO el sistema

### 3. Auxiliar Administrativo (Rol: `auxiliar_administrativo`)
- **Permisos**: Operaciones de soporte bajo supervisión
- **Responsabilidades**:
  - ✅ Registrar pagos de clientes
  - ✅ Registrar abonos de asociados
  - ✅ Consultar estados de cuenta
  - ✅ Generar reportes
- **Usuario ejemplo**: `aux.admin` (ID: 7)
- **Nota**: Rol de apoyo, no puede aprobar préstamos ni cerrar períodos

### 4. Asociado (Rol: `asociado`)
- **Permisos**: Gestión de su cartera de clientes
- **Responsabilidades**:
  - ✅ Cobrar quincenas a sus clientes (fuera del sistema)
  - ✅ Reportar pagos cobrados al sistema
  - ✅ Liquidar estados de cuenta a CrediCuenta
  - ✅ Gestionar liquidaciones parciales si tiene deuda
  - ✅ Reportar clientes morosos con evidencia
- **Características**:
  - Tiene nivel (Bronce, Plata, Oro, Platino, Diamante)
  - **Límite de crédito global** basado en su nivel (NO por préstamo individual)
  - **Crédito disponible** = credit_limit - credit_used - debt_balance
  - Se ocupa al aprobar préstamos, se libera con pagos recibidos
  - Gana comisión sobre pagos cobrados
  - Es 100% responsable de su cartera (absorbe deuda de clientes morosos)
- **Usuario ejemplo**: `asociado_test` (ID: 3)
- **Nota**: Por ahora, el admin registra sus operaciones, pero sistema preparado para futuro

### 5. Cliente (Rol: `cliente`)
- **Permisos**: Consulta de sus préstamos
- **Responsabilidades**:
  - ✅ Pagar quincenas al asociado
  - ✅ Cumplir cronograma de pagos
- **Características**:
  - Puede tener múltiples préstamos (si no es moroso)
  - Puede renovar préstamo antes de terminarlo
- **Usuario ejemplo**: `sofia.vargas` (ID: 4)

---

## 🔄 FLUJOS PRINCIPALES DE NEGOCIO

### FLUJO 1: Solicitud y Aprobación de Préstamo

```
INICIADOR: Cliente o Admin (vía WhatsApp)
DURACIÓN: 1-3 días laborales
RESULTADO: Préstamo activo con cronograma generado

┌─────────────────────────────────────────────────────┐
│ PASO 1: Solicitud                                    │
├─────────────────────────────────────────────────────┤
│ OPCIÓN A: Cliente solicita directamente (FUTURO)    │
│   1. Cliente llena formulario en sistema            │
│   2. Sistema crea préstamo con status = PENDING     │
│   3. Campo created_by = user_id (cliente)           │
│   ⚠️  Por ahora NO disponible, preparado para v2.0  │
│                                                      │
│ OPCIÓN B: Admin crea a nombre de cliente (ACTUAL)   │
│   1. Cliente contacta Admin por WhatsApp/teléfono   │
│   2. Admin verifica identidad y documentos          │
│   3. Admin llena formulario igual que opción A      │
│   4. Campo created_by = 2 (admin_id)                │
│   5. Campo user_id = cliente_id (dueño del préstamo)│
│   ✅ Esta es la operación ACTUAL del sistema        │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│ PASO 2: Validaciones Pre-Aprobación                 │
├─────────────────────────────────────────────────────┤
│ Sistema valida:                                      │
│ ✓ Cliente NO es moroso (is_defaulter = FALSE)       │
│ ✓ Asociado tiene CRÉDITO DISPONIBLE suficiente      │
│ ✓ credit_available >= monto_préstamo (NUEVO)        │
│ ✓ Cliente tiene documentos completos                │
│ ✓ Monto <= credit_limit del asociado                │
│                                                      │
│ SQL: SELECT * FROM check_associate_credit_available(│
│   p_associate_id := 3,                              │
│   p_loan_amount := 100000                           │
│ );                                                  │
│                                                      │
│ Retorna:                                             │
│   has_credit: TRUE/FALSE                            │
│   credit_available: 150000.00                       │
│   shortage: 0 (si tiene, o déficit si no)           │
│                                                      │
│ Si falla: Préstamo se marca REJECTED                │
│ Si pasa: Admin puede aprobar                        │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│ PASO 3: Aprobación                                  │
├─────────────────────────────────────────────────────┤
│ Admin ejecuta:                                       │
│   UPDATE loans                                       │
│   SET status_id = 2,  -- APPROVED                   │
│       approved_at = CURRENT_TIMESTAMP,              │
│       approved_by = 2  -- admin_id                  │
│   WHERE id = 123;                                   │
│                                                      │
│ ⚡ TRIGGER AUTOMÁTICO: handle_loan_approval_trigger │
│   → Actualiza approved_at si es NULL                │
│                                                      │
│ ⚡ TRIGGER CRÍTICO: generate_payment_schedule       │
│   → Detecta cambio a APPROVED                       │
│   → Llama calculate_first_payment_date()            │
│   → Genera N registros en payments (N=term_biweeks) │
│   → Asigna fechas alternadas: día 15 ↔ último día  │
│   → Asocia cada pago con su cut_period_id           │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│ PASO 4: Generación de Contrato                      │
├─────────────────────────────────────────────────────┤
│ Sistema genera automáticamente:                     │
│   INSERT INTO contracts (                           │
│     loan_id, document_number, status_id, start_date │
│   ) VALUES (                                        │
│     123, 'CONT-2025-123', 3, CURRENT_DATE           │
│   );                                                │
│                                                      │
│ Asocia contrato con préstamo:                       │
│   UPDATE loans SET contract_id = X WHERE id = 123; │
└─────────────────────────────────────────────────────┘

RESULTADO FINAL:
├── Préstamo status = APPROVED
├── Cronograma de N pagos generado (donde N = term_biweeks)
├── Cada pago con payment_due_date calculado (día 15 o último del mes)
├── Contrato firmado digitalmente
├── Crédito del asociado actualizado: credit_used += monto_préstamo
└── Cliente puede recibir desembolso
```

### FLUJO 2: Pago Quincenal del Cliente (⚠️ FUTURO - v2.0)

```
⚠️  NOTA: Este flujo está documentado para futuro, pero por ahora
   NO se implementa. El sistema actual solo rastrea liquidaciones
   del asociado a CrediCuenta, NO pagos individuales de clientes.
   
INICIADOR: Cliente (en futuro, por ahora N/A)
FRECUENCIA: Cada 15 días
RESULTADO: Pago registrado, comisión calculada

┌─────────────────────────────────────────────────────┐
│ PASO 1: Cliente Paga al Asociado (FUERA DEL SISTEMA)│
├─────────────────────────────────────────────────────┤
│ MEDIO: Efectivo, transferencia, depósito            │
│ FECHA: Día 15 o último día del mes (según cronograma)│
│ MONTO: Monto de la quincena (ej: $8,333.33 FICTICIO)│
│                                                      │
│ ⚠️ IMPORTANTE: Esto ocurre FÍSICAMENTE, fuera del  │
│    sistema. El sistema solo REGISTRA después.       │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│ PASO 2: Asociado Reporta Pago (DENTRO DEL SISTEMA)  │
├─────────────────────────────────────────────────────┤
│ Opción A: Asociado reporta (FUTURO, si tiene acceso)│
│ Opción B: Admin registra el pago (ACTUAL)           │
│                                                      │
│ SQL:                                                 │
│   UPDATE payments                                    │
│   SET amount_paid = 8333.33,                        │
│       payment_date = '2025-01-15',                  │
│       actual_payment_date = '2025-01-15',           │
│       status_id = 3,  -- PAID                       │
│       is_late = CASE                                │
│         WHEN '2025-01-15' > payment_due_date        │
│         THEN TRUE ELSE FALSE                        │
│       END                                           │
│   WHERE id = 456;                                   │
│                                                      │
│ Sistema automáticamente:                             │
│ ✓ Calcula si hubo atraso (is_late)                  │
│ ✓ Actualiza status_id según lógica                  │
│ ✓ Registra fecha real del pago                      │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│ PASO 3: Sistema Acumula para Estado de Cuenta       │
├─────────────────────────────────────────────────────┤
│ Al cerrar período (día 8 o 23):                     │
│                                                      │
│ Sistema genera associate_payment_statement:          │
│   - total_payments_count = N pagos en el período    │
│   - total_amount_collected = Suma de amount_paid    │
│   - total_commission_owed = Suma × commission_rate  │
│   - due_date = ~5 días después del cierre (opcional)│
│                                                      │
│ Ejemplo FICTICIO (ilustrativo):                     │
│   Período: 8-22 enero                               │
│   Pagos cobrados: 10 clientes × $8,333 = $83,330   │
│   Comisión: $83,330 × 4.5% = $3,750                │
│   Debe pagar a CrediCuenta: $83,330 - $3,750 = $79,580│
│   Fecha límite sugerida: 27 enero                   │
│                                                      │
│ ⚠️  Nota: El cliente puede pagar días 15/último,   │
│    pero asociado tiene hasta ANTES del siguiente    │
│    corte para reportar/liquidar.                    │
└─────────────────────────────────────────────────────┘
```

### FLUJO 3: Liquidación de Asociado a CrediCuenta

```
INICIADOR: Asociado (operado por Admin actualmente)
FRECUENCIA: Cada período (quincenal)
RESULTADO: Estado de cuenta pagado o deuda acumulada

┌─────────────────────────────────────────────────────┐
│ ESCENARIO A: Pago Completo (Caso Ideal)             │
├─────────────────────────────────────────────────────┤
│ Asociado paga el total del estado de cuenta:        │
│                                                      │
│ SQL:                                                 │
│   UPDATE associate_payment_statements               │
│   SET paid_amount = 79580.00,                       │
│       paid_date = '2025-01-25',                     │
│       payment_method_id = 2,  -- TRANSFER           │
│       payment_reference = 'SPEI-123456',            │
│       status_id = 3  -- PAID                        │
│   WHERE id = 10;                                    │
│                                                      │
│ RESULTADO:                                           │
│ ✅ Estado de cuenta cerrado                         │
│ ✅ Comisión del asociado = $3,750                   │
│ ✅ No hay deuda acumulada                           │
│ ✅ Contador consecutive_full_credit_periods++       │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│ ESCENARIO B: Pago Parcial (Liquidación Parcial)     │
├─────────────────────────────────────────────────────┤
│ Asociado paga solo una parte:                       │
│                                                      │
│ PASO 1: Registrar primer abono                      │
│   INSERT INTO associate_debt_payments (             │
│     user_id, statement_id, payment_amount,          │
│     payment_date, registered_by                     │
│   ) VALUES (                                        │
│     3, 10, 50000.00, '2025-01-25', 2                │
│   );                                                │
│                                                      │
│ ⚡ TRIGGER: update_statement_on_debt_payment        │
│   → Actualiza associate_payment_statements:         │
│     total_paid_amount = 50000                       │
│     remaining_balance = 79580 - 50000 = 29580       │
│     status_id = 4  -- PARTIAL_PAID                  │
│                                                      │
│   → Actualiza associate_accumulated_balances:       │
│     current_balance += 29580                        │
│   → Actualiza associate_profiles.credit_available   │
│     (crédito reducido por deuda acumulada)          │
│                                                      │
│ PASO 2: Registrar segundo abono (mismo día u otro)  │
│   INSERT INTO associate_debt_payments (             │
│     user_id, statement_id, payment_amount,          │
│     payment_date, registered_by                     │
│   ) VALUES (                                        │
│     3, 10, 20000.00, '2025-01-30', 2                │
│   );                                                │
│                                                      │
│ ⚡ TRIGGER actualiza nuevamente:                     │
│   total_paid_amount = 70000                         │
│   remaining_balance = 9580                          │
│   current_balance = 9580                            │
│   credit_available actualizado                      │
│                                                      │
│ ⚠️  NOTA: No hay restricción de cantidad/frecuencia│
│    de abonos, siempre que sean dentro del período.  │
│                                                      │
│ PASO 3: Liquidación final                           │
│   (Mismo proceso hasta remaining_balance = 0)       │
│                                                      │
│ RESULTADO:                                           │
│ ✅ Múltiples abonos registrados                     │
│ ✅ Balance acumulado actualizado                    │
│ ✅ Deuda rastreada en tiempo real                   │
│ ✅ Crédito disponible reflejado correctamente       │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│ ESCENARIO C: No Paga (Vencimiento)                  │
├─────────────────────────────────────────────────────┤
│ Asociado no paga antes del cierre de período:       │
│                                                      │
│ Al ejecutar close_period_and_accumulate_debt_v2():  │
│   1. Marca TODOS los pagos del período como pagados │
│      - PAID = reportados por asociado               │
│      - PAID_NOT_REPORTED = no reportados            │
│      - PAID_BY_ASSOCIATE = cliente moroso           │
│   2. Calcula deuda por pagos NO reportados          │
│   3. Registra en associate_debt_breakdown:          │
│      - debt_type = 'UNREPORTED_PAYMENT'             │
│      - debt_amount = suma de pagos no reportados    │
│   4. Actualiza associate_accumulated_balances:      │
│      current_balance += deuda_nueva                 │
│   5. Actualiza credit_available del asociado        │
│   6. Aplica cargo por mora SI no reportó NI 1 pago: │
│      late_fee = total_commission × 30%              │
│                                                      │
│ RESULTADO:                                           │
│ ❌ Deuda se acumula automáticamente                 │
│ ❌ Crédito disponible disminuye                     │
│ ❌ Mora aplicada si NO reportó ningún pago          │
│ ❌ Contador consecutive_full_credit_periods = 0     │
│ ⚠️  Puede resultar en descenso de nivel            │
│ ⚠️  Admin puede restringir nuevos préstamos        │
└─────────────────────────────────────────────────────┘
```

### FLUJO 4: Renovación de Préstamo (Liquidación Anticipada)

```
INICIADOR: Cliente (solicita), Admin (ejecuta)
CONDICIÓN: Préstamo activo con pagos pendientes
RESULTADO: Préstamo anterior liquidado, nuevo préstamo activo

┌─────────────────────────────────────────────────────┐
│ CONTEXTO DEL CASO DE USO                             │
├─────────────────────────────────────────────────────┤
│ Cliente Juan tiene:                                  │
│   - Préstamo activo: $100,000 a 12 quincenas        │
│   - Ha pagado: 6 quincenas = $50,000                │
│   - Pagos pendientes: 6 quincenas = $50,000         │
│                                                      │
│ Cliente quiere nuevo préstamo de $150,000           │
│                                                      │
│ OPCIÓN A: Sacar segundo préstamo (2 activos)        │
│   → Solo si asociado tiene crédito disponible       │
│   → Valida: credit_available >= $150,000            │
│   → Cliente NO debe ser moroso                      │
│                                                      │
│ OPCIÓN B: Renovar (liquidar anterior con nuevo) ✅  │
│   → Recomendado, simplifica cobranza                │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│ PASO 1: Calcular Saldo Pendiente                    │
├─────────────────────────────────────────────────────┤
│ SQL:                                                 │
│   SELECT * FROM calculate_loan_remaining_balance(123);│
│                                                      │
│ Retorna:                                             │
│   remaining_capital: 50000.00                       │
│   remaining_interest: 2500.00  (ejemplo: 5% anual)  │
│   remaining_commission: 1250.00  (2.5%)             │
│   total_to_liquidate: 53750.00                      │
│   pending_payments_count: 6                         │
│                                                      │
│ CÁLCULOS INTERNOS:                                   │
│ • Capital = (Total - Pagado)                        │
│ • Interés = Capital × (interest_rate/100) × meses   │
│ • Comisión = Capital × (commission_rate/100)        │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│ PASO 2: Ejecutar Renovación                         │
├─────────────────────────────────────────────────────┤
│ SQL:                                                 │
│   SELECT renew_loan(                                │
│     p_old_loan_id := 123,                           │
│     p_new_amount := 150000.00,                      │
│     p_new_term := 12,                               │
│     p_approved_by := 2                              │
│   );                                                │
│                                                      │
│ PROCESO INTERNO DE LA FUNCIÓN:                       │
│                                                      │
│ 1. Validar préstamo anterior esté ACTIVE/APPROVED   │
│ 2. Calcular saldo pendiente: $53,750               │
│ 3. Validar nuevo monto > saldo: $150k > $53.7k ✓   │
│ 4. Calcular entrega real: $150k - $53.7k = $96,250 │
│                                                      │
│ 5. Actualizar préstamo anterior:                    │
│    UPDATE loans                                      │
│    SET status_id = 9,  -- LIQUIDATED_BY_RENEWAL     │
│        renewed_by_loan_id = [nuevo_id]              │
│    WHERE id = 123;                                  │
│                                                      │
│ 6. Marcar pagos pendientes como pagados:            │
│    UPDATE payments                                   │
│    SET amount_paid = [monto_calculado],             │
│        paid_by_renewal = TRUE,                      │
│        status_id = 8,  -- PAID_BY_RENEWAL           │
│        actual_payment_date = CURRENT_DATE           │
│    WHERE loan_id = 123                              │
│      AND amount_paid = 0;                           │
│                                                      │
│ 7. Crear nuevo préstamo:                            │
│    INSERT INTO loans (                              │
│      user_id, amount, term_biweeks,                 │
│      status_id, renewal_of_loan_id, approved_by     │
│    ) VALUES (                                       │
│      4, 150000, 12, 2, 123, 2                       │
│    );                                               │
│                                                      │
│ 8. Registrar en loan_renewals:                      │
│    INSERT INTO loan_renewals (                      │
│      old_loan_id, new_loan_id,                      │
│      old_loan_remaining_capital,                    │
│      total_liquidation_amount,                      │
│      amount_delivered_to_client                     │
│    ) VALUES (                                       │
│      123, [nuevo_id], 50000, 53750, 96250           │
│    );                                               │
│                                                      │
│ 9. Generar cronograma nuevo (trigger automático)    │
│                                                      │
│ RESULTADO RETORNADO: nuevo_loan_id                  │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│ PASO 3: Comisión del Asociado en Renovación         │
├─────────────────────────────────────────────────────┤
│ Asociado gana comisión sobre el saldo liquidado:    │
│                                                      │
│ Comisión = $53,750 × 2.5% = $1,343.75              │
│                                                      │
│ Esta comisión se acredita en su estado de cuenta    │
│ del período actual.                                  │
└─────────────────────────────────────────────────────┘

RESULTADO FINAL:
├── Préstamo anterior: LIQUIDATED_BY_RENEWAL
├── Pagos pendientes marcados: PAID_BY_RENEWAL
├── Nuevo préstamo: APPROVED con cronograma generado
├── Cliente recibe: $96,250 (no $150,000)
├── Registro de auditoría en loan_renewals
└── Asociado cobra comisión sobre liquidación
```

### FLUJO 5: Cliente Moroso y Convenio

```
INICIADOR: Asociado/Admin (asociado reporta, admin aprueba)
CONDICIÓN: Cliente no paga al asociado
RESULTADO: Cliente marcado moroso, deuda absorbida por asociado, convenio opcional

┌─────────────────────────────────────────────────────┐
│ CONTEXTO: ¿Qué es un Cliente Moroso?                │
├─────────────────────────────────────────────────────┤
│ Cliente moroso = Cliente que NO pagó al ASOCIADO    │
│                                                      │
│ ⚠️  LÓGICA CRÍTICA (corregida):                     │
│ • Al cerrar período, TODOS los pagos se marcan      │
│   como "pagados" (PAID, PAID_NOT_REPORTED o         │
│   PAID_BY_ASSOCIATE)                                │
│ • Los pagos del cliente moroso se marcan            │
│   PAID_BY_ASSOCIATE = absorbidos por asociado       │
│ • La deuda se acumula en associate_debt_breakdown   │
│   con tipo 'DEFAULTED_CLIENT'                       │
│ • El asociado es 100% responsable                   │
│                                                      │
│ ¿Cómo se detecta?                                    │
│ • Asociado reporta explícitamente al cliente        │
│ • Admin revisa evidencia y aprueba                  │
│ • Sistema marca cliente como moroso                 │
│                                                      │
│ ⚠️  NO habrá "3 pagos vencidos" visibles después   │
│    del cierre de período. La morosidad se rastrea   │
│    por REPORTES, no por acumulación de pagos.       │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│ PASO 1: Asociado Reporta Cliente Moroso             │
├─────────────────────────────────────────────────────┤
│ Asociado contacta Admin y dice:                     │
│ "El cliente Juan (préstamo #456) no me ha pagado.   │
│  Ya intenté cobrar pero no responde."               │
│                                                      │
│ Admin ejecuta (por ahora, en futuro será el asociado):│
│   SELECT report_defaulted_client(                   │
│     p_loan_id := 456,                               │
│     p_reported_by := 2,  -- admin_id                │
│     p_payment_ids := ARRAY[789, 790, 791],          │
│     p_evidence_notes := 'Cliente no responde        │
│       llamadas ni WhatsApp. Intentos: 15/01,        │
│       20/01, 25/01',                                │
│     p_evidence_file_url := 'uploads/evidencia.pdf'  │
│   );                                                │
│                                                      │
│ Sistema crea registro en defaulted_client_reports:  │
│   - report_status = 'PENDING'                       │
│   - total_payments_defaulted = 3                    │
│   - total_amount_defaulted = $25,000                │
│   - Evidencia adjunta                               │
│                                                      │
│ RESULTADO: Reporte #X creado, pendiente aprobación  │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│ PASO 2: Admin Revisa y Decide Estrategia            │
├─────────────────────────────────────────────────────┤
│ Admin revisa:                                        │
│ • Evidencia de intentos de cobro                    │
│ • Historial del cliente                             │
│ • Historial del asociado                            │
│                                                      │
│ OPCIÓN A: Aprobar reporte con convenio (común)      │
│   → Cliente se marca moroso (is_defaulter = TRUE)   │
│   → Pagos se marcan PAID_BY_ASSOCIATE               │
│   → Deuda se registra en debt_breakdown             │
│   → Se crea convenio automático                     │
│   → Asociado paga deuda en abonos quincenales       │
│                                                      │
│ OPCIÓN B: Aprobar sin convenio (menos común)        │
│   → Cliente marcado moroso                          │
│   → Deuda registrada                                │
│   → Asociado sigue intentando cobrar                │
│   → Si cobra, puede liquidar deuda específica       │
│                                                      │
│ OPCIÓN C: Rechazar reporte                          │
│   → No se marca nada                                │
│   → Asociado debe seguir gestionando                │
│                                                      │
│ ⚠️  La estrategia la decide el ASOCIADO, pero el   │
│    admin facilita el proceso.                       │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│ PASO 3: Aprobar Reporte y Crear Convenio            │
├─────────────────────────────────────────────────────┤
│ SQL:                                                 │
│   SELECT * FROM approve_defaulted_client_report(    │
│     p_report_id := 10,                              │
│     p_reviewed_by := 2,  -- admin_id                │
│     p_review_notes := 'Evidencia suficiente,        │
│       cliente efectivamente moroso',                │
│     p_create_agreement := TRUE                      │
│   );                                                │
│                                                      │
│ PROCESO INTERNO:                                     │
│                                                      │
│ 1. Marcar cliente como moroso:                      │
│    UPDATE loans                                      │
│    SET is_defaulter = TRUE,                         │
│        in_collection_by_associate = TRUE            │
│    WHERE id = 456;                                  │
│                                                      │
│ 2. Marcar pagos como PAID_BY_ASSOCIATE:             │
│    UPDATE payments                                   │
│    SET status_id = 9,  -- PAID_BY_ASSOCIATE         │
│        updated_at = CURRENT_TIMESTAMP               │
│    WHERE id IN (789, 790, 791);                     │
│                                                      │
│ 3. Registrar deuda en breakdown:                    │
│    INSERT INTO associate_debt_breakdown (           │
│      user_id, cut_period_id, debt_type,             │
│      related_client_id, related_loan_id,            │
│      debt_amount, notes                             │
│    ) VALUES (                                       │
│      3, 12, 'DEFAULTED_CLIENT',                     │
│      4, 456, 25000.00,                              │
│      'Cliente moroso reportado. Reporte #10'        │
│    );                                               │
│                                                      │
│ 4. Crear convenio (si p_create_agreement = TRUE):   │
│    SELECT create_agreement_for_defaulted_loan(      │
│      p_loan_id := 456,                              │
│      p_strategy := 'forgive_all',                   │
│      p_created_by := 2                              │
│    );                                               │
│                                                      │
│ 5. Actualizar reporte:                              │
│    UPDATE defaulted_client_reports                  │
│    SET report_status = 'IN_AGREEMENT',              │
│        reviewed_by = 2,                             │
│        reviewed_at = CURRENT_TIMESTAMP              │
│    WHERE id = 10;                                   │
│                                                      │
│ RESULTADO RETORNADO:                                 │
│   report_approved: TRUE                             │
│   client_marked_defaulter: TRUE                     │
│   payments_marked: 3                                │
│   debt_registered: TRUE                             │
│   agreement_created: [agreement_id]                 │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│ PASO 4 (ALTERNATIVO): Admin Marca Pagos Manualmente │
├─────────────────────────────────────────────────────┤
│ Si el admin prefiere marcar pagos ANTES de aprobar  │
│ el reporte (para más control):                      │
│                                                      │
│ SQL por cada pago:                                   │
│   SELECT * FROM admin_mark_payment_status(          │
│     p_payment_id := 789,                            │
│     p_new_status_id := 9,  -- PAID_BY_ASSOCIATE     │
│     p_marked_by := 2,  -- admin_id                  │
│     p_notes := 'Cliente Juan no pagó. Evidencia:    │
│       Llamadas: 15/01, 20/01. WhatsApp sin          │
│       respuesta. Asociado confirma no pago.'        │
│   );                                                │
│                                                      │
│ Esto registra en el pago:                           │
│   - marked_by = 2 (admin)                           │
│   - marked_at = TIMESTAMP actual                    │
│   - marking_notes = evidencia completa              │
│                                                      │
│ VENTAJAS:                                            │
│ ✅ Tracking completo (quién, cuándo, por qué)       │
│ ✅ Auditoría clara de decisiones                    │
│ ✅ Distinción visual en reportes                    │
│ ✅ Vínculo directo con debt_breakdown               │
│                                                      │
│ ESTADOS DISPONIBLES PARA EL ADMIN:                  │
│   3. PAID - Reportado normalmente (real)            │
│   9. PAID_BY_ASSOCIATE - Absorbido (cliente moroso) │
│   10. PAID_NOT_REPORTED - No reportado (cerrado)    │
│   11. FORGIVEN - Perdonado (excepcional)            │
│   12. CANCELLED - Cancelado                         │
└─────────────────────────────────────────────────────┘

RESULTADO FINAL:
├── Cliente marcado: is_defaulter = TRUE
├── Pagos marcados: PAID_BY_ASSOCIATE (con tracking)
├── Cada pago registra: quién lo marcó, cuándo y por qué
├── Deuda registrada en: associate_debt_breakdown (tipo: DEFAULTED_CLIENT)
├── Convenio creado (opcional): agreements + agreement_items
├── Asociado paga deuda en abonos quincenales
├── Cliente bloqueado para nuevos préstamos
├── Rastreabilidad COMPLETA: reporte → pagos marcados → breakdown → convenio
└── Vista especializada: v_payments_absorbed_by_associate

⚠️  IMPORTANTE SOBRE CONVENIOS:
┌─────────────────────────────────────────────────────┐
│ Propósito del Convenio en Sistema de Morosidad      │
├─────────────────────────────────────────────────────┤
│ ⚠️  LA DEUDA SIEMPRE ES DEL ASOCIADO, NO DEL CLIENTE│
│                                                      │
│ RAZÓN:                                               │
│ • Cliente ya NO le paga al asociado (moroso)        │
│ • Asociado YA reportó a CrediCuenta esos cobros     │
│ • CrediCuenta ya descontó de los estados de cuenta  │
│ • El dinero técnicamente ya pasó a CrediCuenta      │
│                                                      │
│ FUNCIÓN DEL CONVENIO:                                │
│ 1. Formalizar la deuda del asociado con CrediCuenta │
│ 2. Establecer plan de pagos en abonos quincenales   │
│ 3. SACAR al cliente moroso de la relación/quincena  │
│ 4. Evitar que aparezcan pagos del moroso en cortes  │
│                                                      │
│ EFECTO PRÁCTICO:                                     │
│ • Los pagos restantes del cliente moroso YA NO      │
│   aparecen en la siguiente quincena del asociado    │
│ • El préstamo moroso queda "congelado"              │
│ • El asociado paga la deuda poco a poco             │
│ • Cliente sigue moroso (is_defaulter = TRUE)        │
│                                                      │
│ EJEMPLO:                                             │
│   Cliente Juan debe: $30,000 (3 pagos × $10k)       │
│   Convenio: Asociado paga $30k en 3 quincenas       │
│   Resultado: Cliente fuera, asociado absorbe deuda  │
│                                                      │
│ ⚠️  El convenio NO es para que el cliente pague,   │
│    es para que el ASOCIADO pague por el cliente.    │
└─────────────────────────────────────────────────────┘
```
│                                                      │
│ 2. Verificar si asociado tiene convenio activo:     │
│    SELECT * FROM agreements                          │
│    WHERE associate_user_id = 3                      │
│      AND status_id = 2;  -- ACTIVE                  │
│                                                      │
│    Si existe: Agregar item al convenio existente    │
│    Si no existe: Crear nuevo convenio               │
│                                                      │
│ 3. Crear/Actualizar convenio:                       │
│    INSERT INTO agreements (                         │
│      associate_user_id, agreement_number,           │
│      total_agreement_amount, remaining_balance,     │
│      biweekly_payment_amount, status_id             │
│    ) VALUES (                                       │
│      3, 'CONV-2025-001', 25000, 25000,              │
│      10000, 2                                       │
│    );                                               │
│                                                      │
│ 4. Agregar item de préstamo moroso:                 │
│    INSERT INTO agreement_items (                    │
│      agreement_id, item_type_id,                    │
│      reference_loan_id, client_user_id,             │
│      amount, description                            │
│    ) VALUES (                                       │
│      [id], 1, 456, 4,                               │
│      25000, 'Préstamo #456 moroso, 3 pagos'         │
│    );                                               │
│                                                      │
│ 5. Marcar préstamo como moroso en convenio:         │
│    UPDATE loans                                      │
│    SET status_id = 10,  -- DEFAULTED_IN_AGREEMENT   │
│        is_defaulter = TRUE,                         │
│        in_collection_by_associate = FALSE           │
│    WHERE id = 456;                                  │
│                                                      │
│ 6. Marcar pagos vencidos como pagados (ficticios):  │
│    UPDATE payments                                   │
│    SET amount_paid = amount_expected,               │
│        paid_by_agreement = TRUE,                    │
│        status_id = 7,  -- PAID_BY_AGREEMENT         │
│        actual_payment_date = CURRENT_DATE           │
│    WHERE loan_id = 456                              │
│      AND amount_paid = 0                            │
│      AND payment_due_date < CURRENT_DATE;           │
│                                                      │
│ 7. Actualizar balance del asociado:                 │
│    INSERT INTO associate_accumulated_balances       │
│      (user_id, total_debt_accumulated,              │
│       current_balance, active_agreement_id)         │
│    VALUES (3, 25000, 25000, [agreement_id])         │
│    ON CONFLICT (user_id) DO UPDATE                  │
│    SET total_debt_accumulated += 25000,             │
│        current_balance += 25000,                    │
│        active_agreement_id = [agreement_id];        │
│                                                      │
│ RESULTADO RETORNADO: agreement_id                   │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│ PASO 4: Asociado Abona al Convenio                  │
├─────────────────────────────────────────────────────┤
│ Cada quincena, asociado paga abono al convenio:     │
│                                                      │
│ SQL:                                                 │
│   INSERT INTO agreement_payments (                  │
│     agreement_id, payment_amount, payment_date,     │
│     payment_method_id, registered_by                │
│   ) VALUES (                                        │
│     1, 10000.00, '2025-02-15', 2, 2                 │
│   );                                                │
│                                                      │
│ ⚡ TRIGGER: update_agreement_on_payment             │
│   → Actualiza agreement:                            │
│     total_paid_amount += 10000                      │
│     remaining_balance = 25000 - 10000 = 15000       │
│                                                      │
│   → Actualiza associate_accumulated_balances:       │
│     total_paid_to_date += 10000                     │
│     current_balance = 25000 - 10000 = 15000         │
│                                                      │
│   → Si remaining_balance = 0:                       │
│     agreement.status_id = 3  -- COMPLETED           │
│     Resetea flags del préstamo                      │
└─────────────────────────────────────────────────────┘

RESULTADO FINAL:
├── Cliente marcado: is_defaulter = TRUE
├── Pagos marcados: PAID_BY_ASSOCIATE
├── Deuda registrada en: associate_debt_breakdown (tipo: DEFAULTED_CLIENT)
├── Convenio creado (opcional): agreements + agreement_items
├── Asociado paga deuda en abonos quincenales
├── Cliente bloqueado para nuevos préstamos
└── Rastreabilidad completa: reporte → breakdown → convenio
```

### FLUJO 6: Registro de Usuarios y Asignación de Roles

```
INICIADOR: Admin (por ahora, futuro: auto-registro)
CONDICIÓN: Jerarquía de roles respetada
RESULTADO: Usuario creado con rol asignado

┌─────────────────────────────────────────────────────┐
│ CONTEXTO: Jerarquía de Roles                         │
├─────────────────────────────────────────────────────┤
│ JERARQUÍA (mayor a menor):                           │
│   1. Desarrollador (máximo poder)                   │
│   2. Administrador                                   │
│   3. Auxiliar Administrativo                         │
│   4. Asociado                                        │
│   5. Cliente (menor poder)                          │
│                                                      │
│ REGLA FUNDAMENTAL:                                   │
│ Solo puedes crear usuarios con jerarquía MÁS BAJA   │
│ que la tuya.                                         │
│                                                      │
│ PERMISOS DE CREACIÓN:                                │
│ • Desarrollador → Puede crear: todos                │
│ • Admin → Puede crear: Auxiliar, Asociado, Cliente  │
│ • Asociado → Puede crear: Cliente                   │
│ • Cliente → NO puede crear usuarios                 │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│ PASO 1: Validar Permisos del Creador                │
├─────────────────────────────────────────────────────┤
│ Ejemplo: Admin (role_id=2) quiere crear Asociado    │
│                                                      │
│ SQL de validación:                                   │
│   SELECT                                             │
│     creator_role.name as creator_role,              │
│     target_role.name as target_role,                │
│     creator_role.id < target_role.id as can_create  │
│   FROM roles creator_role, roles target_role        │
│   WHERE creator_role.id = 2  -- Admin               │
│     AND target_role.id = 4;  -- Asociado            │
│                                                      │
│ Resultado: can_create = TRUE (2 < 4)                │
│                                                      │
│ Si FALSE: Rechazar con error de permisos            │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│ PASO 2: Crear Usuario Base                          │
├─────────────────────────────────────────────────────┤
│ SQL:                                                 │
│   INSERT INTO users (                               │
│     username, password_hash, first_name, last_name, │
│     email, phone_number, curp, birth_date           │
│   ) VALUES (                                        │
│     'carlos.lopez', -- único                        │
│     '$2b$12$...hash...', -- bcrypt                  │
│     'Carlos', 'López',                              │
│     'carlos@example.com',  -- único                 │
│     '5512345678',  -- único, 10 dígitos             │
│     'LOPC900512HDFLPR09',  -- único, 18 caracteres  │
│     '1990-05-12'                                    │
│   )                                                 │
│   RETURNING id;                                     │
│                                                      │
│ ⚠️  Validaciones automáticas vía CHECK constraints:│
│   • CURP: 18 caracteres exactos                     │
│   • Teléfono: 10 dígitos numéricos                  │
│   • Email: formato válido                           │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│ PASO 3: Asignar Rol                                 │
├─────────────────────────────────────────────────────┤
│ SQL:                                                 │
│   INSERT INTO user_roles (user_id, role_id)        │
│   VALUES (                                          │
│     [nuevo_user_id],                                │
│     4  -- asociado                                  │
│   );                                                │
│                                                      │
│ ⚠️  Un usuario puede tener múltiples roles         │
│    (ej: asociado + cliente), pero NO común.        │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│ PASO 4: Crear Perfiles Específicos del Rol          │
├─────────────────────────────────────────────────────┤
│ SI rol = ASOCIADO:                                   │
│   INSERT INTO associate_profiles (                  │
│     user_id, level_id, default_commission_rate,     │
│     credit_limit, credit_available, active          │
│   ) VALUES (                                        │
│     [user_id], 1,  -- Nivel Bronce inicial          │
│     4.5, 100000.00, 100000.00, TRUE                 │
│   );                                                │
│                                                      │
│ SI rol = CLIENTE:                                    │
│   -- No requiere perfil adicional por ahora         │
│   -- Futuro: client_profiles con scoring, etc.      │
│                                                      │
│ PARA TODOS:                                          │
│   INSERT INTO addresses (                           │
│     user_id, street, city, state, postal_code       │
│   ) VALUES (                                        │
│     [user_id], 'Calle...', 'CDMX', 'CDMX', '01000'  │
│   );                                                │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│ PASO 5: Notificar al Usuario (Futuro)               │
├─────────────────────────────────────────────────────┤
│ • Enviar email de bienvenida                        │
│ • Enviar SMS con credenciales temporales            │
│ • Registrar en log de auditoría                     │
│                                                      │
│ ⚠️  Por ahora: Admin comunica credenciales por     │
│    WhatsApp/teléfono directamente.                  │
└─────────────────────────────────────────────────────┘

RESULTADO FINAL:
├── Usuario creado en tabla `users`
├── Rol asignado en tabla `user_roles`
├── Perfil específico creado (si aplica)
├── Dirección registrada
├── Jerarquía de roles respetada
└── Listo para usar el sistema con permisos correctos
```

---

## � ESTADOS DE PAGO Y TRACKING

### 🎯 Estados Disponibles (12 estados)

#### Estados Pendientes (Asociado puede reportar)
| ID | Estado | Descripción | Color | Uso |
|----|--------|-------------|-------|-----|
| 1 | `SCHEDULED` | Pago programado, no vencido | Gris | Inicial automático |
| 2 | `DUE_TODAY` | Vence hoy | Naranja | Alerta automática |
| 4 | `PARTIAL` | Pago parcial recibido | Azul | Asociado reporta |
| 5 | `OVERDUE` | Vencido sin reportar | Rojo | Automático si no reporta |
| 6 | `OVERDUE_PARTIAL` | Vencido con abono parcial | Rojo oscuro | Asociado reporta |
| 7 | `PENDING_REGISTER` | A tiempo pero registro tardío | Amarillo | Fin de semana |

#### Estados Finales - Pagos REALES (💵 Dinero cobrado)
| ID | Estado | Descripción | Color | Uso |
|----|--------|-------------|-------|-----|
| 3 | `PAID` | Reportado normalmente | Verde | Asociado reporta ✅ |
| 8 | `PAID_BY_RENEWAL` | Liquidado por renovación | Cian | Sistema automático ✅ |

#### Estados Finales - Pagos FICTICIOS (⚠️ NO cobrados)
| ID | Estado | Descripción | Color | Uso |
|----|--------|-------------|-------|-----|
| 9 | `PAID_BY_ASSOCIATE` | Absorbido (cliente moroso) | Morado | **Admin marca** ⚠️ |
| 10 | `PAID_NOT_REPORTED` | Cerrado auto (no reportado) | Marrón | Sistema al cerrar ⚠️ |
| 11 | `FORGIVEN` | Perdonado excepcional | Gris oscuro | Admin marca ⚠️ |
| 12 | `CANCELLED` | Préstamo cancelado | Negro | Sistema ❌ |

### 🔍 Tracking Completo

Cada pago registra:
```sql
payments (
    status_id,           -- Estado actual
    marked_by,           -- Usuario que marcó (NULL = automático)
    marked_at,           -- Timestamp del marcado
    marking_notes,       -- Notas del admin (evidencia)
    amount_paid,         -- Monto real cobrado
    payment_date,        -- Fecha de cobro
    actual_payment_date  -- Fecha real vs programada
)
```

### 📋 Uso por el Admin

**Función principal**: `admin_mark_payment_status()`

**Ejemplo - Marcar cliente moroso**:
```sql
SELECT * FROM admin_mark_payment_status(
    p_payment_id := 789,
    p_new_status_id := 9,  -- PAID_BY_ASSOCIATE
    p_marked_by := 2,      -- admin_id
    p_notes := 'Cliente Juan no pagó. Llamadas 15/01, 20/01 sin respuesta.'
);
```

**Resultado**:
- Pago marcado como absorbido por asociado
- Registra quién (admin), cuándo (timestamp), por qué (notas)
- Se vincula con `associate_debt_breakdown`
- Visible en vista `v_payments_absorbed_by_associate`

### 📊 Vistas Especializadas

1. **v_payments_by_status_detailed**: Resumen por estado
2. **v_payments_absorbed_by_associate**: Solo pagos absorbidos con tracking
3. **get_payment_status_history()**: Historial completo de un pago

---

## �📐 REGLAS DE NEGOCIO CRÍTICAS

### RN-001: Doble Calendario Quincenal

**Prioridad**: 🔥 CRÍTICA  
**Implementación**: `calculate_first_payment_date()` (línea 29-198 del init_clean.sql)

```sql
IF día_aprobación BETWEEN 1 AND 7 THEN
    primer_pago := día 15 del MISMO mes
ELSIF día_aprobación BETWEEN 8 AND 22 THEN
    primer_pago := ÚLTIMO día del MISMO mes
ELSIF día_aprobación >= 23 THEN
    primer_pago := día 15 del SIGUIENTE mes
END IF;

-- Después alternancia automática: 15 ↔ último día
```

**Justificación**: Sincroniza vencimientos de clientes con períodos administrativos.

### RN-002: Cliente Moroso Bloqueado

**Prioridad**: 🔥 CRÍTICA  
**Implementación**: `prevent_loan_approval_to_defaulter()` trigger

```sql
-- VALIDACIÓN AUTOMÁTICA AL APROBAR
IF EXISTS (
    SELECT 1 FROM loans
    WHERE user_id = NEW.user_id
      AND is_defaulter = TRUE
) THEN
    RAISE EXCEPTION 'Cliente es moroso, préstamo bloqueado';
END IF;
```

**Justificación**: Protege a CrediCuenta de clientes con historial de impago.

### RN-003: Nivel Determina Crédito Global del Asociado

**Tabla**: `associate_levels` + `associate_profiles`

```
NIVEL         | CREDIT_LIMIT (max_loan_amount)
--------------+---------------------------------
Bronce        | $50,000
Plata         | $100,000
Oro           | $250,000
Platino       | $600,000
Diamante      | $1,000,000
```

**⚠️ CORRECCIÓN IMPORTANTE**:
El `max_loan_amount` NO es el límite por préstamo individual, sino el **CRÉDITO TOTAL** que el asociado puede tener activo simultáneamente.

**Fórmula del crédito disponible**:
```sql
credit_available = credit_limit - credit_used - debt_balance

DONDE:
  credit_limit  = max_loan_amount del nivel actual
  credit_used   = Suma de saldos pendientes de todos los préstamos activos
  debt_balance  = Deuda acumulada no liquidada con CrediCuenta
```

**Ejemplo Real**:
```
Asociado nivel Oro (credit_limit = $250,000)
Préstamos activos:
  - Préstamo #1: $100,000 (pagado $50,000) → saldo: $50,000
  - Préstamo #2: $80,000 (pagado $20,000) → saldo: $60,000
Deuda acumulada: $15,000

credit_used = $50,000 + $60,000 = $110,000
credit_available = $250,000 - $110,000 - $15,000 = $125,000

✅ Puede aprobar nuevo préstamo de hasta $125,000
❌ NO puede aprobar préstamo de $150,000 (excede disponible)
```

**Actualización automática**:
- ↓ Disminuye al aprobar préstamo (trigger: `update_associate_credit_on_loan_approval`)
- ↑ Aumenta al registrar pago de cliente (trigger: `update_associate_credit_on_payment`)
- ↑ Aumenta al liquidar deuda (trigger: `update_associate_credit_on_debt_payment`)
- ↑ Aumenta al subir de nivel (trigger: `update_associate_credit_on_level_change`)

**Validación**: En `check_associate_credit_available()`

### RN-004: Comisión del Asociado

**Cálculo**:
```
comision = total_cobrado × commission_rate
monto_a_pagar = total_cobrado - comision
```

**Ejemplo**:
```
Total cobrado: $100,000
Commission rate: 4.5%
Comisión: $4,500
Paga a CrediCuenta: $95,500
```

### RN-005: Renovación Requiere Saldo Pendiente

**Regla**: Solo puedes renovar si:
- Préstamo está ACTIVE o APPROVED
- Hay pagos pendientes (no terminó el plazo)
- Nuevo monto > saldo pendiente

**Validación**: En `renew_loan()`

### RN-006: Convenio Absorbe Deuda del Asociado

**Regla**: Cuando cliente es moroso:
- Asociado YA pagó a CrediCuenta por esos cobros
- Cliente no pagó al asociado
- Deuda es problema del ASOCIADO
- Convenio = Asociado devuelve ese dinero a CrediCuenta en abonos

**Justificación**: Asociado es responsable de su cartera.

---

**[Continúa en siguiente archivo - Parte 2]**

Este archivo es PARTE 1 de 3. Contiene:
✅ Contexto del sistema
✅ Actores
✅ 5 flujos principales completos
✅ 6 reglas de negocio críticas

**Siguiente archivo incluirá**:
- Casos de uso detallados (con ejemplos SQL reales)
- Cálculos y fórmulas
- Estados y transiciones
- Validaciones automáticas
- Ejemplos paso a paso

¿Continúo con la Parte 2?
