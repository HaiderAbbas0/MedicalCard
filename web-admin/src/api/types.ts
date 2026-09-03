// Shared API types — mirror the backend's response shapes.

export type Role = 'patient' | 'doctor' | 'lab_worker' | 'receptionist' | 'admin';
export type AccountStatus = 'active' | 'pending' | 'suspended' | 'rejected';

export interface Profile {
  id: string;
  /** 13-digit CNIC — citizen identity (P-FR-001/005). */
  cnic: string | null;
  /** 16-digit Hayaat number printed on the health card. */
  card_number: string;
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
  cnic: string | null;
  card_number: string;
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

export type DeletionStatus = 'pending' | 'processing' | 'completed' | 'rejected' | 'failed';

export interface DeletionRequest {
  id: string;
  user_id: string | null;
  reason: string | null;
  status: DeletionStatus;
  note: string | null;
  requested_at: string;
  processed_at: string | null;
  processed_by: string | null;
  full_name: string | null;
  card_number: string | null;
}

export interface AppNotification {
  id: string;
  recipient_id: string;
  type: string;
  title: string;
  body: string | null;
  is_read: boolean;
  resource_id: string | null;
  created_at: string;
}

export type CardStatus = 'virtual' | 'physical_requested' | 'delivered';

export interface CardDelivery {
  id: string;
  profile_id: string;
  card_number: string;
  name_en: string | null;
  status: CardStatus;
  delivery_address: string | null;
  delivery_phone: string | null;
  delivery_fee_pkr: number | null;
  updated_at: string;
  full_name: string | null;
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
