import React from 'react';
import DatePicker, { registerLocale } from 'react-datepicker';
import es from 'date-fns/locale/es';

// Registrar el locale en español
registerLocale('es', es);

const CustomDatePicker = ({ selectedDate, onChange }) => {
  return (
    <DatePicker
      selected={selectedDate}
      onChange={onChange}
      dateFormat="dd/MM/yyyy"
      placeholderText="dd/mm/aaaa"
      showMonthDropdown
      showYearDropdown
      dropdownMode="select"
      locale="es"
      className="form-control" // Reutilizamos la clase para mantener el estilo
      autoComplete="off"
    />
  );
};

export default CustomDatePicker;
