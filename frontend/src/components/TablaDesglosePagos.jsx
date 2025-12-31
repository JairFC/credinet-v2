import React, { useState, useEffect } from 'react';
import { API_BASE_URL } from '../config';

const TablaDesglosePagos = ({ statementId }) => {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    if (statementId) {
      fetchPayments();
    }
  }, [statementId]);

  const fetchPayments = async () => {
    try {
      setLoading(true);
      const token = localStorage.getItem('token');
      const response = await fetch(
        `${API_BASE_URL}/statements/${statementId}/payments`,
        {
          headers: { 'Authorization': `Bearer ${token}` }
        }
      );

      const result = await response.json();

      if (response.ok && result.success) {
        setData(result.data);
      } else {
        setError(result.detail || 'Error al cargar abonos');
      }
    } catch (err) {
      setError('Error de conexión: ' + err.message);
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return (
      <div style={{ padding: '20px', textAlign: 'center' }}>
        <div className="spinner">⏳ Cargando desglose...</div>
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

  if (!data || !data.payments || data.payments.length === 0) {
    return (
      <div className="alert alert-info" style={{ margin: '20px' }}>
        📋 No hay abonos registrados para este statement
      </div>
    );
  }

  const getStatusBadge = (status) => {
    const badges = {
      'PAID': { color: '#28a745', label: '✅ PAGADO' },
      'PARTIAL': { color: '#ffc107', label: '⚠️ PARCIAL' },
      'COLLECTING': { color: '#3B82F6', label: '💰 EN COBRO' },
      'DRAFT': { color: '#6c757d', label: '📝 BORRADOR' },
      'OVERDUE': { color: '#dc3545', label: '⚠️ VENCIDO' },
      'ABSORBED': { color: '#607D8B', label: '📦 ABSORBIDO' }
    };

    const badge = badges[status] || badges['COLLECTING'];

    return (
      <span style={{
        backgroundColor: badge.color,
        color: 'white',
        padding: '4px 8px',
        borderRadius: '4px',
        fontSize: '12px',
        fontWeight: '600'
      }}>
        {badge.label}
      </span>
    );
  };

  const progressPercent = (data.paid_amount / data.total_owed) * 100;

  return (
    <div style={{ padding: '20px' }}>
      {/* Resumen */}
      <div className="card" style={{
        padding: '16px',
        marginBottom: '20px',
        backgroundColor: 'var(--color-surface-secondary)',
        borderRadius: '8px'
      }}>
        <div style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(150px, 1fr))',
          gap: '16px',
          marginBottom: '12px'
        }}>
          <div>
            <div style={{ fontSize: '12px', opacity: 0.7 }}>Adeudado</div>
            <div style={{ fontSize: '20px', fontWeight: '600', color: 'var(--color-danger)' }}>
              ${data.total_owed.toFixed(2)}
            </div>
          </div>
          <div>
            <div style={{ fontSize: '12px', opacity: 0.7 }}>Pagado</div>
            <div style={{ fontSize: '20px', fontWeight: '600', color: 'var(--color-success)' }}>
              ${data.paid_amount.toFixed(2)}
            </div>
          </div>
          <div>
            <div style={{ fontSize: '12px', opacity: 0.7 }}>Restante</div>
            <div style={{ fontSize: '20px', fontWeight: '600', color: 'var(--color-warning)' }}>
              ${data.remaining.toFixed(2)}
            </div>
          </div>
          <div>
            <div style={{ fontSize: '12px', opacity: 0.7 }}>Estado</div>
            <div style={{ marginTop: '4px' }}>
              {getStatusBadge(data.status)}
            </div>
          </div>
        </div>

        {/* Barra de progreso */}
        <div style={{ marginTop: '12px' }}>
          <div style={{
            width: '100%',
            height: '8px',
            backgroundColor: 'var(--color-border)',
            borderRadius: '4px',
            overflow: 'hidden'
          }}>
            <div style={{
              width: `${Math.min(progressPercent, 100)}%`,
              height: '100%',
              backgroundColor: progressPercent >= 100 ? 'var(--color-success)' : 'var(--color-primary)',
              transition: 'width 0.3s ease'
            }} />
          </div>
          <div style={{ fontSize: '12px', marginTop: '4px', textAlign: 'right', opacity: 0.7 }}>
            {progressPercent.toFixed(1)}% pagado
          </div>
        </div>
      </div>

      {/* Tabla de Abonos */}
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
              <th style={{ padding: '12px', textAlign: 'right' }}>Monto</th>
              <th style={{ padding: '12px', textAlign: 'left' }}>Método</th>
              <th style={{ padding: '12px', textAlign: 'left' }}>Referencia</th>
              <th style={{ padding: '12px', textAlign: 'left' }}>Registrado por</th>
              <th style={{ padding: '12px', textAlign: 'left' }}>Notas</th>
            </tr>
          </thead>
          <tbody>
            {data.payments.map((payment, index) => (
              <tr
                key={payment.id}
                style={{
                  borderBottom: '1px solid var(--color-border)',
                  backgroundColor: index % 2 === 0 ? 'transparent' : 'var(--color-surface-secondary)'
                }}
              >
                <td style={{ padding: '12px' }}>
                  {new Date(payment.payment_date).toLocaleDateString('es-MX')}
                </td>
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
                <td style={{ padding: '12px', fontSize: '13px' }}>
                  {payment.registered_by}
                </td>
                <td style={{ padding: '12px', fontSize: '12px', opacity: 0.8 }}>
                  {payment.notes || <span style={{ opacity: 0.5 }}>—</span>}
                </td>
              </tr>
            ))}
          </tbody>
          <tfoot>
            <tr style={{
              backgroundColor: 'var(--color-surface-secondary)',
              fontWeight: '600',
              borderTop: '2px solid var(--color-border)'
            }}>
              <td style={{ padding: '12px' }}>TOTAL</td>
              <td style={{
                padding: '12px',
                textAlign: 'right',
                color: 'var(--color-success)',
                fontSize: '16px'
              }}>
                ${data.paid_amount.toFixed(2)}
              </td>
              <td colSpan="4" style={{ padding: '12px', textAlign: 'right', opacity: 0.7 }}>
                {data.payments.length} abono{data.payments.length !== 1 ? 's' : ''} registrado{data.payments.length !== 1 ? 's' : ''}
              </td>
            </tr>
          </tfoot>
        </table>
      </div>
    </div>
  );
};

export default TablaDesglosePagos;
