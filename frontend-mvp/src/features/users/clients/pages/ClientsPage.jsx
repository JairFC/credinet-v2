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
  const [searchTerm, setSearchTerm] = useState('');
  const [debouncedSearch, setDebouncedSearch] = useState('');
  const [activeOnly, setActiveOnly] = useState(true);

  // Pagination - usando currentPage en lugar de offset para simplificar
  const [currentPage, setCurrentPage] = useState(1);
  const [totalItems, setTotalItems] = useState(0);
  const [itemsPerPage] = useState(10);

  // Debounce search - esperar 800ms antes de buscar en backend
  // Reset de página incluido aquí para evitar múltiples renders
  useEffect(() => {
    const timer = setTimeout(() => {
      setDebouncedSearch(searchTerm);
      setCurrentPage(1); // Reset página al buscar
    }, 800);
    return () => clearTimeout(timer);
  }, [searchTerm]);

  // Cargar clientes cuando cambia la página, filtros o búsqueda
  useEffect(() => {
    loadClients();
  }, [currentPage, activeOnly, debouncedSearch]);

  const loadClients = async () => {
    try {
      setLoading(true);
      setError(null);

      const params = {
        limit: itemsPerPage,
        offset: (currentPage - 1) * itemsPerPage,
        active_only: activeOnly,
      };

      // Agregar búsqueda si hay término
      if (debouncedSearch.trim()) {
        params.search = debouncedSearch.trim();
      }

      const response = await clientsService.getAll(params);

      const data = response.data;
      setClients(Array.isArray(data.items) ? data.items : []);
      setTotalItems(data.total || 0);
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

  // Estadísticas
  const stats = useMemo(() => {
    const activeCount = clients.filter(c => c.active).length;
    return {
      total: totalItems,
      showing: clients.length,
      active: activeCount,
    };
  }, [clients, totalItems]);

  const totalPages = Math.ceil(totalItems / itemsPerPage);

  const goToPage = (page) => {
    setCurrentPage(page);
  };

  // Solo mostrar loading inicial, no en búsquedas subsecuentes
  const isInitialLoading = loading && clients.length === 0 && !debouncedSearch;

  if (isInitialLoading) {
    return (
      <div className="clients-page">
        <div className="loading-screen">
          <div className="loading-content">
            <div className="loading-spinner">
              <div className="spinner-ring"></div>
              <div className="spinner-ring"></div>
              <div className="spinner-ring"></div>
            </div>
            <h2 className="loading-title">Cargando clientes...</h2>
            <p className="loading-subtitle">Por favor espere</p>
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
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="search-input"
          />
          {searchTerm && (
            <button
              className="search-clear"
              onClick={() => setSearchTerm('')}
            >
              ✕
            </button>
          )}
        </div>

        <div className="filter-controls">
          <label className="toggle-label">
            <input
              type="checkbox"
              checked={activeOnly}
              onChange={(e) => setActiveOnly(e.target.checked)}
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
            {clients.length === 0 ? (
              <tr>
                <td colSpan="7" className="empty-state">
                  <div className="empty-content">
                    <span className="empty-icon">📋</span>
                    <p>No se encontraron clientes</p>
                    {searchTerm && (
                      <button
                        className="btn-link"
                        onClick={() => setSearchTerm('')}
                      >
                        Limpiar búsqueda
                      </button>
                    )}
                  </div>
                </td>
              </tr>
            ) : (
              clients.map((client) => (
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
                    <span className={`status-badge ${client.active ? 'status-active' : 'status-inactive'}`}>
                      <span className="status-dot"></span>
                      {client.active ? 'Activo' : 'Inactivo'}
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
            Mostrando {clients.length} de {totalItems} clientes
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
