import { config, getApiBaseUrl } from './index.js';

// API Base URL
export const API_BASE_URL = getApiBaseUrl();

// Helper para hacer requests a la API
export const apiRequest = async (endpoint, options = {}) => {
  const url = `${API_BASE_URL}${endpoint}`;

  const defaultOptions = {
    headers: {
      ...options.headers,
    },
  };

  // Solo agregar Content-Type si no es FormData
  if (!(options.body instanceof FormData)) {
    defaultOptions.headers['Content-Type'] = 'application/json';
  }

  // Si hay un token en localStorage, agregarlo
  const token = localStorage.getItem(config.auth.tokenKey);
  if (token) {
    defaultOptions.headers.Authorization = `Bearer ${token}`;
  }

  return fetch(url, { ...defaultOptions, ...options });
};