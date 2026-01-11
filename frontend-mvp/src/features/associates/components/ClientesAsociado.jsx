/**
 * ClientesAsociado - Lista de clientes (borrowers) de un asociado
 * 
 * Muestra todos los clientes que han solicitado préstamos con este asociado,
 * incluyendo estadísticas de relación y estado actual.
 */

import { useState, useEffect, useCallback } from 'react';
import { apiClient } from '../../../shared/api/apiClient';
import './ClientesAsociado.css';

const ClientesAsociado = ({ associateId }) => {
  const [clients, setClients] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [statusFilter, setStatusFilter] = useState('');
  const [pagination, setPagination] = useState({
    total: 0,
    limit: 5,
    offset: 0
  });

  const fetchClients = useCallback(async () => {
    if (!associateId) return;

    try {
      setLoading(true);
      setError('');

      let url = `/api/v1/associates/${associateId}/clients?limit=${pagination.limit}&offset=${pagination.offset}`;
      if (statusFilter) {
        url += `&status_filter=${statusFilter}`;
      }

      const response = await apiClient.get(url);
      console.log('📥 Clientes del asociado:', response.data);

      if (response.data?.success && response.data?.data) {
        setClients(response.data.data.clients || []);
        setPagination(prev => ({
          ...prev,
          total: response.data.data.total || 0
        }));
      } else {
        setClients([]);
      }
    } catch (err) {
      console.error('❌ Error cargando clientes:', err);
      setError('Error al cargar clientes: ' + (err.response?.data?.detail || err.message));
    } finally {
      setLoading(false);
    }
  }, [associateId, statusFilter, pagination.limit, pagination.offset]);

  useEffect(() => {
    fetchClients();
  }, [fetchClients]);

  const handleStatusFilterChange = (e) => {
    setStatusFilter(e.target.value);
    setPagination(prev => ({ ...prev, offset: 0 })); // Reset to first page
  };

  const handleNextPage = () => {
    if (pagination.offset + pagination.limit < pagination.total) {
      setPagination(prev => ({
        ...prev,
        offset: prev.offset + prev.limit
      }));
    }
  };

  const handlePrevPage = () => {
    if (pagination.offset > 0) {
      setPagination(prev => ({
        ...prev,
        offset: Math.max(0, prev.offset - prev.limit)
      }));
    }
  };

  const getStatusBadge = (status) => {
    const statusConfig = {
      'ACTIVE': { label: 'Activo', class: 'badge-primary' },
      'GOOD_STANDING': { label: 'Al corriente', class: 'badge-success' },
      'DEFAULTED': { label: 'Moroso', class: 'badge-danger' },
      'INACTIVE': { label: 'Inactivo', class: 'badge-secondary' }
    };
    const config = statusConfig[status] || { label: status, class: 'badge-secondary' };
    return <span className={`badge ${config.class}`}>{config.label}</span>;
  };

  const formatCurrency = (value) => {
    return new Intl.NumberFormat('es-MX', {
      style: 'currency',
      currency: 'MXN'
    }).format(value || 0);
  };

  const formatDate = (dateStr) => {
    if (!dateStr) return '-';
    return new Date(dateStr).toLocaleDateString('es-MX', {
      day: '2-digit',
      month: 'short',
      year: 'numeric'
    });
  };

  if (loading && clients.length === 0) {
    return (
      <div className="clientes-asociado">
        <div className="loading-spinner">
          ⏳ Cargando clientes...
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="clientes-asociado">
        <div className="error-message">
          ⚠️ {error}
          <button onClick={fetchClients} className="btn-retry">Reintentar</button>
        </div>
      </div>
    );
  }

  const currentPage = Math.floor(pagination.offset / pagination.limit) + 1;
  const totalPages = Math.ceil(pagination.total / pagination.limit);

  return (
    <div className="clientes-asociado">
      {/* Filtros y controles */}
      <div className="clientes-toolbar">
        <div className="filter-group">
          <label htmlFor="status-filter">Filtrar por estado:</label>
          <select
            id="status-filter"
            value={statusFilter}
            onChange={handleStatusFilterChange}
            className="filter-select"
          >
            <option value="">Todos</option>
            <option value="ACTIVE">Con préstamo activo</option>
            <option value="GOOD_STANDING">Al corriente</option>
            <option value="DEFAULTED">Morosos</option>
          </select>
        </div>

        <div className="stats-summary">
          <span className="total-count">
            📊 {pagination.total} cliente{pagination.total !== 1 ? 's' : ''} encontrado{pagination.total !== 1 ? 's' : ''}
          </span>
        </div>
      </div>

      {/* Tabla de clientes */}
      {clients.length === 0 ? (
        <div className="empty-state">
          <span className="empty-icon">👥</span>
          <p>No se encontraron clientes{statusFilter ? ' con el filtro seleccionado' : ' para este asociado'}</p>
        </div>
      ) : (
        <>
          <div className="clientes-table-wrapper">
            <table className="clientes-table">
              <thead>
                <tr>
                  <th>Cliente</th>
                  <th>Contacto</th>
                  <th>Préstamos</th>
                  <th>Monto Total</th>
                  <th>Último Préstamo</th>
                  <th>Estado</th>
                </tr>
              </thead>
              <tbody>
                {clients.map((client) => (
                  <tr key={client.client_user_id}>
                    <td>
                      <div className="client-name">
                        <strong>{client.full_name}</strong>
                        <small className="curp">{client.curp || '-'}</small>
                      </div>
                    </td>
                    <td>
                      <div className="client-contact">
                        {client.phone_number && (
                          <span className="phone">📱 {client.phone_number}</span>
                        )}
                        {client.email && (
                          <span className="email">✉️ {client.email}</span>
                        )}
                      </div>
                    </td>
                    <td>
                      <div className="loan-stats">
                        <span className="total">Total: {client.total_loans}</span>
                        {client.active_loans > 0 && (
                          <span className="active badge-primary-small">
                            {client.active_loans} activo{client.active_loans !== 1 ? 's' : ''}
                          </span>
                        )}
                        {client.defaulted_loans > 0 && (
                          <span className="defaulted badge-danger-small">
                            {client.defaulted_loans} moroso{client.defaulted_loans !== 1 ? 's' : ''}
                          </span>
                        )}
                      </div>
                    </td>
                    <td className="amount-cell">
                      {formatCurrency(client.total_amount_loaned)}
                    </td>
                    <td>
                      {formatDate(client.last_loan_date)}
                    </td>
                    <td>
                      {getStatusBadge(client.client_status)}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {/* Paginación */}
          {totalPages > 1 && (
            <div className="pagination-controls">
              <button
                onClick={handlePrevPage}
                disabled={pagination.offset === 0}
                className="btn-page"
              >
                ← Anterior
              </button>
              <span className="page-info">
                Página {currentPage} de {totalPages}
              </span>
              <button
                onClick={handleNextPage}
                disabled={pagination.offset + pagination.limit >= pagination.total}
                className="btn-page"
              >
                Siguiente →
              </button>
            </div>
          )}
        </>
      )}
    </div>
  );
};

export default ClientesAsociado;
