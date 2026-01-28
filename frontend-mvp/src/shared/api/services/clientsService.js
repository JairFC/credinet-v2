/**
 * Clients Service - API calls para gestión de clientes
 * 
 * Clientes: Usuarios que solicitan préstamos
 */
import { apiClient } from '../apiClient';
import { ENDPOINTS } from '../endpoints';

export const clientsService = {
  /**
   * Obtiene lista paginada de clientes
   * @param {Object} params - Parámetros de búsqueda
   * @param {number} params.limit - Máximo de resultados
   * @param {number} params.offset - Desplazamiento para paginación
   * @param {boolean} params.active_only - Solo clientes activos
   * @param {string} params.search - Término de búsqueda (opcional)
   */
  getAll: async (params = {}) => {
    const queryParams = {
      limit: params.limit || 50,
      offset: params.offset || 0,
      active_only: params.active_only !== undefined ? params.active_only : true,
    };
    
    // Incluir search si existe y no está vacío
    if (params.search && params.search.trim()) {
      queryParams.search = params.search.trim();
    }
    
    return apiClient.get(ENDPOINTS.clients.list, { params: queryParams });
  },

  /**
   * Obtiene detalle de un cliente
   */
  getById: (id) => {
    return apiClient.get(ENDPOINTS.clients.detail(id));
  },

  /**
   * Crea un nuevo cliente
   */
  create: (data) => {
    return apiClient.post(ENDPOINTS.auth.register, data);
  },

  /**
   * Actualiza un cliente existente
   */
  update: (id, data) => {
    return apiClient.put(ENDPOINTS.clients.detail(id), data);
  },

  /**
   * Elimina (desactiva) un cliente
   */
  delete: (id) => {
    return apiClient.delete(ENDPOINTS.clients.detail(id));
  },
};
