import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import PrivateRoute from './PrivateRoute';
import AdminRoute from './AdminRoute';
import LoginPage from "../../features/auth/pages/LoginPage";
import DashboardPage from "../../features/dashboard/pages/DashboardPage";
import LoansPage from "../../features/loans/pages/LoansPage";
import LoanCreatePage from "../../features/loans/pages/LoanCreatePage";
import LoanDetailPage from "../../features/loans/pages/LoanDetailPage";
import SimuladorPrestamosPage from "../../features/loans/pages/SimuladorPrestamosPage";
import PaymentsPage from "../../features/payments/pages/PaymentsPage";
import EstadosCuentaPage from "../../features/statements/pages/EstadosCuentaPage";
import StatementDetailPage from "../../features/statements/pages/StatementDetailPage";
import AssociateDetailPage from "../../features/associates/pages/AssociateDetailPage";

// Users Module - Separated by role
import ClientsPage from "../../features/users/clients/pages/ClientsPage";
import ClientCreatePage from "../../features/users/clients/pages/ClientCreatePage";
import ClientDetailPage from "../../features/users/clients/pages/ClientDetailPage";
import AssociatesManagementPage from "../../features/users/associates/pages/AssociatesManagementPage";
import AssociateCreatePage from "../../features/users/associates/pages/AssociateCreatePage";

// Agreements Module (Convenios y Reportes de Morosos)
import { AgreementsPage, DefaultedReportsPage, CreateDefaultedReportPage, CreateAgreementPage, AgreementDetailPage, NuevoConvenioPage } from "../../features/agreements";

// Notifications Module
import { NotificationsPage } from "../../features/notifications";

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
            <AdminRoute>
              <MainLayout>
                <DashboardPage />
              </MainLayout>
            </AdminRoute>
          }
        />

        <Route
          path="/prestamos"
          element={
            <AdminRoute>
              <MainLayout>
                <LoansPage />
              </MainLayout>
            </AdminRoute>
          }
        />

        <Route
          path="/prestamos/nuevo"
          element={
            <AdminRoute>
              <MainLayout>
                <LoanCreatePage />
              </MainLayout>
            </AdminRoute>
          }
        />

        <Route
          path="/prestamos/:id"
          element={
            <AdminRoute>
              <MainLayout>
                <LoanDetailPage />
              </MainLayout>
            </AdminRoute>
          }
        />

        <Route
          path="/prestamos/simulador"
          element={
            <AdminRoute>
              <MainLayout>
                <SimuladorPrestamosPage />
              </MainLayout>
            </AdminRoute>
          }
        />

        <Route
          path="/pagos"
          element={
            <AdminRoute>
              <MainLayout>
                <PaymentsPage />
              </MainLayout>
            </AdminRoute>
          }
        />

        <Route
          path="/estados-cuenta"
          element={
            <AdminRoute>
              <MainLayout>
                <EstadosCuentaPage />
              </MainLayout>
            </AdminRoute>
          }
        />

        <Route
          path="/estados-cuenta/:statementId"
          element={
            <AdminRoute>
              <MainLayout>
                <StatementDetailPage />
              </MainLayout>
            </AdminRoute>
          }
        />

        <Route
          path="/asociados/:associateId"
          element={
            <AdminRoute>
              <MainLayout>
                <AssociateDetailPage />
              </MainLayout>
            </AdminRoute>
          }
        />

        {/* ====== USERS MODULE - SEPARATED BY ROLE ====== */}

        {/* Clients (Usuarios que solicitan préstamos) */}
        <Route
          path="/usuarios/clientes"
          element={
            <AdminRoute>
              <MainLayout>
                <ClientsPage />
              </MainLayout>
            </AdminRoute>
          }
        />

        <Route
          path="/usuarios/clientes/nuevo"
          element={
            <AdminRoute>
              <MainLayout>
                <ClientCreatePage />
              </MainLayout>
            </AdminRoute>
          }
        />

        <Route
          path="/usuarios/clientes/:clientId"
          element={
            <AdminRoute>
              <MainLayout>
                <ClientDetailPage />
              </MainLayout>
            </AdminRoute>
          }
        />

        {/* Associates Management (Gestión de asociados que prestan dinero) */}
        <Route
          path="/usuarios/asociados"
          element={
            <AdminRoute>
              <MainLayout>
                <AssociatesManagementPage />
              </MainLayout>
            </AdminRoute>
          }
        />

        <Route
          path="/usuarios/asociados/nuevo"
          element={
            <AdminRoute>
              <MainLayout>
                <AssociateCreatePage />
              </MainLayout>
            </AdminRoute>
          }
        />

        {/* ====== AGREEMENTS MODULE (Convenios y Morosos) ====== */}
        
        {/* Lista de convenios */}
        <Route
          path="/convenios"
          element={
            <AdminRoute>
              <MainLayout>
                <AgreementsPage />
              </MainLayout>
            </AdminRoute>
          }
        />

        {/* Lista de reportes de morosos */}
        <Route
          path="/convenios/reportes"
          element={
            <AdminRoute>
              <MainLayout>
                <DefaultedReportsPage />
              </MainLayout>
            </AdminRoute>
          }
        />

        {/* Crear nuevo reporte de moroso */}
        <Route
          path="/convenios/nuevo-reporte"
          element={
            <AdminRoute>
              <MainLayout>
                <CreateDefaultedReportPage />
              </MainLayout>
            </AdminRoute>
          }
        />

        {/* Crear nuevo convenio (desde préstamos activos) */}
        <Route
          path="/convenios/nuevo"
          element={
            <AdminRoute>
              <MainLayout>
                <NuevoConvenioPage />
              </MainLayout>
            </AdminRoute>
          }
        />

        {/* Detalle de convenio */}
        <Route
          path="/convenios/:agreementId"
          element={
            <AdminRoute>
              <MainLayout>
                <AgreementDetailPage />
              </MainLayout>
            </AdminRoute>
          }
        />

        {/* Notificaciones */}
        <Route
          path="/notificaciones"
          element={
            <AdminRoute>
              <MainLayout>
                <NotificationsPage />
              </MainLayout>
            </AdminRoute>
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
