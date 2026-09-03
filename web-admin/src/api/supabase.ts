import { createClient } from '@supabase/supabase-js';

// Configured per environment via Vite env vars (see .env.example). The defaults
// below are the shared development project's *publishable* key — safe to ship because
// Row Level Security enforces all access. Production builds MUST set VITE_SUPABASE_*.
export const SUPABASE_URL =
  import.meta.env.VITE_SUPABASE_URL ?? 'https://iikwdtiqvxxatrzahuzo.supabase.co';
export const SUPABASE_PUBLISHABLE_KEY =
  import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY ?? 'sb_publishable_4axuKG5-YTuZeHuuzZjuVw_cB5_h-xn';

export const supabase = createClient(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, {
  auth: { storageKey: 'hayaat_admin_auth', persistSession: true, autoRefreshToken: true },
});

/** Resolve Hayaat ID/email/employee ID to the underlying Auth email. */
export async function resolveLoginEmail(identifier: string): Promise<string> {
  const id = identifier.trim();
  if (id.includes('@')) return id.toLowerCase();
  const { data, error } = await supabase.rpc('login_email', { p_id: id });
  if (error) throw new Error(error.message);
  if (!data) throw new Error('Invalid Hayaat ID or email.');
  return data as string;
}

/** Fetch a full profile (base + role-extended) for a user id. */
export async function fetchFullProfile(userId: string) {
  const { data: base } = await supabase.from('profiles').select('*').eq('id', userId).maybeSingle();
  if (!base) return null;
  const extTable: Record<string, string> = {
    patient: 'patient_profiles',
    doctor: 'doctor_profiles',
    lab_worker: 'lab_worker_profiles',
    receptionist: 'receptionist_profiles',
    admin: 'admin_profiles',
  };
  let extended: Record<string, unknown> = {};
  const table = extTable[base.role as string];
  if (table) {
    const { data: ext } = await supabase.from(table).select('*').eq('id', userId).maybeSingle();
    if (ext) extended = ext;
  }
  return { ...base, extended };
}
