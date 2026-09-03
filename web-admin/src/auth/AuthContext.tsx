import { createContext, useContext, useEffect, useState, type ReactNode } from 'react';
import { supabase, resolveLoginEmail, fetchFullProfile } from '../api/supabase';
import type { Profile } from '../api/types';

interface AuthState {
  user: Profile | null;
  loading: boolean;
  login: (identifier: string, password: string) => Promise<void>;
  logout: () => void;
}

const AuthContext = createContext<AuthState | undefined>(undefined);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<Profile | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    supabase.auth.getSession().then(async ({ data }) => {
      const uid = data.session?.user.id;
      if (uid) {
        const profile = await fetchFullProfile(uid);
        if (profile && profile.role === 'admin') setUser(profile as unknown as Profile);
        else await supabase.auth.signOut();
      }
      setLoading(false);
    });
  }, []);

  async function login(identifier: string, password: string) {
    const { error } = await supabase.auth.signInWithPassword({
      email: await resolveLoginEmail(identifier),
      password,
    });
    if (error) throw new Error(error.message.includes('Invalid') ? 'Invalid Hayaat ID or password.' : error.message);

    const uid = (await supabase.auth.getUser()).data.user?.id;
    const profile = uid ? await fetchFullProfile(uid) : null;
    if (!profile || profile.role !== 'admin') {
      await supabase.auth.signOut();
      throw new Error('This portal is for administrators only.');
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
