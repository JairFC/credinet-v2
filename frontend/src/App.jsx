import React from 'react';
import { Routes, Route, Navigate } from 'react-router-dom';
import { AuthProvider } from './context/AuthContext';
import { ThemeProvider } from './context/ThemeContext';
import LoginPage from './pages/LoginPage';
import DashboardPage from './pages/DashboardPage';
import AssociatesPage from './pages/AssociatesPage';
import CreateAssociatePage from './pages/CreateAssociatePage';
import NewAssociatePage from './pages/NewAssociatePage'; // ✨ NUEVO FORMULARIO SIMPLE
import EditAssociatePage from './pages/EditAssociatePage';
import AssociateLoansPage from './pages/AssociateLoansPage';
import UsersPage from './pages/UsersPage';
import CreateUserPage from './pages/CreateUserPage';
import ClientsViewPage from './pages/ClientsViewPage';
// 🚀 FRONTEND V2.0 - Clean Architecture
import CreateClientPageV2 from './pages/v2/CreateClientPageV2'; // ✨ FORMULARIO V2.0 CLEAN ARCHITECTURE
import TestPageV2 from './pages/v2/TestPageV2'; // 🧪 DEBUG PAGE
import ApiTestPageV2 from './pages/v2/ApiTestPageV2'; // 🧪 API DEBUG PAGE
import CreateClientPage from './pages/CreateClientPage'; // 🗑️ LEGACY - Solo como backup
import NewClientPage from './pages/NewClientPage'; // ✨ NUEVO FORMULARIO SIMPLE
import ClientDetailsPage from './pages/ClientDetailsPage';
import ClientDocumentsPage from './pages/ClientDocumentsPage';
import UserLoansPage from './pages/UserLoansPage';
import LoanDetailsPage from './pages/LoanDetailsPage';
import LoansPage from './pages/LoansPage';
import CreateLoanPage from './pages/CreateLoanPage';
import CriticalLoanForm from './components/CriticalLoanForm'; // ✨ NUEVO FORMULARIO CRÍTICO
import { PeriodsList, PeriodSummary } from './pages/Periods';
import ProtectedRoute from './components/ProtectedRoute';
import Navbar from './components/Navbar';
import Footer from './components/Footer';

function App() {
  return (
    <AuthProvider>
      <ThemeProvider>
        <div style={{ display: 'flex', flexDirection: 'column', minHeight: '100vh' }}>
          <Navbar />
          <main style={{ flex: 1, padding: '20px' }}>
            <Routes>
              <Route path="/" element={<Navigate to="/login" />} />
              <Route path="/login" element={<LoginPage />} />
              <Route path="/dashboard" element={<ProtectedRoute><DashboardPage /></ProtectedRoute>} />
              <Route path="/associates" element={<ProtectedRoute><AssociatesPage /></ProtectedRoute>} />
              <Route path="/associates/new" element={<ProtectedRoute><CreateAssociatePage /></ProtectedRoute>} /> {/* 🏆 FORMULARIO COMPLEJO ORIGINAL */}
              <Route path="/associates/simple" element={<ProtectedRoute><NewAssociatePage /></ProtectedRoute>} /> {/* ✨ FORMULARIO SIMPLE BACKUP */}
              <Route path="/associates/edit/:id" element={<ProtectedRoute><EditAssociatePage /></ProtectedRoute>} />
              <Route path="/associates/:associateId/loans" element={<ProtectedRoute><AssociateLoansPage /></ProtectedRoute>} />
              <Route path="/users" element={<ProtectedRoute><UsersPage /></ProtectedRoute>} />
              <Route path="/users/new" element={<ProtectedRoute><CreateUserPage /></ProtectedRoute>} />
              <Route path="/clients" element={<ProtectedRoute><ClientsViewPage /></ProtectedRoute>} />
              <Route path="/clients/test" element={<ProtectedRoute><TestPageV2 /></ProtectedRoute>} /> {/* 🧪 DEBUG FRONTEND V2.0 */}
              <Route path="/clients/api-test" element={<ProtectedRoute><ApiTestPageV2 /></ProtectedRoute>} /> {/* 🧪 API DEBUG V2.0 */}
              <Route path="/clients/new" element={<ProtectedRoute><CreateClientPageV2 /></ProtectedRoute>} /> {/* 🚀 FORMULARIO V2.0 CLEAN ARCHITECTURE */}
              <Route path="/clients/legacy" element={<ProtectedRoute><CreateClientPage /></ProtectedRoute>} /> {/* 🗑️ LEGACY BACKUP */}
              <Route path="/clients/simple" element={<ProtectedRoute><NewClientPage /></ProtectedRoute>} /> {/* ✨ FORMULARIO SIMPLE BACKUP */}
              <Route path="/clients/:id" element={<ProtectedRoute><ClientDetailsPage /></ProtectedRoute>} />
              <Route path="/clients/:id/documents" element={<ProtectedRoute><ClientDocumentsPage /></ProtectedRoute>} />
              <Route path="/users/:userId/loans" element={<ProtectedRoute><UserLoansPage /></ProtectedRoute>} />
              <Route path="/users/:userId/loans" element={<ProtectedRoute><UserLoansPage /></ProtectedRoute>} />
              <Route path="/loans" element={<ProtectedRoute><LoansPage /></ProtectedRoute>} />
              <Route path="/loans/new" element={<ProtectedRoute><CreateLoanPage /></ProtectedRoute>} />
              <Route path="/loans/critical" element={<ProtectedRoute><CriticalLoanForm /></ProtectedRoute>} /> {/* 🎯 FORMULARIO CRÍTICO */}
              <Route path="/loans/:loanId" element={<ProtectedRoute><LoanDetailsPage /></ProtectedRoute>} />
              <Route path="/admin/periods" element={<ProtectedRoute><PeriodsList /></ProtectedRoute>} />
              <Route path="/admin/periods/:periodId/summary" element={<ProtectedRoute><PeriodSummary /></ProtectedRoute>} />
            </Routes>
          </main>
          <Footer />
        </div>
      </ThemeProvider>
    </AuthProvider>
  );
}

export default App;
