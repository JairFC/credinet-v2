/**
 * AssociateCreatePage - Formulario para crear nuevo asociado
 */
import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { associatesService } from '../../../../shared/api/services/associatesService';
import { useFieldValidation } from '../../../../shared/hooks/useFieldValidation';
import Modal from '../../../../shared/components/ui/modal';
import {
  prepareUserData,
  validateUserForm,
  extractErrorMessage
} from '../../../../shared/utils/userFormHelpers';
import './AssociateCreatePage.css';

export default function AssociateCreatePage() {
  const navigate = useNavigate();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [showErrorModal, setShowErrorModal] = useState(false);
  const [errors, setErrors] = useState({});
  const { validationStates, validateField, clearAllValidations } = useFieldValidation();

  const [formData, setFormData] = useState({
    // Credenciales
    username: '',
    password: '',
    confirmPassword: '',
    // Información personal
    first_name: '',
    last_name: '',
    email: '',
    phone_number: '',
    curp: '',
    birth_date: '',
    // Información de asociado
    credit_limit: '',
    contact_person: '',
    contact_email: '',
    default_commission_rate: '10.00',
  });

  const handleChange = (e) => {
    const { name, value } = e.target;
    setFormData((prev) => ({
      ...prev,
      [name]: value,
    }));

    if (errors[name]) {
      setErrors((prev) => ({ ...prev, [name]: null }));
    }

    // Validaciones en tiempo real
    if (name === 'username' && value.length >= 4) {
      validateField(name, value, 'username');
    } else if (name === 'email' && value.includes('@')) {
      validateField(name, value, 'email');
    } else if (name === 'phone_number' && value.length === 10) {
      validateField(name, value, 'phone');
    } else if (name === 'curp' && value.length === 18) {
      validateField(name, value, 'curp');
    } else if (name === 'contact_email' && value.includes('@')) {
      validateField(name, value, 'contact_email');
    }
  };

  const validateForm = () => {
    const newErrors = {};

    // Validar disponibilidad en tiempo real
    if (validationStates.username && !validationStates.username.available) {
      newErrors.username = 'Este usuario ya existe';
    }
    if (validationStates.email && !validationStates.email.available) {
      newErrors.email = 'Este email ya está registrado';
    }
    if (validationStates.phone_number && !validationStates.phone_number.available) {
      newErrors.phone_number = 'Este teléfono ya está registrado';
    }
    if (validationStates.curp && !validationStates.curp.available) {
      newErrors.curp = 'Este CURP ya está registrado';
    }
    if (validationStates.contact_email && !validationStates.contact_email.available) {
      newErrors.contact_email = 'Este email de contacto ya está registrado';
    }

    // Username
    if (!formData.username.trim()) {
      newErrors.username = 'El usuario es obligatorio';
    } else if (formData.username.length < 4) {
      newErrors.username = 'El usuario debe tener al menos 4 caracteres';
    }

    // Password
    if (!formData.password) {
      newErrors.password = 'La contraseña es obligatoria';
    } else if (formData.password.length < 8) {
      newErrors.password = 'La contraseña debe tener al menos 8 caracteres';
    }

    // Confirm Password
    if (formData.password !== formData.confirmPassword) {
      newErrors.confirmPassword = 'Las contraseñas no coinciden';
    }

    // Nombres
    if (!formData.first_name.trim()) {
      newErrors.first_name = 'El nombre es obligatorio';
    }
    if (!formData.last_name.trim()) {
      newErrors.last_name = 'El apellido es obligatorio';
    }

    // Email
    if (!formData.email.trim()) {
      newErrors.email = 'El email es obligatorio';
    } else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(formData.email)) {
      newErrors.email = 'Email inválido';
    }

    // Phone (OBLIGATORIO en la BD)
    if (!formData.phone_number) {
      newErrors.phone_number = 'El teléfono es obligatorio';
    } else if (!/^\d{10}$/.test(formData.phone_number)) {
      newErrors.phone_number = 'El teléfono debe tener 10 dígitos';
    }

    // CURP
    if (formData.curp && !/^[A-Z]{4}\d{6}[HM][A-Z]{5}[0-9A-Z]\d$/.test(formData.curp.toUpperCase())) {
      newErrors.curp = 'CURP inválido';
    }

    // Credit Limit
    if (!formData.credit_limit) {
      newErrors.credit_limit = 'La línea de crédito es obligatoria';
    } else if (parseFloat(formData.credit_limit) <= 0) {
      newErrors.credit_limit = 'La línea de crédito debe ser mayor a 0';
    }

    // Commission Rate
    const rate = parseFloat(formData.default_commission_rate);
    if (isNaN(rate) || rate < 0 || rate > 100) {
      newErrors.default_commission_rate = 'Tasa de comisión inválida (0-100)';
    }

    // Contact Email (si se proporciona)
    if (formData.contact_email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(formData.contact_email)) {
      newErrors.contact_email = 'Email de contacto inválido';
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

      // Preparar datos usando utilidad compartida
      const payload = prepareUserData(formData, 'associate');

      console.log('📤 Enviando datos de asociado:', payload);

      const response = await associatesService.create(payload);

      console.log('✅ Asociado creado:', response);

      alert('✅ Asociado creado exitosamente');
      navigate('/usuarios/asociados');
    } catch (err) {
      console.error('❌ Error al crear asociado:', err);
      console.error('📋 Detalle completo:', err.response);

      // Usar utilidad compartida para extraer mensaje
      const errorMsg = extractErrorMessage(err);

      setError(errorMsg);
      setShowErrorModal(true);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="associate-create-page">
      {/* Modal de Error */}
      <Modal
        isOpen={showErrorModal}
        onClose={() => setShowErrorModal(false)}
        title="Error al crear asociado"
        type="error"
      >
        <div className="whitespace-pre-line">
          {error}
        </div>
      </Modal>

      <div className="page-header">
        <button
          className="btn-back"
          onClick={() => navigate('/usuarios/asociados')}
        >
          ← Volver
        </button>
        <h1>💼 Nuevo Asociado</h1>
      </div>

      <div className="form-container">
        <form onSubmit={handleSubmit} className="associate-form">

          {/* Sección: Credenciales */}
          <div className="form-section">
            <h3 className="section-title">🔐 Credenciales de Acceso</h3>

            <div className="form-row">
              <div className="form-group">
                <label htmlFor="username">
                  Usuario <span className="required">*</span>
                </label>
                <input
                  type="text"
                  id="username"
                  name="username"
                  value={formData.username}
                  onChange={handleChange}
                  className={errors.username ? 'input-error' : ''}
                  placeholder="asociado123"
                  disabled={loading}
                />
                {errors.username && (
                  <span className="error-message">{errors.username}</span>
                )}
              </div>
            </div>

            <div className="form-row">
              <div className="form-group">
                <label htmlFor="password">
                  Contraseña <span className="required">*</span>
                </label>
                <input
                  type="password"
                  id="password"
                  name="password"
                  value={formData.password}
                  onChange={handleChange}
                  className={errors.password ? 'input-error' : ''}
                  placeholder="Mínimo 8 caracteres"
                  disabled={loading}
                />
                {errors.password && (
                  <span className="error-message">{errors.password}</span>
                )}
              </div>

              <div className="form-group">
                <label htmlFor="confirmPassword">
                  Confirmar Contraseña <span className="required">*</span>
                </label>
                <input
                  type="password"
                  id="confirmPassword"
                  name="confirmPassword"
                  value={formData.confirmPassword}
                  onChange={handleChange}
                  className={errors.confirmPassword ? 'input-error' : ''}
                  placeholder="Repetir contraseña"
                  disabled={loading}
                />
                {errors.confirmPassword && (
                  <span className="error-message">{errors.confirmPassword}</span>
                )}
              </div>
            </div>
          </div>

          {/* Sección: Información Personal */}
          <div className="form-section">
            <h3 className="section-title">👤 Información Personal</h3>

            <div className="form-row">
              <div className="form-group">
                <label htmlFor="first_name">
                  Nombre(s) <span className="required">*</span>
                </label>
                <input
                  type="text"
                  id="first_name"
                  name="first_name"
                  value={formData.first_name}
                  onChange={handleChange}
                  className={errors.first_name ? 'input-error' : ''}
                  placeholder="María"
                  disabled={loading}
                />
                {errors.first_name && (
                  <span className="error-message">{errors.first_name}</span>
                )}
              </div>

              <div className="form-group">
                <label htmlFor="last_name">
                  Apellido(s) <span className="required">*</span>
                </label>
                <input
                  type="text"
                  id="last_name"
                  name="last_name"
                  value={formData.last_name}
                  onChange={handleChange}
                  className={errors.last_name ? 'input-error' : ''}
                  placeholder="González López"
                  disabled={loading}
                />
                {errors.last_name && (
                  <span className="error-message">{errors.last_name}</span>
                )}
              </div>
            </div>

            <div className="form-row">
              <div className="form-group">
                <label htmlFor="email">
                  Email <span className="required">*</span>
                </label>
                <input
                  type="email"
                  id="email"
                  name="email"
                  value={formData.email}
                  onChange={handleChange}
                  className={errors.email ? 'input-error' : ''}
                  placeholder="asociado@ejemplo.com"
                  disabled={loading}
                />
                {errors.email && (
                  <span className="error-message">{errors.email}</span>
                )}
              </div>

              <div className="form-group">
                <label htmlFor="phone_number">Teléfono</label>
                <input
                  type="tel"
                  id="phone_number"
                  name="phone_number"
                  value={formData.phone_number}
                  onChange={handleChange}
                  className={errors.phone_number ? 'input-error' : ''}
                  placeholder="5512345678"
                  maxLength="10"
                  disabled={loading}
                />
                {errors.phone_number && (
                  <span className="error-message">{errors.phone_number}</span>
                )}
              </div>
            </div>

            <div className="form-row">
              <div className="form-group">
                <label htmlFor="curp">CURP</label>
                <input
                  type="text"
                  id="curp"
                  name="curp"
                  value={formData.curp}
                  onChange={handleChange}
                  className={errors.curp ? 'input-error' : ''}
                  placeholder="ABCD123456HDFRRL01"
                  maxLength="18"
                  disabled={loading}
                />
                {errors.curp && (
                  <span className="error-message">{errors.curp}</span>
                )}
              </div>

              <div className="form-group">
                <label htmlFor="birth_date">Fecha de Nacimiento</label>
                <input
                  type="date"
                  id="birth_date"
                  name="birth_date"
                  value={formData.birth_date}
                  onChange={handleChange}
                  disabled={loading}
                />
              </div>
            </div>
          </div>

          {/* Sección: Configuración de Asociado */}
          <div className="form-section associate-config">
            <h3 className="section-title">💰 Configuración de Asociado</h3>

            <div className="form-row">
              <div className="form-group">
                <label htmlFor="credit_limit">
                  Línea de Crédito <span className="required">*</span>
                </label>
                <div className="input-with-prefix">
                  <span className="input-prefix">$</span>
                  <input
                    type="number"
                    id="credit_limit"
                    name="credit_limit"
                    value={formData.credit_limit}
                    onChange={handleChange}
                    className={errors.credit_limit ? 'input-error' : ''}
                    placeholder="50000.00"
                    min="0"
                    step="0.01"
                    disabled={loading}
                  />
                </div>
                {errors.credit_limit && (
                  <span className="error-message">{errors.credit_limit}</span>
                )}
                <span className="help-text">Monto máximo que puede prestar</span>
              </div>

              <div className="form-group">
                <label htmlFor="default_commission_rate">
                  Tasa de Comisión (%) <span className="required">*</span>
                </label>
                <div className="input-with-suffix">
                  <input
                    type="number"
                    id="default_commission_rate"
                    name="default_commission_rate"
                    value={formData.default_commission_rate}
                    onChange={handleChange}
                    className={errors.default_commission_rate ? 'input-error' : ''}
                    placeholder="10.00"
                    min="0"
                    max="100"
                    step="0.01"
                    disabled={loading}
                  />
                  <span className="input-suffix">%</span>
                </div>
                {errors.default_commission_rate && (
                  <span className="error-message">{errors.default_commission_rate}</span>
                )}
                <span className="help-text">Comisión por préstamo otorgado</span>
              </div>
            </div>

            <div className="form-row">
              <div className="form-group">
                <label htmlFor="contact_person">Persona de Contacto</label>
                <input
                  type="text"
                  id="contact_person"
                  name="contact_person"
                  value={formData.contact_person}
                  onChange={handleChange}
                  placeholder="Juan Pérez"
                  disabled={loading}
                />
                <span className="help-text">Opcional: Contacto alternativo</span>
              </div>

              <div className="form-group">
                <label htmlFor="contact_email">Email de Contacto</label>
                <input
                  type="email"
                  id="contact_email"
                  name="contact_email"
                  value={formData.contact_email}
                  onChange={handleChange}
                  className={errors.contact_email ? 'input-error' : ''}
                  placeholder="contacto@ejemplo.com"
                  disabled={loading}
                />
                {errors.contact_email && (
                  <span className="error-message">{errors.contact_email}</span>
                )}
              </div>
            </div>
          </div>

          {/* Botones */}
          <div className="form-actions">
            <button
              type="button"
              className="btn btn-secondary"
              onClick={() => navigate('/usuarios/asociados')}
              disabled={loading}
            >
              Cancelar
            </button>
            <button
              type="submit"
              className="btn btn-primary"
              disabled={loading}
            >
              {loading ? 'Guardando...' : '✅ Crear Asociado'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
