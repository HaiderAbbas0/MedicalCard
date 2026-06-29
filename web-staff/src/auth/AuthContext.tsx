import { createContext, useContext, useEffect, useState, type ReactNode } from 'react';
import { api, tokenStore, ApiError } from '../api/client';
import type { AuthResponse, Profile } from '../api/types';

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
    const token = tokenStore.get();
    if (!token) {
      setLoading(false);
      return;
    }
    api
      .post<AuthResponse>('/auth/refresh', { token })
      .then((res) => {
        if (!STAFF_ROLES.includes(res.user.role)) {
          tokenStore.clear();
          return;
        }
        tokenStore.set(res.token);
        setUser(res.user);
      })
      .catch(() => tokenStore.clear())
      .finally(() => setLoading(false));
  }, []);

  async function login(identifier: string, password: string) {
    const res = await api.post<AuthResponse>('/auth/login', { identifier, password });
    // Staff portal: doctors, lab workers, receptionists only.
    if (!STAFF_ROLES.includes(res.user.role)) {
      const who = res.user.role === 'admin' ? 'Administrators use the admin portal.' : 'Patients use the mobile app.';
      throw new ApiError(`This portal is for clinic staff. ${who}`, 403);
    }
    tokenStore.set(res.token);
    setUser(res.user);
  }

  function logout() {
    api.post('/auth/logout').catch(() => undefined);
    tokenStore.clear();
    setUser(null);
  }

  return <AuthContext.Provider value={{ user, loading, login, logout }}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be used within AuthProvider');
  return ctx;
}
