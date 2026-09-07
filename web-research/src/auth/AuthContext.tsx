import { createContext, useContext, useEffect, useState, type ReactNode } from 'react';
import { supabase, resolveLoginEmail, fetchResearcherProfile } from '../api/supabase';
import type { ResearcherUser } from '../api/types';

interface AuthValue {
  user: ResearcherUser | null;
  loading: boolean;
  signIn: (identifier: string, password: string) => Promise<void>;
  signOut: () => Promise<void>;
}

const Ctx = createContext<AuthValue | null>(null);

export function useAuth() {
  const v = useContext(Ctx);
  if (!v) throw new Error('useAuth must be used within AuthProvider');
  return v;
}

/**
 * Gates the portal to researchers whose account AND organisation are both
 * active. A clinician or administrator who authenticates here is signed out
 * again — external company users must never share a session surface with
 * clinical staff.
 */
function gate(profile: Awaited<ReturnType<typeof fetchResearcherProfile>>): ResearcherUser {
  if (!profile) throw new Error('Account profile not found.');
  const role = (profile as { role?: string }).role;
  if (role !== 'researcher') {
    throw new Error('This portal is for approved research organisations only.');
  }
  if ((profile as { status?: string }).status !== 'active') {
    throw new Error('Your researcher account is not active yet. An administrator must approve it.');
  }
  const user = profile as unknown as ResearcherUser;
  const org = user.extended?.organization ?? null;
  if (!org) {
    throw new Error('Your account is not linked to an organisation. Contact your administrator.');
  }
  if (org.status !== 'active') {
    throw new Error(
      org.status === 'pending'
        ? 'Your organisation is still awaiting approval.'
        : 'Your organisation’s access has been suspended.',
    );
  }
  return user;
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<ResearcherUser | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    (async () => {
      try {
        const { data } = await supabase.auth.getSession();
        if (data.session) {
          // Re-validate on every restore, so a revoked researcher or suspended
          // organisation loses access on the next load rather than lingering.
          const profile = await fetchResearcherProfile(data.session.user.id);
          try {
            setUser(gate(profile));
          } catch {
            await supabase.auth.signOut();
            setUser(null);
          }
        }
      } finally {
        setLoading(false);
      }
    })();
  }, []);

  const signIn = async (identifier: string, password: string) => {
    const email = await resolveLoginEmail(identifier);
    const { data, error } = await supabase.auth.signInWithPassword({ email, password });
    if (error) {
      throw new Error(
        /invalid/i.test(error.message) ? 'Invalid identifier or password.' : error.message,
      );
    }
    const profile = await fetchResearcherProfile(data.user.id);
    try {
      setUser(gate(profile));
    } catch (e) {
      await supabase.auth.signOut();
      throw e;
    }
  };

  const signOut = async () => {
    await supabase.auth.signOut();
    setUser(null);
  };

  return <Ctx.Provider value={{ user, loading, signIn, signOut }}>{children}</Ctx.Provider>;
}
