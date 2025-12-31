/**
 * PeriodosConStatementsPage
 * Sistema de períodos estilo NU:
 * - TODOS los períodos siempre existen (son los cortes quincenales)
 * - Vista PREVIEW en tiempo real para períodos ACTIVOS (status_id = 2)
 * - Los pagos se van acumulando conforme se registran
 * - Al llegar día 8 o 23: status → REVIEW (automático)
 * - Admin hace cierre manual: status → CLOSED
 * - Filtro por asociada individual
 * - Estadísticas generales de TODOS los períodos
 */
import { useState, useEffect, useMemo } from 'react';
import { useAuth } from '@/app/providers/AuthProvider';
import cutPeriodsService from '@/shared/api/services/cutPeriodsService';
import statementsService from '@/shared/api/services/statementsService';
import RegistrarPagoModal from '../../payments/components/RegistrarPagoModal';
import './PeriodosConStatementsPage.css';

const PAGE_SIZE = 5; // Paginación muy agresiva

export default function PeriodosConStatementsPage() {
  const { user } = useAuth();

  const [periods, setPeriods] = useState([]);
  const [selectedPeriod, setSelectedPeriod] = useState(null);
  const [periodData, setPeriodData] = useState([]);
  const [loading, setLoading] = useState(true);
  const [loadingStatements, setLoadingStatements] = useState(false);
  const [error, setError] = useState(null);

  // Paginación y filtros
  const [currentPage, setCurrentPage] = useState(0);
  const [paymentFilter, setPaymentFilter] = useState('all'); // all, pending, partial, paid
  const [searchTerm, setSearchTerm] = useState('');

  // Modal
  const [paymentModal, setPaymentModal] = useState({ open: false, statement: null });

  useEffect(() => {
    loadPeriods();
  }, []);

  useEffect(() => {
    if (selectedPeriod) {
      loadStatementsForPeriod(selectedPeriod.id);
    }
  }, [selectedPeriod]);

  const loadPeriods = async () => {
    try {
      setLoading(true);
      const data = await cutPeriodsService.getAll();

      // Ordenar por fecha descendente (más reciente primero)
      const sortedPeriods = (data.data?.items || data.items || []).sort((a, b) => {
        return new Date(b.period_start_date) - new Date(a.period_start_date);
      });

      setPeriods(sortedPeriods);

      // Seleccionar el período EN COBRO (status_id = 4) por defecto
      // Si no hay ninguno en cobro, seleccionar el más reciente
      const collectingPeriod = sortedPeriods.find(p => p.status_id === 4);
      if (collectingPeriod) {
        setSelectedPeriod(collectingPeriod);
      } else if (sortedPeriods.length > 0) {
        setSelectedPeriod(sortedPeriods[0]);
      }
    } catch (err) {
      console.error('Error al cargar períodos:', err);
    } finally {
      setLoading(false);
    }
  };

  const loadStatementsForPeriod = async (periodId) => {
    if (!periodId) return;

    setLoadingStatements(true);
    try {
      const data = await cutPeriodsService.getStatements(periodId);
      // El backend devuelve {success: true, data: [...]}
      // Necesitamos extraer solo el array
      let statements = [];

      if (Array.isArray(data)) {
        statements = data;
      } else if (data && Array.isArray(data.data)) {
        statements = data.data;
      } else if (data && data.data && typeof data.data === 'object') {
        // Si data.data es un objeto, podría ser un solo statement
        statements = [data.data];
      }

      setPeriodData(statements);
    } catch (err) {
      setError('Error al cargar estados de cuenta del período');
      console.error('Error loading period statements:', err);
      setPeriodData([]); // Asegurar que siempre sea un array
    } finally {
      setLoadingStatements(false);
    }
  };

  const handlePeriodSelect = (period) => {
    setSelectedPeriod(period);
    loadStatementsForPeriod(period.id);
  };

  const handleClosePeriod = async () => {
    if (!selectedPeriod) return;

    // Solo períodos en SETTLING (6) pueden cerrarse definitivamente
    if (selectedPeriod.status_id !== 6) {
      alert('Solo se pueden cerrar períodos en estado LIQUIDACIÓN (6).\n\nPrimero debe avanzar el período a LIQUIDACIÓN.');
      return;
    }

    if (!confirm(`¿Cerrar definitivamente el período ${selectedPeriod.cut_code}?\n\n⚠️ Esta acción:\n- Transferirá deudas pendientes a los asociados\n- Marcará los statements impagos como ABSORBIDOS\n- Es IRREVERSIBLE`)) {
      return;
    }

    try {
      setLoadingStatements(true);

      // Llamar al endpoint real de cierre
      const response = await fetch(`/api/v1/cut-periods/${selectedPeriod.id}/close`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${localStorage.getItem('token')}`,
          'Content-Type': 'application/json'
        }
      });

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.detail || 'Error al cerrar período');
      }

      alert(`✅ Período ${selectedPeriod.cut_code} cerrado exitosamente.\n\nDeudas transferidas: ${data.debts_created || 0}`);
      await loadPeriods(); // Recargar períodos
      await loadStatementsForPeriod(selectedPeriod.id);
    } catch (err) {
      console.error('Error al cerrar período:', err);
      alert('❌ Error al cerrar período: ' + (err.message || err));
    } finally {
      setLoadingStatements(false);
    }
  };

  const handleOpenPayment = (statement) => {
    setPaymentModal({ open: true, statement });
  };

  const handlePaymentSuccess = async (paymentData) => {
    try {
      await statementsService.registerPayment(paymentModal.statement.id, paymentData);
      setPaymentModal({ open: false, statement: null });
      await loadStatementsForPeriod(selectedPeriod.id);
    } catch (err) {
      throw err;
    }
  };

  const formatDate = (dateStr) => {
    if (!dateStr) return '-';
    const date = new Date(dateStr + 'T12:00:00Z');
    return date.toLocaleDateString('es-MX', {
      day: '2-digit',
      month: 'short',
      year: 'numeric',
      timeZone: 'UTC'
    });
  };

  const formatMoney = (amount) => {
    return new Intl.NumberFormat('es-MX', {
      style: 'currency',
      currency: 'MXN'
    }).format(amount || 0);
  };

  const getStatusInfo = (statusId) => {
    const statuses = {
      1: { label: 'Pendiente', class: 'status-preliminary', icon: '⏳' },
      2: { label: 'Activo (deprecado)', class: 'status-active', icon: '⚠️' },
      3: { label: 'Corte (Borrador)', class: 'status-review', icon: '📝' },
      4: { label: 'En Cobro', class: 'status-active', icon: '💵' },
      5: { label: 'Cerrado', class: 'status-closed', icon: '✅' },
      6: { label: 'Liquidación', class: 'status-locked', icon: '⚖️' }
    };
    return statuses[statusId] || { label: 'Desconocido', class: 'status-unknown', icon: '❓' };
  };

  // Estados de statement (ciclo de vida)
  const getStatementStatusInfo = (statusId) => {
    const statuses = {
      6: { label: 'Borrador', color: '#FFC107', icon: '📝' },
      7: { label: 'En Cobro', color: '#2196F3', icon: '💰' },
      9: { label: 'Liquidación', color: '#9C27B0', icon: '⚖️' },
      10: { label: 'Cerrado', color: '#455A64', icon: '🔒' },
      // Estados legacy (deprecados pero pueden existir en datos)
      3: { label: 'Pagado', color: '#4CAF50', icon: '✅' },
      4: { label: 'Parcial', color: '#FF9800', icon: '⚠️' },
      5: { label: 'Vencido', color: '#F44336', icon: '🚨' },
      8: { label: 'Absorbido', color: '#607D8B', icon: '📦' },
    };
    return statuses[statusId] || { label: 'Desconocido', color: '#9E9E9E', icon: '❓' };
  };

  // Estado de DEUDA calculado dinámicamente
  const getPaymentStatus = (stmt) => {
    const totalOwed = (stmt.total_to_credicuenta || 0) + (stmt.late_fee_amount || 0);
    const paid = stmt.paid_amount || 0;
    const pending = totalOwed - paid;

    if (pending <= 0.01) {
      return { label: 'Pagado', color: '#4CAF50', icon: '✅', key: 'paid' };
    } else if (paid > 0) {
      return { label: 'Parcial', color: '#FF9800', icon: '⚠️', key: 'partial' };
    } else {
      return { label: 'Pendiente', color: '#F44336', icon: '🔴', key: 'pending' };
    }
  };

  // Estadísticas calculadas
  const stats = useMemo(() => {
    const result = {
      total: periodData.length,
      paid: 0,
      partial: 0,
      pending: 0,
      totalOwed: 0,
      totalPaid: 0,
      totalPending: 0
    };

    periodData.forEach(stmt => {
      const totalOwed = (stmt.total_to_credicuenta || 0) + (stmt.late_fee_amount || 0);
      const paid = stmt.paid_amount || 0;
      const pending = totalOwed - paid;

      result.totalOwed += totalOwed;
      result.totalPaid += paid;
      result.totalPending += Math.max(0, pending);

      if (pending <= 0.01) result.paid++;
      else if (paid > 0) result.partial++;
      else result.pending++;
    });

    return result;
  }, [periodData]);

  // Filtrado y paginación con useMemo
  const { filteredData, paginatedData, totalPages } = useMemo(() => {
    let filtered = [...periodData];

    // Filtrar por estado de pago
    if (paymentFilter !== 'all') {
      filtered = filtered.filter(stmt => {
        const status = getPaymentStatus(stmt);
        return status.key === paymentFilter;
      });
    }

    // Filtrar por búsqueda
    if (searchTerm.trim()) {
      const term = searchTerm.toLowerCase();
      filtered = filtered.filter(stmt =>
        (stmt.associate_name || '').toLowerCase().includes(term) ||
        String(stmt.associate_id || '').includes(term)
      );
    }

    // Ordenar por pendiente (mayor primero)
    filtered.sort((a, b) => {
      const pendingA = (a.total_to_credicuenta || 0) - (a.paid_amount || 0);
      const pendingB = (b.total_to_credicuenta || 0) - (b.paid_amount || 0);
      return pendingB - pendingA;
    });

    const total = Math.ceil(filtered.length / PAGE_SIZE);
    const paginated = filtered.slice(currentPage * PAGE_SIZE, (currentPage + 1) * PAGE_SIZE);

    return { filteredData: filtered, paginatedData: paginated, totalPages: total };
  }, [periodData, paymentFilter, searchTerm, currentPage]);

  // Reset página cuando cambia filtro
  useEffect(() => {
    setCurrentPage(0);
  }, [paymentFilter, searchTerm, selectedPeriod]);

  if (loading) {
    return (
      <div className="periodos-page">
        <div className="loading-state">
          <div className="spinner"></div>
          <p>Cargando períodos...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="periodos-page">
      {/* Header */}
      <div className="page-header">
        <div>
          <h1>📅 Gestión por Períodos</h1>
          <p className="page-subtitle">
            Sistema de períodos quincenales • Vista en tiempo real de cobros y comisiones
          </p>
        </div>
      </div>

      {/* Selector de Período */}
      <div className="period-selector-section">
        <h3 style={{ margin: '0 0 1rem 0', color: 'var(--text-primary)' }}>Períodos</h3>
        <div className="period-list">
          {periods.map(period => {
            const statusInfo = getStatusInfo(period.status_id);
            return (
              <div
                key={period.id}
                className={`period-list-item ${selectedPeriod?.id === period.id ? 'active' : ''}`}
                onClick={() => handlePeriodSelect(period)}
              >
                <div className="period-item-icon">
                  <span className="status-icon-large">{statusInfo.icon}</span>
                </div>
                <div className="period-item-content">
                  <div className="period-item-header">
                    <h4 className="period-code">{period.cut_code}</h4>
                    <span className={`period-status-badge ${statusInfo.class}`}>
                      {statusInfo.label}
                    </span>
                  </div>
                  <div className="period-item-details">
                    <span className="period-dates">
                      {formatDate(period.period_start_date)} - {formatDate(period.period_end_date)}
                    </span>
                    <span className="period-collection">
                      Cobranza: {period.collection_percentage?.toFixed(1) || '0.0'}%
                    </span>
                  </div>
                </div>
              </div>
            );
          })}
        </div>

        {selectedPeriod && (
          <div className="period-info-bar">
            <div className="period-info-grid">
              <div className="info-item">
                <label>Estados de Cuenta:</label>
                <span>{periodData.length} (Tiempo Real)</span>
              </div>
            </div>

            {selectedPeriod.status_id === 6 && (
              <button
                className="btn-close-period"
                onClick={handleClosePeriod}
                title="Cierra el período, transfiere deudas pendientes"
              >
                🔒 Cerrar Período y Transferir Deudas
              </button>
            )}
          </div>
        )}
      </div>

      {/* Tabla de Statements */}
      {selectedPeriod && (
        <div className="statements-section">
          {loadingStatements ? (
            <div className="loading-state">
              <div className="spinner"></div>
              <p>Cargando estados de cuenta...</p>
            </div>
          ) : periodData.length === 0 ? (
            <div className="empty-state">
              <div className="empty-icon">📭</div>
              <h3>No hay estados de cuenta</h3>
              <p>
                {selectedPeriod.status_id === 1
                  ? 'Este período está preliminar, aún no hay datos.'
                  : selectedPeriod.status_id === 2
                    ? 'Este período está activo pero aún no hay pagos registrados.'
                    : 'No hay estados de cuenta para este período.'
                }
              </p>
            </div>
          ) : (
            <>
              {/* Resumen Rápido */}
              <div style={{
                display: 'grid',
                gridTemplateColumns: 'repeat(auto-fit, minmax(140px, 1fr))',
                gap: '12px',
                marginBottom: '20px'
              }}>
                <div style={{
                  padding: '16px',
                  borderRadius: '12px',
                  background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
                  color: 'white'
                }}>
                  <div style={{ fontSize: '12px', opacity: 0.9 }}>Total Adeudado</div>
                  <div style={{ fontSize: '22px', fontWeight: '700' }}>{formatMoney(stats.totalOwed)}</div>
                </div>
                <div style={{
                  padding: '16px',
                  borderRadius: '12px',
                  background: 'linear-gradient(135deg, #11998e 0%, #38ef7d 100%)',
                  color: 'white'
                }}>
                  <div style={{ fontSize: '12px', opacity: 0.9 }}>Total Pagado</div>
                  <div style={{ fontSize: '22px', fontWeight: '700' }}>{formatMoney(stats.totalPaid)}</div>
                </div>
                <div style={{
                  padding: '16px',
                  borderRadius: '12px',
                  background: stats.totalPending > 0
                    ? 'linear-gradient(135deg, #eb3349 0%, #f45c43 100%)'
                    : 'linear-gradient(135deg, #11998e 0%, #38ef7d 100%)',
                  color: 'white'
                }}>
                  <div style={{ fontSize: '12px', opacity: 0.9 }}>Pendiente</div>
                  <div style={{ fontSize: '22px', fontWeight: '700' }}>{formatMoney(stats.totalPending)}</div>
                </div>
                <div style={{
                  padding: '16px',
                  borderRadius: '12px',
                  background: 'var(--color-surface-secondary)',
                  border: '1px solid var(--color-border)'
                }}>
                  <div style={{ fontSize: '12px', opacity: 0.7 }}>Cobranza</div>
                  <div style={{ fontSize: '22px', fontWeight: '700' }}>
                    {stats.totalOwed > 0 ? ((stats.totalPaid / stats.totalOwed) * 100).toFixed(0) : 0}%
                  </div>
                </div>
              </div>

              {/* Filtros Compactos */}
              <div style={{
                display: 'flex',
                flexWrap: 'wrap',
                gap: '8px',
                marginBottom: '16px',
                alignItems: 'center'
              }}>
                {/* Filtros de estado */}
                <div style={{ display: 'flex', gap: '4px', flexWrap: 'wrap' }}>
                  {[
                    { key: 'all', label: 'Todos', count: stats.total, color: '#6c757d' },
                    { key: 'pending', label: '🔴 Pendiente', count: stats.pending, color: '#F44336' },
                    { key: 'partial', label: '⚠️ Parcial', count: stats.partial, color: '#FF9800' },
                    { key: 'paid', label: '✅ Pagado', count: stats.paid, color: '#4CAF50' }
                  ].map(f => (
                    <button
                      key={f.key}
                      onClick={() => setPaymentFilter(f.key)}
                      style={{
                        padding: '6px 12px',
                        borderRadius: '20px',
                        border: 'none',
                        cursor: 'pointer',
                        fontSize: '12px',
                        fontWeight: paymentFilter === f.key ? '600' : '400',
                        backgroundColor: paymentFilter === f.key ? f.color : 'var(--color-surface-secondary)',
                        color: paymentFilter === f.key ? 'white' : 'inherit',
                        transition: 'all 0.2s'
                      }}
                    >
                      {f.label} ({f.count})
                    </button>
                  ))}
                </div>

                {/* Búsqueda */}
                <input
                  type="text"
                  placeholder="🔍 Buscar asociado..."
                  value={searchTerm}
                  onChange={(e) => setSearchTerm(e.target.value)}
                  style={{
                    padding: '6px 12px',
                    borderRadius: '20px',
                    border: '1px solid var(--color-border)',
                    fontSize: '13px',
                    width: '180px',
                    backgroundColor: 'var(--color-surface)',
                    marginLeft: 'auto'
                  }}
                />
              </div>

              {/* Lista de Cards */}
              {paginatedData.length === 0 ? (
                <div style={{ textAlign: 'center', padding: '40px', opacity: 0.6 }}>
                  No hay resultados para el filtro seleccionado
                </div>
              ) : (
                <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
                  {paginatedData.map(stmt => {
                    const totalOwed = (stmt.total_to_credicuenta || 0) + (stmt.late_fee_amount || 0);
                    const pending = totalOwed - (stmt.paid_amount || 0);
                    const canPay = pending > 0 && selectedPeriod.status_id !== 5;
                    const paymentStatus = getPaymentStatus(stmt);
                    const progressPercent = totalOwed > 0 ? ((stmt.paid_amount || 0) / totalOwed) * 100 : 0;

                    return (
                      <div
                        key={stmt.id}
                        style={{
                          display: 'flex',
                          alignItems: 'center',
                          padding: '12px 16px',
                          backgroundColor: 'var(--color-surface-secondary)',
                          borderRadius: '10px',
                          borderLeft: `4px solid ${paymentStatus.color}`,
                          gap: '16px',
                          transition: 'transform 0.1s, box-shadow 0.1s'
                        }}
                        onMouseEnter={(e) => {
                          e.currentTarget.style.transform = 'translateX(4px)';
                          e.currentTarget.style.boxShadow = '0 2px 8px rgba(0,0,0,0.1)';
                        }}
                        onMouseLeave={(e) => {
                          e.currentTarget.style.transform = 'translateX(0)';
                          e.currentTarget.style.boxShadow = 'none';
                        }}
                      >
                        {/* Info Principal */}
                        <div style={{ flex: 1, minWidth: 0 }}>
                          <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '4px' }}>
                            <span style={{ fontWeight: '600', fontSize: '14px' }}>
                              {stmt.associate_name || 'Sin nombre'}
                            </span>
                            <span style={{
                              padding: '2px 8px',
                              borderRadius: '10px',
                              backgroundColor: paymentStatus.color,
                              color: 'white',
                              fontSize: '10px',
                              fontWeight: '600'
                            }}>
                              {paymentStatus.icon} {paymentStatus.label}
                            </span>
                          </div>
                          <div style={{ fontSize: '12px', opacity: 0.7 }}>
                            ID: {stmt.associate_id} • {stmt.total_payments_count || 0} cobros
                          </div>
                          {/* Mini barra de progreso */}
                          <div style={{
                            marginTop: '6px',
                            height: '4px',
                            backgroundColor: 'var(--color-border)',
                            borderRadius: '2px',
                            overflow: 'hidden',
                            maxWidth: '200px'
                          }}>
                            <div style={{
                              width: `${Math.min(progressPercent, 100)}%`,
                              height: '100%',
                              backgroundColor: paymentStatus.color,
                              transition: 'width 0.3s'
                            }} />
                          </div>
                        </div>

                        {/* Montos */}
                        <div style={{ textAlign: 'right', minWidth: '100px' }}>
                          <div style={{ fontSize: '11px', opacity: 0.6 }}>Adeudo</div>
                          <div style={{ fontWeight: '600', fontSize: '14px' }}>
                            {formatMoney(totalOwed)}
                          </div>
                        </div>

                        <div style={{ textAlign: 'right', minWidth: '100px' }}>
                          <div style={{ fontSize: '11px', opacity: 0.6 }}>Pagado</div>
                          <div style={{ fontWeight: '600', fontSize: '14px', color: '#4CAF50' }}>
                            {formatMoney(stmt.paid_amount || 0)}
                          </div>
                        </div>

                        <div style={{ textAlign: 'right', minWidth: '100px' }}>
                          <div style={{ fontSize: '11px', opacity: 0.6 }}>Pendiente</div>
                          <div style={{
                            fontWeight: '600',
                            fontSize: '14px',
                            color: pending > 0 ? '#F44336' : '#4CAF50'
                          }}>
                            {formatMoney(pending)}
                          </div>
                        </div>

                        {/* Acción */}
                        <button
                          onClick={() => handleOpenPayment(stmt)}
                          disabled={!canPay}
                          style={{
                            padding: '8px 16px',
                            borderRadius: '8px',
                            border: 'none',
                            backgroundColor: canPay ? 'var(--color-primary)' : 'var(--color-border)',
                            color: canPay ? 'white' : 'var(--color-text-secondary)',
                            cursor: canPay ? 'pointer' : 'not-allowed',
                            fontSize: '13px',
                            fontWeight: '500',
                            whiteSpace: 'nowrap',
                            opacity: canPay ? 1 : 0.5
                          }}
                        >
                          💰 Pagar
                        </button>
                      </div>
                    );
                  })}
                </div>
              )}

              {/* Paginación */}
              {totalPages > 1 && (
                <div style={{
                  display: 'flex',
                  justifyContent: 'center',
                  alignItems: 'center',
                  gap: '8px',
                  marginTop: '20px',
                  padding: '12px',
                  backgroundColor: 'var(--color-surface-secondary)',
                  borderRadius: '8px'
                }}>
                  <button
                    onClick={() => setCurrentPage(0)}
                    disabled={currentPage === 0}
                    style={{
                      padding: '6px 10px',
                      border: '1px solid var(--color-border)',
                      borderRadius: '4px',
                      cursor: currentPage === 0 ? 'not-allowed' : 'pointer',
                      opacity: currentPage === 0 ? 0.5 : 1,
                      backgroundColor: 'transparent'
                    }}
                  >
                    ⏮
                  </button>
                  <button
                    onClick={() => setCurrentPage(p => Math.max(0, p - 1))}
                    disabled={currentPage === 0}
                    style={{
                      padding: '6px 12px',
                      border: '1px solid var(--color-border)',
                      borderRadius: '4px',
                      cursor: currentPage === 0 ? 'not-allowed' : 'pointer',
                      opacity: currentPage === 0 ? 0.5 : 1,
                      backgroundColor: 'transparent'
                    }}
                  >
                    ← Anterior
                  </button>

                  <div style={{
                    display: 'flex',
                    gap: '4px',
                    alignItems: 'center'
                  }}>
                    {/* Mostrar números de página */}
                    {Array.from({ length: Math.min(5, totalPages) }, (_, i) => {
                      let pageNum;
                      if (totalPages <= 5) {
                        pageNum = i;
                      } else if (currentPage < 3) {
                        pageNum = i;
                      } else if (currentPage > totalPages - 4) {
                        pageNum = totalPages - 5 + i;
                      } else {
                        pageNum = currentPage - 2 + i;
                      }
                      return (
                        <button
                          key={pageNum}
                          onClick={() => setCurrentPage(pageNum)}
                          style={{
                            width: '32px',
                            height: '32px',
                            borderRadius: '4px',
                            border: currentPage === pageNum ? 'none' : '1px solid var(--color-border)',
                            backgroundColor: currentPage === pageNum ? 'var(--color-primary)' : 'transparent',
                            color: currentPage === pageNum ? 'white' : 'inherit',
                            cursor: 'pointer',
                            fontWeight: currentPage === pageNum ? '600' : '400'
                          }}
                        >
                          {pageNum + 1}
                        </button>
                      );
                    })}
                  </div>

                  <button
                    onClick={() => setCurrentPage(p => Math.min(totalPages - 1, p + 1))}
                    disabled={currentPage >= totalPages - 1}
                    style={{
                      padding: '6px 12px',
                      border: '1px solid var(--color-border)',
                      borderRadius: '4px',
                      cursor: currentPage >= totalPages - 1 ? 'not-allowed' : 'pointer',
                      opacity: currentPage >= totalPages - 1 ? 0.5 : 1,
                      backgroundColor: 'transparent'
                    }}
                  >
                    Siguiente →
                  </button>
                  <button
                    onClick={() => setCurrentPage(totalPages - 1)}
                    disabled={currentPage >= totalPages - 1}
                    style={{
                      padding: '6px 10px',
                      border: '1px solid var(--color-border)',
                      borderRadius: '4px',
                      cursor: currentPage >= totalPages - 1 ? 'not-allowed' : 'pointer',
                      opacity: currentPage >= totalPages - 1 ? 0.5 : 1,
                      backgroundColor: 'transparent'
                    }}
                  >
                    ⏭
                  </button>
                </div>
              )}

              {/* Info de paginación */}
              <div style={{
                textAlign: 'center',
                fontSize: '12px',
                opacity: 0.6,
                marginTop: '8px'
              }}>
                Mostrando {paginatedData.length} de {filteredData.length}
                {paymentFilter !== 'all' && ` (filtrado de ${stats.total} total)`}
              </div>
            </>
          )}
        </div>
      )}

      {/* Modal de Pago */}
      <RegistrarPagoModal
        isOpen={paymentModal.open}
        onClose={() => setPaymentModal({ open: false, statement: null })}
        tipo="periodo"
        statement={paymentModal.statement}
        associateId={paymentModal.statement?.associate_id}
        onSuccess={handlePaymentSuccess}
      />
    </div>
  );
}
