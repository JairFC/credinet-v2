/**
 * Statements Service
 * Handles statement-related API calls
 */
import apiClient from '../apiClient';
import { ENDPOINTS } from '../endpoints';

export const statementsService = {
  /**
   * Get all statements with filters
   * @param {Object} params - Query params { status, client_id, date_from, date_to, page, limit }
   * @returns {Promise} Response with statements list
   */
  getAll: (params = {}) => {
    return apiClient.get(ENDPOINTS.statements.list, { params });
  },

  /**
   * Get statement by ID
   * @param {number} id - Statement ID
   * @returns {Promise} Response with statement details
   */
  getById: (id) => {
    return apiClient.get(ENDPOINTS.statements.detail(id));
  },

  /**
   * Get statements by loan ID
   * @param {number} loanId - Loan ID
   * @param {Object} params - Optional query params
   * @returns {Promise} Response with statements list
   */
  getByLoanId: (loanId, params = {}) => {
    return apiClient.get(ENDPOINTS.statements.byLoan(loanId), { params });
  },

  /**
   * Mark statement as paid
   * @param {number} id - Statement ID
   * @param {Object} data - Payment data { payment_date, amount, payment_method, notes }
   * @returns {Promise} Response with updated statement
   */
  markAsPaid: (id, data) => {
    return apiClient.post(ENDPOINTS.statements.markPaid(id), data);
  },

  /**
   * Apply late fee to statement
   * @param {number} id - Statement ID
   * @param {Object} data - Late fee data { amount, reason }
   * @returns {Promise} Response with updated statement
   */
  applyLateFee: (id, data) => {
    return apiClient.post(ENDPOINTS.statements.applyLateFee(id), data);
  },

  /**
   * Generate statement for a loan
   * @param {number} loanId - Loan ID
   * @param {Object} data - Statement generation data
   * @returns {Promise} Response with generated statement
   */
  generate: (loanId, data) => {
    return apiClient.post(ENDPOINTS.statements.generate(loanId), data);
  },

  /**
   * Recalculate statement
   * @param {number} id - Statement ID
   * @returns {Promise} Response with recalculated statement
   */
  recalculate: (id) => {
    return apiClient.post(ENDPOINTS.statements.recalculate(id));
  },

  /**
   * Register payment to associate statement (abono al período)
   * @param {number} id - Statement ID
   * @param {Object} paymentData - { payment_amount, payment_date, payment_method_id, payment_reference, notes }
   * @returns {Promise} Response with updated statement
   */
  registerPayment: (id, paymentData) => {
    // El endpoint usa query params, no body
    return apiClient.post(ENDPOINTS.statements.registerPayment(id), null, {
      params: paymentData
    });
  },

  /**
   * Get all payments made to a statement
   * @param {number} id - Statement ID
   * @returns {Promise} Response with payments list
   */
  getPayments: (id) => {
    return apiClient.get(ENDPOINTS.statements.payments(id));
  },

  /**
   * Get period statistics
   * @param {number} periodId - Period ID
   * @returns {Promise} Response with period statistics
   */
  getPeriodStats: (periodId) => {
    return apiClient.get(ENDPOINTS.statements.periodStats(periodId));
  },
};

export default statementsService;
