import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '@/app/providers/AuthProvider';
import { loansService } from '@/shared/api/services';
import './LoansPage.css';

/**
 * LoansPage - Vista principal de gestión de préstamos
 * 
 * Lógica del Sistema (Backend v2.0):
 * - Estados de préstamo (status_id):
 *   1 = PENDING (pendiente aprobación)
 *   2 = APPROVED (aprobado, cronograma generado)
 *   3 = ACTIVE (activo, en cobro)
 *   4 = PAID_OFF (liquidado)
 *   5 = DEFAULTED (en mora)
 *   6 = REJECTED (rechazado)
 * 
 * - Solo préstamos en PENDING pueden ser aprobados/rechazados
 * - Al aprobar: trigger genera cronograma automáticamente
 * - Al rechazar: rejection_reason es OBLIGATORIO (min 10 chars)
 */

export default function LoansPage() {
  const navigate = useNavigate();
  const { user } = useAuth();

  // State management
  const [loans, setLoans] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [filter, setFilter] = useState('all');
  const [searchTerm, setSearchTerm] = useState('');

  // Modal states
  const [approveModal, setApproveModal] = useState({ isOpen: false, loan: null, notes: '' });
  const [rejectModal, setRejectModal] = useState({ isOpen: false, loan: null, reason: '' });
  const [actionLoading, setActionLoading] = useState(false);

  useEffect(() => {
    loadLoans();
  }, []);

  const loadLoans = async () => {
    try {
      setLoading(true);
      setError(null);

      const response = await loansService.getAll();
      // El backend retorna { items: [], total: X, limit: Y, offset: Z }
      const items = response.data?.items || response.data || [];
      setLoans(Array.isArray(items) ? items : []);
    } catch (err) {
      console.error('Error loading loans:', err);
      setError(err.response?.data?.detail || 'Error al cargar préstamos');
      setLoans([]);
    } finally {
      setLoading(false);
    }
  };

  // ============ MAPEO DE ESTADOS BACKEND → UI ============
  const LOAN_STATUS = {
    PENDING: 1,
    APPROVED: 2,
    ACTIVE: 3,
    PAID_OFF: 4,
    DEFAULTED: 5,
    REJECTED: 6,
    CANCELLED: 7,
    RESTRUCTURED: 8,
    OVERDUE: 9,
    EARLY_PAYMENT: 10
  };

  const getStatusInfo = (status_id) => {
    const statusMap = {
      1: { text: 'Pendiente Aprobación', class: 'badge-warning', filter: 'pending' },
      2: { text: 'Aprobado', class: 'badge-info', filter: 'active' },
      3: { text: 'Activo', class: 'badge-success', filter: 'active' },
      4: { text: 'Liquidado', class: 'badge-success', filter: 'completed' },
      5: { text: 'En Mora', class: 'badge-danger', filter: 'active' },
      6: { text: 'Rechazado', class: 'badge-danger', filter: 'completed' },
      7: { text: 'Cancelado', class: 'badge-secondary', filter: 'completed' },
      8: { text: 'Reestructurado', class: 'badge-info', filter: 'active' },
      9: { text: 'Vencido', class: 'badge-danger', filter: 'active' },
      10: { text: 'Pago Anticipado', class: 'badge-success', filter: 'completed' }
    };
    return statusMap[status_id] || { text: 'Desconocido', class: 'badge-secondary', filter: 'all' };
  };

  const canApproveOrReject = (loan) => loan.status_id === LOAN_STATUS.PENDING;

  // ============ FILTRADO Y BÚSQUEDA ============
  const filteredLoans = loans.filter(loan => {
    const statusInfo = getStatusInfo(loan.status_id);

    if (filter === 'pending' && statusInfo.filter !== 'pending') return false;
    if (filter === 'active' && statusInfo.filter !== 'active') return false;
    if (filter === 'completed' && statusInfo.filter !== 'completed') return false;

    if (searchTerm) {
      const search = searchTerm.toLowerCase();
      const clientName = loan.client_name || '';
      const associateName = loan.associate_name || '';
      return (
        loan.id.toString().includes(search) ||
        clientName.toLowerCase().includes(search) ||
        associateName.toLowerCase().includes(search)
      );
    }

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

  const getPaymentFrequency = (term_biweeks) => {
    return term_biweeks ? `${term_biweeks} quincenas` : '-';
  };

  // ============ ESTADÍSTICAS ============
  const totalLoans = loans.length;
  const totalLent = loans.reduce((sum, loan) => sum + parseFloat(loan.amount || 0), 0);
  const totalPending = loans.reduce((sum, loan) => {
    if ([3, 5, 9].includes(loan.status_id)) {
      return sum + parseFloat(loan.amount || 0);
    }
    return sum;
  }, 0);
  const recoveryRate = totalLent > 0
    ? ((totalLent - totalPending) / totalLent * 100).toFixed(1)
    : 0;

  // ============ ACCIONES DE APROBACIÓN Y RECHAZO ============
  const handleApproveLoan = async () => {
    if (!approveModal.loan) return;

    try {
      setActionLoading(true);

      const payload = {
        approved_by: user.id,
        notes: approveModal.notes.trim() || null
      };

      await loansService.approve(approveModal.loan.id, payload);

      setApproveModal({ isOpen: false, loan: null, notes: '' });
      await loadLoans();

      console.log('✅ Préstamo aprobado exitosamente');
    } catch (err) {
      console.error('Error aprobando préstamo:', err);
      alert(err.response?.data?.detail || 'Error al aprobar préstamo');
    } finally {
      setActionLoading(false);
    }
  };

  const handleRejectLoan = async () => {
    if (!rejectModal.loan) return;

    const reason = rejectModal.reason.trim();

    if (reason.length < 10) {
      alert('La razón del rechazo debe tener al menos 10 caracteres');
      return;
    }

    try {
      setActionLoading(true);

      const payload = {
        rejected_by: user.id,
        rejection_reason: reason
      };

      await loansService.reject(rejectModal.loan.id, payload);

      setRejectModal({ isOpen: false, loan: null, reason: '' });
      await loadLoans();

      console.log('✅ Préstamo rechazado exitosamente');
    } catch (err) {
      console.error('Error rechazando préstamo:', err);
      alert(err.response?.data?.detail || 'Error al rechazar préstamo');
    } finally {
      setActionLoading(false);
    }
  };

  // ============ RENDER ============
  if (loading) {
    return (
      <div className="loans-page">
        <div className="loans-header">
          <div className="header-content">
            <h1>💰 Gestión de Préstamos</h1>
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
      <div className="loans-page">
        <div className="loans-header">
          <div className="header-content">
            <h1>💰 Gestión de Préstamos</h1>
          </div>
        </div>
        <div className="error-container">
          <div className="error-icon">⚠️</div>
          <h3>Error al cargar préstamos</h3>
          <p>{error}</p>
          <button className="btn-primary" onClick={loadLoans}>
            🔄 Reintentar
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="loans-page">
      {/* Header */}
      <div className="loans-header">
        <div className="header-content">
          <div className="header-left">
            <h1>💰 Gestión de Préstamos</h1>
            <p>Administra todos los préstamos del sistema</p>
          </div>
          <button
            className="btn-primary"
            onClick={() => navigate('/prestamos/nuevo')}
          >
            <span className="btn-icon">➕</span>
            Nuevo Préstamo
          </button>
        </div>
      </div>

      {/* Summary Stats */}
      <div className="loans-summary">
        <div className="summary-card">
          <div className="summary-label">Total Préstamos</div>
          <div className="summary-value">{totalLoans}</div>
        </div>
        <div className="summary-card">
          <div className="summary-label">Total Prestado</div>
          <div className="summary-value">{formatCurrency(totalLent)}</div>
        </div>
        <div className="summary-card">
          <div className="summary-label">Total Pendiente</div>
          <div className="summary-value">{formatCurrency(totalPending)}</div>
        </div>
        <div className="summary-card">
          <div className="summary-label">Tasa de Recuperación</div>
          <div className="summary-value">{recoveryRate}%</div>
        </div>
      </div>

      {/* Filters and Search */}
      <div className="loans-filters">
        <div className="filter-buttons">
          <button
            className={`filter-btn ${filter === 'all' ? 'active' : ''}`}
            onClick={() => setFilter('all')}
          >
            Todos ({loans.length})
          </button>
          <button
            className={`filter-btn ${filter === 'pending' ? 'active' : ''}`}
            onClick={() => setFilter('pending')}
          >
            Pendientes ({loans.filter(l => getStatusInfo(l.status_id).filter === 'pending').length})
          </button>
          <button
            className={`filter-btn ${filter === 'active' ? 'active' : ''}`}
            onClick={() => setFilter('active')}
          >
            Activos ({loans.filter(l => getStatusInfo(l.status_id).filter === 'active').length})
          </button>
          <button
            className={`filter-btn ${filter === 'completed' ? 'active' : ''}`}
            onClick={() => setFilter('completed')}
          >
            Completados ({loans.filter(l => getStatusInfo(l.status_id).filter === 'completed').length})
          </button>
        </div>
        <div className="search-box">
          <input
            type="text"
            placeholder="Buscar por ID o nombre..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="search-input"
          />
        </div>
      </div>

      {/* Loans Table */}
      <div className="loans-table-container">
        {filteredLoans.length === 0 ? (
          <div className="empty-state">
            <span className="empty-icon">📭</span>
            <h3>No se encontraron préstamos</h3>
            <p>
              {searchTerm
                ? 'Intenta con otro término de búsqueda'
                : 'Crea tu primer préstamo para comenzar'}
            </p>
          </div>
        ) : (
          <table className="loans-table">
            <thead>
              <tr>
                <th>ID</th>
                <th>Cliente</th>
                <th>Asociado</th>
                <th>Monto</th>
                <th>Cuotas</th>
                <th>Saldo</th>
                <th>Fecha</th>
                <th>Estado</th>
                <th>Acciones</th>
              </tr>
            </thead>
            <tbody>
              {filteredLoans.map(loan => {
                const statusInfo = getStatusInfo(loan.status_id);

                return (
                  <tr key={loan.id}>
                    <td>#{loan.id}</td>
                    <td>{loan.client_name || 'N/A'}</td>
                    <td>{loan.associate_name || 'Sin asignar'}</td>
                    <td>{formatCurrency(loan.amount)}</td>
                    <td>{getPaymentFrequency(loan.term_biweeks)}</td>
                    <td>{formatCurrency(loan.amount)}</td>
                    <td>{formatDate(loan.created_at)}</td>
                    <td>
                      <span className={`badge ${statusInfo.class}`}>
                        {statusInfo.text}
                      </span>
                    </td>
                    <td className="actions-cell">
                      <button
                        className="btn-icon"
                        onClick={() => navigate(`/prestamos/${loan.id}`)}
                        title="Ver detalles"
                      >
                        👁️
                      </button>
                      {canApproveOrReject(loan) && (
                        <>
                          <button
                            className="btn-icon btn-success"
                            onClick={() => setApproveModal({ isOpen: true, loan, notes: '' })}
                            title="Aprobar préstamo"
                          >
                            ✅
                          </button>
                          <button
                            className="btn-icon btn-danger"
                            onClick={() => setRejectModal({ isOpen: true, loan, reason: '' })}
                            title="Rechazar préstamo"
                          >
                            ❌
                          </button>
                        </>
                      )}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        )}
      </div>

      {/* Modal de Aprobación */}
      {approveModal.isOpen && (
        <div className="modal-overlay" onClick={() => !actionLoading && setApproveModal({ isOpen: false, loan: null, notes: '' })}>
          <div className="modal-content" onClick={(e) => e.stopPropagation()}>
            <h2>✅ Aprobar Préstamo</h2>
            <p>¿Estás seguro de aprobar el préstamo #{approveModal.loan?.id}?</p>
            <p className="modal-info">
              <strong>Asociado:</strong> {approveModal.loan?.client_name || 'N/A'}<br />
              <strong>Monto:</strong> {formatCurrency(approveModal.loan?.amount)}<br />
              <strong>Plazo:</strong> {getPaymentFrequency(approveModal.loan?.term_biweeks)}
            </p>

            <div className="form-group">
              <label>Notas (opcional):</label>
              <textarea
                value={approveModal.notes}
                onChange={(e) => setApproveModal({ ...approveModal, notes: e.target.value })}
                placeholder="Agrega notas sobre esta aprobación..."
                rows="3"
                disabled={actionLoading}
              />
            </div>

            <div className="modal-actions">
              <button
                className="btn-secondary"
                onClick={() => setApproveModal({ isOpen: false, loan: null, notes: '' })}
                disabled={actionLoading}
              >
                Cancelar
              </button>
              <button
                className="btn-primary"
                onClick={handleApproveLoan}
                disabled={actionLoading}
              >
                {actionLoading ? 'Aprobando...' : 'Confirmar Aprobación'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Modal de Rechazo */}
      {rejectModal.isOpen && (
        <div className="modal-overlay" onClick={() => !actionLoading && setRejectModal({ isOpen: false, loan: null, reason: '' })}>
          <div className="modal-content" onClick={(e) => e.stopPropagation()}>
            <h2>❌ Rechazar Préstamo</h2>
            <p>¿Estás seguro de rechazar el préstamo #{rejectModal.loan?.id}?</p>
            <p className="modal-info">
              <strong>Asociado:</strong> {rejectModal.loan?.client_name || 'N/A'}<br />
              <strong>Monto:</strong> {formatCurrency(rejectModal.loan?.amount)}
            </p>

            <div className="form-group">
              <label>Razón del rechazo (obligatorio, mínimo 10 caracteres):</label>
              <textarea
                value={rejectModal.reason}
                onChange={(e) => setRejectModal({ ...rejectModal, reason: e.target.value })}
                placeholder="Explica la razón del rechazo..."
                rows="4"
                disabled={actionLoading}
                required
              />
              <small className={`char-count ${rejectModal.reason.length < 10 ? 'invalid' : 'valid'}`}>
                {rejectModal.reason.length} / 10 caracteres mínimos
              </small>
            </div>

            <div className="modal-actions">
              <button
                className="btn-secondary"
                onClick={() => setRejectModal({ isOpen: false, loan: null, reason: '' })}
                disabled={actionLoading}
              >
                Cancelar
              </button>
              <button
                className="btn-danger"
                onClick={handleRejectLoan}
                disabled={actionLoading || rejectModal.reason.trim().length < 10}
              >
                {actionLoading ? 'Rechazando...' : 'Confirmar Rechazo'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
