/**
 * CollapsibleSection - Sección colapsable con carga diferida
 * 
 * Características:
 * - Se expande/colapsa con animación suave
 * - Carga el contenido SOLO cuando se expande por primera vez (lazy loading)
 * - Muestra contador/badge opcional en el header
 * - SIEMPRE inicia colapsada para ahorrar recursos
 */

import { useState, useCallback } from 'react';
import './CollapsibleSection.css';

const CollapsibleSection = ({
  title,
  icon = '📁',
  subtitle,
  badge,
  badgeColor = 'info',
  children,
  onExpand, // Callback cuando se expande (para cargar datos)
  className = ''
}) => {
  // SIEMPRE inicia colapsada
  const [isExpanded, setIsExpanded] = useState(false);
  const [hasLoaded, setHasLoaded] = useState(false);
  const [isAnimating, setIsAnimating] = useState(false);

  const toggleExpanded = useCallback(() => {
    setIsAnimating(true);

    if (!isExpanded && !hasLoaded) {
      // Primera vez que se expande: marcar como cargado y llamar callback
      setHasLoaded(true);
      if (onExpand) {
        onExpand();
      }
    }

    setIsExpanded(prev => !prev);

    // Limpiar estado de animación después de la transición
    setTimeout(() => setIsAnimating(false), 300);
  }, [isExpanded, hasLoaded, onExpand]);

  const getBadgeClass = () => {
    const classes = {
      info: 'badge-info',
      success: 'badge-success',
      warning: 'badge-warning',
      danger: 'badge-danger',
      primary: 'badge-primary'
    };
    return classes[badgeColor] || 'badge-info';
  };

  return (
    <div className={`collapsible-section ${isExpanded ? 'expanded' : 'collapsed'} ${className}`}>
      <div
        className="collapsible-header"
        onClick={toggleExpanded}
        role="button"
        tabIndex={0}
        onKeyDown={(e) => e.key === 'Enter' && toggleExpanded()}
        aria-expanded={isExpanded}
      >
        <div className="header-left">
          <span className={`expand-icon ${isExpanded ? 'rotated' : ''}`}>
            ▶
          </span>
          <span className="section-icon">{icon}</span>
          <div className="header-text">
            <h3 className="section-title">{title}</h3>
            {subtitle && <p className="section-subtitle">{subtitle}</p>}
          </div>
        </div>

        <div className="header-right">
          {badge !== undefined && (
            <span className={`section-badge badge ${getBadgeClass()}`}>
              {badge}
            </span>
          )}
        </div>
      </div>

      <div
        className={`collapsible-content ${isExpanded ? 'show' : ''} ${isAnimating ? 'animating' : ''}`}
      >
        <div className="content-inner">
          {/* Solo renderiza children si ya se ha expandido al menos una vez */}
          {hasLoaded ? children : null}
        </div>
      </div>
    </div>
  );
};

export default CollapsibleSection;
