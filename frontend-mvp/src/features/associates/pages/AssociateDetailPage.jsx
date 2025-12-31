/**
 * AssociateDetailPage - Vista detallada de un asociado con desglose de deuda
 * 
 * OPTIMIZADO: Secciones colapsables con lazy loading
 * 
 * Muestra:
 * - Información general del asociado (siempre visible)
 * - Estado de crédito (siempre visible)
 * - Préstamos del asociado (colapsable, lazy load)
 * - Clientes del asociado (colapsable, lazy load)
 * - Desglose de deuda (colapsable, lazy load)
 * - Historial de deudas (colapsable, lazy load)
 * - Auditoría (colapsable, lazy load)
 */

import { useState, useEffect, useCallback } from 'react';
import { useParams } from 'react-router-dom';
import CollapsibleSection from '../../../shared/components/CollapsibleSection';
import DesgloseDeuda from '../../../shared/components/DesgloseDeuda';
import HistorialDeudas from '../../../shared/components/HistorialDeudas';
import AuditHistory from '../../../shared/components/AuditHistory';
import PrestamosAsociado from '../../../shared/components/PrestamosAsociado';
import RegistrarAbonoDeudaModal from '../components/RegistrarAbonoDeudaModal';
import ClientesAsociado from '../components/ClientesAsociado';
import { apiClient } from '../../../shared/api/apiClient';
import ENDPOINTS from '../../../shared/api/endpoints';
import './AssociateDetailPage.css';

const AssociateDetailPage = () => {
  const { associateId } = useParams();
  const [associate, setAssociate] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [showAbonoModal, setShowAbonoModal] = useState(false);
  const [refreshKey, setRefreshKey] = useState(0);

  // Estados para contadores de badges (cargados bajo demanda)
  const [loansCount, setLoansCount] = useState(null);
  const [clientsCount, setClientsCount] = useState(null);

  const fetchAssociateData = useCallback(async () => {
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
  }, [associateId]);

  useEffect(() => {
    if (associateId) {
      fetchAssociateData();
    }
  }, [associateId, fetchAssociateData]);

  // Cargar contadores de badges (ligero, para mostrar en headers colapsados)
  const fetchBadgeCounts = useCallback(async () => {
    if (!associate?.user_id) return;

    try {
      // Obtener conteo de préstamos
      const loansRes = await apiClient.get(`${ENDPOINTS.loans.list}?associate_user_id=${associate.user_id}&limit=1`);
      setLoansCount(loansRes.data?.total || 0);

      // Obtener conteo de clientes
      const clientsRes = await apiClient.get(`/api/v1/associates/${associateId}/clients?limit=1`);
      setClientsCount(clientsRes.data?.data?.total || 0);
    } catch (err) {
      console.error('Error fetching badge counts:', err);
    }
  }, [associate?.user_id, associateId]);

  useEffect(() => {
    if (associate) {
      fetchBadgeCounts();
    }
  }, [associate, fetchBadgeCounts]);

  const handleAbonoSuccess = (data) => {
    console.log('✅ Abono registrado:', data);
    // Refrescar datos del asociado
    fetchAssociateData();
    // Forzar refresh de componentes hijos
    setRefreshKey(prev => prev + 1);
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

        {/* Estado de Crédito - Siempre visible */}
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
              {debtBalance > 0 && (
                <button
                  onClick={() => setShowAbonoModal(true)}
                  className="btn-abono-inline"
                >
                  💰 Abonar
                </button>
              )}
            </div>
          </div>

          {/* Métricas */}
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

          {/* Barra de progreso */}
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

      {/* ═══════════════════════════════════════════════════════════════════
          SECCIONES COLAPSABLES (Lazy Loading)
          ═══════════════════════════════════════════════════════════════════ */}

      {/* Préstamos del Asociado */}
      <CollapsibleSection
        title="Préstamos del Asociado"
        icon="📋"
        subtitle="Préstamos gestionados por este asociado • Click para expandir"
        badge={loansCount}
        badgeColor={loansCount > 0 ? 'primary' : 'info'}
        defaultExpanded={false}
        persistKey={`associate_${associateId}_loans`}
      >
        {associate.user_id ? (
          <PrestamosAsociado associateUserId={associate.user_id} key={`prestamos-${refreshKey}`} />
        ) : (
          <div className="alert alert-warning">
            No se puede cargar préstamos sin ID de usuario del asociado.
          </div>
        )}
      </CollapsibleSection>

      {/* Clientes del Asociado */}
      <CollapsibleSection
        title="Clientes del Asociado"
        icon="👥"
        subtitle="Personas que han solicitado préstamos a través de este asociado"
        badge={clientsCount}
        badgeColor={clientsCount > 0 ? 'success' : 'info'}
        defaultExpanded={false}
        persistKey={`associate_${associateId}_clients`}
      >
        {associateId ? (
          <ClientesAsociado associateId={parseInt(associateId)} key={`clientes-${refreshKey}`} />
        ) : (
          <div className="alert alert-warning">
            No se puede cargar clientes sin ID de asociado.
          </div>
        )}
      </CollapsibleSection>

      {/* Desglose de Deuda */}
      <CollapsibleSection
        title="Desglose de Deuda"
        icon="📊"
        subtitle="Sistema FIFO: Abonos se aplican a deudas más antiguas primero"
        badge={debtBalance > 0 ? `$${debtBalance.toLocaleString('es-MX')}` : '✓ Sin deuda'}
        badgeColor={debtBalance > 0 ? 'danger' : 'success'}
        defaultExpanded={debtBalance > 0}
        persistKey={`associate_${associateId}_debt`}
      >
        <div style={{ display: 'flex', justifyContent: 'flex-end', marginBottom: '12px' }}>
          {debtBalance > 0 && (
            <button
              onClick={() => setShowAbonoModal(true)}
              className="btn btn-success"
            >
              💰 Registrar Abono a Deuda
            </button>
          )}
        </div>
        {associateId ? (
          <DesgloseDeuda associateId={associateId} key={`desglose-${refreshKey}`} />
        ) : (
          <div className="alert alert-info">
            No se puede cargar el desglose de deuda sin un ID de asociado válido.
          </div>
        )}
      </CollapsibleSection>

      {/* Historial de Deudas Acumuladas */}
      <CollapsibleSection
        title="Historial de Deudas Acumuladas"
        icon="📜"
        subtitle="Deudas transferidas de períodos cerrados (statements no pagados completamente)"
        defaultExpanded={false}
        persistKey={`associate_${associateId}_history`}
      >
        {associateId ? (
          <HistorialDeudas associateId={associateId} key={`historial-${refreshKey}`} />
        ) : (
          <div className="alert alert-info">
            No se puede cargar el historial de deudas sin un ID de asociado válido.
          </div>
        )}
      </CollapsibleSection>

      {/* Historial de Auditoría */}
      {associate?.user_id && (
        <CollapsibleSection
          title="Historial de Cambios"
          icon="🔍"
          subtitle="Quién creó y modificó este registro"
          defaultExpanded={false}
          persistKey={`associate_${associateId}_audit`}
        >
          <AuditHistory
            tableName="users"
            recordId={associate.user_id}
            title=""
          />
        </CollapsibleSection>
      )}

      {/* Modal de Abono a Deuda */}
      <RegistrarAbonoDeudaModal
        isOpen={showAbonoModal}
        onClose={() => setShowAbonoModal(false)}
        associateId={parseInt(associateId)}
        associateName={associate?.full_name || `${associate?.first_name || ''} ${associate?.last_name || ''}`.trim()}
        currentDebt={debtBalance}
        onSuccess={handleAbonoSuccess}
      />
    </div>
  );
};

export default AssociateDetailPage;
