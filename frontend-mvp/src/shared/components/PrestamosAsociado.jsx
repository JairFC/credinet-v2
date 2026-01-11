import React, { useState, useEffect } from 'react';
import { apiClient } from '../api/apiClient';
import ENDPOINTS from '../api/endpoints';

/**
 * PrestamosAsociado - Lista compacta de préstamos de un asociado
 * 
 * Muestra:
 * - Contadores por estado (activos, aprobados, etc.)
 * - Lista paginada de préstamos con filtro por estado
 * - Información resumida de cada préstamo
 */
const PrestamosAsociado = ({ associateUserId }) => {
  const [loans, setLoans] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [filter, setFilter] = useState('all'); // all, active, approved, completed, cancelled
  const [page, setPage] = useState(0);
  const [total, setTotal] = useState(0);
  const [stats, setStats] = useState({
    total: 0,
    active: 0,
    approved: 0,
    completed: 0,
    cancelled: 0,
    totalAmount: 0,
    totalPending: 0
  });

  const PAGE_SIZE = 5;

  useEffect(() => {
    if (associateUserId) {
      fetchLoans();
    }
  }, [associateUserId, filter, page]);

  const fetchLoans = async () => {
    try {
      setLoading(true);

      // Mapear filtro a status_id (según loan_statuses table)
      // 1=PENDING, 2=ACTIVE, 4=COMPLETED, 5=PAID, 6=DEFAULTED, 7=REJECTED, 8=CANCELLED, 9=IN_AGREEMENT
      const statusMap = {
        'all': null,
        'active': 2,      // ACTIVE
        'completed': 4,   // COMPLETED
        'cancelled': 8    // CANCELLED
      };

      const params = new URLSearchParams({
        associate_user_id: associateUserId,
        limit: PAGE_SIZE,
        offset: page * PAGE_SIZE
      });

      if (statusMap[filter]) {
        params.append('status_id', statusMap[filter]);
      }

      const response = await apiClient.get(`${ENDPOINTS.loans.list}?${params}`);

      if (response.data) {
        setLoans(response.data.items || []);
        setTotal(response.data.total || 0);

        // Si es la primera carga (all), calcular stats
        if (filter === 'all' && page === 0) {
          calculateStats(response.data.items || [], response.data.total || 0);
        }
      }
    } catch (err) {
      setError('Error al cargar préstamos: ' + (err.response?.data?.detail || err.message));
    } finally {
      setLoading(false);
    }
  };

  const calculateStats = async (items, total) => {
    // Obtener conteos por estado (IDs según loan_statuses table)
    // 1=PENDING, 2=ACTIVE, 4=COMPLETED, 5=PAID, 6=DEFAULTED, 7=REJECTED, 8=CANCELLED, 9=IN_AGREEMENT
    try {
      const [activeRes, completedRes, cancelledRes] = await Promise.all([
        apiClient.get(`${ENDPOINTS.loans.list}?associate_user_id=${associateUserId}&status_id=2&limit=1`),
        apiClient.get(`${ENDPOINTS.loans.list}?associate_user_id=${associateUserId}&status_id=4&limit=1`),
        apiClient.get(`${ENDPOINTS.loans.list}?associate_user_id=${associateUserId}&status_id=8&limit=1`)
      ]);

      const totalAmount = items.reduce((sum, l) => sum + (parseFloat(l.amount) || 0), 0);

      setStats({
        total: total,
        active: activeRes.data?.total || 0,
        completed: completedRes.data?.total || 0,
        cancelled: cancelledRes.data?.total || 0,
        totalAmount
      });
    } catch (err) {
      console.error('Error calculando stats:', err);
    }
  };

  const formatCurrency = (amount) => {
    return new Intl.NumberFormat('es-MX', {
      style: 'currency',
      currency: 'MXN'
    }).format(amount || 0);
  };

  const formatDate = (dateStr) => {
    if (!dateStr) return '—';
    return new Date(dateStr).toLocaleDateString('es-MX', {
      day: '2-digit',
      month: 'short',
      year: 'numeric'
    });
  };

  const getStatusBadge = (statusId) => {
    // IDs según loan_statuses table:
    // 1=PENDING, 2=ACTIVE, 4=COMPLETED, 5=PAID, 6=DEFAULTED, 7=REJECTED, 8=CANCELLED, 9=IN_AGREEMENT
    const statuses = {
      1: { label: 'Pendiente', color: '#FFC107', icon: '⏳' },
      2: { label: 'Activo', color: '#28A745', icon: '💰' },
      4: { label: 'Completado', color: '#00C853', icon: '✅' },
      5: { label: 'Pagado', color: '#00C853', icon: '✅' },
      6: { label: 'En Mora', color: '#DC3545', icon: '⚠️' },
      7: { label: 'Rechazado', color: '#9E9E9E', icon: '✗' },
      8: { label: 'Cancelado', color: '#757575', icon: '🚫' },
      9: { label: 'En Convenio', color: '#FF9800', icon: '📋' }
    };
    return statuses[statusId] || { label: 'Desconocido', color: '#9E9E9E', icon: '?' };
  };

  const totalPages = Math.ceil(total / PAGE_SIZE);

  if (!associateUserId) {
    return (
      <div className="alert alert-warning">
        No se proporcionó ID de usuario asociado
      </div>
    );
  }

  return (
    <div style={{ padding: '16px' }}>
      {/* Contadores Rápidos */}
      <div style={{
        display: 'grid',
        gridTemplateColumns: 'repeat(auto-fit, minmax(100px, 1fr))',
        gap: '12px',
        marginBottom: '20px'
      }}>
        <div
          onClick={() => { setFilter('all'); setPage(0); }}
          style={{
            padding: '12px',
            borderRadius: '8px',
            backgroundColor: filter === 'all' ? 'var(--color-primary)' : 'var(--color-surface-secondary)',
            color: filter === 'all' ? 'white' : 'inherit',
            cursor: 'pointer',
            textAlign: 'center',
            transition: 'all 0.2s'
          }}
        >
          <div style={{ fontSize: '24px', fontWeight: 'bold' }}>{stats.total}</div>
          <div style={{ fontSize: '11px', opacity: 0.8 }}>Total</div>
        </div>

        <div
          onClick={() => { setFilter('active'); setPage(0); }}
          style={{
            padding: '12px',
            borderRadius: '8px',
            backgroundColor: filter === 'active' ? '#28A745' : 'var(--color-surface-secondary)',
            color: filter === 'active' ? 'white' : 'inherit',
            cursor: 'pointer',
            textAlign: 'center',
            transition: 'all 0.2s'
          }}
        >
          <div style={{ fontSize: '24px', fontWeight: 'bold' }}>{stats.active}</div>
          <div style={{ fontSize: '11px', opacity: 0.8 }}>💰 Activos</div>
        </div>

        <div
          onClick={() => { setFilter('completed'); setPage(0); }}
          style={{
            padding: '12px',
            borderRadius: '8px',
            backgroundColor: filter === 'completed' ? '#6C757D' : 'var(--color-surface-secondary)',
            color: filter === 'completed' ? 'white' : 'inherit',
            cursor: 'pointer',
            textAlign: 'center',
            transition: 'all 0.2s'
          }}
        >
          <div style={{ fontSize: '24px', fontWeight: 'bold' }}>{stats.completed}</div>
          <div style={{ fontSize: '11px', opacity: 0.8 }}>✅ Completados</div>
        </div>

        <div
          onClick={() => { setFilter('cancelled'); setPage(0); }}
          style={{
            padding: '12px',
            borderRadius: '8px',
            backgroundColor: filter === 'cancelled' ? '#343A40' : 'var(--color-surface-secondary)',
            color: filter === 'cancelled' ? 'white' : 'inherit',
            cursor: 'pointer',
            textAlign: 'center',
            transition: 'all 0.2s'
          }}
        >
          <div style={{ fontSize: '24px', fontWeight: 'bold' }}>{stats.cancelled}</div>
          <div style={{ fontSize: '11px', opacity: 0.8 }}>✗ Cancelados</div>
        </div>
      </div>

      {/* Error */}
      {error && (
        <div className="alert alert-danger" style={{ marginBottom: '16px' }}>
          {error}
        </div>
      )}

      {/* Lista de Préstamos */}
      {loading ? (
        <div style={{ textAlign: 'center', padding: '20px' }}>
          ⏳ Cargando préstamos...
        </div>
      ) : loans.length === 0 ? (
        <div style={{
          textAlign: 'center',
          padding: '30px',
          backgroundColor: 'var(--color-surface-secondary)',
          borderRadius: '8px'
        }}>
          📭 No hay préstamos {filter !== 'all' ? `en estado "${filter}"` : ''}
        </div>
      ) : (
        <>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
            {loans.map(loan => {
              const status = getStatusBadge(loan.status_id);
              return (
                <div
                  key={loan.id}
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'space-between',
                    padding: '12px 16px',
                    backgroundColor: 'var(--color-surface-secondary)',
                    borderRadius: '8px',
                    borderLeft: `4px solid ${status.color}`,
                    cursor: 'pointer',
                    transition: 'transform 0.1s'
                  }}
                  onClick={() => window.open(`/prestamos/${loan.id}`, '_blank')}
                  onMouseEnter={(e) => e.currentTarget.style.transform = 'translateX(4px)'}
                  onMouseLeave={(e) => e.currentTarget.style.transform = 'translateX(0)'}
                >
                  <div style={{ flex: 1 }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '4px' }}>
                      <span style={{ fontWeight: '600', fontSize: '14px' }}>
                        #{loan.id}
                      </span>
                      <span style={{
                        padding: '2px 8px',
                        borderRadius: '4px',
                        backgroundColor: status.color,
                        color: 'white',
                        fontSize: '11px',
                        fontWeight: '600'
                      }}>
                        {status.icon} {status.label}
                      </span>
                    </div>
                    <div style={{ fontSize: '13px', opacity: 0.8 }}>
                      👤 {loan.client_name || 'Cliente'} • {loan.term_biweeks} quincenas
                    </div>
                  </div>

                  <div style={{ textAlign: 'right' }}>
                    <div style={{ fontWeight: '600', fontSize: '16px', color: 'var(--color-primary)' }}>
                      {formatCurrency(loan.amount)}
                    </div>
                    <div style={{ fontSize: '11px', opacity: 0.6 }}>
                      {formatDate(loan.created_at)}
                    </div>
                  </div>
                </div>
              );
            })}
          </div>

          {/* Paginación */}
          {totalPages > 1 && (
            <div style={{
              display: 'flex',
              justifyContent: 'center',
              alignItems: 'center',
              gap: '8px',
              marginTop: '16px'
            }}>
              <button
                onClick={() => setPage(p => Math.max(0, p - 1))}
                disabled={page === 0}
                style={{
                  padding: '6px 12px',
                  border: '1px solid var(--color-border)',
                  borderRadius: '4px',
                  backgroundColor: page === 0 ? 'transparent' : 'var(--color-surface-secondary)',
                  cursor: page === 0 ? 'not-allowed' : 'pointer',
                  opacity: page === 0 ? 0.5 : 1
                }}
              >
                ← Anterior
              </button>

              <span style={{ fontSize: '13px', padding: '0 12px' }}>
                Página {page + 1} de {totalPages}
              </span>

              <button
                onClick={() => setPage(p => Math.min(totalPages - 1, p + 1))}
                disabled={page >= totalPages - 1}
                style={{
                  padding: '6px 12px',
                  border: '1px solid var(--color-border)',
                  borderRadius: '4px',
                  backgroundColor: page >= totalPages - 1 ? 'transparent' : 'var(--color-surface-secondary)',
                  cursor: page >= totalPages - 1 ? 'not-allowed' : 'pointer',
                  opacity: page >= totalPages - 1 ? 0.5 : 1
                }}
              >
                Siguiente →
              </button>
            </div>
          )}

          {/* Total mostrado */}
          <div style={{
            textAlign: 'center',
            fontSize: '12px',
            opacity: 0.6,
            marginTop: '12px'
          }}>
            Mostrando {loans.length} de {total} préstamos
          </div>
        </>
      )}
    </div>
  );
};

export default PrestamosAsociado;
