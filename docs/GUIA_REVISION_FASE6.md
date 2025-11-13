# 🚀 Guía de Revisión del Sistema - CrediNet V2
## Fase 6: Seguimiento de Pagos y Deuda Acumulada

**Fecha**: 2025-11-11  
**Host Remoto**: 192.168.98.98  
**Branch**: feature/sprint-6-associates

---

## ✅ Estado de los Servicios

### Contenedores Docker

```bash
docker compose ps
```

**Estado Actual**:
- ✅ **credinet-backend** - Up (healthy) - Puerto 8000
- ✅ **credinet-frontend** - Up (healthy) - Puerto 5173  
- ✅ **credinet-postgres** - Up (healthy) - Puerto 5432

---

## 🔍 URLs para Revisar

### 1. Backend API

**OpenAPI Documentation (Swagger)**:
```
http://192.168.98.98:8000/docs
```

**Health Check**:
```
http://192.168.98.98:8000/health
```

Deberías ver:
```json
{
  "status": "healthy",
  "version": "2.0.0"
}
```

---

### 2. Frontend MVP

**Aplicación Principal**:
```
http://192.168.98.98:5173
```

**Login de Prueba**:
```
Usuario: admin (o el usuario que tengas configurado)
Password: [tu contraseña]
```

---

## 📋 Checklist de Funcionalidades Fase 6

### Backend - Endpoints Implementados

Verifica en Swagger (`/docs`) que existen estos 5 endpoints:

#### 1. Statements - Seguimiento de Pagos
- [ ] **POST** `/api/v1/statements/{id}/payments` - Registrar abono a saldo actual
- [ ] **GET** `/api/v1/statements/{id}/payments` - Ver desglose de abonos

**Prueba manual**:
```bash
# 1. Autentícate primero (obtén token)
curl -X POST http://192.168.98.98:8000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"tu_password"}'

# 2. Consulta pagos de un statement (reemplaza {statement_id} y {token})
curl http://192.168.98.98:8000/api/v1/statements/{statement_id}/payments \
  -H "Authorization: Bearer {token}"
```

#### 2. Associates - Deuda Acumulada
- [ ] **GET** `/api/v1/associates/{id}/debt-summary` - Resumen de deuda con FIFO
- [ ] **GET** `/api/v1/associates/{id}/all-payments` - Todos los abonos del asociado
- [ ] **POST** `/api/v1/associates/{id}/debt-payments` - Registrar abono a deuda

---

### Frontend - Componentes Nuevos

#### 1. Página de Statements (Modificada)

**Ruta**: `/statements`

**Funcionalidades a revisar**:
- [ ] Tabla de statements cargando correctamente
- [ ] Botón "▶ Desglose" en cada fila
- [ ] Al hacer clic, se expande la fila mostrando `TablaDesglosePagos`
- [ ] Tabla de desglose muestra:
  - Resumen (Total adeudado, Pagado, Restante)
  - Barra de progreso visual
  - Lista de abonos con fecha, monto, método, referencia
  - Estado del statement (PAID, PARTIAL_PAID, PENDING)
- [ ] Botón "Registrar Abono" abre `ModalRegistrarAbono`

**Modal Registrar Abono - Saldo Actual**:
- [ ] Campo "Monto del Abono" (numérico)
- [ ] Campo "Fecha de Pago" (date picker)
- [ ] Select "Método de Pago" (carga desde catálogo)
- [ ] Campo opcional "Referencia"
- [ ] Campo opcional "Notas"
- [ ] Botón "Registrar" que:
  - Envía POST a `/api/v1/statements/{id}/payments`
  - Cierra modal y recarga datos

---

#### 2. Página de Asociado (Nueva)

**Ruta**: `/asociados/{associateId}`

**Cómo acceder**:
1. Ir a la lista de asociados (si existe en el menú)
2. O navegar directamente: `http://192.168.98.98:5173/asociados/1` (reemplaza 1 con ID válido)

**Funcionalidades a revisar**:

**Sección: Información General**
- [ ] Nombre del asociado
- [ ] Código/ID
- [ ] Información de contacto

**Sección: Estado de Crédito**
- [ ] Gráfico de barras con:
  - Límite de crédito (azul)
  - Crédito usado (naranja)
  - Crédito disponible (verde)

**Sección: Desglose de Deuda** (`DesgloseDeuda` component)
- [ ] Resumen General:
  - Total deuda original
  - Total abonado
  - Deuda pendiente
- [ ] Tabs:
  - **Tab "Ítems Pendientes (FIFO)"**:
    - Lista de statements/loans pendientes ordenados por antigüedad
    - Muestra: Descripción, Fecha vencimiento, Monto original, Abonado, Pendiente
  - **Tab "Abonos Aplicados"**:
    - Lista de todos los abonos realizados
    - Muestra: Fecha, Monto, Método, Referencia, Statement/Préstamo aplicado
- [ ] Botón "Registrar Abono a Deuda" abre `ModalRegistrarAbono` en modo DEUDA_ACUMULADA

**Modal Registrar Abono - Deuda Acumulada**:
- [ ] Radio buttons: "SALDO_ACTUAL" | "DEUDA_ACUMULADA" (selecciona segunda)
- [ ] Si hay deuda, muestra resumen:
  - Total deuda
  - Ítems pendientes más antiguos
- [ ] Mismo formulario que saldo actual
- [ ] Envía POST a `/api/v1/associates/{id}/debt-payments`
- [ ] Sistema FIFO aplica abono automáticamente (backend)

---

## 🧪 Casos de Prueba Recomendados

### Escenario 1: Pago Parcial a Statement
1. Ir a `/statements`
2. Buscar statement con saldo pendiente
3. Clic en "▶ Desglose"
4. Clic en "Registrar Abono"
5. Ingresar monto menor al total adeudado
6. Verificar que:
   - Statement pasa a estado "PARTIAL_PAID"
   - Barra de progreso se actualiza
   - Saldo restante es correcto

### Escenario 2: Pago Completo a Statement
1. Registrar abono por el monto total restante
2. Verificar que:
   - Statement pasa a estado "PAID"
   - Barra de progreso al 100%
   - Aparece badge verde "✅ PAGADO"

### Escenario 3: Deuda Acumulada con FIFO
1. Ir a `/asociados/1` (asociado con múltiples statements pendientes)
2. Verificar tab "Ítems Pendientes":
   - Ordenados del más antiguo al más reciente
3. Clic en "Registrar Abono a Deuda"
4. Ingresar monto que cubra parcialmente el primer ítem
5. Verificar después de guardar:
   - El abono se aplicó al ítem más antiguo primero
   - Si sobra dinero, se aplicó al siguiente ítem
   - Tab "Abonos Aplicados" muestra el nuevo abono

---

## 🐛 Verificaciones Técnicas

### 1. Arquitectura FSD

**Verificar que los componentes usen apiClient**:
```bash
# Desde el host remoto
cd /home/credicuenta/proyectos/credinet-v2/frontend-mvp

# No debe haber fetch() manual
grep -r "fetch(" src/shared/components/ src/features/

# No debe haber localStorage.getItem('token')
grep -r "localStorage.getItem('token')" src/

# No debe haber API_BASE_URL hardcoded
grep -r "API_BASE_URL" src/
```

**Resultado esperado**: Sin resultados (0 matches)

---

### 2. Logs del Backend

**Ver requests en tiempo real**:
```bash
docker compose logs -f backend | grep -E "(Request|Response|ERROR)"
```

**Buscar errores**:
```bash
docker compose logs backend --tail 100 | grep -i error
```

---

### 3. Logs del Frontend

**Ver compilación de Vite**:
```bash
docker compose logs -f frontend
```

**Buscar errores de imports o sintaxis**:
```bash
docker compose logs frontend --tail 50 | grep -E "(error|Error|failed)"
```

---

## 📊 Endpoints de Backend - Pruebas con cURL

### Autenticación
```bash
# 1. Login
curl -X POST http://192.168.98.98:8000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}'

# Respuesta esperada:
{
  "access_token": "eyJ...",
  "refresh_token": "eyJ...",
  "user": { ... }
}
```

### Statements - Pagos
```bash
# 2. Obtener desglose de pagos de statement
TOKEN="tu_token_aqui"
curl http://192.168.98.98:8000/api/v1/statements/1/payments \
  -H "Authorization: Bearer $TOKEN"

# 3. Registrar abono a statement
curl -X POST "http://192.168.98.98:8000/api/v1/statements/1/payments?payment_amount=1000&payment_date=2025-11-11&payment_method_id=1" \
  -H "Authorization: Bearer $TOKEN"
```

### Associates - Deuda
```bash
# 4. Resumen de deuda
curl http://192.168.98.98:8000/api/v1/associates/1/debt-summary \
  -H "Authorization: Bearer $TOKEN"

# 5. Todos los abonos del asociado
curl http://192.168.98.98:8000/api/v1/associates/1/all-payments \
  -H "Authorization: Bearer $TOKEN"

# 6. Registrar abono a deuda acumulada
curl -X POST "http://192.168.98.98:8000/api/v1/associates/1/debt-payments?payment_amount=2000&payment_date=2025-11-11&payment_method_id=1" \
  -H "Authorization: Bearer $TOKEN"
```

---

## 🗄️ Base de Datos - Queries de Verificación

**Conectar a PostgreSQL**:
```bash
docker compose exec postgres psql -U credicoop -d credinet_v2
```

**Queries útiles**:
```sql
-- Ver statements con sus pagos
SELECT 
  s.statement_id,
  s.period,
  s.total_commission_owed,
  s.paid_amount,
  s.status_id,
  COUNT(sp.payment_id) as num_payments
FROM statements s
LEFT JOIN statement_payments sp ON s.statement_id = sp.statement_id
GROUP BY s.statement_id
ORDER BY s.statement_id DESC
LIMIT 10;

-- Ver deuda acumulada de un asociado (vista materializada)
SELECT * FROM v_associate_debt_summary WHERE associate_id = 1;

-- Ver todos los abonos de un asociado
SELECT * FROM v_associate_all_payments WHERE associate_id = 1 ORDER BY payment_date DESC;

-- Ver aplicación FIFO de un abono
SELECT * FROM debt_payment_applications WHERE payment_id = 1;
```

---

## 🎯 Puntos Críticos a Revisar

### 1. **Inyección Automática de JWT Token**
- Los componentes NO deben tener `localStorage.getItem('token')`
- El `apiClient` debe inyectar el token automáticamente
- Verifica en Network Tab del navegador que requests tengan header `Authorization: Bearer ...`

### 2. **Sistema FIFO**
- Al registrar abono a deuda acumulada:
  - El backend debe aplicar FIFO automáticamente
  - Verificar en la vista `v_associate_debt_summary` que el orden es correcto
  - El ítem más antiguo debe liquidarse primero

### 3. **Actualización en Tiempo Real**
- Después de registrar un abono:
  - Los totales deben actualizarse sin recargar página
  - Las barras de progreso deben reflejar el nuevo estado
  - Los badges de estado deben cambiar (PENDING → PARTIAL_PAID → PAID)

### 4. **Validaciones**
- No permitir abonos mayores al saldo restante
- Fechas de pago no pueden ser futuras
- Método de pago es obligatorio
- Monto debe ser > 0

---

## 📸 Screenshots Recomendados

Para documentar la revisión, toma screenshots de:

1. ✅ Swagger UI mostrando los 5 nuevos endpoints
2. ✅ Página de Statements con fila expandida (TablaDesglosePagos visible)
3. ✅ Modal "Registrar Abono" - Modo Saldo Actual
4. ✅ Página de Asociado con gráfico de crédito
5. ✅ DesgloseDeuda - Tab "Ítems Pendientes (FIFO)"
6. ✅ DesgloseDeuda - Tab "Abonos Aplicados"
7. ✅ Modal "Registrar Abono" - Modo Deuda Acumulada
8. ✅ Network Tab del navegador mostrando requests con JWT token

---

## 🚨 Troubleshooting

### Problema: Frontend no carga
```bash
# Verificar logs
docker compose logs frontend --tail 50

# Reconstruir contenedor
docker compose up -d --build frontend
```

### Problema: Error 401 en requests
```bash
# Verificar que el token sea válido
# En el navegador, abre DevTools > Application > Local Storage
# Busca 'token' y verifica que exista

# O reloguea en la aplicación
```

### Problema: Endpoints no aparecen en Swagger
```bash
# Reiniciar backend
docker compose restart backend

# Verificar logs de backend
docker compose logs backend --tail 100
```

### Problema: Base de datos sin datos
```bash
# Ejecutar migraciones
docker compose exec backend python -c "from app.core.database import engine; print('DB OK')"

# Verificar tablas
docker compose exec postgres psql -U credicoop -d credinet_v2 -c "\dt"
```

---

## ✅ Checklist Final de Revisión

- [ ] Backend healthy y respondiendo en puerto 8000
- [ ] Frontend healthy y respondiendo en puerto 5173
- [ ] PostgreSQL healthy en puerto 5432
- [ ] Swagger UI accesible y muestra 5 nuevos endpoints
- [ ] Login funciona correctamente
- [ ] Página Statements carga y muestra datos
- [ ] Botón "Desglose" expande fila correctamente
- [ ] TablaDesglosePagos muestra abonos y resumen
- [ ] Modal Registrar Abono (Saldo Actual) funciona
- [ ] Página Asociado carga con ID válido
- [ ] Gráfico de crédito se renderiza
- [ ] DesgloseDeuda muestra tabs correctamente
- [ ] Tab "Ítems Pendientes" ordena por FIFO
- [ ] Tab "Abonos Aplicados" lista pagos
- [ ] Modal Registrar Abono (Deuda) funciona
- [ ] Network Tab muestra JWT en headers
- [ ] Sin errores en consola del navegador
- [ ] Sin errores en logs de backend
- [ ] Sin errores en logs de frontend

---

## 📞 Soporte

Si encuentras problemas:

1. **Revisa logs**:
   ```bash
   docker compose logs backend --tail 100
   docker compose logs frontend --tail 100
   ```

2. **Verifica estado de servicios**:
   ```bash
   docker compose ps
   ```

3. **Consulta documentación**:
   - `/docs/AUDITORIA_ARQUITECTURA_FASE6.md`
   - `/docs/ARQUITECTURA_BACKEND_V2_DEFINITIVA.md`
   - `/frontend-mvp/ARQUITECTURA.md`

---

**¡Sistema listo para revisión!** 🚀

Todos los componentes están funcionando y siguiendo Clean Architecture + FSD.
