import React, { useState, useEffect } from 'react';
import { Card, CardHeader, CardTitle, CardContent } from '../ui/card';
import { Input } from '../ui/input';
import { Label } from '../ui/label';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '../ui/select';
import { lookupZipCode, getColonies } from '../../api/services/zipCodeService';

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
      <Card className="cursor-pointer hover:bg-gray-50 dark:hover:bg-gray-900" onClick={() => setIsExpanded(true)}>
        <CardHeader>
          <CardTitle className="text-sm font-normal text-gray-600 dark:text-gray-400">
            + Agregar Dirección {!required && '(opcional)'}
          </CardTitle>
        </CardHeader>
      </Card>
    );
  }

  return (
    <Card>
      <CardHeader>
        <div className="flex items-center justify-between">
          <CardTitle>
            Dirección {!required && '(opcional)'}
          </CardTitle>
          {collapsible && !required && (
            <button
              type="button"
              onClick={() => setIsExpanded(false)}
              className="text-sm text-gray-500 hover:text-gray-700"
            >
              Contraer
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
            <Select
              value={formData.colony || ''}
              onValueChange={(value) => onChange({ colony: value })}
            >
              <SelectTrigger id="colony">
                <SelectValue placeholder="Seleccionar colonia" />
              </SelectTrigger>
              <SelectContent className="max-h-[200px]">
                {colonies.map((colony, index) => (
                  <SelectItem key={index} value={colony}>
                    {colony}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
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
