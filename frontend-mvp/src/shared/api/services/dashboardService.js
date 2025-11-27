/**
 * Dashboard Service
 * Handles dashboard-related API calls
 */
import apiClient from '../apiClient';
import { ENDPOINTS } from '../endpoints';

export const dashboardService = {
  /**
   * Get dashboard statistics
   * @returns {Promise} Response with stats data
   */
  getStats: () => {
    return apiClient.get(ENDPOINTS.dashboard.stats);
  },

  /**
   * Get recent activity
   * @param {Object} params - Optional query params { limit, offset }
   * @returns {Promise} Response with activity list
   */
  getRecentActivity: (params = {}) => {
    return apiClient.get(ENDPOINTS.dashboard.recentActivity, { params });
  },
};

export default dashboardService;
