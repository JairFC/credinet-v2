import { useState, useEffect, useRef } from 'react';
import PropTypes from 'prop-types';
import './SearchableSelect.css';

/**
 * Componente reutilizable de selección con búsqueda
 * 
 * Características:
 * - Búsqueda en tiempo real
 * - Debounce configurable
 * - Carga bajo demanda
 * - Dropdown con scroll
 * - Soporte para renderizado personalizado
 */
const SearchableSelect = ({
  value,
  onChange,
  onSearch,
  renderOption,
  renderSelected,
  placeholder = 'Buscar...',
  minChars = 2,
  debounceMs = 300,
  disabled = false,
  error = null,
  helperText = null,
  loading = false,
}) => {
  const [searchTerm, setSearchTerm] = useState('');
  const [isOpen, setIsOpen] = useState(false);
  const [options, setOptions] = useState([]);
  const [isSearching, setIsSearching] = useState(false);
  const wrapperRef = useRef(null);
  const searchTimeoutRef = useRef(null);

  // Cerrar dropdown al hacer clic fuera
  useEffect(() => {
    const handleClickOutside = (event) => {
      if (wrapperRef.current && !wrapperRef.current.contains(event.target)) {
        setIsOpen(false);
      }
    };

    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  // Búsqueda con debounce
  useEffect(() => {
    if (searchTerm.length < minChars) {
      setOptions([]);
      return;
    }

    // Limpiar timeout anterior
    if (searchTimeoutRef.current) {
      clearTimeout(searchTimeoutRef.current);
    }

    // Ejecutar búsqueda después del debounce
    searchTimeoutRef.current = setTimeout(async () => {
      setIsSearching(true);
      try {
        const results = await onSearch(searchTerm);
        setOptions(Array.isArray(results) ? results : []);
      } catch (err) {
        console.error('Error en búsqueda:', err);
        setOptions([]);
      } finally {
        setIsSearching(false);
      }
    }, debounceMs);

    return () => {
      if (searchTimeoutRef.current) {
        clearTimeout(searchTimeoutRef.current);
      }
    };
  }, [searchTerm, minChars, debounceMs, onSearch]);

  const handleInputChange = (e) => {
    const newValue = e.target.value;
    setSearchTerm(newValue);
    setIsOpen(true);
  };

  const handleOptionClick = (option) => {
    onChange(option);
    setSearchTerm('');
    setOptions([]);
    setIsOpen(false);
  };

  const handleClear = () => {
    onChange(null);
    setSearchTerm('');
    setOptions([]);
  };

  const handleInputFocus = () => {
    setIsOpen(true);
  };

  return (
    <div className={`searchable-select ${error ? 'has-error' : ''}`} ref={wrapperRef}>
      <div className="searchable-select-control">
        {value ? (
          <div className="searchable-select-selected">
            {renderSelected ? renderSelected(value) : value.label || value.name || 'Seleccionado'}
            <button
              type="button"
              className="searchable-select-clear"
              onClick={handleClear}
              disabled={disabled}
              aria-label="Limpiar selección"
            >
              ✕
            </button>
          </div>
        ) : (
          <input
            type="text"
            className="searchable-select-input"
            placeholder={placeholder}
            value={searchTerm}
            onChange={handleInputChange}
            onFocus={handleInputFocus}
            disabled={disabled || loading}
          />
        )}
      </div>

      {error && <div className="searchable-select-error">{error}</div>}
      {helperText && !error && <div className="searchable-select-helper">{helperText}</div>}

      {isOpen && !value && (
        <div className="searchable-select-dropdown">
          {isSearching ? (
            <div className="searchable-select-loading">
              <div className="spinner-small"></div>
              <span>Buscando...</span>
            </div>
          ) : searchTerm.length < minChars ? (
            <div className="searchable-select-hint">
              Escribe al menos {minChars} caracteres para buscar
            </div>
          ) : options.length === 0 ? (
            <div className="searchable-select-empty">
              No se encontraron resultados
            </div>
          ) : (
            <div className="searchable-select-options">
              {options.map((option, index) => (
                <div
                  key={option.id || index}
                  className="searchable-select-option"
                  onClick={() => handleOptionClick(option)}
                >
                  {renderOption ? renderOption(option) : option.label || option.name || 'Opción'}
                </div>
              ))}
            </div>
          )}
        </div>
      )}
    </div>
  );
};

SearchableSelect.propTypes = {
  value: PropTypes.object,
  onChange: PropTypes.func.isRequired,
  onSearch: PropTypes.func.isRequired,
  renderOption: PropTypes.func,
  renderSelected: PropTypes.func,
  placeholder: PropTypes.string,
  minChars: PropTypes.number,
  debounceMs: PropTypes.number,
  disabled: PropTypes.bool,
  error: PropTypes.string,
  helperText: PropTypes.string,
  loading: PropTypes.bool,
};

export default SearchableSelect;
