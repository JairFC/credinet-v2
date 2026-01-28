# Análisis: Préstamo 1 y Convenios - 27 Enero 2026

## Situación Actual

### Timeline de Eventos (María Cruz - user_id=4)

| Fecha/Hora | Evento |
|------------|--------|
| 22 Jan 22:03 | Préstamo 1 creado ($10,000, 12 pagos de $1,255) |
| 23 Jan 06:02 | Statement generado (período 49, incluye pago 1) |
| 23 Jan 13:15 | Primer abono registrado ($9.95) |
| 23 Jan 13:38 | Segundo abono ($200.00) |
| 23 Jan 13:39 | Tercer abono ($10.00) |
| 23 Jan 14:17 | Cuarto abono ($47.00 - CARD ref:66655444) |
| 23 Jan 16:55 | **Convenio 7 creado** (préstamos 3,4) |
| 23 Jan 21:12 | Quinto abono ($499.97 - "RECIBE LA DISTRIBUIDORA") |

**Total abonos al statement: $766.92**

### Préstamos de María Cruz

| Loan | Estado | Monto | Convenio |
|------|--------|-------|----------|
| 1 | IN_AGREEMENT | $10,000 | Convenio 2 |
| 2 | IN_AGREEMENT | $15,000 | Convenio 2 |
| 3 | IN_AGREEMENT | $5,000 | Convenio 7 |
| 4 | IN_AGREEMENT | $3,000 | Convenio 7 |
| 6 | ACTIVE | $4,000 | - |
| 7 | ACTIVE | $3,000 | - |
| 8 | IN_AGREEMENT | $3,000 | Convenio 1 |
| 9 | IN_AGREEMENT | $5,000 | Convenio 1 |

### Convenios Activos

| Convenio | Préstamos | Deuda Total | Pagos |
|----------|-----------|-------------|-------|
| CONV-2026-0001 | 8, 9 | $10,544.04 | 6 x $1,757.34 |
| CONV-2026-0002 | 1, 2 | $34,102.50 | 6 x $5,683.75 |
| CONV-2026-0006 | 3, 4 | $10,003.98 | 6 x $1,667.33 |

## Problemas Identificados

### 1. Abonos "Huérfanos" en Statement

El statement del período 49 tiene:
- `total_amount_collected = $1,255.00` (pago 1 del préstamo 1)
- `paid_amount = $766.92` (abonos registrados)
- **Pero el pago 1 ahora está en IN_AGREEMENT**

Los $766.92 abonados ya no están aplicándose a nada porque:
1. El pago original del préstamo pasó a IN_AGREEMENT
2. Los pagos del convenio son diferentes ($1,757.34 para convenio 1)

### 2. El Préstamo 1 NO debe estar en convenio

El préstamo 1 es el **único de prueba** para el cron del día de corte. Según el usuario:
- Necesita estar como préstamo normal para probar el proceso de corte
- Si no se paga, la deuda debe pasar a consolidada
- Es el único con tiempos correctos para las pruebas

**El préstamo 1 debe sacarse del convenio 2**.

### 3. Regla de Negocio Faltante

No debería ser posible agregar a un convenio préstamos que:
- Ya tienen pagos en el statement del período actual
- Ya tienen abonos parciales registrados
- Ya pasaron un corte con pagos vencidos

**Propuesta**: Validar antes de crear convenio:
```
SI período_actual tiene statement con pagos del préstamo:
   SI el statement tiene abonos (paid_amount > 0):
      RECHAZAR: "El préstamo tiene pagos parciales en el período actual"
```

### 4. No Revertir Convenios Post-Corte

Si ya pasó un corte desde la creación del convenio:
- El primer pago del convenio ya fue requerido
- Revertir causaría inconsistencias en los statements

**Propuesta**: 
```
SI fecha_actual > primer_pago_convenio.due_date:
   RECHAZAR reversión
```

## ✅ Implementaciones Realizadas (27 Enero 2026)

### Validaciones Preventivas
1. **Validación abonos parciales**: No se puede crear convenio si el statement actual tiene `paid_amount > 0`
2. **Validación post-corte**: No se puede cancelar convenio si el primer pago ya venció y el período está cerrado
3. **Validación convenio duplicado**: Ya existía - no agregar préstamo a múltiples convenios activos

### Alertas/Notificaciones Agregadas
- ✅ Nuevo usuario registrado (`/auth/register`)
- ✅ Nuevo asociado creado (`/associates POST`)
- ✅ Cliente promovido a asociado (`/associates/promote-to-associate`)
- ✅ Convenio creado desde préstamos (`/agreements/from-loans`)
- ✅ Convenio cancelado (`/agreements/{id}/cancel`)

### Persistencia de Auditoría
- ✅ Tabla `system_events` creada para registro permanente de eventos
- ✅ `NotificationService.send()` ahora persiste automáticamente todos los eventos

## Plan de Acción Pendiente

### Fase 1: Corrección de Datos (DECISIÓN REQUERIDA)

El préstamo 1 está en convenio 2. Este préstamo es necesario para:
- Probar el proceso de corte (cron día 8 y 23)
- Verificar que la deuda no pagada pasa a consolidada

**Opciones:**

**OPCIÓN A**: Sacar préstamo 1 del convenio 2
- Crear función para sacar un préstamo específico de un convenio
- Restaurar pagos del préstamo 1 a PENDING
- Recalcular statement período 49 (los $766.92 deben volver a aplicarse)
- Ajustar deuda del convenio 2

**OPCIÓN B**: Mantener préstamo 1 en convenio y usar otro para pruebas
- Crear un nuevo préstamo de prueba para María Cruz
- Dejarlo fuera de convenio para las pruebas de corte

### Fase 2: Tracking de Pagos Convenio

Agregar vista/endpoint que muestre:
- Deuda original del convenio
- Pagos realizados
- Deuda restante
- Próximo pago y fecha

## Decisión Requerida

⚠️ **El préstamo 1 debe sacarse del convenio 2?**

Si SÍ:
- El convenio 2 quedará solo con préstamo 2 ($15,000)
- La deuda del convenio 2 se reducirá a ~$20,962.50
- Los pagos del convenio 2 se recalcularán

Si NO:
- Los abonos de $766.92 quedan "perdidos"
- El préstamo 1 no servirá para probar el cron de corte
