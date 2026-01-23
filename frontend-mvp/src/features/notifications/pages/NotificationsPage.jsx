import { useState, useEffect } from 'react';
import { useAuth } from '@/app/providers/AuthProvider';
import { apiClient } from '@/shared/api/apiClient';
import './NotificationsPage.css';

/**
 * Página de configuración de notificaciones del sistema.
 * Muestra el estado de los canales y permite enviar notificaciones de prueba.
 */
const NotificationsPage = () => {
  const { user } = useAuth();
  const [status, setStatus] = useState({
    telegram: { configured: false, lastTest: null },
    discord: { configured: false, lastTest: null },
    email: { configured: false, lastTest: null }
  });
  const [health, setHealth] = useState({ telegram: 'unknown', discord: 'unknown', email: 'unknown' });
  const [testing, setTesting] = useState(null);
  const [testResult, setTestResult] = useState(null);
  const [logs, setLogs] = useState([]);

  useEffect(() => {
    fetchNotificationStatus();
    fetchRecentLogs();
    fetchHealth();
    // Actualizar health cada 30 segundos
    const interval = setInterval(fetchHealth, 30000);
    return () => clearInterval(interval);
  }, []);

  const fetchHealth = async () => {
    try {
      const response = await fetch('/api/v1/notifications/health');
      if (response.ok) {
        const data = await response.json();
        setHealth(data);
      }
    } catch {
      setHealth({ telegram: 'error', discord: 'error', email: 'error' });
    }
  };

  const fetchNotificationStatus = async () => {
    try {
      const response = await apiClient.get('/api/v1/notifications/status');
      if (response.status === 200) {
        setStatus(response.data);
      }
    } catch (error) {
      console.log('Error obteniendo estado de notificaciones:', error);
      // Fallback al endpoint de health (sin auth)
      try {
        const healthRes = await fetch('/api/v1/notifications/health');
        if (healthRes.ok) {
          const health = await healthRes.json();
          setStatus({
            telegram: { configured: health.telegram === 'ok', lastTest: null },
            discord: { configured: health.discord === 'ok', lastTest: null },
            email: { configured: health.email === 'ok', lastTest: null }
          });
        }
      } catch {
        // Estado por defecto
        setStatus({
          telegram: { configured: true, lastTest: null },
          discord: { configured: true, lastTest: null },
          email: { configured: false, lastTest: null }
        });
      }
    }
  };

  const fetchRecentLogs = async () => {
    // Mock de logs recientes - en producción vendría del backend
    setLogs([
      { id: 1, type: 'success', title: 'Backup Completado', timestamp: new Date().toISOString(), channels: ['telegram', 'discord'] },
      { id: 2, type: 'info', title: 'Pago Registrado', timestamp: new Date(Date.now() - 3600000).toISOString(), channels: ['discord'] },
      { id: 3, type: 'success', title: 'Préstamo Aprobado', timestamp: new Date(Date.now() - 7200000).toISOString(), channels: ['telegram', 'discord'] },
    ]);
  };

  const sendTestNotification = async (channel) => {
    setTesting(channel);
    setTestResult(null);
    
    try {
      const response = await apiClient.post('/api/v1/notifications/test', { 
        channel,
        title: '🧪 Prueba desde UI',
        message: `Notificación de prueba enviada por ${user?.username || 'Admin'} desde la interfaz web.`
      });
      
      if (response.status === 200 && response.data.success) {
        setTestResult({ success: true, channel, message: response.data.message || 'Notificación enviada correctamente' });
        fetchNotificationStatus();
      } else {
        setTestResult({ success: false, channel, message: response.data.message || 'Error al enviar notificación' });
      }
    } catch (error) {
      console.error('Error enviando notificación de prueba:', error);
      const errorMsg = error.response?.data?.detail || error.message || 'Error al enviar notificación';
      setTestResult({ success: false, channel, message: errorMsg });
    }
    
    setTesting(null);
  };

  const getChannelIcon = (channel) => {
    switch(channel) {
      case 'telegram': return '📱';
      case 'discord': return '🎮';
      case 'email': return '📧';
      default: return '🔔';
    }
  };

  const getTypeIcon = (type) => {
    switch(type) {
      case 'success': return '✅';
      case 'error': return '❌';
      case 'warning': return '⚠️';
      case 'info': return 'ℹ️';
      default: return '🔔';
    }
  };

  const formatTime = (timestamp) => {
    const date = new Date(timestamp);
    return date.toLocaleString('es-MX', { 
      timeZone: 'America/Chihuahua',
      dateStyle: 'short',
      timeStyle: 'short'
    });
  };

  return (
    <div className="notifications-page">
      <div className="page-header">
        <div className="header-main">
          <h1>🔔 Centro de Notificaciones</h1>
          <div className="health-leds">
            <div className={`led led-${health.telegram}`} title={`Telegram: ${health.telegram}`}>
              📱 <span className="led-dot"></span>
            </div>
            <div className={`led led-${health.discord}`} title={`Discord: ${health.discord}`}>
              🎮 <span className="led-dot"></span>
            </div>
            <div className={`led led-${health.email}`} title={`Email: ${health.email}`}>
              📧 <span className="led-dot"></span>
            </div>
          </div>
        </div>
        <p className="subtitle">Configuración y monitoreo de alertas del sistema</p>
      </div>

      {/* Estado de canales */}
      <section className="section channels-section">
        <h2>📡 Canales de Notificación</h2>
        <div className="channels-grid">
          {/* Telegram */}
          <div className={`channel-card ${status.telegram.configured ? 'active' : 'inactive'}`}>
            <div className="channel-header">
              <span className="channel-icon">📱</span>
              <h3>Telegram</h3>
              <span className={`status-badge ${status.telegram.configured ? 'success' : 'warning'}`}>
                {status.telegram.configured ? '✓ Activo' : '○ No configurado'}
              </span>
            </div>
            <div className="channel-body">
              <p>Notificaciones instantáneas a chat personal y grupo.</p>
              <ul className="channel-features">
                <li>✓ Chat personal</li>
                <li>✓ Grupo de equipo</li>
                <li>✓ Dual timezone (Chihuahua + UTC)</li>
              </ul>
            </div>
            <div className="channel-footer">
              <button 
                className="btn-test"
                onClick={() => sendTestNotification('telegram')}
                disabled={testing === 'telegram' || !status.telegram.configured}
              >
                {testing === 'telegram' ? '⏳ Enviando...' : '🧪 Probar'}
              </button>
            </div>
          </div>

          {/* Discord */}
          <div className={`channel-card ${status.discord.configured ? 'active' : 'inactive'}`}>
            <div className="channel-header">
              <span className="channel-icon">🎮</span>
              <h3>Discord</h3>
              <span className={`status-badge ${status.discord.configured ? 'success' : 'warning'}`}>
                {status.discord.configured ? '✓ Activo' : '○ No configurado'}
              </span>
            </div>
            <div className="channel-body">
              <p>Alertas al canal #alerts del servidor Discord.</p>
              <ul className="channel-features">
                <li>✓ Webhook configurado</li>
                <li>✓ Formato enriquecido</li>
                <li>✓ Historial permanente</li>
              </ul>
            </div>
            <div className="channel-footer">
              <button 
                className="btn-test"
                onClick={() => sendTestNotification('discord')}
                disabled={testing === 'discord' || !status.discord.configured}
              >
                {testing === 'discord' ? '⏳ Enviando...' : '🧪 Probar'}
              </button>
            </div>
          </div>

          {/* Email */}
          <div className={`channel-card ${status.email.configured ? 'active' : 'inactive'}`}>
            <div className="channel-header">
              <span className="channel-icon">📧</span>
              <h3>Email</h3>
              <span className={`status-badge ${status.email.configured ? 'success' : 'disabled'}`}>
                {status.email.configured ? '✓ Activo' : '○ Deshabilitado'}
              </span>
            </div>
            <div className="channel-body">
              <p>Notificaciones por correo electrónico (opcional).</p>
              <ul className="channel-features">
                <li className="muted">○ SMTP no configurado</li>
                <li className="muted">○ Requiere Gmail App Password</li>
              </ul>
            </div>
            <div className="channel-footer">
              <button 
                className="btn-test"
                disabled={true}
              >
                No disponible
              </button>
            </div>
          </div>
        </div>

        {testResult && (
          <div className={`test-result ${testResult.success ? 'success' : 'error'}`}>
            {testResult.success ? '✅' : '❌'} {testResult.message}
          </div>
        )}
      </section>

      {/* Tipos de eventos */}
      <section className="section events-section">
        <h2>📋 Eventos Notificados</h2>
        <div className="events-grid">
          <div className="event-card">
            <span className="event-icon">💾</span>
            <h4>Backups</h4>
            <p>Backup diario completado o fallido</p>
            <span className="event-channels">📱 🎮</span>
          </div>
          <div className="event-card">
            <span className="event-icon">📅</span>
            <h4>Cortes de Período</h4>
            <p>Ejecución automática días 8 y 23</p>
            <span className="event-channels">📱 🎮</span>
          </div>
          <div className="event-card">
            <span className="event-icon">✅</span>
            <h4>Préstamos Aprobados</h4>
            <p>Notificación al aprobar préstamos</p>
            <span className="event-channels">📱 🎮</span>
          </div>
          <div className="event-card">
            <span className="event-icon">💰</span>
            <h4>Pagos Registrados</h4>
            <p>Registro de pagos (solo grupo)</p>
            <span className="event-channels">🎮</span>
          </div>
          <div className="event-card">
            <span className="event-icon">🚀</span>
            <h4>Deploys</h4>
            <p>Actualizaciones del sistema</p>
            <span className="event-channels">📱 🎮</span>
          </div>
          <div className="event-card">
            <span className="event-icon">⚠️</span>
            <h4>Errores Críticos</h4>
            <p>Fallos en procesos automáticos</p>
            <span className="event-channels">📱 🎮</span>
          </div>
        </div>
      </section>

      {/* Historial reciente */}
      <section className="section history-section">
        <h2>📜 Historial Reciente</h2>
        <div className="history-list">
          {logs.map(log => (
            <div key={log.id} className={`history-item ${log.type}`}>
              <span className="history-icon">{getTypeIcon(log.type)}</span>
              <div className="history-content">
                <span className="history-title">{log.title}</span>
                <span className="history-time">{formatTime(log.timestamp)}</span>
              </div>
              <div className="history-channels">
                {log.channels.map(ch => (
                  <span key={ch} className="channel-badge">{getChannelIcon(ch)}</span>
                ))}
              </div>
            </div>
          ))}
        </div>
      </section>
    </div>
  );
};

export default NotificationsPage;
