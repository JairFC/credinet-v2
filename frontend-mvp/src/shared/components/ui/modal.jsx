/**
 * Componente Modal simple para mensajes y errores
 */
import { useEffect } from 'react';
import { createPortal } from 'react-dom';

export const Modal = ({ isOpen, onClose, title, children, type = 'info' }) => {
  // Bloquear scroll del body cuando el modal está abierto
  useEffect(() => {
    if (isOpen) {
      document.body.style.overflow = 'hidden';
    }
    return () => {
      document.body.style.overflow = 'unset';
    };
  }, [isOpen]);

  if (!isOpen) return null;

  const typeStyles = {
    error: 'bg-red-50 border-red-500 dark:bg-red-950 dark:border-red-600',
    success: 'bg-green-50 border-green-500 dark:bg-green-950 dark:border-green-600',
    warning: 'bg-yellow-50 border-yellow-500 dark:bg-yellow-950 dark:border-yellow-600',
    info: 'bg-blue-50 border-blue-500 dark:bg-blue-950 dark:border-blue-600'
  };

  const iconStyles = {
    error: '❌',
    success: '✅',
    warning: '⚠️',
    info: 'ℹ️'
  };

  const titleStyles = {
    error: 'text-red-800 dark:text-red-200',
    success: 'text-green-800 dark:text-green-200',
    warning: 'text-yellow-800 dark:text-yellow-200',
    info: 'text-blue-800 dark:text-blue-200'
  };

  const modalContent = (
    <div
      className="fixed inset-0 bg-black bg-opacity-70 flex items-center justify-center p-4"
      style={{ zIndex: 99999 }}
      onClick={onClose}
    >
      <div
        className={`max-w-lg w-full rounded-lg shadow-2xl border-4 ${typeStyles[type]} p-6`}
        style={{
          animation: 'fadeIn 0.2s ease-in-out',
          maxHeight: '90vh',
          overflowY: 'auto'
        }}
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-start gap-3 mb-4">
          <span className="text-3xl flex-shrink-0">{iconStyles[type]}</span>
          <h2 className={`text-xl font-bold flex-1 ${titleStyles[type]}`}>{title}</h2>
          <button
            onClick={onClose}
            className="text-gray-500 hover:text-gray-700 dark:text-gray-400 dark:hover:text-gray-200 text-3xl leading-none font-bold flex-shrink-0"
            title="Cerrar"
          >
            ×
          </button>
        </div>
        <div className="text-gray-800 dark:text-gray-200 text-base">
          {children}
        </div>
        <div className="mt-6 flex justify-end gap-2">
          <button
            onClick={onClose}
            className="px-6 py-2 bg-gray-600 hover:bg-gray-700 text-white rounded-md font-medium transition-colors"
          >
            Cerrar
          </button>
        </div>
      </div>
    </div>
  );

  // Renderizar en el body usando portal
  return createPortal(modalContent, document.body);
};

export default Modal;
