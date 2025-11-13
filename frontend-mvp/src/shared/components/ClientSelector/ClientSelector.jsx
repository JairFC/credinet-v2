import PropTypes from 'prop-types';
import SearchableSelect from '../SearchableSelect/SearchableSelect';
import { apiClient } from '../../api/apiClient';
import './ClientSelector.css';

/**
 * Selector de clientes elegibles para préstamos
 * 
 * Características:
 * - Solo clientes activos
 * - Filtra clientes morosos
 * - Muestra información financiera
 * - Búsqueda en tiempo real
 */
const ClientSelector = ({ value, onChange, error, disabled }) => {

  const searchClients = async (searchTerm) => {
    try {
      const response = await apiClient.get('/api/v1/clients/search/eligible', {
        params: {
          q: searchTerm,
          limit: 10
        }
      });

      return response.data || [];
    } catch (err) {
      console.error('Error buscando clientes:', err);
      return [];
    }
  };

  const renderOption = (client) => (
    <div className="client-option">
      <div className="client-option-header">
        <span className="client-option-name">{client.full_name}</span>
        <span className="client-option-username">@{client.username}</span>
      </div>
      <div className="client-option-details">
        <span className="client-option-email">📧 {client.email}</span>
        {client.phone_number && (
          <span className="client-option-phone">📱 {client.phone_number}</span>
        )}
      </div>
      <div className="client-option-stats">
        {client.active_loans > 0 && (
          <span className="badge badge-info">
            {client.active_loans} préstamo{client.active_loans > 1 ? 's' : ''} activo{client.active_loans > 1 ? 's' : ''}
          </span>
        )}
        {!client.has_overdue_payments && (
          <span className="badge badge-success">✓ Al corriente</span>
        )}
      </div>
    </div>
  );

  const renderSelected = (client) => (
    <div className="client-selected">
      <div className="client-selected-main">
        <span className="client-selected-icon">👤</span>
        <div className="client-selected-info">
          <div className="client-selected-name">{client.full_name}</div>
          <div className="client-selected-meta">{client.email}</div>
        </div>
      </div>
      {client.active_loans > 0 && (
        <span className="badge badge-sm badge-info">
          {client.active_loans} activo{client.active_loans > 1 ? 's' : ''}
        </span>
      )}
    </div>
  );

  return (
    <div className="client-selector">
      <SearchableSelect
        value={value}
        onChange={onChange}
        onSearch={searchClients}
        renderOption={renderOption}
        renderSelected={renderSelected}
        placeholder="Buscar cliente por nombre, teléfono, email..."
        minChars={2}
        debounceMs={300}
        disabled={disabled}
        error={error}
        helperText="Busca entre todos los clientes activos del sistema"
      />
    </div>
  );
};

ClientSelector.propTypes = {
  value: PropTypes.object,
  onChange: PropTypes.func.isRequired,
  error: PropTypes.string,
  disabled: PropTypes.bool,
};

export default ClientSelector;
