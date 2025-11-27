/**
 * SimuladorPrestamosPage
 * Página principal del simulador de préstamos con tabs
 */
import { useState } from 'react';
import { useSimulator } from '../hooks/useSimulator';
import FormularioSimulador from '../components/simulator/FormularioSimulador';
import ResumenSimulacion from '../components/simulator/ResumenSimulacion';
import TablaAmortizacion from '../components/simulator/TablaAmortizacion';
import TablaReferenciaRapida from '../components/simulator/TablaReferenciaRapida';
import './SimuladorPrestamosPage.css';

export default function SimuladorPrestamosPage() {
  const [activeTab, setActiveTab] = useState('simulador');
  const { simulationResult, loading, error, simulate } = useSimulator();

  const handleSimulate = async (params) => {
    try {
      await simulate(params);
    } catch (err) {
      console.error('Error en simulación:', err);
    }
  };

  return (
    <div className="simulador-prestamos-page">
      <div className="page-header">
        <h1>🧮 Simulador de Préstamos</h1>
        <p className="page-description">
          Calcula pagos, comisiones y tabla de amortización con fechas reales
        </p>
      </div>

      {/* Tabs */}
      <div className="tabs-container">
        <button
          className={`tab ${activeTab === 'simulador' ? 'active' : ''}`}
          onClick={() => setActiveTab('simulador')}
        >
          🧮 Simulador
        </button>
        <button
          className={`tab ${activeTab === 'referencia' ? 'active' : ''}`}
          onClick={() => setActiveTab('referencia')}
        >
          📚 Tabla de Referencia
        </button>
      </div>

      {/* Contenido según tab activo */}
      <div className="tab-content">
        {activeTab === 'simulador' && (
          <div className="simulador-tab">
            {/* Formulario */}
            <FormularioSimulador onSimulate={handleSimulate} loading={loading} />

            {/* Error */}
            {error && (
              <div className="alert alert-error">
                ❌ {error}
              </div>
            )}

            {/* Resultados */}
            {simulationResult && (
              <>
                <ResumenSimulacion summary={simulationResult.summary} />
                <TablaAmortizacion payments={simulationResult.amortization_table} />
              </>
            )}

            {/* Estado vacío */}
            {!simulationResult && !loading && !error && (
              <div className="empty-state">
                <div className="empty-icon">📊</div>
                <h3>Configura tu simulación</h3>
                <p>Completa el formulario y presiona "Simular Préstamo" para ver los resultados</p>
              </div>
            )}
          </div>
        )}

        {activeTab === 'referencia' && (
          <div className="referencia-tab">
            <TablaReferenciaRapida />
          </div>
        )}
      </div>
    </div>
  );
}
