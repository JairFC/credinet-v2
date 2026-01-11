/**
 * StatementDetailPage - Página completa de detalles del estado de cuenta
 * 
 * Reemplaza el modal anterior para mejor rendimiento y experiencia de usuario.
 * Muestra:
 * - Header con info del asociado y período
 * - Resumen de totales en tarjetas
 * - Tabla detallada de todos los pagos
 * - Opción de registrar abonos
 * - Exportación a PDF profesional
 */

import React, { useState, useEffect, useMemo } from 'react';
import { useParams, useNavigate, useLocation } from 'react-router-dom';
import apiClient from '@/shared/api/apiClient';
import RegistrarAbonoModal from '../components/RegistrarAbonoModal';
import { generateStatementPDF } from '../utils/generateStatementPDF';
import './StatementDetailPage.css';

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

// Formatea fecha con hora
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

// Estados de pago
const PAYMENT_STATUS = {
  'pending': { label: 'Pendiente', class: 'pending', icon: '⏳' },
  'PENDING': { label: 'Pendiente', class: 'pending', icon: '⏳' },
  'paid': { label: 'Pagado', class: 'paid', icon: '✅' },
  'PAID': { label: 'Pagado', class: 'paid', icon: '✅' },
  'partial': { label: 'Parcial', class: 'partial', icon: '⚡' },
  'PARTIAL': { label: 'Parcial', class: 'partial', icon: '⚡' },
  'overdue': { label: 'Vencido', class: 'overdue', icon: '⚠️' },
  'OVERDUE': { label: 'Vencido', class: 'overdue', icon: '⚠️' },
  'paid_by_associate': { label: 'Absorbido', class: 'absorbed', icon: '🔄' },
  'PAID_BY_ASSOCIATE': { label: 'Absorbido', class: 'absorbed', icon: '🔄' },
  'paid_not_reported': { label: 'No Reportado', class: 'not-reported', icon: '📋' },
  'PAID_NOT_REPORTED': { label: 'No Reportado', class: 'not-reported', icon: '📋' },
  'forgiven': { label: 'Perdonado', class: 'forgiven', icon: '💝' },
  'FORGIVEN': { label: 'Perdonado', class: 'forgiven', icon: '💝' },
  'cancelled': { label: 'Cancelado', class: 'cancelled', icon: '❌' },
  'CANCELLED': { label: 'Cancelado', class: 'cancelled', icon: '❌' }
};

// Estados de statement (según statement_statuses table)
// Flujo principal: DRAFT(6) → COLLECTING(7) → SETTLING(9) → CLOSED(10)
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

export default function StatementDetailPage() {
  const { statementId } = useParams();
  const navigate = useNavigate();
  const location = useLocation();

  // Datos pasados via state (si vienen de la página de estados de cuenta)
  const passedStatement = location.state?.statement;
  const passedPeriodInfo = location.state?.periodInfo;

  const [statement, setStatement] = useState(passedStatement || null);
  const [payments, setPayments] = useState([]);
  const [periodInfo, setPeriodInfo] = useState(passedPeriodInfo || null);
  const [loading, setLoading] = useState(!passedStatement);
  const [loadingPayments, setLoadingPayments] = useState(true);
  const [error, setError] = useState(null);

  const [sortField, setSortField] = useState('due_date');
  const [sortDirection, setSortDirection] = useState('asc');
  const [filterStatus, setFilterStatus] = useState('all');

  // Modal de abono
  const [abonoModalOpen, setAbonoModalOpen] = useState(false);

  // Historial de abonos
  const [statementAbonos, setStatementAbonos] = useState([]);
  const [loadingAbonos, setLoadingAbonos] = useState(false);

  // Cargar statement si no viene por state
  useEffect(() => {
    if (!passedStatement && statementId) {
      loadStatement();
    }
    // Cargar pagos solo si tenemos período y statement
    if (passedStatement && passedPeriodInfo) {
      loadPaymentsFromPeriod();
    } else if (statementId) {
      loadPayments();
    }
  }, [statementId, passedStatement, passedPeriodInfo]);

  // Cargar abonos cuando tengamos el statement
  useEffect(() => {
    const stmtId = statement?.id || statementId;
    if (stmtId) {
      loadStatementAbonos(stmtId);
    }
  }, [statement?.id, statementId]);

  const loadStatement = async () => {
    try {
      setLoading(true);
      const response = await apiClient.get(`/api/v1/statements/${statementId}`);
      setStatement(response.data?.data || response.data);
    } catch (err) {
      console.error('Error loading statement:', err);
      setError('No se pudo cargar el estado de cuenta');
    } finally {
      setLoading(false);
    }
  };

  // Cargar pagos usando el endpoint de payments-preview (método del modal original)
  const loadPaymentsFromPeriod = async () => {
    if (!passedPeriodInfo?.id || !passedStatement?.associate_id) {
      setLoadingPayments(false);
      return;
    }

    try {
      setLoadingPayments(true);
      const response = await apiClient.get(`/api/v1/cut-periods/${passedPeriodInfo.id}/payments-preview`, {
        params: {
          include_all_associates: false,
          include_payments_detail: true
        }
      });

      if (response.data?.success) {
        // Buscar el asociado específico
        const associateData = response.data.data?.find(
          a => a.associate_id === passedStatement.associate_id
        );
        setPayments(associateData?.payments || []);
      }
    } catch (err) {
      console.error('Error loading payments from period:', err);
      setPayments([]);
    } finally {
      setLoadingPayments(false);
    }
  };

  const loadPayments = async () => {
    try {
      setLoadingPayments(true);
      const response = await apiClient.get(`/api/v1/statements/${statementId}/payments`);
      const data = response.data?.data || response.data || [];
      setPayments(Array.isArray(data) ? data : []);
    } catch (err) {
      console.error('Error loading payments:', err);
      setPayments([]);
    } finally {
      setLoadingPayments(false);
    }
  };

  // Cargar abonos registrados para este statement
  const loadStatementAbonos = async (stmtId) => {
    try {
      setLoadingAbonos(true);
      // Endpoint: GET /statements/{id}/payments devuelve { payments: [...] }
      const response = await apiClient.get(`/api/v1/statements/${stmtId}/payments`);
      const data = response.data?.data?.payments || response.data?.payments || [];
      setStatementAbonos(Array.isArray(data) ? data : []);

      // También actualizar el paid_amount del statement si viene
      if (response.data?.data?.paid_amount !== undefined) {
        setStatement(prev => prev ? {
          ...prev,
          total_paid: response.data.data.paid_amount,
          paid_amount: response.data.data.paid_amount
        } : prev);
      }
    } catch (err) {
      console.error('Error loading abonos:', err);
      setStatementAbonos([]);
    } finally {
      setLoadingAbonos(false);
    }
  };

  // Cuando se registra un abono exitosamente
  const handleAbonoSuccess = () => {
    const stmtId = statement?.id || statementId;
    // Recargar el statement para actualizar paid_amount
    if (!passedStatement) {
      loadStatement();
    }
    // Recargar abonos
    if (stmtId) {
      loadStatementAbonos(stmtId);
    }
  };

  // Eliminar un abono
  const handleDeleteAbono = async (abonoId, amount) => {
    if (!window.confirm(
      `¿Estás seguro de eliminar este abono de ${formatMoney(amount)}?\n\n` +
      `Esta acción no se puede deshacer.`
    )) {
      return;
    }

    const stmtId = statement?.id || statementId;
    try {
      const response = await apiClient.delete(
        `/api/v1/statements/${stmtId}/payments/${abonoId}`
      );

      if (response.data?.success) {
        alert(`✅ Abono eliminado correctamente.`);
        // Recargar abonos
        loadStatementAbonos(stmtId);
        // Actualizar paid_amount si viene en la respuesta
        if (response.data.data?.new_paid_amount !== undefined) {
          setStatement(prev => prev ? {
            ...prev,
            paid_amount: response.data.data.new_paid_amount,
            total_paid: response.data.data.new_paid_amount
          } : prev);
        }
      }
    } catch (err) {
      console.error('Error deleting abono:', err);
      alert(err.response?.data?.detail || 'Error al eliminar el abono');
    }
  };

  // Verificar si se pueden eliminar abonos (solo en COLLECTING o SETTLING)
  const canDeleteAbonos = periodInfo?.status_id === 4 || periodInfo?.status_id === 6;

  // Calcular totales
  const totals = useMemo(() => {
    return payments.reduce((acc, p) => ({
      expected: acc.expected + (p.expected_amount || 0),
      commission: acc.commission + (p.commission_amount || 0),
      toCredicuenta: acc.toCredicuenta + (p.associate_payment || 0),
      paid: acc.paid + (p.paid_amount || p.amount_paid || 0)
    }), { expected: 0, commission: 0, toCredicuenta: 0, paid: 0 });
  }, [payments]);

  // Ordenar y filtrar pagos
  const sortedPayments = useMemo(() => {
    let filtered = [...payments];

    if (filterStatus !== 'all') {
      filtered = filtered.filter(p =>
        p.status?.toLowerCase() === filterStatus.toLowerCase()
      );
    }

    filtered.sort((a, b) => {
      let aVal = a[sortField];
      let bVal = b[sortField];

      if (typeof aVal === 'string') {
        aVal = aVal?.toLowerCase() || '';
        bVal = bVal?.toLowerCase() || '';
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

  const handleGoBack = () => {
    navigate(-1);
  };

  const statusInfo = statement ? STATEMENT_STATUS[statement.status_id] || STATEMENT_STATUS[6] : null;

  // Total abonado a CrediCuenta (desde el backend o calculado)
  const realPaidAmount = statement?.paid_amount || statement?.total_paid || 0;

  // Saldo pendiente = Lo que debe a CrediCuenta (calculado en tiempo real) - Lo que ha abonado
  // IMPORTANTE: Usar totals.toCredicuenta (calculado de payments reales) en lugar de 
  // statement.total_to_credicuenta que puede estar desactualizado
  const pendingBalance = statement
    ? (totals.toCredicuenta || 0) + (statement.late_fee || 0) - realPaidAmount
    : 0;

  if (loading) {
    return (
      <div className="statement-detail-page">
        <div className="loading-container">
          <div className="spinner"></div>
          <p>Cargando estado de cuenta...</p>
        </div>
      </div>
    );
  }

  if (error || !statement) {
    return (
      <div className="statement-detail-page">
        <div className="error-container">
          <span className="error-icon">⚠️</span>
          <h2>Error</h2>
          <p>{error || 'No se encontró el estado de cuenta'}</p>
          <button className="btn-back" onClick={handleGoBack}>
            ← Volver
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="statement-detail-page">
      {/* Header */}
      <div className="page-header">
        <button className="btn-back" onClick={handleGoBack}>
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
            <path d="M19 12H5M12 19l-7-7 7-7" />
          </svg>
          Volver
        </button>

        <div className="header-content">
          <div className="header-main">
            <div className="associate-avatar">
              <span>{statement.associate_name?.split(' ').map(n => n[0]).join('').substring(0, 2).toUpperCase() || '??'}</span>
            </div>
            <div className="header-info">
              <h1>{statement.associate_name || 'Asociado'}</h1>
              <div className="header-meta">
                {statement.associate_code && (
                  <span className="meta-badge code">#{statement.associate_code}</span>
                )}
                {periodInfo?.period_code && (
                  <span className="meta-badge period">📅 {periodInfo.period_code}</span>
                )}
                <span className="meta-badge payments">📑 {payments.length} pagos</span>
                {/* Enlace al perfil del asociado */}
                {statement.associate_id && (
                  <button
                    className="meta-badge-link"
                    onClick={() => navigate(`/asociados/${statement.associate_id}`)}
                    title="Ver historial completo de deuda"
                  >
                    📊 Ver historial de deuda
                  </button>
                )}
              </div>
            </div>
          </div>

          <div className="header-status">
            {statusInfo && (
              <div className={`status-badge-large ${statusInfo.class}`}>
                <span className="status-icon">{statusInfo.icon}</span>
                <span className="status-text">{statusInfo.label}</span>
              </div>
            )}
          </div>
        </div>
      </div>

      {/* Summary Cards - Usando totales calculados de los pagos */}
      <div className="summary-grid">
        <div className="summary-card collected">
          <div className="card-icon">💵</div>
          <div className="card-content">
            <span className="card-label">Total Esperado</span>
            <span className="card-value">{formatMoney(totals.expected)}</span>
          </div>
        </div>

        <div className="summary-card commission">
          <div className="card-icon">🎯</div>
          <div className="card-content">
            <span className="card-label">Comisión Ganada</span>
            <span className="card-value success">{formatMoney(totals.commission)}</span>
          </div>
        </div>

        <div className="summary-card to-pay">
          <div className="card-icon">📤</div>
          <div className="card-content">
            <span className="card-label">A Pagar a CrediCuenta</span>
            <span className="card-value">{formatMoney(totals.toCredicuenta)}</span>
          </div>
        </div>

        <div className="summary-card paid">
          <div className="card-icon">✅</div>
          <div className="card-content">
            <span className="card-label">Total Abonado a CrediCuenta</span>
            <span className="card-value info">{formatMoney(realPaidAmount)}</span>
          </div>
        </div>

        <div className={`summary-card balance ${pendingBalance > 0 ? 'pending' : 'clear'}`}>
          <div className="card-icon">{pendingBalance > 0 ? '⏰' : '🎉'}</div>
          <div className="card-content">
            <span className="card-label">Saldo Pendiente</span>
            <span className={`card-value ${pendingBalance > 0 ? 'danger' : 'success'}`}>
              {formatMoney(pendingBalance)}
            </span>
          </div>
        </div>
      </div>

      {/* Toolbar */}
      <div className="content-toolbar">
        <div className="toolbar-left">
          <h2>Detalle de Pagos</h2>
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
          {pendingBalance > 0 && (
            <button className="toolbar-btn btn-payment" onClick={() => setAbonoModalOpen(true)}>
              <span>💳</span> Registrar Abono
            </button>
          )}
          <button 
            className="toolbar-btn btn-export"
            onClick={() => generateStatementPDF({
              statement,
              payments: sortedPayments,
              totals,
              periodInfo,
              abonos: statementAbonos,
              pendingBalance
            })}
          >
            <span>📥</span> Exportar PDF
          </button>
          <button className="toolbar-btn btn-print" onClick={() => window.print()}>
            <span>🖨️</span> Imprimir
          </button>
        </div>
      </div>

      {/* Payments Table */}
      <div className="table-section">
        {loadingPayments ? (
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
                  <th className="sortable" onClick={() => handleSort('payment_number')}>
                    # Pago
                    {sortField === 'payment_number' && (
                      <span className="sort-icon">{sortDirection === 'asc' ? '↑' : '↓'}</span>
                    )}
                  </th>
                  <th className="sortable" onClick={() => handleSort('client_name')}>
                    Cliente
                    {sortField === 'client_name' && (
                      <span className="sort-icon">{sortDirection === 'asc' ? '↑' : '↓'}</span>
                    )}
                  </th>
                  <th>Préstamo</th>
                  <th className="sortable text-right" onClick={() => handleSort('due_date')}>
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
                  const paymentStatus = PAYMENT_STATUS[payment.status] || PAYMENT_STATUS.pending;
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
                        <span className={`status-pill ${paymentStatus.class}`}>
                          <span className="status-icon">{paymentStatus.icon}</span>
                          {paymentStatus.label}
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

      {/* Footer Totals */}
      {!loadingPayments && sortedPayments.length > 0 && (
        <div className="totals-footer">
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
              <span className="total-label">Total Abonado</span>
              <span className="total-value info">{formatMoney(realPaidAmount)}</span>
            </div>
            <div className="total-item final">
              <span className="total-label">Saldo Pendiente</span>
              <span className={`total-value ${pendingBalance > 0 ? 'danger' : 'success'}`}>
                {formatMoney(pendingBalance)}
              </span>
            </div>
          </div>
        </div>
      )}

      {/* Historial de Abonos */}
      <div className="abonos-section">
        <div className="section-header">
          <h2>
            💳 Historial de Abonos
            {statementAbonos.length > 0 && (
              <span className="abonos-count">{statementAbonos.length}</span>
            )}
          </h2>
          {pendingBalance > 0 && (
            <button className="btn-add-abono" onClick={() => setAbonoModalOpen(true)}>
              ➕ Nuevo Abono
            </button>
          )}
        </div>

        {loadingAbonos ? (
          <div className="loading-state small">
            <div className="spinner"></div>
            <p>Cargando abonos...</p>
          </div>
        ) : statementAbonos.length === 0 ? (
          <div className="empty-abonos">
            <span className="empty-icon">💸</span>
            <p>No hay abonos registrados para este estado de cuenta.</p>
            {pendingBalance > 0 && (
              <button className="btn-first-abono" onClick={() => setAbonoModalOpen(true)}>
                Registrar primer abono
              </button>
            )}
          </div>
        ) : (
          <div className="abonos-list">
            {statementAbonos.map((abono) => (
              <div key={abono.id} className="abono-card">
                <div className="abono-amount">
                  <span className="amount">{formatMoney(abono.payment_amount)}</span>
                  <span className="method">{abono.payment_method}</span>
                </div>
                <div className="abono-details">
                  <div className="abono-date">
                    <span className="icon">📅</span>
                    {formatDate(abono.payment_date)}
                  </div>
                  <div className="abono-time" style={{ fontSize: '12px', color: 'var(--color-text-secondary)' }}>
                    <span className="icon">🕐</span>
                    Registrado: {formatDateTime(abono.created_at)}
                  </div>
                  {abono.payment_reference && (
                    <div className="abono-reference">
                      <span className="icon">🔖</span>
                      Ref: {abono.payment_reference}
                    </div>
                  )}
                  {abono.notes && (
                    <div className="abono-notes">
                      <span className="icon">📝</span>
                      {abono.notes}
                    </div>
                  )}
                </div>
                <div className="abono-meta">
                  <span className="registered-by">Por: {abono.registered_by}</span>
                </div>
                <div className="abono-actions" style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
                  {/* Botón evidencia (placeholder) */}
                  <button
                    className="btn-evidence"
                    onClick={() => alert('Función de evidencia próximamente')}
                    title="Agregar evidencia (próximamente)"
                    style={{
                      padding: '6px 10px',
                      borderRadius: '6px',
                      border: '1px solid var(--color-border)',
                      backgroundColor: 'var(--color-surface)',
                      cursor: 'pointer',
                      fontSize: '12px',
                      color: 'var(--color-text-secondary)'
                    }}
                  >
                    📎 Evidencia
                  </button>
                  {/* Botón eliminar - solo si el período está EN COBRO o LIQUIDACIÓN */}
                  {canDeleteAbonos && (
                    <button
                      className="btn-delete-abono"
                      onClick={() => handleDeleteAbono(abono.id, abono.payment_amount)}
                      title="Eliminar este abono"
                    >
                      🗑️
                    </button>
                  )}
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Modal de Registro de Abono */}
      <RegistrarAbonoModal
        isOpen={abonoModalOpen}
        onClose={() => setAbonoModalOpen(false)}
        statement={statement}
        periodInfo={periodInfo}
        onSuccess={(data) => {
          handleAbonoSuccess();
          // Actualizar el statement con el nuevo paid_amount
          if (data?.paid_amount_total !== undefined) {
            setStatement(prev => ({
              ...prev,
              paid_amount: data.paid_amount_total,
              total_paid: data.paid_amount_total
            }));
          }
        }}
      />
    </div>
  );
}
