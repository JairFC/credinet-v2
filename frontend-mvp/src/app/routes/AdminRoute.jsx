import { Navigate } from 'react-router-dom';
import { useAuth } from '@/app/providers/AuthProvider';

/**
 * AdminRoute - Protects routes that require admin role
 * 
 * Usage:
 *   <AdminRoute>
 *     <SomeAdminComponent />
 *   </AdminRoute>
 * 
 * In the future, you can create similar components for:
 * - ClientRoute (for client-specific pages)
 * - AssociateRoute (for associate-specific pages)
 */
const AdminRoute = ({ children }) => {
  const { user, isAuthenticated, loading } = useAuth();

  if (loading) {
    return (
      <div style={{
        display: 'flex',
        justifyContent: 'center',
        alignItems: 'center',
        height: '100vh'
      }}>
        <div>Cargando...</div>
      </div>
    );
  }

  // First check if user is authenticated
  if (!isAuthenticated) {
    return <Navigate to="/login" replace />;
  }

  // Then check if user has admin role
  const userRoles = user?.roles || [];
  const hasAdminAccess = userRoles.some(role =>
    role === 'admin' ||
    role === 'desarrollador' ||
    role === 'administrador'
  );

  if (!hasAdminAccess) {
    // Redirect to unauthorized page or dashboard
    return (
      <div style={{
        display: 'flex',
        flexDirection: 'column',
        justifyContent: 'center',
        alignItems: 'center',
        height: '100vh',
        textAlign: 'center',
        padding: '20px'
      }}>
        <h1>🚫 Acceso Denegado</h1>
        <p>No tienes permisos de administrador para acceder a esta página.</p>
        <p>Rol actual: {userRoles.join(', ') || 'Sin rol asignado'}</p>
        <button
          onClick={() => window.location.href = '/dashboard'}
          style={{
            marginTop: '20px',
            padding: '10px 20px',
            fontSize: '16px',
            cursor: 'pointer'
          }}
        >
          Volver al Dashboard
        </button>
      </div>
    );
  }

  return children;
};

export default AdminRoute;
