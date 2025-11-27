# 03 - Lógica de Generación

## ⚠️ NOTA IMPORTANTE

**Esta documentación describe la lógica ADAPTADA a la estructura real de la BD.**

Última actualización: 2025-11-06  
Basada en: Estructura real de `associate_payment_statements`

---

## 🎯 Algoritmo Principal (Versión Simplificada)

### Función: `generate_payment_statement()`

```python
def generate_payment_statement(user_id: int, cut_period_id: int) -> int:
    """
    Genera una relación de pago para un asociado en un periodo específico.
    
    NOTA: Esta versión simplificada NO incluye:
    - Snapshot de crédito (se consulta en tiempo real)
    - Detalles de préstamos (tabla auxiliar no implementada)
    - Comisiones renovadas (tabla auxiliar no implementada)
    
    Args:
        user_id: ID del asociado (user.id donde user tiene rol 'asociado')
        cut_period_id: ID del periodo de corte
    
    Returns:
        statement_id (int): ID del statement generado
        
    Raises:
        ValueError: Si el asociado no existe, periodo inválido o statement duplicado
    """
    
    # 1. VALIDAR ENTRADA
    associate = get_associate_by_user_id(user_id)
    if not associate:
        raise ValueError(f"Usuario {user_id} no es un asociado válido")
    
    cut_period = get_cut_period(cut_period_id)
    if not cut_period:
        raise ValueError(f"Periodo {cut_period_id} no existe")
    
    # Verificar si ya existe statement (evitar duplicados)
    existing = db.query(AssociatePaymentStatement).filter(
        AssociatePaymentStatement.user_id == user_id,
        AssociatePaymentStatement.cut_period_id == cut_period_id
    ).first()
    
    if existing:
        raise ValueError(
            f"Ya existe statement #{existing.id} para este asociado y periodo"
        )
    
    # 2. OBTENER PAGOS PENDIENTES DEL PERIODO
    pending_payments = get_pending_payments_for_period(user_id, cut_period_id)
    
    if not pending_payments:
        # No hay pagos pendientes, no generar relación
        logger.info(f"Asociado {user_id} no tiene pagos pendientes en periodo {cut_period_id}")
        return None
    
    # 3. CALCULAR TOTALES
    totals = calculate_statement_totals(pending_payments, associate)
    
    # 4. GENERAR NÚMERO DE STATEMENT
    statement_number = generate_statement_number(cut_period_id, user_id)
    
    # 5. CALCULAR FECHA DE VENCIMIENTO
    # Por defecto: 7 días después del fin del periodo
    due_date = cut_period.period_end_date + timedelta(days=7)
    
    # 6. CREAR REGISTRO PRINCIPAL
    statement = AssociatePaymentStatement(
        statement_number=statement_number,
        user_id=user_id,
        cut_period_id=cut_period_id,
        
        # Estadísticas
        total_payments_count=totals['payments_count'],
        total_amount_collected=totals['total_collected'],
        total_commission_owed=totals['total_commission'],
        commission_rate_applied=associate.commission_rate,
        
        # Estado inicial
        status_id=get_statement_status_id('GENERATED'),
        
        # Fechas
        generated_date=date.today(),
        due_date=due_date,
        
        # Cargos (inicialmente en 0)
        late_fee_amount=Decimal('0.00'),
        late_fee_applied=False
    )
    
    db.add(statement)
    db.commit()
    db.refresh(statement)
    
    # 7. NOTIFICAR (opcional)
    notify_statement_generated(statement.id)
    
    logger.info(
        f"Statement #{statement.id} generado: {totals['payments_count']} pagos, "
        f"comisión ${totals['total_commission']}"
    )
    
    return statement.id
```

---

## 🔢 Funciones de Cálculo

### 1. Obtener Pagos Pendientes

```python
def get_pending_payments_for_period(user_id: int, cut_period_id: int) -> List[Payment]:
    """
    Obtiene todos los pagos pendientes de un asociado para un periodo.
    
    IMPORTANTE: La tabla se llama 'payments' (no 'payment_schedule')
    """
    return db.query(Payment).join(
        Loan, Payment.loan_id == Loan.id
    ).join(
        PaymentStatus, Payment.status_id == PaymentStatus.id
    ).filter(
        Loan.associate_profile_id == user_id,  # Asociado dueño del préstamo
        Payment.cut_period_id == cut_period_id,  # Periodo específico
        PaymentStatus.name.in_(['PENDING', 'OVERDUE']),  # Solo pendientes o vencidos
        Loan.status_id.in_([
            get_loan_status_id('ACTIVE'),
            get_loan_status_id('APPROVED')
        ])  # Préstamos activos
    ).order_by(
        Loan.client_id,
        Loan.id,
        Payment.payment_number
    ).all()
```

### 2. Calcular Totales

```python
def calculate_statement_totals(
    payments: List[Payment], 
    associate: AssociateProfile
) -> dict:
    """
    Calcula los totales de la relación de pago.
    
    Args:
        payments: Lista de pagos pendientes
        associate: Perfil del asociado
        
    Returns:
        dict con:
            - payments_count: Cantidad de pagos
            - total_collected: Total cobrado a clientes
            - total_commission: Comisión total del asociado
    """
    
    # Contar pagos únicos
    payments_count = len(payments)
    
    # Sumar montos esperados de clientes
    total_collected = sum(
        p.expected_amount for p in payments 
        if p.expected_amount is not None
    )
    
    # Sumar comisiones
    total_commission = sum(
        p.commission_amount for p in payments 
        if p.commission_amount is not None
    )
    
    # Validación de coherencia
    if total_commission < 0:
        raise ValueError("La comisión total no puede ser negativa")
    
    if total_collected < total_commission:
        logger.warning(
            f"Anomalía: total_collected (${total_collected}) < "
            f"total_commission (${total_commission})"
        )
    
    return {
        'payments_count': payments_count,
        'total_collected': total_collected,
        'total_commission': total_commission
    }
```

### 3. Generar Número de Statement

```python
def generate_statement_number(cut_period_id: int, user_id: int) -> str:
    """
    Genera un número único de statement.
    
    Formato: ST-{YYYY}-{QNN}-{ASSOC_ID}
    Ejemplo: ST-2025-Q01-005
    
    Args:
        cut_period_id: ID del periodo de corte
        user_id: ID del asociado
        
    Returns:
        str: Número de statement único
    """
    cut_period = get_cut_period(cut_period_id)
    
    # Obtener código del periodo (ej: 2025-Q01)
    period_code = cut_period.cut_code
    
    # Formatear ID del asociado con ceros a la izquierda
    associate_code = str(user_id).zfill(3)
    
    statement_number = f"ST-{period_code}-{associate_code}"
    
    return statement_number
```

---

## 🔢 Funciones Auxiliares (Futuro)

### Calcular Seguro (NO IMPLEMENTADO AÚN)

```python
def calculate_insurance_fee(
    payments_count: int, 
    rate_per_payment: Decimal = Decimal('3.92')
) -> Decimal:
    """
    Calcula el cargo por seguro.
    
    ⚠️ NOTA: Esta funcionalidad NO está implementada en la BD actual.
    La tabla no tiene campo 'insurance_fee'.
    
    Fórmula: payments_count * rate_per_payment
    Ejemplo: 97 recibos * $3.92 = $380.24
    """
    return Decimal(payments_count) * rate_per_payment
```

### Snapshot de Crédito (CONSULTA EN TIEMPO REAL)

```python
def get_credit_snapshot(user_id: int) -> dict:
    """
    Obtiene el estado actual del crédito del asociado.
    
    ⚠️ NOTA: NO se guarda en associate_payment_statements.
    Se consulta en tiempo real de associate_profiles.
    """
    associate = db.query(AssociateProfile).filter_by(user_id=user_id).first()
    
    if not associate:
        raise ValueError(f"Asociado {user_id} no encontrado")
    
    credit_available = (
        associate.credit_limit - 
        associate.credit_used - 
        associate.debt_balance
    )
    
    return {
        'credit_limit': associate.credit_limit,
        'credit_used': associate.credit_used,
        'credit_available': credit_available,
        'debt_balance': associate.debt_balance
    }
```

---

## 🔢 Fórmulas Matemáticas

### Fórmula 1: Comisión por Pago

```python
# En la tabla payments, cada pago ya tiene calculado:
commission_amount = expected_amount - associate_payment

# Ejemplo:
# expected_amount = $633.00 (paga el cliente)
# associate_payment = $553.00 (recibe el asociado)
# commission_amount = $80.00 (comisión de Credicuenta)
```

### Fórmula 2: Total Cobrado

```python
total_amount_collected = SUM(expected_amount) 
                         FOR payments IN cut_period
                         WHERE status IN ('PENDING', 'OVERDUE')

# Ejemplo MELY (97 pagos):
# total_amount_collected = $103,697.00
```

### Fórmula 3: Total Comisión

```python
total_commission_owed = SUM(commission_amount)
                        FOR payments IN cut_period
                        WHERE status IN ('PENDING', 'OVERDUE')

# Ejemplo MELY (97 pagos):
# total_commission_owed = $12,680.00
```

### Fórmula 4: Crédito Disponible (Tiempo Real)

```python
credit_available = credit_limit - credit_used - debt_balance

# Ejemplo MELY (sin deuda):
# credit_available = $700,000 - $552,297 - $0 = $147,703

# Ejemplo PILAR (con deuda):
# credit_available = $700,000 - $593,953 - $57,476 = $106,047
```

### Fórmula 5: Seguro

```javascript
insurance_fee = payments_count * rate_per_payment

// MELY:
insurance_fee = 97 * $3.92 ≈ $380.00
```

---

## 📋 Generación de Número de Statement

```python
def generate_statement_number(cut_period_id: int, associate_id: int) -> str:
    """
    Genera un número único para el statement.
    
    Formato: ST-YYYY-PPP-AAA
    - ST: Statement
    - YYYY: Año
    - PPP: Número de periodo (001-024)
    - AAA: ID del asociado (001-999)
    
    Ejemplo: ST-2025-002-005
    """
    cut_period = get_cut_period(cut_period_id)
    year = cut_period.start_date.year
    period_number = cut_period.period_number  # 1-24 (2 por mes)
    
    return f"ST-{year}-{period_number:03d}-{associate_id:03d}"
```

---

## 🔄 Job Automático

```python
from apscheduler.schedulers.background import BackgroundScheduler
from apscheduler.triggers.cron import CronTrigger

def generate_all_statements_for_period(cut_period_id: int):
    """
    Genera statements para todos los asociados con pagos pendientes.
    """
    # Obtener todos los asociados activos
    associates = db.query(AssociateProfile).filter(
        AssociateProfile.status == 'ACTIVE'
    ).all()
    
    success_count = 0
    error_count = 0
    
    for associate in associates:
        try:
            statement_id = generate_payment_statement(associate.user_id, cut_period_id)
            if statement_id:
                success_count += 1
                send_notification_to_admin(
                    f"Statement {statement_id} generado para {associate.full_name}"
                )
        except Exception as e:
            error_count += 1
            log_error(f"Error generando statement para {associate.user_id}: {e}")
    
    return {
        'success': success_count,
        'errors': error_count
    }

# Configurar scheduler
scheduler = BackgroundScheduler()

# Día 8 de cada mes a las 6:00 AM
scheduler.add_job(
    func=lambda: generate_all_statements_for_current_period(),
    trigger=CronTrigger(day=8, hour=6, minute=0),
    id='generate_statements_period_a'
)

# Día 23 de cada mes a las 6:00 AM
scheduler.add_job(
    func=lambda: generate_all_statements_for_current_period(),
    trigger=CronTrigger(day=23, hour=6, minute=0),
    id='generate_statements_period_b'
)

scheduler.start()
```

---

## ⚠️ Casos Especiales

### Caso 1: Asociado sin Pagos en el Periodo

```python
pending_payments = get_pending_payments_for_period(associate_id, cut_period_id)

if not pending_payments:
    # No generar statement
    return None
```

### Caso 2: Cliente con Múltiples Préstamos

```python
# Los préstamos se ordenan por client_id + loan_id
# El sufijo "PARTE UNO", "PARTE DOS" se agrega en el frontend
# basado en la cantidad de préstamos del mismo cliente

def add_loan_part_suffix(client_id: int, loans: List) -> List:
    client_loans = [l for l in loans if l.client_id == client_id]
    if len(client_loans) > 1:
        for idx, loan in enumerate(client_loans, start=1):
            loan.client_name_display = f"{loan.client_name} PARTE {number_to_word(idx)}"
    return loans
```

### Caso 3: Préstamo Liquidado Durante el Periodo

```python
# Solo incluir si el pago está PENDING u OVERDUE
# No incluir si ya está PAID
filter(PaymentSchedule.status.in_(['PENDING', 'OVERDUE']))
```

---

**Siguiente**: [04_APIS_REST.md](./04_APIS_REST.md)
