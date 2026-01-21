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
import DeudaUnificada from '../../../shared/components/DeudaUnificada';
import AuditHistory from '../../../shared/components/AuditHistory';
import PrestamosAsociado from '../../../shared/components/PrestamosAsociado';
import PromoteRoleModal from '../../../shared/components/PromoteRoleModal';
import RegistrarAbonoDeudaModal from '../components/RegistrarAbonoDeudaModal';
import ClientesAsociado from '../components/ClientesAsociado';
import { apiClient } from '../../../shared/api/apiClient';
import { associatesService } from '../../../shared/api/services/associatesService';
import ENDPOINTS from '../../../shared/api/endpoints';
import './AssociateDetailPage.css';

const AssociateDetailPage = () => {
  const { associateId } = useParams();
  const [associate, setAssociate] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [showAbonoModal, setShowAbonoModal] = useState(false);
  const [showRoleModal, setShowRoleModal] = useState(false);
  const [refreshKey, setRefreshKey] = useState(0);
  const [userRoles, setUserRoles] = useState([]);

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
      
      // Obtener roles del usuario
      if (response.data?.user_id) {
        try {
          const rolesRes = await associatesService.getUserRoles(response.data.user_id);
          setUserRoles(rolesRes.data?.roles || []);
        } catch (roleErr) {
          console.error('Error fetching roles:', roleErr);
        }
      }
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

  const handleRoleSuccess = () => {
    fetchAssociateData();
  };

  const isAlsoClient = userRoles.some(r => r.role_id === 5 || r.role_name?.toLowerCase() === 'cliente');

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
  // NOMBRES ACTUALIZADOS (Backend v2.0):
  // - pending_payments_total: lo que el asociado debe cobrar/entregar
  // - consolidated_debt: deuda consolidada (statements + convenios)
  // - available_credit: crédito disponible
  const creditLimit = parseFloat(associate.credit_limit) || 0;
  const pendingPaymentsTotal = parseFloat(associate.pending_payments_total) || 0;
  const availableCredit = parseFloat(associate.available_credit) || 0;
  const consolidatedDebt = parseFloat(associate.consolidated_debt) || 0;

  // Uso de crédito = pending_payments_total + consolidated_debt
  const totalCreditUsed = pendingPaymentsTotal + consolidatedDebt;
  const creditUsagePercent = creditLimit > 0
    ? (totalCreditUsed / creditLimit) * 100
    : 0;

  return (
    <div className="associate-detail-page">
      {/* Header con nombre del asociado */}
      <div className="page-header">
        <div className="header-info">
          <h1>{associate.full_name || `${associate.first_name || ''} ${associate.last_name || ''}`.trim() || 'Asociado'}</h1>
          <div className="header-meta">
            <span className={`status-badge ${associate.active ? 'active' : 'inactive'}`}>
              {associate.active ? '● Activo' : '○ Inactivo'}
            </span>
            <span className="associate-id">ID: #{associate.id}</span>
            {associate.username && <span className="username">@{associate.username}</span>}
            {isAlsoClient && (
              <span className="role-badge client">También es Cliente</span>
            )}
          </div>
        </div>
        <div className="header-actions">
          {!isAlsoClient && (
            <button
              className="btn btn-add-role"
              onClick={() => setShowRoleModal(true)}
            >
              👤 Agregar Rol Cliente
            </button>
          )}
          <button
            className="btn btn-secondary"
            onClick={() => window.history.back()}
          >
            ← Volver
          </button>
        </div>
      </div>

      {/* Modal para agregar rol */}
      <PromoteRoleModal
        isOpen={showRoleModal}
        onClose={() => setShowRoleModal(false)}
        user={associate}
        promotionType="to-client"
        onSuccess={handleRoleSuccess}
      />

      {/* Estado de Crédito - SIEMPRE VISIBLE (Hero Section) */}
      <div className="credit-hero-card">
        <div className="credit-stats">
          <div className="credit-stat">
            <div className="stat-label">Límite de Crédito</div>
            <div className="stat-value">
              ${creditLimit.toLocaleString('es-MX', { minimumFractionDigits: 2 })}
            </div>
          </div>

          <div className="credit-stat">
            <div className="stat-label">Pagos Pendientes</div>
            <div className="stat-value stat-warning">
              ${pendingPaymentsTotal.toLocaleString('es-MX', { minimumFractionDigits: 2 })}
            </div>
            <div className="stat-hint">Por cobrar a clientes</div>
          </div>

          <div className="credit-stat">
            <div className="stat-label">Crédito Disponible</div>
            <div className="stat-value stat-success">
              ${availableCredit.toLocaleString('es-MX', { minimumFractionDigits: 2 })}
            </div>
          </div>

          <div className="credit-stat">
            <div className="stat-label">Deuda Consolidada</div>
            <div className="stat-value stat-danger">
              ${consolidatedDebt.toLocaleString('es-MX', { minimumFractionDigits: 2 })}
            </div>
            <div className="stat-hint">Statements + Convenios</div>
            {consolidatedDebt > 0 && (
              <button
                onClick={() => setShowAbonoModal(true)}
                className="btn-abono-inline"
              >
                💰 Abonar
              </button>
            )}
          </div>
        </div>

        {/* Barra de progreso */}
        <div className="credit-progress-container">
          <div className="credit-progress-bar">
            <div
              className="credit-progress-fill"
              style={{
                width: `${Math.min(creditUsagePercent, 100)}%`,
                backgroundColor: creditUsagePercent > 90 ? '#ef4444' : creditUsagePercent > 70 ? '#f59e0b' : '#10b981'
              }}
            />
          </div>
          <div className="credit-progress-label">
            {creditUsagePercent.toFixed(1)}% del crédito utilizado
          </div>
        </div>
      </div>

      {/* ═══════════════════════════════════════════════════════════════════
          SECCIONES COLAPSABLES (Lazy Loading)
          ═══════════════════════════════════════════════════════════════════ */}

      {/* Información del Asociado */}
      <CollapsibleSection
        title="Información del Asociado"
        icon="📋"
        subtitle="Datos personales, contacto y métricas"
        badge={`Nivel ${associate.level_id || '?'}`}
        badgeColor="info"
      >
        <div className="info-grid">
          <div className="info-item">
            <span className="label">Email</span>
            <span className="value">{associate.email || 'N/A'}</span>
          </div>
          <div className="info-item">
            <span className="label">Teléfono</span>
            <span className="value">{associate.phone_number || 'N/A'}</span>
          </div>
          <div className="info-item">
            <span className="label">Nivel</span>
            <span className="value badge badge-info">Nivel {associate.level_id || 'N/A'}</span>
          </div>
          <div className="info-item">
            <span className="label">Períodos con crédito completo</span>
            <span className="value">{associate.consecutive_full_credit_periods || 0}</span>
          </div>
          <div className="info-item">
            <span className="label">Pagos puntuales consecutivos</span>
            <span className="value">{associate.consecutive_on_time_payments || 0}</span>
          </div>
          <div className="info-item">
            <span className="label">Clientes en acuerdo</span>
            <span className="value">{associate.clients_in_agreement || 0}</span>
          </div>
        </div>
      </CollapsibleSection>

      {/* Préstamos del Asociado */}
      <CollapsibleSection
        title="Préstamos del Asociado"
        icon="📋"
        subtitle="Préstamos gestionados por este asociado • Click para expandir"
        badge={loansCount}
        badgeColor={loansCount > 0 ? 'primary' : 'info'}
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
      >
        {associateId ? (
          <ClientesAsociado associateId={parseInt(associateId)} key={`clientes-${refreshKey}`} />
        ) : (
          <div className="alert alert-warning">
            No se puede cargar clientes sin ID de asociado.
          </div>
        )}
      </CollapsibleSection>

      {/* Deuda del Asociado - Vista Unificada */}
      <CollapsibleSection
        title="Deuda del Asociado"
        icon="💰"
        subtitle="Deuda consolidada: statements cerrados + convenios activos"
        badge={consolidatedDebt > 0 ? `$${consolidatedDebt.toLocaleString('es-MX')}` : '✓ Sin deuda'}
        badgeColor={consolidatedDebt > 0 ? 'danger' : 'success'}
      >
        {associateId ? (
          <DeudaUnificada 
            associateId={associateId} 
            consolidatedDebt={consolidatedDebt}
            onAbonarClick={() => setShowAbonoModal(true)}
            key={`deuda-${refreshKey}`} 
          />
        ) : (
          <div className="alert alert-info">
            No se puede cargar la deuda sin un ID de asociado válido.
          </div>
        )}
      </CollapsibleSection>

      {/* Historial de Auditoría */}
      {associate?.user_id && (
        <CollapsibleSection
          title="Historial de Cambios"
          icon="🔍"
          subtitle="Quién creó y modificó este registro"
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
        currentDebt={consolidatedDebt}
        onSuccess={handleAbonoSuccess}
      />
    </div>
  );
};

export default AssociateDetailPage;
