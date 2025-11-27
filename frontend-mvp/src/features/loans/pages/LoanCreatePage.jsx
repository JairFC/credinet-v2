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

  const [formData, setFormData] = useState({
    amount: '',
    term_biweeks: '12',
    profile_code: 'legacy',
    interest_rate: '',
    commission_rate: '',
    notes: ''
  });

  const [errors, setErrors] = useState({});

  // Cargar perfiles de tasa al montar el componente
  useEffect(() => {
    loadRateProfiles();
  }, []);

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
        // Custom requiere tasas manuales
        setFormData(prev => ({
          ...prev,
          profile_code: value,
          interest_rate: '',
          commission_rate: '2.50' // Sugerencia por defecto
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
        newErrors.associate = `El asociado solo tiene L.${available.toFixed(2)} disponibles`;
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
        newErrors.amount = `El monto mínimo es L.${selectedProfile.min_amount}`;
      }
      if (selectedProfile.max_amount && parseFloat(formData.amount) > parseFloat(selectedProfile.max_amount)) {
        newErrors.amount = `El monto máximo es L.${selectedProfile.max_amount}`;
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
        notes: formData.notes.trim() || null
      };

      // Si usa perfil de tasa (no custom)
      if (formData.profile_code && formData.profile_code !== 'custom') {
        payload.profile_code = formData.profile_code;
      } else if (formData.profile_code === 'custom') {
        // Si usa tasas manuales (custom)
        payload.interest_rate = parseFloat(formData.interest_rate);
        payload.commission_rate = parseFloat(formData.commission_rate);
      }

      const response = await loansService.create(payload);

      console.log('✅ Préstamo creado exitosamente:', response.data);
      alert('Préstamo creado exitosamente');
      navigate('/prestamos');

    } catch (err) {
      console.error('Error creando préstamo:', err);
      alert(err.response?.data?.detail || 'Error al crear préstamo');
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
              <div className="form-group">
                <label htmlFor="amount">Monto (L) *</label>
                {selectedProfile?.code === 'legacy' ? (
                  // Para legacy: dropdown de montos predefinidos
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
                        L.{parseFloat(la.amount).toLocaleString('es-HN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                        {' → '}L.{parseFloat(la.biweekly_payment).toLocaleString('es-HN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}/quinc.
                      </option>
                    ))}
                  </select>
                ) : (
                  // Para otros perfiles: input numérico
                  <input
                    type="number"
                    id="amount"
                    name="amount"
                    value={formData.amount}
                    onChange={handleChange}
                    placeholder="Ej: 5000.00"
                    step="0.01"
                    min="0"
                    className={errors.amount ? 'error' : ''}
                  />
                )}
                {errors.amount && <span className="error-message">{errors.amount}</span>}
                {selectedProfile?.code === 'legacy' && (
                  <small className="form-hint">
                    💡 Montos predefinidos de la tabla histórica
                  </small>
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
                ) : selectedProfile?.valid_terms && selectedProfile.valid_terms.length > 0 ? (
                  // Perfiles con términos restringidos
                  <select
                    id="term_biweeks"
                    name="term_biweeks"
                    value={formData.term_biweeks}
                    onChange={handleChange}
                    className={errors.term_biweeks ? 'error' : ''}
                    required
                  >
                    <option value="">-- Selecciona un plazo --</option>
                    {selectedProfile.valid_terms.map(term => {
                      const months = Math.round(term / 2);
                      return (
                        <option key={term} value={term}>
                          {term} quincenas ({months} {months === 1 ? 'mes' : 'meses'})
                        </option>
                      );
                    })}
                  </select>
                ) : (
                  // Custom: cualquier plazo
                  <input
                    type="number"
                    id="term_biweeks"
                    name="term_biweeks"
                    value={formData.term_biweeks}
                    onChange={handleChange}
                    placeholder="Ej: 12"
                    min="1"
                    max="52"
                    className={errors.term_biweeks ? 'error' : ''}
                  />
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
                    <option value="custom">Custom (Tasas Manuales)</option>
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
                      📊 Tasas: {selectedProfile.interest_rate_percent}% interés, {selectedProfile.commission_rate_percent}% comisión
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
                  <label htmlFor="interest_rate">Tasa de Interés (%) *</label>
                  <input
                    type="number"
                    id="interest_rate"
                    name="interest_rate"
                    value={formData.interest_rate}
                    onChange={handleChange}
                    placeholder="Ej: 4.25"
                    step="0.01"
                    min="0"
                    max="100"
                    className={errors.interest_rate ? 'error' : ''}
                  />
                  {errors.interest_rate && <span className="error-message">{errors.interest_rate}</span>}
                </div>

                <div className="form-group">
                  <label htmlFor="commission_rate">Tasa de Comisión (%) *</label>
                  <input
                    type="number"
                    id="commission_rate"
                    name="commission_rate"
                    value={formData.commission_rate}
                    onChange={handleChange}
                    placeholder="Ej: 2.50"
                    step="0.01"
                    min="0"
                    max="100"
                    className={errors.commission_rate ? 'error' : ''}
                  />
                  {errors.commission_rate && <span className="error-message">{errors.commission_rate}</span>}
                </div>
              </div>
            )}
          </div>

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
