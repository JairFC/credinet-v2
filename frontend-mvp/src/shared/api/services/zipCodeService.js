/**
 * API Service para códigos postales de México
 * Integración con API GRATUITA de Sepomex por iCalialabs
 * Documentación: https://sepomex.icalialabs.com/
 * 
 * ✅ API GRATUITA - No requiere token ni registro
 * ✅ Datos reales de SEPOMEX (Servicio Postal Mexicano)
 */

const SEPOMEX_API_URL = 'https://sepomex.icalialabs.com/api/v1';

/**
 * Busca información de un código postal usando Sepomex API (iCalialabs)
 * @param {string} zipCode - Código postal (5 dígitos)
 * @returns {Promise<Object>} Información del CP o null
 */
export const lookupZipCode = async (zipCode) => {
  if (!zipCode || zipCode.length !== 5) {
    return null;
  }

  try {
    const url = `${SEPOMEX_API_URL}/zip_codes?zip_code=${zipCode}`;
    const response = await fetch(url);

    if (!response.ok) {
      console.error('Error fetching ZIP code:', response.status);
      return {
        error: true,
        message: `Error ${response.status}: No se pudo consultar el código postal`
      };
    }

    const data = await response.json();

    // Verificar si hay resultados
    if (!data.zip_codes || data.zip_codes.length === 0) {
      return {
        error: true,
        message: 'Código postal no encontrado'
      };
    }

    // La API devuelve un array de resultados (una entrada por colonia)
    // Tomamos el primer resultado para obtener municipio y estado
    const firstResult = data.zip_codes[0];

    // Extraer todas las colonias únicas
    const colonies = [...new Set(data.zip_codes.map(item => item.d_asenta))];

    return {
      zipCode: firstResult.d_codigo,
      municipality: firstResult.d_mnpio || '',
      state: firstResult.d_estado || '',
      city: firstResult.d_ciudad || '',
      colonies: colonies,
      type: firstResult.d_tipo_asenta || '',
      zone: firstResult.d_zona || '',
      success: true
    };
  } catch (error) {
    console.error('Error fetching ZIP code:', error);
    return {
      error: true,
      message: 'Error de conexión con la API',
      details: error.message
    };
  }
};

/**
 * Busca todas las colonias de un código postal
 * @param {string} zipCode - Código postal (5 dígitos)
 * @returns {Promise<Array>} Lista de colonias o array vacío
 */
export const getColonies = async (zipCode) => {
  if (!zipCode || zipCode.length !== 5) {
    return [];
  }

  try {
    const url = `${SEPOMEX_API_URL}/zip_codes?zip_code=${zipCode}`;
    const response = await fetch(url);

    if (!response.ok) {
      return [];
    }

    const data = await response.json();

    if (!data.zip_codes || data.zip_codes.length === 0) {
      return [];
    }

    // Extraer colonias únicas
    const colonies = [...new Set(data.zip_codes.map(item => item.d_asenta))];
    return colonies.filter(Boolean); // Remover valores nulos/undefined
  } catch (error) {
    console.error('Error fetching colonies:', error);
    return [];
  }
};

/**
 * Lista todos los estados de México con sus códigos
 * @returns {Array<{code: string, name: string}>} Estados con códigos
 */
export const getStates = () => {
  return [
    { code: 'AS', name: 'Aguascalientes' },
    { code: 'BC', name: 'Baja California' },
    { code: 'BS', name: 'Baja California Sur' },
    { code: 'CC', name: 'Campeche' },
    { code: 'CS', name: 'Chiapas' },
    { code: 'CH', name: 'Chihuahua' },
    { code: 'DF', name: 'Ciudad de México' },
    { code: 'CL', name: 'Coahuila' },
    { code: 'CM', name: 'Colima' },
    { code: 'DG', name: 'Durango' },
    { code: 'GT', name: 'Guanajuato' },
    { code: 'GR', name: 'Guerrero' },
    { code: 'HG', name: 'Hidalgo' },
    { code: 'JC', name: 'Jalisco' },
    { code: 'MC', name: 'México' },
    { code: 'MN', name: 'Michoacán' },
    { code: 'MS', name: 'Morelos' },
    { code: 'NT', name: 'Nayarit' },
    { code: 'NL', name: 'Nuevo León' },
    { code: 'OC', name: 'Oaxaca' },
    { code: 'PL', name: 'Puebla' },
    { code: 'QT', name: 'Querétaro' },
    { code: 'QR', name: 'Quintana Roo' },
    { code: 'SP', name: 'San Luis Potosí' },
    { code: 'SL', name: 'Sinaloa' },
    { code: 'SR', name: 'Sonora' },
    { code: 'TC', name: 'Tabasco' },
    { code: 'TS', name: 'Tamaulipas' },
    { code: 'TL', name: 'Tlaxcala' },
    { code: 'VZ', name: 'Veracruz' },
    { code: 'YN', name: 'Yucatán' },
    { code: 'ZS', name: 'Zacatecas' }
  ];
};

/**
 * Valida formato de código postal mexicano
 * @param {string} zipCode - Código postal
 * @returns {boolean} True si es válido
 */
export const isValidZipCode = (zipCode) => {
  if (!zipCode) return false;
  const cleaned = zipCode.replace(/\D/g, '');
  return cleaned.length === 5 && /^\d{5}$/.test(cleaned);
};
