/**
 * AgreementDetailPage - Detalle de Convenio
 * 
 * Muestra información del convenio con:
 * - Datos generales
 * - Items incluidos (deudas)
 * - Calendario de pagos con acción de registrar
 * - Progreso de pago
 */
import React, { useState, useEffect, useCallback } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { agreementsService } from '../../../shared/api/services';
import './AgreementDetailPage.css';

const AgreementDetailPage = () => {
  const { agreementId } = useParams();
  const navigate = useNavigate();
  
  const [agreement, setAgreement] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  
  // Modal para registrar pago
  const [showPaymentModal, setShowPaymentModal] = useState(false);
  const [selectedPayment, setSelectedPayment] = useState(null);
  const [paymentData, setPaymentData] = useState({
    payment_method_id: 1,
    payment_reference: '',
    notes: ''
  });
  const [isProcessing, setIsProcessing] = useState(false);

  const loadAgreement = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const response = await agreementsService.getAgreement(agreementId);
      setAgreement(response.data);
    } catch (err) {
      console.error('Error cargando convenio:', err);
      setError(err.response?.data?.detail || 'Error al cargar el convenio');
    } finally {
      setLoading(false);
    }
  }, [agreementId]);

  useEffect(() => {
    loadAgreement();
  }, [loadAgreement]);

  const formatCurrency = (amount) => {
    return new Intl.NumberFormat('es-MX', {
      style: 'currency',
      currency: 'MXN'
    }).format(amount);
  };

  const formatDate = (dateStr) => {
    if (!dateStr) return '-';
    return new Date(dateStr).toLocaleDateString('es-MX', {
      year: 'numeric',
      month: 'short',
      day: 'numeric'
    });
  };

  const getStatusBadge = (status) => {
    const statusConfig = {
      ACTIVE: { label: 'Activo', class: 'status-active' },
      COMPLETED: { label: 'Completado', class: 'status-completed' },
      DEFAULTED: { label: 'Incumplido', class: 'status-defaulted' },
      CANCELLED: { label: 'Cancelado', class: 'status-cancelled' },
      PENDING: { label: 'Pendiente', class: 'status-pending' },
      PAID: { label: 'Pagado', class: 'status-paid' },
      OVERDUE: { label: 'Vencido', class: 'status-overdue' }
    };
    const config = statusConfig[status] || { label: status, class: '' };
    return <span className={`status-badge ${config.class}`}>{config.label}</span>;
  };

  const formatDebtType = (type) => {
    const types = {
      DEFAULTED_CLIENT: 'Cliente Moroso',
      UNREPORTED_PAYMENT: 'Pago No Reportado',
      LATE_FEE: 'Cargo por Mora',
      OTHER: 'Otro'
    };
    return types[type] || type;
  };

  // Calcular progreso
  const calculateProgress = () => {
    if (!agreement) return 0;
    const total = parseFloat(agreement.total_debt_amount || 0);
    const paid = parseFloat(agreement.total_paid || 0);
    if (total === 0) return 0;
    return Math.min(100, Math.round((paid / total) * 100));
  };

  // Abrir modal para registrar pago
  const openPaymentModal = (payment) => {
    setSelectedPayment(payment);
    setPaymentData({
      payment_method_id: 1,
      payment_reference: '',
      notes: ''
    });
    setShowPaymentModal(true);
  };

  // Registrar pago
  const handleRegisterPayment = async () => {
    if (!selectedPayment) return;
    
    setIsProcessing(true);
    try {
      await agreementsService.registerAgreementPayment(
        agreementId, 
        selectedPayment.payment_number,
        paymentData
      );
      setShowPaymentModal(false);
      loadAgreement(); // Recargar
    } catch (err) {
      console.error('Error registrando pago:', err);
      alert(err.response?.data?.detail || 'Error al registrar el pago');
    } finally {
      setIsProcessing(false);
    }
  };

  if (loading) {
    return (
      <div className="agreement-detail-page">
        <div className="loading-state">
          <span className="spinner">🔄</span>
          Cargando convenio...
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="agreement-detail-page">
        <div className="error-state">
          <h2>⚠️ Error</h2>
          <p>{error}</p>
          <button onClick={() => navigate('/convenios')}>
            Volver a Convenios
          </button>
        </div>
      </div>
    );
  }

  if (!agreement) return null;

  const progress = calculateProgress();

  return (
    <div className="agreement-detail-page">
      {/* Header */}
      <div className="page-header">
        <button 
          className="btn-back" 
          onClick={() => navigate('/convenios')}
        >
          ← Volver a Convenios
        </button>
        <div className="header-content">
          <div className="header-left">
            <h1>Convenio {agreement.agreement_number}</h1>
            <p className="subtitle">{agreement.associate_name}</p>
          </div>
          <div className="header-right">
            {getStatusBadge(agreement.status)}
          </div>
        </div>
      </div>

      {/* Progress Card */}
      <div className="progress-card">
        <div className="progress-info">
          <div className="progress-stats">
            <div className="stat">
              <span className="stat-label">Deuda Total</span>
              <span className="stat-value">{formatCurrency(agreement.total_debt_amount)}</span>
            </div>
            <div className="stat">
              <span className="stat-label">Pagado</span>
              <span className="stat-value paid">{formatCurrency(agreement.total_paid)}</span>
            </div>
            <div className="stat">
              <span className="stat-label">Pendiente</span>
              <span className="stat-value pending">
                {formatCurrency(agreement.total_debt_amount - agreement.total_paid)}
              </span>
            </div>
          </div>
          <div className="progress-bar-container">
            <div className="progress-bar" style={{ width: `${progress}%` }}></div>
          </div>
          <div className="progress-text">{progress}% completado</div>
        </div>
      </div>

      {/* Details Grid */}
      <div className="details-grid">
        {/* Agreement Info */}
        <div className="detail-card">
          <h2>📋 Información del Convenio</h2>
          <div className="info-grid">
            <div className="info-item">
              <span className="info-label">Número</span>
              <span className="info-value">{agreement.agreement_number}</span>
            </div>
            <div className="info-item">
              <span className="info-label">Fecha Creación</span>
              <span className="info-value">{formatDate(agreement.agreement_date)}</span>
            </div>
            <div className="info-item">
              <span className="info-label">Inicio Pagos</span>
              <span className="info-value">{formatDate(agreement.start_date)}</span>
            </div>
            <div className="info-item">
              <span className="info-label">Fin Estimado</span>
              <span className="info-value">{formatDate(agreement.end_date)}</span>
            </div>
            <div className="info-item">
              <span className="info-label">Plazo</span>
              <span className="info-value">{agreement.payment_plan_months} meses</span>
            </div>
            <div className="info-item">
              <span className="info-label">Pago Mensual</span>
              <span className="info-value">{formatCurrency(agreement.monthly_payment_amount)}</span>
            </div>
            <div className="info-item">
              <span className="info-label">Pagos Realizados</span>
              <span className="info-value">
                {agreement.payments_made} de {agreement.payment_plan_months}
              </span>
            </div>
            {agreement.next_payment_date && (
              <div className="info-item">
                <span className="info-label">Próximo Pago</span>
                <span className="info-value highlight">{formatDate(agreement.next_payment_date)}</span>
              </div>
            )}
          </div>
          {agreement.notes && (
            <div className="notes-section">
              <h4>Notas</h4>
              <p>{agreement.notes}</p>
            </div>
          )}
        </div>

        {/* Items */}
        <div className="detail-card">
          <h2>📦 Deudas Incluidas ({agreement.items?.length || 0})</h2>
          {agreement.items?.length > 0 ? (
            <div className="items-list">
              {agreement.items.map(item => (
                <div key={item.id} className="item-row">
                  <div className="item-info">
                    <span className="item-type">{formatDebtType(item.debt_type)}</span>
                    {item.client_name && (
                      <span className="item-client">Cliente: {item.client_name}</span>
                    )}
                    {item.loan_id && (
                      <span className="item-loan">Préstamo #{item.loan_id}</span>
                    )}
                    {item.description && (
                      <span className="item-desc">{item.description}</span>
                    )}
                  </div>
                  <span className="item-amount">{formatCurrency(item.debt_amount)}</span>
                </div>
              ))}
            </div>
          ) : (
            <p className="no-items">No hay items registrados</p>
          )}
        </div>
      </div>

      {/* Payments Calendar */}
      <div className="detail-card payments-card">
        <h2>📅 Calendario de Pagos</h2>
        {agreement.payments?.length > 0 ? (
          <div className="payments-table-container">
            <table className="payments-table">
              <thead>
                <tr>
                  <th>#</th>
                  <th>Fecha Vencimiento</th>
                  <th>Monto</th>
                  <th>Estado</th>
                  <th>Fecha Pago</th>
                  <th>Referencia</th>
                  <th>Acciones</th>
                </tr>
              </thead>
              <tbody>
                {agreement.payments.map(payment => (
                  <tr key={payment.id} className={`payment-row ${payment.status.toLowerCase()}`}>
                    <td>{payment.payment_number}</td>
                    <td>{formatDate(payment.payment_due_date)}</td>
                    <td>{formatCurrency(payment.payment_amount)}</td>
                    <td>{getStatusBadge(payment.status)}</td>
                    <td>{payment.payment_date ? formatDate(payment.payment_date) : '-'}</td>
                    <td>{payment.payment_reference || '-'}</td>
                    <td>
                      {payment.status === 'PENDING' && agreement.status === 'ACTIVE' && (
                        <button 
                          className="btn-register-payment"
                          onClick={() => openPaymentModal(payment)}
                        >
                          💰 Registrar
                        </button>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <p className="no-items">No hay pagos programados</p>
        )}
      </div>

      {/* Payment Modal */}
      {showPaymentModal && selectedPayment && (
        <div className="modal-overlay" onClick={() => setShowPaymentModal(false)}>
          <div className="modal-content" onClick={e => e.stopPropagation()}>
            <div className="modal-header">
              <h3>💰 Registrar Pago #{selectedPayment.payment_number}</h3>
              <button 
                className="modal-close"
                onClick={() => setShowPaymentModal(false)}
              >
                ×
              </button>
            </div>
            <div className="modal-body">
              <div className="payment-summary">
                <p><strong>Monto:</strong> {formatCurrency(selectedPayment.payment_amount)}</p>
                <p><strong>Vencimiento:</strong> {formatDate(selectedPayment.payment_due_date)}</p>
              </div>
              
              <div className="form-group">
                <label>Método de Pago</label>
                <select
                  value={paymentData.payment_method_id}
                  onChange={(e) => setPaymentData({
                    ...paymentData,
                    payment_method_id: parseInt(e.target.value)
                  })}
                  className="form-control"
                >
                  <option value={1}>Efectivo</option>
                  <option value={2}>Transferencia</option>
                  <option value={3}>Depósito</option>
                </select>
              </div>
              
              <div className="form-group">
                <label>Referencia (opcional)</label>
                <input
                  type="text"
                  value={paymentData.payment_reference}
                  onChange={(e) => setPaymentData({
                    ...paymentData,
                    payment_reference: e.target.value
                  })}
                  placeholder="Número de referencia, folio, etc."
                  className="form-control"
                />
              </div>
              
              <div className="form-group">
                <label>Notas (opcional)</label>
                <textarea
                  value={paymentData.notes}
                  onChange={(e) => setPaymentData({
                    ...paymentData,
                    notes: e.target.value
                  })}
                  placeholder="Notas adicionales..."
                  className="form-control"
                  rows="2"
                />
              </div>
            </div>
            <div className="modal-footer">
              <button 
                className="btn btn-secondary"
                onClick={() => setShowPaymentModal(false)}
                disabled={isProcessing}
              >
                Cancelar
              </button>
              <button 
                className="btn btn-primary"
                onClick={handleRegisterPayment}
                disabled={isProcessing}
              >
                {isProcessing ? 'Procesando...' : 'Registrar Pago'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default AgreementDetailPage;
