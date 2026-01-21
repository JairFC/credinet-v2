/**
 * RelacionAsociadoCard - Tarjeta profesional de estado de cuenta por asociado
 * Prefijo: rac- para evitar conflictos CSS
 */

import React from 'react';
import './RelacionAsociadoCard.css';

// Configuración de estados de statement (IDs según BD)
const STATEMENT_STATUS = {
  6: { label: 'Borrador', class: 'draft', icon: '📝' },
  7: { label: 'En cobro', class: 'collecting', icon: '💰' },
  9: { label: 'Liquidación', class: 'settling', icon: '⚖️' },
  10: { label: 'Cerrado', class: 'closed', icon: '✓' },
  3: { label: 'Pagado', class: 'paid', icon: '✓' },
  4: { label: 'Parcial', class: 'partial', icon: '◐' },
  5: { label: 'Vencido', class: 'overdue', icon: '!' },
  8: { label: 'Absorbido', class: 'absorbed', icon: '▣' }
};

const formatMoney = (amount) => {
  if (amount === null || amount === undefined) return '$0.00';
  return new Intl.NumberFormat('es-MX', {
    style: 'currency',
    currency: 'MXN'
  }).format(amount);
};

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

  const getInitials = (name) => {
    if (!name) return '??';
    const parts = name.split(' ');
    if (parts.length >= 2) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return name.substring(0, 2).toUpperCase();
  };

  // Tarjeta sin pagos
  if (!hasPayments) {
    return (
      <div className="rac-card rac-card--no-payments">
        <div className="rac-content">
          <div className="rac-left">
            <div className="rac-avatar rac-avatar--inactive">
              {getInitials(associate_name)}
            </div>
            <div className="rac-info">
              <span className="rac-name">{associate_name || 'Asociado'}</span>
              <span className="rac-meta">
                {associate_code && <span className="rac-code">#{associate_code}</span>}
              </span>
            </div>
          </div>
          <div className="rac-right">
            <span className="rac-empty-badge">📭 Sin pagos en este período</span>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className={`rac-card ${isPreview ? 'rac-card--preview' : ''}`}>
      <div className="rac-content">
        {/* Izquierda: Avatar + Info */}
        <div className="rac-left">
          <div className="rac-avatar">
            {getInitials(associate_name)}
          </div>
          <div className="rac-info">
            <span className="rac-name">{associate_name || 'Asociado'}</span>
            <span className="rac-meta">
              {associate_code && <span className="rac-code">#{associate_code}</span>}
              <span className="rac-payments">📑 {payment_count} pagos</span>
            </span>
          </div>
        </div>

        {/* Centro: Montos */}
        <div className="rac-amounts">
          <div className="rac-amount">
            <span className="rac-amount-label">COMISIÓN</span>
            <span className="rac-amount-value rac-amount-value--success">{formatMoney(total_commission)}</span>
          </div>
          <div className="rac-amount">
            <span className="rac-amount-label">A PAGAR</span>
            <span className="rac-amount-value">{formatMoney(total_to_credicuenta)}</span>
          </div>
          <div className="rac-amount">
            <span className="rac-amount-label">SALDO</span>
            <span className={`rac-amount-value ${pendingBalance > 0 ? 'rac-amount-value--danger' : 'rac-amount-value--success'}`}>
              {formatMoney(pendingBalance)}
            </span>
          </div>
        </div>

        {/* Derecha: Estado + Acciones */}
        <div className="rac-right">
          <span className={`rac-status rac-status--${statusInfo.class}`}>
            <span className="rac-status-icon">{statusInfo.icon}</span>
            {statusInfo.label}
          </span>
          
          {pendingBalance > 0 && onMakePayment && (
            <button
              className="rac-btn rac-btn--primary"
              onClick={(e) => {
                e.stopPropagation();
                onMakePayment(statement);
              }}
            >
              💳 Abonar
            </button>
          )}
          
          <button
            className="rac-btn rac-btn--secondary"
            onClick={(e) => {
              e.stopPropagation();
              onViewPayments && onViewPayments(statement);
            }}
          >
            Ver detalles →
          </button>
        </div>
      </div>

      {/* Barra de Progreso */}
      <div className="rac-progress">
        <div className="rac-progress-bar">
          <div 
            className={`rac-progress-fill rac-progress-fill--${statusInfo.class}`}
            style={{ width: `${progress}%` }}
          />
        </div>
        <div className="rac-progress-info">
          <span>Abonado: {formatMoney(total_paid)}</span>
          <span>{progress}%</span>
        </div>
      </div>
    </div>
  );
}
