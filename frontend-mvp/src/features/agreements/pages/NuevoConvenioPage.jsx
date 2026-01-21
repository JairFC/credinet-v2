/**
 * NuevoConvenioPage - Crear Convenio desde Préstamos Activos
 * 
 * Crea un convenio para que el ASOCIADO pague su deuda a CrediCuenta.
 * Los convenios transfieren pagos pendientes de préstamos activos
 * a deuda consolidada del asociado.
 * 
 * ⚠️ IMPORTANTE: Los convenios son para ASOCIADOS, NO para clientes.
 * El ASOCIADO es quien paga las cuotas del convenio a CrediCuenta.
 * 
 * LÓGICA DE NEGOCIO:
 * - Los convenios se crean desde PRÉSTAMOS ACTIVOS con pagos futuros
 * - pending_payments_total BAJA por el monto de los pagos pendientes
 * - consolidated_debt SUBE por el mismo monto
 * - available_credit QUEDA IGUAL (es una transferencia, no un nuevo cargo)
 * - El préstamo se marca como IN_AGREEMENT (status_id=9)
 * - Los pagos se marcan como IN_AGREEMENT (status_id=13)
 * - El cliente que tiene préstamos en convenio se marca como moroso (referencia)
 * - El ASOCIADO paga las cuotas del convenio → consolidated_debt disminuye
 * 
 * FLUJO:
 * 1. Buscar asociado que tenga préstamos activos
 * 2. Ver lista de préstamos activos del asociado
 * 3. Seleccionar préstamos a incluir en el convenio
 * 4. Definir plan de pago (meses)
 * 5. Crear convenio
 * 6. ASOCIADO paga cuotas mensuales a CrediCuenta
 */
import React, { useState, useEffect, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { agreementsService, associatesService, loansService } from '../../../shared/api/services';
import './NuevoConvenioPage.css';

const NuevoConvenioPage = () => {
  const navigate = useNavigate();
  
  // State para búsqueda de asociado
  const [searchTerm, setSearchTerm] = useState('');
  const [searchResults, setSearchResults] = useState([]);
  const [isSearching, setIsSearching] = useState(false);
  const [selectedAssociate, setSelectedAssociate] = useState(null);
  
  // State para préstamos
  const [loans, setLoans] = useState([]);
  const [selectedLoans, setSelectedLoans] = useState([]);
  const [loadingLoans, setLoadingLoans] = useState(false);
  
  // State para formulario
  const [paymentPlanMonths, setPaymentPlanMonths] = useState(6);
  const [notes, setNotes] = useState('');
  
  // State para UI
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState(null);
  const [successMessage, setSuccessMessage] = useState(null);

  // Calcular totales basados en associate_payment pendiente de cada préstamo
  const totalSelected = selectedLoans.reduce((sum, loanId) => {
    const loan = loans.find(l => l.id === loanId);
    return sum + (loan ? parseFloat(loan.pending_associate_payment || 0) : 0);
  }, 0);
  
  const monthlyPayment = paymentPlanMonths > 0 ? totalSelected / paymentPlanMonths : 0;

  // Búsqueda de asociados usando el endpoint correcto
  const searchAssociates = useCallback(async (term) => {
    if (!term || term.length < 2) {
      setSearchResults([]);
      return;
    }

    setIsSearching(true);
    try {
      // Usar el endpoint de búsqueda que sí soporta filtro
      const response = await associatesService.searchAvailable(term, 0, 10);
      const associates = response.data || [];
      setSearchResults(associates);
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

  // Cargar préstamos activos cuando se selecciona asociado
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
        // Obtener préstamos ACTIVOS del asociado (solo status_id=2)
        // Solo préstamos ACTIVE (2) tienen pagos en curso que pueden transferirse a convenio
        const responseActive = await loansService.getAll({ 
          associate_user_id: selectedAssociate.user_id,
          status_id: 2, // ACTIVE only
          limit: 100
        });
        
        // Solo préstamos activos
        const allLoans = responseActive.data?.items || [];
        
        // Para cada préstamo, estimar pagos pendientes basados en el schedule
        // El backend hará el cálculo exacto al crear el convenio
        const loansWithEstimates = await Promise.all(
          allLoans.map(async (loan) => {
            try {
              const amortResponse = await loansService.getAmortization(loan.id);
              const schedule = amortResponse.data?.schedule || [];
              
              // Contar pagos que aún no han vencido o están pendientes
              // Usamos fecha actual para determinar pendientes
              const today = new Date();
              const pendingSchedule = schedule.filter(p => {
                const paymentDate = new Date(p.payment_date);
                return paymentDate >= today;
              });
              
              // Sumar associate_payment de los pagos futuros
              const estimatedAssociatePayment = pendingSchedule.reduce(
                (sum, p) => sum + parseFloat(p.associate_payment || 0), 
                0
              );
              
              return {
                ...loan,
                pending_payments_count: pendingSchedule.length,
                pending_associate_payment: estimatedAssociatePayment,
                total_scheduled_payments: schedule.length
              };
            } catch (err) {
              console.error(`Error loading amortization for loan ${loan.id}:`, err);
              return {
                ...loan,
                pending_payments_count: 0,
                pending_associate_payment: 0,
                total_scheduled_payments: 0
              };
            }
          })
        );
        
        // Filtrar solo préstamos que tengan pagos pendientes
        const loansWithPendingPayments = loansWithEstimates.filter(
          l => l.pending_payments_count > 0
        );
        
        setLoans(loansWithPendingPayments);
        
        if (loansWithPendingPayments.length === 0 && allLoans.length > 0) {
          setError('Los préstamos de este asociado no tienen pagos futuros pendientes');
        } else if (allLoans.length === 0) {
          setError('Este asociado no tiene préstamos activos');
        }
      } catch (err) {
        console.error('Error cargando préstamos:', err);
        setError('Error al cargar los préstamos del asociado');
        setLoans([]);
      } finally {
        setLoadingLoans(false);
      }
    };

    loadLoans();
  }, [selectedAssociate]);

  // Seleccionar asociado
  const handleSelectAssociate = (associate) => {
    setSelectedAssociate(associate);
    setSearchTerm('');
    setSearchResults([]);
  };

  // Toggle selección de préstamo
  const toggleLoanSelection = (loanId) => {
    setSelectedLoans(prev => 
      prev.includes(loanId)
        ? prev.filter(id => id !== loanId)
        : [...prev, loanId]
    );
  };

  // Seleccionar/deseleccionar todos
  const toggleSelectAll = () => {
    if (selectedLoans.length === loans.length) {
      setSelectedLoans([]);
    } else {
      setSelectedLoans(loans.map(l => l.id));
    }
  };

  // Crear convenio
  const handleSubmit = async (e) => {
    e.preventDefault();
    
    if (!selectedAssociate) {
      setError('Debe seleccionar un asociado');
      return;
    }
    
    if (selectedLoans.length === 0) {
      setError('Debe seleccionar al menos un préstamo');
      return;
    }

    if (paymentPlanMonths < 1 || paymentPlanMonths > 36) {
      setError('El plan de pago debe ser entre 1 y 36 meses');
      return;
    }

    setIsSubmitting(true);
    setError(null);

    try {
      const response = await agreementsService.createAgreementFromLoans({
        loan_ids: selectedLoans,
        payment_plan_months: paymentPlanMonths,
        notes: notes || null
      });
      
      const agreementNumber = response.data?.agreement_number || 'Nuevo';
      
      navigate('/convenios', { 
        state: { success: `Convenio ${agreementNumber} creado exitosamente` } 
      });
    } catch (err) {
      console.error('Error creando convenio:', err);
      setError(err.response?.data?.detail || 'Error al crear el convenio');
    } finally {
      setIsSubmitting(false);
    }
  };

  // Limpiar selección
  const handleReset = () => {
    setSelectedAssociate(null);
    setLoans([]);
    setSelectedLoans([]);
    setPaymentPlanMonths(6);
    setNotes('');
    setError(null);
  };

  // Formatear moneda
  const formatCurrency = (amount) => {
    return new Intl.NumberFormat('es-MX', {
      style: 'currency',
      currency: 'MXN'
    }).format(amount);
  };

  // Formatear fecha
  const formatDate = (dateString) => {
    if (!dateString) return '-';
    return new Date(dateString).toLocaleDateString('es-MX', {
      year: 'numeric',
      month: 'short',
      day: 'numeric'
    });
  };

  return (
    <div className="nuevo-convenio-page">
      <div className="page-header">
        <h1>➕ Nuevo Convenio</h1>
        <p className="page-description">
          Crear convenio desde préstamos activos. Los pagos pendientes se transfieren a deuda del asociado.
        </p>
      </div>

      {error && (
        <div className="alert alert-error">
          <span className="alert-icon">⚠️</span>
          {error}
          <button onClick={() => setError(null)} className="alert-close">×</button>
        </div>
      )}

      {successMessage && (
        <div className="alert alert-success">
          <span className="alert-icon">✓</span>
          {successMessage}
        </div>
      )}

      <form onSubmit={handleSubmit} className="convenio-form">
        {/* PASO 1: Búsqueda de Asociado */}
        <div className="form-section">
          <h2>1. Seleccionar Asociado</h2>
          
          {!selectedAssociate ? (
            <div className="search-container">
              <input
                type="text"
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                placeholder="Buscar asociado por nombre, email o teléfono..."
                className="search-input"
                autoFocus
              />
              
              {isSearching && <div className="search-spinner">Buscando...</div>}
              
              {searchResults.length > 0 && (
                <ul className="search-results">
                  {searchResults.map((associate) => (
                    <li 
                      key={associate.id}
                      onClick={() => handleSelectAssociate(associate)}
                      className="search-result-item"
                    >
                      <div className="associate-info">
                        <strong>{associate.full_name}</strong>
                        <span className="associate-email">{associate.email}</span>
                      </div>
                      <div className="associate-credit">
                        <span className="credit-label">Pagos pendientes:</span>
                        <span className="credit-value">{formatCurrency(associate.pending_payments_total || 0)}</span>
                      </div>
                    </li>
                  ))}
                </ul>
              )}
              
              {searchTerm.length >= 2 && searchResults.length === 0 && !isSearching && (
                <div className="no-results">No se encontraron asociados</div>
              )}
            </div>
          ) : (
            <div className="selected-associate">
              <div className="associate-card">
                <div className="associate-header">
                  <h3>{selectedAssociate.full_name}</h3>
                  <button 
                    type="button" 
                    onClick={handleReset}
                    className="btn-change"
                  >
                    Cambiar
                  </button>
                </div>
                <div className="associate-details">
                  <p><strong>Email:</strong> {selectedAssociate.email}</p>
                  <p><strong>ID Usuario:</strong> {selectedAssociate.user_id}</p>
                  <div className="credit-summary">
                    <div className="credit-item">
                      <span className="label">Límite:</span>
                      <span className="value">{formatCurrency(selectedAssociate.credit_limit || 0)}</span>
                    </div>
                    <div className="credit-item">
                      <span className="label">Pagos Pendientes:</span>
                      <span className="value used">{formatCurrency(selectedAssociate.pending_payments_total || 0)}</span>
                    </div>
                    <div className="credit-item">
                      <span className="label">Deuda Consolidada:</span>
                      <span className="value debt">{formatCurrency(selectedAssociate.consolidated_debt || 0)}</span>
                    </div>
                    <div className="credit-item">
                      <span className="label">Disponible:</span>
                      <span className="value available">{formatCurrency(selectedAssociate.available_credit || 0)}</span>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          )}
        </div>

        {/* PASO 2: Seleccionar Préstamos */}
        {selectedAssociate && (
          <div className="form-section">
            <h2>2. Seleccionar Préstamos Activos</h2>
            
            {loadingLoans ? (
              <div className="loading-state">
                <div className="spinner"></div>
                <p>Cargando préstamos activos...</p>
              </div>
            ) : loans.length === 0 ? (
              <div className="empty-state">
                <p>No hay préstamos activos con pagos pendientes para este asociado.</p>
              </div>
            ) : (
              <>
                <div className="loans-header">
                  <label className="select-all">
                    <input
                      type="checkbox"
                      checked={selectedLoans.length === loans.length && loans.length > 0}
                      onChange={toggleSelectAll}
                    />
                    Seleccionar todos ({loans.length})
                  </label>
                </div>
                
                <div className="loans-list">
                  {loans.map((loan) => (
                    <div 
                      key={loan.id} 
                      className={`loan-item ${selectedLoans.includes(loan.id) ? 'selected' : ''}`}
                      onClick={() => toggleLoanSelection(loan.id)}
                    >
                      <div className="loan-checkbox">
                        <input
                          type="checkbox"
                          checked={selectedLoans.includes(loan.id)}
                          onChange={() => toggleLoanSelection(loan.id)}
                          onClick={(e) => e.stopPropagation()}
                        />
                      </div>
                      <div className="loan-info">
                        <div className="loan-header">
                          <span className="loan-id">Préstamo #{loan.id}</span>
                          <span className="loan-date">{formatDate(loan.created_at)}</span>
                        </div>
                        <div className="loan-client">
                          <strong>Cliente:</strong> {loan.client_name || 'N/A'}
                        </div>
                        <div className="loan-amounts">
                          <div className="amount-item">
                            <span className="label">Monto Original:</span>
                            <span className="value">{formatCurrency(loan.amount)}</span>
                          </div>
                          <div className="amount-item">
                            <span className="label">Pagos Pendientes:</span>
                            <span className="value">{loan.pending_payments_count}</span>
                          </div>
                          <div className="amount-item highlight">
                            <span className="label">A Transferir (Associate):</span>
                            <span className="value">{formatCurrency(loan.pending_associate_payment)}</span>
                          </div>
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              </>
            )}
          </div>
        )}

        {/* PASO 3: Plan de Pago */}
        {selectedLoans.length > 0 && (
          <div className="form-section">
            <h2>3. Configurar Plan de Pago</h2>
            
            <div className="payment-plan-form">
              <div className="form-group">
                <label htmlFor="paymentMonths">Número de Meses:</label>
                <input
                  type="number"
                  id="paymentMonths"
                  value={paymentPlanMonths}
                  onChange={(e) => setPaymentPlanMonths(parseInt(e.target.value) || 1)}
                  min="1"
                  max="36"
                  className="input-months"
                />
                <span className="helper-text">Entre 1 y 36 meses</span>
              </div>
              
              <div className="form-group">
                <label htmlFor="notes">Notas (opcional):</label>
                <textarea
                  id="notes"
                  value={notes}
                  onChange={(e) => setNotes(e.target.value)}
                  placeholder="Agregar notas o comentarios sobre este convenio..."
                  rows={3}
                  className="input-notes"
                />
              </div>
            </div>
            
            <div className="payment-summary">
              <h3>Resumen del Convenio</h3>
              <div className="summary-grid">
                <div className="summary-item">
                  <span className="label">Préstamos Seleccionados:</span>
                  <span className="value">{selectedLoans.length}</span>
                </div>
                <div className="summary-item total">
                  <span className="label">Total a Transferir a Deuda:</span>
                  <span className="value">{formatCurrency(totalSelected)}</span>
                </div>
                <div className="summary-item">
                  <span className="label">Plan de Pago:</span>
                  <span className="value">{paymentPlanMonths} meses</span>
                </div>
                <div className="summary-item monthly">
                  <span className="label">Pago Mensual Estimado:</span>
                  <span className="value">{formatCurrency(monthlyPayment)}</span>
                </div>
              </div>
              
              <div className="info-box">
                <strong>ℹ️ Importante:</strong>
                <ul>
                  <li>Este monto ({formatCurrency(totalSelected)}) se transferirá de <strong>crédito usado</strong> a <strong>deuda del asociado</strong>.</li>
                  <li>El <strong>crédito disponible</strong> del asociado no cambiará.</li>
                  <li>Los préstamos se marcarán como "EN CONVENIO" y los pagos pendientes también.</li>
                  <li>El asociado deberá pagar esta deuda según el plan acordado.</li>
                </ul>
              </div>
            </div>
          </div>
        )}

        {/* Botones de Acción */}
        <div className="form-actions">
          <button 
            type="button" 
            onClick={() => navigate('/convenios')}
            className="btn btn-secondary"
          >
            Cancelar
          </button>
          
          <button 
            type="submit"
            disabled={isSubmitting || selectedLoans.length === 0}
            className="btn btn-primary"
          >
            {isSubmitting ? 'Creando...' : 'Crear Convenio'}
          </button>
        </div>
      </form>
    </div>
  );
};

export default NuevoConvenioPage;
