import { createClient } from '@supabase/supabase-js';

export const SUPABASE_URL = 'https://iikwdtiqvxxatrzahuzo.supabase.co';
export const SUPABASE_PUBLISHABLE_KEY = 'sb_publishable_4axuKG5-YTuZeHuuzZjuVw_cB5_h-xn';

export const supabase = createClient(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, {
  auth: { storageKey: 'hayaat_admin_auth', persistSession: true, autoRefreshToken: true },
});

/** CNIC/email → auth email (CNIC maps to <digits>@hayaat.id). */
export function emailFor(identifier: string): string {
  const id = identifier.trim();
  return id.includes('@') ? id : `${id.replace(/\D/g, '')}@hayaat.id`;
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
