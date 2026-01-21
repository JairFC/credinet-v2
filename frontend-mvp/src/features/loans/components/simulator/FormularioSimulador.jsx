/**
 * FormularioSimulador
 * Formulario para configurar parámetros de simulación con calendario de fecha
 */
import { useState, useEffect } from 'react';
import './FormularioSimulador.css';

/**
 * Rangos recomendados para tasas
 * IMPORTANTE: La comisión se calcula sobre el MONTO prestado (no sobre el pago)
 */
const RATE_RANGES = {
  interest: {
    min: 0.5,     // 0.5% por quincena (mínimo)
    max: 10,      // 10% por quincena (máximo)
    recommended: { min: 3, max: 5 },  // Rango típico: 3-5% por quincena
    standard: 4.25  // Standard usa 4.25% por quincena
  },
  commission: {
    min: 0,
    max: 5,       // 5% del monto por quincena (máximo)
    recommended: { min: 1, max: 2 },  // Rango típico: 1-2% del monto
    standard: 1.6  // Standard usa 1.6% del monto (igual que Legacy)
  }
};

const PROFILES = [
  {
    code: 'legacy',
    name: 'Tabla Histórica v2.0 (Solo 12Q)',
    terms: [12],
    predefinedAmounts: [3000, 4000, 5000, 6000, 7000, 7500, 8000, 9000, 10000, 11000, 12000, 13000, 14000, 15000, 16000, 17000, 18000, 19000, 20000, 21000, 22000, 23000, 24000, 25000, 26000, 27000, 28000, 29000, 30000],
    allowCustomAmount: false
  },
  {
    code: 'standard',
    name: 'Estándar - Recomendado ⭐',
    description: 'Interés 4.25% por quincena, comisión asociado 1.6% del monto',
    terms: [3, 6, 9, 12, 15, 18, 21, 24, 30, 36],
    predefinedAmounts: [3000, 4000, 5000, 6000, 7000, 8000, 9000, 10000, 12000, 15000, 18000, 20000, 22000, 25000, 28000, 30000],
    allowCustomAmount: true
  },
  {
    code: 'custom',
    name: 'Personalizado',
    description: 'Define tus propias tasas de interés y comisión',
    terms: [3, 6, 9, 12, 15, 18, 21, 24, 30, 36],
    predefinedAmounts: [3000, 4000, 5000, 6000, 7000, 8000, 9000, 10000, 12000, 15000, 18000, 20000, 22000, 25000, 28000, 30000],
    allowCustomAmount: true
  },
];

export default function FormularioSimulador({ onSimulate, loading }) {
  const [formData, setFormData] = useState({
    amount: 10000,
    term_biweeks: 12,
    profile_code: 'standard',
    approval_date: new Date().toISOString().split('T')[0],
    // Tasas quincenales (no anuales) para coincidir con la lógica del backend
    custom_interest_rate: '',
    custom_commission_rate: '',
    useCustomAmount: false,
    customAmount: '',
  });

  const [errors, setErrors] = useState({});
  const [availableTerms, setAvailableTerms] = useState([]);
  const [selectedProfile, setSelectedProfile] = useState(null);

  // Actualizar términos disponibles cuando cambia el perfil
  useEffect(() => {
    const profile = PROFILES.find(p => p.code === formData.profile_code);
    if (profile) {
      setSelectedProfile(profile);
      setAvailableTerms(profile.terms);

      // Si el término actual no está disponible, seleccionar el primero
      if (profile.terms.length > 0 && !profile.terms.includes(formData.term_biweeks)) {
        setFormData(prev => ({ ...prev, term_biweeks: profile.terms[0] }));
      }

      // Resetear custom amount al cambiar de perfil
      setFormData(prev => ({
        ...prev,
        useCustomAmount: false,
        customAmount: '',
        amount: profile.predefinedAmounts.includes(prev.amount) ? prev.amount : profile.predefinedAmounts[0]
      }));
    }
  }, [formData.profile_code]);

  const handleChange = (e) => {
    const { name, value, type, checked } = e.target;

    if (name === 'useCustomAmount') {
      setFormData(prev => ({
        ...prev,
        useCustomAmount: checked,
        amount: checked ? (prev.customAmount || 10000) : selectedProfile?.predefinedAmounts[0] || 10000,
        customAmount: checked ? (prev.customAmount || '') : '',
      }));
    } else if (name === 'customAmount') {
      const numValue = Number(value);
      setFormData(prev => ({
        ...prev,
        customAmount: value,
        amount: numValue || 0,
      }));
    } else if (name === 'amountSelect') {
      setFormData(prev => ({
        ...prev,
        amount: Number(value),
      }));
    } else {
      setFormData(prev => ({
        ...prev,
        [name]: name === 'amount' || name === 'term_biweeks' ? Number(value) : value,
      }));
    }

    // Limpiar error del campo
    if (errors[name]) {
      setErrors(prev => ({ ...prev, [name]: null }));
    }
  };

  const validate = () => {
    const newErrors = {};

    // Validar monto
    if (formData.amount < 3000) {
      newErrors.amount = 'El monto mínimo es $3,000';
    } else if (formData.amount > 30000) {
      newErrors.amount = 'El monto máximo es $30,000';
    } else if (formData.amount % 1000 !== 0) {
      newErrors.amount = 'El monto debe ser múltiplo de $1,000';
    }

    // Validar fecha
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const selectedDate = new Date(formData.approval_date);
    selectedDate.setHours(0, 0, 0, 0);

    if (selectedDate < today) {
      newErrors.approval_date = 'La fecha no puede ser anterior a hoy';
    }

    // Validar tasas custom
    if (formData.profile_code === 'custom') {
      const interestRate = parseFloat(formData.custom_interest_rate);
      const commissionRate = parseFloat(formData.custom_commission_rate);

      if (!formData.custom_interest_rate || isNaN(interestRate)) {
        newErrors.custom_interest_rate = 'Ingrese la tasa de interés por quincena';
      } else if (interestRate < RATE_RANGES.interest.min || interestRate > RATE_RANGES.interest.max) {
        newErrors.custom_interest_rate = `Rango válido: ${RATE_RANGES.interest.min}% - ${RATE_RANGES.interest.max}% por quincena`;
      } else if (interestRate < RATE_RANGES.interest.recommended.min || interestRate > RATE_RANGES.interest.recommended.max) {
        newErrors.custom_interest_rate = `⚠️ Fuera del rango típico (${RATE_RANGES.interest.recommended.min}%-${RATE_RANGES.interest.recommended.max}% por quincena). Standard usa ${RATE_RANGES.interest.standard}%`;
      }

      if (formData.custom_commission_rate === '' || isNaN(commissionRate)) {
        newErrors.custom_commission_rate = 'Ingrese el % de comisión sobre el monto';
      } else if (commissionRate < RATE_RANGES.commission.min || commissionRate > RATE_RANGES.commission.max) {
        newErrors.custom_commission_rate = `Rango válido: ${RATE_RANGES.commission.min}% - ${RATE_RANGES.commission.max}% del monto`;
      } else if (commissionRate < RATE_RANGES.commission.recommended.min || commissionRate > RATE_RANGES.commission.recommended.max) {
        newErrors.custom_commission_rate = `⚠️ Fuera del rango típico (${RATE_RANGES.commission.recommended.min}%-${RATE_RANGES.commission.recommended.max}% del monto). Standard usa ${RATE_RANGES.commission.standard}%`;
      }
    } setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleSubmit = (e) => {
    e.preventDefault();

    if (validate()) {
      const params = {
        amount: formData.amount,
        term_biweeks: formData.term_biweeks,
        profile_code: formData.profile_code,
        approval_date: formData.approval_date,
      };

      // Solo agregar tasas custom si el perfil es 'custom'
      if (formData.profile_code === 'custom') {
        params.custom_interest_rate = parseFloat(formData.custom_interest_rate);
        params.custom_commission_rate = parseFloat(formData.custom_commission_rate);
      }

      onSimulate(params);
    }
  }; return (
    <div className="formulario-simulador">
      <h3>💰 Configurar Simulación</h3>

      <form onSubmit={handleSubmit}>
        {/* Monto */}
        <div className="form-group">
          <label htmlFor="amount">
            Monto del Préstamo <span className="required">*</span>
          </label>

          {!formData.useCustomAmount ? (
            <select
              id="amountSelect"
              name="amountSelect"
              value={formData.amount}
              onChange={handleChange}
              disabled={loading}
              className={errors.amount ? 'error' : ''}
            >
              {selectedProfile?.predefinedAmounts.map(amount => (
                <option key={amount} value={amount}>
                  ${amount.toLocaleString('es-MX')}
                </option>
              ))}
            </select>
          ) : (
            <input
              type="number"
              id="customAmount"
              name="customAmount"
              value={formData.customAmount}
              onChange={handleChange}
              min="3000"
              max="30000"
              step="1000"
              placeholder="Ingresa el monto"
              disabled={loading}
              className={errors.amount ? 'error' : ''}
            />
          )}

          {selectedProfile?.allowCustomAmount && (
            <div className="custom-amount-toggle">
              <label className="checkbox-label">
                <input
                  type="checkbox"
                  name="useCustomAmount"
                  checked={formData.useCustomAmount}
                  onChange={handleChange}
                  disabled={loading}
                />
                <span>💡 Ingresar otra cantidad</span>
              </label>
            </div>
          )}

          <small className="help-text">
            {formData.useCustomAmount
              ? 'Rango: $3,000 - $30,000 (múltiplos de $1,000)'
              : selectedProfile?.code === 'legacy'
                ? 'Montos históricos disponibles en la tabla legacy'
                : 'Selecciona un monto o marca la casilla para ingresar otro'
            }
          </small>
          {errors.amount && <span className="error-message">{errors.amount}</span>}
        </div>

        {/* Perfil de Tasa */}
        <div className="form-group">
          <label htmlFor="profile_code">
            Perfil de Tasa <span className="required">*</span>
          </label>
          <select
            id="profile_code"
            name="profile_code"
            value={formData.profile_code}
            onChange={handleChange}
            disabled={loading}
          >
            {PROFILES.map(profile => (
              <option key={profile.code} value={profile.code}>
                {profile.name}
              </option>
            ))}
          </select>
        </div>

        {/* Plazo */}
        <div className="form-group">
          <label htmlFor="term_biweeks">
            Plazo <span className="required">*</span>
          </label>
          {availableTerms.length > 0 ? (
            <select
              id="term_biweeks"
              name="term_biweeks"
              value={formData.term_biweeks}
              onChange={handleChange}
              disabled={loading}
            >
              {availableTerms.map(term => (
                <option key={term} value={term}>
                  {term} quincenas ({(term / 2).toFixed(1)} meses)
                </option>
              ))}
            </select>
          ) : (
            <input
              type="number"
              id="term_biweeks"
              name="term_biweeks"
              value={formData.term_biweeks}
              onChange={handleChange}
              min="1"
              max="52"
              disabled={loading}
            />
          )}
        </div>

        {/* Fecha de Aprobación (Calendario) */}
        <div className="form-group">
          <label htmlFor="approval_date">
            📅 Fecha de Aprobación <span className="required">*</span>
          </label>
          <input
            type="date"
            id="approval_date"
            name="approval_date"
            value={formData.approval_date}
            onChange={handleChange}
            min={new Date().toISOString().split('T')[0]}
            disabled={loading}
            className={errors.approval_date ? 'error' : ''}
          />
          <small className="help-text">
            La simulación calculará fechas de pago cada 15 días desde esta fecha
          </small>
          {errors.approval_date && <span className="error-message">{errors.approval_date}</span>}
        </div>

        {/* Tasas Custom (solo si aplica) */}
        {formData.profile_code === 'custom' && (
          <>
            <div className="form-group">
              <label htmlFor="custom_interest_rate">
                📈 Tasa de Interés por Quincena (%) <span className="required">*</span>
              </label>
              <input
                type="number"
                id="custom_interest_rate"
                name="custom_interest_rate"
                value={formData.custom_interest_rate}
                onChange={handleChange}
                min={RATE_RANGES.interest.min}
                max={RATE_RANGES.interest.max}
                step="0.25"
                placeholder="Ej: 4.25 (Standard)"
                disabled={loading}
                className={errors.custom_interest_rate ? 'error' : ''}
              />
              <small className="help-text">
                💡 Interés que se suma al préstamo por cada quincena. Standard: {RATE_RANGES.interest.standard}%, Rango típico: {RATE_RANGES.interest.recommended.min}-{RATE_RANGES.interest.recommended.max}%
              </small>
              {errors.custom_interest_rate && (
                <span className="error-message">{errors.custom_interest_rate}</span>
              )}
            </div>

            <div className="form-group">
              <label htmlFor="custom_commission_rate">
                💰 Comisión del Asociado (% del Monto Prestado) <span className="required">*</span>
              </label>
              <input
                type="number"
                id="custom_commission_rate"
                name="custom_commission_rate"
                value={formData.custom_commission_rate}
                onChange={handleChange}
                min={RATE_RANGES.commission.min}
                max={RATE_RANGES.commission.max}
                step="0.1"
                placeholder="Ej: 1.6 (Standard)"
                disabled={loading}
                className={errors.custom_commission_rate ? 'error' : ''}
              />
              <small className="help-text">
                💡 Ganancia del asociado por quincena = Monto × este %. Ejemplo: $10,000 × 1.6% = $160/quincena. Standard: {RATE_RANGES.commission.standard}%
              </small>
              {errors.custom_commission_rate && (
                <span className="error-message">{errors.custom_commission_rate}</span>
              )}
            </div>
          </>
        )}

        {/* Botón de Simular */}
        <button
          type="submit"
          className="btn btn-primary btn-simulate"
          disabled={loading}
        >
          {loading ? '⏳ Simulando...' : '🧮 Simular Préstamo'}
        </button>
      </form>
    </div>
  );
}
