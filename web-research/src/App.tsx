import { lazy, Suspense } from 'react';
import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom';
import { AuthProvider, useAuth } from './auth/AuthContext';
import { ErrorBoundary } from './components/ErrorBoundary';
import { Layout } from './components/Layout';
import { ToastProvider } from './components/Toast';
import { Spinner } from './components/ui';
import LoginPage from './pages/LoginPage';

const CohortExplorerPage = lazy(() => import('./pages/CohortExplorerPage'));
const CatalogPage = lazy(() => import('./pages/CatalogPage'));
const RequestsPage = lazy(() => import('./pages/RequestsPage'));
const DownloadsPage = lazy(() => import('./pages/DownloadsPage'));
const CompliancePage = lazy(() => import('./pages/CompliancePage'));

function ProtectedRoutes() {
  const { user, loading } = useAuth();
  if (loading) return <Spinner />;
  if (!user) return <Navigate to="/login" replace />;
  return (
    <Routes>
      <Route element={<Layout />}>
        <Route path="/cohorts" element={<CohortExplorerPage />} />
        <Route path="/catalog" element={<CatalogPage />} />
        <Route path="/requests" element={<RequestsPage />} />
        <Route path="/downloads" element={<DownloadsPage />} />
        <Route path="/compliance" element={<CompliancePage />} />
        <Route path="*" element={<Navigate to="/cohorts" replace />} />
      </Route>
    </Routes>
  );
}

function LoginRoute() {
  const { user, loading } = useAuth();
  if (loading) return <Spinner />;
  if (user) return <Navigate to="/cohorts" replace />;
  return <LoginPage />;
}

export default function App() {
  return (
    <BrowserRouter>
      <ToastProvider>
        <AuthProvider>
          <ErrorBoundary>
            <Suspense fallback={<Spinner />}>
              <Routes>
                <Route path="/login" element={<LoginRoute />} />
                <Route path="/*" element={<ProtectedRoutes />} />
              </Routes>
            </Suspense>
          </ErrorBoundary>
        </AuthProvider>
      </ToastProvider>
    </BrowserRouter>
  );
}
