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
};

export default statementsService;
