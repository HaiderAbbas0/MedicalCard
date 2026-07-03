import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// Admin portal. Talks directly to Supabase (Auth + Postgres + Storage) — there is
// no application backend to proxy to. Supabase config comes from VITE_SUPABASE_*
// env vars (see .env.example).
export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
  },
});
