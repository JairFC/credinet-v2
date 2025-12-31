import { createContext, useContext, useState, useEffect } from 'react';
import { auth as authUtils } from '@/shared/utils/auth';
import { authService } from '@/shared/api/services';

const AuthContext = createContext(null);

export const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    // Revalidate user on app load
    const revalidateUser = async () => {
      const token = authUtils.getAccessToken();

      if (token) {
        try {
          // Call /auth/me to validate token and get fresh user data
          const { data } = await authService.me();
          // Note: /auth/me returns UserResponse directly, NOT wrapped in { user: {...} }
          setUser(data);
          // Update user in localStorage with fresh data
          authUtils.setAuth(data, token, authUtils.getRefreshToken());
        } catch (error) {
          // Token validation failed - this is expected when token expires
          // Only log if it's not a 401 error
          if (error.response?.status !== 401) {
            console.error('Token validation failed:', error);
          }
          // Token is invalid - clear auth
          authUtils.clearAuth();
          setUser(null);
        }
      } else {
        // No token - check if we have stored user (shouldn't happen)
        const storedUser = authUtils.getUser();
        if (storedUser) {
          console.warn('User found without token - clearing');
          authUtils.clearAuth();
        }
      }

      setLoading(false);
    };

    revalidateUser();
  }, []);

  const login = async (credentials) => {
    try {
      const { data } = await authService.login(credentials);
      const { user: userData, tokens } = data;

      authUtils.setAuth(userData, tokens.access_token, tokens.refresh_token);
      setUser(userData);

      return { success: true, user: userData };
    } catch (error) {
      console.error('Login failed:', error);
      const errorMessage = error.response?.data?.detail
        || error.response?.data?.message
        || 'Error al iniciar sesión';
      return { success: false, error: errorMessage };
    }
  };

  const logout = async () => {
    try {
      // Call backend logout endpoint
      await authService.logout();
    } catch (error) {
      console.error('Logout API call failed:', error);
      // Continue with local logout even if API fails
    } finally {
      authUtils.clearAuth();
      setUser(null);
    }
  };

  const isAuthenticated = () => {
    return !!authUtils.getAccessToken() && !!user;
  };

  const value = {
    user,
    loading,
    login,
    logout,
    isAuthenticated: isAuthenticated(),
  };

  return (
    <AuthContext.Provider value={value}>
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within AuthProvider');
  }
  return context;
};
