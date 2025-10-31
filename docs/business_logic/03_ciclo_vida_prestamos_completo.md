# Módulo Crítico: Ciclo de Vida Completo de Préstamos

> **[MÓDULO CRÍTICO - ETAPA FINAL]**
> 
> Este documento especifica la implementación del sistema más complejo y crítico del proyecto Credinet: el ciclo de vida completo de préstamos con generación automática de contratos, cortes quincenales, relaciones de pago y documentación digital.

## 1. VISIÓN GENERAL DEL FLUJO

### 1.1. Flujo Principal del Ciclo de Vida

```
CREACIÓN DE PRÉSTAMO → CONTRATO DIGITAL → TABLA DE PAGOS → CORTES QUINCENALES → RELACIONES DE PAGO → DOCUMENTOS AUTOMÁTICOS
```

### 1.2. Entidades Principales Involucradas

- **Préstamo (Loan)**: Entidad central que desencadena todo el proceso
- **Contrato Digital (Contract)**: Documento legal automático vinculado al préstamo
- **Tabla de Pagos (Payment Schedule)**: Calendario completo de pagos del préstamo
- **Cortes Quincenales (Cut Periods)**: Períodos de facturación días 8 y 23
- **Relaciones de Pago (Payment Relations)**: Documentos para asociados por corte
- **Documentos Automáticos**: PDFs y reportes generados automáticamente

## 2. REGLAS DE NEGOCIO IRREFUTABLES

### 2.1. Fechas y Cortes - CRONOLOGÍA REAL

- **REGLA #1**: Los cortes se generan los días **8 y 23** de cada mes
- **REGLA #2**: **ASIGNACIÓN DE PRIMER PAGO**:
  - Préstamos creados **ANTES del día 8** → Su primer pago sale en el corte del **día 8**
  - Préstamos creados **del día 8 al 23** → Su primer pago sale en el corte del **día 23**
- **REGLA #3**: **FECHAS LÍMITE PARA CLIENTES**:
  - Corte día 8 → Clientes pagan hasta el **día 15**
  - Corte día 23 → Clientes pagan hasta el **día 30/31**
- **REGLA #4**: **FECHAS LÍMITE PARA ASOCIADAS LIQUIDAR**:
  - Relación del día 8 → Asociada liquida hasta el **día 22 del mismo mes** (antes del siguiente corte día 23)
  - Relación del día 23 → Asociada liquida hasta el **día 7 del mes siguiente** (antes del siguiente corte día 8)
- **REGLA #5**: **PENALIZACIÓN**: Si asociada no liquida a tiempo, se le descuenta **30% de comisión**

### 2.2. Nomenclatura de Cortes

**PROPUESTA**: Utilizaremos el formato `{YYYY}-Q{NN}` donde:
- `YYYY`: Año actual
- `Q`: Quincena
- `NN`: Número de quincena del año (01-24)

**Ejemplos**:
- `2025-Q01`: Primera quincena de enero (1-15 enero)
- `2025-Q02`: Segunda quincena de enero (16-31 enero)
- `2025-Q23`: Primera quincena de diciembre
- `2025-Q24`: Segunda quincena de diciembre

### 2.3. Generación Automática

- **REGLA #5**: Al crear un préstamo se debe generar automáticamente:
  1. Contrato digital firmable
  2. Tabla completa de pagos programados
  3. Documentos PDF del contrato
  4. Registro en sistema de documentos del cliente

- **REGLA #6**: En cada corte (días 8 y 23) se debe generar automáticamente:
  1. Relaciones de pago para cada asociado con clientes en ese corte
  2. Documentos PDF de las relaciones de pago
  3. Registro en sistema de documentos del asociado
  4. Cálculos de comisiones y totales

## 3. MAPA MENTAL DEL FLUJO COMPLETO

### 3.1. Fase 1: Creación de Préstamo
```
Usuario → Crear Préstamo → Validaciones → [AUTOMÁTICO] → Generar Contrato → Generar Tabla Pagos → Guardar Documentos
```

### 3.2. Fase 2: Activación de Préstamo
```
Contrato Firmado → Activar Préstamo → Status "ACTIVE" → Pagos Programados Activos
```

### 3.3. Fase 3: Cortes Automáticos (Días 8 y 23)
```
Día 8 → Generar Relación Corte 8 → Incluir TODOS los préstamos activos con pagos programados para esa fecha → Clientes pagan hasta día 15 → Asociadas liquidan hasta día 22 del mismo mes

Día 23 → Generar Relación Corte 23 → Incluir TODOS los préstamos activos con pagos programados para esa fecha → Clientes pagan hasta día 30/31 → Asociadas liquidan hasta día 7 del mes siguiente
```

### 3.3. Composición Real de Relaciones de Pago

**CONCEPTO CLAVE**: Las relaciones NO incluyen solo préstamos nuevos, sino **TODOS los pagos programados** para esa fecha:

- **Pago #1**: De préstamos creados en el período correspondiente
- **Pago #2, #3, #N**: De préstamos creados en períodos anteriores
- **Ejemplo**: Relación del 8 julio incluye:
  - Segundo pago del préstamo del 9 junio
  - Primer pago de préstamos creados 24 jun - 8 jul  
  - Quinto pago de préstamos más antiguos
  - **Cualquier pago** de cualquier préstamo activo programado para esa fecha

### 3.4. Fase 4: Gestión de Pagos
```
Registro de Pago → Actualizar Saldo → Verificar Estado → [Si Completado] → Finalizar Préstamo
```

## 4. DISEÑO DE CONTRATOS DIGITALES

### 4.1. Ejemplo de Contrato Base

```
CONTRATO DE PRÉSTAMO PERSONAL
No. de Contrato: {document_number}

ACREDITADO: {client_full_name}
DIRECCIÓN: {client_address}
TELÉFONO: {client_phone}
CURP: {client_curp}

ACREDITANTE: CrediCuenta S.A. de C.V.

CARACTERÍSTICAS DEL PRÉSTAMO:
- Monto: ${loan_amount} MXN
- Tasa de Interés: {interest_rate}% quincenal
- Plazo: {term_biweeks} quincenas
- Pago Quincenal: ${biweekly_payment} MXN

ASOCIADO ORIGINADOR:
{associate_name} - Comisión: {commission_rate}%

El acreditado se obliga a pagar las cantidades según la tabla de amortización adjunta.

Fecha de Inicio: {start_date}
Fecha de Firma: {sign_date}

[FIRMAS DIGITALES]
```

### 4.2. Campos Dinámicos del Contrato

- `document_number`: Generado automáticamente (formato: CONT-{YYYY}-{auto_increment})
- `client_*`: Datos extraídos del perfil del cliente
- `loan_*`: Características específicas del préstamo
- `associate_*`: Información del asociado originador
- `biweekly_payment`: Calculado automáticamente de la tabla de amortización quincenal

## 5. SISTEMA DE CORTES QUINCENALES

### 5.1. Estructura de Datos de Corte

```sql
-- Estructura optimizada para cut_periods
CREATE TABLE cut_periods (
    id SERIAL PRIMARY KEY,
    cut_code VARCHAR(10) UNIQUE NOT NULL,  -- Formato: 2025-Q01
    cut_number INTEGER NOT NULL,           -- 1-24
    period_start_date DATE NOT NULL,
    period_end_date DATE NOT NULL,
    client_payment_deadline DATE NOT NULL, -- Día 15 o último del mes
    associate_report_deadline DATE NOT NULL, -- Día 7 o 22
    status VARCHAR(20) DEFAULT 'PENDING',
    total_expected_payments NUMERIC(12,2) DEFAULT 0,
    total_received_payments NUMERIC(12,2) DEFAULT 0,
    total_commission NUMERIC(12,2) DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);
```

### 5.2. Generación Automática de Cortes

El sistema debe generar automáticamente los cortes del año:
- **Primer corte del mes**: Del 1 al 15, fecha límite día 15
- **Segundo corte del mes**: Del 16 al último día, fecha límite último día

## 6. RELACIONES DE PAGO PARA ASOCIADOS

### 6.1. Estructura de Relación de Pago

```sql
CREATE TABLE associate_payment_relations (
    id SERIAL PRIMARY KEY,
    cut_period_id INTEGER NOT NULL REFERENCES cut_periods(id),
    associate_user_id INTEGER NOT NULL REFERENCES users(id),
    relation_number VARCHAR(50) UNIQUE NOT NULL, -- REL-{cut_code}-{associate_id}
    total_clients INTEGER DEFAULT 0,
    total_amount_to_collect NUMERIC(12,2) DEFAULT 0,
    total_commission_earned NUMERIC(12,2) DEFAULT 0,
    document_path VARCHAR(500), -- PDF generado
    status VARCHAR(20) DEFAULT 'GENERATED',
    generated_date TIMESTAMP DEFAULT NOW(),
    due_date DATE NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);
```

### 6.2. Detalle de Pagos por Relación

```sql
CREATE TABLE payment_relation_details (
    id SERIAL PRIMARY KEY,
    payment_relation_id INTEGER NOT NULL REFERENCES associate_payment_relations(id),
    loan_id INTEGER NOT NULL REFERENCES loans(id),
    client_name VARCHAR(200) NOT NULL,
    scheduled_amount NUMERIC(12,2) NOT NULL,
    payment_due_date DATE NOT NULL,
    payment_status VARCHAR(20) DEFAULT 'PENDING',
    commission_amount NUMERIC(12,2) NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);
```

## 7. CALENDARIO DE IMPLEMENTACIÓN

### 7.1. Fase 1: Fundación (Sprint 1)
- [ ] Optimizar esquema de base de datos
- [ ] Crear nuevas tablas requeridas
- [ ] Implementar generación automática de contratos
- [ ] Crear plantillas de contratos

### 7.2. Fase 2: Cortes y Relaciones (Sprint 2)
- [ ] Implementar sistema de cortes quincenales
- [ ] Desarrollar generación de relaciones de pago
- [ ] Crear documentos PDF automáticos
- [ ] Integrar con sistema de documentos

### 7.3. Fase 3: Automatización (Sprint 3)
- [ ] Implementar triggers automáticos para cortes
- [ ] Crear notificaciones para asociados
- [ ] Desarrollar reportes y dashboards
- [ ] Pruebas integrales del flujo completo

## 8. OPORTUNIDADES DE MEJORA IDENTIFICADAS

### 8.1. Mejoras en la Base de Datos
- Separar la tabla de `payment_schedule` de `payments` para mayor claridad
- Añadir índices compuestos para consultas de cortes
- Implementar vistas materializadas para cálculos complejos

### 8.2. Mejoras en la Lógica de Negocio
- Sistema de notificaciones automáticas
- Dashboard en tiempo real para asociados
- Histórico de cambios en contratos
- Sistema de firmas electrónicas

### 8.3. Mejoras en la Experiencia de Usuario
- Vista previa de contratos antes de generar
- Descarga masiva de documentos
- Filtros avanzados por período y asociado
- Alertas de vencimientos próximos

## 9. SIGUIENTES PASOS INMEDIATOS

1. **Revisar y aprobar** este diseño conceptual
2. **Optimizar esquema** de base de datos con nuevas tablas
3. **Implementar generación** de contratos digitales
4. **Desarrollar lógica** de cortes quincenales
5. **Crear sistema** de relaciones de pago automáticas
6. **Integrar todo** en un flujo cohesivo y probado

---

**NOTA CRÍTICA**: Este módulo es la culminación del proyecto y debe ser implementado con la máxima atención al detalle, siguiendo todas las reglas de negocio especificadas y manteniendo la integridad de los datos en todo momento.