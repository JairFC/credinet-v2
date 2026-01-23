/**
 * RegistrarAbonoModal - Modal para registrar abonos a estados de cuenta
 * 
 * Funcionalidad:
 * - Muestra info del statement y saldo pendiente
 * - Permite ingresar monto, método de pago, referencia y notas
 * - Valida datos antes de enviar
 * - Confirmación extra antes de registrar
 * - Actualiza automáticamente el estado del statement vía triggers
 */

import React, { useState, useEffect, useMemo } from 'react';
import apiClient from '@/shared/api/apiClient';
import './RegistrarAbonoModal.css';

// Iconos para métodos de pago
const PAYMENT_METHOD_ICONS = {
  'CASH': '💵',
  'TRANSFER': '🏦',
  'CHECK': '📝',
  'PAYROLL_DEDUCTION': '💼',
  'CARD': '💳',
  'DEPOSIT': '📥',
  'OXXO': '🏪'
};

// Labels amigables
const PAYMENT_METHOD_LABELS = {
  'CASH': 'Efectivo',
  'TRANSFER': 'Transferencia',
  'CHECK': 'Cheque',
  'PAYROLL_DEDUCTION': 'Descuento Nómina',
  'CARD': 'Tarjeta',
  'DEPOSIT': 'Depósito',
  'OXXO': 'OXXO'
};

export default function RegistrarAbonoModal({
  isOpen,
  onClose,
  statement,
  onSuccess,
  periodInfo
}) {
  // Estados del formulario
  const [paymentAmount, setPaymentAmount] = useState('');
  const [paymentDate, setPaymentDate] = useState(new Date().toISOString().split('T')[0]);
  const [paymentMethodId, setPaymentMethodId] = useState(1); // Default: Efectivo
  const [paymentReference, setPaymentReference] = useState('');
  const [notes, setNotes] = useState('');

  // Estados de UI
  const [paymentMethods, setPaymentMethods] = useState([]);
  const [loading, setLoading] = useState(false);
  const [loadingMethods, setLoadingMethods] = useState(true);
  const [error, setError] = useState(null);
  const [success, setSuccess] = useState(null);
  const [showConfirmation, setShowConfirmation] = useState(false);

  // Cargar métodos de pago al abrir
  useEffect(() => {
    if (isOpen) {
      loadPaymentMethods();
      // Resetear form
      setPaymentAmount('');
      setPaymentDate(new Date().toISOString().split('T')[0]);
      setPaymentMethodId(1);
      setPaymentReference('');
      setNotes('');
      setError(null);
      setSuccess(null);
      setShowConfirmation(false);
    }
  }, [isOpen]);

  const loadPaymentMethods = async () => {
    try {
      setLoadingMethods(true);
      const response = await apiClient.get('/api/v1/catalogs/payment-methods');
      const methods = response.data || [];
      setPaymentMethods(methods.filter(m => m.is_active));
    } catch (err) {
      console.error('Error loading payment methods:', err);
      // Fallback a métodos básicos
      setPaymentMethods([
        { id: 1, name: 'CASH', requires_reference: false },
        { id: 2, name: 'TRANSFER', requires_reference: true },
        { id: 6, name: 'DEPOSIT', requires_reference: true }
      ]);
    } finally {
      setLoadingMethods(false);
    }
  };

  // Calcular saldo pendiente con memoización
  // El asociado debe a CrediCuenta: total_to_credicuenta (ya mapeado en EstadosCuentaPage)
  const pendingBalance = useMemo(() => {
    if (!statement) return 0;

    let totalOwed = 0;
    let totalPaid = 0;

    // El backend ahora envía campos correctos: total_to_credicuenta y commission_earned
    if (statement.total_to_credicuenta !== undefined) {
      totalOwed = Number(statement.total_to_credicuenta) + Number(statement.late_fee || statement.late_fee_amount || 0);
      totalPaid = Number(statement.total_paid || statement.paid_amount || 0);
    }
    // Fallback para datos antiguos o no mapeados
    else if (statement.total_amount_collected !== undefined) {
      totalOwed = Number(statement.total_amount_collected || 0) + Number(statement.late_fee_amount || 0);
      totalPaid = Number(statement.paid_amount || 0);
    }

    return Math.max(0, totalOwed - totalPaid);
  }, [statement]);

  // Verificar si método requiere referencia
  const selectedMethod = paymentMethods.find(m => m.id === paymentMethodId);
  const requiresReference = selectedMethod?.requires_reference || false;

  // Validar formulario
  const validateForm = () => {
    const amount = parseFloat(paymentAmount);

    if (!amount || amount <= 0) {
      setError('El monto debe ser mayor a $0.00');
      return false;
    }

    if (amount > pendingBalance) {
      setError(`El monto no puede exceder el saldo pendiente (${formatMoney(pendingBalance)})`);
      return false;
    }

    if (!paymentDate) {
      setError('Selecciona una fecha de pago');
      return false;
    }

    if (requiresReference && !paymentReference.trim()) {
      setError('Este método de pago requiere una referencia');
      return false;
    }

    return true;
  };

  // Mostrar confirmación antes de enviar
  const handleShowConfirmation = (e) => {
    e.preventDefault();
    setError(null);
    if (!validateForm()) return;
    setShowConfirmation(true);
  };

  // Cancelar confirmación
  const handleCancelConfirmation = () => {
    setShowConfirmation(false);
  };

  // Enviar abono (después de confirmación)
  const handleSubmit = async (e) => {
    if (e) e.preventDefault();
    setError(null);
    setSuccess(null);

    if (!validateForm()) return;

    try {
      setLoading(true);

      // Llamar al endpoint de registro de abono
      const params = new URLSearchParams({
        payment_amount: paymentAmount,
        payment_date: paymentDate,
        payment_method_id: paymentMethodId.toString()
      });

      if (paymentReference.trim()) {
        params.append('payment_reference', paymentReference.trim());
      }
      if (notes.trim()) {
        params.append('notes', notes.trim());
      }

      const response = await apiClient.post(
        `/api/v1/statements/${statement.id}/payments?${params.toString()}`
      );

      if (response.data?.success) {
        setShowConfirmation(false);
        setSuccess(`✅ Abono registrado exitosamente. Nuevo saldo: ${formatMoney(response.data.data.remaining_amount)}`);

        // Esperar un momento para mostrar el éxito y luego cerrar
        setTimeout(() => {
          onSuccess && onSuccess(response.data.data);
          onClose();
        }, 1500);
      } else {
        throw new Error(response.data?.detail || 'Error al registrar abono');
      }

    } catch (err) {
      console.error('Error registering payment:', err);
      setError(err.response?.data?.detail || err.message || 'Error al registrar el abono');
    } finally {
      setLoading(false);
    }
  };

  // Formatear moneda
  const formatMoney = (amount) => {
    if (amount === null || amount === undefined) return '$0.00';
    return new Intl.NumberFormat('es-MX', {
      style: 'currency',
      currency: 'MXN'
    }).format(amount);
  };

  // Establecer monto completo
  const handlePayFull = () => {
    setPaymentAmount(pendingBalance.toFixed(2));
  };

  if (!isOpen) return null;

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="abono-modal" onClick={e => e.stopPropagation()}>
        {/* Header */}
        <div className="modal-header">
          <div className="header-info">
            <h2>💳 Registrar Abono</h2>
            <span className="statement-ref">
              {statement?.statement_number || `Statement #${statement?.id}`}
            </span>
          </div>
          <button className="close-btn" onClick={onClose} disabled={loading}>×</button>
        </div>

        {/* Info del Asociado */}
        <div className="associate-info-banner">
          <div className="associate-avatar">
            {statement?.associate_name?.split(' ').map(n => n[0]).join('').substring(0, 2).toUpperCase() || '??'}
          </div>
          <div className="associate-details">
            <h3>{statement?.associate_name || 'Asociado'}</h3>
            <span className="period-info">
              📅 Período: {periodInfo?.cut_code || statement?.cut_code || 'N/A'}
            </span>
          </div>
        </div>

        {/* Resumen de Saldo */}
        <div className="balance-summary">
          <div className="balance-item">
            <span className="balance-label">Total Adeudado</span>
            <span className="balance-value">
              {formatMoney(
                // Usar total_to_credicuenta (del backend o mapeado)
                (statement?.total_to_credicuenta || 0) + (statement?.late_fee || statement?.late_fee_amount || 0)
              )}
            </span>
          </div>
          <div className="balance-item">
            <span className="balance-label">Ya Pagado</span>
            <span className="balance-value paid">
              {formatMoney(statement?.total_paid || statement?.paid_amount || 0)}
            </span>
          </div>
          <div className="balance-item highlight">
            <span className="balance-label">Saldo Pendiente</span>
            <span className="balance-value pending">
              {formatMoney(pendingBalance)}
            </span>
          </div>
        </div>

        {/* Mensajes */}
        {error && (
          <div className="message error">
            <span className="icon">⚠️</span>
            {error}
          </div>
        )}
        {success && (
          <div className="message success">
            <span className="icon">✅</span>
            {success}
          </div>
        )}

        {/* Formulario */}
        <form onSubmit={handleShowConfirmation} className="abono-form">
          {/* Monto */}
          <div className="form-group">
            <label htmlFor="paymentAmount">
              💰 Monto del Abono
              <button
                type="button"
                className="btn-pay-full"
                onClick={handlePayFull}
                disabled={loading}
              >
                Pagar todo ({formatMoney(pendingBalance)})
              </button>
            </label>
            <div className="input-with-prefix">
              <span className="prefix">$</span>
              <input
                id="paymentAmount"
                type="number"
                step="0.01"
                min="0.01"
                value={paymentAmount}
                onChange={e => setPaymentAmount(e.target.value)}
                placeholder="0.00"
                disabled={loading}
                required
              />
            </div>
            {parseFloat(paymentAmount) > pendingBalance && (
              <p className="amount-warning">
                ⚠️ El monto máximo permitido es {formatMoney(pendingBalance)}
              </p>
            )}
          </div>

          {/* Fecha */}
          <div className="form-group">
            <label htmlFor="paymentDate">📅 Fecha del Pago</label>
            <input
              id="paymentDate"
              type="date"
              value={paymentDate}
              onChange={e => setPaymentDate(e.target.value)}
              max={new Date().toISOString().split('T')[0]}
              disabled={loading}
              required
            />
          </div>

          {/* Método de Pago */}
          <div className="form-group">
            <label htmlFor="paymentMethod">🏦 Método de Pago</label>
            {loadingMethods ? (
              <div className="loading-methods">Cargando métodos...</div>
            ) : (
              <div className="payment-methods-grid">
                {paymentMethods.map(method => (
                  <button
                    key={method.id}
                    type="button"
                    className={`method-btn ${paymentMethodId === method.id ? 'selected' : ''}`}
                    onClick={() => setPaymentMethodId(method.id)}
                    disabled={loading}
                  >
                    <span className="method-icon">
                      {PAYMENT_METHOD_ICONS[method.name] || '💳'}
                    </span>
                    <span className="method-name">
                      {PAYMENT_METHOD_LABELS[method.name] || method.name}
                    </span>
                  </button>
                ))}
              </div>
            )}
          </div>

          {/* Referencia (condicional) */}
          {requiresReference && (
            <div className="form-group">
              <label htmlFor="paymentReference">
                🔖 Referencia / Folio
                <span className="required">*</span>
              </label>
              <input
                id="paymentReference"
                type="text"
                value={paymentReference}
                onChange={e => setPaymentReference(e.target.value)}
                placeholder="Número de referencia o folio bancario"
                disabled={loading}
                required={requiresReference}
              />
            </div>
          )}

          {/* Notas */}
          <div className="form-group">
            <label htmlFor="notes">📝 Notas (opcional)</label>
            <textarea
              id="notes"
              value={notes}
              onChange={e => setNotes(e.target.value)}
              placeholder="Observaciones adicionales..."
              rows={2}
              disabled={loading}
            />
          </div>

          {/* Botones */}
          <div className="form-actions">
            <button
              type="button"
              className="btn-cancel"
              onClick={onClose}
              disabled={loading}
            >
              Cancelar
            </button>
            <button
              type="submit"
              className="btn-submit"
              disabled={loading || !paymentAmount || parseFloat(paymentAmount) <= 0}
            >
              {loading ? (
                <>
                  <span className="spinner"></span>
                  Procesando...
                </>
              ) : (
                <>
                  ➡️ Continuar
                </>
              )}
            </button>
          </div>
        </form>

        {/* Modal de Confirmación */}
        {showConfirmation && (
          <div className="confirmation-overlay">
            <div className="confirmation-card">
              <div className="confirmation-header">
                <span className="confirmation-icon">⚠️</span>
                <h3>Confirmar Abono</h3>
              </div>
              <div className="confirmation-body">
                <p className="confirmation-warning">
                  ¿Estás seguro de registrar este abono?
                </p>
                <div className="confirmation-details">
                  <div className="detail-row">
                    <span className="detail-label">Asociado:</span>
                    <span className="detail-value">{statement?.associate_name}</span>
                  </div>
                  <div className="detail-row">
                    <span className="detail-label">Monto:</span>
                    <span className="detail-value amount">{formatMoney(parseFloat(paymentAmount))}</span>
                  </div>
                  <div className="detail-row">
                    <span className="detail-label">Método:</span>
                    <span className="detail-value">
                      {PAYMENT_METHOD_LABELS[selectedMethod?.name] || selectedMethod?.name}
                    </span>
                  </div>
                  <div className="detail-row">
                    <span className="detail-label">Fecha:</span>
                    <span className="detail-value">{paymentDate}</span>
                  </div>
                  {paymentReference && (
                    <div className="detail-row">
                      <span className="detail-label">Referencia:</span>
                      <span className="detail-value">{paymentReference}</span>
                    </div>
                  )}
                </div>
                <p className="confirmation-note">
                  Esta acción no se puede deshacer fácilmente.
                </p>
              </div>
              <div className="confirmation-actions">
                <button
                  type="button"
                  className="btn-cancel"
                  onClick={handleCancelConfirmation}
                  disabled={loading}
                >
                  ← Volver
                </button>
                <button
                  type="button"
                  className="btn-confirm"
                  onClick={handleSubmit}
                  disabled={loading}
                >
                  {loading ? (
                    <>
                      <span className="spinner"></span>
                      Procesando...
                    </>
                  ) : (
                    <>
                      ✅ Confirmar Abono
                    </>
                  )}
                </button>
              </div>
            </div>
          </div>
        )}

        {/* Footer info */}
        <div className="modal-footer-info">
          <span className="info-icon">ℹ️</span>
          <span className="info-text">
            Los abonos se aplican automáticamente al estado de cuenta.
            Si hay excedente, se aplicará a deudas anteriores (FIFO).
          </span>
        </div>
      </div>
    </div>
  );
}
