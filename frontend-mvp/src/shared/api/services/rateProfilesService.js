import apiClient from '../apiClient';

/**
 * Servicio para gestionar perfiles de tasas
 */
export const rateProfilesService = {
  /**
   * Obtiene todos los perfiles de tasa habilitados
   * @returns {Promise} Lista de perfiles con restricciones
   */
  getAll: async () => {
    const response = await apiClient.get('/api/v1/rate-profiles');
    return response;
  },

  /**
   * Obtiene un perfil específico por código
   * @param {string} code - Código del perfil (legacy, standard, etc.)
   * @returns {Promise} Detalles del perfil
   */
  getByCode: async (code) => {
    const response = await apiClient.get(`/api/v1/rate-profiles/${code}`);
    return response;
  },

  /**
   * Obtiene los montos disponibles para el perfil legacy
   * Todos los montos legacy son para 12 quincenas
   * @returns {Promise} Lista de montos predefinidos
   */
  getLegacyAmounts: async () => {
    const response = await apiClient.get('/api/v1/rate-profiles/legacy-payments');
    return response;
  },

  /**
   * Calcula un préstamo usando un perfil específico
   * @param {Object} data - { amount, term_biweeks, profile_code }
   * @returns {Promise} Cálculo del préstamo
   */
  calculate: async (data) => {
    const response = await apiClient.post('/api/v1/rate-profiles/calculate', data);
    return response;
  },

  /**
   * Compara múltiples perfiles para un mismo préstamo
   * @param {Object} data - { amount, term_biweeks, profile_codes }
   * @returns {Promise} Comparación de perfiles
   */
  compare: async (data) => {
    const response = await apiClient.post('/api/v1/rate-profiles/compare', data);
    return response;
  }
};
