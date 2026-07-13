import { supabase } from './supabase';
import type { Clinic, DashboardStats, DoctorApplication, Lab, Profile, AuditEntry, DeletionRequest, DeletionStatus, CardDelivery, CardStatus } from './types';

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
        '*, profiles!id(id, full_name, card_number, email, phone_primary, status, created_at), clinics(name)',
      ),
    );
    return data
      .filter((r) => r.profiles?.status === status)
      .map((r) => ({
        id: r.profiles.id,
        full_name: r.profiles.full_name,
        card_number: r.profiles.card_number,
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
    if (filters.q) query = query.or(`full_name.ilike.%${filters.q}%,card_number.ilike.%${filters.q.replace(/\s/g, '')}%`);
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
  async createClinic(body: Record<string, unknown>): Promise<{ id: string }> {
    const { data, error } = await supabase
      .from('clinics')
      .insert({ ...body, status: 'active' })
      .select('id')
      .single();
    if (error) throw new Error(error.message);
    return data as { id: string };
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

  /** Account deletion requests, joined to the requesting user's profile, newest first. */
  async deletionRequests(): Promise<DeletionRequest[]> {
    const data = await rows<Q>(
      supabase
        .from('deletion_requests')
        .select('*, profiles!user_id(full_name, card_number)')
        .order('requested_at', { ascending: false }),
    );
    return data.map((r) => ({
      id: r.id,
      user_id: r.user_id,
      reason: r.reason,
      status: r.status,
      note: r.note,
      requested_at: r.requested_at,
      processed_at: r.processed_at,
      processed_by: r.processed_by,
      full_name: r.profiles?.full_name ?? null,
      card_number: r.profiles?.card_number ?? null,
    }));
  },

  /**
   * Record an admin decision on a deletion request. Sets status, an optional note,
   * and stamps processed_at/processed_by. NOTE: erasing the auth user + data is done
   * by the delete-account Edge Function, not from the browser.
   */
  async updateDeletionRequest(id: string, status: DeletionStatus, note: string): Promise<void> {
    const adminId = (await supabase.auth.getUser()).data.user?.id ?? null;
    const request = (await this.deletionRequests()).find((r) => r.id === id);
    if (!request) throw new Error('Deletion request not found.');

    if (status === 'completed') {
      if (!request.user_id) throw new Error('This request is no longer linked to a user account.');
      const { data: session } = await supabase.auth.getSession();
      const token = session?.session?.access_token;
      if (!token) throw new Error('You must be logged in as an admin.');

      const { error: processingError } = await supabase.rpc('admin_mark_deletion_request', {
        p_request_id: id,
        p_status: 'processing',
        p_note: note,
      });
      if (processingError) throw new Error(processingError.message);

      const url = `${import.meta.env.VITE_SUPABASE_URL ?? 'https://iikwdtiqvxxatrzahuzo.supabase.co'}/functions/v1/delete-account`;
      const res = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` },
        body: JSON.stringify({ user_id: request.user_id, request_id: id, note }),
      });
      const json = await res.json().catch(() => ({}));
      if (!res.ok) {
        const { error: failedMarkError } = await supabase.rpc('admin_mark_deletion_request', {
          p_request_id: id,
          p_status: 'failed',
          p_note: json?.message ?? `Delete account failed: ${res.status}`,
        });
        if (failedMarkError) console.warn('Failed to mark deletion request failed', failedMarkError.message);
        throw new Error(json?.message ?? `Delete account failed: ${res.status}`);
      }
      return;
    }

    const { error } = await supabase.rpc('admin_mark_deletion_request', {
      p_request_id: id,
      p_status: status,
      p_note: note.trim() || null,
    });
    if (error) {
      const { error: fallbackError } = await supabase
        .from('deletion_requests')
        .update({
          status,
          note: note.trim() || null,
          processed_at: status === 'rejected' ? new Date().toISOString() : null,
          processed_by: status === 'rejected' ? adminId : null,
        })
        .eq('id', id);
      if (fallbackError) throw new Error(fallbackError.message);
    }
  },

  /** Cards awaiting delivery (or optionally already delivered), joined to the owner profile. */
  async cardDeliveries(statuses: CardStatus[] = ['physical_requested']): Promise<CardDelivery[]> {
    const data = await rows<Q>(
      supabase
        .from('cards')
        .select('*, profiles!profile_id(full_name)')
        .in('status', statuses)
        .order('updated_at', { ascending: false }),
    );
    return data.map((c) => ({
      id: c.id,
      profile_id: c.profile_id,
      card_number: c.card_number,
      name_en: c.name_en,
      status: c.status,
      delivery_address: c.delivery_address,
      delivery_phone: c.delivery_phone,
      delivery_fee_pkr: c.delivery_fee_pkr,
      updated_at: c.updated_at,
      full_name: c.profiles?.full_name ?? null,
    }));
  },

  async markCardDelivered(id: string): Promise<void> {
    const { error } = await supabase
      .from('cards')
      .update({ status: 'delivered', updated_at: new Date().toISOString() })
      .eq('id', id);
    if (error) throw new Error(error.message);
  },

  /** Create a staff/admin account via the admin-create-user Edge Function. */
  async createStaff(role: string, body: Record<string, unknown>): Promise<void> {
    // Use raw fetch instead of supabase.functions.invoke to get real error messages.
    const { data: session } = await supabase.auth.getSession();
    const token = session?.session?.access_token;
    if (!token) throw new Error('You must be logged in as an admin to create accounts.');

    const url = `${import.meta.env.VITE_SUPABASE_URL ?? 'https://iikwdtiqvxxatrzahuzo.supabase.co'}/functions/v1/admin-create-user`;
    const res = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`,
      },
      body: JSON.stringify({ role, ...body }),
    });
    const json = await res.json().catch(() => ({}));
    if (!res.ok) throw new Error(json?.message ?? `Edge Function error: ${res.status}`);
  },
};
