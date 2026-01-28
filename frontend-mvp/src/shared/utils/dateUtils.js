/**
 * Utilidades de formateo de fechas para CrediCuenta
 * 
 * ⚠️ IMPORTANTE: Este archivo resuelve el problema de timezone donde
 * fechas como "1995-05-25" se muestran como "24 de mayo" debido a que
 * JavaScript interpreta fechas sin hora como UTC y luego convierte
 * a la zona horaria local (Chihuahua UTC-7/-6).
 * 
 * REGLA DE ORO:
 * - Para fechas de SOLO DÍA (birth_date, payment_due_date): usar formatDateOnly()
 * - Para fechas con HORA (created_at, updated_at): usar formatDateTime()
 */

/**
 * Formatea una fecha de solo día (sin hora) correctamente.
 * Evita el problema de timezone donde "1995-05-25" se muestra como día anterior.
 * 
 * @param {string|Date} dateValue - Fecha en formato ISO (YYYY-MM-DD) o Date object
 * @param {Object} options - Opciones de formato
 * @param {boolean} options.includeYear - Incluir año (default: true)
 * @param {string} options.monthFormat - 'long' | 'short' | 'numeric' (default: 'long')
 * @returns {string} Fecha formateada en español
 * 
 * @example
 * formatDateOnly("1995-05-25") // "25 de mayo de 1995"
 * formatDateOnly("1995-05-25", { monthFormat: 'short' }) // "25 may 1995"
 */
export function formatDateOnly(dateValue, options = {}) {
  if (!dateValue) return 'N/A';
  
  const { includeYear = true, monthFormat = 'long' } = options;
  
  let dateStr = dateValue;
  
  // Si es un objeto Date, convertir a string ISO
  if (dateValue instanceof Date) {
    dateStr = dateValue.toISOString().split('T')[0];
  }
  
  // Parsear la fecha directamente como string para evitar timezone issues
  // Formato esperado: "YYYY-MM-DD" o "YYYY-MM-DDTHH:MM:SS..."
  const datePart = String(dateStr).split('T')[0];
  const [year, month, day] = datePart.split('-').map(Number);
  
  if (!year || !month || !day || isNaN(year) || isNaN(month) || isNaN(day)) {
    return 'N/A';
  }
  
  // Crear fecha usando UTC para evitar conversión de timezone
  const date = new Date(Date.UTC(year, month - 1, day));
  
  // Usar toLocaleDateString con timeZone: 'UTC' para que no aplique offset
  const formatOptions = {
    day: 'numeric',
    month: monthFormat,
    timeZone: 'UTC' // ⭐ CLAVE: Evita la conversión de timezone
  };
  
  if (includeYear) {
    formatOptions.year = 'numeric';
  }
  
  return date.toLocaleDateString('es-MX', formatOptions);
}

/**
 * Formatea una fecha con hora en zona horaria de Chihuahua.
 * Usa para created_at, updated_at, approved_at, etc.
 * 
 * @param {string|Date} dateValue - Fecha ISO con hora
 * @param {Object} options - Opciones de formato
 * @param {boolean} options.includeTime - Incluir hora (default: true)
 * @param {boolean} options.includeSeconds - Incluir segundos (default: false)
 * @returns {string} Fecha y hora formateada
 * 
 * @example
 * formatDateTime("2026-01-28T15:30:00Z") // "28 de enero de 2026, 08:30"
 */
export function formatDateTime(dateValue, options = {}) {
  if (!dateValue) return 'N/A';
  
  const { includeTime = true, includeSeconds = false } = options;
  
  const date = new Date(dateValue);
  
  if (isNaN(date.getTime())) {
    return 'N/A';
  }
  
  const formatOptions = {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
    timeZone: 'America/Chihuahua' // ⭐ Zona horaria de Chihuahua
  };
  
  if (includeTime) {
    formatOptions.hour = '2-digit';
    formatOptions.minute = '2-digit';
    if (includeSeconds) {
      formatOptions.second = '2-digit';
    }
  }
  
  return date.toLocaleDateString('es-MX', formatOptions);
}

/**
 * Formatea una fecha de pago (solo día) con formato corto.
 * 
 * @param {string} dateValue - Fecha en formato ISO
 * @returns {string} Fecha formateada "15 Ene 2026"
 */
export function formatPaymentDate(dateValue) {
  return formatDateOnly(dateValue, { monthFormat: 'short' });
}

/**
 * Parsea una fecha ISO sin aplicar conversión de timezone.
 * Útil cuando necesitas trabajar con el objeto Date pero sin offset.
 * 
 * @param {string} dateString - Fecha en formato YYYY-MM-DD
 * @returns {Date} Objeto Date representando medianoche UTC de ese día
 */
export function parseDateOnly(dateString) {
  if (!dateString) return null;
  
  const datePart = String(dateString).split('T')[0];
  const [year, month, day] = datePart.split('-').map(Number);
  
  if (!year || !month || !day) return null;
  
  return new Date(Date.UTC(year, month - 1, day));
}

/**
 * Compara si una fecha de solo día está vencida (es anterior a hoy).
 * 
 * @param {string} dateString - Fecha en formato ISO
 * @returns {boolean} true si la fecha ya pasó
 */
export function isDateOverdue(dateString) {
  const date = parseDateOnly(dateString);
  if (!date) return false;
  
  const today = new Date();
  const todayUTC = new Date(Date.UTC(today.getFullYear(), today.getMonth(), today.getDate()));
  
  return date < todayUTC;
}

/**
 * Formatea la fecha relativa ("hace 2 días", "en 3 días").
 * 
 * @param {string} dateString - Fecha en formato ISO
 * @returns {string} Texto relativo
 */
export function formatRelativeDate(dateString) {
  const date = parseDateOnly(dateString);
  if (!date) return 'N/A';
  
  const today = new Date();
  const todayUTC = new Date(Date.UTC(today.getFullYear(), today.getMonth(), today.getDate()));
  
  const diffTime = date.getTime() - todayUTC.getTime();
  const diffDays = Math.round(diffTime / (1000 * 60 * 60 * 24));
  
  if (diffDays === 0) return 'Hoy';
  if (diffDays === 1) return 'Mañana';
  if (diffDays === -1) return 'Ayer';
  if (diffDays > 1) return `En ${diffDays} días`;
  return `Hace ${Math.abs(diffDays)} días`;
}
