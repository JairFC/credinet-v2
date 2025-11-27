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

      if (refreshToken) {
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
          window.location.href = '/login';
          return Promise.reject(refreshError);
        }
      } else {
        // No refresh token - redirect to login
        auth.clearAuth();
        window.location.href = '/login';
      }
    }

    // For other errors, just reject
    return Promise.reject(error);
  }
);

export default apiClient;
