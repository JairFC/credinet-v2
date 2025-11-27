import { useState, useEffect } from 'react';
import cutPeriodsService from '@/shared/api/services/cutPeriodsService';
import statementsService from '@/shared/api/services/statementsService';
import RegistrarPagoModal from '../components/RegistrarPagoModal';
import './EstadosCuentaPage.css';

export default function EstadosCuentaPage() {
  const [periods, setPeriods] = useState([]);
  const [currentPeriod, setCurrentPeriod] = useState(null);
  const [selectedPeriod, setSelectedPeriod] = useState(null);
  const [statements, setStatements] = useState([]);
  const [loading, setLoading] = useState(true);
  const [statementsLoading, setStatementsLoading] = useState(false);
  const [error, setError] = useState(null);

  // Modal state
  const [modalOpen, setModalOpen] = useState(false);
  const [selectedStatement, setSelectedStatement] = useState(null);
  const [modalTipo, setModalTipo] = useState('periodo');

  useEffect(() => {
    loadPeriods();
  }, []);

  useEffect(() => {
    if (selectedPeriod) {
      loadStatements(selectedPeriod.id);
    }
  }, [selectedPeriod]);

  const loadPeriods = async () => {
    try {
      setLoading(true);
      setError(null);

      const [allPeriods, current] = await Promise.all([
        cutPeriodsService.getAll(),
        cutPeriodsService.getCurrent()
      ]);

      setPeriods(allPeriods);
      setCurrentPeriod(current);

      // Seleccionar el período actual por defecto
      if (current) {
        setSelectedPeriod(current);
      }
    } catch (err) {
      setError('Error al cargar períodos: ' + err.message);
    } finally {
      setLoading(false);
    }
  };

  const loadStatements = async (periodId) => {
    try {
      setStatementsLoading(true);
      const data = await cutPeriodsService.getStatements(periodId);
      setStatements(data);
    } catch (err) {
      console.error('Error al cargar estados de cuenta:', err);
      setStatements([]);
    } finally {
      setStatementsLoading(false);
    }
  };

  const handlePeriodChange = (event) => {
    const periodId = parseInt(event.target.value);
    const period = periods.find(p => p.id === periodId);
    setSelectedPeriod(period);
  };

  const handleRegistrarPago = (statement) => {
    setSelectedStatement(statement);
    setModalTipo('periodo');
    setModalOpen(true);
  };

  const handlePaymentSuccess = async (paymentData) => {
    try {
      // Llamar al API para registrar el pago
      await statementsService.registerPayment(selectedStatement.id, paymentData);

      // Cerrar modal
      setModalOpen(false);

      // Recargar estados de cuenta
      if (selectedPeriod) {
        loadStatements(selectedPeriod.id);
      }
    } catch (err) {
      console.error('Error al registrar pago:', err);
      throw err; // Re-throw para que el modal muestre el error
    }
  };

  const formatDate = (dateStr) => {
    if (!dateStr) return '-';
    const date = new Date(dateStr + 'T12:00:00Z');
    return date.toLocaleDateString('es-MX', {
      day: '2-digit',
      month: 'short',
      year: 'numeric',
      timeZone: 'UTC'
    });
  };

  const formatMoney = (amount) => {
    if (amount == null) return '$0.00';
    return new Intl.NumberFormat('es-MX', {
      style: 'currency',
      currency: 'MXN'
    }).format(amount);
  };

  const getStatusBadge = (status) => {
    const badges = {
      1: { label: 'Abierto', className: 'status-open' },
      2: { label: 'Cerrado', className: 'status-closed' },
      3: { label: 'Pendiente', className: 'status-pending' }
    };
    const badge = badges[status] || { label: 'Desconocido', className: 'status-unknown' };
    return <span className={`status-badge ${badge.className}`}>{badge.label}</span>;
  };

  if (loading) {
    return (
      <div className="estados-cuenta-page">
        <div className="loading-container">
          <div className="spinner"></div>
          <p>Cargando períodos...</p>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="estados-cuenta-page">
        <div className="error-container">
          <p>{error}</p>
          <button onClick={loadPeriods} className="btn-retry">
            Reintentar
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="estados-cuenta-page">
      <div className="page-header">
        <h1>Estados de Cuenta</h1>
        <p className="page-subtitle">Consulta y gestión de estados de cuenta por período</p>
      </div>

      {/* Selector de período */}
      <div className="period-selector-card">
        <div className="period-selector-header">
          <label htmlFor="period-select">Período:</label>
          {currentPeriod && (
            <span className="current-period-indicator">
              Actual: {currentPeriod.cut_code}
            </span>
          )}
        </div>

        <select
          id="period-select"
          value={selectedPeriod?.id || ''}
          onChange={handlePeriodChange}
          className="period-select"
        >
          <option value="">Seleccionar período...</option>
          {periods.map(period => (
            <option key={period.id} value={period.id}>
              {period.cut_code} ({formatDate(period.period_start_date)} - {formatDate(period.period_end_date)})
            </option>
          ))}
        </select>

        {selectedPeriod && (
          <div className="period-info">
            <div className="info-row">
              <span className="info-label">Estado:</span>
              {getStatusBadge(selectedPeriod.status_id)}
            </div>
            <div className="info-row">
              <span className="info-label">Fecha de pago:</span>
              <span className="info-value">{formatDate(selectedPeriod.payment_date)}</span>
            </div>
            <div className="info-row">
              <span className="info-label">Fecha de corte:</span>
              <span className="info-value">{formatDate(selectedPeriod.cut_date)}</span>
            </div>
          </div>
        )}
      </div>

      {/* Tabla de estados de cuenta */}
      {selectedPeriod && (
        <div className="statements-section">
          <div className="section-header">
            <h2>Estados de Cuenta - {selectedPeriod.cut_code}</h2>
            <span className="statements-count">
              {statements.length} asociada{statements.length !== 1 ? 's' : ''}
            </span>
          </div>

          {statementsLoading ? (
            <div className="loading-container">
              <div className="spinner"></div>
              <p>Cargando estados de cuenta...</p>
            </div>
          ) : statements.length === 0 ? (
            <div className="empty-state">
              <p>No hay estados de cuenta para este período</p>
            </div>
          ) : (
            <div className="statements-table-container">
              <table className="statements-table">
                <thead>
                  <tr>
                    <th>Asociada</th>
                    <th className="text-right">Total Cobrado</th>
                    <th className="text-right">Comisión</th>
                    <th className="text-right">Pagado</th>
                    <th className="text-right">Pendiente</th>
                    <th className="text-right">Mora</th>
                    <th className="text-center">Acciones</th>
                  </tr>
                </thead>
                <tbody>
                  {statements.map(statement => {
                    const pending = statement.total_statement_amount - statement.paid_statement_amount;
                    return (
                      <tr key={statement.id}>
                        <td>
                          <div className="associate-cell">
                            <div className="associate-name">
                              {statement.associate_name || 'N/A'}
                            </div>
                            <div className="associate-id">
                              ID: {statement.associate_id}
                            </div>
                          </div>
                        </td>
                        <td className="text-right font-semibold">
                          {formatMoney(statement.total_collected_amount)}
                        </td>
                        <td className="text-right">
                          {formatMoney(statement.commission_amount)}
                        </td>
                        <td className="text-right text-success">
                          {formatMoney(statement.paid_statement_amount)}
                        </td>
                        <td className="text-right">
                          <span className={pending > 0 ? 'text-warning' : 'text-success'}>
                            {formatMoney(pending)}
                          </span>
                        </td>
                        <td className="text-right">
                          {statement.late_fee_amount > 0 ? (
                            <span className="text-danger">
                              {formatMoney(statement.late_fee_amount)}
                            </span>
                          ) : (
                            <span className="text-muted">-</span>
                          )}
                        </td>
                        <td className="text-center">
                          <button
                            onClick={() => handleRegistrarPago(statement)}
                            className="btn-action btn-pay"
                            disabled={pending <= 0}
                            title={pending <= 0 ? 'Sin saldo pendiente' : 'Registrar pago'}
                          >
                            💰 Pagar
                          </button>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          )}
        </div>
      )}

      {/* Modal de registro de pago */}
      <RegistrarPagoModal
        isOpen={modalOpen}
        onClose={() => setModalOpen(false)}
        tipo={modalTipo}
        statement={selectedStatement}
        associateId={selectedStatement?.associate_id}
        onSuccess={handlePaymentSuccess}
      />
    </div>
  );
}
