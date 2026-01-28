import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { loansService } from '@/shared/api/services/loansService';
import { rateProfilesService } from '@/shared/api/services/rateProfilesService';
import ClientSelector from '../../../shared/components/ClientSelector/ClientSelector';
import AssociateSelector from '../../../shared/components/AssociateSelector/AssociateSelector';
import LoanSummaryPreview from '../components/LoanSummaryPreview';
import SuccessNotification from '../../../shared/components/SuccessNotification';
import './LoanCreatePage.css';

const LoanCreatePage = () => {
  const navigate = useNavigate();
  const [loading, setLoading] = useState(false);
  const [loadingProfiles, setLoadingProfiles] = useState(true);

  // Estados para los selectores
  const [selectedClient, setSelectedClient] = useState(null);
  const [selectedAssociate, setSelectedAssociate] = useState(null);

  // Estados para perfiles y restricciones
  const [profiles, setProfiles] = useState([]);
  const [legacyAmounts, setLegacyAmounts] = useState([]);
  const [selectedProfile, setSelectedProfile] = useState(null);

  // Estados para preview de cálculos
  const [calculation, setCalculation] = useState(null);
  const [calculatingPreview, setCalculatingPreview] = useState(false);

  // ⭐ Estado para notificación de éxito
  const [successNotification, setSuccessNotification] = useState({
    isOpen: false,
    loanId: null,
    isRenewal: false,
    renewalDetails: null
  });

  // ⭐ ESTADOS PARA RENOVACIÓN
  const [clientActiveLoans, setClientActiveLoans] = useState([]);
  const [loadingActiveLoans, setLoadingActiveLoans] = useState(false);
  const [isRenewal, setIsRenewal] = useState(false);
  const [selectedLoanToRenew, setSelectedLoanToRenew] = useState(null);
  const [renewalExpanded, setRenewalExpanded] = useState(false); // Colapsado por defecto
  const [renewalPage, setRenewalPage] = useState(1);
  const LOANS_PER_PAGE = 3;

  const [formData, setFormData] = useState({
    amount: '',
    term_biweeks: '12',
    profile_code: 'legacy',
    interest_rate: '',
    commission_rate: '',
    notes: '',
    useCustomAmount: false,
    customAmount: ''
  });

  const [errors, setErrors] = useState({});

  // Cargar perfiles de tasa al montar el componente
  useEffect(() => {
    loadRateProfiles();
  }, []);

  // ⭐ Verificar si el cliente tiene préstamos activos cuando se selecciona
  useEffect(() => {
    const checkActiveLoans = async () => {
      if (!selectedClient?.id) {
        setClientActiveLoans([]);
        setIsRenewal(false);
        setSelectedLoanToRenew(null);
        setRenewalExpanded(false);
        setRenewalPage(1);
        return;
      }

      try {
        setLoadingActiveLoans(true);
        // Resetear estados de UI al cambiar cliente
        setRenewalExpanded(false);
        setRenewalPage(1);
        
        const response = await loansService.getClientActiveLoans(selectedClient.id);
        setClientActiveLoans(response.data.active_loans || []);

        // Si no hay préstamos activos, resetear renovación
        if (!response.data.has_active_loans) {
          setIsRenewal(false);
          setSelectedLoanToRenew(null);
        }
      } catch (err) {
        console.error('Error verificando préstamos activos:', err);
        setClientActiveLoans([]);
      } finally {
        setLoadingActiveLoans(false);
      }
    };

    checkActiveLoans();
  }, [selectedClient]);

  // Calcular preview cuando cambian amount, term, profile o tasas custom
  useEffect(() => {
    const calculatePreview = async () => {
      // Solo calcular si hay monto y plazo válidos
      const amount = parseFloat(formData.amount);
      const term = parseInt(formData.term_biweeks);

      if (!amount || amount <= 0 || !term || term < 1) {
        setCalculation(null);
        return;
      }

      // Para custom, necesitamos ambas tasas
      if (formData.profile_code === 'custom') {
        const interestRate = parseFloat(formData.interest_rate);
        const commissionRate = parseFloat(formData.commission_rate);
        if (!interestRate || interestRate < 0 || !commissionRate || commissionRate < 0) {
          setCalculation(null);
          return;
        }
      }

      try {
        setCalculatingPreview(true);

        const payload = {
          amount,
          term_biweeks: term,
          profile_code: formData.profile_code
        };

        // Si es custom, agregar las tasas
        if (formData.profile_code === 'custom') {
          payload.interest_rate = parseFloat(formData.interest_rate);
          payload.commission_rate = parseFloat(formData.commission_rate);
        }

        const response = await rateProfilesService.calculate(payload);
        setCalculation(response.data);
      } catch (err) {
        console.error('Error calculando preview:', err);
        setCalculation(null);
      } finally {
        setCalculatingPreview(false);
      }
    };

    // Debounce de 500ms para no saturar la API
    const timeoutId = setTimeout(calculatePreview, 500);
    return () => clearTimeout(timeoutId);
  }, [
    formData.amount,
    formData.term_biweeks,
    formData.profile_code,
    formData.interest_rate,
    formData.commission_rate
  ]);

  const loadRateProfiles = async () => {
    try {
      setLoadingProfiles(true);
      const [profilesRes, legacyRes] = await Promise.all([
        rateProfilesService.getAll(),
        rateProfilesService.getLegacyAmounts()
      ]);

      setProfiles(profilesRes.data);
      setLegacyAmounts(legacyRes.data);

      // Establecer perfil legacy por defecto
      const legacyProfile = profilesRes.data.find(p => p.code === 'legacy');
      if (legacyProfile) {
        setSelectedProfile(legacyProfile);
      }
    } catch (err) {
      console.error('Error cargando perfiles:', err);
      alert('Error cargando perfiles de tasa');
    } finally {
      setLoadingProfiles(false);
    }
  };

  const handleChange = (e) => {
    const { name, value } = e.target;

    // Si cambió el perfil, actualizar restricciones
    if (name === 'profile_code') {
      const profile = profiles.find(p => p.code === value);
      setSelectedProfile(profile || null);

      // Si es legacy, forzar term a 12 y limpiar amount
      if (value === 'legacy') {
        setFormData(prev => ({
          ...prev,
          profile_code: value,
          term_biweeks: '12',
          amount: ''
        }));
      } else if (value === 'custom') {
        // Custom requiere tasas manuales - establecer plazo válido por defecto
        setFormData(prev => ({
          ...prev,
          profile_code: value,
          term_biweeks: '12',  // Valor válido por defecto
          interest_rate: '',
          commission_rate: '1.6' // Igual que Standard
        }));
      } else {
        setFormData(prev => ({
          ...prev,
          [name]: value
        }));
      }
    } else {
      setFormData(prev => ({
        ...prev,
        [name]: value
      }));
    }

    // Limpiar error del campo
    if (errors[name]) {
      setErrors(prev => ({
        ...prev,
        [name]: ''
      }));
    }
  };

  const validateForm = () => {
    const newErrors = {};

    if (!selectedClient) {
      newErrors.client = 'Debe seleccionar un cliente';
    }

    if (!selectedAssociate) {
      newErrors.associate = 'Debe seleccionar un asociado';
    }

    if (!formData.amount || parseFloat(formData.amount) <= 0) {
      newErrors.amount = 'El monto debe ser mayor a 0';
    }

    // Validar que el asociado tenga crédito suficiente
    if (selectedAssociate && formData.amount) {
      const amount = parseFloat(formData.amount);
      const available = parseFloat(selectedAssociate.available_credit) || 0;
      if (amount > available) {
        newErrors.associate = `El asociado solo tiene $${available.toFixed(2)} disponibles`;
      }
    }

    // Validar restricciones del perfil
    if (selectedProfile) {
      // Validar términos válidos
      if (selectedProfile.valid_terms && selectedProfile.valid_terms.length > 0) {
        const term = parseInt(formData.term_biweeks);
        if (!selectedProfile.valid_terms.includes(term)) {
          newErrors.term_biweeks = `Este perfil solo permite: ${selectedProfile.valid_terms.join(', ')} quincenas`;
        }
      }

      // Validar rangos de montos
      if (selectedProfile.min_amount && parseFloat(formData.amount) < parseFloat(selectedProfile.min_amount)) {
        newErrors.amount = `El monto mínimo es $${selectedProfile.min_amount}`;
      }
      if (selectedProfile.max_amount && parseFloat(formData.amount) > parseFloat(selectedProfile.max_amount)) {
        newErrors.amount = `El monto máximo es $${selectedProfile.max_amount}`;
      }

      // Validar legacy: solo montos predefinidos
      if (selectedProfile.code === 'legacy' && formData.amount) {
        const amount = parseFloat(formData.amount);
        const validAmount = legacyAmounts.find(la => parseFloat(la.amount) === amount);
        if (!validAmount) {
          newErrors.amount = 'Debe seleccionar un monto de la lista predefinida';
        }
      }
    }

    // ⭐ Validar monto mínimo para renovación
    if (isRenewal && selectedLoanToRenew) {
      const amount = parseFloat(formData.amount) || 0;
      const minRequired = parseFloat(selectedLoanToRenew.total_pending_amount) || 0;
      if (amount < minRequired) {
        newErrors.amount = `Para renovar, el monto mínimo es $${minRequired.toLocaleString('es-MX', { minimumFractionDigits: 2 })} (saldo pendiente)`;
      }
    }

    if (!formData.term_biweeks || parseInt(formData.term_biweeks) < 1 || parseInt(formData.term_biweeks) > 52) {
      newErrors.term_biweeks = 'El plazo debe estar entre 1 y 52 quincenas';
    }

    // Si usa custom, validar tasas manuales
    if (formData.profile_code === 'custom') {
      if (!formData.interest_rate || parseFloat(formData.interest_rate) < 0) {
        newErrors.interest_rate = 'Debe especificar la tasa de interés';
      }
      if (!formData.commission_rate || parseFloat(formData.commission_rate) < 0) {
        newErrors.commission_rate = 'Debe especificar la tasa de comisión';
      }
    }

    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleSubmit = async (e) => {
    e.preventDefault();

    if (!validateForm()) {
      return;
    }

    try {
      setLoading(true);

      // Construir payload según si usa perfil o tasas manuales
      const payload = {
        user_id: selectedClient.id,
        associate_user_id: selectedAssociate.user_id,
        amount: parseFloat(formData.amount),
        term_biweeks: parseInt(formData.term_biweeks),
        notes: formData.notes.trim() || null,
        profile_code: formData.profile_code  // Siempre enviar profile_code
      };

      // Si usa tasas manuales (custom): agregar las tasas personalizadas
      if (formData.profile_code === 'custom') {
        payload.interest_rate = parseFloat(formData.interest_rate);
        payload.commission_rate = parseFloat(formData.commission_rate);
      }

      let response;

      // ⭐ Si es renovación, usar endpoint de renovación
      if (isRenewal && selectedLoanToRenew) {
        payload.original_loan_id = selectedLoanToRenew.loan_id;
        response = await loansService.renew(payload);

        const renewalInfo = response.data.renewal_info;

        // Mostrar notificación de éxito para renovación
        setSuccessNotification({
          isOpen: true,
          loanId: response.data.id,
          isRenewal: true,
          renewalDetails: {
            originalLoanId: selectedLoanToRenew.loan_id,
            amountLiquidated: renewalInfo?.amount_liquidated || 0,
            commissionsToAssociate: renewalInfo?.commissions_owed_to_associate || 0,
            netToClient: renewalInfo?.net_to_client || 0
          }
        });
      } else {
        response = await loansService.create(payload);
        
        // Mostrar notificación de éxito para préstamo nuevo
        setSuccessNotification({
          isOpen: true,
          loanId: response.data.id,
          isRenewal: false,
          renewalDetails: null
        });
      }

      console.log('✅ Préstamo creado exitosamente:', response.data);

    } catch (err) {
      console.error('Error creando préstamo:', err);
      console.error('Error response:', err.response);
      console.error('Error detail:', err.response?.data?.detail);
      const errorMsg = err.response?.data?.detail || err.response?.data?.message || 'Error al crear préstamo';
      alert(errorMsg);
    } finally {
      setLoading(false);
    }
  };

  // ⭐ Handler para seleccionar préstamo a renovar
  const handleSelectLoanToRenew = (loan) => {
    setSelectedLoanToRenew(loan);
    setIsRenewal(true);

    // Pre-seleccionar el asociado del préstamo original
    if (loan.associate_user_id) {
      // El AssociateSelector debería actualizar cuando se establezca
      // Por ahora, mostrar mensaje
      console.log('Préstamo a renovar seleccionado:', loan);
    }

    // Establecer monto mínimo = saldo pendiente
    const minAmount = loan.total_pending_amount;
    if (parseFloat(formData.amount) < minAmount) {
      setFormData(prev => ({
        ...prev,
        amount: Math.ceil(minAmount / 1000) * 1000,  // Redondear al siguiente mil
        useCustomAmount: true,
        customAmount: Math.ceil(minAmount / 1000) * 1000
      }));
    }
  };

  // ⭐ Handler para cancelar renovación
  const handleCancelRenewal = () => {
    setIsRenewal(false);
    setSelectedLoanToRenew(null);
  };

  // Calcular el monto para filtrar asociados
  const loanAmount = parseFloat(formData.amount) || 0;

  // Formatear moneda para la notificación
  const formatCurrency = (amount) => {
    return `$${parseFloat(amount || 0).toLocaleString('es-MX', { minimumFractionDigits: 2 })}`;
  };

  return (
    <div className="loan-create-page">
      {/* ⭐ Notificación de éxito estilo Discord */}
      <SuccessNotification
        isOpen={successNotification.isOpen}
        onClose={() => {
          setSuccessNotification(prev => ({ ...prev, isOpen: false }));
          navigate('/prestamos');
        }}
        title={successNotification.isRenewal ? '🔄 Préstamo Renovado' : '✅ Préstamo Creado'}
        message={
          successNotification.isRenewal && successNotification.renewalDetails
            ? `Préstamo #${successNotification.loanId} creado correctamente.\n` +
              `Préstamo anterior (#${successNotification.renewalDetails.originalLoanId}) liquidado.\n` +
              `Neto para el cliente: ${formatCurrency(successNotification.renewalDetails.netToClient)}`
            : `Préstamo #${successNotification.loanId} creado exitosamente.\nEstado: Pendiente de aprobación.`
        }
        icon={successNotification.isRenewal ? '🔄' : '💰'}
        duration={0} // Sin auto-cerrar, requiere botón
        actions={[
          {
            label: 'Ver Préstamo',
            icon: '📋',
            variant: 'secondary',
            onClick: () => navigate(`/prestamos/${successNotification.loanId}`)
          },
          {
            label: 'Aceptar',
            icon: '✅',
            variant: 'primary',
            onClick: () => navigate('/prestamos')
          }
        ]}
      />

      <div className="page-header">
        <div className="header-content">
          <div className="header-left">
            <button
              className="btn-back"
              onClick={() => navigate('/prestamos')}
            >
              ← Volver
            </button>
            <h1>➕ Nuevo Préstamo</h1>
          </div>
        </div>
      </div>

      <div className="loan-form-container">
        <form onSubmit={handleSubmit} className="loan-form">

          {/* Sección: Información del Préstamo */}
          <div className="form-section">
            <h2>📋 Información del Préstamo</h2>

            <div className="form-row">
              <div className="form-group">
                <label>Cliente *</label>
                <ClientSelector
                  value={selectedClient}
                  onChange={(client) => {
                    setSelectedClient(client);
                    if (errors.client) {
                      setErrors(prev => ({ ...prev, client: '' }));
                    }
                  }}
                  error={errors.client}
                  disabled={loading}
                />
              </div>

              <div className="form-group">
                <label>Asociado *</label>
                <AssociateSelector
                  value={selectedAssociate}
                  onChange={(associate) => {
                    setSelectedAssociate(associate);
                    if (errors.associate) {
                      setErrors(prev => ({ ...prev, associate: '' }));
                    }
                  }}
                  error={errors.associate}
                  disabled={loading}
                  requiredCredit={loanAmount}
                />
              </div>
            </div>

            {/* ⭐ SECCIÓN DE RENOVACIÓN - Mostrar si el cliente tiene préstamos activos */}
            {selectedClient && !loadingActiveLoans && clientActiveLoans.length > 0 && (
              <div className="renewal-section">
                {/* Header colapsable con resumen */}
                <div 
                  className={`renewal-header-collapsible ${renewalExpanded ? 'expanded' : ''}`}
                  onClick={() => !isRenewal && setRenewalExpanded(!renewalExpanded)}
                  style={{ cursor: isRenewal ? 'default' : 'pointer' }}
                >
                  <div className="renewal-header-left">
                    <span className="renewal-icon">{renewalExpanded || isRenewal ? '🔽' : '▶️'}</span>
                    <h3>🔄 Renovación de Préstamo</h3>
                    <span className="renewal-badge-count">{clientActiveLoans.length} ACTIVO{clientActiveLoans.length > 1 ? 'S' : ''}</span>
                  </div>
                  <div className="renewal-header-summary">
                    <span className="summary-total">
                      Deuda total: ${clientActiveLoans.reduce((sum, l) => sum + parseFloat(l.total_pending_amount || 0), 0).toLocaleString('es-MX', { minimumFractionDigits: 2 })}
                    </span>
                  </div>
                </div>

                {/* Contenido expandible */}
                <div className={`renewal-content ${renewalExpanded || isRenewal ? 'expanded' : 'collapsed'}`}>
                  {!isRenewal && (
                    <p className="renewal-hint">
                      Este cliente tiene {clientActiveLoans.length} préstamo(s) activo(s).
                      Puedes crear un nuevo préstamo que liquide el anterior.
                    </p>
                  )}

                  {!isRenewal ? (
                    <>
                      <div className="active-loans-list">
                        {clientActiveLoans
                          .slice((renewalPage - 1) * LOANS_PER_PAGE, renewalPage * LOANS_PER_PAGE)
                          .map(loan => (
                          <div key={loan.loan_id} className="active-loan-card">
                            <div className="loan-card-header">
                              <span className="loan-id">Préstamo #{loan.loan_id}</span>
                              <span className="loan-status active">ACTIVO</span>
                            </div>
                            <div className="loan-card-body">
                              <div className="loan-detail">
                                <span className="label">Monto original:</span>
                                <span className="value">${parseFloat(loan.loan_amount).toLocaleString('es-MX', { minimumFractionDigits: 2 })}</span>
                              </div>
                              <div className="loan-detail">
                                <span className="label">Pagos pendientes:</span>
                                <span className="value">{loan.pending_payments_count} de {loan.total_payments}</span>
                              </div>
                              <div className="loan-detail highlight">
                                <span className="label">Saldo a liquidar:</span>
                                <span className="value">${parseFloat(loan.total_pending_amount).toLocaleString('es-MX', { minimumFractionDigits: 2 })}</span>
                              </div>
                              <div className="loan-detail">
                                <span className="label">Comisiones pendientes (asociado):</span>
                                <span className="value">${parseFloat(loan.pending_commissions).toLocaleString('es-MX', { minimumFractionDigits: 2 })}</span>
                              </div>
                            </div>
                            <button
                              type="button"
                              className="btn-renew"
                              onClick={() => handleSelectLoanToRenew(loan)}
                            >
                              🔄 Renovar este préstamo
                            </button>
                          </div>
                        ))}
                      </div>
                      
                      {/* Paginación si hay más de LOANS_PER_PAGE préstamos */}
                      {clientActiveLoans.length > LOANS_PER_PAGE && (
                        <div className="renewal-pagination">
                          <button
                            type="button"
                            className="pagination-btn"
                            disabled={renewalPage === 1}
                            onClick={() => setRenewalPage(p => p - 1)}
                          >
                            ← Anterior
                          </button>
                          <span className="pagination-info">
                            Página {renewalPage} de {Math.ceil(clientActiveLoans.length / LOANS_PER_PAGE)}
                          </span>
                          <button
                            type="button"
                            className="pagination-btn"
                            disabled={renewalPage >= Math.ceil(clientActiveLoans.length / LOANS_PER_PAGE)}
                            onClick={() => setRenewalPage(p => p + 1)}
                          >
                            Siguiente →
                          </button>
                        </div>
                      )}
                    </>
                  ) : (
                  <div className="renewal-selected-card">
                    <div className="renewal-header">
                      <span className="renewal-badge">✅ MODO RENOVACIÓN</span>
                      <button
                        type="button"
                        className="btn-cancel-renewal"
                        onClick={handleCancelRenewal}
                      >
                        ✕ Cancelar renovación
                      </button>
                    </div>
                    <div className="renewal-summary">
                      <h4>Liquidando Préstamo #{selectedLoanToRenew.loan_id}</h4>
                      <div className="renewal-detail">
                        <span className="label">Monto original del préstamo:</span>
                        <span className="value">${parseFloat(selectedLoanToRenew.loan_amount).toLocaleString('es-MX', { minimumFractionDigits: 2 })}</span>
                      </div>
                      <div className="renewal-detail">
                        <span className="label">Pagos restantes:</span>
                        <span className="value">{selectedLoanToRenew.pending_payments_count} de {selectedLoanToRenew.total_payments}</span>
                      </div>
                      <div className="renewal-detail highlight-box">
                        <span className="label">💰 Saldo a liquidar (capital + intereses):</span>
                        <span className="value highlight">${parseFloat(selectedLoanToRenew.total_pending_amount).toLocaleString('es-MX', { minimumFractionDigits: 2 })}</span>
                      </div>
                      <div className="renewal-detail important">
                        <span className="label">📊 Comisiones pendientes (saldo a favor asociado):</span>
                        <span className="value">${parseFloat(selectedLoanToRenew.pending_commissions).toLocaleString('es-MX', { minimumFractionDigits: 2 })}</span>
                      </div>
                      <div className="renewal-notes">
                        <p className="renewal-note warning">
                          ⚠️ <strong>Monto mínimo requerido:</strong> ${parseFloat(selectedLoanToRenew.total_pending_amount).toLocaleString('es-MX', { minimumFractionDigits: 2 })}
                        </p>
                        <p className="renewal-note info">
                          ℹ️ El saldo a liquidar incluye capital + intereses pendientes. No hay descuento por pago anticipado.
                        </p>
                        <p className="renewal-note success">
                          ✅ <strong>Aprobación automática:</strong> Los préstamos de renovación se aprueban automáticamente.
                        </p>
                      </div>
                    </div>
                  </div>
                )}
                </div>
              </div>
            )}

            {loadingActiveLoans && selectedClient && (
              <div className="renewal-loading">
                ⏳ Verificando préstamos activos del cliente...
              </div>
            )}

            <div className="form-row">
              <div className="form-group amount-group-full-width">
                <label htmlFor="amount">Monto ($) *</label>

                {selectedProfile?.code === 'legacy' ? (
                  // Para legacy: dropdown de montos predefinidos
                  <>
                    <select
                      id="amount"
                      name="amount"
                      value={formData.amount}
                      onChange={handleChange}
                      className={errors.amount ? 'error' : ''}
                      required
                    >
                      <option value="">-- Selecciona un monto --</option>
                      {legacyAmounts.map(la => (
                        <option key={la.amount} value={la.amount}>
                          ${parseFloat(la.amount).toLocaleString('es-MX', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                          {' → '}${parseFloat(la.biweekly_payment).toLocaleString('es-MX', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}/quinc.
                        </option>
                      ))}
                    </select>
                    {errors.amount && <span className="error-message">{errors.amount}</span>}
                    <small className="form-hint">
                      💡 Montos predefinidos de la tabla histórica
                    </small>
                  </>
                ) : (
                  // Para Standard y Custom: botones + "Otro monto"
                  <>
                    <div className="amount-buttons-grid">
                      {[3000, 4000, 5000, 6000, 7000, 8000, 9000, 10000, 12000, 15000, 18000, 20000, 22000, 25000, 28000, 30000].map(amt => (
                        <button
                          key={amt}
                          type="button"
                          className={`amount-btn ${formData.amount === amt && !formData.useCustomAmount ? 'active' : ''}`}
                          onClick={() => {
                            setFormData(prev => ({ ...prev, amount: amt, useCustomAmount: false, customAmount: '' }));
                            if (errors.amount) setErrors(prev => ({ ...prev, amount: '' }));
                          }}
                          disabled={loading}
                        >
                          ${(amt / 1000)}k
                        </button>
                      ))}
                      <button
                        type="button"
                        className={`amount-btn custom-btn ${formData.useCustomAmount ? 'active' : ''}`}
                        onClick={() => {
                          setFormData(prev => ({ ...prev, useCustomAmount: !prev.useCustomAmount, amount: prev.useCustomAmount ? 10000 : (parseInt(prev.customAmount) || 0) }));
                        }}
                        disabled={loading}
                      >
                        Otro monto
                      </button>
                    </div>

                    {formData.useCustomAmount && (
                      <div className="custom-amount-input">
                        <input
                          type="number"
                          name="customAmount"
                          value={formData.customAmount}
                          onChange={(e) => {
                            const value = e.target.value;
                            setFormData(prev => ({ ...prev, customAmount: value, amount: parseInt(value) || 0 }));
                            if (errors.amount) setErrors(prev => ({ ...prev, amount: '' }));
                          }}
                          placeholder="Ingresa el monto personalizado"
                          step="1000"
                          min="3000"
                          max="30000"
                          className={errors.amount ? 'error' : ''}
                        />
                      </div>
                    )}

                    {errors.amount && <span className="error-message">{errors.amount}</span>}
                    <small className="form-hint">
                      💡 Selecciona un monto predefinido o ingresa uno personalizado
                    </small>
                  </>
                )}
              </div>

              <div className="form-group">
                <label htmlFor="term_biweeks">Plazo (quincenas) *</label>
                {selectedProfile?.code === 'legacy' ? (
                  // Legacy: siempre 12 quincenas
                  <input
                    type="text"
                    id="term_biweeks"
                    value="12 quincenas (6 meses)"
                    disabled
                    className="disabled-input"
                  />
                ) : (
                  // Standard, Custom y otros: siempre usar select con términos válidos
                  // Fallback a términos por defecto si no hay valid_terms
                  <select
                    id="term_biweeks"
                    name="term_biweeks"
                    value={formData.term_biweeks}
                    onChange={handleChange}
                    className={errors.term_biweeks ? 'error' : ''}
                    required
                  >
                    <option value="">-- Selecciona un plazo --</option>
                    {(selectedProfile?.valid_terms?.length > 0
                      ? selectedProfile.valid_terms
                      : [3, 6, 9, 12, 15, 18, 21, 24, 30, 36]  // Fallback por defecto
                    ).map(term => {
                      const months = Math.round(term / 2);
                      return (
                        <option key={term} value={term}>
                          {term} quincenas ({months} {months === 1 ? 'mes' : 'meses'})
                        </option>
                      );
                    })}
                  </select>
                )}
                {errors.term_biweeks && <span className="error-message">{errors.term_biweeks}</span>}
                {selectedProfile?.code === 'legacy' && (
                  <small className="form-hint">
                    💡 Legacy solo permite 12 quincenas
                  </small>
                )}
              </div>
            </div>
          </div>

          {/* Sección: Tasas */}
          <div className="form-section">
            <h2>📊 Configuración de Tasas</h2>

            <div className="form-group">
              <label htmlFor="profile_code">Perfil de Tasa</label>
              <select
                id="profile_code"
                name="profile_code"
                value={formData.profile_code}
                onChange={handleChange}
                disabled={loadingProfiles}
              >
                {loadingProfiles ? (
                  <option value="">Cargando perfiles...</option>
                ) : (
                  <>
                    {profiles.map(profile => (
                      <option key={profile.code} value={profile.code}>
                        {profile.name}
                        {profile.is_recommended ? ' ⭐' : ''}
                        {profile.code === 'legacy' ? ' (Solo 12 quincenas)' : ''}
                      </option>
                    ))}
                  </>
                )}
              </select>
              <small className="form-hint">
                {selectedProfile?.description || 'Seleccione un perfil para ver su descripción'}
              </small>
              {selectedProfile && (
                <div className="profile-info">
                  {selectedProfile.calculation_type === 'formula' && selectedProfile.interest_rate_percent && (
                    <small className="profile-rates">
                      📊 Interés: {selectedProfile.interest_rate_percent}% por quincena | Comisión: {selectedProfile.commission_rate_percent}% del monto prestado
                    </small>
                  )}
                  {selectedProfile.valid_terms && selectedProfile.valid_terms.length > 0 && (
                    <small className="profile-terms">
                      📅 Plazos disponibles: {selectedProfile.valid_terms.join(', ')} quincenas
                    </small>
                  )}
                </div>
              )}
            </div>

            {formData.profile_code === 'custom' && (
              <div className="form-row">
                <div className="form-group">
                  <label htmlFor="interest_rate">Tasa de Interés por Quincena (%) *</label>
                  <input
                    type="number"
                    id="interest_rate"
                    name="interest_rate"
                    value={formData.interest_rate}
                    onChange={handleChange}
                    placeholder="Ej: 4.25 (Standard)"
                    step="0.25"
                    min="0.5"
                    max="10"
                    className={errors.interest_rate ? 'error' : ''}
                  />
                  <small className="form-hint">
                    💡 Interés que se suma al préstamo por cada quincena. Rango típico: 3-5%
                  </small>
                  {errors.interest_rate && <span className="error-message">{errors.interest_rate}</span>}
                </div>

                <div className="form-group">
                  <label htmlFor="commission_rate">Comisión del Asociado (% del Monto Prestado) *</label>
                  <input
                    type="number"
                    id="commission_rate"
                    name="commission_rate"
                    value={formData.commission_rate}
                    onChange={handleChange}
                    placeholder="Ej: 1.6 (Standard)"
                    step="0.1"
                    min="0"
                    max="5"
                    className={errors.commission_rate ? 'error' : ''}
                  />
                  <small className="form-hint">
                    💡 Ganancia del asociado por quincena = Monto × este %. Ejemplo: $10,000 × 1.6% = $160/quincena. Rango típico: 1-2%
                  </small>
                  {errors.commission_rate && <span className="error-message">{errors.commission_rate}</span>}
                </div>
              </div>
            )}
          </div>

          {/* Sección: Preview de Cálculos */}
          {calculation && (
            <LoanSummaryPreview 
              calculation={calculation} 
              profileCode={formData.profile_code} 
            />
          )}

          {calculatingPreview && (
            <div className="form-section calculation-loading">
              <p>⏳ Calculando preview...</p>
            </div>
          )}

          {/* Sección: Notas */}
          <div className="form-section">
            <h2>📝 Notas Adicionales</h2>

            <div className="form-group">
              <label htmlFor="notes">Notas (Opcional)</label>
              <textarea
                id="notes"
                name="notes"
                value={formData.notes}
                onChange={handleChange}
                placeholder="Información adicional sobre el préstamo..."
                rows="4"
                maxLength="1000"
              />
              <small className="form-hint">
                {formData.notes.length}/1000 caracteres
              </small>
            </div>
          </div>

          {/* Botones de Acción */}
          <div className="form-actions">
            <button
              type="button"
              className="btn-secondary"
              onClick={() => navigate('/prestamos')}
              disabled={loading}
            >
              Cancelar
            </button>
            <button
              type="submit"
              className="btn-primary"
              disabled={loading}
            >
              {loading ? 'Creando...' : '✓ Crear Préstamo'}
            </button>
          </div>

        </form>
      </div>
    </div>
  );
};

export default LoanCreatePage;
