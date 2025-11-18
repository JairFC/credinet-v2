/**
 * useSimulator Hook
 * Manejo centralizado del estado y lógica del simulador de préstamos
 */
import { useState } from 'react';
import { simulatorService } from '../services/simulatorService';

export const useSimulator = () => {
  const [simulationResult, setSimulationResult] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  /**
   * Simular préstamo completo
   */
  const simulate = async (params) => {
    try {
      setLoading(true);
      setError(null);

      const result = await simulatorService.simulate(params);
      setSimulationResult(result);

      return result;
    } catch (err) {
      const errorMsg = err.response?.data?.detail || 'Error al simular préstamo';
      setError(errorMsg);
      throw err;
    } finally {
      setLoading(false);
    }
  };

  /**
   * Cálculo rápido sin amortización
   */
  const quickCalculate = async (params) => {
    try {
      setLoading(true);
      setError(null);

      const result = await simulatorService.quickCalculate(params);
      return result;
    } catch (err) {
      const errorMsg = err.response?.data?.detail || 'Error al calcular';
      setError(errorMsg);
      throw err;
    } finally {
      setLoading(false);
    }
  };

  /**
   * Resetear estado del simulador
   */
  const reset = () => {
    setSimulationResult(null);
    setError(null);
  };

  return {
    simulationResult,
    loading,
    error,
    simulate,
    quickCalculate,
    reset,
  };
};
