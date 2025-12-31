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
 * Genera CURP con dígito verificador aproximado
 * Nota: La homoclave real la asigna RENAPO, este es un cálculo aproximado
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

  // Mapeo de nombre de estado a código CURP
  const estadosPorNombre = {
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

  // Códigos válidos de estado (para cuando el valor ya viene como código)
  const codigosValidos = ['AS', 'BC', 'BS', 'CC', 'CL', 'CM', 'CS', 'CH', 'DF', 'DG',
    'GT', 'GR', 'HG', 'JC', 'MC', 'MN', 'MS', 'NT', 'NL', 'OC', 'PL', 'QT', 'QR',
    'SP', 'SL', 'SR', 'TC', 'TS', 'TL', 'VZ', 'YN', 'ZS', 'NE'];

  // Tabla para cálculo del dígito verificador
  const tablaValores = '0123456789ABCDEFGHIJKLMN&OPQRSTUVWXYZ';

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

  // Limpiar y normalizar nombres (quitar acentos)
  const normalizarTexto = (str) => {
    return str
      .toUpperCase()
      .trim()
      .normalize('NFD')
      .replace(/[\u0300-\u036f]/g, '')
      .replace(/Ñ/g, 'X'); // Ñ se maneja especialmente
  };

  // Obtener código de estado (puede venir como código o como nombre)
  const getCodigoEstado = (estado) => {
    const estadoUpper = estado.toUpperCase().trim();
    // Si ya es un código válido, usarlo directamente
    if (codigosValidos.includes(estadoUpper)) {
      return estadoUpper;
    }
    // Si no, buscar por nombre
    return estadosPorNombre[estadoUpper] || 'NE';
  };

  const sanitizedNombre = normalizarTexto(firstName);
  const sanitizedAP = normalizarTexto(paternalLastName);
  const sanitizedAM = normalizarTexto(maternalLastName || '');

  const fecha = new Date(birthDate + 'T00:00:00');
  const anio = fecha.getFullYear().toString().slice(-2);
  const mes = ('0' + (fecha.getMonth() + 1)).slice(-2);
  const dia = ('0' + fecha.getDate()).slice(-2);

  // Construir los primeros 16 caracteres
  let curp16 = '';
  curp16 += sanitizedAP.charAt(0);
  curp16 += getPrimeraVocalInterna(sanitizedAP);
  curp16 += (sanitizedAM ? sanitizedAM.charAt(0) : 'X');
  curp16 += sanitizedNombre.charAt(0);
  curp16 += anio + mes + dia;
  // H = Hombre, M = Mujer (estándar CURP)
  const genderUpper = gender.toUpperCase();
  const curpGender = (genderUpper === 'H' || genderUpper === 'HOMBRE' || genderUpper === 'MASCULINO') ? 'H' : 'M';
  curp16 += curpGender;
  curp16 += getCodigoEstado(birthState);
  curp16 += getPrimeraConsonanteInterna(sanitizedAP);
  curp16 += getPrimeraConsonanteInterna(sanitizedAM || 'X');
  curp16 += getPrimeraConsonanteInterna(sanitizedNombre);

  // Homoclave: Para nacidos antes del 2000 usa 0-9, después del 2000 usa A-Z
  // El primer dígito de homoclave lo asigna RENAPO, usamos '0' como default
  const yearFull = fecha.getFullYear();
  const homoclaveChar = yearFull < 2000 ? '0' : 'A';

  // Calcular dígito verificador usando el algoritmo oficial
  const curp17 = curp16 + homoclaveChar;
  let suma = 0;
  for (let i = 0; i < 17; i++) {
    const char = curp17.charAt(i);
    const valor = tablaValores.indexOf(char);
    suma += valor * (18 - i);
  }
  const residuo = suma % 10;
  const digitoVerificador = residuo === 0 ? 0 : (10 - residuo);

  return curp16 + homoclaveChar + digitoVerificador;
};
