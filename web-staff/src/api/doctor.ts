// Doctor-facing API calls (Scope §11.3).

import { api } from './client';
import type { Appointment, AvailabilitySlot, Encounter, LabOrderForReview, PatientSummary } from './types';

export const doctorApi = {
  appointments: (date?: string) => api.get<Appointment[]>(`/doctor/appointments${date ? `?date=${date}` : ''}`),
  confirmAppointment: (id: string) => api.patch(`/appointments/${id}/confirm`),
  checkInAppointment: (id: string) => api.patch(`/appointments/${id}/check-in`),
  noShowAppointment: (id: string) => api.patch(`/appointments/${id}/no-show`),

  searchPatient: (cnic: string) => api.get<PatientSummary>(`/patients/search?cnic=${cnic}`),
  patient: (id: string) => api.get<PatientSummary>(`/patients/${id}`),
  timeline: (id: string) => api.get<{ items: Encounter[]; total: number }>(`/patients/${id}/timeline`),
  medications: (id: string) => api.get<Record<string, unknown>[]>(`/patients/${id}/medications`),
  recordAllergy: (id: string, body: Record<string, unknown>) => api.post(`/patients/${id}/allergies`, body),

  createEncounter: (patientId: string, chiefComplaint?: string) =>
    api.post<Encounter>('/encounters', { patient_id: patientId, chief_complaint: chiefComplaint }),
  updateEncounter: (id: string, patch: Record<string, unknown>) => api.patch(`/encounters/${id}`, patch),
  addCondition: (id: string, body: Record<string, unknown>) => api.post(`/encounters/${id}/conditions`, body),
  addMedication: (id: string, body: Record<string, unknown>) =>
    api.post<{ medication: Record<string, unknown>; allergy_warning: string | null }>(`/encounters/${id}/medications`, body),
  addVital: (id: string, body: Record<string, unknown>) => api.post(`/encounters/${id}/vitals`, body),
  addLabOrder: (id: string, body: Record<string, unknown>) => api.post(`/encounters/${id}/lab-orders`, body),
  finalizeEncounter: (id: string) => api.post<Encounter>(`/encounters/${id}/finalize`),

  labs: () => api.get<{ id: string; name: string }[]>('/labs'),
  labOrdersForReview: () => api.get<LabOrderForReview[]>('/doctor/lab-orders'),
  reviewLabOrder: (id: string) => api.patch(`/lab-orders/${id}/review`),
  releaseLabOrder: (id: string) => api.patch(`/lab-orders/${id}/release`),

  availability: () => api.get<AvailabilitySlot[]>('/doctor/availability'),
  addAvailability: (body: Record<string, unknown>) => api.post<AvailabilitySlot>('/doctor/availability', body),
  deleteAvailability: (id: string) => api.del(`/doctor/availability/${id}`),

  updateProfile: (patch: Record<string, unknown>) => api.patch('/me', patch),
};
