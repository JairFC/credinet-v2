import React, { useState, useEffect } from 'react';
import { API_BASE_URL } from '../config';

const ModalRegistrarAbono = ({
  isOpen,
  onClose,
  statementId,
  associateId,
  totalOwed = 0,
  paidAmount = 0,
  onSuccess
}) => {
  const [paymentType, setPaymentType] = useState('SALDO_ACTUAL'); // SALDO_ACTUAL | DEUDA_ACUMULADA
  const [formData, setFormData] = useState({
    payment_amount: '',
    payment_date: new Date().toISOString().split('T')[0],
    payment_method_id: '1',
    payment_reference: '',
    notes: ''
  });
  const [paymentMethods, setPaymentMethods] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [debtSummary, setDebtSummary] = useState(null);

  useEffect(() => {
    if (isOpen) {
      fetchPaymentMethods();
      if (paymentType === 'DEUDA_ACUMULADA' && associateId) {
        fetchDebtSummary();
      }
    }
  }, [isOpen, paymentType, associateId]);

  const fetchPaymentMethods = async () => {
    try {
      const token = localStorage.getItem('token');
      const response = await fetch(`${API_BASE_URL}/catalogs/payment-methods?active_only=true`, {
        headers: { 'Authorization': `Bearer ${token}` }
      });

      if (response.ok) {
        const data = await response.json();
        setPaymentMethods(data);
      }
    } catch (err) {
      console.error('Error fetching payment methods:', err);
    }
  };

  const fetchDebtSummary = async () => {
    try {
      const token = localStorage.getItem('token');
      const response = await fetch(`${API_BASE_URL}/associates/${associateId}/debt-summary`, {
        headers: { 'Authorization': `Bearer ${token}` }
      });

      if (response.ok) {
        const result = await response.json();
        setDebtSummary(result.data);
      }
    } catch (err) {
      console.error('Error fetching debt summary:', err);
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError('');

    try {
      const token = localStorage.getItem('token');
      let url, params;

      if (paymentType === 'SALDO_ACTUAL') {
        url = `${API_BASE_URL}/statements/${statementId}/payments`;
        params = new URLSearchParams({
          payment_amount: formData.payment_amount,
          payment_date: formData.payment_date,
          payment_method_id: formData.payment_method_id,
          ...(formData.payment_reference && { payment_reference: formData.payment_reference }),
          ...(formData.notes && { notes: formData.notes })
        });
      } else {
        url = `${API_BASE_URL}/associates/${associateId}/debt-payments`;
        params = new URLSearchParams({
          payment_amount: formData.payment_amount,
          payment_date: formData.payment_date,
          payment_method_id: formData.payment_method_id,
          ...(formData.payment_reference && { payment_reference: formData.payment_reference }),
          ...(formData.notes && { notes: formData.notes })
        });
      }

      const response = await fetch(`${url}?${params}`, {
        method: 'POST',
        headers: { 'Authorization': `Bearer ${token}` }
      });

      const result = await response.json();

      if (response.ok && result.success) {
        onSuccess && onSuccess(result.data);
        handleClose();
      } else {
        setError(result.detail || 'Error al registrar abono');
      }
    } catch (err) {
      setError('Error de conexión: ' + err.message);
    } finally {
      setLoading(false);
    }
  };

  const handleClose = () => {
    setFormData({
      payment_amount: '',
      payment_date: new Date().toISOString().split('T')[0],
      payment_method_id: '1',
      payment_reference: '',
      notes: ''
    });
    setPaymentType('SALDO_ACTUAL');
    setError('');
    setDebtSummary(null);
    onClose();
  };

  const remainingAmount = totalOwed - paidAmount;

  if (!isOpen) return null;

  return (
    <div
      className="modal-overlay"
      onClick={handleClose}
      style={{
        position: 'fixed',
        top: 0,
        left: 0,
        right: 0,
        bottom: 0,
        backgroundColor: 'rgba(0, 0, 0, 0.5)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        zIndex: 1000
      }}
    >
      <div
        className="modal-content"
        onClick={(e) => e.stopPropagation()}
        style={{
          backgroundColor: 'var(--color-surface)',
          borderRadius: '8px',
          padding: '24px',
          maxWidth: '600px',
          width: '90%',
          maxHeight: '90vh',
          overflow: 'auto',
          boxShadow: '0 4px 20px rgba(0,0,0,0.3)'
        }}
      >
        <div className="modal-header" style={{ marginBottom: '20px' }}>
          <h3 style={{ margin: 0, color: 'var(--color-text-primary)', fontSize: '20px' }}>
            💰 Registrar Abono
          </h3>
        </div>

        <form onSubmit={handleSubmit}>
          {/* Selector de Tipo de Abono */}
          <div className="form-group" style={{ marginBottom: '20px' }}>
            <label style={{ display: 'block', marginBottom: '8px', fontWeight: '500' }}>
              Tipo de Abono
            </label>
            <div style={{ display: 'flex', gap: '16px' }}>
              <label style={{ display: 'flex', alignItems: 'center', cursor: 'pointer' }}>
                <input
                  type="radio"
                  name="paymentType"
                  value="SALDO_ACTUAL"
                  checked={paymentType === 'SALDO_ACTUAL'}
                  onChange={(e) => setPaymentType(e.target.value)}
                  style={{ marginRight: '8px' }}
                />
                <span>📊 Saldo Actual</span>
              </label>
              <label style={{ display: 'flex', alignItems: 'center', cursor: 'pointer' }}>
                <input
                  type="radio"
                  name="paymentType"
                  value="DEUDA_ACUMULADA"
                  checked={paymentType === 'DEUDA_ACUMULADA'}
                  onChange={(e) => setPaymentType(e.target.value)}
                  style={{ marginRight: '8px' }}
                />
                <span>📜 Deuda Acumulada</span>
              </label>
            </div>
          </div>

          {/* Info del Statement (solo si es saldo actual) */}
          {paymentType === 'SALDO_ACTUAL' && (
            <div className="info-box" style={{
              padding: '12px',
              backgroundColor: 'var(--color-surface-secondary)',
              borderRadius: '6px',
              marginBottom: '16px',
              fontSize: '14px'
            }}>
              <div><strong>Adeudado:</strong> ${totalOwed.toFixed(2)}</div>
              <div><strong>Pagado:</strong> ${paidAmount.toFixed(2)}</div>
              <div style={{
                marginTop: '4px',
                paddingTop: '8px',
                borderTop: '1px solid var(--color-border)',
                fontWeight: '600'
              }}>
                <strong>Restante:</strong> ${remainingAmount.toFixed(2)}
              </div>
            </div>
          )}

          {/* Info de Deuda (solo si es deuda acumulada) */}
          {paymentType === 'DEUDA_ACUMULADA' && debtSummary && (
            <div className="info-box" style={{
              padding: '12px',
              backgroundColor: 'var(--color-warning-light)',
              borderRadius: '6px',
              marginBottom: '16px',
              fontSize: '14px'
            }}>
              <div><strong>Deuda Total:</strong> ${debtSummary.current_debt_balance?.toFixed(2) || '0.00'}</div>
              <div><strong>Items Pendientes:</strong> {debtSummary.pending_debt_items || 0}</div>
              <div style={{ fontSize: '12px', marginTop: '4px', opacity: 0.8 }}>
                ℹ️ Se aplicará FIFO (más antiguos primero)
              </div>
            </div>
          )}

          {/* Monto */}
          <div className="form-group" style={{ marginBottom: '16px' }}>
            <label style={{ display: 'block', marginBottom: '4px' }}>
              Monto del Abono *
            </label>
            <input
              type="number"
              step="0.01"
              min="0.01"
              className="form-input"
              value={formData.payment_amount}
              onChange={(e) => setFormData({ ...formData, payment_amount: e.target.value })}
              required
              placeholder="0.00"
              style={{
                width: '100%',
                padding: '8px 12px',
                borderRadius: '4px',
                border: '1px solid var(--color-border)',
                fontSize: '14px'
              }}
            />
          </div>

          {/* Fecha */}
          <div className="form-group" style={{ marginBottom: '16px' }}>
            <label style={{ display: 'block', marginBottom: '4px' }}>
              Fecha del Abono *
            </label>
            <input
              type="date"
              className="form-input"
              value={formData.payment_date}
              onChange={(e) => setFormData({ ...formData, payment_date: e.target.value })}
              max={new Date().toISOString().split('T')[0]}
              required
              style={{
                width: '100%',
                padding: '8px 12px',
                borderRadius: '4px',
                border: '1px solid var(--color-border)',
                fontSize: '14px'
              }}
            />
          </div>

          {/* Método de Pago */}
          <div className="form-group" style={{ marginBottom: '16px' }}>
            <label style={{ display: 'block', marginBottom: '4px' }}>
              Método de Pago *
            </label>
            <select
              className="form-input"
              value={formData.payment_method_id}
              onChange={(e) => setFormData({ ...formData, payment_method_id: e.target.value })}
              required
              style={{
                width: '100%',
                padding: '8px 12px',
                borderRadius: '4px',
                border: '1px solid var(--color-border)',
                fontSize: '14px'
              }}
            >
              {paymentMethods.map(method => (
                <option key={method.id} value={method.id}>
                  {method.name}
                </option>
              ))}
            </select>
          </div>

          {/* Referencia */}
          <div className="form-group" style={{ marginBottom: '16px' }}>
            <label style={{ display: 'block', marginBottom: '4px' }}>
              Referencia de Pago
            </label>
            <input
              type="text"
              className="form-input"
              value={formData.payment_reference}
              onChange={(e) => setFormData({ ...formData, payment_reference: e.target.value })}
              placeholder="SPEI-123456, Recibo #001, etc."
              style={{
                width: '100%',
                padding: '8px 12px',
                borderRadius: '4px',
                border: '1px solid var(--color-border)',
                fontSize: '14px'
              }}
            />
          </div>

          {/* Notas */}
          <div className="form-group" style={{ marginBottom: '20px' }}>
            <label style={{ display: 'block', marginBottom: '4px' }}>
              Notas
            </label>
            <textarea
              className="form-input"
              value={formData.notes}
              onChange={(e) => setFormData({ ...formData, notes: e.target.value })}
              rows="3"
              placeholder="Información adicional..."
              style={{
                width: '100%',
                padding: '8px 12px',
                borderRadius: '4px',
                border: '1px solid var(--color-border)',
                fontSize: '14px',
                resize: 'vertical'
              }}
            />
          </div>

          {/* Error */}
          {error && (
            <div className="alert alert-danger" style={{
              padding: '10px',
              backgroundColor: 'var(--color-danger-light)',
              color: 'var(--color-danger)',
              borderRadius: '4px',
              marginBottom: '16px',
              fontSize: '14px'
            }}>
              {error}
            </div>
          )}

          {/* Botones */}
          <div className="modal-actions" style={{ display: 'flex', gap: '12px', justifyContent: 'flex-end' }}>
            <button
              type="button"
              onClick={handleClose}
              className="btn btn-secondary"
              disabled={loading}
              style={{
                padding: '8px 16px',
                borderRadius: '4px',
                border: 'none',
                cursor: 'pointer',
                fontSize: '14px',
                backgroundColor: 'var(--color-surface-secondary)',
                color: 'var(--color-text-primary)'
              }}
            >
              Cancelar
            </button>
            <button
              type="submit"
              className="btn btn-primary"
              disabled={loading}
              style={{
                padding: '8px 16px',
                borderRadius: '4px',
                border: 'none',
                cursor: loading ? 'not-allowed' : 'pointer',
                fontSize: '14px',
                backgroundColor: 'var(--color-primary)',
                color: 'white',
                opacity: loading ? 0.6 : 1
              }}
            >
              {loading ? '⏳ Registrando...' : '💾 Registrar Abono'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};

export default ModalRegistrarAbono;
