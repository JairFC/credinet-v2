/**
 * Cut Periods Service
 * Maneja períodos de corte (estados de cuenta base)
 */
import apiClient from '../apiClient';
import { ENDPOINTS } from '../endpoints';

export const cutPeriodsService = {
  /**
   * Get all cut periods with optional filters
   * @param {Object} params - Query params { status, year, limit }
   * @returns {Promise} Response with periods list
   */
  getAll: (params = {}) => {
    return apiClient.get(ENDPOINTS.cutPeriods.list, { params });
  },

  /**
   * Get period by ID
   * @param {number} id - Period ID
   * @returns {Promise} Response with period details
   */
  getById: (id) => {
    return apiClient.get(ENDPOINTS.cutPeriods.detail(id));
  },

  /**
   * Get current active period
   * @returns {Promise} Response with current period
   */
  getCurrent: () => {
    return apiClient.get(ENDPOINTS.cutPeriods.current);
  },

  /**
   * Get all statements for a specific period
   * @param {number} periodId - Period ID
   * @returns {Promise} Response with statements list
   */
  getStatements: (periodId) => {
    return apiClient.get(ENDPOINTS.cutPeriods.statements(periodId));
  },
};

export default cutPeriodsService;
