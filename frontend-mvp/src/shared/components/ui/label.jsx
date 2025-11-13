/**
 * Componente Label simple usando HTML
 */
export const Label = ({ children, className = '', htmlFor, ...props }) => {
  return (
    <label
      htmlFor={htmlFor}
      className={`form-label ${className}`}
      {...props}
    >
      {children}
    </label>
  );
};
