/**
 * ClientsPage - Gestión de Clientes
 * 
 * Clientes: Usuarios que SOLICITAN préstamos
 * Versión profesional con diseño limpio y búsqueda inteligente
 */
import { useState, useEffect, useMemo } from 'react';
import { useNavigate } from 'react-router-dom';
import { clientsService } from '../../../../shared/api/services/clientsService';
import './ClientsPage.css';

export default function ClientsPage() {
  const navigate = useNavigate();
  const [clients, setClients] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [filters, setFilters] = useState({
    active_only: true,
    search: '',
  });

  // Pagination
  const [pagination, setPagination] = useState({
    limit: 10,
    offset: 0,
    total: 0,
  });

  useEffect(() => {
    loadClients();
  }, [pagination.limit, pagination.offset, filters.active_only]);

  const loadClients = async () => {
    try {
      setLoading(true);
      setError(null);

      const response = await clientsService.getAll({
        limit: pagination.limit,
        offset: pagination.offset,
        active_only: filters.active_only,
      });

      const data = response.data;
      setClients(Array.isArray(data.items) ? data.items : []);
      setPagination((prev) => ({ ...prev, total: data.total || 0 }));
    } catch (err) {
      console.error('Error loading clients:', err);
      setError(err.response?.data?.detail || 'Error al cargar clientes');
      setClients([]);
    } finally {
      setLoading(false);
    }
  };

  const handleViewDetail = (clientId) => {
    navigate(`/usuarios/clientes/${clientId}`);
  };

  const handleCreateClient = () => {
    navigate('/usuarios/clientes/nuevo');
  };

  // Normaliza texto para búsqueda (quita acentos y convierte a minúsculas)
  const normalizeText = (text) => {
    if (!text) return '';
    return text
      .toLowerCase()
      .normalize('NFD')
      .replace(/[\u0300-\u036f]/g, '');
  };

  // Búsqueda inteligente - busca en múltiples campos
  const filteredClients = useMemo(() => {
    if (!filters.search.trim()) return clients;

    const searchTerms = normalizeText(filters.search).split(/\s+/).filter(Boolean);

    return clients.filter((client) => {
      const searchableText = normalizeText([
        client.username,
        client.full_name,
        client.id?.toString(),
        client.email,
        client.phone_number,
      ].filter(Boolean).join(' '));

      return searchTerms.every(term => searchableText.includes(term));
    });
  }, [clients, filters.search]);

  // Estadísticas
  const stats = useMemo(() => {
    const activeCount = clients.filter(c => c.active).length;
    return {
      total: pagination.total,
      showing: filteredClients.length,
      active: activeCount,
    };
  }, [clients, filteredClients, pagination.total]);

  const totalPages = Math.ceil(pagination.total / pagination.limit);
  const currentPage = Math.floor(pagination.offset / pagination.limit) + 1;

  const goToPage = (page) => {
    setPagination(prev => ({ ...prev, offset: (page - 1) * prev.limit }));
  };

  if (loading) {
    return (
      <div className="clients-page">
        <div className="page-header">
          <h1>Gestión de Clientes</h1>
        </div>
        <div className="loading-container">
          <div className="skeleton-table">
            <div className="skeleton-row"></div>
            <div className="skeleton-row"></div>
            <div className="skeleton-row"></div>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="clients-page">
      {/* Header */}
      <div className="page-header">
        <div className="header-info">
          <h1>Gestión de Clientes</h1>
          <p className="header-subtitle">
            Usuarios que solicitan préstamos
          </p>
        </div>
        <button className="btn-primary-action" onClick={handleCreateClient}>
          <span className="btn-icon">+</span>
          Nuevo Cliente
        </button>
      </div>

      {/* Resumen */}
      <div className="stats-summary">
        <div className="stat-card stat-highlight">
          <span className="stat-value">{stats.total}</span>
          <span className="stat-label">Total Clientes</span>
        </div>
        <div className="stat-card">
          <span className="stat-value">{stats.showing}</span>
          <span className="stat-label">Mostrando</span>
        </div>
      </div>

      {/* Filtros */}
      <div className="filters-bar">
        <div className="search-container">
          <span className="search-icon">🔍</span>
          <input
            type="text"
            placeholder="Buscar por nombre, usuario o email..."
            value={filters.search}
            onChange={(e) => setFilters({ ...filters, search: e.target.value })}
            className="search-input"
          />
          {filters.search && (
            <button
              className="search-clear"
              onClick={() => setFilters({ ...filters, search: '' })}
            >
              ✕
            </button>
          )}
        </div>

        <div className="filter-controls">
          <label className="toggle-label">
            <input
              type="checkbox"
              checked={filters.active_only}
              onChange={(e) => setFilters({ ...filters, active_only: e.target.checked })}
              className="toggle-input"
            />
            <span className="toggle-switch"></span>
            <span className="toggle-text">Solo activos</span>
          </label>
        </div>
      </div>

      {/* Error */}
      {error && (
        <div className="error-banner">
          <span className="error-icon">⚠️</span>
          <span>{error}</span>
        </div>
      )}

      {/* Tabla */}
      <div className="table-wrapper">
        <table className="data-table">
          <thead>
            <tr>
              <th className="col-id">ID</th>
              <th className="col-user">Usuario</th>
              <th className="col-name">Nombre Completo</th>
              <th className="col-email">Email</th>
              <th className="col-phone">Teléfono</th>
              <th className="col-status">Estado</th>
              <th className="col-actions">Acciones</th>
            </tr>
          </thead>
          <tbody>
            {filteredClients.length === 0 ? (
              <tr>
                <td colSpan="7" className="empty-state">
                  <div className="empty-content">
                    <span className="empty-icon">📋</span>
                    <p>No se encontraron clientes</p>
                    {filters.search && (
                      <button
                        className="btn-link"
                        onClick={() => setFilters({ ...filters, search: '' })}
                      >
                        Limpiar búsqueda
                      </button>
                    )}
                  </div>
                </td>
              </tr>
            ) : (
              filteredClients.map((client) => (
                <tr key={client.id}>
                  <td className="col-id">
                    <span className="id-badge">{client.id}</span>
                  </td>
                  <td className="col-user">
                    <span className="username">@{client.username}</span>
                  </td>
                  <td className="col-name">
                    <span className="client-name">{client.full_name || 'Sin nombre'}</span>
                  </td>
                  <td className="col-email">
                    <span className="email-text">{client.email || '—'}</span>
                  </td>
                  <td className="col-phone">
                    <span className="phone-text">{client.phone_number || '—'}</span>
                  </td>
                  <td className="col-status">
                    <span className={`status-pill ${client.active ? 'active' : 'inactive'}`}>
                      {client.active ? '✓ ACTIVO' : '✗ Inactivo'}
                    </span>
                  </td>
                  <td className="col-actions">
                    <button
                      className="btn-action"
                      onClick={() => handleViewDetail(client.id)}
                    >
                      Detalles
                    </button>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>

      {/* Paginación */}
      {totalPages > 1 && (
        <div className="pagination-bar">
          <div className="pagination-info">
            Mostrando {filteredClients.length} de {pagination.total} clientes
          </div>
          <div className="pagination-controls">
            <button
              className="pagination-btn"
              onClick={() => goToPage(1)}
              disabled={currentPage === 1}
              title="Primera página"
            >
              «
            </button>
            <button
              className="pagination-btn"
              onClick={() => goToPage(currentPage - 1)}
              disabled={currentPage === 1}
            >
              ‹ Anterior
            </button>

            <div className="pagination-pages">
              {Array.from({ length: Math.min(5, totalPages) }, (_, i) => {
                let pageNum;
                if (totalPages <= 5) {
                  pageNum = i + 1;
                } else if (currentPage < 3) {
                  pageNum = i + 1;
                } else if (currentPage > totalPages - 2) {
                  pageNum = totalPages - 4 + i;
                } else {
                  pageNum = currentPage - 2 + i;
                }
                return (
                  <button
                    key={pageNum}
                    onClick={() => goToPage(pageNum)}
                    className={`pagination-page ${currentPage === pageNum ? 'active' : ''}`}
                  >
                    {pageNum}
                  </button>
                );
              })}
            </div>

            <button
              className="pagination-btn"
              onClick={() => goToPage(currentPage + 1)}
              disabled={currentPage === totalPages}
            >
              Siguiente ›
            </button>
            <button
              className="pagination-btn"
              onClick={() => goToPage(totalPages)}
              disabled={currentPage === totalPages}
              title="Última página"
            >
              »
            </button>
          </div>
        </div>
      )}

      {/* Footer info */}
      <div className="page-footer">
        Página {currentPage} de {totalPages}
      </div>
    </div>
  );
}
