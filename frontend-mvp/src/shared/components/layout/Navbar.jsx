import { useState, useEffect, useRef } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useAuth } from '@/app/providers/AuthProvider';
import { ThemeToggle } from '@/shared/components/ThemeToggle';
import './Navbar.css';

const Navbar = () => {
  const navigate = useNavigate();
  const { user, logout } = useAuth();
  const [menuOpen, setMenuOpen] = useState(false);
  const [usersMenuOpen, setUsersMenuOpen] = useState(false);
  const [loansMenuOpen, setLoansMenuOpen] = useState(false);
  const [agreementsMenuOpen, setAgreementsMenuOpen] = useState(false);

  // Refs para detectar hover
  const loansMenuRef = useRef(null);
  const usersMenuRef = useRef(null);
  const agreementsMenuRef = useRef(null);

  // Timers para auto-cierre
  const loansTimerRef = useRef(null);
  const usersTimerRef = useRef(null);
  const agreementsTimerRef = useRef(null);

  // Auto-cierre de dropdown de préstamos
  useEffect(() => {
    if (loansMenuOpen) {
      const handleMouseEnter = () => {
        if (loansTimerRef.current) {
          clearTimeout(loansTimerRef.current);
        }
      };

      const handleMouseLeave = () => {
        loansTimerRef.current = setTimeout(() => {
          setLoansMenuOpen(false);
        }, 2500);
      };

      const menuElement = loansMenuRef.current;
      if (menuElement) {
        menuElement.addEventListener('mouseenter', handleMouseEnter);
        menuElement.addEventListener('mouseleave', handleMouseLeave);
        handleMouseLeave(); // Iniciar timer inmediatamente

        return () => {
          menuElement.removeEventListener('mouseenter', handleMouseEnter);
          menuElement.removeEventListener('mouseleave', handleMouseLeave);
          if (loansTimerRef.current) {
            clearTimeout(loansTimerRef.current);
          }
        };
      }
    }
  }, [loansMenuOpen]);

  // Auto-cierre de dropdown de usuarios
  useEffect(() => {
    if (usersMenuOpen) {
      const handleMouseEnter = () => {
        if (usersTimerRef.current) {
          clearTimeout(usersTimerRef.current);
        }
      };

      const handleMouseLeave = () => {
        usersTimerRef.current = setTimeout(() => {
          setUsersMenuOpen(false);
        }, 2500);
      };

      const menuElement = usersMenuRef.current;
      if (menuElement) {
        menuElement.addEventListener('mouseenter', handleMouseEnter);
        menuElement.addEventListener('mouseleave', handleMouseLeave);
        handleMouseLeave();

        return () => {
          menuElement.removeEventListener('mouseenter', handleMouseEnter);
          menuElement.removeEventListener('mouseleave', handleMouseLeave);
          if (usersTimerRef.current) {
            clearTimeout(usersTimerRef.current);
          }
        };
      }
    }
  }, [usersMenuOpen]);

  // Auto-cierre de dropdown de convenios
  useEffect(() => {
    if (agreementsMenuOpen) {
      const handleMouseEnter = () => {
        if (agreementsTimerRef.current) {
          clearTimeout(agreementsTimerRef.current);
        }
      };

      const handleMouseLeave = () => {
        agreementsTimerRef.current = setTimeout(() => {
          setAgreementsMenuOpen(false);
        }, 2500);
      };

      const menuElement = agreementsMenuRef.current;
      if (menuElement) {
        menuElement.addEventListener('mouseenter', handleMouseEnter);
        menuElement.addEventListener('mouseleave', handleMouseLeave);
        handleMouseLeave();

        return () => {
          menuElement.removeEventListener('mouseenter', handleMouseEnter);
          menuElement.removeEventListener('mouseleave', handleMouseLeave);
          if (agreementsTimerRef.current) {
            clearTimeout(agreementsTimerRef.current);
          }
        };
      }
    }
  }, [agreementsMenuOpen]);

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

  const toggleAgreementsMenu = () => {
    setAgreementsMenuOpen(!agreementsMenuOpen);
  };

  return (
    <nav className="navbar">
      <div className="navbar-container">
        <div className="navbar-brand">
          <Link to="/dashboard" className="brand-link">
            {/* Mini Logo 3D GameCube Style */}
            <div className="brand-logo-mini">
              <div className="mini-cube-container">
                <div className="mini-cube"></div>
                <div className="mini-cube"></div>
                <div className="mini-cube"></div>
                <div className="mini-cube"></div>
              </div>
            </div>
            <span className="brand-text"><span className="brand-credi">Credi</span><span className="brand-cuenta">Cuenta</span></span>
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
            <li className="navbar-dropdown" ref={loansMenuRef}>
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
            <li className="navbar-dropdown" ref={usersMenuRef}>
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

            {/* Agreements Module (Convenios) - Dropdown */}
            <li className="navbar-dropdown" ref={agreementsMenuRef}>
              <button
                className="dropdown-toggle"
                onClick={toggleAgreementsMenu}
              >
                📋 Convenios {agreementsMenuOpen ? '▲' : '▼'}
              </button>
              {agreementsMenuOpen && (
                <ul className="dropdown-menu">
                  <li>
                    <Link
                      to="/convenios"
                      onClick={() => {
                        setMenuOpen(false);
                        setAgreementsMenuOpen(false);
                      }}
                    >
                      📋 Lista de Convenios
                    </Link>
                  </li>
                  <li>
                    <Link
                      to="/convenios/nuevo"
                      onClick={() => {
                        setMenuOpen(false);
                        setAgreementsMenuOpen(false);
                      }}
                    >
                      ➕ Nuevo Convenio
                    </Link>
                  </li>
                </ul>
              )}
            </li>

          </ul>

          <div className="navbar-user">
            <Link to="/notificaciones" className="notification-icon" title="Notificaciones">
              🔔
            </Link>
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
            <ThemeToggle />
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
