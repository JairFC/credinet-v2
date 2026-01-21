import React, { useState, useEffect } from 'react';
import { Card, CardHeader, CardTitle, CardContent } from '../ui/card';
import { Input } from '../ui/input';
import { Label } from '../ui/label';

/**
 * Componente reutilizable para configuración de perfil de asociado
 * Incluye: Nivel, Línea de crédito, Tasa de comisión, Contacto
 */
export const AssociateProfileSection = ({
  formData,
  onChange,
  associateLevels = []
}) => {
  const [selectedLevel, setSelectedLevel] = useState(null);

  // Cargar niveles de asociado si no están disponibles
  useEffect(() => {
    if (associateLevels.length === 0) {
      // Por defecto, mostrar niveles estándar
      // En producción, estos deberían venir del backend
    }
  }, [associateLevels]);

  // Actualizar información del nivel seleccionado y crédito automáticamente
  useEffect(() => {
    if (formData.level_id && associateLevels.length > 0) {
      const level = associateLevels.find(l => l.id === parseInt(formData.level_id));
      setSelectedLevel(level);

      // SIEMPRE actualizar crédito cuando cambia el nivel
      if (level && level.credit_limit) {
        onChange({ credit_limit: level.credit_limit });
      }
    }
  }, [formData.level_id, associateLevels]);

  return (
    <Card>
      <CardHeader>
        <CardTitle>💰 Configuración de Asociado</CardTitle>
      </CardHeader>

      <CardContent className="space-y-4">
        {/* Nivel de Asociado */}
        <div className="space-y-2">
          <Label htmlFor="level_id">
            Nivel de Asociado <span className="text-red-500">*</span>
          </Label>
          <select
            id="level_id"
            value={formData.level_id || '1'}
            onChange={(e) => onChange({ level_id: e.target.value })}
            className="w-full rounded-md border border-gray-300 bg-white px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
          >
            <option value="">Seleccionar nivel...</option>
            {associateLevels.length > 0 ? (
              associateLevels.map((level) => (
                <option key={level.id} value={level.id}>
                  {level.name} - Crédito: ${level.credit_limit?.toLocaleString() || 'N/A'}
                </option>
              ))
            ) : (
              <>
                <option value="1">Bronce - Crédito: $25,000</option>
                <option value="2">Plata - Crédito: $300,000</option>
                <option value="3">Oro - Crédito: $600,000</option>
                <option value="4">Platino - Crédito: $900,000</option>
                <option value="5">Diamante - Crédito: $5,000,000</option>
              </>
            )}
          </select>
          {selectedLevel && (
            <div className="mt-2 p-3 bg-blue-50 dark:bg-blue-950 rounded-md border border-blue-200 dark:border-blue-800">
              <p className="text-sm font-medium text-blue-900 dark:text-blue-100">
                💳 Crédito asignado: ${selectedLevel.credit_limit?.toLocaleString('es-MX')}
              </p>
              <p className="text-xs text-blue-700 dark:text-blue-300 mt-1">
                Este monto se asigna automáticamente según el nivel seleccionado
              </p>
            </div>
          )}
        </div>

        {/* Nota informativa - la comisión se calcula automáticamente al crear préstamos */}
        <div className="bg-blue-50 dark:bg-blue-950 border border-blue-200 dark:border-blue-800 rounded-md p-3">
          <p className="text-sm text-blue-800 dark:text-blue-200">
            💡 El nivel determina el límite de crédito disponible. Este límite disminuye conforme se usa.
          </p>
        </div>
      </CardContent>
    </Card>
  );
};

export default AssociateProfileSection;
