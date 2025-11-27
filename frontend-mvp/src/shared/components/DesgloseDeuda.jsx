import React, { useState, useEffect } from 'react';
import { apiClient } from '../api/apiClient';
import ENDPOINTS from '../api/endpoints';

const DesgloseDeuda = ({ associateId }) => {
  const [debtSummary, setDebtSummary] = useState(null);
  const [allPayments, setAllPayments] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [activeTab, setActiveTab] = useState('items'); // 'items' | 'payments'

  useEffect(() => {
    if (associateId) {
      fetchDebtData();
    }
  }, [associateId]);

  const fetchDebtData = async () => {
    try {
      setLoading(true);

      // Fetch debt summary
      const summaryResponse = await apiClient.get(ENDPOINTS.associates.debtSummary(associateId));

      if (!summaryResponse.data.success) {
        throw new Error(summaryResponse.data.detail || 'Error al cargar resumen de deuda');
      }

      setDebtSummary(summaryResponse.data.data);

      // Fetch all payments
      const paymentsResponse = await apiClient.get(ENDPOINTS.associates.allPayments(associateId));

      if (paymentsResponse.data.success) {
        setAllPayments(paymentsResponse.data.data.payments || []);
      }

    } catch (err) {
      setError(err.response?.data?.detail || err.message);
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return (
      <div style={{ padding: '20px', textAlign: 'center' }}>
        <div className="spinner">⏳ Cargando desglose de deuda...</div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="alert alert-danger" style={{ margin: '20px' }}>
        {error}
      </div>
    );
  }

  if (!debtSummary) {
    return (
      <div className="alert alert-info" style={{ margin: '20px' }}>
        📋 No hay datos de deuda disponibles
      </div>
    );
  }

  const { summary, debt_items, debt_payments } = debtSummary;

  // Validar que summary exista antes de renderizar
  if (!summary) {
    return (
      <div className="alert alert-info" style={{ margin: '20px' }}>
        📋 No hay información de resumen de deuda
      </div>
    );
  }

  // Valores por defecto seguros
  const items = debt_items || [];
  const payments = debt_payments || [];

  return (
    <div style={{ padding: '20px' }}>
      {/* Resumen General */}
      <div className="card" style={{
        padding: '20px',
        marginBottom: '24px',
        backgroundColor: 'var(--color-surface-secondary)',
        borderRadius: '8px'
      }}>
        <h3 style={{ marginTop: 0, marginBottom: '16px', fontSize: '18px' }}>
          📊 Resumen de Deuda
        </h3>

        <div style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))',
          gap: '16px'
        }}>
          <div>
            <div style={{ fontSize: '12px', opacity: 0.7 }}>Deuda Total</div>
            <div style={{
              fontSize: '24px',
              fontWeight: '700',
              color: (summary.total_debt || 0) > 0 ? 'var(--color-danger)' : 'var(--color-success)'
            }}>
              ${(summary.total_debt || 0).toFixed(2)}
            </div>
          </div>

          <div>
            <div style={{ fontSize: '12px', opacity: 0.7 }}>Items Pendientes</div>
            <div style={{ fontSize: '24px', fontWeight: '700', color: 'var(--color-warning)' }}>
              {summary.pending_items || 0}
            </div>
          </div>

          <div>
            <div style={{ fontSize: '12px', opacity: 0.7 }}>Items Liquidados</div>
            <div style={{ fontSize: '24px', fontWeight: '700', color: 'var(--color-success)' }}>
              {summary.liquidated_items || 0}
            </div>
          </div>

          <div>
            <div style={{ fontSize: '12px', opacity: 0.7 }}>Total Pagado (Deuda)</div>
            <div style={{ fontSize: '24px', fontWeight: '700', color: 'var(--color-primary)' }}>
              ${(summary.total_paid_debt || 0).toFixed(2)}
            </div>
          </div>
        </div>

        {/* FIFO Notice */}
        {(summary.pending_items || 0) > 0 && (
          <div style={{
            marginTop: '16px',
            padding: '12px',
            backgroundColor: 'var(--color-warning-light)',
            borderLeft: '4px solid var(--color-warning)',
            borderRadius: '4px'
          }}>
            <strong>⚡ Método FIFO:</strong> Los pagos se aplicarán automáticamente a los adeudos más antiguos primero.
          </div>
        )}
      </div>

      {/* Tabs */}
      <div style={{ marginBottom: '16px' }}>
        <button
          onClick={() => setActiveTab('items')}
          style={{
            padding: '10px 20px',
            marginRight: '8px',
            border: 'none',
            borderBottom: activeTab === 'items' ? '3px solid var(--color-primary)' : '3px solid transparent',
            backgroundColor: 'transparent',
            cursor: 'pointer',
            fontWeight: activeTab === 'items' ? '600' : '400',
            color: activeTab === 'items' ? 'var(--color-primary)' : 'var(--color-text-secondary)'
          }}
        >
          📜 Items de Deuda ({items.length})
        </button>
        <button
          onClick={() => setActiveTab('payments')}
          style={{
            padding: '10px 20px',
            border: 'none',
            borderBottom: activeTab === 'payments' ? '3px solid var(--color-primary)' : '3px solid transparent',
            backgroundColor: 'transparent',
            cursor: 'pointer',
            fontWeight: activeTab === 'payments' ? '600' : '400',
            color: activeTab === 'payments' ? 'var(--color-primary)' : 'var(--color-text-secondary)'
          }}
        >
          💰 Pagos a Deuda ({payments.length})
        </button>
      </div>

      {/* Content */}
      {activeTab === 'items' && (
        <DebtItemsTable items={items} />
      )}

      {activeTab === 'payments' && (
        <DebtPaymentsTable payments={payments} allPayments={allPayments} />
      )}
    </div>
  );
};

// Sub-component: Debt Items Table
const DebtItemsTable = ({ items }) => {
  if (items.length === 0) {
    return (
      <div className="alert alert-info">
        ✅ No hay items de deuda registrados
      </div>
    );
  }

  return (
    <div className="card" style={{ padding: '0', overflow: 'hidden' }}>
      <table className="table" style={{
        width: '100%',
        borderCollapse: 'collapse',
        fontSize: '14px'
      }}>
        <thead>
          <tr style={{
            backgroundColor: 'var(--color-surface-secondary)',
            borderBottom: '2px solid var(--color-border)'
          }}>
            <th style={{ padding: '12px', textAlign: 'left' }}>Creado</th>
            <th style={{ padding: '12px', textAlign: 'left' }}>Concepto</th>
            <th style={{ padding: '12px', textAlign: 'right' }}>Monto Original</th>
            <th style={{ padding: '12px', textAlign: 'right' }}>Pagado</th>
            <th style={{ padding: '12px', textAlign: 'right' }}>Restante</th>
            <th style={{ padding: '12px', textAlign: 'center' }}>Estado</th>
          </tr>
        </thead>
        <tbody>
          {items.map((item, index) => {
            const remaining = item.debt_amount - item.paid_amount;
            const isLiquidated = item.is_liquidated;

            return (
              <tr
                key={item.id}
                style={{
                  borderBottom: '1px solid var(--color-border)',
                  backgroundColor: index % 2 === 0 ? 'transparent' : 'var(--color-surface-secondary)',
                  opacity: isLiquidated ? 0.6 : 1
                }}
              >
                <td style={{ padding: '12px', fontSize: '13px' }}>
                  {new Date(item.created_at).toLocaleDateString('es-MX')}
                </td>
                <td style={{ padding: '12px' }}>
                  {item.debt_concept}
                  {item.statement_id && (
                    <div style={{ fontSize: '11px', opacity: 0.6 }}>
                      Statement #{item.statement_id}
                    </div>
                  )}
                </td>
                <td style={{
                  padding: '12px',
                  textAlign: 'right',
                  fontWeight: '600'
                }}>
                  ${item.debt_amount.toFixed(2)}
                </td>
                <td style={{
                  padding: '12px',
                  textAlign: 'right',
                  color: 'var(--color-success)'
                }}>
                  ${item.paid_amount.toFixed(2)}
                </td>
                <td style={{
                  padding: '12px',
                  textAlign: 'right',
                  fontWeight: '600',
                  color: isLiquidated ? 'var(--color-success)' : 'var(--color-danger)'
                }}>
                  ${remaining.toFixed(2)}
                </td>
                <td style={{ padding: '12px', textAlign: 'center' }}>
                  {isLiquidated ? (
                    <span style={{
                      backgroundColor: 'var(--color-success)',
                      color: 'white',
                      padding: '4px 8px',
                      borderRadius: '4px',
                      fontSize: '11px',
                      fontWeight: '600'
                    }}>
                      ✅ LIQUIDADO
                    </span>
                  ) : (
                    <span style={{
                      backgroundColor: 'var(--color-warning)',
                      color: 'white',
                      padding: '4px 8px',
                      borderRadius: '4px',
                      fontSize: '11px',
                      fontWeight: '600'
                    }}>
                      ⏳ PENDIENTE
                    </span>
                  )}
                </td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
};

// Sub-component: Debt Payments Table
const DebtPaymentsTable = ({ payments, allPayments }) => {
  const [showAllPayments, setShowAllPayments] = useState(false);

  const displayPayments = showAllPayments ? allPayments : payments;

  if (payments.length === 0 && !showAllPayments) {
    return (
      <div className="alert alert-info">
        📋 No hay pagos a deuda registrados aún
        {allPayments.length > 0 && (
          <>
            <br /><br />
            <button
              onClick={() => setShowAllPayments(true)}
              style={{
                padding: '8px 16px',
                backgroundColor: 'var(--color-primary)',
                color: 'white',
                border: 'none',
                borderRadius: '4px',
                cursor: 'pointer'
              }}
            >
              Ver todos los pagos ({allPayments.length})
            </button>
          </>
        )}
      </div>
    );
  }

  return (
    <>
      {allPayments.length > 0 && (
        <div style={{ marginBottom: '16px', display: 'flex', gap: '8px' }}>
          <button
            onClick={() => setShowAllPayments(false)}
            style={{
              padding: '8px 16px',
              backgroundColor: showAllPayments ? 'transparent' : 'var(--color-primary)',
              color: showAllPayments ? 'var(--color-text-primary)' : 'white',
              border: '1px solid var(--color-primary)',
              borderRadius: '4px',
              cursor: 'pointer'
            }}
          >
            Pagos a Deuda ({payments.length})
          </button>
          <button
            onClick={() => setShowAllPayments(true)}
            style={{
              padding: '8px 16px',
              backgroundColor: showAllPayments ? 'var(--color-primary)' : 'transparent',
              color: showAllPayments ? 'white' : 'var(--color-text-primary)',
              border: '1px solid var(--color-primary)',
              borderRadius: '4px',
              cursor: 'pointer'
            }}
          >
            Todos los Pagos ({allPayments.length})
          </button>
        </div>
      )}

      <div className="card" style={{ padding: '0', overflow: 'hidden' }}>
        <table className="table" style={{
          width: '100%',
          borderCollapse: 'collapse',
          fontSize: '14px'
        }}>
          <thead>
            <tr style={{
              backgroundColor: 'var(--color-surface-secondary)',
              borderBottom: '2px solid var(--color-border)'
            }}>
              <th style={{ padding: '12px', textAlign: 'left' }}>Fecha</th>
              {showAllPayments && (
                <th style={{ padding: '12px', textAlign: 'center' }}>Tipo</th>
              )}
              <th style={{ padding: '12px', textAlign: 'right' }}>Monto</th>
              <th style={{ padding: '12px', textAlign: 'left' }}>Método</th>
              <th style={{ padding: '12px', textAlign: 'left' }}>Referencia</th>
              <th style={{ padding: '12px', textAlign: 'left' }}>Items Aplicados</th>
            </tr>
          </thead>
          <tbody>
            {displayPayments.map((payment, index) => {
              const breakdown = payment.applied_breakdown_items || [];
              const isDebtPayment = payment.payment_type === 'DEUDA_ACUMULADA' || !showAllPayments;

              return (
                <tr
                  key={`${payment.payment_type || 'debt'}-${payment.id}`}
                  style={{
                    borderBottom: '1px solid var(--color-border)',
                    backgroundColor: index % 2 === 0 ? 'transparent' : 'var(--color-surface-secondary)'
                  }}
                >
                  <td style={{ padding: '12px' }}>
                    {new Date(payment.payment_date).toLocaleDateString('es-MX')}
                  </td>
                  {showAllPayments && (
                    <td style={{ padding: '12px', textAlign: 'center' }}>
                      {payment.payment_type === 'SALDO_ACTUAL' ? (
                        <span style={{
                          padding: '4px 8px',
                          backgroundColor: 'var(--color-info)',
                          color: 'white',
                          borderRadius: '4px',
                          fontSize: '11px'
                        }}>
                          📊 SALDO
                        </span>
                      ) : (
                        <span style={{
                          padding: '4px 8px',
                          backgroundColor: 'var(--color-warning)',
                          color: 'white',
                          borderRadius: '4px',
                          fontSize: '11px'
                        }}>
                          📜 DEUDA
                        </span>
                      )}
                    </td>
                  )}
                  <td style={{
                    padding: '12px',
                    textAlign: 'right',
                    fontWeight: '600',
                    color: 'var(--color-success)'
                  }}>
                    ${payment.payment_amount.toFixed(2)}
                  </td>
                  <td style={{ padding: '12px' }}>
                    <span style={{
                      padding: '2px 8px',
                      backgroundColor: 'var(--color-primary-light)',
                      borderRadius: '4px',
                      fontSize: '12px'
                    }}>
                      {payment.payment_method}
                    </span>
                  </td>
                  <td style={{ padding: '12px', fontSize: '13px', fontFamily: 'monospace' }}>
                    {payment.payment_reference || <span style={{ opacity: 0.5 }}>—</span>}
                  </td>
                  <td style={{ padding: '12px' }}>
                    {isDebtPayment && breakdown.length > 0 ? (
                      <div style={{ fontSize: '12px' }}>
                        {breakdown.map((item, i) => (
                          <div key={i} style={{
                            marginBottom: '4px',
                            padding: '4px 8px',
                            backgroundColor: 'var(--color-surface-tertiary)',
                            borderRadius: '4px'
                          }}>
                            <strong>Item #{item.debt_item_id}:</strong> ${item.amount_applied.toFixed(2)}
                            {item.liquidated && (
                              <span style={{ marginLeft: '8px', color: 'var(--color-success)' }}>
                                ✅ Liquidado
                              </span>
                            )}
                          </div>
                        ))}
                      </div>
                    ) : (
                      <span style={{ opacity: 0.5, fontSize: '12px' }}>
                        {isDebtPayment ? 'Sin desglose' : 'N/A'}
                      </span>
                    )}
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    </>
  );
};

export default DesgloseDeuda;
