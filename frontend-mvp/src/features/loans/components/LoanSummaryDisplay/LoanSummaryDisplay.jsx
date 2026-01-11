/**
 * LoanSummaryDisplay - Componente de Resumen de Préstamo para vista de detalle
 * 
 * Diseño profesional para mostrar información de un préstamo existente.
 * Similar a LoanSummaryPreview pero adaptado para datos de un loan existente.
 * 
 * @param {Object} loan - Datos del préstamo
 */
import React from 'react';
import './LoanSummaryDisplay.css';

const LoanSummaryDisplay = ({ loan }) => {
  if (!loan) return null;

  const formatCurrency = (amount) => {
    const num = parseFloat(amount) || 0;
    return new Intl.NumberFormat('es-MX', {
      style: 'currency',
      currency: 'MXN',
      minimumFractionDigits: 2
    }).format(num);
  };

  const formatPercent = (value) => {
    const num = parseFloat(value) || 0;
    return `${num.toFixed(2)}%`;
  };

  const formatDate = (dateStr) => {
    if (!dateStr) return '-';
    const date = new Date(dateStr);
    return new Intl.DateTimeFormat('es-MX', {
      day: '2-digit',
      month: 'short',
      year: 'numeric'
    }).format(date);
  };

  // Cálculos derivados
  const biweeklyPayment = parseFloat(loan.payment_amount || loan.biweekly_payment) || 0;
  const totalPayment = parseFloat(loan.total_to_pay || loan.total_payment) || 0;
  const amount = parseFloat(loan.amount) || 0;
  const interestRate = parseFloat(loan.interest_rate) || 0;
  const commissionRate = parseFloat(loan.commission_rate) || 0;
  const termBiweeks = parseInt(loan.term_biweeks) || 0;
  
  // Usar valores pre-calculados del backend si están disponibles, sino calcular manualmente
  const totalInterest = parseFloat(loan.total_interest) || (totalPayment - amount);
  const commissionPerPayment = parseFloat(loan.commission_per_payment) || ((amount * commissionRate) / 100);
  const associatePayment = parseFloat(loan.associate_payment) || (biweeklyPayment - commissionPerPayment);
  const totalCommission = parseFloat(loan.total_commission) || (commissionPerPayment * termBiweeks);
  const associateTotal = (associatePayment * termBiweeks);

  return (
    <div className="loan-summary-display">
      {/* Header */}
      <div className="lsd-header">
        <div className="lsd-header-icon">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <path d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"/>
            <path d="M9 12h6M9 16h6"/>
          </svg>
        </div>
        <h2 className="lsd-header-title">Resumen del Préstamo</h2>
        <p className="lsd-header-subtitle">Información detallada del préstamo #{loan.id}</p>
      </div>

      {/* Progress bar decorativo */}
      <div className="lsd-progress-bar">
        <div className="lsd-progress-fill"></div>
      </div>

      {/* Grid de 3 columnas */}
      <div className="lsd-grid">
        
        {/* Card 1: Información del Préstamo */}
        <div className="lsd-card lsd-card--info">
          <div className="lsd-card-header">
            <div className="lsd-card-icon lsd-card-icon--info">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <circle cx="12" cy="12" r="10"/>
                <path d="M12 16v-4M12 8h.01"/>
              </svg>
            </div>
            <h3 className="lsd-card-title">Información</h3>
          </div>
          
          <div className="lsd-card-body">
            <div className="lsd-row">
              <span className="lsd-row-label">Monto solicitado</span>
              <span className="lsd-row-value lsd-row-value--lg">
                {formatCurrency(amount)}
              </span>
            </div>
            
            <div className="lsd-row">
              <span className="lsd-row-label">Plazo</span>
              <span className="lsd-row-value">
                <strong>{termBiweeks}</strong> quincenas 
                <span className="lsd-row-meta">({Math.round(termBiweeks / 2)} meses)</span>
              </span>
            </div>
            
            <div className="lsd-row">
              <span className="lsd-row-label">Perfil</span>
              <span className="lsd-row-value">
                <span className="lsd-badge lsd-badge--profile">
                  {loan.profile_code || 'Personalizado'}
                </span>
              </span>
            </div>
            
            <div className="lsd-divider"></div>
            
            <div className="lsd-row lsd-row--highlight">
              <span className="lsd-row-label">Tasa de interés</span>
              <span className="lsd-tag lsd-tag--warning">
                {formatPercent(interestRate)} <small>por quincena</small>
              </span>
            </div>
            
            <div className="lsd-row lsd-row--highlight">
              <span className="lsd-row-label">Comisión asociado</span>
              <span className="lsd-tag lsd-tag--info">
                {formatPercent(commissionRate)} 
                <small>({formatCurrency(commissionPerPayment)}/qna)</small>
              </span>
            </div>

            {loan.approved_at && (
              <>
                <div className="lsd-divider"></div>
                <div className="lsd-row">
                  <span className="lsd-row-label">Aprobado</span>
                  <span className="lsd-row-value lsd-row-value--muted">
                    {formatDate(loan.approved_at)}
                  </span>
                </div>
              </>
            )}
          </div>
        </div>

        {/* Card 2: Totales del Cliente */}
        <div className="lsd-card lsd-card--client">
          <div className="lsd-card-header">
            <div className="lsd-card-icon lsd-card-icon--client">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <path d="M20 21v-2a4 4 0 00-4-4H8a4 4 0 00-4 4v2"/>
                <circle cx="12" cy="7" r="4"/>
              </svg>
            </div>
            <h3 className="lsd-card-title">Totales del Cliente</h3>
          </div>
          
          <div className="lsd-card-body">
            {/* Pago quincenal destacado */}
            <div className="lsd-featured">
              <span className="lsd-featured-label">Pago quincenal</span>
              <span className="lsd-featured-value lsd-featured-value--client">
                {formatCurrency(biweeklyPayment)}
              </span>
            </div>
            
            <div className="lsd-row">
              <span className="lsd-row-label">Total a pagar</span>
              <span className="lsd-row-value">
                {formatCurrency(totalPayment)}
              </span>
            </div>
            
            <div className="lsd-row">
              <span className="lsd-row-label">Total de intereses</span>
              <span className="lsd-row-value lsd-row-value--muted">
                {formatCurrency(totalInterest)}
              </span>
            </div>
          </div>
        </div>

        {/* Card 3: Totales del Asociado */}
        <div className="lsd-card lsd-card--associate">
          <div className="lsd-card-header">
            <div className="lsd-card-icon lsd-card-icon--associate">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <path d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4"/>
              </svg>
            </div>
            <h3 className="lsd-card-title">Totales del Asociado</h3>
          </div>
          
          <div className="lsd-card-body">
            {/* Pago quincenal destacado */}
            <div className="lsd-featured">
              <span className="lsd-featured-label">Pago quincenal a CrediCuenta</span>
              <span className="lsd-featured-value lsd-featured-value--associate">
                {formatCurrency(associatePayment)}
              </span>
            </div>
            
            <div className="lsd-row">
              <span className="lsd-row-label">Total a pagar a CrediCuenta</span>
              <span className="lsd-row-value">
                {formatCurrency(associateTotal)}
              </span>
            </div>
            
            {/* Ganancia destacada */}
            <div className="lsd-earnings">
              <div className="lsd-earnings-content">
                <span className="lsd-earnings-label">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" width="16" height="16">
                    <path d="M12 2v20M17 5H9.5a3.5 3.5 0 000 7h5a3.5 3.5 0 010 7H6"/>
                  </svg>
                  Comisión total ganada
                </span>
                <span className="lsd-earnings-value">
                  {formatCurrency(totalCommission)}
                </span>
              </div>
            </div>
          </div>
        </div>
        
      </div>
    </div>
  );
};

export default LoanSummaryDisplay;
