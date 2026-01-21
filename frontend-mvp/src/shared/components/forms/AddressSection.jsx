import React, { useState, useEffect } from 'react';
import { Card, CardHeader, CardTitle, CardContent } from '../ui/card';
import { Input } from '../ui/input';
import { Label } from '../ui/label';
import { lookupZipCode } from '../../api/services/zipCodeService';

/**
 * Componente reutilizable para dirección
 * Incluye integración con CopomexAPI para auto-completar datos por CP
 */
export const AddressSection = ({
  formData,
  onChange,
  required = false,
  collapsible = false
}) => {
  const [zipLoading, setZipLoading] = useState(false);
  const [colonies, setColonies] = useState([]);
  const [zipError, setZipError] = useState('');
  const [isExpanded, setIsExpanded] = useState(!collapsible || required);

  // Handler para expandir/contraer
  const handleToggleExpand = (e) => {
    e.preventDefault();
    e.stopPropagation();
    setIsExpanded(!isExpanded);
  };

  // Buscar información del CP cuando se completan 5 dígitos
  useEffect(() => {
    const handleZipLookup = async () => {
      const zipCode = formData.zip_code;

      if (!zipCode || zipCode.length !== 5) {
        setColonies([]);
        setZipError('');
        return;
      }

      setZipLoading(true);
      setZipError('');

      try {
        const result = await lookupZipCode(zipCode);

        if (result && result.error) {
          // Manejar errores de la API
          setZipError(result.message || 'Error al buscar código postal');
          setColonies([]);
        } else if (result && result.success) {
          // Auto-completar municipio y estado
          onChange({
            municipality: result.municipality,
            state: result.state
          });

          // Las colonias ya vienen en el resultado
          setColonies(result.colonies || []);

          // Si solo hay una colonia, auto-seleccionarla
          if (result.colonies && result.colonies.length === 1) {
            onChange({ colony: result.colonies[0] });
          }
        } else {
          setZipError('Código postal no encontrado');
          setColonies([]);
        }
      } catch (error) {
        console.error('Error al buscar CP:', error);
        setZipError(`Error al buscar código postal: ${error.message}`);
        setColonies([]);
      } finally {
        setZipLoading(false);
      }
    };

    handleZipLookup();
  }, [formData.zip_code]);

  if (collapsible && !isExpanded) {
    return (
      <Card>
        <CardHeader>
          <button
            type="button"
            onClick={handleToggleExpand}
            className="w-full text-left cursor-pointer hover:bg-gray-50 dark:hover:bg-gray-900 -m-4 p-4 rounded-lg"
          >
            <CardTitle className="text-sm font-normal text-gray-600 dark:text-gray-400 flex items-center gap-2">
              <span className="text-lg">📍</span>
              + Agregar Dirección {!required && '(opcional)'}
            </CardTitle>
          </button>
        </CardHeader>
      </Card>
    );
  }

  return (
    <Card>
      <CardHeader>
        <div className="flex items-center justify-between">
          <CardTitle className="flex items-center gap-2">
            <span>📍</span>
            Dirección {!required && '(opcional)'}
          </CardTitle>
          {collapsible && !required && (
            <button
              type="button"
              onClick={handleToggleExpand}
              className="text-sm text-gray-500 hover:text-gray-700 dark:text-gray-400 dark:hover:text-gray-200 px-2 py-1 rounded hover:bg-gray-100 dark:hover:bg-gray-700"
            >
              ✕ Contraer
            </button>
          )}
        </div>
      </CardHeader>

      <CardContent className="space-y-4">
        {/* Código Postal */}
        <div className="space-y-2">
          <Label htmlFor="zip_code">Código Postal {required && '*'}</Label>
          <div className="relative">
            <Input
              id="zip_code"
              value={formData.zip_code || ''}
              onChange={(e) => onChange({ zip_code: e.target.value })}
              placeholder="12345"
              maxLength={5}
              required={required}
            />
            {zipLoading && (
              <div className="absolute right-3 top-2.5">
                <span className="text-gray-400">⏳</span>
              </div>
            )}
          </div>
          {zipError && (
            <p className="text-sm text-red-600">{zipError}</p>
          )}
        </div>

        {/* Colonia */}
        {colonies.length > 0 && (
          <div className="space-y-2">
            <Label htmlFor="colony">Colonia {required && '*'}</Label>
            <select
              id="colony"
              value={formData.colony || ''}
              onChange={(e) => onChange({ colony: e.target.value })}
              className="w-full rounded-md border border-gray-300 bg-white px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
            >
              <option value="">Seleccionar colonia...</option>
              {colonies.map((colony, index) => (
                <option key={index} value={colony}>
                  {colony}
                </option>
              ))}
            </select>
          </div>
        )}

        {/* Municipio y Estado (auto-completados) */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div className="space-y-2">
            <Label htmlFor="municipality">Municipio {required && '*'}</Label>
            <Input
              id="municipality"
              value={formData.municipality || ''}
              onChange={(e) => onChange({ municipality: e.target.value })}
              placeholder="Se completa automáticamente"
              disabled={zipLoading}
              required={required}
            />
          </div>

          <div className="space-y-2">
            <Label htmlFor="state">Estado {required && '*'}</Label>
            <Input
              id="state"
              value={formData.state || ''}
              onChange={(e) => onChange({ state: e.target.value })}
              placeholder="Se completa automáticamente"
              disabled={zipLoading}
              required={required}
            />
          </div>
        </div>

        {/* Calle y números */}
        <div className="space-y-2">
          <Label htmlFor="street">Calle {required && '*'}</Label>
          <Input
            id="street"
            value={formData.street || ''}
            onChange={(e) => onChange({ street: e.target.value })}
            placeholder="Av. Insurgentes"
            required={required}
          />
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div className="space-y-2">
            <Label htmlFor="external_number">Número Exterior {required && '*'}</Label>
            <Input
              id="external_number"
              value={formData.external_number || ''}
              onChange={(e) => onChange({ external_number: e.target.value })}
              placeholder="123"
              required={required}
            />
          </div>

          <div className="space-y-2">
            <Label htmlFor="internal_number">Número Interior</Label>
            <Input
              id="internal_number"
              value={formData.internal_number || ''}
              onChange={(e) => onChange({ internal_number: e.target.value })}
              placeholder="A (opcional)"
            />
          </div>
        </div>
      </CardContent>
    </Card>
  );
};

export default AddressSection;
