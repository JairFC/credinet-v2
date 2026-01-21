// Mock API Service - Credinet Frontend MVP
// Simula el backend sin necesidad de servidor real

import loansData from '../mocks/loans.json.js';
import paymentsData from '../mocks/payments.json.js';
import rateProfilesData from '../mocks/rateProfiles.json.js';

// Utilidad para simular latencia de red
const delay = (ms) => new Promise(resolve => setTimeout(resolve, ms));

// Utilidad para simular errores ocasionales (opcional)
const shouldFail = (probability = 0) => Math.random() < probability;

// ============================================
// LOANS API
// ============================================

export const loansApi = {
  /**
   * Obtener todos los préstamos
   * @param {Object} filters - Filtros opcionales { status, client_id, associate_id }
   * @returns {Promise<Array>}
   */
  getAll: async (filters = {}) => {
    await delay(300);

    let filtered = [...loansData];

    if (filters.status) {
      filtered = filtered.filter(loan => loan.status === filters.status);
    }
    if (filters.client_id) {
      filtered = filtered.filter(loan => loan.client_id === filters.client_id);
    }
    if (filters.associate_id) {
      filtered = filtered.filter(loan => loan.associate_id === filters.associate_id);
    }

    return filtered;
  },

  /**
   * Obtener un préstamo por ID
   * @param {number} id - ID del préstamo
   * @returns {Promise<Object>}
   */
  getById: async (id) => {
    await delay(200);

    const loan = loansData.find(l => l.id === parseInt(id));

    if (!loan) {
      throw new Error(`Loan with id ${id} not found`);
    }

    return loan;
  },

  /**
   * Crear nuevo préstamo (solicitud)
   * @param {Object} loanData - Datos del préstamo { client_id, amount, term_biweeks, loan_reason, profile_code }
   * @returns {Promise<Object>}
   */
  create: async (loanData) => {
    await delay(500);

    // Simular cálculo de campos (normalmente lo hace el backend)
    const mockCalculation = {
      biweekly_payment: 3145.83,
      total_payment: 37750.00,
      total_interest: 12750.00,
      total_commission: 29690.40,
      commission_per_payment: 2474.20,
      associate_payment: 671.63
    };

    const newLoan = {
      id: Math.max(...loansData.map(l => l.id)) + 1,
      ...loanData,
      ...mockCalculation,
      status_id: 1,
      status: "PENDING",
      requested_at: new Date().toISOString(),
      approved_at: null,
      approved_by: null,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString()
    };

    loansData.push(newLoan);

    return {
      success: true,
      loan: newLoan,
      message: "Solicitud de préstamo creada exitosamente"
    };
  },

  /**
   * Aprobar préstamo
   * @param {number} id - ID del préstamo
   * @param {Object} data - { associate_id, approved_by }
   * @returns {Promise<Object>}
   */
  approve: async (id, data) => {
    await delay(800);

    const loan = loansData.find(l => l.id === parseInt(id));

    if (!loan) {
      throw new Error(`Loan with id ${id} not found`);
    }

    if (loan.status !== "PENDING") {
      throw new Error(`Loan is not pending approval (current status: ${loan.status})`);
    }

    // Actualizar loan
    // ACTIVE = status_id 2 (unico estado para préstamos activos)
    loan.status = "ACTIVE";
    loan.status_id = 2;
    loan.associate_id = data.associate_id;
    loan.approved_by = data.approved_by;
    loan.approved_at = new Date().toISOString();
    loan.updated_at = new Date().toISOString();

    // Simular generación de payments (normalmente lo hace el trigger en BD)
    console.log(`🎯 Mock: Generating payment schedule for loan ${id}`);
    console.log(`   - Capital: $${loan.amount}`);
    console.log(`   - Term: ${loan.term_biweeks} biweeks`);
    console.log(`   - Biweekly payment: $${loan.biweekly_payment}`);

    return {
      success: true,
      loan_id: id,
      status: "ACTIVE",
      payments_generated: loan.term_biweeks,
      first_payment_date: "2025-11-15",
      message: "Préstamo aprobado exitosamente"
    };
  },

  /**
   * Rechazar préstamo
   * @param {number} id - ID del préstamo
   * @param {Object} data - { rejected_by, rejection_reason }
   * @returns {Promise<Object>}
   */
  reject: async (id, data) => {
    await delay(500);

    const loan = loansData.find(l => l.id === parseInt(id));

    if (!loan) {
      throw new Error(`Loan with id ${id} not found`);
    }

    if (loan.status !== "PENDING") {
      throw new Error(`Loan is not pending (current status: ${loan.status})`);
    }

    loan.status = "REJECTED";
    loan.status_id = 6;
    loan.rejection_reason = data.rejection_reason;
    loan.rejected_by = data.rejected_by;
    loan.rejected_at = new Date().toISOString();
    loan.updated_at = new Date().toISOString();

    return {
      success: true,
      loan_id: id,
      status: "REJECTED",
      message: "Préstamo rechazado"
    };
  }
};

// ============================================
// PAYMENTS API
// ============================================

export const paymentsApi = {
  /**
   * Obtener todos los pagos de un préstamo
   * @param {number} loanId - ID del préstamo
   * @param {Object} filters - Filtros opcionales { status }
   * @returns {Promise<Array>}
   */
  getByLoanId: async (loanId, filters = {}) => {
    await delay(300);

    let filtered = paymentsData.filter(p => p.loan_id === parseInt(loanId));

    if (filters.status) {
      filtered = filtered.filter(p => p.status === filters.status);
    }

    return filtered;
  },

  /**
   * Obtener un pago por ID
   * @param {number} id - ID del pago
   * @returns {Promise<Object>}
   */
  getById: async (id) => {
    await delay(200);

    const payment = paymentsData.find(p => p.id === parseInt(id));

    if (!payment) {
      throw new Error(`Payment with id ${id} not found`);
    }

    return payment;
  },

  /**
   * Registrar pago
   * @param {number} id - ID del pago
   * @param {Object} data - { amount_paid, payment_date, payment_method, reference_number, registered_by }
   * @returns {Promise<Object>}
   */
  register: async (id, data) => {
    await delay(600);

    const payment = paymentsData.find(p => p.id === parseInt(id));

    if (!payment) {
      throw new Error(`Payment with id ${id} not found`);
    }

    if (payment.status === "PAID") {
      throw new Error(`Payment already paid on ${payment.payment_date}`);
    }

    // Actualizar payment
    payment.amount_paid = data.amount_paid;
    payment.payment_date = data.payment_date;
    payment.payment_method = data.payment_method;
    payment.reference_number = data.reference_number;
    payment.registered_by = data.registered_by;
    payment.status = "PAID";
    payment.status_id = 8;
    payment.updated_at = new Date().toISOString();

    // Determinar si es pago atrasado
    const dueDate = new Date(payment.payment_due_date);
    const paidDate = new Date(data.payment_date);
    payment.is_late = paidDate > dueDate;

    return {
      success: true,
      payment_id: id,
      new_status: "PAID",
      is_late: payment.is_late,
      message: "Pago registrado exitosamente"
    };
  },

  /**
   * Obtener resumen de pagos
   * @param {number} loanId - ID del préstamo
   * @returns {Promise<Object>}
   */
  getSummary: async (loanId) => {
    await delay(250);

    const loanPayments = paymentsData.filter(p => p.loan_id === parseInt(loanId));

    const paidPayments = loanPayments.filter(p => p.status === "PAID");
    const totalPaid = paidPayments.reduce((sum, p) => sum + p.amount_paid, 0);
    const totalExpected = loanPayments.reduce((sum, p) => sum + p.expected_amount, 0);
    const balanceRemaining = loanPayments[loanPayments.length - 1]?.balance_remaining || 0;

    return {
      payments_total: loanPayments.length,
      payments_made: paidPayments.length,
      payments_pending: loanPayments.length - paidPayments.length,
      total_expected: totalExpected,
      total_paid: totalPaid,
      balance_remaining: balanceRemaining,
      percent_complete: (paidPayments.length / loanPayments.length) * 100
    };
  }
};

// ============================================
// RATE PROFILES API
// ============================================

export const rateProfilesApi = {
  /**
   * Obtener todos los perfiles de tasas
   * @returns {Promise<Array>}
   */
  getAll: async () => {
    await delay(200);
    return rateProfilesData.filter(profile => profile.is_active);
  },

  /**
   * Obtener un perfil por código
   * @param {string} code - Código del perfil (standard, vip, premium, basic)
   * @returns {Promise<Object>}
   */
  getByCode: async (code) => {
    await delay(150);

    const profile = rateProfilesData.find(p => p.code === code);

    if (!profile) {
      throw new Error(`Rate profile with code ${code} not found`);
    }

    return profile;
  },

  /**
   * Calcular pago de préstamo
   * @param {number} amount - Monto del préstamo
   * @param {number} termBiweeks - Plazo en quincenas
   * @param {string} profileCode - Código del perfil
   * @returns {Promise<Object>}
   */
  calculateLoanPayment: async (amount, termBiweeks, profileCode) => {
    await delay(300);

    // Buscar profile
    const profile = rateProfilesData.find(p => p.code === profileCode);
    if (!profile) {
      throw new Error(`Rate profile ${profileCode} not found`);
    }

    // Buscar detail para el término
    const detail = profile.details.find(d => d.term_biweeks === termBiweeks);
    if (!detail) {
      throw new Error(`Term ${termBiweeks} not available for profile ${profileCode}`);
    }

    // Cálculos (simulación de calculate_loan_payment())
    const clientRateBiweekly = detail.client_rate_annual / 10;
    const associateRateBiweekly = detail.associate_rate_annual / 10;
    const commissionRateBiweekly = detail.commission_rate_annual / 10;

    const interestAmount = (amount * clientRateBiweekly / 100) * termBiweeks;
    const commissionAmount = (amount * commissionRateBiweekly / 100) * termBiweeks;
    const totalPayment = amount + interestAmount + commissionAmount;
    const biweeklyPayment = totalPayment / termBiweeks;
    const commissionPerPayment = commissionAmount / termBiweeks;
    const associatePayment = (amount * associateRateBiweekly / 100);

    return {
      biweekly_payment: Math.round(biweeklyPayment * 100) / 100,
      total_payment: Math.round(totalPayment * 100) / 100,
      total_interest: Math.round(interestAmount * 100) / 100,
      total_commission: Math.round(commissionAmount * 100) / 100,
      commission_per_payment: Math.round(commissionPerPayment * 100) / 100,
      associate_payment: Math.round(associatePayment * 100) / 100,
      client_rate: detail.client_rate_annual,
      associate_rate: detail.associate_rate_annual,
      commission_rate: detail.commission_rate_annual,
      biweekly_client_rate: clientRateBiweekly,
      biweekly_associate_rate: associateRateBiweekly,
      biweekly_commission_rate: commissionRateBiweekly,
      term_biweeks: termBiweeks
    };
  }
};

// ============================================
// EXPORT COMPLETO
// ============================================

const api = {
  loans: loansApi,
  payments: paymentsApi,
  rateProfiles: rateProfilesApi
};

export default api;
