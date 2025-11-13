/**
 * Utilidades compartidas para formularios de usuarios (clientes y asociados)
 */

/**
 * Adapta los datos del formulario al formato del backend
 * @param {Object} formData - Datos del formulario
 * @param {string} userType - 'client' o 'associate'
 * @returns {Object} Datos formateados para el backend
 */
export const prepareUserData = (formData, userType = 'client') => {
  const baseData = {
    username: formData.username?.trim(),
    password: formData.password,
    email: formData.email?.trim() || `${formData.username}@credinet.temp`,
    first_name: formData.first_name?.trim(),
    phone_number: formData.phone_number?.trim(),
    curp: formData.curp?.trim()?.toUpperCase() || null,
    birth_date: formData.birth_date || null,
  };

  // Para clientes: combinar apellidos en last_name
  if (userType === 'client') {
    baseData.last_name = formData.maternal_last_name
      ? `${formData.paternal_last_name} ${formData.maternal_last_name}`
      : formData.paternal_last_name;
    baseData.role_id = 5; // Cliente
  }
  // Para asociados: enviar apellidos separados
  else if (userType === 'associate') {
    baseData.paternal_last_name = formData.paternal_last_name?.trim();
    baseData.maternal_last_name = formData.maternal_last_name?.trim() || null;
    baseData.gender = formData.gender?.trim() || null;
    baseData.birth_state = formData.birth_state?.trim() || null;
    // Datos adicionales de asociado
    baseData.credit_limit = parseFloat(formData.credit_limit);
    baseData.contact_person = formData.contact_person?.trim() || null;
    baseData.contact_email = formData.contact_email?.trim()?.toLowerCase() || null;
    baseData.default_commission_rate = parseFloat(formData.default_commission_rate || 5);
    baseData.level_id = formData.level_id || 1;
  }

  return baseData;
};

/**
 * Valida la contraseña según requisitos del backend
 * @param {string} password - Contraseña a validar
 * @returns {Object} { valid: boolean, errors: string[] }
 */
export const validatePassword = (password) => {
  const errors = [];

  if (!password || password.length < 8) {
    errors.push('La contraseña debe tener mínimo 8 caracteres');
  }
  if (!/[A-Z]/.test(password)) {
    errors.push('Debe contener al menos una mayúscula');
  }
  if (!/[a-z]/.test(password)) {
    errors.push('Debe contener al menos una minúscula');
  }
  if (!/[0-9]/.test(password)) {
    errors.push('Debe contener al menos un número');
  }

  return {
    valid: errors.length === 0,
    errors
  };
};

/**
 * Extrae mensajes de error del response del backend
 * @param {Error} error - Error de Axios
 * @returns {string} Mensaje de error formateado
 */
export const extractErrorMessage = (error) => {
  if (!error.response?.data) {
    return error.message || 'Error desconocido';
  }

  const data = error.response.data;

  // Errores de validación de FastAPI (array)
  if (data.detail && Array.isArray(data.detail)) {
    return data.detail.map(err => {
      const field = err.loc?.slice(-1)[0] || 'Campo';
      return `• ${field}: ${err.msg}`;
    }).join('\n');
  }

  // Mensaje de error simple del backend
  if (data.detail) {
    let message = data.detail;

    // Traducir errores comunes de SQL/Backend a mensajes amigables
    if (message.includes('duplicate key') || message.includes('already exists')) {
      // Extraer qué campo está duplicado
      if (message.includes('username')) {
        return 'El nombre de usuario ya está registrado. Por favor usa uno diferente.';
      }
      if (message.includes('email')) {
        return 'El correo electrónico ya está registrado.';
      }
      if (message.includes('phone') || message.includes('phone_number')) {
        return 'El número de teléfono ya está registrado en el sistema.';
      }
      if (message.includes('curp')) {
        return 'La CURP ya está registrada.';
      }
      return 'Ya existe un registro con esos datos. Verifica la información.';
    }

    // Errores de validación
    if (message.includes('ValidationError')) {
      return 'Error de validación. Verifica que todos los campos sean correctos.';
    }

    // Retornar el mensaje original si no coincide con ningún patrón
    return message;
  }

  if (data.message) {
    return data.message;
  }

  return 'Error al procesar la solicitud';
};

/**
 * Valida campos comunes de formularios de usuario
 * @param {Object} formData - Datos del formulario
 * @param {string} userType - 'client' o 'associate'
 * @returns {Array} Array de errores { field, message }
 */
export const validateUserForm = (formData, userType = 'client') => {
  const errors = [];

  // Validaciones comunes
  if (!formData.first_name?.trim()) {
    errors.push({ field: 'first_name', message: 'El nombre es obligatorio' });
  }

  // Validación de apellidos (ambos tipos usan campos separados)
  if (!formData.paternal_last_name?.trim()) {
    errors.push({ field: 'paternal_last_name', message: 'El apellido paterno es obligatorio' });
  }

  if (!formData.birth_date) {
    errors.push({ field: 'birth_date', message: 'La fecha de nacimiento es obligatoria' });
  }

  if (!formData.phone_number || formData.phone_number.length !== 10) {
    errors.push({ field: 'phone_number', message: 'El teléfono debe tener 10 dígitos' });
  }

  if (formData.email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(formData.email)) {
    errors.push({ field: 'email', message: 'El email no es válido' });
  }

  // Validar contraseña
  const passwordValidation = validatePassword(formData.password);
  if (!passwordValidation.valid) {
    passwordValidation.errors.forEach(msg => {
      errors.push({ field: 'password', message: msg });
    });
  }

  // Validaciones específicas de asociados
  if (userType === 'associate') {
    if (!formData.credit_limit || parseFloat(formData.credit_limit) <= 0) {
      errors.push({ field: 'credit_limit', message: 'La línea de crédito debe ser mayor a 0' });
    }

    const rate = parseFloat(formData.default_commission_rate);
    if (isNaN(rate) || rate < 0 || rate > 100) {
      errors.push({ field: 'default_commission_rate', message: 'La tasa debe estar entre 0 y 100' });
    }

    if (formData.contact_email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(formData.contact_email)) {
      errors.push({ field: 'contact_email', message: 'El email de contacto no es válido' });
    }
  }

  return errors;
};
