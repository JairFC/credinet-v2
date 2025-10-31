import React from 'react';

const footerStyle = {
  textAlign: 'center',
  padding: '20px',
  marginTop: 'auto', // Empuja el footer hacia abajo
  backgroundColor: 'var(--color-surface)',
  borderTop: '1px solid var(--color-border)',
  color: 'var(--color-text-secondary)',
};

const Footer = () => {
  return (
    <footer style={footerStyle}>
      <p>&copy; {new Date().getFullYear()} Credinet. Todos los derechos reservados.</p>
    </footer>
  );
};

export default Footer;
