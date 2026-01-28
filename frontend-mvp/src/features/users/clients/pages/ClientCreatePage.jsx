/**
 * ClientCreatePage - Formulario completo para crear nuevo cliente
 * Usa componentes reutilizables para: Datos personales, Dirección, Aval, Beneficiario
 */
import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { clientsService } from '../../../../shared/api/services/clientsService';
import SimpleModal from '../../../../shared/components/ui/SimpleModal';
import SuccessNotification from '../../../../shared/components/SuccessNotification';
import {
  prepareUserData,
  validateUserForm,
  extractErrorMessage
} from '../../../../shared/utils/userFormHelpers';
import {
  PersonalDataSection,
  AddressSection,
  GuarantorSection,
  BeneficiarySection
} from '../../../../shared/components/forms';

export default function ClientCreatePage() {
  const navigate = useNavigate();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [showErrorModal, setShowErrorModal] = useState(false);
  const [showSuccessNotification, setShowSuccessNotification] = useState(false);
  const [createdClientId, setCreatedClientId] = useState(null);
  const [autoGenerate, setAutoGenerate] = useState(true);

  const [formData, setFormData] = useState({
    username: '',
    password: '',
    confirmPassword: '',
    first_name: '',
    paternal_last_name: '',
    maternal_last_name: '',
    birth_date: '',
    gender: '',
    birth_state: '',
    email: '',
    phone_number: '',
    curp: '',
    street: '',
    external_number: '',
    internal_number: '',
    colony: '',
    municipality: '',
    state: '',
    zip_code: '',
    guarantor_first_name: '',
    guarantor_paternal_last_name: '',
    guarantor_maternal_last_name: '',
    guarantor_birth_date: '',
    guarantor_gender: '',
    guarantor_birth_state: '',
    guarantor_relationship: '',
    guarantor_phone: '',
    guarantor_curp: '',
    beneficiary_full_name: '',
    beneficiary_relationship: '',
    beneficiary_phone: '',
  });

  const handleFormChange = (updates) => {
    setFormData(prev => ({ ...prev, ...updates }));
  };

  const validateForm = () => {
    // Usar validación compartida
    const errors = validateUserForm(formData, 'client');

    // Validaciones adicionales específicas de clientes
    if (!formData.gender) {
      errors.push({ field: 'gender', message: 'El género es obligatorio' });
    }
    if (!formData.birth_state) {
      errors.push({ field: 'birth_state', message: 'El estado de nacimiento es obligatorio' });
    }

    return errors.length > 0 ? errors : null;
  }; const scrollToField = (fieldId) => {
    const element = document.getElementById(fieldId);
    if (element) {
      element.scrollIntoView({ behavior: 'smooth', block: 'center' });
      element.focus();
      // Añadir clase de animación temporal
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
      // Mostrar modal con todos los errores
      const errorCount = validationErrors.length;
      const errorList = validationErrors.map(err => err.message).join('\n• ');
      const plural = errorCount > 1 ? 'errores encontrados' : 'error encontrado';
      const fullErrorMsg = `⚠️ ${errorCount} ${plural}:\n\n• ${errorList}`;

      setError(fullErrorMsg);
      setShowErrorModal(true);

      // Scroll al primer campo con error
      scrollToField(validationErrors[0].field);
      return;
    } setLoading(true);
    try {
      // Preparar datos usando utilidad compartida
      const userData = prepareUserData(formData, 'client');

      console.log('📤 Enviando datos al backend:', userData);

      const response = await clientsService.create(userData);

      // El backend retorna los datos en response.data
      if (!response?.data?.id) {
        throw new Error('No se recibió el ID del usuario creado');
      }
      const userId = response.data.id;

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
          // Calcular nombre completo a partir de los campos separados
          const guarantorFullName = [
            formData.guarantor_first_name,
            formData.guarantor_paternal_last_name,
            formData.guarantor_maternal_last_name
          ].filter(Boolean).join(' ');

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
              phone_number: formData.beneficiary_phone
            })
          });
        } catch (beneficiaryError) {
          console.error('Error al crear beneficiario:', beneficiaryError);
        }
      }
      setCreatedClientId(userId);
      setShowSuccessNotification(true);
    } catch (error) {
      console.error('❌ Error al crear cliente:', error);

      // Usar utilidad compartida para extraer mensaje de error
      const errorMsg = extractErrorMessage(error);

      setError(errorMsg);
      setShowErrorModal(true);
    } finally {
      setLoading(false);
    }
  }; return (
    <div className="min-h-screen bg-gray-50 dark:bg-gray-900 p-6">
      <div className="max-w-4xl mx-auto">
        {/* Modal de Error - SIMPLE VERSION */}
        <SimpleModal
          isOpen={showErrorModal}
          onClose={() => setShowErrorModal(false)}
          title="Error en el formulario"
        >
          {error}
        </SimpleModal>

        {/* Notificación de éxito elegante */}
        <SuccessNotification
          isOpen={showSuccessNotification}
          onClose={() => {
            setShowSuccessNotification(false);
            navigate('/usuarios/clientes');
          }}
          title="¡Cliente creado exitosamente!"
          message={`${formData.first_name} ${formData.paternal_last_name} ha sido registrado en el sistema.`}
          icon="🎉"
          duration={5000}
          actions={[
            {
              label: 'Ver Cliente',
              icon: '👤',
              variant: 'secondary',
              onClick: () => {
                setShowSuccessNotification(false);
                navigate(`/usuarios/clientes/${createdClientId}`);
              }
            },
            {
              label: 'Ir al Listado',
              icon: '📋',
              variant: 'primary',
              onClick: () => {
                setShowSuccessNotification(false);
                navigate('/usuarios/clientes');
              }
            }
          ]}
        />

        {/* Header */}
        <div className="mb-6 flex items-center justify-between">
          <div className="flex items-center gap-4">
            <button
              type="button"
              onClick={() => navigate('/usuarios/clientes')}
              className="btn btn-secondary"
            >
              ← Volver
            </button>
            <h1 className="text-3xl font-bold">Nuevo Cliente</h1>
          </div>
        </div>

        {/* Formulario con secciones */}
        <form onSubmit={handleSubmit} className="space-y-6">

          {/* Datos Personales y Credenciales */}
          <PersonalDataSection
            formData={formData}
            onChange={handleFormChange}
            showCredentials={true}
            autoGenerate={autoGenerate}
            onAutoGenerateChange={setAutoGenerate}
          />

          {/* Dirección (opcional) */}
          <AddressSection
            formData={formData}
            onChange={handleFormChange}
            required={false}
            collapsible={true}
          />

          {/* Aval (opcional) */}
          <GuarantorSection
            formData={formData}
            onChange={handleFormChange}
            collapsible={true}
          />

          {/* Beneficiario (opcional) */}
          <BeneficiarySection
            formData={formData}
            onChange={handleFormChange}
            collapsible={true}
          />

          {/* Botones de acción */}
          <div className="flex items-center justify-end gap-4 pt-4">
            <button
              type="button"
              onClick={() => navigate('/usuarios/clientes')}
              disabled={loading}
              className="btn btn-secondary"
            >
              Cancelar
            </button>
            <button
              type="submit"
              disabled={loading}
              className="btn btn-primary"
            >
              {loading ? 'Guardando...' : '✅ Crear Cliente'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
