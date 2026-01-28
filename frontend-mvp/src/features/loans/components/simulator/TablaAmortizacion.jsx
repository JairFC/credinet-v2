/**
 * TablaAmortizacion
 * Muestra el desglose pago por pago con fechas y períodos de corte
 * 
 * Columnas:
 * - Saldo Cliente: Capital restante del préstamo
 * - Saldo Pendiente: Total por pagar (incluyendo intereses futuros)
 * - Restante Asociado: Deuda real hacia CrediCuenta
 */
import { formatDateOnly } from '@/shared/utils/dateUtils';
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

  // Usar formatDateOnly centralizado para evitar problemas de timezone
  const formatDate = (dateStr) => formatDateOnly(dateStr, { monthFormat: 'numeric' });

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
              <th className="currency">Restante Asociado</th>
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
                  {formatCurrency(payment.total_pending_balance ?? payment.remaining_balance ?? 0)}
                </td>
                <td className="currency balance-value associate-balance">
                  {formatCurrency(payment.associate_total_pending ?? payment.associate_remaining_balance ?? 0)}
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
              <td colSpan="2"></td>
            </tr>
          </tfoot>
        </table>
      </div>
    </div>
  );
}
