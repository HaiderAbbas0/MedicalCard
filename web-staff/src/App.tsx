import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom';
import { AuthProvider, useAuth } from './auth/AuthContext';
import { Spinner } from './components/ui';
import StaffLayout from './components/StaffLayout';
import LoginPage from './pages/LoginPage';
import DoctorRegisterPage from './pages/DoctorRegisterPage';
// Doctor
import AppointmentsPage from './pages/doctor/AppointmentsPage';
import PatientLookupPage from './pages/doctor/PatientLookupPage';
import PatientRecordPage from './pages/doctor/PatientRecordPage';
import NewEncounterPage from './pages/doctor/NewEncounterPage';
import LabReviewPage from './pages/doctor/LabReviewPage';
import AvailabilityPage from './pages/doctor/AvailabilityPage';
import DoctorProfilePage from './pages/doctor/DoctorProfilePage';
// Lab + Reception
import LabQueuePage from './pages/lab/LabQueuePage';
import SchedulePage from './pages/reception/SchedulePage';

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
