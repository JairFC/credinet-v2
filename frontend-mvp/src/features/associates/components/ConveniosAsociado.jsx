/**
 * ConveniosAsociado - Lista de convenios de pago de un asociado
 * 
 * Muestra los convenios activos y completados del asociado con:
 * - Resumen de deuda en convenios
 * - Lista de convenios con progreso de pagos
 * - Historial de pagos de convenios
 */

import { useState, useEffect, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { apiClient } from '../../../shared/api/apiClient';
import './ConveniosAsociado.css';

const ConveniosAsociado = ({ associateProfileId }) => {
  const navigate = useNavigate();
  const [convenios, setConvenios] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [expandedId, setExpandedId] = useState(null);

  const fetchConvenios = useCallback(async () => {
    if (!associateProfileId) return;

    try {
      setLoading(true);
      setError('');

      const response = await apiClient.get(`/api/v1/agreements?associate_profile_id=${associateProfileId}`);
      console.log('📥 Convenios del asociado:', response.data);

      if (response.data?.items) {
        setConvenios(response.data.items);
      } else {
        setConvenios([]);
      }
    } catch (err) {
      console.error('❌ Error cargando convenios:', err);
      setError('Error al cargar convenios: ' + (err.response?.data?.detail || err.message));
    } finally {
      setLoading(false);
    }
  }, [associateProfileId]);

  useEffect(() => {
    fetchConvenios();
  }, [fetchConvenios]);

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

  const getStatusBadge = (status) => {
    const config = {
      'ACTIVE': { label: 'Activo', class: 'badge-warning', icon: '⏳' },
      'COMPLETED': { label: 'Completado', class: 'badge-success', icon: '✓' },
      'CANCELLED': { label: 'Cancelado', class: 'badge-danger', icon: '✗' },
      'DEFAULTED': { label: 'Incumplido', class: 'badge-danger', icon: '⚠️' }
    };
    const cfg = config[status] || { label: status, class: 'badge-secondary', icon: '?' };
    return <span className={`badge ${cfg.class}`}>{cfg.icon} {cfg.label}</span>;
  };

  if (loading) {
    return (
      <div className="convenios-asociado">
        <div className="loading-spinner">
          ⏳ Cargando convenios...
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="convenios-asociado">
        <div className="error-message">
          ⚠️ {error}
          <button onClick={fetchConvenios} className="btn-retry">Reintentar</button>
        </div>
      </div>
    );
  }

  // Calcular resumen
  const conveniosActivos = convenios.filter(c => c.status === 'ACTIVE');
  const totalDeudaConvenios = conveniosActivos.reduce((sum, c) => sum + parseFloat(c.total_debt_amount || 0), 0);
  const totalPagadoConvenios = convenios.reduce((sum, c) => sum + parseFloat(c.total_paid || 0), 0);
  const totalPendienteConvenios = conveniosActivos.reduce((sum, c) => {
    const deuda = parseFloat(c.total_debt_amount || 0);
    const pagado = parseFloat(c.total_paid || 0);
    return sum + (deuda - pagado);
  }, 0);

  if (convenios.length === 0) {
    return (
      <div className="convenios-asociado">
        <div className="empty-state">
          <span className="empty-icon">📋</span>
          <p>Este asociado no tiene convenios de pago registrados</p>
        </div>
      </div>
    );
  }

  return (
    <div className="convenios-asociado">
      {/* Resumen de Convenios */}
      <div className="convenios-summary">
        <div className="summary-card total">
          <div className="summary-icon">📋</div>
          <div className="summary-content">
            <div className="summary-label">Total en Convenios</div>
            <div className="summary-value">{formatCurrency(totalDeudaConvenios)}</div>
            <div className="summary-detail">{conveniosActivos.length} convenio{conveniosActivos.length !== 1 ? 's' : ''} activo{conveniosActivos.length !== 1 ? 's' : ''}</div>
          </div>
        </div>

        <div className="summary-card paid">
          <div className="summary-icon">✓</div>
          <div className="summary-content">
            <div className="summary-label">Total Pagado</div>
            <div className="summary-value">{formatCurrency(totalPagadoConvenios)}</div>
          </div>
        </div>

        <div className="summary-card pending">
          <div className="summary-icon">⏳</div>
          <div className="summary-content">
            <div className="summary-label">Pendiente de Pagar</div>
            <div className="summary-value">{formatCurrency(totalPendienteConvenios)}</div>
          </div>
        </div>
      </div>

      {/* Lista de Convenios */}
      <div className="convenios-list">
        <h4>📝 Convenios de Pago</h4>
        
        {convenios.map((convenio) => {
          const deuda = parseFloat(convenio.total_debt_amount || 0);
          const pagado = parseFloat(convenio.total_paid || 0);
          const pendiente = deuda - pagado;
          const progreso = deuda > 0 ? (pagado / deuda) * 100 : 0;
          const isExpanded = expandedId === convenio.id;

          return (
            <div key={convenio.id} className={`convenio-item ${convenio.status.toLowerCase()}`}>
              <div 
                className="convenio-header"
                onClick={() => setExpandedId(isExpanded ? null : convenio.id)}
              >
                <div className="convenio-info">
                  <div className="convenio-number">
                    <strong>{convenio.agreement_number}</strong>
                    {getStatusBadge(convenio.status)}
                  </div>
                  <div className="convenio-date">
                    Creado: {formatDate(convenio.agreement_date)}
                  </div>
                </div>

                <div className="convenio-amounts">
                  <div className="amount-item">
                    <span className="label">Total:</span>
                    <span className="value">{formatCurrency(deuda)}</span>
                  </div>
                  <div className="amount-item paid">
                    <span className="label">Pagado:</span>
                    <span className="value">{formatCurrency(pagado)}</span>
                  </div>
                  <div className="amount-item pending">
                    <span className="label">Pendiente:</span>
                    <span className="value">{formatCurrency(pendiente)}</span>
                  </div>
                </div>

                <div className="convenio-progress">
                  <div className="progress-bar">
                    <div 
                      className="progress-fill"
                      style={{ width: `${Math.min(progreso, 100)}%` }}
                    />
                  </div>
                  <span className="progress-text">{progreso.toFixed(0)}%</span>
                </div>

                <div className="convenio-toggle">
                  {isExpanded ? '▲' : '▼'}
                </div>
              </div>

              {isExpanded && (
                <div className="convenio-details">
                  <div className="details-grid">
                    <div className="detail-item">
                      <span className="label">Plazo:</span>
                      <span className="value">
                        {convenio.payment_plan_periods 
                          ? `${convenio.payment_plan_periods} quincenas` 
                          : `${convenio.payment_plan_months} meses`}
                      </span>
                    </div>
                    <div className="detail-item">
                      <span className="label">
                        {convenio.payment_frequency === 'biweekly' ? 'Cuota quincenal:' : 'Cuota mensual:'}
                      </span>
                      <span className="value">{formatCurrency(convenio.period_payment_amount || convenio.monthly_payment_amount)}</span>
                    </div>
                    <div className="detail-item">
                      <span className="label">Pagos realizados:</span>
                      <span className="value">{convenio.payments_made} de {convenio.payment_plan_periods || convenio.payment_plan_months}</span>
                    </div>
                  </div>

                  <div className="details-actions">
                    <button
                      className="btn btn-primary btn-sm"
                      onClick={(e) => {
                        e.stopPropagation();
                        navigate(`/convenios/${convenio.id}`);
                      }}
                    >
                      📋 Ver Detalle
                    </button>
                  </div>
                </div>
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
};

export default ConveniosAsociado;
