# Componentes Reutilizables de Formularios - Implementación Completada

## 📋 Resumen

Se crearon **componentes reutilizables** para formularios de usuarios (clientes y asociados) con funcionalidades avanzadas:
- ✅ Auto-generación de credenciales (username, password basado en CURP, email temporal)
- ✅ Generación de CURP en tiempo real con verificación de homoclave
- ✅ Integración con CopomexAPI para códigos postales reales
- ✅ Validaciones en tiempo real (debounced)
- ✅ Formularios multi-sección colapsables

---

## 🗂️ Estructura de Archivos Creados

```
frontend-mvp/src/shared/
├── components/forms/
│   ├── PersonalDataSection.jsx    # Datos personales + CURP + credenciales
│   ├── AddressSection.jsx         # Dirección con API de CP
│   ├── GuarantorSection.jsx       # Datos del aval/garante
│   ├── BeneficiarySection.jsx     # Datos del beneficiario
│   └── index.js                   # Barrel export
├── utils/
│   └── credentialsGenerator.js    # ✏️ ACTUALIZADO: generatePassword() usa CURP
└── api/services/
    └── zipCodeService.js          # ✏️ ACTUALIZADO: CopomexAPI real
```

---

## 🆕 Componentes Creados

### 1. **PersonalDataSection.jsx**

Maneja todos los datos personales y credenciales del usuario.

**Props:**
- `formData` (object): Estado del formulario
- `onChange` (function): Callback para actualizar campos
- `showCredentials` (boolean): Mostrar/ocultar credenciales
- `autoGenerate` (boolean): Auto-generar credenciales
- `onAutoGenerateChange` (function): Toggle auto-generación

**Características:**
- ✅ **Generación de CURP en tiempo real** mientras el usuario escribe
- ✅ **Verificación de homoclave**: muestra los 16 primeros dígitos + input editable de 2 dígitos
- ✅ **Auto-generación de username**: `nombre.apellido` (sin acentos, máx 50 chars)
- ✅ **Password = CURP**: asigna automáticamente la CURP como contraseña
- ✅ **Email temporal**: `username@credinet.temp` si el usuario no ingresa uno
- ✅ **Validaciones en tiempo real**: username, email, phone, CURP
- ✅ **Manejo de duplicados**: botón "Generar alternativa" si el username ya existe

**Campos:**
- Nombre(s) *
- Apellido Paterno *
- Apellido Materno
- Fecha de Nacimiento *
- Género * (Masculino/Femenino)
- Estado de Nacimiento * (32 estados de México)
- Teléfono * (10 dígitos)
- Email (opcional)
- CURP (generado automáticamente)
- Usuario * (auto-generado)
- Contraseña * (auto-generada)

---

### 2. **AddressSection.jsx**

Sección de dirección con integración a CopomexAPI.

**Props:**
- `formData` (object)
- `onChange` (function)
- `required` (boolean): Si la dirección es obligatoria
- `collapsible` (boolean): Si se puede contraer la sección

**Características:**
- ✅ **Integración con CopomexAPI**: auto-completa municipio, estado y colonias al ingresar CP
- ✅ **Búsqueda automática**: se activa al completar 5 dígitos del código postal
- ✅ **Selector de colonias**: múltiples opciones si el CP tiene varias
- ✅ **Auto-selección**: si solo hay una colonia, se selecciona automáticamente
- ✅ **Indicador de carga**: spinner mientras busca el CP
- ✅ **Colapsable**: puede ocultarse si es opcional

**Campos:**
- Código Postal (5 dígitos)
- Colonia (selector dinámico)
- Municipio (auto-completado)
- Estado (auto-completado)
- Calle
- Número Exterior
- Número Interior (opcional)

---

### 3. **GuarantorSection.jsx**

Sección opcional para datos del aval/garante.

**Props:**
- `formData` (object)
- `onChange` (function)
- `collapsible` (boolean)

**Características:**
- ✅ **Opcional y colapsable**: botón "+ Agregar Aval/Garante"
- ✅ **Validación de CURP**: si se proporciona, valida en tiempo real
- ✅ **Dos formas de ingreso**: nombre completo O nombres separados
- ✅ **Indicador visual**: mensaje sobre que es opcional

**Campos:**
- Nombre Completo
- *O separados:*
  - Nombre(s)
  - Apellido Paterno
  - Apellido Materno
- Parentesco/Relación
- Teléfono
- CURP (opcional)

---

### 4. **BeneficiarySection.jsx**

Sección opcional para beneficiario.

**Props:**
- `formData` (object)
- `onChange` (function)
- `collapsible` (boolean)

**Características:**
- ✅ **Opcional y colapsable**: botón "+ Agregar Beneficiario"
- ✅ **Información clara**: tooltip explicando qué es un beneficiario

**Campos:**
- Nombre Completo
- Parentesco/Relación
- Teléfono

---

## 🔧 Utilidades Actualizadas

### **credentialsGenerator.js**

#### ❌ ANTES:
```javascript
generatePassword(firstName, lastName, birthDate) {
  return `${first}${last}${year}!`; // Ejemplo: "JuaPer2025!"
}
```

#### ✅ AHORA:
```javascript
generatePassword(curp) {
  if (curp && curp.length === 18) {
    return curp; // Usa la CURP como contraseña
  }
  return 'Temporal123!'; // Fallback si no hay CURP
}
```

**Funciones disponibles:**
- `generateUsername(firstName, lastName, counter)` → "nombre.apellido" o "nombre.apellido2"
- `generatePassword(curp)` → CURP completo (18 caracteres)
- `generateTempEmail(username)` → "username@credinet.temp"
- `generateCurp({firstName, paternalLastName, maternalLastName, birthDate, gender, birthState})` → CURP de 18 dígitos

---

### **zipCodeService.js**

#### ❌ ANTES:
```javascript
const CP_DATABASE = {
  '01000': { municipality: 'Álvaro Obregón', ... }
  // Solo 5 CPs hardcodeados
};
```

#### ✅ AHORA:
```javascript
const COPOMEX_API_URL = 'https://api.copomex.com/query';
const COPOMEX_TOKEN = 'pruebas'; // Token público

export const lookupZipCode = async (zipCode) => {
  const response = await fetch(`${COPOMEX_API_URL}/info_cp/${zipCode}?token=${COPOMEX_TOKEN}`);
  // Retorna datos reales de todos los CPs de México
};
```

**Funciones disponibles:**
- `lookupZipCode(zipCode)` → {zipCode, municipality, state, colonies[], city, type, zone, stateCode, success}
- `getColonies(zipCode)` → Array de colonias
- `getStates()` → Array de 32 estados mexicanos

---

## 📄 ClientCreatePage Refactorizado

El archivo `ClientCreatePage.jsx` fue completamente reescrito para usar los componentes nuevos:

### **Estructura del Formulario:**

```jsx
<form onSubmit={handleSubmit}>
  <PersonalDataSection 
    formData={formData} 
    onChange={handleFormChange}
    showCredentials={true}
    autoGenerate={autoGenerate}
    onAutoGenerateChange={setAutoGenerate}
  />
  
  <AddressSection 
    formData={formData} 
    onChange={handleFormChange}
    required={false}
    collapsible={true}
  />
  
  <GuarantorSection 
    formData={formData} 
    onChange={handleFormChange}
    collapsible={true}
  />
  
  <BeneficiarySection 
    formData={formData} 
    onChange={handleFormChange}
    collapsible={true}
  />
  
  <div className="form-actions">
    <Button variant="outline">Cancelar</Button>
    <Button type="submit">Crear Cliente</Button>
  </div>
</form>
```

### **Flujo de Creación:**

1. **Crear usuario** → POST `/api/v1/auth/register`
2. **Recibir `user_id`** del response
3. **Crear dirección** (si se llenó) → POST `/addresses`
4. **Crear aval** (si se llenó) → POST `/guarantors`
5. **Crear beneficiario** (si se llenó) → POST `/beneficiaries`
6. **Redirigir** a `/usuarios/clientes`

---

## 🎯 Validaciones Implementadas

### **En tiempo real (debounced 500ms):**
- ✅ Username (mínimo 4 caracteres, único)
- ✅ Email (formato válido, único)
- ✅ Teléfono (10 dígitos, único)
- ✅ CURP (18 caracteres, único)
- ✅ CURP del aval (si se proporciona, único)

### **Al enviar formulario:**
- ✅ Credenciales: username ≥ 4 chars, password ≥ 8 chars
- ✅ Datos personales: nombre, apellido paterno, fecha nacimiento, género, estado nacimiento
- ✅ Teléfono: exactamente 10 dígitos
- ✅ Email: formato válido (si se proporciona)

---

## 🚀 Próximos Pasos

### **Pendiente Backend:**
1. **Endpoints faltantes:**
   - `POST /api/v1/addresses` (crear dirección)
   - `POST /api/v1/guarantors` (crear aval)
   - `POST /api/v1/beneficiaries` (crear beneficiario)

2. **O alternativa: Endpoint compuesto:**
   - `POST /api/v1/users/complete` (crea user + address + guarantor + beneficiary en una transacción)

### **Aplicar a AssociateCreatePage:**
```jsx
<PersonalDataSection ... />
<AddressSection required={true} /> {/* Requerido para asociados */}
<GuarantorSection ... />
<BeneficiarySection ... />
<AssociateSpecificFields /> {/* credit_limit, commission_rate, etc. */}
```

---

## 📊 Comparación: Antes vs Ahora

| **Aspecto** | **Antes** | **Ahora** |
|------------|----------|-----------|
| **Generación CURP** | ❌ No existía | ✅ Tiempo real con homoclave editable |
| **Contraseña** | Basada en nombre | **Usa CURP completo** |
| **Email** | Obligatorio | **Opcional** (genera temp si vacío) |
| **Código Postal** | 5 CPs hardcodeados | **API real de México** (CopomexAPI) |
| **Validaciones** | Al enviar | **Tiempo real debounced** |
| **Estructura** | Formulario monolítico | **Componentes reutilizables** |
| **Secciones** | Todo junto | **Multi-sección colapsable** |
| **Dirección/Aval/Beneficiario** | No existía | **Completamente implementado** |
| **Reutilización** | 0% | **100% compartible con AssociateCreatePage** |

---

## 🧪 Testing

### **Probar generación automática:**
1. Ingresar nombre: "Juan"
2. Ingresar apellido paterno: "Pérez"
3. Ingresar apellido materno: "García"
4. Seleccionar fecha nacimiento: "1990-05-25"
5. Seleccionar género: "Masculino"
6. Seleccionar estado: "Jalisco"

**Resultado esperado:**
- CURP generado: `PEGJ900525HJCRRN` + homoclave editable (2 dígitos)
- Username: `juan.perez`
- Password: `PEGJ900525HJCRRN00` (la CURP completa)
- Email: `juan.perez@credinet.temp` (si no se ingresó uno)

### **Probar búsqueda de CP:**
1. Ingresar código postal: `44100`
2. Esperar spinner de carga
3. **Resultado:**
   - Municipio: "Guadalajara"
   - Estado: "Jalisco"
   - Colonias: [selector con múltiples opciones]

---

## 📞 Soporte

Si necesitas modificar algún componente:

```javascript
// Ejemplo: cambiar email temporal domain
// En credentialsGenerator.js
export const generateTempEmail = (username) => {
  return `${username}@tudominio.com`; // Cambiar aquí
};
```

```javascript
// Ejemplo: cambiar token de CopomexAPI
// En zipCodeService.js
const COPOMEX_TOKEN = 'tu_token_produccion'; // Cambiar aquí
```

---

## ✅ Checklist de Implementación

- [x] Crear PersonalDataSection con CURP en tiempo real
- [x] Crear AddressSection con CopomexAPI
- [x] Crear GuarantorSection colapsable
- [x] Crear BeneficiarySection colapsable
- [x] Actualizar generatePassword() para usar CURP
- [x] Integrar CopomexAPI real en zipCodeService
- [x] Refactorizar ClientCreatePage para usar componentes
- [x] Validaciones en tiempo real con useFieldValidation
- [x] Flujo de creación con múltiples endpoints
- [ ] Crear endpoints backend (/addresses, /guarantors, /beneficiaries)
- [ ] Aplicar mismo patrón a AssociateCreatePage
- [ ] Pruebas E2E con datos reales
- [ ] Cambiar COPOMEX_TOKEN a producción

---

**Fecha de implementación:** 2025-01-XX  
**Desarrollador:** GitHub Copilot  
**Versión:** v2.0
