import { useState, useEffect } from 'react';
import PropTypes from 'prop-types';
import SearchableSelect from '../SearchableSelect/SearchableSelect';
import { apiClient } from '../../api/apiClient';
import './AssociateSelector.css';

/**
 * Selector de asociados con crédito disponible
 * 
 * Características:
 * - Solo asociados activos
 * - Filtra por crédito disponible
 * - Muestra información de crédito en tiempo real
 * - Validación contra monto del préstamo
 */
const AssociateSelector = ({
  value,
  onChange,
  error,
  disabled,
  requiredCredit = 0
}) => {
  const [validationWarning, setValidationWarning] = useState(null);

  // Validar que el asociado tenga crédito suficiente
  useEffect(() => {
    if (value && requiredCredit > 0) {
      const available = parseFloat(value.available_credit) || 0;
      if (available < requiredCredit) {
        setValidationWarning(
          `⚠️ El crédito disponible (L.${available.toFixed(2)}) es menor al monto solicitado (L.${requiredCredit.toFixed(2)})`
        );
      } else {
        setValidationWarning(null);
      }
    } else {
      setValidationWarning(null);
    }
  }, [value, requiredCredit]);

  const searchAssociates = async (searchTerm) => {
    try {
      const response = await apiClient.get('/api/v1/associates/search/available', {
        params: {
          q: searchTerm,
          min_credit: Math.max(0, requiredCredit),
          limit: 10
        }
      });

      return response.data || [];
    } catch (err) {
      console.error('Error buscando asociados:', err);
      return [];
    }
  };

  const renderOption = (associate) => {
    const creditLimit = parseFloat(associate.credit_limit) || 0;
    const pendingPayments = parseFloat(associate.pending_payments_total) || 0;
    const availableCredit = parseFloat(associate.available_credit) || 0;
    const usagePercentage = associate.credit_usage_percentage || 0;

    const canGrant = requiredCredit === 0 || availableCredit >= requiredCredit;

    return (
      <div className="associate-option">
        <div className="associate-option-header">
          <span className="associate-option-name">{associate.full_name}</span>
          <span className="associate-option-username">@{associate.username}</span>
        </div>

        {associate.email && (
          <div className="associate-option-email">📧 {associate.email}</div>
        )}

        <div className="associate-option-credit">
          <div className="credit-bar-container">
            <div className="credit-bar-labels">
              <span className="credit-bar-label">Crédito usado</span>
              <span className="credit-bar-percentage">{usagePercentage.toFixed(1)}%</span>
            </div>
            <div className="credit-bar">
              <div
                className={`credit-bar-fill ${usagePercentage > 90 ? 'danger' : usagePercentage > 70 ? 'warning' : 'success'}`}
                style={{ width: `${Math.min(100, usagePercentage)}%` }}
              />
            </div>
            <div className="credit-bar-amounts">
              <span className="credit-used">Pendiente: L.{pendingPayments.toFixed(2)}</span>
              <span className="credit-available">
                Disponible: <strong>L.{availableCredit.toFixed(2)}</strong>
              </span>
            </div>
          </div>
        </div>

        <div className="associate-option-footer">
          <span className="badge badge-sm badge-info">
            Límite: L.{creditLimit.toFixed(2)}
          </span>
          {canGrant ? (
            <span className="badge badge-sm badge-success">✓ Crédito suficiente</span>
          ) : (
            <span className="badge badge-sm badge-warning">⚠️ Crédito insuficiente</span>
          )}
        </div>
      </div>
    );
  };

  const renderSelected = (associate) => {
    const availableCredit = parseFloat(associate.available_credit) || 0;
    const usagePercentage = associate.credit_usage_percentage || 0;

    return (
      <div className="associate-selected">
        <div className="associate-selected-main">
          <span className="associate-selected-icon">👔</span>
          <div className="associate-selected-info">
            <div className="associate-selected-name">{associate.full_name}</div>
            <div className="associate-selected-meta">
              Disponible: <strong>L.{availableCredit.toFixed(2)}</strong>
              {' • '}
              Uso: {usagePercentage.toFixed(1)}%
            </div>
          </div>
        </div>
        {availableCredit > 0 && (
          <span className="badge badge-sm badge-success">
            ✓ Activo
          </span>
        )}
      </div>
    );
  };

  const displayError = error || validationWarning;

  return (
    <div className="associate-selector">
      <SearchableSelect
        value={value}
        onChange={onChange}
        onSearch={searchAssociates}
        renderOption={renderOption}
        renderSelected={renderSelected}
        placeholder="Buscar asociado por nombre o email..."
        minChars={2}
        debounceMs={300}
        disabled={disabled}
        error={displayError}
        helperText={requiredCredit > 0
          ? `Se buscarán asociados con al menos L.${requiredCredit.toFixed(2)} disponibles`
          : "Se mostrarán asociados activos con crédito disponible"
        }
      />
    </div>
  );
};

AssociateSelector.propTypes = {
  value: PropTypes.object,
  onChange: PropTypes.func.isRequired,
  error: PropTypes.string,
  disabled: PropTypes.bool,
  requiredCredit: PropTypes.number,
};

export default AssociateSelector;
