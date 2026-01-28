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
import { lookupZipCode } from '../../../../shared/api/services/zipCodeService';
import apiClient from '../../../../shared/api/apiClient';
import AuditHistory from '../../../../shared/components/AuditHistory';
import PromoteRoleModal from '../../../../shared/components/PromoteRoleModal';
import SuccessNotification from '../../../../shared/components/SuccessNotification';
import { formatDateOnly, formatDateTime } from '../../../../shared/utils/dateUtils';
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
  
  // Catálogos
  const [relationships, setRelationships] = useState([]);
  const [colonies, setColonies] = useState([]);
  const [zipLoading, setZipLoading] = useState(false);
  const [zipError, setZipError] = useState('');

  useEffect(() => {
    if (clientId) {
      fetchClientData();
      fetchCatalogs();
    }
  }, [clientId]);
  
  // Cargar catálogo de parentesco
  const fetchCatalogs = async () => {
    try {
      const response = await fetch(`${import.meta.env.VITE_API_URL}/api/v1/shared/relationships`);
      if (response.ok) {
        const data = await response.json();
        setRelationships(data.data || []);
      }
    } catch (err) {
      console.error('Error fetching relationships:', err);
    }
  };
  
  // Buscar colonias cuando cambia el código postal
  const handleZipCodeChange = async (zipCode) => {
    updateEditData('zip_code', zipCode);
    
    if (zipCode.length !== 5) {
      setColonies([]);
      setZipError('');
      return;
    }
    
    setZipLoading(true);
    setZipError('');
    
    try {
      const result = await lookupZipCode(zipCode);
      
      if (result?.error) {
        setZipError(result.message);
        setColonies([]);
      } else if (result?.success) {
        // Auto-completar municipio y estado
        updateEditData('municipality', result.municipality);
        updateEditData('state', result.state);
        setColonies(result.colonies || []);
        
        // Si solo hay una colonia, seleccionarla automáticamente
        if (result.colonies?.length === 1) {
          updateEditData('colony', result.colonies[0]);
        }
      }
    } catch (err) {
      setZipError('Error al buscar código postal');
      setColonies([]);
    } finally {
      setZipLoading(false);
    }
  };

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
          console.log('🔍 Roles response:', rolesRes.data);
          // La API devuelve { success: true, data: { roles: [...] } }
          setUserRoles(rolesRes.data?.data?.roles || rolesRes.data?.roles || []);
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
        // Cargar colonias del CP existente
        if (client.address?.zip_code?.length === 5) {
          lookupZipCode(client.address.zip_code).then(result => {
            if (result?.success) {
              setColonies(result.colonies || []);
            }
          });
        }
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

  // ⭐ Usar formatDateOnly del módulo centralizado para fechas de solo día (birth_date)
  // formatDateTime se usa para timestamps con hora (created_at, updated_at)
  const formatDate = formatDateOnly;

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

      {/* Header - Similar al de AssociateDetailPage */}
      <div className="page-header">
        <div className="header-left">
          <h1>{client.full_name || `${client.first_name} ${client.last_name}`}</h1>
          <div className="header-meta">
            <span className={`status-badge ${client.active ? 'active' : 'inactive'}`}>
              {client.active ? '● Activo' : '○ Inactivo'}
            </span>
            <span className="client-id">ID: #{client.id}</span>
            {client.username && <span className="username">@{client.username}</span>}
            {isAlsoAssociate && (
              <span className="role-badge associate">También es Asociado</span>
            )}
          </div>
        </div>
        <div className="header-actions">
          <button
            className="btn btn-promote"
            onClick={() => setShowPromoteModal(true)}
            disabled={isAlsoAssociate}
            title={isAlsoAssociate ? 'Este cliente ya es asociado' : 'Convertir a asociado'}
          >
            {isAlsoAssociate ? '✓ Ya es Asociado' : '🎯 Hacer Asociado'}
          </button>
          <button
            className="btn btn-secondary"
            onClick={() => navigate('/usuarios/clientes')}
          >
            ← Volver
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
              {/* Código Postal con búsqueda automática */}
              <div className="info-item editing">
                <label className="label">Código Postal:</label>
                {editingSection === 'address' ? (
                  <div className="zip-code-field">
                    <input
                      type="text"
                      value={editData.zip_code || ''}
                      onChange={(e) => handleZipCodeChange(e.target.value.replace(/\D/g, '').slice(0, 5))}
                      className={`edit-input ${zipError ? 'has-error' : ''}`}
                      placeholder="12345"
                      maxLength={5}
                    />
                    {zipLoading && <span className="zip-loading">⏳</span>}
                    {zipError && <span className="field-error">{zipError}</span>}
                  </div>
                ) : (
                  <span className="value">{client.address.zip_code || 'N/A'}</span>
                )}
              </div>

              {/* Colonia - Desplegable cuando hay colonias disponibles */}
              <div className="info-item editing">
                <label className="label">Colonia:</label>
                {editingSection === 'address' ? (
                  colonies.length > 0 ? (
                    <select
                      value={editData.colony || ''}
                      onChange={(e) => updateEditData('colony', e.target.value)}
                      className="edit-input"
                    >
                      <option value="">Seleccionar colonia...</option>
                      {colonies.map((col, idx) => (
                        <option key={idx} value={col}>{col}</option>
                      ))}
                    </select>
                  ) : (
                    <input
                      type="text"
                      value={editData.colony || ''}
                      onChange={(e) => updateEditData('colony', e.target.value)}
                      className="edit-input"
                      placeholder="Ingrese CP para ver colonias"
                    />
                  )
                ) : (
                  <span className="value">{client.address.colony || 'N/A'}</span>
                )}
              </div>

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
              {/* Parentesco - Desplegable con catálogo */}
              <div className="info-item editing">
                <label className="label">Parentesco:</label>
                {editingSection === 'guarantor' ? (
                  <select
                    value={editData.guarantor_relationship || ''}
                    onChange={(e) => updateEditData('guarantor_relationship', e.target.value)}
                    className="edit-input"
                  >
                    <option value="">Seleccionar parentesco...</option>
                    {relationships.map((rel) => (
                      <option key={rel.id} value={rel.name}>{rel.name}</option>
                    ))}
                  </select>
                ) : (
                  <span className="value">{client.guarantor.relationship || 'N/A'}</span>
                )}
              </div>
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
              {/* Parentesco - Desplegable con catálogo */}
              <div className="info-item editing">
                <label className="label">Parentesco:</label>
                {editingSection === 'beneficiary' ? (
                  <select
                    value={editData.beneficiary_relationship || ''}
                    onChange={(e) => updateEditData('beneficiary_relationship', e.target.value)}
                    className="edit-input"
                  >
                    <option value="">Seleccionar parentesco...</option>
                    {relationships.map((rel) => (
                      <option key={rel.id} value={rel.name}>{rel.name}</option>
                    ))}
                  </select>
                ) : (
                  <span className="value">{client.beneficiary.relationship || 'N/A'}</span>
                )}
              </div>
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
            includeRelated={true}
            title=""
          />
        </CollapsibleSection>
      </div>
    </div>
  );
};

export default ClientDetailPage;
