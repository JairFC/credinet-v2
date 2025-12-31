import { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useAuth } from '@/app/providers/AuthProvider';
import './Navbar.css';

const Navbar = () => {
  const navigate = useNavigate();
  const { user, logout } = useAuth();
  const [menuOpen, setMenuOpen] = useState(false);
  const [usersMenuOpen, setUsersMenuOpen] = useState(false);
  const [loansMenuOpen, setLoansMenuOpen] = useState(false);

  const handleLogout = () => {
    logout();
    navigate('/login', { replace: true });
  };

  const toggleMenu = () => {
    setMenuOpen(!menuOpen);
  };

  const toggleUsersMenu = () => {
    setUsersMenuOpen(!usersMenuOpen);
  };

  const toggleLoansMenu = () => {
    setLoansMenuOpen(!loansMenuOpen);
  };

  return (
    <nav className="navbar">
      <div className="navbar-container">
        <div className="navbar-brand">
          <Link to="/dashboard" className="brand-link">
            CrediNet <span className="version">V2</span>
          </Link>
        </div>

        <button className="navbar-toggle" onClick={toggleMenu}>
          <span className="hamburger-icon">☰</span>
        </button>

        <div className={`navbar-menu ${menuOpen ? 'active' : ''}`}>
          <ul className="navbar-links">
            <li>
              <Link to="/dashboard" onClick={() => setMenuOpen(false)}>
                📊 Dashboard
              </Link>
            </li>

            {/* Loans Module - Dropdown */}
            <li className="navbar-dropdown">
              <button
                className="dropdown-toggle"
                onClick={toggleLoansMenu}
              >
                💰 Préstamos {loansMenuOpen ? '▲' : '▼'}
              </button>
              {loansMenuOpen && (
                <ul className="dropdown-menu">
                  <li>
                    <Link
                      to="/prestamos"
                      onClick={() => {
                        setMenuOpen(false);
                        setLoansMenuOpen(false);
                      }}
                    >
                      📋 Gestión
                    </Link>
                  </li>
                  <li>
                    <Link
                      to="/prestamos/nuevo"
                      onClick={() => {
                        setMenuOpen(false);
                        setLoansMenuOpen(false);
                      }}
                    >
                      ➕ Nuevo Préstamo
                    </Link>
                  </li>
                  <li>
                    <Link
                      to="/prestamos/simulador"
                      onClick={() => {
                        setMenuOpen(false);
                        setLoansMenuOpen(false);
                      }}
                    >
                      🧮 Simulador
                    </Link>
                  </li>
                </ul>
              )}
            </li>

            <li>
              <Link to="/estados-cuenta" onClick={() => setMenuOpen(false)}>
                📊 Estados de Cuenta
              </Link>
            </li>

            {/* Users Module - Dropdown */}
            <li className="navbar-dropdown">
              <button
                className="dropdown-toggle"
                onClick={toggleUsersMenu}
              >
                👥 Usuarios {usersMenuOpen ? '▲' : '▼'}
              </button>
              {usersMenuOpen && (
                <ul className="dropdown-menu">
                  <li>
                    <Link
                      to="/usuarios/clientes"
                      onClick={() => {
                        setMenuOpen(false);
                        setUsersMenuOpen(false);
                      }}
                    >
                      👤 Clientes
                    </Link>
                  </li>
                  <li>
                    <Link
                      to="/usuarios/asociados"
                      onClick={() => {
                        setMenuOpen(false);
                        setUsersMenuOpen(false);
                      }}
                    >
                      💼 Asociados
                    </Link>
                  </li>
                </ul>
              )}
            </li>

            <li>
              <Link to="/reportes" onClick={() => setMenuOpen(false)}>
                📈 Reportes
              </Link>
            </li>
          </ul>

          <div className="navbar-user">
            <div className="user-info">
              <div className="user-avatar">
                {user?.first_name?.[0]}{user?.last_name?.[0]}
              </div>
              <div className="user-details">
                <span className="user-name">
                  {user?.first_name} {user?.last_name}
                </span>
                <span className="user-role">
                  {user?.roles?.join(', ')}
                </span>
              </div>
            </div>
            <button className="logout-button" onClick={handleLogout}>
              🚪 Salir
            </button>
          </div>
        </div>
      </div>
    </nav>
  );
};

export default Navbar;
