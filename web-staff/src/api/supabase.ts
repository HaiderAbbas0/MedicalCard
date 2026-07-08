import { createClient } from '@supabase/supabase-js';

// Configured per environment via Vite env vars (see .env.example). The defaults
// below are the shared dev/demo project's *publishable* key — safe to ship because
// Row Level Security enforces all access. Production builds MUST set VITE_SUPABASE_*.
export const SUPABASE_URL =
  import.meta.env.VITE_SUPABASE_URL ?? 'https://iikwdtiqvxxatrzahuzo.supabase.co';
export const SUPABASE_PUBLISHABLE_KEY =
  import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY ?? 'sb_publishable_4axuKG5-YTuZeHuuzZjuVw_cB5_h-xn';

export const supabase = createClient(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, {
  auth: { storageKey: 'hayaat_staff_auth', persistSession: true, autoRefreshToken: true },
});

/**
 * CNIC/Employee ID/email → auth email.
 *  - Already an email → used as-is.
 *  - All-digit identifier (13-digit CNIC) → `<digits>@hayaat.id`.
 *  - Alphanumeric identifier (receptionist Employee ID, e.g. "REC-005")
 *    → `<employee_id lowercased>@hayaat.id`, matching how
 *    admin-create-user aliases receptionist accounts.
 */
export function emailFor(identifier: string): string {
  const id = identifier.trim();
  if (id.includes('@')) return id;
  const digitsOnly = id.replace(/\D/g, '');
  if (digitsOnly.length > 0 && digitsOnly === id.replace(/[\s-]/g, '')) {
    // Pure numeric identifier (CNIC) — keep existing digit-stripping behavior.
    return `${digitsOnly}@hayaat.id`;
  }
  // Alphanumeric identifier (Employee ID) — normalize case, keep as-is otherwise.
  return `${id.toLowerCase()}@hayaat.id`;
}

/** Returns the current logged-in user's UUID. */
export async function myId(): Promise<string> {
  const { data } = await supabase.auth.getUser();
  return data.user?.id ?? '';
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