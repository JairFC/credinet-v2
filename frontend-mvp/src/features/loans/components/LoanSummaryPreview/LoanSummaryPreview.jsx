/**
 * LoanSummaryPreview - Componente de Resumen de Préstamo
 * 
 * Diseño profesional y moderno para mostrar el preview de cálculos
 * de un préstamo antes de ser creado.
 * 
 * @param {Object} calculation - Datos del cálculo del préstamo
 * @param {string} profileCode - Código del perfil seleccionado
 */
import React from 'react';
import './LoanSummaryPreview.css';

const LoanSummaryPreview = ({ calculation, profileCode }) => {
  if (!calculation) return null;

  const formatCurrency = (amount) => {
    return new Intl.NumberFormat('es-MX', {
      style: 'currency',
      currency: 'MXN',
      minimumFractionDigits: 2
    }).format(amount);
  };

  const isCustomProfile = profileCode === 'custom';

  return (
    <div className="loan-summary-preview">
      {/* Header */}
      <div className="lsp-header">
        <div className="lsp-header-icon">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <path d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"/>
            <path d="M9 12h6M9 16h6"/>
          </svg>
        </div>
        <h2 className="lsp-header-title">Resumen del Préstamo</h2>
        <p className="lsp-header-subtitle">Vista previa de los cálculos antes de crear</p>
      </div>

      {/* Progress bar decorativo */}
      <div className="lsp-progress-bar">
        <div className="lsp-progress-fill"></div>
      </div>

      {/* Grid de 3 columnas */}
      <div className="lsp-grid">
        
        {/* Card 1: Información del Préstamo */}
        <div className="lsp-card lsp-card--info">
          <div className="lsp-card-header">
            <div className="lsp-card-icon lsp-card-icon--info">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <circle cx="12" cy="12" r="10"/>
                <path d="M12 16v-4M12 8h.01"/>
              </svg>
            </div>
            <h3 className="lsp-card-title">Información</h3>
          </div>
          
          <div className="lsp-card-body">
            <div className="lsp-row">
              <span className="lsp-row-label">Monto solicitado</span>
              <span className="lsp-row-value lsp-row-value--lg">
                {formatCurrency(calculation.amount)}
              </span>
            </div>
            
            <div className="lsp-row">
              <span className="lsp-row-label">Plazo</span>
              <span className="lsp-row-value">
                <strong>{calculation.term_biweeks}</strong> quincenas 
                <span className="lsp-row-meta">({Math.round(calculation.term_biweeks / 2)} meses)</span>
              </span>
            </div>
            
            <div className="lsp-row">
              <span className="lsp-row-label">Perfil</span>
              <span className="lsp-row-value">
                {isCustomProfile ? (
                  <span className="lsp-badge lsp-badge--custom">Personalizado</span>
                ) : (
                  <span className="lsp-badge lsp-badge--profile">
                    {calculation.profile_name}
                    {calculation.profile_name?.toLowerCase().includes('recomendado') && ' ⭐'}
                  </span>
                )}
              </span>
            </div>
            
            <div className="lsp-divider"></div>
            
            <div className="lsp-row lsp-row--highlight">
              <span className="lsp-row-label">Tasa de interés</span>
              <span className="lsp-tag lsp-tag--warning">
                {calculation.interest_rate_percent}% <small>por quincena</small>
              </span>
            </div>
            
            <div className="lsp-row lsp-row--highlight">
              <span className="lsp-row-label">Comisión asociado</span>
              <span className="lsp-tag lsp-tag--info">
                {calculation.commission_rate_percent}% 
                <small>({formatCurrency(calculation.commission_per_payment)}/qna)</small>
              </span>
            </div>
          </div>
        </div>

        {/* Card 2: Totales del Cliente */}
        <div className="lsp-card lsp-card--client">
          <div className="lsp-card-header">
            <div className="lsp-card-icon lsp-card-icon--client">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <path d="M20 21v-2a4 4 0 00-4-4H8a4 4 0 00-4 4v2"/>
                <circle cx="12" cy="7" r="4"/>
              </svg>
            </div>
            <h3 className="lsp-card-title">Totales del Cliente</h3>
          </div>
          
          <div className="lsp-card-body">
            {/* Pago quincenal destacado */}
            <div className="lsp-featured">
              <span className="lsp-featured-label">Pago quincenal</span>
              <span className="lsp-featured-value lsp-featured-value--client">
                {formatCurrency(calculation.biweekly_payment)}
              </span>
            </div>
            
            <div className="lsp-row">
              <span className="lsp-row-label">Total a pagar</span>
              <span className="lsp-row-value">
                {formatCurrency(calculation.total_payment)}
              </span>
            </div>
            
            <div className="lsp-row">
              <span className="lsp-row-label">Total de intereses</span>
              <span className="lsp-row-value lsp-row-value--muted">
                {formatCurrency(calculation.total_interest)}
              </span>
            </div>
          </div>
        </div>

        {/* Card 3: Totales del Asociado */}
        <div className="lsp-card lsp-card--associate">
          <div className="lsp-card-header">
            <div className="lsp-card-icon lsp-card-icon--associate">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <path d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4"/>
              </svg>
            </div>
            <h3 className="lsp-card-title">Totales del Asociado</h3>
          </div>
          
          <div className="lsp-card-body">
            {/* Pago quincenal destacado */}
            <div className="lsp-featured">
              <span className="lsp-featured-label">Pago quincenal a CrediCuenta</span>
              <span className="lsp-featured-value lsp-featured-value--associate">
                {formatCurrency(calculation.associate_payment)}
              </span>
            </div>
            
            <div className="lsp-row">
              <span className="lsp-row-label">Total a pagar a CrediCuenta</span>
              <span className="lsp-row-value">
                {formatCurrency(calculation.associate_total)}
              </span>
            </div>
            
            {/* Ganancia destacada */}
            <div className="lsp-earnings">
              <div className="lsp-earnings-content">
                <span className="lsp-earnings-label">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" width="16" height="16">
                    <path d="M12 2v20M17 5H9.5a3.5 3.5 0 000 7h5a3.5 3.5 0 010 7H6"/>
                  </svg>
                  Comisión total ganada
                </span>
                <span className="lsp-earnings-value">
                  {formatCurrency(calculation.total_commission)}
                </span>
              </div>
            </div>
          </div>
        </div>
        
      </div>
    </div>
  );
};

export default LoanSummaryPreview;
