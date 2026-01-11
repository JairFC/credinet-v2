/**
 * Associates Service - API calls para gestión de asociados
 * 
 * Asociados: Usuarios que prestan dinero (tienen línea de crédito)
 */
import { apiClient } from '../apiClient';
import { ENDPOINTS } from '../endpoints';

export const associatesService = {
  /**
   * Busca asociados por nombre, email o username
   * @param {string} q - Término de búsqueda (mínimo 2 caracteres)
   * @param {number} minCredit - Crédito disponible mínimo (default 0)
   * @param {number} limit - Máximo resultados (default 10)
   */
  searchAvailable: async (q, minCredit = 0, limit = 10) => {
    return apiClient.get(ENDPOINTS.associates.searchAvailable, {
      params: { q, min_credit: minCredit, limit }
    });
  },

  /**
   * Obtiene lista paginada de asociados
   */
  getAll: async (params = {}) => {
    const { limit = 50, offset = 0, active_only = true } = params;
    return apiClient.get(ENDPOINTS.associates.list, {
      params: { limit, offset, active_only }
    });
  },

  /**
   * Obtiene detalle de un asociado
   */
  getById: (id) => {
    return apiClient.get(ENDPOINTS.associates.detail(id));
  },

  /**
   * Obtiene resumen de crédito de un asociado
   */
  getCreditSummary: (userId) => {
    return apiClient.get(ENDPOINTS.associates.credit(userId));
  },

  /**
   * Obtiene el desglose de deuda de un asociado (Phase 6)
   */
  getDebtSummary: (associateId) => {
    return apiClient.get(ENDPOINTS.associates.debtSummary(associateId));
  },

  /**
   * Obtiene historial de deudas por periodo (Phase 6)
   */
  getDebtHistory: (associateId) => {
    return apiClient.get(ENDPOINTS.associates.debtHistory(associateId));
  },

  /**
   * Obtiene todos los pagos de un asociado (Phase 6)
   */
  getAllPayments: (associateId, params = {}) => {
    return apiClient.get(ENDPOINTS.associates.allPayments(associateId), {
      params
    });
  },

  /**
   * Registra un abono de deuda (Phase 6)
   * @param {number} associateId - ID del perfil del asociado
   * @param {Object} data - Datos del pago
   * @param {number} data.payment_amount - Monto del abono
   * @param {number} data.payment_method_id - ID del método de pago
   * @param {string} [data.payment_reference] - Referencia del pago
   * @param {string} [data.notes] - Notas adicionales
   */
  registerDebtPayment: (associateId, data) => {
    return apiClient.post(ENDPOINTS.associates.debtPayments(associateId), data);
  },

  /**
   * Crea un nuevo asociado
   */
  create: (data) => {
    return apiClient.post(ENDPOINTS.associates.list, data);
  },

  /**
   * Actualiza un asociado existente
   */
  update: (id, data) => {
    return apiClient.put(ENDPOINTS.associates.detail(id), data);
  },

  /**
   * Actualiza la línea de crédito de un asociado
   */
  updateCreditLimit: (id, creditLimit) => {
    return apiClient.patch(ENDPOINTS.associates.detail(id), {
      credit_limit: creditLimit
    });
  },

  /**
   * Elimina (desactiva) un asociado
   */
  delete: (id) => {
    return apiClient.delete(ENDPOINTS.associates.detail(id));
  },
};
