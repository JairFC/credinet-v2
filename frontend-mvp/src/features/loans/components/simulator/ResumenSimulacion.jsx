/**
 * ResumenSimulacion
 * Muestra el resumen ejecutivo del préstamo simulado
 */
import './ResumenSimulacion.css';

export default function ResumenSimulacion({ summary }) {
  if (!summary) return null;

  const formatCurrency = (value) => {
    return new Intl.NumberFormat('es-MX', {
      style: 'currency',
      currency: 'MXN',
    }).format(value);
  };

  const formatDate = (dateStr) => {
    const date = new Date(dateStr);
    return new Intl.DateTimeFormat('es-MX', {
      day: '2-digit',
      month: '2-digit',
      year: 'numeric',
    }).format(date);
  };

  return (
    <div className="resumen-simulacion">
      <h3>📋 Resumen del Préstamo</h3>

      <div className="resumen-grid">
        {/* Información del Préstamo */}
        <div className="resumen-card card-info">
          <h4>ℹ️ Información</h4>
          <div className="resumen-item">
            <span className="label">Monto solicitado:</span>
            <span className="value">{formatCurrency(summary.loan_amount)}</span>
          </div>
          <div className="resumen-item">
            <span className="label">Plazo:</span>
            <span className="value">
              {summary.term_biweeks} quincenas ({summary.term_months} meses)
            </span>
          </div>
          <div className="resumen-item">
            <span className="label">Perfil:</span>
            <span className="value">{summary.profile_name}</span>
          </div>
          <div className="resumen-item">
            <span className="label">Tasa de interés:</span>
            <span className="value highlight-rate">{summary.interest_rate_percent}%</span>
          </div>
          <div className="resumen-item">
            <span className="label">Comisión del asociado:</span>
            <span className="value highlight-rate">{summary.commission_rate_percent}%</span>
          </div>
          <div className="resumen-item">
            <span className="label">Fecha de aprobación:</span>
            <span className="value">{formatDate(summary.approval_date)}</span>
          </div>
          <div className="resumen-item">
            <span className="label">Fecha de finalización:</span>
            <span className="value">{formatDate(summary.final_payment_date)}</span>
          </div>
        </div>

        {/* Totales del Cliente */}
        <div className="resumen-card card-client">
          <h4>👤 Totales del Cliente</h4>
          <div className="resumen-item">
            <span className="label">Pago quincenal:</span>
            <span className="value big">{formatCurrency(summary.client_totals.biweekly_payment)}</span>
          </div>
          <div className="resumen-item">
            <span className="label">Total a pagar:</span>
            <span className="value big">{formatCurrency(summary.client_totals.total_payment)}</span>
          </div>
          <div className="resumen-item">
            <span className="label">Total de intereses:</span>
            <span className="value">{formatCurrency(summary.client_totals.total_interest)}</span>
          </div>
        </div>

        {/* Totales del Asociado */}
        <div className="resumen-card card-associate">
          <h4>🏢 Totales del Asociado</h4>
          <div className="resumen-item">
            <span className="label">Pago quincenal:</span>
            <span className="value big">{formatCurrency(summary.associate_totals.biweekly_payment)}</span>
          </div>
          <div className="resumen-item">
            <span className="label">Total a pagar a CrediCuenta:</span>
            <span className="value big">{formatCurrency(summary.associate_totals.total_payment)}</span>
          </div>
          <div className="resumen-item">
            <span className="label">Comisión total ganada:</span>
            <span className="value highlight-commission">
              {formatCurrency(summary.associate_totals.total_commission)}
            </span>
          </div>
        </div>
      </div>
    </div>
  );
}
