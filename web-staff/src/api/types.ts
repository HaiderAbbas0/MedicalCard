// Shared API types for the staff portal.

export type Role = 'patient' | 'doctor' | 'lab_worker' | 'receptionist' | 'admin';
export type AccountStatus = 'active' | 'pending' | 'suspended' | 'rejected';

export interface Profile {
  id: string;
  cnic: string;
  full_name: string;
  email: string | null;
  phone_primary: string;
  role: Role;
  status: AccountStatus;
  created_at: string;
  extended?: Record<string, unknown>;
}

export interface AuthResponse {
  token: string;
  user: Profile;
}

// ── Doctor ────────────────────────────────────────────────────────────────────
export interface Appointment {
  id: string;
  status: string;
  appointment_date: string;
  appointment_time: string;
  appointment_type: string;
  notes_for_doctor?: string | null;
  doctor_name?: string | null;
  patient?: PatientSummary | null;
}

export interface PatientSummary {
  id: string;
  full_name: string;
  cnic: string;
  gender?: string;
  date_of_birth?: string;
  blood_group?: string;
  active_conditions?: Record<string, unknown>[];
  allergies?: Record<string, unknown>[];
}

export interface Encounter {
  id: string;
  encounter_date: string;
  doctor_name?: string;
  chief_complaint?: string | null;
  assessment?: string | null;
  status: string;
  conditions?: Record<string, unknown>[];
  medications?: Record<string, unknown>[];
  observations?: Record<string, unknown>[];
  lab_orders?: Record<string, unknown>[];
}

export interface LabOrderForReview {
  id: string;
  test_name: string;
  status: string;
  patient?: PatientSummary | null;
  result?: {
    structured_results?: { name?: string; value?: string; unit?: string }[] | null;
    comments?: string | null;
    result_file_name?: string | null;
    result_file_url?: string | null;
  } | null;
}

export interface AvailabilitySlot {
  id: string;
  day_of_week: number;
  start_time: string;
  end_time: string;
  slot_duration_minutes: number;
}

// ── Lab worker ────────────────────────────────────────────────────────────────
export interface LabQueueOrder {
  id: string;
  test_name: string;
  priority: string;
  status: string;
  clinical_indication?: string | null;
  special_instructions?: string | null;
  patient?: { display_name: string } | null;
}

// ── Receptionist ──────────────────────────────────────────────────────────────
export interface ClinicAppointment {
  id: string;
  status: string;
  appointment_date: string;
  appointment_time: string;
  appointment_type: string;
  doctor_name?: string | null;
  patient?: { id: string; full_name: string; cnic: string; phone_primary: string } | null;
}

export interface ClinicDoctor {
  id: string;
  full_name: string;
  specialization_primary: string;
}
