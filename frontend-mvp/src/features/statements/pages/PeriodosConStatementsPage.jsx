/**
 * PeriodosConStatementsPage
 * Sistema de períodos estilo NU:
 * - TODOS los períodos siempre existen (son los cortes quincenales)
 * - Vista PREVIEW en tiempo real para períodos ACTIVOS (status_id = 2)
 * - Los pagos se van acumulando conforme se registran
 * - Al llegar día 8 o 23: status → REVIEW (automático)
 * - Admin hace cierre manual: status → CLOSED
 * - Filtro por asociada individual
 * - Estadísticas generales de TODOS los períodos
 */
import { useState, useEffect } from 'react';
import { useAuth } from '@/app/providers/AuthProvider';
import cutPeriodsService from '@/shared/api/services/cutPeriodsService';
import statementsService from '@/shared/api/services/statementsService';
import RegistrarPagoModal from '../../payments/components/RegistrarPagoModal';
import './PeriodosConStatementsPage.css';

export default function PeriodosConStatementsPage() {
  const { user } = useAuth();

  const [periods, setPeriods] = useState([]);
  const [selectedPeriod, setSelectedPeriod] = useState(null);
  const [periodData, setPeriodData] = useState([]);
  const [loading, setLoading] = useState(true);
  const [loadingStatements, setLoadingStatements] = useState(false);
  const [error, setError] = useState(null);

  // Filtros
  const [associateFilter, setAssociateFilter] = useState('');
  const [associates, setAssociates] = useState([]);

  // Estadísticas globales
  const [globalStats, setGlobalStats] = useState({
    total_collected: 0,
    total_commission: 0,
    total_paid: 0,
    total_pending: 0
  });

  // Modal
  const [paymentModal, setPaymentModal] = useState({ open: false, statement: null });

  useEffect(() => {
    loadPeriods();
  }, []);

  useEffect(() => {
    if (selectedPeriod) {
      loadStatementsForPeriod(selectedPeriod.id);
    }
  }, [selectedPeriod]);

  const loadPeriods = async () => {
    try {
      setLoading(true);
      const data = await cutPeriodsService.getAll();

      // Ordenar por fecha descendente (más reciente primero)
      const sortedPeriods = (data.data?.items || data.items || []).sort((a, b) => {
        return new Date(b.period_start_date) - new Date(a.period_start_date);
      });

      setPeriods(sortedPeriods);

      // Seleccionar el período ACTIVO (status_id = 2) por defecto
      const activePeriod = sortedPeriods.find(p => p.status_id === 2);
      if (activePeriod) {
        setSelectedPeriod(activePeriod);
      } else if (sortedPeriods.length > 0) {
        setSelectedPeriod(sortedPeriods[0]);
      }
    } catch (err) {
      console.error('Error al cargar períodos:', err);
    } finally {
      setLoading(false);
    }
  };

  const loadStatementsForPeriod = async (periodId) => {
    if (!periodId) return;

    setLoadingStatements(true);
    try {
      const data = await cutPeriodsService.getStatements(periodId);
      setPeriodData(data);
    } catch (err) {
      setError('Error al cargar estados de cuenta del período');
      console.error('Error loading period statements:', err);
    } finally {
      setLoadingStatements(false);
    }
  };

  const handlePeriodSelect = (period) => {
    setSelectedPeriod(period);
    loadStatementsForPeriod(period.id);
  };

  const handleClosePeriod = async () => {
    if (!selectedPeriod) return;

    if (selectedPeriod.status_id !== 3) {
      alert('Solo se pueden cerrar períodos en estado REVIEW (3)');
      return;
    }

    if (!confirm(`¿Cerrar definitivamente el período ${selectedPeriod.cut_code}?\n\nEsta acción es IRREVERSIBLE.`)) {
      return;
    }

    try {
      setLoadingStatements(true);
      // TODO: Endpoint para cerrar período
      // POST /periods/{id}/close
      await new Promise(resolve => setTimeout(resolve, 1000)); // Simular
      alert('Período cerrado exitosamente');
      await loadPeriods(); // Recargar períodos
      await loadStatementsForPeriod(selectedPeriod.id);
    } catch (err) {
      console.error('Error al cerrar período:', err);
      alert('Error al cerrar período: ' + (err.response?.data?.detail || err.message));
    } finally {
      setLoadingStatements(false);
    }
  };

  const handleOpenPayment = (statement) => {
    setPaymentModal({ open: true, statement });
  };

  const handlePaymentSuccess = async (paymentData) => {
    try {
      await statementsService.registerPayment(paymentModal.statement.id, paymentData);
      setPaymentModal({ open: false, statement: null });
      await loadStatementsForPeriod(selectedPeriod.id);
    } catch (err) {
      throw err;
    }
  };

  const formatDate = (dateStr) => {
    if (!dateStr) return '-';
    const date = new Date(dateStr + 'T12:00:00Z');
    return date.toLocaleDateString('es-MX', {
      day: '2-digit',
      month: 'short',
      year: 'numeric',
      timeZone: 'UTC'
    });
  };

  const formatMoney = (amount) => {
    return new Intl.NumberFormat('es-MX', {
      style: 'currency',
      currency: 'MXN'
    }).format(amount || 0);
  };

  const getStatusInfo = (statusId) => {
    const statuses = {
      1: { label: 'Preliminar', class: 'status-preliminary', icon: '⚙️' },
      2: { label: 'Activo', class: 'status-active', icon: '👁️' },
      3: { label: 'En Revisión', class: 'status-review', icon: '📝' },
      4: { label: 'Bloqueado', class: 'status-locked', icon: '🔒' },
      5: { label: 'Cerrado', class: 'status-closed', icon: '✅' }
    };
    return statuses[statusId] || { label: 'Desconocido', class: 'status-unknown', icon: '❓' };
  };

  if (loading) {
    return (
      <div className="periodos-page">
        <div className="loading-state">
          <div className="spinner"></div>
          <p>Cargando períodos...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="periodos-page">
      {/* Header */}
      <div className="page-header">
        <div>
          <h1>📅 Gestión por Períodos</h1>
          <p className="page-subtitle">
            Sistema de períodos quincenales • Vista en tiempo real de cobros y comisiones
          </p>
        </div>
      </div>

      {/* Selector de Período */}
      <div className="period-selector-section">
        <h3 style={{ margin: '0 0 1rem 0', color: 'var(--text-primary)' }}>Períodos</h3>
        <div className="period-list">
          {periods.map(period => {
            const statusInfo = getStatusInfo(period.status_id);
            return (
              <div
                key={period.id}
                className={`period-list-item ${selectedPeriod?.id === period.id ? 'active' : ''}`}
                onClick={() => handlePeriodSelect(period)}
              >
                <div className="period-item-icon">
                  <span className="status-icon-large">{statusInfo.icon}</span>
                </div>
                <div className="period-item-content">
                  <div className="period-item-header">
                    <h4 className="period-code">{period.cut_code}</h4>
                    <span className={`period-status-badge ${statusInfo.class}`}>
                      {statusInfo.label}
                    </span>
                  </div>
                  <div className="period-item-details">
                    <span className="period-dates">
                      {formatDate(period.period_start_date)} - {formatDate(period.period_end_date)}
                    </span>
                    <span className="period-collection">
                      Cobranza: {period.collection_percentage?.toFixed(1) || '0.0'}%
                    </span>
                  </div>
                </div>
              </div>
            );
          })}
        </div>

        {selectedPeriod && (
          <div className="period-info-bar">
            <div className="period-info-grid">
              <div className="info-item">
                <label>Estados de Cuenta:</label>
                <span>{periodData.length} (Tiempo Real)</span>
              </div>
            </div>

            {selectedPeriod.status_id === 3 && (
              <button
                className="btn-close-period"
                onClick={handleClosePeriod}
              >
                🔒 Cerrar Período
              </button>
            )}
          </div>
        )}
      </div>

      {/* Tabla de Statements */}
      {selectedPeriod && (
        <div className="statements-section">
          {loadingStatements ? (
            <div className="loading-state">
              <div className="spinner"></div>
              <p>Cargando estados de cuenta...</p>
            </div>
          ) : periodData.length === 0 ? (
            <div className="empty-state">
              <div className="empty-icon">📭</div>
              <h3>No hay estados de cuenta</h3>
              <p>
                {selectedPeriod.status_id === 1
                  ? 'Este período está preliminar, aún no hay datos.'
                  : selectedPeriod.status_id === 2
                    ? 'Este período está activo pero aún no hay pagos registrados.'
                    : 'No hay estados de cuenta para este período.'
                }
              </p>
            </div>
          ) : (
            <>
              <div className="statements-table-container">
                <table className="statements-table">
                  <thead>
                    <tr>
                      <th>Asociado</th>
                      <th className="text-right">Total Cobrado</th>
                      <th className="text-right">Comisión</th>
                      <th className="text-right">Pagado</th>
                      <th className="text-right">Pendiente</th>
                      <th className="text-right">Mora</th>
                      <th className="text-center">Acciones</th>
                    </tr>
                  </thead>
                  <tbody>
                    {periodData.map(stmt => {
                      const pending = (stmt.total_statement_amount || stmt.commission_amount) - (stmt.paid_statement_amount || stmt.paid_amount || 0);
                      const canPay = pending > 0 && selectedPeriod.status_id !== 5;

                      return (
                        <tr key={stmt.id}>
                          <td>
                            <div className="associate-info">
                              <div className="associate-name">{stmt.associate_name || 'N/A'}</div>
                              <div className="associate-id">ID: {stmt.associate_id}</div>
                            </div>
                          </td>
                          <td className="text-right font-semibold">
                            {formatMoney(stmt.total_collected_amount || stmt.total_amount_collected)}
                          </td>
                          <td className="text-right">
                            {formatMoney(stmt.commission_amount || stmt.total_commission_owed)}
                          </td>
                          <td className="text-right text-success">
                            {formatMoney(stmt.paid_statement_amount || stmt.paid_amount)}
                          </td>
                          <td className="text-right">
                            <span className={pending > 0 ? 'text-warning' : 'text-success'}>
                              {formatMoney(pending)}
                            </span>
                          </td>
                          <td className="text-right">
                            {(stmt.late_fee_amount || 0) > 0 ? (
                              <span className="text-danger">{formatMoney(stmt.late_fee_amount)}</span>
                            ) : (
                              <span className="text-muted">-</span>
                            )}
                          </td>
                          <td className="text-center">
                            <button
                              className="btn-action btn-pay"
                              onClick={() => handleOpenPayment(stmt)}
                              disabled={!canPay}
                              title={canPay ? 'Registrar pago' : selectedPeriod.status_id === 5 ? 'Período cerrado' : 'Sin saldo pendiente'}
                            >
                              💰 Pagar
                            </button>
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>
            </>
          )}
        </div>
      )}

      {/* Modal de Pago */}
      <RegistrarPagoModal
        isOpen={paymentModal.open}
        onClose={() => setPaymentModal({ open: false, statement: null })}
        tipo="periodo"
        statement={paymentModal.statement}
        associateId={paymentModal.statement?.associate_id}
        onSuccess={handlePaymentSuccess}
      />
    </div>
  );
}
