/**
 * AssociateCreatePage - Formulario completo para crear nuevo asociado
 * Usa componentes reutilizables para: Datos personales, Dirección, Aval, Beneficiario, Perfil de Asociado
 */
import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { associatesService } from '../../../../shared/api/services/associatesService';
import SimpleModal from '../../../../shared/components/ui/SimpleModal';
import {
  prepareUserData,
  validateUserForm,
  extractErrorMessage
} from '../../../../shared/utils/userFormHelpers';
import {
  PersonalDataSection,
  AddressSection,
  GuarantorSection,
  BeneficiarySection,
  AssociateProfileSection
} from '../../../../shared/components/forms';

export default function AssociateCreatePage() {
  const navigate = useNavigate();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [showErrorModal, setShowErrorModal] = useState(false);
  const [autoGenerate, setAutoGenerate] = useState(true);
  const [associateLevels, setAssociateLevels] = useState([]);

  const [formData, setFormData] = useState({
    // Credenciales
    username: '',
    password: '',
    confirmPassword: '',
    // Información personal
    first_name: '',
    paternal_last_name: '',
    maternal_last_name: '',
    birth_date: '',
    gender: '',
    birth_state: '',
    email: '',
    phone_number: '',
    curp: '',
    // Dirección (opcional)
    street: '',
    external_number: '',
    internal_number: '',
    colony: '',
    municipality: '',
    state: '',
    zip_code: '',
    // Aval (opcional)
    guarantor_first_name: '',
    guarantor_paternal_last_name: '',
    guarantor_maternal_last_name: '',
    guarantor_birth_date: '',
    guarantor_gender: '',
    guarantor_birth_state: '',
    guarantor_relationship: '',
    guarantor_phone: '',
    guarantor_curp: '',
    // Beneficiario (opcional)
    beneficiary_full_name: '',
    beneficiary_relationship: '',
    beneficiary_phone: '',
    // Perfil de Asociado
    level_id: '1',
    credit_limit: '',
    default_commission_rate: '5.00',
  });

  // Cargar niveles de asociado al montar
  useEffect(() => {
    const loadLevels = async () => {
      try {
        // TODO: Crear endpoint para obtener niveles
        // Por ahora, usar niveles actualizados según especificaciones
        setAssociateLevels([
          { id: 1, name: 'Bronce', credit_limit: 25000 },
          { id: 2, name: 'Plata', credit_limit: 300000 },
          { id: 3, name: 'Oro', credit_limit: 600000 },
          { id: 4, name: 'Platino', credit_limit: 900000 },
          { id: 5, name: 'Diamante', credit_limit: 5000000 },
        ]);
      } catch (err) {
        console.error('Error cargando niveles:', err);
      }
    };
    loadLevels();
  }, []);

  const handleFormChange = (updates) => {
    setFormData(prev => ({ ...prev, ...updates }));
  };

  const validateForm = () => {
    // Usar validación compartida
    const errors = validateUserForm(formData, 'associate');

    // Validaciones adicionales específicas de asociados
    if (!formData.gender) {
      errors.push({ field: 'gender', message: 'El género es obligatorio' });
    }
    if (!formData.birth_state) {
      errors.push({ field: 'birth_state', message: 'El estado de nacimiento es obligatorio' });
    }
    if (!formData.level_id) {
      errors.push({ field: 'level_id', message: 'El nivel de asociado es obligatorio' });
    }
    if (!formData.credit_limit || parseFloat(formData.credit_limit) <= 0) {
      errors.push({ field: 'credit_limit', message: 'La línea de crédito debe ser mayor a 0' });
    }
    const rate = parseFloat(formData.default_commission_rate);
    if (isNaN(rate) || rate < 0 || rate > 100) {
      errors.push({ field: 'default_commission_rate', message: 'Tasa de comisión inválida (0-100%)' });
    }

    return errors.length > 0 ? errors : null;
  };

  const scrollToField = (fieldId) => {
    const element = document.getElementById(fieldId);
    if (element) {
      element.scrollIntoView({ behavior: 'smooth', block: 'center' });
      element.focus();
      element.classList.add('ring-2', 'ring-red-500', 'ring-offset-2');
      setTimeout(() => {
        element.classList.remove('ring-2', 'ring-red-500', 'ring-offset-2');
      }, 2000);
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    setShowErrorModal(false);

    const validationErrors = validateForm();
    if (validationErrors) {
      const errorCount = validationErrors.length;
      const errorList = validationErrors.map(err => err.message).join('\n• ');
      const plural = errorCount > 1 ? 'errores encontrados' : 'error encontrado';
      const fullErrorMsg = `⚠️ ${errorCount} ${plural}:\n\n• ${errorList}`;

      setError(fullErrorMsg);
      setShowErrorModal(true);
      scrollToField(validationErrors[0].field);
      return;
    }

    setLoading(true);
    try {
      // Preparar datos usando utilidad compartida
      const userData = prepareUserData(formData, 'associate');

      // Agregar campos específicos de asociado
      const associateData = {
        ...userData,
        level_id: parseInt(formData.level_id),
        credit_limit: parseFloat(formData.credit_limit),
        default_commission_rate: parseFloat(formData.default_commission_rate),
      };

      console.log('📤 Enviando datos al backend:', associateData);

      const response = await associatesService.create(associateData);

      console.log('📥 Respuesta completa del backend:', response);
      console.log('📥 response.data:', response.data);

      // El backend devuelve { success: true, data: { user_id: ... } }
      // Y axios lo wrappea en response.data
      if (!response?.data?.data?.user_id) {
        console.error('❌ No se encontró user_id en response.data.data');
        console.error('Estructura recibida:', JSON.stringify(response, null, 2));
        throw new Error('No se recibió el ID del usuario creado');
      }
      const userId = response.data.data.user_id;
      console.log('✅ Usuario creado con ID:', userId);

      // Crear dirección si se proporcionó
      if (formData.street && formData.external_number && formData.zip_code) {
        try {
          await fetch(`${import.meta.env.VITE_API_URL}/api/v1/addresses`, {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'Authorization': `Bearer ${localStorage.getItem('token')}`
            },
            body: JSON.stringify({
              user_id: userId,
              street: formData.street,
              external_number: formData.external_number,
              internal_number: formData.internal_number || null,
              colony: formData.colony,
              municipality: formData.municipality,
              state: formData.state,
              zip_code: formData.zip_code
            })
          });
        } catch (addrError) {
          console.error('Error al crear dirección:', addrError);
        }
      }

      // Crear aval si se proporcionó
      if (formData.guarantor_first_name && formData.guarantor_paternal_last_name && formData.guarantor_relationship && formData.guarantor_phone) {
        try {
          const guarantorFullName = [
            formData.guarantor_first_name,
            formData.guarantor_paternal_last_name,
            formData.guarantor_maternal_last_name
          ].filter(Boolean).join(' ');

          // Buscar relationship_id del catálogo
          const relResponse = await fetch(`${import.meta.env.VITE_API_URL}/api/v1/shared/relationships`);
          const relData = await relResponse.json();
          const relationship = relData.data.find(r => r.name === formData.guarantor_relationship);

          await fetch(`${import.meta.env.VITE_API_URL}/api/v1/guarantors`, {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'Authorization': `Bearer ${localStorage.getItem('token')}`
            },
            body: JSON.stringify({
              user_id: userId,
              full_name: guarantorFullName,
              first_name: formData.guarantor_first_name,
              paternal_last_name: formData.guarantor_paternal_last_name,
              maternal_last_name: formData.guarantor_maternal_last_name || null,
              relationship: formData.guarantor_relationship,
              relationship_id: relationship?.id || null,
              phone_number: formData.guarantor_phone,
              curp: formData.guarantor_curp || null
            })
          });
        } catch (guarantorError) {
          console.error('Error al crear aval:', guarantorError);
        }
      }

      // Crear beneficiario si se proporcionó
      if (formData.beneficiary_full_name && formData.beneficiary_relationship && formData.beneficiary_phone) {
        try {
          // Buscar relationship_id del catálogo
          const relResponse = await fetch(`${import.meta.env.VITE_API_URL}/api/v1/shared/relationships`);
          const relData = await relResponse.json();
          const relationship = relData.data.find(r => r.name === formData.beneficiary_relationship);

          await fetch(`${import.meta.env.VITE_API_URL}/api/v1/beneficiaries`, {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'Authorization': `Bearer ${localStorage.getItem('token')}`
            },
            body: JSON.stringify({
              user_id: userId,
              full_name: formData.beneficiary_full_name,
              relationship: formData.beneficiary_relationship,
              relationship_id: relationship?.id || null,
              phone_number: formData.beneficiary_phone
            })
          });
        } catch (beneficiaryError) {
          console.error('Error al crear beneficiario:', beneficiaryError);
        }
      }

      alert('✅ Asociado creado exitosamente');
      navigate('/usuarios/asociados');
    } catch (error) {
      console.error('❌ Error al crear asociado:', error);

      // Log detallado para debugging
      if (error.response) {
        console.error('Response data:', error.response.data);
        console.error('Response status:', error.response.status);
      }

      const errorMsg = extractErrorMessage(error);
      setError(errorMsg);
      setShowErrorModal(true);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-50 to-gray-100 dark:from-gray-900 dark:to-gray-800 p-4 md:p-8">
      {/* Modal de Error */}
      <SimpleModal
        isOpen={showErrorModal}
        onClose={() => setShowErrorModal(false)}
        title="⚠️ Error al crear asociado"
      >
        <div className="whitespace-pre-line text-sm">
          {error}
        </div>
      </SimpleModal>

      {/* Header */}
      <div className="max-w-7xl mx-auto mb-6">
        <button
          onClick={() => navigate('/usuarios/asociados')}
          className="mb-4 flex items-center text-gray-600 hover:text-gray-900 dark:text-gray-400 dark:hover:text-gray-100"
        >
          <span className="mr-2">←</span> Volver a Asociados
        </button>
        <h1 className="text-3xl font-bold text-gray-900 dark:text-gray-100">
          💼 Nuevo Asociado
        </h1>
        <p className="text-gray-600 dark:text-gray-400 mt-2">
          Complete la información del nuevo asociado. Los campos marcados con * son obligatorios.
        </p>
      </div>

      {/* Formulario */}
      <form onSubmit={handleSubmit} className="max-w-7xl mx-auto space-y-6">
        {/* Sección 1: Datos Personales */}
        <PersonalDataSection
          formData={formData}
          onChange={handleFormChange}
          autoGenerate={autoGenerate}
          onToggleAutoGenerate={() => setAutoGenerate(!autoGenerate)}
          userType="associate"
        />

        {/* Sección 2: Perfil de Asociado */}
        <AssociateProfileSection
          formData={formData}
          onChange={handleFormChange}
          associateLevels={associateLevels}
        />

        {/* Sección 3: Dirección (Opcional) */}
        <AddressSection
          formData={formData}
          onChange={handleFormChange}
          collapsible={true}
        />

        {/* Sección 4: Aval (Opcional) */}
        <GuarantorSection
          formData={formData}
          onChange={handleFormChange}
          collapsible={true}
        />

        {/* Sección 5: Beneficiario (Opcional) */}
        <BeneficiarySection
          formData={formData}
          onChange={handleFormChange}
          collapsible={true}
        />

        {/* Botones de Acción */}
        <div className="flex gap-4 justify-end sticky bottom-4 bg-white dark:bg-gray-800 p-4 rounded-lg shadow-lg border border-gray-200 dark:border-gray-700">
          <button
            type="button"
            onClick={() => navigate('/usuarios/asociados')}
            disabled={loading}
            className="px-6 py-2 border border-gray-300 dark:border-gray-600 rounded-md text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-700 disabled:opacity-50"
          >
            Cancelar
          </button>
          <button
            type="submit"
            disabled={loading}
            className="px-6 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
          >
            {loading ? (
              <>
                <svg className="animate-spin h-5 w-5" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                  <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                  <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                </svg>
                Guardando...
              </>
            ) : (
              '✅ Crear Asociado'
            )}
          </button>
        </div>
      </form>
    </div>
  );
}
