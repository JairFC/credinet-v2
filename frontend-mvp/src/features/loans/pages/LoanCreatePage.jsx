import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { loansService } from '@/shared/api/services/loansService';
import { rateProfilesService } from '@/shared/api/services/rateProfilesService';
import ClientSelector from '../../../shared/components/ClientSelector/ClientSelector';
import AssociateSelector from '../../../shared/components/AssociateSelector/AssociateSelector';
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
      const available = parseFloat(selectedAssociate.credit_available) || 0;
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

      const response = await loansService.create(payload);

      console.log('✅ Préstamo creado exitosamente:', response.data);
      alert('Préstamo creado exitosamente');
      navigate('/prestamos');

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

  // Calcular el monto para filtrar asociados
  const loanAmount = parseFloat(formData.amount) || 0;

  return (
    <div className="loan-create-page">
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
            <div className="form-section">
              <h2 className="preview-title">📋 Resumen del Préstamo</h2>

              <div className="loan-summary-grid">
                {/* Columna 1: Información */}
                <div className="summary-card info-card">
                  <h3><span className="icon">ℹ️</span> Información</h3>

                  <div className="summary-item">
                    <span className="label">Monto solicitado:</span>
                    <span className="value">${calculation.amount.toLocaleString('es-MX', { minimumFractionDigits: 2 })}</span>
                  </div>

                  <div className="summary-item">
                    <span className="label">Plazo:</span>
                    <span className="value">{calculation.term_biweeks} quincenas ({Math.round(calculation.term_biweeks / 2)} meses)</span>
                  </div>

                  <div className="summary-item">
                    <span className="label">Perfil:</span>
                    <span className="value">{formData.profile_code === 'custom' ? 'Personalizado' : calculation.profile_name}</span>
                  </div>

                  <div className="summary-item highlight">
                    <span className="label">Tasa de interés:</span>
                    <span className="value badge">{calculation.interest_rate_percent}% por quincena</span>
                  </div>

                  <div className="summary-item highlight">
                    <span className="label">Comisión del asociado:</span>
                    <span className="value badge-commission">{calculation.commission_rate_percent}% del monto (${calculation.commission_per_payment.toLocaleString('es-MX', { minimumFractionDigits: 2 })}/quincena)</span>
                  </div>
                </div>

                {/* Columna 2: Totales del Cliente */}
                <div className="summary-card client-card">
                  <h3><span className="icon">👤</span> Totales del Cliente</h3>

                  <div className="summary-item primary">
                    <span className="label">Pago quincenal:</span>
                    <span className="value highlight-amount">${calculation.biweekly_payment.toLocaleString('es-MX', { minimumFractionDigits: 2 })}</span>
                  </div>

                  <div className="summary-item">
                    <span className="label">Total a pagar:</span>
                    <span className="value">${calculation.total_payment.toLocaleString('es-MX', { minimumFractionDigits: 2 })}</span>
                  </div>

                  <div className="summary-item">
                    <span className="label">Total de intereses:</span>
                    <span className="value">${calculation.total_interest.toLocaleString('es-MX', { minimumFractionDigits: 2 })}</span>
                  </div>
                </div>

                {/* Columna 3: Totales del Asociado */}
                <div className="summary-card associate-card">
                  <h3><span className="icon">💼</span> Totales del Asociado</h3>

                  <div className="summary-item primary">
                    <span className="label">Pago quincenal:</span>
                    <span className="value highlight-amount">${calculation.associate_payment.toLocaleString('es-MX', { minimumFractionDigits: 2 })}</span>
                  </div>

                  <div className="summary-item">
                    <span className="label">Total a pagar a CrediCuenta:</span>
                    <span className="value">${calculation.associate_total.toLocaleString('es-MX', { minimumFractionDigits: 2 })}</span>
                  </div>

                  <div className="summary-item success">
                    <span className="label">Comisión total ganada:</span>
                    <span className="value success-amount">${calculation.total_commission.toLocaleString('es-MX', { minimumFractionDigits: 2 })}</span>
                  </div>
                </div>
              </div>
            </div>
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
