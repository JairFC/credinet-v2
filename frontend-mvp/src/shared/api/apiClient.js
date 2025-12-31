/**
 * API Client - Axios instance with interceptors
 * Handles authentication, token refresh, and error handling
 */
import axios from 'axios';
import { auth } from '@/shared/utils/auth';

// Get API base URL from environment variables
const API_BASE_URL = import.meta.env.VITE_API_URL || 'http://localhost:8000';

// Create axios instance with default config
export const apiClient = axios.create({
  baseURL: API_BASE_URL,
  timeout: 30000, // 30 seconds timeout (increased for debugging)
  headers: {
    'Content-Type': 'application/json',
  },
});

/**
 * Request Interceptor
 * Adds JWT token to all requests
 */
apiClient.interceptors.request.use(
  (config) => {
    const token = auth.getAccessToken();
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);

/**
 * Response Interceptor
 * Handles token refresh and error responses
 */
apiClient.interceptors.response.use(
  // Success response - just pass through
  (response) => response,

  // Error response - handle token refresh
  async (error) => {
    const originalRequest = error.config;

    // If error is 401 (Unauthorized) and we haven't retried yet
    if (error.response?.status === 401 && !originalRequest._retry) {
      originalRequest._retry = true;

      const refreshToken = auth.getRefreshToken();

      // Don't try to refresh if we're calling /auth/me or /auth/login
      const isAuthEndpoint = originalRequest.url?.includes('/auth/me') ||
        originalRequest.url?.includes('/auth/login') ||
        originalRequest.url?.includes('/auth/refresh');

      if (refreshToken && !isAuthEndpoint) {
        try {
          // Try to refresh the token
          const { data } = await axios.post(`${API_BASE_URL}/api/v1/auth/refresh`, {
            refresh_token: refreshToken,
          });

          // Update tokens in localStorage
          const currentUser = auth.getUser();
          auth.setAuth(currentUser, data.access_token, data.refresh_token);

          // Retry the original request with new token
          originalRequest.headers.Authorization = `Bearer ${data.access_token}`;
          return apiClient(originalRequest);
        } catch (refreshError) {
          // Refresh failed - clear auth and redirect to login
          auth.clearAuth();
          if (window.location.pathname !== '/login') {
            window.location.href = '/login';
          }
          return Promise.reject(refreshError);
        }
      } else if (isAuthEndpoint) {
        // Auth endpoint failed - just clear and reject (don't redirect)
        auth.clearAuth();
        return Promise.reject(error);
      } else {
        // No refresh token - redirect to login if not already there
        auth.clearAuth();
        if (window.location.pathname !== '/login') {
          window.location.href = '/login';
        }
      }
    }

    // For other errors, just reject
    return Promise.reject(error);
  }
);

export default apiClient;
