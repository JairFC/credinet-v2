/**
 * Agreements Service
 * Handles agreements (convenios) and defaulted client reports API calls
 * 
 * LÓGICA DE NEGOCIO:
 * - Cuando un asociado reporta un cliente moroso, se crea un reporte PENDING
 * - Admin aprueba el reporte → pagos se marcan PAID_BY_ASSOCIATE → debt_balance aumenta
 * - Se puede crear un convenio para que el asociado pague su deuda en cuotas mensuales
 */
import apiClient from '../apiClient';
import { ENDPOINTS } from '../endpoints';

export const agreementsService = {
  // ==================== REPORTES DE CLIENTES MOROSOS ====================

  /**
   * Get all defaulted client reports with optional filters
   * @param {Object} params - Query params { status, associate_id, page, limit }
   * @returns {Promise} Response with reports list
   */
  getDefaultedReports: (params = {}) => {
    return apiClient.get(ENDPOINTS.agreements.defaultedReports, { params });
  },

  /**
   * Get a specific defaulted client report
   * @param {number} id - Report ID
   * @returns {Promise} Response with report details
   */
  getDefaultedReport: (id) => {
    return apiClient.get(ENDPOINTS.agreements.defaultedReportDetail(id));
  },

  /**
   * Create a new defaulted client report
   * Called when associate reports a problematic client
   * 
   * @param {Object} reportData - Report data
   * @param {number} reportData.loan_id - Loan ID being reported
   * @param {number} reportData.total_debt_amount - Total debt amount
   * @param {string} reportData.evidence_details - Description of evidence
   * @param {File} [reportData.evidence_file] - Optional evidence file
   * @returns {Promise} Response with created report
   */
  createDefaultedReport: (reportData) => {
    // If there's a file, use FormData
    if (reportData.evidence_file) {
      const formData = new FormData();
      formData.append('loan_id', reportData.loan_id);
      formData.append('total_debt_amount', reportData.total_debt_amount);
      formData.append('evidence_details', reportData.evidence_details);
      formData.append('evidence_file', reportData.evidence_file);
      
      return apiClient.post(ENDPOINTS.agreements.createDefaultedReport, formData, {
        headers: { 'Content-Type': 'multipart/form-data' }
      });
    }
    
    return apiClient.post(ENDPOINTS.agreements.createDefaultedReport, reportData);
  },

  /**
   * Approve a defaulted client report
   * - Marks loan payments as PAID_BY_ASSOCIATE
   * - Adds debt to associate's debt_balance
   * - Creates record in associate_debt_breakdown
   * 
   * @param {number} id - Report ID
   * @param {Object} data - Approval data { notes }
   * @returns {Promise} Response with updated report
   */
  approveDefaultedReport: (id, data = {}) => {
    return apiClient.post(ENDPOINTS.agreements.approveDefaultedReport(id), data);
  },

  /**
   * Reject a defaulted client report
   * @param {number} id - Report ID
   * @param {Object} data - Rejection data { rejection_reason }
   * @returns {Promise} Response with updated report
   */
  rejectDefaultedReport: (id, data) => {
    return apiClient.post(ENDPOINTS.agreements.rejectDefaultedReport(id), data);
  },

  /**
   * Get defaulted reports for a specific associate
   * @param {number} associateProfileId - Associate Profile ID
   * @returns {Promise} Response with reports list
   */
  getAssociateDefaultedReports: (associateProfileId) => {
    return apiClient.get(ENDPOINTS.agreements.associateDefaultedReports(associateProfileId));
  },

  // ==================== CONVENIOS ====================

  /**
   * Get all agreements with optional filters
   * @param {Object} params - Query params { status, associate_id, page, limit }
   * @returns {Promise} Response with agreements list
   */
  getAgreements: (params = {}) => {
    return apiClient.get(ENDPOINTS.agreements.list, { params });
  },

  /**
   * Get a specific agreement with items
   * @param {number} id - Agreement ID
   * @returns {Promise} Response with agreement details
   */
  getAgreement: (id) => {
    return apiClient.get(ENDPOINTS.agreements.detail(id));
  },

  /**
   * Get agreements for a specific associate
   * @param {number} associateProfileId - Associate Profile ID
   * @returns {Promise} Response with agreements list
   */
  getAssociateAgreements: (associateProfileId) => {
    return apiClient.get(ENDPOINTS.agreements.associateAgreements(associateProfileId));
  },

  /**
   * Create a new agreement (convenio)
   * Groups approved defaulted reports into a payment plan
   * 
   * @param {Object} agreementData - Agreement data
   * @param {number} agreementData.associate_profile_id - Associate Profile ID
   * @param {number} agreementData.payment_plan_months - Number of months for payment plan
   * @param {Array} agreementData.item_ids - Array of debt breakdown IDs to include
   * @param {string} [agreementData.notes] - Optional notes
   * @returns {Promise} Response with created agreement
   */
  createAgreement: (agreementData) => {
    return apiClient.post(ENDPOINTS.agreements.create, agreementData);
  },

  /**
   * Create a new agreement (convenio) from ACTIVE LOANS
   * Transfers pending payments from credit_used to debt_balance
   * 
   * BUSINESS LOGIC:
   * - Takes active loans with pending future payments
   * - Calculates SUM(associate_payment) for all pending payments
   * - Decreases credit_used by that amount
   * - Increases debt_balance by the same amount
   * - credit_available stays UNCHANGED (it's a transfer, not a new charge)
   * - Marks loans as IN_AGREEMENT (status_id=9)
   * - Marks pending payments as IN_AGREEMENT (status_id=13)
   * 
   * @param {Object} data - Agreement data
   * @param {Array<number>} data.loan_ids - Array of active loan IDs to include
   * @param {number} data.payment_plan_months - Number of months for payment plan (1-36)
   * @param {string} [data.notes] - Optional notes
   * @returns {Promise} Response with created agreement
   */
  createAgreementFromLoans: (data) => {
    return apiClient.post(ENDPOINTS.agreements.createFromLoans, data);
  },

  /**
   * Register a payment for an agreement
   * Reduces associate's debt_balance
   * 
   * @param {number} agreementId - Agreement ID
   * @param {number} paymentNumber - Payment number (1, 2, 3...)
   * @param {Object} paymentData - Payment data { payment_method_id, payment_reference, notes }
   * @returns {Promise} Response with updated agreement
   */
  registerAgreementPayment: (agreementId, paymentNumber, paymentData) => {
    return apiClient.post(ENDPOINTS.agreements.registerPayment(agreementId, paymentNumber), paymentData);
  },

  /**
   * Get payments for an agreement
   * @param {number} agreementId - Agreement ID
   * @returns {Promise} Response with payments list
   */
  getAgreementPayments: (agreementId) => {
    return apiClient.get(ENDPOINTS.agreements.payments(agreementId));
  },

  /**
   * Cancel an agreement
   * @param {number} id - Agreement ID
   * @param {Object} data - Cancellation data { reason }
   * @returns {Promise} Response with cancelled agreement
   */
  cancelAgreement: (id, data) => {
    return apiClient.post(ENDPOINTS.agreements.cancel(id), data);
  },

  // ==================== DESGLOSE DE DEUDA ====================

  /**
   * Get debt breakdown for an associate
   * Shows all debts by type (DEFAULTED_CLIENT, UNREPORTED_PAYMENT, LATE_FEE, etc.)
   * 
   * @param {number} associateProfileId - Associate Profile ID
   * @param {Object} params - Query params { is_liquidated }
   * @returns {Promise} Response with debt breakdown list
   */
  getDebtBreakdown: (associateProfileId, params = {}) => {
    return apiClient.get(ENDPOINTS.agreements.debtBreakdown(associateProfileId), { params });
  },
};

export default agreementsService;
