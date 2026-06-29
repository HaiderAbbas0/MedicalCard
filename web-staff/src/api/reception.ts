// Receptionist-facing API calls (Scope §11.5).

import { api } from './client';
import type { ClinicAppointment, ClinicDoctor } from './types';

export const receptionApi = {
  appointments: (date?: string) =>
    api.get<ClinicAppointment[]>(`/clinic/appointments${date ? `?date=${date}` : ''}`),
  doctors: () => api.get<ClinicDoctor[]>('/clinic/doctors'),
  searchPatient: (cnic: string) =>
    api.get<{ id: string; full_name: string; cnic: string; phone_primary: string }>(`/patients/search?cnic=${cnic}`),
  book: (body: Record<string, unknown>) => api.post('/appointments', body),
  checkIn: (id: string) => api.patch(`/appointments/${id}/check-in`),
  cancel: (id: string, reason?: string) => api.patch(`/appointments/${id}/cancel`, { reason }),
};
