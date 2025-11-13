/**
 * AssociatesManagementPage - Gestión de Asociados
 * 
 * Asociados: Usuarios que PRESTAN dinero (tienen línea de crédito)
 */
import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { associatesService } from '../../../../shared/api/services/associatesService';
import './AssociatesManagementPage.css';

export default function AssociatesManagementPage() {
  const navigate = useNavigate();
  const [associates, setAssociates] = useState([]);
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
    loadAssociates();
  }, [pagination.limit, pagination.offset, filters.active_only]);

  const loadAssociates = async () => {
    try {
      setLoading(true);
      setError(null);

      const response = await associatesService.getAll({
        limit: pagination.limit,
        offset: pagination.offset,
        active_only: filters.active_only,
      });

      const data = response.data;
      setAssociates(Array.isArray(data.items) ? data.items : []);
      setPagination((prev) => ({ ...prev, total: data.total || 0 }));
    } catch (err) {
      console.error('Error loading associates:', err);
      setError(err.response?.data?.detail || 'Error al cargar asociados');
      setAssociates([]);
    } finally {
      setLoading(false);
    }
  };

  const handleViewDetail = (associateId) => {
    navigate(`/asociados/${associateId}`);
  };

  const handleCreateAssociate = () => {
    navigate('/usuarios/asociados/nuevo');
  };

  const formatCurrency = (amount) => {
    return new Intl.NumberFormat('es-MX', {
      style: 'currency',
      currency: 'MXN',
    }).format(amount || 0);
  };

  const formatPercentage = (value) => {
    return `${((value || 0) * 100).toFixed(1)}%`;
  };

  const filteredAssociates = associates.filter((assoc) => {
    if (!filters.search) return true;
    const searchLower = filters.search.toLowerCase();
    return (
      assoc.username?.toLowerCase().includes(searchLower) ||
      assoc.user_id?.toString().includes(searchLower)
    );
  });

  // Calculate totals - convertir a número ya que vienen como strings del backend
  const totals = filteredAssociates.reduce(
    (acc, assoc) => ({
      creditLimit: acc.creditLimit + (parseFloat(assoc.credit_limit) || 0),
      creditUsed: acc.creditUsed + (parseFloat(assoc.credit_used) || 0),
      creditAvailable: acc.creditAvailable + (parseFloat(assoc.credit_available) || 0),
      debtBalance: acc.debtBalance + (parseFloat(assoc.debt_balance) || 0),
      pendingDebts: acc.pendingDebts + (parseInt(assoc.pending_debts_count) || 0),
    }),
    { creditLimit: 0, creditUsed: 0, creditAvailable: 0, debtBalance: 0, pendingDebts: 0 }
  );

  const totalPages = Math.ceil(pagination.total / pagination.limit);
  const currentPage = Math.floor(pagination.offset / pagination.limit) + 1;

  if (loading) {
    return (
      <div className="associates-management-page">
        <div className="associates-header">
          <h1>💼 Gestión de Asociados</h1>
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
    <div className="associates-management-page">
      <div className="associates-header">
        <div className="header-content">
          <h1>💼 Gestión de Asociados</h1>
          <p className="subtitle">Usuarios que prestan dinero (líneas de crédito)</p>
        </div>
        <button className="btn btn-primary" onClick={handleCreateAssociate}>
          ➕ Nuevo Asociado
        </button>
      </div>

      {/* Filters */}
      <div className="filters-section">
        <div className="search-box">
          <input
            type="text"
            placeholder="🔍 Buscar por usuario o ID..."
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
        <div className="stat-card stat-total">
          <div className="stat-value">{pagination.total}</div>
          <div className="stat-label">Total Asociados</div>
        </div>
        <div className="stat-card stat-limit">
          <div className="stat-value">{formatCurrency(totals.creditLimit)}</div>
          <div className="stat-label">Línea Total</div>
        </div>
        <div className="stat-card stat-used">
          <div className="stat-value">{formatCurrency(totals.creditUsed)}</div>
          <div className="stat-label">Crédito Usado</div>
        </div>
        <div className="stat-card stat-available">
          <div className="stat-value">{formatCurrency(totals.creditAvailable)}</div>
          <div className="stat-label">Disponible</div>
        </div>
        <div className="stat-card stat-debt">
          <div className="stat-value">{formatCurrency(totals.debtBalance)}</div>
          <div className="stat-label">Deuda Total</div>
        </div>
        <div className="stat-card stat-pending">
          <div className="stat-value">{totals.pendingDebts}</div>
          <div className="stat-label">Deudas Pend.</div>
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
        <table className="associates-table">
          <thead>
            <tr>
              <th>ID</th>
              <th>User ID</th>
              <th>Usuario</th>
              <th>Nombre Completo</th>
              <th>Línea de Crédito</th>
              <th>Usado</th>
              <th>Disponible</th>
              <th>Deuda Total</th>
              <th>Deudas Pend.</th>
              <th>Uso %</th>
              <th>Estado</th>
              <th>Acciones</th>
            </tr>
          </thead>
          <tbody>
            {filteredAssociates.length === 0 ? (
              <tr>
                <td colSpan="12" className="no-data">
                  No se encontraron asociados
                </td>
              </tr>
            ) : (
              filteredAssociates.map((assoc) => {
                const usagePercent = assoc.credit_limit
                  ? (assoc.credit_used / assoc.credit_limit) * 100
                  : 0;

                return (
                  <tr key={assoc.id}>
                    <td>{assoc.id}</td>
                    <td>{assoc.user_id}</td>
                    <td>
                      <strong>{assoc.username || 'N/A'}</strong>
                    </td>
                    <td>
                      {assoc.full_name || 'Sin nombre'}
                    </td>
                    <td className="currency">
                      {formatCurrency(assoc.credit_limit)}
                    </td>
                    <td className="currency text-danger">
                      {formatCurrency(assoc.credit_used)}
                    </td>
                    <td className="currency text-success">
                      {formatCurrency(assoc.credit_available)}
                    </td>
                    <td className="currency text-warning">
                      {formatCurrency(assoc.debt_balance || 0)}
                    </td>
                    <td className="text-center">
                      {assoc.pending_debts_count > 0 ? (
                        <span className="badge badge-danger">
                          {assoc.pending_debts_count}
                        </span>
                      ) : (
                        <span className="badge badge-success">0</span>
                      )}
                    </td>
                    <td>
                      <div className="usage-cell">
                        <div className="usage-bar">
                          <div
                            className="usage-fill"
                            style={{
                              width: `${Math.min(100, usagePercent)}%`,
                              backgroundColor:
                                usagePercent > 90
                                  ? '#dc2626'
                                  : usagePercent > 70
                                    ? '#f59e0b'
                                    : '#10b981',
                            }}
                          />
                        </div>
                        <span className="usage-text">
                          {usagePercent.toFixed(1)}%
                        </span>
                      </div>
                    </td>
                    <td>
                      <span
                        className={`status-badge ${assoc.active ? 'status-active' : 'status-inactive'
                          }`}
                      >
                        {assoc.active ? '✓ Activo' : '✗ Inactivo'}
                      </span>
                    </td>
                    <td>
                      <button
                        className="btn btn-sm btn-secondary"
                        onClick={() => handleViewDetail(assoc.id)}
                      >
                        👁️ Ver
                      </button>
                    </td>
                  </tr>
                );
              })
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
