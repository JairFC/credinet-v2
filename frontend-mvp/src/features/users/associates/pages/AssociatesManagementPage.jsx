/**
 * AssociatesManagementPage - Gestión de Asociados
 * 
 * Asociados: Usuarios que PRESTAN dinero (tienen línea de crédito)
 * Versión profesional con diseño limpio y búsqueda inteligente
 */
import { useState, useEffect, useMemo } from 'react';
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
    limit: 10,
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

  // Normaliza texto para búsqueda (quita acentos y convierte a minúsculas)
  const normalizeText = (text) => {
    if (!text) return '';
    return text
      .toLowerCase()
      .normalize('NFD')
      .replace(/[\u0300-\u036f]/g, '');
  };

  // Búsqueda inteligente - busca en múltiples campos
  const filteredAssociates = useMemo(() => {
    if (!filters.search.trim()) return associates;

    const searchTerms = normalizeText(filters.search).split(/\s+/).filter(Boolean);

    return associates.filter((assoc) => {
      // Campos donde buscar
      const searchableText = normalizeText([
        assoc.username,
        assoc.full_name,
        assoc.user_id?.toString(),
        assoc.id?.toString(),
        assoc.email,
        assoc.phone_number,
      ].filter(Boolean).join(' '));

      // Todos los términos deben coincidir (búsqueda AND)
      return searchTerms.every(term => searchableText.includes(term));
    });
  }, [associates, filters.search]);

  // Totales calculados
  const totals = useMemo(() => {
    return filteredAssociates.reduce(
      (acc, assoc) => ({
        creditLimit: acc.creditLimit + (parseFloat(assoc.credit_limit) || 0),
        pendingPaymentsTotal: acc.pendingPaymentsTotal + (parseFloat(assoc.pending_payments_total) || 0),
        availableCredit: acc.availableCredit + (parseFloat(assoc.available_credit) || 0),
        consolidatedDebt: acc.consolidatedDebt + (parseFloat(assoc.consolidated_debt) || 0),
        pendingDebts: acc.pendingDebts + (parseInt(assoc.pending_debts_count) || 0),
      }),
      { creditLimit: 0, pendingPaymentsTotal: 0, availableCredit: 0, consolidatedDebt: 0, pendingDebts: 0 }
    );
  }, [filteredAssociates]);

  // Porcentaje de uso global (pending_payments_total + consolidated_debt vs credit_limit)
  const totalUsed = totals.pendingPaymentsTotal + totals.consolidatedDebt;
  const globalUsagePercent = totals.creditLimit > 0
    ? ((totalUsed / totals.creditLimit) * 100).toFixed(1)
    : 0;

  const totalPages = Math.ceil(pagination.total / pagination.limit);
  const currentPage = Math.floor(pagination.offset / pagination.limit) + 1;

  // Función para cambiar página
  const goToPage = (page) => {
    setPagination(prev => ({ ...prev, offset: (page - 1) * prev.limit }));
  };

  if (loading) {
    return (
      <div className="associates-page">
        <div className="page-header">
          <h1>Gestión de Asociados</h1>
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
    <div className="associates-page">
      {/* Header */}
      <div className="page-header">
        <div className="header-info">
          <h1>Gestión de Asociados</h1>
          <p className="header-subtitle">
            Administra las líneas de crédito y deudas de los asociados
          </p>
        </div>
        <button className="btn-primary-action" onClick={handleCreateAssociate}>
          <span className="btn-icon">+</span>
          Nuevo Asociado
        </button>
      </div>

      {/* Resumen Financiero */}
      <div className="financial-summary">
        <div className="summary-main">
          <div className="summary-card summary-highlight">
            <div className="summary-icon">👥</div>
            <div className="summary-content">
              <span className="summary-value">{pagination.total}</span>
              <span className="summary-label">Asociados Activos</span>
            </div>
          </div>

          <div className="summary-card">
            <div className="summary-content">
              <span className="summary-value">{formatCurrency(totals.creditLimit)}</span>
              <span className="summary-label">Línea de Crédito Total</span>
            </div>
          </div>

          <div className="summary-card">
            <div className="summary-content">
              <span className="summary-value text-used">{formatCurrency(totals.creditUsed)}</span>
              <span className="summary-label">Crédito Utilizado</span>
            </div>
            <div className="summary-bar">
              <div
                className="summary-bar-fill"
                style={{ width: `${Math.min(100, globalUsagePercent)}%` }}
              />
            </div>
            <span className="summary-percent">{globalUsagePercent}% usado</span>
          </div>

          <div className="summary-card">
            <div className="summary-content">
              <span className="summary-value text-available">{formatCurrency(totals.creditAvailable)}</span>
              <span className="summary-label">Disponible</span>
            </div>
          </div>
        </div>

        {(totals.consolidatedDebt > 0 || totals.pendingDebts > 0) && (
          <div className="summary-alert">
            <div className="alert-item">
              <span className="alert-label">Deuda pendiente:</span>
              <span className="alert-value">{formatCurrency(totals.consolidatedDebt)}</span>
            </div>
            {totals.pendingDebts > 0 && (
              <div className="alert-item">
                <span className="alert-label">Períodos con deuda:</span>
                <span className="alert-value alert-count">{totals.pendingDebts}</span>
              </div>
            )}
          </div>
        )}
      </div>

      {/* Filtros */}
      <div className="filters-bar">
        <div className="search-container">
          <span className="search-icon">🔍</span>
          <input
            type="text"
            placeholder="Buscar por nombre, usuario, ID, email o teléfono..."
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
              <th className="col-name">Asociado</th>
              <th className="col-money">Línea de Crédito</th>
              <th className="col-money">Pagos Pendientes</th>
              <th className="col-money">Disponible</th>
              <th className="col-usage">Uso</th>
              <th className="col-debt">Deuda Consolidada</th>
              <th className="col-status">Estado</th>
              <th className="col-actions">Acciones</th>
            </tr>
          </thead>
          <tbody>
            {filteredAssociates.length === 0 ? (
              <tr>
                <td colSpan="9" className="empty-state">
                  <div className="empty-content">
                    <span className="empty-icon">📋</span>
                    <p>No se encontraron asociados</p>
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
              filteredAssociates.map((assoc) => {
                // Calcular uso de crédito: (pending_payments_total + consolidated_debt) / credit_limit
                const totalUsed = (parseFloat(assoc.pending_payments_total) || 0) + (parseFloat(assoc.consolidated_debt) || 0);
                const usagePercent = assoc.credit_limit
                  ? (totalUsed / assoc.credit_limit) * 100
                  : 0;
                const usageLevel = usagePercent > 90 ? 'critical' : usagePercent > 70 ? 'warning' : 'normal';

                return (
                  <tr key={assoc.id}>
                    <td className="col-id">
                      <span className="id-badge">{assoc.id}</span>
                    </td>
                    <td className="col-name">
                      <div className="associate-info">
                        <span className="associate-name">{assoc.full_name || 'Sin nombre'}</span>
                        <span className="associate-username">@{assoc.username || 'N/A'}</span>
                      </div>
                    </td>
                    <td className="col-money">
                      <span className="money-value">{formatCurrency(assoc.credit_limit)}</span>
                    </td>
                    <td className="col-money">
                      <span className="money-value text-used">{formatCurrency(assoc.pending_payments_total)}</span>
                    </td>
                    <td className="col-money">
                      <span className="money-value text-available">{formatCurrency(assoc.available_credit)}</span>
                    </td>
                    <td className="col-usage">
                      <div className="usage-indicator">
                        <div className={`usage-bar-container usage-bg-${usageLevel}`}>
                          <div
                            className={`usage-bar-fill usage-${usageLevel}`}
                            style={{ width: `${Math.min(100, usagePercent)}%` }}
                          />
                          <span className="usage-percent-inside">
                            {usagePercent.toFixed(0)}%
                          </span>
                        </div>
                      </div>
                    </td>
                    <td className="col-debt">
                      {(assoc.consolidated_debt || 0) > 0 || (assoc.pending_debts_count || 0) > 0 ? (
                        <div className="debt-info">
                          <span className="debt-amount">{formatCurrency(assoc.consolidated_debt || 0)}</span>
                          {assoc.pending_debts_count > 0 && (
                            <span className="debt-count">{assoc.pending_debts_count} período(s)</span>
                          )}
                        </div>
                      ) : (
                        <span className="debt-clear">Sin deuda</span>
                      )}
                    </td>
                    <td className="col-status">
                      <span className={`status-pill ${assoc.active ? 'active' : 'inactive'}`}>
                        {assoc.active ? 'Activo' : 'Inactivo'}
                      </span>
                    </td>
                    <td className="col-actions">
                      <button
                        className="btn-action"
                        onClick={() => handleViewDetail(assoc.id)}
                      >
                        Detalles
                      </button>
                    </td>
                  </tr>
                );
              })
            )}
          </tbody>
        </table>
      </div>

      {/* Paginación */}
      {totalPages > 1 && (
        <div className="pagination-bar">
          <div className="pagination-info">
            Mostrando {filteredAssociates.length} de {pagination.total} asociados
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
