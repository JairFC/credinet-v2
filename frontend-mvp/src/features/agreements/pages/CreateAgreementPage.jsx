/**
 * CreateAgreementPage - Crear Convenio de Pago
 * 
 * Permite crear un convenio agrupando deudas aprobadas de un asociado
 * en un plan de pago mensual.
 * 
 * FLUJO:
 * 1. Seleccionar asociado con deuda pendiente
 * 2. Ver desglose de deuda (de reportes aprobados)
 * 3. Seleccionar deudas a incluir en el convenio
 * 4. Definir plan de pago (meses)
 * 5. Crear convenio
 */
import React, { useState, useEffect, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { agreementsService, associatesService } from '../../../shared/api/services';
import './CreateAgreementPage.css';

const CreateAgreementPage = () => {
  const navigate = useNavigate();
  
  // State para búsqueda de asociado
  const [searchTerm, setSearchTerm] = useState('');
  const [searchResults, setSearchResults] = useState([]);
  const [isSearching, setIsSearching] = useState(false);
  const [selectedAssociate, setSelectedAssociate] = useState(null);
  
  // State para deudas
  const [debts, setDebts] = useState([]);
  const [selectedDebts, setSelectedDebts] = useState([]);
  const [loadingDebts, setLoadingDebts] = useState(false);
  
  // State para formulario
  const [paymentPlanMonths, setPaymentPlanMonths] = useState(6);
  const [notes, setNotes] = useState('');
  const [startDate, setStartDate] = useState(() => {
    const today = new Date();
    return today.toISOString().split('T')[0];
  });
  
  // State para UI
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState(null);

  // Calcular totales
  const totalSelected = selectedDebts.reduce((sum, debtId) => {
    const debt = debts.find(d => d.id === debtId);
    return sum + (debt ? parseFloat(debt.amount) : 0);
  }, 0);
  
  const monthlyPayment = paymentPlanMonths > 0 ? totalSelected / paymentPlanMonths : 0;

  // Búsqueda de asociados con deuda
  const searchAssociates = useCallback(async (term) => {
    if (!term || term.length < 2) {
      setSearchResults([]);
      return;
    }

    setIsSearching(true);
    try {
      // Buscar asociados
      const response = await associatesService.getAssociates({ search: term, limit: 10 });
      const associates = response.data?.items || response.data || [];
      
      // Filtrar solo los que tienen consolidated_debt > 0
      const withDebt = associates.filter(a => parseFloat(a.consolidated_debt || 0) > 0);
      setSearchResults(withDebt);
    } catch (err) {
      console.error('Error buscando asociados:', err);
      setSearchResults([]);
    } finally {
      setIsSearching(false);
    }
  }, []);

  // Debounce para búsqueda
  useEffect(() => {
    const timer = setTimeout(() => {
      searchAssociates(searchTerm);
    }, 300);
    return () => clearTimeout(timer);
  }, [searchTerm, searchAssociates]);

  // Cargar deudas cuando se selecciona asociado
  useEffect(() => {
    if (!selectedAssociate) {
      setDebts([]);
      setSelectedDebts([]);
      return;
    }

    const loadDebts = async () => {
      setLoadingDebts(true);
      setError(null);
      try {
        const response = await agreementsService.getDebtBreakdown(selectedAssociate.id, { is_liquidated: false });
        const debtItems = response.data?.items || response.data || [];
        setDebts(debtItems);
        // Pre-seleccionar todas las deudas
        setSelectedDebts(debtItems.map(d => d.id));
      } catch (err) {
        console.error('Error cargando deudas:', err);
        setError('Error al cargar el desglose de deuda');
        setDebts([]);
      } finally {
        setLoadingDebts(false);
      }
    };

    loadDebts();
  }, [selectedAssociate]);

  // Seleccionar asociado
  const handleSelectAssociate = (associate) => {
    setSelectedAssociate(associate);
    setSearchTerm('');
    setSearchResults([]);
  };

  // Toggle selección de deuda
  const toggleDebtSelection = (debtId) => {
    setSelectedDebts(prev => 
      prev.includes(debtId)
        ? prev.filter(id => id !== debtId)
        : [...prev, debtId]
    );
  };

  // Seleccionar/deseleccionar todas
  const toggleSelectAll = () => {
    if (selectedDebts.length === debts.length) {
      setSelectedDebts([]);
    } else {
      setSelectedDebts(debts.map(d => d.id));
    }
  };

  // Crear convenio
  const handleSubmit = async (e) => {
    e.preventDefault();
    
    if (!selectedAssociate) {
      setError('Debe seleccionar un asociado');
      return;
    }
    
    if (selectedDebts.length === 0) {
      setError('Debe seleccionar al menos una deuda');
      return;
    }

    if (paymentPlanMonths < 1 || paymentPlanMonths > 36) {
      setError('El plan de pago debe ser entre 1 y 36 meses');
      return;
    }

    setIsSubmitting(true);
    setError(null);

    try {
      await agreementsService.createAgreement({
        associate_profile_id: selectedAssociate.id,
        debt_breakdown_ids: selectedDebts,
        payment_plan_months: paymentPlanMonths,
        start_date: startDate,
        notes: notes || null
      });
      
      navigate('/convenios', { 
        state: { success: 'Convenio creado exitosamente' } 
      });
    } catch (err) {
      console.error('Error creando convenio:', err);
      setError(err.response?.data?.detail || 'Error al crear el convenio');
    } finally {
      setIsSubmitting(false);
    }
  };

  // Formatear moneda
  const formatCurrency = (amount) => {
    return new Intl.NumberFormat('es-MX', {
      style: 'currency',
      currency: 'MXN'
    }).format(amount);
  };

  // Formatear tipo de deuda
  const formatDebtType = (type) => {
    const types = {
      DEFAULTED_CLIENT: 'Cliente Moroso',
      UNREPORTED_PAYMENT: 'Pago No Reportado',
      LATE_FEE: 'Cargo por Mora',
      OTHER: 'Otro'
    };
    return types[type] || type;
  };

  return (
    <div className="create-agreement-page">
      <div className="page-header">
        <button 
          className="btn-back" 
          onClick={() => navigate('/convenios')}
        >
          ← Volver a Convenios
        </button>
        <h1>Crear Nuevo Convenio</h1>
        <p className="subtitle">
          Agrupa las deudas de un asociado en un plan de pago mensual
        </p>
      </div>

      {error && (
        <div className="error-banner">
          <span>⚠️</span>
          {error}
          <button onClick={() => setError(null)}>×</button>
        </div>
      )}

      <form onSubmit={handleSubmit} className="agreement-form">
        {/* Paso 1: Buscar Asociado */}
        <section className="form-section">
          <h2>1. Seleccionar Asociado</h2>
          
          {!selectedAssociate ? (
            <div className="search-section">
              <div className="search-input-wrapper">
                <input
                  type="text"
                  placeholder="Buscar asociado por nombre, CURP o teléfono..."
                  value={searchTerm}
                  onChange={(e) => setSearchTerm(e.target.value)}
                  className="search-input"
                />
                {isSearching && <span className="search-spinner">🔄</span>}
              </div>
              
              {searchResults.length > 0 && (
                <div className="search-results">
                  {searchResults.map(associate => (
                    <div 
                      key={associate.id}
                      className="search-result-item"
                      onClick={() => handleSelectAssociate(associate)}
                    >
                      <div className="associate-info">
                        <span className="associate-name">
                          {associate.full_name || `${associate.first_name} ${associate.last_name}`}
                        </span>
                        <span className="associate-curp">{associate.curp}</span>
                      </div>
                      <div className="debt-badge">
                        Deuda: {formatCurrency(associate.consolidated_debt || 0)}
                      </div>
                    </div>
                  ))}
                </div>
              )}
              
              {searchTerm.length >= 2 && searchResults.length === 0 && !isSearching && (
                <p className="no-results">
                  No se encontraron asociados con deuda pendiente
                </p>
              )}
            </div>
          ) : (
            <div className="selected-associate">
              <div className="associate-card">
                <div className="associate-details">
                  <h3>{selectedAssociate.full_name || `${selectedAssociate.first_name} ${selectedAssociate.last_name}`}</h3>
                  <p><strong>CURP:</strong> {selectedAssociate.curp}</p>
                  <p><strong>Teléfono:</strong> {selectedAssociate.phone}</p>
                </div>
                <div className="associate-debt-info">
                  <span className="debt-label">Deuda Consolidada</span>
                  <span className="debt-amount">{formatCurrency(selectedAssociate.consolidated_debt || 0)}</span>
                </div>
                <button 
                  type="button"
                  className="btn-change"
                  onClick={() => setSelectedAssociate(null)}
                >
                  Cambiar
                </button>
              </div>
            </div>
          )}
        </section>

        {/* Paso 2: Seleccionar Deudas */}
        {selectedAssociate && (
          <section className="form-section">
            <h2>2. Seleccionar Deudas a Incluir</h2>
            
            {loadingDebts ? (
              <div className="loading-state">
                <span className="spinner">🔄</span>
                Cargando desglose de deuda...
              </div>
            ) : debts.length === 0 ? (
              <div className="empty-state">
                <p>No hay deudas pendientes para este asociado</p>
              </div>
            ) : (
              <>
                <div className="debts-header">
                  <label className="select-all">
                    <input
                      type="checkbox"
                      checked={selectedDebts.length === debts.length}
                      onChange={toggleSelectAll}
                    />
                    Seleccionar todas ({debts.length})
                  </label>
                  <span className="selected-count">
                    {selectedDebts.length} de {debts.length} seleccionadas
                  </span>
                </div>
                
                <div className="debts-list">
                  {debts.map(debt => (
                    <div 
                      key={debt.id}
                      className={`debt-item ${selectedDebts.includes(debt.id) ? 'selected' : ''}`}
                      onClick={() => toggleDebtSelection(debt.id)}
                    >
                      <input
                        type="checkbox"
                        checked={selectedDebts.includes(debt.id)}
                        onChange={() => toggleDebtSelection(debt.id)}
                        onClick={(e) => e.stopPropagation()}
                      />
                      <div className="debt-details">
                        <span className="debt-type">{formatDebtType(debt.debt_type)}</span>
                        <span className="debt-description">{debt.description || 'Sin descripción'}</span>
                        {debt.loan_id && (
                          <span className="debt-loan">Préstamo #{debt.loan_id}</span>
                        )}
                        <span className="debt-date">
                          Registrado: {new Date(debt.created_at).toLocaleDateString('es-MX')}
                        </span>
                      </div>
                      <span className="debt-amount">{formatCurrency(debt.amount)}</span>
                    </div>
                  ))}
                </div>
              </>
            )}
          </section>
        )}

        {/* Paso 3: Configurar Plan de Pago */}
        {selectedAssociate && selectedDebts.length > 0 && (
          <section className="form-section">
            <h2>3. Configurar Plan de Pago</h2>
            
            <div className="payment-config">
              <div className="form-row">
                <div className="form-group">
                  <label htmlFor="paymentPlanMonths">Plazo (meses)</label>
                  <input
                    type="number"
                    id="paymentPlanMonths"
                    value={paymentPlanMonths}
                    onChange={(e) => setPaymentPlanMonths(parseInt(e.target.value) || 1)}
                    min="1"
                    max="36"
                    className="form-control"
                  />
                  <span className="help-text">Mínimo 1, máximo 36 meses</span>
                </div>
                
                <div className="form-group">
                  <label htmlFor="startDate">Fecha de Inicio</label>
                  <input
                    type="date"
                    id="startDate"
                    value={startDate}
                    onChange={(e) => setStartDate(e.target.value)}
                    className="form-control"
                  />
                </div>
              </div>

              <div className="form-group">
                <label htmlFor="notes">Notas (opcional)</label>
                <textarea
                  id="notes"
                  value={notes}
                  onChange={(e) => setNotes(e.target.value)}
                  placeholder="Notas adicionales sobre el convenio..."
                  className="form-control"
                  rows="3"
                />
              </div>
            </div>

            {/* Resumen del Convenio */}
            <div className="agreement-summary">
              <h3>Resumen del Convenio</h3>
              <div className="summary-grid">
                <div className="summary-item">
                  <span className="summary-label">Deudas Incluidas</span>
                  <span className="summary-value">{selectedDebts.length}</span>
                </div>
                <div className="summary-item">
                  <span className="summary-label">Deuda Total</span>
                  <span className="summary-value highlight">{formatCurrency(totalSelected)}</span>
                </div>
                <div className="summary-item">
                  <span className="summary-label">Plazo</span>
                  <span className="summary-value">{paymentPlanMonths} meses</span>
                </div>
                <div className="summary-item">
                  <span className="summary-label">Pago Mensual</span>
                  <span className="summary-value highlight">{formatCurrency(monthlyPayment)}</span>
                </div>
              </div>
            </div>
          </section>
        )}

        {/* Botón de Submit */}
        {selectedAssociate && selectedDebts.length > 0 && (
          <div className="form-actions">
            <button 
              type="button"
              className="btn btn-secondary"
              onClick={() => navigate('/convenios')}
              disabled={isSubmitting}
            >
              Cancelar
            </button>
            <button 
              type="submit"
              className="btn btn-primary"
              disabled={isSubmitting}
            >
              {isSubmitting ? 'Creando...' : 'Crear Convenio'}
            </button>
          </div>
        )}
      </form>
    </div>
  );
};

export default CreateAgreementPage;
