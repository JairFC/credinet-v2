import React from 'react';
import ReactDOM from 'react-dom/client';
import { BrowserRouter } from 'react-router-dom';
import App from './App';

// 1. Estilos base y variables
import './index.css';
// 2. Estilos de librerías de terceros
import 'react-datepicker/dist/react-datepicker.css';
// 3. Estilos de componentes comunes
import './styles/common.css';
// 4. Anulaciones específicas para librerías
import './styles/overrides.css';

ReactDOM.createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <BrowserRouter
      future={{
        v7_startTransition: true,
        v7_relativeSplatPath: true
      }}
    >
      <App />
    </BrowserRouter>
  </React.StrictMode>
);
