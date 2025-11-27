/**
 * useFieldValidation - Hook para validaciones en tiempo real
 * 
 * Valida campos contra el backend con debounce para evitar sobrecarga
 */
import { useState, useEffect, useCallback, useRef } from 'react';
import { apiClient } from '../api/apiClient';
import { ENDPOINTS } from '../api/endpoints';

export const useFieldValidation = () => {
  const [validationStates, setValidationStates] = useState({});
  const timeoutsRef = useRef({});

  const validateField = useCallback(async (fieldName, value, validationType) => {
    // Limpiar timeout anterior
    if (timeoutsRef.current[fieldName]) {
      clearTimeout(timeoutsRef.current[fieldName]);
    }

    // Si el campo está vacío, limpiar validación
    if (!value || value.trim() === '') {
      setValidationStates(prev => ({
        ...prev,
        [fieldName]: null
      }));
      return;
    }

    // Marcar como validando
    setValidationStates(prev => ({
      ...prev,
      [fieldName]: { validating: true }
    }));

    // Validar después de 500ms de inactividad (debounce)
    timeoutsRef.current[fieldName] = setTimeout(async () => {
      try {
        let endpoint;

        switch (validationType) {
          case 'username':
            endpoint = ENDPOINTS.auth.validateUsername(value);
            break;
          case 'email':
            endpoint = ENDPOINTS.auth.validateEmail(value);
            break;
          case 'phone':
            endpoint = ENDPOINTS.auth.validatePhone(value);
            break;
          case 'curp':
            endpoint = ENDPOINTS.auth.validateCurp(value);
            break;
          case 'contact_email':
            endpoint = ENDPOINTS.associates.validateContactEmail(value);
            break;
          default:
            return;
        }

        const response = await apiClient.get(endpoint);

        setValidationStates(prev => ({
          ...prev,
          [fieldName]: {
            validating: false,
            available: response.data.available,
            message: response.data.message
          }
        }));
      } catch (error) {
        console.error(`Error validating ${fieldName}:`, error);
        setValidationStates(prev => ({
          ...prev,
          [fieldName]: {
            validating: false,
            available: true, // Asumir disponible si hay error
            message: null
          }
        }));
      }
    }, 500);
  }, []);

  const clearValidation = useCallback((fieldName) => {
    if (timeoutsRef.current[fieldName]) {
      clearTimeout(timeoutsRef.current[fieldName]);
    }
    setValidationStates(prev => {
      const newState = { ...prev };
      delete newState[fieldName];
      return newState;
    });
  }, []);

  const clearAllValidations = useCallback(() => {
    Object.keys(timeoutsRef.current).forEach(key => {
      clearTimeout(timeoutsRef.current[key]);
    });
    timeoutsRef.current = {};
    setValidationStates({});
  }, []);

  // Limpiar timeouts al desmontar
  useEffect(() => {
    return () => {
      Object.keys(timeoutsRef.current).forEach(key => {
        clearTimeout(timeoutsRef.current[key]);
      });
    };
  }, []);

  return {
    validationStates,
    validateField,
    clearValidation,
    clearAllValidations
  };
};
