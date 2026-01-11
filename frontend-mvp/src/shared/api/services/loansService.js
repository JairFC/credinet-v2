/**
 * Loans Service
 * Handles loan-related API calls
 */
import apiClient from '../apiClient';
import { ENDPOINTS } from '../endpoints';

export const loansService = {
  /**
   * Get all loans with optional filters
   * @param {Object} params - Query params { status, client_id, associate_id, page, limit }
   * @returns {Promise} Response with loans list
   */
  getAll: (params = {}) => {
    return apiClient.get(ENDPOINTS.loans.list, { params });
  },

  /**
   * Get loan by ID
   * @param {number} id - Loan ID
   * @returns {Promise} Response with loan details
   */
  getById: (id) => {
    return apiClient.get(ENDPOINTS.loans.detail(id));
  },

  /**
   * Create new loan
   * @param {Object} loanData - Loan data
   * @returns {Promise} Response with created loan
   */
  create: (loanData) => {
    return apiClient.post(ENDPOINTS.loans.create, loanData);
  },

  /**
   * Approve loan
   * @param {number} id - Loan ID
   * @param {Object} data - Approval data { approved_by, notes }
   * @returns {Promise} Response with updated loan
   */
  approve: (id, data = {}) => {
    return apiClient.post(ENDPOINTS.loans.approve(id), data);
  },

  /**
   * Reject loan
   * @param {number} id - Loan ID
   * @param {Object} data - Rejection data { rejected_by, rejection_reason }
   * @returns {Promise} Response with updated loan
   */
  reject: (id, data) => {
    return apiClient.post(ENDPOINTS.loans.reject(id), data);
  },

  /**
   * Update loan
   * @param {number} id - Loan ID
   * @param {Object} updateData - Updated loan data
   * @returns {Promise} Response with updated loan
   */
  update: (id, updateData) => {
    return apiClient.put(ENDPOINTS.loans.update(id), updateData);
  },

  /**
   * Delete loan
   * @param {number} id - Loan ID
   * @returns {Promise}
   */
  delete: (id) => {
    return apiClient.delete(ENDPOINTS.loans.delete(id));
  },

  /**
   * Force delete loan with all payments
   * @param {number} id - Loan ID
   * @returns {Promise} Response with deletion details
   */
  forceDelete: (id) => {
    return apiClient.delete(`/api/v1/loans/${id}/force`);
  },

  /**
   * Get amortization schedule (real or simulated)
   * @param {number} id - Loan ID
   * @returns {Promise} Response with amortization schedule
   */
  getAmortization: (id) => {
    return apiClient.get(ENDPOINTS.loans.amortization(id));
  },

  // ========== RENOVACIÓN DE PRÉSTAMOS ==========

  /**
   * Get client's active loans for renewal consideration
   * @param {number} clientUserId - Client user ID
   * @returns {Promise} Response with active loans info
   */
  getClientActiveLoans: (clientUserId) => {
    return apiClient.get(ENDPOINTS.loans.clientActiveLoans(clientUserId));
  },

  /**
   * Create a renewal loan (liquidates previous loan)
   * @param {Object} renewalData - Renewal data including original_loan_id
   * @returns {Promise} Response with new loan
   */
  renew: (renewalData) => {
    return apiClient.post(ENDPOINTS.loans.renew, renewalData);
  },
};

export default loansService;
