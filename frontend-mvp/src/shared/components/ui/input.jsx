/**
 * Componente Input simple usando HTML
 */
export const Input = ({ className = '', ...props }) => {
  return (
    <input
      className={`form-input ${className}`}
      {...props}
    />
  );
};
