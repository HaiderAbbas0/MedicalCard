import { createClient } from '@supabase/supabase-js';

// Configured per environment via Vite env vars (see .env.example). The defaults
// below are the shared development project's *publishable* key — safe to ship
// because Row Level Security plus the research_* SECURITY DEFINER functions
// enforce all access. Production builds MUST set VITE_SUPABASE_*.
export const SUPABASE_URL =
  import.meta.env.VITE_SUPABASE_URL ?? 'https://iikwdtiqvxxatrzahuzo.supabase.co';
export const SUPABASE_PUBLISHABLE_KEY =
  import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY ?? 'sb_publishable_4axuKG5-YTuZeHuuzZjuVw_cB5_h-xn';

export const supabase = createClient(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, {
  // Namespaced so the research portal never shares a session with the admin or
  // staff portals on the same origin.
  auth: { storageKey: 'hayaat_research_auth', persistSession: true, autoRefreshToken: true },
});

/** Resolve a Hayaat ID / employee ID / email to the underlying Auth email. */
export async function resolveLoginEmail(identifier: string): Promise<string> {
  const id = identifier.trim();
  if (id.includes('@')) return id.toLowerCase();
  const { data, error } = await supabase.rpc('login_email', { p_id: id });
  if (error) throw new Error(error.message);
  if (!data) throw new Error('Invalid identifier or email.');
  return data as string;
}

/** Base profile plus the researcher extension row and its organisation. */
export async function fetchResearcherProfile(userId: string) {
  const { data: base } = await supabase.from('profiles').select('*').eq('id', userId).maybeSingle();
  if (!base) return null;
  const { data: ext } = await supabase
    .from('researcher_profiles')
    .select('*, organization:research_organizations(*)')
    .eq('id', userId)
    .maybeSingle();
  return { ...base, extended: ext ?? null };
}
