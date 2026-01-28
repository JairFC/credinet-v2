/**
 * AuditHistory - Componente para mostrar historial de auditoría de un registro
 * 
 * Muestra quién creó, modificó y el historial de cambios de un registro específico
 * 
 * Props:
 * - tableName: tabla principal (ej: 'users')
 * - recordId: ID del registro
 * - includeRelated: si es true y tableName='users', incluye addresses, guarantors, beneficiaries
 * - title: título del componente
 */
import { useState, useEffect } from 'react';
import { apiClient } from '../api/apiClient';
import { formatDateTime, formatDateOnly } from '../utils/dateUtils';
import './AuditHistory.css';

const AuditHistory = ({ tableName, recordId, includeRelated = false, title = 'Historial de Cambios' }) => {
  const [history, setHistory] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [isExpanded, setIsExpanded] = useState(false);
  const [userCache, setUserCache] = useState({});

  useEffect(() => {
    if (tableName && recordId) {
      fetchAuditHistory();
    }
  }, [tableName, recordId, includeRelated]);

  const fetchAuditHistory = async () => {
    try {
      setLoading(true);
      setError('');
      
      let logs = [];
      
      // Si es users y queremos incluir tablas relacionadas, usar el endpoint especial
      if (tableName === 'users' && includeRelated) {
        const response = await apiClient.get(`/api/v1/audit/users/${recordId}/full-history`);
        logs = response.data || [];
      } else {
        const response = await apiClient.get(`/api/v1/audit/records/${tableName}/${recordId}`);
        logs = response.data || [];
      }
      
      setHistory(logs);

      // Extraer nombres de usuarios de new_data._changed_by_name (agregado por backend)
      const cache = { ...userCache };
      for (const log of logs) {
        if (log.changed_by && log.new_data?._changed_by_name) {
          cache[log.changed_by] = log.new_data._changed_by_name;
        }
      }
      setUserCache(cache);
    } catch (err) {
      console.error('Error fetching audit history:', err);
      // No mostrar error si simplemente no hay historial
      if (err.response?.status !== 404) {
        setError('No se pudo cargar el historial');
      }
    } finally {
      setLoading(false);
    }
  };

  const formatDate = (dateString) => {
    if (!dateString) return 'N/A';
    // Usar formatDateTime para timestamps de auditoría (zona Chihuahua)
    return formatDateTime(dateString, { includeTime: true });
  };

  const getOperationLabel = (operation, log) => {
    // Para cambios de roles, mostrar descripción más específica
    if (log?.new_data?.action) {
      switch (log.new_data.action) {
        case 'promote_to_associate':
          return { label: 'Promovido a Asociado', icon: '🎯', class: 'op-insert' };
        case 'add_client_role':
          return { label: 'Rol Cliente Agregado', icon: '👤', class: 'op-insert' };
      }
    }
    
    switch (operation) {
      case 'INSERT': return { label: 'Creación', icon: '✨', class: 'op-insert' };
      case 'UPDATE': return { label: 'Modificación', icon: '✏️', class: 'op-update' };
      case 'DELETE': return { label: 'Eliminación', icon: '🗑️', class: 'op-delete' };
      default: return { label: operation, icon: '📝', class: '' };
    }
  };

  // Traducir nombres de tablas a español
  const getTableLabel = (tableName) => {
    const tableLabels = {
      'users': 'Datos personales',
      'addresses': 'Dirección',
      'guarantors': 'Aval',
      'beneficiaries': 'Beneficiario',
      'loans': 'Préstamo',
      'payments': 'Pago',
      'associates': 'Asociado',
      'associate_profiles': 'Perfil de asociado'
    };
    return tableLabels[tableName] || tableName;
  };

  const getActionDescription = (log) => {
    if (!log.new_data) return null;
    
    const data = log.new_data;
    
    // Descripción para cambios de roles
    if (data.action === 'promote_to_associate') {
      return `Se le asignó el rol de Asociado`;
    }
    if (data.action === 'add_client_role') {
      return `Se le agregó el rol de Cliente`;
    }
    if (data.promoted_from_client) {
      return `Promovido desde Cliente - Nivel ${data.level_id}, Límite $${data.credit_limit?.toLocaleString('es-MX')}`;
    }
    
    return null;
  };

  const getChangedFieldsDisplay = (log) => {
    if (!log.changed_fields || log.changed_fields.length === 0) {
      return null;
    }

    // Traducir nombres de campos comunes
    const fieldTranslations = {
      'first_name': 'Nombre',
      'last_name': 'Apellido',
      'email': 'Email',
      'phone_number': 'Teléfono',
      'curp': 'CURP',
      'birth_date': 'Fecha de nacimiento',
      'active': 'Estado activo',
      'password_hash': 'Contraseña',
      'profile_picture_url': 'Foto de perfil',
      'username': 'Usuario',
      'credit_limit': 'Límite de crédito',
      'level_id': 'Nivel',
      'default_commission_rate': 'Comisión',
      'street': 'Calle',
      'external_number': 'Número exterior',
      'internal_number': 'Número interior',
      'colony': 'Colonia',
      'municipality': 'Municipio',
      'state': 'Estado',
      'zip_code': 'Código postal',
      'full_name': 'Nombre completo',
      'relationship': 'Parentesco',
      'updated_at': null // Ocultar este campo
    };

    return log.changed_fields
      .filter(field => fieldTranslations[field] !== null && field !== 'updated_at')
      .map(field => fieldTranslations[field] || field);
  };

  // Obtener los cambios detallados con valores anteriores y nuevos
  const getDetailedChanges = (log) => {
    if (!log.changed_fields || !log.old_data || !log.new_data) {
      return [];
    }

    const fieldTranslations = {
      'first_name': 'Nombre',
      'last_name': 'Apellido',
      'email': 'Email',
      'phone_number': 'Teléfono',
      'curp': 'CURP',
      'birth_date': 'Fecha de nacimiento',
      'active': 'Estado activo',
      'username': 'Usuario',
      'credit_limit': 'Límite de crédito',
      'level_id': 'Nivel',
      'default_commission_rate': 'Comisión',
      'street': 'Calle',
      'external_number': 'Número exterior',
      'internal_number': 'Número interior',
      'colony': 'Colonia',
      'municipality': 'Municipio',
      'state': 'Estado',
      'zip_code': 'Código postal',
      'full_name': 'Nombre completo',
      'relationship': 'Parentesco'
    };

    // Campos a ignorar (no mostrar cambios de estos)
    const ignoredFields = ['updated_at', 'password_hash', 'profile_picture_url', '_changed_by_name'];

    return log.changed_fields
      .filter(field => !ignoredFields.includes(field))
      .map(field => {
        const oldValue = log.old_data[field];
        const newValue = log.new_data[field];
        const fieldName = fieldTranslations[field] || field;

        // Formatear valores especiales
        const formatValue = (value) => {
          if (value === null || value === undefined || value === '') return '(vacío)';
          if (typeof value === 'boolean') return value ? 'Sí' : 'No';
          if (field === 'birth_date' && value) {
            // Usar formatDateOnly para evitar offset de timezone
            return formatDateOnly(value);
          }
          if (field === 'credit_limit' && typeof value === 'number') {
            return `$${value.toLocaleString('es-MX')}`;
          }
          return String(value);
        };

        return {
          field: fieldName,
          oldValue: formatValue(oldValue),
          newValue: formatValue(newValue)
        };
      });
  };

  // Encontrar el registro de creación
  const creationLog = history.find(log => log.operation === 'INSERT');
  const updateLogs = history.filter(log => log.operation === 'UPDATE');

  if (loading) {
    return (
      <div className="audit-history-card">
        <div className="audit-header">
          <h3>📜 {title}</h3>
        </div>
        <div className="audit-loading">⏳ Cargando historial...</div>
      </div>
    );
  }

  return (
    <div className="audit-history-card">
      <div className="audit-header">
        <h3>📜 {title}</h3>
        {updateLogs.length > 0 && (
          <button
            className="btn-toggle-history"
            onClick={() => setIsExpanded(!isExpanded)}
          >
            {isExpanded ? '▼ Ocultar historial' : `▶ Ver historial (${updateLogs.length} cambios)`}
          </button>
        )}
      </div>

      <div className="audit-content">
        {/* Información de creación */}
        <div className="audit-creation-info">
          <div className="audit-info-row">
            <span className="audit-label">✨ Creado:</span>
            <span className="audit-value">
              {creationLog ? (
                <>
                  {formatDate(creationLog.changed_at)}
                  <span className="audit-by"> por <strong>
                    {creationLog.changed_by 
                      ? (userCache[creationLog.changed_by] || `Usuario #${creationLog.changed_by}`)
                      : 'Sistema (Auto-registro)'}
                  </strong></span>
                  {getActionDescription(creationLog) && (
                    <div className="audit-description">{getActionDescription(creationLog)}</div>
                  )}
                </>
              ) : (
                <span className="audit-no-data">Sin información de creación</span>
              )}
            </span>
          </div>

          {updateLogs.length > 0 && (
            <div className="audit-info-row">
              <span className="audit-label">✏️ Última modificación:</span>
              <span className="audit-value">
                {formatDate(updateLogs[0].changed_at)}
                {updateLogs[0].changed_by && (
                  <span className="audit-by"> por <strong>{userCache[updateLogs[0].changed_by] || `Usuario #${updateLogs[0].changed_by}`}</strong></span>
                )}
              </span>
            </div>
          )}
        </div>

        {/* Mostrar todos los registros de INSERT (para roles pueden haber varios) */}
        {history.filter(log => log.operation === 'INSERT').length > 1 && (
          <div className="audit-timeline">
            <h4>📋 Eventos registrados</h4>
            {history.filter(log => log.operation === 'INSERT').map((log, index) => {
              const opInfo = getOperationLabel(log.operation, log);
              const description = getActionDescription(log);

              return (
                <div key={log.id || index} className={`audit-timeline-item ${opInfo.class}`}>
                  <div className="timeline-marker">{opInfo.icon}</div>
                  <div className="timeline-content">
                    <div className="timeline-header">
                      <span className="timeline-operation">{opInfo.label}</span>
                      <span className="timeline-date">{formatDate(log.changed_at)}</span>
                    </div>
                    {log.changed_by && (
                      <div className="timeline-user">
                        Por: <strong>{userCache[log.changed_by] || `Usuario #${log.changed_by}`}</strong>
                      </div>
                    )}
                    {description && (
                      <div className="timeline-description">{description}</div>
                    )}
                  </div>
                </div>
              );
            })}
          </div>
        )}

        {/* Historial expandible de UPDATEs */}
        {isExpanded && updateLogs.length > 0 && (
          <div className="audit-timeline">
            <h4>📋 Historial de modificaciones</h4>
            {updateLogs.map((log, index) => {
              const opInfo = getOperationLabel(log.operation, log);
              const detailedChanges = getDetailedChanges(log);
              const sectionLabel = getTableLabel(log.table_name);

              return (
                <div key={log.id || index} className={`audit-timeline-item ${opInfo.class}`}>
                  <div className="timeline-marker">{opInfo.icon}</div>
                  <div className="timeline-content">
                    <div className="timeline-header">
                      <span className="timeline-operation">
                        {opInfo.label}
                        {sectionLabel && <span className="timeline-section"> • {sectionLabel}</span>}
                      </span>
                      <span className="timeline-date">{formatDate(log.changed_at)}</span>
                    </div>
                    {log.changed_by && (
                      <div className="timeline-user">
                        Por: {userCache[log.changed_by] || `Usuario #${log.changed_by}`}
                      </div>
                    )}
                    {detailedChanges.length > 0 && (
                      <div className="timeline-changes">
                        {detailedChanges.map((change, idx) => (
                          <div key={idx} className="change-detail">
                            <span className="change-field">{change.field}:</span>
                            <span className="change-old">{change.oldValue}</span>
                            <span className="change-arrow">→</span>
                            <span className="change-new">{change.newValue}</span>
                          </div>
                        ))}
                      </div>
                    )}
                  </div>
                </div>
              );
            })}
          </div>
        )}

        {error && <div className="audit-error">⚠️ {error}</div>}

        {!loading && history.length === 0 && !error && (
          <div className="audit-empty">
            📭 No hay historial de cambios registrado
          </div>
        )}
      </div>
    </div>
  );
};

export default AuditHistory;
