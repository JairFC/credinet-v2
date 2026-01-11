/**
 * generateStatementPDF.js - Generador de PDF para Estados de Cuenta
 * 
 * Esta utilidad genera un PDF profesional del estado de cuenta
 * usando una ventana de impresión optimizada sin dependencias externas.
 * 
 * Funcionalidades:
 * - Genera documento HTML optimizado para impresión
 * - Incluye estilos embebidos para consistencia
 * - Formato profesional con logo y membrete
 * - Soporta tabla de pagos y resumen de abonos
 */

// Formateadores
const formatMoney = (amount) => {
  if (amount === null || amount === undefined) return '$0.00';
  return new Intl.NumberFormat('es-MX', {
    style: 'currency',
    currency: 'MXN'
  }).format(amount);
};

const formatDate = (dateStr) => {
  if (!dateStr) return '-';
  const date = new Date(dateStr);
  return date.toLocaleDateString('es-MX', {
    day: '2-digit',
    month: 'short',
    year: 'numeric'
  });
};

const formatDateTime = (dateStr) => {
  if (!dateStr) return '-';
  const date = new Date(dateStr);
  return date.toLocaleString('es-MX', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
    hour12: true
  });
};

// Estilos embebidos para el PDF
const getPDFStyles = () => `
  * {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
  }

  @page {
    size: letter;
    margin: 1.5cm;
  }

  body {
    font-family: 'Segoe UI', -apple-system, BlinkMacSystemFont, sans-serif;
    font-size: 11px;
    line-height: 1.5;
    color: #1f2937;
    background: white;
  }

  .pdf-container {
    max-width: 100%;
    padding: 0;
  }

  /* Header del documento */
  .pdf-header {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    padding-bottom: 20px;
    border-bottom: 3px solid #6366f1;
    margin-bottom: 24px;
  }

  .pdf-logo {
    display: flex;
    align-items: center;
    gap: 12px;
  }

  .pdf-logo-icon {
    width: 48px;
    height: 48px;
    background: linear-gradient(135deg, #6366f1, #8b5cf6);
    border-radius: 10px;
    display: flex;
    align-items: center;
    justify-content: center;
    color: white;
    font-size: 24px;
    font-weight: 700;
  }

  .pdf-company-name {
    font-size: 22px;
    font-weight: 700;
    color: #1f2937;
    letter-spacing: -0.5px;
  }

  .pdf-company-tagline {
    font-size: 10px;
    color: #6b7280;
  }

  .pdf-doc-info {
    text-align: right;
  }

  .pdf-doc-title {
    font-size: 16px;
    font-weight: 700;
    color: #6366f1;
    text-transform: uppercase;
    letter-spacing: 1px;
  }

  .pdf-doc-meta {
    font-size: 10px;
    color: #6b7280;
    margin-top: 4px;
  }

  /* Info del asociado */
  .pdf-associate-section {
    background: #f8fafc;
    border: 1px solid #e5e7eb;
    border-radius: 8px;
    padding: 16px 20px;
    margin-bottom: 20px;
  }

  .pdf-associate-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 12px;
  }

  .pdf-associate-name {
    font-size: 16px;
    font-weight: 700;
    color: #1f2937;
  }

  .pdf-associate-code {
    font-size: 11px;
    font-family: 'Courier New', monospace;
    background: #6366f1;
    color: white;
    padding: 4px 10px;
    border-radius: 4px;
    font-weight: 600;
  }

  .pdf-period-badge {
    font-size: 11px;
    background: #fef3c7;
    color: #d97706;
    padding: 4px 10px;
    border-radius: 4px;
    font-weight: 600;
    margin-left: 8px;
  }

  .pdf-status-badge {
    padding: 6px 14px;
    border-radius: 6px;
    font-size: 11px;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.5px;
  }

  .pdf-status-badge.collecting { background: #dbeafe; color: #2563eb; }
  .pdf-status-badge.settling { background: #fef3c7; color: #d97706; }
  .pdf-status-badge.closed, .pdf-status-badge.paid { background: #d1fae5; color: #059669; }
  .pdf-status-badge.overdue { background: #fee2e2; color: #dc2626; }
  .pdf-status-badge.draft { background: #f3f4f6; color: #6b7280; }

  /* Summary Grid */
  .pdf-summary-grid {
    display: grid;
    grid-template-columns: repeat(5, 1fr);
    gap: 12px;
    margin-bottom: 24px;
  }

  .pdf-summary-card {
    background: white;
    border: 1px solid #e5e7eb;
    border-radius: 8px;
    padding: 12px 14px;
    text-align: center;
    border-left: 3px solid #e5e7eb;
  }

  .pdf-summary-card.collected { border-left-color: #8b5cf6; }
  .pdf-summary-card.commission { border-left-color: #10b981; }
  .pdf-summary-card.to-pay { border-left-color: #f59e0b; }
  .pdf-summary-card.paid { border-left-color: #3b82f6; }
  .pdf-summary-card.balance { border-left-color: #ef4444; }
  .pdf-summary-card.balance-clear { border-left-color: #22c55e; }

  .pdf-summary-label {
    font-size: 9px;
    text-transform: uppercase;
    letter-spacing: 0.5px;
    color: #6b7280;
    font-weight: 600;
    margin-bottom: 4px;
  }

  .pdf-summary-value {
    font-size: 14px;
    font-weight: 700;
    color: #1f2937;
    font-family: 'Courier New', monospace;
  }

  .pdf-summary-value.success { color: #059669; }
  .pdf-summary-value.info { color: #2563eb; }
  .pdf-summary-value.danger { color: #dc2626; }

  /* Table */
  .pdf-section-title {
    font-size: 12px;
    font-weight: 700;
    color: #1f2937;
    margin-bottom: 12px;
    padding-bottom: 6px;
    border-bottom: 1px solid #e5e7eb;
    display: flex;
    align-items: center;
    gap: 6px;
  }

  .pdf-table-container {
    margin-bottom: 24px;
  }

  .pdf-table {
    width: 100%;
    border-collapse: collapse;
    font-size: 10px;
  }

  .pdf-table thead {
    background: #f3f4f6;
  }

  .pdf-table th {
    padding: 10px 8px;
    text-align: left;
    font-weight: 600;
    color: #374151;
    border-bottom: 2px solid #e5e7eb;
    text-transform: uppercase;
    font-size: 9px;
    letter-spacing: 0.5px;
  }

  .pdf-table td {
    padding: 9px 8px;
    border-bottom: 1px solid #f3f4f6;
    color: #4b5563;
  }

  .pdf-table tbody tr:nth-child(even) {
    background: #fafafa;
  }

  .pdf-table .text-right {
    text-align: right;
  }

  .pdf-table .text-center {
    text-align: center;
  }

  .pdf-table .mono {
    font-family: 'Courier New', monospace;
    font-weight: 500;
  }

  .pdf-table .number-badge {
    display: inline-block;
    background: #eef2ff;
    color: #6366f1;
    padding: 2px 8px;
    border-radius: 4px;
    font-weight: 600;
    font-size: 10px;
  }

  .pdf-table .amount-green { color: #059669; font-weight: 600; }
  .pdf-table .amount-blue { color: #2563eb; font-weight: 600; }
  .pdf-table .amount-red { color: #dc2626; font-weight: 600; }

  .pdf-status-pill {
    display: inline-block;
    padding: 3px 8px;
    border-radius: 10px;
    font-size: 9px;
    font-weight: 600;
  }

  .pdf-status-pill.pending { background: #f3f4f6; color: #6b7280; }
  .pdf-status-pill.paid { background: #d1fae5; color: #059669; }
  .pdf-status-pill.partial { background: #fef3c7; color: #d97706; }
  .pdf-status-pill.overdue { background: #fee2e2; color: #dc2626; }

  /* Totals Footer */
  .pdf-totals {
    display: flex;
    justify-content: flex-end;
    gap: 16px;
    margin-bottom: 24px;
    padding: 16px 20px;
    background: #f8fafc;
    border-radius: 8px;
  }

  .pdf-total-item {
    text-align: center;
    padding: 8px 16px;
    background: white;
    border-radius: 6px;
    border: 1px solid #e5e7eb;
    min-width: 120px;
  }

  .pdf-total-label {
    font-size: 9px;
    text-transform: uppercase;
    color: #6b7280;
    font-weight: 600;
    margin-bottom: 2px;
  }

  .pdf-total-value {
    font-size: 13px;
    font-weight: 700;
    font-family: 'Courier New', monospace;
    color: #1f2937;
  }

  .pdf-total-value.highlight { color: #059669; }
  .pdf-total-value.final { color: #6366f1; }
  .pdf-total-value.danger { color: #dc2626; }

  /* Abonos Section */
  .pdf-abonos-section {
    page-break-inside: avoid;
  }

  .pdf-abono-card {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 12px 16px;
    background: #f8fafc;
    border: 1px solid #e5e7eb;
    border-left: 3px solid #10b981;
    border-radius: 6px;
    margin-bottom: 8px;
  }

  .pdf-abono-amount {
    font-size: 14px;
    font-weight: 700;
    color: #059669;
    font-family: 'Courier New', monospace;
  }

  .pdf-abono-method {
    font-size: 10px;
    color: #6b7280;
    background: white;
    padding: 2px 8px;
    border-radius: 4px;
    margin-top: 4px;
    display: inline-block;
  }

  .pdf-abono-date {
    font-size: 10px;
    color: #4b5563;
  }

  .pdf-abono-reference {
    font-size: 9px;
    color: #6b7280;
    font-family: 'Courier New', monospace;
  }

  /* Footer */
  .pdf-footer {
    margin-top: 32px;
    padding-top: 16px;
    border-top: 1px solid #e5e7eb;
    font-size: 9px;
    color: #9ca3af;
    text-align: center;
  }

  .pdf-footer-notice {
    margin-top: 8px;
    font-style: italic;
  }

  /* Print-specific */
  @media print {
    .pdf-container {
      padding: 0;
    }
    
    .pdf-table-container,
    .pdf-abonos-section {
      page-break-inside: avoid;
    }

    .pdf-header {
      page-break-after: avoid;
    }
  }
`;

// Estados de pago
const PAYMENT_STATUS = {
  'pending': 'Pendiente',
  'PENDING': 'Pendiente',
  'paid': 'Pagado',
  'PAID': 'Pagado',
  'partial': 'Parcial',
  'PARTIAL': 'Parcial',
  'overdue': 'Vencido',
  'OVERDUE': 'Vencido',
  'paid_by_associate': 'Absorbido',
  'PAID_BY_ASSOCIATE': 'Absorbido',
  'forgiven': 'Perdonado',
  'FORGIVEN': 'Perdonado'
};

const STATEMENT_STATUS = {
  6: { label: 'BORRADOR', class: 'draft' },
  7: { label: 'EN COBRO', class: 'collecting' },
  9: { label: 'LIQUIDACIÓN', class: 'settling' },
  10: { label: 'CERRADO', class: 'closed' },
  3: { label: 'PAGADO', class: 'paid' },
  4: { label: 'PARCIAL', class: 'partial' },
  5: { label: 'VENCIDO', class: 'overdue' }
};

/**
 * Genera el HTML del documento PDF
 */
const generatePDFHTML = ({ statement, payments, totals, periodInfo, abonos, pendingBalance }) => {
  const statusInfo = STATEMENT_STATUS[statement?.status_id] || STATEMENT_STATUS[6];
  const now = new Date();
  
  // Generar filas de pagos
  const paymentRows = payments.map((payment, idx) => {
    const status = payment.status?.toLowerCase() || 'pending';
    return `
      <tr>
        <td class="text-center">
          <span class="number-badge">${payment.payment_number || idx + 1}</span>
        </td>
        <td>${payment.client_name || `Cliente #${payment.client_id}`}</td>
        <td class="mono">#${payment.loan_id}</td>
        <td class="text-center">${formatDate(payment.due_date || payment.payment_due_date)}</td>
        <td class="text-right mono">${formatMoney(payment.expected_amount)}</td>
        <td class="text-right mono amount-green">${formatMoney(payment.commission_amount)}</td>
        <td class="text-right mono">${formatMoney(payment.associate_payment)}</td>
        <td class="text-right mono amount-blue">${formatMoney(payment.paid_amount || payment.amount_paid)}</td>
        <td class="text-center">
          <span class="pdf-status-pill ${status}">${PAYMENT_STATUS[payment.status] || 'Pendiente'}</span>
        </td>
      </tr>
    `;
  }).join('');

  // Generar cards de abonos
  const abonosHTML = abonos.length > 0 ? `
    <div class="pdf-abonos-section">
      <div class="pdf-section-title">💳 Historial de Abonos (${abonos.length})</div>
      ${abonos.map(abono => `
        <div class="pdf-abono-card">
          <div>
            <div class="pdf-abono-amount">${formatMoney(abono.payment_amount)}</div>
            <div class="pdf-abono-method">${abono.payment_method}</div>
          </div>
          <div style="text-align: right;">
            <div class="pdf-abono-date">📅 ${formatDate(abono.payment_date)}</div>
            ${abono.payment_reference ? `<div class="pdf-abono-reference">Ref: ${abono.payment_reference}</div>` : ''}
          </div>
        </div>
      `).join('')}
    </div>
  ` : '';

  return `
    <!DOCTYPE html>
    <html lang="es">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Estado de Cuenta - ${statement?.associate_name || 'Asociado'}</title>
      <style>${getPDFStyles()}</style>
    </head>
    <body>
      <div class="pdf-container">
        <!-- Header -->
        <div class="pdf-header">
          <div class="pdf-logo">
            <div class="pdf-logo-icon">C</div>
            <div>
              <div class="pdf-company-name">CrediCuenta</div>
              <div class="pdf-company-tagline">Sistema de Gestión de Créditos</div>
            </div>
          </div>
          <div class="pdf-doc-info">
            <div class="pdf-doc-title">Estado de Cuenta</div>
            <div class="pdf-doc-meta">
              Generado: ${formatDateTime(now)}<br>
              ID: ${statement?.id || '-'}
            </div>
          </div>
        </div>

        <!-- Associate Info -->
        <div class="pdf-associate-section">
          <div class="pdf-associate-header">
            <div>
              <span class="pdf-associate-name">${statement?.associate_name || 'Asociado'}</span>
              ${statement?.associate_code ? `<span class="pdf-associate-code">#${statement.associate_code}</span>` : ''}
              ${periodInfo?.period_code ? `<span class="pdf-period-badge">📅 ${periodInfo.period_code}</span>` : ''}
            </div>
            <span class="pdf-status-badge ${statusInfo.class}">${statusInfo.label}</span>
          </div>
        </div>

        <!-- Summary Cards -->
        <div class="pdf-summary-grid">
          <div class="pdf-summary-card collected">
            <div class="pdf-summary-label">Total Esperado</div>
            <div class="pdf-summary-value">${formatMoney(totals.expected)}</div>
          </div>
          <div class="pdf-summary-card commission">
            <div class="pdf-summary-label">Comisión Ganada</div>
            <div class="pdf-summary-value success">${formatMoney(totals.commission)}</div>
          </div>
          <div class="pdf-summary-card to-pay">
            <div class="pdf-summary-label">A Pagar a CrediCuenta</div>
            <div class="pdf-summary-value">${formatMoney(totals.toCredicuenta)}</div>
          </div>
          <div class="pdf-summary-card paid">
            <div class="pdf-summary-label">Total Abonado</div>
            <div class="pdf-summary-value info">${formatMoney(statement?.paid_amount || 0)}</div>
          </div>
          <div class="pdf-summary-card ${pendingBalance > 0 ? 'balance' : 'balance-clear'}">
            <div class="pdf-summary-label">Saldo Pendiente</div>
            <div class="pdf-summary-value ${pendingBalance > 0 ? 'danger' : 'success'}">${formatMoney(pendingBalance)}</div>
          </div>
        </div>

        <!-- Payments Table -->
        <div class="pdf-table-container">
          <div class="pdf-section-title">📋 Detalle de Pagos (${payments.length} registros)</div>
          <table class="pdf-table">
            <thead>
              <tr>
                <th class="text-center"># Pago</th>
                <th>Cliente</th>
                <th>Préstamo</th>
                <th class="text-center">F. Vencimiento</th>
                <th class="text-right">Esperado</th>
                <th class="text-right">Comisión</th>
                <th class="text-right">A Pagar</th>
                <th class="text-right">Pagado</th>
                <th class="text-center">Estado</th>
              </tr>
            </thead>
            <tbody>
              ${paymentRows}
            </tbody>
          </table>
        </div>

        <!-- Totals -->
        <div class="pdf-totals">
          <div class="pdf-total-item">
            <div class="pdf-total-label">Total Esperado</div>
            <div class="pdf-total-value">${formatMoney(totals.expected)}</div>
          </div>
          <div class="pdf-total-item">
            <div class="pdf-total-label">Total Comisión</div>
            <div class="pdf-total-value highlight">${formatMoney(totals.commission)}</div>
          </div>
          <div class="pdf-total-item">
            <div class="pdf-total-label">Total a CrediCuenta</div>
            <div class="pdf-total-value">${formatMoney(totals.toCredicuenta)}</div>
          </div>
          <div class="pdf-total-item">
            <div class="pdf-total-label">Saldo Pendiente</div>
            <div class="pdf-total-value ${pendingBalance > 0 ? 'danger' : 'final'}">${formatMoney(pendingBalance)}</div>
          </div>
        </div>

        <!-- Abonos -->
        ${abonosHTML}

        <!-- Footer -->
        <div class="pdf-footer">
          <div>CrediCuenta - Sistema de Gestión de Créditos | ${formatDate(now)}</div>
          <div class="pdf-footer-notice">
            Este documento es un comprobante generado automáticamente. Conserve una copia para sus registros.
          </div>
        </div>
      </div>
    </body>
    </html>
  `;
};

/**
 * Abre una ventana de impresión con el PDF generado
 */
export const generateStatementPDF = (data) => {
  const { statement, payments, totals, periodInfo, abonos = [], pendingBalance } = data;
  
  // Generar HTML
  const htmlContent = generatePDFHTML({
    statement,
    payments,
    totals,
    periodInfo,
    abonos,
    pendingBalance
  });

  // Crear ventana de impresión
  const printWindow = window.open('', '_blank', 'width=900,height=700');
  
  if (!printWindow) {
    alert('Por favor permite las ventanas emergentes para generar el PDF');
    return false;
  }

  printWindow.document.write(htmlContent);
  printWindow.document.close();

  // Esperar a que cargue y abrir diálogo de impresión
  printWindow.onload = () => {
    setTimeout(() => {
      printWindow.print();
    }, 250);
  };

  return true;
};

/**
 * Descarga el PDF directamente (usando print to PDF del navegador)
 */
export const downloadStatementPDF = (data) => {
  const success = generateStatementPDF(data);
  if (success) {
    console.log('✅ Ventana de impresión abierta. Selecciona "Guardar como PDF" en el diálogo de impresión.');
  }
  return success;
};

export default generateStatementPDF;
