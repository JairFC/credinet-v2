# 🧪 GUÍA COMPLETA DE TESTING GUI - Validación de Correcciones

**Fecha**: 2026-01-07  
**Objetivo**: Validar que las 3 correcciones críticas funcionen correctamente en la GUI  
**Tiempo estimado**: 30-40 minutos

---

## 🎯 QUÉ VAMOS A VALIDAR

### ✅ Corrección #1: Liberación de crédito en pagos (solo capital)
- Al registrar un pago, el crédito del asociado debe liberarse SOLO por el capital
- NO debe incluir intereses ni comisión

### ✅ Corrección #2: Cálculo de saldo pendiente
- El saldo pendiente debe ser la suma de `expected_amount` de pagos PENDING
- Debe incluir capital + intereses (pero NO comisión del asociado)

### ✅ Corrección #3: Deuda acumulada en cierre
- Al cerrar período, los pagos no reportados deben registrarse con `expected_amount`
- La deuda del asociado debe reflejar lo que realmente debe pagar

---

## 📋 PREPARACIÓN

### 1. Abrir la GUI

```bash
# La GUI ya está corriendo en:
http://localhost:5173

# Backend API:
http://localhost:8000
```

### 2. Login

- Usuario: `admin` (o el usuario admin que tengas)
- Navega a la sección de **Préstamos**

---

## 🧪 TEST 1: CREAR Y APROBAR PRÉSTAMO

### Objetivo
Verificar que al aprobar un préstamo, el crédito usado aumenta correctamente.

### Pasos:

#### 1.1 Ir a "Crear Préstamo"
- Menú lateral → **Préstamos** → **Nuevo Préstamo**
- URL: `http://localhost:5173/loans/create`

#### 1.2 Seleccionar Asociado
- Click en el selector de asociado
- **ANOTAR** el crédito disponible ANTES:
  ```
  Asociado: _______________________
  Crédito Usado ANTES: $____________
  Crédito Disponible ANTES: $____________
  ```

#### 1.3 Seleccionar Cliente
- Click en el selector de cliente
- Elegir cualquier cliente sin préstamos activos

#### 1.4 Llenar el formulario
- **Monto**: `$23,000.00`
- **Plazo**: `12 quincenas`
- **Perfil**: `Standard` (o el que prefieras)
- **Notas**: `Testing corrección crédito`

#### 1.5 Ver Preview de Cálculo
Debe aparecer un preview automático mostrando:
- Pago quincenal total (expected_amount)
- Comisión por pago
- Total a pagar

**ANOTAR:**
```
Pago quincenal (expected_amount): $____________
Capital por pago: $____________ (23,000 / 12 = $1,916.67)
Comisión por pago: $____________
```

#### 1.6 Crear el préstamo
- Click en **"Crear Préstamo"**
- Debe aparecer confirmación de éxito
- **ANOTAR EL ID DEL PRÉSTAMO**: `#______`

#### 1.7 Aprobar el préstamo
- En la lista de préstamos, buscar el que acabas de crear
- Estado debe ser **"PENDING"**
- Click en **"Aprobar"**
- Agregar notas: `Aprobado para testing`
- Confirmar aprobación

#### 1.8 Verificar crédito DESPUÉS de aprobar
- Ir a **Asociados** → Buscar el asociado seleccionado
- **ANOTAR** el crédito usado DESPUÉS:
  ```
  Crédito Usado DESPUÉS: $____________
  Crédito Disponible DESPUÉS: $____________
  ```

#### 1.9 Validar el cambio
```
✅ VALIDACIÓN ESPERADA:
   Crédito Usado DESPUÉS = Crédito Usado ANTES + $23,000
   
   Si el asociado tenía $100,000 usado:
   → Debe quedar en $123,000 usado
   
   ✅ El crédito disponible debe reducirse en $23,000
```

**¿Pasó la validación?** ☐ SÍ  ☐ NO

---

## 🧪 TEST 2: REGISTRAR PAGO Y VERIFICAR LIBERACIÓN

### Objetivo
Verificar que al registrar un pago, el crédito se libera SOLO por el capital (no interés/comisión).

### Pasos:

#### 2.1 Ir al detalle del préstamo
- Click en el préstamo que creaste
- URL: `http://localhost:5173/loans/[ID]`

#### 2.2 Ver la tabla de amortización
- Debe mostrar los 12 pagos programados
- **Ubicar el Pago #1** y anotar:
  ```
  Pago #1:
  - Expected amount (cliente paga): $____________
  - Commission (comisión asociado): $____________
  - Associate payment (asociado entrega): $____________
  - Principal (capital): $____________ (debería ser ~$1,916.67)
  - Interest (interés): $____________
  ```

#### 2.3 Registrar el pago del cliente
- Buscar el botón **"Registrar Pago"** en el pago #1
- O ir a la sección de Pagos y buscar este pago específico

**IMPORTANTE**: Necesitas anotar el **crédito usado del asociado ANTES** de registrar el pago.

- Ir a **Asociados** → Ver el asociado
- **ANOTAR**:
  ```
  Crédito Usado ANTES del pago: $____________
  ```

#### 2.4 Volver al préstamo y registrar el pago
- Amount paid (monto recibido): ingresa el `expected_amount` completo
- Payment date: hoy
- Payment method: Efectivo (o el que prefieras)
- Confirmar

#### 2.5 Verificar crédito DESPUÉS del pago
- Volver a **Asociados** → Ver el mismo asociado
- **ANOTAR**:
  ```
  Crédito Usado DESPUÉS del pago: $____________
  ```

#### 2.6 Calcular la diferencia
```
✅ VALIDACIÓN ESPERADA:
   Liberación = Crédito Usado ANTES - Crédito Usado DESPUÉS
   
   Liberación ESPERADA = $1,916.67 (solo el capital)
   
   ❌ NO debe ser el expected_amount completo (~$2,894)
   ✅ DEBE ser solo el principal (~$1,917)
   
   Ejemplo:
   - Crédito usado ANTES: $123,000
   - Crédito usado DESPUÉS: $121,083.33
   - Diferencia: $1,916.67 ✅ CORRECTO
```

**¿Pasó la validación?** ☐ SÍ  ☐ NO

**Diferencia real observada**: $____________

---

## 🧪 TEST 3: CALCULAR SALDO PENDIENTE (RENOVACIÓN)

### Objetivo
Verificar que el saldo pendiente se calcule correctamente para renovaciones.

### Pasos:

#### 3.1 Ir a renovar el préstamo
- Desde el detalle del préstamo, buscar opción **"Renovar"**
- O ir a **Crear Préstamo** y seleccionar el mismo cliente

#### 3.2 Ver los préstamos activos del cliente
Si el cliente tiene el préstamo activo, debe aparecer una sección mostrando:
```
Préstamos Activos del Cliente:
- Préstamo #[ID] - $23,000
- Pagos pendientes: 11 (registraste 1 de 12)
- Saldo pendiente total: $____________
```

#### 3.3 Validar el cálculo del saldo
```
✅ VALIDACIÓN ESPERADA:
   Saldo pendiente = 11 pagos × expected_amount de cada pago
   
   Si expected_amount es $2,894.17:
   → Saldo = 11 × $2,894.17 = $31,835.87
   
   ✅ Debe incluir capital + intereses de pagos pendientes
   ❌ NO debe incluir comisiones (esas son ganancia del asociado)
```

**Saldo mostrado en GUI**: $____________

**¿Coincide con el cálculo esperado?** ☐ SÍ  ☐ NO

---

## 🧪 TEST 4: CERRAR PERÍODO Y DEUDA ACUMULADA

### Objetivo
Verificar que al cerrar un período, los pagos no reportados se registren correctamente en la deuda.

### Preparación:
Este test requiere tener un período activo con pagos. Si no hay períodos:

#### 4.1 Ir a Períodos/Statements
- Menú lateral → **Statements** o **Períodos**
- URL: `http://localhost:5173/statements`

#### 4.2 Ver el período actual
- Debe haber un período con estado **"OPEN"** o **"ACTIVE"**
- Click para ver detalles

#### 4.3 Ver los pagos del período
- Debe mostrar lista de pagos programados para este período
- Identificar pagos que NO se han reportado (amount_paid = 0)

#### 4.4 Anotar ANTES de cerrar
```
Asociado a verificar: _______________________
Debt Balance ANTES: $____________

Pagos NO reportados en este período:
- Pago #___ : Expected Amount: $____________
- Pago #___ : Expected Amount: $____________
Total no reportado: $____________
```

#### 4.5 Cerrar el período
- Click en **"Cerrar Período"**
- Confirmar cierre

#### 4.6 Verificar deuda DESPUÉS
- Ir a **Asociados** → Ver el asociado
- Ver su **Debt Balance** (Deuda Acumulada)
  ```
  Debt Balance DESPUÉS: $____________
  ```

#### 4.7 Validar el incremento
```
✅ VALIDACIÓN ESPERADA:
   Incremento de deuda = Debt Balance DESPUÉS - Debt Balance ANTES
   
   Debe coincidir con la suma de expected_amount de pagos no reportados
   
   Ejemplo:
   - Debt Balance ANTES: $0
   - Pagos no reportados: 2 pagos × $2,894.17 = $5,788.34
   - Debt Balance DESPUÉS: $5,788.34 ✅ CORRECTO
```

**Incremento real observado**: $____________

**¿Pasó la validación?** ☐ SÍ  ☐ NO

---

## 🧪 TEST 5: ABONAR A STATEMENT (OPCIONAL)

### Objetivo
Verificar que los abonos al statement actual actualicen correctamente el saldo.

#### 5.1 Ver un statement pendiente
- En **Statements**, buscar un statement con estado **PENDING** o **PARTIAL_PAID**

#### 5.2 Anotar los montos
```
Statement #___:
- Total cobrado (total_amount_collected): $____________
- Comisión adeudada (total_commission_owed): $____________
- Asociado debe entregar: $____________ (cobrado - comisión)
- Ya pagado (paid_amount): $____________
- Pendiente: $____________
```

#### 5.3 Registrar un abono
- Click en **"Registrar Abono"**
- Monto: la mitad del pendiente
- Método: Transferencia
- Confirmar

#### 5.4 Verificar actualización
- El `paid_amount` debe aumentar
- El estado puede cambiar a **PARTIAL_PAID**
- Si cubre todo → **PAID**

**¿Se actualizó correctamente?** ☐ SÍ  ☐ NO

---

## 📊 RESUMEN DE VALIDACIONES

| # | Test | Esperado | Real | ✅/❌ |
|---|------|----------|------|-------|
| 1 | Aprobar préstamo aumenta crédito usado | +$23,000 | $______ | ☐ |
| 2 | Pago libera solo capital | -$1,916.67 | $______ | ☐ |
| 3 | Saldo pendiente correcto | 11×$2,894.17 | $______ | ☐ |
| 4 | Deuda usa expected_amount | +$5,788.34 | $______ | ☐ |
| 5 | Abono actualiza statement | Correcto | Correcto | ☐ |

---

## 🔍 QUÉ BUSCAR EN CASO DE ERRORES

### Si el Test 1 falla (crédito no aumenta):
- Verificar que el trigger `trigger_update_associate_credit_on_loan_approval` esté activo
- Verificar en la BD directamente:
  ```sql
  SELECT credit_used, credit_available 
  FROM associate_profiles 
  WHERE user_id = [ASSOCIATE_ID];
  ```

### Si el Test 2 falla (libera monto incorrecto):
- El bug más probable: está liberando `expected_amount` en vez de solo el capital
- Verificar que el trigger `trigger_update_associate_credit_on_payment` esté corregido

### Si el Test 3 falla (saldo pendiente incorrecto):
- Verificar que la función `calculate_loan_remaining_balance` esté corregida
- Debe sumar `expected_amount` de pagos con status PENDING

### Si el Test 4 falla (deuda con monto 0):
- El bug: está usando `amount_paid` en vez de `expected_amount`
- Verificar que `close_period_and_accumulate_debt` esté corregida

---

## 📸 CAPTURAS RECOMENDADAS

Toma capturas de pantalla en:
1. Crédito del asociado ANTES y DESPUÉS de aprobar
2. Crédito del asociado ANTES y DESPUÉS de registrar pago
3. Saldo pendiente mostrado en renovación
4. Debt balance ANTES y DESPUÉS de cerrar período

---

## 🎯 CONCLUSIÓN

Al finalizar todos los tests, deberías tener:
- ✅ 5 validaciones completadas
- 📸 4-6 capturas de pantalla
- 📊 Tabla de resumen completa

Si todos los tests pasan: **🎉 TODAS LAS CORRECCIONES FUNCIONAN CORRECTAMENTE**

Si algún test falla: **⚠️ REVISAR LA CORRECCIÓN ESPECÍFICA**

---

**Siguiente paso**: Reportar resultados y decidir si aplicar a producción.
