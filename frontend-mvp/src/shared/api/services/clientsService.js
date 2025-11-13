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
   */
  getAll: async (params = {}) => {
    const { limit = 50, offset = 0, active_only = true } = params;
    return apiClient.get(ENDPOINTS.clients.list, {
      params: { limit, offset, active_only }
    });
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
