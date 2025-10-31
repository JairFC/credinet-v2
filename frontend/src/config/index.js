// Environment configuration for the frontend
export const config = {
  api: {
    // Backend port mapping
    backendPort: import.meta.env.VITE_BACKEND_PORT || '8001',
    frontendPort: import.meta.env.VITE_FRONTEND_PORT || '5174',

    // Development hosts that should use external IP
    localHosts: ['localhost', '127.0.0.1'],

    // API endpoints
    endpoints: {
      auth: '/api/auth',
      loans: '/api/loans',
      users: '/api/auth/users',
      associates: '/api/associates',
      documents: '/api/documents',
      utils: '/api/utils'
    }
  },

  auth: {
    tokenKey: 'authToken',
    refreshTokenKey: 'refreshToken'
  },

  ui: {
    defaultPageSize: 20,
    debounceDelay: 300
  }
};

// Dynamic API base URL calculation
export const getApiBaseUrl = () => {
  const { hostname } = window.location;

  // For external IPs, use explicit backend port
  if (!config.api.localHosts.includes(hostname)) {
    return `http://${hostname}:${config.api.backendPort}`;
  }

  // For localhost, use Vite proxy
  return '';
};