# 🎯 Sistema de Selección Inteligente de Clientes y Asociados

## 📋 Descripción General

Se ha implementado un sistema completo de selección con búsqueda en tiempo real para clientes y asociados en el formulario de creación de préstamos, reemplazando los dropdowns simples por componentes inteligentes con validaciones automáticas.

---

## 🏗️ Arquitectura de la Solución

### Backend (FastAPI)

#### 1. **Endpoint: Búsqueda de Clientes Elegibles**
```
GET /api/v1/clients/search/eligible?q={término}&limit={n}
```

**Características:**
- ✅ Búsqueda por: nombre completo, username, email, teléfono
- ✅ Filtra solo clientes activos (role_id = 5)
- ✅ NO filtra por morosidad (se gestiona vía reportes administrativos)
- ✅ Retorna información financiera (préstamos activos)
- ✅ Optimizado con JOINs y agregaciones SQL

**Response DTO:**
```typescript
{
  id: number
  username: string
  full_name: string
  email: string
  phone_number: string
  active: boolean
  has_overdue_payments: boolean  // Siempre false (filtrado)
  total_debt: decimal
  active_loans: number
}
```

**Ejemplo de uso:**
```bash
GET /api/v1/clients/search/eligible?q=juan&limit=10
# Busca "juan" en nombre, username, email, teléfono
# Retorna máximo 10 clientes elegibles
```

---

#### 2. **Endpoint: Búsqueda de Asociados con Crédito**
```
GET /api/v1/associates/search/available?q={término}&min_credit={monto}&limit={n}
```

**Características:**
- ✅ Búsqueda por: nombre completo, username, email
- ✅ Filtra solo asociados activos
- ✅ Filtra por crédito disponible >= min_credit
- ✅ Ordena por crédito disponible (descendente)
- ✅ Muestra información completa de crédito

**Response DTO:**
```typescript
{
  id: number
  user_id: number
  username: string
  full_name: string
  email: string
  phone_number: string
  level_id: number
  credit_limit: decimal
  credit_used: decimal
  credit_available: decimal
  credit_usage_percentage: float
  active: boolean
  can_grant_loans: boolean
}
```

**Ejemplo de uso:**
```bash
GET /api/v1/associates/search/available?q=maria&min_credit=5000&limit=10
# Busca "maria" con al menos L.5,000 disponibles
# Útil para filtrar asociados según el monto del préstamo
```

---

### Frontend (React)

#### 1. **SearchableSelect** - Componente Reutilizable

**Ubicación:** `/frontend-mvp/src/shared/components/SearchableSelect/`

**Características:**
- ✅ Búsqueda con debounce (300ms por defecto)
- ✅ Mínimo de caracteres configurable (default: 2)
- ✅ Dropdown con scroll automático
- ✅ Renderizado personalizado de opciones
- ✅ Cierre automático al hacer clic fuera
- ✅ Estados: loading, empty, error
- ✅ Accesible (keyboard navigation ready)

**Props:**
```typescript
{
  value: object | null
  onChange: (option) => void
  onSearch: (term: string) => Promise<Array>
  renderOption?: (option) => ReactNode
  renderSelected?: (option) => ReactNode
  placeholder?: string
  minChars?: number
  debounceMs?: number
  disabled?: boolean
  error?: string
  helperText?: string
  loading?: boolean
}
```

**Ejemplo de uso:**
```jsx
<SearchableSelect
  value={selected}
  onChange={setSelected}
  onSearch={async (term) => {
    const response = await api.search(term);
    return response.data;
  }}
  renderOption={(item) => <div>{item.name}</div>}
  placeholder="Buscar..."
  minChars={3}
/>
```

---

#### 2. **ClientSelector** - Selector de Clientes

**Ubicación:** `/frontend-mvp/src/shared/components/ClientSelector/`

**Características:**
- ✅ Búsqueda en tiempo real (debounce 300ms)
- ✅ Muestra solo clientes elegibles (no morosos)
- ✅ Información rica: nombre, email, teléfono
- ✅ Badges: préstamos activos, estado de pagos
- ✅ Vista compacta cuando está seleccionado

**Renderizado de opciones:**
```
┌─────────────────────────────────────────┐
│ Juan Pérez                    @juanp   │
│ 📧 juan@example.com  📱 555-1234       │
│ [2 préstamos activos] [✓ Al corriente] │
└─────────────────────────────────────────┘
```

**Uso:**
```jsx
<ClientSelector
  value={selectedClient}
  onChange={setSelectedClient}
  error={errors.client}
  disabled={loading}
/>
```

---

#### 3. **AssociateSelector** - Selector de Asociados

**Ubicación:** `/frontend-mvp/src/shared/components/AssociateSelector/`

**Características:**
- ✅ Búsqueda con filtro dinámico por monto
- ✅ Visualización de crédito disponible
- ✅ Barra de progreso del uso de crédito
- ✅ Validación automática vs monto solicitado
- ✅ Códigos de color: verde (<70%), naranja (70-90%), rojo (>90%)
- ✅ Advertencia si crédito insuficiente

**Renderizado de opciones:**
```
┌──────────────────────────────────────────────────┐
│ María González                   @mariag         │
│ 📧 maria@example.com                             │
│                                                   │
│ Crédito usado                           45.2%    │
│ [████████░░░░░░░░░░░░]                           │
│ Usado: L.22,600.00  Disponible: L.27,400.00     │
│                                                   │
│ [Límite: L.50,000] [✓ Crédito suficiente]       │
└──────────────────────────────────────────────────┘
```

**Uso:**
```jsx
<AssociateSelector
  value={selectedAssociate}
  onChange={setSelectedAssociate}
  error={errors.associate}
  disabled={loading}
  requiredCredit={loanAmount}  // Filtra asociados con crédito suficiente
/>
```

---

## 🔄 Flujo de Trabajo

### 1. Selección de Cliente

```
Usuario escribe "juan" → (debounce 300ms) →
  Backend: GET /clients/search/eligible?q=juan →
    SQL: Busca en nombre, username, email, teléfono →
    Filtra: active=true AND no pagos vencidos →
    Retorna: Lista de clientes elegibles →
  Frontend: Renderiza opciones en dropdown →
Usuario selecciona → Cliente guardado en estado
```

### 2. Selección de Asociado

```
Usuario escribe "maria" →
Usuario ingresa monto: L.10,000 →
  Backend: GET /associates/search/available?q=maria&min_credit=10000 →
    SQL: Busca en nombre, username, email →
    Filtra: active=true AND credit_available >= 10000 →
    Ordena: credit_available DESC →
    Retorna: Asociados con crédito suficiente →
  Frontend: Muestra barra de crédito y validación →
Usuario selecciona → Asociado guardado en estado
```

### 3. Validación al Enviar

```javascript
validateForm() {
  // Validar cliente seleccionado
  if (!selectedClient) {
    errors.client = 'Debe seleccionar un cliente';
  }
  
  // Validar asociado seleccionado
  if (!selectedAssociate) {
    errors.associate = 'Debe seleccionar un asociado';
  }
  
  // Validar crédito suficiente
  if (amount > selectedAssociate.credit_available) {
    errors.associate = 'Crédito insuficiente';
  }
}
```

---

## 📊 Optimizaciones Implementadas

### Backend

1. **Query Optimizado con Agregaciones**
   - Usa `GROUP BY` para calcular préstamos activos
   - `HAVING` clause para filtrar morosos
   - Índices en: `user_id`, `status_id`, `due_date`

2. **Lazy Loading**
   - No carga todos los registros
   - Búsqueda bajo demanda (mínimo 2 caracteres)
   - Límite configurable de resultados

3. **Filtr os Inteligentes**
   - Clientes: Excluye morosos automáticamente
   - Asociados: Filtra por crédito disponible >= monto

### Frontend

1. **Debounce**
   - 300ms delay antes de buscar
   - Evita llamadas innecesarias al API
   - Cancela búsquedas pendientes

2. **Carga Bajo Demanda**
   - No carga datos al inicio
   - Búsqueda solo con >= 2 caracteres
   - Dropdown cierra automáticamente

3. **Validación en Tiempo Real**
   - Asociado valida crédito vs monto
   - Muestra advertencias visuales
   - Previene errores antes de enviar

---

## 🎨 Experiencia de Usuario

### Estados del Componente

| Estado | Mensaje | Acción |
|--------|---------|--------|
| **Inicial** | "Buscar cliente..." | Input vacío |
| **Escribiendo** | "Escribe al menos 2 caracteres" | < 2 chars |
| **Buscando** | "Buscando..." + spinner | Cargando |
| **Sin resultados** | "No se encontraron resultados" | Query vacío |
| **Con resultados** | Lista de opciones | Click para seleccionar |
| **Seleccionado** | Vista compacta + botón limpiar | Mostrar selección |
| **Error** | Mensaje de error en rojo | Validación fallida |

### Indicadores Visuales

- 🟢 Verde: Cliente al corriente / Crédito disponible
- 🟡 Naranja: Uso de crédito 70-90%
- 🔴 Rojo: Uso de crédito >90% / Crédito insuficiente
- 🔵 Azul: Información adicional (préstamos activos, límite)

---

## 🧪 Casos de Uso

### Caso 1: Cliente Sin Pagos Vencidos

```
Usuario busca: "Juan Pérez"
Backend retorna: 1 resultado
Frontend muestra:
  - ✓ Al corriente
  - 2 préstamos activos
  - Email y teléfono
Usuario selecciona → ✅ Procede
```

### Caso 2: Cliente Moroso

```
Usuario busca: "María González"
Backend: Cliente tiene pago vencido
Backend retorna: 0 resultados (filtrado)
Frontend muestra: "No se encontraron resultados"
Usuario: ❌ No puede seleccionar
```

### Caso 3: Asociado con Crédito Insuficiente

```
Usuario ingresa: Monto L.50,000
Usuario busca: "Pedro López"
Backend: Pedro tiene L.30,000 disponibles
Backend retorna: 0 resultados (min_credit=50000)
Frontend muestra: "No se encontraron resultados"
Usuario: ❌ No puede seleccionar

// O si búsqueda sin monto:
Frontend muestra: [⚠️ Crédito insuficiente]
Validación al enviar: "Crédito disponible menor al monto"
```

### Caso 4: Búsqueda Exitosa

```
Usuario busca: "Ana"
Backend retorna: 3 resultados
  1. Ana Martínez - L.50,000 disponibles
  2. Ana López - L.35,000 disponibles
  3. Ana García - L.20,000 disponibles
Frontend: Ordena por crédito disponible DESC
Usuario selecciona: Ana Martínez
Frontend: Muestra barra 40% usada (verde)
```

---

## 📝 Notas de Implementación

### Seguridad

- ✅ Solo clientes activos son elegibles
- ✅ Validación de pagos vencidos en SQL
- ✅ Validación de crédito en backend y frontend
- ✅ Sanitización de inputs (SQL injection prevention)

### Performance

- ✅ Índices en columnas de búsqueda
- ✅ LIMIT en queries para evitar sobrecarga
- ✅ Debounce para reducir llamadas al API
- ✅ Lazy loading (no carga datos al inicio)

### Accesibilidad

- ✅ Labels claros para lectores de pantalla
- ✅ Aria labels en botones
- ✅ Estados de carga visibles
- ✅ Mensajes de error descriptivos

### Mantenibilidad

- ✅ Componentes reutilizables
- ✅ Separación de responsabilidades
- ✅ DTOs bien definidos
- ✅ Documentación inline

---

## 🚀 Próximas Mejoras

### Fase 1 (Corto Plazo)
- [ ] Agregar cache de búsquedas recientes
- [ ] Implementar keyboard navigation (↑↓ Enter)
- [ ] Agregar historial de selecciones frecuentes

### Fase 2 (Mediano Plazo)
- [ ] Búsqueda fuzzy (tolerancia a errores de escritura)
- [ ] Filtros avanzados (por rango de crédito, nivel)
- [ ] Exportar lista de resultados

### Fase 3 (Largo Plazo)
- [ ] Machine learning para sugerencias inteligentes
- [ ] Análisis de patrones de selección
- [ ] Recomendaciones de asociado según historial

---

## 📚 Referencias

- **Backend DTOs:** `/backend/app/modules/clients/application/dtos/client_dto.py`
- **Backend Routes:** `/backend/app/modules/clients/routes.py`
- **Frontend Componentes:** `/frontend-mvp/src/shared/components/`
- **Página Principal:** `/frontend-mvp/src/features/loans/pages/LoanCreatePage.jsx`

---

**Última actualización:** 13 de Noviembre, 2025  
**Versión:** 2.0.0  
**Autor:** Sistema de IA GitHub Copilot
