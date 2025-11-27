/**
 * TablaAmortizacion
 * Muestra el desglose pago por pago con fechas y períodos de corte
 */
import './TablaAmortizacion.css';

export default function TablaAmortizacion({ payments }) {
  if (!payments || payments.length === 0) return null;

  const formatCurrency = (value) => {
    return new Intl.NumberFormat('es-MX', {
      style: 'currency',
      currency: 'MXN',
      minimumFractionDigits: 2,
      maximumFractionDigits: 2,
    }).format(value);
  };

  const formatDate = (dateStr) => {
    // Parsear fecha en UTC para evitar problemas de timezone
    // Si la fecha viene como "2025-12-15" (sin hora), agregarle la hora UTC
    const date = new Date(dateStr + 'T12:00:00Z');
    return new Intl.DateTimeFormat('es-MX', {
      day: '2-digit',
      month: '2-digit',
      year: 'numeric',
      timeZone: 'UTC', // Formatear en UTC para mantener el día correcto
    }).format(date);
  };

  // Calcular totales
  const totals = payments.reduce((acc, payment) => ({
    client_payment: acc.client_payment + parseFloat(payment.client_payment || 0),
    associate_payment: acc.associate_payment + parseFloat(payment.associate_payment || 0),
    commission: acc.commission + parseFloat(payment.commission || 0),
  }), { client_payment: 0, associate_payment: 0, commission: 0 });

  return (
    <div className="tabla-amortizacion">
      <h3>📅 Tabla de Amortización ({payments.length} pagos)</h3>

      <div className="table-container">
        <table className="amortization-table">
          <thead>
            <tr>
              <th>#</th>
              <th>Fecha de Pago</th>
              <th>Período de Corte</th>
              <th className="currency">Pago Cliente</th>
              <th className="currency">Pago Asociado</th>
              <th className="currency">Comisión</th>
              <th className="currency">Saldo Pendiente</th>
            </tr>
          </thead>
          <tbody>
            {payments.map((payment, index) => (
              <tr
                key={payment.payment_number}
                className={index === 0 ? 'first-payment' : index === payments.length - 1 ? 'last-payment' : ''}
              >
                <td className="payment-number">{payment.payment_number}</td>
                <td className="payment-date">{formatDate(payment.payment_date)}</td>
                <td className="cut-period">{payment.cut_period}</td>
                <td className="currency client-value">{formatCurrency(payment.client_payment)}</td>
                <td className="currency associate-value">{formatCurrency(payment.associate_payment)}</td>
                <td className="currency commission-value">{formatCurrency(payment.commission)}</td>
                <td className="currency balance-value">
                  {formatCurrency(Math.max(0, payment.remaining_balance))}
                </td>
              </tr>
            ))}
          </tbody>
          <tfoot>
            <tr>
              <td colSpan="3" className="totals-label">TOTALES</td>
              <td className="currency total-value">{formatCurrency(totals.client_payment)}</td>
              <td className="currency total-value">{formatCurrency(totals.associate_payment)}</td>
              <td className="currency total-value">{formatCurrency(totals.commission)}</td>
              <td></td>
            </tr>
          </tfoot>
        </table>
      </div>
    </div>
  );
}
