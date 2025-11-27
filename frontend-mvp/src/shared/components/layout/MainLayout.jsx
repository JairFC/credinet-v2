import Navbar from './Navbar';
import './MainLayout.css';

const MainLayout = ({ children }) => {
  return (
    <div className="main-layout">
      <Navbar />
      <main className="main-content">
        {children}
      </main>
      <footer className="main-footer">
        <p>© 2025 CrediNet V2 - Sistema de Gestión de Préstamos</p>
      </footer>
    </div>
  );
};

export default MainLayout;
