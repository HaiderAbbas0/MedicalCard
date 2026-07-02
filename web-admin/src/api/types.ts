// Shared API types — mirror the backend's response shapes.

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
  status_reason?: string | null;
  created_at: string;
  extended?: Record<string, unknown>;
}

export interface AuthResponse {
  token: string;
  user: Profile;
}

export interface DoctorApplication {
  id: string;
  full_name: string;
  cnic: string;
  email: string | null;
  phone_primary: string;
  status: AccountStatus;
  created_at: string;
  pmdc_number: string;
  specialization_primary: string;
  qualification_mbbs?: boolean;
  qualification_md?: boolean;
  qualification_fcps?: boolean;
  years_of_experience?: number | null;
  clinic?: Clinic | null;
}

export interface Lab {
  id: string;
  name: string;
  license_number: string;
  phone: string;
  address_city: string;
  address_province: string;
  status: AccountStatus;
}

export interface Clinic {
  id: string;
  name: string;
  type: string;
  phone?: string | null;
  address_city?: string | null;
  address_province?: string | null;
  status: string;
}

export interface DashboardStats {
  total_patients: number;
  approved_doctors: number;
  pending_doctor_applications: number;
  pending_lab_applications: number;
  appointments_today: number;
  pending_lab_orders: number;
  total_clinics: number;
  total_labs: number;
}

export interface AuditEntry {
  id: string;
  actor_id: string | null;
  actor_name: string;
  actor_role: string | null;
  action: string;
  resource_type: string | null;
  resource_id: string | null;
  status: string;
  timestamp: string;
}
