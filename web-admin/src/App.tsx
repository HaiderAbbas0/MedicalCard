import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom';
import { AuthProvider, useAuth } from './auth/AuthContext';
import { Spinner } from './components/ui';
import Layout from './components/Layout';
import LoginPage from './pages/LoginPage';
import DashboardPage from './pages/DashboardPage';
import DoctorApplicationsPage from './pages/DoctorApplicationsPage';
import LabApplicationsPage from './pages/LabApplicationsPage';
import UsersPage from './pages/UsersPage';
import ClinicsPage from './pages/ClinicsPage';
import CardDeliveriesPage from './pages/CardDeliveriesPage';
import AuditLogPage from './pages/AuditLogPage';
import DeletionRequestsPage from './pages/DeletionRequestsPage';
import PrivacyPolicyPage from './pages/legal/PrivacyPolicyPage';
import TermsPage from './pages/legal/TermsPage';

function ProtectedRoutes() {
  const { user, loading } = useAuth();
  if (loading) return <Spinner />;
  if (!user) return <Navigate to="/login" replace />;
  return (
    <Routes>
      <Route element={<Layout />}>
        <Route path="/dashboard" element={<DashboardPage />} />
        <Route path="/doctor-applications" element={<DoctorApplicationsPage />} />
        <Route path="/lab-applications" element={<LabApplicationsPage />} />
        <Route path="/users" element={<UsersPage />} />
        <Route path="/clinics" element={<ClinicsPage />} />
        <Route path="/card-deliveries" element={<CardDeliveriesPage />} />
        <Route path="/deletion-requests" element={<DeletionRequestsPage />} />
        <Route path="/audit" element={<AuditLogPage />} />
        <Route path="*" element={<Navigate to="/dashboard" replace />} />
      </Route>
    </Routes>
  );
}

function Root() {
  const { user, loading } = useAuth();
  return (
    <Routes>
      <Route
        path="/login"
        element={loading ? <Spinner /> : user ? <Navigate to="/dashboard" replace /> : <LoginPage />}
      />
      <Route path="/legal/privacy" element={<PrivacyPolicyPage />} />
      <Route path="/legal/terms" element={<TermsPage />} />
      <Route path="/*" element={<ProtectedRoutes />} />
    </Routes>
  );
}

export default function App() {
  return (
    <BrowserRouter>
      <AuthProvider>
        <Root />
      </AuthProvider>
    </BrowserRouter>
  );
}
