/**
 * RelacionAsociadoCard - Tarjeta SIMPLIFICADA de estado de cuenta por asociado
 * 
 * Versión optimizada para rendimiento:
 * - Sin carga de pagos en la lista (se cargan on-demand al ver detalles)
 * - Sin sección expandible pesada
 * - Solo muestra resumen compacto y botón para ver detalles
 */

import React from 'react';
import './RelacionAsociadoCard.css';

// Configuración de estados de statement (IDs según BD)
const STATEMENT_STATUS = {
  6: { label: 'BORRADOR', class: 'draft', icon: '📝' },
  7: { label: 'EN COBRO', class: 'collecting', icon: '💰' },
  9: { label: 'LIQUIDACIÓN', class: 'settling', icon: '⚖️' },
  10: { label: 'CERRADO', class: 'closed', icon: '✅' },
  3: { label: 'PAGADO', class: 'paid', icon: '✅' },
  4: { label: 'PARCIAL', class: 'partial', icon: '⚡' },
  5: { label: 'VENCIDO', class: 'overdue', icon: '⚠️' },
  8: { label: 'ABSORBIDO', class: 'absorbed', icon: '📦' }
};

// Formatea moneda
const formatMoney = (amount) => {
  if (amount === null || amount === undefined) return '$0.00';
  return new Intl.NumberFormat('es-MX', {
    style: 'currency',
    currency: 'MXN'
  }).format(amount);
};

// Calcula el porcentaje de progreso
const calculateProgress = (paid, total) => {
  if (!total || total === 0) return 0;
  return Math.min(100, Math.round((paid / total) * 100));
};

export default function RelacionAsociadoCard({
  statement,
  onViewPayments,
  onMakePayment,
  isPreview = false,
  hasPayments = true
}) {
  // Datos del statement
  const {
    associate_name,
    associate_id,
    associate_code,
    total_collected = 0,
    total_commission = 0,
    total_to_credicuenta = 0,
    total_paid = 0,
    status_id = 6,
    payment_count = 0,
    late_fee = 0,
  } = statement || {};

  const statusInfo = STATEMENT_STATUS[status_id] || STATEMENT_STATUS[6];
  const progress = calculateProgress(total_paid, total_to_credicuenta + late_fee);
  const pendingBalance = (total_to_credicuenta + late_fee) - total_paid;

  // Generar iniciales del nombre
  const getInitials = (name) => {
    if (!name) return '??';
    const parts = name.split(' ');
    if (parts.length >= 2) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return name.substring(0, 2).toUpperCase();
  };

  // Si no tiene pagos, mostrar tarjeta mínima
  if (!hasPayments) {
    return (
      <div className="asociado-card no-payments">
        <div className="card-header">
          <div className="associate-info">
            <div className="associate-avatar inactive">
              <span className="avatar-initials">{getInitials(associate_name)}</span>
            </div>
            <div className="associate-details">
              <h3 className="associate-name">{associate_name || 'Asociado'}</h3>
              <span className="associate-meta">
                {associate_code && <span className="code">#{associate_code}</span>}
              </span>
            </div>
          </div>
          <div className="card-summary">
            <div className="no-payments-badge">
              <span className="badge-icon">📭</span>
              <span className="badge-text">Sin pagos en este período</span>
            </div>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className={`asociado-card simple ${isPreview ? 'preview-mode' : ''}`}>
      {/* Header de la tarjeta */}
      <div className="card-header">
        <div className="associate-info">
          <div className="associate-avatar">
            <span className="avatar-initials">{getInitials(associate_name)}</span>
          </div>
          <div className="associate-details">
            <h3 className="associate-name">{associate_name || 'Asociado'}</h3>
            <span className="associate-meta">
              {associate_code && <span className="code">#{associate_code}</span>}
              <span className="payment-count">📑 {payment_count} pagos</span>
            </span>
          </div>
        </div>

        <div className="card-summary">
          {/* Comisión ganada */}
          <div className="summary-amount commission-amount">
            <span className="amount-label">Comisión</span>
            <span className="amount-value success">{formatMoney(total_commission)}</span>
          </div>

          {/* Monto Total a Pagar */}
          <div className="summary-amount main-amount">
            <span className="amount-label">A Pagar</span>
            <span className="amount-value">{formatMoney(total_to_credicuenta)}</span>
          </div>

          {/* Saldo Pendiente */}
          <div className={`summary-amount balance-amount ${pendingBalance > 0 ? 'pending' : 'clear'}`}>
            <span className="amount-label">Saldo</span>
            <span className="amount-value">{formatMoney(pendingBalance)}</span>
          </div>

          {/* Status Badge */}
          <div className={`status-badge ${statusInfo.class}`}>
            <span className="status-icon">{statusInfo.icon}</span>
            <span className="status-text">{statusInfo.label}</span>
          </div>

          {/* Botón Abonar (solo si hay saldo pendiente) */}
          {pendingBalance > 0 && onMakePayment && (
            <button
              className="btn-make-payment"
              onClick={(e) => {
                e.stopPropagation();
                onMakePayment(statement);
              }}
              title="Registrar abono"
            >
              <span>💳</span>
              <span>Abonar</span>
            </button>
          )}

          {/* Botón Ver Detalles */}
          <button
            className="btn-view-details"
            onClick={(e) => {
              e.stopPropagation();
              onViewPayments && onViewPayments(statement);
            }}
            title="Ver detalles de pagos"
          >
            <span>Ver detalles</span>
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
              <path d="M5 12h14M12 5l7 7-7 7" />
            </svg>
          </button>
        </div>
      </div>

      {/* Barra de Progreso */}
      <div className="progress-section">
        <div className="progress-bar">
          <div
            className={`progress-fill ${statusInfo.class}`}
            style={{ width: `${progress}%` }}
          ></div>
        </div>
        <div className="progress-labels">
          <span className="progress-paid">Abonado: {formatMoney(total_paid)}</span>
          <span className="progress-percent">{progress}%</span>
        </div>
      </div>
    </div>
  );
}
