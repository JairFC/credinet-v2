import React from 'react';

export const ErrorModal = ({ show, title = "Error", message, onClose }) => {
  if (!show) return null;

  return (
    <div
      className="error-modal-overlay"
      style={{
        position: 'fixed',
        top: 0,
        left: 0,
        right: 0,
        bottom: 0,
        backgroundColor: 'rgba(0, 0, 0, 0.5)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        zIndex: 1000
      }}
      onClick={onClose}
    >
      <div
        className="error-modal"
        style={{
          backgroundColor: 'white',
          borderRadius: '8px',
          padding: '24px',
          maxWidth: '500px',
          width: '90%',
          maxHeight: '80vh',
          overflow: 'auto',
          boxShadow: '0 4px 6px rgba(0, 0, 0, 0.1)'
        }}
        onClick={(e) => e.stopPropagation()}
      >
        <div className="error-modal-header" style={{ marginBottom: '16px' }}>
          <h3 style={{ margin: 0, color: '#dc3545', fontSize: '18px', fontWeight: '600' }}>
            {title}
          </h3>
        </div>

        <div className="error-modal-body" style={{ marginBottom: '20px' }}>
          <p style={{ margin: 0, color: '#495057', lineHeight: '1.5' }}>
            {message}
          </p>
        </div>

        <div className="error-modal-footer" style={{ textAlign: 'right' }}>
          <button
            onClick={onClose}
            style={{
              backgroundColor: '#dc3545',
              color: 'white',
              border: 'none',
              borderRadius: '4px',
              padding: '8px 16px',
              cursor: 'pointer',
              fontSize: '14px',
              fontWeight: '500'
            }}
          >
            Cerrar
          </button>
        </div>
      </div>
    </div>
  );
};
