import { createContext, useContext, useEffect, useState, type ReactNode } from 'react';
import { supabase, resolveLoginEmail, fetchFullProfile } from '../api/supabase';
import type { Profile } from '../api/types';

interface AuthState {
  user: Profile | null;
  loading: boolean;
  login: (identifier: string, password: string) => Promise<void>;
  logout: () => void;
}

const STAFF_ROLES = ['doctor', 'lab_worker', 'receptionist'];
const AuthContext = createContext<AuthState | undefined>(undefined);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<Profile | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    supabase.auth.getSession().then(async ({ data }) => {
      const uid = data.session?.user.id;
      if (uid) {
        const profile = await fetchFullProfile(uid);
        if (profile && STAFF_ROLES.includes(profile.role as string)) setUser(profile as unknown as Profile);
        else await supabase.auth.signOut();
      }
      setLoading(false);
    });
  }, []);

  async function login(identifier: string, password: string) {
    const email = await resolveLoginEmail(identifier);
    const { error } = await supabase.auth.signInWithPassword({ email, password });
    if (error) throw new Error(error.message.includes('Invalid') ? 'Invalid Hayaat ID or password.' : error.message);

    const uid = (await supabase.auth.getUser()).data.user?.id;
    const profile = uid ? await fetchFullProfile(uid) : null;
    if (!profile || !STAFF_ROLES.includes(profile.role as string)) {
      await supabase.auth.signOut();
      const who = profile?.role === 'admin' ? 'Administrators use the admin portal.' : 'Patients use the mobile app.';
      throw new Error(`This portal is for clinic staff. ${who}`);
    }
    if (profile.status !== 'active') {
      await supabase.auth.signOut();
      throw new Error('Your account is not active yet. An administrator must approve it.');
    }
    setUser(profile as unknown as Profile);
  }

  function logout() {
    supabase.auth.signOut();
    setUser(null);
  }

  return <AuthContext.Provider value={{ user, loading, login, logout }}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be used within AuthProvider');
  return ctx;
}
