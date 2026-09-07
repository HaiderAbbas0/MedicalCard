import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// Staff portal. Talks directly to Supabase (Auth + Postgres + Storage) — there is
// no application backend to proxy to. Supabase config comes from VITE_SUPABASE_*
// env vars (see .env.example).
export default defineConfig({
  plugins: [react()],
  server: {
    port: 5174,
    // src/index.css imports ../../shared-ui/theme.css, which lives outside this
    // app's root - the dev server needs explicit permission to serve it.
    fs: { allow: ['..'] },
  },
});
