# 📋 Lógica de Convenios - Documentación Definitiva

**Última actualización:** 27 de Enero 2026  
**Autor:** Sistema de análisis  
**Estado:** En producción (con bugs identificados)

---

## 📌 Resumen Ejecutivo

El sistema de **Convenios de Pago** permite a CrediCuenta reestructurar la deuda de un asociado cuando tiene préstamos activos con pagos pendientes. El convenio "mueve" la deuda de `pending_payments_total` a `consolidated_debt`, liberando la capacidad de préstamo del asociado pero sin perdonar la deuda.

---

## 🔄 Flujos de Convenios

### ✅ **Flujo 1: Convenio desde Préstamos Activos** (EN USO)

📍 Frontend: `/convenios/nuevo` → `NuevoConvenioPage.jsx`  
📍 Backend: `POST /api/v1/agreements/from-loans`

**Este es el flujo activo en producción.** Se usa cuando:
- Un asociado tiene préstamos ACTIVOS con pagos PENDING
- El asociado no puede o no quiere esperar a que el cliente pague
- Se quiere "cerrar" los préstamos y convertir la deuda en un plan de pagos

#### Paso a Paso:

1. **Seleccionar Asociado** - Buscar asociado con préstamos activos
2. **Seleccionar Préstamos** - Elegir qué préstamos incluir (muestra pagos pendientes)
3. **Configurar Plan** - Definir plazo en meses (actualmente 1-36, debería ser quincenas)
4. **Crear Convenio** - Sin aprobación, se crea inmediatamente como ACTIVE

#### Acciones del Backend:

```python
# 1. Calcula total a mover (SUM de associate_payment de pagos PENDING)
total_to_move = SUM(payments.associate_payment WHERE status_id = 1 AND loan_id IN selected)

# 2. Marca pagos como IN_AGREEMENT
UPDATE payments SET status_id = 13 WHERE loan_id IN selected AND status_id = 1

# 3. Marca préstamos como IN_AGREEMENT
UPDATE loans SET status_id = 9 WHERE id IN selected

# 4. Mueve de pending_payments_total a consolidated_debt
UPDATE associate_profiles SET
    pending_payments_total = pending_payments_total - total_to_move,
    consolidated_debt = consolidated_debt + total_to_move
WHERE id = associate_profile_id

# 5. Crea calendario de pagos del convenio (agreement_payments)
FOR i in 1..payment_plan_months:
    INSERT INTO agreement_payments (payment_number, payment_amount, payment_due_date, status='PENDING')

# 6. Verifica que available_credit NO cambió (fórmula protegida)
ASSERT: available_credit_before == available_credit_after
```

---

### ⚠️ **Flujo 2: Convenio desde Deudas Aprobadas** (SIN USO)

📍 Frontend: `/convenios/crear` → `CreateAgreementPage.jsx`  
📍 Backend: `POST /api/v1/agreements`

**Este flujo está implementado pero NO se usa en producción.**

Es para crear convenios a partir de registros en `associate_debt_breakdown`, que se crean cuando:
- Se aprueba un reporte de cliente moroso
- Se registra una penalización o cargo adicional

Actualmente no hay clientes morosos aprobados en el sistema.

---

## 🔢 Fórmula del Crédito (CRÍTICA)

```
available_credit = credit_limit - pending_payments_total - consolidated_debt
```

### Al crear convenio:
| Campo | Antes | Después | Cambio |
|-------|-------|---------|--------|
| `pending_payments_total` | $10,000 | $0 | -$10,000 |
| `consolidated_debt` | $0 | $10,000 | +$10,000 |
| `available_credit` | $5,000 | $5,000 | **SIN CAMBIO** |

### Al pagar cuota de convenio:
| Campo | Antes | Después | Cambio (pago $2,000) |
|-------|-------|---------|----------------------|
| `consolidated_debt` | $10,000 | $8,000 | -$2,000 |
| `available_credit` | $5,000 | $7,000 | **+$2,000** |

---

## 📊 Estructura de Datos

### Tablas Involucradas:

```sql
-- Convenio principal
agreements (
    id, agreement_number, associate_profile_id,
    total_debt_amount, payment_plan_months, monthly_payment_amount,
    status ENUM('ACTIVE', 'COMPLETED', 'CANCELLED'),
    start_date, end_date, created_by, notes
)

-- Items incluidos en el convenio (préstamos)
agreement_items (
    id, agreement_id, loan_id, client_user_id,
    debt_amount, debt_type ENUM('LOAN_TRANSFER', 'DEFAULTED_CLIENT', ...),
    description
)

-- Calendario de pagos del convenio
agreement_payments (
    id, agreement_id, payment_number,
    payment_amount, payment_due_date,
    payment_date, payment_method_id, payment_reference,
    status ENUM('PENDING', 'PAID', 'CANCELLED')
)
```

### Estados de Pago Relevantes:

| status_id | Nombre | Significado |
|-----------|--------|-------------|
| 1 | PENDING | Pago pendiente (normal) |
| 13 | IN_AGREEMENT | Pago incluido en convenio |
| 9 | IN_AGREEMENT (loan) | Préstamo con convenio activo |

---

## 🐛 Bugs y Problemas Identificados

### 🔴 **Bug Crítico: Pagos IN_AGREEMENT en Statements**

**Problema:** Los pagos marcados como `IN_AGREEMENT` (status_id=13) **siguen apareciendo en los statements** porque las consultas SQL no los filtran.

**Impacto:** 
- 69+ pagos distribuidos en 16 períodos futuros
- Statements muestran montos incorrectos
- Asociado ve cuotas "duplicadas" (convenio + statement)

**Archivos a corregir:**
1. `backend/app/scheduler/jobs.py` líneas 243-264
2. `backend/app/modules/cut_periods/routes.py` líneas 916-929
3. `backend/app/modules/cut_periods/routes.py` líneas 340-365

**Corrección:** Agregar `AND p.status_id != 13` a las consultas.

---

### 🟡 **Problema: Pagos son MENSUALES, no QUINCENALES**

**Actual:** Los pagos de convenio se generan cada MES usando:
```python
payment_date = payment_date + relativedelta(months=1)
```

**Requerido:** Deberían ser QUINCENALES, alineados con los períodos de corte (días 8 y 23):
```python
# Propuesta: Alinear con períodos
if fecha.day <= 7:
    next_date = fecha.replace(day=22)
elif fecha.day <= 22:
    next_date = (fecha + relativedelta(months=1)).replace(day=7)
```

---

### 🟡 **Problema: No hay flujo de aprobación**

Los convenios se crean como `ACTIVE` inmediatamente. Debería haber:
- Estado `PENDING` inicial
- Proceso de aprobación por admin
- Verificación de condiciones

---

### 🟡 **Problema: Falta cálculo de deuda del CLIENTE**

Al crear convenio solo se muestra `associate_payment` (lo que debe el asociado a CrediCuenta).

También debería mostrarse `expected_amount` (lo que el cliente debe al préstamo):

| Préstamo | Deuda Cliente | Deuda Asociado |
|----------|---------------|----------------|
| #1 | $15,060.00 | $13,140.00 |
| #2 | $24,562.50 | $20,962.50 |

---

### 🟡 **Problema: Cancel no restaura estados**

Al cancelar convenio:
- NO restaura `payments` de IN_AGREEMENT → PENDING
- NO restaura `loans` de IN_AGREEMENT → ACTIVE
- Solo aumenta `consolidated_debt` (inconsistente)

---

## 📈 Convenios Actuales en Producción

| Convenio | Total | Meses | Préstamos | Estado |
|----------|-------|-------|-----------|--------|
| CONV-2026-0001 | $10,544.04 | 3 | #8, #9 | ACTIVE |
| CONV-2026-0002 | $34,102.50 | 3 | #1, #2 | ACTIVE |
| CONV-2026-0006 | $10,003.98 | 3 | #3, #4 | ACTIVE |

**Nota:** Hay convenios CANCELLED (0003, 0004, 0005) que fueron pruebas.

---

## 🎯 Mejoras Propuestas

### Prioridad ALTA (Crítico)

1. **Filtrar pagos IN_AGREEMENT de statements**
   - Impacto: Los statements mostrarán montos correctos
   - Esfuerzo: 30 minutos

2. **Cambiar de meses a quincenas**
   - Impacto: Alineación con períodos de corte
   - Esfuerzo: 1-2 horas

### Prioridad MEDIA

3. **Agregar cálculo de deuda del cliente**
   - Mostrar en NuevoConvenioPage cuánto debe el cliente
   - Esfuerzo: 1 hora

4. **Implementar flujo de aprobación**
   - Estado PENDING → aprobación → ACTIVE
   - Esfuerzo: 2-3 horas

5. **Corregir cancelación**
   - Restaurar estados originales de pagos y préstamos
   - Esfuerzo: 1-2 horas

### Prioridad BAJA

6. **Agregar notificaciones de vencimiento**
7. **Reportes de convenios por período**
8. **Dashboard de convenios con métricas**

---

## 📝 Notas Adicionales

### Usuarios Administradores Creados (27-Ene-2026)

| Usuario | Nombre | Email | Rol |
|---------|--------|-------|-----|
| Sandra.Lopez | Sandra Lopez Lopez | sandra.lopez@credinet.com | administrador |
| Jair.Franco | Jair Franco Cruz | jair.franco@credinet.com | administrador |
| Vanessa.Orozco | Vanessa Orozco Lopez | vanessa.orozco@credinet.com | administrador |

**Contraseña:** Sparrow20

---

## 🔗 Referencias

- [NuevoConvenioPage.jsx](../frontend-mvp/src/features/agreements/pages/NuevoConvenioPage.jsx)
- [agreements/routes.py](../backend/app/modules/agreements/routes.py)
- [defaulted_reports_routes.py](../backend/app/modules/agreements/defaulted_reports_routes.py)
