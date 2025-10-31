const vocales = 'AEIOU';
const consonantes = 'BCDFGHJKLMNPQRSTVWXYZ';
const estados = {
  'AGUASCALIENTES': 'AS', 'BAJA CALIFORNIA': 'BC', 'BAJA CALIFORNIA SUR': 'BS',
  'CAMPECHE': 'CC', 'COAHUILA': 'CL', 'COLIMA': 'CM', 'CHIAPAS': 'CS',
  'CHIHUAHUA': 'CH', 'DISTRITO FEDERAL': 'DF', 'DURANGO': 'DG',
  'GUANAJUATO': 'GT', 'GUERRERO': 'GR', 'HIDALGO': 'HG', 'JALISCO': 'JC',
  'MEXICO': 'MC', 'MICHOACAN': 'MN', 'MORELOS': 'MS', 'NAYARIT': 'NT',
  'NUEVO LEON': 'NL', 'OAXACA': 'OC', 'PUEBLA': 'PL', 'QUERETARO': 'QT',
  'QUINTANA ROO': 'QR', 'SAN LUIS POTOSI': 'SP', 'SINALOA': 'SL',
  'SONORA': 'SR', 'TABASCO': 'TC', 'TAMAULIPAS': 'TS', 'TLAXCALA': 'TL',
  'VERACRUZ': 'VZ', 'YUCATAN': 'YN', 'ZACATECAS': 'ZS',
  'NACIDO EN EL EXTRANJERO': 'NE'
};

function getPrimeraVocalInterna(str) {
  for (let i = 1; i < str.length; i++) {
    if (vocales.includes(str[i].toUpperCase())) {
      return str[i].toUpperCase();
    }
  }
  return 'X';
}

function getPrimeraConsonanteInterna(str) {
  for (let i = 1; i < str.length; i++) {
    if (consonantes.includes(str[i].toUpperCase())) {
      return str[i].toUpperCase();
    }
  }
  return 'X';
}

export const generateCurp = ({ nombre, apellidoPaterno, apellidoMaterno, fechaNacimiento, sexo, estadoNacimiento }) => {
  if (!nombre || !apellidoPaterno || !fechaNacimiento || !sexo || !estadoNacimiento) {
    return '';
  }

  const sanitizedNombre = nombre.toUpperCase().trim();
  const sanitizedAP = apellidoPaterno.toUpperCase().trim();
  const sanitizedAM = (apellidoMaterno || '').toUpperCase().trim();

  const fecha = new Date(fechaNacimiento + 'T00:00:00');
  const anio = fecha.getFullYear().toString().slice(-2);
  const mes = ('0' + (fecha.getMonth() + 1)).slice(-2);
  const dia = ('0' + fecha.getDate()).slice(-2);

  let curp = '';
  curp += sanitizedAP.charAt(0);
  curp += getPrimeraVocalInterna(sanitizedAP);
  curp += (sanitizedAM ? sanitizedAM.charAt(0) : 'X');
  curp += sanitizedNombre.charAt(0);
  curp += anio + mes + dia;
  curp += (sexo === 'HOMBRE' ? 'H' : 'M');
  curp += estados[estadoNacimiento.toUpperCase()] || 'NE';
  curp += getPrimeraConsonanteInterna(sanitizedAP);
  curp += getPrimeraConsonanteInterna(sanitizedAM);
  curp += getPrimeraConsonanteInterna(sanitizedNombre);
  curp += '00';

  return curp.slice(0, 18);
};