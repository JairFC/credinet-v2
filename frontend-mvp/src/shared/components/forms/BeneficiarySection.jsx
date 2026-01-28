import React, { useState } from 'react';
import { Card, CardHeader, CardTitle, CardContent } from '../ui/card';
import { Input } from '../ui/input';
import { Label } from '../ui/label';

/**
 * Componente reutilizable para datos del beneficiario
 * Sección opcional y colapsable
 */
export const BeneficiarySection = ({
  formData,
  onChange,
  collapsible = true
}) => {
  const [isExpanded, setIsExpanded] = useState(false);
  const [phoneError, setPhoneError] = useState('');

  // Validación de teléfono mexicano (10 dígitos)
  const validatePhone = (phone) => {
    if (!phone) return ''; // Opcional
    const digitsOnly = phone.replace(/\D/g, '');
    if (digitsOnly.length > 0 && digitsOnly.length < 10) {
      return 'El teléfono debe tener 10 dígitos';
    }
    if (digitsOnly.length === 10 && !/^[1-9]\d{9}$/.test(digitsOnly)) {
      return 'Formato de teléfono inválido';
    }
    return '';
  };

  const handlePhoneChange = (e) => {
    const value = e.target.value.replace(/\D/g, ''); // Solo dígitos
    if (value.length <= 10) {
      onChange({ beneficiary_phone: value });
      setPhoneError(validatePhone(value));
    }
  };

  // Relaciones por defecto (el endpoint del backend no existe aún)
  const relationships = [
    { id: 1, name: 'Padre' },
    { id: 2, name: 'Madre' },
    { id: 3, name: 'Hermano/a' },
    { id: 4, name: 'Esposo/a' },
    { id: 5, name: 'Hijo/a' },
    { id: 6, name: 'Tío/a' },
    { id: 7, name: 'Primo/a' },
    { id: 8, name: 'Abuelo/a' },
    { id: 9, name: 'Suegro/a' },
    { id: 10, name: 'Cuñado/a' },
    { id: 11, name: 'Amigo/a' },
    { id: 12, name: 'Conocido/a' },
    { id: 13, name: 'Otro' }
  ];

  // Handler para expandir/contraer
  const handleToggleExpand = (e) => {
    e.preventDefault();
    e.stopPropagation();
    setIsExpanded(!isExpanded);
  };

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
              <span className="text-lg">👤</span>
              + Agregar Beneficiario (opcional)
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
            <span>👤</span>
            Beneficiario (opcional)
          </CardTitle>
          {collapsible && (
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
        {/* Nombre completo */}
        <div className="space-y-2">
          <Label htmlFor="beneficiary_full_name">Nombre Completo</Label>
          <Input
            id="beneficiary_full_name"
            name="benef_name_new"
            value={formData.beneficiary_full_name || ''}
            onChange={(e) => onChange({ beneficiary_full_name: e.target.value })}
            placeholder="Nombre completo del beneficiario"
            autoComplete="new-password"
          />
        </div>

        {/* Relación */}
        <div className="space-y-2">
          <Label htmlFor="beneficiary_relationship">Parentesco/Relación</Label>
          <select
            id="beneficiary_relationship"
            value={formData.beneficiary_relationship || ''}
            onChange={(e) => onChange({ beneficiary_relationship: e.target.value })}
            className="w-full rounded-md border border-gray-300 bg-white px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500 dark:border-gray-600 dark:bg-gray-800 dark:text-gray-100"
          >
            <option value="">Seleccionar...</option>
            {relationships.map((rel) => (
              <option key={rel.id} value={rel.name}>
                {rel.name}
              </option>
            ))}
          </select>
        </div>

        {/* Teléfono */}
        <div className="space-y-2">
          <Label htmlFor="beneficiary_phone">Teléfono</Label>
          <Input
            id="beneficiary_phone"
            name="benef_phone_new"
            type="tel"
            value={formData.beneficiary_phone || ''}
            onChange={handlePhoneChange}
            placeholder="5512345678"
            maxLength={10}
            autoComplete="new-password"
            className={phoneError ? 'border-red-500 focus:border-red-500 focus:ring-red-500' : ''}
          />
          {phoneError && (
            <p className="text-sm text-red-600 dark:text-red-400">⚠️ {phoneError}</p>
          )}
          {formData.beneficiary_phone?.length === 10 && !phoneError && (
            <p className="text-sm text-green-600 dark:text-green-400">✓ Teléfono válido</p>
          )}
        </div>

        <div className="bg-blue-50 dark:bg-blue-950 border border-blue-200 dark:border-blue-800 rounded-md p-3">
          <p className="text-sm text-blue-800 dark:text-blue-200">
            ℹ️ El beneficiario recibirá derechos o prestaciones en caso de fallecimiento del titular.
          </p>
        </div>
      </CardContent>
    </Card>
  );
};

export default BeneficiarySection;
