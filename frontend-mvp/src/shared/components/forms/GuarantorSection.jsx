import React, { useState, useEffect } from 'react';
import { Card, CardHeader, CardTitle, CardContent } from '../ui/card';
import { Input } from '../ui/input';
import { Label } from '../ui/label';
import { generateCURP } from '../../utils/curpGenerator';

/**
 * Componente reutilizable para datos del aval/garante
 * Sección opcional y colapsable
 * Calcula CURP automáticamente basado en nombre, apellidos, fecha de nacimiento, género y estado
 */
export const GuarantorSection = ({
  formData,
  onChange,
  collapsible = true
}) => {
  const [isExpanded, setIsExpanded] = useState(false);

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

  // Calcular CURP automáticamente cuando cambien los datos necesarios
  useEffect(() => {
    if (
      formData.guarantor_first_name &&
      formData.guarantor_paternal_last_name &&
      formData.guarantor_maternal_last_name &&
      formData.guarantor_birth_date &&
      formData.guarantor_gender &&
      formData.guarantor_birth_state
    ) {
      const curp = generateCURP({
        firstName: formData.guarantor_first_name,
        paternalLastName: formData.guarantor_paternal_last_name,
        maternalLastName: formData.guarantor_maternal_last_name,
        birthDate: formData.guarantor_birth_date,
        gender: formData.guarantor_gender,
        birthState: formData.guarantor_birth_state
      });

      if (curp && curp !== formData.guarantor_curp) {
        onChange({ guarantor_curp: curp });
      }
    }
  }, [
    formData.guarantor_first_name,
    formData.guarantor_paternal_last_name,
    formData.guarantor_maternal_last_name,
    formData.guarantor_birth_date,
    formData.guarantor_gender,
    formData.guarantor_birth_state
  ]);

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
              <span className="text-lg">🤝</span>
              + Agregar Aval/Garante (opcional)
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
            <span>🤝</span>
            Aval/Garante (opcional)
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
        {/* Nombres y apellidos */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div className="space-y-2">
            <Label htmlFor="guarantor_first_name">Nombre(s)</Label>
            <Input
              id="guarantor_first_name"
              name="guar_fname_new"
              value={formData.guarantor_first_name || ''}
              onChange={(e) => onChange({ guarantor_first_name: e.target.value })}
              placeholder="Juan"
              autoComplete="new-password"
            />
          </div>

          <div className="space-y-2">
            <Label htmlFor="guarantor_paternal_last_name">Apellido Paterno</Label>
            <Input
              id="guarantor_paternal_last_name"
              name="guar_plname_new"
              value={formData.guarantor_paternal_last_name || ''}
              onChange={(e) => onChange({ guarantor_paternal_last_name: e.target.value })}
              placeholder="Pérez"
              autoComplete="new-password"
            />
          </div>

          <div className="space-y-2">
            <Label htmlFor="guarantor_maternal_last_name">Apellido Materno</Label>
            <Input
              id="guarantor_maternal_last_name"
              name="guar_mlname_new"
              value={formData.guarantor_maternal_last_name || ''}
              onChange={(e) => onChange({ guarantor_maternal_last_name: e.target.value })}
              placeholder="García"
              autoComplete="new-password"
            />
          </div>
        </div>

        {/* Fecha de nacimiento, género y estado */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div className="space-y-2">
            <Label htmlFor="guarantor_birth_date">Fecha de Nacimiento</Label>
            <Input
              id="guarantor_birth_date"
              type="date"
              value={formData.guarantor_birth_date || ''}
              onChange={(e) => onChange({ guarantor_birth_date: e.target.value })}
            />
          </div>

          <div className="space-y-2">
            <Label htmlFor="guarantor_gender">Género</Label>
            <select
              id="guarantor_gender"
              value={formData.guarantor_gender || ''}
              onChange={(e) => onChange({ guarantor_gender: e.target.value })}
              className="w-full rounded-md border border-gray-300 bg-white px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500 dark:border-gray-600 dark:bg-gray-800 dark:text-gray-100"
            >
              <option value="">Seleccionar...</option>
              <option value="M">Masculino</option>
              <option value="F">Femenino</option>
            </select>
          </div>

          <div className="space-y-2">
            <Label htmlFor="guarantor_birth_state">Estado de Nacimiento</Label>
            <select
              id="guarantor_birth_state"
              value={formData.guarantor_birth_state || ''}
              onChange={(e) => onChange({ guarantor_birth_state: e.target.value })}
              className="w-full rounded-md border border-gray-300 bg-white px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500 dark:border-gray-600 dark:bg-gray-800 dark:text-gray-100"
            >
              <option value="">Seleccionar...</option>
              <option value="AS">Aguascalientes</option>
              <option value="BC">Baja California</option>
              <option value="BS">Baja California Sur</option>
              <option value="CC">Campeche</option>
              <option value="CS">Chiapas</option>
              <option value="CH">Chihuahua</option>
              <option value="CL">Coahuila</option>
              <option value="CM">Colima</option>
              <option value="DF">Ciudad de México</option>
              <option value="DG">Durango</option>
              <option value="GT">Guanajuato</option>
              <option value="GR">Guerrero</option>
              <option value="HG">Hidalgo</option>
              <option value="JC">Jalisco</option>
              <option value="MC">México</option>
              <option value="MN">Michoacán</option>
              <option value="MS">Morelos</option>
              <option value="NT">Nayarit</option>
              <option value="NL">Nuevo León</option>
              <option value="OC">Oaxaca</option>
              <option value="PL">Puebla</option>
              <option value="QT">Querétaro</option>
              <option value="QR">Quintana Roo</option>
              <option value="SP">San Luis Potosí</option>
              <option value="SL">Sinaloa</option>
              <option value="SR">Sonora</option>
              <option value="TC">Tabasco</option>
              <option value="TS">Tamaulipas</option>
              <option value="TL">Tlaxcala</option>
              <option value="VZ">Veracruz</option>
              <option value="YN">Yucatán</option>
              <option value="ZS">Zacatecas</option>
              <option value="NE">Nacido en el Extranjero</option>
            </select>
          </div>
        </div>

        {/* Relación */}
        <div className="space-y-2">
          <Label htmlFor="guarantor_relationship">Parentesco/Relación</Label>
          <select
            id="guarantor_relationship"
            value={formData.guarantor_relationship || ''}
            onChange={(e) => onChange({ guarantor_relationship: e.target.value })}
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
          <Label htmlFor="guarantor_phone">Teléfono</Label>
          <Input
            id="guarantor_phone"
            name="guar_phone_new"
            type="tel"
            value={formData.guarantor_phone || ''}
            onChange={(e) => onChange({ guarantor_phone: e.target.value })}
            placeholder="5512345678"
            maxLength={10}
            autoComplete="new-password"
          />
        </div>

        {/* CURP - calculado automáticamente */}
        <div className="space-y-2">
          <Label htmlFor="guarantor_curp">CURP</Label>
          <Input
            id="guarantor_curp"
            value={formData.guarantor_curp || ''}
            onChange={(e) => onChange({ guarantor_curp: e.target.value.toUpperCase() })}
            placeholder="Se calcula automáticamente"
            maxLength={18}
            className="bg-gray-50"
          />
          {formData.guarantor_curp && (
            <p className="text-xs text-green-600">
              ✓ CURP generado automáticamente
            </p>
          )}
        </div>

        <div className="bg-blue-50 dark:bg-blue-950 border border-blue-200 dark:border-blue-800 rounded-md p-3">
          <p className="text-sm text-blue-800 dark:text-blue-200">
            💡 El CURP se calcula automáticamente al ingresar nombre, apellidos, fecha de nacimiento, género y estado.
          </p>
        </div>

        <div className="bg-yellow-50 dark:bg-yellow-950 border border-yellow-200 dark:border-yellow-800 rounded-md p-3">
          <p className="text-sm text-yellow-800 dark:text-yellow-200">
            💡 El aval es opcional. Agrega esta información solo si es requerida.
          </p>
        </div>
      </CardContent>
    </Card>
  );
};

export default GuarantorSection;
