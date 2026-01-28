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

  // Cargar asociados cuando cambia la página, filtros o búsqueda
  useEffect(() => {
    loadAssociates();
  }, [currentPage, activeOnly, debouncedSearch]);

  const loadAssociates = async () => {
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

      const response = await associatesService.getAll(params);

      const data = response.data;
      setAssociates(Array.isArray(data.items) ? data.items : []);
      setTotalItems(data.total || 0);
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

  // Totales calculados
  const totals = useMemo(() => {
    return associates.reduce(
      (acc, assoc) => ({
        creditLimit: acc.creditLimit + (parseFloat(assoc.credit_limit) || 0),
        pendingPaymentsTotal: acc.pendingPaymentsTotal + (parseFloat(assoc.pending_payments_total) || 0),
        availableCredit: acc.availableCredit + (parseFloat(assoc.available_credit) || 0),
        consolidatedDebt: acc.consolidatedDebt + (parseFloat(assoc.consolidated_debt) || 0),
        pendingDebts: acc.pendingDebts + (parseInt(assoc.pending_debts_count) || 0),
      }),
      { creditLimit: 0, pendingPaymentsTotal: 0, availableCredit: 0, consolidatedDebt: 0, pendingDebts: 0 }
    );
  }, [associates]);

  // Porcentaje de uso global (pending_payments_total + consolidated_debt vs credit_limit)
  const totalUsed = totals.pendingPaymentsTotal + totals.consolidatedDebt;
  const globalUsagePercent = totals.creditLimit > 0
    ? ((totalUsed / totals.creditLimit) * 100).toFixed(1)
    : 0;

  const totalPages = Math.ceil(totalItems / itemsPerPage);

  // Función para cambiar página
  const goToPage = (page) => {
    setCurrentPage(page);
  };

  // Solo mostrar loading inicial, no en búsquedas subsecuentes
  const isInitialLoading = loading && associates.length === 0 && !debouncedSearch;

  if (isInitialLoading) {
    return (
      <div className="associates-page">
        <div className="loading-screen">
          <div className="loading-content">
            <div className="loading-spinner">
              <div className="spinner-ring"></div>
              <div className="spinner-ring"></div>
              <div className="spinner-ring"></div>
            </div>
            <h2 className="loading-title">Cargando asociados...</h2>
            <p className="loading-subtitle">Por favor espere</p>
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
              <span className="summary-value">{totalItems}</span>
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
            {associates.length === 0 ? (
              <tr>
                <td colSpan="9" className="empty-state">
                  <div className="empty-content">
                    <span className="empty-icon">📋</span>
                    <p>No se encontraron asociados</p>
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
              associates.map((assoc) => {
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
            Mostrando {associates.length} de {totalItems} asociados
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
