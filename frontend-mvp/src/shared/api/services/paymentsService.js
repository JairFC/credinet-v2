/**
 * Payments Service
 * Handles payment-related API calls
 */
import apiClient from '../apiClient';
import { ENDPOINTS } from '../endpoints';

export const paymentsService = {
  /**
   * Get all payments for a specific loan
   * @param {number} loanId - Loan ID
   * @param {Object} params - Optional query params { pending_only }
   * @returns {Promise} Response with payments list
   */
  getByLoanId: (loanId, params = {}) => {
    return apiClient.get(ENDPOINTS.payments.byLoan(loanId), { params });
  },

  /**
   * Get payment summary for a loan
   * @param {number} loanId - Loan ID
   * @returns {Promise} Response with payment summary
   */
  getSummary: (loanId) => {
    return apiClient.get(ENDPOINTS.payments.summary(loanId));
  },

  /**
   * Get payment by ID
   * @param {number} id - Payment ID
   * @returns {Promise} Response with payment details
   */
  getById: (id) => {
    return apiClient.get(ENDPOINTS.payments.detail(id));
  },

  /**
   * Create/Register new payment
   * @param {Object} paymentData - Payment data
   * @returns {Promise} Response with created payment
   */
  create: (paymentData) => {
    return apiClient.post(ENDPOINTS.payments.create, paymentData);
  },

  /**
   * Cancel payment
   * @param {number} id - Payment ID
   * @param {string} reason - Cancellation reason
   * @returns {Promise} Response with updated payment
   */
  cancel: (id, reason) => {
    return apiClient.post(ENDPOINTS.payments.cancel(id), { reason });
  },
};

export default paymentsService;
