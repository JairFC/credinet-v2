/**
 * ClientDetailPage - Vista detallada de un cliente
 * 
 * Muestra:
 * - Información personal del cliente
 * - Datos de dirección
 * - Información laboral
 * - Datos bancarios
 * - Aval y beneficiario
 * - Préstamos activos
 */

import { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { clientsService } from '../../../../shared/api/services/clientsService';
import { associatesService } from '../../../../shared/api/services/associatesService';
import AuditHistory from '../../../../shared/components/AuditHistory';
import PromoteRoleModal from '../../../../shared/components/PromoteRoleModal';
import './ClientDetailPage.css';

const ClientDetailPage = () => {
  const { clientId } = useParams();
  const navigate = useNavigate();
  const [client, setClient] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [showPromoteModal, setShowPromoteModal] = useState(false);
  const [userRoles, setUserRoles] = useState([]);

  useEffect(() => {
    if (clientId) {
      fetchClientData();
    }
  }, [clientId]);

  const fetchClientData = async () => {
    try {
      setLoading(true);
      setError('');
      const response = await clientsService.getById(clientId);
      setClient(response.data);
      
      // Obtener roles del usuario
      if (response.data?.user_id || response.data?.id) {
        try {
          const rolesRes = await associatesService.getUserRoles(response.data.user_id || response.data.id);
          setUserRoles(rolesRes.data?.roles || []);
        } catch (roleErr) {
          console.error('Error fetching roles:', roleErr);
        }
      }
    } catch (err) {
      console.error('Error fetching client:', err);
      setError(err.response?.data?.detail || 'Error al cargar datos del cliente');
    } finally {
      setLoading(false);
    }
  };

  const isAlsoAssociate = userRoles.some(r => r.role_id === 4 || r.role_name?.toLowerCase() === 'asociado');

  const handlePromoteSuccess = () => {
    fetchClientData(); // Refrescar datos
  };

  if (loading) {
    return (
      <div className="client-detail-page">
        <div className="loading-container">
          <div className="spinner">⏳ Cargando datos del cliente...</div>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="client-detail-page">
        <div className="error-banner">
          <span>⚠️ {error}</span>
          <button className="btn btn-primary" onClick={fetchClientData}>Reintentar</button>
        </div>
      </div>
    );
  }

  if (!client) {
    return (
      <div className="client-detail-page">
        <div className="alert alert-warning">
          📋 No se encontró información del cliente
        </div>
      </div>
    );
  }

  return (
    <div className="client-detail-page">
      {/* Header */}
      <div className="page-header">
        <div className="header-left">
          <h1>👤 Detalle del Cliente</h1>
          <span className={`status-badge ${client.active ? 'active' : 'inactive'}`}>
            {client.active ? '✓ Activo' : '✗ Inactivo'}
          </span>
          {isAlsoAssociate && (
            <span className="role-badge associate">También es Asociado</span>
          )}
        </div>
        <div className="header-actions">
          {!isAlsoAssociate && (
            <button
              className="btn btn-promote"
              onClick={() => setShowPromoteModal(true)}
            >
              🎯 Hacer Asociado
            </button>
          )}
          <button
            className="btn btn-secondary"
            onClick={() => navigate('/usuarios/clientes')}
          >
            ← Volver al Listado
          </button>
        </div>
      </div>

      {/* Modal de Promoción */}
      <PromoteRoleModal
        isOpen={showPromoteModal}
        onClose={() => setShowPromoteModal(false)}
        user={client}
        promotionType="to-associate"
        onSuccess={handlePromoteSuccess}
      />

      <div className="detail-container">
        {/* Información Personal */}
        <div className="info-card">
          <div className="card-header">
            <h2>👤 Información Personal</h2>
          </div>
          <div className="info-grid">
            <div className="info-item">
              <span className="label">Nombre Completo:</span>
              <span className="value">{client.full_name || `${client.first_name} ${client.last_name}`}</span>
            </div>
            <div className="info-item">
              <span className="label">Usuario:</span>
              <span className="value">{client.username}</span>
            </div>
            <div className="info-item">
              <span className="label">CURP:</span>
              <span className="value">{client.curp || 'N/A'}</span>
            </div>
            <div className="info-item">
              <span className="label">Fecha de Nacimiento:</span>
              <span className="value">
                {client.birth_date
                  ? new Date(client.birth_date).toLocaleDateString('es-MX', {
                    year: 'numeric',
                    month: 'long',
                    day: 'numeric'
                  })
                  : 'N/A'
                }
              </span>
            </div>
          </div>
        </div>

        {/* Información de Contacto */}
        <div className="info-card">
          <div className="card-header">
            <h2>� Información de Contacto</h2>
          </div>
          <div className="info-grid">
            <div className="info-item">
              <span className="label">Email:</span>
              <span className="value">{client.email || 'N/A'}</span>
            </div>
            <div className="info-item">
              <span className="label">Teléfono:</span>
              <span className="value">{client.phone_number || 'N/A'}</span>
            </div>
            {client.profile_picture_url && (
              <div className="info-item">
                <span className="label">Foto de Perfil:</span>
                <img
                  src={client.profile_picture_url}
                  alt={client.full_name}
                  className="profile-picture"
                />
              </div>
            )}
          </div>
        </div>

        {/* Dirección - Solo si existe */}
        {client.address && (
          <div className="info-card">
            <div className="card-header">
              <h2>📍 Dirección</h2>
            </div>
            <div className="info-grid">
              <div className="info-item">
                <span className="label">Calle:</span>
                <span className="value">{client.address.street}</span>
              </div>
              <div className="info-item">
                <span className="label">Número Exterior:</span>
                <span className="value">{client.address.external_number}</span>
              </div>
              {client.address.internal_number && (
                <div className="info-item">
                  <span className="label">Número Interior:</span>
                  <span className="value">{client.address.internal_number}</span>
                </div>
              )}
              <div className="info-item">
                <span className="label">Colonia:</span>
                <span className="value">{client.address.colony}</span>
              </div>
              <div className="info-item">
                <span className="label">Municipio:</span>
                <span className="value">{client.address.municipality}</span>
              </div>
              <div className="info-item">
                <span className="label">Estado:</span>
                <span className="value">{client.address.state}</span>
              </div>
              <div className="info-item">
                <span className="label">Código Postal:</span>
                <span className="value">{client.address.zip_code}</span>
              </div>
            </div>
          </div>
        )}

        {/* Aval - Solo si existe */}
        {client.guarantor && (
          <div className="info-card">
            <div className="card-header">
              <h2>🤝 Información del Aval</h2>
            </div>
            <div className="info-grid">
              <div className="info-item">
                <span className="label">Nombre Completo:</span>
                <span className="value">{client.guarantor.full_name}</span>
              </div>
              <div className="info-item">
                <span className="label">Parentesco:</span>
                <span className="value">{client.guarantor.relationship}</span>
              </div>
              <div className="info-item">
                <span className="label">Teléfono:</span>
                <span className="value">{client.guarantor.phone_number}</span>
              </div>
              {client.guarantor.curp && (
                <div className="info-item">
                  <span className="label">CURP:</span>
                  <span className="value">{client.guarantor.curp}</span>
                </div>
              )}
            </div>
          </div>
        )}

        {/* Beneficiario - Solo si existe */}
        {client.beneficiary && (
          <div className="info-card">
            <div className="card-header">
              <h2>👨‍👩‍👧‍👦 Información del Beneficiario</h2>
            </div>
            <div className="info-grid">
              <div className="info-item">
                <span className="label">Nombre Completo:</span>
                <span className="value">{client.beneficiary.full_name}</span>
              </div>
              <div className="info-item">
                <span className="label">Parentesco:</span>
                <span className="value">{client.beneficiary.relationship}</span>
              </div>
              <div className="info-item">
                <span className="label">Teléfono:</span>
                <span className="value">{client.beneficiary.phone_number}</span>
              </div>
            </div>
          </div>
        )}

        {/* Historial de Auditoría - Quién creó y modificó el registro */}
        <AuditHistory
          tableName="users"
          recordId={client.id}
          title="Historial de Cambios del Cliente"
        />
      </div>
    </div>
  );
};

export default ClientDetailPage;
