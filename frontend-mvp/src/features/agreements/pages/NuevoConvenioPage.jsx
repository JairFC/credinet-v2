/**
 * NuevoConvenioPage - Crear Convenio desde Préstamos Activos
 * 
 * FLUJO:
 * 1. Buscar y seleccionar asociado
 * 2. Ver sus préstamos activos con pagos pendientes
 * 3. Seleccionar préstamos a incluir en convenio
 * 4. Configurar plan de pago (meses)
 * 5. Crear convenio
 */
import React, { useState, useEffect, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { agreementsService, associatesService, loansService } from '../../../shared/api/services';
import './NuevoConvenioPage.css';

const NuevoConvenioPage = () => {
  const navigate = useNavigate();
  
  // State
  const [searchTerm, setSearchTerm] = useState('');
  const [searchResults, setSearchResults] = useState([]);
  const [isSearching, setIsSearching] = useState(false);
  const [selectedAssociate, setSelectedAssociate] = useState(null);
  const [loans, setLoans] = useState([]);
  const [selectedLoans, setSelectedLoans] = useState([]);
  const [loadingLoans, setLoadingLoans] = useState(false);
  const [paymentPlanMonths, setPaymentPlanMonths] = useState(6);
  const [notes, setNotes] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState(null);

  // Calcular totales
  const totalSelected = selectedLoans.reduce((sum, loanId) => {
    const loan = loans.find(l => l.id === loanId);
    return sum + (loan ? parseFloat(loan.pending_associate_payment || 0) : 0);
  }, 0);
  
  const monthlyPayment = paymentPlanMonths > 0 ? totalSelected / paymentPlanMonths : 0;

  // Búsqueda de asociados
  const searchAssociates = useCallback(async (term) => {
    if (!term || term.length < 2) {
      setSearchResults([]);
      return;
    }
    setIsSearching(true);
    try {
      const response = await associatesService.searchAvailable(term, 0, 10);
      setSearchResults(response.data || []);
    } catch (err) {
      console.error('Error buscando asociados:', err);
      setSearchResults([]);
    } finally {
      setIsSearching(false);
    }
  }, []);

  // Debounce búsqueda
  useEffect(() => {
    const timer = setTimeout(() => searchAssociates(searchTerm), 300);
    return () => clearTimeout(timer);
  }, [searchTerm, searchAssociates]);

  // Cargar préstamos al seleccionar asociado
  useEffect(() => {
    if (!selectedAssociate) {
      setLoans([]);
      setSelectedLoans([]);
      return;
    }

    const loadLoans = async () => {
      setLoadingLoans(true);
      setError(null);
      try {
        const response = await loansService.getAll({ 
          associate_user_id: selectedAssociate.user_id,
          status_id: 2,
          limit: 100
        });
        
        const allLoans = response.data?.items || [];
        
        // Cargar amortización para cada préstamo
        const loansWithDetails = await Promise.all(
          allLoans.map(async (loan) => {
            try {
              const amortRes = await loansService.getAmortization(loan.id);
              const schedule = amortRes.data?.schedule || [];
              const today = new Date();
              const pending = schedule.filter(p => new Date(p.payment_date) >= today);
              const pendingAmount = pending.reduce((sum, p) => sum + parseFloat(p.associate_payment || 0), 0);
              
              return {
                ...loan,
                pending_count: pending.length,
                pending_associate_payment: pendingAmount,
                total_payments: schedule.length
              };
            } catch {
              return { ...loan, pending_count: 0, pending_associate_payment: 0, total_payments: 0 };
            }
          })
        );
        
        setLoans(loansWithDetails.filter(l => l.pending_count > 0));
      } catch (err) {
        console.error('Error cargando préstamos:', err);
        setError('Error al cargar préstamos');
      } finally {
        setLoadingLoans(false);
      }
    };

    loadLoans();
  }, [selectedAssociate]);

  // Handlers
  const handleSelectAssociate = (associate) => {
    setSelectedAssociate(associate);
    setSearchTerm('');
    setSearchResults([]);
  };

  const handleClearAssociate = () => {
    setSelectedAssociate(null);
    setLoans([]);
    setSelectedLoans([]);
  };

  const toggleLoan = (loanId) => {
    setSelectedLoans(prev => 
      prev.includes(loanId) ? prev.filter(id => id !== loanId) : [...prev, loanId]
    );
  };

  const toggleSelectAll = () => {
    setSelectedLoans(selectedLoans.length === loans.length ? [] : loans.map(l => l.id));
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!selectedAssociate || selectedLoans.length === 0) return;
    
    setIsSubmitting(true);
    setError(null);

    try {
      const today = new Date().toISOString().split('T')[0]; // YYYY-MM-DD
      const response = await agreementsService.createAgreementFromLoans({
        associate_profile_id: selectedAssociate.id,
        loan_ids: selectedLoans,
        payment_plan_months: paymentPlanMonths,
        start_date: today,
        notes: notes || null
      });
      
      navigate('/convenios', { 
        state: { success: `Convenio ${response.data?.agreement_number} creado exitosamente` } 
      });
    } catch (err) {
      setError(err.response?.data?.detail || 'Error al crear convenio');
    } finally {
      setIsSubmitting(false);
    }
  };

  const formatCurrency = (amount) => {
    return new Intl.NumberFormat('es-MX', { style: 'currency', currency: 'MXN' }).format(amount);
  };

  const formatDate = (dateString) => {
    if (!dateString) return '-';
    return new Date(dateString).toLocaleDateString('es-MX', { day: '2-digit', month: 'short', year: 'numeric' });
  };

  return (
    <div className="nuevo-convenio-page">
      {/* Header */}
      <header className="nc-header">
        <div className="nc-header-content">
          <h1>➕ Nuevo Convenio</h1>
          <p>Transferir pagos pendientes de préstamos activos a deuda consolidada del asociado</p>
        </div>
      </header>

      {error && (
        <div className="nc-alert nc-alert-error">
          <span>⚠️</span>
          <span>{error}</span>
          <button onClick={() => setError(null)}>×</button>
        </div>
      )}

      <form onSubmit={handleSubmit} className="nc-form">
        
        {/* PASO 1: Seleccionar Asociado */}
        <section className="nc-section">
          <div className="nc-section-header">
            <span className="nc-step-badge">1</span>
            <h2>Seleccionar Asociado</h2>
          </div>

          {!selectedAssociate ? (
            <div className="nc-search-wrapper">
              <input
                type="text"
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                placeholder="Buscar por nombre, email o teléfono..."
                className="nc-search-input"
                autoComplete="off"
              />
              {isSearching && <span className="nc-search-loading">🔍</span>}
              
              {searchResults.length > 0 && (
                <ul className="nc-dropdown">
                  {searchResults.map((a) => (
                    <li key={a.id} onClick={() => handleSelectAssociate(a)}>
                      <div className="nc-dropdown-main">
                        <strong>{a.full_name}</strong>
                        <span>{a.email}</span>
                      </div>
                      <span className="nc-dropdown-badge">{formatCurrency(a.pending_payments_total)}</span>
                    </li>
                  ))}
                </ul>
              )}
              
              {searchTerm.length >= 2 && searchResults.length === 0 && !isSearching && (
                <div className="nc-no-results">No se encontraron asociados</div>
              )}
            </div>
          ) : (
            <div className="nc-associate-card">
              <div className="nc-associate-main">
                <div className="nc-associate-avatar">
                  {selectedAssociate.full_name.charAt(0).toUpperCase()}
                </div>
                <div className="nc-associate-info">
                  <h3>{selectedAssociate.full_name}</h3>
                  <span>{selectedAssociate.email}</span>
                </div>
              </div>
              
              <div className="nc-associate-stats">
                <div className="nc-stat">
                  <span className="nc-stat-label">Límite</span>
                  <span className="nc-stat-value">{formatCurrency(selectedAssociate.credit_limit)}</span>
                </div>
                <div className="nc-stat">
                  <span className="nc-stat-label">Pendiente</span>
                  <span className="nc-stat-value nc-stat-warning">{formatCurrency(selectedAssociate.pending_payments_total)}</span>
                </div>
                <div className="nc-stat">
                  <span className="nc-stat-label">Disponible</span>
                  <span className="nc-stat-value nc-stat-success">{formatCurrency(selectedAssociate.available_credit)}</span>
                </div>
              </div>
              
              <button type="button" onClick={handleClearAssociate} className="nc-btn-change">
                Cambiar
              </button>
            </div>
          )}
        </section>

        {/* PASO 2: Seleccionar Préstamos */}
        {selectedAssociate && (
          <section className="nc-section">
            <div className="nc-section-header">
              <span className="nc-step-badge">2</span>
              <h2>Seleccionar Préstamos</h2>
              {loans.length > 0 && (
                <label className="nc-select-all">
                  <input
                    type="checkbox"
                    checked={selectedLoans.length === loans.length && loans.length > 0}
                    onChange={toggleSelectAll}
                  />
                  Seleccionar todos ({loans.length})
                </label>
              )}
            </div>

            {loadingLoans ? (
              <div className="nc-loading">
                <div className="nc-spinner"></div>
                <span>Cargando préstamos...</span>
              </div>
            ) : loans.length === 0 ? (
              <div className="nc-empty">
                <span>📋</span>
                <p>No hay préstamos activos con pagos pendientes</p>
              </div>
            ) : (
              <div className="nc-loans-grid">
                {loans.map((loan) => (
                  <div 
                    key={loan.id} 
                    className={`nc-loan-card ${selectedLoans.includes(loan.id) ? 'selected' : ''}`}
                    onClick={() => toggleLoan(loan.id)}
                  >
                    <div className="nc-loan-checkbox">
                      <input
                        type="checkbox"
                        checked={selectedLoans.includes(loan.id)}
                        onChange={() => {}}
                      />
                    </div>
                    
                    <div className="nc-loan-content">
                      <div className="nc-loan-header">
                        <span className="nc-loan-id">#{loan.id}</span>
                        <span className="nc-loan-date">{formatDate(loan.created_at)}</span>
                      </div>
                      
                      <div className="nc-loan-client">
                        <span>👤</span>
                        <span>{loan.client_name || 'Cliente'}</span>
                      </div>
                      
                      <div className="nc-loan-details">
                        <div className="nc-loan-detail">
                          <span>Monto</span>
                          <strong>{formatCurrency(loan.amount)}</strong>
                        </div>
                        <div className="nc-loan-detail">
                          <span>Pagos</span>
                          <strong>{loan.pending_count} / {loan.total_payments}</strong>
                        </div>
                        <div className="nc-loan-detail nc-loan-highlight">
                          <span>A transferir</span>
                          <strong>{formatCurrency(loan.pending_associate_payment)}</strong>
                        </div>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </section>
        )}

        {/* PASO 3: Configurar Plan */}
        {selectedLoans.length > 0 && (
          <section className="nc-section">
            <div className="nc-section-header">
              <span className="nc-step-badge">3</span>
              <h2>Plan de Pago</h2>
            </div>

            <div className="nc-plan-config">
              <div className="nc-plan-input">
                <label>Número de meses</label>
                <div className="nc-months-control">
                  <button type="button" onClick={() => setPaymentPlanMonths(Math.max(1, paymentPlanMonths - 1))}>−</button>
                  <input
                    type="number"
                    value={paymentPlanMonths}
                    onChange={(e) => setPaymentPlanMonths(Math.min(36, Math.max(1, parseInt(e.target.value) || 1)))}
                    min="1"
                    max="36"
                  />
                  <button type="button" onClick={() => setPaymentPlanMonths(Math.min(36, paymentPlanMonths + 1))}>+</button>
                </div>
              </div>
              
              <div className="nc-plan-input nc-plan-notes">
                <label>Notas (opcional)</label>
                <textarea
                  value={notes}
                  onChange={(e) => setNotes(e.target.value)}
                  placeholder="Comentarios sobre el convenio..."
                  rows={2}
                />
              </div>
            </div>

            {/* Resumen */}
            <div className="nc-summary">
              <h3>📊 Resumen del Convenio</h3>
              
              <div className="nc-summary-grid">
                <div className="nc-summary-item">
                  <span>Préstamos</span>
                  <strong>{selectedLoans.length}</strong>
                </div>
                <div className="nc-summary-item">
                  <span>Meses</span>
                  <strong>{paymentPlanMonths}</strong>
                </div>
                <div className="nc-summary-item nc-summary-total">
                  <span>Total a Transferir</span>
                  <strong>{formatCurrency(totalSelected)}</strong>
                </div>
                <div className="nc-summary-item nc-summary-monthly">
                  <span>Pago Mensual</span>
                  <strong>{formatCurrency(monthlyPayment)}</strong>
                </div>
              </div>

              <div className="nc-summary-note">
                <strong>ℹ️ Nota:</strong> El monto se transferirá de "Pagos Pendientes" a "Deuda Consolidada". 
                El crédito disponible no cambiará.
              </div>
            </div>
          </section>
        )}

        {/* Acciones */}
        <div className="nc-actions">
          <button type="button" onClick={() => navigate('/convenios')} className="nc-btn nc-btn-secondary">
            Cancelar
          </button>
          <button 
            type="submit" 
            disabled={isSubmitting || selectedLoans.length === 0}
            className="nc-btn nc-btn-primary"
          >
            {isSubmitting ? 'Creando...' : 'Crear Convenio'}
          </button>
        </div>
      </form>
    </div>
  );
};

export default NuevoConvenioPage;
