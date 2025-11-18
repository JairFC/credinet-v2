# 📊 ANÁLISIS COMPLETO: SIMULADOR DE PRÉSTAMOS

## 🎯 Objetivo del Proyecto

Crear un **simulador completo de préstamos** en el frontend que permita a los administradores:
1. Ver una **tabla guía de referencia** con todos los valores precalculados
2. **Simular préstamos** con parámetros personalizados
3. Ver la **tabla de amortización** completa con fechas y períodos de corte
4. Visualizar un **resumen ejecutivo** con totales del cliente, asociado y comisiones

---

## 📋 REQUERIMIENTOS FUNCIONALES

### 1. Tabla Guía de Referencia (Reference Table)

**Propósito**: Mostrar valores precalculados para consulta rápida, similar a la tabla legacy.

**Características**:
- Mostrar todos los montos y plazos disponibles para un perfil
- Filtrar por perfil de tasa (transition, standard, premium, custom)
- Mostrar columnas:
  - Monto del préstamo
  - Plazo (quincenas)
  - **Pago quincenal del cliente** (lo que cobra el asociado)
  - **Pago quincenal del asociado** (lo que paga el asociado a CrediCuenta)
  - **Comisión por pago** (diferencia entre ambos)
  - **Total a pagar por el cliente**
  - **Total a pagar por el asociado**
  - **Comisión total**

**Datos desde**: 
- Base de datos: `rate_profile_reference_table` (336 registros precalculados)
- Vista: `v_rate_reference_complete` para consulta optimizada
- API Endpoint: `GET /api/v1/rate-profiles/reference?profile_code=standard`

**Componente Frontend**:
- `TablaReferenciaRapida.jsx`
- Filtros: Selector de perfil, selector de plazo (opcional)
- Ordenamiento: Por monto (asc/desc)
- Exportar a CSV/Excel (opcional)

---

### 2. Simulador Interactivo

**Propósito**: Permitir simulación con parámetros personalizados y ver resultados en tiempo real.

**Características**:
- **Formulario de entrada**:
  - Monto del préstamo (input numérico, validación: $3,000 - $30,000)
  - Plazo en quincenas (selector: 3, 6, 9, 12, 15, 18, 21, 24, 30, 36)
  - Perfil de tasa (selector: transition, standard, premium, custom)
  - Fecha de aprobación (date picker, default: hoy)
  - Si es custom: tasa de interés personalizada (input decimal)

- **Botón de simulación**: "Simular Préstamo"

- **Resultados instantáneos**:
  - Resumen ejecutivo (arriba)
  - Tabla de amortización (abajo)

**Validaciones**:
- Monto: múltiplo de 1000, rango $3k-$30k
- Plazo: debe estar en los términos válidos del perfil seleccionado
- Fecha: no puede ser pasada
- Tasa custom: entre 0.5% y 10%

**Datos desde**:
- API Endpoint: `POST /api/v1/simulator/simulate`
- Request body:
```json
{
  "amount": 25000,
  "term_biweeks": 12,
  "profile_code": "standard",
  "approval_date": "2025-11-15",
  "custom_interest_rate": null
}
```

**Componente Frontend**:
- `SimuladorPrestamos.jsx` (página principal)
- `FormularioSimulador.jsx` (formulario de inputs)
- `ResumenSimulacion.jsx` (resumen ejecutivo)
- `TablaAmortizacion.jsx` (tabla de pagos)

---

### 3. Tabla de Amortización

**Propósito**: Mostrar el desglose pago por pago con fechas reales y períodos de corte.

**Características**:
- **Columnas**:
  1. # Pago (1 a N)
  2. Fecha de pago (cada 15 días)
  3. Período de corte (ej: 2025-Q22)
  4. **Pago del cliente** (lo que cobra el asociado)
  5. **Pago del asociado** (lo que paga a CrediCuenta)
  6. **Comisión** (diferencia)
  7. **Saldo pendiente** (disminuye cada pago)

- **Totales al final**:
  - Total pagado por cliente
  - Total pagado por asociado
  - Comisión total

- **Visualización**:
  - Tabla responsiva con scroll horizontal si es necesario
  - Colores alternados por fila para facilitar lectura
  - Destacar primera y última fila
  - Mostrar fechas en formato DD/MM/YYYY
  - Mostrar montos en formato $X,XXX.XX

**Lógica de fechas** (CRÍTICO):
- Fecha inicial = `approval_date`
- Fechas de pago cada 15 días desde la fecha de aprobación
- Integración con tabla `cut_periods` para obtener el código de corte correcto
- Usar función de base de datos `simulate_loan()` que ya calcula fechas

**Datos desde**:
- Parte del response de `POST /api/v1/simulator/simulate`
- Campo: `amortization_table` (array de objetos)

**Componente Frontend**:
- `TablaAmortizacion.jsx`
- Props: `{ payments: Array<AmortizationRow> }`

---

### 4. Resumen Ejecutivo

**Propósito**: Mostrar información clave del préstamo simulado de forma clara y visual.

**Características**:
- **Sección 1: Información del préstamo**
  - Monto solicitado: $XX,XXX
  - Plazo: XX quincenas (XX meses)
  - Perfil de tasa: XXXXX
  - Tasa de interés: X.XX%
  - Comisión del asociado: XX%
  - Fecha de aprobación: DD/MM/YYYY
  - Fecha de finalización: DD/MM/YYYY

- **Sección 2: Totales del Cliente**
  - Pago quincenal: $X,XXX.XX
  - Total a pagar: $XX,XXX.XX
  - Total de intereses: $X,XXX.XX

- **Sección 3: Totales del Asociado**
  - Pago quincenal hacia CrediCuenta: $X,XXX.XX
  - Total a pagar a CrediCuenta: $XX,XXX.XX
  - Comisión total ganada: $X,XXX.XX

- **Sección 4: Visualización (opcional)**
  - Gráfico de barras: Cliente vs Asociado vs Comisión
  - Gráfico de pastel: Distribución de pagos

**Datos desde**:
- Parte del response de `POST /api/v1/simulator/simulate`
- Campo: `summary` (objeto)

**Componente Frontend**:
- `ResumenSimulacion.jsx`
- Props: `{ summary: LoanSummary }`

---

## 🏗️ ARQUITECTURA DEL SISTEMA

### Stack Tecnológico

**Backend**:
- FastAPI 0.104
- SQLAlchemy 2.0 (async)
- PostgreSQL 15
- Funciones SQL: `calculate_loan_payment()`, `simulate_loan()`

**Frontend**:
- React 18.2
- React Router 6
- Axios para HTTP
- CSS modules / styled-components

---

### Flujo de Datos

```
┌─────────────────────────────────────────────────────────────┐
│                    FRONTEND (React)                          │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  SimuladorPrestamosPage.jsx (Página principal)       │   │
│  │                                                       │   │
│  │  ┌────────────────────┐  ┌──────────────────────┐   │   │
│  │  │ TablaReferenciaRapida│  │ FormularioSimulador  │   │   │
│  │  │ (Valores precalc.)   │  │ (Inputs usuario)     │   │   │
│  │  └────────────────────┘  └──────────────────────┘   │   │
│  │                                                       │   │
│  │  ┌────────────────────┐  ┌──────────────────────┐   │   │
│  │  │ ResumenSimulacion  │  │ TablaAmortizacion    │   │   │
│  │  │ (Totales)          │  │ (Pago por pago)      │   │   │
│  │  └────────────────────┘  └──────────────────────┘   │   │
│  └──────────────────────────────────────────────────────┘   │
│                           │                                  │
│                           ▼                                  │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  simulatorService.js (API calls)                     │   │
│  └──────────────────────────────────────────────────────┘   │
└───────────────────────────┬──────────────────────────────────┘
                            │
                            │ HTTP Requests
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    BACKEND (FastAPI)                         │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  routes_simulator.py                                 │   │
│  │                                                       │   │
│  │  POST /api/v1/simulator/simulate                     │   │
│  │  GET  /api/v1/simulator/quick                        │   │
│  │  GET  /api/v1/rate-profiles/reference                │   │
│  └──────────────────────────────────────────────────────┘   │
│                           │                                  │
│                           ▼                                  │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  simulatorService (Business Logic)                   │   │
│  └──────────────────────────────────────────────────────┘   │
│                           │                                  │
│                           ▼                                  │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Database Functions (PostgreSQL)                     │   │
│  │                                                       │   │
│  │  - calculate_loan_payment(amount, term, profile)     │   │
│  │  - simulate_loan(amount, term, profile, date)        │   │
│  │  - rate_profile_reference_table                      │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

---

### Endpoints de API

#### 1. **POST /api/v1/simulator/simulate**

**Propósito**: Simular un préstamo completo con amortización y resumen.

**Request**:
```json
{
  "amount": 25000,
  "term_biweeks": 12,
  "profile_code": "standard",
  "approval_date": "2025-11-15",
  "custom_interest_rate": null
}
```

**Response**:
```json
{
  "success": true,
  "data": {
    "summary": {
      "loan_amount": 25000.00,
      "term_biweeks": 12,
      "term_months": 6,
      "profile_code": "standard",
      "profile_name": "Standard",
      "interest_rate_percent": 4.25,
      "commission_rate_percent": 12.00,
      "approval_date": "2025-11-15",
      "final_payment_date": "2026-05-14",
      
      "client_totals": {
        "biweekly_payment": 2604.17,
        "total_payment": 31250.00,
        "total_interest": 6250.00
      },
      
      "associate_totals": {
        "biweekly_payment": 2291.67,
        "total_payment": 27500.00,
        "total_commission": 3750.00
      }
    },
    
    "amortization_table": [
      {
        "payment_number": 1,
        "payment_date": "2025-11-30",
        "cut_period": "2025-Q22",
        "client_payment": 2604.17,
        "associate_payment": 2291.67,
        "commission": 312.50,
        "remaining_balance": 22395.83
      },
      {
        "payment_number": 2,
        "payment_date": "2025-12-15",
        "cut_period": "2025-Q23",
        "client_payment": 2604.17,
        "associate_payment": 2291.67,
        "commission": 312.50,
        "remaining_balance": 19791.66
      },
      // ... hasta payment_number: 12
    ]
  }
}
```

**Errores**:
- 400: Parámetros inválidos (monto fuera de rango, plazo no permitido)
- 404: Perfil de tasa no encontrado
- 500: Error en cálculo

---

#### 2. **GET /api/v1/simulator/quick**

**Propósito**: Obtener solo los totales sin tabla de amortización (más rápido).

**Query Parameters**:
- `amount` (required): Monto del préstamo
- `term_biweeks` (required): Plazo en quincenas
- `profile_code` (required): Código del perfil
- `custom_interest_rate` (optional): Tasa custom

**Response**:
```json
{
  "success": true,
  "data": {
    "client_biweekly_payment": 2604.17,
    "client_total_payment": 31250.00,
    "associate_biweekly_payment": 2291.67,
    "associate_total_payment": 27500.00,
    "commission_per_payment": 312.50,
    "total_commission": 3750.00
  }
}
```

---

#### 3. **GET /api/v1/rate-profiles/reference**

**Propósito**: Obtener tabla de referencia precalculada.

**Query Parameters**:
- `profile_code` (optional): Filtrar por perfil (transition, standard, premium)
- `term_biweeks` (optional): Filtrar por plazo

**Response**:
```json
{
  "success": true,
  "data": {
    "profile_code": "standard",
    "profile_name": "Standard",
    "interest_rate_percent": 4.25,
    "commission_rate_percent": 12.00,
    "reference_table": [
      {
        "amount": 3000,
        "term_biweeks": 3,
        "biweekly_payment": 1031.88,
        "total_payment": 3095.63,
        "commission_per_payment": 123.83,
        "total_commission": 371.48,
        "associate_payment": 908.05,
        "associate_total": 2724.16
      },
      // ... 139 más para standard
    ]
  }
}
```

---

## 🎨 DISEÑO DE COMPONENTES FRONTEND

### Estructura de Archivos

```
frontend-mvp/
└── src/
    └── features/
        └── loans/
            ├── pages/
            │   ├── LoansPage.jsx
            │   ├── LoanCreatePage.jsx
            │   ├── LoanDetailPage.jsx
            │   └── SimuladorPrestamosPage.jsx  ⭐ NUEVO
            │
            ├── components/
            │   ├── simulator/  ⭐ NUEVO
            │   │   ├── TablaReferenciaRapida.jsx
            │   │   ├── FormularioSimulador.jsx
            │   │   ├── ResumenSimulacion.jsx
            │   │   ├── TablaAmortizacion.jsx
            │   │   └── styles/
            │   │       ├── SimuladorPage.css
            │   │       ├── TablaReferencia.css
            │   │       └── TablaAmortizacion.css
            │   │
            │   └── (otros componentes existentes)
            │
            ├── hooks/
            │   └── useSimulator.js  ⭐ NUEVO
            │
            └── services/
                └── simulatorService.js  ⭐ NUEVO
```

---

### Componente 1: `SimuladorPrestamosPage.jsx`

**Responsabilidad**: Página principal que orquesta todos los sub-componentes.

**Estado local**:
```javascript
const [activeTab, setActiveTab] = useState('simulador'); // 'simulador' | 'referencia'
const [simulationResult, setSimulationResult] = useState(null);
const [loading, setLoading] = useState(false);
const [error, setError] = useState(null);
```

**Layout**:
```
┌────────────────────────────────────────────────────────┐
│  📊 Simulador de Préstamos                             │
├────────────────────────────────────────────────────────┤
│  [Simulador] [Tabla de Referencia]  ← Tabs            │
├────────────────────────────────────────────────────────┤
│                                                        │
│  ┌──────────────────────────────────────────────────┐ │
│  │  TAB 1: SIMULADOR                                │ │
│  │  ┌────────────────────────────────────────────┐  │ │
│  │  │  FormularioSimulador                       │  │ │
│  │  └────────────────────────────────────────────┘  │ │
│  │                                                  │ │
│  │  ┌────────────────────────────────────────────┐  │ │
│  │  │  ResumenSimulacion                         │  │ │
│  │  └────────────────────────────────────────────┘  │ │
│  │                                                  │ │
│  │  ┌────────────────────────────────────────────┐  │ │
│  │  │  TablaAmortizacion                         │  │ │
│  │  └────────────────────────────────────────────┘  │ │
│  └──────────────────────────────────────────────────┘ │
│                                                        │
│  ┌──────────────────────────────────────────────────┐ │
│  │  TAB 2: TABLA DE REFERENCIA                     │ │
│  │  ┌────────────────────────────────────────────┐  │ │
│  │  │  TablaReferenciaRapida                     │  │ │
│  │  │  (Valores precalculados)                   │  │ │
│  │  └────────────────────────────────────────────┘  │ │
│  └──────────────────────────────────────────────────┘ │
└────────────────────────────────────────────────────────┘
```

---

### Componente 2: `FormularioSimulador.jsx`

**Props**:
```javascript
{
  onSimulate: (params) => void,
  loading: boolean
}
```

**Estado interno**:
```javascript
const [formData, setFormData] = useState({
  amount: 10000,
  term_biweeks: 12,
  profile_code: 'standard',
  approval_date: new Date().toISOString().split('T')[0],
  custom_interest_rate: null
});

const [errors, setErrors] = useState({});
```

**Validaciones**:
- Monto: >= 3000, <= 30000, múltiplo de 1000
- Plazo: debe estar en términos válidos del perfil
- Fecha: no puede ser pasada
- Custom rate: si profile = custom, obligatorio entre 0.5 y 10

**UI**:
```
┌────────────────────────────────────────────────────┐
│  💰 Configurar Simulación                          │
├────────────────────────────────────────────────────┤
│                                                    │
│  Monto del Préstamo *                              │
│  [$________] (Rango: $3,000 - $30,000)             │
│                                                    │
│  Plazo *                                           │
│  [Seleccionar ▼] (3, 6, 9, 12... quincenas)        │
│                                                    │
│  Perfil de Tasa *                                  │
│  [Seleccionar ▼] (Transition, Standard, Premium)   │
│                                                    │
│  Fecha de Aprobación *                             │
│  [📅 DD/MM/YYYY]                                   │
│                                                    │
│  [Simular Préstamo] ← Botón                        │
└────────────────────────────────────────────────────┘
```

---

### Componente 3: `ResumenSimulacion.jsx`

**Props**:
```javascript
{
  summary: {
    loan_amount: number,
    term_biweeks: number,
    profile_name: string,
    interest_rate_percent: number,
    commission_rate_percent: number,
    approval_date: string,
    final_payment_date: string,
    client_totals: {...},
    associate_totals: {...}
  }
}
```

**UI**:
```
┌────────────────────────────────────────────────────┐
│  📋 Resumen del Préstamo                           │
├────────────────────────────────────────────────────┤
│                                                    │
│  ┌──────────────────┐  ┌──────────────────┐       │
│  │ INFORMACIÓN      │  │ TOTALES CLIENTE  │       │
│  │                  │  │                  │       │
│  │ Monto: $25,000   │  │ Pago quincenal:  │       │
│  │ Plazo: 12 quinc. │  │ $2,604.17        │       │
│  │ Perfil: Standard │  │                  │       │
│  │ Tasa: 4.25%      │  │ Total a pagar:   │       │
│  │ Comisión: 12%    │  │ $31,250.00       │       │
│  │                  │  │                  │       │
│  │ Inicio: 15/11/25 │  │ Intereses:       │       │
│  │ Final: 14/05/26  │  │ $6,250.00        │       │
│  └──────────────────┘  └──────────────────┘       │
│                                                    │
│  ┌──────────────────┐  ┌──────────────────┐       │
│  │ TOTALES ASOCIADO │  │ COMISIONES       │       │
│  │                  │  │                  │       │
│  │ Pago quincenal:  │  │ Por pago:        │       │
│  │ $2,291.67        │  │ $312.50          │       │
│  │                  │  │                  │       │
│  │ Total a pagar:   │  │ Total comisión:  │       │
│  │ $27,500.00       │  │ $3,750.00        │       │
│  └──────────────────┘  └──────────────────┘       │
└────────────────────────────────────────────────────┘
```

---

### Componente 4: `TablaAmortizacion.jsx`

**Props**:
```javascript
{
  payments: Array<{
    payment_number: number,
    payment_date: string,
    cut_period: string,
    client_payment: number,
    associate_payment: number,
    commission: number,
    remaining_balance: number
  }>
}
```

**UI**:
```
┌─────────────────────────────────────────────────────────────────┐
│  📅 Tabla de Amortización (12 pagos)                             │
├─────────────────────────────────────────────────────────────────┤
│ # │ Fecha      │ Corte    │ Cliente  │ Asociado │ Comisión │ Saldo    │
├───┼────────────┼──────────┼──────────┼──────────┼──────────┼──────────┤
│ 1 │ 30/11/2025 │ 2025-Q22 │ $2,604   │ $2,292   │ $313     │ $22,396  │
│ 2 │ 15/12/2025 │ 2025-Q23 │ $2,604   │ $2,292   │ $313     │ $19,792  │
│ 3 │ 30/12/2025 │ 2025-Q24 │ $2,604   │ $2,292   │ $313     │ $17,188  │
│...│ ...        │ ...      │ ...      │ ...      │ ...      │ ...      │
│12 │ 14/05/2026 │ 2026-Q09 │ $2,604   │ $2,292   │ $313     │ $0.00    │
├───┴────────────┴──────────┼──────────┼──────────┼──────────┼──────────┤
│                    TOTALES│ $31,250  │ $27,500  │ $3,750   │          │
└───────────────────────────┴──────────┴──────────┴──────────┴──────────┘
```

**Features**:
- Filas alternas con color de fondo (#f9f9f9)
- Primera y última fila destacadas (bold)
- Scroll horizontal si es necesario
- Totales en footer con fondo diferente
- Montos formateados con separador de miles

---

### Componente 5: `TablaReferenciaRapida.jsx`

**Props**: Ninguno (carga datos internamente)

**Estado interno**:
```javascript
const [profileCode, setProfileCode] = useState('standard');
const [referenceData, setReferenceData] = useState([]);
const [loading, setLoading] = useState(false);
```

**UI**:
```
┌─────────────────────────────────────────────────────────────────┐
│  📚 Tabla de Referencia Rápida                                   │
├─────────────────────────────────────────────────────────────────┤
│  Perfil: [Standard ▼]  Plazo: [Todos ▼]                         │
├─────────────────────────────────────────────────────────────────┤
│ Monto   │ Plazo │ Pago Cliente │ Pago Asociado │ Comisión │ Total Cliente │
├─────────┼───────┼──────────────┼───────────────┼──────────┼───────────────┤
│ $3,000  │ 3q    │ $1,032       │ $908          │ $124     │ $3,096        │
│ $3,000  │ 6q    │ $531         │ $468          │ $64      │ $3,191        │
│ $3,000  │ 9q    │ $365         │ $321          │ $44      │ $3,287        │
│ ...     │ ...   │ ...          │ ...           │ ...      │ ...           │
│ $30,000 │ 36q   │ $1,177       │ $1,036        │ $141     │ $42,375       │
└─────────┴───────┴──────────────┴───────────────┴──────────┴───────────────┘
```

**Features**:
- Filtrar por perfil (dropdown)
- Filtrar por plazo (opcional, dropdown multi-select)
- Ordenar por columna (click en header)
- Buscar por monto (input de búsqueda)
- Paginación (20 registros por página)

---

## 🔄 CUSTOM HOOK: `useSimulator.js`

**Propósito**: Centralizar la lógica de simulación y manejo de estado.

```javascript
import { useState } from 'react';
import { simulatorService } from '../services/simulatorService';

export const useSimulator = () => {
  const [simulationResult, setSimulationResult] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  const simulate = async (params) => {
    try {
      setLoading(true);
      setError(null);
      
      const result = await simulatorService.simulate(params);
      setSimulationResult(result);
      
      return result;
    } catch (err) {
      setError(err.response?.data?.detail || 'Error al simular préstamo');
      throw err;
    } finally {
      setLoading(false);
    }
  };

  const quickCalculate = async (params) => {
    try {
      setLoading(true);
      setError(null);
      
      const result = await simulatorService.quickCalculate(params);
      return result;
    } catch (err) {
      setError(err.response?.data?.detail || 'Error al calcular');
      throw err;
    } finally {
      setLoading(false);
    }
  };

  const reset = () => {
    setSimulationResult(null);
    setError(null);
  };

  return {
    simulationResult,
    loading,
    error,
    simulate,
    quickCalculate,
    reset
  };
};
```

---

## 📡 SERVICE LAYER: `simulatorService.js`

```javascript
import { apiClient } from '@/shared/api/apiClient';
import ENDPOINTS from '@/shared/api/endpoints';

export const simulatorService = {
  /**
   * Simular préstamo completo con amortización
   */
  async simulate(params) {
    const response = await apiClient.post(
      ENDPOINTS.simulator.simulate,
      params
    );
    return response.data.data;
  },

  /**
   * Cálculo rápido sin amortización
   */
  async quickCalculate(params) {
    const response = await apiClient.get(
      ENDPOINTS.simulator.quick,
      { params }
    );
    return response.data.data;
  },

  /**
   * Obtener tabla de referencia
   */
  async getReferenceTable(profileCode, termBiweeks = null) {
    const params = { profile_code: profileCode };
    if (termBiweeks) params.term_biweeks = termBiweeks;
    
    const response = await apiClient.get(
      ENDPOINTS.simulator.reference,
      { params }
    );
    return response.data.data;
  }
};
```

**Endpoints a agregar** en `/shared/api/endpoints.js`:
```javascript
simulator: {
  simulate: '/simulator/simulate',
  quick: '/simulator/quick',
  reference: '/rate-profiles/reference'
}
```

---

## 🗺️ ROUTING

**Agregar en** `/app/routes/index.jsx`:

```javascript
<Route
  path="/prestamos/simulador"
  element={
    <PrivateRoute>
      <MainLayout>
        <SimuladorPrestamosPage />
      </MainLayout>
    </PrivateRoute>
  }
/>
```

**Agregar en** Navbar (sidebar):
```javascript
{
  label: 'Simulador',
  path: '/prestamos/simulador',
  icon: '🧮'
}
```

---

## ✅ VALIDACIONES DE NEGOCIO

### Frontend Validations

1. **Monto**:
   - Mínimo: $3,000
   - Máximo: $30,000
   - Múltiplo de: $1,000
   - Mensaje: "El monto debe ser entre $3,000 y $30,000 en múltiplos de $1,000"

2. **Plazo**:
   - Valores permitidos dependen del perfil:
     - legacy: [12]
     - transition: [6, 12, 18, 24]
     - standard/premium: [3, 6, 9, 12, 15, 18, 21, 24, 30, 36]
     - custom: [1-52]
   - Mensaje: "El plazo seleccionado no está disponible para este perfil"

3. **Fecha de aprobación**:
   - No puede ser fecha pasada
   - Formato: YYYY-MM-DD
   - Mensaje: "La fecha de aprobación no puede ser anterior a hoy"

4. **Tasa custom**:
   - Solo si profile_code = 'custom'
   - Rango: 0.5% - 10%
   - Mensaje: "La tasa de interés debe estar entre 0.5% y 10%"

### Backend Validations (ya implementadas)

- Verificar que profile_code exista en rate_profiles
- Validar que term_biweeks esté en valid_terms del perfil
- Calcular fechas correctamente con cut_periods

---

## 🎯 CASOS DE USO

### Caso 1: Ver Tabla de Referencia

**Actor**: Administrador

**Flujo**:
1. Usuario navega a "Préstamos > Simulador"
2. Selecciona tab "Tabla de Referencia"
3. Selecciona perfil "Standard"
4. Sistema carga 140 registros de la tabla de referencia
5. Usuario ve todos los montos ($3k-$30k) con sus pagos
6. Usuario puede filtrar por plazo (ej: solo 12 quincenas)
7. Usuario puede buscar monto específico

**Resultado**: Usuario ve rápidamente cuánto cobraría/pagaría para cualquier combinación.

---

### Caso 2: Simular Préstamo Personalizado

**Actor**: Administrador

**Flujo**:
1. Usuario selecciona tab "Simulador"
2. Ingresa:
   - Monto: $18,500
   - Plazo: 15 quincenas
   - Perfil: Premium (4.5%)
   - Fecha: 01/12/2025
3. Click en "Simular Préstamo"
4. Sistema calcula:
   - Pago quincenal cliente: $1,632.64
   - Pago quincenal asociado: $1,436.72
   - Comisión por pago: $195.92
5. Sistema genera tabla de amortización con 15 filas
6. Usuario ve fechas cada 15 días desde 01/12/2025
7. Usuario ve períodos de corte correctos (2025-Q22, Q23, etc.)

**Resultado**: Usuario puede analizar préstamo específico no disponible en tabla de referencia.

---

### Caso 3: Comparar Perfiles

**Actor**: Administrador

**Flujo**:
1. Usuario simula con Standard (4.25%): Comisión total $3,750
2. Usuario cambia a Premium (4.5%): Comisión total $3,937.50
3. Usuario cambia a Transition (3.75%): Comisión total $3,562.50
4. Usuario compara y decide qué perfil ofrecer

**Resultado**: Usuario toma decisión informada sobre qué tasa aplicar.

---

## 🚧 CONSIDERACIONES TÉCNICAS

### Performance

1. **Tabla de Referencia**:
   - Usar paginación (20 registros por página)
   - Cargar datos al montar componente
   - Cachear en memoria (no recargar si cambia de tab)

2. **Simulación**:
   - Debounce en inputs numéricos (500ms)
   - Mostrar loader mientras calcula
   - Timeout de 10 segundos para API call

3. **Optimizaciones DB**:
   - Índices en rate_profile_reference_table (ya creados)
   - Función SQL `simulate_loan()` es eficiente (usa JOIN con cut_periods)

### Responsividad

- Desktop: 1200px+ → Mostrar todo side-by-side
- Tablet: 768px-1199px → Stack vertical (resumen arriba, tabla abajo)
- Mobile: <768px → Tabla con scroll horizontal

### Accesibilidad

- Labels correctos en formularios
- ARIA labels para botones
- Keyboard navigation
- Contraste de colores (WCAG AA)

---

## 📝 TAREAS DE IMPLEMENTACIÓN

### Backend (15 minutos)

- [x] Crear funciones SQL: `calculate_loan_payment()`, `simulate_loan()`
- [x] Crear tabla: `rate_profile_reference_table`
- [x] Crear archivo: `routes_simulator.py`
- [ ] Registrar router en `main.py`
- [ ] Agregar endpoint de referencia en `routes_rate_profiles.py`
- [ ] Probar endpoints con Postman

### Frontend (3-4 horas)

#### Fase 1: Setup (30 min)
- [ ] Crear carpeta `features/loans/components/simulator/`
- [ ] Crear `simulatorService.js`
- [ ] Crear `useSimulator.js` hook
- [ ] Agregar endpoints a `endpoints.js`
- [ ] Crear ruta en `routes/index.jsx`

#### Fase 2: Componentes Base (1 hora)
- [ ] `SimuladorPrestamosPage.jsx` (estructura con tabs)
- [ ] `FormularioSimulador.jsx` (formulario + validaciones)
- [ ] Estilos: `SimuladorPage.css`

#### Fase 3: Visualización (1.5 horas)
- [ ] `ResumenSimulacion.jsx` (cards de totales)
- [ ] `TablaAmortizacion.jsx` (tabla responsiva)
- [ ] `TablaReferenciaRapida.jsx` (tabla con filtros)
- [ ] Estilos: `TablaAmortizacion.css`, `TablaReferencia.css`

#### Fase 4: Integración (1 hora)
- [ ] Conectar formulario → API → resultados
- [ ] Manejo de errores y estados de carga
- [ ] Probar flujo completo
- [ ] Ajustes de UX

---

## 🎨 PALETA DE COLORES (Recomendada)

```css
/* Colores del sistema */
--primary-color: #007bff;      /* Azul principal */
--success-color: #28a745;      /* Verde (pagos) */
--warning-color: #ffc107;      /* Amarillo (alertas) */
--danger-color: #dc3545;       /* Rojo (errores) */
--info-color: #17a2b8;         /* Azul claro (info) */

/* Colores específicos del simulador */
--client-color: #007bff;       /* Azul para cliente */
--associate-color: #6c757d;    /* Gris para asociado */
--commission-color: #28a745;   /* Verde para comisiones */

/* Backgrounds */
--card-bg: #ffffff;
--table-header-bg: #f8f9fa;
--table-row-alt: #f9f9f9;
--table-footer-bg: #e9ecef;
```

---

## 🔮 MEJORAS FUTURAS (Fase 2)

1. **Gráficos**:
   - Chart.js o Recharts para visualizar distribución
   - Gráfico de pastel: Cliente vs Asociado vs Comisión
   - Gráfico de línea: Evolución del saldo

2. **Exportación**:
   - Exportar tabla de amortización a PDF
   - Exportar tabla de referencia a Excel
   - Compartir simulación por email

3. **Comparador**:
   - Comparar 2-3 simulaciones lado a lado
   - Guardar simulaciones favoritas

4. **Calculadora de Capacidad**:
   - Input: ingreso quincenal del cliente
   - Output: monto máximo que puede pagar

5. **Historial**:
   - Guardar simulaciones en localStorage
   - Ver últimas 10 simulaciones

---

## 📊 MÉTRICAS DE ÉXITO

1. **Funcionalidad**:
   - ✅ Simulación calcula correctamente (validar con casos de prueba)
   - ✅ Fechas coinciden con doble calendario
   - ✅ Totales cuadran (suma de pagos = total)

2. **Performance**:
   - ⏱️ Simulación completa < 2 segundos
   - ⏱️ Carga de tabla de referencia < 1 segundo
   - ⏱️ Interacción con formulario sin lag

3. **UX**:
   - 📱 Responsivo en mobile, tablet y desktop
   - ♿ Accesible (WCAG AA)
   - 🎨 Diseño consistente con el resto del sistema

---

## 🔐 PERMISOS Y ROLES

**Acceso al simulador**:
- ✅ Administradores: Full access
- ✅ Asociados: Solo ver tabla de referencia (opcional)
- ❌ Clientes: No tienen acceso

---

## 📚 DOCUMENTACIÓN RELACIONADA

- `DOCUMENTACION_RATE_PROFILES_v2.0.3.md` - Lógica de perfiles de tasa
- `ARQUITECTURA_DOBLE_CALENDARIO.md` - Sistema de cut_periods
- `LOGICA_DE_NEGOCIO_DEFINITIVA.md` - Reglas de cálculo
- `/db/v2.0/modules/10_rate_profiles.sql` - Funciones de cálculo
- `/db/v2.0/modules/12_loan_simulator.sql` - Funciones de simulación

---

## ✅ CHECKLIST FINAL ANTES DE IMPLEMENTAR

- [ ] Backend: Funciones SQL probadas y validadas
- [ ] Backend: Endpoints registrados y documentados
- [ ] Backend: DTOs definidos correctamente
- [ ] Frontend: Estructura de carpetas creada
- [ ] Frontend: Service layer configurado
- [ ] Frontend: Routing agregado
- [ ] Frontend: Componentes diseñados en papel/Figma
- [ ] Casos de prueba definidos
- [ ] Validaciones de negocio documentadas
- [ ] Paleta de colores y estilos definidos

---

**🎯 SIGUIENTE PASO**: Revisar este análisis con el usuario y obtener aprobación antes de comenzar la implementación.
