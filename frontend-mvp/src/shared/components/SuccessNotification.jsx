/**
 * SuccessNotification - Componente de notificación elegante para acciones exitosas
 * 
 * Diseño premium con animaciones y auto-dismiss
 */
import React, { useEffect, useState } from 'react';
import { createPortal } from 'react-dom';
import './SuccessNotification.css';

const SuccessNotification = ({
  isOpen,
  onClose,
  title = 'Operación exitosa',
  message,
  icon = '✅',
  duration = 4000, // Auto-cerrar después de 4 segundos
  actions = [], // Botones de acción opcionales
  variant = 'success' // success, info, warning
}) => {
  const [isVisible, setIsVisible] = useState(false);
  const [isExiting, setIsExiting] = useState(false);

  useEffect(() => {
    if (isOpen) {
      setIsVisible(true);
      setIsExiting(false);

      // Auto-cerrar si duration > 0
      if (duration > 0) {
        const timer = setTimeout(() => {
          handleClose();
        }, duration);
        return () => clearTimeout(timer);
      }
    }
  }, [isOpen, duration]);

  const handleClose = () => {
    setIsExiting(true);
    setTimeout(() => {
      setIsVisible(false);
      onClose?.();
    }, 300); // Duración de la animación de salida
  };

  if (!isVisible) return null;

  const content = (
    <div className={`success-notification-overlay ${isExiting ? 'exiting' : ''}`}>
      <div className={`success-notification ${variant} ${isExiting ? 'exiting' : ''}`}>
        {/* Partículas de celebración */}
        <div className="celebration-particles">
          {[...Array(8)].map((_, i) => (
            <span key={i} className="particle" style={{ '--i': i }} />
          ))}
        </div>

        {/* Icono principal */}
        <div className="notification-icon">
          <div className="icon-circle">
            <span className="icon-emoji">{icon}</span>
          </div>
          <div className="icon-pulse" />
        </div>

        {/* Contenido */}
        <div className="notification-content">
          <h3 className="notification-title">{title}</h3>
          {message && <p className="notification-message">{message}</p>}
        </div>

        {/* Barra de progreso (auto-dismiss) */}
        {duration > 0 && (
          <div className="progress-bar">
            <div 
              className="progress-fill" 
              style={{ animationDuration: `${duration}ms` }}
            />
          </div>
        )}

        {/* Acciones */}
        <div className="notification-actions">
          {actions.map((action, idx) => (
            <button
              key={idx}
              className={`notification-btn ${action.variant || 'primary'}`}
              onClick={() => {
                action.onClick?.();
                if (action.closeOnClick !== false) {
                  handleClose();
                }
              }}
            >
              {action.icon && <span className="btn-icon">{action.icon}</span>}
              {action.label}
            </button>
          ))}
          {actions.length === 0 && (
            <button className="notification-btn primary" onClick={handleClose}>
              Aceptar
            </button>
          )}
        </div>

        {/* Botón de cerrar */}
        <button className="notification-close" onClick={handleClose}>
          ✕
        </button>
      </div>
    </div>
  );

  return createPortal(content, document.body);
};

export default SuccessNotification;
