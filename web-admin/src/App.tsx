import { lazy, Suspense } from 'react';
import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom';
import { AuthProvider, useAuth } from './auth/AuthContext';
import { Spinner } from './components/ui';
import ErrorBoundary from './components/ErrorBoundary';
import Layout from './components/Layout';
import LoginPage from './pages/LoginPage';

const DashboardPage = lazy(() => import('./pages/DashboardPage'));
const DoctorApplicationsPage = lazy(() => import('./pages/DoctorApplicationsPage'));
const LabApplicationsPage = lazy(() => import('./pages/LabApplicationsPage'));
const UsersPage = lazy(() => import('./pages/UsersPage'));
const ClinicsPage = lazy(() => import('./pages/ClinicsPage'));
const CardDeliveriesPage = lazy(() => import('./pages/CardDeliveriesPage'));
const AuditLogPage = lazy(() => import('./pages/AuditLogPage'));
const DeletionRequestsPage = lazy(() => import('./pages/DeletionRequestsPage'));
const PrivacyPolicyPage = lazy(() => import('./pages/legal/PrivacyPolicyPage'));
const TermsPage = lazy(() => import('./pages/legal/TermsPage'));

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
        <ErrorBoundary>
          <Suspense fallback={<Spinner />}>
            <Root />
          </Suspense>
        </ErrorBoundary>
      </AuthProvider>
    </BrowserRouter>
  );
}
