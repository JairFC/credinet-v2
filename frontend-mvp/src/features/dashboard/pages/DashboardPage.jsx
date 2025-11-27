import { useState, useEffect } from 'react';
import { useAuth } from '@/app/providers/AuthProvider';
import { dashboardService } from '@/shared/api/services';
import './DashboardPage.css';

const DashboardPage = () => {
  const { user } = useAuth();

  // State management
  const [stats, setStats] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  // Fetch dashboard data on mount
  useEffect(() => {
    const fetchDashboardData = async () => {
      try {
        setLoading(true);
        setError(null);

        const { data } = await dashboardService.getStats();
        setStats(data);
      } catch (err) {
        console.error('Error fetching dashboard stats:', err);
        setError(err.response?.data?.detail || 'Error al cargar estadísticas');
      } finally {
        setLoading(false);
      }
    };

    fetchDashboardData();
  }, []);

  // Transform backend data to UI cards
  const getStatsCards = () => {
    if (!stats) return [];

    return [
      {
        id: 1,
        title: 'Préstamos Activos',
        value: stats.active_loans.toString(),
        icon: '�',
        color: '#667eea',
        trend: `${stats.total_loans} total en sistema`
      },
      {
        id: 2,
        title: 'Pagos Pendientes',
        value: stats.pending_payments_count.toString(),
        icon: '⏰',
        color: '#f093fb',
        trend: `$${Number(stats.pending_payments_amount).toLocaleString('es-MX', { maximumFractionDigits: 0 })} pendientes`
      },
      {
        id: 3,
        title: 'Cobrado Este Mes',
        value: `$${Number(stats.collected_this_month).toLocaleString('es-MX', { maximumFractionDigits: 0 })}`,
        icon: '💵',
        color: '#4facfe',
        trend: `$${Number(stats.collected_today).toLocaleString('es-MX', { maximumFractionDigits: 0 })} hoy`
      },
      {
        id: 4,
        title: 'Total Clientes',
        value: stats.total_clients.toString(),
        icon: '�',
        color: '#43e97b',
        trend: `${stats.pending_loans} préstamos pendientes`
      }
    ];
  };

  // Fake recent activities for now (backend doesn't have this endpoint yet)
  const recentActivities = [
    {
      id: 1,
      type: 'payment',
      description: 'Sistema sincronizado con éxito',
      amount: `${stats?.pending_payments_count || 0} pagos`,
      time: 'Datos actualizados',
      icon: '✅'
    }
  ];

  const quickActions = [
    { id: 1, label: 'Nuevo Préstamo', icon: '➕', color: '#667eea' },
    { id: 2, label: 'Registrar Pago', icon: '💳', color: '#f093fb' },
    { id: 3, label: 'Ver Reportes', icon: '📊', color: '#4facfe' },
    { id: 4, label: 'Gestionar Asociados', icon: '👤', color: '#43e97b' }
  ];

  // Loading state
  if (loading) {
    return (
      <div className="dashboard-page">
        <div className="dashboard-header">
          <h1>Cargando dashboard... ⏳</h1>
        </div>
        <div className="stats-grid">
          {[1, 2, 3, 4].map(i => (
            <div key={i} className="stat-card skeleton">
              <div className="skeleton-content">
                <div className="skeleton-title"></div>
                <div className="skeleton-value"></div>
              </div>
            </div>
          ))}
        </div>
      </div>
    );
  }

  // Error state
  if (error) {
    return (
      <div className="dashboard-page">
        <div className="dashboard-header">
          <h1>Error al cargar dashboard ⚠️</h1>
          <p className="error-message">{error}</p>
        </div>
        <button
          className="retry-button"
          onClick={() => window.location.reload()}
        >
          Reintentar
        </button>
      </div>
    );
  }

  const statsCards = getStatsCards();

  return (
    <div className="dashboard-page">
      <div className="dashboard-header">
        <div className="welcome-section">
          <h1>¡Bienvenido, {user?.first_name}! 👋</h1>
          <p>Aquí está el resumen de tu sistema de préstamos</p>
          {stats?.overdue_payments_count > 0 && (
            <div className="alert-banner">
              ⚠️ {stats.overdue_payments_count} pagos vencidos
              (${Number(stats.overdue_payments_amount).toLocaleString('es-MX', { maximumFractionDigits: 0 })})
            </div>
          )}
        </div>
      </div>

      {/* Stats Cards */}
      <div className="stats-grid">
        {statsCards.map(stat => (
          <div key={stat.id} className="stat-card" style={{ borderLeftColor: stat.color }}>
            <div className="stat-icon" style={{ background: `${stat.color}20`, color: stat.color }}>
              {stat.icon}
            </div>
            <div className="stat-content">
              <p className="stat-title">{stat.title}</p>
              <h2 className="stat-value">{stat.value}</h2>
              <p className="stat-trend">{stat.trend}</p>
            </div>
          </div>
        ))}
      </div>

      {/* Quick Actions */}
      <div className="quick-actions-section">
        <h2 className="section-title">Acciones Rápidas</h2>
        <div className="quick-actions-grid">
          {quickActions.map(action => (
            <button
              key={action.id}
              className="quick-action-btn"
            >
              <span className="action-icon">{action.icon}</span>
              <span className="action-label">{action.label}</span>
            </button>
          ))}
        </div>
      </div>

      {/* Recent Activity */}
      <div className="recent-activity-section">
        <h2 className="section-title">Actividad Reciente</h2>
        <div className="activity-list">
          {recentActivities.map(activity => (
            <div key={activity.id} className={`activity-item ${activity.type}`}>
              <div className="activity-icon">{activity.icon}</div>
              <div className="activity-content">
                <p className="activity-description">{activity.description}</p>
                <p className="activity-time">{activity.time}</p>
              </div>
              <div className="activity-amount">{activity.amount}</div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
};

export default DashboardPage;
