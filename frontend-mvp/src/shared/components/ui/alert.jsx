/**
 * Componentes de Alert simples usando HTML y CSS
 */
export const Alert = ({ children, variant = 'info', className = '', ...props }) => {
  const variantClass = variant === 'destructive' ? 'alert-error' : `alert-${variant}`;

  return (
    <div className={`alert ${variantClass} ${className}`} {...props}>
      {children}
    </div>
  );
};

export const AlertDescription = ({ children, className = '', ...props }) => {
  return (
    <p className={`alert-description ${className}`} {...props}>
      {children}
    </p>
  );
};
