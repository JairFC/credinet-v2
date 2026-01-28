import React, { useEffect, useState } from 'react';
import { Card, CardHeader, CardTitle, CardContent } from '../ui/card';
import { Input } from '../ui/input';
import { Label } from '../ui/label';
import { Switch } from '../ui/switch';
import { generateUsername, generatePassword, generateTempEmail, generateCurp } from '../../utils/credentialsGenerator';
import { getStates } from '../../api/services/zipCodeService';
import { useFieldValidation } from '../../hooks/useFieldValidation';

/**
 * Componente reutilizable para datos personales y credenciales
 * Incluye generación automática de CURP, username, password y email
 */
export const PersonalDataSection = ({
  formData,
  onChange,
  showCredentials = true,
  autoGenerate = true,
  onAutoGenerateChange
}) => {
  const [curpDraft, setCurpDraft] = useState('');
  const [homoclave, setHomoclave] = useState('');
  const [usernameCounter, setUsernameCounter] = useState(1);

  // Validaciones en tiempo real
  const { validationStates, validateField } = useFieldValidation();

  const states = getStates();

  // Generar CURP en tiempo real conforme el usuario escribe
  useEffect(() => {
    if (!autoGenerate) return;

    const { first_name, paternal_last_name, maternal_last_name, birth_date, gender, birth_state } = formData;

    if (first_name && paternal_last_name && birth_date && gender && birth_state) {
      const generated = generateCurp({
        firstName: first_name,
        paternalLastName: paternal_last_name,
        maternalLastName: maternal_last_name || '',
        birthDate: birth_date,
        gender,
        birthState: birth_state
      });

      setCurpDraft(generated.slice(0, 16)); // Primeros 16 caracteres
      setHomoclave(generated.slice(16, 18)); // Últimos 2 (homoclave)

      // Auto-completar CURP completo
      onChange({ curp: generated });
    }
  }, [
    formData.first_name,
    formData.paternal_last_name,
    formData.maternal_last_name,
    formData.birth_date,
    formData.gender,
    formData.birth_state,
    autoGenerate
  ]);

  // Auto-generar credenciales cuando cambia el nombre
  useEffect(() => {
    if (!autoGenerate || !showCredentials) return;

    const { first_name, paternal_last_name, curp } = formData;

    if (first_name && paternal_last_name) {
      const username = generateUsername(first_name, paternal_last_name, usernameCounter);
      const password = generatePassword(curp); // Usa CURP como contraseña
      const email = formData.email || generateTempEmail(username);

      onChange({
        username,
        password,
        confirmPassword: password,
        email: formData.email || email // Solo si el usuario no ingresó email
      });
    }
  }, [formData.first_name, formData.paternal_last_name, formData.curp, usernameCounter, autoGenerate, showCredentials]);

  // Validar username cuando cambia
  useEffect(() => {
    if (formData.username && formData.username.trim()) {
      validateField('username', formData.username, 'username');
    }
  }, [formData.username, validateField]);

  // Validar email cuando cambia
  useEffect(() => {
    if (formData.email && formData.email.trim()) {
      validateField('email', formData.email, 'email');
    }
  }, [formData.email, validateField]);

  // Validar CURP cuando cambia
  useEffect(() => {
    if (formData.curp && formData.curp.length === 18) {
      validateField('curp', formData.curp, 'curp');
    }
  }, [formData.curp, validateField]);

  // Validar teléfono cuando cambia
  useEffect(() => {
    if (formData.phone_number && formData.phone_number.length === 10) {
      validateField('phone', formData.phone_number, 'phone');
    }
  }, [formData.phone_number, validateField]);

  // Manejar cambio manual de homoclave
  const handleHomoclaveChange = (value) => {
    setHomoclave(value);
    const fullCurp = curpDraft + value;
    if (fullCurp.length === 18) {
      onChange({ curp: fullCurp });
    }
  };

  // Incrementar contador si username está duplicado
  const handleUsernameConflict = () => {
    setUsernameCounter(prev => prev + 1);
  };

  return (
    <Card>
      <CardHeader>
        <div className="flex items-center justify-between">
          <CardTitle>Datos Personales</CardTitle>
          {onAutoGenerateChange && (
            <div className="flex items-center gap-2">
              <Label htmlFor="auto-generate" className="text-sm font-normal">
                Auto-generar credenciales
              </Label>
              <Switch
                id="auto-generate"
                checked={autoGenerate}
                onCheckedChange={onAutoGenerateChange}
              />
            </div>
          )}
        </div>
      </CardHeader>

      <CardContent className="space-y-4">
        {/* Nombre completo */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div className="space-y-2">
            <Label htmlFor="first_name">Nombre(s) *</Label>
            <Input
              id="first_name"
              value={formData.first_name || ''}
              onChange={(e) => onChange({ first_name: e.target.value })}
              placeholder="Juan"
              autoComplete="off"
              required
            />
          </div>

          <div className="space-y-2">
            <Label htmlFor="paternal_last_name">Apellido Paterno *</Label>
            <Input
              id="paternal_last_name"
              value={formData.paternal_last_name || ''}
              onChange={(e) => onChange({ paternal_last_name: e.target.value })}
              placeholder="Pérez"
              autoComplete="off"
              required
            />
          </div>

          <div className="space-y-2">
            <Label htmlFor="maternal_last_name">Apellido Materno</Label>
            <Input
              id="maternal_last_name"
              value={formData.maternal_last_name || ''}
              onChange={(e) => onChange({ maternal_last_name: e.target.value })}
              placeholder="García"
              autoComplete="off"
            />
          </div>
        </div>

        {/* Fecha de nacimiento y género */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div className="space-y-2">
            <Label htmlFor="birth_date">Fecha de Nacimiento *</Label>
            <Input
              id="birth_date"
              type="date"
              value={formData.birth_date || ''}
              onChange={(e) => onChange({ birth_date: e.target.value })}
              required
            />
          </div>

          <div className="space-y-2">
            <Label htmlFor="gender">Género *</Label>
            <select
              id="gender"
              value={formData.gender || ''}
              onChange={(e) => onChange({ gender: e.target.value })}
              required
              className="w-full rounded-md border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
            >
              <option value="">Seleccionar género...</option>
              <option value="H">Hombre</option>
              <option value="M">Mujer</option>
            </select>
          </div>
        </div>

        {/* Estado de nacimiento */}
        <div className="space-y-2">
          <Label htmlFor="birth_state">Estado de Nacimiento *</Label>
          <select
            id="birth_state"
            value={formData.birth_state || ''}
            onChange={(e) => onChange({ birth_state: e.target.value })}
            required
            className="w-full rounded-md border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500 max-h-[200px]"
          >
            <option value="">Seleccionar estado...</option>
            {states.map((state) => (
              <option key={state.code} value={state.code}>
                {state.name}
              </option>
            ))}
          </select>
        </div>

        {/* CURP generado - SIEMPRE VISIBLE */}
        <div className="space-y-2 bg-blue-50 dark:bg-blue-950 p-4 rounded-md border border-blue-200 dark:border-blue-800">
          <Label className="text-blue-900 dark:text-blue-100 font-semibold">
            📋 CURP (Generado automáticamente)
          </Label>

          {!curpDraft ? (
            <p className="text-sm text-blue-700 dark:text-blue-300">
              💡 Completa los datos arriba para generar la CURP
            </p>
          ) : (
            <>
              <div className="flex gap-2 items-center">
                <Input
                  value={curpDraft}
                  onChange={(e) => {
                    const value = e.target.value.toUpperCase();
                    if (value.length <= 16) {
                      setCurpDraft(value);
                      const fullCurp = value + homoclave;
                      if (fullCurp.length === 18) {
                        onChange({ curp: fullCurp });
                      }
                    }
                  }}
                  maxLength={16}
                  className="flex-1 bg-white dark:bg-gray-900 font-mono text-lg font-bold border-2 border-blue-400"
                  title="CURP base (primeros 16 caracteres) - Editable para casos especiales"
                  autoComplete="off"
                />
                <Input
                  value={homoclave}
                  onChange={(e) => handleHomoclaveChange(e.target.value.toUpperCase())}
                  maxLength={2}
                  placeholder="00"
                  className="w-20 text-center font-mono text-lg font-bold border-2 border-blue-400"
                  title="Homoclave (últimos 2 dígitos) - Editable"
                  autoComplete="off"
                />
              </div>
              <div className="text-sm">
                <p className="text-blue-700 dark:text-blue-300">
                  <strong>CURP completa:</strong> <span className="font-mono text-lg">{curpDraft}{homoclave}</span>
                </p>
                <p className="text-xs text-blue-600 dark:text-blue-400 mt-1">
                  ✏️ Todos los 18 dígitos son editables. Los primeros 16 se autogeneran pero puedes ajustarlos para casos especiales.
                </p>
              </div>

              {validationStates.curp?.validating && (
                <p className="text-sm text-gray-500">⏳ Verificando disponibilidad...</p>
              )}
              {validationStates.curp?.message && (
                <p className={`text-sm font-semibold ${validationStates.curp.available ? 'text-green-600' : 'text-red-600'}`}>
                  {validationStates.curp.available ? '✅' : '❌'} {validationStates.curp.message}
                </p>
              )}
            </>
          )}
        </div>

        {/* Teléfono */}
        <div className="space-y-2">
          <Label htmlFor="phone_number">Teléfono *</Label>
          <Input
            id="phone_number"
            type="tel"
            value={formData.phone_number || ''}
            onChange={(e) => onChange({ phone_number: e.target.value })}
            placeholder="5512345678"
            maxLength={10}
            required
          />
          {validationStates.phone?.validating && (
            <p className="text-sm text-gray-500">⏳ Verificando teléfono...</p>
          )}
          {validationStates.phone?.message && (
            <p className={`text-sm ${validationStates.phone.available ? 'text-green-600' : 'text-red-600'}`}>
              {validationStates.phone.available ? '✅' : '❌'} {validationStates.phone.message}
            </p>
          )}
        </div>

        {/* Email opcional */}
        <div className="space-y-2">
          <Label htmlFor="email">Email (opcional)</Label>
          <Input
            id="email"
            type="email"
            value={formData.email || ''}
            onChange={(e) => onChange({ email: e.target.value })}
            placeholder="usuario@ejemplo.com (se generará automático si vacío)"
          />
          {validationStates.email?.validating && (
            <p className="text-sm text-gray-500">⏳ Verificando email...</p>
          )}
          {validationStates.email?.message && (
            <p className={`text-sm font-semibold ${validationStates.email.available ? 'text-green-600' : 'text-red-600'}`}>
              {validationStates.email.available ? '✅' : '❌'} {validationStates.email.message}
            </p>
          )}
        </div>

        {/* Credenciales generadas - SIEMPRE VISIBLE */}
        {showCredentials && (
          <div className="space-y-4 border-t-2 pt-4 mt-4 bg-green-50 dark:bg-green-950 p-4 rounded-md">
            <h3 className="font-semibold text-lg text-green-900 dark:text-green-100">
              🔐 Credenciales de Acceso (Generadas Automáticamente)
            </h3>

            <div className="space-y-2">
              <Label htmlFor="username" className="font-semibold">Usuario Generado *</Label>
              {!formData.username ? (
                <p className="text-sm text-green-700 dark:text-green-300">
                  💡 Se generará automáticamente al ingresar nombre y apellido
                </p>
              ) : (
                <>
                  <Input
                    id="username"
                    value={formData.username || ''}
                    onChange={(e) => onChange({ username: e.target.value })}
                    placeholder="nombre.apellido"
                    disabled={autoGenerate}
                    required
                    className="font-mono text-lg font-bold bg-white dark:bg-gray-900"
                  />
                  {validationStates.username?.validating && (
                    <p className="text-sm text-gray-500">⏳ Verificando disponibilidad...</p>
                  )}
                  {validationStates.username?.message && (
                    <div className="flex items-center justify-between">
                      <p className={`text-sm font-semibold ${validationStates.username.available ? 'text-green-600' : 'text-red-600'}`}>
                        {validationStates.username.available ? '✅' : '❌'} {validationStates.username.message}
                      </p>
                      {!validationStates.username.available && autoGenerate && (
                        <button
                          type="button"
                          onClick={handleUsernameConflict}
                          className="text-sm text-blue-600 hover:underline font-semibold"
                        >
                          🔄 Generar alternativa
                        </button>
                      )}
                    </div>
                  )}
                </>
              )}
            </div>

            <div className="space-y-2">
              <Label htmlFor="password" className="font-semibold">Contraseña (CURP) *</Label>
              {!formData.password || formData.password === 'Temporal123!' ? (
                <p className="text-sm text-green-700 dark:text-green-300">
                  💡 Se asignará automáticamente la CURP completa como contraseña
                </p>
              ) : (
                <>
                  <Input
                    id="password"
                    type="text"
                    value={formData.password || ''}
                    onChange={(e) => onChange({ password: e.target.value })}
                    placeholder="Se usará CURP como contraseña"
                    disabled={autoGenerate}
                    required
                    className="font-mono text-lg font-bold bg-white dark:bg-gray-900"
                  />
                  <p className="text-xs text-green-600 dark:text-green-400 mt-1">
                    🔒 La contraseña será la CURP completa de 18 dígitos
                  </p>
                </>
              )}
            </div>
          </div>
        )}
      </CardContent>
    </Card>
  );
};

export default PersonalDataSection;
