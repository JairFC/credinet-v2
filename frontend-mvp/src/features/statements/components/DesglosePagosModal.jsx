/**
 * DesglosePagosModal - Modal con tabla completa de pagos del período por asociado
 * 
 * Muestra:
 * - Header con info del asociado y período
 * - Tabla detallada de todos los pagos
 * - Totales y estadísticas
 * - Opción de exportar/imprimir
 */

import React, { useState, useMemo } from 'react';
import './DesglosePagosModal.css';

// Formatea moneda
const formatMoney = (amount) => {
  if (amount === null || amount === undefined) return '$0.00';
  return new Intl.NumberFormat('es-MX', {
    style: 'currency',
    currency: 'MXN'
  }).format(amount);
};

// Formatea fecha
const formatDate = (dateStr) => {
  if (!dateStr) return '-';
  const date = new Date(dateStr);
  return date.toLocaleDateString('es-MX', {
    day: '2-digit',
    month: 'short',
    year: 'numeric'
  });
};

// Estados de pago - mapear tanto mayúsculas como minúsculas
const PAYMENT_STATUS = {
  'pending': { label: 'Pendiente', class: 'pending', icon: '⏳' },
  'PENDING': { label: 'Pendiente', class: 'pending', icon: '⏳' },
  'paid': { label: 'Pagado', class: 'paid', icon: '✅' },
  'PAID': { label: 'Pagado', class: 'paid', icon: '✅' },
  'partial': { label: 'Parcial', class: 'partial', icon: '⚡' },
  'PARTIAL': { label: 'Parcial', class: 'partial', icon: '⚡' },
  'overdue': { label: 'Vencido', class: 'overdue', icon: '⚠️' },
  'OVERDUE': { label: 'Vencido', class: 'overdue', icon: '⚠️' }
};

export default function DesglosePagosModal({
  isOpen,
  onClose,
  statement,
  payments = [],
  periodInfo,
  loading = false
}) {
  const [sortField, setSortField] = useState('due_date');
  const [sortDirection, setSortDirection] = useState('asc');
  const [filterStatus, setFilterStatus] = useState('all');

  // Calcular totales
  const totals = useMemo(() => {
    return payments.reduce((acc, p) => ({
      expected: acc.expected + (p.expected_amount || 0),
      commission: acc.commission + (p.commission_amount || 0),
      toCredicuenta: acc.toCredicuenta + (p.associate_payment || 0),
      paid: acc.paid + (p.paid_amount || 0)
    }), { expected: 0, commission: 0, toCredicuenta: 0, paid: 0 });
  }, [payments]);

  // Ordenar y filtrar pagos
  const sortedPayments = useMemo(() => {
    let filtered = [...payments];

    // Filtrar por estado
    if (filterStatus !== 'all') {
      filtered = filtered.filter(p => p.status === filterStatus);
    }

    // Ordenar
    filtered.sort((a, b) => {
      let aVal = a[sortField];
      let bVal = b[sortField];

      if (typeof aVal === 'string') {
        aVal = aVal.toLowerCase();
        bVal = (bVal || '').toLowerCase();
      }

      if (aVal < bVal) return sortDirection === 'asc' ? -1 : 1;
      if (aVal > bVal) return sortDirection === 'asc' ? 1 : -1;
      return 0;
    });

    return filtered;
  }, [payments, sortField, sortDirection, filterStatus]);

  const handleSort = (field) => {
    if (field === sortField) {
      setSortDirection(sortDirection === 'asc' ? 'desc' : 'asc');
    } else {
      setSortField(field);
      setSortDirection('asc');
    }
  };

  if (!isOpen) return null;

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="desglose-modal" onClick={e => e.stopPropagation()}>
        {/* Header */}
        <div className="modal-header">
          <div className="header-info">
            <h2>
              <span className="header-icon">📋</span>
              Desglose de Pagos
            </h2>
            <div className="header-meta">
              <span className="meta-item">
                <strong>Asociado:</strong> {statement?.associate_name || 'N/A'}
              </span>
              <span className="meta-divider">|</span>
              <span className="meta-item">
                <strong>Período:</strong> {periodInfo?.period_code || 'N/A'}
              </span>
              <span className="meta-divider">|</span>
              <span className="meta-item">
                <strong>Pagos:</strong> {payments.length}
              </span>
            </div>
          </div>
          <button className="close-btn" onClick={onClose}>
            <span>×</span>
          </button>
        </div>

        {/* Toolbar */}
        <div className="modal-toolbar">
          <div className="toolbar-left">
            <div className="filter-group">
              <label>Filtrar:</label>
              <select
                value={filterStatus}
                onChange={(e) => setFilterStatus(e.target.value)}
                className="filter-select"
              >
                <option value="all">Todos los pagos</option>
                <option value="pending">Pendientes</option>
                <option value="paid">Pagados</option>
                <option value="partial">Parciales</option>
                <option value="overdue">Vencidos</option>
              </select>
            </div>
          </div>
          <div className="toolbar-right">
            <button className="toolbar-btn btn-export">
              <span>📥</span> Exportar
            </button>
            <button className="toolbar-btn btn-print">
              <span>🖨️</span> Imprimir
            </button>
          </div>
        </div>

        {/* Tabla de Pagos */}
        <div className="modal-body">
          {loading ? (
            <div className="loading-state">
              <div className="spinner"></div>
              <p>Cargando pagos...</p>
            </div>
          ) : sortedPayments.length === 0 ? (
            <div className="empty-state">
              <span className="empty-icon">📭</span>
              <h3>Sin pagos</h3>
              <p>No hay pagos registrados para este período y asociado.</p>
            </div>
          ) : (
            <div className="table-container">
              <table className="payments-table">
                <thead>
                  <tr>
                    <th
                      className="sortable"
                      onClick={() => handleSort('payment_number')}
                    >
                      # Pago
                      {sortField === 'payment_number' && (
                        <span className="sort-icon">{sortDirection === 'asc' ? '↑' : '↓'}</span>
                      )}
                    </th>
                    <th
                      className="sortable"
                      onClick={() => handleSort('client_name')}
                    >
                      Cliente
                      {sortField === 'client_name' && (
                        <span className="sort-icon">{sortDirection === 'asc' ? '↑' : '↓'}</span>
                      )}
                    </th>
                    <th>Préstamo</th>
                    <th
                      className="sortable text-right"
                      onClick={() => handleSort('due_date')}
                    >
                      F. Vencimiento
                      {sortField === 'due_date' && (
                        <span className="sort-icon">{sortDirection === 'asc' ? '↑' : '↓'}</span>
                      )}
                    </th>
                    <th className="text-right">Esperado</th>
                    <th className="text-right">Comisión</th>
                    <th className="text-right">A Pagar</th>
                    <th className="text-right">Pagado</th>
                    <th className="text-center">Estado</th>
                  </tr>
                </thead>
                <tbody>
                  {sortedPayments.map((payment, idx) => {
                    const statusInfo = PAYMENT_STATUS[payment.status] || PAYMENT_STATUS.pending;
                    return (
                      <tr key={payment.id || idx}>
                        <td className="payment-number">
                          <span className="number-badge">
                            {payment.payment_number || idx + 1}
                          </span>
                        </td>
                        <td>
                          <div className="client-cell">
                            <span className="client-name">
                              {payment.client_name || `Cliente #${payment.client_id}`}
                            </span>
                            {payment.client_phone && (
                              <span className="client-phone">{payment.client_phone}</span>
                            )}
                          </div>
                        </td>
                        <td>
                          <div className="loan-cell">
                            <span className="loan-id">#{payment.loan_id}</span>
                            {payment.loan_type && (
                              <span className="loan-type">{payment.loan_type}</span>
                            )}
                          </div>
                        </td>
                        <td className="text-right">
                          {formatDate(payment.due_date || payment.payment_due_date)}
                        </td>
                        <td className="text-right amount">
                          {formatMoney(payment.expected_amount)}
                        </td>
                        <td className="text-right amount commission">
                          {formatMoney(payment.commission_amount)}
                        </td>
                        <td className="text-right amount to-pay">
                          {formatMoney(payment.associate_payment)}
                        </td>
                        <td className="text-right amount paid">
                          {formatMoney(payment.paid_amount || payment.amount_paid)}
                        </td>
                        <td className="text-center">
                          <span className={`status-pill ${statusInfo.class}`}>
                            <span className="status-icon">{statusInfo.icon}</span>
                            {statusInfo.label}
                          </span>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          )}
        </div>

        {/* Footer con Totales */}
        <div className="modal-footer">
          <div className="totals-grid">
            <div className="total-item">
              <span className="total-label">Total Esperado</span>
              <span className="total-value">{formatMoney(totals.expected)}</span>
            </div>
            <div className="total-item highlight">
              <span className="total-label">Total Comisión</span>
              <span className="total-value success">{formatMoney(totals.commission)}</span>
            </div>
            <div className="total-item">
              <span className="total-label">Total a CrediCuenta</span>
              <span className="total-value">{formatMoney(totals.toCredicuenta)}</span>
            </div>
            <div className="total-item">
              <span className="total-label">Total Cobrado</span>
              <span className="total-value info">{formatMoney(totals.paid)}</span>
            </div>
            <div className="total-item final">
              <span className="total-label">Saldo Pendiente</span>
              <span className={`total-value ${totals.toCredicuenta - totals.paid > 0 ? 'danger' : 'success'}`}>
                {formatMoney(totals.toCredicuenta - totals.paid)}
              </span>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
