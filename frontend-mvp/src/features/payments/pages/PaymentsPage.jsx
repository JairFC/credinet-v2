import { useState, useEffect } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { useAuth } from '@/app/providers/AuthProvider';
import { paymentsService } from '@/shared/api/services';
import './PaymentsPage.css';

/**
 * PaymentsPage - Vista de gestión de pagos quincenales
 * 
 * Lógica del Sistema (Backend v2.0 - 12 Estados):
 * 
 * PENDIENTES (6):
 *   1 = PENDING (programado, no vence)
 *   2 = DUE_TODAY (vence hoy)
 *   4 = OVERDUE (vencido)
 *   5 = PARTIAL (pago parcial)
 *   6 = IN_COLLECTION (en cobranza)
 *   7 = RESCHEDULED (reprogramado)
 * 
 * PAGADOS REALES (2): 💵
 *   3 = PAID (pagado por cliente)
 *   8 = PAID_PARTIAL (pago parcial aceptado)
 * 
 * FICTICIOS (4): ⚠️
 *   9 = PAID_BY_ASSOCIATE (absorbido por asociado)
 *   10 = PAID_NOT_REPORTED (no reportado al cierre)
 *   11 = FORGIVEN (perdonado)
 *   12 = CANCELLED (cancelado)
 * 
 * Reglas de Negocio:
 * - Solo pagos PENDIENTES pueden ser marcados como pagados
 * - amount_paid puede ser parcial o completo
 * - marked_by debe ser el usuario actual (admin/asociado)
 * - Si amount_paid >= expected_amount → estado PAID
 * - Si amount_paid < expected_amount → estado PARTIAL
 */

export default function PaymentsPage() {
  const navigate = useNavigate();
  const { user } = useAuth();
  const [searchParams, setSearchParams] = useSearchParams();

  // State management
  const [payments, setPayments] = useState([]);
  const [activeLoans, setActiveLoans] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [filter, setFilter] = useState(searchParams.get('filter') || 'all');
  const [loanFilter, setLoanFilter] = useState(searchParams.get('loan_id') || '');

  // Modal states
  const [markModal, setMarkModal] = useState({
    isOpen: false,
    payment: null,
    amount: '',
    notes: ''
  });
  const [actionLoading, setActionLoading] = useState(false);

  useEffect(() => {
    if (loanFilter) {
      loadPayments();
    } else {
      loadActiveLoans();
    }
  }, [loanFilter]);

  useEffect(() => {
    // Actualizar URL cuando cambian los filtros
    const params = {};
    if (filter !== 'all') params.filter = filter;
    if (loanFilter) params.loan_id = loanFilter;
    setSearchParams(params);
  }, [filter, loanFilter]);

  const loadPayments = async () => {
    try {
      setLoading(true);
      setError(null);

      if (!loanFilter) {
        // Si no hay filtro de préstamo, cargar lista de préstamos activos
        setPayments([]);
        return;
      }

      // GET /payments/loans/:loanId
      const response = await paymentsService.getByLoanId(loanFilter);
      setPayments(response.data || []);
    } catch (err) {
      console.error('Error loading payments:', err);
      setError(err.response?.data?.detail || 'Error al cargar pagos');
    } finally {
      setLoading(false);
    }
  };

  const loadActiveLoans = async () => {
    try {
      setLoading(true);
      setError(null);

      // Importar loansService
      const { loansService } = await import('@/shared/api/services');

      // Obtener préstamos activos (status_id = 2 APPROVED o 3 ACTIVE)
      const response = await loansService.getAll();
      const allLoans = response.data?.items || response.data || [];

      // Filtrar solo préstamos APPROVED (2) o ACTIVE (3)
      const active = allLoans.filter(loan => loan.status_id === 2 || loan.status_id === 3);
      setActiveLoans(active);
    } catch (err) {
      console.error('Error loading active loans:', err);
      setError(err.response?.data?.detail || 'Error al cargar préstamos activos');
    } finally {
      setLoading(false);
    }
  };

  // ============ MAPEO DE ESTADOS BACKEND → UI ============
  const PAYMENT_STATUS = {
    // Pendientes (6)
    PENDING: 1,
    DUE_TODAY: 2,
    OVERDUE: 4,
    PARTIAL: 5,
    IN_COLLECTION: 6,
    RESCHEDULED: 7,
    // Pagados reales (2)
    PAID: 3,
    PAID_PARTIAL: 8,
    // Ficticios (4)
    PAID_BY_ASSOCIATE: 9,
    PAID_NOT_REPORTED: 10,
    FORGIVEN: 11,
    CANCELLED: 12
  };

  const getStatusInfo = (status_id) => {
    const statusMap = {
      // Pendientes
      1: { text: 'Pendiente', class: 'badge-secondary', filter: 'pending', canPay: true },
      2: { text: 'Vence Hoy', class: 'badge-warning', filter: 'pending', canPay: true },
      4: { text: 'Vencido', class: 'badge-danger', filter: 'overdue', canPay: true },
      5: { text: 'Parcial', class: 'badge-info', filter: 'pending', canPay: true },
      6: { text: 'En Cobranza', class: 'badge-danger-alt', filter: 'overdue', canPay: true },
      7: { text: 'Reprogramado', class: 'badge-info', filter: 'pending', canPay: true },
      // Pagados reales
      3: { text: 'Pagado', class: 'badge-success', filter: 'paid', canPay: false },
      8: { text: 'Pago Parcial', class: 'badge-success-alt', filter: 'paid', canPay: false },
      // Ficticios
      9: { text: 'Absorbido', class: 'badge-purple', filter: 'paid', canPay: false },
      10: { text: 'No Reportado', class: 'badge-brown', filter: 'paid', canPay: false },
      11: { text: 'Perdonado', class: 'badge-gray', filter: 'paid', canPay: false },
      12: { text: 'Cancelado', class: 'badge-black', filter: 'paid', canPay: false }
    };
    return statusMap[status_id] || {
      text: 'Desconocido',
      class: 'badge-secondary',
      filter: 'all',
      canPay: false
    };
  };

  // Verificar si un pago puede ser marcado como pagado
  const canMarkAsPaid = (payment) => {
    const statusInfo = getStatusInfo(payment.status_id);
    return statusInfo.canPay;
  };

  // ============ FILTRADO ============
  const filteredPayments = payments.filter(payment => {
    const statusInfo = getStatusInfo(payment.status_id);

    if (filter === 'pending' && statusInfo.filter !== 'pending') return false;
    if (filter === 'overdue' && statusInfo.filter !== 'overdue') return false;
    if (filter === 'paid' && statusInfo.filter !== 'paid') return false;

    return true;
  });

  // ============ UTILIDADES DE FORMATO ============
  const formatCurrency = (amount) => {
    return new Intl.NumberFormat('es-MX', {
      style: 'currency',
      currency: 'MXN',
      minimumFractionDigits: 2
    }).format(amount || 0);
  };

  const formatDate = (dateString) => {
    if (!dateString) return '-';
    return new Date(dateString).toLocaleDateString('es-MX', {
      year: 'numeric',
      month: '2-digit',
      day: '2-digit'
    });
  };

  const getStatusBadge = (status_id) => {
    const statusMap = {
      1: { text: 'Pendiente', class: 'badge-warning' },
      2: { text: 'Aprobado', class: 'badge-info' },
      3: { text: 'Activo', class: 'badge-success' },
    };
    const info = statusMap[status_id] || { text: 'Desconocido', class: 'badge-secondary' };
    return info;
  };

  // ============ ESTADÍSTICAS ============
  const totalPayments = payments.length;
  const totalPaid = payments.filter(p => [3, 8, 9, 10, 11].includes(p.status_id)).length;
  const totalPending = payments.filter(p => [1, 2, 4, 5, 6, 7].includes(p.status_id)).length;
  const totalOverdue = payments.filter(p => [4, 6].includes(p.status_id)).length;

  const totalExpected = payments.reduce((sum, p) => sum + parseFloat(p.expected_amount || 0), 0);
  const totalCollected = payments.reduce((sum, p) => sum + parseFloat(p.amount_paid || 0), 0);
  const collectionRate = totalExpected > 0
    ? ((totalCollected / totalExpected) * 100).toFixed(1)
    : 0;

  // ============ ACCIÓN DE MARCAR COMO PAGADO ============
  const handleMarkAsPaid = async () => {
    if (!markModal.payment) return;

    const amount = parseFloat(markModal.amount);

    // Validaciones
    if (!amount || amount <= 0) {
      alert('Debes ingresar un monto válido');
      return;
    }

    const expectedAmount = parseFloat(markModal.payment.expected_amount);
    const amountPaid = parseFloat(markModal.payment.amount_paid || 0);
    const remaining = expectedAmount - amountPaid;

    if (amount > remaining) {
      alert(`El monto no puede exceder el saldo pendiente: ${formatCurrency(remaining)}`);
      return;
    }

    try {
      setActionLoading(true);

      const payload = {
        marked_by: user.id,
        amount_paid: amount,
        notes: markModal.notes.trim() || null
      };

      // PUT /payments/:id/mark
      await paymentsService.markAsPaid(markModal.payment.id, payload);

      setMarkModal({ isOpen: false, payment: null, amount: '', notes: '' });
      await loadPayments();

      console.log('✅ Pago marcado exitosamente');
    } catch (err) {
      console.error('Error marcando pago:', err);
      alert(err.response?.data?.detail || 'Error al marcar pago');
    } finally {
      setActionLoading(false);
    }
  };

  // ============ RENDER ============
  if (loading) {
    return (
      <div className="payments-page">
        <div className="payments-header">
          <div className="header-content">
            <h1>💰 Gestión de Pagos</h1>
          </div>
        </div>
        <div className="loading-container">
          <div className="skeleton-table">
            <div className="skeleton-row"></div>
            <div className="skeleton-row"></div>
            <div className="skeleton-row"></div>
            <div className="skeleton-row"></div>
          </div>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="payments-page">
        <div className="payments-header">
          <div className="header-content">
            <h1>💰 Gestión de Pagos</h1>
          </div>
        </div>
        <div className="error-container">
          <div className="error-icon">⚠️</div>
          <h3>Error al cargar pagos</h3>
          <p>{error}</p>
          <button className="btn-primary" onClick={loadPayments}>
            🔄 Reintentar
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="payments-page">
      {/* Header */}
      <div className="payments-header">
        <div className="header-content">
          <div className="header-left">
            <h1>💰 Gestión de Pagos</h1>
            <p>Administra los pagos quincenales de todos los préstamos</p>
          </div>
        </div>
      </div>

      {/* Si no hay préstamo seleccionado, mostrar lista de préstamos activos */}
      {!loanFilter ? (
        <div className="loan-selector-container">
          <div className="selector-header">
            <h2>📋 Selecciona un Préstamo</h2>
            <p>Elige un préstamo activo para ver su cronograma de pagos</p>
          </div>

          {activeLoans.length === 0 ? (
            <div className="empty-state">
              <span className="empty-icon">📭</span>
              <h3>No hay préstamos activos</h3>
              <p>No hay préstamos aprobados o activos en este momento</p>
            </div>
          ) : (
            <div className="loans-grid">
              {activeLoans.map(loan => {
                const statusInfo = getStatusBadge(loan.status_id);
                return (
                  <div
                    key={loan.id}
                    className="loan-card"
                    onClick={() => setLoanFilter(loan.id.toString())}
                  >
                    <div className="loan-card-header">
                      <div className="loan-card-title">
                        <span className="loan-id">Préstamo #{loan.id}</span>
                        <span className={`badge ${statusInfo.class}`}>{statusInfo.text}</span>
                      </div>
                      <div className="loan-card-amount">{formatCurrency(loan.amount)}</div>
                    </div>
                    <div className="loan-card-body">
                      <div className="loan-card-info">
                        <span className="info-label">Cliente:</span>
                        <span className="info-value">{loan.client_name || 'N/A'}</span>
                      </div>
                      <div className="loan-card-info">
                        <span className="info-label">Asociado:</span>
                        <span className="info-value">{loan.associate_name || 'Sin asignar'}</span>
                      </div>
                      <div className="loan-card-info">
                        <span className="info-label">Plazo:</span>
                        <span className="info-value">{loan.term_biweeks} quincenas</span>
                      </div>
                      <div className="loan-card-info">
                        <span className="info-label">Creado:</span>
                        <span className="info-value">{formatDate(loan.created_at)}</span>
                      </div>
                    </div>
                    <div className="loan-card-footer">
                      <button className="btn-view-payments">
                        Ver Pagos →
                      </button>
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </div>
      ) : (
        <>
          {/* Summary Stats */}
          <div className="payments-summary">
            <div className="summary-card">
              <div className="summary-label">Total Pagos</div>
              <div className="summary-value">{totalPayments}</div>
            </div>
            <div className="summary-card">
              <div className="summary-label">Pagados</div>
              <div className="summary-value success">{totalPaid}</div>
            </div>
            <div className="summary-card">
              <div className="summary-label">Pendientes</div>
              <div className="summary-value warning">{totalPending}</div>
            </div>
            <div className="summary-card">
              <div className="summary-label">Vencidos</div>
              <div className="summary-value danger">{totalOverdue}</div>
            </div>
            <div className="summary-card">
              <div className="summary-label">Tasa de Cobro</div>
              <div className="summary-value">{collectionRate}%</div>
            </div>
          </div>

          {/* Filters */}
          <div className="payments-filters">
            <div className="filter-buttons">
              <button
                className={`filter-btn ${filter === 'all' ? 'active' : ''}`}
                onClick={() => setFilter('all')}
              >
                Todos ({payments.length})
              </button>
              <button
                className={`filter-btn ${filter === 'pending' ? 'active' : ''}`}
                onClick={() => setFilter('pending')}
              >
                Pendientes ({payments.filter(p => getStatusInfo(p.status_id).filter === 'pending').length})
              </button>
              <button
                className={`filter-btn ${filter === 'overdue' ? 'active' : ''}`}
                onClick={() => setFilter('overdue')}
              >
                Vencidos ({payments.filter(p => getStatusInfo(p.status_id).filter === 'overdue').length})
              </button>
              <button
                className={`filter-btn ${filter === 'paid' ? 'active' : ''}`}
                onClick={() => setFilter('paid')}
              >
                Pagados ({payments.filter(p => getStatusInfo(p.status_id).filter === 'paid').length})
              </button>
            </div>

            <div className="loan-filter">
              <label htmlFor="loanFilter">Filtrar por Préstamo:</label>
              <input
                id="loanFilter"
                type="number"
                placeholder="ID del préstamo"
                value={loanFilter}
                onChange={(e) => setLoanFilter(e.target.value)}
                className="loan-filter-input"
              />
              {loanFilter && (
                <button
                  className="btn-clear"
                  onClick={() => setLoanFilter('')}
                  title="Limpiar filtro"
                >
                  ✕
                </button>
              )}
            </div>
          </div>

          {/* Payments Table */}
          <div className="payments-table-container">
            {filteredPayments.length === 0 ? (
              <div className="empty-state">
                <span className="empty-icon">📭</span>
                <h3>No se encontraron pagos</h3>
                <p>
                  {loanFilter
                    ? `No hay pagos para el préstamo #${loanFilter}`
                    : 'No hay pagos que coincidan con los filtros seleccionados'}
                </p>
              </div>
            ) : (
              <table className="payments-table">
                <thead>
                  <tr>
                    <th>ID Pago</th>
                    <th>Préstamo</th>
                    <th>Cuota #</th>
                    <th>Monto Esperado</th>
                    <th>Monto Pagado</th>
                    <th>Saldo</th>
                    <th>Fecha Vencimiento</th>
                    <th>Estado</th>
                    <th>Acciones</th>
                  </tr>
                </thead>
                <tbody>
                  {filteredPayments.map(payment => {
                    const statusInfo = getStatusInfo(payment.status_id);
                    const remaining = payment.expected_amount - (payment.amount_paid || 0);

                    return (
                      <tr key={payment.id} className={statusInfo.filter}>
                        <td>#{payment.id}</td>
                        <td>
                          <button
                            className="link-btn"
                            onClick={() => navigate(`/prestamos/${payment.loan_id}`)}
                          >
                            Préstamo #{payment.loan_id}
                          </button>
                        </td>
                        <td>Cuota {payment.payment_number}</td>
                        <td>{formatCurrency(payment.expected_amount)}</td>
                        <td className={payment.amount_paid > 0 ? 'paid-amount' : ''}>
                          {formatCurrency(payment.amount_paid || 0)}
                        </td>
                        <td className={remaining > 0 ? 'pending-amount' : 'paid-amount'}>
                          {formatCurrency(remaining)}
                        </td>
                        <td>{formatDate(payment.payment_due_date)}</td>
                        <td>
                          <span className={`badge ${statusInfo.class}`}>
                            {statusInfo.text}
                          </span>
                        </td>
                        <td className="actions-cell">
                          <button
                            className="btn-icon"
                            onClick={() => navigate(`/pagos/${payment.id}`)}
                            title="Ver detalles"
                          >
                            👁️
                          </button>
                          {canMarkAsPaid(payment) && (
                            <button
                              className="btn-icon btn-success"
                              onClick={() => setMarkModal({
                                isOpen: true,
                                payment,
                                amount: remaining.toString(),
                                notes: ''
                              })}
                              title="Marcar como pagado"
                            >
                              💵
                            </button>
                          )}
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            )}
          </div>
        </>
      )}

      {/* Modal de Marcar como Pagado */}
      {markModal.isOpen && (
        <div className="modal-overlay" onClick={() => !actionLoading && setMarkModal({ isOpen: false, payment: null, amount: '', notes: '' })}>
          <div className="modal-content" onClick={(e) => e.stopPropagation()}>
            <h2>💵 Marcar Pago</h2>
            <p>Registra el pago del cliente para la cuota #{markModal.payment?.payment_number}</p>

            <div className="modal-info">
              <strong>Préstamo:</strong> #{markModal.payment?.loan_id}<br />
              <strong>Monto Esperado:</strong> {formatCurrency(markModal.payment?.expected_amount)}<br />
              <strong>Ya Pagado:</strong> {formatCurrency(markModal.payment?.amount_paid || 0)}<br />
              <strong>Saldo Pendiente:</strong> {formatCurrency(markModal.payment?.expected_amount - (markModal.payment?.amount_paid || 0))}
            </div>

            <div className="form-group">
              <label>Monto Recibido (obligatorio):</label>
              <input
                type="number"
                step="0.01"
                min="0.01"
                max={markModal.payment?.expected_amount - (markModal.payment?.amount_paid || 0)}
                value={markModal.amount}
                onChange={(e) => setMarkModal({ ...markModal, amount: e.target.value })}
                placeholder="0.00"
                disabled={actionLoading}
                required
              />
              <small className="hint">
                Puedes registrar un pago parcial o el monto completo
              </small>
            </div>

            <div className="form-group">
              <label>Notas (opcional):</label>
              <textarea
                value={markModal.notes}
                onChange={(e) => setMarkModal({ ...markModal, notes: e.target.value })}
                placeholder="Método de pago, referencia, comentarios..."
                rows="3"
                disabled={actionLoading}
              />
            </div>

            <div className="modal-actions">
              <button
                className="btn-secondary"
                onClick={() => setMarkModal({ isOpen: false, payment: null, amount: '', notes: '' })}
                disabled={actionLoading}
              >
                Cancelar
              </button>
              <button
                className="btn-primary"
                onClick={handleMarkAsPaid}
                disabled={actionLoading || !markModal.amount || parseFloat(markModal.amount) <= 0}
              >
                {actionLoading ? 'Registrando...' : 'Confirmar Pago'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
