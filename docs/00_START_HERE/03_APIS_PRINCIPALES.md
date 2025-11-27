# 🌐 APIS PRINCIPALES

**Tiempo de lectura:** ~12 minutos  
**Prerequisito:** Haber leído `02_ARQUITECTURA_STACK.md`

---

## 📚 TABLA DE CONTENIDO

1. [Base URL y Autenticación](#base-url-y-autenticación)
2. [Módulo Auth](#módulo-auth)
3. [Módulo Loans](#módulo-loans)
4. [Módulo Rate Profiles](#módulo-rate-profiles)
5. [Módulo Catalogs](#módulo-catalogs)
6. [Códigos de Respuesta](#códigos-de-respuesta)
7. [Ejemplos Completos](#ejemplos-completos)

---

## 🔗 BASE URL Y AUTENTICACIÓN

### Base URL
```
http://localhost:8000/api/v1
```

### Documentación Interactiva
```
Swagger UI:  http://localhost:8000/docs
ReDoc:       http://localhost:8000/redoc
```

### Autenticación JWT

**Obtener token:**
```bash
POST /api/v1/auth/login
Content-Type: application/json

{
  "username": "admin",
  "password": "Sparrow20"
}

Response:
{
  "access_token": "eyJhbGciOiJIUzI1NiIs...",
  "token_type": "bearer"
}
```

**Usar token en requests:**
```bash
GET /api/v1/loans
Authorization: Bearer eyJhbGciOiJIUzI1NiIs...
```

---

## 🔐 MÓDULO AUTH

### 1. Login
```http
POST /api/v1/auth/login
Content-Type: application/json

Request:
{
  "username": "admin",
  "password": "Sparrow20"
}

Response 200:
{
  "access_token": "eyJhbGciOiJIUzI1NiIs...",
  "token_type": "bearer",
  "user": {
    "id": 1,
    "username": "admin",
    "email": "admin@credinet.com",
    "full_name": "Administrador",
    "role": "ADMIN"
  }
}

Response 401:
{
  "detail": "Incorrect username or password"
}
```

### 2. Get Current User
```http
GET /api/v1/auth/me
Authorization: Bearer {token}

Response 200:
{
  "id": 1,
  "username": "admin",
  "email": "admin@credinet.com",
  "full_name": "Administrador",
  "role": "ADMIN",
  "active": true,
  "created_at": "2025-01-01T00:00:00"
}
```

### 3. Register User (Admin only)
```http
POST /api/v1/auth/register
Authorization: Bearer {admin_token}
Content-Type: application/json

Request:
{
  "username": "juan",
  "email": "juan@credinet.com",
  "password": "SecurePass123",
  "full_name": "Juan Pérez",
  "role_id": 2
}

Response 201:
{
  "id": 5,
  "username": "juan",
  "email": "juan@credinet.com",
  "full_name": "Juan Pérez",
  "role": "ASOCIADO",
  "active": true,
  "created_at": "2025-11-05T10:30:00"
}
```

---

## 💰 MÓDULO LOANS

### 1. Listar Préstamos
```http
GET /api/v1/loans?status=PENDIENTE&limit=10&offset=0
Authorization: Bearer {token}

Response 200:
{
  "loans": [
    {
      "id": 5,
      "client_name": "María González",
      "amount": 22000.00,
      "term_biweeks": 12,
      "biweekly_payment": 2823.33,
      "total_payment": 33880.00,
      "total_interest": 11880.00,
      "total_commission": 6600.00,
      "status": "PENDIENTE",
      "profile_code": "standard",
      "interest_rate": 4.50,
      "commission_rate": 2.50,
      "requested_at": "2025-11-01T14:00:00",
      "requested_by": 3
    }
  ],
  "total": 1,
  "limit": 10,
  "offset": 0
}
```

### 2. Obtener Préstamo por ID
```http
GET /api/v1/loans/5
Authorization: Bearer {token}

Response 200:
{
  "id": 5,
  "client_name": "María González",
  "client_phone": "555-1234",
  "client_address": "Calle Principal 123",
  "amount": 22000.00,
  "term_biweeks": 12,
  "biweekly_payment": 2823.33,
  "total_payment": 33880.00,
  "total_interest": 11880.00,
  "total_commission": 6600.00,
  "insurance_fee": 50.00,
  "status": "PENDIENTE",
  "profile_code": "standard",
  "interest_rate": 4.50,
  "commission_rate": 2.50,
  "requested_at": "2025-11-01T14:00:00",
  "requested_by": 3,
  "approved_at": null,
  "approved_by": null,
  "first_payment_date": null
}
```

### 3. Crear Préstamo
```http
POST /api/v1/loans
Authorization: Bearer {token}
Content-Type: application/json

Request:
{
  "client_name": "Carlos Ramírez",
  "client_phone": "555-9876",
  "client_address": "Av. Libertad 456",
  "amount": 15000.00,
  "term_biweeks": 12,
  "profile_code": "standard",
  "requested_by": 3
}

Response 201:
{
  "id": 8,
  "client_name": "Carlos Ramírez",
  "amount": 15000.00,
  "term_biweeks": 12,
  "biweekly_payment": 1925.00,
  "total_payment": 23100.00,
  "total_interest": 8100.00,
  "total_commission": 4500.00,
  "status": "PENDIENTE",
  "profile_code": "standard",
  "interest_rate": 4.50,
  "commission_rate": 2.50,
  "requested_at": "2025-11-05T15:00:00",
  "requested_by": 3
}
```

### 4. Aprobar Préstamo
```http
POST /api/v1/loans/5/approve
Authorization: Bearer {admin_token}
Content-Type: application/json

Request:
{
  "associate_id": 2,
  "approved_by": 1,
  "disbursement_date": "2025-11-08"
}

Response 200:
{
  "id": 5,
  "status": "APROBADO",
  "approved_at": "2025-11-05T16:00:00",
  "approved_by": 1,
  "associate_id": 2,
  "first_payment_date": "2025-11-15",
  "payment_schedule": [
    {
      "payment_number": 1,
      "due_date": "2025-11-15",
      "client_payment": 2823.33,
      "associate_payment": 2273.33,
      "commission": 550.00,
      "insurance_fee": 50.00,
      "status": "PENDIENTE"
    },
    // ... 11 pagos más
  ]
}
```

### 5. Rechazar Préstamo
```http
POST /api/v1/loans/5/reject
Authorization: Bearer {admin_token}
Content-Type: application/json

Request:
{
  "rejection_reason": "Cliente no cumple requisitos de crédito",
  "rejected_by": 1
}

Response 200:
{
  "id": 5,
  "status": "RECHAZADO",
  "rejection_reason": "Cliente no cumple requisitos de crédito",
  "rejected_at": "2025-11-05T16:30:00",
  "rejected_by": 1
}
```

### 6. Obtener Payment Schedule
```http
GET /api/v1/loans/6/payment-schedule
Authorization: Bearer {token}

Response 200:
{
  "loan_id": 6,
  "total_payments": 12,
  "payments": [
    {
      "id": 46,
      "payment_number": 1,
      "due_date": "2025-11-15",
      "cut_period_id": 24,
      "client_payment": 2823.33,
      "associate_payment": 2273.33,
      "commission": 550.00,
      "insurance_fee": 50.00,
      "principal_amount": 1833.33,
      "interest_amount": 990.00,
      "status": "PENDIENTE",
      "paid_at": null,
      "paid_amount": null
    },
    // ... 11 pagos más
  ]
}
```

### 7. Registrar Pago
```http
POST /api/v1/loans/6/payments/46
Authorization: Bearer {token}
Content-Type: application/json

Request:
{
  "amount_paid": 2823.33,
  "payment_date": "2025-11-15",
  "payment_method": "TRANSFERENCIA",
  "notes": "Pago recibido completo"
}

Response 200:
{
  "id": 46,
  "payment_number": 1,
  "status": "PAGADO",
  "paid_at": "2025-11-15T10:00:00",
  "paid_amount": 2823.33,
  "payment_method": "TRANSFERENCIA",
  "notes": "Pago recibido completo"
}
```

---

## 💳 MÓDULO RATE PROFILES

### 1. Listar Perfiles de Tasa
```http
GET /api/v1/rate-profiles
Authorization: Bearer {token}

Response 200:
[
  {
    "code": "standard",
    "name": "Estándar",
    "description": "Perfil para clientes regulares",
    "interest_rate": 4.50,
    "commission_rate": 2.50,
    "min_amount": 3000.00,
    "max_amount": 50000.00,
    "is_active": true
  },
  {
    "code": "vip",
    "name": "VIP",
    "description": "Perfil para clientes preferenciales",
    "interest_rate": 4.00,
    "commission_rate": 2.00,
    "min_amount": 10000.00,
    "max_amount": 100000.00,
    "is_active": true
  }
]
```

### 2. Obtener Perfil por Código
```http
GET /api/v1/rate-profiles/standard
Authorization: Bearer {token}

Response 200:
{
  "code": "standard",
  "name": "Estándar",
  "description": "Perfil para clientes regulares",
  "interest_rate": 4.50,
  "commission_rate": 2.50,
  "min_amount": 3000.00,
  "max_amount": 50000.00,
  "is_active": true,
  "created_at": "2025-01-01T00:00:00",
  "updated_at": "2025-01-01T00:00:00"
}
```

### 3. Calcular Préstamo
```http
POST /api/v1/rate-profiles/calculate
Authorization: Bearer {token}
Content-Type: application/json

Request:
{
  "amount": 22000.00,
  "term_biweeks": 12,
  "profile_code": "standard"
}

Response 200:
{
  "amount": 22000.00,
  "term_biweeks": 12,
  "profile_code": "standard",
  "interest_rate": 4.50,
  "commission_rate": 2.50,
  "biweekly_payment": 2823.33,
  "total_payment": 33880.00,
  "total_interest": 11880.00,
  "total_commission": 6600.00,
  "interest_factor": 1.54,
  "calculation": {
    "principal_per_payment": 1833.33,
    "interest_per_payment": 990.00,
    "commission_per_payment": 550.00,
    "associate_payment": 2273.33
  }
}
```

---

## 📋 MÓDULO CATALOGS

### 1. Listar Estados de Préstamo
```http
GET /api/v1/catalogs/loan-statuses
Authorization: Bearer {token}

Response 200:
[
  {
    "id": 1,
    "code": "PENDIENTE",
    "name": "Pendiente de Aprobación",
    "description": "Solicitud en revisión"
  },
  {
    "id": 2,
    "code": "APROBADO",
    "name": "Aprobado",
    "description": "Préstamo aprobado y activo"
  },
  {
    "id": 3,
    "code": "RECHAZADO",
    "name": "Rechazado",
    "description": "Solicitud rechazada"
  },
  {
    "id": 4,
    "code": "LIQUIDADO",
    "name": "Liquidado",
    "description": "Préstamo completamente pagado"
  }
]
```

### 2. Listar Roles
```http
GET /api/v1/catalogs/roles
Authorization: Bearer {token}

Response 200:
[
  {
    "id": 1,
    "code": "ADMIN",
    "name": "Administrador",
    "description": "Acceso completo al sistema"
  },
  {
    "id": 2,
    "code": "ASOCIADO",
    "name": "Asociado",
    "description": "Gestión de sus préstamos"
  },
  {
    "id": 3,
    "code": "COBRADOR",
    "name": "Cobrador",
    "description": "Registrar pagos"
  }
]
```

---

## 📊 CÓDIGOS DE RESPUESTA

### Códigos de Éxito
```
200 OK                  - Operación exitosa
201 Created             - Recurso creado exitosamente
204 No Content          - Operación exitosa sin contenido
```

### Códigos de Error del Cliente
```
400 Bad Request         - Datos inválidos
401 Unauthorized        - Sin autenticación o token inválido
403 Forbidden           - Sin permisos suficientes
404 Not Found           - Recurso no encontrado
409 Conflict            - Conflicto (ej: duplicado)
422 Unprocessable       - Validación fallida
```

### Códigos de Error del Servidor
```
500 Internal Error      - Error del servidor
503 Service Unavailable - Servicio no disponible
```

### Formato de Error
```json
{
  "detail": "Descripción del error",
  "error_code": "LOAN_NOT_FOUND",
  "field": "loan_id",  // Opcional
  "value": 999         // Opcional
}
```

---

## 💡 EJEMPLOS COMPLETOS

### Ejemplo 1: Flujo Completo de Préstamo

```bash
# 1. Login
curl -X POST http://localhost:8000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "admin",
    "password": "Sparrow20"
  }'

# Respuesta: { "access_token": "eyJ..." }
TOKEN="eyJ..."

# 2. Crear préstamo
curl -X POST http://localhost:8000/api/v1/loans \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "client_name": "Ana López",
    "client_phone": "555-4321",
    "client_address": "Calle 5 #123",
    "amount": 18000.00,
    "term_biweeks": 12,
    "profile_code": "standard",
    "requested_by": 3
  }'

# Respuesta: { "id": 10, "status": "PENDIENTE", ... }

# 3. Aprobar préstamo
curl -X POST http://localhost:8000/api/v1/loans/10/approve \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "associate_id": 2,
    "approved_by": 1,
    "disbursement_date": "2025-11-08"
  }'

# Respuesta: { "status": "APROBADO", "first_payment_date": "2025-11-15", ... }

# 4. Ver payment schedule
curl -X GET http://localhost:8000/api/v1/loans/10/payment-schedule \
  -H "Authorization: Bearer $TOKEN"

# 5. Registrar primer pago
curl -X POST http://localhost:8000/api/v1/loans/10/payments/58 \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "amount_paid": 2308.50,
    "payment_date": "2025-11-15",
    "payment_method": "EFECTIVO"
  }'
```

### Ejemplo 2: Calcular Préstamo Antes de Crear

```bash
# Calcular diferentes escenarios
curl -X POST http://localhost:8000/api/v1/rate-profiles/calculate \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "amount": 30000.00,
    "term_biweeks": 12,
    "profile_code": "vip"
  }'

# Respuesta:
# {
#   "biweekly_payment": 3750.00,
#   "total_payment": 45000.00,
#   "total_interest": 15000.00,
#   "total_commission": 7500.00
# }

# Comparar con perfil standard
curl -X POST http://localhost:8000/api/v1/rate-profiles/calculate \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "amount": 30000.00,
    "term_biweeks": 12,
    "profile_code": "standard"
  }'

# Respuesta:
# {
#   "biweekly_payment": 3850.00,
#   "total_payment": 46200.00,
#   "total_interest": 16200.00,
#   "total_commission": 9000.00
# }
```

### Ejemplo 3: Python con requests

```python
import requests

BASE_URL = "http://localhost:8000/api/v1"

# Login
response = requests.post(
    f"{BASE_URL}/auth/login",
    json={"username": "admin", "password": "Sparrow20"}
)
token = response.json()["access_token"]

# Headers con autenticación
headers = {"Authorization": f"Bearer {token}"}

# Listar préstamos pendientes
loans = requests.get(
    f"{BASE_URL}/loans",
    params={"status": "PENDIENTE"},
    headers=headers
).json()

print(f"Préstamos pendientes: {loans['total']}")

# Aprobar cada préstamo
for loan in loans["loans"]:
    response = requests.post(
        f"{BASE_URL}/loans/{loan['id']}/approve",
        json={
            "associate_id": 2,
            "approved_by": 1,
            "disbursement_date": "2025-11-08"
        },
        headers=headers
    )
    print(f"Préstamo {loan['id']}: {response.json()['status']}")
```

---

## 🔗 REFERENCIAS

### Documentos Relacionados
- [`ARQUITECTURA_BACKEND_V2_DEFINITIVA.md`](../ARQUITECTURA_BACKEND_V2_DEFINITIVA.md) - Arquitectura
- [`EXPLICACION_DOS_TASAS.md`](../EXPLICACION_DOS_TASAS.md) - Sistema de tasas
- [`DOCUMENTACION_RATE_PROFILES_v2.0.3.md`](../DOCUMENTACION_RATE_PROFILES_v2.0.3.md) - Rate profiles

### Código
- Backend endpoints: `/backend/app/modules/*/presentation/routes.py`
- DTOs: `/backend/app/modules/*/application/dtos/`
- Tests de integración: `/backend/tests/`

### Herramientas
- Swagger UI: http://localhost:8000/docs
- Postman Collection: (pendiente de crear)

---

## ✅ VERIFICACIÓN DE COMPRENSIÓN

Antes de continuar, asegúrate de poder:

1. Hacer login y obtener un token JWT
2. Listar préstamos con filtros
3. Crear un préstamo nuevo
4. Aprobar un préstamo
5. Calcular un préstamo con rate profiles
6. Registrar un pago

---

**Siguiente:** [`04_FRONTEND_ESTRUCTURA.md`](./04_FRONTEND_ESTRUCTURA.md) - Estructura del frontend

**Tiempo total hasta ahora:** ~37 minutos
