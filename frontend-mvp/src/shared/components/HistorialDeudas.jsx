import React, { useState, useEffect } from 'react';
import { apiClient } from '../api/apiClient';
import ENDPOINTS from '../api/endpoints';
import { formatDateOnly } from '../utils/dateUtils';

/**
 * HistorialDeudas - Muestra el historial de deudas acumuladas de un asociado
 * 
 * Incluye:
 * - Total de deuda pendiente
 * - Lista de deudas por período
 * - Detalles expandibles de cada deuda (statement origen, montos)
 */
const HistorialDeudas = ({ associateId }) => {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [expandedPeriod, setExpandedPeriod] = useState(null);

  useEffect(() => {
    if (associateId) {
      fetchDebtHistory();
    }
  }, [associateId]);

  const fetchDebtHistory = async () => {
    try {
      setLoading(true);
      const response = await apiClient.get(ENDPOINTS.associates.debtHistory(associateId));

      if (response.data.success) {
        setData(response.data.data);
      } else {
        setError(response.data.detail || 'Error al cargar historial de deudas');
      }
    } catch (err) {
      // Si es 404 (no hay deudas), no es error
      if (err.response?.status === 404) {
        setData({ total_debt: 0, debt_history: [] });
      } else {
        setError('Error de conexión: ' + (err.response?.data?.detail || err.message));
      }
    } finally {
      setLoading(false);
    }
  };

  const formatCurrency = (amount) => {
    return new Intl.NumberFormat('es-MX', {
      style: 'currency',
      currency: 'MXN'
    }).format(amount);
  };

  const formatDate = (dateStr) => {
    if (!dateStr) return '—';
    // Usar formatDateOnly para evitar offset de timezone
    return formatDateOnly(dateStr, { monthFormat: 'short' });
  };

  if (loading) {
    return (
      <div style={{ padding: '20px', textAlign: 'center' }}>
        <div className="spinner">⏳ Cargando historial de deudas...</div>
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

  if (!data || !data.debt_history || data.debt_history.length === 0) {
    return (
      <div className="alert alert-success" style={{ margin: '20px' }}>
        ✅ Este asociado no tiene deudas acumuladas pendientes.
      </div>
    );
  }

  return (
    <div style={{ padding: '16px' }}>
      {/* Resumen Total */}
      <div className="card" style={{
        padding: '20px',
        marginBottom: '20px',
        background: data.total_debt > 0
          ? 'linear-gradient(135deg, #dc3545 0%, #c82333 100%)'
          : 'linear-gradient(135deg, #28a745 0%, #218838 100%)',
        color: 'white',
        borderRadius: '12px'
      }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <div>
            <div style={{ fontSize: '14px', opacity: 0.9, marginBottom: '4px' }}>
              💰 Deuda Total Acumulada
            </div>
            <div style={{ fontSize: '32px', fontWeight: '700' }}>
              {formatCurrency(data.total_debt)}
            </div>
            <div style={{ fontSize: '12px', opacity: 0.8, marginTop: '4px' }}>
              {data.periods_with_debt} período{data.periods_with_debt !== 1 ? 's' : ''} con deuda
            </div>
          </div>
          <div style={{
            fontSize: '48px',
            opacity: 0.3
          }}>
            {data.total_debt > 0 ? '⚠️' : '✅'}
          </div>
        </div>
      </div>

      {/* Lista de Deudas por Período */}
      <div style={{ marginBottom: '12px' }}>
        <h4 style={{ margin: '0 0 16px 0', fontSize: '16px' }}>
          📋 Desglose por Período
        </h4>
      </div>

      {data.debt_history.map((debt) => (
        <div
          key={debt.id}
          className="card"
          style={{
            marginBottom: '12px',
            overflow: 'hidden',
            border: expandedPeriod === debt.id ? '2px solid var(--color-primary)' : '1px solid var(--color-border)'
          }}
        >
          {/* Header del período */}
          <div
            onClick={() => setExpandedPeriod(expandedPeriod === debt.id ? null : debt.id)}
            style={{
              padding: '16px',
              cursor: 'pointer',
              display: 'flex',
              justifyContent: 'space-between',
              alignItems: 'center',
              backgroundColor: 'var(--color-surface-secondary)',
              borderBottom: expandedPeriod === debt.id ? '1px solid var(--color-border)' : 'none'
            }}
          >
            <div>
              <div style={{ fontWeight: '600', fontSize: '15px' }}>
                📆 Período {debt.period_code}
              </div>
              <div style={{ fontSize: '12px', opacity: 0.7, marginTop: '4px' }}>
                {formatDate(debt.period_start)} - {formatDate(debt.period_end)}
              </div>
            </div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '16px' }}>
              <div style={{
                textAlign: 'right',
                color: 'var(--color-danger)',
                fontWeight: '700',
                fontSize: '18px'
              }}>
                {formatCurrency(debt.accumulated_debt)}
              </div>
              <span style={{
                fontSize: '20px',
                transition: 'transform 0.2s',
                transform: expandedPeriod === debt.id ? 'rotate(180deg)' : 'none'
              }}>
                ▼
              </span>
            </div>
          </div>

          {/* Detalles expandidos */}
          {expandedPeriod === debt.id && debt.details && debt.details.length > 0 && (
            <div style={{ padding: '16px' }}>
              <table style={{
                width: '100%',
                borderCollapse: 'collapse',
                fontSize: '13px'
              }}>
                <thead>
                  <tr style={{
                    backgroundColor: 'var(--color-surface-tertiary)',
                    textAlign: 'left'
                  }}>
                    <th style={{ padding: '10px', borderBottom: '1px solid var(--color-border)' }}>
                      Statement
                    </th>
                    <th style={{ padding: '10px', borderBottom: '1px solid var(--color-border)', textAlign: 'right' }}>
                      Monto Original
                    </th>
                    <th style={{ padding: '10px', borderBottom: '1px solid var(--color-border)', textAlign: 'right' }}>
                      Mora
                    </th>
                    <th style={{ padding: '10px', borderBottom: '1px solid var(--color-border)', textAlign: 'right' }}>
                      Pagado
                    </th>
                    <th style={{ padding: '10px', borderBottom: '1px solid var(--color-border)', textAlign: 'right' }}>
                      Deuda
                    </th>
                    <th style={{ padding: '10px', borderBottom: '1px solid var(--color-border)' }}>
                      Fecha Absorción
                    </th>
                  </tr>
                </thead>
                <tbody>
                  {debt.details.map((detail, idx) => (
                    <tr
                      key={idx}
                      style={{
                        backgroundColor: idx % 2 === 0 ? 'transparent' : 'var(--color-surface-secondary)'
                      }}
                    >
                      <td style={{ padding: '10px', borderBottom: '1px solid var(--color-border)' }}>
                        <span style={{
                          fontFamily: 'monospace',
                          fontSize: '12px',
                          backgroundColor: 'var(--color-primary-light)',
                          padding: '2px 6px',
                          borderRadius: '4px'
                        }}>
                          {detail.statement_number}
                        </span>
                      </td>
                      <td style={{
                        padding: '10px',
                        borderBottom: '1px solid var(--color-border)',
                        textAlign: 'right'
                      }}>
                        {formatCurrency(detail.original_amount)}
                      </td>
                      <td style={{
                        padding: '10px',
                        borderBottom: '1px solid var(--color-border)',
                        textAlign: 'right',
                        color: detail.late_fee > 0 ? 'var(--color-warning)' : 'inherit'
                      }}>
                        {detail.late_fee > 0 ? formatCurrency(detail.late_fee) : '—'}
                      </td>
                      <td style={{
                        padding: '10px',
                        borderBottom: '1px solid var(--color-border)',
                        textAlign: 'right',
                        color: 'var(--color-success)'
                      }}>
                        {formatCurrency(detail.paid_amount)}
                      </td>
                      <td style={{
                        padding: '10px',
                        borderBottom: '1px solid var(--color-border)',
                        textAlign: 'right',
                        fontWeight: '600',
                        color: 'var(--color-danger)'
                      }}>
                        {formatCurrency(detail.debt_amount)}
                      </td>
                      <td style={{
                        padding: '10px',
                        borderBottom: '1px solid var(--color-border)',
                        fontSize: '12px',
                        opacity: 0.8
                      }}>
                        {formatDate(detail.absorbed_date)}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}

          {/* Si no hay detalles */}
          {expandedPeriod === debt.id && (!debt.details || debt.details.length === 0) && (
            <div style={{
              padding: '20px',
              textAlign: 'center',
              opacity: 0.7
            }}>
              Sin detalles disponibles
            </div>
          )}
        </div>
      ))}
    </div>
  );
};

export default HistorialDeudas;
