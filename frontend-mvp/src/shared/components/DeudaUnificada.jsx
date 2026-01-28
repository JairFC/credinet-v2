/**
 * DeudaUnificada - Vista unificada de toda la deuda del asociado
 * 
 * Muestra:
 * - Resumen de deuda consolidada (consolidated_debt del perfil)
 * - Deuda en convenios (planes de pago activos para el ASOCIADO)
 * - Historial de deuda por período (accumulated_balances)
 * - Pagos realizados por el ASOCIADO a CrediCuenta
 * 
 * LÓGICA DE NEGOCIO:
 * - La deuda consolidada viene de statements cerrados + convenios - pagos
 * - Los convenios son para que el ASOCIADO pague a CrediCuenta (NO clientes)
 * - Los pagos del ASOCIADO a convenios reducen consolidated_debt
 * - pending_payments_total es lo que el asociado debe cobrar a clientes
 */

import { useState, useEffect, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { apiClient } from '../api/apiClient';
import ENDPOINTS from '../api/endpoints';
import './DeudaUnificada.css';

const DeudaUnificada = ({ associateId, consolidatedDebt, onAbonarClick }) => {
  const navigate = useNavigate();
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  
  // Datos
  const [debtHistory, setDebtHistory] = useState([]);
  const [convenios, setConvenios] = useState([]);
  const [allPayments, setAllPayments] = useState([]); // Historial de abonos del ASOCIADO
  const [totalAcumulado, setTotalAcumulado] = useState(0);
  const [totalPagado, setTotalPagado] = useState(0);
  
  // UI
  const [activeTab, setActiveTab] = useState('convenios'); // 'convenios' | 'historial' | 'abonos'
  const [expandedPeriod, setExpandedPeriod] = useState(null);
  const [expandedConvenio, setExpandedConvenio] = useState(null);

  // Filtros y paginación para historial de abonos
  const [filterType, setFilterType] = useState('all'); // 'all' | 'SALDO_ACTUAL' | 'DEUDA_ACUMULADA' | 'PAGO_CONVENIO'
  const [currentPage, setCurrentPage] = useState(1);
  const ITEMS_PER_PAGE = 3;

  const fetchData = useCallback(async () => {
    if (!associateId) return;

    try {
      setLoading(true);
      setError('');

      // Fetch en paralelo (incluyendo historial de abonos)
      const [historyRes, conveniosRes, paymentsRes] = await Promise.all([
        apiClient.get(ENDPOINTS.associates.debtHistory(associateId)),
        apiClient.get(`/api/v1/agreements?associate_profile_id=${associateId}`),
        apiClient.get(ENDPOINTS.associates.allPayments(associateId))
      ]);

      // Historial de deudas por período
      if (historyRes.data?.success && historyRes.data?.data) {
        setDebtHistory(historyRes.data.data.debt_history || []);
        // Este es solo el total de periodos, no convenios
        setTotalAcumulado(historyRes.data.data.total_debt || 0);
      }

      // Convenios
      let totalPagadoConvenios = 0;
      if (conveniosRes.data?.items) {
        setConvenios(conveniosRes.data.items);
        // Calcular total pagado en convenios
        totalPagadoConvenios = conveniosRes.data.items.reduce((sum, c) => sum + parseFloat(c.total_paid || 0), 0);
      }

      // Historial de abonos (todos los pagos)
      if (paymentsRes.data?.success && paymentsRes.data?.data?.payments) {
        setAllPayments(paymentsRes.data.data.payments);
        // Calcular total pagado de todos los tipos
        const totalAllPayments = paymentsRes.data.data.payments.reduce((sum, p) => sum + parseFloat(p.payment_amount || 0), 0);
        setTotalPagado(totalAllPayments);
      } else {
        setTotalPagado(totalPagadoConvenios);
      }

    } catch (err) {
      console.error('❌ Error cargando datos de deuda:', err);
      if (err.response?.status !== 404) {
        setError('Error al cargar datos: ' + (err.response?.data?.detail || err.message));
      }
    } finally {
      setLoading(false);
    }
  }, [associateId]);

  useEffect(() => {
    fetchData();
  }, [fetchData]);

  // Reset página cuando cambia filtro
  useEffect(() => {
    setCurrentPage(1);
  }, [filterType]);

  const formatCurrency = (value) => {
    return new Intl.NumberFormat('es-MX', {
      style: 'currency',
      currency: 'MXN'
    }).format(value || 0);
  };

  const formatDate = (dateStr) => {
    if (!dateStr) return '-';
    return new Date(dateStr).toLocaleDateString('es-MX', {
      day: '2-digit',
      month: 'short',
      year: 'numeric'
    });
  };

  if (loading) {
    return (
      <div className="deuda-unificada loading">
        <div className="spinner">⏳ Cargando información de deuda...</div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="deuda-unificada error">
        <div className="alert alert-danger">
          ⚠️ {error}
          <button onClick={fetchData} className="btn-retry">Reintentar</button>
        </div>
      </div>
    );
  }

  // Calcular métricas
  const conveniosActivos = convenios.filter(c => c.status === 'ACTIVE');
  const deudaEnConvenios = conveniosActivos.reduce((sum, c) => {
    const deuda = parseFloat(c.total_debt_amount || 0);
    const pagado = parseFloat(c.total_paid || 0);
    return sum + (deuda - pagado);
  }, 0);
  const deudaSinConvenio = consolidatedDebt - deudaEnConvenios;

  // Calcular total histórico REAL: pendiente + pagado
  const totalConveniosOriginal = convenios.reduce((sum, c) => sum + parseFloat(c.total_debt_amount || 0), 0);
  const totalHistorico = consolidatedDebt + totalPagado; // Lo que queda + lo que se pagó = Total que alguna vez existió

  // Filtrar y paginar abonos
  const filteredPayments = filterType === 'all' 
    ? allPayments 
    : allPayments.filter(p => p.payment_type === filterType);
  
  const totalPages = Math.ceil(filteredPayments.length / ITEMS_PER_PAGE);
  const paginatedPayments = filteredPayments.slice(
    (currentPage - 1) * ITEMS_PER_PAGE,
    currentPage * ITEMS_PER_PAGE
  );

  // Si no hay deuda
  if (consolidatedDebt <= 0 && convenios.length === 0) {
    return (
      <div className="deuda-unificada">
        <div className="no-deuda">
          <span className="icon">✅</span>
          <h3>Sin Deuda Pendiente</h3>
          <p>Este asociado no tiene deudas acumuladas.</p>
        </div>
      </div>
    );
  }

  return (
    <div className="deuda-unificada">
      {/* ═══════════════════════════════════════════════════════════════
          RESUMEN PRINCIPAL
          ═══════════════════════════════════════════════════════════════ */}
      <div className="deuda-resumen">
        <div className="resumen-header">
          <div className="resumen-total">
            <span className="label">💰 Deuda Total Actual</span>
            <span className="value">{formatCurrency(consolidatedDebt)}</span>
            <span className="note">Lo que queda por pagar</span>
          </div>
          {consolidatedDebt > 0 && (
            <button 
              className="btn btn-success btn-abonar"
              onClick={onAbonarClick}
            >
              💰 Registrar Abono
            </button>
          )}
        </div>

        {/* Desglose */}
        <div className="resumen-desglose">
          <div className="desglose-item en-convenio">
            <div className="desglose-icon">📋</div>
            <div className="desglose-content">
              <span className="desglose-label">En Convenios</span>
              <span className="desglose-value">{formatCurrency(deudaEnConvenios)}</span>
              <span className="desglose-detail">{conveniosActivos.length} convenio{conveniosActivos.length !== 1 ? 's' : ''} activo{conveniosActivos.length !== 1 ? 's' : ''}</span>
            </div>
          </div>

          <div className="desglose-item sin-convenio">
            <div className="desglose-icon">📊</div>
            <div className="desglose-content">
              <span className="desglose-label">Sin Plan de Pago</span>
              <span className="desglose-value">{formatCurrency(Math.max(0, deudaSinConvenio))}</span>
              <span className="desglose-detail">Deuda acumulada directa</span>
            </div>
          </div>

          <div className="desglose-item pagado">
            <div className="desglose-icon">✓</div>
            <div className="desglose-content">
              <span className="desglose-label">Total Pagado</span>
              <span className="desglose-value">{formatCurrency(totalPagado)}</span>
              <span className="desglose-detail">Abonos realizados</span>
            </div>
          </div>
        </div>

        {/* Info adicional - CORREGIDO: mostrar total histórico real */}
        <div className="resumen-info">
          <span className="info-icon">ℹ️</span>
          <span className="info-text">
            Deuda original en convenios: {formatCurrency(totalConveniosOriginal)} + 
            Deuda de períodos: {formatCurrency(Math.max(0, deudaSinConvenio))} | 
            Pagado: {formatCurrency(totalPagado)} | 
            Pendiente: {formatCurrency(consolidatedDebt)}
          </span>
        </div>
      </div>

      {/* ═══════════════════════════════════════════════════════════════
          TABS
          ═══════════════════════════════════════════════════════════════ */}
      <div className="deuda-tabs">
        <button 
          className={`tab ${activeTab === 'convenios' ? 'active' : ''}`}
          onClick={() => setActiveTab('convenios')}
        >
          📋 Convenios ({convenios.length})
        </button>
        <button 
          className={`tab ${activeTab === 'historial' ? 'active' : ''}`}
          onClick={() => setActiveTab('historial')}
        >
          📜 Historial por Período ({debtHistory.length})
        </button>
        <button 
          className={`tab ${activeTab === 'abonos' ? 'active' : ''}`}
          onClick={() => setActiveTab('abonos')}
        >
          💵 Historial de Abonos ({allPayments.length})
        </button>
      </div>

      {/* ═══════════════════════════════════════════════════════════════
          CONTENIDO DE TABS
          ═══════════════════════════════════════════════════════════════ */}
      <div className="deuda-content">
        
        {/* TAB: CONVENIOS */}
        {activeTab === 'convenios' && (
          <div className="tab-convenios">
            {convenios.length === 0 ? (
              <div className="empty-state">
                <p>No hay convenios de pago registrados</p>
              </div>
            ) : (
              convenios.map((convenio) => {
                const deuda = parseFloat(convenio.total_debt_amount || 0);
                const pagado = parseFloat(convenio.total_paid || 0);
                const pendiente = deuda - pagado;
                const progreso = deuda > 0 ? (pagado / deuda) * 100 : 0;
                const isExpanded = expandedConvenio === convenio.id;

                return (
                  <div 
                    key={convenio.id} 
                    className={`convenio-card ${convenio.status.toLowerCase()}`}
                  >
                    <div 
                      className="convenio-header"
                      onClick={() => setExpandedConvenio(isExpanded ? null : convenio.id)}
                    >
                      <div className="convenio-info">
                        <strong>{convenio.agreement_number}</strong>
                        <span className={`badge badge-${convenio.status === 'ACTIVE' ? 'warning' : convenio.status === 'COMPLETED' ? 'success' : 'secondary'}`}>
                          {convenio.status === 'ACTIVE' ? '⏳ Activo' : convenio.status === 'COMPLETED' ? '✓ Completado' : convenio.status}
                        </span>
                      </div>
                      
                      <div className="convenio-progress">
                        <div className="progress-bar">
                          <div className="progress-fill" style={{ width: `${progreso}%` }} />
                        </div>
                        <span className="progress-text">{progreso.toFixed(0)}%</span>
                      </div>

                      <div className="convenio-amounts">
                        <span className="amount pendiente">{formatCurrency(pendiente)}</span>
                        <span className="amount-label">pendiente</span>
                      </div>

                      <span className="toggle">{isExpanded ? '▲' : '▼'}</span>
                    </div>

                    {isExpanded && (
                      <div className="convenio-details">
                        <div className="details-grid">
                          <div className="detail">
                            <span className="label">Total Convenio</span>
                            <span className="value">{formatCurrency(deuda)}</span>
                          </div>
                          <div className="detail">
                            <span className="label">Pagado</span>
                            <span className="value success">{formatCurrency(pagado)}</span>
                          </div>
                          <div className="detail">
                            <span className="label">
                              {convenio.payment_frequency === 'biweekly' ? 'Cuota Quincenal' : 'Cuota Mensual'}
                            </span>
                            <span className="value">{formatCurrency(convenio.period_payment_amount || convenio.monthly_payment_amount)}</span>
                          </div>
                          <div className="detail">
                            <span className="label">Pagos</span>
                            <span className="value">{convenio.payments_made} de {convenio.payment_plan_periods || convenio.payment_plan_months}</span>
                          </div>
                        </div>
                        <div className="details-actions">
                          <button 
                            className="btn btn-primary btn-sm"
                            onClick={() => navigate(`/convenios/${convenio.id}`)}
                          >
                            📋 Ver Detalle Completo
                          </button>
                        </div>
                      </div>
                    )}
                  </div>
                );
              })
            )}
          </div>
        )}

        {/* TAB: HISTORIAL POR PERÍODO */}
        {activeTab === 'historial' && (
          <div className="tab-historial">
            {debtHistory.length === 0 ? (
              <div className="empty-state">
                <p>No hay historial de deudas por período</p>
              </div>
            ) : (
              debtHistory.map((period) => {
                const isExpanded = expandedPeriod === period.id;
                
                return (
                  <div key={period.id} className="periodo-card">
                    <div 
                      className="periodo-header"
                      onClick={() => setExpandedPeriod(isExpanded ? null : period.id)}
                    >
                      <div className="periodo-info">
                        <span className="periodo-icon">📅</span>
                        <div className="periodo-text">
                          <strong>Período {period.period_code}</strong>
                          <span className="periodo-dates">
                            {formatDate(period.period_start)} - {formatDate(period.period_end)}
                          </span>
                        </div>
                      </div>
                      
                      <div className="periodo-amount">
                        <span className="amount">{formatCurrency(period.accumulated_debt)}</span>
                        <span className="toggle">{isExpanded ? '▼' : '▶'}</span>
                      </div>
                    </div>

                    {isExpanded && period.details && period.details.length > 0 && (
                      <div className="periodo-details">
                        {period.details.map((detail, idx) => (
                          <div key={idx} className="detail-item">
                            <div className="detail-header">
                              <span className="statement-number">{detail.statement_number}</span>
                            </div>
                            <div className="detail-amounts">
                              <div className="amount-row">
                                <span className="label">Original:</span>
                                <span className="value">{formatCurrency(detail.original_amount)}</span>
                              </div>
                              <div className="amount-row">
                                <span className="label">Pagado:</span>
                                <span className="value success">{formatCurrency(detail.paid_amount)}</span>
                              </div>
                              <div className="amount-row">
                                <span className="label">Deuda:</span>
                                <span className="value danger">{formatCurrency(detail.debt_amount)}</span>
                              </div>
                            </div>
                            <div className="detail-date">
                              Absorbido: {formatDate(detail.absorbed_date)}
                            </div>
                          </div>
                        ))}
                      </div>
                    )}
                  </div>
                );
              })
            )}
          </div>
        )}

        {/* TAB: HISTORIAL DE ABONOS */}
        {activeTab === 'abonos' && (
          <div className="tab-abonos">
            {/* Filtros */}
            <div className="abonos-filters">
              <div className="filter-group">
                <label>Tipo de Pago:</label>
                <select 
                  value={filterType} 
                  onChange={(e) => setFilterType(e.target.value)}
                  className="filter-select"
                >
                  <option value="all">Todos ({allPayments.length})</option>
                  <option value="SALDO_ACTUAL">📊 Pagos a Statement ({allPayments.filter(p => p.payment_type === 'SALDO_ACTUAL').length})</option>
                  <option value="DEUDA_ACUMULADA">💰 Abonos a Deuda ({allPayments.filter(p => p.payment_type === 'DEUDA_ACUMULADA').length})</option>
                  <option value="PAGO_CONVENIO">📋 Pagos de Convenio ({allPayments.filter(p => p.payment_type === 'PAGO_CONVENIO').length})</option>
                </select>
              </div>
              <div className="filter-summary">
                Mostrando {paginatedPayments.length} de {filteredPayments.length} abonos
              </div>
            </div>

            {filteredPayments.length === 0 ? (
              <div className="empty-state">
                <p>No hay abonos de este tipo</p>
              </div>
            ) : (
              <>
                <div className="abonos-list">
                  {paginatedPayments.map((payment) => {
                    const paymentTypeConfig = {
                      'SALDO_ACTUAL': { icon: '📊', label: 'Pago a Statement', color: 'primary' },
                      'DEUDA_ACUMULADA': { icon: '💰', label: 'Abono a Deuda', color: 'warning' },
                      'PAGO_CONVENIO': { icon: '📋', label: 'Pago de Convenio', color: 'success' }
                    };
                    const config = paymentTypeConfig[payment.payment_type] || { icon: '💵', label: payment.payment_type, color: 'secondary' };

                    return (
                      <div key={`${payment.payment_type}-${payment.id}`} className="abono-card">
                        <div className="abono-header">
                          <div className="abono-type">
                            <span className="abono-icon">{config.icon}</span>
                            <span className={`abono-badge badge-${config.color}`}>{config.label}</span>
                          </div>
                          <div className="abono-amount">
                            {formatCurrency(payment.payment_amount)}
                          </div>
                        </div>
                        <div className="abono-details">
                          <div className="abono-date">
                            <span className="label">Fecha:</span>
                            <span className="value">{formatDate(payment.payment_date)}</span>
                          </div>
                          <div className="abono-method">
                            <span className="label">Método:</span>
                            <span className="value">{payment.payment_method || 'N/A'}</span>
                          </div>
                          {payment.payment_reference && (
                            <div className="abono-reference">
                              <span className="label">Referencia:</span>
                              <span className="value">{payment.payment_reference}</span>
                            </div>
                          )}
                          {payment.notes && (
                            <div className="abono-notes">
                              <span className="label">Notas:</span>
                              <span className="value">{payment.notes}</span>
                            </div>
                          )}
                          {payment.period_start && payment.period_end && (
                            <div className="abono-period">
                              <span className="label">Período:</span>
                              <span className="value">{formatDate(payment.period_start)} - {formatDate(payment.period_end)}</span>
                            </div>
                          )}
                        </div>
                      </div>
                    );
                  })}
                </div>

                {/* Paginación */}
                {totalPages > 1 && (
                  <div className="abonos-pagination">
                    <button
                      className="pagination-btn"
                      onClick={() => setCurrentPage(prev => Math.max(1, prev - 1))}
                      disabled={currentPage === 1}
                    >
                      ← Anterior
                    </button>
                    <div className="pagination-info">
                      Página {currentPage} de {totalPages}
                    </div>
                    <button
                      className="pagination-btn"
                      onClick={() => setCurrentPage(prev => Math.min(totalPages, prev + 1))}
                      disabled={currentPage === totalPages}
                    >
                      Siguiente →
                    </button>
                  </div>
                )}
              </>
            )}
          </div>
        )}
      </div>
    </div>
  );
};

export default DeudaUnificada;
