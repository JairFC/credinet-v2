import { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { loansService } from '@/shared/api/services';
import './LoanDetailPage.css';

/**
 * LoanDetailPage - Vista detallada de un préstamo
 * 
 * Muestra:
 * - Información completa del préstamo
 * - Datos del cliente y asociado
 * - Cálculos de tasas e intereses
 * - Cronograma de pagos (si está aprobado)
 * - Historial de acciones
 */
export default function LoanDetailPage() {
  const { id } = useParams();
  const navigate = useNavigate();

  const [loan, setLoan] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    if (id) {
      loadLoanDetail();
    }
  }, [id]);

  const loadLoanDetail = async () => {
    if (!id) return;

    try {
      setLoading(true);
      setError(null);

      const response = await loansService.getById(id);
      setLoan(response.data);
    } catch (err) {
      console.error('Error loading loan detail:', err);
      setError(err.response?.data?.detail || 'Error al cargar préstamo');
    } finally {
      setLoading(false);
    }
  };

  // ============ MAPEO DE ESTADOS ============
  const getStatusInfo = (status_id) => {
    const statusMap = {
      1: { text: 'Pendiente Aprobación', class: 'badge-warning', icon: '⏳' },
      2: { text: 'Aprobado', class: 'badge-info', icon: '✅' },
      3: { text: 'Activo', class: 'badge-success', icon: '💰' },
      4: { text: 'Liquidado', class: 'badge-success', icon: '✔️' },
      5: { text: 'En Mora', class: 'badge-danger', icon: '⚠️' },
      6: { text: 'Rechazado', class: 'badge-danger', icon: '❌' },
      7: { text: 'Cancelado', class: 'badge-secondary', icon: '🚫' },
    };
    return statusMap[status_id] || { text: 'Desconocido', class: 'badge-secondary', icon: '❓' };
  };

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
      month: 'long',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
  };

  const formatPercent = (value) => {
    return `${parseFloat(value || 0).toFixed(2)}%`;
  };

  // ============ CÁLCULOS ============
  const calculateTotalInterest = () => {
    if (!loan) return 0;
    return loan.total_interest || (loan.total_to_pay - loan.amount) || 0;
  };

  const calculateTotalCommission = () => {
    if (!loan) return 0;
    return loan.total_commission || (loan.commission_per_payment * loan.term_biweeks) || 0;
  };

  // ============ RENDER ============
  if (loading) {
    return (
      <div className="loan-detail-page">
        <div className="page-header">
          <button className="btn-back" onClick={() => navigate('/prestamos')}>
            ← Volver
          </button>
          <h1>Cargando préstamo...</h1>
        </div>
        <div className="loading-spinner">
          <div className="spinner"></div>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="loan-detail-page">
        <div className="page-header">
          <button className="btn-back" onClick={() => navigate('/prestamos')}>
            ← Volver
          </button>
          <h1>Error</h1>
        </div>
        <div className="error-container">
          <div className="error-icon">⚠️</div>
          <h3>Error al cargar préstamo</h3>
          <p>{error}</p>
          <button className="btn-primary" onClick={loadLoanDetail}>
            🔄 Reintentar
          </button>
        </div>
      </div>
    );
  }

  if (!loan) {
    return (
      <div className="loan-detail-page">
        <div className="page-header">
          <button className="btn-back" onClick={() => navigate('/prestamos')}>
            ← Volver
          </button>
          <h1>Préstamo no encontrado</h1>
        </div>
      </div>
    );
  }

  const statusInfo = getStatusInfo(loan.status_id);

  return (
    <div className="loan-detail-page">
      {/* Header */}
      <div className="page-header">
        <div className="header-left">
          <button className="btn-back" onClick={() => navigate('/prestamos')}>
            ← Volver
          </button>
          <div className="header-title">
            <h1>Préstamo #{loan.id}</h1>
            <span className={`badge ${statusInfo.class}`}>
              {statusInfo.icon} {statusInfo.text}
            </span>
          </div>
        </div>
        <div className="header-actions">
          {loan.status_id === 3 && (
            <button
              className="btn-primary"
              onClick={() => navigate(`/pagos?loan_id=${loan.id}`)}
            >
              📅 Ver Pagos
            </button>
          )}
        </div>
      </div>

      <div className="loan-detail-container">
        {/* Sección: Información General */}
        <div className="detail-section">
          <h2>📋 Información General</h2>
          <div className="info-grid">
            <div className="info-item">
              <label>Monto Solicitado</label>
              <div className="value-large">{formatCurrency(loan.amount)}</div>
            </div>
            <div className="info-item">
              <label>Plazo</label>
              <div className="value-large">{loan.term_biweeks} quincenas</div>
            </div>
            <div className="info-item">
              <label>Pago Quincenal</label>
              <div className="value-large">{formatCurrency(loan.payment_amount || loan.biweekly_payment)}</div>
            </div>
            <div className="info-item">
              <label>Total a Pagar</label>
              <div className="value-large">{formatCurrency(loan.total_to_pay || loan.total_payment)}</div>
            </div>
          </div>
        </div>

        {/* Sección: Cliente y Asociado */}
        <div className="detail-section">
          <h2>👥 Cliente y Asociado</h2>
          <div className="info-grid-2">
            <div className="info-card">
              <div className="card-header">
                <span className="card-icon">👤</span>
                <h3>Cliente</h3>
              </div>
              <div className="card-content">
                <div className="info-row">
                  <label>Nombre:</label>
                  <span>{loan.client_name || 'N/A'}</span>
                </div>
                <div className="info-row">
                  <label>ID:</label>
                  <span>#{loan.user_id}</span>
                </div>
              </div>
            </div>

            <div className="info-card">
              <div className="card-header">
                <span className="card-icon">👔</span>
                <h3>Asociado</h3>
              </div>
              <div className="card-content">
                <div className="info-row">
                  <label>Nombre:</label>
                  <span>{loan.associate_name || 'Sin asignar'}</span>
                </div>
                <div className="info-row">
                  <label>ID:</label>
                  <span>{loan.associate_user_id ? `#${loan.associate_user_id}` : 'N/A'}</span>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Sección: Tasas y Cálculos */}
        <div className="detail-section">
          <h2>📊 Tasas y Cálculos</h2>
          <div className="info-grid-3">
            <div className="info-card">
              <label>Tasa de Interés</label>
              <div className="value-highlight">{formatPercent(loan.interest_rate)}</div>
              <div className="value-sub">Total: {formatCurrency(calculateTotalInterest())}</div>
            </div>
            <div className="info-card">
              <label>Tasa de Comisión</label>
              <div className="value-highlight">{formatPercent(loan.commission_rate)}</div>
              <div className="value-sub">Total: {formatCurrency(calculateTotalCommission())}</div>
            </div>
            <div className="info-card">
              <label>Perfil de Tasa</label>
              <div className="value-highlight">{loan.profile_code || 'Manual'}</div>
              <div className="value-sub">{loan.profile_code ? 'Perfil configurado' : 'Tasas manuales'}</div>
            </div>
          </div>
        </div>

        {/* Sección: Fechas e Historial */}
        <div className="detail-section">
          <h2>📅 Fechas e Historial</h2>
          <div className="timeline">
            <div className="timeline-item">
              <span className="timeline-icon">📝</span>
              <div className="timeline-content">
                <label>Creación</label>
                <span>{formatDate(loan.created_at)}</span>
              </div>
            </div>

            {loan.approved_at && (
              <div className="timeline-item">
                <span className="timeline-icon">✅</span>
                <div className="timeline-content">
                  <label>Aprobación</label>
                  <span>{formatDate(loan.approved_at)}</span>
                  {loan.approver_name && <div className="timeline-sub">Por: {loan.approver_name}</div>}
                </div>
              </div>
            )}

            {loan.rejected_at && (
              <div className="timeline-item">
                <span className="timeline-icon">❌</span>
                <div className="timeline-content">
                  <label>Rechazo</label>
                  <span>{formatDate(loan.rejected_at)}</span>
                  {loan.rejecter_name && <div className="timeline-sub">Por: {loan.rejecter_name}</div>}
                  {loan.rejection_reason && (
                    <div className="rejection-reason">
                      <strong>Razón:</strong> {loan.rejection_reason}
                    </div>
                  )}
                </div>
              </div>
            )}

            <div className="timeline-item">
              <span className="timeline-icon">🔄</span>
              <div className="timeline-content">
                <label>Última Actualización</label>
                <span>{formatDate(loan.updated_at)}</span>
              </div>
            </div>
          </div>
        </div>

        {/* Sección: Notas */}
        {loan.notes && (
          <div className="detail-section">
            <h2>📝 Notas</h2>
            <div className="notes-box">
              {loan.notes}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
