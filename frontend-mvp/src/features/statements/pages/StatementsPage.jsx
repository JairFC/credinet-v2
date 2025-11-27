/**
 * StatementsPage - Vista de gestión de estados de cuenta de asociados
 * 
 * Lógica del Sistema (Backend v2.0 - 5 Estados):
 * 1 = GENERATED      # Generado
 * 2 = SENT           # Enviado al asociado
 * 3 = PAID           # Pagado completamente (is_paid = TRUE)
 * 4 = PARTIAL_PAID   # Pago parcial
 * 5 = OVERDUE        # Vencido sin pagar
 * 
 * Reglas de Negocio:
 * - Mora del 30%: Se aplica AL FINAL DEL CORTE si el asociado NO hizo ningún abono (paid_amount = 0)
 * - late_fee_amount = total_commission_owed * 0.30
 * - Total adeudado = total_commission_owed + late_fee_amount
 * - Saldo restante = total_adeudado - paid_amount
 * - Solo GENERATED, SENT, PARTIAL_PAID y OVERDUE pueden recibir pagos
 * - Mora solo se aplica si: OVERDUE + NO pagado + NO tiene mora aplicada + paid_amount = 0
 */

import { useState, useEffect } from 'react';
import { useAuth } from '../../../app/providers/AuthProvider';
import { statementsService } from '../../../shared/api/services/statementsService';
import ModalRegistrarAbono from '../../../shared/components/ModalRegistrarAbono';
import RegistrarPagoModal from '../../payments/components/RegistrarPagoModal';
import TablaDesglosePagos from '../../../shared/components/TablaDesglosePagos';
import './StatementsPage.css';

const StatementsPage = () => {
  const { user } = useAuth();

  // Estados principales
  const [statements, setStatements] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [filter, setFilter] = useState('all'); // all, pending, overdue, paid
  const [associateFilter, setAssociateFilter] = useState(''); // Filtro por asociado
  const [periodFilter, setPeriodFilter] = useState(''); // Filtro por período

  // Modales
  const [markPaidModal, setMarkPaidModal] = useState(null);
  const [applyFeeModal, setApplyFeeModal] = useState(null);

  // Estado para expansion de desglose
  const [expandedStatementId, setExpandedStatementId] = useState(null);

  const [applyFeeData, setApplyFeeData] = useState({
    apply_fee: true,
    applied_by: user?.id,
    notes: ''
  });

  useEffect(() => {
    fetchStatements();
  }, [associateFilter, periodFilter]);

  const fetchStatements = async () => {
    try {
      setLoading(true);
      setError(null);

      const params = {};
      if (associateFilter) params.user_id = associateFilter;
      if (periodFilter) params.cut_period_id = periodFilter;

      const response = await statementsService.getAll(params);
      setStatements(Array.isArray(response.data) ? response.data : []);
    } catch (err) {
      console.error('Error al cargar statements:', err);
      setError('Error al cargar estados de cuenta. Por favor, intenta nuevamente.');
      setStatements([]);
    } finally {
      setLoading(false);
    }
  };

  // Mapeo de estados
  const getStatusInfo = (statusId) => {
    const statusMap = {
      1: { text: 'Generado', class: 'generated', filter: 'pending', canPay: true, canApplyFee: false },
      2: { text: 'Enviado', class: 'sent', filter: 'pending', canPay: true, canApplyFee: false },
      3: { text: 'Pagado', class: 'paid', filter: 'paid', canPay: false, canApplyFee: false },
      4: { text: 'Pago Parcial', class: 'partial', filter: 'pending', canPay: true, canApplyFee: false },
      5: { text: 'Vencido', class: 'overdue', filter: 'overdue', canPay: true, canApplyFee: true }
    };
    return statusMap[statusId] || { text: 'Desconocido', class: 'unknown', filter: 'all', canPay: false, canApplyFee: false };
  };

  // Filtrado de statements
  const getFilteredStatements = () => {
    if (filter === 'all') return statements;
    return statements.filter(stmt => {
      const statusInfo = getStatusInfo(stmt.status_id);
      return statusInfo.filter === filter;
    });
  };

  // Verificar si puede marcar como pagado
  const canMarkAsPaid = (stmt) => {
    const statusInfo = getStatusInfo(stmt.status_id);
    return statusInfo.canPay && stmt.remaining_amount > 0;
  };

  // Verificar si puede aplicar mora
  // Regla: Solo si está OVERDUE, NO pagado, NO tiene mora aplicada, y NO ha hecho ningún abono
  const canApplyLateFee = (stmt) => {
    const statusInfo = getStatusInfo(stmt.status_id);
    const noAbonos = !stmt.paid_amount || stmt.paid_amount === 0;
    return statusInfo.canApplyFee && !stmt.is_paid && !stmt.late_fee_applied && noAbonos;
  };

  // Handlers para modales
  const handleOpenMarkPaid = (stmt) => {
    setMarkPaidModal(stmt);
  };

  const handleOpenApplyFee = (stmt) => {
    setApplyFeeModal(stmt);
    setApplyFeeData({
      apply_fee: true,
      applied_by: user?.id,
      notes: ''
    });
  };

  const handlePaymentSuccess = async (paymentData) => {
    try {
      // Llamar al API para registrar el pago
      await statementsService.registerPayment(markPaidModal.id, paymentData);

      // Cerrar modal y recargar datos
      setMarkPaidModal(null);
      await fetchStatements();
    } catch (err) {
      console.error('Error al registrar pago:', err);
      throw err; // Re-throw para que el modal muestre el error
    }
  };

  const toggleStatementDetail = (statementId) => {
    setExpandedStatementId(expandedStatementId === statementId ? null : statementId);
  };

  const handleMarkAsPaid = async () => {
    if (!markPaidModal) return;

    // Este handler ya no se usa - el modal nuevo maneja el submit
    setMarkPaidModal(null);
  };

  const handleApplyLateFee = async () => {
    if (!applyFeeModal) return;

    try {
      setLoading(true);
      await statementsService.applyLateFee(applyFeeModal.id, applyFeeData);
      setApplyFeeModal(null);
      await fetchStatements();
      alert('Mora del 30% aplicada exitosamente');
    } catch (err) {
      console.error('Error al aplicar mora:', err);
      alert('Error al aplicar mora: ' + (err.response?.data?.detail || err.message));
    } finally {
      setLoading(false);
    }
  };

  // Calcular estadísticas
  const stats = {
    total: statements.length,
    paid: statements.filter(s => s.status_id === 3).length,
    pending: statements.filter(s => [1, 2, 4].includes(s.status_id)).length,
    overdue: statements.filter(s => s.status_id === 5).length,
    totalCommissionOwed: statements.reduce((sum, s) => sum + (s.total_commission_owed || 0), 0),
    totalLateFees: statements.reduce((sum, s) => sum + (s.late_fee_amount || 0), 0),
    totalCollected: statements.reduce((sum, s) => sum + (s.paid_amount || 0), 0)
  };

  const filteredStatements = getFilteredStatements();

  if (loading && statements.length === 0) {
    return (
      <div className="statements-page">
        <div className="statements-header">
          <h1>📋 Estados de Cuenta</h1>
        </div>
        <div className="statements-loading">
          <div className="skeleton-card"></div>
          <div className="skeleton-table"></div>
        </div>
      </div>
    );
  }

  return (
    <div className="statements-page">
      <div className="statements-header">
        <h1>📋 Estados de Cuenta de Asociados</h1>
        <p className="subtitle">Gestión de comisiones y moras del sistema</p>
      </div>

      {error && (
        <div className="error-banner">
          <span>⚠️ {error}</span>
          <button onClick={fetchStatements}>Reintentar</button>
        </div>
      )}

      {/* Estadísticas */}
      <div className="statements-stats">
        <div className="stat-card">
          <div className="stat-icon">📊</div>
          <div className="stat-info">
            <span className="stat-label">Total Statements</span>
            <span className="stat-value">{stats.total}</span>
          </div>
        </div>

        <div className="stat-card">
          <div className="stat-icon">✅</div>
          <div className="stat-info">
            <span className="stat-label">Pagados</span>
            <span className="stat-value">{stats.paid}</span>
          </div>
        </div>

        <div className="stat-card">
          <div className="stat-icon">⏳</div>
          <div className="stat-info">
            <span className="stat-label">Pendientes</span>
            <span className="stat-value">{stats.pending}</span>
          </div>
        </div>

        <div className="stat-card">
          <div className="stat-icon">⚠️</div>
          <div className="stat-info">
            <span className="stat-label">Vencidos</span>
            <span className="stat-value">{stats.overdue}</span>
          </div>
        </div>

        <div className="stat-card">
          <div className="stat-icon">💰</div>
          <div className="stat-info">
            <span className="stat-label">Comisiones Totales</span>
            <span className="stat-value">${stats.totalCommissionOwed.toLocaleString('es-MX', { minimumFractionDigits: 2 })}</span>
          </div>
        </div>

        <div className="stat-card">
          <div className="stat-icon">⚡</div>
          <div className="stat-info">
            <span className="stat-label">Moras Totales (30%)</span>
            <span className="stat-value stat-danger">${stats.totalLateFees.toLocaleString('es-MX', { minimumFractionDigits: 2 })}</span>
          </div>
        </div>

        <div className="stat-card">
          <div className="stat-icon">💵</div>
          <div className="stat-info">
            <span className="stat-label">Total Cobrado</span>
            <span className="stat-value stat-success">${stats.totalCollected.toLocaleString('es-MX', { minimumFractionDigits: 2 })}</span>
          </div>
        </div>
      </div>

      {/* Filtros */}
      <div className="statements-filters">
        <div className="filter-group">
          <label>Estado:</label>
          <select value={filter} onChange={(e) => setFilter(e.target.value)}>
            <option value="all">Todos</option>
            <option value="pending">Pendientes</option>
            <option value="overdue">Vencidos</option>
            <option value="paid">Pagados</option>
          </select>
        </div>

        <div className="filter-group">
          <label>Asociado ID:</label>
          <input
            type="number"
            placeholder="Filtrar por asociado..."
            value={associateFilter}
            onChange={(e) => setAssociateFilter(e.target.value)}
          />
        </div>

        <div className="filter-group">
          <label>Período ID:</label>
          <input
            type="number"
            placeholder="Filtrar por período..."
            value={periodFilter}
            onChange={(e) => setPeriodFilter(e.target.value)}
          />
        </div>

        <button className="btn-refresh" onClick={fetchStatements} disabled={loading}>
          {loading ? '🔄 Cargando...' : '🔄 Actualizar'}
        </button>
      </div>

      {/* Tabla de Statements */}
      <div className="statements-table-container">
        {filteredStatements.length === 0 ? (
          <div className="empty-state">
            <p>📭 No hay estados de cuenta con los filtros aplicados</p>
          </div>
        ) : (
          <table className="statements-table">
            <thead>
              <tr>
                <th>ID</th>
                <th>Número</th>
                <th>Asociado</th>
                <th>Período</th>
                <th>Pagos Reportados</th>
                <th>Comisión</th>
                <th>Mora (30%)</th>
                <th>Total Adeudado</th>
                <th>Abonado</th>
                <th>Saldo</th>
                <th>Estado</th>
                <th>Fecha Vencimiento</th>
                <th>Acciones</th>
              </tr>
            </thead>
            <tbody>
              {filteredStatements.map((stmt) => {
                const statusInfo = getStatusInfo(stmt.status_id);
                const totalOwed = (stmt.total_commission_owed || 0) + (stmt.late_fee_amount || 0);
                const remaining = stmt.remaining_amount || 0;

                return (
                  <>
                    <tr key={stmt.id} className={stmt.is_overdue ? 'row-overdue' : ''}>
                      <td>{stmt.id}</td>
                      <td className="statement-number">{stmt.statement_number}</td>
                      <td>{stmt.associate_name || `Usuario ${stmt.user_id}`}</td>
                      <td>{stmt.cut_period_code || `Período ${stmt.cut_period_id}`}</td>
                      <td className="text-center">
                        {stmt.total_payments_count}
                        {stmt.total_payments_count === 0 && <span className="badge-warning-small">⚠️ Sin pagos</span>}
                      </td>
                      <td className="text-right">${(stmt.total_commission_owed || 0).toLocaleString('es-MX', { minimumFractionDigits: 2 })}</td>
                      <td className="text-right">
                        {stmt.late_fee_amount > 0 ? (
                          <span className="text-danger">
                            ${stmt.late_fee_amount.toLocaleString('es-MX', { minimumFractionDigits: 2 })}
                            {stmt.late_fee_applied && <span className="badge-danger-small">Aplicada</span>}
                          </span>
                        ) : (
                          <span className="text-muted">$0.00</span>
                        )}
                      </td>
                      <td className="text-right font-bold">${totalOwed.toLocaleString('es-MX', { minimumFractionDigits: 2 })}</td>
                      <td className="text-right">
                        {stmt.paid_amount > 0 ? (
                          <span className="text-success">${stmt.paid_amount.toLocaleString('es-MX', { minimumFractionDigits: 2 })}</span>
                        ) : (
                          <span className="text-muted">
                            $0.00
                            {stmt.is_overdue && <span className="badge-danger-small">Sin abonos</span>}
                          </span>
                        )}
                      </td>
                      <td className="text-right font-bold">${remaining.toLocaleString('es-MX', { minimumFractionDigits: 2 })}</td>
                      <td>
                        <span className={`badge badge-${statusInfo.class}`}>
                          {statusInfo.text}
                        </span>
                      </td>
                      <td>
                        {stmt.due_date ? new Date(stmt.due_date).toLocaleDateString('es-MX') : '-'}
                        {stmt.is_overdue && <span className="badge-danger-small">Vencido</span>}
                      </td>
                      <td className="actions-cell">
                        <button
                          className="btn-action btn-info-small"
                          onClick={() => toggleStatementDetail(stmt.id)}
                          title="Ver desglose de abonos"
                          style={{ marginRight: '4px' }}
                        >
                          {expandedStatementId === stmt.id ? '▼ Ocultar' : '▶ Desglose'}
                        </button>
                        {canMarkAsPaid(stmt) && (
                          <button
                            className="btn-action btn-success-small"
                            onClick={() => handleOpenMarkPaid(stmt)}
                            title="Marcar como pagado"
                          >
                            💰 Pagar
                          </button>
                        )}
                        {canApplyLateFee(stmt) && (
                          <button
                            className="btn-action btn-warning-small"
                            onClick={() => handleOpenApplyFee(stmt)}
                            title="Aplicar mora del 30%"
                          >
                            ⚡ Mora 30%
                          </button>
                        )}
                        {stmt.is_paid && (
                          <span className="badge-success-small">✅ Pagado</span>
                        )}
                      </td>
                    </tr>
                    {/* Fila expandida con desglose de pagos */}
                    {expandedStatementId === stmt.id && (
                      <tr key={`expanded-${stmt.id}`} className="expanded-row">
                        <td colSpan="13" style={{ padding: 0, backgroundColor: '#f8f9fa' }}>
                          <TablaDesglosePagos statementId={stmt.id} />
                        </td>
                      </tr>
                    )}
                  </>
                );
              })}
            </tbody>
          </table>
        )}
      </div>

      {/* Modal: Registrar Abono */}
      {markPaidModal && (
        <RegistrarPagoModal
          isOpen={!!markPaidModal}
          onClose={() => setMarkPaidModal(null)}
          tipo="periodo"
          statement={{
            id: markPaidModal.id,
            cut_code: markPaidModal.cut_code,
            total_collected_amount: markPaidModal.total_amount_collected || 0,
            commission_amount: markPaidModal.total_commission_owed || 0,
            paid_amount: markPaidModal.paid_amount || 0,
            late_fee_amount: markPaidModal.late_fee_amount || 0,
            total_amount_collected: markPaidModal.total_amount_collected || 0,
            total_commission_owed: markPaidModal.total_commission_owed || 0,
          }}
          associateId={markPaidModal.user_id}
          onSuccess={handlePaymentSuccess}
        />
      )}

      {/* Modal: Aplicar Mora del 30% */}
      {applyFeeModal && (
        <div className="modal-overlay" onClick={() => setApplyFeeModal(null)}>
          <div className="modal-content" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header">
              <h2>⚡ Aplicar Mora del 30%</h2>
              <button className="modal-close" onClick={() => setApplyFeeModal(null)}>✕</button>
            </div>

            <div className="modal-body">
              <div className="statement-info-box warning-box">
                <p><strong>⚠️ ADVERTENCIA:</strong> Esta acción aplicará una mora del 30% sobre la comisión adeudada.</p>
                <p><strong>Razón:</strong> El asociado NO realizó ningún abono al final del período de corte.</p>
                <p><strong>Statement:</strong> {applyFeeModal.statement_number}</p>
                <p><strong>Asociado:</strong> {applyFeeModal.associate_name || `Usuario ${applyFeeModal.user_id}`}</p>
                <p><strong>Período:</strong> {applyFeeModal.cut_period_code || `Período ${applyFeeModal.cut_period_id}`}</p>
                <p><strong>Comisión base:</strong> ${(applyFeeModal.total_commission_owed || 0).toLocaleString('es-MX', { minimumFractionDigits: 2 })}</p>
                <p><strong>Abonos realizados:</strong> <span className="text-danger">${(applyFeeModal.paid_amount || 0).toLocaleString('es-MX', { minimumFractionDigits: 2 })} (Sin abonos)</span></p>
                <p><strong>Mora a aplicar (30%):</strong> <span className="text-danger">${(applyFeeModal.total_commission_owed * 0.30).toLocaleString('es-MX', { minimumFractionDigits: 2 })}</span></p>
                <p><strong>Nuevo total:</strong> ${(applyFeeModal.total_commission_owed * 1.30).toLocaleString('es-MX', { minimumFractionDigits: 2 })}</p>
              </div>

              <div className="form-group">
                <label>Motivo / Notas *</label>
                <textarea
                  rows="4"
                  value={applyFeeData.notes}
                  onChange={(e) => setApplyFeeData({ ...applyFeeData, notes: e.target.value })}
                  placeholder="Explica el motivo de la aplicación de mora (ej: Asociado no realizó ningún abono al saldo del período al cierre, incumplimiento de fechas de pago, etc.)"
                  required
                />
                <small className="help-text text-danger">Este campo es obligatorio. Min 10 caracteres.</small>
              </div>

              <div className="form-group">
                <label className="checkbox-label">
                  <input
                    type="checkbox"
                    checked={applyFeeData.apply_fee}
                    onChange={(e) => setApplyFeeData({ ...applyFeeData, apply_fee: e.target.checked })}
                  />
                  Confirmo que deseo aplicar la mora del 30%
                </label>
              </div>
            </div>

            <div className="modal-footer">
              <button
                className="btn btn-secondary"
                onClick={() => setApplyFeeModal(null)}
              >
                Cancelar
              </button>
              <button
                className="btn btn-danger"
                onClick={handleApplyLateFee}
                disabled={!applyFeeData.apply_fee || !applyFeeData.notes || applyFeeData.notes.length < 10}
              >
                ⚡ Aplicar Mora 30%
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default StatementsPage;
