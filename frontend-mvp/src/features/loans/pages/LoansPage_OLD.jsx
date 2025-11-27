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
  const [filter, setFilter] = useState('all'); // all, pending, active, completed
  const [searchTerm, setSearchTerm] = useState('');

  // Modal states
  const [approveModal, setApproveModal] = useState({ isOpen: false, loan: null });
  const [rejectModal, setRejectModal] = useState({ isOpen: false, loan: null, reason: '' });
  const [actionLoading, setActionLoading] = useState(false);

  useEffect(() => {
    loadLoans();
  }, []);

  const loadLoans = async () => {
    try {
      setLoading(true);
      setError(null);

      // GET /api/v1/loans (retorna PaginatedLoansDTO)
      const { data } = await loansService.getAll();

      // data = { items: [...], total, limit, offset }
      setLoans(data.items || []);
    } catch (err) {
      console.error('Error loading loans:', err);
      setError(err.response?.data?.detail || 'Error al cargar préstamos');
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

  // Verificar si un préstamo puede ser aprobado o rechazado
  const canApproveOrReject = (loan) => loan.status_id === LOAN_STATUS.PENDING;

  // ============ FILTRADO Y BÚSQUEDA ============
  const filteredLoans = loans.filter(loan => {
    const statusInfo = getStatusInfo(loan.status_id);

    // Filtro por estado
    if (filter === 'pending' && statusInfo.filter !== 'pending') return false;
    if (filter === 'active' && statusInfo.filter !== 'active') return false;
    if (filter === 'completed' && statusInfo.filter !== 'completed') return false;

    // Filtro por búsqueda (ID o nombre de asociado)
    if (searchTerm) {
      const search = searchTerm.toLowerCase();
      const associateName = loan.client_name || loan.associate_name || '';
      return (
        loan.id.toString().includes(search) ||
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
      minimumFractionDigits: 0
    }).format(amount);
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
  // remaining_balance debe calcularse desde payments en backend, si no existe usar amount
  const totalPending = loans.reduce((sum, loan) => {
    // Si el préstamo está activo/vencido/mora, contar el monto completo
    if ([3, 5, 9].includes(loan.status_id)) {
      return sum + parseFloat(loan.amount || 0);
    }
    return sum;
  }, 0);
  const recoveryRate = totalLent > 0
    ? ((totalLent - totalPending) / totalLent * 100).toFixed(1)
    : 0;

  // ============ ACCIONES DE APROBACIÓN Y RECHAZO ============
  /**
   * Aprobar préstamo (solo si status_id === 1 PENDING)
   * Backend automáticamente:
   * - Cambia status_id a 2 (APPROVED)
   * - Ejecuta trigger generate_payment_schedule()
   * - Actualiza associate.credit_used
   */
  const handleApproveLoan = async (notes = '') => {
    if (!approveModal.loan) return;

    try {
      setActionLoading(true);

      const payload = {
        approved_by: user.id,
        notes: notes.trim() || null
      };

      await loansService.approve(approveModal.loan.id, payload);

      // Éxito: cerrar modal y recargar lista
      setApproveModal({ isOpen: false, loan: null });
      await loadLoans();

      // TODO: Mostrar toast de éxito (Fase 7)
      console.log('✅ Préstamo aprobado exitosamente');
    } catch (err) {
      console.error('Error aprobando préstamo:', err);
      alert(err.response?.data?.detail || 'Error al aprobar préstamo');
    } finally {
      setActionLoading(false);
    }
  };

  /**
   * Rechazar préstamo (solo si status_id === 1 PENDING)
   * Backend requiere:
   * - rejection_reason: OBLIGATORIO, min 10 chars, max 1000
   */
  const handleRejectLoan = async () => {
    if (!rejectModal.loan) return;

    const reason = rejectModal.reason.trim();

    // Validación frontend (backend también valida)
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

      // Éxito: cerrar modal y recargar lista
      setRejectModal({ isOpen: false, loan: null, reason: '' });
      await loadLoans();

      // TODO: Mostrar toast de éxito (Fase 7)
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
            Activos ({loans.filter(l => l.status === 'active').length})
          </button>
          <button
            className={`filter-btn ${filter === 'pending' ? 'active' : ''}`}
            onClick={() => setFilter('pending')}
          >
            Pendientes ({loans.filter(l => l.status === 'pending_approval').length})
          </button>
          <button
            className={`filter-btn ${filter === 'completed' ? 'active' : ''}`}
            onClick={() => setFilter('completed')}
          >
            Completados ({loans.filter(l => l.status === 'completed').length})
          </button>
        </div>

        <div className="search-box">
          <span className="search-icon">🔍</span>
          <input
            type="text"
            placeholder="Buscar por ID o nombre de asociado..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
          />
        </div>
      </div>

      {/* Loans Table */}
      <div className="loans-table-container">
        {loading ? (
          <div className="loading-state">
            <div className="spinner"></div>
            <p>Cargando préstamos...</p>
          </div>
        ) : filteredLoans.length === 0 ? (
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
                <th>Asociado</th>
                <th>Monto</th>
                <th>Cuotas</th>
                <th>Frecuencia</th>
                <th>Saldo</th>
                <th>Fecha Inicio</th>
                <th>Estado</th>
                <th>Acciones</th>
              </tr>
            </thead>
            <tbody>
              {filteredLoans.map(loan => {
                const badge = getStatusBadge(loan.status);
                return (
                  <tr key={loan.id} className="loan-row">
                    <td className="loan-id">#{loan.id}</td>
                    <td className="loan-associate">
                      <div className="associate-cell">
                        <div className="associate-avatar">
                          {loan.associate_name?.charAt(0).toUpperCase() || 'A'}
                        </div>
                        <div className="associate-info">
                          <span className="associate-name">{loan.associate_name || 'N/A'}</span>
                          <span className="associate-id">ID: {loan.associate_id}</span>
                        </div>
                      </div>
                    </td>
                    <td className="loan-amount">{formatCurrency(loan.loan_amount)}</td>
                    <td className="loan-installments">{loan.number_of_installments}</td>
                    <td className="loan-frequency">{getPaymentFrequency(loan.payment_frequency)}</td>
                    <td className="loan-balance">
                      <span className={loan.remaining_balance > 0 ? 'balance-pending' : 'balance-paid'}>
                        {formatCurrency(loan.remaining_balance)}
                      </span>
                    </td>
                    <td className="loan-date">{formatDate(loan.start_date)}</td>
                    <td>
                      <span className={`status-badge ${badge.class}`}>
                        {badge.text}
                      </span>
                    </td>
                    <td className="loan-actions">
                      <button
                        className="btn-action btn-view"
                        onClick={() => navigate(`/prestamos/${loan.id}`)}
                        title="Ver detalles"
                      >
                        👁️
                      </button>
                      {loan.status === 'pending_approval' && (
                        <button
                          className="btn-action btn-approve"
                          onClick={() => navigate(`/prestamos/${loan.id}/aprobar`)}
                          title="Aprobar"
                        >
                          ✅
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

      {/* Stats Summary */}
      {!loading && loans.length > 0 && (
        <div className="loans-summary">
          <div className="summary-card">
            <span className="summary-label">Total Préstamos</span>
            <span className="summary-value">{loans.length}</span>
          </div>
          <div className="summary-card">
            <span className="summary-label">Total Prestado</span>
            <span className="summary-value">
              {formatCurrency(loans.reduce((sum, l) => sum + l.loan_amount, 0))}
            </span>
          </div>
          <div className="summary-card">
            <span className="summary-label">Total Pendiente</span>
            <span className="summary-value">
              {formatCurrency(loans.reduce((sum, l) => sum + l.remaining_balance, 0))}
            </span>
          </div>
          <div className="summary-card">
            <span className="summary-label">Tasa Recuperación</span>
            <span className="summary-value">
              {((1 - loans.reduce((sum, l) => sum + l.remaining_balance, 0) /
                loans.reduce((sum, l) => sum + l.loan_amount, 0)) * 100).toFixed(1)}%
            </span>
          </div>
        </div>
      )}
    </div>
  );
}
