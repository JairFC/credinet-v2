/**
 * API Endpoints - Centralized route definitions
 * Single source of truth for all backend routes
 */

export const ENDPOINTS = {
  // Authentication
  auth: {
    login: '/api/v1/auth/login',
    register: '/api/v1/auth/register',
    refresh: '/api/v1/auth/refresh',
    me: '/api/v1/auth/me',
    logout: '/api/v1/auth/logout',
    // Validations
    validateUsername: (username) => `/api/v1/auth/validate/username/${username}`,
    validateEmail: (email) => `/api/v1/auth/validate/email/${encodeURIComponent(email)}`,
    validatePhone: (phone) => `/api/v1/auth/validate/phone/${phone}`,
    validateCurp: (curp) => `/api/v1/auth/validate/curp/${curp}`,
  },

  // Dashboard
  dashboard: {
    stats: '/api/v1/dashboard/stats',
    recentActivity: '/api/v1/dashboard/recent-activity',
  },

  // Loans
  loans: {
    list: '/api/v1/loans',
    detail: (id) => `/api/v1/loans/${id}`,
    create: '/api/v1/loans',
    approve: (id) => `/api/v1/loans/${id}/approve`,
    reject: (id) => `/api/v1/loans/${id}/reject`,
    update: (id) => `/api/v1/loans/${id}`,
    delete: (id) => `/api/v1/loans/${id}`,
    amortization: (id) => `/api/v1/loans/${id}/amortization`,
    // Renovación
    clientActiveLoans: (clientUserId) => `/api/v1/loans/client/${clientUserId}/active-loans`,
    renew: '/api/v1/loans/renew',
  },

  // Payments
  payments: {
    byLoan: (loanId) => `/api/v1/payments/loans/${loanId}`,
    detail: (id) => `/api/v1/payments/${id}`,
    create: '/api/v1/payments/register',
    summary: (loanId) => `/api/v1/payments/loans/${loanId}/summary`,
  },

  // Statements
  statements: {
    list: '/api/v1/statements',
    detail: (id) => `/api/v1/statements/${id}`,
    create: '/api/v1/statements',
    markPaid: (id) => `/api/v1/statements/${id}/mark-paid`,
    applyLateFee: (id) => `/api/v1/statements/${id}/apply-late-fee`,
    periodStats: (periodId) => `/api/v1/statements/stats/period/${periodId}`,
    // Phase 6: Payment tracking endpoints
    payments: (id) => `/api/v1/statements/${id}/payments`,
    registerPayment: (id) => `/api/v1/statements/${id}/payments`,
  },

  // Cut Periods (Estados de Cuenta base)
  cutPeriods: {
    list: '/api/v1/cut-periods',
    detail: (id) => `/api/v1/cut-periods/${id}`,
    current: '/api/v1/cut-periods/current',
    statements: (periodId) => `/api/v1/cut-periods/${periodId}/statements`,
    close: (periodId) => `/api/v1/cut-periods/${periodId}/close`,
  },

  // Associates
  associates: {
    list: '/api/v1/associates',
    detail: (id) => `/api/v1/associates/${id}`,
    byUserId: (userId) => `/api/v1/associates/by-user/${userId}`,  // Para buscar por user_id (usado en statements)
    searchAvailable: '/api/v1/associates/search/available', // Buscar asociados por nombre/email
    create: '/api/v1/associates',
    update: (id) => `/api/v1/associates/${id}`,
    profile: (id) => `/api/v1/associates/${id}/profile`,
    credit: (userId) => `/api/v1/associates/${userId}/credit`,
    // Phase 6: Debt tracking endpoints
    debtSummary: (userId) => `/api/v1/associates/${userId}/debt-summary`,
    allPayments: (userId) => `/api/v1/associates/${userId}/all-payments`,
    debtPayments: (userId) => `/api/v1/associates/${userId}/debt-payments`,
    debtHistory: (userId) => `/api/v1/associates/${userId}/debt-history`,
    // Validations
    validateContactEmail: (email) => `/api/v1/associates/validate/contact-email/${encodeURIComponent(email)}`,
  },

  // Clients
  clients: {
    list: '/api/v1/clients',
    detail: (id) => `/api/v1/clients/${id}`,
    create: '/api/v1/clients',
    update: (id) => `/api/v1/clients/${id}`,
  },

  // Catalogs
  catalogs: {
    loanStatuses: '/api/v1/catalogs/loan-statuses',
    paymentStatuses: '/api/v1/catalogs/payment-statuses',
    statementStatuses: '/api/v1/catalogs/statement-statuses',
    paymentMethods: '/api/v1/catalogs/payment-methods',
    creditLevels: '/api/v1/catalogs/credit-levels',
  },

  // Rate Profiles
  rateProfiles: {
    list: '/api/v1/rate-profiles',
    detail: (code) => `/api/v1/rate-profiles/${code}`,
    reference: '/api/v1/rate-profiles/reference',
  },

  // Simulator
  simulator: {
    simulate: '/api/v1/simulator/simulate',
    quick: '/api/v1/simulator/quick',
  },

  // Agreements (Convenios) y Reportes de Morosos
  agreements: {
    // Reportes de clientes morosos
    defaultedReports: '/api/v1/defaulted-reports',
    defaultedReportDetail: (id) => `/api/v1/defaulted-reports/${id}`,
    createDefaultedReport: '/api/v1/defaulted-reports',
    approveDefaultedReport: (id) => `/api/v1/defaulted-reports/${id}/approve`,
    rejectDefaultedReport: (id) => `/api/v1/defaulted-reports/${id}/reject`,
    associateDefaultedReports: (associateProfileId) => `/api/v1/defaulted-reports/associate/${associateProfileId}`,
    
    // Convenios
    list: '/api/v1/agreements',
    detail: (id) => `/api/v1/agreements/${id}`,
    create: '/api/v1/agreements',
    createFromLoans: '/api/v1/agreements/from-loans', // Crear convenio desde préstamos activos
    associateAgreements: (associateProfileId) => `/api/v1/agreements/associates/${associateProfileId}`,
    registerPayment: (agreementId, paymentNumber) => `/api/v1/agreements/${agreementId}/payments/${paymentNumber}`,
    payments: (agreementId) => `/api/v1/agreements/${agreementId}/payments`,
    cancel: (id) => `/api/v1/agreements/${id}/cancel`,
    
    // Desglose de deuda
    debtBreakdown: (associateProfileId) => `/api/v1/associates/${associateProfileId}/debt-breakdown`,
  },
};

export default ENDPOINTS;
