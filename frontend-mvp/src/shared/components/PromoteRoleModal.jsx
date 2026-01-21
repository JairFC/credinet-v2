/**
 * PromoteRoleModal - Modal para promocionar usuarios entre roles
 * 
 * Soporta:
 * - Cliente → Asociado (requiere seleccionar nivel)
 * - Asociado → Cliente (solo confirmación)
 * 
 * Features:
 * - Maneja casos donde el usuario ya tiene el rol
 * - Muestra mensaje apropiado según el resultado
 * - Registra auditoría en backend
 */
import { useState } from 'react';
import { associatesService } from '../api/services/associatesService';
import './PromoteRoleModal.css';

const ASSOCIATE_LEVELS = [
  { id: 1, name: 'Bronce', credit_limit: 25000 },
  { id: 2, name: 'Plata', credit_limit: 300000 },
  { id: 3, name: 'Oro', credit_limit: 600000 },
  { id: 4, name: 'Platino', credit_limit: 900000 },
  { id: 5, name: 'Diamante', credit_limit: 5000000 },
];

export default function PromoteRoleModal({ 
  isOpen, 
  onClose, 
  user, 
  promotionType, // 'to-associate' | 'to-client'
  onSuccess 
}) {
  const [selectedLevel, setSelectedLevel] = useState('2'); // Plata por defecto
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [successMessage, setSuccessMessage] = useState('');
  const [alreadyHasRole, setAlreadyHasRole] = useState(false);

  if (!isOpen || !user) return null;

  const handlePromote = async () => {
    setLoading(true);
    setError('');
    setSuccessMessage('');

    try {
      let response;
      if (promotionType === 'to-associate') {
        // Promover cliente a asociado
        response = await associatesService.promoteToAssociate(user.user_id || user.id, {
          level_id: parseInt(selectedLevel)
        });
      } else {
        // Agregar rol de cliente a asociado
        response = await associatesService.addClientRole(user.user_id || user.id);
      }

      const data = response.data || response;
      
      // Verificar si ya tenía el rol
      if (data.data?.already_associate || data.data?.already_client || data.data?.role_added === false) {
        setAlreadyHasRole(true);
        setSuccessMessage(data.message || 'El usuario ya tiene este rol');
        // Igual llamar onSuccess para actualizar la UI
        setTimeout(() => {
          onSuccess?.();
          onClose();
        }, 1500);
      } else {
        setSuccessMessage(data.message || '¡Rol asignado exitosamente!');
        setTimeout(() => {
          onSuccess?.();
          onClose();
        }, 1000);
      }
    } catch (err) {
      console.error('Error promoting user:', err);
      const message = err.response?.data?.detail || err.message || 'Error al cambiar rol';
      setError(message);
    } finally {
      setLoading(false);
    }
  };

  const selectedLevelData = ASSOCIATE_LEVELS.find(l => l.id === parseInt(selectedLevel));

  // Reset state when modal opens
  const handleClose = () => {
    setError('');
    setSuccessMessage('');
    setAlreadyHasRole(false);
    onClose();
  };

  return (
    <div className="promote-modal-overlay" onClick={handleClose}>
      <div className="promote-modal" onClick={e => e.stopPropagation()}>
        <div className="promote-modal-header">
          <h2>
            {promotionType === 'to-associate' 
              ? '🎯 Promover a Asociado' 
              : '👤 Agregar Rol de Cliente'}
          </h2>
          <button className="close-btn" onClick={handleClose}>×</button>
        </div>

        <div className="promote-modal-body">
          {/* Info del usuario */}
          <div className="user-info-card">
            <div className="user-avatar">
              {(user.first_name?.[0] || user.full_name?.[0] || 'U').toUpperCase()}
            </div>
            <div className="user-details">
              <h3>{user.full_name || \`\${user.first_name} \${user.paternal_last_name || user.last_name || ''}\`}</h3>
              <span className="user-email">{user.email}</span>
              {user.username && <span className="user-username">@{user.username}</span>}
            </div>
          </div>

          {/* Mensajes de estado */}
          {error && (
            <div className="error-alert">
              ⚠️ {error}
            </div>
          )}

          {successMessage && (
            <div className={\`success-alert \${alreadyHasRole ? 'info' : ''}\`}>
              {alreadyHasRole ? 'ℹ️' : '✅'} {successMessage}
            </div>
          )}

          {!successMessage && (
            <>
              {promotionType === 'to-associate' ? (
                <>
                  <div className="info-message">
                    <span className="info-icon">ℹ️</span>
                    <p>
                      Este cliente será promovido a <strong>Asociado</strong>. 
                      Mantendrá su historial como cliente y ahora también podrá otorgar préstamos.
                    </p>
                  </div>

                  <div className="form-group">
                    <label htmlFor="level">Selecciona el nivel de asociado:</label>
                    <select 
                      id="level"
                      value={selectedLevel}
                      onChange={(e) => setSelectedLevel(e.target.value)}
                      className="level-select"
                      disabled={loading}
                    >
                      {ASSOCIATE_LEVELS.map(level => (
                        <option key={level.id} value={level.id}>
                          {level.name} - Hasta \${level.credit_limit.toLocaleString('es-MX')}
                        </option>
                      ))}
                    </select>
                  </div>

                  {selectedLevelData && (
                    <div className="level-preview">
                      <div className="level-badge" data-level={selectedLevelData.name.toLowerCase()}>
                        {selectedLevelData.name.toUpperCase()}
                      </div>
                      <div className="level-info">
                        <span>Límite de crédito:</span>
                        <strong>\${selectedLevelData.credit_limit.toLocaleString('es-MX')}</strong>
                      </div>
                    </div>
                  )}
                </>
              ) : (
                <div className="info-message">
                  <span className="info-icon">ℹ️</span>
                  <p>
                    Este asociado también obtendrá el rol de <strong>Cliente</strong>.
                    Podrá solicitar préstamos de otros asociados mientras mantiene su capacidad de otorgar préstamos.
                  </p>
                </div>
              )}
            </>
          )}
        </div>

        <div className="promote-modal-footer">
          <button 
            className="btn-cancel" 
            onClick={handleClose}
            disabled={loading}
          >
            {successMessage ? 'Cerrar' : 'Cancelar'}
          </button>
          {!successMessage && (
            <button 
              className="btn-confirm"
              onClick={handlePromote}
              disabled={loading}
            >
              {loading ? (
                <>⏳ Procesando...</>
              ) : promotionType === 'to-associate' ? (
                <>✅ Promover a Asociado</>
              ) : (
                <>✅ Agregar Rol Cliente</>
              )}
            </button>
          )}
        </div>
      </div>
    </div>
  );
}
