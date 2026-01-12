/**
 * PeriodoTimelineV2 - Timeline Futurista de Períodos
 * 
 * Diseño inspirado en interfaces sci-fi con glassmorphism,
 * animaciones fluidas y navegación inteligente.
 * 
 * Features:
 * - Filtra automáticamente períodos relevantes (con actividad)
 * - Navegación por gestos (swipe) y teclado
 * - Indicadores visuales de estado con animaciones
 * - Dropdown rápido para saltar a cualquier período
 * - Modo compacto para móviles
 */

import React, { useState, useRef, useEffect, useMemo } from 'react';
import './PeriodoTimelineV2.css';

// Configuración de estados con colores y efectos
const STATUS_CONFIG = {
  1: { // PENDING
    name: 'PENDIENTE',
    shortName: 'PND',
    color: '#64748b',
    glow: 'rgba(100, 116, 139, 0.4)',
    icon: '⏳',
    priority: 0
  },
  3: { // CUTOFF
    name: 'BORRADOR',
    shortName: 'BRR',
    color: '#f59e0b',
    glow: 'rgba(245, 158, 11, 0.5)',
    icon: '✂️',
    priority: 3
  },
  4: { // COLLECTING
    name: 'EN COBRO',
    shortName: 'COB',
    color: '#10b981',
    glow: 'rgba(16, 185, 129, 0.5)',
    icon: '💰',
    pulse: true,
    priority: 4
  },
  5: { // CLOSED
    name: 'CERRADO',
    shortName: 'CRD',
    color: '#6366f1',
    glow: 'rgba(99, 102, 241, 0.4)',
    icon: '✅',
    priority: 1
  },
  6: { // SETTLING
    name: 'LIQUIDACIÓN',
    shortName: 'LIQ',
    color: '#ef4444',
    glow: 'rgba(239, 68, 68, 0.5)',
    icon: '⚖️',
    pulse: true,
    priority: 5
  }
};

// Nombres de meses en español
const MONTHS = ['ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN', 'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC'];
const MONTHS_FULL = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];

// Formatear código de período corto
const formatPeriodShort = (cutCode) => {
  if (!cutCode) return '???';
  // Jan08-2026 → ENE 08
  const match = cutCode.match(/([A-Za-z]+)(\d+)-(\d+)/);
  if (match) {
    const [, month, day] = match;
    const monthMap = {
      'Jan': 'ENE', 'Feb': 'FEB', 'Mar': 'MAR', 'Apr': 'ABR',
      'May': 'MAY', 'Jun': 'JUN', 'Jul': 'JUL', 'Aug': 'AGO',
      'Sep': 'SEP', 'Oct': 'OCT', 'Nov': 'NOV', 'Dec': 'DIC',
      'Ene': 'ENE', 'Abr': 'ABR', 'Ago': 'AGO', 'Dic': 'DIC'
    };
    return `${monthMap[month] || month.toUpperCase().slice(0, 3)} ${day}`;
  }
  return cutCode.slice(0, 6);
};

// Formatear fecha para display
const formatDateRange = (startDate, endDate) => {
  if (!startDate || !endDate) return '';
  const start = new Date(startDate + 'T12:00:00');
  const end = new Date(endDate + 'T12:00:00');
  
  const startMonth = MONTHS[start.getMonth()];
  const endMonth = MONTHS[end.getMonth()];
  const startDay = start.getDate();
  const endDay = end.getDate();
  const year = end.getFullYear();
  
  if (startMonth === endMonth) {
    return `${startDay}-${endDay} ${startMonth} ${year}`;
  }
  return `${startDay} ${startMonth} - ${endDay} ${endMonth} ${year}`;
};

// Obtener año de un período
const getYear = (period) => {
  if (!period?.period_end_date) return new Date().getFullYear();
  return new Date(period.period_end_date + 'T12:00:00').getFullYear();
};

export default function PeriodoTimelineV2({
  periods = [],
  selectedPeriod,
  onSelectPeriod,
  loading = false,
  periodStats = {}
}) {
  const [showDropdown, setShowDropdown] = useState(false);
  const [dropdownFilter, setDropdownFilter] = useState('');
  const [hoveredPeriod, setHoveredPeriod] = useState(null);
  const timelineRef = useRef(null);
  const dropdownRef = useRef(null);

  // Cerrar dropdown al hacer clic fuera
  useEffect(() => {
    const handleClickOutside = (e) => {
      if (dropdownRef.current && !dropdownRef.current.contains(e.target)) {
        setShowDropdown(false);
      }
    };
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  // Filtrar y categorizar períodos
  const { relevantPeriods, allYears, periodsByYear, allPeriodsSorted } = useMemo(() => {
    // Primero ordenar TODOS los períodos cronológicamente
    const allSorted = [...periods].sort((a, b) => 
      new Date(a.period_start_date) - new Date(b.period_start_date)
    );
    
    // Estados con actividad real
    const activeStatuses = [3, 4, 6]; // CUTOFF, COLLECTING, SETTLING
    
    // Encontrar el índice del período activo actual
    const currentActiveIndex = allSorted.findIndex(p => 
      p.status_id === 4 || p.status_id === 6 || p.status_id === 3
    );
    
    // Calcular horizonte: 6 meses hacia adelante desde hoy
    const today = new Date();
    const horizonDate = new Date(today);
    horizonDate.setMonth(horizonDate.getMonth() + 6);
    
    // Construir lista de períodos relevantes
    const relevant = [];
    const addedIds = new Set();
    
    // 1. Agregar todos los períodos CERRADOS con statements reales (histórico)
    allSorted.forEach(p => {
      if (p.status_id === 5 && p.statements_count && p.statements_count > 0) {
        if (!addedIds.has(p.id)) {
          relevant.push(p);
          addedIds.add(p.id);
        }
      }
    });
    
    // 2. Agregar el período activo actual
    if (currentActiveIndex >= 0) {
      const activePeriod = allSorted[currentActiveIndex];
      if (!addedIds.has(activePeriod.id)) {
        relevant.push(activePeriod);
        addedIds.add(activePeriod.id);
      }
    }
    
    // 3. Agregar TODOS los períodos futuros hasta el horizonte (6 meses)
    allSorted.forEach(p => {
      if (p.status_id === 1) { // PENDING
        const periodStart = new Date(p.period_start_date + 'T12:00:00');
        if (periodStart <= horizonDate && !addedIds.has(p.id)) {
          relevant.push(p);
          addedIds.add(p.id);
        }
      }
    });
    
    // Ordenar cronológicamente
    relevant.sort((a, b) => 
      new Date(a.period_start_date) - new Date(b.period_start_date)
    );

    // Si no hay relevantes, mostrar los últimos 10 períodos
    const finalRelevant = relevant.length > 0 ? relevant : 
      allSorted.slice(-10);

    // Agrupar por año para el dropdown
    const byYear = {};
    const years = new Set();
    
    periods.forEach(p => {
      const year = getYear(p);
      years.add(year);
      if (!byYear[year]) byYear[year] = [];
      byYear[year].push(p);
    });

    // Ordenar períodos dentro de cada año por fecha descendente (para dropdown)
    Object.keys(byYear).forEach(year => {
      byYear[year].sort((a, b) => 
        new Date(b.period_start_date) - new Date(a.period_start_date)
      );
    });

    return {
      relevantPeriods: finalRelevant,
      allYears: Array.from(years).sort((a, b) => b - a),
      periodsByYear: byYear,
      allPeriodsSorted: allSorted // Exponer todos los períodos ordenados
    };
  }, [periods]);

  // Si el período seleccionado no está en relevantPeriods, usar todos los períodos
  // Esto permite navegar cuando se selecciona desde el dropdown
  const navigationPeriods = useMemo(() => {
    if (!selectedPeriod) return relevantPeriods;
    
    const isInRelevant = relevantPeriods.some(p => p.id === selectedPeriod.id);
    if (isInRelevant) return relevantPeriods;
    
    // El período seleccionado no está en relevantes - usar todos los períodos ordenados
    // para permitir navegación completa
    return allPeriodsSorted;
  }, [relevantPeriods, selectedPeriod, allPeriodsSorted]);

  // Índice del período seleccionado en los períodos de navegación
  const selectedIndex = useMemo(() => {
    if (!selectedPeriod) return -1;
    return navigationPeriods.findIndex(p => p.id === selectedPeriod.id);
  }, [navigationPeriods, selectedPeriod]);

  // Períodos visibles en el timeline (máximo 7)
  // Centrado en el período seleccionado
  const visiblePeriods = useMemo(() => {
    // Usar navigationPeriods para mostrar el contexto correcto
    const periodsToShow = navigationPeriods;
    if (periodsToShow.length <= 7) return periodsToShow;
    
    const idx = Math.max(0, selectedIndex);
    // Centrar el período seleccionado
    let start = Math.max(0, idx - 3);
    // Asegurar que no nos pasemos del final
    if (start + 7 > periodsToShow.length) {
      start = periodsToShow.length - 7;
    }
    return periodsToShow.slice(start, start + 7);
  }, [navigationPeriods, selectedIndex]);

  // Navegación - Cronológica:
  // ← (Previous) = ir al período MÁS ANTIGUO (índice menor)
  // → (Next) = ir al período MÁS RECIENTE (índice mayor)
  const goToPrevious = () => {
    if (selectedIndex > 0) {
      onSelectPeriod(navigationPeriods[selectedIndex - 1]);
    }
  };

  const goToNext = () => {
    if (selectedIndex < navigationPeriods.length - 1) {
      onSelectPeriod(navigationPeriods[selectedIndex + 1]);
    }
  };

  // Verificar si hay más períodos en cada dirección
  const canGoPrevious = selectedIndex > 0;
  const canGoNext = selectedIndex < navigationPeriods.length - 1;

  // Keyboard navigation
  useEffect(() => {
    const handleKeyDown = (e) => {
      if (showDropdown) return;
      if (e.key === 'ArrowLeft') goToPrevious();
      if (e.key === 'ArrowRight') goToNext();
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [selectedIndex, relevantPeriods, showDropdown]);

  // Filtrar períodos en dropdown
  const filteredDropdownPeriods = useMemo(() => {
    if (!dropdownFilter) return periods.slice(0, 50);
    const filter = dropdownFilter.toLowerCase();
    return periods.filter(p => 
      p.cut_code?.toLowerCase().includes(filter) ||
      formatPeriodShort(p.cut_code).toLowerCase().includes(filter)
    ).slice(0, 30);
  }, [periods, dropdownFilter]);

  const config = selectedPeriod ? STATUS_CONFIG[selectedPeriod.status_id] : STATUS_CONFIG[1];

  if (loading) {
    return (
      <div className="timeline-v2 timeline-v2--loading">
        <div className="timeline-v2__loader">
          <div className="timeline-v2__loader-ring"></div>
          <span>Cargando períodos...</span>
        </div>
      </div>
    );
  }

  return (
    <div className="timeline-v2">
      {/* Fondo con efecto de partículas */}
      <div className="timeline-v2__bg">
        <div className="timeline-v2__particles"></div>
        <div className="timeline-v2__grid"></div>
      </div>

      {/* Header con período actual */}
      <div className="timeline-v2__header">
        <div className="timeline-v2__current" ref={dropdownRef}>
          <button 
            className="timeline-v2__selector"
            onClick={() => setShowDropdown(!showDropdown)}
            style={{ '--glow-color': config?.glow }}
          >
            <div className="timeline-v2__selector-content">
              <span className="timeline-v2__selector-icon">{config?.icon}</span>
              <div className="timeline-v2__selector-info">
                <span className="timeline-v2__selector-code">
                  {selectedPeriod?.cut_code || 'Seleccionar'}
                </span>
                <span className="timeline-v2__selector-dates">
                  {selectedPeriod && formatDateRange(selectedPeriod.period_start_date, selectedPeriod.period_end_date)}
                </span>
              </div>
              <span className={`timeline-v2__selector-status timeline-v2__selector-status--${config?.name?.toLowerCase().replace(/\s/g, '-')}`}
                    style={{ '--status-color': config?.color }}>
                {config?.name}
              </span>
            </div>
            <span className={`timeline-v2__selector-arrow ${showDropdown ? 'open' : ''}`}>
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <polyline points="6,9 12,15 18,9"></polyline>
              </svg>
            </span>
          </button>

          {/* Dropdown de selección rápida */}
          {showDropdown && (
            <div className="timeline-v2__dropdown">
              <div className="timeline-v2__dropdown-header">
                <input
                  type="text"
                  placeholder="🔍 Buscar período..."
                  value={dropdownFilter}
                  onChange={(e) => setDropdownFilter(e.target.value)}
                  className="timeline-v2__dropdown-search"
                  autoFocus
                />
              </div>
              <div className="timeline-v2__dropdown-list">
                {allYears.map(year => (
                  <div key={year} className="timeline-v2__dropdown-group">
                    <div className="timeline-v2__dropdown-year">{year}</div>
                    {(periodsByYear[year] || [])
                      .filter(p => !dropdownFilter || 
                        p.cut_code?.toLowerCase().includes(dropdownFilter.toLowerCase()))
                      .map(period => {
                        const pConfig = STATUS_CONFIG[period.status_id];
                        const isSelected = period.id === selectedPeriod?.id;
                        return (
                          <button
                            key={period.id}
                            className={`timeline-v2__dropdown-item ${isSelected ? 'selected' : ''}`}
                            onClick={() => {
                              onSelectPeriod(period);
                              setShowDropdown(false);
                              setDropdownFilter('');
                            }}
                            style={{ '--item-color': pConfig?.color }}
                          >
                            <span className="timeline-v2__dropdown-item-icon">{pConfig?.icon}</span>
                            <span className="timeline-v2__dropdown-item-code">{period.cut_code}</span>
                            <span className="timeline-v2__dropdown-item-status">{pConfig?.shortName}</span>
                            {period.statements_count > 0 && (
                              <span className="timeline-v2__dropdown-item-badge">
                                {period.statements_count} 📄
                              </span>
                            )}
                          </button>
                        );
                      })}
                  </div>
                ))}
                {filteredDropdownPeriods.length === 0 && (
                  <div className="timeline-v2__dropdown-empty">
                    No se encontraron períodos
                  </div>
                )}
              </div>
            </div>
          )}
        </div>

        {/* Stats rápidos */}
        <div className="timeline-v2__quick-stats">
          <div className="timeline-v2__stat">
            <span className="timeline-v2__stat-value">{periodStats.statementCount || 0}</span>
            <span className="timeline-v2__stat-label">Estados</span>
          </div>
          <div className="timeline-v2__stat">
            <span className="timeline-v2__stat-value">{periodStats.associateCount || 0}</span>
            <span className="timeline-v2__stat-label">Asociados</span>
          </div>
          <div className="timeline-v2__stat">
            <span className="timeline-v2__stat-value">{periodStats.paymentCount || 0}</span>
            <span className="timeline-v2__stat-label">Pagos</span>
          </div>
        </div>
      </div>

      {/* Timeline visual */}
      <div className="timeline-v2__track" ref={timelineRef}>
        {/* Botón anterior (← = más antiguo) */}
        <button 
          className="timeline-v2__nav timeline-v2__nav--prev"
          onClick={goToPrevious}
          disabled={!canGoPrevious}
          title="Período anterior (←)"
        >
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <polyline points="15,18 9,12 15,6"></polyline>
          </svg>
        </button>

        {/* Nodos del timeline */}
        <div className="timeline-v2__nodes">
          {/* Línea de conexión */}
          <div className="timeline-v2__line">
            <div className="timeline-v2__line-glow" style={{ '--glow-color': config?.glow }}></div>
          </div>

          {visiblePeriods.map((period, idx) => {
            const pConfig = STATUS_CONFIG[period.status_id];
            const isSelected = period.id === selectedPeriod?.id;
            const isHovered = hoveredPeriod === period.id;
            const hasActivity = (period.statements_count > 0) || (period.payment_count > 0);

            return (
              <button
                key={period.id}
                className={`timeline-v2__node ${isSelected ? 'selected' : ''} ${pConfig?.pulse ? 'pulse' : ''} ${hasActivity ? 'has-activity' : ''}`}
                onClick={() => onSelectPeriod(period)}
                onMouseEnter={() => setHoveredPeriod(period.id)}
                onMouseLeave={() => setHoveredPeriod(null)}
                style={{ 
                  '--node-color': pConfig?.color,
                  '--node-glow': pConfig?.glow
                }}
                title={`${period.cut_code} - ${pConfig?.name}`}
              >
                <div className="timeline-v2__node-ring">
                  <div className="timeline-v2__node-core">
                    {isSelected ? pConfig?.icon : ''}
                  </div>
                </div>
                <div className="timeline-v2__node-label">
                  <span className="timeline-v2__node-code">{formatPeriodShort(period.cut_code)}</span>
                  {hasActivity && (
                    <span className="timeline-v2__node-dot"></span>
                  )}
                </div>

                {/* Tooltip en hover */}
                {(isHovered && !isSelected) && (
                  <div className="timeline-v2__tooltip">
                    <div className="timeline-v2__tooltip-header">
                      <span>{pConfig?.icon}</span>
                      <span>{period.cut_code}</span>
                    </div>
                    <div className="timeline-v2__tooltip-status" style={{ color: pConfig?.color }}>
                      {pConfig?.name}
                    </div>
                    {period.statements_count > 0 && (
                      <div className="timeline-v2__tooltip-meta">
                        {period.statements_count} estados de cuenta
                      </div>
                    )}
                  </div>
                )}
              </button>
            );
          })}
        </div>

        {/* Botón siguiente (→ = más reciente) */}
        <button 
          className="timeline-v2__nav timeline-v2__nav--next"
          onClick={goToNext}
          disabled={!canGoNext}
          title="Período siguiente (→)"
        >
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <polyline points="9,18 15,12 9,6"></polyline>
          </svg>
        </button>
      </div>

      {/* Indicador de posición */}
      <div className="timeline-v2__position">
        <span className="timeline-v2__position-current">{selectedIndex + 1}</span>
        <span className="timeline-v2__position-separator">/</span>
        <span className="timeline-v2__position-total">{navigationPeriods.length}</span>
        <span className="timeline-v2__position-label">
          {navigationPeriods === relevantPeriods ? 'períodos con actividad' : 'períodos disponibles'}
        </span>
      </div>
    </div>
  );
}
