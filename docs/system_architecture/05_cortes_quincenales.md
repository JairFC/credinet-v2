# Sistema de Cortes Quincenales y Relaciones de Pago

## 1. ARQUITECTURA DEL SISTEMA DE CORTES

### 1.1. Concepto de Cortes Quincenales

El sistema divide cada mes en dos períodos de facturación:
- **Primer Corte**: Del día 1 al 15 de cada mes
- **Segundo Corte**: Del día 16 al último día del mes

### 1.2. Cronología de Procesos - LÓGICA REAL

```
📅 CORTE DÍA 8:
• Incluye: Todos los préstamos creados ANTES del día 8
• Su primer pago programado sale en esta relación
• Clientes tienen hasta el DÍA 15 para pagar
• Asociadas deben liquidar hasta el DÍA 7 DEL MES SIGUIENTE

📅 CORTE DÍA 23:  
• Incluye: Todos los préstamos creados del DÍA 8 AL 23
• Su primer pago programado sale en esta relación
• Clientes tienen hasta el DÍA 30/31 para pagar
• Asociadas deben liquidar hasta el DÍA 22 DEL MES SIGUIENTE

🚨 PENALIZACIÓN:
• Si asociada no liquida a tiempo → Se descuenta 30% de su comisión
```

**EJEMPLO PRÁCTICO:**
```
Préstamo del 23 enero → Primer pago en relación 8 febrero → Cliente paga hasta 15 febrero → Asociada liquida hasta 22 febrero

Préstamo del 9 enero → Primer pago en relación 23 enero → Cliente paga hasta 30 enero → Asociada liquida hasta 7 febrero
```

## 2. NOMENCLATURA Y CÓDIGOS

### 2.1. Sistema de Códigos de Corte

**Formato**: `{YYYY}-Q{NN}`

Donde:
- `YYYY`: Año de 4 dígitos
- `Q`: Literal "Q" (Quincena)
- `NN`: Número de quincena del año (01-24)

### 2.2. Ejemplos de Códigos por Año

```
2025-Q01: 1-15 enero 2025
2025-Q02: 16-31 enero 2025
2025-Q03: 1-15 febrero 2025
2025-Q04: 16-28 febrero 2025
...
2025-Q23: 1-15 diciembre 2025
2025-Q24: 16-31 diciembre 2025
```

### 2.3. Ventajas de esta Nomenclatura

- **Legibilidad**: Fácil identificación visual del período
- **Ordenamiento**: Se ordenan cronológicamente de forma natural
- **Unicidad**: Cada corte tiene un identificador único
- **Escalabilidad**: Funciona para cualquier año

## 3. MOTOR DE GENERACIÓN DE CORTES

### 3.1. Clase CutPeriodManager

```python
from datetime import datetime, date
from calendar import monthrange
import asyncpg

class CutPeriodManager:
    
    def __init__(self):
        self.GENERATION_DAYS = [8, 23]  # Días de generación automática
    
    async def generate_cuts_for_year(self, year: int, conn: asyncpg.Connection):
        """Genera todos los cortes del año especificado"""
        cuts_created = []
        
        for month in range(1, 13):  # Enero a Diciembre
            # Primer corte del mes (1-15)
            first_cut = await self.create_cut_period(
                year=year,
                month=month,
                is_first_half=True,
                conn=conn
            )
            cuts_created.append(first_cut)
            
            # Segundo corte del mes (16-último día)
            second_cut = await self.create_cut_period(
                year=year,
                month=month,
                is_first_half=False,
                conn=conn
            )
            cuts_created.append(second_cut)
        
        return cuts_created
    
    async def create_cut_period(self, year: int, month: int, is_first_half: bool, conn: asyncpg.Connection):
        """Crea un período de corte específico"""
        
        # Calcular número de quincena
        cut_number = (month - 1) * 2 + (1 if is_first_half else 2)
        cut_code = f"{year}-Q{cut_number:02d}"
        
        # Calcular fechas del período
        if is_first_half:
            period_start = date(year, month, 1)
            period_end = date(year, month, 15)
            client_deadline = date(year, month, 15)
            # Corte día 8: asociadas liquidan hasta día 22 del mismo mes
            associate_deadline = date(year, month, min(22, monthrange(year, month)[1]))
        else:
            last_day = monthrange(year, month)[1]
            period_start = date(year, month, 16)
            period_end = date(year, month, last_day)
            client_deadline = date(year, month, last_day)
            
            # Corte día 23: asociadas liquidan hasta día 7 del mes siguiente
            next_month = month + 1 if month < 12 else 1
            next_year = year if month < 12 else year + 1
            associate_deadline = date(next_year, next_month, 7)
        
        # Insertar en base de datos
        cut_id = await conn.fetchval("""
            INSERT INTO cut_periods (
                cut_code, cut_number, period_start_date, period_end_date,
                client_payment_deadline, associate_report_deadline,
                status, created_by
            ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
            RETURNING id
        """, cut_code, cut_number, period_start, period_end, 
            client_deadline, associate_deadline, 'PENDING', 2)  # Usuario admin
        
        return {
            'id': cut_id,
            'cut_code': cut_code,
            'period_start_date': period_start,
            'period_end_date': period_end
        }
    
    def get_current_cut_period(self) -> dict:
        """Determina el período de corte actual basado en la fecha de hoy"""
        today = date.today()
        year = today.year
        month = today.month
        day = today.day
        
        if day <= 15:
            # Primer corte del mes
            cut_number = (month - 1) * 2 + 1
            period_start = date(year, month, 1)
            period_end = date(year, month, 15)
        else:
            # Segundo corte del mes
            cut_number = (month - 1) * 2 + 2
            last_day = monthrange(year, month)[1]
            period_start = date(year, month, 16)
            period_end = date(year, month, last_day)
        
        cut_code = f"{year}-Q{cut_number:02d}"
        
        return {
            'cut_code': cut_code,
            'cut_number': cut_number,
            'period_start_date': period_start,
            'period_end_date': period_end
        }
```

### 3.2. Generación Automática en Días Específicos

```python
async def check_and_generate_payment_relations(self, conn: asyncpg.Connection):
    """Verifica si hoy es día de generación y ejecuta el proceso"""
    today = date.today()
    
    if today.day not in self.GENERATION_DAYS:
        return {"message": "No es día de generación automática"}
    
    # Determinar qué corte generar
    if today.day == 8:
        # Generar relaciones del primer corte del mes
        cut_period = await self.get_cut_by_code(f"{today.year}-Q{(today.month-1)*2+1:02d}", conn)
    elif today.day == 23:
        # Generar relaciones del segundo corte del mes
        cut_period = await self.get_cut_by_code(f"{today.year}-Q{(today.month-1)*2+2:02d}", conn)
    
    if cut_period:
        relations_generated = await self.generate_payment_relations_for_cut(cut_period['id'], conn)
        return {
            "cut_period": cut_period,
            "relations_generated": relations_generated
        }
    
    return {"message": "No se encontró período de corte para generar"}
```

## 4. SISTEMA DE RELACIONES DE PAGO

### 4.1. Generador de Relaciones de Pago

```python
class PaymentRelationGenerator:
    
    async def generate_payment_relations_for_cut(self, cut_period_id: int, conn: asyncpg.Connection):
        """Genera todas las relaciones de pago para un corte específico
        
        LÓGICA CLAVE: Incluye TODOS los préstamos activos con pagos programados 
        para esta fecha, sin importar cuándo se crearon o qué número de pago es.
        """
        
        # Obtener todos los asociados con préstamos activos que tengan pagos en este corte
        associates_with_payments = await self.get_associates_with_payments_in_cut(
            cut_period_id, conn
        )
        
        relations_created = []
        
        for associate in associates_with_payments:
            relation = await self.create_payment_relation_for_associate(
                cut_period_id, associate['user_id'], conn
            )
            relations_created.append(relation)
        
        # Generar documentos PDF para todas las relaciones
        for relation in relations_created:
            await self.generate_relation_document(relation['id'], conn)
        
        return relations_created
    
    async def create_payment_relation_for_associate(self, cut_period_id: int, associate_user_id: int, conn: asyncpg.Connection):
        """Crea una relación de pago específica para un asociado"""
        
        # Obtener información del corte
        cut_period = await conn.fetchrow("SELECT * FROM cut_periods WHERE id = $1", cut_period_id)
        
        # Generar número de relación
        relation_number = f"REL-{cut_period['cut_code']}-{associate_user_id:04d}"
        
        # Obtener préstamos del asociado con pagos programados para este corte
        # INCLUYE: Cualquier pago (1°, 2°, 3°, etc.) de cualquier préstamo activo
        loans_data = await self.get_associate_payments_for_cut(
            associate_user_id, cut_period_id, conn
        )
        
        # Calcular totales
        total_clients = len(set(loan['client_id'] for loan in loans_data))
        total_loans = len(loans_data)
        total_amount = sum(loan['scheduled_amount'] for loan in loans_data)
        total_commission = sum(loan['commission_amount'] for loan in loans_data)
        
        # Crear relación de pago
        relation_id = await conn.fetchval("""
            INSERT INTO associate_payment_relations (
                cut_period_id, associate_user_id, relation_number,
                total_clients, total_loans, total_amount_to_collect,
                total_commission_earned, due_date, status
            ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
            RETURNING id
        """, cut_period_id, associate_user_id, relation_number,
            total_clients, total_loans, total_amount, total_commission,
            cut_period['associate_report_deadline'], 'GENERATED')
        
        # Crear detalles de la relación
        for loan in loans_data:
            await conn.execute("""
                INSERT INTO payment_relation_details (
                    payment_relation_id, loan_id, payment_schedule_id,
                    client_name, client_phone, scheduled_amount,
                    payment_due_date, commission_rate, commission_amount
                ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
            """, relation_id, loan['loan_id'], loan['schedule_id'],
                loan['client_name'], loan['client_phone'], loan['scheduled_amount'],
                loan['due_date'], loan['commission_rate'], loan['commission_amount'])
        
        return {
            'id': relation_id,
            'relation_number': relation_number,
            'total_clients': total_clients,
            'total_amount': total_amount,
            'total_commission': total_commission
        }
    
    async def get_associate_loans_for_period(self, associate_user_id: int, cut_period_id: int, conn: asyncpg.Connection):
        """Obtiene los préstamos de un asociado que tienen pagos en el período"""
        
        return await conn.fetch("""
            SELECT 
                ps.id as schedule_id,
                ps.loan_id,
                ps.scheduled_amount,
                ps.scheduled_date as due_date,
                l.user_id as client_id,
                l.commission_rate,
                ps.scheduled_amount * (l.commission_rate / 100) as commission_amount,
                u.first_name || ' ' || u.last_name as client_name,
                u.phone_number as client_phone
            FROM payment_schedule ps
            JOIN loans l ON ps.loan_id = l.id
            JOIN users u ON l.user_id = u.id
            JOIN cut_periods cp ON ps.cut_period_id = cp.id
            WHERE l.associate_user_id = $1 
            AND ps.cut_period_id = $2
            AND l.status = 'ACTIVE'
            AND ps.status IN ('PENDING', 'PARTIAL', 'OVERDUE')
            ORDER BY ps.scheduled_date, u.last_name, u.first_name
        """, associate_user_id, cut_period_id)
```

### 4.2. Asignación de Pagos a Cortes - LÓGICA CORREGIDA

```python
async def assign_loan_to_cut_period(self, loan_id: int, loan_creation_date: date, conn: asyncpg.Connection):
    """Asigna el PRIMER PAGO de un préstamo al corte correspondiente según fecha de creación"""
    
    year = loan_creation_date.year
    month = loan_creation_date.month
    day = loan_creation_date.day
    
    # LÓGICA REAL: Basado en cuándo se CREÓ el préstamo
    if day < 8:
        # Préstamo creado ANTES del día 8 → Va al corte del día 8
        cut_number = (month - 1) * 2 + 1  # Corte del día 8
        cut_code = f"{year}-Q{cut_number:02d}"
        
        # Fecha límite para cliente: día 15 del mismo mes
        client_deadline = date(year, month, 15)
        
        # Fecha límite para asociada: día 7 del mes siguiente
        next_month = month + 1 if month < 12 else 1
        next_year = year if month < 12 else year + 1
        associate_deadline = date(next_year, next_month, 7)
        
    else:
        # Préstamo creado del día 8 al 23 → Va al corte del día 23
        cut_number = (month - 1) * 2 + 2  # Corte del día 23
        cut_code = f"{year}-Q{cut_number:02d}"
        
        # Fecha límite para cliente: último día del mes
        last_day = monthrange(year, month)[1]
        client_deadline = date(year, month, last_day)
        
        # Fecha límite para asociada: día 22 del mes siguiente
        next_month = month + 1 if month < 12 else 1
        next_year = year if month < 12 else year + 1
        associate_deadline = date(next_year, next_month, 22)
    
    # Buscar el corte en la base de datos
    cut_period = await conn.fetchrow("""
        SELECT id FROM cut_periods WHERE cut_code = $1
    """, cut_code)
    
    if cut_period:
        # Actualizar el PRIMER pago programado con el cut_period_id
        await conn.execute("""
            UPDATE payment_schedule 
            SET cut_period_id = $1,
                scheduled_date = $2
            WHERE loan_id = $3 AND payment_number = 1
        """, cut_period['id'], client_deadline, loan_id)
        
        return {
            'cut_period_id': cut_period['id'],
            'cut_code': cut_code,
            'client_deadline': client_deadline,
            'associate_deadline': associate_deadline
        }
    
    return None
```

## 5. PLANTILLA DE RELACIÓN DE PAGO - BASADA EN FORMATO REAL

### 5.1. Formato CrediCuenta (Basado en Relación de Olga Lydia Quiñones)

```
═══════════════════════════════════════════════════════════════════════════════
                              📄 CrediCuenta
                         RELACIÓN DE PAGOS - CORTE {{cut_code}}
                             {{associate_name}}
═══════════════════════════════════════════════════════════════════════════════

PERÍODO DE CORTE: {{period_description}}
FECHA LÍMITE PAGO CLIENTES: {{client_deadline}}
FECHA LÍMITE LIQUIDACIÓN ASOCIADA: {{associate_deadline}}

───────────────────────────────────────────────────────────────────────────────
Contrato    Personal                    Monto     Saldo    Abono    No.   Pago    No.   Plazo
                                      Acreditado Actualizado Quincenal Pago   Vencido  Pagos Restantes
───────────────────────────────────────────────────────────────────────────────
{{#each loan_details}}
{{contract_number}} {{client_name_padded}} ${{loan_amount}} ${{current_balance}} ${{payment_amount}} {{payment_number}} ${{overdue_amount}} {{remaining_payments}} {{term_months}}
{{/each}}
───────────────────────────────────────────────────────────────────────────────

COMISIONES POR COBRO DE PRÉSTAMOS RENOVADOS:

Cliente                               Cuota    Total de Préstamos en    Forma de
                                               Cartera                   Renovación

{{#each renewals}}
{{client_name}}                      ${{quota}}    ${{total_portfolio}}        {{renewal_type}}
{{/each}}

═══════════════════════════════════════════════════════════════════════════════
                            RESUMEN FINANCIERO
═══════════════════════════════════════════════════════════════════════════════

CANTIDAD RECIBIDA:  ${{total_received}}           TOTAL DE PRÉSTAMOS EN
                                                  CARTERA:       ${{total_portfolio}}

GASTOS              ${{expenses}}                 TOTAL COMISIÓN: ${{total_commission}}
OTORGADOS:

CRÉDITO             ${{credit_granted}}          SEGURO:    ${{insurance}}    COMISIÓN: ${{commission_amount}}
UTILIZADO:

CRÉDITO             ${{available_credit}}        TOTAL A PAGAR: ${{total_to_pay}}
DISPONIBLE:

ADEUDO              ${{total_debt}}
ACUMULADO:

───────────────────────────────────────────────────────────────────────────────
INTESTAR CORTE QUINCENAL    MANTENER EXPEDIENTE AL    FECHA RECEPCIÓN    OBSERVACIONES
                                  CORRIENTE
                            ____________________      _______________    _______________

═══════════════════════════════════════════════════════════════════════════════

FIRMA

_____________________        _____________________        ___________
    ACREDITADA                   ASESOR ACREDITADO           FECHA
{{associate_name}}            {{advisor_name}}          {{generation_date}}

───────────────────────────────────────────────────────────────────────────────
⚠️  IMPORTANTE: 
• Liquidar esta relación antes del {{associate_deadline}}
• El incumplimiento genera descuento del 30% en comisiones
• Clientes pueden pagar intereses moratorios adicionales según criterio
═══════════════════════════════════════════════════════════════════════════════
```

## 6. API ENDPOINTS PARA CORTES

### 6.1. Generar Cortes del Año

```python
@router.post("/cut-periods/generate-year/{year}")
async def generate_cuts_for_year(
    year: int,
    current_user: UserInDB = Depends(require_roles(["administrador"])),
    conn: asyncpg.Connection = Depends(get_db)
):
    """Genera todos los cortes de un año específico"""
    
    manager = CutPeriodManager()
    cuts = await manager.generate_cuts_for_year(year, conn)
    
    return {
        "year": year,
        "cuts_generated": len(cuts),
        "cuts": cuts
    }
```

### 6.2. Ejecutar Generación de Relaciones

```python
@router.post("/cut-periods/{cut_period_id}/generate-relations")
async def generate_payment_relations(
    cut_period_id: int,
    current_user: UserInDB = Depends(require_roles(["administrador", "auxiliar_administrativo"])),
    conn: asyncpg.Connection = Depends(get_db)
):
    """Genera las relaciones de pago para un corte específico"""
    
    generator = PaymentRelationGenerator()
    relations = await generator.generate_payment_relations_for_cut(cut_period_id, conn)
    
    return {
        "cut_period_id": cut_period_id,
        "relations_generated": len(relations),
        "relations": relations
    }
```

### 6.3. Obtener Relaciones de un Asociado

```python
@router.get("/associates/{associate_id}/payment-relations")
async def get_associate_payment_relations(
    associate_id: int,
    cut_code: Optional[str] = None,
    current_user: UserInDB = Depends(get_current_user),
    conn: asyncpg.Connection = Depends(get_db)
):
    """Obtiene las relaciones de pago de un asociado"""
    
    # Si es asociado, solo puede ver sus propias relaciones
    if "asociado" in current_user.roles and current_user.id != associate_id:
        raise HTTPException(status_code=403, detail="Sin permisos")
    
    query = """
        SELECT apr.*, cp.cut_code, cp.period_start_date, cp.period_end_date
        FROM associate_payment_relations apr
        JOIN cut_periods cp ON apr.cut_period_id = cp.id
        WHERE apr.associate_user_id = $1
    """
    params = [associate_id]
    
    if cut_code:
        query += " AND cp.cut_code = $2"
        params.append(cut_code)
    
    query += " ORDER BY cp.period_start_date DESC"
    
    relations = await conn.fetch(query, *params)
    
    return {"relations": [dict(r) for r in relations]}
```

## 7. PROCESO DE AUTOMATIZACIÓN

### 7.1. Job Scheduler para Generación Automática

```python
import schedule
import time
from datetime import date

class AutomatedCutProcessor:
    
    def __init__(self):
        self.setup_scheduled_jobs()
    
    def setup_scheduled_jobs(self):
        """Configura los trabajos programados"""
        
        # Ejecutar todos los días 8 a las 6:00 AM
        schedule.every().day.at("06:00").do(self.process_day_8_cuts)
        
        # Ejecutar todos los días 23 a las 6:00 AM  
        schedule.every().day.at("06:00").do(self.process_day_23_cuts)
    
    def process_day_8_cuts(self):
        """Procesa cortes del día 8 si es el día correcto"""
        if date.today().day == 8:
            asyncio.run(self.generate_first_cut_relations())
    
    def process_day_23_cuts(self):
        """Procesa cortes del día 23 si es el día correcto"""
        if date.today().day == 23:
            asyncio.run(self.generate_second_cut_relations())
    
    async def generate_first_cut_relations(self):
        """Genera relaciones para el primer corte del mes"""
        # Implementar lógica de generación
        pass
    
    async def generate_second_cut_relations(self):
        """Genera relaciones para el segundo corte del mes"""
        # Implementar lógica de generación
        pass
```

## 7. CONSULTAS SQL PARA GENERACIÓN DE RELACIONES

### 7.1. Obtener Todos los Pagos para un Corte

```sql
-- CONSULTA CLAVE: Obtiene TODOS los pagos programados para un corte específico
-- NO solo primeros pagos, sino cualquier número de pago de cualquier préstamo activo

SELECT 
    ps.loan_id,
    ps.payment_number,
    ps.scheduled_amount,
    l.client_id,
    l.associate_user_id,
    u_client.full_name as client_name,
    u_associate.full_name as associate_name,
    ps.scheduled_date
FROM payment_schedule ps
JOIN loans l ON ps.loan_id = l.id
JOIN users u_client ON l.client_id = u_client.id  
JOIN users u_associate ON l.associate_user_id = u_associate.id
WHERE ps.cut_period_id = $1  -- ID del corte específico
  AND ps.status = 'PENDING'
  AND l.status = 'ACTIVE'
ORDER BY u_associate.full_name, l.client_id, ps.payment_number;
```

### 7.2. Ejemplo de Resultado para Corte 8 Julio

```
| Préstamo | Pago # | Cliente | Asociada | Monto | Fecha Original |
|----------|--------|---------|----------|-------|----------------|
| L001     | 2      | Juan    | María    | 10000 | 9 junio        |
| L002     | 1      | Ana     | María    | 15000 | 2 julio        |  
| L003     | 5      | Luis    | María    | 8000  | 15 abril       |
| L004     | 1      | Rosa    | Carmen   | 12000 | 5 julio        |
```

**Explicación del ejemplo:**
- **L001**: Segundo pago del préstamo del 9 junio (12 quincenas)
- **L002**: Primer pago de préstamo nuevo del 2 julio
- **L003**: Quinto pago de préstamo antiguo del 15 abril  
- **L004**: Primer pago de préstamo nuevo del 5 julio

### 7.3. Totales por Asociada para el Corte

```sql
-- Calcular totales por asociada para generar su relación de pago
SELECT 
    l.associate_user_id,
    u.full_name as associate_name,
    COUNT(DISTINCT l.client_id) as total_clients,
    COUNT(ps.id) as total_payments,
    SUM(ps.scheduled_amount) as total_amount
FROM payment_schedule ps
JOIN loans l ON ps.loan_id = l.id
JOIN users u ON l.associate_user_id = u.id
WHERE ps.cut_period_id = $1
  AND ps.status = 'PENDING'
  AND l.status = 'ACTIVE'
GROUP BY l.associate_user_id, u.full_name
ORDER BY u.full_name;
```

## 8. MÉTRICAS Y REPORTES

### 8.1. Dashboard de Cortes

- Cortes activos y completados
- Monto total por corte
- Asociados con mayor volumen
- Eficiencia de cobro por período

### 8.2. Alertas Automáticas

- Cortes próximos a vencer
- Asociados con reportes pendientes
- Clientes con pagos atrasados
- Inconsistencias en los cálculos

Este sistema proporciona una base sólida para la gestión automatizada de cortes quincenales y relaciones de pago, manteniendo la trazabilidad completa y facilitando la administración del flujo de caja del negocio.