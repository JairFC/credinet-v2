/**
 * Simulator Service
 * Maneja las llamadas al API del simulador de préstamos
 */
import { apiClient } from '@/shared/api/apiClient';
import ENDPOINTS from '@/shared/api/endpoints';

export const simulatorService = {
  /**
   * Simular préstamo completo con tabla de amortización
   * 
   * @param {Object} params - Parámetros de simulación
   * @param {number} params.amount - Monto del préstamo
   * @param {number} params.term_biweeks - Plazo en quincenas
   * @param {string} params.profile_code - Código del perfil de tasa
   * @param {string} params.approval_date - Fecha de aprobación (YYYY-MM-DD)
   * @param {number} [params.custom_interest_rate] - Tasa de interés personalizada (solo para profile_code='custom')
   * @param {number} [params.custom_commission_rate] - Tasa de comisión personalizada (solo para profile_code='custom')
   * 
   * @returns {Promise<Object>} Objeto con summary y amortization_table
   */
  async simulate(params) {
    const response = await apiClient.post(ENDPOINTS.simulator.simulate, params);
    return response.data;
  },

  /**
   * Cálculo rápido sin tabla de amortización
   * Solo retorna totales
   * 
   * @param {Object} params - Parámetros de cálculo
   * @returns {Promise<Object>} Objeto con totales calculados
   */
  async quickCalculate(params) {
    const response = await apiClient.get(ENDPOINTS.simulator.quick, { params });
    return response.data;
  },

  /**
   * Obtener tabla de referencia precalculada
   * 
   * @param {string} [profileCode] - Filtrar por código de perfil
   * @param {number} [termBiweeks] - Filtrar por plazo
   * @returns {Promise<Object>} Tabla de referencia
   */
  async getReferenceTable(profileCode = null, termBiweeks = null) {
    const params = {};
    if (profileCode) params.profile_code = profileCode;
    if (termBiweeks) params.term_biweeks = termBiweeks;

    const response = await apiClient.get(ENDPOINTS.rateProfiles.reference, { params });
    return response.data;
  },
};
