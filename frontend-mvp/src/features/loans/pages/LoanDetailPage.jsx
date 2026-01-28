import { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { loansService } from '@/shared/api/services';
import TablaAmortizacion from '../components/simulator/TablaAmortizacion';
import LoanSummaryDisplay from '../components/LoanSummaryDisplay';
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
  const [amortization, setAmortization] = useState(null);
  const [amortizationLoading, setAmortizationLoading] = useState(false);
  const [isSimulation, setIsSimulation] = useState(false);

  // Estado para modal de eliminación con doble confirmación
  const [deleteModal, setDeleteModal] = useState({
    isOpen: false,
    step: 1, // 1 = primera confirmación, 2 = segunda confirmación
    deleting: false
  });

  useEffect(() => {
    if (id) {
      loadLoanDetail();
      loadAmortization();
    }
  }, [id]);

  const loadLoanDetail = async () => {
    if (!id) return;

    try {
      setLoading(true);
      setError(null);

      const response = await loansService.getById(id);
      console.log('=== LOAN DATA LOADED ===', response.data);
      console.log('client_name:', response.data.client_name);
      console.log('associate_name:', response.data.associate_name);
      console.log('interest_rate:', response.data.interest_rate);
      console.log('commission_rate:', response.data.commission_rate);
      setLoan(response.data);
    } catch (err) {
      console.error('Error loading loan detail:', err);
      setError(err.response?.data?.detail || 'Error al cargar préstamo');
    } finally {
      setLoading(false);
    }
  };

  const loadAmortization = async () => {
    if (!id) return;

    try {
      setAmortizationLoading(true);
      const response = await loansService.getAmortization(id);
      console.log('Amortization response:', response.data);
      setAmortization(response.data.schedule);
      setIsSimulation(response.data.is_simulation);
    } catch (err) {
      console.error('Error loading amortization:', err);
      console.error('Error details:', err.response?.data);
      // No mostrar error crítico si falla la amortización
    } finally {
      setAmortizationLoading(false);
    }
  };

  // ============ MAPEO DE ESTADOS ============
  const getStatusInfo = (status_id) => {
    const statusMap = {
      1: { text: 'Pendiente Aprobación', class: 'badge-warning', icon: '⏳' },
      2: { text: 'Activo', class: 'badge-success', icon: '💰' },
      4: { text: 'Completado', class: 'badge-info', icon: '✔️' },
      5: { text: 'Pagado', class: 'badge-success', icon: '✅' },
      6: { text: 'En Mora', class: 'badge-danger', icon: '⚠️' },
      7: { text: 'Rechazado', class: 'badge-danger', icon: '❌' },
      8: { text: 'Cancelado', class: 'badge-secondary', icon: '🚫' },
      9: { text: 'En Convenio', class: 'badge-info', icon: '📋' },
    };
    return statusMap[status_id] || { text: 'Desconocido', class: 'badge-secondary', icon: '❓' };
  };

  // ============ UTILIDADES DE FORMATO ============
  const formatCurrency = (amount) => {
    const numericAmount = parseFloat(amount);
    if (isNaN(numericAmount)) return '$0.00';

    return new Intl.NumberFormat('es-MX', {
      style: 'currency',
      currency: 'MXN',
      minimumFractionDigits: 2
    }).format(numericAmount);
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
    const totalInterest = parseFloat(loan.total_interest);
    if (!isNaN(totalInterest)) return totalInterest;

    const totalToPay = parseFloat(loan.total_to_pay);
    const amount = parseFloat(loan.amount);
    return (!isNaN(totalToPay) && !isNaN(amount)) ? (totalToPay - amount) : 0;
  };

  const calculateTotalCommission = () => {
    if (!loan) return 0;
    const totalCommission = parseFloat(loan.total_commission);
    if (!isNaN(totalCommission)) return totalCommission;

    // Calcular comisión por pago: monto × commission_rate%
    const amount = parseFloat(loan.amount);
    const commissionRate = parseFloat(loan.commission_rate);
    const termBiweeks = parseInt(loan.term_biweeks);

    if (!isNaN(amount) && !isNaN(commissionRate) && !isNaN(termBiweeks)) {
      const commissionPerPayment = (amount * commissionRate) / 100;
      return commissionPerPayment * termBiweeks;
    }

    return 0;
  };

  const calculateAssociatePayment = () => {
    if (!loan) return 0;
    const associatePayment = parseFloat(loan.associate_payment);
    if (!isNaN(associatePayment)) return associatePayment;

    // Pago asociado = pago cliente - comisión
    const biweeklyPayment = parseFloat(loan.payment_amount || loan.biweekly_payment);
    const amount = parseFloat(loan.amount);
    const commissionRate = parseFloat(loan.commission_rate);

    if (!isNaN(biweeklyPayment) && !isNaN(amount) && !isNaN(commissionRate)) {
      const commissionPerPayment = (amount * commissionRate) / 100;
      return biweeklyPayment - commissionPerPayment;
    }

    return 0;
  };

  const calculateAssociateTotal = () => {
    if (!loan) return 0;
    const associateTotal = parseFloat(loan.associate_total);
    if (!isNaN(associateTotal)) return associateTotal;

    // Total asociado = pago asociado × plazo
    const associatePayment = calculateAssociatePayment();
    const termBiweeks = parseInt(loan.term_biweeks);

    if (!isNaN(associatePayment) && !isNaN(termBiweeks)) {
      return associatePayment * termBiweeks;
    }

    return 0;
  };

  // ============ FUNCIONES DE ELIMINACIÓN ============
  const canDeleteLoan = () => {
    if (!loan) return false;
    
    // No permitir si tiene pagos en statements (ya fue incluido en un corte)
    if (loan.has_statement_payments) return false;
    
    // No permitir eliminar préstamos PAID_OFF (4), DEFAULTED (5), CANCELLED (7)
    const forbiddenStates = [4, 5, 7];
    return !forbiddenStates.includes(loan.status_id);
  };

  const getDeleteButtonTooltip = () => {
    if (!loan) return '';
    if (loan.has_statement_payments) {
      return 'No se puede eliminar: ya tiene pagos registrados en un statement';
    }
    const forbiddenStates = [4, 5, 7];
    if (forbiddenStates.includes(loan.status_id)) {
      return 'No se puede eliminar préstamos completados, defaulted o cancelados';
    }
    return 'Eliminar préstamo';
  };

  const handleDeleteClick = () => {
    setDeleteModal({ isOpen: true, step: 1, deleting: false });
  };

  const handleDeleteFirstConfirm = () => {
    setDeleteModal(prev => ({ ...prev, step: 2 }));
  };

  const handleDeleteFinalConfirm = async () => {
    setDeleteModal(prev => ({ ...prev, deleting: true }));

    try {
      await loansService.forceDelete(id);
      navigate('/prestamos', {
        state: { message: `Préstamo #${id} eliminado exitosamente` }
      });
    } catch (err) {
      console.error('Error deleting loan:', err);
      alert(err.response?.data?.detail || 'Error al eliminar el préstamo');
      setDeleteModal({ isOpen: false, step: 1, deleting: false });
    }
  };

  const handleDeleteCancel = () => {
    setDeleteModal({ isOpen: false, step: 1, deleting: false });
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
          {loan.status_id === 2 && (
            <button
              className="btn-primary"
              onClick={() => navigate(`/pagos?loan_id=${loan.id}`)}
            >
              📅 Ver Pagos
            </button>
          )}
          {/* Botón eliminar - mostrar deshabilitado si tiene pagos en statements */}
          {(canDeleteLoan() || loan.has_statement_payments) && ![4, 5, 7].includes(loan.status_id) && (
            <button
              className={`btn-danger ${!canDeleteLoan() ? 'disabled' : ''}`}
              onClick={canDeleteLoan() ? handleDeleteClick : undefined}
              disabled={!canDeleteLoan()}
              title={getDeleteButtonTooltip()}
            >
              🗑️ Eliminar
            </button>
          )}
        </div>
      </div>

      {/* Modal de Eliminación con Doble Confirmación */}
      {deleteModal.isOpen && (
        <div className="delete-modal-overlay">
          <div className="delete-modal">
            {deleteModal.step === 1 ? (
              <>
                <div className="delete-modal-header warning">
                  <span className="icon">⚠️</span>
                  <h2>¿Eliminar Préstamo #{loan.id}?</h2>
                </div>
                <div className="delete-modal-body">
                  <p className="warning-text">
                    Esta acción eliminará permanentemente:
                  </p>
                  <ul className="delete-list">
                    <li>El préstamo por <strong>{formatCurrency(loan.amount)}</strong></li>
                    <li>Todos los pagos programados ({amortization?.length || loan.term_biweeks} quincenas)</li>
                    {loan.associate_user_id && loan.status_id >= 2 && (
                      <li>Se liberará el crédito del asociado</li>
                    )}
                  </ul>
                  <p className="info-text">
                    Cliente: <strong>{loan.client_name || `Usuario #${loan.user_id}`}</strong>
                  </p>
                </div>
                <div className="delete-modal-actions">
                  <button
                    className="btn-cancel"
                    onClick={handleDeleteCancel}
                  >
                    Cancelar
                  </button>
                  <button
                    className="btn-warning"
                    onClick={handleDeleteFirstConfirm}
                  >
                    Continuar →
                  </button>
                </div>
              </>
            ) : (
              <>
                <div className="delete-modal-header danger">
                  <span className="icon">🚨</span>
                  <h2>Confirmación Final</h2>
                </div>
                <div className="delete-modal-body">
                  <p className="danger-text">
                    <strong>¡ATENCIÓN!</strong> Esta acción es <strong>IRREVERSIBLE</strong>.
                  </p>
                  <p className="confirm-text">
                    ¿Estás completamente seguro de eliminar el Préstamo #{loan.id}?
                  </p>
                  <div className="final-warning">
                    <span className="icon">⛔</span>
                    <span>No podrás recuperar esta información</span>
                  </div>
                </div>
                <div className="delete-modal-actions">
                  <button
                    className="btn-cancel"
                    onClick={handleDeleteCancel}
                    disabled={deleteModal.deleting}
                  >
                    ← Volver
                  </button>
                  <button
                    className="btn-danger-confirm"
                    onClick={handleDeleteFinalConfirm}
                    disabled={deleteModal.deleting}
                  >
                    {deleteModal.deleting ? (
                      <>
                        <span className="spinner"></span>
                        Eliminando...
                      </>
                    ) : (
                      '🗑️ Sí, Eliminar Definitivamente'
                    )}
                  </button>
                </div>
              </>
            )}
          </div>
        </div>
      )}

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

        {/* Sección: Resumen del Préstamo (Componente nuevo) */}
        <LoanSummaryDisplay loan={loan} />

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

        {/* Sección: Tabla de Amortización */}
        <div className="detail-section">
          <div className="section-header-with-badge">
            <h2>📊 Tabla de Amortización</h2>
            {amortization && (
              <span className={`amortization-badge ${isSimulation ? 'badge-warning' : 'badge-success'}`}>
                {isSimulation ? '⚠️ SIMULACIÓN - Fechas Tentativas' : '✅ CRONOGRAMA OFICIAL'}
              </span>
            )}
          </div>

          {amortizationLoading ? (
            <div className="loading-spinner">
              <div className="spinner"></div>
              <p>Cargando cronograma...</p>
            </div>
          ) : amortization && amortization.length > 0 ? (
            <>
              {isSimulation && (
                <div className="simulation-notice">
                  <strong>ℹ️ Nota:</strong> Estas fechas son tentativas y se recalculan automáticamente.
                  Una vez aprobado el préstamo, se generará el cronograma oficial con fechas definitivas.
                </div>
              )}
              <TablaAmortizacion payments={amortization} />
            </>
          ) : (
            <div className="empty-state">
              <span className="empty-icon">📋</span>
              <p>No hay cronograma disponible para este préstamo</p>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
