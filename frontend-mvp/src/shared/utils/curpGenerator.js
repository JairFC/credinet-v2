/**
 * Generador de CURP (Clave Única de Registro de Población)
 * Genera automáticamente el CURP basado en datos personales
 */

const vocales = 'AEIOU';
const consonantes = 'BCDFGHJKLMNPQRSTVWXYZ';

// Mapeo de códigos de estado para CURP
const estadosCodes = {
  'AS': 'AS', // Aguascalientes
  'BC': 'BC', // Baja California
  'BS': 'BS', // Baja California Sur
  'CC': 'CC', // Campeche
  'CS': 'CS', // Chiapas
  'CH': 'CH', // Chihuahua
  'CL': 'CL', // Coahuila
  'CM': 'CM', // Colima
  'DF': 'DF', // Ciudad de México
  'DG': 'DG', // Durango
  'GT': 'GT', // Guanajuato
  'GR': 'GR', // Guerrero
  'HG': 'HG', // Hidalgo
  'JC': 'JC', // Jalisco
  'MC': 'MC', // México
  'MN': 'MN', // Michoacán
  'MS': 'MS', // Morelos
  'NT': 'NT', // Nayarit
  'NL': 'NL', // Nuevo León
  'OC': 'OC', // Oaxaca
  'PL': 'PL', // Puebla
  'QT': 'QT', // Querétaro
  'QR': 'QR', // Quintana Roo
  'SP': 'SP', // San Luis Potosí
  'SL': 'SL', // Sinaloa
  'SR': 'SR', // Sonora
  'TC': 'TC', // Tabasco
  'TS': 'TS', // Tamaulipas
  'TL': 'TL', // Tlaxcala
  'VZ': 'VZ', // Veracruz
  'YN': 'YN', // Yucatán
  'ZS': 'ZS', // Zacatecas
  'NE': 'NE'  // Nacido en el Extranjero
};

/**
 * Obtiene la primera vocal interna de un string
 */
function getPrimeraVocalInterna(str) {
  if (!str || str.length < 2) return 'X';

  for (let i = 1; i < str.length; i++) {
    if (vocales.includes(str[i].toUpperCase())) {
      return str[i].toUpperCase();
    }
  }
  return 'X';
}

/**
 * Obtiene la primera consonante interna de un string
 */
function getPrimeraConsonanteInterna(str) {
  if (!str || str.length < 2) return 'X';

  for (let i = 1; i < str.length; i++) {
    if (consonantes.includes(str[i].toUpperCase())) {
      return str[i].toUpperCase();
    }
  }
  return 'X';
}

/**
 * Genera CURP automáticamente
 * @param {Object} params - Parámetros para generar CURP
 * @param {string} params.firstName - Nombre(s)
 * @param {string} params.paternalLastName - Apellido paterno
 * @param {string} params.maternalLastName - Apellido materno
 * @param {string} params.birthDate - Fecha de nacimiento (formato YYYY-MM-DD)
 * @param {string} params.gender - Género ('M' o 'F')
 * @param {string} params.birthState - Código del estado de nacimiento (2 letras)
 * @returns {string} CURP generado (18 caracteres)
 */
export const generateCURP = ({
  firstName,
  paternalLastName,
  maternalLastName,
  birthDate,
  gender,
  birthState
}) => {
  // Validar que tengamos todos los datos necesarios
  if (!firstName || !paternalLastName || !birthDate || !gender || !birthState) {
    return '';
  }

  try {
    // Sanitizar y convertir a mayúsculas
    const nombre = firstName.toUpperCase().trim();
    const apellidoP = paternalLastName.toUpperCase().trim();
    const apellidoM = (maternalLastName || '').toUpperCase().trim();

    // Extraer fecha
    const fecha = new Date(birthDate + 'T00:00:00');
    if (isNaN(fecha.getTime())) {
      return '';
    }

    const anio = fecha.getFullYear().toString().slice(-2);
    const mes = ('0' + (fecha.getMonth() + 1)).slice(-2);
    const dia = ('0' + fecha.getDate()).slice(-2);

    // Construir CURP
    let curp = '';

    // 1. Primera letra y primera vocal interna del apellido paterno
    curp += apellidoP.charAt(0);
    curp += getPrimeraVocalInterna(apellidoP);

    // 2. Primera letra del apellido materno (o X si no hay)
    curp += (apellidoM ? apellidoM.charAt(0) : 'X');

    // 3. Primera letra del nombre
    curp += nombre.charAt(0);

    // 4. Fecha de nacimiento (AAMMDD)
    curp += anio + mes + dia;

    // 5. Sexo (H o M)
    curp += (gender.toUpperCase() === 'M' ? 'H' : 'M'); // M=Masculino=H, F=Femenino=M

    // 6. Estado de nacimiento (2 letras)
    curp += (estadosCodes[birthState.toUpperCase()] || 'NE');

    // 7. Primera consonante interna de apellido paterno
    curp += getPrimeraConsonanteInterna(apellidoP);

    // 8. Primera consonante interna de apellido materno
    curp += getPrimeraConsonanteInterna(apellidoM);

    // 9. Primera consonante interna del nombre
    curp += getPrimeraConsonanteInterna(nombre);

    // 10. Homoclave (por ahora 00, se debería calcular)
    curp += '00';

    return curp.slice(0, 18);
  } catch (error) {
    console.error('Error generando CURP:', error);
    return '';
  }
};
