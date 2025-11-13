# API de Códigos Postales - Sepomex (iCalialabs)

## ✅ Estado Actual: FUNCIONANDO

La aplicación está configurada para usar **API gratuita de Sepomex por iCalialabs** (https://sepomex.icalialabs.com).

### ✅ Ventajas

- **100% GRATUITA** - No requiere registro ni token
- **Datos reales** de SEPOMEX (Servicio Postal Mexicano)
- **Sin límite de consultas** (uso razonable)
- **Siempre actualizada** con el catálogo oficial

---

## Uso Actual

### Endpoint Principal
```
GET https://sepomex.icalialabs.com/api/v1/zip_codes?zip_code={CP}
```

### Ejemplo de Respuesta
```json
{
  "zip_codes": [
    {
      "d_codigo": "44100",
      "d_asenta": "Guadalajara Centro",
      "d_tipo_asenta": "Colonia",
      "d_mnpio": "Guadalajara",
      "d_estado": "Jalisco",
      "d_ciudad": "Guadalajara",
      "d_zona": "Urbano"
    }
  ]
}
```

### Campos Importantes

- `d_codigo`: Código postal (5 dígitos)
- `d_asenta`: Nombre de la colonia/asentamiento
- `d_tipo_asenta`: Tipo (Colonia, Fraccionamiento, etc.)
- `d_mnpio`: Municipio
- `d_estado`: Estado
- `d_ciudad`: Ciudad
- `d_zona`: Zona (Urbano/Rural)

---

## Implementación

### 1. Archivo de Servicio
**Ubicación:** `/frontend-mvp/src/shared/api/services/zipCodeService.js`

```javascript
const SEPOMEX_API_URL = 'https://sepomex.icalialabs.com/api/v1';

export const lookupZipCode = async (zipCode) => {
  const url = `${SEPOMEX_API_URL}/zip_codes?zip_code=${zipCode}`;
  const response = await fetch(url);
  const data = await response.json();
  
  return {
    zipCode: data.zip_codes[0].d_codigo,
    municipality: data.zip_codes[0].d_mnpio,
    state: data.zip_codes[0].d_estado,
    colonies: data.zip_codes.map(item => item.d_asenta),
    success: true
  };
};
```

### 2. Componente de Dirección
**Ubicación:** `/frontend-mvp/src/shared/components/forms/AddressSection.jsx`

- Auto-completa municipio y estado al ingresar CP
- Muestra lista de colonias disponibles
- Selección automática si solo hay una colonia

---

## Pruebas

### CPs de Ejemplo

```bash
# Guadalajara, Jalisco
curl "https://sepomex.icalialabs.com/api/v1/zip_codes?zip_code=44100"

# Ciudad de México, Juárez
curl "https://sepomex.icalialabs.com/api/v1/zip_codes?zip_code=06600"

# Monterrey, Nuevo León
curl "https://sepomex.icalialabs.com/api/v1/zip_codes?zip_code=64000"
```

---

## Manejo de Errores

### Errores Manejados

✅ **CP no encontrado:** Muestra mensaje "Código postal no encontrado"  
✅ **CP inválido:** No hace consulta si no son 5 dígitos  
✅ **Error de red:** Muestra mensaje con detalles del error  
✅ **Sin colonias:** Devuelve array vacío  

### Ejemplo de Error
```javascript
{
  error: true,
  message: 'Código postal no encontrado'
}
```

---

## Comportamiento en Producción

### Flujo Completo

1. **Usuario ingresa CP:** `44100`
2. **API consulta automáticamente** cuando tiene 5 dígitos
3. **Auto-completa campos:**
   - Municipio: `Guadalajara`
   - Estado: `Jalisco`
4. **Muestra colonias** en select
5. **Auto-selecciona** si solo hay una colonia

---

## Optimización (Opcional)

### Implementar Caché Local

Para reducir consultas repetidas:

```javascript
const cache = new Map();
const CACHE_DURATION = 24 * 60 * 60 * 1000; // 24 horas

export const lookupZipCode = async (zipCode) => {
  // Verificar caché
  if (cache.has(zipCode)) {
    const { data, timestamp } = cache.get(zipCode);
    if (Date.now() - timestamp < CACHE_DURATION) {
      return data;
    }
  }

  // Consultar API
  const result = await fetchFromAPI(zipCode);
  
  // Guardar en caché
  cache.set(zipCode, { 
    data: result, 
    timestamp: Date.now() 
  });
  
  return result;
};
```

---

## Alternativas

### Si esta API deja de funcionar:

1. **CopomexAPI** (https://api.copomex.com)
   - Requiere registro y pago
   - Datos más completos
   - Geocodificación disponible

2. **Base de Datos Local**
   - Descargar catálogo de SEPOMEX
   - Importar a PostgreSQL
   - 100% control y sin límites

3. **Implementar en Backend**
   - Proxy desde FastAPI
   - Caché en Redis
   - Control total

---

## Documentación

- **API oficial:** https://sepomex.icalialabs.com/
- **SEPOMEX:** https://www.correosdemexico.gob.mx/
- **Catálogo oficial:** https://www.correosdemexico.gob.mx/SSLServicios/ConsultaCP/CodigoPostal_Exportar.aspx

---

## Estado del Proyecto

✅ **API configurada y funcionando**  
✅ **Datos reales de SEPOMEX**  
✅ **Sin costos**  
✅ **Auto-completado activo**  
✅ **Manejo de errores implementado**  

**Última actualización:** 2025-11-12  
**Estado:** ✅ PRODUCCIÓN - API gratuita funcionando correctamente


## Estado Actual

La aplicación está configurada para usar **CopomexAPI** (https://api.copomex.com) para buscar información de códigos postales de México.

### ⚠️ PROBLEMA: Token de Pruebas Activo

**Actualmente la API está usando el token `'pruebas'` que devuelve datos ofuscados/aleatorios.**

Cuando usas el token de pruebas, la API responde con datos como:
```json
{
  "cp": "44100",
  "asentamiento": "vNTjxpxtSA",
  "municipio": "j0NHcIw7vhttWU",
  "estado": "hkgiw9Q2ScjjU"
}
```

En lugar de datos reales:
```json
{
  "cp": "44100",
  "asentamiento": ["Centro", "Analco"],
  "municipio": "Guadalajara",
  "estado": "Jalisco"
}
```

## Solución: Obtener Token Real

### Paso 1: Registrarse en CopomexAPI

1. Ir a https://api.copomex.com/panel
2. Crear una cuenta gratuita
3. Crear un proyecto
4. Comprar un paquete de créditos (cada consulta = 1 crédito)

### Paso 2: Configurar el Token

Editar el archivo: `/frontend-mvp/src/shared/api/services/zipCodeService.js`

```javascript
// Línea 11 - Cambiar esto:
const COPOMEX_TOKEN = 'pruebas';

// Por tu token real:
const COPOMEX_TOKEN = 'tu_token_aqui_1234567890';
```

### Paso 3: Verificar

Después de configurar el token real, probar con un CP conocido:

```bash
curl "https://api.copomex.com/query/info_cp/44100?type=simplified&token=TU_TOKEN_AQUI"
```

Deberías ver datos reales de Guadalajara, Jalisco.

## Paquetes Disponibles

Según la documentación de CopomexAPI:
- Debes adquirir créditos de consumo
- Cada petición consume 1 crédito
- Métodos de geocoding consumen 2 créditos

## Endpoints Usados

La aplicación usa los siguientes endpoints:

### 1. Información de CP (simplificado)
```
GET https://api.copomex.com/query/info_cp/{CP}?type=simplified&token={TOKEN}
```

**Respuesta:**
```json
{
  "error": false,
  "response": {
    "cp": "44100",
    "asentamiento": ["Centro", "Analco", "Mexicaltzingo"],
    "tipo_asentamiento": "Colonia",
    "municipio": "Guadalajara",
    "estado": "Jalisco",
    "ciudad": "Guadalajara",
    "pais": "México"
  }
}
```

### 2. Listado de Colonias por CP
```
GET https://api.copomex.com/query/get_colonia_por_cp/{CP}?token={TOKEN}
```

**Respuesta:**
```json
{
  "error": false,
  "response": {
    "colonia": [
      "Centro",
      "Analco",
      "Mexicaltzingo"
    ]
  }
}
```

## Alternativas Gratuitas

Si prefieres no pagar por créditos, hay alternativas:

### Opción 1: API Sepomex Alternativa
```javascript
// En zipCodeService.js
const API_URL = 'https://api-sepomex.hckdrk.mx/query';
```
**Nota:** Esta API puede estar inestable o discontinuada.

### Opción 2: Base de Datos Local
Descargar el catálogo oficial de SEPOMEX y crear una base de datos local:
- Fuente: https://www.correosdemexico.gob.mx/SSLServicios/ConsultaCP/CodigoPostal_Exportar.aspx
- Importar a PostgreSQL
- Crear endpoints en el backend

### Opción 3: Implementar en Backend
Crear un proxy en el backend de FastAPI que maneje la API:

```python
# backend/app/modules/addresses/routes.py
@router.get("/zip-codes/{zip_code}")
async def lookup_zip_code(zip_code: str):
    # Llamar a CopomexAPI desde el servidor
    # Cachear resultados para ahorrar créditos
    pass
```

**Ventajas:**
- Ocultar el token de la API
- Implementar caché para reducir consultas
- Controlar el uso de créditos

## Manejo de Errores Actual

El código ya maneja los siguientes casos:

✅ **Error de conexión:** Muestra mensaje de error
✅ **Token de pruebas:** Advierte que los datos son ofuscados
✅ **CP no encontrado:** Muestra mensaje específico
✅ **CP inválido:** No hace consulta si no son 5 dígitos

## Comportamiento en Producción

### Con Token de Pruebas (ACTUAL)
- ❌ Los usuarios verán datos sin sentido
- ❌ No podrán seleccionar colonias reales
- ⚠️ Aparece mensaje de advertencia en consola

### Con Token Real (RECOMENDADO)
- ✅ Auto-completa municipio y estado
- ✅ Muestra colonias reales del CP
- ✅ Selección única automática si solo hay una colonia
- ✅ Experiencia de usuario profesional

## Costos Estimados

Considerando el uso típico:

- **Registro de cliente:** 1 consulta por CP ingresado
- **Estimado:** 100 registros/mes = 100 créditos/mes
- **Recomendación:** Comprar paquete de 1,000 créditos para empezar

## Implementación de Caché (Recomendado)

Para optimizar el uso de créditos, implementar caché:

```javascript
// zipCodeService.js
const cache = new Map();
const CACHE_DURATION = 24 * 60 * 60 * 1000; // 24 horas

export const lookupZipCode = async (zipCode) => {
  // Verificar caché
  if (cache.has(zipCode)) {
    const { data, timestamp } = cache.get(zipCode);
    if (Date.now() - timestamp < CACHE_DURATION) {
      return data;
    }
  }

  // Consultar API
  const result = await fetch(/*...*/);
  
  // Guardar en caché
  cache.set(zipCode, { data: result, timestamp: Date.now() });
  
  return result;
};
```

## Contacto y Soporte

- **Documentación:** https://api.copomex.com/documentacion
- **Panel de control:** https://api.copomex.com/panel
- **Changelog:** Actualizado al 30 de julio de 2024

## TODO

- [ ] Registrarse en CopomexAPI
- [ ] Comprar paquete de créditos
- [ ] Configurar token real en `zipCodeService.js`
- [ ] Probar con CPs reales
- [ ] Implementar caché (opcional)
- [ ] Considerar mover la API al backend (opcional)
- [ ] Monitorear consumo de créditos

---

**Última actualización:** $(date)
**Estado:** ⚠️ Token de pruebas activo - REQUIERE CONFIGURACIÓN
