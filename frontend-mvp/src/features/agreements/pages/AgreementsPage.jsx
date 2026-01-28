/**
 * Agreements List Page (Convenios)
 * 
 * ⚠️ IMPORTANTE: Los convenios son para ASOCIADOS, NO para clientes.
 * 
 * FLUJO DE NEGOCIO:
 * - Un convenio agrupa deudas de un ASOCIADO con CrediCuenta
 * - Se crea desde préstamos activos o deudas consolidadas
 * - El ASOCIADO paga cuotas mensuales a CrediCuenta
 * - Cada pago reduce su consolidated_debt y aumenta available_credit
 * - El convenio puede estar: ACTIVE, COMPLETED, DEFAULTED, CANCELLED
 */
import { useState, useEffect, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { agreementsService } from '@/shared/api/services/agreementsService';
import { formatDateTime } from '@/shared/utils/dateUtils';
import './AgreementsPage.css';

const STATUS_CONFIG = {
  DRAFT: { label: 'Borrador', color: 'default', icon: '📝' },
  ACTIVE: { label: 'Activo', color: 'success', icon: '✅' },
  COMPLETED: { label: 'Completado', color: 'info', icon: '🎉' },
  DEFAULTED: { label: 'Incumplido', color: 'danger', icon: '⚠️' },
  CANCELLED: { label: 'Cancelado', color: 'warning', icon: '❌' },
};

const AgreementsPage = () => {
  const navigate = useNavigate();
  const [agreements, setAgreements] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  
  // Filters
  const [statusFilter, setStatusFilter] = useState('');
  const [searchTerm, setSearchTerm] = useState('');
  
  // Pagination
  const [page, setPage] = useState(1);
  const [total, setTotal] = useState(0);
  const ITEMS_PER_PAGE = 10;

  // Stats
  const [stats, setStats] = useState({
    total: 0,
    active: 0,
    completed: 0,
    totalDebt: 0,
    totalPaid: 0,
  });

  const loadAgreements = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);
      
      const params = {
        limit: ITEMS_PER_PAGE,
        offset: (page - 1) * ITEMS_PER_PAGE,
        ...(statusFilter && { status: statusFilter }),
        ...(searchTerm && { search: searchTerm }),
      };
      
      const response = await agreementsService.getAgreements(params);
      const data = response.data;
      
      setAgreements(data.items || []);
      setTotal(data.total || 0);
      
      // Calculate stats from items (simplified, ideally from backend)
      const items = data.items || [];
      setStats({
        total: data.total || 0,
        active: items.filter(a => a.status === 'ACTIVE').length,
        completed: items.filter(a => a.status === 'COMPLETED').length,
        totalDebt: items.reduce((sum, a) => sum + parseFloat(a.total_debt_amount || 0), 0),
        totalPaid: items.reduce((sum, a) => sum + parseFloat(a.total_paid || 0), 0),
      });
    } catch (err) {
      console.error('Error loading agreements:', err);
      setError('Error al cargar los convenios');
    } finally {
      setLoading(false);
    }
  }, [page, statusFilter, searchTerm]);

  useEffect(() => {
    loadAgreements();
  }, [loadAgreements]);

  const formatCurrency = (amount) => {
    return `$${parseFloat(amount || 0).toLocaleString('es-MX', { minimumFractionDigits: 2 })}`;
  };

  const formatDate = (dateStr) => {
    if (!dateStr) return '-';
    // Usar formatDateTime para fechas de convenios (zona Chihuahua)
    return formatDateTime(dateStr, { includeTime: false });
  };

  const calculateProgress = (agreement) => {
    const total = parseFloat(agreement.total_debt_amount || 0);
    const paid = parseFloat(agreement.total_paid || 0);
    if (total === 0) return 0;
    return Math.min(100, Math.round((paid / total) * 100));
  };

  const totalPages = Math.ceil(total / ITEMS_PER_PAGE);

  return (
    <div className="agreements-page">
      <div className="page-header">
        <div className="header-content">
          <div className="header-left">
            <h1>📋 Convenios de Pago</h1>
            <p className="subtitle">Planes de pago para deudas de asociados</p>
          </div>
          <div className="header-actions">
            <button 
              className="btn btn-primary"
              onClick={() => navigate('/convenios/nuevo')}
            >
              ➕ Nuevo Convenio
            </button>
          </div>
        </div>
      </div>

      {/* Stats Cards */}
      <div className="stats-grid">
        <div className="stat-card">
          <div className="stat-icon">📊</div>
          <div className="stat-info">
            <span className="stat-value">{stats.total}</span>
            <span className="stat-label">Total Convenios</span>
          </div>
        </div>
        <div className="stat-card active">
          <div className="stat-icon">✅</div>
          <div className="stat-info">
            <span className="stat-value">{stats.active}</span>
            <span className="stat-label">Activos</span>
          </div>
        </div>
        <div className="stat-card completed">
          <div className="stat-icon">🎉</div>
          <div className="stat-info">
            <span className="stat-value">{stats.completed}</span>
            <span className="stat-label">Completados</span>
          </div>
        </div>
        <div className="stat-card debt">
          <div className="stat-icon">💰</div>
          <div className="stat-info">
            <span className="stat-value">{formatCurrency(stats.totalDebt)}</span>
            <span className="stat-label">Deuda Total</span>
          </div>
        </div>
      </div>

      {/* Filters */}
      <div className="filters-section">
        <div className="filter-group">
          <label>Estado:</label>
          <select 
            value={statusFilter} 
            onChange={(e) => { setStatusFilter(e.target.value); setPage(1); }}
          >
            <option value="">Todos</option>
            <option value="ACTIVE">Activo</option>
            <option value="COMPLETED">Completado</option>
            <option value="DEFAULTED">Incumplido</option>
            <option value="CANCELLED">Cancelado</option>
          </select>
        </div>
        <div className="filter-group search">
          <label>Buscar:</label>
          <input
            type="text"
            placeholder="Nombre del asociado o número de convenio..."
            value={searchTerm}
            onChange={(e) => { setSearchTerm(e.target.value); setPage(1); }}
          />
        </div>
        <button 
          className="btn btn-secondary" 
          onClick={() => { setStatusFilter(''); setSearchTerm(''); setPage(1); }}
        >
          🔄 Limpiar
        </button>
      </div>

      {/* Error Message */}
      {error && (
        <div className="error-message">
          <span>⚠️ {error}</span>
          <button onClick={loadAgreements}>Reintentar</button>
        </div>
      )}

      {/* Loading */}
      {loading && (
        <div className="loading-container">
          <div className="spinner"></div>
          <span>Cargando convenios...</span>
        </div>
      )}

      {/* Agreements Grid */}
      {!loading && !error && (
        <>
          {agreements.length === 0 ? (
            <div className="empty-state">
              <div className="empty-icon">📭</div>
              <h3>No hay convenios</h3>
              <p>No se encontraron convenios con los filtros seleccionados.</p>
              <button 
                className="btn btn-primary"
                onClick={() => navigate('/convenios/nuevo')}
              >
                ➕ Crear Primer Convenio
              </button>
            </div>
          ) : (
            <div className="agreements-grid">
              {agreements.map(agreement => {
                const progress = calculateProgress(agreement);
                const statusConfig = STATUS_CONFIG[agreement.status] || STATUS_CONFIG.DRAFT;
                
                return (
                  <div 
                    key={agreement.id} 
                    className={`agreement-card status-${agreement.status?.toLowerCase()}`}
                    onClick={() => navigate(`/convenios/${agreement.id}`)}
                  >
                    <div className="card-header">
                      <div className="agreement-number">
                        {agreement.agreement_number || `CONV-${agreement.id}`}
                      </div>
                      <span className={`status-badge ${statusConfig.color}`}>
                        {statusConfig.icon} {statusConfig.label}
                      </span>
                    </div>
                    
                    <div className="card-body">
                      <div className="associate-info">
                        <span className="label">Asociado:</span>
                        <span className="value">{agreement.associate_name || `#${agreement.associate_profile_id}`}</span>
                      </div>
                      
                      <div className="financial-info">
                        <div className="info-row">
                          <span className="label">Deuda total:</span>
                          <span className="value amount">{formatCurrency(agreement.total_debt_amount)}</span>
                        </div>
                        <div className="info-row">
                          <span className="label">
                            {agreement.payment_frequency === 'biweekly' ? 'Cuota quincenal:' : 'Cuota mensual:'}
                          </span>
                          <span className="value">{formatCurrency(agreement.period_payment_amount || agreement.monthly_payment_amount)}</span>
                        </div>
                        <div className="info-row">
                          <span className="label">Plazo:</span>
                          <span className="value">
                            {agreement.payment_plan_periods 
                              ? `${agreement.payment_plan_periods} quincenas` 
                              : `${agreement.payment_plan_months} meses`}
                          </span>
                        </div>
                      </div>
                      
                      <div className="progress-section">
                        <div className="progress-header">
                          <span>Progreso de pago</span>
                          <span>{progress}%</span>
                        </div>
                        <div className="progress-bar">
                          <div 
                            className="progress-fill" 
                            style={{ width: `${progress}%` }}
                          ></div>
                        </div>
                        <div className="progress-footer">
                          <span>Pagado: {formatCurrency(agreement.total_paid || 0)}</span>
                          <span>Pendiente: {formatCurrency((agreement.total_debt_amount || 0) - (agreement.total_paid || 0))}</span>
                        </div>
                      </div>
                    </div>
                    
                    <div className="card-footer">
                      <span className="date">
                        📅 {formatDate(agreement.start_date)} - {formatDate(agreement.end_date)}
                      </span>
                    </div>
                  </div>
                );
              })}
            </div>
          )}

          {/* Pagination */}
          {totalPages > 1 && (
            <div className="pagination">
              <button
                className="btn btn-sm"
                disabled={page === 1}
                onClick={() => setPage(p => p - 1)}
              >
                ← Anterior
              </button>
              <span className="page-info">
                Página {page} de {totalPages}
              </span>
              <button
                className="btn btn-sm"
                disabled={page === totalPages}
                onClick={() => setPage(p => p + 1)}
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

export default AgreementsPage;
