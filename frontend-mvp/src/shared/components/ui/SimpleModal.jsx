/**
 * Modal simple SIN portal - Para debugging
 */
export const SimpleModal = ({ isOpen, onClose, title, children }) => {
  if (!isOpen) return null;

  return (
    <div
      style={{
        position: 'fixed',
        top: 0,
        left: 0,
        right: 0,
        bottom: 0,
        backgroundColor: 'rgba(0, 0, 0, 0.8)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        zIndex: 999999,
        padding: '20px'
      }}
      onClick={onClose}
    >
      <div
        style={{
          backgroundColor: '#fee',
          border: '4px solid #f00',
          borderRadius: '8px',
          padding: '30px',
          maxWidth: '500px',
          width: '100%',
          maxHeight: '80vh',
          overflowY: 'auto'
        }}
        onClick={(e) => e.stopPropagation()}
      >
        <div style={{ marginBottom: '20px', display: 'flex', alignItems: 'center', gap: '10px' }}>
          <span style={{ fontSize: '32px' }}>❌</span>
          <h2 style={{ fontSize: '20px', fontWeight: 'bold', color: '#900', flex: 1 }}>
            {title}
          </h2>
          <button
            onClick={onClose}
            style={{
              fontSize: '32px',
              fontWeight: 'bold',
              color: '#666',
              background: 'none',
              border: 'none',
              cursor: 'pointer',
              padding: '0 10px'
            }}
          >
            ×
          </button>
        </div>
        <div style={{ color: '#600', fontSize: '16px', whiteSpace: 'pre-line' }}>
          {children}
        </div>
        <div style={{ marginTop: '20px', display: 'flex', justifyContent: 'flex-end' }}>
          <button
            onClick={onClose}
            style={{
              padding: '10px 24px',
              backgroundColor: '#666',
              color: 'white',
              border: 'none',
              borderRadius: '6px',
              fontSize: '16px',
              fontWeight: '500',
              cursor: 'pointer'
            }}
          >
            Cerrar
          </button>
        </div>
      </div>
    </div>
  );
};

export default SimpleModal;
