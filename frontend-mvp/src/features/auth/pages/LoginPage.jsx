import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '@/app/providers/AuthProvider';
import { ThemeToggle } from '@/shared/components/ThemeToggle';
import './LoginPage.css';

// Icons as SVG components for clean design
const UserIcon = () => (
  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
    <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/>
    <circle cx="12" cy="7" r="4"/>
  </svg>
);

const LockIcon = () => (
  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
    <rect x="3" y="11" width="18" height="11" rx="2" ry="2"/>
    <path d="M7 11V7a5 5 0 0 1 10 0v4"/>
  </svg>
);

const EyeIcon = () => (
  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
    <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/>
    <circle cx="12" cy="12" r="3"/>
  </svg>
);

const EyeOffIcon = () => (
  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
    <path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19m-6.72-1.07a3 3 0 1 1-4.24-4.24"/>
    <line x1="1" y1="1" x2="23" y2="23"/>
  </svg>
);

const AlertCircleIcon = () => (
  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
    <circle cx="12" cy="12" r="10"/>
    <line x1="12" y1="8" x2="12" y2="12"/>
    <line x1="12" y1="16" x2="12.01" y2="16"/>
  </svg>
);

// 3D Animated Logo Component - GameCube style with perpetual breathing
const AnimatedLogo = () => {
  // Grid positions for the logo (4x4 with bottom-left corner missing)
  const cubes = [
    // Row 1 (top)
    { row: 0, col: 0, delay: 0 },
    { row: 0, col: 1, delay: 0.1 },
    { row: 0, col: 2, delay: 0.2 },
    { row: 0, col: 3, delay: 0.3 },
    // Row 2
    { row: 1, col: 0, delay: 0.15 },
    { row: 1, col: 1, delay: 0.25 },
    { row: 1, col: 2, delay: 0.35 },
    { row: 1, col: 3, delay: 0.45 },
    // Row 3
    { row: 2, col: 0, delay: 0.3 },
    { row: 2, col: 1, delay: 0.4 },
    { row: 2, col: 2, delay: 0.5 },
    { row: 2, col: 3, delay: 0.6 },
    // Row 4 (bottom) - missing bottom-left corner like original logo
    { row: 3, col: 1, delay: 0.55 },
    { row: 3, col: 2, delay: 0.65 },
    { row: 3, col: 3, delay: 0.75 },
  ];

  return (
    <div className="logo-container">
      <div className="cube-grid">
        {cubes.map((cube, index) => (
          <div
            key={index}
            className="cube-wrapper"
            style={{
              '--row': cube.row,
              '--col': cube.col,
              '--delay': `${cube.delay}s`,
            }}
          >
            <div className="cube-3d">
              <div className="cube-face front"></div>
              <div className="cube-face back"></div>
              <div className="cube-face right"></div>
              <div className="cube-face left"></div>
              <div className="cube-face top"></div>
              <div className="cube-face bottom"></div>
            </div>
          </div>
        ))}
      </div>
      
      <div className="brand-name">
        <span className="brand-credi">Credi</span>
        <span className="brand-cuenta">Cuenta</span>
      </div>
    </div>
  );
};

const LoginPage = () => {
  const navigate = useNavigate();
  const { login } = useAuth();

  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    try {
      const result = await login({ username, password });

      if (result.success) {
        navigate('/dashboard', { replace: true });
      } else {
        setError(result.error);
      }
    } catch (err) {
      console.error('Error de login:', err);
      setError('Error inesperado al iniciar sesión');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="login-page">
      {/* Brand Panel */}
      <div className="login-brand-panel">
        <div className="brand-content">
          <AnimatedLogo />
          
          {/* Main Slogan */}
          <h2 className="brand-slogan">
            Con CrediCuenta usted si cuenta
          </h2>
          
          {/* Secondary Description */}
          <p className="brand-subtitle">
            Sistema integral de gestión de créditos
          </p>
        </div>
        
        {/* Floating particles effect */}
        <div className="particles">
          {[...Array(20)].map((_, i) => (
            <div key={i} className="particle" style={{ '--i': i }} />
          ))}
        </div>
      </div>

      {/* Form Panel */}
      <div className="login-form-panel">
        <div className="login-theme-toggle">
          <ThemeToggle />
        </div>
        
        <div className="login-form-container">
          <div className="login-header">
            <span className="login-greeting">BIENVENIDO DE NUEVO</span>
            <h2 className="login-title">Iniciar Sesión</h2>
            <p className="login-description">
              Ingresa tus credenciales para acceder al sistema
            </p>
          </div>

          <form onSubmit={handleSubmit} className="login-form">
            {error && (
              <div className="form-error">
                <span className="form-error-icon">
                  <AlertCircleIcon />
                </span>
                <span>{error}</span>
              </div>
            )}

            <div className="form-field">
              <label htmlFor="username" className="form-label">
                Usuario o Email
              </label>
              <div className="form-input-wrapper">
                <input
                  id="username"
                  type="text"
                  className="form-input"
                  value={username}
                  onChange={(e) => setUsername(e.target.value)}
                  placeholder="Ingresa tu usuario"
                  required
                  minLength={3}
                  autoComplete="username"
                />
                <span className="form-input-icon">
                  <UserIcon />
                </span>
              </div>
            </div>

            <div className="form-field">
              <label htmlFor="password" className="form-label">
                Contraseña
              </label>
              <div className="form-input-wrapper">
                <input
                  id="password"
                  type={showPassword ? 'text' : 'password'}
                  className="form-input"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="Ingresa tu contraseña"
                  required
                  minLength={6}
                  autoComplete="current-password"
                />
                <span className="form-input-icon">
                  <LockIcon />
                </span>
                <button
                  type="button"
                  className="password-toggle"
                  onClick={() => setShowPassword(!showPassword)}
                  aria-label={showPassword ? 'Ocultar contraseña' : 'Mostrar contraseña'}
                >
                  {showPassword ? <EyeOffIcon /> : <EyeIcon />}
                </button>
              </div>
            </div>

            <button
              type="submit"
              className="login-submit"
              disabled={loading}
            >
              <span className="login-submit-content">
                {loading && <span className="login-spinner" />}
                {loading ? 'Iniciando sesión...' : 'Iniciar Sesión'}
              </span>
            </button>
          </form>
        </div>
      </div>
    </div>
  );
};

export default LoginPage;
