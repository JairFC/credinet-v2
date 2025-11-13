/**
 * Componentes Select simples usando HTML select
 */
export const Select = ({ children, value, onValueChange, ...props }) => {
  // Extraer las opciones de SelectContent y SelectItem
  return (
    <select
      value={value}
      onChange={(e) => onValueChange?.(e.target.value)}
      className="form-input"
      {...props}
    >
      {children}
    </select>
  );
};

export const SelectTrigger = ({ id, children }) => {
  // No se usa en la versión simple, retorna children
  return null;
};

export const SelectValue = ({ placeholder }) => {
  return <option value="" disabled>{placeholder}</option>;
};

export const SelectContent = ({ children }) => {
  return <>{children}</>;
};

export const SelectItem = ({ value, children, ...props }) => {
  return (
    <option value={value} {...props}>
      {children}
    </option>
  );
};
