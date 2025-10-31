// 🌐 CONFIGURACIÓN PARA ENTORNO REMOTO
// IP del servidor Ubuntu: 192.168.98.98

// Detectar el entorno basado en el puerto
const currentPort = window.location.port;
const isDockerEnvironment = currentPort === '5174'; // Docker usa puerto 5174
const isDevEnvironment = currentPort === '5173';    // Dev usa puerto 5173
const isProduction = import.meta.env.PROD;

// Configuración de URLs base
export const API_BASE_URL = (() => {
  if (isDockerEnvironment) {
    // Entorno Docker - usa backend Docker en puerto 8001
    return 'http://192.168.98.98:8001';
  } else if (isDevEnvironment) {
    // Entorno desarrollo - usa backend Docker en puerto 8001 también
    // (porque no tienes backend dev corriendo en 8002)
    return 'http://192.168.98.98:8001';
  } else {
    // Fallback para otros casos
    return 'http://192.168.98.98:8001';
  }
})();

// Configuración adicional
export const config = {
  API_BASE_URL,

  // URLs específicas
  LOGIN_URL: `${API_BASE_URL}/api/auth/login`,
  USERS_SEARCH_URL: `${API_BASE_URL}/api/auth/users/search`,
  USERS_CREATE_URL: `${API_BASE_URL}/api/auth/register`,
  LOANS_URL: `${API_BASE_URL}/api/loans`,
  PAYMENT_PREVIEW_URL: `${API_BASE_URL}/api/loans/payment-preview`,

  // Configuración de desarrollo
  DEV_MODE: !isProduction,
  ENVIRONMENT: isDockerEnvironment ? 'DOCKER' : (isDevEnvironment ? 'DEV' : 'UNKNOWN'),
  CURRENT_PORT: currentPort,
  REMOTE_SERVER_IP: '192.168.98.98',

  // Puertos
  BACKEND_PORT: 8001,
  FRONTEND_DEV_PORT: 5173,
  FRONTEND_DOCKER_PORT: 5174,

  // Timeouts
  API_TIMEOUT: 10000,

  // Headers por defecto
  DEFAULT_HEADERS: {
    'Content-Type': 'application/json',
    'Accept': 'application/json'
  }
};

// 🔍 DEBUG: Mostrar información de entorno en consola
console.log('🌐 CONFIGURACIÓN DE ENTORNO:', {
  ENVIRONMENT: config.ENVIRONMENT,
  CURRENT_PORT: config.CURRENT_PORT,
  API_BASE_URL: config.API_BASE_URL,
  IS_DOCKER: isDockerEnvironment,
  IS_DEV: isDevEnvironment,
  IS_PROD: isProduction
});

export default config;