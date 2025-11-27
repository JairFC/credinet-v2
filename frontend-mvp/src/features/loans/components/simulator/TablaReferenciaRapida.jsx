/**
 * TablaReferenciaRapida
 * Muestra tabla de valores precalculados para consulta rápida
 */
import { useState, useEffect } from 'react';
import { simulatorService } from '../../services/simulatorService';
import './TablaReferenciaRapida.css';

const PROFILES = [
  { code: 'legacy', name: 'Legacy (Variable) ℹ️' },
  { code: 'transition', name: 'Transition (3.75%)' },
  { code: 'standard', name: 'Standard (4.25%)' },
  { code: 'premium', name: 'Premium (4.5%)' },
];

export default function TablaReferenciaRapida() {
  const [profileCode, setProfileCode] = useState('standard');
  const [referenceData, setReferenceData] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  useEffect(() => {
    loadReferenceTable();
  }, [profileCode]);

  const loadReferenceTable = async () => {
    try {
      setLoading(true);
      setError(null);

      const data = await simulatorService.getReferenceTable(profileCode);
      setReferenceData(data);
    } catch (err) {
      setError('Error al cargar tabla de referencia');
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  const formatCurrency = (value) => {
    return new Intl.NumberFormat('es-MX', {
      style: 'currency',
      currency: 'MXN',
      minimumFractionDigits: 0,
      maximumFractionDigits: 0,
    }).format(value);
  };

  if (loading) {
    return (
      <div className="tabla-referencia-loading">
        <p>⏳ Cargando tabla de referencia...</p>
      </div>
    );
  }

  if (error) {
    return (
      <div className="tabla-referencia-error">
        <p>❌ {error}</p>
        <button onClick={loadReferenceTable} className="btn-retry">
          🔄 Reintentar
        </button>
      </div>
    );
  }

  if (!referenceData || referenceData.reference_table.length === 0) {
    return (
      <div className="tabla-referencia-empty">
        <p>📋 No hay datos de referencia disponibles</p>
      </div>
    );
  }

  // Agrupar por plazo
  const groupedByTerm = referenceData.reference_table.reduce((acc, row) => {
    if (!acc[row.term_biweeks]) {
      acc[row.term_biweeks] = [];
    }
    acc[row.term_biweeks].push(row);
    return acc;
  }, {});

  const terms = Object.keys(groupedByTerm).sort((a, b) => Number(a) - Number(b));

  return (
    <div className="tabla-referencia-rapida">
      <div className="referencia-header">
        <h3>📚 Tabla de Referencia Rápida</h3>

        <div className="profile-selector">
          <label htmlFor="profile-select">Perfil:</label>
          <select
            id="profile-select"
            value={profileCode}
            onChange={(e) => setProfileCode(e.target.value)}
          >
            {PROFILES.map(profile => (
              <option key={profile.code} value={profile.code}>
                {profile.name}
              </option>
            ))}
          </select>
        </div>
      </div>

      <div className="profile-info">
        <p>
          <strong>{referenceData.profile_name}</strong>
          {referenceData.interest_rate_percent && (
            <> - Tasa: {referenceData.interest_rate_percent}%</>
          )}
          {referenceData.commission_rate_percent && (
            <> - Comisión: {referenceData.commission_rate_percent}%</>
          )}
        </p>
      </div>

      {/* Tabla por cada plazo */}
      {terms.map(term => (
        <div key={term} className="term-section">
          <h4>Plazo: {term} quincenas ({(Number(term) / 2).toFixed(1)} meses)</h4>

          <div className="table-container">
            <table className="reference-table">
              <thead>
                <tr>
                  <th>Monto</th>
                  <th className="currency">Pago Cliente</th>
                  <th className="currency">Pago Asociado</th>
                  <th className="currency">Comisión</th>
                  <th className="currency">Total Cliente</th>
                </tr>
              </thead>
              <tbody>
                {groupedByTerm[term].map((row, index) => (
                  <tr key={index}>
                    <td className="amount">{formatCurrency(row.amount)}</td>
                    <td className="currency client-value">
                      {formatCurrency(row.biweekly_payment)}
                    </td>
                    <td className="currency associate-value">
                      {formatCurrency(row.associate_payment)}
                    </td>
                    <td className="currency commission-value">
                      {formatCurrency(row.commission_per_payment)}
                    </td>
                    <td className="currency total-value">
                      {formatCurrency(row.total_payment)}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      ))}

      <div className="referencia-footer">
        <p>💡 <em>Estos valores son referenciales y están precalculados en el sistema.</em></p>
      </div>
    </div>
  );
}
