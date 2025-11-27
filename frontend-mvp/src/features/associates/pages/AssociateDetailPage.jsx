/**
 * AssociateDetailPage - Vista detallada de un asociado con desglose de deuda
 * 
 * Muestra:
 * - Información general del asociado
 * - Estado de crédito (límite, usado, disponible)
 * - DesgloseDeuda con sistema FIFO
 */

import { useState, useEffect } from 'react';
import { useParams } from 'react-router-dom';
import DesgloseDeuda from '../../../shared/components/DesgloseDeuda';
import { apiClient } from '../../../shared/api/apiClient';
import ENDPOINTS from '../../../shared/api/endpoints';
import './AssociateDetailPage.css';

const AssociateDetailPage = () => {
  const { associateId } = useParams();
  const [associate, setAssociate] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    if (associateId) {
      fetchAssociateData();
    }
  }, [associateId]);

  const fetchAssociateData = async () => {
    try {
      setLoading(true);
      setError('');
      const response = await apiClient.get(ENDPOINTS.associates.detail(associateId));
      console.log('📥 Associate detail response:', response.data);
      setAssociate(response.data);
    } catch (err) {
      console.error('❌ Error loading associate:', err);
      setError('Error al cargar asociado: ' + (err.response?.data?.detail || err.message));
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return (
      <div className="associate-detail-page">
        <div className="loading-container">
          <div className="spinner">⏳ Cargando datos del asociado...</div>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="associate-detail-page">
        <div className="error-banner">
          <span>⚠️ {error}</span>
          <button onClick={fetchAssociateData}>Reintentar</button>
        </div>
      </div>
    );
  }

  if (!associate) {
    return (
      <div className="associate-detail-page">
        <div className="alert alert-warning">
          📋 No se encontró información del asociado
        </div>
      </div>
    );
  }

  // Convertir valores numéricos que vienen como strings
  const creditLimit = parseFloat(associate.credit_limit) || 0;
  const creditUsed = parseFloat(associate.credit_used) || 0;
  const creditAvailable = parseFloat(associate.credit_available) || 0;
  const debtBalance = parseFloat(associate.debt_balance) || 0;

  const creditUsagePercent = creditLimit > 0
    ? (creditUsed / creditLimit) * 100
    : 0;

  return (
    <div className="associate-detail-page">
      {/* Header */}
      <div className="page-header">
        <h1>👤 Detalle del Asociado</h1>
        <button
          className="btn btn-secondary"
          onClick={() => window.history.back()}
        >
          ← Volver
        </button>
      </div>

      {/* Información General */}
      <div className="associate-info-card">
        <div className="info-section">
          <h2>📋 Información General</h2>
          <div className="info-grid">
            <div className="info-item">
              <span className="label">ID:</span>
              <span className="value">#{associate.id}</span>
            </div>
            <div className="info-item">
              <span className="label">Usuario:</span>
              <span className="value">{associate.username || 'N/A'}</span>
            </div>
            <div className="info-item">
              <span className="label">Nombre:</span>
              <span className="value">{associate.full_name || `${associate.first_name || ''} ${associate.last_name || ''}`.trim() || 'N/A'}</span>
            </div>
            <div className="info-item">
              <span className="label">Email:</span>
              <span className="value">{associate.email || 'N/A'}</span>
            </div>
            <div className="info-item">
              <span className="label">Teléfono:</span>
              <span className="value">{associate.phone_number || 'N/A'}</span>
            </div>
            <div className="info-item">
              <span className="label">Nivel:</span>
              <span className="value badge badge-info">
                Nivel {associate.level_id || 'N/A'}
              </span>
            </div>
            <div className="info-item">
              <span className="label">Estado:</span>
              <span className={`value badge ${associate.active ? 'badge-success' : 'badge-danger'}`}>
                {associate.active ? '✓ Activo' : '✗ Inactivo'}
              </span>
            </div>
            <div className="info-item">
              <span className="label">Comisión:</span>
              <span className="value">{associate.default_commission_rate}%</span>
            </div>
          </div>
        </div>

        {/* Estado de Crédito */}
        <div className="credit-section">
          <h2>💳 Estado de Crédito</h2>

          <div className="credit-stats">
            <div className="credit-stat">
              <div className="stat-label">Límite de Crédito</div>
              <div className="stat-value">
                ${creditLimit.toLocaleString('es-MX', { minimumFractionDigits: 2 })}
              </div>
            </div>

            <div className="credit-stat">
              <div className="stat-label">Crédito Usado</div>
              <div className="stat-value stat-warning">
                ${creditUsed.toLocaleString('es-MX', { minimumFractionDigits: 2 })}
              </div>
            </div>

            <div className="credit-stat">
              <div className="stat-label">Crédito Disponible</div>
              <div className="stat-value stat-success">
                ${creditAvailable.toLocaleString('es-MX', { minimumFractionDigits: 2 })}
              </div>
            </div>

            <div className="credit-stat">
              <div className="stat-label">Deuda Total</div>
              <div className="stat-value stat-danger">
                ${debtBalance.toLocaleString('es-MX', { minimumFractionDigits: 2 })}
              </div>
            </div>
          </div>

          {/* Métricas adicionales */}
          <div className="metrics-grid">
            <div className="metric-item">
              <span className="metric-label">Períodos con crédito completo:</span>
              <span className="metric-value">{associate.consecutive_full_credit_periods || 0}</span>
            </div>
            <div className="metric-item">
              <span className="metric-label">Pagos puntuales consecutivos:</span>
              <span className="metric-value">{associate.consecutive_on_time_payments || 0}</span>
            </div>
            <div className="metric-item">
              <span className="metric-label">Clientes en acuerdo:</span>
              <span className="metric-value">{associate.clients_in_agreement || 0}</span>
            </div>
          </div>

          {/* Barra de progreso de crédito */}
          <div className="credit-progress-container">
            <div className="credit-progress-bar">
              <div
                className="credit-progress-fill"
                style={{
                  width: `${Math.min(creditUsagePercent, 100)}%`,
                  backgroundColor: creditUsagePercent > 90 ? '#dc3545' : creditUsagePercent > 70 ? '#ffc107' : '#28a745'
                }}
              />
            </div>
            <div className="credit-progress-label">
              {creditUsagePercent.toFixed(1)}% del crédito utilizado
            </div>
          </div>
        </div>
      </div>

      {/* Desglose de Deuda */}
      <div className="debt-section">
        <h2>📊 Desglose de Deuda (FIFO)</h2>
        {associateId ? (
          <DesgloseDeuda associateId={associateId} />
        ) : (
          <div className="alert alert-info">
            No se puede cargar el desglose de deuda sin un ID de asociado válido.
          </div>
        )}
      </div>
    </div>
  );
};

export default AssociateDetailPage;
