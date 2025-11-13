/**
 * Utilidades de autenticación
 * Manejo de tokens JWT y datos de usuario
 */

const TOKEN_KEYS = {
  ACCESS: 'access_token',
  REFRESH: 'refresh_token',
  USER: 'user',
};

export const auth = {
  /**
   * Guarda los datos de autenticación en localStorage
   */
  setAuth(user, accessToken, refreshToken) {
    localStorage.setItem(TOKEN_KEYS.ACCESS, accessToken);
    localStorage.setItem(TOKEN_KEYS.REFRESH, refreshToken);
    localStorage.setItem(TOKEN_KEYS.USER, JSON.stringify(user));
  },

  /**
   * Obtiene el access token
   */
  getAccessToken() {
    return localStorage.getItem(TOKEN_KEYS.ACCESS);
  },

  /**
   * Obtiene el refresh token
   */
  getRefreshToken() {
    return localStorage.getItem(TOKEN_KEYS.REFRESH);
  },

  /**
   * Obtiene los datos del usuario autenticado
   */
  getUser() {
    const userJson = localStorage.getItem(TOKEN_KEYS.USER);
    return userJson ? JSON.parse(userJson) : null;
  },

  /**
   * Verifica si hay un usuario autenticado
   */
  isAuthenticated() {
    return !!this.getAccessToken();
  },

  /**
   * Limpia todos los datos de autenticación
   */
  clearAuth() {
    localStorage.removeItem(TOKEN_KEYS.ACCESS);
    localStorage.removeItem(TOKEN_KEYS.REFRESH);
    localStorage.removeItem(TOKEN_KEYS.USER);
  },

  /**
   * Obtiene el header de autorización para requests
   */
  getAuthHeader() {
    const token = this.getAccessToken();
    return token ? { Authorization: `Bearer ${token}` } : {};
  },
};

/**
 * Decodifica un JWT token (sin verificar firma - solo para leer payload)
 */
export function decodeJWT(token) {
  try {
    const base64Url = token.split('.')[1];
    const base64 = base64Url.replace(/-/g, '+').replace(/_/g, '/');
    const jsonPayload = decodeURIComponent(
      atob(base64)
        .split('')
        .map((c) => '%' + ('00' + c.charCodeAt(0).toString(16)).slice(-2))
        .join('')
    );
    return JSON.parse(jsonPayload);
  } catch (error) {
    console.error('Error decoding JWT:', error);
    return null;
  }
}

/**
 * Verifica si un token JWT ha expirado
 */
export function isTokenExpired(token) {
  const decoded = decodeJWT(token);
  if (!decoded || !decoded.exp) return true;

  const currentTime = Math.floor(Date.now() / 1000);
  return decoded.exp < currentTime;
}

/**
 * Obtiene información del usuario del token
 */
export function getUserFromToken(token) {
  const decoded = decodeJWT(token);
  if (!decoded) return null;

  return {
    userId: decoded.sub,
    exp: decoded.exp,
    iat: decoded.iat,
  };
}
