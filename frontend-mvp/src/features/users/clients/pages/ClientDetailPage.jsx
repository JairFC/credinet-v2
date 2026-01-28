/**
 * ClientDetailPage - Vista detallada de un cliente (VERSIÓN MEJORADA)
 * 
 * Características:
 * - Secciones colapsables
 * - Campos editables con modo edición
 * - Auditoría automática de cambios
 * - Validaciones en tiempo real
 */

import { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { clientsService } from '../../../../shared/api/services/clientsService';
import { associatesService } from '../../../../shared/api/services/associatesService';
import apiClient from '../../../../shared/api/apiClient';
import AuditHistory from '../../../../shared/components/AuditHistory';
import PromoteRoleModal from '../../../../shared/components/PromoteRoleModal';
import SuccessNotification from '../../../../shared/components/SuccessNotification';
import './ClientDetailPage.css';

// Componente para sección colapsable y editable
const CollapsibleSection = ({ 
  title, 
  icon, 
  children, 
  defaultExpanded = true,
  isEditing = false,
  onEdit,
  onSave,
  onCancel,
  canEdit = true,
  saving = false
}) => {
  const [isExpanded, setIsExpanded] = useState(defaultExpanded);

  return (
    <div className={`info-card ${isExpanded ? 'expanded' : 'collapsed'}`}>
      <div 
        className="card-header clickable"
        onClick={() => !isEditing && setIsExpanded(!isExpanded)}
      >
        <div className="header-left-content">
          <span className="collapse-icon">{isExpanded ? '▼' : '▶'}</span>
          <h2>{icon} {title}</h2>
        </div>
        <div className="header-actions-inline">
          {canEdit && isExpanded && !isEditing && (
            <button 
              className="btn-edit"
              onClick={(e) => {
                e.stopPropagation();
                onEdit?.();
              }}
            >
              ✏️ Editar
            </button>
          )}
          {isEditing && (
            <>
              <button 
                className="btn-cancel"
                onClick={(e) => {
                  e.stopPropagation();
                  onCancel?.();
                }}
                disabled={saving}
              >
                ✕ Cancelar
              </button>
              <button 
                className="btn-save"
                onClick={(e) => {
                  e.stopPropagation();
                  onSave?.();
                }}
                disabled={saving}
              >
                {saving ? '⏳ Guardando...' : '💾 Guardar'}
              </button>
            </>
          )}
        </div>
      </div>
      {isExpanded && (
        <div className="card-content">
          {children}
        </div>
      )}
    </div>
  );
};

// Componente para campo editable
const EditableField = ({ 
  label, 
  value, 
  isEditing, 
  onChange, 
  type = 'text',
  options = null,
  placeholder = '',
  required = false,
  validation = null
}) => {
  const [error, setError] = useState('');

  const handleChange = (e) => {
    const newValue = e.target.value;
    if (validation) {
      const validationError = validation(newValue);
      setError(validationError || '');
    }
    onChange(newValue);
  };

  if (!isEditing) {
    return (
      <div className="info-item">
        <span className="label">{label}:</span>
        <span className="value">{value || 'N/A'}</span>
      </div>
    );
  }

  return (
    <div className="info-item editing">
      <label className="label">{label}{required && ' *'}:</label>
      {options ? (
        <select
          value={value || ''}
          onChange={handleChange}
          className={`edit-input ${error ? 'has-error' : ''}`}
        >
          <option value="">Seleccionar...</option>
          {options.map(opt => (
            <option key={opt.value} value={opt.value}>{opt.label}</option>
          ))}
        </select>
      ) : type === 'textarea' ? (
        <textarea
          value={value || ''}
          onChange={handleChange}
          className={`edit-input ${error ? 'has-error' : ''}`}
          placeholder={placeholder}
        />
      ) : (
        <input
          type={type}
          value={value || ''}
          onChange={handleChange}
          className={`edit-input ${error ? 'has-error' : ''}`}
          placeholder={placeholder}
        />
      )}
      {error && <span className="field-error">{error}</span>}
    </div>
  );
};

const ClientDetailPage = () => {
  const { clientId } = useParams();
  const navigate = useNavigate();
  const [client, setClient] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [showPromoteModal, setShowPromoteModal] = useState(false);
  const [userRoles, setUserRoles] = useState([]);

  // Estados de edición por sección
  const [editingSection, setEditingSection] = useState(null);
  const [editData, setEditData] = useState({});
  const [saving, setSaving] = useState(false);
  
  // Notificación de éxito
  const [showSuccess, setShowSuccess] = useState(false);
  const [successMessage, setSuccessMessage] = useState('');

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

  const startEditing = (section) => {
    setEditingSection(section);
    switch (section) {
      case 'personal':
        setEditData({
          first_name: client.first_name,
          last_name: client.last_name,
          curp: client.curp,
          birth_date: client.birth_date,
          gender: client.gender
        });
        break;
      case 'contact':
        setEditData({
          email: client.email,
          phone_number: client.phone_number
        });
        break;
      case 'address':
        setEditData({
          street: client.address?.street || '',
          external_number: client.address?.external_number || '',
          internal_number: client.address?.internal_number || '',
          colony: client.address?.colony || '',
          municipality: client.address?.municipality || '',
          state: client.address?.state || '',
          zip_code: client.address?.zip_code || ''
        });
        break;
      case 'guarantor':
        setEditData({
          guarantor_full_name: client.guarantor?.full_name || '',
          guarantor_relationship: client.guarantor?.relationship || '',
          guarantor_phone: client.guarantor?.phone_number || '',
          guarantor_curp: client.guarantor?.curp || ''
        });
        break;
      case 'beneficiary':
        setEditData({
          beneficiary_full_name: client.beneficiary?.full_name || '',
          beneficiary_relationship: client.beneficiary?.relationship || '',
          beneficiary_phone: client.beneficiary?.phone_number || ''
        });
        break;
      default:
        setEditData({});
    }
  };

  const cancelEditing = () => {
    setEditingSection(null);
    setEditData({});
  };

  const saveChanges = async () => {
    try {
      setSaving(true);
      
      let updatePayload = {};
      let endpoint = '';

      switch (editingSection) {
        case 'personal':
          endpoint = `/api/v1/clients/${clientId}`;
          updatePayload = {
            first_name: editData.first_name,
            last_name: editData.last_name,
            birth_date: editData.birth_date,
            curp: editData.curp
          };
          break;
        case 'contact':
          endpoint = `/api/v1/clients/${clientId}`;
          updatePayload = {
            email: editData.email,
            phone_number: editData.phone_number
          };
          break;
        case 'address':
          endpoint = `/api/v1/clients/${clientId}/address`;
          updatePayload = {
            street: editData.street,
            external_number: editData.external_number,
            internal_number: editData.internal_number,
            colony: editData.colony,
            municipality: editData.municipality,
            state: editData.state,
            zip_code: editData.zip_code
          };
          break;
        case 'guarantor':
          endpoint = `/api/v1/clients/${clientId}/guarantor`;
          updatePayload = {
            full_name: editData.guarantor_full_name,
            relationship: editData.guarantor_relationship,
            phone_number: editData.guarantor_phone,
            curp: editData.guarantor_curp
          };
          break;
        case 'beneficiary':
          endpoint = `/api/v1/clients/${clientId}/beneficiary`;
          updatePayload = {
            full_name: editData.beneficiary_full_name,
            relationship: editData.beneficiary_relationship,
            phone_number: editData.beneficiary_phone
          };
          break;
        default:
          throw new Error('Sección no reconocida');
      }

      // Limpiar valores vacíos del payload
      Object.keys(updatePayload).forEach(key => {
        if (updatePayload[key] === '' || updatePayload[key] === null || updatePayload[key] === undefined) {
          delete updatePayload[key];
        }
      });

      await apiClient.patch(endpoint, updatePayload);
      
      setSuccessMessage(`Datos de ${getSectionName(editingSection)} actualizados correctamente`);
      setShowSuccess(true);
      setEditingSection(null);
      await fetchClientData();
      
    } catch (err) {
      console.error('Error saving changes:', err);
      // Mostrar mensaje más descriptivo según el error
      if (err.response?.status === 404 || err.response?.status === 405) {
        setError(`La funcionalidad de edición de ${getSectionName(editingSection)} aún no está disponible en el servidor.`);
      } else {
        setError(err.response?.data?.detail || 'Error al guardar cambios');
      }
    } finally {
      setSaving(false);
    }
  };

  const getSectionName = (section) => {
    const names = {
      personal: 'Información Personal',
      contact: 'Contacto',
      address: 'Dirección',
      guarantor: 'Aval',
      beneficiary: 'Beneficiario'
    };
    return names[section] || section;
  };

  const updateEditData = (field, value) => {
    setEditData(prev => ({ ...prev, [field]: value }));
  };

  const isAlsoAssociate = userRoles.some(r => r.role_id === 4 || r.role_name?.toLowerCase() === 'asociado');

  const handlePromoteSuccess = () => {
    fetchClientData();
  };

  const formatDate = (dateString) => {
    if (!dateString) return 'N/A';
    return new Date(dateString).toLocaleDateString('es-MX', {
      year: 'numeric',
      month: 'long',
      day: 'numeric'
    });
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

  if (error && !client) {
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
      {/* Notificación de éxito */}
      <SuccessNotification
        isOpen={showSuccess}
        onClose={() => setShowSuccess(false)}
        title="¡Cambios guardados!"
        message={successMessage}
        icon="✅"
        duration={3000}
      />

      {/* Header */}
      <div className="page-header">
        <div className="header-left">
          <h1>👤 {client.full_name || `${client.first_name} ${client.last_name}`}</h1>
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

      {/* Error de guardado */}
      {error && (
        <div className="error-banner save-error">
          <span>⚠️ {error}</span>
          <button onClick={() => setError('')}>✕</button>
        </div>
      )}

      <div className="detail-container">
        {/* Información Personal */}
        <CollapsibleSection
          title="Información Personal"
          icon="👤"
          defaultExpanded={true}
          isEditing={editingSection === 'personal'}
          onEdit={() => startEditing('personal')}
          onSave={saveChanges}
          onCancel={cancelEditing}
          saving={saving}
        >
          <div className="info-grid">
            <EditableField
              label="Nombre(s)"
              value={editingSection === 'personal' ? editData.first_name : client.first_name}
              isEditing={editingSection === 'personal'}
              onChange={(v) => updateEditData('first_name', v)}
              required
            />
            <EditableField
              label="Apellidos"
              value={editingSection === 'personal' ? editData.last_name : client.last_name}
              isEditing={editingSection === 'personal'}
              onChange={(v) => updateEditData('last_name', v)}
              required
            />
            <EditableField
              label="Usuario"
              value={client.username}
              isEditing={false}
            />
            <EditableField
              label="CURP"
              value={editingSection === 'personal' ? editData.curp : client.curp}
              isEditing={editingSection === 'personal'}
              onChange={(v) => updateEditData('curp', v.toUpperCase())}
              validation={(v) => v && v.length !== 18 ? 'CURP debe tener 18 caracteres' : ''}
            />
            <EditableField
              label="Fecha de Nacimiento"
              value={editingSection === 'personal' ? editData.birth_date : formatDate(client.birth_date)}
              isEditing={editingSection === 'personal'}
              onChange={(v) => updateEditData('birth_date', v)}
              type="date"
            />
          </div>
        </CollapsibleSection>

        {/* Información de Contacto */}
        <CollapsibleSection
          title="Información de Contacto"
          icon="📞"
          defaultExpanded={true}
          isEditing={editingSection === 'contact'}
          onEdit={() => startEditing('contact')}
          onSave={saveChanges}
          onCancel={cancelEditing}
          saving={saving}
        >
          <div className="info-grid">
            <EditableField
              label="Email"
              value={editingSection === 'contact' ? editData.email : client.email}
              isEditing={editingSection === 'contact'}
              onChange={(v) => updateEditData('email', v)}
              type="email"
            />
            <EditableField
              label="Teléfono"
              value={editingSection === 'contact' ? editData.phone_number : client.phone_number}
              isEditing={editingSection === 'contact'}
              onChange={(v) => updateEditData('phone_number', v.replace(/\D/g, '').slice(0, 10))}
              validation={(v) => v && v.length !== 10 ? 'Teléfono debe tener 10 dígitos' : ''}
            />
          </div>
        </CollapsibleSection>

        {/* Dirección */}
        <CollapsibleSection
          title="Dirección"
          icon="📍"
          defaultExpanded={!!client.address}
          isEditing={editingSection === 'address'}
          onEdit={() => startEditing('address')}
          onSave={saveChanges}
          onCancel={cancelEditing}
          saving={saving}
          canEdit={!!client.address}
        >
          {client.address ? (
            <div className="info-grid">
              <EditableField
                label="Calle"
                value={editingSection === 'address' ? editData.street : client.address.street}
                isEditing={editingSection === 'address'}
                onChange={(v) => updateEditData('street', v)}
              />
              <EditableField
                label="Número Exterior"
                value={editingSection === 'address' ? editData.external_number : client.address.external_number}
                isEditing={editingSection === 'address'}
                onChange={(v) => updateEditData('external_number', v)}
              />
              <EditableField
                label="Número Interior"
                value={editingSection === 'address' ? editData.internal_number : client.address.internal_number}
                isEditing={editingSection === 'address'}
                onChange={(v) => updateEditData('internal_number', v)}
              />
              <EditableField
                label="Colonia"
                value={editingSection === 'address' ? editData.colony : client.address.colony}
                isEditing={editingSection === 'address'}
                onChange={(v) => updateEditData('colony', v)}
              />
              <EditableField
                label="Municipio"
                value={editingSection === 'address' ? editData.municipality : client.address.municipality}
                isEditing={editingSection === 'address'}
                onChange={(v) => updateEditData('municipality', v)}
              />
              <EditableField
                label="Estado"
                value={editingSection === 'address' ? editData.state : client.address.state}
                isEditing={editingSection === 'address'}
                onChange={(v) => updateEditData('state', v)}
              />
              <EditableField
                label="Código Postal"
                value={editingSection === 'address' ? editData.zip_code : client.address.zip_code}
                isEditing={editingSection === 'address'}
                onChange={(v) => updateEditData('zip_code', v.replace(/\D/g, '').slice(0, 5))}
              />
            </div>
          ) : (
            <p className="no-data-text">📭 No hay dirección registrada</p>
          )}
        </CollapsibleSection>

        {/* Aval */}
        <CollapsibleSection
          title="Información del Aval"
          icon="🤝"
          defaultExpanded={!!client.guarantor}
          isEditing={editingSection === 'guarantor'}
          onEdit={() => startEditing('guarantor')}
          onSave={saveChanges}
          onCancel={cancelEditing}
          saving={saving}
          canEdit={!!client.guarantor}
        >
          {client.guarantor ? (
            <div className="info-grid">
              <EditableField
                label="Nombre Completo"
                value={editingSection === 'guarantor' ? editData.guarantor_full_name : client.guarantor.full_name}
                isEditing={editingSection === 'guarantor'}
                onChange={(v) => updateEditData('guarantor_full_name', v)}
              />
              <EditableField
                label="Parentesco"
                value={editingSection === 'guarantor' ? editData.guarantor_relationship : client.guarantor.relationship}
                isEditing={editingSection === 'guarantor'}
                onChange={(v) => updateEditData('guarantor_relationship', v)}
              />
              <EditableField
                label="Teléfono"
                value={editingSection === 'guarantor' ? editData.guarantor_phone : client.guarantor.phone_number}
                isEditing={editingSection === 'guarantor'}
                onChange={(v) => updateEditData('guarantor_phone', v.replace(/\D/g, '').slice(0, 10))}
              />
              <EditableField
                label="CURP"
                value={editingSection === 'guarantor' ? editData.guarantor_curp : client.guarantor.curp}
                isEditing={editingSection === 'guarantor'}
                onChange={(v) => updateEditData('guarantor_curp', v.toUpperCase())}
              />
            </div>
          ) : (
            <p className="no-data-text">📭 No hay aval registrado</p>
          )}
        </CollapsibleSection>

        {/* Beneficiario */}
        <CollapsibleSection
          title="Información del Beneficiario"
          icon="👨‍👩‍👧‍👦"
          defaultExpanded={!!client.beneficiary}
          isEditing={editingSection === 'beneficiary'}
          onEdit={() => startEditing('beneficiary')}
          onSave={saveChanges}
          onCancel={cancelEditing}
          saving={saving}
          canEdit={!!client.beneficiary}
        >
          {client.beneficiary ? (
            <div className="info-grid">
              <EditableField
                label="Nombre Completo"
                value={editingSection === 'beneficiary' ? editData.beneficiary_full_name : client.beneficiary.full_name}
                isEditing={editingSection === 'beneficiary'}
                onChange={(v) => updateEditData('beneficiary_full_name', v)}
              />
              <EditableField
                label="Parentesco"
                value={editingSection === 'beneficiary' ? editData.beneficiary_relationship : client.beneficiary.relationship}
                isEditing={editingSection === 'beneficiary'}
                onChange={(v) => updateEditData('beneficiary_relationship', v)}
              />
              <EditableField
                label="Teléfono"
                value={editingSection === 'beneficiary' ? editData.beneficiary_phone : client.beneficiary.phone_number}
                isEditing={editingSection === 'beneficiary'}
                onChange={(v) => updateEditData('beneficiary_phone', v.replace(/\D/g, '').slice(0, 10))}
              />
            </div>
          ) : (
            <p className="no-data-text">📭 No hay beneficiario registrado</p>
          )}
        </CollapsibleSection>

        {/* Historial de Auditoría */}
        <CollapsibleSection
          title="Historial de Cambios"
          icon="📜"
          defaultExpanded={false}
          canEdit={false}
        >
          <AuditHistory
            tableName="users"
            recordId={client.id}
            title=""
          />
        </CollapsibleSection>
      </div>
    </div>
  );
};

export default ClientDetailPage;
