import React, { useState } from 'react';

export const CollapsibleSection = ({ title, children, defaultOpen = false }) => {
  const [isOpen, setIsOpen] = useState(defaultOpen);

  return (
    <div className="collapsible-section">
      <button
        type="button"
        className="collapsible-header"
        onClick={() => setIsOpen(!isOpen)}
        style={{
          width: '100%',
          padding: '12px 16px',
          backgroundColor: '#f8f9fa',
          border: '1px solid #dee2e6',
          borderRadius: '4px',
          textAlign: 'left',
          cursor: 'pointer',
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          marginBottom: isOpen ? '0' : '16px',
          fontWeight: '600',
          color: '#495057'
        }}
      >
        <span>{title}</span>
        <span style={{ transform: isOpen ? 'rotate(180deg)' : 'rotate(0deg)', transition: 'transform 0.2s' }}>
          ▼
        </span>
      </button>

      {isOpen && (
        <div
          className="collapsible-content"
          style={{
            border: '1px solid #dee2e6',
            borderTop: 'none',
            borderRadius: '0 0 4px 4px',
            padding: '16px',
            backgroundColor: '#fff',
            marginBottom: '16px'
          }}
        >
          {children}
        </div>
      )}
    </div>
  );
};
