/**
 * Componente Switch simple usando checkbox styled
 */
export const Switch = ({ id, checked, onCheckedChange, className = '', ...props }) => {
  return (
    <label className={`switch ${className}`}>
      <input
        type="checkbox"
        id={id}
        checked={checked}
        onChange={(e) => onCheckedChange?.(e.target.checked)}
        {...props}
      />
      <span className="slider"></span>
    </label>
  );
};
