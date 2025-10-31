import React from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import ThemeSwitcher from './ThemeSwitcher';

const navStyle = {
  background: 'var(--color-surface)',
  padding: '1rem',
  display: 'flex',
  justifyContent: 'space-between',
  alignItems: 'center',
  borderBottom: '1px solid var(--color-border)',
};

const linkStyle = {
  color: 'var(--color-text-primary)',
  textDecoration: 'none',
  margin: '0 10px',
};

const Navbar = () => {
  const { user, logoutAction } = useAuth();

  // Funciones de ayuda para verificar roles
  const hasRole = (roles) => user && user.roles && roles.some(role => user.roles.includes(role));

  const canSeeManagement = hasRole(['desarrollador', 'administrador', 'auxiliar_administrativo']);
  const canSeeAdmin = hasRole(['desarrollador', 'administrador']);

  return (
    <nav style={navStyle}>
      <div>
        <Link to={user ? "/dashboard" : "/login"} style={linkStyle}>
          Credinet
        </Link>
      </div>
      <div style={{ display: 'flex', alignItems: 'center' }}>
        {user && (
          <>
            <Link to="/dashboard" style={linkStyle}>Dashboard</Link>

            {canSeeManagement && (
              <>
                <Link to="/clients" style={linkStyle}>Clientes</Link>
                <Link to="/associates" style={linkStyle}>Asociados</Link>
                <Link to="/loans" style={linkStyle}>Préstamos</Link>
              </>
            )}

            {canSeeAdmin && (
              <>
                <Link to="/users" style={linkStyle}>Usuarios</Link>
                <Link to="/loans/critical" style={{ ...linkStyle, fontWeight: 'bold', color: '#667eea' }}>🎯 Préstamo Crítico</Link>
                <Link to="/admin/periods" style={linkStyle}>Períodos</Link>
              </>
            )}

            <button onClick={logoutAction} style={{ ...linkStyle, background: 'none', border: 'none', cursor: 'pointer', marginLeft: '20px' }}>
              Cerrar Sesión ({user.sub})
            </button>
          </>
        )}
        <div style={{ marginLeft: '15px' }}>
          <ThemeSwitcher />
        </div>
      </div>
    </nav>
  );
};

export default Navbar;