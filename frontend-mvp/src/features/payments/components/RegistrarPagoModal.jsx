/**
 * RegistrarPagoModal
 * Modal para registrar pagos de asociados (período o deuda)
 */
import { useState, useEffect } from 'react';
import { useAuth } from '@/app/providers/AuthProvider';
import './RegistrarPagoModal.css';

export default function RegistrarPagoModal({
  isOpen,
  onClose,
  tipo, // 'periodo' o 'deuda'
  statement, // Para tipo='periodo'
  associateId, // Para tipo='deuda'
  onSuccess
}) {
  const { user } = useAuth();

  const [formData, setFormData] = useState({
    payment_amount: '',
    payment_date: new Date().toISOString().split('T')[0],
    payment_method_id: 1, // Efectivo por defecto
    payment_reference: '',
    notes: ''
  });

  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  const paymentMethods = [
    { id: 1, name: 'Efectivo' },
    { id: 2, name: 'Transferencia' },
    { id: 3, name: 'Tarjeta' },
    { id: 4, name: 'Cheque' },
  ];

  useEffect(() => {
    if (isOpen) {
      // Reset form when modal opens
      setFormData({
        payment_amount: '',
        payment_date: new Date().toISOString().split('T')[0],
        payment_method_id: 1,
        payment_reference: '',
        notes: ''
      });
      setError(null);
    }
  }, [isOpen]);

  const handleChange = (e) => {
    const { name, value } = e.target;
    setFormData(prev => ({
      ...prev,
      [name]: value
    }));
  };

  const handleSubmit = async (e) => {
    e.preventDefault();

    if (!formData.payment_amount || parseFloat(formData.payment_amount) <= 0) {
      setError('El monto debe ser mayor a 0');
      return;
    }

    setLoading(true);
    setError(null);

    try {
      // Llamar al callback de éxito con los datos
      await onSuccess({
        ...formData,
        payment_amount: parseFloat(formData.payment_amount),
        payment_method_id: parseInt(formData.payment_method_id),
        registered_by: user.id
      });

      onClose();
    } catch (err) {
      console.error('Error al registrar pago:', err);
      setError(err.response?.data?.detail || err.message || 'Error al registrar pago');
    } finally {
      setLoading(false);
    }
  };

  const formatCurrency = (value) => {
    return new Intl.NumberFormat('es-MX', {
      style: 'currency',
      currency: 'MXN',
    }).format(value);
  };

  if (!isOpen) return null;

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal-content" onClick={(e) => e.stopPropagation()}>
        <div className="modal-header">
          <h2>
            {tipo === 'periodo' ? '💰 Registrar Pago al Período' : '📊 Registrar Pago a Deuda'}
          </h2>
          <button className="modal-close" onClick={onClose}>×</button>
        </div>

        <div className="modal-body">
          {/* Información del destino */}
          {tipo === 'periodo' && statement && (
            <div className="payment-destination-info">
              <div className="info-card">
                <h3>Estado de Cuenta: {statement.statement_number || statement.cut_code}</h3>
                <div className="info-grid">
                  <div className="info-item">
                    <label>Período:</label>
                    <span>{statement.cut_code}</span>
                  </div>
                  <div className="info-item">
                    <label>Total Cobrado:</label>
                    <span className="amount-highlight">{formatCurrency(statement.total_amount_collected || 0)}</span>
                  </div>
                  <div className="info-item">
                    <label>Comisión:</label>
                    <span>{formatCurrency(statement.total_commission_owed || 0)}</span>
                  </div>
                  <div className="info-item">
                    <label>Pagado:</label>
                    <span>{formatCurrency(statement.paid_amount || 0)}</span>
                  </div>
                  <div className="info-item">
                    <label>Pendiente:</label>
                    <span className="amount-pending">
                      {formatCurrency((statement.total_amount_collected - statement.total_commission_owed) - (statement.paid_amount || 0))}
                    </span>
                  </div>
                </div>
              </div>
            </div>
          )}

          {tipo === 'deuda' && (
            <div className="payment-destination-info">
              <div className="info-card">
                <h3>Abono a Deuda Acumulada</h3>
                <p className="help-text">
                  Este pago se aplicará al saldo de deuda del asociado
                </p>
              </div>
            </div>
          )}

          {/* Formulario */}
          <form onSubmit={handleSubmit} className="payment-form">
            <div className="form-group">
              <label htmlFor="payment_amount">
                Monto a Pagar <span className="required">*</span>
              </label>
              <input
                type="number"
                id="payment_amount"
                name="payment_amount"
                value={formData.payment_amount}
                onChange={handleChange}
                step="0.01"
                min="0.01"
                placeholder="0.00"
                required
                autoFocus
              />
            </div>

            <div className="form-group">
              <label htmlFor="payment_date">
                Fecha de Pago <span className="required">*</span>
              </label>
              <input
                type="date"
                id="payment_date"
                name="payment_date"
                value={formData.payment_date}
                onChange={handleChange}
                max={new Date().toISOString().split('T')[0]}
                required
              />
            </div>

            <div className="form-group">
              <label htmlFor="payment_method_id">
                Método de Pago <span className="required">*</span>
              </label>
              <select
                id="payment_method_id"
                name="payment_method_id"
                value={formData.payment_method_id}
                onChange={handleChange}
                required
              >
                {paymentMethods.map(method => (
                  <option key={method.id} value={method.id}>
                    {method.name}
                  </option>
                ))}
              </select>
            </div>

            <div className="form-group">
              <label htmlFor="payment_reference">
                Referencia / No. Transacción
              </label>
              <input
                type="text"
                id="payment_reference"
                name="payment_reference"
                value={formData.payment_reference}
                onChange={handleChange}
                placeholder="Ej: TRANS123456"
                maxLength={100}
              />
            </div>

            <div className="form-group">
              <label htmlFor="notes">
                Notas Adicionales
              </label>
              <textarea
                id="notes"
                name="notes"
                value={formData.notes}
                onChange={handleChange}
                rows={3}
                placeholder="Observaciones del pago..."
              />
            </div>

            {error && (
              <div className="error-message">
                ⚠️ {error}
              </div>
            )}

            <div className="modal-footer">
              <button
                type="button"
                className="btn-secondary"
                onClick={onClose}
                disabled={loading}
              >
                Cancelar
              </button>
              <button
                type="submit"
                className="btn-primary"
                disabled={loading}
              >
                {loading ? '⏳ Registrando...' : '💰 Registrar Pago'}
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
  );
}
