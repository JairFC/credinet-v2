/**
 * Defaulted Client Reports Page
 * 
 * FLUJO DE NEGOCIO:
 * 1. Asociado reporta cliente moroso (con evidencia)
 * 2. Reporte queda en PENDING
 * 3. Admin revisa y aprueba/rechaza
 * 4. Al aprobar:
 *    - Pagos del préstamo → PAID_BY_ASSOCIATE
 *    - consolidated_debt del asociado aumenta
 *    - Se crea registro en associate_debt_breakdown
 * 
 * MODELO DE DEUDA (Backend v2.0):
 * - pending_payments_total: Pagos pendientes por cobrar a clientes
 * - consolidated_debt: Deuda consolidada del ASOCIADO a CrediCuenta
 * - available_credit: Lo que puede usar para nuevos préstamos
 */
import { useState, useEffect, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { agreementsService } from '@/shared/api/services/agreementsService';
import './DefaultedReportsPage.css';

const STATUS_CONFIG = {
  PENDING: { label: 'Pendiente', color: 'warning', icon: '⏳' },
  IN_REVIEW: { label: 'En Revisión', color: 'info', icon: '🔍' },
  APPROVED: { label: 'Aprobado', color: 'success', icon: '✅' },
  REJECTED: { label: 'Rechazado', color: 'danger', icon: '❌' },
};

const DefaultedReportsPage = () => {
  const navigate = useNavigate();
  const [reports, setReports] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  
  // Filters
  const [statusFilter, setStatusFilter] = useState('');
  const [searchTerm, setSearchTerm] = useState('');
  
  // Pagination
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const ITEMS_PER_PAGE = 10;
  
  // Modal states
  const [selectedReport, setSelectedReport] = useState(null);
  const [showDetailModal, setShowDetailModal] = useState(false);
  const [showApproveModal, setShowApproveModal] = useState(false);
  const [showRejectModal, setShowRejectModal] = useState(false);
  const [rejectionReason, setRejectionReason] = useState('');
  const [processing, setProcessing] = useState(false);

  const loadReports = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);
      
      const params = {
        page,
        limit: ITEMS_PER_PAGE,
        ...(statusFilter && { status: statusFilter }),
        ...(searchTerm && { search: searchTerm }),
      };
      
      const response = await agreementsService.getDefaultedReports(params);
      setReports(response.data.items || []);
      setTotalPages(Math.ceil((response.data.total || 0) / ITEMS_PER_PAGE));
    } catch (err) {
      console.error('Error loading reports:', err);
      setError('Error al cargar los reportes de morosos');
    } finally {
      setLoading(false);
    }
  }, [page, statusFilter, searchTerm]);

  useEffect(() => {
    loadReports();
  }, [loadReports]);

  const handleApprove = async () => {
    if (!selectedReport) return;
    
    try {
      setProcessing(true);
      await agreementsService.approveDefaultedReport(selectedReport.id);
      
      alert(
        `✅ Reporte #${selectedReport.id} aprobado\n\n` +
        `📋 Acciones realizadas:\n` +
        `• Pagos del préstamo #${selectedReport.loan_id} marcados como PAID_BY_ASSOCIATE\n` +
        `• Deuda de $${selectedReport.total_debt_amount?.toLocaleString('es-MX', { minimumFractionDigits: 2 })} agregada al asociado\n` +
        `• Registro creado en desglose de deuda`
      );
      
      setShowApproveModal(false);
      setSelectedReport(null);
      loadReports();
    } catch (err) {
      console.error('Error approving report:', err);
      alert(err.response?.data?.detail || 'Error al aprobar el reporte');
    } finally {
      setProcessing(false);
    }
  };

  const handleReject = async () => {
    if (!selectedReport || !rejectionReason.trim()) {
      alert('Debe proporcionar una razón de rechazo');
      return;
    }
    
    try {
      setProcessing(true);
      await agreementsService.rejectDefaultedReport(selectedReport.id, {
        rejection_reason: rejectionReason.trim()
      });
      
      alert(`❌ Reporte #${selectedReport.id} rechazado`);
      
      setShowRejectModal(false);
      setSelectedReport(null);
      setRejectionReason('');
      loadReports();
    } catch (err) {
      console.error('Error rejecting report:', err);
      alert(err.response?.data?.detail || 'Error al rechazar el reporte');
    } finally {
      setProcessing(false);
    }
  };

  const formatDate = (dateStr) => {
    if (!dateStr) return '-';
    return new Date(dateStr).toLocaleDateString('es-MX', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
  };

  const formatCurrency = (amount) => {
    return `$${parseFloat(amount || 0).toLocaleString('es-MX', { minimumFractionDigits: 2 })}`;
  };

  return (
    <div className="defaulted-reports-page">
      <div className="page-header">
        <div className="header-content">
          <div className="header-left">
            <h1>🚨 Reportes de Clientes Morosos</h1>
            <p className="subtitle">Gestión de clientes problemáticos reportados por asociados</p>
          </div>
          <div className="header-actions">
            <button 
              className="btn btn-primary"
              onClick={() => navigate('/convenios/nuevo-reporte')}
            >
              ➕ Nuevo Reporte
            </button>
          </div>
        </div>
      </div>

      {/* Info Banner */}
      <div className="info-banner">
        <div className="info-icon">ℹ️</div>
        <div className="info-content">
          <strong>¿Cómo funciona?</strong>
          <p>
            Cuando un asociado reporta un cliente moroso y es aprobado, los pagos pendientes 
            del préstamo se marcan como <strong>PAID_BY_ASSOCIATE</strong> y la deuda se suma 
            a la <code>consolidated_debt</code> del asociado. Esto permite crear convenios de pago.
          </p>
        </div>
      </div>

      {/* Filters */}
      <div className="filters-section">
        <div className="filter-group">
          <label>Estado:</label>
          <select 
            value={statusFilter} 
            onChange={(e) => { setStatusFilter(e.target.value); setPage(1); }}
          >
            <option value="">Todos</option>
            <option value="PENDING">Pendiente</option>
            <option value="IN_REVIEW">En Revisión</option>
            <option value="APPROVED">Aprobado</option>
            <option value="REJECTED">Rechazado</option>
          </select>
        </div>
        <div className="filter-group search">
          <label>Buscar:</label>
          <input
            type="text"
            placeholder="Nombre de cliente o asociado..."
            value={searchTerm}
            onChange={(e) => { setSearchTerm(e.target.value); setPage(1); }}
          />
        </div>
        <button className="btn btn-secondary" onClick={() => { setStatusFilter(''); setSearchTerm(''); setPage(1); }}>
          🔄 Limpiar
        </button>
      </div>

      {/* Error Message */}
      {error && (
        <div className="error-message">
          <span>⚠️ {error}</span>
          <button onClick={loadReports}>Reintentar</button>
        </div>
      )}

      {/* Loading */}
      {loading && (
        <div className="loading-container">
          <div className="spinner"></div>
          <span>Cargando reportes...</span>
        </div>
      )}

      {/* Reports Table */}
      {!loading && !error && (
        <>
          {reports.length === 0 ? (
            <div className="empty-state">
              <div className="empty-icon">📭</div>
              <h3>No hay reportes</h3>
              <p>No se encontraron reportes de clientes morosos con los filtros seleccionados.</p>
            </div>
          ) : (
            <div className="table-container">
              <table className="reports-table">
                <thead>
                  <tr>
                    <th>ID</th>
                    <th>Fecha</th>
                    <th>Préstamo</th>
                    <th>Cliente</th>
                    <th>Asociado</th>
                    <th>Deuda</th>
                    <th>Estado</th>
                    <th>Acciones</th>
                  </tr>
                </thead>
                <tbody>
                  {reports.map(report => (
                    <tr key={report.id} className={`status-${report.status?.toLowerCase()}`}>
                      <td className="id-cell">#{report.id}</td>
                      <td className="date-cell">{formatDate(report.reported_at)}</td>
                      <td className="loan-cell">
                        <button 
                          className="link-btn"
                          onClick={() => navigate(`/prestamos/${report.loan_id}`)}
                        >
                          #{report.loan_id}
                        </button>
                      </td>
                      <td className="client-cell">
                        <div className="user-info">
                          <span className="name">{report.client_name || `Cliente #${report.client_user_id}`}</span>
                        </div>
                      </td>
                      <td className="associate-cell">
                        <div className="user-info">
                          <span className="name">{report.associate_name || `Asociado #${report.associate_profile_id}`}</span>
                        </div>
                      </td>
                      <td className="amount-cell">{formatCurrency(report.total_debt_amount)}</td>
                      <td className="status-cell">
                        <span className={`status-badge ${STATUS_CONFIG[report.status]?.color || 'default'}`}>
                          {STATUS_CONFIG[report.status]?.icon} {STATUS_CONFIG[report.status]?.label || report.status}
                        </span>
                      </td>
                      <td className="actions-cell">
                        <div className="action-buttons">
                          <button
                            className="btn btn-sm btn-info"
                            onClick={() => { setSelectedReport(report); setShowDetailModal(true); }}
                            title="Ver detalle"
                          >
                            👁️
                          </button>
                          {report.status === 'PENDING' && (
                            <>
                              <button
                                className="btn btn-sm btn-success"
                                onClick={() => { setSelectedReport(report); setShowApproveModal(true); }}
                                title="Aprobar"
                              >
                                ✅
                              </button>
                              <button
                                className="btn btn-sm btn-danger"
                                onClick={() => { setSelectedReport(report); setShowRejectModal(true); }}
                                title="Rechazar"
                              >
                                ❌
                              </button>
                            </>
                          )}
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}

          {/* Pagination */}
          {totalPages > 1 && (
            <div className="pagination">
              <button
                className="btn btn-sm"
                disabled={page === 1}
                onClick={() => setPage(p => p - 1)}
              >
                ← Anterior
              </button>
              <span className="page-info">
                Página {page} de {totalPages}
              </span>
              <button
                className="btn btn-sm"
                disabled={page === totalPages}
                onClick={() => setPage(p => p + 1)}
              >
                Siguiente →
              </button>
            </div>
          )}
        </>
      )}

      {/* Approve Modal */}
      {showApproveModal && selectedReport && (
        <div className="modal-overlay" onClick={() => setShowApproveModal(false)}>
          <div className="modal" onClick={e => e.stopPropagation()}>
            <div className="modal-header">
              <h3>✅ Aprobar Reporte de Moroso</h3>
              <button className="close-btn" onClick={() => setShowApproveModal(false)}>×</button>
            </div>
            <div className="modal-body">
              <div className="confirm-details">
                <p><strong>Reporte:</strong> #{selectedReport.id}</p>
                <p><strong>Préstamo:</strong> #{selectedReport.loan_id}</p>
                <p><strong>Cliente:</strong> {selectedReport.client_name || `#${selectedReport.client_user_id}`}</p>
                <p><strong>Asociado:</strong> {selectedReport.associate_name || `#${selectedReport.associate_profile_id}`}</p>
                <p><strong>Deuda a transferir:</strong> {formatCurrency(selectedReport.total_debt_amount)}</p>
              </div>
              <div className="warning-box">
                <strong>⚠️ Esta acción:</strong>
                <ul>
                  <li>Marcará los pagos pendientes del préstamo como <code>PAID_BY_ASSOCIATE</code></li>
                  <li>Agregará <strong>{formatCurrency(selectedReport.total_debt_amount)}</strong> a la <code>consolidated_debt</code> del asociado</li>
                  <li>El asociado deberá pagar esta deuda mediante convenio o directamente</li>
                </ul>
              </div>
            </div>
            <div className="modal-footer">
              <button 
                className="btn btn-secondary" 
                onClick={() => setShowApproveModal(false)}
                disabled={processing}
              >
                Cancelar
              </button>
              <button 
                className="btn btn-success" 
                onClick={handleApprove}
                disabled={processing}
              >
                {processing ? 'Procesando...' : '✅ Confirmar Aprobación'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Reject Modal */}
      {showRejectModal && selectedReport && (
        <div className="modal-overlay" onClick={() => setShowRejectModal(false)}>
          <div className="modal" onClick={e => e.stopPropagation()}>
            <div className="modal-header">
              <h3>❌ Rechazar Reporte de Moroso</h3>
              <button className="close-btn" onClick={() => setShowRejectModal(false)}>×</button>
            </div>
            <div className="modal-body">
              <div className="confirm-details">
                <p><strong>Reporte:</strong> #{selectedReport.id}</p>
                <p><strong>Préstamo:</strong> #{selectedReport.loan_id}</p>
                <p><strong>Cliente:</strong> {selectedReport.client_name || `#${selectedReport.client_user_id}`}</p>
              </div>
              <div className="form-group">
                <label>Razón del rechazo *</label>
                <textarea
                  value={rejectionReason}
                  onChange={(e) => setRejectionReason(e.target.value)}
                  placeholder="Explique por qué se rechaza este reporte..."
                  rows={4}
                  required
                />
              </div>
            </div>
            <div className="modal-footer">
              <button 
                className="btn btn-secondary" 
                onClick={() => { setShowRejectModal(false); setRejectionReason(''); }}
                disabled={processing}
              >
                Cancelar
              </button>
              <button 
                className="btn btn-danger" 
                onClick={handleReject}
                disabled={processing || !rejectionReason.trim()}
              >
                {processing ? 'Procesando...' : '❌ Confirmar Rechazo'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Detail Modal */}
      {showDetailModal && selectedReport && (
        <div className="modal-overlay" onClick={() => setShowDetailModal(false)}>
          <div className="modal modal-lg" onClick={e => e.stopPropagation()}>
            <div className="modal-header">
              <h3>📋 Detalle del Reporte #{selectedReport.id}</h3>
              <button className="close-btn" onClick={() => setShowDetailModal(false)}>×</button>
            </div>
            <div className="modal-body">
              <div className="detail-grid">
                <div className="detail-section">
                  <h4>📌 Información General</h4>
                  <div className="detail-item">
                    <span className="label">Estado:</span>
                    <span className={`status-badge ${STATUS_CONFIG[selectedReport.status]?.color || 'default'}`}>
                      {STATUS_CONFIG[selectedReport.status]?.icon} {STATUS_CONFIG[selectedReport.status]?.label || selectedReport.status}
                    </span>
                  </div>
                  <div className="detail-item">
                    <span className="label">Fecha de Creación:</span>
                    <span className="value">{formatDate(selectedReport.created_at)}</span>
                  </div>
                  {selectedReport.resolved_at && (
                    <div className="detail-item">
                      <span className="label">Fecha de Resolución:</span>
                      <span className="value">{formatDate(selectedReport.resolved_at)}</span>
                    </div>
                  )}
                </div>

                <div className="detail-section">
                  <h4>💰 Información del Préstamo</h4>
                  <div className="detail-item">
                    <span className="label">ID Préstamo:</span>
                    <span className="value">#{selectedReport.loan_id}</span>
                  </div>
                  <div className="detail-item">
                    <span className="label">Monto de Deuda:</span>
                    <span className="value amount">{formatCurrency(selectedReport.total_debt_amount)}</span>
                  </div>
                </div>

                <div className="detail-section">
                  <h4>👤 Cliente Reportado</h4>
                  <div className="detail-item">
                    <span className="label">Nombre:</span>
                    <span className="value">{selectedReport.client_name || 'N/A'}</span>
                  </div>
                  <div className="detail-item">
                    <span className="label">ID Usuario:</span>
                    <span className="value">#{selectedReport.client_user_id}</span>
                  </div>
                </div>

                <div className="detail-section">
                  <h4>🏢 Asociado que Reporta</h4>
                  <div className="detail-item">
                    <span className="label">Nombre:</span>
                    <span className="value">{selectedReport.associate_name || 'N/A'}</span>
                  </div>
                  <div className="detail-item">
                    <span className="label">ID Perfil:</span>
                    <span className="value">#{selectedReport.associate_profile_id}</span>
                  </div>
                </div>

                {selectedReport.evidence_details && (
                  <div className="detail-section full-width">
                    <h4>📝 Evidencia / Detalles</h4>
                    <div className="evidence-box">
                      {selectedReport.evidence_details}
                    </div>
                  </div>
                )}

                {selectedReport.rejection_reason && (
                  <div className="detail-section full-width">
                    <h4>❌ Razón de Rechazo</h4>
                    <div className="rejection-box">
                      {selectedReport.rejection_reason}
                    </div>
                  </div>
                )}
              </div>
            </div>
            <div className="modal-footer">
              <button 
                className="btn btn-secondary" 
                onClick={() => setShowDetailModal(false)}
              >
                Cerrar
              </button>
              {selectedReport.status === 'PENDING' && (
                <>
                  <button 
                    className="btn btn-success"
                    onClick={() => { setShowDetailModal(false); setShowApproveModal(true); }}
                  >
                    ✅ Aprobar
                  </button>
                  <button 
                    className="btn btn-danger"
                    onClick={() => { setShowDetailModal(false); setShowRejectModal(true); }}
                  >
                    ❌ Rechazar
                  </button>
                </>
              )}
              <button 
                className="btn btn-info"
                onClick={() => navigate(`/prestamos/${selectedReport.loan_id}`)}
              >
                🔗 Ver Préstamo
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default DefaultedReportsPage;
