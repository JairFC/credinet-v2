# 📚 Documentación API - Módulo de Préstamos (Clean Architecture)

## 🎯 Endpoints Migrados a Clean Architecture

Esta documentación cubre los 5 endpoints migrados a Clean Architecture con sus respectivos Use Cases.

---

## 📋 1. Listar Préstamos Paginados

### `GET /loans/`

**Descripción:** Obtiene una lista paginada de préstamos con filtros opcionales.

**Use Case:** `ListLoansUseCase`

#### Parámetros Query

| Parámetro | Tipo | Requerido | Por defecto | Descripción |
|-----------|------|-----------|-------------|-------------|
| `page` | int | No | 1 | Número de página (≥1) |
| `limit` | int | No | 20 | Elementos por página (1-100) |
| `status` | string | No | - | Filtrar por estado |
| `client_id` | int | No | - | Filtrar por ID de cliente |
| `associate_id` | int | No | - | Filtrar por ID de asociado |

#### Respuesta Exitosa (200)

```json
{
  "success": true,
  "data": {
    "items": [
      {
        "loan_id": 1,
        "client_id": 123,
        "amount": 10000.00,
        "commission_rate": 0.05,
        "term_biweeks": 12,
        "status": "ACTIVE",
        "created_at": "2025-09-28",
        "approved_by": 456,
        "approval_date": "2025-09-27",
        "total_interest": 600.00,
        "total_to_pay": 10600.00
      }
    ],
    "total": 25,
    "page": 1,
    "limit": 20,
    "pages": 2
  }
}
```

#### Errores Comunes

- `400`: Parámetros de paginación inválidos
- `401`: No autenticado

---

## ⚡ 2. Activar Préstamo 

### `POST /loans/{loan_id}/activate`

**Descripción:** Activa un préstamo aprobado (equivalente a desembolso).

**Use Case:** `ActivateLoanUseCase`

**Permisos:** Solo administradores

#### Parámetros Path

| Parámetro | Tipo | Descripción |
|-----------|------|-------------|
| `loan_id` | int | ID del préstamo a activar |

#### Respuesta Exitosa (200)

```json
{
  "success": true,
  "data": {
    "message": "Préstamo 1 activado exitosamente",
    "loan_id": 1,
    "status": "ACTIVE",
    "activated_by": 456,
    "activated_at": "2025-09-28"
  }
}
```

#### Reglas de Negocio

- ✅ El préstamo debe estar en estado `APPROVED`
- ✅ Solo administradores pueden activar
- ✅ Se registra quién y cuándo activó

#### Errores Comunes

- `404`: Préstamo no encontrado
- `400`: Estado inválido para activación
- `403`: Sin permisos de administrador

---

## 📝 3. Regresar a Borrador

### `POST /loans/{loan_id}/return-to-draft`

**Descripción:** Regresa un préstamo a estado borrador para correcciones.

**Use Case:** `ReturnToDraftUseCase`

**Permisos:** Solo administradores

#### Parámetros Path

| Parámetro | Tipo | Descripción |
|-----------|------|-------------|
| `loan_id` | int | ID del préstamo a regresar |

#### Respuesta Exitosa (200)

```json
{
  "success": true,
  "data": {
    "loan_id": 1,
    "status": "DRAFT",
    "returned_by": 456,
    "returned_at": "2025-09-28"
  },
  "message": "Préstamo regresado a borrador para correcciones"
}
```

#### Reglas de Negocio

- ✅ Estados válidos: `PENDING`, `APPROVED`, `REJECTED`
- ✅ No se puede regresar préstamos `ACTIVE` o `COMPLETED`
- ✅ Se registra la auditoría completa

#### Errores Comunes

- `404`: Préstamo no encontrado
- `400`: Estado inválido para regreso
- `403`: Sin permisos de administrador

---

## 🚀 4. Enviar para Aprobación

### `POST /loans/{loan_id}/submit-for-approval`

**Descripción:** Envía un préstamo borrador para aprobación administrativa.

**Use Case:** `SubmitForApprovalUseCase`

**Permisos:** Cualquier usuario autenticado

#### Parámetros Path

| Parámetro | Tipo | Descripción |
|-----------|------|-------------|
| `loan_id` | int | ID del préstamo a enviar |

#### Respuesta Exitosa (200)

```json
{
  "success": true,
  "data": {
    "loan_id": 1,
    "status": "PENDING_APPROVAL",
    "submitted_by": 123,
    "submitted_at": "2025-09-28"
  },
  "message": "Préstamo enviado para aprobación exitosamente"
}
```

#### Reglas de Negocio

- ✅ El préstamo debe estar en estado `DRAFT`
- ✅ Cualquier usuario autenticado puede enviar
- ✅ Se registra quién envió y cuándo

#### Errores Comunes

- `404`: Préstamo no encontrado
- `400`: Solo préstamos DRAFT pueden enviarse
- `401`: No autenticado

---

## 🔧 5. Actualizar Estado Genérico

### `PUT /loans/{loan_id}/status`

**Descripción:** Actualiza el estado de un préstamo con validación de transiciones.

**Use Case:** `UpdateLoanStatusUseCase`

**Permisos:** Solo administradores

#### Parámetros Path

| Parámetro | Tipo | Descripción |
|-----------|------|-------------|
| `loan_id` | int | ID del préstamo a actualizar |

#### Cuerpo de la Petición

```json
{
  "status": "APPROVED"
}
```

#### Respuesta Exitosa (200)

```json
{
  "success": true,
  "data": {
    "loan_id": 1,
    "old_status": "PENDING_APPROVAL",
    "new_status": "APPROVED",
    "updated_by": 456,
    "updated_at": "2025-09-28"
  }
}
```

#### Estados Válidos y Transiciones

| Estado Actual | Transiciones Permitidas |
|---------------|-------------------------|
| `DRAFT` | `PENDING_APPROVAL`, `CANCELLED` |
| `PENDING_APPROVAL` | `APPROVED`, `REJECTED`, `DRAFT` |
| `APPROVED` | `ACTIVE`, `CANCELLED` |
| `REJECTED` | `DRAFT`, `CANCELLED` |
| `ACTIVE` | `COMPLETED`, `CANCELLED` |
| `COMPLETED` | *(Estado final)* |
| `CANCELLED` | *(Estado final)* |

#### Reglas de Negocio

- ✅ Validación estricta de transiciones de estado
- ✅ Auditoría completa de cambios
- ✅ Estados finales no pueden cambiarse

#### Errores Comunes

- `404`: Préstamo no encontrado
- `400`: Transición de estado inválida
- `400`: Estado no válido
- `403`: Sin permisos de administrador

---

## 🏗️ Arquitectura Clean

### Patrón de Use Cases

Todos los endpoints siguen el patrón:

```
HTTP Request → Controller → Use Case → Repository → Database
                    ↓           ↓
              DTO Request → Domain Logic → Entity Update
                    ↓           ↓
              DTO Response ← Business Rules ← Domain Entity
```

### Beneficios Obtenidos

1. **🧪 Testabilidad:** Lógica de negocio aislada
2. **🔄 Consistencia:** Patrón uniforme en todos los endpoints  
3. **🔧 Mantenibilidad:** Separación clara de responsabilidades
4. **📈 Escalabilidad:** Fácil extensión con nuevos Use Cases
5. **🔒 Validaciones:** Reglas de negocio centralizadas
6. **📋 Auditoría:** Tracking completo de cambios

### DTOs (Data Transfer Objects)

Cada Use Case tiene DTOs específicos:

- **Request DTOs:** Validación de entrada
- **Response DTOs:** Estructura de respuesta consistente
- **Inmutables:** `@dataclass(frozen=True)` para seguridad

### Manejo de Errores

Todos los Use Cases manejan errores de forma consistente:

- `ValueError`: Errores de validación de negocio
- `Exception`: Errores técnicos (base de datos, etc.)
- Logging estructurado para debugging
- Respuestas HTTP estándares

---

## 🚀 Próximos Pasos

1. **Monitoring:** Métricas y alertas por Use Case
2. **Performance:** Optimización de consultas
3. **Testing:** Tests de integración E2E
4. **Documentation:** OpenAPI/Swagger actualizado