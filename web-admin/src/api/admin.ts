import { supabase } from './supabase';
import type { Clinic, DashboardStats, DoctorApplication, Lab, Profile, AuditEntry } from './types';

// eslint-disable-next-line @typescript-eslint/no-explicit-any
type Q = any;

async function rows<T>(builder: Q): Promise<T[]> {
  const { data, error } = await builder;
  if (error) throw new Error(error.message);
  return (data ?? []) as T[];
}

async function count(table: string, build?: (q: Q) => Q): Promise<number> {
  let q: Q = supabase.from(table).select('*', { count: 'exact', head: true });
  if (build) q = build(q);
  const { count: n, error } = await q;
  if (error) throw new Error(error.message);
  return n ?? 0;
}

export const adminApi = {
  async dashboard(): Promise<DashboardStats> {
    const today = new Date().toISOString().slice(0, 10);
    const [patients, doctors, pendingDocs, pendingLabs, apptsToday, pendingOrders, clinics, labs] = await Promise.all([
      count('profiles', (q) => q.eq('role', 'patient')),
      count('profiles', (q) => q.eq('role', 'doctor').eq('status', 'active')),
      count('profiles', (q) => q.eq('role', 'doctor').eq('status', 'pending')),
      count('diagnostic_labs', (q) => q.eq('status', 'pending')),
      count('appointments', (q) => q.eq('appointment_date', today)),
      count('lab_orders', (q) => q.in('status', ['ordered', 'sample_collected', 'processing', 'resulted', 'reviewed'])),
      count('clinics'),
      count('diagnostic_labs'),
    ]);
    return {
      total_patients: patients,
      approved_doctors: doctors,
      pending_doctor_applications: pendingDocs,
      pending_lab_applications: pendingLabs,
      appointments_today: apptsToday,
      pending_lab_orders: pendingOrders,
      total_clinics: clinics,
      total_labs: labs,
    };
  },

  async doctorApplications(status = 'pending'): Promise<DoctorApplication[]> {
    const data = await rows<Q>(
      supabase.from('doctor_profiles').select(
        '*, profiles!id(id, full_name, cnic, email, phone_primary, status, created_at), clinics(name)',
      ),
    );
    return data
      .filter((r) => r.profiles?.status === status)
      .map((r) => ({
        id: r.profiles.id,
        full_name: r.profiles.full_name,
        cnic: r.profiles.cnic,
        email: r.profiles.email,
        phone_primary: r.profiles.phone_primary,
        status: r.profiles.status,
        created_at: r.profiles.created_at,
        pmdc_number: r.pmdc_number,
        specialization_primary: r.specialization_primary,
        qualification_mbbs: r.qualification_mbbs,
        qualification_md: r.qualification_md,
        qualification_fcps: r.qualification_fcps,
        years_of_experience: r.years_of_experience,
        clinic: r.clinics ? { id: '', name: r.clinics.name, type: '', status: 'active' } : null,
      }));
  },

  async approveDoctor(id: string): Promise<void> {
    let { error } = await supabase.from('profiles').update({ status: 'active', status_reason: 'Approved by admin' }).eq('id', id);
    if (error) throw new Error(error.message);
    await supabase.from('doctor_profiles').update({ approved_at: new Date().toISOString() }).eq('id', id);
    await supabase.from('notifications').insert({
      recipient_id: id, type: 'doctor_approved', title: 'Account approved',
      body: 'Your doctor account has been approved. You can now log in.',
    });
  },

  async rejectDoctor(id: string, reason: string): Promise<void> {
    const { error } = await supabase.from('profiles').update({ status: 'rejected', status_reason: reason }).eq('id', id);
    if (error) throw new Error(error.message);
    await supabase.from('notifications').insert({
      recipient_id: id, type: 'doctor_rejected', title: 'Application rejected',
      body: 'Your doctor registration was not approved.',
    });
  },

  labApplications(status = 'pending'): Promise<Lab[]> {
    return rows<Lab>(supabase.from('diagnostic_labs').select('*').eq('status', status));
  },
  async approveLab(id: string): Promise<void> {
    const { error } = await supabase.from('diagnostic_labs').update({ status: 'active' }).eq('id', id);
    if (error) throw new Error(error.message);
  },
  async rejectLab(id: string): Promise<void> {
    const { error } = await supabase.from('diagnostic_labs').update({ status: 'suspended' }).eq('id', id);
    if (error) throw new Error(error.message);
  },

  users(filters: { role?: string; status?: string; q?: string }): Promise<Profile[]> {
    let query: Q = supabase.from('profiles').select('*').order('created_at', { ascending: false });
    if (filters.role) query = query.eq('role', filters.role);
    if (filters.status) query = query.eq('status', filters.status);
    if (filters.q) query = query.or(`full_name.ilike.%${filters.q}%,cnic.ilike.%${filters.q}%`);
    return rows<Profile>(query);
  },
  async suspendUser(id: string, reason: string): Promise<void> {
    const { error } = await supabase.from('profiles').update({ status: 'suspended', status_reason: reason }).eq('id', id);
    if (error) throw new Error(error.message);
  },
  async reactivateUser(id: string): Promise<void> {
    const { error } = await supabase.from('profiles').update({ status: 'active', status_reason: 'Reactivated by admin' }).eq('id', id);
    if (error) throw new Error(error.message);
  },

  clinics(): Promise<Clinic[]> {
    return rows<Clinic>(supabase.from('clinics').select('*').order('name'));
  },
  async createClinic(body: Record<string, unknown>): Promise<void> {
    const { error } = await supabase.from('clinics').insert({ ...body, status: 'active' });
    if (error) throw new Error(error.message);
  },
  labs(): Promise<Lab[]> {
    return rows<Lab>(supabase.from('diagnostic_labs').select('*').order('name'));
  },

  async auditLogs(limit = 200): Promise<AuditEntry[]> {
    const data = await rows<Q>(
      supabase.from('audit_logs').select('*, actor:profiles!actor_id(full_name)').order('timestamp', { ascending: false }).limit(limit),
    );
    return data.map((l) => ({ ...l, actor_name: l.actor?.full_name ?? 'System' })) as AuditEntry[];
  },

  /** Create a staff/admin account via the admin-create-user Edge Function. */
  async createStaff(role: string, body: Record<string, unknown>): Promise<void> {
    const { error } = await supabase.functions.invoke('admin-create-user', { body: { role, ...body } });
    if (error) throw new Error(error.message || 'Account creation needs the admin-create-user Edge Function (see supabase/functions).');
  },
};
