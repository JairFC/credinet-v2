/**
 * PeriodoTimeline - Navegación horizontal de períodos estilo NU Bank
 * 
 * Muestra una línea de tiempo horizontal con:
 * - Navegación con flechas izquierda/derecha
 * - Período activo destacado en el centro
 * - Indicadores visuales de estado según ciclo de vida
 * - Animaciones suaves de transición
 * 
 * Estados del Período (Flujo):
 * PENDING → CUTOFF → COLLECTING → SETTLING → CLOSED
 * 
 * 1. PENDING    - Períodos futuros con pagos pre-asignados
 * 3. CUTOFF     - BORRADOR: Corte automático, statements en revisión
 * 4. COLLECTING - EN COBRO: Cierre manual, fase de cobro a asociados
 * 6. SETTLING   - LIQUIDACIÓN: Revisión de deuda antes de cierre definitivo
 * 5. CLOSED     - Período archivado definitivamente
 */

import React from 'react';
import './PeriodoTimeline.css';

// Mapeo de estados a iconos y colores
// Flujo: PENDING → CUTOFF → COLLECTING → SETTLING → CLOSED
const STATUS_CONFIG = {
  1: { label: 'PENDIENTE', icon: '📋', class: 'status-pending' },
  2: { label: 'DEPRECADO', icon: '⚠️', class: 'status-pending' }, // ACTIVE deprecado
  3: { label: 'BORRADOR', icon: '✂️', class: 'status-cutoff' },
  4: { label: 'EN COBRO', icon: '💰', class: 'status-collecting' },
  5: { label: 'CERRADO', icon: '✅', class: 'status-closed' },
  6: { label: 'LIQUIDACIÓN', icon: '⚖️', class: 'status-settling' }
};

// Mantener el código del período tal como está (Dec08-2025)
// Este código representa la FECHA DE CORTE (fin del período + 1 día)
const formatPeriodCode = (code) => {
  if (!code) return '';
  return code; // Mantener formato original: Dec08-2025
};

// Formatea el código para mostrar en español de forma más legible
const formatPeriodCodeShort = (code) => {
  if (!code) return '';
  // Format: Dec08-2025 → DIC08
  const match = code.match(/([A-Za-z]+)(\d+)-\d+/);
  if (!match) return code.substring(0, 5);

  const monthMap = {
    'Jan': 'ENE', 'Feb': 'FEB', 'Mar': 'MAR', 'Apr': 'ABR',
    'May': 'MAY', 'Jun': 'JUN', 'Jul': 'JUL', 'Aug': 'AGO',
    'Sep': 'SEP', 'Oct': 'OCT', 'Nov': 'NOV', 'Dec': 'DIC'
  };

  return `${monthMap[match[1]] || match[1]}${match[2]}`;
};

// Formatea fechas en formato corto
const formatDate = (dateStr) => {
  if (!dateStr) return '';
  const date = new Date(dateStr + 'T12:00:00'); // Evitar problemas de timezone
  return date.toLocaleDateString('es-MX', {
    day: '2-digit',
    month: 'short'
  }).toLowerCase();
};

// Formatea rango de fechas: "23 nov - 07 dic"
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
      <div className="periodo-timeline-container">
        <div className="timeline-loading">
          <div className="timeline-skeleton"></div>
        </div>
      </div>
    );
  }

  if (!periods || periods.length === 0) {
    return (
      <div className="periodo-timeline-container">
        <div className="timeline-empty">
          <span className="empty-icon">📅</span>
          <p>No hay períodos disponibles</p>
        </div>
      </div>
    );
  }

  // Encontrar índice del período seleccionado
  // NOTA: periods está ordenado por fecha DESCENDENTE (más reciente/futuro primero)
  const selectedIndex = periods.findIndex(p => p.id === selectedPeriod?.id);

  // Navegación intuitiva:
  // - Flecha IZQUIERDA (←) = ir al PASADO (índice mayor = fechas más antiguas)
  // - Flecha DERECHA (→) = ir al FUTURO (índice menor = fechas más recientes)
  const olderPeriod = selectedIndex < periods.length - 1 ? periods[selectedIndex + 1] : null;
  const newerPeriod = selectedIndex > 0 ? periods[selectedIndex - 1] : null;

  // Navegar al pasado (flecha izquierda)
  const handleGoPast = () => {
    if (olderPeriod) {
      onSelectPeriod(olderPeriod);
    }
  };

  // Navegar al futuro (flecha derecha)
  const handleGoFuture = () => {
    if (newerPeriod) {
      onSelectPeriod(newerPeriod);
    }
  };

  const statusInfo = STATUS_CONFIG[selectedPeriod?.status_id] || STATUS_CONFIG[1];

  return (
    <div className="periodo-timeline-container">
      {/* Navegación Principal */}
      <div className="timeline-navigator">
        {/* Flecha Izquierda - Ir al PASADO (períodos más antiguos) */}
        <button
          className={`nav-arrow nav-prev ${!olderPeriod ? 'disabled' : ''}`}
          onClick={handleGoPast}
          disabled={!olderPeriod}
          title={olderPeriod ? `← ${olderPeriod.period_code} (anterior)` : 'No hay período anterior'}
        >
          <span className="arrow-icon">‹</span>
          {olderPeriod && (
            <span className="nav-label">{olderPeriod.period_code}</span>
          )}
        </button>

        {/* Período Central (Seleccionado) */}
        <div className="timeline-center">
          <div className="center-period">
            <div className="period-indicator">
              <span className={`status-dot ${statusInfo.class}`}></span>
            </div>
            <div className="period-main-info">
              <span className="period-number">PERÍODO #{selectedPeriod?.id}</span>
              <h2 className="period-code">{selectedPeriod?.period_code}</h2>
              <div className="period-dates-row">
                <span className="date-range">
                  📅 {formatDateRange(selectedPeriod?.start_date, selectedPeriod?.end_date)}
                </span>
              </div>
            </div>
            <div className={`period-status-chip ${statusInfo.class}`}>
              <span className="status-icon">{statusInfo.icon}</span>
              <span className="status-label">{statusInfo.label}</span>
            </div>
          </div>

          {/* Indicador de progreso en línea de tiempo */}
          <div className="timeline-progress">
            <div className="progress-line">
              <div className="progress-nodes">
                {/* Invertir el orden para mostrar: PASADO ← PRESENTE → FUTURO */}
                {/* periods está ordenado descendente (futuro primero), así que revertimos para visual */}
                {periods.slice(Math.max(0, selectedIndex - 2), selectedIndex + 3)
                  .reverse() // Invertir para mostrar cronológicamente de izq a der
                  .map((period) => {
                    const isSelected = period.id === selectedPeriod?.id;
                    const periodIdx = periods.indexOf(period);
                    const isFuture = periodIdx < selectedIndex; // Índice menor = más futuro
                    const isPast = periodIdx > selectedIndex;   // Índice mayor = más pasado
                    const periodStatus = STATUS_CONFIG[period.status_id] || STATUS_CONFIG[1];

                    return (
                      <button
                        key={period.id}
                        className={`progress-node ${isSelected ? 'active' : ''} ${isFuture ? 'future' : ''} ${isPast ? 'past' : ''}`}
                        onClick={() => onSelectPeriod(period)}
                        title={`${period.period_code} (${formatDateRange(period.start_date, period.end_date)})`}
                      >
                        <span className={`node-dot ${periodStatus.class}`}></span>
                        <span className="node-label">{formatPeriodCodeShort(period.period_code)}</span>
                      </button>
                    );
                  })}
              </div>
            </div>
          </div>
        </div>

        {/* Flecha Derecha - Ir al FUTURO (períodos más recientes) */}
        <button
          className={`nav-arrow nav-next ${!newerPeriod ? 'disabled' : ''}`}
          onClick={handleGoFuture}
          disabled={!newerPeriod}
          title={newerPeriod ? `${newerPeriod.period_code} (siguiente) →` : 'No hay período siguiente'}
        >
          {newerPeriod && (
            <span className="nav-label">{newerPeriod.period_code}</span>
          )}
          <span className="arrow-icon">›</span>
        </button>
      </div>

      {/* Stats rápidos del período */}
      {selectedPeriod && (
        <div className="timeline-quick-stats">
          <div className="quick-stat">
            <span className="stat-icon">📊</span>
            <span className="stat-text">
              {periodStats?.associateCount || selectedPeriod.total_statements || 0} estados de cuenta
            </span>
          </div>
          <div className="quick-stat">
            <span className="stat-icon">👥</span>
            <span className="stat-text">
              {periodStats?.associateCountTotal || selectedPeriod.total_associates || 0} asociados
            </span>
          </div>
          <div className="quick-stat">
            <span className="stat-icon">📑</span>
            <span className="stat-text">
              {periodStats?.paymentCount || selectedPeriod.total_payments || 0} pagos
            </span>
          </div>
        </div>
      )}
    </div>
  );
}
