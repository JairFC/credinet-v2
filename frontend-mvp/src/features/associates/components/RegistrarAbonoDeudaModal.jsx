/**
 * RegistrarAbonoDeudaModal - Modal para registrar abonos del ASOCIADO a su deuda
 * 
 * ⚠️ IMPORTANTE: Este es el ASOCIADO pagando a CrediCuenta, NO un cliente.
 * 
 * Usa el sistema FIFO v2:
 * - Aplica abonos desde associate_accumulated_balances
 * - Liquida deudas más antiguas primero
 * - Actualiza consolidated_debt y libera crédito (available_credit)
 */

import React, { useState, useEffect } from 'react';
import { apiClient } from '../../../shared/api/apiClient';
import ENDPOINTS from '../../../shared/api/endpoints';
import { associatesService } from '../../../shared/api/services/associatesService';

const RegistrarAbonoDeudaModal = ({
  isOpen,
  onClose,
  associateId,
  associateName,
  currentDebt = 0,
  onSuccess
}) => {
  const [formData, setFormData] = useState({
    payment_amount: '',
    payment_method_id: '1',
    payment_reference: '',
    notes: ''
  });
  const [paymentMethods, setPaymentMethods] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [result, setResult] = useState(null);

  useEffect(() => {
    if (isOpen) {
      fetchPaymentMethods();
      setError('');
      setResult(null);
      setFormData({
        payment_amount: '',
        payment_method_id: '1',
        payment_reference: '',
        notes: ''
      });
    }
  }, [isOpen]);

  const fetchPaymentMethods = async () => {
    try {
      const response = await apiClient.get(ENDPOINTS.catalogs.paymentMethods, {
        params: { active_only: true }
      });
      setPaymentMethods(response.data);
    } catch (err) {
      console.error('Error fetching payment methods:', err);
      setPaymentMethods([
        { id: 1, name: 'Efectivo' },
        { id: 2, name: 'Transferencia' },
        { id: 3, name: 'Cheque' }
      ]);
    }
  };

  const handleChange = (e) => {
    const { name, value } = e.target;
    setFormData(prev => ({ ...prev, [name]: value }));
    setError('');
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError('');
    setResult(null);

    const amount = parseFloat(formData.payment_amount);
    if (isNaN(amount) || amount <= 0) {
      setError('El monto debe ser mayor a 0');
      setLoading(false);
      return;
    }

    if (amount > currentDebt) {
      setError(`El monto ($${amount.toLocaleString('es-MX', { minimumFractionDigits: 2 })}) excede la deuda actual ($${currentDebt.toLocaleString('es-MX', { minimumFractionDigits: 2 })})`);
      setLoading(false);
      return;
    }

    try {
      const response = await associatesService.registerDebtPayment(associateId, {
        payment_amount: amount,
        payment_method_id: parseInt(formData.payment_method_id),
        payment_reference: formData.payment_reference || null,
        notes: formData.notes || null
      });

      if (response.data.success) {
        setResult(response.data);
        // Notificar éxito después de 3 segundos
        setTimeout(() => {
          onSuccess && onSuccess(response.data.data);
          handleClose();
        }, 3000);
      } else {
        setError(response.data.detail || 'Error al registrar abono');
      }
    } catch (err) {
      console.error('Error registrando abono:', err);
      setError(err.response?.data?.detail || 'Error de conexión al servidor');
    } finally {
      setLoading(false);
    }
  };

  const handleClose = () => {
    setFormData({
      payment_amount: '',
      payment_method_id: '1',
      payment_reference: '',
      notes: ''
    });
    setError('');
    setResult(null);
    onClose();
  };

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
        backgroundColor: 'rgba(0, 0, 0, 0.6)',
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
          backgroundColor: 'var(--color-surface, #1a1a2e)',
          borderRadius: '12px',
          padding: '24px',
          maxWidth: '550px',
          width: '90%',
          maxHeight: '90vh',
          overflow: 'auto',
          boxShadow: '0 8px 32px rgba(0,0,0,0.4)',
          border: '1px solid rgba(255,255,255,0.1)'
        }}
      >
        {/* Header */}
        <div style={{ marginBottom: '20px', borderBottom: '1px solid rgba(255,255,255,0.1)', paddingBottom: '16px' }}>
          <h3 style={{ margin: 0, color: 'var(--color-text-primary, #fff)', fontSize: '22px', display: 'flex', alignItems: 'center', gap: '10px' }}>
            💸 Registrar Abono a Deuda
          </h3>
          <p style={{ margin: '8px 0 0 0', opacity: 0.7, fontSize: '14px' }}>
            {associateName || 'Asociado'}
          </p>
        </div>

        {/* Resultado exitoso */}
        {result && (
          <div style={{
            backgroundColor: 'rgba(40, 167, 69, 0.2)',
            border: '1px solid #28a745',
            borderRadius: '8px',
            padding: '16px',
            marginBottom: '20px'
          }}>
            <h4 style={{ color: '#28a745', margin: '0 0 12px 0', display: 'flex', alignItems: 'center', gap: '8px' }}>
              ✅ Abono Aplicado Exitosamente
            </h4>
            <div style={{ display: 'grid', gap: '8px', fontSize: '14px' }}>
              <div><strong>Monto aplicado:</strong> ${result.data.amount_applied?.toLocaleString('es-MX', { minimumFractionDigits: 2 })}</div>
              <div><strong>Deuda restante:</strong> ${result.data.remaining_debt?.toLocaleString('es-MX', { minimumFractionDigits: 2 })}</div>
              <div><strong>Crédito liberado:</strong> ${result.data.credit_released?.toLocaleString('es-MX', { minimumFractionDigits: 2 })}</div>
              {result.data.applied_items && result.data.applied_items.length > 0 && (
                <div style={{ marginTop: '8px' }}>
                  <strong>Períodos liquidados:</strong>
                  <ul style={{ margin: '4px 0 0 0', paddingLeft: '20px' }}>
                    {result.data.applied_items.map((item, idx) => (
                      <li key={idx} style={{ fontSize: '13px' }}>
                        {item.period_code}: ${item.amount_applied?.toLocaleString('es-MX', { minimumFractionDigits: 2 })}
                        {item.fully_liquidated ? ' ✓ Liquidado' : ` (pendiente: $${item.remaining_debt?.toLocaleString('es-MX', { minimumFractionDigits: 2 })})`}
                      </li>
                    ))}
                  </ul>
                </div>
              )}
            </div>
            <p style={{ fontSize: '12px', opacity: 0.7, marginTop: '12px' }}>
              Cerrando en 3 segundos...
            </p>
          </div>
        )}

        {/* Error */}
        {error && (
          <div style={{
            backgroundColor: 'rgba(220, 53, 69, 0.2)',
            border: '1px solid #dc3545',
            borderRadius: '8px',
            padding: '12px',
            marginBottom: '16px',
            color: '#dc3545',
            fontSize: '14px'
          }}>
            ⚠️ {error}
          </div>
        )}

        {/* Resumen de deuda */}
        <div style={{
          backgroundColor: 'rgba(255, 193, 7, 0.1)',
          border: '1px solid rgba(255, 193, 7, 0.3)',
          borderRadius: '8px',
          padding: '16px',
          marginBottom: '20px'
        }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <span style={{ fontSize: '14px', opacity: 0.8 }}>Deuda Total Actual:</span>
            <span style={{ fontSize: '24px', fontWeight: 'bold', color: '#ffc107' }}>
              ${currentDebt.toLocaleString('es-MX', { minimumFractionDigits: 2 })}
            </span>
          </div>
          <p style={{ fontSize: '12px', opacity: 0.6, margin: '8px 0 0 0' }}>
            📌 FIFO: El abono se aplicará primero a las deudas más antiguas
          </p>
        </div>

        {/* Formulario */}
        {!result && (
          <form onSubmit={handleSubmit}>
            {/* Monto */}
            <div style={{ marginBottom: '16px' }}>
              <label style={{ display: 'block', marginBottom: '6px', fontSize: '14px', fontWeight: '500' }}>
                Monto del Abono *
              </label>
              <div style={{ position: 'relative' }}>
                <span style={{
                  position: 'absolute',
                  left: '12px',
                  top: '50%',
                  transform: 'translateY(-50%)',
                  fontSize: '16px',
                  opacity: 0.6
                }}>$</span>
                <input
                  type="number"
                  name="payment_amount"
                  value={formData.payment_amount}
                  onChange={handleChange}
                  placeholder="0.00"
                  step="0.01"
                  min="0.01"
                  max={currentDebt}
                  required
                  style={{
                    width: '100%',
                    padding: '12px 12px 12px 28px',
                    borderRadius: '8px',
                    border: '1px solid rgba(255,255,255,0.2)',
                    backgroundColor: 'rgba(0,0,0,0.2)',
                    color: 'var(--color-text-primary, #fff)',
                    fontSize: '18px',
                    fontWeight: 'bold'
                  }}
                />
              </div>
              {formData.payment_amount && (
                <p style={{ fontSize: '12px', opacity: 0.7, marginTop: '4px' }}>
                  Quedaría pendiente: ${(currentDebt - parseFloat(formData.payment_amount || 0)).toLocaleString('es-MX', { minimumFractionDigits: 2 })}
                </p>
              )}
            </div>

            {/* Método de pago */}
            <div style={{ marginBottom: '16px' }}>
              <label style={{ display: 'block', marginBottom: '6px', fontSize: '14px', fontWeight: '500' }}>
                Método de Pago *
              </label>
              <select
                name="payment_method_id"
                value={formData.payment_method_id}
                onChange={handleChange}
                required
                style={{
                  width: '100%',
                  padding: '12px',
                  borderRadius: '8px',
                  border: '1px solid rgba(255,255,255,0.2)',
                  backgroundColor: 'rgba(0,0,0,0.2)',
                  color: 'var(--color-text-primary, #fff)',
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
            <div style={{ marginBottom: '16px' }}>
              <label style={{ display: 'block', marginBottom: '6px', fontSize: '14px', fontWeight: '500' }}>
                Referencia (opcional)
              </label>
              <input
                type="text"
                name="payment_reference"
                value={formData.payment_reference}
                onChange={handleChange}
                placeholder="Ej: Transferencia #123456"
                maxLength={100}
                style={{
                  width: '100%',
                  padding: '12px',
                  borderRadius: '8px',
                  border: '1px solid rgba(255,255,255,0.2)',
                  backgroundColor: 'rgba(0,0,0,0.2)',
                  color: 'var(--color-text-primary, #fff)',
                  fontSize: '14px'
                }}
              />
            </div>

            {/* Notas */}
            <div style={{ marginBottom: '20px' }}>
              <label style={{ display: 'block', marginBottom: '6px', fontSize: '14px', fontWeight: '500' }}>
                Notas (opcional)
              </label>
              <textarea
                name="notes"
                value={formData.notes}
                onChange={handleChange}
                placeholder="Notas adicionales..."
                rows={2}
                style={{
                  width: '100%',
                  padding: '12px',
                  borderRadius: '8px',
                  border: '1px solid rgba(255,255,255,0.2)',
                  backgroundColor: 'rgba(0,0,0,0.2)',
                  color: 'var(--color-text-primary, #fff)',
                  fontSize: '14px',
                  resize: 'vertical'
                }}
              />
            </div>

            {/* Botones */}
            <div style={{ display: 'flex', gap: '12px', justifyContent: 'flex-end' }}>
              <button
                type="button"
                onClick={handleClose}
                disabled={loading}
                style={{
                  padding: '12px 24px',
                  borderRadius: '8px',
                  border: '1px solid rgba(255,255,255,0.2)',
                  backgroundColor: 'transparent',
                  color: 'var(--color-text-primary, #fff)',
                  fontSize: '14px',
                  cursor: 'pointer',
                  opacity: loading ? 0.5 : 1
                }}
              >
                Cancelar
              </button>
              <button
                type="submit"
                disabled={loading || !formData.payment_amount}
                style={{
                  padding: '12px 24px',
                  borderRadius: '8px',
                  border: 'none',
                  backgroundColor: loading ? '#666' : '#28a745',
                  color: '#fff',
                  fontSize: '14px',
                  fontWeight: 'bold',
                  cursor: loading ? 'not-allowed' : 'pointer',
                  display: 'flex',
                  alignItems: 'center',
                  gap: '8px'
                }}
              >
                {loading ? (
                  <>
                    <span className="spinner-small">⏳</span>
                    Procesando...
                  </>
                ) : (
                  <>
                    💰 Aplicar Abono
                  </>
                )}
              </button>
            </div>
          </form>
        )}
      </div>
    </div>
  );
};

export default RegistrarAbonoDeudaModal;
