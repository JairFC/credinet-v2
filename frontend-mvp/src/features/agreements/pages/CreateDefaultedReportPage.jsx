/**
 * Create Defaulted Report Page
 * 
 * Permite a un admin/asociado reportar un cliente moroso
 * 
 * FLUJO:
 * 1. Seleccionar préstamo con pagos pendientes
 * 2. El sistema calcula automáticamente la deuda (suma de associate_payment pendientes)
 * 3. Agregar evidencia (descripción obligatoria, archivo opcional)
 * 4. Crear reporte en estado PENDING
 * 
 * IMPORTANTE:
 * - La deuda se calcula como SUM(associate_payment) de pagos PENDING
 * - Esto representa lo que el asociado DEBE PAGAR a CrediCuenta
 * - NO es lo que el cliente debía (expected_amount)
 */
import { useState, useEffect } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { agreementsService } from '@/shared/api/services/agreementsService';
import { loansService } from '@/shared/api/services/loansService';
import './CreateDefaultedReportPage.css';

const CreateDefaultedReportPage = () => {
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  const preselectedLoanId = searchParams.get('loan_id');

  const [loadingLoan, setLoadingLoan] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState(null);
  
  // Form state
  const [loanId, setLoanId] = useState(preselectedLoanId || '');
  const [loanData, setLoanData] = useState(null);
  const [evidenceDetails, setEvidenceDetails] = useState('');
  const [evidenceFile, setEvidenceFile] = useState(null);
  
  // Calculated debt (from associate_payment of pending payments)
  const [calculatedDebt, setCalculatedDebt] = useState(null);
  
  // Search functionality
  const [searchMode, setSearchMode] = useState(!preselectedLoanId);
  const [searchResults, setSearchResults] = useState([]);
  const [searchQuery, setSearchQuery] = useState('');
  const [searching, setSearching] = useState(false);

  // Load loan data when loanId changes
  useEffect(() => {
    if (loanId && !searchMode) {
      loadLoanData(loanId);
    }
  }, [loanId, searchMode]);

  const loadLoanData = async (id) => {
    try {
      setLoadingLoan(true);
      setError(null);
      
      // Get loan details
      const loanResponse = await loansService.getById(id);
      const loan = loanResponse.data;
      
      // Validate loan status
      if (loan.status_name !== 'ACTIVE') {
        setError(`El préstamo #${id} no está activo (Estado: ${loan.status_name})`);
        setLoanData(null);
        return;
      }
      
      // Get amortization to calculate pending debt
      const amortResponse = await loansService.getAmortization(id);
      const payments = amortResponse.data.payments || [];
      
      // Calculate debt: sum of associate_payment for PENDING payments
      const pendingPayments = payments.filter(p => p.status === 'PENDING' || p.status_id === 1);
      const totalDebt = pendingPayments.reduce((sum, p) => {
        // associate_payment = expected_amount - commission_amount
        const associatePayment = parseFloat(p.associate_payment || 0) || 
                                 (parseFloat(p.expected_amount || 0) - parseFloat(p.commission_amount || 0));
        return sum + associatePayment;
      }, 0);
      
      setLoanData({
        ...loan,
        pending_payments: pendingPayments,
        pending_count: pendingPayments.length,
        total_payments: payments.length,
      });
      
      setCalculatedDebt({
        total: totalDebt,
        breakdown: {
          pending_payments: pendingPayments.length,
          // For info display
          sum_expected: pendingPayments.reduce((sum, p) => sum + parseFloat(p.expected_amount || 0), 0),
          sum_commission: pendingPayments.reduce((sum, p) => sum + parseFloat(p.commission_amount || 0), 0),
          sum_associate_payment: totalDebt,
        }
      });
      
    } catch (err) {
      console.error('Error loading loan:', err);
      setError(err.response?.data?.detail || 'Error al cargar el préstamo');
      setLoanData(null);
      setCalculatedDebt(null);
    } finally {
      setLoadingLoan(false);
    }
  };

  const handleSearch = async () => {
    if (!searchQuery.trim()) return;
    
    try {
      setSearching(true);
      // Search loans with pending payments
      const response = await loansService.getAll({
        search: searchQuery,
        status_id: 2,  // ACTIVE only
        limit: 10
      });
      
      setSearchResults(response.data.items || response.data || []);
    } catch (err) {
      console.error('Error searching loans:', err);
      setSearchResults([]);
    } finally {
      setSearching(false);
    }
  };

  const selectLoan = (loan) => {
    setLoanId(loan.id.toString());
    setSearchMode(false);
    setSearchResults([]);
    setSearchQuery('');
  };

  const handleFileChange = (e) => {
    const file = e.target.files[0];
    if (file) {
      // Validate file size (max 5MB)
      if (file.size > 5 * 1024 * 1024) {
        alert('El archivo no puede ser mayor a 5MB');
        return;
      }
      setEvidenceFile(file);
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    
    if (!loanData || !calculatedDebt) {
      setError('Debe seleccionar un préstamo válido');
      return;
    }
    
    if (!evidenceDetails.trim()) {
      setError('Debe proporcionar detalles de la evidencia');
      return;
    }
    
    if (evidenceDetails.trim().length < 20) {
      setError('La descripción de evidencia debe tener al menos 20 caracteres');
      return;
    }
    
    try {
      setSubmitting(true);
      setError(null);
      
      const reportData = {
        loan_id: parseInt(loanId),
        total_debt_amount: calculatedDebt.total,
        evidence_details: evidenceDetails.trim(),
        ...(evidenceFile && { evidence_file: evidenceFile }),
      };
      
      await agreementsService.createDefaultedReport(reportData);
      
      alert(
        `✅ Reporte creado exitosamente\n\n` +
        `📋 Detalles:\n` +
        `• Préstamo: #${loanId}\n` +
        `• Cliente: ${loanData.client_name || 'N/A'}\n` +
        `• Deuda reportada: $${calculatedDebt.total.toLocaleString('es-MX', { minimumFractionDigits: 2 })}\n` +
        `• Estado: PENDIENTE DE APROBACIÓN\n\n` +
        `El reporte será revisado por un administrador.`
      );
      
      navigate('/convenios/reportes');
      
    } catch (err) {
      console.error('Error creating report:', err);
      setError(err.response?.data?.detail || 'Error al crear el reporte');
    } finally {
      setSubmitting(false);
    }
  };

  const formatCurrency = (amount) => {
    return `$${parseFloat(amount || 0).toLocaleString('es-MX', { minimumFractionDigits: 2 })}`;
  };

  return (
    <div className="create-report-page">
      <div className="page-header">
        <button className="btn-back" onClick={() => navigate('/convenios/reportes')}>
          ← Volver
        </button>
        <h1>🚨 Reportar Cliente Moroso</h1>
      </div>

      {/* Info Banner */}
      <div className="info-banner">
        <div className="info-icon">ℹ️</div>
        <div className="info-content">
          <strong>¿Qué es un reporte de moroso?</strong>
          <p>
            Cuando un cliente no paga y el asociado no puede cobrar, se puede reportar como moroso.
            La deuda se calcula automáticamente como la suma de <code>associate_payment</code> de los pagos pendientes
            (lo que el asociado debería pagar a CrediCuenta).
          </p>
        </div>
      </div>

      <form onSubmit={handleSubmit} className="report-form">
        {/* Step 1: Select Loan */}
        <div className="form-section">
          <h2>1️⃣ Seleccionar Préstamo</h2>
          
          {searchMode ? (
            <div className="loan-search">
              <div className="search-input-group">
                <input
                  type="text"
                  placeholder="Buscar por ID de préstamo, nombre de cliente o asociado..."
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  onKeyDown={(e) => e.key === 'Enter' && (e.preventDefault(), handleSearch())}
                />
                <button 
                  type="button" 
                  className="btn btn-primary"
                  onClick={handleSearch}
                  disabled={searching}
                >
                  {searching ? '...' : '🔍 Buscar'}
                </button>
              </div>
              
              {searchResults.length > 0 && (
                <div className="search-results">
                  {searchResults.map(loan => (
                    <div 
                      key={loan.id} 
                      className="search-result-item"
                      onClick={() => selectLoan(loan)}
                    >
                      <div className="result-main">
                        <span className="loan-id">#{loan.id}</span>
                        <span className="client-name">{loan.client_name || `Cliente #${loan.user_id}`}</span>
                      </div>
                      <div className="result-details">
                        <span>Monto: {formatCurrency(loan.amount)}</span>
                        <span>Asociado: {loan.associate_name || `#${loan.associate_user_id}`}</span>
                      </div>
                    </div>
                  ))}
                </div>
              )}
              
              <div className="manual-input">
                <span>O ingresa el ID directamente:</span>
                <input
                  type="number"
                  placeholder="ID del préstamo"
                  value={loanId}
                  onChange={(e) => setLoanId(e.target.value)}
                />
                <button 
                  type="button"
                  className="btn btn-secondary"
                  onClick={() => loanId && setSearchMode(false)}
                  disabled={!loanId}
                >
                  Cargar
                </button>
              </div>
            </div>
          ) : (
            <div className="selected-loan">
              {loadingLoan ? (
                <div className="loading-loan">
                  <div className="spinner-small"></div>
                  <span>Cargando préstamo #{loanId}...</span>
                </div>
              ) : loanData ? (
                <div className="loan-details-card">
                  <div className="card-header">
                    <div className="loan-info">
                      <span className="loan-id">Préstamo #{loanData.id}</span>
                      <span className={`status-badge ${loanData.status_name?.toLowerCase()}`}>
                        {loanData.status_name}
                      </span>
                    </div>
                    <button 
                      type="button"
                      className="btn btn-sm btn-secondary"
                      onClick={() => { setSearchMode(true); setLoanData(null); setCalculatedDebt(null); }}
                    >
                      Cambiar
                    </button>
                  </div>
                  
                  <div className="card-body">
                    <div className="info-grid">
                      <div className="info-item">
                        <span className="label">Cliente:</span>
                        <span className="value">{loanData.client_name || `#${loanData.user_id}`}</span>
                      </div>
                      <div className="info-item">
                        <span className="label">Asociado:</span>
                        <span className="value">{loanData.associate_name || `#${loanData.associate_user_id}`}</span>
                      </div>
                      <div className="info-item">
                        <span className="label">Monto original:</span>
                        <span className="value">{formatCurrency(loanData.amount)}</span>
                      </div>
                      <div className="info-item">
                        <span className="label">Pagos pendientes:</span>
                        <span className="value">{loanData.pending_count} de {loanData.total_payments}</span>
                      </div>
                    </div>
                  </div>
                </div>
              ) : (
                <div className="no-loan">
                  <p>No se pudo cargar el préstamo</p>
                  <button 
                    type="button"
                    className="btn btn-secondary"
                    onClick={() => setSearchMode(true)}
                  >
                    Buscar otro
                  </button>
                </div>
              )}
            </div>
          )}
        </div>

        {/* Step 2: Debt Calculation (auto) */}
        {calculatedDebt && (
          <div className="form-section">
            <h2>2️⃣ Cálculo de Deuda (Automático)</h2>
            
            <div className="debt-calculation">
              <div className="debt-total">
                <span className="label">Deuda a reportar:</span>
                <span className="amount">{formatCurrency(calculatedDebt.total)}</span>
              </div>
              
              <div className="debt-breakdown">
                <h4>Desglose:</h4>
                <table>
                  <tbody>
                    <tr>
                      <td>Pagos pendientes:</td>
                      <td>{calculatedDebt.breakdown.pending_payments}</td>
                    </tr>
                    <tr>
                      <td>Suma que cliente debía (expected_amount):</td>
                      <td>{formatCurrency(calculatedDebt.breakdown.sum_expected)}</td>
                    </tr>
                    <tr>
                      <td>Comisiones que asociado se quedaba:</td>
                      <td className="positive">- {formatCurrency(calculatedDebt.breakdown.sum_commission)}</td>
                    </tr>
                    <tr className="total-row">
                      <td><strong>= Lo que asociado paga a CrediCuenta (associate_payment):</strong></td>
                      <td><strong>{formatCurrency(calculatedDebt.breakdown.sum_associate_payment)}</strong></td>
                    </tr>
                  </tbody>
                </table>
              </div>
              
              <div className="debt-note">
                <strong>💡 Nota:</strong> Esta es la deuda real que se sumará a la <code>consolidated_debt</code> del asociado 
                si el reporte es aprobado. Representa lo que el asociado debería haber pagado a CrediCuenta.
              </div>
            </div>
          </div>
        )}

        {/* Step 3: Evidence */}
        {calculatedDebt && (
          <div className="form-section">
            <h2>3️⃣ Evidencia de Morosidad</h2>
            
            <div className="form-group">
              <label htmlFor="evidenceDetails">Descripción de la evidencia *</label>
              <textarea
                id="evidenceDetails"
                value={evidenceDetails}
                onChange={(e) => setEvidenceDetails(e.target.value)}
                placeholder="Describa los intentos de cobro realizados, comunicaciones con el cliente, fechas de contacto, razones dadas por el cliente, etc. (mínimo 20 caracteres)"
                rows={5}
                required
              />
              <span className="char-count">{evidenceDetails.length} caracteres</span>
            </div>
            
            <div className="form-group">
              <label htmlFor="evidenceFile">Archivo de evidencia (opcional)</label>
              <input
                type="file"
                id="evidenceFile"
                onChange={handleFileChange}
                accept=".pdf,.jpg,.jpeg,.png,.doc,.docx"
              />
              <span className="file-hint">
                Formatos aceptados: PDF, JPG, PNG, DOC. Máximo 5MB.
              </span>
              {evidenceFile && (
                <div className="file-selected">
                  📎 {evidenceFile.name} ({(evidenceFile.size / 1024).toFixed(1)} KB)
                  <button type="button" onClick={() => setEvidenceFile(null)}>✕</button>
                </div>
              )}
            </div>
          </div>
        )}

        {/* Error Message */}
        {error && (
          <div className="error-message">
            ⚠️ {error}
          </div>
        )}

        {/* Submit */}
        {calculatedDebt && (
          <div className="form-actions">
            <button 
              type="button" 
              className="btn btn-secondary"
              onClick={() => navigate('/convenios/reportes')}
              disabled={submitting}
            >
              Cancelar
            </button>
            <button 
              type="submit" 
              className="btn btn-primary btn-lg"
              disabled={submitting || !evidenceDetails.trim()}
            >
              {submitting ? 'Creando reporte...' : '🚨 Crear Reporte de Moroso'}
            </button>
          </div>
        )}
      </form>
    </div>
  );
};

export default CreateDefaultedReportPage;
