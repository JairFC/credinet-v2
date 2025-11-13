import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import PrivateRoute from './PrivateRoute';
import LoginPage from "../../features/auth/pages/LoginPage";
import DashboardPage from "../../features/dashboard/pages/DashboardPage";
import LoansPage from "../../features/loans/pages/LoansPage";
import LoanCreatePage from "../../features/loans/pages/LoanCreatePage";
import LoanDetailPage from "../../features/loans/pages/LoanDetailPage";
import PaymentsPage from "../../features/payments/pages/PaymentsPage";
import StatementsPage from "../../features/statements/pages/StatementsPage";
import AssociateDetailPage from "../../features/associates/pages/AssociateDetailPage";

// Users Module - Separated by role
import ClientsPage from "../../features/users/clients/pages/ClientsPage";
import ClientCreatePage from "../../features/users/clients/pages/ClientCreatePage";
import ClientDetailPage from "../../features/users/clients/pages/ClientDetailPage";
import AssociatesManagementPage from "../../features/users/associates/pages/AssociatesManagementPage";
import AssociateCreatePage from "../../features/users/associates/pages/AssociateCreatePage";

import MainLayout from '@/shared/components/layout/MainLayout';

const AppRoutes = () => {
  return (
    <BrowserRouter>
      <Routes>
        {/* Ruta pública */}
        <Route path="/login" element={<LoginPage />} />

        {/* Rutas privadas con layout */}
        <Route
          path="/dashboard"
          element={
            <PrivateRoute>
              <MainLayout>
                <DashboardPage />
              </MainLayout>
            </PrivateRoute>
          }
        />

        <Route
          path="/prestamos"
          element={
            <PrivateRoute>
              <MainLayout>
                <LoansPage />
              </MainLayout>
            </PrivateRoute>
          }
        />

        <Route
          path="/prestamos/nuevo"
          element={
            <PrivateRoute>
              <MainLayout>
                <LoanCreatePage />
              </MainLayout>
            </PrivateRoute>
          }
        />

        <Route
          path="/prestamos/:id"
          element={
            <PrivateRoute>
              <MainLayout>
                <LoanDetailPage />
              </MainLayout>
            </PrivateRoute>
          }
        />

        <Route
          path="/pagos"
          element={
            <PrivateRoute>
              <MainLayout>
                <PaymentsPage />
              </MainLayout>
            </PrivateRoute>
          }
        />

        <Route
          path="/estados-cuenta"
          element={
            <PrivateRoute>
              <MainLayout>
                <StatementsPage />
              </MainLayout>
            </PrivateRoute>
          }
        />

        <Route
          path="/asociados/:associateId"
          element={
            <PrivateRoute>
              <MainLayout>
                <AssociateDetailPage />
              </MainLayout>
            </PrivateRoute>
          }
        />

        {/* ====== USERS MODULE - SEPARATED BY ROLE ====== */}

        {/* Clients (Usuarios que solicitan préstamos) */}
        <Route
          path="/usuarios/clientes"
          element={
            <PrivateRoute>
              <MainLayout>
                <ClientsPage />
              </MainLayout>
            </PrivateRoute>
          }
        />

        <Route
          path="/usuarios/clientes/nuevo"
          element={
            <PrivateRoute>
              <MainLayout>
                <ClientCreatePage />
              </MainLayout>
            </PrivateRoute>
          }
        />

        <Route
          path="/usuarios/clientes/:clientId"
          element={
            <PrivateRoute>
              <MainLayout>
                <ClientDetailPage />
              </MainLayout>
            </PrivateRoute>
          }
        />

        {/* Associates Management (Gestión de asociados que prestan dinero) */}
        <Route
          path="/usuarios/asociados"
          element={
            <PrivateRoute>
              <MainLayout>
                <AssociatesManagementPage />
              </MainLayout>
            </PrivateRoute>
          }
        />

        <Route
          path="/usuarios/asociados/nuevo"
          element={
            <PrivateRoute>
              <MainLayout>
                <AssociateCreatePage />
              </MainLayout>
            </PrivateRoute>
          }
        />

        {/* Redirección por defecto */}
        <Route path="/" element={<Navigate to="/dashboard" replace />} />

        {/* 404 */}
        <Route path="*" element={<Navigate to="/dashboard" replace />} />
      </Routes>
    </BrowserRouter>
  );
};

export default AppRoutes;
