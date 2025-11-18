/**
 * ClientsPage - Gestión de Clientes
 * 
 * Clientes: Usuarios que SOLICITAN préstamos
 */
import { useState, useEffect } from 'react';
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
    limit: 50,
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

  const filteredClients = clients.filter((client) => {
    if (!filters.search) return true;
    const searchLower = filters.search.toLowerCase();
    return (
      client.username?.toLowerCase().includes(searchLower) ||
      client.full_name?.toLowerCase().includes(searchLower) ||
      client.email?.toLowerCase().includes(searchLower)
    );
  });

  const totalPages = Math.ceil(pagination.total / pagination.limit);
  const currentPage = Math.floor(pagination.offset / pagination.limit) + 1;

  if (loading) {
    return (
      <div className="clients-page">
        <div className="clients-header">
          <h1>👥 Gestión de Clientes</h1>
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
      <div className="clients-header">
        <div className="header-content">
          <h1>👥 Gestión de Clientes</h1>
          <p className="subtitle">Usuarios que solicitan préstamos</p>
        </div>
        <button className="btn btn-primary" onClick={handleCreateClient}>
          ➕ Nuevo Cliente
        </button>
      </div>

      {/* Filters */}
      <div className="filters-section">
        <div className="search-box">
          <input
            type="text"
            placeholder="🔍 Buscar por nombre, usuario o email..."
            value={filters.search}
            onChange={(e) => setFilters({ ...filters, search: e.target.value })}
            className="search-input"
          />
        </div>

        <div className="filter-options">
          <label className="checkbox-label">
            <input
              type="checkbox"
              checked={filters.active_only}
              onChange={(e) =>
                setFilters({ ...filters, active_only: e.target.checked })
              }
            />
            <span>Solo activos</span>
          </label>
        </div>
      </div>

      {/* Stats */}
      <div className="stats-row">
        <div className="stat-card">
          <div className="stat-value">{pagination.total}</div>
          <div className="stat-label">Total Clientes</div>
        </div>
        <div className="stat-card">
          <div className="stat-value">{filteredClients.length}</div>
          <div className="stat-label">Mostrando</div>
        </div>
      </div>

      {/* Error */}
      {error && (
        <div className="error-message">
          ⚠️ {error}
        </div>
      )}

      {/* Table */}
      <div className="table-container">
        <table className="clients-table">
          <thead>
            <tr>
              <th>ID</th>
              <th>Usuario</th>
              <th>Nombre Completo</th>
              <th>Email</th>
              <th>Teléfono</th>
              <th>Estado</th>
              <th>Acciones</th>
            </tr>
          </thead>
          <tbody>
            {filteredClients.length === 0 ? (
              <tr>
                <td colSpan="7" className="no-data">
                  No se encontraron clientes
                </td>
              </tr>
            ) : (
              filteredClients.map((client) => (
                <tr key={client.id}>
                  <td>{client.id}</td>
                  <td>
                    <strong>{client.username}</strong>
                  </td>
                  <td>{client.full_name || 'N/A'}</td>
                  <td>{client.email || 'N/A'}</td>
                  <td>{client.phone_number || 'N/A'}</td>
                  <td>
                    <span
                      className={`status-badge ${client.active ? 'status-active' : 'status-inactive'
                        }`}
                    >
                      {client.active ? '✓ Activo' : '✗ Inactivo'}
                    </span>
                  </td>
                  <td>
                    <button
                      className="btn-details"
                      onClick={() => handleViewDetail(client.id)}
                      title="Ver detalles del cliente"
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

      {/* Pagination */}
      {totalPages > 1 && (
        <div className="pagination">
          <button
            className="btn btn-sm"
            disabled={currentPage === 1}
            onClick={() =>
              setPagination((prev) => ({
                ...prev,
                offset: Math.max(0, prev.offset - prev.limit),
              }))
            }
          >
            ← Anterior
          </button>

          <span className="page-info">
            Página {currentPage} de {totalPages}
          </span>

          <button
            className="btn btn-sm"
            disabled={currentPage === totalPages}
            onClick={() =>
              setPagination((prev) => ({
                ...prev,
                offset: prev.offset + prev.limit,
              }))
            }
          >
            Siguiente →
          </button>
        </div>
      )}
    </div>
  );
}
