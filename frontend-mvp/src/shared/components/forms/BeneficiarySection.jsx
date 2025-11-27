import React, { useState, useEffect } from 'react';
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
  const [relationships, setRelationships] = useState([]);

  // Cargar catálogo de relaciones
  useEffect(() => {
    const loadRelationships = async () => {
      try {
        const response = await fetch(`${import.meta.env.VITE_API_URL}/api/v1/shared/relationships`);
        const data = await response.json();
        if (data.success) {
          setRelationships(data.data);
        }
      } catch (error) {
        console.error('Error cargando relaciones:', error);
      }
    };
    loadRelationships();
  }, []);

  if (collapsible && !isExpanded) {
    return (
      <Card className="cursor-pointer hover:bg-gray-50 dark:hover:bg-gray-900" onClick={() => setIsExpanded(true)}>
        <CardHeader>
          <CardTitle className="text-sm font-normal text-gray-600 dark:text-gray-400">
            + Agregar Beneficiario (opcional)
          </CardTitle>
        </CardHeader>
      </Card>
    );
  }

  return (
    <Card>
      <CardHeader>
        <div className="flex items-center justify-between">
          <CardTitle>Beneficiario (opcional)</CardTitle>
          {collapsible && (
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
        {/* Nombre completo */}
        <div className="space-y-2">
          <Label htmlFor="beneficiary_full_name">Nombre Completo</Label>
          <Input
            id="beneficiary_full_name"
            value={formData.beneficiary_full_name || ''}
            onChange={(e) => onChange({ beneficiary_full_name: e.target.value })}
            placeholder="Nombre completo del beneficiario"
          />
        </div>

        {/* Relación */}
        <div className="space-y-2">
          <Label htmlFor="beneficiary_relationship">Parentesco/Relación</Label>
          <select
            id="beneficiary_relationship"
            value={formData.beneficiary_relationship || ''}
            onChange={(e) => onChange({ beneficiary_relationship: e.target.value })}
            className="w-full rounded-md border border-gray-300 bg-white px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
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
            type="tel"
            value={formData.beneficiary_phone || ''}
            onChange={(e) => onChange({ beneficiary_phone: e.target.value })}
            placeholder="5512345678"
            maxLength={10}
          />
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
