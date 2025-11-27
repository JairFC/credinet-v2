import { useState } from 'react';
import reactLogo from '../assets/react.svg';
import { auth } from '../utils/auth';
import '../styles/LoginPage.css';

const API_BASE_URL = 'http://192.168.98.98:8000/api/v1';

const LoginPage = () => {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    try {
      const response = await fetch(`${API_BASE_URL}/auth/login`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ username, password }),
      });

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.detail || data.message || 'Error al iniciar sesión');
      }

      // La respuesta tiene estructura: { user: {...}, tokens: {...} }
      const { user, tokens } = data;

      // Guardar tokens y datos de usuario usando utilidades
      auth.setAuth(user, tokens.access_token, tokens.refresh_token);

      console.log('Login exitoso:', user);
      console.log('Roles:', user.roles);
      console.log('Token expira en:', tokens.expires_in, 'segundos');

      // Aquí se puede redirigir al dashboard
      const rolesStr = user.roles.join(', ');
      alert(`¡Bienvenido ${user.first_name} ${user.last_name}!\n\nRoles: ${rolesStr}\nEmail: ${user.email}`);

    } catch (err) {
      console.error('Error de login:', err);
      setError(err.message || 'Error al conectar con el servidor');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="login-container">
      <div className="login-card">
        <div className="login-header">
          <img src={reactLogo} className="login-logo" alt="React logo" />
          <h1>CrediNet V2</h1>
          <p className="subtitle">Sistema de Gestión de Préstamos</p>
        </div>

        <form onSubmit={handleSubmit} className="login-form">
          {error && (
            <div className="error-message">
              {error}
            </div>
          )}

          <div className="form-group">
            <label htmlFor="username">Usuario o Email</label>
            <input
              id="username"
              type="text"
              value={username}
              onChange={(e) => setUsername(e.target.value)}
              placeholder="admin"
              required
              minLength={3}
              autoComplete="username"
            />
          </div>

          <div className="form-group">
            <label htmlFor="password">Contraseña</label>
            <input
              id="password"
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="••••••••"
              required
              minLength={6}
              autoComplete="current-password"
            />
          </div>

          <button
            type="submit"
            className="login-button"
            disabled={loading}
          >
            {loading ? 'Iniciando sesión...' : 'Iniciar Sesión'}
          </button>
        </form>

        <div className="login-footer">
          <p className="hint">
            💡 Credenciales de prueba: <code>admin</code> / <code>Sparrow20</code>
          </p>
        </div>
      </div>
    </div>
  );
};

export default LoginPage;
