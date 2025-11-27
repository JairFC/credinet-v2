# ⚡ PENDIENTES Y ROADMAP CREDINET v2.0

> **Tracking de trabajo pendiente, prioridades y roadmap futuro**  
> Última actualización: 27 de Noviembre de 2025

---

## 📋 ÍNDICE

1. [Resumen Ejecutivo](#resumen-ejecutivo)
2. [Issues Inmediatos (Esta Semana)](#issues-inmediatos-esta-semana)
3. [Trabajo de Corto Plazo (1-2 Semanas)](#trabajo-de-corto-plazo-1-2-semanas)
4. [Trabajo de Mediano Plazo (1 Mes)](#trabajo-de-mediano-plazo-1-mes)
5. [Roadmap de Largo Plazo](#roadmap-de-largo-plazo)
6. [Bugs Conocidos](#bugs-conocidos)
7. [Deuda Técnica](#deuda-técnica)
8. [Mejoras de UX/UI](#mejoras-de-uxui)

---

## 1. RESUMEN EJECUTIVO

### 🎯 Estado General

| Categoría | Status | Detalles |
|-----------|--------|----------|
| **Sistema Core** | ✅ 95% Completo | Préstamos, pagos, perfiles funcionan |
| **Frontend** | ⚠️ 70% Completo | Requiere actualización nomenclatura y statements |
| **Backend** | ✅ 90% Completo | APIs funcionales, falta automatización |
| **Base de Datos** | ✅ 100% Completo | Schema estable, migraciones actualizadas |
| **Automatización** | ❌ 30% Completo | Falta corte automático y notificaciones |

### 📊 Distribución de Trabajo Pendiente

```
Alta Prioridad (Inmediato):    5 items  ⚠️
Media Prioridad (Corto Plazo): 8 items  🟡
Baja Prioridad (Mediano/Largo): 12 items 🟢
```

---

## 2. ISSUES INMEDIATOS (ESTA SEMANA)

### 🔴 PRIORIDAD CRÍTICA

#### Issue #1: Frontend - Nomenclatura de Periodos Desactualizada
**Problema:**  
Frontend muestra nomenclatura antigua: `Dic01-2025`, `Nov02-2025`, `Nov01-2025`  
Debe mostrar: `Dec23-2025`, `Dec08-2025`, `Nov23-2025`

**Impacto:** Alto - Confusión para usuarios finales  
**Esfuerzo:** Bajo (1-2 horas)  
**Archivo:** `frontend-mvp/src/features/statements/pages/PeriodosConStatementsPage.jsx`

**Solución:**
1. Backend YA devuelve nomenclatura correcta (Migration 024 aplicada)
2. Frontend debe refrescar datos o revisar transformación local
3. Verificar que no haya hardcoded de nombres de periodos

**Pasos:**
```javascript
// Verificar en PeriodosConStatementsPage.jsx
// 1. Revisar si hay formateo/transformación de cut_code
// 2. Asegurar que se use directamente el cut_code del backend
// 3. Refrescar caché si existe
```

**Aceptación:**
- [ ] Frontend muestra `Dec08-2025`, `Dec23-2025` correctamente
- [ ] No hay nomenclatura antigua visible
- [ ] Formato consistente en toda la app

---

#### Issue #2: Endpoint de Statements por Periodo
**Problema:**  
No existe endpoint que liste statements agrupados por asociado para un periodo

**Impacto:** Alto - Bloqueante para funcionalidad de statements  
**Esfuerzo:** Medio (4-6 horas)  
**Archivo:** `backend/app/modules/statements/routes.py` (nuevo)

**Requerimiento:**
```
GET /api/v1/periods/{period_id}/statements

Response:
{
  "period": {
    "cut_period_id": 46,
    "cut_code": "Dec08-2025",
    "status": "ACTIVE",
    "period_end_date": "2025-12-07",
    "print_date": "2025-12-08"
  },
  "statements": [
    {
      "associate": {
        "user_id": 5,
        "full_name": "Juan Pérez",
        "email": "juan@example.com"
      },
      "summary": {
        "total_expected": 1114.58,
        "total_collected": 614.58,
        "total_pending": 500.00,
        "commission_total": 110.00,
        "payments_count": 2,
        "loans_count": 2
      },
      "payments": [
        {
          "payment_id": 123,
          "loan_id": 56,
          "client_name": "María García",
          "payment_number": 1,
          "payment_due_date": "2025-12-15",
          "expected_amount": 614.58,
          "amount_to_associate": 559.58,
          "commission_amount": 55.00,
          "status": "PAID",
          "payment_date": "2025-12-14"
        },
        {
          "payment_id": 124,
          "loan_id": 47,
          "client_name": "Pedro Sánchez",
          "payment_number": 3,
          "payment_due_date": "2025-12-15",
          "expected_amount": 500.00,
          "amount_to_associate": 475.00,
          "commission_amount": 25.00,
          "status": "PENDING",
          "payment_date": null
        }
      ]
    },
    {
      "associate": {
        "user_id": 7,
        "full_name": "Ana López",
        "email": "ana@example.com"
      },
      "summary": {
        "total_expected": 850.00,
        "total_collected": 0.00,
        "total_pending": 850.00,
        "commission_total": 50.00,
        "payments_count": 1,
        "loans_count": 1
      },
      "payments": [...]
    }
  ],
  "totals": {
    "total_expected": 1964.58,
    "total_collected": 614.58,
    "total_pending": 1350.00,
    "associates_count": 2,
    "payments_count": 3
  }
}
```

**Lógica de Negocio:**
- ❌ NO incluir asociados sin pagos en el periodo
- ✅ Solo asociados CON pagos
- Ordenar por: `total_expected DESC` (asociados con más dinero primero)
- Incluir información del cliente en cada pago

**Query SQL Sugerida:**
```sql
WITH period_payments AS (
  SELECT 
    p.*,
    l.associate_user_id,
    l.user_id as client_user_id,
    u_client.full_name as client_name
  FROM payments p
  JOIN loans l ON p.loan_id = l.loan_id
  JOIN users u_client ON l.user_id = u_client.user_id
  WHERE p.cut_period_id = :period_id
),
associate_summaries AS (
  SELECT 
    associate_user_id,
    SUM(expected_amount) as total_expected,
    SUM(CASE WHEN status_id = 2 THEN amount_paid ELSE 0 END) as total_collected,
    SUM(CASE WHEN status_id != 2 THEN expected_amount ELSE 0 END) as total_pending,
    SUM(commission_amount) as commission_total,
    COUNT(*) as payments_count,
    COUNT(DISTINCT loan_id) as loans_count
  FROM period_payments
  GROUP BY associate_user_id
)
SELECT 
  u.user_id,
  u.full_name,
  u.email,
  s.*
FROM associate_summaries s
JOIN users u ON s.associate_user_id = u.user_id
ORDER BY s.total_expected DESC;
```

**Aceptación:**
- [ ] Endpoint funcional con autenticación
- [ ] Solo asociados con pagos en el periodo
- [ ] Incluye información de clientes
- [ ] Totales calculados correctamente
- [ ] Documentado en Swagger/OpenAPI

---

#### Issue #3: Vista Frontend de Statements por Asociado
**Problema:**  
Al hacer clic en un periodo, debe mostrar lista de statements por asociado

**Impacto:** Alto - Funcionalidad core de sistema  
**Esfuerzo:** Medio (6-8 horas)  
**Archivo:** `frontend-mvp/src/features/statements/pages/PeriodoDetailPage.jsx` (nuevo)

**Diseño Propuesto:**

```
┌─────────────────────────────────────────────────────────────┐
│ Periodo: Dec08-2025                                   [🔙]  │
│ Estado: ACTIVE  •  Cierre: 07/Dic/2025  •  Impresión: 08/Dic│
├─────────────────────────────────────────────────────────────┤
│                                                             │
│ 📊 RESUMEN DEL PERIODO                                      │
│                                                             │
│ Total Esperado:  $1,964.58    Asociados con Pagos: 2       │
│ Total Cobrado:   $  614.58    Préstamos Únicos:    3       │
│ Total Pendiente: $1,350.00    Total de Pagos:      3       │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│ 👥 STATEMENTS POR ASOCIADO                                  │
│                                                             │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ 👤 Juan Pérez                                           │ │
│ │ juan@example.com                                        │ │
│ │                                                         │ │
│ │ Esperado: $1,114.58  |  Cobrado: $614.58  |  Pend: $500│ │
│ │ 2 pagos de 2 préstamos                                 │ │
│ │                                                         │ │
│ │ [Ver Detalle] [Imprimir PDF] [Enviar Email]           │ │
│ └─────────────────────────────────────────────────────────┘ │
│                                                             │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ 👤 Ana López                                            │ │
│ │ ana@example.com                                         │ │
│ │                                                         │ │
│ │ Esperado: $850.00  |  Cobrado: $0.00  |  Pend: $850.00 │ │
│ │ 1 pago de 1 préstamo                                   │ │
│ │                                                         │ │
│ │ [Ver Detalle] [Imprimir PDF] [Enviar Email]           │ │
│ └─────────────────────────────────────────────────────────┘ │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Componentes Necesarios:**
```
src/features/statements/pages/
  └─ PeriodoDetailPage.jsx (NUEVO)

src/features/statements/components/
  ├─ PeriodoSummaryCard.jsx (NUEVO)
  ├─ AssociateStatementCard.jsx (NUEVO)
  └─ StatementActionButtons.jsx (NUEVO)

src/shared/api/services/
  └─ statementsService.js (actualizar)
```

**Aceptación:**
- [ ] Vista muestra lista de asociados con pagos
- [ ] Resumen del periodo correcto
- [ ] Cada card de asociado muestra totales
- [ ] Botón "Ver Detalle" muestra tabla de pagos
- [ ] Responsive (mobile y desktop)
- [ ] Loading states y error handling

---

#### Issue #4: Modal de Detalle de Pagos por Asociado
**Problema:**  
Al hacer clic en "Ver Detalle", mostrar tabla completa de pagos

**Impacto:** Medio - Complementa funcionalidad de statements  
**Esfuerzo:** Medio (4 horas)  
**Archivo:** `frontend-mvp/src/features/statements/components/AssociatePaymentsModal.jsx` (nuevo)

**Diseño:**
```
┌─────────────────────────────────────────────────────────────┐
│ Detalle de Pagos - Juan Pérez                         [✕]  │
│ Periodo: Dec08-2025                                         │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│ Cliente      | Préstamo | Pago # | Vence     | Esperado    │
│──────────────┼──────────┼────────┼───────────┼─────────────┤
│ María García │ #56      │ 1/12   │ 15/Dic/25 │ $614.58 ✅ │
│ Pedro Sánch  │ #47      │ 3/12   │ 15/Dic/25 │ $500.00 ⏳ │
│──────────────┴──────────┴────────┴───────────┴─────────────┤
│                                                             │
│ Total Esperado:  $1,114.58                                 │
│ Total Cobrado:   $  614.58                                 │
│ Total Pendiente: $  500.00                                 │
│ Comisión Total:  $  110.00                                 │
│                                                             │
│                                          [Cerrar] [Imprimir]│
└─────────────────────────────────────────────────────────────┘
```

**Aceptación:**
- [ ] Modal muestra todos los pagos del asociado en el periodo
- [ ] Información del cliente visible
- [ ] Estados visuales claros (✅ PAID, ⏳ PENDING, ⚠️ LATE)
- [ ] Totales calculados correctamente

---

#### Issue #5: Mensaje para Asociados Sin Pagos
**Problema:**  
Si se busca un asociado que no tiene pagos en el periodo, mostrar mensaje claro

**Impacto:** Bajo - UX  
**Esfuerzo:** Bajo (1 hora)  

**Diseño:**
```
┌─────────────────────────────────────────────────────────────┐
│ Periodo: Dec08-2025                                         │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│                  ℹ️  ASOCIADO SIN ACTIVIDAD                 │
│                                                             │
│  El asociado seleccionado no tiene pagos programados       │
│  para este periodo de corte.                               │
│                                                             │
│                        [Entendido]                          │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 3. TRABAJO DE CORTO PLAZO (1-2 SEMANAS)

### 🟡 PRIORIDAD MEDIA

#### Issue #6: Implementar Corte Automático (Cron Job)
**Problema:**  
Sistema no cierra periodos automáticamente a las 00:00 de días 8 y 23

**Impacto:** Alto - Operación manual es ineficiente  
**Esfuerzo:** Alto (8-12 horas)  
**Tecnología:** APScheduler + FastAPI

**Implementación:**

```python
# backend/app/core/scheduler.py (NUEVO)

from apscheduler.schedulers.asyncio import AsyncIOScheduler
from datetime import datetime

scheduler = AsyncIOScheduler()

@scheduler.scheduled_job('cron', day='8,23', hour=0, minute=0)
async def auto_close_period():
    """
    Ejecuta a las 00:00 de días 8 y 23 de cada mes
    """
    logger.info(f"Auto-close triggered at {datetime.now()}")
    
    # 1. Obtener periodo ACTIVE que debe cerrarse hoy
    today = datetime.now().date()
    period = await get_period_to_close(today)
    
    if not period:
        logger.warning("No period to close today")
        return
    
    # 2. Cambiar estado a DRAFT
    await update_period_status(period.cut_period_id, status_id=2)
    
    # 3. Generar statements por asociado
    statements = await generate_statements_for_period(period.cut_period_id)
    
    logger.info(f"Generated {len(statements)} statements for period {period.cut_code}")
    
    # 4. Enviar notificación a admins
    await notify_admins_period_closed(period, statements)
```

**Configuración:**
```python
# backend/app/main.py

from app.core.scheduler import scheduler

@app.on_event("startup")
async def startup_event():
    scheduler.start()
    logger.info("Scheduler started")

@app.on_event("shutdown")
async def shutdown_event():
    scheduler.shutdown()
    logger.info("Scheduler stopped")
```

**Aceptación:**
- [ ] Scheduler funciona en producción
- [ ] Ejecuta exactamente a las 00:00 días 8 y 23
- [ ] Genera statements correctamente
- [ ] Logs completos de ejecución
- [ ] Manejo de errores robusto
- [ ] No ejecuta múltiples veces el mismo día

---

#### Issue #7: Endpoint de Cierre Manual de Periodo
**Problema:**  
Admin no puede cerrar periodo manualmente (DRAFT → CLOSED)

**Impacto:** Alto - Workflow incompleto  
**Esfuerzo:** Medio (4 horas)  
**Archivo:** `backend/app/modules/statements/routes.py`

**Endpoint:**
```python
@router.post("/periods/{period_id}/close")
async def close_period_manually(
    period_id: int,
    current_user: User = Depends(get_current_user)
):
    """
    Cierra un periodo manualmente (DRAFT → CLOSED)
    Solo admin puede ejecutar
    Cambio IRREVERSIBLE
    """
    # 1. Verificar rol admin
    if not current_user.has_role('admin'):
        raise HTTPException(403, "Solo admins pueden cerrar periodos")
    
    # 2. Obtener periodo
    period = await get_period(period_id)
    
    # 3. Validar estado actual
    if period.status_id != 2:  # DRAFT
        raise HTTPException(400, "Solo periodos en DRAFT pueden cerrarse")
    
    # 4. Cambiar estado a CLOSED
    await update_period_status(period_id, status_id=3, closed_by=current_user.user_id)
    
    # 5. Marcar statements como FINALIZED
    await finalize_statements(period_id)
    
    # 6. Registrar en audit_log
    await audit_log_create(
        user_id=current_user.user_id,
        action="PERIOD_CLOSED",
        entity_type="cut_period",
        entity_id=period_id
    )
    
    return {"message": "Periodo cerrado exitosamente", "period_id": period_id}
```

**Aceptación:**
- [ ] Solo admin puede ejecutar
- [ ] Solo periodos DRAFT pueden cerrarse
- [ ] Cambio registrado en audit_log
- [ ] Statements marcados como FINALIZED
- [ ] Error handling completo

---

#### Issue #8: Generación de Statements Automática
**Problema:**  
Al cambiar periodo a DRAFT, debe generar records en `associate_payment_statements`

**Impacto:** Alto - Core de sistema  
**Esfuerzo:** Alto (6-8 horas)  
**Archivo:** `backend/app/modules/statements/service.py` (nuevo)

**Función:**
```python
async def generate_statements_for_period(period_id: int) -> List[AssociateStatement]:
    """
    Genera statements para todos los asociados con pagos en el periodo
    """
    statements = []
    
    # 1. Obtener asociados únicos con pagos en el periodo
    query = """
        SELECT DISTINCT l.associate_user_id
        FROM payments p
        JOIN loans l ON p.loan_id = l.loan_id
        WHERE p.cut_period_id = :period_id
    """
    associates = await db.fetch_all(query, {"period_id": period_id})
    
    # 2. Para cada asociado, generar statement
    for assoc in associates:
        assoc_id = assoc['associate_user_id']
        
        # 2.1 Calcular totales
        totals_query = """
            SELECT 
                SUM(p.expected_amount) as total_expected,
                SUM(CASE WHEN p.status_id = 2 THEN p.amount_paid ELSE 0 END) as total_collected,
                SUM(CASE WHEN p.status_id != 2 THEN p.expected_amount ELSE 0 END) as total_pending,
                SUM(p.commission_amount) as commission_total,
                COUNT(*) as payments_count,
                COUNT(DISTINCT p.loan_id) as loans_count
            FROM payments p
            JOIN loans l ON p.loan_id = l.loan_id
            WHERE p.cut_period_id = :period_id
              AND l.associate_user_id = :assoc_id
        """
        totals = await db.fetch_one(totals_query, {"period_id": period_id, "assoc_id": assoc_id})
        
        # 2.2 Crear statement
        stmt_id = await db.execute("""
            INSERT INTO associate_payment_statements (
                associate_user_id, cut_period_id, status_id,
                total_expected, total_collected, total_pending, commission_total,
                payments_count, loans_count
            ) VALUES (
                :assoc_id, :period_id, 1,
                :total_expected, :total_collected, :total_pending, :commission_total,
                :payments_count, :loans_count
            )
            RETURNING statement_id
        """, {
            "assoc_id": assoc_id,
            "period_id": period_id,
            **totals
        })
        
        # 2.3 Vincular pagos
        await db.execute("""
            INSERT INTO associate_statement_payments (statement_id, payment_id)
            SELECT :stmt_id, p.payment_id
            FROM payments p
            JOIN loans l ON p.loan_id = l.loan_id
            WHERE p.cut_period_id = :period_id
              AND l.associate_user_id = :assoc_id
        """, {"stmt_id": stmt_id, "period_id": period_id, "assoc_id": assoc_id})
        
        statements.append({"statement_id": stmt_id, "associate_user_id": assoc_id})
    
    return statements
```

**Aceptación:**
- [ ] Genera statements solo para asociados CON pagos
- [ ] Totales calculados correctamente
- [ ] Pagos vinculados correctamente
- [ ] Estado inicial: DRAFT
- [ ] Logs de generación

---

#### Issue #9: Sistema de Notificaciones por Email
**Problema:**  
Sistema no envía emails automáticos

**Impacto:** Medio - UX y operaciones  
**Esfuerzo:** Alto (8-10 horas)  
**Tecnología:** FastAPI-Mail + Templates

**Casos de Uso:**
1. Email cuando periodo se cierra automáticamente (a admins)
2. Email cuando statement está listo (a asociado)
3. Email cuando pago vence pronto (a cliente)
4. Email cuando pago está en mora (a cliente y asociado)

**Implementación:**
```python
# backend/app/core/email.py (NUEVO)

from fastapi_mail import FastMail, MessageSchema, ConnectionConfig
from jinja2 import Environment, FileSystemLoader

mail_conf = ConnectionConfig(
    MAIL_USERNAME="credinet@example.com",
    MAIL_PASSWORD="password",
    MAIL_FROM="credinet@example.com",
    MAIL_PORT=587,
    MAIL_SERVER="smtp.gmail.com",
    MAIL_STARTTLS=True,
    MAIL_SSL_TLS=False,
    USE_CREDENTIALS=True
)

fm = FastMail(mail_conf)

# Templates
template_env = Environment(loader=FileSystemLoader("app/templates/emails"))

async def send_period_closed_notification(period, statements_count):
    """Notifica a admins que periodo se cerró automáticamente"""
    template = template_env.get_template("period_closed.html")
    html = template.render(period=period, count=statements_count)
    
    message = MessageSchema(
        subject=f"Periodo {period.cut_code} cerrado automáticamente",
        recipients=["admin@credinet.com"],
        body=html,
        subtype="html"
    )
    
    await fm.send_message(message)

async def send_statement_ready(associate_email, statement):
    """Notifica a asociado que su statement está listo"""
    template = template_env.get_template("statement_ready.html")
    html = template.render(statement=statement)
    
    message = MessageSchema(
        subject=f"Tu estado de cuenta {statement.period_code} está listo",
        recipients=[associate_email],
        body=html,
        subtype="html"
    )
    
    await fm.send_message(message)
```

**Templates HTML:**
```html
<!-- app/templates/emails/period_closed.html -->
<html>
<body>
  <h2>Periodo {{ period.cut_code }} Cerrado Automáticamente</h2>
  <p>El sistema ha cerrado el periodo {{ period.cut_code }} a las 00:00.</p>
  <p>Estadísticas:</p>
  <ul>
    <li>Statements generados: {{ count }}</li>
    <li>Estado: DRAFT (requiere revisión)</li>
  </ul>
  <a href="https://credinet.com/periods/{{ period.cut_period_id }}">
    Ver Periodo
  </a>
</body>
</html>
```

**Aceptación:**
- [ ] Envío de emails funcional
- [ ] Templates HTML bien diseñados
- [ ] No envía spam (límites configurados)
- [ ] Logs de emails enviados
- [ ] Manejo de errores de SMTP

---

#### Issue #10: Dashboard de Admin con Métricas
**Problema:**  
Vista de admin sin métricas visuales útiles

**Impacto:** Medio - UX  
**Esfuerzo:** Alto (10-12 horas)  
**Archivo:** `frontend-mvp/src/features/dashboard/AdminDashboard.jsx`

**Métricas Necesarias:**
1. **Periodos:**
   - Periodo activo actual
   - Próximo cierre (días restantes)
   - Periodos en DRAFT pendientes de cerrar
2. **Préstamos:**
   - Total activos
   - Monto total prestado
   - Tasa de aprobación
3. **Pagos:**
   - Pagos pendientes hoy
   - Pagos en mora
   - Tasa de morosidad
4. **Asociados:**
   - Total activos
   - Top 5 asociados (por monto prestado)
   - Distribución por nivel

**Componentes:**
```jsx
<AdminDashboard>
  <MetricsGrid>
    <MetricCard title="Periodo Actual" value="Dec08-2025" />
    <MetricCard title="Próximo Cierre" value="7 días" />
    <MetricCard title="Préstamos Activos" value="42" />
    <MetricCard title="Morosidad" value="5.2%" />
  </MetricsGrid>
  
  <ChartsGrid>
    <LoansTrendChart />
    <PaymentsStatusPieChart />
    <TopAssociatesChart />
  </ChartsGrid>
  
  <AlertsPanel>
    <Alert type="warning">3 pagos vencen hoy</Alert>
    <Alert type="info">Periodo Dec08-2025 cierra en 7 días</Alert>
  </AlertsPanel>
</AdminDashboard>
```

**Aceptación:**
- [ ] Métricas en tiempo real
- [ ] Gráficas visuales (Chart.js o similar)
- [ ] Alertas contextuales
- [ ] Responsive

---

## 4. TRABAJO DE MEDIANO PLAZO (1 MES)

### 🟢 PRIORIDAD BAJA

#### Issue #11: Generación de PDFs de Statements
**Esfuerzo:** Alto (12-16 horas)  
**Tecnología:** ReportLab o WeasyPrint

**Características:**
- Logo de CrediNet
- Información del asociado
- Tabla de pagos del periodo
- Totales y resumen
- Código QR para verificación

---

#### Issue #12: Sistema de Recordatorios Automáticos
**Esfuerzo:** Medio (6-8 horas)  
**Tecnología:** APScheduler + Email/SMS

**Tipos de Recordatorios:**
- 3 días antes de vencimiento → Email a cliente
- Día de vencimiento → Email + SMS a cliente
- 1 día después → Email a cliente y asociado
- 7 días después → Marcado como LATE, notificación urgente

---

#### Issue #13: Búsqueda Avanzada de Préstamos
**Esfuerzo:** Medio (6 horas)

**Filtros:**
- Por asociado
- Por cliente
- Por rango de fechas
- Por monto
- Por estado
- Por perfil (legacy/standard/custom)
- Por tasa de comisión

---

#### Issue #14: Exportación de Reportes
**Esfuerzo:** Medio (6-8 horas)

**Reportes:**
- Listado de préstamos (CSV, Excel)
- Listado de pagos (CSV, Excel)
- Reporte de morosidad
- Reporte de comisiones

---

#### Issue #15: Integración WhatsApp Business API
**Esfuerzo:** Alto (16-20 horas)

**Funcionalidades:**
- Recordatorios automáticos
- Consulta de saldo
- Registro de pagos vía chatbot

---

## 5. ROADMAP DE LARGO PLAZO

### Q1 2026 (Enero - Marzo)

**Módulo de Renovaciones Automáticas**
- Cliente completa préstamo → Oferta automática de renovación
- Pre-aprobación basada en historial
- Tasas preferenciales para buenos pagadores

**Analytics Avanzado**
- Predicción de morosidad con ML
- Análisis de rentabilidad por asociado
- Clustering de clientes (riesgo)

**Multi-tenant**
- Soporte para múltiples cooperativas
- Base de datos por tenant
- Facturación por uso

---

### Q2 2026 (Abril - Junio)

**App Móvil (React Native)**
- Vista de asociado
- Notificaciones push
- Consulta de statements offline
- Registro de pagos desde móvil

**Pasarelas de Pago**
- Stripe/PayPal
- OXXO Pay
- Transferencias SPEI

---

### Q3 2026 (Julio - Septiembre)

**Sistema de Crédito Scoring**
- Score basado en historial
- Recomendaciones de aprobación/rechazo
- Límites dinámicos

**Marketplace de Asociados**
- Clientes eligen asociado
- Ranking de asociados (tasas, velocidad)
- Sistema de reviews

---

## 6. BUGS CONOCIDOS

### 🐛 Bug #1: Validación de CURP/RFC Falta
**Severidad:** Media  
**Impacto:** Datos inconsistentes  
**Solución:** Agregar validación regex en backend y frontend

### 🐛 Bug #2: Timezone en Fechas de Corte
**Severidad:** Baja  
**Impacto:** Cortes pueden ejecutarse con 1 hora de diferencia  
**Solución:** Usar UTC en DB, convertir a timezone México en app

### 🐛 Bug #3: Paginación Lenta en Lista de Pagos
**Severidad:** Baja  
**Impacto:** Performance con +1000 pagos  
**Solución:** Índices adicionales, paginación server-side

---

## 7. DEUDA TÉCNICA

### 📦 Deuda #1: Tests Unitarios Faltantes
**Impacto:** Alto - Riesgo de regresiones  
**Cobertura actual:** ~20%  
**Meta:** 80% cobertura

**Prioridad de Testing:**
1. Funciones críticas (`generate_payment_schedule`, `get_cut_period_for_payment`)
2. Endpoints de préstamos y pagos
3. Lógica de cálculo de intereses
4. Trigger de generación

---

### 📦 Deuda #2: Documentación de API Incompleta
**Impacto:** Medio - Onboarding lento  
**Estado actual:** Swagger básico  
**Meta:** Swagger completo con ejemplos

---

### 📦 Deuda #3: Logs Estructurados
**Impacto:** Medio - Debugging difícil  
**Actual:** print() y logs básicos  
**Meta:** Structured logging con contexto

---

### 📦 Deuda #4: CI/CD Pipeline
**Impacto:** Alto - Deploy manual  
**Meta:** GitHub Actions con:
- Tests automáticos
- Linting
- Build de Docker
- Deploy a staging/producción

---

## 8. MEJORAS DE UX/UI

### 🎨 UX #1: Loading States Consistentes
Todos los componentes deben tener spinners/skeletons consistentes

### 🎨 UX #2: Error Messages Amigables
Errores técnicos deben traducirse a mensajes comprensibles

### 🎨 UX #3: Animaciones de Transición
Transiciones suaves entre vistas

### 🎨 UX #4: Modo Oscuro
Tema oscuro para reducir fatiga visual

### 🎨 UX #5: Accesibilidad (a11y)
- ARIA labels
- Navegación por teclado
- Contraste de colores

---

## 📊 TRACKING DE PROGRESO

```
COMPLETADO:     ████████████████████████░░░░░░  80%
EN PROGRESO:    ██████░░░░░░░░░░░░░░░░░░░░░░░░  20%
PENDIENTE:      ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░   0%
```

| Categoría | Completado | En Progreso | Pendiente |
|-----------|------------|-------------|-----------|
| Core Features | 18/20 | 2/20 | 0/20 |
| Frontend | 12/18 | 3/18 | 3/18 |
| Backend APIs | 25/30 | 3/30 | 2/30 |
| Automatización | 2/8 | 2/8 | 4/8 |
| Testing | 5/30 | 5/30 | 20/30 |
| Documentación | 15/20 | 3/20 | 2/20 |

---

**Última actualización:** 27 de Noviembre de 2025  
**Próxima revisión:** 4 de Diciembre de 2025  
**Responsable:** Equipo de Desarrollo CrediNet
