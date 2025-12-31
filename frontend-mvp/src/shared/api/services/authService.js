/**
 * Auth Service
 * Handles authentication-related API calls
 */
import apiClient from '../apiClient';
import { ENDPOINTS } from '../endpoints';

export const authService = {
  /**
   * Login user
   * @param {Object} credentials - { username, password }
   * @returns {Promise} Response with user and tokens
   */
  login: (credentials) => {
    return apiClient.post(ENDPOINTS.auth.login, credentials);
  },

  /**
   * Refresh access token
   * @param {string} refreshToken - Refresh token
   * @returns {Promise} Response with new tokens
   */
  refreshToken: (refreshToken) => {
    return apiClient.post(ENDPOINTS.auth.refresh, { refresh_token: refreshToken });
  },

  /**
   * Get current user info
   * @returns {Promise} Response with user data
   */
  me: () => {
    // Special handling: suppress console errors for 401 responses
    // This is expected when token expires or doesn't exist
    return apiClient.get(ENDPOINTS.auth.me).catch(error => {
      // Re-throw the error but prevent it from logging to console
      // if it's a 401 (expected during token validation)
      if (error.response?.status === 401) {
        // Create a new error without the noisy console output
        const cleanError = new Error('Unauthorized');
        cleanError.response = error.response;
        cleanError.config = error.config;
        throw cleanError;
      }
      throw error;
    });
  },

  /**
   * Logout user (optional - can revoke token on backend)
   * @returns {Promise}
   */
  logout: () => {
    return apiClient.post(ENDPOINTS.auth.logout);
  },
};

export default authService;
