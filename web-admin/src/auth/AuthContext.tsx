import { createContext, useContext, useEffect, useState, type ReactNode } from 'react';
import { api, tokenStore, ApiError } from '../api/client';
import type { AuthResponse, Profile } from '../api/types';

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

  // Restore the session on first load by refreshing the stored token.
  useEffect(() => {
    const token = tokenStore.get();
    if (!token) {
      setLoading(false);
      return;
    }
    api
      .post<AuthResponse>('/auth/refresh', { token })
      .then((res) => {
        tokenStore.set(res.token);
        setUser(res.user);
      })
      .catch(() => tokenStore.clear())
      .finally(() => setLoading(false));
  }, []);

  async function login(identifier: string, password: string) {
    const res = await api.post<AuthResponse>('/auth/login', { identifier, password });
    if (res.user.role !== 'admin') {
      throw new ApiError('This portal is for administrators only. Staff use the staff portal.', 403);
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
