/**
 * Utilidades para generación automática de credenciales
 */

/**
 * Genera username basado en nombre.apellido+contador
 * @param {string} firstName - Nombre
 * @param {string} lastName - Apellido
 * @param {number} counter - Contador para evitar duplicados
 * @returns {string} Username generado
 */
export const generateUsername = (firstName, lastName, counter = 1) => {
  if (!firstName || !lastName) return '';

  const cleanFirst = firstName.toLowerCase().trim().replace(/\s+/g, '');
  const cleanLast = lastName.toLowerCase().trim().replace(/\s+/g, '').split(' ')[0]; // Solo primer apellido

  const username = `${cleanFirst}.${cleanLast}${counter > 1 ? counter : ''}`;

  // Remover acentos
  return username
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .substring(0, 50); // Max 50 caracteres
};

/**
 * Genera contraseña basada en CURP pero que cumpla requisitos del backend
 * Requisitos: mínimo 8 caracteres, mayúscula, minúscula, número
 * @param {string} curp - CURP del usuario
 * @returns {string} Contraseña válida
 */
export const generatePassword = (curp) => {
  if (curp && curp.length === 18) {
    // Formato: Curp + primeros 6 dígitos + !
    // Ejemplo: FACJ251125MCHRRR04 -> Curp251125!
    const digits = curp.match(/\d+/g)?.join('').substring(0, 6) || '123456';
    return `Curp${digits}!`;
  }
  return 'Temporal123!'; // Contraseña temporal si no hay CURP
};

/**
 * Genera email temporal
 * @param {string} username - Username generado
 * @returns {string} Email temporal
 */
export const generateTempEmail = (username) => {
  if (!username) return '';
  return `${username}@credinet.temp`;
};

/**
 * Valida y formatea código postal
 * @param {string} zipCode - Código postal
 * @returns {string} Código postal formateado (5 dígitos)
 */
export const formatZipCode = (zipCode) => {
  if (!zipCode) return '';
  const cleaned = zipCode.replace(/\D/g, '');
  return cleaned.substring(0, 5);
};

/**
 * Valida formato de teléfono (10 dígitos)
 * @param {string} phone - Número telefónico
 * @returns {boolean} True si es válido
 */
export const isValidPhone = (phone) => {
  if (!phone) return false;
  const cleaned = phone.replace(/\D/g, '');
  return cleaned.length === 10;
};

/**
 * Genera CURP (simplificado)
 * Basado en el generador existente
 */
export const generateCurp = ({
  firstName,
  paternalLastName,
  maternalLastName,
  birthDate,
  gender,
  birthState
}) => {
  if (!firstName || !paternalLastName || !birthDate || !gender || !birthState) {
    return '';
  }

  const vocales = 'AEIOU';
  const consonantes = 'BCDFGHJKLMNPQRSTVWXYZ';

  const estados = {
    'AGUASCALIENTES': 'AS', 'BAJA CALIFORNIA': 'BC', 'BAJA CALIFORNIA SUR': 'BS',
    'CAMPECHE': 'CC', 'COAHUILA': 'CL', 'COLIMA': 'CM', 'CHIAPAS': 'CS',
    'CHIHUAHUA': 'CH', 'CIUDAD DE MEXICO': 'DF', 'DURANGO': 'DG',
    'GUANAJUATO': 'GT', 'GUERRERO': 'GR', 'HIDALGO': 'HG', 'JALISCO': 'JC',
    'MEXICO': 'MC', 'MICHOACAN': 'MN', 'MORELOS': 'MS', 'NAYARIT': 'NT',
    'NUEVO LEON': 'NL', 'OAXACA': 'OC', 'PUEBLA': 'PL', 'QUERETARO': 'QT',
    'QUINTANA ROO': 'QR', 'SAN LUIS POTOSI': 'SP', 'SINALOA': 'SL',
    'SONORA': 'SR', 'TABASCO': 'TC', 'TAMAULIPAS': 'TS', 'TLAXCALA': 'TL',
    'VERACRUZ': 'VZ', 'YUCATAN': 'YN', 'ZACATECAS': 'ZS'
  };

  const getPrimeraVocalInterna = (str) => {
    for (let i = 1; i < str.length; i++) {
      if (vocales.includes(str[i].toUpperCase())) {
        return str[i].toUpperCase();
      }
    }
    return 'X';
  };

  const getPrimeraConsonanteInterna = (str) => {
    for (let i = 1; i < str.length; i++) {
      if (consonantes.includes(str[i].toUpperCase())) {
        return str[i].toUpperCase();
      }
    }
    return 'X';
  };

  const sanitizedNombre = firstName.toUpperCase().trim();
  const sanitizedAP = paternalLastName.toUpperCase().trim();
  const sanitizedAM = (maternalLastName || '').toUpperCase().trim();

  const fecha = new Date(birthDate + 'T00:00:00');
  const anio = fecha.getFullYear().toString().slice(-2);
  const mes = ('0' + (fecha.getMonth() + 1)).slice(-2);
  const dia = ('0' + fecha.getDate()).slice(-2);

  let curp = '';
  curp += sanitizedAP.charAt(0);
  curp += getPrimeraVocalInterna(sanitizedAP);
  curp += (sanitizedAM ? sanitizedAM.charAt(0) : 'X');
  curp += sanitizedNombre.charAt(0);
  curp += anio + mes + dia;
  curp += (gender === 'H' || gender === 'HOMBRE' ? 'H' : 'M');
  curp += estados[birthState.toUpperCase()] || 'NE';
  curp += getPrimeraConsonanteInterna(sanitizedAP);
  curp += getPrimeraConsonanteInterna(sanitizedAM);
  curp += getPrimeraConsonanteInterna(sanitizedNombre);
  curp += '00';

  return curp.slice(0, 18);
};
