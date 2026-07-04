import { lazy, Suspense } from 'react';
import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom';
import { AuthProvider, useAuth } from './auth/AuthContext';
import { Spinner } from './components/ui';
import ErrorBoundary from './components/ErrorBoundary';
import StaffLayout from './components/StaffLayout';
import LoginPage from './pages/LoginPage';

const DoctorRegisterPage = lazy(() => import('./pages/DoctorRegisterPage'));
// Doctor
const AppointmentsPage = lazy(() => import('./pages/doctor/AppointmentsPage'));
const PatientLookupPage = lazy(() => import('./pages/doctor/PatientLookupPage'));
const PatientRecordPage = lazy(() => import('./pages/doctor/PatientRecordPage'));
const NewEncounterPage = lazy(() => import('./pages/doctor/NewEncounterPage'));
const LabReviewPage = lazy(() => import('./pages/doctor/LabReviewPage'));
const MessagesPage = lazy(() => import('./pages/doctor/MessagesPage'));
const AvailabilityPage = lazy(() => import('./pages/doctor/AvailabilityPage'));
const DoctorProfilePage = lazy(() => import('./pages/doctor/DoctorProfilePage'));
// Lab + Reception
const LabQueuePage = lazy(() => import('./pages/lab/LabQueuePage'));
const SchedulePage = lazy(() => import('./pages/reception/SchedulePage'));
const PrivacyPolicyPage = lazy(() => import('./pages/legal/PrivacyPolicyPage'));
const TermsPage = lazy(() => import('./pages/legal/TermsPage'));

function homeFor(role: string) {
  if (role === 'lab_worker') return '/lab';
  if (role === 'receptionist') return '/reception';
  return '/doctor';
}

function DoctorRoutes() {
  return (
    <Route element={<StaffLayout />}>
      <Route path="/doctor" element={<AppointmentsPage />} />
      <Route path="/doctor/patients" element={<PatientLookupPage />} />
      <Route path="/doctor/patient/:id" element={<PatientRecordPage />} />
      <Route path="/doctor/patient/:id/encounter" element={<NewEncounterPage />} />
      <Route path="/doctor/lab-results" element={<LabReviewPage />} />
      <Route path="/doctor/messages" element={<MessagesPage />} />
      <Route path="/doctor/availability" element={<AvailabilityPage />} />
      <Route path="/doctor/profile" element={<DoctorProfilePage />} />
    </Route>
  );
}

function ProtectedRoutes() {
  const { user, loading } = useAuth();
  if (loading) return <Spinner />;
  if (!user) return <Navigate to="/login" replace />;
  const home = homeFor(user.role);
  return (
    <Routes>
      {DoctorRoutes()}
      <Route element={<StaffLayout />}>
        <Route path="/lab" element={<LabQueuePage />} />
        <Route path="/reception" element={<SchedulePage />} />
      </Route>
      <Route path="*" element={<Navigate to={home} replace />} />
    </Routes>
  );
}

function Root() {
  const { user, loading } = useAuth();
  return (
    <Routes>
      <Route
        path="/login"
        element={loading ? <Spinner /> : user ? <Navigate to={homeFor(user.role)} replace /> : <LoginPage />}
      />
      <Route path="/register-doctor" element={<DoctorRegisterPage />} />
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
