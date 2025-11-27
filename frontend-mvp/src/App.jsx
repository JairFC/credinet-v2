import { AuthProvider } from '@/app/providers/AuthProvider';
import AppRoutes from '@/app/routes';
import './App.css';

function App() {
  return (
    <AuthProvider>
      <AppRoutes />
    </AuthProvider>
  );
}

export default App;
