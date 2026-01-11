/**
 * PeriodoTimeline - Navegación horizontal de períodos
 * Prefijo: ptl- para evitar conflictos CSS
 */

import React from 'react';
import './PeriodoTimeline.css';

const STATUS_CONFIG = {
  1: { label: 'PENDIENTE', icon: '📋', class: 'pending' },
  2: { label: 'DEPRECADO', icon: '⚠️', class: 'pending' },
  3: { label: 'BORRADOR', icon: '✂️', class: 'cutoff' },
  4: { label: 'EN COBRO', icon: '💰', class: 'collecting' },
  5: { label: 'CERRADO', icon: '✅', class: 'closed' },
  6: { label: 'LIQUIDACIÓN', icon: '⚖️', class: 'settling' }
};

const formatPeriodCodeShort = (code) => {
  if (!code) return '';
  const match = code.match(/([A-Za-z]+)(\d+)-\d+/);
  if (!match) return code.substring(0, 5);
  const monthMap = {
    'Jan': 'ENE', 'Feb': 'FEB', 'Mar': 'MAR', 'Apr': 'ABR',
    'May': 'MAY', 'Jun': 'JUN', 'Jul': 'JUL', 'Aug': 'AGO',
    'Sep': 'SEP', 'Oct': 'OCT', 'Nov': 'NOV', 'Dec': 'DIC'
  };
  return `${monthMap[match[1]] || match[1]}${match[2]}`;
};

const formatDate = (dateStr) => {
  if (!dateStr) return '';
  const date = new Date(dateStr + 'T12:00:00');
  return date.toLocaleDateString('es-MX', { day: '2-digit', month: 'short' }).toLowerCase();
};

const formatDateRange = (startDate, endDate) => {
  if (!startDate || !endDate) return '';
  return `${formatDate(startDate)} - ${formatDate(endDate)}`;
};

export default function PeriodoTimeline({
  periods,
  selectedPeriod,
  onSelectPeriod,
  loading = false,
  periodStats = null
}) {
  if (loading) {
    return (
      <div className="ptl-container">
        <div className="ptl-loading">
          <div className="ptl-skeleton" />
        </div>
      </div>
    );
  }

  if (!periods || periods.length === 0) {
    return (
      <div className="ptl-container">
        <div className="ptl-empty">
          <span>📅</span>
          <p>No hay períodos disponibles</p>
        </div>
      </div>
    );
  }

  const selectedIndex = periods.findIndex(p => p.id === selectedPeriod?.id);
  const olderPeriod = selectedIndex < periods.length - 1 ? periods[selectedIndex + 1] : null;
  const newerPeriod = selectedIndex > 0 ? periods[selectedIndex - 1] : null;
  const statusInfo = STATUS_CONFIG[selectedPeriod?.status_id] || STATUS_CONFIG[1];

  return (
    <div className="ptl-container">
      <div className="ptl-nav">
        {/* Flecha Izquierda - Pasado */}
        <button
          className={`ptl-arrow ${!olderPeriod ? 'ptl-arrow--disabled' : ''}`}
          onClick={() => olderPeriod && onSelectPeriod(olderPeriod)}
          disabled={!olderPeriod}
        >
          <span className="ptl-arrow-icon">‹</span>
          {olderPeriod && <span className="ptl-arrow-label">{olderPeriod.period_code}</span>}
        </button>

        {/* Centro - Período Actual */}
        <div className="ptl-center">
          <div className="ptl-current">
            <div className={`ptl-dot ptl-dot--${statusInfo.class}`} />
            <div className="ptl-info">
              <span className="ptl-period-num">PERÍODO #{selectedPeriod?.id}</span>
              <h2 className="ptl-period-code">{selectedPeriod?.period_code}</h2>
              <span className="ptl-dates">📅 {formatDateRange(selectedPeriod?.start_date, selectedPeriod?.end_date)}</span>
            </div>
            <span className={`ptl-status ptl-status--${statusInfo.class}`}>
              <span>{statusInfo.icon}</span>
              {statusInfo.label}
            </span>
          </div>

          {/* Mini timeline */}
          <div className="ptl-timeline">
            <div className="ptl-timeline-line" />
            <div className="ptl-timeline-nodes">
              {periods.slice(Math.max(0, selectedIndex - 2), selectedIndex + 3)
                .reverse()
                .map((period) => {
                  const isSelected = period.id === selectedPeriod?.id;
                  const pStatus = STATUS_CONFIG[period.status_id] || STATUS_CONFIG[1];
                  return (
                    <button
                      key={period.id}
                      className={`ptl-node ${isSelected ? 'ptl-node--active' : ''}`}
                      onClick={() => onSelectPeriod(period)}
                    >
                      <span className={`ptl-node-dot ptl-node-dot--${pStatus.class}`} />
                      <span className="ptl-node-label">{formatPeriodCodeShort(period.period_code)}</span>
                    </button>
                  );
                })}
            </div>
          </div>
        </div>

        {/* Flecha Derecha - Futuro */}
        <button
          className={`ptl-arrow ptl-arrow--next ${!newerPeriod ? 'ptl-arrow--disabled' : ''}`}
          onClick={() => newerPeriod && onSelectPeriod(newerPeriod)}
          disabled={!newerPeriod}
        >
          {newerPeriod && <span className="ptl-arrow-label">{newerPeriod.period_code}</span>}
          <span className="ptl-arrow-icon">›</span>
        </button>
      </div>

      {/* Quick Stats */}
      <div className="ptl-stats">
        <span className="ptl-stat">📊 {periodStats?.associateCount || 0} estados de cuenta</span>
        <span className="ptl-stat">👥 {periodStats?.associateCountTotal || 0} asociados</span>
        <span className="ptl-stat">📑 {periodStats?.paymentCount || 0} pagos</span>
      </div>
    </div>
  );
}
